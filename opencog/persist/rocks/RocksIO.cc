/*
 * RocksIO.cc
 * Save/restore of individual atoms.
 *
 * Copyright (c) 2020 Linas Vepstas <linas@linas.org>
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

#include <opencog/atoms/base/Atom.h>
#include <opencog/atoms/base/Node.h>
#include <opencog/atoms/base/Link.h>
#include <opencog/atomspace/AtomSpace.h>
#include <opencog/persist/sexpr/Sexpr.h>

#include "RocksStorage.h"

using namespace opencog;

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::storeValue(const Handle& h, const Handle& key)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::loadValue(const Handle& h, const Handle& key)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::removeAtom(const Handle& h, bool recursive)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

Handle RocksStorage::getNode(Type t, const char * str)
{
	throw IOException(TRACE_INFO, "Not implemented!");
	return Handle();
}

Handle RocksStorage::getLink(Type t, const HandleSeq& hs)
{
	throw IOException(TRACE_INFO, "Not implemented!");
	return Handle();
}

void RocksStorage::getIncomingSet(AtomTable& table, const Handle& h)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::getIncomingByType(AtomTable& table, const Handle& h, Type t)
{
}

void RocksStorage::loadAtomSpace(AtomTable &table)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::loadType(AtomTable &table, Type t)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::storeAtomSpace(const AtomTable &table)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::kill_data(void)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

void RocksStorage::runQuery(const Handle& query, const Handle& key,
                                const Handle& meta, bool fresh)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}
