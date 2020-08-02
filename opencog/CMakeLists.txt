
# INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR})

DECLARE_GUILE_CONFIG_TARGET(SCM_CONFIG "opencog rocks-config" "OPENCOG_TEST")

ADD_SUBDIRECTORY (persist)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/rocks-config.scm SCM_CONFIG TRUE)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm SCM_CONFIG FALSE)
INSTALL(FILES ${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm DESTINATION ${GUILE_SITE_DIR}/opencog RENAME rocks-config.scm)
