#
# Build the RocksDB driver for a single AtomSpace
#

ADD_LIBRARY (persist-monospace SHARED
	MonoIO
	MonoStorage
	MonoPersistSCM
)

TARGET_LINK_LIBRARIES(persist-monospace
	${ATOMSPACE_LIBRARIES}
	rocksdb
)

ADD_GUILE_EXTENSION(SCM_CONFIG persist-mono
	"opencog-ext-path-persist-mono")

# The EXPORT is neeed to autogenerate CMake boilerplate in the lib
# directory that lets other packages FIND_PACKAGE(AtomSpaceMonoSpace)
INSTALL (TARGETS persist-monospace
	EXPORT AtomSpaceMonoSpaceTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)
