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

/// int to base-62 We use base62 not base64 because we
/// want to reserve punctuation "just in case" as special chars.
std::string RocksStorage::aidtostr(uint64_t aid) const
{
	std::string s;
	do
	{
		char c = aid % 62;
		if (c < 10) c += '0';
		else if (c < 37) c += 'A' - 10;
		else c += 'a' - 36;
		s.push_back(c);
	}
	while (0 < (aid /= 62));

	return s;
}

/// base-62 to int
uint64_t RocksStorage::strtoaid(const std::string& sid) const
{
	uint64_t aid = 0;

	int len = sid.size();
	int i = 0;
	uint64_t shift = 1;
	while (i < len)
	{
		char c = sid[i];
		if (c <= '9') c -= '0';
		else if (c <= 'Z') c -= 'A' - 10;
		else c -= 'a' - 36;

		aid += shift * c;
		i++;
		shift *= 62;
	}

	return aid;
}

/// Verify that the Atom is in storage.
/// Return the matching sid.
std::string RocksStorage::writeAtom(const Handle& h)
{
	std::string satom = Sexpr::encode_atom(h);

	std::string sid;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), satom, &sid);
	if (not s.ok())
	{
		if (h->is_link())
		{
			// Store the outgoing set .. just in case someone asks for it.
			for (const Handle& ho : h->getOutgoingSet())
				writeAtom(ho);
		}
		uint64_t aid = _next_aid.fetch_add(1);
		sid = aidtostr(aid);
		_rfile->Put(rocksdb::WriteOptions(), satom, sid);
	}
printf("Store sid= >>%s<< for %s\n", sid.c_str(), satom.c_str());
	return sid;
}

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	std::string sid = writeAtom(h);

	// Separator for values
	sid.push_back(':');
	for (const Handle& key : h->getKeys())
		storeValue(sid, h, key);
}

void RocksStorage::storeValue(const std::string& sid,
                              const Handle& h,
                              const Handle& key)
{
	std::string skey = sid + writeAtom(key);
	ValuePtr vp = h->getValue(key);
	std::string sval = Sexpr::encode_value(vp);
	_rfile->Put(rocksdb::WriteOptions(), skey, sval);
}

void RocksStorage::storeValue(const Handle& h, const Handle& key)
{
	std::string sid = writeAtom(h) + ":";
	storeValue(sid, h, key);
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
