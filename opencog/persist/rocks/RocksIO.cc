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

// ======================================================================
// Common abbreviations:
// satom == string s-expression for an Atom.
// sval == string s-expression for a Value.
// aid == uint-64 atom ID.
// sid == aid as ASCII string.
// kid == sid for a key
// skid == sid:kid pair of id's

// associative pairs in the Rocks DB are:
// sid . satom -- finds the satom associated with sid
// satom . sid -- finds the sid associated with the satom
// sid@keys . key-list -- find the list of all Keys on Atom
// sid:kid . sval -- find the value for the Atom,Key

/// Place Atom into storage.
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
		_rfile->Put(rocksdb::WriteOptions(), sid, satom);
	}
printf("Store sid= >>%s<< for >>%s<<\n", sid.c_str(), satom.c_str());
	return sid;
}

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	std::string sid = writeAtom(h);

	// Separator for keys
	std::string cid = sid + ":";

	// Create a list of all keys...
	std::string keylist;
	for (const Handle& key : h->getKeys())
	{
		std::string skey = writeAtom(key);
		keylist += skey + " ";

		ValuePtr vp = h->getValue(key);
		storeValue(cid + skey, vp);
	}

	_rfile->Put(rocksdb::WriteOptions(), sid + "@keys", keylist);
}

void RocksStorage::storeValue(const std::string& skid,
                              const ValuePtr& vp)
{
	std::string sval = Sexpr::encode_value(vp);
	_rfile->Put(rocksdb::WriteOptions(), skid, sval);
}

/// Backing-store API.
void RocksStorage::storeValue(const Handle& h, const Handle& key)
{
	std::string sid = writeAtom(h);
	std::string kid = writeAtom(key);
	ValuePtr vp = h->getValue(key);

	// First store the value
	storeValue(sid + ":" + kid, vp);

	// Now, make sure the key-list has the key in it.
	std::string keylist = getKeyList(sid);
	size_t pos = keylist.find(kid);
	if (std::string::npos == pos)
	{
		keylist += kid + " ";
		setKeyList(sid, keylist);
	}
}

// =========================================================

std::string RocksStorage::getKeyList(const std::string& sid)
{
	std::string keylist;
	_rfile->Get(rocksdb::ReadOptions(), sid + "@keys", &keylist);
	return keylist;
}

void RocksStorage::setKeyList(const std::string& sid,
                              const std::string& keylist)
{
	_rfile->Put(rocksdb::WriteOptions(), sid + "@keys", keylist);
}

/// Return the Atom located at sid.
Handle RocksStorage::getAtom(const std::string& sid)
{
	std::string satom;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), sid, &satom);
	if (not s.ok())
		throw IOException(TRACE_INFO, "Internal Error!");

	size_t pos = 0;
	return Sexpr::decode_atom(satom, pos);
}

/// Return the Value located at skid.
ValuePtr RocksStorage::getValue(const std::string& skid)
{
	std::string sval;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), skid, &sval);
	if (not s.ok())
		throw IOException(TRACE_INFO, "Internal Error!");

	size_t pos = 0;
	return Sexpr::decode_value(sval, pos);
}

/// Backend callback
void RocksStorage::loadValue(const Handle& h, const Handle& key)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

/// Backend callback - get the Node
Handle RocksStorage::getNode(Type t, const char * str)
{
	std::string satom =
		"(" + nameserver().getTypeName(t) + " \"" + str + "\")";

	std::string sid;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), satom, &sid);
	if (not s.ok())
		return Handle();

	Handle h = createNode(t, str);

	// Get all of the keys
	std::string keylist = getKeyList(sid);

	std::string cid = sid + ":";
	size_t nsk = 0;
	size_t last = keylist.find(' ');
	while (std::string::npos != last)
	{
		const std::string kid = keylist.substr(nsk, last-nsk);
		Handle key = getAtom(kid);
		ValuePtr vp = getValue(cid + kid);
		h->setValue(key, vp);
		nsk = last + 1;
		last = keylist.find(' ', nsk);
	}

	return h;
}

Handle RocksStorage::getLink(Type t, const HandleSeq& hs)
{
	throw IOException(TRACE_INFO, "Not implemented!");
	return Handle();
}

// =========================================================

void RocksStorage::removeAtom(const Handle& h, bool recursive)
{
	throw IOException(TRACE_INFO, "Not implemented!");
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
