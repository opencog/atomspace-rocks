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

#include <filesystem>
#include <sys/resource.h>

#include "rocksdb/db.h"
#include "rocksdb/slice.h"
#include "rocksdb/options.h"
// #include "rocksdb/table.h"
// #include "rocksdb/filter_policy.h"

#include <opencog/util/Logger.h>
#include <opencog/atoms/base/Node.h>
#include <opencog/persist/rocks-types/atom_types.h>

#include "RocksStorage.h"

using namespace opencog;

static const char* aid_key = "*-NextUnusedAID-*";
static const char* version_key = "*-Version-*";

/* ================================================================ */
// Constructors

void RocksStorage::init(const char * uri, bool read_only)
{
#define URIX_LEN (sizeof("rocks://") - 1)  // Should be 8
	// We expect the URI to be for the form (note: three slashes)
	//    rocks:///path/to/file
	std::string file(uri + URIX_LEN);

	rocksdb::Options options;
	options.IncreaseParallelism();

	// Setting this is supposed to reduce how often compactions run,
	// and how much CPU they take. Seems to help when we're doing
	// intensive I/O.
	options.OptimizeLevelStyleCompaction();

	// This might improve performance, maybe. It will use a hash table
	// instead of a binary tree for lookup. Iterators over a hash table
	// are then managed by using bloom filters.
	// options.OptimizeForPointLookup();

	// Prefix for bloom filter -- first 2 chars.
	// options.prefix_extractor.reset(rocksdb::NewFixedPrefixTransform(2));

	// Create the file if it doesn't exist yet (not in read-only mode).
	options.create_if_missing = not read_only;

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
	rocksdb::Status s;
	if (read_only)
		s = rocksdb::DB::OpenForReadOnly(options, file, &_rfile);
	else
		s = rocksdb::DB::Open(options, file, &_rfile);

	if (not s.ok())
		throw IOException(TRACE_INFO, "Can't open file: %s",
			s.ToString().c_str());

	_read_only = read_only;

	// Does the file contain multiple atomspaces?
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	it->Seek("f@");
	if (it->Valid() and it->key().starts_with("f@"))
		_multi_space = true;
	delete it;

	// Verify the version number.
	// If there is no version number, then the DB has no frames;
	//    its a mono-space DB (and the mono driver should be used).
	// Version 1 DB's might have frames. They work with current code.
	// Version 2 DB's have frame reversed indexes ("o@") for frame
	//    deletion. Frames cannot be deleted without this. Added Oct 2022.
	std::string version;
	s = _rfile->Get(rocksdb::ReadOptions(), version_key, &version);
	if (not s.ok())
	{
		if (read_only)
			throw IOException(TRACE_INFO,
				"Cannot open read-only: DB has no version (not initialized)");
		_rfile->Put(rocksdb::WriteOptions(), version_key, "2");
	}
	else
	{
		if (0 != version.compare("1") and
		    0 != version.compare("2"))
			throw IOException(TRACE_INFO,
				"Unsupported DB version '%s'\n", version.c_str());

		// If it's version 1, and does not (yet) contain multiple
		// spaces, it is safe to upgrade to version 2.
		// Skip upgrade in read-only mode.
		if (not read_only and 0 == version.compare("1") and not _multi_space)
			_rfile->Put(rocksdb::WriteOptions(), version_key, "2");
	}

	// If the file was created just now, then set the UUID to 1.
	std::string sid;
	s = _rfile->Get(rocksdb::ReadOptions(), aid_key, &sid);
	if (not s.ok())
	{
		if (read_only)
			throw IOException(TRACE_INFO,
				"Cannot open read-only: DB has no aid (not initialized)");
		_next_aid = 1;
		sid = aidtostr(1);
		s = _rfile->Put(rocksdb::WriteOptions(), aid_key, sid);
	}
	else
		_next_aid = strtoaid(sid) + 1; // next unused...

// Informational prints.
printf("Rocks: opened=%s%s\n", file.c_str(), read_only ? " (read-only)" : "");
printf("Rocks: DB-version=%s multi-space=%d initial aid=%lu\n",
get_version().c_str(), _multi_space, _next_aid.load());

	if (read_only) return;

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
	init(_name.c_str(), false);
}

void RocksStorage::open_read_only()
{
	// User might call us twice. If so, ignore the second call.
	if (_rfile) return;
	init(_name.c_str(), true);
}

RocksStorage::RocksStorage(std::string uri) :
	StorageNode(ROCKS_STORAGE_NODE, std::move(uri)),
	_rfile(nullptr),
	_multi_space(false),
	_read_only(false),
	_unknown_type(false),
	_next_aid(0)
{
	const char *yuri = _name.c_str();

	// We expect the URI to be for the form (note: three slashes)
	//    rocks:///path/to/file
	if (strncmp(yuri, "rocks://", URIX_LEN))
		throw IOException(TRACE_INFO,
			"Unknown URI '%s'\nValid URI's start with 'rocks://'\n", yuri);

	// Normalize the filename. This avoids multiple different
	// StorageNodes referring to exactly the same file.
	std::string file(yuri + URIX_LEN);
	std::filesystem::path fpath(file);
	std::filesystem::path npath(fpath.lexically_normal());
	file = npath.string();
	_uri = "rocks://" + file;
	_name = _uri;
}

