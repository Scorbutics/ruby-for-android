# check_ruby_patches.cmake
#
# Checks that every Ruby patch the build would select applies, for every
# supported Ruby version, platform and build type. The build applies Ruby
# patches strictly, so this catches the failure before a long build does,
# and in CI for platforms the runner does not build.
#
# Usage:
#   cmake -DWORK_DIR=/tmp/ruby-patches -P cmake/ruby-app/tests/check_ruby_patches.cmake
#
# WORK_DIR holds the downloaded tarballs and one extracted tree per version.
# Patches are applied for real in series order, then reverted in reverse
# order, so that a patch that depends on an earlier one is checked correctly.

cmake_minimum_required(VERSION 3.14)

if(NOT WORK_DIR)
    message(FATAL_ERROR "check_ruby_patches.cmake: WORK_DIR is required")
endif()

get_filename_component(_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
include("${_ROOT}/cmake/core/PlatformPatches.cmake")
include("${_ROOT}/cmake/ruby-app/ruby-versions.cmake")

set(_PLATFORMS android ios linux macos)
set(_BUILD_TYPES static shared)
set(_FAILURES "")

file(MAKE_DIRECTORY "${WORK_DIR}")

foreach(_entry ${RUBY_SUPPORTED_VERSIONS})
    string(REPLACE "|" ";" _entry "${_entry}")
    list(GET _entry 0 _version)
    list(GET _entry 1 _sha256)
    string(REGEX MATCH "^[0-9]+\\.[0-9]+" _minor "${_version}")

    set(_tarball "${WORK_DIR}/ruby-${_version}.tar.xz")
    set(_tree "${WORK_DIR}/ruby-${_version}")
    if(NOT EXISTS "${_tarball}")
        message(STATUS "Downloading ruby-${_version}.tar.xz")
        file(DOWNLOAD "https://cache.ruby-lang.org/pub/ruby/${_minor}/ruby-${_version}.tar.xz"
            "${_tarball}" EXPECTED_HASH SHA256=${_sha256} TLS_VERIFY ON)
    endif()
    file(REMOVE_RECURSE "${_tree}")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf "${_tarball}"
        WORKING_DIRECTORY "${WORK_DIR}" RESULT_VARIABLE _res)
    if(NOT _res EQUAL 0 OR NOT EXISTS "${_tree}")
        message(FATAL_ERROR "Cannot extract ${_tarball}")
    endif()

    foreach(_platform ${_PLATFORMS})
        foreach(_build_type ${_BUILD_TYPES})
            get_platform_patches(
                LIBRARY ruby
                VERSION ${_version}
                PLATFORM ${_platform}
                PATCH_BASE "${_ROOT}/cmake/ruby-app/patches"
                BUILD_TYPE ${_build_type}
                OUTPUT_VAR _patches
            )
            set(_applied "")
            foreach(_patch ${_patches})
                get_filename_component(_name "${_patch}" NAME)
                execute_process(COMMAND patch -p1 -s -f --no-backup-if-mismatch -i "${_patch}"
                    WORKING_DIRECTORY "${_tree}" RESULT_VARIABLE _res
                    OUTPUT_VARIABLE _out ERROR_VARIABLE _out)
                if(_res EQUAL 0)
                    list(INSERT _applied 0 "${_patch}")
                    message(STATUS "ok    ${_version} ${_platform} ${_build_type}: ${_name}")
                else()
                    list(APPEND _FAILURES "${_version} ${_platform} ${_build_type}: ${_name}")
                    message(STATUS "FAIL  ${_version} ${_platform} ${_build_type}: ${_name}\n${_out}")
                    # A failed patch may have changed some files: start over clean.
                    file(REMOVE_RECURSE "${_tree}")
                    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf "${_tarball}"
                        WORKING_DIRECTORY "${WORK_DIR}")
                    set(_applied "")
                    break()
                endif()
            endforeach()
            foreach(_patch ${_applied})
                execute_process(COMMAND patch -p1 -R -s -f --no-backup-if-mismatch -i "${_patch}"
                    WORKING_DIRECTORY "${_tree}" RESULT_VARIABLE _res)
                if(NOT _res EQUAL 0)
                    message(FATAL_ERROR "Cannot revert ${_patch} in ${_tree}")
                endif()
            endforeach()
        endforeach()
    endforeach()
    file(REMOVE_RECURSE "${_tree}")
endforeach()

if(_FAILURES)
    string(REPLACE ";" "\n  " _list "${_FAILURES}")
    message(FATAL_ERROR "Ruby patches that do not apply:\n  ${_list}")
endif()
message(STATUS "All Ruby patches apply on every supported version and platform")
