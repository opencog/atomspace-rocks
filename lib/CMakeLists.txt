
# CMake boilerplate mumbo-jumbo that does something.

include(CMakePackageConfigHelpers)

set(ConfigPackageLocation lib/cmake/AtomSpaceMonoSpace)

install(EXPORT AtomSpaceMonoSpaceTargets
	FILE AtomSpaceMonoSpaceTargets.cmake
	DESTINATION ${ConfigPackageLocation}
)

configure_package_config_file(AtomSpaceMonoSpaceConfig.cmake.in
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceMonoSpaceConfig.cmake
	INSTALL_DESTINATION ${ConfigPackageLocation}
	PATH_VARS CMAKE_INSTALL_PREFIX
)

SET(SEMANTIC_VERSION 0.9.1)

write_basic_package_version_file(
	"${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceMonoSpaceConfigVersion.cmake"
	VERSION ${SEMANTIC_VERSION}
	COMPATIBILITY SameMajorVersion
)

INSTALL(FILES
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceMonoSpaceConfigVersion.cmake
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceMonoSpaceConfig.cmake
	DESTINATION ${ConfigPackageLocation}
)
