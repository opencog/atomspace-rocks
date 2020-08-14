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
#include <opencog/atomspace/BackingStore.h>

namespace opencog
{
/** \addtogroup grp_persist
 *  @{
 */

class RocksSatisfyingSet;

class RocksStorage : public BackingStore
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

		// Special case (PredicateNode "*-TruthValueKey-*")
		std::string tv_pred_sid;

		// Several operations really need to be exclusive.
		std::mutex _mtx;

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
		void print_all(void);

	public:
		RocksStorage(std::string uri);
		RocksStorage(const RocksStorage&) = delete; // disable copying
		RocksStorage& operator=(const RocksStorage&) = delete; // disable assignment
		virtual ~RocksStorage();
		bool connected(void); // connection to DB is alive

		void kill_data(void); // destroy DB contents

		void registerWith(AtomSpace*);
		void unregisterWith(AtomSpace*);

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

/** @}*/
} // namespace opencog

#endif // _ATOMSPACE_ROCKS_STORAGE_H
