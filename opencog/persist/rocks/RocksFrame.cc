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

/// Load the entire collection of AtomSpace frames.
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

	const auto& pr = _frame_map.find(hasp);
	if (_frame_map.end() == pr)
		throw IOException(TRACE_INFO,
			"Cannot find the AtomSpace in the AtomSpace DAG!\n");

	// OK, we've got the frame to delete.
	// First, get rid of all the atoms in it.
	std::string fid = pr->second + ":";
	std::string oid = "o@" + fid;
printf("hello world %s\n", fid.c_str());

	// Loop over all atoms in the frame, and delete any keys on them.
	size_t sidoff = oid.size();
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(oid); it->Valid() and it->key().starts_with(oid); it->Next())
	{
		const std::string& fis = it->key().ToString();
		const std::string& sid = fis.substr(sidoff);
printf("hello sid %s\n", sid.c_str());

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
}

// ======================== THE END ======================
