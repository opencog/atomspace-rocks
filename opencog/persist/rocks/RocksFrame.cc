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

using namespace opencog;

// ======================================================================

#define CHECK_OPEN \
	if (nullptr == _rfile) \
		throw IOException(TRACE_INFO, "RocksDB is not open! %s", \
			_name.c_str());

// =========================================================

/// Load the entire collection of AtomSpace frames.
void RocksStorage::deleteFrame(AtomSpace* frame)
{
	CHECK_OPEN;
printf("hello world\n");
	_multi_space = true;
}

// ======================== THE END ======================
