AtomSpace RocksDB Backend
=========================
[![CircleCI](https://circleci.com/gh/opencog/atomspace-rocks.svg?style=svg)](https://circleci.com/gh/opencog/atomspace-rocks)

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

RocksDB (see https://rocksdb.org/) is an "embeddable persistent key-value
store for fast storage." The goal of layering the AtomSpace on top of it
is to provide fast persistent storage for the AtomSpace.  There are
several advantages to doing this:

* RocksDB is file-based, and so it is straight-forward to make backup
  copies of datasets, as well as to share these copies with others.
  (You don't need to be a DB Admin to do this!)
* RocksDB runs locally, and so the overhead of pushing bytes through
  the network is eliminated. The remaining inefficiencies/bottlenecks
  have to do with converting between the AtomSpace's natural in-RAM
  format, and the position-independent format that all databases need.
  (Here, we say "position-independent" in that the DB format does not
  contain any C/C++ pointers; all references are managed with local
  unique ID's.)
* RocksDB is a "real" database, and so enables the storage of datasets
  that might not otherwise fit into RAM. This back-end does not try
  to guess what your working set is; it is up to you to load, work with
  and save those Atoms that are important for you. The [examples](examples)
  demonstrate exactly how that can be done.

This backend, together with the CogServer-based
[network AtomSpace](https://github.com/opencog/atomspace-cog)
backend provides a building-block out of which more complex
distributed and/or decentralized AtomSpaces can be built.


Status
------
This is **Version 0.9.3**.  All unit tests pass.  This is effectively
version 1.0; waiting on user feedback.


Example Usage
-------------
Well, see the examples directory for details. But, in brief:

```
$ guile
scheme@(guile-user)> (use-modules (opencog))
scheme@(guile-user)> (use-modules (opencog persist))
scheme@(guile-user)> (use-modules (opencog persist-rocks))
scheme@(guile-user)> (cog-rocks-open "rocks:///tmp/foo.rdb/")
scheme@(guile-user)> (load-atomspace)
```

That's it! You've loaded the entire contents of `foo.rdb` into the
AtomSpace!  Of course, loading everything is not generally desirable,
especially when the file is huge and RAM space is tight.  More granular
load and store is possible; see the [examples directory](examples) for
details.

Design
------
This is a minimalistic implementation. There has been no performance
tuning. There's only just enough code to make everything work; that's
it. This does nothing at all fancy/sophisticated with RocksDB, and it
might be possible to improve performance and squeeze out some air.
