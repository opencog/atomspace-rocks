
ENABLE_TESTING()
INCLUDE(AddCxxtest)

# All tests should load the atomspace scm from the build dir, unless the scm
# file is specific to the test (this variable is used by ADD_CXXTEST)
SET(GUILE_LOAD_PATH "${PROJECT_BINARY_DIR}/opencog/scm")

# Perform tests in component-dependency order, as much as possible.
IF (CXXTEST_FOUND)
   ADD_SUBDIRECTORY (persist)
ENDIF (CXXTEST_FOUND)
