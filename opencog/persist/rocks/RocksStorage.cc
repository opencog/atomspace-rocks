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

	// RocksDB likes to splurge with `*.sst` files. Without setting the
	// upper bound, Rocks will exceed the ulimit -n setting, and follow
	// up with data corruption. Worse: it appears that total RAM usage
	// is about 3x the total disk usage, and disk usage is dominated by
	// tempory sst files. For me, each sst file is about 40MBytes, and
	// costs about 120MBytes of RAM. Thus, 100 of these chews up 12
	// GBytes, and 1K of them chews up 120GBytes. Root cause, unknown.
	// See https://github.com/facebook/rocksdb/issues/3216 for more.
	// The below hard-codes max_open_files to 300, which means that
	// Rocks will use about 172 sst files, and about 20GB RAM. XXX
	// This is submission by blunt-force trauma; something more elegant
	// is needed here.
	struct rlimit maxfh;
	getrlimit(RLIMIT_NOFILE, &maxfh);
	size_t max_of = maxfh.rlim_cur;
	if (400 < max_of) max_of -= 200;
	else max_of /= 2;
	if (300 < max_of) max_of = 300;

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

void RocksStorage::print_stats(void)
{
	printf("Connected to %s\n", _uri.c_str());
	printf("Database contents:\n");
	printf("Next aid: %lu\n", _next_aid.load());
	printf("Atoms/Links/Nodes a@: %lu l@: %lu n@: %lu\n",
		count_records("a@"), count_records("l@"), count_records("n@"));
	printf("Keys/Incoming/Hash k@: %lu i@: %lu h@: %lu\n",
		count_records("k@"), count_records("i@"), count_records("h@"));

	printf("\n");
	struct rlimit maxfh;
	getrlimit(RLIMIT_NOFILE, &maxfh);
	printf("Unix max open files lim=%lu %lu\n", maxfh.rlim_cur, maxfh.rlim_max);
}

DEFINE_NODE_FACTORY(RocksStorageNode, ROCKS_STORAGE_NODE)

/* ============================= END OF FILE ================= */
