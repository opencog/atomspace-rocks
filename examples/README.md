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
