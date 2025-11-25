AtomSpace RocksDB Backend Usage Examples
----------------------------------------
Save and restore AtomSpace contents to a RocksDB database. The RocksDB
database is a single-user, local-host-only file-backed database. That
means that only one Atomese process can work with it at any given moment.

In ASCII-art:

```
 +-------------+
 |   Atomese   |
 |   Process   |
 |             |
 +---- API-----+
 |             |
 |   RocksDB   |
 |    files    |
 +-------------+
```

RocksDB is a fast, modern and very popular database. It acheives high
performance through a large variety of techniques; one of these is by
avoiding the complexity of supporting multiple simultaneous users. This
single-user constraint carries over to Atomese processes as well. The
CogServer, and the
[`atomspace-cog`](https://github/opencog/atomspace-cog) facility can be
used to get multi-user access. See the wiki pages for
[StorageNode](https://wiki.opencog.org/w/StorageNode) for more info.

The RocksStorageNode allows you to work with datasets that are too big
to fit in RAM; it also provides long-term off-line storage.

The basic RocksStorage back-end does not try to guess what your working
set is; it is up to you to load, work with and save those Atoms that are
important for you. Some of the
[ProxyNodes](https://wiki.opencog.org/w/ProxyNode) provide more
sophisticated storage management. These are layered on top of existing
StorageNodes, or on top of other ProxyNodes.


The goal of the examples here is to show how to use RocksStorage
directly, to save and restore individual Values, Atoms or entire
AtomSpaces.

Examples, from basic to sophisticated:

* [fetch-store.scm](fetch-store.scm) -- Basic fetch and store of single atoms
* [load-dump.scm](load-dump.scm) -- Loading and saving entire AtomSpaces.

The next demo is more curious. It allows queries to be run so that only
a specific portion of the database is loaded into the AtomSpace. The
query will run correctly, in that it will behave as if the entire
AtomSpace had been loaded into RAM. However, it does not actually
require that everything be loaded; Atoms are fectched from the filestore
in an as-needed basis.  This is currently a bit experimental; the API
is subject to change without notice (and there may be bugs?)

* [query-storage.scm](query-storage.scm) -- Run queries out of the database.

All AtomSpace backends are encapsulated with `StorageNode`s, and can
thus be treated as ordinary Atoms. Among other things, this allows
multiple databases to be simultaneously opened for reading and writing.

* [multiple-databases.scm](multiple-databases.scm) -- Several at once.

AtomSpaces can be stacked, one on top another. Each space in the stack
is called a "frame", and it holds a change-set: all of the Atoms and
Values that changed from the spaces further down in the stack. This
stack (actually, a DAG) can be stored and fetched, just as above.

* [space-frames.scm](space-frames.scm) -- A stack of AtomSpace Frames.
