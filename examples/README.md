AtomSpace RocksDB Backend Usage Examples
----------------------------------------
Save and restore AtomSpace contents to a RocksDB database. The RocksDB
database is a single-user, local-host-only file-backed database. That
means that only one AtomSpace can connect to it at any given moment.

In ASCII-art:

```
 +-------------+
 |  AtomSpace  |
 |             |
 +---- API-----+
 |             |
 |   RocksDB   |
 |    files    |
 +-------------+
```

RocksDB is a "real" database, and so datasets too big to fit into RAM
can be stored in it.  This back-end does not try to guess what your
working set is; it is up to you to load, work with and save those Atoms
that are important for you. The goal of the examples is to show exactly
how to do this. These are:

* [fetch-store.scm](fetch-store.scm) -- Basic fetch and store of single atoms
* [load-dump.scm](load-dump.scm) -- Loading and saving entire AtomSpaces.

The next demo is more curious. It allows queries to be run so that only
a specific portion of the database is loaded into the AtomSpace. The
query will run correctly, in that it will behave as if the entire
AtomSpace had been loaded into RAM. However, it does not actually
require that everything be loaded; Atoms are fectched from the filestore
in an as-needed basis.  This is currently a bit experimental; the API
is subject to change without notice, and there may be bugs.

* [query-storage.scm](query-storage.scm) -- Run queries out of the database.
