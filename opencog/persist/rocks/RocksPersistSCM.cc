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
#include <opencog/persist/api/PersistSCM.h>
#include <opencog/persist/api/StorageNode.h>
#include <opencog/guile/SchemePrimitive.h>

#include "RocksStorage.h"
#include "RocksPersistSCM.h"

using namespace opencog;


// =================================================================

RocksPersistSCM::RocksPersistSCM(AtomSpace *as)
{
    _as = as;

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
    _storage = nullptr;
}

void RocksPersistSCM::do_open(const std::string& uri)
{
    if (_storage)
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-open: Error: Already connected to a database!");

    // Unconditionally use the current atomspace, until the next close.
    AtomSpace *as = SchemeSmob::ss_get_env_as("cog-rocks-open");
    if (nullptr != as) _as = as;

    if (nullptr == _as)
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-open: Error: Can't find the atomspace!");

    // Adding the postgres node to the atomspace will fail on read-only
    // atomspaces.
    if (_as->get_read_only())
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-open: Error: AtomSpace is read-only!");

    // Use the RocksDB driver.
    Handle hsn = _as->add_node(ROCKS_STORAGE_NODE, std::string(uri));
    _storage = RocksStorageNodeCast(hsn);
    _storage->open();

    if (!_storage->connected())
    {
        _as->extract_atom(hsn);
        _storage = nullptr;
        throw RuntimeException(TRACE_INFO,
            "cog-rocks-open: Error: Unable to connect to the database");
    }

    PersistSCM::set_connection(_storage);
}

void RocksPersistSCM::do_close(void)
{
    if (nullptr == _storage)
        throw RuntimeException(TRACE_INFO,
             "cog-rocks-close: Error: AtomSpace not connected to database!");

    // The destructor might run for a while before its done; it will
    // be emptying the pending store queues, which might take a while.
    // So unhook the atomspace first -- this will prevent new writes
    // from accidentally being queued. (It will also drain the queues)
    // Only then actually call the dtor.
    _storage->close();
    _as->extract_atom(HandleCast(_storage));
    _storage = nullptr;
}

void RocksPersistSCM::do_stats(void)
{
    if (nullptr == _storage) {
        printf("cog-rocks-stats: AtomSpace not connected to database!\n");
        return;
    }

    printf("cog-rocks-stats: Atomspace holds %lu atoms\n", _as->get_size());
    _storage->print_stats();
}

void RocksPersistSCM::do_clear_stats(void)
{
    if (nullptr == _storage) {
        printf("cog-rocks-stats: AtomSpace not connected to database!\n");
        return;
    }

    _storage->clear_stats();
}

void opencog_persist_rocks_init(void)
{
    static RocksPersistSCM patty(NULL);
}
