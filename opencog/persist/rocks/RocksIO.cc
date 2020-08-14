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
		else if (c < 36) c += 'A' - 10;
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

static const char* aid_key = "*-NextUnusedAID-*";

// ======================================================================
// Common abbreviations:
// satom == string s-expression for an Atom.
// sval == string s-expression for a Value.
// stype == string name of Atomese Type. e.g. "ConceptNode".
// aid == uint-64 ID. Every Atom gets one.
// sid == aid as ASCII string.
// kid == sid for an Atomese key (i.e. an Atom)
// skid == sid:kid pair of id's
// shash == 64-bit hash of the Atom (as provided by Atom::get_hash())

// prefixes and associative pairs in the Rocks DB are:
// "a@" sid . satom -- finds the satom associated with sid
// "l@" satom . sid -- finds the sid associated with the Link
// "n@" satom . sid -- finds the sid associated with the Node
// "k@" sid:kid . sval -- find the Atomese Value for the Atom,Key
// "i@" sid:stype . sid-list -- finds IncomingSet of sid
// "h@" shash . sid-list -- finds all sids having a given hash

// ======================================================================
// Some notes about threading and locking.
//
// The current implementation is minimalist, and uses only one mutex
// to ensure the safety of the one obviously-racey section, where
// multiple threads might be editing the IncomingSet of the same
// Atom.  (We use only one lock to protect *all* incoming sets.)
//
// Note that, even without this lock, the current multi-threading
// test i.e. MultiPersistUTest passes just fine. Maybe the test is
// too short, or too small, or doesn't do anything dangerous...
//
// Besides the above, there may be other racey usages that are not
// anticipated. For example, if one thread is getting the same Atom
// that another thread is deleting, it might be possible to arrive at
// some weird state, possibly with a crash(??) or a malfunctioning
// get(??). This code has NOT been audited for this situation.
// The degree of safety here for production usage is unknown.
// (That's why it's version 0.8 right now, as of 4 August 2020.)
// The good news: this file is really pretty small, as such things go,
// so auditing should not be that hard.

// ======================================================================
/// Place Atom into storage.
/// Return the matching sid.
std::string RocksStorage::writeAtom(const Handle& h)
{
	// If it's alpha-convertible, then look for equivalents.
	bool convertible = nameserver().isA(h->get_type(), ALPHA_CONVERTIBLE_LINK);
	std::string shash;
	if (convertible)
	{
		shash = "h@" + aidtostr(h->get_hash());
		std::string sid;
		Handle ha = findAlpha(h, shash, sid);
		if (ha) return sid;
	}

	std::string satom = Sexpr::encode_atom(h);
	std::string pfx = h->is_node() ? "n@" : "l@";

	std::string sid;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
	if (s.ok()) return sid;

	uint64_t aid = _next_aid.fetch_add(1);
	sid = aidtostr(aid);

	// Update immediately, in case of a future crash or something...
	// Notes: (1) this isn't "really" necessary, because the dtor
	// updates this value. But we want to update anyway, just in case
	// someone crashes before the dtor. (2) this is racey, in that
	// other threads may already have a newer aid than us (and so
	// we are clobbering a newer aid with an older one). But the
	// raciness doesn't matter because (3) next time someone writes
	// an atom, or if the dtor runs, then the correct aid will be
	// stored. So ... if no one crashes, then everything is OK. If
	// someone crashes, then this is racey.
	_rfile->Put(rocksdb::WriteOptions(), aid_key, sid);

	if (h->is_link())
	{
		Type t = h->get_type();
		std::string stype = ":" + nameserver().getTypeName(t);

		// Store the outgoing set ... just in case someone asks for it.
		// The key is in the format `i@sid:type` and the type is used
		// for get-incoming-by-type searches.
		for (const Handle& ho : h->getOutgoingSet())
		{
			std::string ist = "i@" + writeAtom(ho) + stype;
			updateSidList(ist, sid);
		}
	}

	// logger().debug("Store sid=>>%s<< for >>%s<<", sid.c_str(), satom.c_str());
	_rfile->Put(rocksdb::WriteOptions(), pfx + satom, sid);
	_rfile->Put(rocksdb::WriteOptions(), "a@" + sid, satom);

	if (not convertible) return sid;

	updateSidList(shash, sid);

	return sid;
}

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	std::string sid = writeAtom(h);

	// Separator for keys
	std::string cid = "k@" + sid + ":";

	// Always clobber the TV, set it back to default.
	// The below will revise as needed.
	_rfile->Delete(rocksdb::WriteOptions(), "k@" + sid + tv_pred_sid);

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

