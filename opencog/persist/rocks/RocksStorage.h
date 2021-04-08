/*
 * FILE:
 * opencog/persist/rocks/RocksStorage.h
 *
 * FUNCTION:
 * Simple RocksDB-backed persistent storage.
 *
 * HISTORY:
 * Copyright (c) 2020 Linas Vepstas <linasvepstas@gmail.com>
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

#ifndef _ATOMSPACE_ROCKS_STORAGE_H
#define _ATOMSPACE_ROCKS_STORAGE_H

#include <atomic>
#include <mutex>
#include "rocksdb/db.h"

#include <opencog/atomspace/AtomTable.h>
#include <opencog/persist/api/StorageNode.h>

namespace opencog
{
/** \addtogroup grp_persist
 *  @{
 */

class RocksSatisfyingSet;

class RocksStorage : public StorageNode
{
	friend class RocksImplicator;
	friend class RocksSatisfyingSet;
	friend class RocksJoinCallback;
	private:
		void init(const char *);
		std::string _uri;
		rocksdb::DB* _rfile;

		// unique ID's
		std::atomic_uint64_t _next_aid;
		uint64_t strtoaid(const std::string&) const;
		std::string aidtostr(uint64_t) const;
		void write_aid(void);

		// Special case (PredicateNode "*-TruthValueKey-*")
		std::string tv_pred_sid;

		// Several operations really need to be exclusive.
		std::recursive_mutex _mtx_list;
		std::mutex _mtx_sid;

		// Assorted helper functions
		std::string findAtom(const Handle&);
		std::string writeAtom(const Handle&);
		void appendToSidList(const std::string&, const std::string&);
		void remFromSidList(const std::string&, const std::string&);
		void storeValue(const std::string& skid,
		                const ValuePtr& vp);

		ValuePtr getValue(const std::string&);
		Handle getAtom(const std::string&);
		Handle findAlpha(const Handle&, const std::string&, std::string&);
		void getKeys(AtomSpace*, const std::string&, const Handle&);
		void loadAtoms(AtomTable& table, const std::string& pfx);
		void loadInset(AtomSpace*, const std::string& ist);

		void removeSatom(const std::string&, const std::string&, bool, bool);
		void remIncoming(const std::string&, const std::string&,
		                 const std::string&);

		void getIncomingSet(AtomSpace*, const Handle&);
		void getIncomingByType(AtomSpace*, const Handle&, Type t);
		size_t count_records(const std::string&);

	public:
		RocksStorage(std::string uri);
		RocksStorage(const RocksStorage&) = delete; // disable copying
		RocksStorage& operator=(const RocksStorage&) = delete; // disable assignment
		virtual ~RocksStorage();

		void open(void);
		void close(void);
		bool connected(void); // connection to DB is alive

		void create(void) {}
		void destroy(void) { kill_data(); /* TODO also delete the db */ }
		void erase(void) { kill_data(); }

		void kill_data(void); // destroy DB contents
		void print_range(const std::string&); // Debugging utility

		// AtomStorage interface
		void getAtom(const Handle&);
		Handle getLink(Type, const HandleSeq&);
		void getIncomingSet(AtomTable&, const Handle&);
		void getIncomingByType(AtomTable&, const Handle&, Type t);
		void storeAtom(const Handle&, bool synchronous = false);
		void removeAtom(const Handle&, bool recursive);
		void storeValue(const Handle& atom, const Handle& key);
		void loadValue(const Handle& atom, const Handle& key);
		void loadType(AtomTable&, Type);
		void loadAtomSpace(AtomTable&); // Load entire contents
		void storeAtomSpace(const AtomTable&); // Store entire contents
		void barrier();

		// Debugging and performance monitoring
		void print_stats(void);
		void clear_stats(void); // reset stats counters.
};

class RocksStorageNode : public RocksStorage
{
	public:
		RocksStorageNode(Type t, const std::string&& uri) :
			RocksStorage(std::move(uri))
		{}
		RocksStorageNode(const std::string&& uri) :
			RocksStorage(std::move(uri))
		{}

		void setAtomSpace(AtomSpace* as)
		{
			// This is called with a null pointer when this
			// Atom is extracted from the AtomSpace.
			if (nullptr == as) close();
			Atom::setAtomSpace(as);
		}
		static Handle factory(const Handle&);
};

typedef std::shared_ptr<RocksStorageNode> RocksStorageNodePtr;
static inline RocksStorageNodePtr RocksStorageNodeCast(const Handle& h)
	{ return std::dynamic_pointer_cast<RocksStorageNode>(h); }

#define createRocksStorageNode std::make_shared<RocksStorageNode>

/** @}*/
} // namespace opencog

#endif // _ATOMSPACE_ROCKS_STORAGE_H
