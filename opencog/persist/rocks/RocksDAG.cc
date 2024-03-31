/*
 * RocksDAG.cc
 * Save/restore of multi-AtomSpace DAG's
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

// =========================================================

/// Convert an AtomSpace to an encoded s-expression string.
/// It will have the form:
///    `(AtomSpace "space name" 42 55 66)`
/// where the numbers are the string sid's of the outgoing set.
std::string RocksStorage::encodeFrame(const Handle& hasp)
{
	// We should say `getTypeName()` as below, expect that today,
	// this will always be `AtomSpace`, 100% of the time. So the
	// fancier type lookup is not needed.
	// std::string txt = "(" + nameserver().getTypeName(hasp->get_type()) + " ";
	std::string txt = "(as ";

	std::stringstream ss;
	ss << std::quoted(hasp->get_name());
	txt += ss.str();

	for (const Handle& ho : hasp->getOutgoingSet())
		txt += " " + writeFrame(ho);

	txt += ")";
	return txt;
}

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

	// std::string sframe = Sexpr::encode_frame(hasp);
	std::string sframe = encodeFrame(hasp);

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
		return sid;
	}

	if (not _multi_space)
		throw IOException(TRACE_INFO,
			"Attempting to store Atoms from multiple AtomSpaces. "
			"Did you forget to say `store-frames` first?");

	// Issue a band-new aid for this frame.
	sid = get_new_aid();
	{
		std::lock_guard<std::mutex> flck(_mtx_frame);
		_frame_map.insert({hasp, sid});
		_fid_map.insert({sid, hasp});
	}

	// The rest is safe to do in parallel.
	lck.unlock();

	// logger().debug("Frame sid=>>%s<< for >>%s<<", sid.c_str(), sframe.c_str());
	_rfile->Put(rocksdb::WriteOptions(), "f@" + sframe, sid);
	_rfile->Put(rocksdb::WriteOptions(), "d@" + sid, sframe);

	return sid;
}

/// Decode the string encoding of the Frame
Handle RocksStorage::decodeFrame(const std::string& senc)
{
	if (0 != senc.compare(0, 5, "(as \""))
		throw IOException(TRACE_INFO, "Internal Error!");

	size_t pos = 4;
	size_t ros = -1;
	std::string name = Sexpr::get_node_name(senc, pos, ros, FRAME);

	pos = ros;
	HandleSeq oset;
	while (' ' == senc[pos])
	{
		pos++;
		ros = senc.find_first_of(" )", pos);
		oset.push_back(getFrame(senc.substr(pos, ros-pos)));
		pos = ros;
	}
	AtomSpacePtr asp = createAtomSpace(oset);
	asp->set_name(name);
	asp->set_copy_on_write();
	return HandleCast(asp);
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
	_rfile->Get(rocksdb::ReadOptions(), "d@" + fid, &sframe);

	// So, this->_atom_space is actually Atom::_atom_space
	// It is safe to dereference fas.get() because fas is
	// pointing to some AtomSpace in the environ of _atom_space.
	// Handle asp = HandleCast(_atom_space);
	// Handle fas = Sexpr::decode_frame(asp, sframe);
	Handle fas = decodeFrame(sframe);
	std::lock_guard<std::mutex> flck(_mtx_frame);
	_frame_map.insert({fas, fid});
	_fid_map.insert({fid, fas});

	return fas;
}

// =========================================================
// DAG API

/// Load the entire collection of AtomSpace frames.
/// The load is done unconditionally, each time this is called.
HandleSeq RocksStorage::loadFrameDAG(void)
{
	CHECK_OPEN;

	// Load all frames.
	auto it = _rfile->NewIterator(rocksdb::ReadOptions());
	for (it->Seek("d@"); it->Valid() and it->key().starts_with("d@"); it->Next())
	{
		const std::string& fid = it->key().ToString().substr(2);
		getFrame(fid);
	}
	delete it;

	// Huh. There weren't any.
	if (0 == _frame_map.size())
		return HandleSeq();

	// Get all spaces that are subspaces
	HandleSet all;
	HandleSet subs;
	for (const auto& pr : _frame_map)
	{
		const Handle& hasp = pr.first;
		all.insert(hasp);
		for (const Handle& ho : hasp->getOutgoingSet())
			subs.insert(ho);
	}

	// The tops of the DAG are all the spaces that are not subspaces.
	HandleSeq tops;
	std::set_difference(all.begin(), all.end(),
	                    subs.begin(), subs.end(),
	                    std::back_inserter(tops));
	return tops;
}

/// Store the entire collection of AtomSpace frames.
void RocksStorage::storeFrameDAG(AtomSpace* top)
{
	CHECK_OPEN;
	if (not _multi_space)
	{
		convertForFrames(HandleCast(top));
		return;
	}

	writeFrame(HandleCast(top));
}

// =========================================================
// General utility

/// Create a total order out of a partial order, such that earlier
/// AtomSpaces *always* appear before later ones.
/// `hasp` is an AtomSpacePtr.
/// `order` is the total order being created.
void RocksStorage::makeOrder(Handle hasp,
                             std::map<uint64_t, Handle>& order)
{
// XXX TODO: we should probably cache the results, instead of
// recomputing every time!?
	// As long as there's a stack of Frames, just loop.
	while (true)
	{
		const auto& pr = _frame_map.find(hasp);
		if (_frame_map.end() == pr)

			// Maybe it's safe to auto-load here, i.e. to call
			// loadFrameDAG() and merge the results. Maybe. But
			// for now, we're going to throw, instead, until the
			// general use-patterns clear up a bit more.
			throw IOException(TRACE_INFO,
				"Cannot use an AtomSpace DAG inconsistent with stored DAG!\n"
				"Did you forget to call `(load-frames)`?");

		order.insert({strtoaid(pr->second), hasp});
		size_t nas = hasp->get_arity();
		if (0 == nas) return;
		if (1 < nas) break;
		hasp = hasp->getOutgoingAtom(0);
	}

	// Recurse if there are more than one.
	for (const Handle& ho: hasp->getOutgoingSet())
		makeOrder(ho, order);
}

// =========================================================
// Debug utility

HandleSeq RocksStorage::topFrames(void)
{
	HandleSeq tops;
	for (const auto& pr : _frame_map)
	{
		const Handle& hasp = pr.first;

		bool found = false;
		for (const Handle& hi : hasp->getIncomingSet())
		{
			if (_frame_map.end() != _frame_map.find(hi))
			{ found = true; break; }
		}
		if (not found) tops.push_back(hasp);
	}
	return tops;
}

// ======================== THE END ======================
