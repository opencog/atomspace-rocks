/*
 * RocksFrame.cc
 * Delete and collapse frames.
 *
 * Copyright (c) 2022 Linas Vepstas <linas@linas.org>
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

#include <iomanip> // for std::quote

#include <opencog/atomspace/AtomSpace.h>
#include <opencog/persist/sexpr/Sexpr.h>

#include "RocksStorage.h"
#include "RocksUtils.h"

using namespace opencog;

// ======================================================================

/// Delete all keys on all atoms in the indicated frame, and
/// then delete the record of the frame itself. This will leak
/// atoms, if the frame contains Atoms that do not appear in any
/// other frame. These will remain behind in the DB, orphaned.
/// These can be easily found, by searching for sids that have
/// no k@ on them.  A DB scrub routine (not implemented) could
/// "easily" remove them.
void RocksStorage::deleteFrame(AtomSpace* frame)
{
	CHECK_OPEN;
	if (not _multi_space)
		throw IOException(TRACE_INFO, "There are no frames!");

	std::string db_version = get_version();
	if (0 != db_version.compare("2"))
		throw IOException(TRACE_INFO, "DB too old to support frame deletion!");

	Handle hasp = HandleCast(frame);

	if (0 < hasp->getIncomingSetSize())
		throw IOException(TRACE_INFO,
			"Deletion of non-top frames is not currently supported!\n");

	// Everything under here proceeds with the frame lock held.
	std::lock_guard<std::mutex> flck(_mtx_frame);

	const auto& pr = _frame_map.find(hasp);
	if (_frame_map.end() == pr)
		throw IOException(TRACE_INFO,
			"Cannot find the AtomSpace in the AtomSpace DAG!\n");

	// OK, we've got the frame to delete.
	// First, get rid of all the atoms in it.
	std::string fid = pr->second + ":";
	std::string oid = "o@" + fid;

	// Loop over all atoms in the frame, and delete any keys on them.
	size_t sidoff = oid.size();
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(oid); it->Valid() and it->key().starts_with(oid); it->Next())
	{
		const std::string& fis = it->key().ToString();
		const std::string& sid = fis.substr(sidoff);

		// Delete all values hanging on the atom ...
		std::string pfx = "k@" + sid + ":" + fid;
		auto kt = _rfile->NewIterator(rocksdb::ReadOptions());
		for (kt->Seek(pfx); kt->Valid() and kt->key().starts_with(pfx); kt->Next())
			_rfile->Delete(rocksdb::WriteOptions(), kt->key());
		delete kt;

		// Delete the key itself
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
	}
	delete it;

	// Delete the frame encoding, too.
	fid = pr->second;
	std::string did = "d@" + fid;
	std::string senc;
	_rfile->Get(rocksdb::ReadOptions(), did, &senc);
	_rfile->Delete(rocksdb::WriteOptions(), did);
	_rfile->Delete(rocksdb::WriteOptions(), "f@" + senc);

	// Finally, remove it from out own tables.
	_fid_map.erase(fid);
	_frame_map.erase(hasp);
}

// ======================================================================

/// Scrube away any orphaned Atoms resulting from frame deletion.
void RocksStorage::scrubFrames(void)
{
printf("hello scrub\n");
}

// ======================== THE END ======================
