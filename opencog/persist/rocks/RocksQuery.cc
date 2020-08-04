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

#include <opencog/atoms/base/Atom.h>
#include <opencog/atoms/base/Node.h>
#include <opencog/atoms/base/Link.h>
#include <opencog/atomspace/AtomSpace.h>
#include <opencog/query/Satisfier.h>
#include <opencog/persist/sexpr/Sexpr.h>

#include "RocksStorage.h"

using namespace opencog;

class RocksSatisfyingSet : public SatisfyingSet
{
	public:
		RocksSatisfyingSet(AtomSpace* as) : SatisfyingSet(as) {}
		virtual ~RocksSatisfyingSet() {}
		virtual IncomingSet get_incoming_set(const Handle&, Type);
};

IncomingSet RocksSatisfyingSet::get_incoming_set(const Handle& h, Type t)
{
	// _store->getIncomingByType(_as, h, t);
printf("need the inco of %s\n", h->to_string().c_str());
	return h->getIncomingSetByType(t, _as);
}

void RocksStorage::runQuery(const Handle& query, const Handle& key,
                            const Handle& meta, bool fresh)
{
	Type qt = query->get_type();
	if (not nameserver().isA(qt, MEET_LINK))
		throw IOException(TRACE_INFO, "Only MeetLink is supported!");

	AtomSpace* as = query->getAtomSpace();
	RocksSatisfyingSet sater(as);
	sater.satisfy(PatternLinkCast(query));

	QueueValuePtr qv = sater.get_result_queue();

printf("yoo got %s\n", qv->to_string().c_str());
}
