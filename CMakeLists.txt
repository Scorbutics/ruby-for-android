cmake_minimum_required(VERSION 3.10)
project(cruby-cross-platform)

# Project information
message(STATUS "==========================================")
message(STATUS "  Ruby Cross-Platform Build System")
message(STATUS "==========================================")

# Set module path for custom CMake modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# Include build helpers (must be first)
include(RubyBuildHelpers)

# Detect and configure target platform
include(PlatformDetection)

# Create staging directories
message(STATUS "Build directories:")
message(STATUS "  Downloads: ${RUBY_BUILD_DOWNLOAD_DIR}")
message(STATUS "  Staging:   ${RUBY_BUILD_STAGING_DIR}")

# Configure environment template for runtime
configure_file(
    ${CMAKE_SOURCE_DIR}/tools/env.src.template
    ${RUBY_BUILD_STAGING_DIR}/env.src
    @ONLY
)

# Load all dependency configurations
include(Dependencies)

# Create clean targets
add_custom_target(clean-libs
    COMMENT "Cleaning all library build directories"
)

# Add individual library clean targets as dependencies
foreach(DEP ${RUBY_DEPENDENCIES})
    add_dependencies(clean-libs ${DEP}_clean)
endforeach()

add_custom_target(clean-artifacts
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${RUBY_BUILD_STAGING_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${RUBY_BUILD_STAGING_DIR}
    COMMENT "Cleaning build artifacts"
)

add_custom_target(clean-downloads
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${RUBY_BUILD_DOWNLOAD_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${RUBY_BUILD_DOWNLOAD_DIR}
    COMMENT "Cleaning downloaded sources"
)

add_custom_target(clean-cmake-files
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/CMakeFiles
    COMMAND ${CMAKE_COMMAND} -E remove -f ${CMAKE_BINARY_DIR}/CMakeCache.txt
    COMMAND ${CMAKE_COMMAND} -E remove -f ${CMAKE_BINARY_DIR}/cmake_install.cmake
    COMMENT "Cleaning CMake generated files"
)

add_custom_target(clean-all
    DEPENDS clean-libs clean-artifacts clean-downloads
    COMMENT "Cleaning everything"
)

# Summary
message(STATUS "==========================================")
message(STATUS "Configuration Summary:")
message(STATUS "  Platform:      ${RUBY_TARGET_PLATFORM}")
message(STATUS "  Architecture:  ${RUBY_TARGET_ARCH}")
message(STATUS "  Host Triplet:  ${RUBY_HOST_TRIPLET}")
message(STATUS "  Dependencies:  ${RUBY_DEPENDENCIES}")
message(STATUS "==========================================")
message(STATUS "Build targets:")
message(STATUS "  all           - Build everything (default)")
message(STATUS "  ruby_archive  - Build and create ruby_full.zip")
message(STATUS "  clean-all     - Clean everything")
message(STATUS "  clean-libs    - Clean all library builds")
message(STATUS "  {dep}_clean   - Clean specific dependency")
message(STATUS "==========================================")
