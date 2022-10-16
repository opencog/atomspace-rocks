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
	HandleSeq all_atoms;
	get_atoms_in_frame(frame, all_atoms);

printf("hello world fid=%s num=%lu\n", pr->second.c_str(),
all_atoms.size());

	for (const Handle& h : all_atoms)
	{
		doRemoveAtom(h);
	}
}

// ======================== THE END ======================
