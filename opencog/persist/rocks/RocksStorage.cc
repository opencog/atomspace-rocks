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


#include "rocksdb/db.h"
#include "rocksdb/slice.h"
#include "rocksdb/options.h"

#include "RocksStorage.h"

using namespace opencog;

/* ================================================================ */
// Constructors

void RocksStorage::init(const char * uri)
{
#define URIX_LEN (sizeof("rocks://") - 1)  // Should be 8
	if (strncmp(uri, "rocks://", URIX_LEN))
		throw IOException(TRACE_INFO, "Unknown URI '%s'\n", uri);

	_uri = uri;

	// We expect the URI to be for the form (note: three slashes)
	//    rocks:///path/to/file

	std::string file(uri + URIX_LEN);

	rocksdb::Options options;
	options.IncreaseParallelism();
	options.OptimizeLevelStyleCompaction();

	// Create the file if it doesn't exist yet.
	options.create_if_missing = true;

	// Open the file
	rocksdb::Status s = rocksdb::DB::Open(options, file, &_rfile);

	if (not s.ok())
		throw IOException(TRACE_INFO, "Can't open file: %s",
			s.ToString().c_str());

	s = _rfile->Put(rocksdb::WriteOptions(), "foo", "bar");
}

RocksStorage::RocksStorage(std::string uri) :
	_rfile(nullptr),
	_next_aid(0)
{
	init(uri.c_str());
}

RocksStorage::~RocksStorage()
{
	delete _rfile;
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
}

/* ================================================================ */

void RocksStorage::registerWith(AtomSpace* as)
{
	BackingStore::registerWith(as);
}

void RocksStorage::unregisterWith(AtomSpace* as)
{
	BackingStore::unregisterWith(as);
}

/* ================================================================ */

void RocksStorage::clear_stats(void)
{
}

void RocksStorage::print_stats(void)
{
	printf("Connected to %s\n", _uri.c_str());
	printf("no stats yet\n");
}

/* ============================= END OF FILE ================= */
