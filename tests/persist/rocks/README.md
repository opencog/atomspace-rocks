Unit tests
----------
All of the tests here are a port of those found in

https://github.com/opencog/atomspace-cog/tree/master/tests/persist/cog-storage

which in turn were ported from

https://github.com/opencog/atomspace/tree/master/tests/persist/sql

and so they should all be testing the same things in the same ways, more
or less.  The only exception is that this one does not have a 
`MultiUserUTest.cxxtest` because it is a singleton backend.
(It doesn't run over the network, there is no way for more than
one user to connect to it. RocksDB itself ensures that there is
only one active use at a time.)
