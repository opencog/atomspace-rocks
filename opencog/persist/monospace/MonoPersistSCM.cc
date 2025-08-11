/*
 * opencog/persist/mono/MonoPersistSCM.cc
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

#include "MonoStorage.h"
#include "MonoPersistSCM.h"

using namespace opencog;


// =================================================================

MonoPersistSCM::MonoPersistSCM(AtomSpace *as)
{
    if (as)
        _as = AtomSpaceCast(as->shared_from_this());

    static bool is_init = false;
    if (is_init) return;
    is_init = true;
    scm_with_guile(init_in_guile, this);
}

void* MonoPersistSCM::init_in_guile(void* self)
{
    scm_c_define_module("opencog persist-mono", init_in_module, self);
    scm_c_use_module("opencog persist-mono");
    return NULL;
}

void MonoPersistSCM::init_in_module(void* data)
{
   MonoPersistSCM* self = (MonoPersistSCM*) data;
   self->init();
}

void MonoPersistSCM::init(void)
{
    define_scheme_primitive("cog-mono-open", &MonoPersistSCM::do_open, this, "persist-mono");
    define_scheme_primitive("cog-mono-close", &MonoPersistSCM::do_close, this, "persist-mono");
    define_scheme_primitive("cog-mono-stats", &MonoPersistSCM::do_stats, this, "persist-mono");
    define_scheme_primitive("cog-mono-clear-stats", &MonoPersistSCM::do_clear_stats, this, "persist-mono");
    define_scheme_primitive("cog-mono-get", &MonoPersistSCM::do_get, this, "persist-mono");
    define_scheme_primitive("cog-mono-print", &MonoPersistSCM::do_print, this, "persist-mono");
}

MonoPersistSCM::~MonoPersistSCM()
{
    _storage = nullptr;
}

void MonoPersistSCM::do_open(const std::string& uri)
{
    if (_storage)
        throw RuntimeException(TRACE_INFO,
             "cog-mono-open: Error: Already connected to a database!");

    // Unconditionally use the current atomspace, until the next close.
    AtomSpacePtr as = SchemeSmob::ss_get_env_as("cog-mono-open");
    if (nullptr != as) _as = as;

    if (nullptr == _as)
        throw RuntimeException(TRACE_INFO,
             "cog-mono-open: Error: Can't find the atomspace!");

    // Adding the MonoStorageNode to the atomspace will fail on
    // read-only atomspaces.
    if (_as->get_read_only())
        throw RuntimeException(TRACE_INFO,
             "cog-mono-open: Error: AtomSpace is read-only!");

    // Use the RocksDB driver.
    Handle hsn = _as->add_node(MONO_STORAGE_NODE, std::string(uri));
    _storage = MonoStorageNodeCast(hsn);
    _storage->open();

    if (!_storage->connected())
    {
        _as->extract_atom(hsn);
        _storage = nullptr;
        throw RuntimeException(TRACE_INFO,
            "cog-mono-open: Error: Unable to connect to the database");
    }
}

void MonoPersistSCM::do_close(void)
{
    if (nullptr == _storage)
        throw RuntimeException(TRACE_INFO,
             "cog-mono-close: Error: AtomSpace not connected to database!");

    // The destructor might run for a while before its done; it will
    // be emptying the pending store queues, which might take a while.
    // So unhook the atomspace first -- this will prevent new writes
    // from accidentally being queued. (It will also drain the queues)
    // Only then actually call the dtor.
    _storage->close();
    _as->extract_atom(HandleCast(_storage));
    _storage = nullptr;
}

void MonoPersistSCM::do_get(const std::string& prefix)
{
    if (nullptr == _storage) {
        printf("cog-mono-get: AtomSpace not connected to database!\n");
        return;
    }
    _storage->print_range(prefix);
}

#define GET_SNP(FUN) \
	MonoStorageNodePtr snp = MonoStorageNodeCast(h); \
	if (nullptr == snp) \
		throw RuntimeException(TRACE_INFO, FUN ": Not a MonoStorageNode!\n");

void MonoPersistSCM::do_stats(const Handle& h)
{
	GET_SNP("cog-mono-stats")
	snp->print_stats();
}

void MonoPersistSCM::do_clear_stats(const Handle& h)
{
	GET_SNP("cog-mono-clear-stats")
	snp->clear_stats();
}

void MonoPersistSCM::do_print(const Handle& h, const std::string& prefix)
{
	GET_SNP("cog-mono-print")
	snp->print_range(prefix);
}

void opencog_persist_mono_init(void)
{
	static MonoPersistSCM patty(nullptr);
}