/// Append to incoming set.
/// Add `sid` to the list of other sids stored at key `klist`.
void RocksStorage::updateSidList(const std::string& klist,
                                 const std::string& sid)
{
	// The-read-modify-write of the list has to be protected
	// from other callers, as well as from the deletion code.
	std::lock_guard<std::mutex> lck(_mtx);

	std::string sidlist;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), klist, &sidlist);
	if (not s.ok() or std::string::npos == sidlist.find(sid))
	{
		sidlist += sid + " ";
		_rfile->Put(rocksdb::WriteOptions(), klist, sidlist);
	}
}

// =========================================================

/// Return the Atom located at sid.
/// This only gets the Atom, it does NOT get any Values for it.
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
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	std::string kid = findAtom(key);
	if (0 == kid.size()) return;
	ValuePtr vp = getValue("k@" + sid + ":" + kid);
	AtomSpace* as = h->getAtomSpace();
	if (as and vp) vp = as->add_atoms(vp);
	h->setValue(key, vp);
}

/// Get all of the keys for the Atom at `sid`, and attach them to `h`.
/// Place the keys into the AtomSpace.
void RocksStorage::getKeys(AtomSpace* as,
                           const std::string& sid, const Handle& h)
{
	std::string cid = "k@" + sid + ":";
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());

	// Iterate over all the keys on the Atom.
	size_t pos = cid.size();
	for (it->Seek(cid); it->Valid() and it->key().starts_with(cid); it->Next())
	{
		Handle key = getAtom(it->key().ToString().substr(pos));
		if (as) key = as->add_atom(key);

		// read-only Atomspaces will refuse insertion of keys.
		// However, we have to special-case the truth values.
		// Mostly because (PredicateNode "*-TruthValueKey-*")
		// is not in the AtomSpace. Argh! That's an old design flaw.
		if (nullptr == key)
		{
			if (0 == tv_pred_sid.compare(1, tv_pred_sid.size(),
				it->key().ToString().substr(pos)))
			{
				size_t junk = 0;
				ValuePtr vp = Sexpr::decode_value(it->value().ToString(), junk);
				h->setTruthValue(TruthValueCast(vp));
			}
			continue;
		}

		size_t junk = 0;
		ValuePtr vp = Sexpr::decode_value(it->value().ToString(), junk);
		if (vp) vp = as->add_atoms(vp);
		h->setValue(key, vp);
	}
}

/// Backend callback - get the Atom
void RocksStorage::getAtom(const Handle& h)
{
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	getKeys(h->getAtomSpace(), sid, h);
}

/// Backend callback - find the Link
Handle RocksStorage::getLink(Type t, const HandleSeq& hs)
{
	std::string satom = "l@(" + nameserver().getTypeName(t) + " ";
	for (const Handle& ho: hs)
		satom += Sexpr::encode_atom(ho);
	satom += ")";

	std::string sid;
	_rfile->Get(rocksdb::ReadOptions(), satom, &sid);
	if (0 == sid.size()) return Handle::UNDEFINED;

	Handle h = createLink(hs, t);
	getKeys(nullptr, sid, h);
	return h;
}

// =========================================================

/// Find the sid of Atom. Return empty string if its not there.
std::string RocksStorage::findAtom(const Handle& h)
{
	// If it's alpha-convertible, maybe we already know about
	// an alpha-equivalent form...
	if (nameserver().isA(h->get_type(), ALPHA_CONVERTIBLE_LINK))
	{
		std::string shash = "h@" + aidtostr(h->get_hash());
		std::string sid;
		findAlpha(h, shash, sid);
		return sid;
	}

	std::string satom = Sexpr::encode_atom(h);
	std::string pfx = h->is_node() ? "n@" : "l@";

	std::string sid;
	_rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
	return sid;
}

