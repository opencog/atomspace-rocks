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
}

void RocksStorage::storeValue(const Handle& h, const Handle& key)
{
}

void RocksStorage::loadValue(const Handle& h, const Handle& key)
{
}

void RocksStorage::removeAtom(const Handle& h, bool recursive)
{
}

Handle RocksStorage::getNode(Type t, const char * str)
{
	return Handle();
}

Handle RocksStorage::getLink(Type t, const HandleSeq& hs)
{
	return Handle();
}

void RocksStorage::getIncomingSet(AtomTable& table, const Handle& h)
{
}

void RocksStorage::getIncomingByType(AtomTable& table, const Handle& h, Type t)
{
}

void RocksStorage::loadAtomSpace(AtomTable &table)
{
}

void RocksStorage::loadType(AtomTable &table, Type t)
{
}

void RocksStorage::storeAtomSpace(const AtomTable &table)
{
}

void RocksStorage::kill_data(void)
{
}

void RocksStorage::runQuery(const Handle& query, const Handle& key,
                                const Handle& meta, bool fresh)
{
}
