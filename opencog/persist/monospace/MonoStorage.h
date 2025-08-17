/*
 * FILE:
 * opencog/persist/monospace/MonoStorage.h
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

#ifndef _ATOMSPACE_MONO_STORAGE_H
#define _ATOMSPACE_MONO_STORAGE_H

#include <atomic>
#include <mutex>
#include "rocksdb/db.h"

#include <opencog/persist/api/StorageNode.h>
#include <opencog/persist/rocks-types/atom_types.h>

namespace opencog
{
/** \addtogroup grp_persist
 *  @{
 */

class MonoSatisfyingSet;

class MonoStorage : public StorageNode
{
	friend class MonoImplicator;
	friend class MonoSatisfyingSet;
	friend class MonoJoinCallback;
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

		// Issue of sid needs to be atomic.
		std::mutex _mtx_sid;

#ifdef NEED_LIST_LOCK
		// Guarantee atomic update of atom plus it's incoming set.
		std::recursive_mutex _mtx_list;
#endif

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
		void loadAtoms(AtomSpace*, const std::string& pfx);
		void loadInset(AtomSpace*, const std::string& ist);
		void appendToInset(const std::string&, const std::string&);
		void remFromInset(const std::string&, const std::string&);

		void removeSatom(const std::string&, const std::string&, bool, bool);
		void remIncoming(const std::string&, const std::string&,
		                 const std::string&);

		size_t count_records(const std::string&);

	public:
		MonoStorage(std::string uri);
		MonoStorage(const MonoStorage&) = delete; // disable copying
		MonoStorage& operator=(const MonoStorage&) = delete; // disable assignment
		virtual ~MonoStorage();

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
		void fetchIncomingSet(AtomSpace*, const Handle&);
		void fetchIncomingByType(AtomSpace*, const Handle&, Type t);
		void storeAtom(const Handle&, bool synchronous = false);
		void removeAtom(AtomSpace*, const Handle&, bool recursive);
		void storeValue(const Handle& atom, const Handle& key);
		void updateValue(const Handle&, const Handle&, const ValuePtr&);
		void loadValue(const Handle& atom, const Handle& key);
		void loadType(AtomSpace*, Type);
		void loadAtomSpace(AtomSpace*); // Load entire contents
		void storeAtomSpace(const AtomSpace*); // Store entire contents
		void barrier();
		std::string monitor();

		// Debugging and performance monitoring
		void print_stats(void);
		void clear_stats(void); // reset stats counters.
		void checkdb(void);
};

class MonoStorageNode : public MonoStorage
{
	public:
		MonoStorageNode(Type t, const std::string&& uri) :
			MonoStorage(std::move(uri))
		{}
		MonoStorageNode(const std::string&& uri) :
			MonoStorage(std::move(uri))
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

NODE_PTR_DECL(MonoStorageNode)
#define createMonoStorageNode CREATE_DECL(MonoStorageNode)

/** @}*/
} // namespace opencog

#endif // _ATOMSPACE_MONO_STORAGE_H
