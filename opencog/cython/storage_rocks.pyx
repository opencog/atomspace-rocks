#
# storage_rocks.pyx
#
# Defines a python module for the RocksDB storage nodes.
# There's almost nothing here, just enough to link the C library to
# cython so that user can import. Intended use is for the user to say
#
# from opencog.storage_rocks import *
#
# and that's all. The RocksStorageNode type will then be available.
#

from opencog.atomspace import types, regenerate_types

# Regenerate types so that RocksStorageNode becomes available.
regenerate_types()