RocksStorage::~RocksStorage()
{
	close();
}

void RocksStorage::close()
{
	if (nullptr == _rfile) return;

	if (not _read_only)
	{
		logger().debug("Rocks: storing final aid=%lu\n", _next_aid.load());
		write_aid();
	}
	delete _rfile;
	_rfile = nullptr;
	_next_aid = 0;

	// Invalidate the local cache.
	_multi_space = false;
	_read_only = false;
	_frame_map.clear();
	_fid_map.clear();
	_top_frames.clear();
}

std::string RocksStorage::get_version(void)
{
	std::string version;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), version_key, &version);
	if (not s.ok())
		throw IOException(TRACE_INFO, "Cannot find the DB version!");
	return version;
}

void RocksStorage::write_aid(void)
{
	// We write the highest issued atom-id. This is the behavior that
	// is compatible with writeAtom(), which also writes the atom-id.
	uint64_t naid = _next_aid.load();
	naid --;
	std::string sid = aidtostr(naid);
	_rfile->Put(rocksdb::WriteOptions(), aid_key, sid);
}

std::string RocksStorage::get_new_aid(void)
{
	uint64_t aid = _next_aid.fetch_add(1);
	std::string sid = aidtostr(aid);

	// Update immediately, in case of a future crash or badness...
	// This isn't "really" necessary, because our dtor ~RocksStorage()
	// updates this value. But if someone crashes before our dtor runs,
	// we want to make sure the new bumped value is written, before we
	// start using it in other records.  We want to avoid issuing it
	// twice.
	_rfile->Put(rocksdb::WriteOptions(), aid_key, sid);

	return sid;
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
void RocksStorage::barrier(AtomSpace* as)
{
	if (_read_only) return;
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

	if (nullptr == _rfile)
	{
		rs += "RocksStorageNode is closed; no stats available\n";
		return rs;
	}

	rs += "Database contents:\n";
	rs += "  Version: " + get_version();
	rs += "  Multispace: " + std::to_string(_multi_space);
	rs += "\n";
	rs += "  Next aid: " + std::to_string(_next_aid.load());
	rs += "  Frame count f@: " + std::to_string(count_records("f@"));
	rs += "\n";
	rs += "  Atom/Link/Node count a@: " + std::to_string(count_records("a@"));
	rs += " l@: " + std::to_string(count_records("l@"));
	rs += " n@: " + std::to_string(count_records("n@"));
	rs += "\n";
	rs += "  Keys/Incoming/Hash count k@: " + std::to_string(count_records("k@"));
	rs += " i@: " + std::to_string(count_records("i@"));
	rs += " h@: " + std::to_string(count_records("h@"));
	rs += "\n";

	if (_multi_space)
	{
		rs += "\n";
		rs += "  Height Distribution:\n";
		size_t height = 1;
		while (true)
		{
			std::string zed = "z" + aidtostr(height) + "@";
			size_t nrec = count_records(zed);
			if (0 == nrec) break;
			rs += "    " + zed + ": " + std::to_string(nrec) + "\n";
			height ++;
		}

		HandleSeq tops = topFrames();
		rs += "\n";
		rs += "  Number of Frame tops: " + std::to_string(tops.size());
		if (0 == tops.size())
			rs += " (Frames must be loaded to see frame stats)";
		rs += "\n";
		for (const Handle& ht: tops)
		{
			rs += "  Frame top: `" + AtomSpaceCast(ht)->get_name() + "`\n";
			rs += "  Size   Name\n";
			// total order
			std::map<uint64_t, Handle> totor;
			makeOrder(ht, totor);
			for (const auto& pr : totor)
			{
				const Handle& hasp = pr.second;
				const AtomSpacePtr asp = AtomSpaceCast(hasp);
				std::string fid = aidtostr(pr.first);
				size_t nrec = count_records("o@" + fid);
				rs += "    " + std::to_string(nrec) + "\t`";
				rs += asp->get_name() + "`\n";
			}
		}
	}

	rs += "\n";

	struct rlimit maxfh;
	getrlimit(RLIMIT_NOFILE, &maxfh);
	rs += "Unix max open files rlimit cur: " + std::to_string(maxfh.rlim_cur);
	rs += " rlimit max: " + std::to_string(maxfh.rlim_max);
	rs += "\n";
	return rs;
}

void RocksStorage::print_stats(void)
{
	if (nullptr == _rfile) return;

	std::string rstats;
	_rfile->GetProperty("rocksdb.stats", &rstats);
	printf("%s\n\n", rstats.c_str());
	printf("Please wait, computing AtomSpace stats now ...\n");
	fflush(stdout);
	printf("%s\n", monitor().c_str());
}

DEFINE_NODE_FACTORY(RocksStorageNode, ROCKS_STORAGE_NODE)

/* ============================= END OF FILE ================= */
