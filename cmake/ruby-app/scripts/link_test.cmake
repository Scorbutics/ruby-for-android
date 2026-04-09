# link_test.cmake
# Compile and link a minimal C program against the built Ruby static libraries.
# This validates that no symbols are missing from the cross-compiled output.
#
# Required variables (passed via -D):
#   BUILD_STAGING_DIR   - Staging directory with installed libraries
#   RUBY_ABI_VERSION    - Ruby ABI version (e.g., 3.1.0)
#   CROSS_CC            - Cross-compiler command (may contain flags, e.g. "clang -target ...")
#   CFLAGS              - Compiler flags
#   LDFLAGS             - Linker flags
#   TARGET_PLATFORM     - Platform name (Linux, Android, iOS)
#   LINK_TEST_SRC       - Path to test source file
#   LINK_TEST_BIN       - Output binary path

cmake_minimum_required(VERSION 3.10)

foreach(VAR BUILD_STAGING_DIR RUBY_ABI_VERSION CROSS_CC LINK_TEST_SRC LINK_TEST_BIN TARGET_PLATFORM)
    if(NOT DEFINED ${VAR})
        message(FATAL_ERROR "link_test.cmake: ${VAR} is required")
    endif()
endforeach()

# --- Detect RUBY_PLATFORM from config.h (same logic as create_ruby_archive.cmake) ---
set(CONFIG_H_PATH "${BUILD_STAGING_DIR}/usr/local/include/ruby-${RUBY_ABI_VERSION}")

file(GLOB CANDIDATE_DIRS "${CONFIG_H_PATH}/*")
set(RUBY_PLATFORM_DIR "")
foreach(DIR ${CANDIDATE_DIRS})
    if(IS_DIRECTORY "${DIR}" AND EXISTS "${DIR}/ruby/config.h")
        set(RUBY_PLATFORM_DIR "${DIR}")
        break()
    endif()
endforeach()

if(NOT RUBY_PLATFORM_DIR)
    message(FATAL_ERROR "Could not find platform-specific include directory in ${CONFIG_H_PATH}")
endif()

get_filename_component(RUBY_PLATFORM "${RUBY_PLATFORM_DIR}" NAME)
message(STATUS "Link test: detected Ruby platform: ${RUBY_PLATFORM}")

# --- Build include flags ---
set(INCLUDE_FLAGS
    "-I${CONFIG_H_PATH}"
    "-I${RUBY_PLATFORM_DIR}"
)

# --- Build library search paths ---
set(LIB_FLAGS
    "-L${BUILD_STAGING_DIR}/usr/local/lib"
    "-L${BUILD_STAGING_DIR}/usr/lib"
)

# --- Static libraries in link order ---
# Ruby core first, then extensions, then dependencies (deepest deps last)
set(LIBS -lruby-static)
if(EXISTS "${BUILD_STAGING_DIR}/usr/local/lib/libruby-ext.a")
    list(APPEND LIBS -lruby-ext)
endif()
# Ruby depends on these (order matters for static linking):
# Note: libffi and libyaml are bundled inside Ruby (ext/fiddle, ext/psych)
# and their symbols are in libruby-ext.a, not separate .a files.
list(APPEND LIBS -lssl -lcrypto -lgdbm -lreadline -lncurses -lgmp -lz)

# Platform-specific system libraries
if(TARGET_PLATFORM STREQUAL "Linux")
    if(EXISTS "${BUILD_STAGING_DIR}/usr/lib/libcrypt.a")
        list(APPEND LIBS -lcrypt)
    endif()
    list(APPEND LIBS -lm -lpthread -ldl)
elseif(TARGET_PLATFORM STREQUAL "Android")
    list(APPEND LIBS -lm -ldl -llog)
elseif(TARGET_PLATFORM STREQUAL "iOS")
    list(APPEND LIBS -lm)
    # iOS needs system framework for startup code
    list(APPEND LIBS -framework Foundation)
endif()

# --- Run the compiler ---
# CROSS_CC may contain spaces (e.g., "clang -target aarch64-linux-android26")
separate_arguments(CC_CMD UNIX_COMMAND "${CROSS_CC}")

# CFLAGS and LDFLAGS are also space-separated strings
if(DEFINED CFLAGS)
    separate_arguments(CFLAG_LIST UNIX_COMMAND "${CFLAGS}")
else()
    set(CFLAG_LIST "")
endif()

if(DEFINED LDFLAGS)
    separate_arguments(LDFLAG_LIST UNIX_COMMAND "${LDFLAGS}")
else()
    set(LDFLAG_LIST "")
endif()

set(FULL_CMD
    ${CC_CMD}
    ${CFLAG_LIST}
    ${INCLUDE_FLAGS}
    ${LINK_TEST_SRC}
    -o ${LINK_TEST_BIN}
    ${LDFLAG_LIST}
    ${LIB_FLAGS}
    ${LIBS}
)

# Log the command for debugging
string(REPLACE ";" " " CMD_STR "${FULL_CMD}")
message(STATUS "Link test command: ${CMD_STR}")

execute_process(
    COMMAND ${FULL_CMD}
    RESULT_VARIABLE LINK_RESULT
    OUTPUT_VARIABLE LINK_OUTPUT
    ERROR_VARIABLE LINK_ERROR
)

if(LINK_OUTPUT)
    message(STATUS "${LINK_OUTPUT}")
endif()

if(NOT LINK_RESULT EQUAL 0)
    message(FATAL_ERROR
        "Link test FAILED! Missing symbols in the built libraries.\n"
        "Compiler output:\n${LINK_ERROR}"
    )
endif()

message(STATUS "Link test PASSED - all symbols resolved successfully")
