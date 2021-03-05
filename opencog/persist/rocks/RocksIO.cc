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

// Prefixes and associative pairs in the Rocks DB are:
// "a@" sid . [shash]satom -- finds the satom associated with sid
// "l@" satom . sid -- finds the sid associated with the Link
// "n@" satom . sid -- finds the sid associated with the Node
// "k@" sid:kid . sval -- find the Atomese Value for the Atom,Key
// "i@" sid:stype . sid-list -- finds IncomingSet of sid
// "h@" shash . sid-list -- finds all sids having a given hash

// General design:
// The basic representation for an Atom is its s-expression.
// Because this is verbose, each s-expression is associated with a
// unique integer, the "aid" or "atom id". Since Rocks works with
// strings, the aid is converted to a base-62 string, the "sid".
// Base-62 is used because its fairly compact but still leaves
// punctuation symbols free for other uses.
//
// The main lookups involve converting s-expressions aka "satoms"
// to sids, and back again. This is done with the `a@`, `n@` and `l@`
// prefixes. These are "prefixes" because RocksDB stores keys in
// lexical order, so one can quickly find all keys starting with `n@`,
// which is useful for rapid load of entire AtomSpaces. Similarly,
// all ConceptNodes will have the prefix `n@(Concept` and likewise
// can be rapidly traversed by RocksDB.
//
// Value lookups (e.g. TruthValue) is also handled with this prefix
// trick, so that, for example, all Values on a given Atom will be
// next to each-other in the Rocks DB, because all of them will appear
// next to each-other, in order, under the prefix `k@sid:`. If only
// one value is needed, it can be found at `k@sid:key`.
//
// The same trick is applied for incoming-sets. So, the entire
// incoming set for an atom appears under the prefix `i@sid:` and
// the incoming set of a given type is under `i@sid:stype`.  The
// incoming set itself is stored as a space-separated list of sids.
// This works, but has the (minor!?) disadvantage that this list has
// to be edited every time an atom is added or removed.
//
// That's pretty much it ... except that there's one last little tricky
// bit, forced on us by alpha-equivalence and alpha-conversion.
//
// Two different atoms will *always* have different s-expressions.
// The converse is not true: two different s-expressions might be
// alpha-equivalent. For example,
//    (Lambda (Variable "X") (Concept "A"))
// and
//    (Lambda (Variable "Y") (Concept "A"))
// are alpha-equivalent. The problem here is that Rocks might be
// holding the first satom, while the user is asking for the second,
// and we have to find the first, whenever the user asks for the second.
// This is handled by using the Atom hashes.  The C++ method
// `Atom::get_hash()` will *always* return the same hash for two alpha-
// equivalent atoms. Unfortunately, there might be hash collisions:
// two different atoms can have the same hash. These are disambiguated
// with the `h@` prefix, which holds a list of sids with the same hash.
// When the user asks for an alpha-convertible atom, then, if we have
// it, it is guaranteed to show up in this list. We just have to walk
// the list, and find the one that is alpha-convertible. This works
// well, because the `Atom::get_hash()` method generates relatively few
// hash collisions; the list will almost always have only one entry in
// it (or it will be empty, if we don't hold a convertible atom).
// That solves the alpha-convertible lookup problem. Like dominoes,
// however, this creates a problem with Atom deletion. This is solved
// by pre-pending the satom string with the hash, whenever the hash is
// being used. At this time, hashes are used only to track the alpha-
// convertible atoms. Although every atom has a hash, we don't need it
// for the "ordinary" case, and so don't use it.

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
	std::string sid;
	if (convertible)
	{
		shash = "h@" + aidtostr(h->get_hash());
		findAlpha(h, shash, sid);
		if (0 < sid.size()) return sid;
	}

	std::string satom = Sexpr::encode_atom(h);
	std::string pfx = h->is_node() ? "n@" : "l@";

	if (not convertible)
	{
		_rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
		if (0 < sid.size()) return sid;
	}

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
			appendToSidList(ist, sid);
		}
	}

	// logger().debug("Store sid=>>%s<< for >>%s<<", sid.c_str(), satom.c_str());
	_rfile->Put(rocksdb::WriteOptions(), pfx + satom, sid);
	_rfile->Put(rocksdb::WriteOptions(), "a@" + sid, shash+satom);

	if (not convertible) return sid;

	appendToSidList(shash, sid);

	return sid;
}

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	std::string sid = writeAtom(h);

	// Separator for keys
	std::string cid = "k@" + sid + ":";

	// Always clobber the TV, set it back to default.
	// The below will revise as needed.
	_rfile->Delete(rocksdb::WriteOptions(), cid + tv_pred_sid);

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
void RocksStorage::appendToSidList(const std::string& klist,
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

	size_t pos = satom.find('('); // skip over hash, if present
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
		Handle key;
		try
		{
			key = getAtom(it->key().ToString().substr(pos));
		}
		catch (const IOException& ex)
		{
			// If the user deleted the key-Atom from storage, then
			// the above getAtom() will fail. Ignore the failure,
			// and instead just cleanup the key storage.
			//
			// (Design comments: its easiest to do it like this,
			// because doing it any other way would require
			// tracking keys. Which is hard; the atomspace was
			// designed to NOT track keys on purpose, for efficiency.)
			std::lock_guard<std::mutex> lck(_mtx);
			_rfile->Delete(rocksdb::WriteOptions(), it->key());
			continue;
		}
		if (as) key = as->add_atom(key);

		// read-only Atomspaces will refuse insertion of keys.
		// However, we have to special-case the truth values.
		// Mostly because (PredicateNode "*-TruthValueKey-*")
		// is not in the AtomSpace. Argh! That's an old design flaw.
		if (nullptr == key)
		{
			if (0 == tv_pred_sid.compare(it->key().ToString().substr(pos)))
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
	// If it's alpha-convertible, then look for equivalents.
	bool convertible = nameserver().isA(t, ALPHA_CONVERTIBLE_LINK);
	if (convertible)
	{
		Handle h = createLink(hs, t);
		std::string shash = "h@" + aidtostr(h->get_hash());
		std::string sid;
		h = findAlpha(h, shash, sid);
		if (nullptr == h) return h;
		getKeys(nullptr, sid, h);
		return h;
	}

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
	bool convertible = nameserver().isA(h->get_type(), ALPHA_CONVERTIBLE_LINK);
	std::string sid;
	std::string satom;
	std::string shash;
	if (convertible)
	{
		shash = "h@" + aidtostr(h->get_hash());
		findAlpha(h, shash, sid);
		if (0 == sid.size()) return;

		// Get the matching satom string.
		rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), "a@" + sid, &satom);
		if (not s.ok())
			throw IOException(TRACE_INFO, "Internal Error!");
	}
	else
	{
		satom = Sexpr::encode_atom(h);
		std::string pfx = h->is_node() ? "n@" : "l@";

		_rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
		// We don't know this atom. Give up.
		if (0 == sid.size()) return;
	}

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
	// Skip over leading hash, if needed.
	size_t paren = osatom.find('(');
	const std::string& sotype = osatom.substr(paren+1, osatom.find(' ', paren) - 1);
	Type ot = nameserver().getType(sotype);
	std::string opf = nameserver().isNode(ot) ? "n@" : "l@";

	// Get the matching osid
	std::string osid;
	_rfile->Get(rocksdb::ReadOptions(), opf + osatom.substr(paren), &osid);

	// Get the incoming set. Since we have the type, we can get this
	// directly, without needing any loops.
	std::string ist = "i@" + osid + ":" + stype;
	remFromSidList(ist, sid);
}