/// If an Atom is an ALPHA_CONVERTIBLE_LINK, then we have to look
/// for it's hash, and figure out if we already know it in a different
/// but alpha-equivalent form. Return the sid of that form, if found.
Handle RocksStorage::findAlpha(const Handle& h, const std::string& shash,
                               std::string& sid)
{
	// Get a list of all atoms with the same hash...
	std::string alfali;
	_rfile->Get(rocksdb::ReadOptions(), shash, &alfali);
	if (0 == alfali.size()) return Handle::UNDEFINED;

	// Loop over these atoms...
	size_t nsk = 0;
	size_t last = alfali.find(' ');
	while (std::string::npos != last)
	{
		const std::string& cid = alfali.substr(nsk, last-nsk);
		Handle ha = getAtom(cid);

		// If content compares, then we got it.
		if (*ha == *h) { sid = cid; return ha; }
	}

	return Handle::UNDEFINED;
}

// =========================================================
// Remove-related stuff...

void RocksStorage::removeAtom(const Handle& h, bool recursive)
{
#ifdef HAVE_DELETE_RANGE
	rocksdb::Slice start, end;
	_rfile->DeleteRange(rocksdb::WriteOptions(), start, end);

#endif
	// Are we even holding the Atom to be deleted?
	std::string satom = Sexpr::encode_atom(h);
	std::string pfx = h->is_node() ? "n@" : "l@";

	std::string sid;
	_rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);

	// We don't know this atom. Give up.
	if (0 == sid.size()) return;

	// Removal needs to be atomic, and not race with other
	// removals, nor with other manipulations of the incoming
	// set. A plain-old lock is the easiest way to get this.
	std::lock_guard<std::mutex> lck(_mtx);
	removeSatom(satom, sid, h->is_node(), recursive);
}

/// Remove `sid` from the incoming set of `osatom`.
/// Assumes that `sid` references an Atom that has `osatom`
/// in it's outgoing set.   Assumes that `stype` is the type
/// of `sid`.
void RocksStorage::remIncoming(const std::string& sid,
                               const std::string& stype,
                               const std::string& osatom)
{
	// Oh bother. Is it a Node, or a Link?
	const std::string& sotype = osatom.substr(1, osatom.find(' ') - 1);
	Type ot = nameserver().getType(sotype);
	std::string opf = nameserver().isNode(ot) ? "n@" : "l@";

	// Get the matching osid
	std::string osid;
	_rfile->Get(rocksdb::ReadOptions(), opf + osatom, &osid);

	// Get the incoming set. Since we have the type, we can get this
	// directly, without needing any loops.
	std::string ist = "i@" + osid + ":" + stype;
	std::string inlist;
	_rfile->Get(rocksdb::ReadOptions(), ist, &inlist);

	// Some consistency checks ...
	if (0 == inlist.size())
		throw IOException(TRACE_INFO, "Internal Error!");

	size_t pos = inlist.find(sid);
	if (std::string::npos == pos)
		throw IOException(TRACE_INFO, "Internal Error!");

	// That's it. Now edit the inlist string, remove the sid
	// from it, and store it as the new inlist. Unless its empty...
	inlist.replace(pos, sid.size() + 1, "");
	if (0 == inlist.size())
		_rfile->Delete(rocksdb::WriteOptions(), ist);
	else
		_rfile->Put(rocksdb::WriteOptions(), ist, inlist);
}

