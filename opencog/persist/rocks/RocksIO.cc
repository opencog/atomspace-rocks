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

// prefixes and associative pairs in the Rocks DB are:
// "a@" sid . satom -- finds the satom associated with sid
// "l@" satom . sid -- finds the sid associated with the Link
// "n@" satom . sid -- finds the sid associated with the Node
// "k@" sid:kid . sval -- find the value for the Atom,Key
// "i@" sid:stype . sid-list -- finds incoming set of sid

/// Place Atom into storage.
/// Return the matching sid.
std::string RocksStorage::writeAtom(const Handle& h)
{
	std::string satom = Sexpr::encode_atom(h);
	std::string pfx = h->is_node() ? "n@" : "l@";

	std::string sid;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
	if (not s.ok())
	{
		uint64_t aid = _next_aid.fetch_add(1);
		sid = aidtostr(aid);

		if (h->is_link())
		{
			Type t = h->get_type();

			// Store the outgoing set .. just in case someone asks for it.
			for (const Handle& ho : h->getOutgoingSet())
			{
				std::string soid = writeAtom(ho);
				updateInset(soid, t, sid);
			}
		}
		_rfile->Put(rocksdb::WriteOptions(), pfx + satom, sid);
		_rfile->Put(rocksdb::WriteOptions(), "a@" + sid, satom);
	}

	// logger().debug("Store sid= >>%s<< for >>%s<<", sid.c_str(), satom.c_str());
printf("Store sid= >>%s<< for >>%s<<\n", sid.c_str(), satom.c_str());
	return sid;
}

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	std::string sid = writeAtom(h);

	// Separator for keys
	std::string cid = "k@" + sid + ":";

	// Store all the keys on the atom ...
	for (const Handle& key : h->getKeys())
		storeValue(cid + writeAtom(key), h->getValue(key));
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
	storeValue("k@" + sid + ":" + kid, vp);
}

/// Add `sid` to the incoming set of `soid`.
/// That is, `sid` is a Link that contains `soid`.
/// The Type of `sid` should be `t` (and it should always be a Link).
void RocksStorage::updateInset(const std::string& soid, Type t,
                               const std::string& sid)
{
	std::string ist = "i@" + soid + ":" + nameserver().getTypeName(t);

	// XXX TODO This update needs to be atomic!!
	std::string inlist;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), ist, &inlist);
	if (not s.ok() or std::string::npos == inlist.find(sid))
	{
		inlist += sid + " ";
		_rfile->Put(rocksdb::WriteOptions(), ist, inlist);
	}
}

// =========================================================

/// Return the Atom located at sid.
Handle RocksStorage::getAtom(const std::string& sid)
{
	std::string satom;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), "a@" + sid, &satom);
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

/// Get all of the keys
void RocksStorage::getKeys(const std::string& sid, const Handle& h)
{
	std::string cid = "k@" + sid + ":";
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());

	// Iterate over all the keys on the Atom.
	size_t pos = cid.size();
	for (it->Seek(cid); it->Valid() and it->key().starts_with(cid); it->Next())
	{
		Handle key = getAtom(it->key().ToString().substr(pos));

		size_t junk = 0;
		ValuePtr vp = Sexpr::decode_value(it->value().ToString(), junk);
		h->setValue(key, vp);
	}
}

/// Backend callback - get the Node
Handle RocksStorage::getNode(Type t, const char * str)
{
	std::string satom =
		"n@(" + nameserver().getTypeName(t) + " \"" + str + "\")";

	std::string sid;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), satom, &sid);
	if (not s.ok())
		return Handle();

	Handle h = createNode(t, str);
	getKeys(sid, h);

	return h;
}

Handle RocksStorage::getLink(Type t, const HandleSeq& hs)
{
	std::string satom =
		"l@(" + nameserver().getTypeName(t) + " ";

	for (const Handle& h : hs)
		satom += Sexpr::encode_atom(h);

	satom += ")";

	std::string sid;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), satom, &sid);
	if (not s.ok())
		return Handle();

	Handle h = createLink(hs, t);
	getKeys(sid, h);

	return h;
}

// =========================================================

/// Find the sid of Atom. Return empty string if its not there.
std::string RocksStorage::findAtom(const Handle& h)
{
	std::string satom = Sexpr::encode_atom(h);
	std::string pfx = h->is_node() ? "n@" : "l@";

	std::string sid;
	_rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
	return sid;
}

void RocksStorage::removeAtom(const Handle& h, bool recursive)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

/// Backing API - get the incoming set.
void RocksStorage::getIncomingSet(AtomTable& table, const Handle& h)
{
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;

	std::string ist = "i@" + sid + ":";

	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(ist); it->Valid() and it->key().starts_with(ist); it->Next())
	{
		// The list of sids of incoming Atoms.
		std::string inlist = it->value().ToString();

		size_t nsk = 0;
		size_t last = inlist.find(' ');
		while (std::string::npos != last)
		{
			const std::string sid = inlist.substr(nsk, last-nsk);

printf("duuuude %s has inco >>%s<<\n", h->to_string().c_str(),
sid.c_str());
			// table.add(h);
			nsk = last + 1;
			last = inlist.find(' ', nsk);
		}
	}
}

void RocksStorage::getIncomingByType(AtomTable& table, const Handle& h, Type t)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}

/// Load all the Atoms starting with the prefix.
/// Currently, the prfix must be "n@ " for Nodes or "l@" for Links.
void RocksStorage::loadAtoms(AtomTable &table, const std::string& pfx)
{
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
	{
		Handle h = Sexpr::decode_atom(it->key().ToString().substr(2));
		getKeys(it->value().ToString(), h);
		table.add(h);
	}
}

/// Backing API - load the entire AtomSpace.
void RocksStorage::loadAtomSpace(AtomTable &table)
{
	// First, load all the nodes ... then the links.
	// XXX TODO - maybe load links depth-order...
	loadAtoms(table, "n@");
	loadAtoms(table, "l@");
}

void RocksStorage::loadType(AtomTable &table, Type t)
{
	std::string pfx = nameserver().isNode(t) ? "n@(" : "l@(";
	std::string typ = pfx + nameserver().getTypeName(t);

	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(typ); it->Valid() and it->key().starts_with(typ); it->Next())
	{
		Handle h = Sexpr::decode_atom(it->key().ToString().substr(2));
		getKeys(it->value().ToString(), h);
		table.add(h);
	}
}

void RocksStorage::storeAtomSpace(const AtomTable &table)
{
	HandleSet all_atoms;
	table.getHandleSetByType(all_atoms, ATOM, true);
	for (const Handle& h : all_atoms)
		storeAtom(h);
}

/// Kill everything in the database ... everything.
void RocksStorage::kill_data(void)
{
#ifdef HAVE_DELETE_RANGE
	rocksdb::Slice start, end;
	_rfile->DeleteRange(rocksdb::WriteOptions(), start, end);

#else
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(""); it->Valid(); it->Next())
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
#endif
}

void RocksStorage::runQuery(const Handle& query, const Handle& key,
                                const Handle& meta, bool fresh)
{
	throw IOException(TRACE_INFO, "Not implemented!");
}
