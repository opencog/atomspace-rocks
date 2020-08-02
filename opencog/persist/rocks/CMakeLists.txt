#
# Build the RocksDB driver for the AtomSpace
#

ADD_LIBRARY (persist-rocks SHARED
   RocksStorage
   RocksPersistSCM
)

TARGET_LINK_LIBRARIES(persist-rocks
   ${ATOMSPACE_LIBRARIES}
)

ADD_GUILE_EXTENSION(SCM_CONFIG persist-rocks
   "opencog-ext-path-persist-rocks")

INSTALL (TARGETS persist-rocks EXPORT AtomSpaceTargets
   DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)

