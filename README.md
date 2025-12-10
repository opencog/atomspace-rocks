AtomSpace RocksDB StorageNode
=============================
[![CircleCI](https://circleci.com/gh/opencog/atomspace-rocks.svg?style=svg)](https://circleci.com/gh/opencog/atomspace-rocks)

Save and restore [AtomSpace](https://github.com/opencog/atomspace)
contents as well as individual Atoms to a
[RocksDB](https://rocksdb.org) database. The RocksDB database is a
high-performance, zero-configuration, single-user, local-host-only
file-backed database. It provides top-notch read and write performance,
which is the #1 reason you should e interested in using it. But please
note: only one running AtomSpace executable can connect to it at any
given moment. Multi-user, networked AtomSpaces are provided by the
[AtomSpace-Cog](https://github.com/opencog/atomspace-cog) `StorageNode`
driver.

In ASCII-art:

```
 +---------------------+
 |                     |
 |      AtomSpace      |
 |                     |
 +-- StorageNode API --+
 |                     |
 |  RocksStorageNode   |
 |                     |
 +---------------------+
 |       RocksDB       |
 +---------------------+
 |     filesystem      |
 +---------------------+
```
Each box is a shared library. Library calls go downwards. The
[StorageNode API](https://wiki.opencog.org/w/StorageNode) is the same
for **all** `StorageNode`s; the `RocksStorageNode` is just one of them.

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
This is ***Version 1.6.0***.  All unit tests pass.  It has been used in
at least one major project, to process tens of millions of Atoms.

The list of changes since January 2024 is long and fairly boring;
mostly bug fixes and patches forced by updates to the core AtomSpace.
The following changes are notable:

* The `*-delete-*` message only deletes Atoms from the on-disk
  AtomSpace DB.  Deleting from the local (in-RAM) AtomSpace must now
  be performed as a distinct step.
* Atoms that are used as keys or messages cannot be deleted.
* The Python API has been fixed so it actually works. It uses the new
  message-passing system.
* The base `StorageNode` (provided by
  [atomspace-storage](https://github.com/opencog/atomspace-storage))
  now uses a message-passing system to perform all actions. Typical
  messages include `*-open-*`, `*-close-*`, `*-load-atom-*`,
  `*-store-atom-*` and so on. The same base set is supported by all
  `StorageNode`s (and `ProxyNode`s), not just atomspace-rocks.
  See the wiki pages for
  [StorageNode](https://wiki.opencog.org/w/StorageNode) and
  [ObjectNode](https://wiki.opencog.org/w/ObjectNode).


Building and Installing
-----------------------
RocksDB is a prerequisite. On Debian/Ubuntu, `apt install librocks-dev`

The build and install of `atomspace-rocks` follows the same pattern as
other AtomSpace projects. Prerequisites include the AtomSpace itself
(from https://github.com/opencog/atomspace) and the generic StorageNode
API (from https://github.com/opencog/atomspace-storage).

All Atomese projects, including this one, use the same build, install
and test pattern:
```
    cd to project dir atomspace-rocks
    git pull
    mkdir build
    cd build
    cmake ..
    make -j
    sudo make install
    make -j check check ARGS=-j
```

Example Usage
-------------
See the examples directory for details. In brief:

```
$ guile
scheme@(guile-user)> (use-modules (opencog))
scheme@(guile-user)> (use-modules (opencog persist))
scheme@(guile-user)> (use-modules (opencog persist-rocks))
scheme@(guile-user)> (define sto (RocksStorageNode "rocks:///tmp/foo.rdb/"))
scheme@(guile-user)> (cog-open sto)
scheme@(guile-user)> (load-atomspace)
scheme@(guile-user)> (cog-close sto)
```

That's it! You've loaded the entire contents of `foo.rdb` into the
AtomSpace!  Of course, loading everything is not generally desirable,
especially when the file is huge and RAM space is tight.  More granular
load and store is possible; see the [examples directory](examples) for
details.

Contents
--------
There are two implementations in this repo: a simple one, suitable for
users who use only a single AtomSpace, and a sophisticated one, intended
for sophisticated users who need to work with complex DAG's of
AtomSpaces. These two are accessed by using either `MonoStorageNode`
or by using `RocksStorageNode`. Both use the standard
[`StorageNode`](https://wiki.opencog.org/w/StorageNode) API.

The implementation of `MonoStorageNode` is smaller and simpler, and is
the easier of the two to understand.

The implementation of `RocksStorageNode` provides full support for deep
stacks (DAG's) of AtomSpaces, layered one on top another (called
"Frames", a name meant to suggest "Kripke Frames" and "stackframes").
An individual "frame" can be thought of as a change-set, a collection of
deltas to the next frame further down in the DAG. A frame inheriting
from multiple AtomSpaces contains the set-union of Atoms in the
contributing AtomSpaces. Atoms and Values can added, changed and removed
in each changeset, without affecting Atoms and Values in deeper frames.

Design
------
This is a minimalistic implementation. There has been no performance
tuning. There's only just enough code to make everything work; that's
it. This does nothing at all fancy/sophisticated with RocksDB, and it
might be possible to improve performance and squeeze out some air.
However, the code is not sloppy, so it might be hard to make it go
faster.

If you are creating a new StorageNode to some other kind of database,
using the code here as a starting point would make an excellent design
choice.  All the hard problems have been solved, and yet the overall
design remains fairly simple.  All you'd need to do is to replace all
of the references to RocksDB to your favorite, desired DB.
