# strip_legacy_darwin_flags.cmake
# Remove -force_cpusubtype_ALL from autoconf/libtool files that ship it.
# No-op for files that don't exist (e.g. CMake-based deps have no configure
# or ltmain.sh, but the parent step runs unconditionally on Apple platforms).
#
# Args:
#   TARGET_DIR  Source dir to scan (typically the dep's SOURCE_DIR).

if(NOT TARGET_DIR)
    message(FATAL_ERROR "strip_legacy_darwin_flags: -DTARGET_DIR=... is required")
endif()

foreach(_f configure ltmain.sh)
    set(_path "${TARGET_DIR}/${_f}")
    if(NOT EXISTS "${_path}")
        continue()
    endif()
    file(READ "${_path}" _contents)
    string(REPLACE " -force_cpusubtype_ALL" "" _stripped "${_contents}")
    if(NOT _stripped STREQUAL _contents)
        file(WRITE "${_path}" "${_stripped}")
        message(STATUS "[strip_legacy_darwin_flags] Stripped from ${_f}")
    endif()
endforeach()
