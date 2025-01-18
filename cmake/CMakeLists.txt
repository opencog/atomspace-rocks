
# CMake boilerplate that allows users to do
#    find_package(AtomspaceRocks REQUIRED 1.3.0)
# and have it work.

include(CMakePackageConfigHelpers)

set(ConfigPackageLocation lib/cmake/AtomSpaceRocks)

install(EXPORT AtomSpaceRocksTargets
	FILE AtomSpaceRocksTargets.cmake
	DESTINATION ${ConfigPackageLocation}
)

SET(SEMANTIC_VERSION 1.3.0)

configure_package_config_file(AtomSpaceRocksConfig.cmake.in
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceRocksConfig.cmake
	INSTALL_DESTINATION ${ConfigPackageLocation}
	PATH_VARS CMAKE_INSTALL_PREFIX
)

write_basic_package_version_file(
	"${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceRocksConfigVersion.cmake"
	VERSION ${SEMANTIC_VERSION}
	COMPATIBILITY SameMajorVersion
)

INSTALL(FILES
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceRocksConfigVersion.cmake
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceRocksConfig.cmake
	DESTINATION ${ConfigPackageLocation}
)

# -----------------------------------------------------------
