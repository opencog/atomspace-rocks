#
# Master AtomSpace RocksDB Backend CMake file.
#
# General organization:
# -- check for different compilers, OS'es
# -- search for various required & optional libraries/tools
# -- decide what to build based on above results.
# -- configure various config files.
# -- print pretty summary
#

# cogutils already requires 3.12, so may as well ask for that.
CMAKE_MINIMUM_REQUIRED(VERSION 3.12)
IF (COMMAND CMAKE_POLICY)
	# These must be explicitly set, as otherwise warnings are printed.
	CMAKE_POLICY(SET CMP0003 NEW)
	CMAKE_POLICY(SET CMP0037 NEW)
	CMAKE_POLICY(SET CMP0045 NEW)
ENDIF (COMMAND CMAKE_POLICY)

# Python venv seems to need this.
IF(CMAKE_VERSION VERSION_GREATER 3.31)
	CMAKE_POLICY(SET CMP0177 NEW)
ENDIF(CMAKE_VERSION VERSION_GREATER 3.31)

PROJECT(atomspace-rocks VERSION 1.6.0)

# ----------------------------------------------------------
# User-modifiable options. Feel free to change these!
#
# Uncomment to be in Release mode [default].
# SET(CMAKE_BUILD_TYPE Release)

# Uncomment to build in debug mode.
# SET(CMAKE_BUILD_TYPE Debug)

# Uncomment to be in coverage testing mode.
# SET(CMAKE_BUILD_TYPE Coverage)

# Uncomment to build in profile mode.
# SET(CMAKE_BUILD_TYPE Profile)

# Uncomment to build in release mode with debug information.
# SET(CMAKE_BUILD_TYPE RelWithDebInfo)

# default build type
IF (CMAKE_BUILD_TYPE STREQUAL "")
	SET(CMAKE_BUILD_TYPE Release)
ENDIF (CMAKE_BUILD_TYPE STREQUAL "")

