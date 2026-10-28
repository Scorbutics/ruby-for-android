# ruby-versions.cmake
# Supported Ruby versions and the version selected for this build.
#
# Pokemon Studio compiles game bytecode with a different Ruby on each OS
# (3.0 on Windows, 3.2 on macOS, 3.3 on Linux) and bytecode only loads on
# the Ruby minor version that produced it, so one build exists per minor.
#
# Select the version with -DRUBY_VERSION=X.Y.Z (./configure --with-ruby-version).
# Included from the top-level CMakeLists.txt before any dependency.

set(RUBY_VERSION "3.0.7" CACHE STRING "Ruby version to build (one of RUBY_SUPPORTED_VERSIONS)")

# <version>|<sha256 of ruby-<version>.tar.xz>, as published on ruby-lang.org
set(RUBY_SUPPORTED_VERSIONS
    "3.0.7|1748338373c4fad80129921080d904aca326e41bd9589b498aa5ee09fd575bab"
    "3.1.1|7aefaa6b78b076515d272ec59c4616707a54fc9f2391239737d5f10af7a16caa"
    "3.2.11|c13aec0c206725d5d356acbae6e5fd8bffd92dc325aec14fd5dd7795d4b763d2"
    "3.3.13|6bd764359992373a96556b45fb7dfe6b6170da34a0a2fd0b7e1be7932fea982b"
)

set(_RUBY_KNOWN_VERSIONS "")
unset(RUBY_TARBALL_SHA256)
foreach(_entry ${RUBY_SUPPORTED_VERSIONS})
    string(REPLACE "|" ";" _entry "${_entry}")
    list(GET _entry 0 _version)
    list(GET _entry 1 _sha256)
    list(APPEND _RUBY_KNOWN_VERSIONS "${_version}")
    if(_version STREQUAL RUBY_VERSION)
        set(RUBY_TARBALL_SHA256 "${_sha256}")
    endif()
endforeach()

if(NOT RUBY_TARBALL_SHA256)
    message(FATAL_ERROR "Unsupported RUBY_VERSION '${RUBY_VERSION}'. Supported: ${_RUBY_KNOWN_VERSIONS}")
endif()

string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" _ "${RUBY_VERSION}")
set(RUBY_MAJOR_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")   # e.g. 3.0
set(RUBY_ABI_VERSION "${RUBY_MAJOR_VERSION}.0")                 # include/lib path component

message(STATUS "Ruby version: ${RUBY_VERSION} (ABI ${RUBY_ABI_VERSION})")
