cmake_minimum_required(VERSION 3.10)
project(cruby-android)

message("Using compiler toolchain ${CMAKE_CXX_ANDROID_TOOLCHAIN_PREFIX}...${CMAKE_CXX_ANDROID_TOOLCHAIN_SUFFIX}")

file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/download)
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/target)

configure_file(${CMAKE_SOURCE_DIR}/tools/env.src.template ./target/env.src @ONLY)
set(SETUP_COMMAND . ${CMAKE_BINARY_DIR}/target/env.src )

add_subdirectory(${CMAKE_SOURCE_DIR}/ruby-build)
add_custom_target(clean-libs
    COMMAND ${CMAKE_SOURCE_DIR}/scripts/tools/clean-all-libs.sh
)
add_custom_target(clean-artifacts
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/target
)
add_custom_target(clean-downloads
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/download
)
add_custom_target(clean-cmake-files
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/CMakeFiles
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/CMakeCache.txt
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/cmake_install.cmake
)
add_custom_target(clean-all
    DEPENDS clean-libs clean-artifacts clean-downloads
)
