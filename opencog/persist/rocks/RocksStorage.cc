/*
 * FILE:
 * opencog/persist/rocks/RocksStorage.cc
 *
 * FUNCTION:
 * Simple CogServer-backed persistent storage.
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <errno.h>

#include "RocksStorage.h"

using namespace opencog;

/* ================================================================ */
// Constructors

void RocksStorage::init(const char * uri)
{
#define URIX_LEN (sizeof("rocks://") - 1)  // Should be 8
	if (strncmp(uri, "rocks://", URIX_LEN))
		throw IOException(TRACE_INFO, "Unknown URI '%s'\n", uri);

	_uri = uri;

	// We expect the URI to be for the form
	//    rocks://path/to/file

#if 0
	std::string host(uri + URIX_LEN);
	size_t slash = host.find_first_of(":/");
	if (std::string::npos != slash)
		host = host.substr(0, slash);
#endif
}

RocksStorage::RocksStorage(std::string uri)
{
	init(uri.c_str());
}

RocksStorage::~RocksStorage()
{
}

bool RocksStorage::connected(void)
{
	return false;
}

/* ================================================================== */
/// Drain the pending store queue. This is a fencing operation; the
/// goal is to make sure that all writes that occurred before the
/// barrier really are performed before before all the writes after
/// the barrier.
///
void RocksStorage::barrier()
{
}

/* ================================================================ */

void RocksStorage::registerWith(AtomSpace* as)
{
	BackingStore::registerWith(as);
}

void RocksStorage::unregisterWith(AtomSpace* as)
{
	BackingStore::unregisterWith(as);
}

/* ================================================================ */

void RocksStorage::clear_stats(void)
{
}

void RocksStorage::print_stats(void)
{
	printf("Connected to %s\n", _uri.c_str());
	printf("no stats yet\n");
}

/* ============================= END OF FILE ================= */
