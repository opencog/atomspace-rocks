/*
 * RocksIO.cc
 * Save/restore of individual atoms.
 *
 * Copyright (c) 2020,2022 Linas Vepstas <linas@linas.org>
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

// The old incoming-list needs locks; the new one does not.
#if USE_INLIST_STRING
	#define NEED_LIST_LOCK 1
#endif // USE_INLIST_STRING

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
// ---------------------
// satom == string s-expression for an Atom.
// sval == string s-expression for a Value.
// stype == string name of Atomese Type. e.g. "ConceptNode".
// aid == uint-64 ID. Every Atom gets one.
// sid == aid as ASCII string.
// kid == sid for an Atomese key (keys must always be Atoms)
// fid == sid for an AtomSpace frame.
// skid == sid:kid pair of id's
// shash == 64-bit hash of the Atom (as provided by Atom::get_hash())
//
// Prefixes and associative pairs in the Rocks DB are:
// "a@" sid: . [shash]satom -- finds the satom associated with sid
// "l@" satom . sid -- finds the sid associated with the Link
// "n@" satom . sid -- finds the sid associated with the Node
// "f@" satom . sid -- finds the sid associated with the AtomSpace
// "k@" sid:kid . sval -- find the Atomese Value for the Atom,Key
// "k@" sid:fid:kid . sval -- find the Value for the Atom,AtomSpace,Key
// "i@" sid:stype-sid . (null) -- finds IncomingSet of sid
// "h@" shash . sid-list -- finds all sids having a given hash
//
// General design:
// ---------------
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
// the incoming set of a given type is under `i@sid:stype`.  There
// are two choices for how to store the incoming set: either as a
// long space-separated list of sids, or by encoding each sid into
// it's own key. The former style seems to cause issues when the
// incoming set is large: the update of the large string seems to
// drive RocksDB just crazy, leading to RAM and disk-usage issues.
// See https://github.com/facebook/rocksdb/issues/3216 for more.
//
// The current code will use the space-separated list when
// #define USE_INLIST_STRING 1 is set, otherwise it uses one key
// per incoming.
//
// Multiple AtomSpaces
// -------------------
// Multiple AtomSpaces are used to define "Frames" (Kripke frames).
// These are DAGs of AtomSpaces, one on top another, with Atoms having
// different Values in different Spaces, or simply being absent in some
// but not others.
//
// In this case, the representation is slightly more complex, for the
// expected reasons:
//  * Atoms must be tagged with the AtomSpace that they are in.
//  * Values (identified by atom-key pairs) can be different in
//    different AtomSpaces.
//  * Atoms lower down in a stack can be hidden, when they are deleted
//    higher up in a stack.
//
// Debugging
// ---------
// To view the database contents, use `cog-rocks-get` to fetch a range
// of database keys. For example, (cog-rocks-get "n@(Con") will print
// all of the ConceptNodes stored in the database.
//
// Alpha Conversion
// ----------------
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
//
// ======================================================================
// Some notes about threading and locking.
//
// The current implementation is minimal; it uses one mutex to protect
// the increment and issue of new sid's (new numeric ID's for each atom).
//
// There is another mutex that guarantees that the update of the atom
// plus it's incoming set will be atomic. This was needed in an earlier
// incoming-set design; it's not needed in the current design. It's been
// left in the code, #ifdef'ed out, just in case something blows up.

// ======================================================================

#define CHECK_OPEN \
	if (nullptr == _rfile) \
		throw IOException(TRACE_INFO, "RocksDB is not open! %s", \
			_name.c_str());

// ======================================================================
/// Place Atom into storage.
/// Return the matching sid.
std::string RocksStorage::writeAtom(const Handle& h)
{
	AtomSpace* as = h->getAtomSpace();
	if (_atom_space and as and as != _atom_space)
		writeFrame(as);

	// The issuance of new sids needs to be atomic, as otherwise we
	// risk having the Get(pfx + satom) fail in parallel, and have
	// two different sids issued for the same atom.
	std::unique_lock<std::mutex> lck(_mtx_sid, std::defer_lock);

	std::string shash, sid, satom, pfx;

	// If it's alpha-convertible, then look for equivalents.
	bool convertible = nameserver().isA(h->get_type(), ALPHA_CONVERTIBLE_LINK);
	if (convertible)
	{
		shash = "h@" + aidtostr(h->get_hash());
		lck.lock();
		findAlpha(h, shash, sid);
		if (0 < sid.size()) return sid;
	}

	satom = Sexpr::encode_atom(h);
	pfx = h->is_node() ? "n@" : "l@";

	if (not convertible)
	{
		lck.lock();
		_rfile->Get(rocksdb::ReadOptions(), pfx + satom, &sid);
		if (0 < sid.size()) return sid;
	}

	uint64_t aid = _next_aid.fetch_add(1);
	sid = aidtostr(aid);

	// Update immediately, in case of a future crash or badness...
	// This isn't "really" necessary, because our dtor ~RocksStorage()
	// updates this value. But if someone crashes before our dtor runs,
	// we want to make sure the new bumped value is written, before we
	// start using it in other records.  We want to avoid issueing it
	// twice.
	_rfile->Put(rocksdb::WriteOptions(), aid_key, sid);

	// The rest is safe to do in parallel.
	lck.unlock();

#ifdef NEED_LIST_LOCK
	// The-read-modify-write of the incoming-set list has to be
	// protected from other callers, as well as from the atom
	// deletion code. Delete races are checked with a@ and so the
	// update of a@ and i@ must be atomic.
	std::lock_guard<std::recursive_mutex> lilck(_mtx_list);
#endif

	// logger().debug("Store sid=>>%s<< for >>%s<<", sid.c_str(), satom.c_str());
	_rfile->Put(rocksdb::WriteOptions(), pfx + satom, sid);
	_rfile->Put(rocksdb::WriteOptions(), "a@" + sid + ":", shash+satom);

	if (convertible)
		appendToSidList(shash, sid);

	// If its a Node, we are done.
	if (not h->is_link()) return sid;

	// Recurse downwards
	Type t = h->get_type();
	std::string stype = ":" + nameserver().getTypeName(t);

	// Store the outgoing set ... just in case someone asks for it.
	// The key is in the format `i@sid:type` and the type is used
	// for get-incoming-by-type searches.
	for (const Handle& ho : h->getOutgoingSet())
	{
		std::string ist = "i@" + writeAtom(ho) + stype;
		appendToInset(ist, sid);
	}

	return sid;
}

void RocksStorage::storeAtom(const Handle& h, bool synchronous)
{
	CHECK_OPEN;
	std::string sid = writeAtom(h);

	// Separator for keys
	std::string cid = "k@" + sid + ":";
	if (_multi_space)
		cid += writeFrame(h->getAtomSpace()) + ":";

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
	CHECK_OPEN;
	std::string sid = writeAtom(h);
	if (_multi_space)
		sid += ":" + writeFrame(h->getAtomSpace());
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
	std::string sidlist;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), klist, &sidlist);
	if (not s.ok() or std::string::npos == sidlist.find(sid))
	{
		sidlist += sid + " ";
		_rfile->Put(rocksdb::WriteOptions(), klist, sidlist);
	}
}

// =========================================================

/// Search for the indicated AtomSpace, returning it's sid (string ID).
/// The argument must *always* be an AtomSpacePtr.  If the AtomSpace-sid
/// pairing has not yet been written to storage, it will be; otherwise,
/// the already-existing pairing is returned.
///
/// The issuance of the sid's preserves the partial order of the Frames,
/// so that a smaller sid is always deeper in the DAG, closer to the
/// bottom.  This is a guarantee that can be used when restoring the
/// contents of the DAG, during a bulk load.
std::string RocksStorage::writeFrame(const Handle& hasp)
{
	if (nullptr == hasp) return "0";

	// Keep a map. This will be faster than the string conversion and
	// string lookup. We expect this to be small, no larger than a few
	// thousand entries, and so don't expect it to compete for RAM.
	{
		std::lock_guard<std::mutex> flck(_mtx_frame);
		auto it = _frame_map.find(hasp);
		if (it != _frame_map.end())
			return it->second;
	}

	std::string sframe = Sexpr::encode_frame(hasp);

	// The issuance of new sids needs to be atomic, as otherwise we
	// risk having the Get(pfx + satom) fail in parallel, and have
	// two different sids issued for the same AtomSpace.
	std::unique_lock<std::mutex> lck(_mtx_sid);

	std::string sid;
	_rfile->Get(rocksdb::ReadOptions(), "f@" + sframe, &sid);
	if (0 < sid.size())
	{
		std::lock_guard<std::mutex> flck(_mtx_frame);
		_frame_map.insert({hasp, sid});
		_fid_map.insert({sid, hasp});
		_frame_order.insert({strtoaid(sid), (AtomSpace*) hasp.get()});
		return sid;
	}

	_multi_space = true;

	// Recurse downwards first, if possible.
	if (0 < hasp->get_arity())
	{
		lck.unlock();
		for (const Handle& ho : hasp->getOutgoingSet())
			writeFrame(ho);
		lck.lock();
	}

	uint64_t aid = _next_aid.fetch_add(1);
	sid = aidtostr(aid);

	// Update immediately, in case of a future crash or badness...
	// This isn't "really" necessary, because our dtor ~RocksStorage()
	// updates this value. But if someone crashes before our dtor runs,
	// we want to make sure the new bumped value is written, before we
	// start using it in other records.  We want to avoid issueing it
	// twice.
	_rfile->Put(rocksdb::WriteOptions(), aid_key, sid);

	{
		std::lock_guard<std::mutex> flck(_mtx_frame);
		_frame_map.insert({hasp, sid});
		_fid_map.insert({sid, hasp});
		_frame_order.insert({aid, (AtomSpace*) hasp.get()});
	}

	// The rest is safe to do in parallel.
	lck.unlock();

	// logger().debug("Frame sid=>>%s<< for >>%s<<", sid.c_str(), sframe.c_str());
	_rfile->Put(rocksdb::WriteOptions(), "f@" + sframe, sid);
	_rfile->Put(rocksdb::WriteOptions(), "a@" + sid + ":", sframe);

	return sid;
}

/// Return the AtomSpacePtr corresponding to fid.
Handle RocksStorage::getFrame(const std::string& fid)
{
	{
		std::lock_guard<std::mutex> flck(_mtx_frame);
		auto it = _fid_map.find(fid);
		if (it != _fid_map.end())
			return it->second;
	}

	std::string sframe;
	_rfile->Get(rocksdb::ReadOptions(), "a@" + fid + ":", &sframe);

	// So, this->_atom_space is actually Atom::_atom_space
	// It is safe to dereference fas.get() because fas is
	// pointing to some AtomSpace in the environ of _atom_space.
	Handle asp = HandleCast(_atom_space);
	Handle fas = Sexpr::decode_frame(asp, sframe);
	std::lock_guard<std::mutex> flck(_mtx_frame);
	_frame_map.insert({fas, fid});
	_fid_map.insert({fid, fas});

	_multi_space = true;
	return fas;
}

// =========================================================

/// Return the Atom located at sid.
/// This only gets the Atom, it does NOT get any Values for it.
Handle RocksStorage::getAtom(const std::string& sid)
{
	std::string satom;
	rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(),
		"a@" + sid + ":", &satom);
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
	CHECK_OPEN;
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	std::string kid = findAtom(key);
	if (0 == kid.size()) return;
	std::string fid = ":";
	AtomSpace* as = h->getAtomSpace();
	if (as and _multi_space)
		writeFrame(as);

	ValuePtr vp = getValue("k@" + sid + fid + kid);
// XXX this is adding to wrong atomspace!?
	if (as and vp) vp = as->add_atoms(vp);
	h->setValue(key, vp);
}

/// Get all of the keys for the Atom at `sid`, and attach them to `h`.
/// Place the keys into the AtomSpace.
void RocksStorage::getKeys(AtomSpace* as,
                           const std::string& sid, const Handle& h)
{
	std::string cid = "k@" + sid + ":";
	if (as and _multi_space)
		cid += writeFrame(as) + ":";

	// Iterate over all the keys on the Atom.
	size_t esid = cid.size();
	size_t pos = esid;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(cid); it->Valid() and it->key().starts_with(cid); it->Next())
	{
		const std::string& rks = it->key().ToString();
		Handle key;
		try
		{
			if (_multi_space) pos = rks.rfind(':') + 1;
			key = getAtom(rks.substr(pos));
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
#ifdef NEED_LIST_LOCK
			std::lock_guard<std::recursive_mutex> lck(_mtx_list);
#endif
			_rfile->Delete(rocksdb::WriteOptions(), it->key());
			continue;
		}
// XXX this is adding to wrong atomspace!?
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
// XXX this is adding to wrong atomspace!?
		if (vp) vp = as->add_atoms(vp);

		if (as)
			as->set_value(h, key, vp);
		else
			h->setValue(key, vp);
	}
	delete it;
}

/// Backend callback - get the Atom
void RocksStorage::getAtom(const Handle& h)
{
	CHECK_OPEN;
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	getKeys(h->getAtomSpace(), sid, h);
}

/// Backend callback - find the Link
Handle RocksStorage::getLink(Type t, const HandleSeq& hs)
{
	CHECK_OPEN;
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
	CHECK_OPEN;
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
	CHECK_OPEN;
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
		rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(),
			"a@" + sid + ":", &satom);
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

#ifdef NEED_LIST_LOCK
	// Removal needs to be atomic, and not race with other
	// removals, nor with other manipulations of the incoming
	// set. A plain-old lock is the easiest way to get this.
	std::lock_guard<std::recursive_mutex> lck(_mtx_list);
#endif
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
	remFromInset(ist, sid);
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
		throw NotFoundException(TRACE_INFO, "Internal Error!");

	// Search for the sid in the sidlist. If must be either the
	// very first sid in the list, or it must be preceeded and
	// followed by whitespace. Else we risk finding a substring
	// of some other sid. We don't want substrings!
	std::string sidblank = sid + " ";
	size_t sidlen = sidblank.size();
	size_t pos = sidlist.find(sidblank);
	while (std::string::npos != pos and 0 < pos)
	{
		if (' ' != sidlist[pos-1])
			pos = sidlist.find(sidblank, pos+sidlen);
		else
			break;
	}
	if (std::string::npos == pos)
		throw NotFoundException(TRACE_INFO, "Internal Error!");

	// That's it. Now edit the sidlist string, remove the sid
	// from it, and store it as the new sidlist. Unless its empty...
	sidlist.replace(pos, sidlen, "");
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

#if USE_INLIST_STRING
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(ist); it->Valid() and it->key().starts_with(ist); it->Next())
	{
		// If there is an incoming set, but were are not recursive,
		// then refuse to do anything more.
		if (not recursive)
		{
			delete it;
			return;
		}

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
			_rfile->Get(rocksdb::ReadOptions(), "a@" + isid + ":", &isatom);

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
	delete it;
#else
	size_t istlen = ist.size();
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(ist); it->Valid() and it->key().starts_with(ist); it->Next())
	{
		// If there is an incoming set, but were are not recursive,
		// then refuse to do anything more.
		if (not recursive)
		{
			delete it;
			return;
		}

		// The key is of the form `i@ABC:ConceptNode-456`
		// where `456` is the sid that we want.
		const std::string& frag = it->key().ToString().substr(istlen);
		size_t offset = frag.find('-') + 1;
		const std::string& isid = frag.substr(offset);
		std::string isatom;
		_rfile->Get(rocksdb::ReadOptions(), "a@" + isid + ":", &isatom);

		// Its possible its been already removed. For example,
		// delete a in (Link (Link a b) a)
		if (0 < isatom.size())
			removeSatom(isatom, isid, false, recursive);
	}
	delete it;
#endif

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
			{
				// Two diferent threads may be racing to delete the same
				// atom. If so, the second thread loses and throws a
				// consistency check error. If it lost, we just ignore
				// the error here. Triggered by MultiDeleteUTest.
				try
				{
					remIncoming(sid, stype, osatom);
				}
				catch(const NotFoundException& ex)
				{
					std::string satom;
					rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(),
						"a@" + sid + ":", &satom);
					if (s.ok()) throw;
				}
			}
		}
	}

	// Delete the Atom, next.
	std::string pfx = is_node ? "n@" : "l@";
	_rfile->Delete(rocksdb::WriteOptions(), pfx + satom.substr(paren));
	_rfile->Delete(rocksdb::WriteOptions(), "a@" + sid + ":");

	// Delete all values hanging on the atom ...
	pfx = "k@" + sid + ":";
	it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
	delete it;
}

// =========================================================
// Work with the incoming set

void RocksStorage::appendToInset(const std::string& klist,
                                 const std::string& sid)
{
#if USE_INLIST_STRING
	appendToSidList(klist, sid);
#else
	std::string key = klist + "-" + sid;
	rocksdb::Status s = _rfile->Put(rocksdb::WriteOptions(), key, "");
	if (not s.ok())
		throw IOException(TRACE_INFO, "Internal Error!");
#endif
}

void RocksStorage::remFromInset(const std::string& klist,
                                const std::string& sid)
{
#if USE_INLIST_STRING
	remFromSidList(klist, sid);
#else
	std::string key = klist + "-" + sid;
	rocksdb::Status s = _rfile->Delete(rocksdb::WriteOptions(), key);
	if (not s.ok())
		throw IOException(TRACE_INFO, "Internal Error!");
#endif
}

/// Load the incoming set based on the key prefix `ist`.
void RocksStorage::loadInset(AtomSpace* as, const std::string& ist)
{
#if USE_INLIST_STRING
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
	delete it;
#else

	// `ist` is either `i@ABC:ConceptNode-` or else it is
	// just `i@ABC:` and we have to search for the dash.
	size_t istlen = ist.size();
	size_t offset = -1;
	if ('-' == ist[istlen - 1]) offset = 0;

	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(ist); it->Valid() and it->key().starts_with(ist); it->Next())
	{
		const std::string& frag = it->key().ToString().substr(istlen);

		// The sid is appended to the key.
		if (0 != offset) offset = frag.find('-') + 1;
		const std::string& sid = frag.substr(offset);

		Handle hi = getAtom(sid);
		getKeys(as, sid, hi);
// XXX this is adding to wrong atomspace!?
		as->add_atom(hi);
	}
	delete it;
#endif
}

/// Backing API - get the incoming set.
void RocksStorage::fetchIncomingSet(AtomSpace* as, const Handle& h)
{
	CHECK_OPEN;
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	std::string ist = "i@" + sid + ":";
	loadInset(as, ist);
}

void RocksStorage::fetchIncomingByType(AtomSpace* as, const Handle& h, Type t)
{
	CHECK_OPEN;
	std::string sid = findAtom(h);
	if (0 == sid.size()) return;
	std::string ist = "i@" + sid + ":" + nameserver().getTypeName(t);
	loadInset(as, ist);
}

// =========================================================
// Load and store everything in bulk.

/// Load all the Atoms starting with the prefix.
/// Currently, the `pfx` must be "n@ " for Nodes or "l@" for Links.
void RocksStorage::loadAtoms(AtomSpace* as, const std::string& pfx)
{
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
	{
		Handle h = Sexpr::decode_atom(it->key().ToString().substr(2));
		h = as->storage_add_nocheck(h);
		getKeys(as, it->value().ToString(), h);
	}
	delete it;
}

/// Load only the indicated AtomSpace.
void RocksStorage::loadOneFrame(AtomSpace* table)
{
	// First, load all the nodes ... then the links.
	// XXX TODO - maybe load links depth-order...
	loadAtoms(table, "n@");
	loadAtoms(table, "l@");
}

/// Backing API - load the entire AtomSpace.
void RocksStorage::loadAtomSpace(AtomSpace* table)
{
	CHECK_OPEN;

	if (not _multi_space)
	{
		loadOneFrame(table);
		return;
	}

	// Restore frames, preservingthe partial order, so that the
	// lowest ones are restored first.
	for (const auto& it: _frame_order)
		loadOneFrame(it.second);
}

/// Load the entire collection of AtomSpace frames.
Handle RocksStorage::loadFrameDAG(AtomSpace* base)
{
	CHECK_OPEN;

	if (not _multi_space)
	{
		if (base) return HandleCast(base);
		return Handle::UNDEFINED;
	}

	// Find the smallest and largest frame-id's. Due to the way
	// they are added, the lowest will not have an environ, while
	// the highest will encompase everything.
	size_t fidlo = UINT_MAX;
	size_t fidhi = 0;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek("f@"); it->Valid() and it->key().starts_with("f@"); it->Next())
	{
		size_t id = strtoaid(it->value().ToString());
		if (id < fidlo) fidlo = id;
		if (fidhi < id) fidhi = id;
	}
	delete it;

	// Instantiate the entire frame. The way this is written, it assumes
	// that there is a single top-most frame, and a single bottom-most
	// frame, and that everything else lies between these two. If these
	// assumptions are violated, then things will break.
	std::string sframe;
	std::string fid = aidtostr(fidhi);
	_rfile->Get(rocksdb::ReadOptions(), "a@" + fid + ":", &sframe);
	Handle frm = Sexpr::decode_frame(HandleCast(base), sframe);

	// Loop again, this time to fill up the cache, so that future
	// calls to getFrame() work correctly.
	std::lock_guard<std::mutex> flck(_mtx_frame);
	it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek("f@"); it->Valid() and it->key().starts_with("f@"); it->Next())
	{
		const std::string& fid = it->value().ToString();
		const std::string& sframe = it->key().ToString().substr(2);
		Handle fas = Sexpr::decode_frame(frm, sframe);
		_frame_map.insert({fas, fid});
		_fid_map.insert({fid, fas});
		_frame_order.insert({strtoaid(fid), (AtomSpace*) fas.get()});
	}
	delete it;

	return frm;
}

/// Load the entire collection of AtomSpace frames.
void RocksStorage::storeFrameDAG(AtomSpace* top)
{
	CHECK_OPEN;
	writeFrame(HandleCast(top));
	_multi_space = true;
}

void RocksStorage::loadTypeOneFrame(AtomSpace* as, Type t)
{
	std::string pfx = nameserver().isNode(t) ? "n@(" : "l@(";
	std::string typ = pfx + nameserver().getTypeName(t);

	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(typ); it->Valid() and it->key().starts_with(typ); it->Next())
	{
		Handle h = Sexpr::decode_atom(it->key().ToString().substr(2));
		h = as->storage_add_nocheck(h);
		getKeys(as, it->value().ToString(), h);
	}
	delete it;
}

void RocksStorage::loadType(AtomSpace* as, Type t)
{
	CHECK_OPEN;

	if (not _multi_space)
	{
		loadTypeOneFrame(as, t);
		return;
	}

	// Restore frames, preservingthe partial order, so that the
	// lowest ones are restored first.
	for (const auto& it: _frame_order)
		loadTypeOneFrame(it.second, t);
}

void RocksStorage::storeAtomSpace(const AtomSpace* table)
{
	CHECK_OPEN;
	HandleSeq all_atoms;
	table->get_handles_by_type(all_atoms, ATOM, true);
	for (const Handle& h : all_atoms)
		storeAtom(h);

	// Make sure that the latest atomid has been stored!
	write_aid();
}

/// Kill everything in the database ... everything.
void RocksStorage::kill_data(void)
{
	CHECK_OPEN;
#ifdef HAVE_DELETE_RANGE
	rocksdb::Slice start, end;
	_rfile->DeleteRange(rocksdb::WriteOptions(), start, end);

#else
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(""); it->Valid(); it->Next())
		_rfile->Delete(rocksdb::WriteOptions(), it->key());
	delete it;
#endif

	// Reset.
	_next_aid = 1;
	write_aid();
}

/// Dump database contents to stdout.
void RocksStorage::print_range(const std::string& pfx)
{
	CHECK_OPEN;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
	{
		printf("rkey: >>%s<<    rval: >>%s<<\n",
			it->key().ToString().c_str(), it->value().ToString().c_str());
	}
	delete it;
}

/// Return a count of the number of records with the indicated prefix
size_t RocksStorage::count_records(const std::string& pfx)
{
	CHECK_OPEN;
	size_t cnt = 0;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
		cnt++;

	delete it;
	return cnt;
}

/// Perform some consistency checks
void RocksStorage::checkdb()
{
	CHECK_OPEN;

	// Look for orphaned Values -- Values not attached to any Atom.
	// These are in the form of "k@sid:" which have no matching "a@sid:"
	// Note the use of the colon to terminate te sid!
	std::string pfx = "k@";
	size_t cnt = 0;
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek(pfx); it->Valid() and it->key().starts_with(pfx); it->Next())
	{
		std::string vkey = it->key().ToString();
		vkey[0] = 'a';
		vkey.resize(vkey.find(':') + 1);

		std::string satom;
		rocksdb::Status s = _rfile->Get(rocksdb::ReadOptions(), vkey,  &satom);
		if (not s.ok())
			cnt++;
	}
	delete it;

	if (cnt)
		printf("Error: found %zu orphaned Values!\n", cnt);
	else
		printf("Completed DB consistency check w/o errors\n");
}

// ======================== THE END ======================