/// Remove the given Atom from the database.
/// The Atom is encoded both as `satom` (the s-expression)
/// and also as `sid` (the matching Atom ID).
/// The flag `is_node` should be true, if the Atom is a Node.
/// The flag `recursive` should be set to perform recursive deletes.
void RocksStorage::removeSatom(const std::string& satom,
                               const std::string& sid,
                               bool is_node,
                               bool recursive)
{
	// So first, iterate up to the top, chopping away the incoming set.
	// It's stored with prefixes according to type, so this is a loop...
	std::string ist = "i@" + sid;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(ist); it->Valid() and it->key().starts_with(ist); it->Next())
	{
		// If there is an incoming set, but were are not recursive,
		// then refuse to do anything more.
		if (not recursive) return;

		// The list of sids of incoming Atoms.
		std::string inset = it->value().ToString();

		// Loop over the incoming set.
		size_t nsk = 0;
		size_t last = inset.find(' ');
		while (std::string::npos != last)
		{
			// isid is the sid of an atom in the incoming set.
			// Get the matching atom.
			const std::string& isid = inset.substr(nsk, last-nsk);
			std::string isatom;
			_rfile->Get(rocksdb::ReadOptions(), "a@" + isid, &isatom);

			removeSatom(isatom, isid, false, recursive);

			nsk = last + 1;
			last = inset.find(' ', nsk);
		}

		// Finally, delete the inset itself.
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
	}

	// If the atom to be deleted is a link, we need to loop over
	// it's outgoing set, and patch up the incoming sets of those
	// atoms.
	if (not is_node)
	{
		size_t pos = satom.find(' ');
		if (std::string::npos != pos)
		{
			// style is the type of the Link.
			const std::string& stype = satom.substr(1, pos-1);

			// Loop over the outgoing set of `satom`.
			size_t l = pos;
			size_t e = satom.size() - 1;
			while (l < e)
			{
				size_t r = e;
				int pcnt = Sexpr::get_next_expr(satom, l, r, 0);
				if (0 < pcnt or l == r) break;
				r++;

				// osatom is an atom in the outgoing set of satom
				const std::string& osatom = satom.substr(l, r-l);
				remIncoming(sid, stype, osatom);

				l = r;
			}
		}
	}

	// Delete the Atom, next.
	std::string pfx = is_node ? "n@" : "l@";
	_rfile->Delete(rocksdb::WriteOptions(), pfx + satom);
	_rfile->Delete(rocksdb::WriteOptions(), "a@" + sid);

	// Delete all values hanging on the atom ...
	pfx = "k@" + sid;
	it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
}

// =========================================================
// Work with the incoming set

/// Load the incoming set based on the key prefix `ist`.
void RocksStorage::loadInset(AtomSpace* as, const std::string& ist)
{
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(ist); it->Valid() and it->key().starts_with(ist); it->Next())
	{
		// The list of sids of incoming Atoms.
		std::string inlist = it->value().ToString();

		size_t nsk = 0;
		size_t last = inlist.find(' ');
		while (std::string::npos != last)
		{
			const std::string& sid = inlist.substr(nsk, last-nsk);

			Handle hi = getAtom(sid);
			getKeys(as, sid, hi);
			as->add_atom(hi);
			nsk = last + 1;
			last = inlist.find(' ', nsk);
		}
	}
}

/// Backing API - get the incoming set.
void RocksStorage::getIncomingSet(AtomSpace* as, const Handle& h)
{
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	std::string ist = "i@" + sid + ":";
	loadInset(as, ist);
}

void RocksStorage::getIncomingByType(AtomSpace* as, const Handle& h, Type t)
{
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	std::string ist = "i@" + sid + ":" + nameserver().getTypeName(t);
	loadInset(as, ist);
}

void RocksStorage::getIncomingSet(AtomTable& table, const Handle& h)
{
	getIncomingSet(table.getAtomSpace(), h);
}

void RocksStorage::getIncomingByType(AtomTable& table, const Handle& h, Type t)
{
	getIncomingByType(table.getAtomSpace(), h, t);
}

// =========================================================
// Load and store everything in bulk.

/// Load all the Atoms starting with the prefix.
/// Currently, the prfix must be "n@ " for Nodes or "l@" for Links.
void RocksStorage::loadAtoms(AtomTable &table, const std::string& pfx)
{
	AtomSpace* as = table.getAtomSpace();

	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
	{
		Handle h = Sexpr::decode_atom(it->key().ToString().substr(2));
		getKeys(as, it->value().ToString(), h);
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
	AtomSpace* as = table.getAtomSpace();

	std::string pfx = nameserver().isNode(t) ? "n@(" : "l@(";
	std::string typ = pfx + nameserver().getTypeName(t);

	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(typ); it->Valid() and it->key().starts_with(typ); it->Next())
	{
		Handle h = Sexpr::decode_atom(it->key().ToString().substr(2));
		getKeys(as, it->value().ToString(), h);
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

	// Reset. Will be stored on close.
	_next_aid = 1;
}

/// Dump database contents to stdout.
void RocksStorage::print_all(void)
{
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(""); it->Valid(); it->Next())
	{
		printf("rkey: >>%s<<    rval: >>%s<<\n",
			it->key().ToString().c_str(), it->value().ToString().c_str());
	}
}

// ======================== THE END ======================
