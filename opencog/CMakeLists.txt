
# This declaration must happen before subdirectory traversal.
DECLARE_GUILE_CONFIG_TARGET(SCM_CONFIG "opencog rocks-config" "OPENCOG_TEST")

ADD_SUBDIRECTORY (cython)
ADD_SUBDIRECTORY (persist)

# ------------------------------------------------------------------
ADD_GUILE_MODULE (FILES
   scm/persist-mono.scm
   scm/persist-rocks.scm
   MODULE_DESTINATION "${GUILE_SITE_DIR}/opencog"
)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/rocks-config.scm SCM_CONFIG TRUE)
# Ugly hack to work around the icky config-file infrastructure
FILE(APPEND ${GUILE_BIN_DIR}/opencog/rocks-config.scm
	"(define-public opencog-ext-path-persist-mono \"${CMAKE_CURRENT_BINARY_DIR}/persist/monospace/\")\n")

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm SCM_CONFIG FALSE)
FILE(APPEND ${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm
	"(define-public opencog-ext-path-persist-mono opencog-ext-path-persist-rocks)\n")

INSTALL(FILES ${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm DESTINATION ${GUILE_SITE_DIR}/opencog RENAME rocks-config.scm)
