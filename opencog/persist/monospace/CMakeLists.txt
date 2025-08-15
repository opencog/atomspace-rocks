#
# Build the RocksDB driver for a single AtomSpace
#

ADD_LIBRARY (persist-monospace SHARED
	MonoIO.cc
	MonoStorage.cc
	MonoPersistSCM.cc
)

# The atom_types.h file is written to the build directory
TARGET_INCLUDE_DIRECTORIES(persist-monospace PRIVATE ${CMAKE_BINARY_DIR})

TARGET_LINK_LIBRARIES(persist-monospace
	${ATOMSPACE_STORAGE_LIBRARIES}
	${ATOMSPACE_LIBRARIES}
	rocksdb
	persist-rocks-types
)

ADD_DEPENDENCIES(persist-monospace persist_rocks_atom_types)

ADD_GUILE_EXTENSION(SCM_CONFIG persist-monospace
	"opencog-ext-path-persist-mono")

# The EXPORT is need to autogenerate CMake boilerplate in the lib
# directory that lets other packages FIND_PACKAGE(AtomSpaceMonoSpace)
INSTALL (TARGETS persist-monospace
	EXPORT AtomSpaceMonoSpaceTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)

INSTALL (FILES
   MonoStorage.h
   DESTINATION "include/opencog/persist/monospace"
)
