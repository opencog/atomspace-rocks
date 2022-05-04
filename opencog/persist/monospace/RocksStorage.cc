/*
 * FILE:
 * opencog/persist/rocks/RocksStorage.cc
 *
 * FUNCTION:
 * Simple CogServer-backed persistent storage.
 *
 * HISTORY:
 * Copyright (c) 2020 Linas Vepstas <linasvepstas@gmail.com>
 *
 * LICENSE:
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License v3 as
 * published by the Free Software Foundation and including the exceptions
 * at http://opencog.org/wiki/Licenses
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program; if not, write to:
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <sys/resource.h>

#include "rocksdb/db.h"
#include "rocksdb/slice.h"
#include "rocksdb/options.h"
// #include "rocksdb/table.h"
// #include "rocksdb/filter_policy.h"

#include <opencog/util/Logger.h>
#include <opencog/atoms/base/Node.h>

#include "RocksStorage.h"

using namespace opencog;

static const char* aid_key = "*-NextUnusedAID-*";

/* ================================================================ */
// Constructors

void RocksStorage::init(const char * uri)
{
	_uri = uri;

#define URIX_LEN (sizeof("rocks://") - 1)  // Should be 8
	// We expect the URI to be for the form (note: three slashes)
	//    rocks:///path/to/file
	std::string file(uri + URIX_LEN);

	rocksdb::Options options;
	options.IncreaseParallelism();
	options.OptimizeLevelStyleCompaction();

	// Prefix for bloom filter -- first 2 chars.
	// options.prefix_extractor.reset(rocksdb::NewFixedPrefixTransform(2));

	// Create the file if it doesn't exist yet.
	options.create_if_missing = true;

	// The primary consumer of disk and RAM in RocksDB are the `*.sst`
	// files: each one is opened and memory-mapped. RocksDB does NOT
	// check the `ulimit -n` setting, and can overflow it, resulting
	// in failed reads and dropped writes. We MUST set `max_open_files`
	// to an acceptable value. Rocks will run, just more slowly, when
	// it hits this limit.
	//
	// For me, each sst file averages about 40MBytes, with a roughly
	// comparable amount of RAM usage. Thus, the linux default of 1024
	// limits RAM usage to about 40GBytes.
	//
	// The setting is a bit of a guesstimate: guile+opencog currently
	// uses 185 filedesc's for open *.so shared libs and *.go bytecode
	// files, and another 25 for misc other stuff. So reserve that many
	// plus a little more, for future expansion.  This is a bit blunt.
	struct rlimit maxfh;
	getrlimit(RLIMIT_NOFILE, &maxfh);
	size_t max_of = maxfh.rlim_cur;
	if (256 < max_of) max_of -= 230;
	else
		throw IOException(TRACE_INFO,
			"Open file limit too low. Set ulimit -n 1024 or larger!");

	options.max_open_files = max_of;

#if 0
	// According to the RocksDB wiki, Bloom filters should make
	// everything go faster for us, since we use lots of Get()'s.
	// But the unit tests are completely unaffected by this.
	// So don't enable.
	rocksdb::BlockBasedTableOptions toptions;
	toptions.filter_policy.reset(rocksdb::NewBloomFilterPolicy(10, false));
	// toptions.optimize_filters_for_memory = true;
	auto tfactory = rocksdb::NewBlockBasedTableFactory(toptions);
	options.table_factory.reset(tfactory);
#endif

	// Open the file.
	rocksdb::Status s = rocksdb::DB::Open(options, file, &_rfile);

	if (not s.ok())
		throw IOException(TRACE_INFO, "Can't open file: %s",
			s.ToString().c_str());

	// If the file was created just now, then set the UUID to 1.
	std::string sid;
	s = _rfile->Get(rocksdb::ReadOptions(), aid_key, &sid);
	if (not s.ok())
	{
		_next_aid = 1;
		sid = aidtostr(1);
		s = _rfile->Put(rocksdb::WriteOptions(), aid_key, sid);
	}
	else
		_next_aid = strtoaid(sid) + 1; // next unused...

printf("Rocks: opened=%s\n", file.c_str());
printf("Rocks: initial aid=%lu\n", _next_aid.load());

	// Set up a SID for the TV predicate key.
	// This must match what the AtomSpace is using.
	// Tack on a leading colon, for convenience.
	Handle h = createNode(PREDICATE_NODE, "*-TruthValueKey-*");
	tv_pred_sid = writeAtom(h);
}

void RocksStorage::open()
{
	// User might call us twice. If so, ignore the second call.
	if (_rfile) return;
	init(_name.c_str());
}

RocksStorage::RocksStorage(std::string uri) :
	StorageNode(ROCKS_STORAGE_NODE, std::move(uri)),
	_rfile(nullptr),
	_next_aid(0)
{
	const char *yuri = _name.c_str();
	if (strncmp(yuri, "rocks://", URIX_LEN))
		throw IOException(TRACE_INFO, "Unknown URI '%s'\n", yuri);
}

RocksStorage::~RocksStorage()
{
	close();
}

void RocksStorage::close()
{
	if (nullptr == _rfile) return;

	logger().debug("Rocks: storing final aid=%lu\n", _next_aid.load());
	write_aid();
	delete _rfile;
	_rfile = nullptr;
	_next_aid = 0;
}

void RocksStorage::write_aid(void)
{
	// We write the highest issued atom-id. This is the behavior that
	// is compatible with writeAtom(), which also write the atom-id.
	uint64_t naid = _next_aid.load();
	naid --;
	std::string sid = aidtostr(naid);
	_rfile->Put(rocksdb::WriteOptions(), aid_key, sid);
}

bool RocksStorage::connected(void)
{
	return nullptr != _rfile;
}

/* ================================================================== */
/// Drain the pending store queue. This is a fencing operation; the
/// goal is to make sure that all writes that occurred before the
/// barrier really are performed before before all the writes after
/// the barrier.
///
void RocksStorage::barrier()
{
	// belt and suspenders.
	write_aid();
}

/* ================================================================ */

void RocksStorage::clear_stats(void)
{
}

std::string RocksStorage::monitor(void)
{
	std::string rs;
	rs += "Connected to `" + _uri + "`\n";
	rs += "Database contents:\n";
	rs += "  Next aid: " + std::to_string(_next_aid.load());
	rs += "\n";
	rs += "  Atoms/Links/Nodes a@: " + std::to_string(count_records("a@"));
	rs += " l@: " + std::to_string(count_records("l@"));
	rs += " n@: " + std::to_string(count_records("n@"));
	rs += "\n";
	rs += "  Keys/Incoming/Hash k@: " + std::to_string(count_records("k@"));
	rs += " i@: " + std::to_string(count_records("i@"));
	rs += " h@: " + std::to_string(count_records("h@"));
	rs += "\n";

	struct rlimit maxfh;
	getrlimit(RLIMIT_NOFILE, &maxfh);
	rs += "Unix max open files rlimit= " + std::to_string(maxfh.rlim_cur);
	rs += " " + std::to_string(maxfh.rlim_max);
	rs += "\n";
	return rs;
}

void RocksStorage::print_stats(void)
{
	printf("%s\n", monitor().c_str());
}

DEFINE_NODE_FACTORY(RocksStorageNode, ROCKS_STORAGE_NODE)

/* ============================= END OF FILE ================= */
