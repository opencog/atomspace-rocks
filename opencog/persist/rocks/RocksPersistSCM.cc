/*
 * opencog/persist/cog-simple/RocksPersistSCM.cc
 * Scheme Guile API wrappers for the backend.
 *
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

#include <libguile.h>

#include <opencog/atomspace/AtomSpace.h>
#include <opencog/atomspace/BackingStore.h>
#include <opencog/guile/SchemePrimitive.h>

#include "RocksStorage.h"
#include "RocksPersistSCM.h"

using namespace opencog;


// =================================================================

RocksPersistSCM::RocksPersistSCM(AtomSpace *as)
{
    _as = as;
    _backing = nullptr;

    static bool is_init = false;
    if (is_init) return;
    is_init = true;
    scm_with_guile(init_in_guile, this);
}

void* RocksPersistSCM::init_in_guile(void* self)
{
    scm_c_define_module("opencog persist-rocks", init_in_module, self);
    scm_c_use_module("opencog persist-rocks");
    return NULL;
}

void RocksPersistSCM::init_in_module(void* data)
{
   RocksPersistSCM* self = (RocksPersistSCM*) data;
   self->init();
}

void RocksPersistSCM::init(void)
{
    define_scheme_primitive("cog-rocks-open", &RocksPersistSCM::do_open, this, "persist-rocks");
    define_scheme_primitive("cog-rocks-close", &RocksPersistSCM::do_close, this, "persist-rocks");
    define_scheme_primitive("cog-rocks-stats", &RocksPersistSCM::do_stats, this, "persist-rocks");
    define_scheme_primitive("cog-rocks-clear-stats", &RocksPersistSCM::do_clear_stats, this, "persist-rocks");
}

RocksPersistSCM::~RocksPersistSCM()
{
    if (_backing) delete _backing;
}

void RocksPersistSCM::do_open(const std::string& uri)
{
    if (_backing)
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-open: Error: Already connected to a database!");

    // Unconditionally use the current atomspace, until the next close.
    AtomSpace *as = SchemeSmob::ss_get_env_as("cog-rocks-open");
    if (nullptr != as) _as = as;

    if (nullptr == _as)
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-open: Error: Can't find the atomspace!");

    // Allow only one connection at a time.
    if (_as->isAttachedToBackingStore())
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-open: Error: Atomspace connected to another storage backend!");
    // Use the RocksDB driver.
    RocksStorage *store = new RocksStorage(uri);
    if (!store)
        throw RuntimeException(TRACE_INFO,
            "cog-rocks-open: Error: Unable to open the database");

    if (!store->connected())
    {
        delete store;
        throw RuntimeException(TRACE_INFO,
            "cog-rocks-open: Error: Unable to connect to the database");
    }

    _backing = store;
    _backing->registerWith(_as);
}

void RocksPersistSCM::do_close(void)
{
    if (nullptr == _backing)
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-close: Error: AtomSpace not connected to database!");

    RocksStorage *backing = _backing;
    _backing = nullptr;

    // The destructor might run for a while before its done; it will
    // be emptying the pending store queues, which might take a while.
    // So unhook the atomspace first -- this will prevent new writes
    // from accidentally being queued. (It will also drain the queues)
    // Only then actually call the dtor.
    backing->unregisterWith(_as);
    delete backing;
}

void RocksPersistSCM::do_stats(void)
{
    if (nullptr == _backing) {
        printf("cog-rocks-stats: AtomSpace not connected to database!\n");
        return;
    }

    printf("cog-rocks-stats: Atomspace holds %lu atoms\n", _as->get_size());
    _backing->print_stats();
}

void RocksPersistSCM::do_clear_stats(void)
{
    if (nullptr == _backing) {
        printf("cog-rocks-stats: AtomSpace not connected to database!\n");
        return;
    }

    _backing->clear_stats();
}

void opencog_persist_cog_simple_init(void)
{
    static RocksPersistSCM patty(NULL);
}