/// Remove `sid` from the list of sids stored at `klist`.
/// Write out the revised `klist` or just delete `klist` if
/// the result is empty.
void RocksStorage::remFromSidList(const std::string& klist,
                                  const std::string& sid)
{
	std::string sidlist;
	_rfile->Get(rocksdb::ReadOptions(), klist, &sidlist);

	// Some consistency checks ...
	if (0 == sidlist.size())
		throw IOException(TRACE_INFO, "Internal Error!");

	size_t pos = sidlist.find(sid);
	if (std::string::npos == pos)
		throw IOException(TRACE_INFO, "Internal Error!");

	// That's it. Now edit the sidlist string, remove the sid
	// from it, and store it as the new sidlist. Unless its empty...
	sidlist.replace(pos, sid.size() + 1, "");
	if (0 == sidlist.size())
		_rfile->Delete(rocksdb::WriteOptions(), klist);
	else
		_rfile->Put(rocksdb::WriteOptions(), klist, sidlist);
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
	std::string ist = "i@" + sid + ":";
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

			// Its possible its been already removed. For example,
			// delete a in (Link (Link a b) a)
			if (0 < isatom.size())
				removeSatom(isatom, isid, false, recursive);

			nsk = last + 1;
			last = inset.find(' ', nsk);
		}

		// Finally, delete the inset itself.
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
	}

	// If the atom to be deleted has a hash, we need to remove it
	// (the atom) from the list of other atoms having the same hash.
	// (from the hash-bucket.)
	size_t paren = satom.find('(');
	if (0 < paren)
	{
		const std::string& shash = satom.substr(0, paren);
		remFromSidList(shash, sid);
	}

	// If the atom to be deleted is a link, we need to loop over
	// it's outgoing set, and patch up the incoming sets of those
	// atoms.
	if (not is_node)
	{
		size_t pos = satom.find(' ', paren);
		if (std::string::npos != pos)
		{
			// stype is the string-type of the Link.
			const std::string& stype = satom.substr(paren+1, pos-paren-1);

			// Loop over the outgoing set of `satom`.
			// Deduplicate the set by using std::set<>
			std::set<std::string> soset;
			size_t l = pos;
			size_t e = satom.size() - 1;
			while (l < e)
			{
				size_t r = e;
				int pcnt = Sexpr::get_next_expr(satom, l, r, 0);
				if (0 < pcnt or l == r) break;
				r++;

				// osatom is an atom in the outgoing set of satom
				soset.insert(satom.substr(l, r-l));

				l = r;
			}

			// Perform the deduplicated delete.
			for (const std::string& osatom : soset)
				remIncoming(sid, stype, osatom);
		}
	}

	// Delete the Atom, next.
	std::string pfx = is_node ? "n@" : "l@";
	_rfile->Delete(rocksdb::WriteOptions(), pfx + satom.substr(paren));
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
/// Currently, the `pfx` must be "n@ " for Nodes or "l@" for Links.
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

	// Make sure that the latest atomid has been stored!
	write_aid();
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

	// Reset.
	_next_aid = 1;
	write_aid();
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

/// Return a count of the number of records with the indicated prefix
size_t RocksStorage::count_records(const std::string& pfx)
{
	size_t cnt = 0;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
		cnt++;

	return cnt;
}

// ======================== THE END ======================
