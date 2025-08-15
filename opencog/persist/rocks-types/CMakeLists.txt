# Generate the atom types
OPENCOG_GEN_CXX_ATOMTYPES(atom_types.script
	atom_types.h
	atom_types.definitions
	atom_types.inheritance)

OPENCOG_GEN_SCM_ATOMTYPES(atom_types.script persist_rocks_types.scm)
OPENCOG_GEN_PYTHON_ATOMTYPES(atom_types.script persist_rocks_types.pyx)

ADD_CUSTOM_TARGET(persist_rocks_atom_types
	DEPENDS atom_types.h persist_rocks_types.scm persist_rocks_types.pyx)

# Build the shared library
ADD_LIBRARY (persist-rocks-types SHARED
	atom_types_init.cc
)

# The atom_types.h file is written to the build directory
TARGET_INCLUDE_DIRECTORIES(persist-rocks-types PRIVATE ${CMAKE_BINARY_DIR})

TARGET_LINK_LIBRARIES(persist-rocks-types
	${ATOMSPACE_STORAGE_LIBRARIES}
	${ATOMSPACE_LIBRARIES}
)

ADD_DEPENDENCIES(persist-rocks-types persist_rocks_atom_types)

# Install targets
INSTALL (TARGETS persist-rocks-types EXPORT AtomSpaceRocksTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)

INSTALL (FILES
	${CMAKE_CURRENT_BINARY_DIR}/atom_types.h
	DESTINATION "include/opencog/persist/rocks-types"
)

ADD_GUILE_MODULE (FILES
	${CMAKE_CURRENT_BINARY_DIR}/persist_rocks_types.scm
	MODULE_DESTINATION "${GUILE_SITE_DIR}/opencog/persist/rocks-types"
	DEPENDS persist_rocks_atom_types
)

ADD_GUILE_EXTENSION(SCM_CONFIG persist-rocks-types "opencog-ext-path-persist-rocks-types")