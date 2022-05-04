/*
 * opencog/persist/mono/MonoPersistSCM.h
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

#ifndef _OPENCOG_MONO_PERSIST_SCM_H
#define _OPENCOG_MONO_PERSIST_SCM_H

#include <string>

#include <opencog/atomspace/AtomSpace.h>
#include <opencog/persist/mono/MonoStorage.h>

namespace opencog
{
/** \addtogroup grp_persist
 *  @{
 */

class MonoPersistSCM
{
private:
	static void* init_in_guile(void*);
	static void init_in_module(void*);
	void init(void);

	MonoStorageNodePtr _storage;
	AtomSpace *_as;

public:
	MonoPersistSCM(AtomSpace*);
	~MonoPersistSCM();

	void do_open(const std::string&);
	void do_close(void);
	void do_load(void);
	void do_store(void);

	void do_stats(void);
	void do_clear_stats(void);

	void do_get(const std::string&);
	void do_print(const Handle&, const std::string&);
}; // class

/** @}*/
}  // namespace

extern "C" {
void opencog_persist_rocks_init(void);
};

#endif // _OPENCOG_MONO_PERSIST_SCM_H