MESSAGE(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

ADD_DEFINITIONS(-DPROJECT_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
                -DPROJECT_BINARY_DIR="${CMAKE_BINARY_DIR}")

# ===============================================================
# Check for existence of various required, optional packages.
# Listed in alphabetical order, more or less.
# CogUtil must come first, because it supplies various FindXXX macros.

# Cogutil
FIND_PACKAGE(CogUtil 2.2.1 CONFIG REQUIRED)
IF (NOT COGUTIL_FOUND)
	MESSAGE(FATAL_ERROR "CogUtil missing: it is needed!")
ENDIF ()

include(OpenCogGccOptions)
include(OpenCogLibOptions)
include(OpenCogInstallOptions)
include(Summary)

# ===================================================================
# Check for existence of various required, optional packages.

# AtomSpace
FIND_PACKAGE(AtomSpace 5.2.0 CONFIG REQUIRED)
IF (NOT ATOMSPACE_FOUND)
	MESSAGE(FATAL_ERROR "AtomSpace missing: it is needed!")
ENDIF ()

FIND_PACKAGE(AtomSpaceStorage 4.3 CONFIG REQUIRED)
IF (NOT ATOMSPACE_STORAGE_FOUND)
	MESSAGE(FATAL_ERROR "AtomSpace Storage missing: it is needed!")
ENDIF ()

# RocksDB
FIND_PACKAGE(RocksDB REQUIRED)
IF (ROCKSDB_FOUND)
	MESSAGE(STATUS "RocksDB found.")
	SET(HAVE_ROCKSDB 1)
ELSE (ROCKSDB_FOUND)
	MESSAGE(FATAL_ERROR "RocksDB was not found.")
ENDIF (ROCKSDB_FOUND)

# ----------------------------------------------------------
# Guile Python and Cython

include(OpenCogFindGuile)
include(OpenCogFindPython)

# ----------------------------------------------------------
# Optional, currently needed only to hush up DRD in util/Logger.cc
FIND_PACKAGE(VALGRIND)
IF (VALGRIND_FOUND)
	MESSAGE(STATUS "VALGRIND was found.")
	IF (VALGRIND_INCLUDE_DIR)
		MESSAGE(STATUS "VALGRIND devel headers found.")
		ADD_DEFINITIONS(-DHAVE_VALGRIND)
	ELSE (VALGRIND_INCLUDE_DIR)
		MESSAGE(STATUS "VALGRIND devel headers NOT FOUND: needed for thread debugging.")
	ENDIF (VALGRIND_INCLUDE_DIR)
ELSE (VALGRIND_FOUND)
	MESSAGE(STATUS "VALGRIND missing: needed for thread debugging.")
ENDIF (VALGRIND_FOUND)

# ===================================================================
# Include configuration.

# Set default include paths.
INCLUDE_DIRECTORIES(${PROJECT_SOURCE_DIR}
	${COGUTIL_INCLUDE_DIR} ${ATOMSPACE_INCLUDE_DIR})

INCLUDE(OpenCogMacros)
INCLUDE(OpenCogGuile)
INCLUDE(OpenCogCython)

# ==========================================================
# Decide what to build, based on the packages found.

ADD_SUBDIRECTORY(cmake)
ADD_SUBDIRECTORY(opencog)

INCLUDE(OpenCogTestOptions)
OPENCOG_SETUP_TESTING()
OPENCOG_ADD_TEST_TARGET(test_mono
	tests/persist/monospace "Running Monospace tests...")
OPENCOG_ADD_TEST_TARGET(test_multi
	tests/persist/rocks "Running Multispace tests...")

ADD_CUSTOM_TARGET(cscope
	COMMAND find opencog examples tests -name '*.cc' -o -name '*.h' -o -name '*.cxxtest' -o -name '*.scm' > ${CMAKE_SOURCE_DIR}/cscope.files
	COMMAND cscope -b
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
	COMMENT "Generating CScope database"
)

# ===================================================================
# Packaging
# XXX FIXME. Packaging below is stale/wrong/broken.
## Architecture the package is for.
## TODO: Will give error on non debian distros, fix it.
EXECUTE_PROCESS(COMMAND  dpkg --print-architecture
	OUTPUT_VARIABLE PACKAGE_ARCHITECTURE
	OUTPUT_STRIP_TRAILING_WHITESPACE)
STRING(TIMESTAMP UTC_DATE %Y%m%d UTC)
# If 'sudo make install' is run before 'make package', then install_manifest.txt
# will be owned by root. Creating the file during configuration stage ensures
# that it is owned by the builder thus avoiding 'Permission denied' error when
# packaging.
FILE(WRITE "${PROJECT_BINARY_DIR}/install_manifest.txt")

## Cpack configuration
SET(CPACK_GENERATOR "DEB")
SET(CPACK_PACKAGE_CONTACT "opencog@googlegroups.com")
SET(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
SET(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/packages")
SET(CPACK_PACKAGE_DESCRIPTION_SUMMARY "The AtomSpace RocksDB Storage Backend")
SET(CPACK_PACKAGE_NAME "atomspace-rocks-dev")
SET(CPACK_PACKAGE_VENDOR "opencog.org")
SET(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}-${UTC_DATE}")
SET(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
SET(CPACK_PACKAGE_FILE_NAME
	"${CPACK_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}_${PACKAGE_ARCHITECTURE}")
SET(CPACK_PACKAGING_INSTALL_PREFIX "/usr/local")

## Debian specific configurations
SET(DEPENDENCY_LIST
	"guile-3.0-dev (>= 3.0.0)"
	"libstdc++6 (>= 7.0)"
	"libcogutil-dev (>= 2.2.1)"
	"atomspace-dev (>= 5.2.0)"
)

STRING(REPLACE ";" ", " MAIN_DEPENDENCIES "${DEPENDENCY_LIST}")
SET(CPACK_DEBIAN_PACKAGE_DEPENDS "${MAIN_DEPENDENCIES}")
SET(CPACK_DEBIAN_PACKAGE_SECTION "libdevel")
SET(CPACK_DEBIAN_PACKAGE_HOMEPAGE "http://opencog.org")
INCLUDE(CPack)

# ===================================================================
# Documentation.
FIND_PACKAGE(Doxygen)
# ADD_SUBDIRECTORY(doc EXCLUDE_FROM_ALL)

# ===================================================================
# Show a summary of what we found, what we will do.

SUMMARY_ADD("Cython"     "Cython (python) bindings" HAVE_CYTHON)
SUMMARY_ADD("Doxygen"    "Code documentation" DOXYGEN_FOUND)
SUMMARY_ADD("Unit tests" "Unit tests" CXXTEST_FOUND)

SUMMARY_SHOW()
