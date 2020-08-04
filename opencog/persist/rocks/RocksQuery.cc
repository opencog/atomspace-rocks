/*
 * RocksQuery.cc
 * Query the database.
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

#include <time.h>

#include <opencog/atoms/base/Atom.h>
#include <opencog/atoms/base/Node.h>
#include <opencog/atoms/base/Link.h>
#include <opencog/atomspace/AtomSpace.h>
#include <opencog/query/Satisfier.h>
#include <opencog/persist/sexpr/Sexpr.h>

#include "RocksStorage.h"

namespace opencog
{

class RocksSatisfyingSet : public SatisfyingSet
{
		RocksStorage* _store;
	public:
		RocksSatisfyingSet(RocksStorage* sto, AtomSpace* as) :
			SatisfyingSet(as), _store(sto) {}
		virtual ~RocksSatisfyingSet() {}
		virtual IncomingSet get_incoming_set(const Handle&, Type);
};

} // namespace opencog

using namespace opencog;

// XXX TODO ?? Maybe not everything in the incoming set is needed. To
// keep the atomspace slim, we should kill this ... or we should run in
// a temp atomspace ...
IncomingSet RocksSatisfyingSet::get_incoming_set(const Handle& h, Type t)
{
	_store->getIncomingByType(_as, h, t);
	return h->getIncomingSetByType(t, _as);
}

/// Attention: The design of this thing is subject to change.
/// This is the current experimental API.
///
/// The thing I don't like about this is the caching... so, we
/// performed the query straight out of disk starage (with the
/// incoming-set trick above), but then we are wasting CPU cycles
/// writing results back to disk, and maybe the user didn't need
/// that.
///
/// This should be compared to the client-server variant of this,
/// where the caching comes "for free" (because the search result is
/// already on the srever; it would take more effort to send it to the
/// client, delete it from the server, only to have the client turn
/// around and send it back to the server for caching.
///
/// Maybe we need two versions of this: a cached and a non-cached API...
void RocksStorage::runQuery(const Handle& query, const Handle& key,
                            const Handle& meta, bool fresh)
{
	Type qt = query->get_type();
	if (not nameserver().isA(qt, MEET_LINK))
		throw IOException(TRACE_INFO, "Only MeetLink is supported!");

	if (not fresh)
	{
		// Return cached value, by default.
		ValuePtr vp = query->getValue(key);
		if (vp != nullptr) return;

		// Oh no! Go fetch it!
		loadValue(query, key);
		if (meta) loadValue(query, meta);
		barrier();
		ValuePtr lvp = query->getValue(key);
		if (lvp != nullptr) return;
	}

	// Still no luck. Bummer. Perform the query.
	AtomSpace* as = query->getAtomSpace();
	RocksSatisfyingSet sater(this, as);
	sater.satisfy(PatternLinkCast(query));

	QueueValuePtr qv = sater.get_result_queue();
	query->setValue(key, qv);

	// And cache it in the file, as well! This caching is compatible
	// with what `cog-execute-cache!` does. It allows the cached
	// value to be retreived later, without re-performing the search.
	storeValue(query, key);

	// If there's a meta-info key, then attach a timestamp. For now,
	// that's teh only meta info we attach, and we try to be compatible
	// with what the code in `cog-execute-cache!` does. See
	// https://github.com/opencog/atomspace/tree/master/opencog/scm/opencog/exec.scm
   // somewhere around lines 16-50.

	if (nullptr == meta) return;

	time_t now = time(0);
	double dnow = now;
	query->setValue(meta, createFloatValue(dnow));
	storeValue(query, meta);
}
