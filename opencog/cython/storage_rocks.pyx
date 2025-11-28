#
# storage_rocks.pyx
#
# Defines a python module for the RocksDB storage nodes.
# Intended use is for the user to say
#
# from opencog.storage_rocks import *
#
# and that's all. The RocksStorageNode type will then be available.
#

from opencog.atomspace import types, regenerate_types

# Regenerate types so that RocksStorageNode becomes available.
regenerate_types()

# Import add_node for the type constructors below.
from opencog.type_ctors import add_node

# Include the auto-generated type constructors.
include "opencog/persist/rocks-types/persist_rocks_types.pyx"
