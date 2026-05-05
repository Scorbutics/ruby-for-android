# build_ruby_physfs.cmake
# Cross-compile the ruby-physfs gem's C++ sources into libphysfs-ruby.a.
# Invoked via `cmake -P` from ruby-physfs.cmake's BUILD_COMMAND.
#
# CWD is the gem source root (BUILD_IN_SOURCE) — the cloned ruby-physfs repo.
#
# Args (passed via -D before -P):
#   STAGING_DIR        Same as BUILD_STAGING_DIR — for Ruby + libphysfs headers.
#   RUBY_ABI_VERSION   e.g. "3.1.0", to locate ${STAGING_DIR}/usr/local/include/ruby-${ABI}/...
#
# Required env vars (set by BUILD_ENV via the wrapping `cmake -E env`):
#   CXX     cross C++ compiler
#   CFLAGS  cross compile flags (we add -std=c++17 -fPIC ourselves)
#   AR      cross archiver
#
# We bypass mkmf entirely: it's awkward to cross-compile, and the gem's
# C-extension is just four .cpp files we can build directly. Pure CMake
# (no shell) so the build works identically on Linux, macOS, and Windows.

if(NOT STAGING_DIR)
    message(FATAL_ERROR "build_ruby_physfs: -DSTAGING_DIR=... is required")
endif()
if(NOT RUBY_ABI_VERSION)
    message(FATAL_ERROR "build_ruby_physfs: -DRUBY_ABI_VERSION=... is required")
endif()

set(CXX     "$ENV{CXX}")
set(CFLAGS  "$ENV{CFLAGS}")
set(AR      "$ENV{AR}")

if(NOT CXX)
    message(FATAL_ERROR "build_ruby_physfs: CXX env var not set.")
endif()
if(NOT AR)
    message(FATAL_ERROR "build_ruby_physfs: AR env var not set.")
endif()

separate_arguments(CXX_LIST    UNIX_COMMAND "${CXX}")
separate_arguments(CFLAGS_LIST UNIX_COMMAND "${CFLAGS}")
separate_arguments(AR_LIST     UNIX_COMMAND "${AR}")

# Locate Ruby's platform-specific include dir (where ruby/config.h lives).
# Mirrors the resolution logic in create_ruby_archive.cmake: the directory
# name varies (e.g., aarch64-linux-android, x86_64-linux-gnu, arm64-darwin),
# so we glob and pick the first one that contains ruby/config.h.
set(RUBY_INC_BASE "${STAGING_DIR}/usr/local/include/ruby-${RUBY_ABI_VERSION}")
if(NOT IS_DIRECTORY "${RUBY_INC_BASE}")
    message(FATAL_ERROR
        "build_ruby_physfs: Ruby headers not found at ${RUBY_INC_BASE}\n"
        "  — was Ruby built first? (ruby must precede ruby-physfs in APP_DEPENDENCIES)")
endif()

set(RUBY_PLATFORM_INC "")
file(GLOB _candidates "${RUBY_INC_BASE}/*")
foreach(C ${_candidates})
    if(IS_DIRECTORY "${C}" AND EXISTS "${C}/ruby/config.h")
        set(RUBY_PLATFORM_INC "${C}")
        break()
    endif()
endforeach()
if(NOT RUBY_PLATFORM_INC)
    message(FATAL_ERROR
        "build_ruby_physfs: could not locate ruby/config.h under ${RUBY_INC_BASE}/<platform>/\n"
        "  Available subdirs: ${_candidates}")
endif()

set(GEM_SRC "ext/physfs")
if(NOT IS_DIRECTORY "${GEM_SRC}")
    message(FATAL_ERROR "build_ruby_physfs: missing ${GEM_SRC} in ${CMAKE_CURRENT_SOURCE_DIR}")
endif()

file(GLOB GEM_SOURCES "${GEM_SRC}/*.cpp")
if(NOT GEM_SOURCES)
    message(FATAL_ERROR "build_ruby_physfs: no ${GEM_SRC}/*.cpp found")
endif()

set(INCLUDES
    "-I${RUBY_INC_BASE}"
    "-I${RUBY_PLATFORM_INC}"
    "-I${STAGING_DIR}/usr/local/include"
)

set(OBJDIR "ruby_physfs_objects")
file(REMOVE_RECURSE "${OBJDIR}")
file(MAKE_DIRECTORY "${OBJDIR}")

set(OBJS "")
foreach(SRC ${GEM_SOURCES})
    get_filename_component(BASENAME "${SRC}" NAME_WE)
    set(OBJ "${OBJDIR}/${BASENAME}.o")
    execute_process(
        COMMAND ${CXX_LIST} -c ${CFLAGS_LIST} -std=c++17 -fPIC ${INCLUDES} "${SRC}" -o "${OBJ}"
        RESULT_VARIABLE _rv
    )
    if(NOT _rv EQUAL 0)
        message(FATAL_ERROR "build_ruby_physfs: failed to compile ${SRC}")
    endif()
    list(APPEND OBJS "${OBJ}")
endforeach()

execute_process(
    COMMAND ${AR_LIST} crs libphysfs-ruby.a ${OBJS}
    RESULT_VARIABLE _rv
)
if(NOT _rv EQUAL 0)
    message(FATAL_ERROR "build_ruby_physfs: ar failed")
endif()

file(SIZE "libphysfs-ruby.a" LIB_SIZE)
math(EXPR LIB_SIZE_KB "${LIB_SIZE} / 1024")
message(STATUS "[ruby-physfs] Built libphysfs-ruby.a (${LIB_SIZE_KB} KB)")
