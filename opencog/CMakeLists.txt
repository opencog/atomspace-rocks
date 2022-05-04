
DECLARE_GUILE_CONFIG_TARGET(SCM_CONFIG "opencog rocks-config" "OPENCOG_TEST")

ADD_SUBDIRECTORY (persist)

# ------------------------------------------------------------------
ADD_GUILE_MODULE (FILES
   scm/persist-mono.scm
   scm/persist-rocks.scm
   MODULE_DESTINATION "${GUILE_SITE_DIR}/opencog"
)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/rocks-config.scm SCM_CONFIG TRUE)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm SCM_CONFIG FALSE)
INSTALL(FILES ${GUILE_BIN_DIR}/opencog/rocks-config-installable.scm DESTINATION ${GUILE_SITE_DIR}/opencog RENAME rocks-config.scm)
