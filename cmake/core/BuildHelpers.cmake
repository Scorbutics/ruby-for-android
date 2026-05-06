# BuildHelpers.cmake
# Generic cross-platform build helper functions for external dependencies
# This is a reusable core build system that can be applied to any project

include(ExternalProject)

include(PlatformDetection)

# Captured at include time so functions in this file can resolve sibling
# helper scripts. CMAKE_CURRENT_FUNCTION_LIST_DIR would be cleaner but
# requires CMake 3.17, and this project pins 3.14.
set(_BUILDHELPERS_DIR "${CMAKE_CURRENT_LIST_DIR}")

string(TOLOWER "${TARGET_PLATFORM}" PLATFORM_LOWER)

# Global configuration
set(BUILD_DOWNLOAD_DIR "${CMAKE_BINARY_DIR}/download" CACHE PATH "Download directory for sources")
file(MAKE_DIRECTORY "${BUILD_DOWNLOAD_DIR}")

set(BUILD_STAGING_DIR "${CMAKE_BINARY_DIR}/target/${TARGET_ARCH}-${PLATFORM_LOWER}" CACHE PATH "Staging directory for installation")
file(MAKE_DIRECTORY "${BUILD_STAGING_DIR}")

# Set number of parallel jobs for builds
include(ProcessorCount)
ProcessorCount(NCPUS)
if(NCPUS EQUAL 0)
    set(NCPUS 1)
endif()
set(BUILD_PARALLEL_JOBS ${NCPUS} CACHE STRING "Number of parallel build jobs")

#
# add_external_dependency()
#
# Adds an external library dependency using ExternalProject
# This is the core generic function for building any external dependency
#
# Parameters:
#   NAME                    - Name of the dependency (e.g., "openssl", "ncurses")
#   VERSION                 - Version string (e.g., "1.1.1m")
#   URL                     - Download URL (for tarballs, mutually exclusive with GIT_REPOSITORY)
#   URL_HASH                - Hash for verification (e.g., "SHA256=...")
#   GIT_REPOSITORY          - Git repository URL (mutually exclusive with URL)
#   GIT_TAG                 - Git tag/branch/commit to checkout
#   GIT_SHALLOW             - Perform shallow clone (TRUE/FALSE)
#   GIT_SUBMODULES_RECURSE  - Recursively clone submodules (TRUE/FALSE)
#   CONFIGURE_COMMAND       - Configure command (as list)
#   BUILD_COMMAND           - Build command (as list, optional - defaults to make)
#   INSTALL_COMMAND         - Install command (as list, optional - defaults to make install)
#   BUILD_IN_SOURCE         - Build in source directory (TRUE/FALSE, defaults to TRUE)
#   EXTRACT_COMMAND         - Custom extract command (optional)
#   PATCH_COMMAND           - Patch command (as list, optional)
#   DEPENDS                 - List of dependency targets (optional)
#   ENV_VARS                - Additional environment variables (as list, optional)
#                             Format: VAR1=value1 VAR2=value2
#                             These override/extend variables from BUILD_ENV
#   PATCH_DIR               - Directory containing patches (optional, defaults to cmake/patches/${NAME})
#
function(add_external_dependency)
    set(options "")
    set(oneValueArgs NAME VERSION URL_HASH ARCHIVE_NAME PATCH_DIR
                     GIT_REPOSITORY GIT_TAG GIT_SHALLOW GIT_SUBMODULES_RECURSE
                     BUILD_IN_SOURCE)
    set(multiValueArgs URL CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND
                       EXTRACT_COMMAND PATCH_COMMAND DEPENDS ENV_VARS)
    cmake_parse_arguments(DEP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required arguments
    if(NOT DEP_NAME)
        message(FATAL_ERROR "add_external_dependency: NAME is required")
    endif()
    if(NOT DEP_VERSION)
        message(FATAL_ERROR "add_external_dependency: VERSION is required for ${DEP_NAME}")
    endif()
    if(NOT DEP_URL AND NOT DEP_GIT_REPOSITORY)
        message(FATAL_ERROR "add_external_dependency: Either URL or GIT_REPOSITORY is required for ${DEP_NAME}")
    endif()
    if(DEP_URL AND DEP_GIT_REPOSITORY)
        message(FATAL_ERROR "add_external_dependency: URL and GIT_REPOSITORY are mutually exclusive for ${DEP_NAME}")
    endif()

    # Set defaults
    if(NOT DEP_ARCHIVE_NAME)
        set(DEP_ARCHIVE_NAME "${DEP_NAME}-${DEP_VERSION}")
    endif()

    set(BUILD_DIR  "${CMAKE_BINARY_DIR}/${DEP_NAME}/build_dir/${TARGET_ARCH}-${PLATFORM_LOWER}")
    set(SOURCE_DIR "${CMAKE_BINARY_DIR}/${DEP_NAME}/build_dir/${TARGET_ARCH}-${PLATFORM_LOWER}/${DEP_ARCHIVE_NAME}")

    # Default build and install commands
    if(NOT DEP_BUILD_COMMAND)
        set(DEP_BUILD_COMMAND ${CMAKE_COMMAND} -E env ${BUILD_ENV} make -j${BUILD_PARALLEL_JOBS})
    endif()

    if(NOT DEP_INSTALL_COMMAND)
        set(DEP_INSTALL_COMMAND make install DESTDIR=${BUILD_STAGING_DIR})
    endif()

    # Default BUILD_IN_SOURCE
    if(NOT DEFINED DEP_BUILD_IN_SOURCE)
        set(DEP_BUILD_IN_SOURCE TRUE)
    endif()

    # Allow override with custom patch command
    if(DEP_PATCH_COMMAND)
        set(PATCH_CMD ${DEP_PATCH_COMMAND})
    else()
        # Build patch command using get_platform_patches
        set(PATCH_CMD "")
        
        # Determine base patch directory
        set(PATCH_BASE_DIR "")
        if(DEP_PATCH_DIR AND EXISTS "${DEP_PATCH_DIR}/${DEP_NAME}")
            set(PATCH_BASE_DIR "${DEP_PATCH_DIR}/${DEP_NAME}")
        elseif(DEFINED APP_DIR AND EXISTS "${APP_DIR}/patches/${DEP_NAME}")
            set(PATCH_BASE_DIR "${APP_DIR}/patches/${DEP_NAME}")
        endif()

        if(NOT PATCH_BASE_DIR)
            message(STATUS "  No patch directory found for ${DEP_NAME} (APP_DIR=${APP_DIR})")
        endif()
        if(PATCH_BASE_DIR)
            message(STATUS "  Patch base dir: ${PATCH_BASE_DIR}")
            message(STATUS "  Looking for patches: library=${DEP_NAME} version=${DEP_VERSION} platform=${PLATFORM_LOWER}")

            # Determine build type for conditional patch annotations ([shared] / [static])
            if(BUILD_SHARED_LIBS)
                set(_PATCH_BUILD_TYPE "shared")
            else()
                set(_PATCH_BUILD_TYPE "static")
            endif()

            # Get the list of patches to apply
            get_platform_patches(
                LIBRARY ${DEP_NAME}
                VERSION ${DEP_VERSION}
                PLATFORM ${PLATFORM_LOWER}
                PATCH_BASE "${PATCH_BASE_DIR}/.."
                BUILD_TYPE ${_PATCH_BUILD_TYPE}
                OUTPUT_VAR PATCH_LIST
            )

            message(STATUS "  Found patches: ${PATCH_LIST}")

            # Build command list from patches
            if(PATCH_LIST)
                set(PATCH_CMD ${CMAKE_COMMAND} -E echo "Applying patches for ${DEP_NAME} ${DEP_VERSION}...")
                
                foreach(PATCH_PATH ${PATCH_LIST})
                    get_filename_component(PATCH_FILE "${PATCH_PATH}" NAME)
                    # Use --forward to skip already-applied patches, --reject-file=- to discard rejects
                    # and || true to continue even if patch is already applied
                    list(APPEND PATCH_CMD COMMAND patch -p1 --forward --reject-file=- -i "${PATCH_PATH}" || true)
                    list(APPEND PATCH_CMD COMMAND ${CMAKE_COMMAND} -E echo "  Applied: ${PATCH_FILE}")
                endforeach()
            endif()
        endif()

    endif()

    if(POLICY CMP0135)
        cmake_policy(SET CMP0135 OLD)
    endif()

    # Build download parameters based on source type
    set(DOWNLOAD_PARAMS "")
    if(DEP_URL)
        list(APPEND DOWNLOAD_PARAMS
            URL                 ${DEP_URL}
            URL_HASH            ${DEP_URL_HASH}
            DOWNLOAD_DIR        ${BUILD_DOWNLOAD_DIR}
        )
    else()
        list(APPEND DOWNLOAD_PARAMS
            GIT_REPOSITORY      ${DEP_GIT_REPOSITORY}
            GIT_TAG             ${DEP_GIT_TAG}
        )
        if(DEP_GIT_SHALLOW)
            list(APPEND DOWNLOAD_PARAMS GIT_SHALLOW ${DEP_GIT_SHALLOW})
        endif()
        if(DEP_GIT_SUBMODULES_RECURSE)
            list(APPEND DOWNLOAD_PARAMS GIT_SUBMODULES_RECURSE ${DEP_GIT_SUBMODULES_RECURSE})
        endif()
    endif()

    # Create the ExternalProject
    ExternalProject_Add(${DEP_NAME}_external
        ${DOWNLOAD_PARAMS}
        PREFIX              ${BUILD_DIR}
        SOURCE_DIR          ${SOURCE_DIR}
        STAMP_DIR           ${BUILD_DIR}/stamps
        TMP_DIR             ${BUILD_DIR}/tmp

        # Disable automatic git updates on every build
        UPDATE_COMMAND      ""

        PATCH_COMMAND       ${PATCH_CMD}

        CONFIGURE_COMMAND   ${CMAKE_COMMAND} -E env ${BUILD_ENV} ${DEP_ENV_VARS}
                            ${DEP_CONFIGURE_COMMAND}

        BUILD_COMMAND       ${DEP_BUILD_COMMAND}
        BUILD_IN_SOURCE     ${DEP_BUILD_IN_SOURCE}

        INSTALL_COMMAND     ${CMAKE_COMMAND} -E env ${BUILD_ENV}
                            ${DEP_INSTALL_COMMAND}

        LOG_DOWNLOAD        TRUE
        LOG_CONFIGURE       TRUE
        LOG_BUILD           TRUE
        LOG_INSTALL         TRUE
        LOG_OUTPUT_ON_FAILURE TRUE

        DEPENDS             ${DEP_DEPENDS}
    )

    # On Apple platforms (iOS/macOS), old autoconf+libtool bundles hardcode
    # -force_cpusubtype_ALL into their link commands. Modern Xcode linkers
    # (15+) no longer recognize this flag. Strip it from configure/ltmain.sh
    # after patches are applied but before configure runs.
    #
    # Only the autoconf-shaped deps actually have configure/ltmain.sh — for
    # CMake-based deps (e.g. physfs) those files don't exist and perl -pi
    # would fail. We dispatch through a tiny cmake -P script that no-ops
    # missing files instead of guessing per-dep here.
    if(TARGET_PLATFORM STREQUAL "iOS" OR TARGET_PLATFORM STREQUAL "macOS")
        ExternalProject_Add_Step(${DEP_NAME}_external strip_legacy_darwin_flags
            COMMAND ${CMAKE_COMMAND}
                    -DTARGET_DIR=${SOURCE_DIR}
                    -P ${_BUILDHELPERS_DIR}/scripts/strip_legacy_darwin_flags.cmake
            DEPENDEES patch
            DEPENDERS configure
            LOG TRUE
            LOG_OUTPUT_ON_FAILURE TRUE
        )
    endif()

    # Create a target that depends on the external project
    add_custom_target(${DEP_NAME} DEPENDS ${DEP_NAME}_external)

    # Create clean target for this dependency
    add_custom_target(${DEP_NAME}_clean
        COMMAND ${CMAKE_COMMAND} -E remove_directory ${BUILD_DIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${BUILD_DIR}
        COMMENT "Cleaning ${DEP_NAME} build directory"
    )
endfunction()

#
# get_platform_patches()
#
# Build a list of all matching patches for a library/platform/version combination
# Supports organized patch directory structure with series files
#
# Parameters:
#   LIBRARY     - Library name (e.g., "openssl", "ncurses")
#   VERSION     - Library version
#   PLATFORM    - Platform name (e.g., "android", "ios", "linux")
#   PATCH_BASE  - Base directory for patches (optional, defaults to cmake/patches)
#   OUTPUT_VAR  - Variable name to store the list of patch paths
#
function(get_platform_patches)
    set(options "")
    set(oneValueArgs LIBRARY VERSION PLATFORM PATCH_BASE BUILD_TYPE OUTPUT_VAR)
    set(multiValueArgs "")
    cmake_parse_arguments(PATCH "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT PATCH_PATCH_BASE)
        set(PATCH_PATCH_BASE "${CMAKE_SOURCE_DIR}/cmake/patches")
    endif()

    set(PATCH_BASE "${PATCH_PATCH_BASE}/${PATCH_LIBRARY}")

    # Patch search order:
    # 1. Platform + version specific: patches/{library}/{platform}/{version}/
    # 2. Platform specific: patches/{library}/{platform}/
    # 3. Version specific: patches/{library}/{version}/
    # 4. Common: patches/{library}/common/

    set(PATCH_SEARCH_PATHS
        "${PATCH_BASE}/${PATCH_PLATFORM}/${PATCH_VERSION}"
        "${PATCH_BASE}/${PATCH_PLATFORM}"
        "${PATCH_BASE}/${PATCH_VERSION}"
        "${PATCH_BASE}/common"
    )

    message(STATUS "  Patch base: ${PATCH_BASE}")
    message(STATUS "  Patch search paths: ${PATCH_SEARCH_PATHS}")

    set(COLLECTED_PATCHES "")

    foreach(SEARCH_PATH ${PATCH_SEARCH_PATHS})
        if(EXISTS "${SEARCH_PATH}")
            message(STATUS "  [EXISTS] ${SEARCH_PATH}")
        else()
            message(STATUS "  [MISSING] ${SEARCH_PATH}")
        endif()
        if(EXISTS "${SEARCH_PATH}/series")
            # Read patch series file
            file(STRINGS "${SEARCH_PATH}/series" PATCH_LIST)
            foreach(PATCH_FILE ${PATCH_LIST})
                string(STRIP "${PATCH_FILE}" PATCH_FILE)
                # Skip comments and empty lines
                if(NOT PATCH_FILE MATCHES "^#" AND NOT PATCH_FILE STREQUAL "")
                    # Parse optional build-type condition: "file.patch [shared]" or "file.patch [static]"
                    set(PATCH_CONDITION "")
                    if(PATCH_FILE MATCHES "^(.+[^ \t])[ \t]+\\[([a-zA-Z]+)\\]$")
                        set(PATCH_FILE "${CMAKE_MATCH_1}")
                        set(PATCH_CONDITION "${CMAKE_MATCH_2}")
                    endif()

                    # Skip patch if build-type condition doesn't match
                    if(PATCH_CONDITION AND PATCH_BUILD_TYPE AND NOT PATCH_CONDITION STREQUAL PATCH_BUILD_TYPE)
                        message(STATUS "    Skipping ${PATCH_FILE} (condition [${PATCH_CONDITION}], build type: ${PATCH_BUILD_TYPE})")
                        continue()
                    endif()

                    set(PATCH_PATH "${SEARCH_PATH}/${PATCH_FILE}")
                    if(EXISTS "${PATCH_PATH}")
                        list(APPEND COLLECTED_PATCHES "${PATCH_PATH}")
                    endif()
                endif()
            endforeach()
        else()
            # No series file, apply all .patch files in alphabetical order
            file(GLOB PATCHES "${SEARCH_PATH}/*.patch")
            list(SORT PATCHES)
            foreach(PATCH_PATH ${PATCHES})
                list(APPEND COLLECTED_PATCHES "${PATCH_PATH}")
            endforeach()
        endif()
    endforeach()

    # Return the collected patches list
    set(${PATCH_OUTPUT_VAR} ${COLLECTED_PATCHES} PARENT_SCOPE)
endfunction()

#
# create_archive_target()
#
# Creates a target to package the build output and registers it for export
#
# Parameters:
#   NAME        - Target name
#   OUTPUT      - Output filename (relative to BUILD_STAGING_DIR)
#   INCLUDES    - List of paths to include in archive
#   DEPENDS     - List of target dependencies
#   FORMAT      - Archive format (zip, tar.gz, etc.)
#
# Side effects:
#   - Appends OUTPUT to TARGET_ARCHIVES cache variable for install step discovery
#
function(create_archive_target)
    set(options "")
    set(oneValueArgs NAME OUTPUT FORMAT)
    set(multiValueArgs INCLUDES DEPENDS)
    cmake_parse_arguments(ARCHIVE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARCHIVE_OUTPUT)
        message(FATAL_ERROR "create_archive_target: OUTPUT parameter is required")
    endif()

    if(NOT ARCHIVE_FORMAT)
        set(ARCHIVE_FORMAT "zip")
    endif()

    if(ARCHIVE_FORMAT STREQUAL "zip")
        add_custom_target(${ARCHIVE_NAME}
            COMMAND zip -q --symlinks -r ${ARCHIVE_OUTPUT} ${ARCHIVE_INCLUDES}
            WORKING_DIRECTORY ${BUILD_STAGING_DIR}
            DEPENDS ${ARCHIVE_DEPENDS}
            COMMENT "Creating archive: ${ARCHIVE_OUTPUT}"
        )
    elseif(ARCHIVE_FORMAT STREQUAL "tar.gz")
        add_custom_target(${ARCHIVE_NAME}
            COMMAND tar czf ${ARCHIVE_OUTPUT} ${ARCHIVE_INCLUDES}
            WORKING_DIRECTORY ${BUILD_STAGING_DIR}
            DEPENDS ${ARCHIVE_DEPENDS}
            COMMENT "Creating archive: ${ARCHIVE_OUTPUT}"
        )
    else()
        message(FATAL_ERROR "Unsupported archive format: ${ARCHIVE_FORMAT}")
    endif()

    # Register this archive for export by appending to TARGET_ARCHIVES cache variable
    # Initialize TARGET_ARCHIVES if not already set
    if(NOT DEFINED TARGET_ARCHIVES)
        set(TARGET_ARCHIVES "" CACHE STRING "List of archives to export (relative to BUILD_STAGING_DIR)" FORCE)
    endif()

    # Append this archive to the list
    set(TARGET_ARCHIVES "${TARGET_ARCHIVES};${ARCHIVE_OUTPUT}" CACHE STRING "List of archives to export (relative to BUILD_STAGING_DIR)" FORCE)

    message(STATUS "Registered archive for export: ${ARCHIVE_OUTPUT}")
endfunction()

#
# get_sub_cmake_cross_args()
#
# Build the list of -D arguments needed by a child CMake invocation (i.e. an
# ExternalProject CONFIGURE_COMMAND that runs `cmake -S ... -B ...`) so that
# the child inherits the same cross-compile target as the parent.
#
# Use this for dependencies whose upstream is itself CMake-based (or for which
# we provide a small in-tree CMakeLists.txt). Autoconf-based deps don't need
# it — they pick up CC/CFLAGS/etc. from BUILD_ENV.
#
# Output:
#   <OUT_VAR>  list variable receiving the args (set in PARENT_SCOPE)
#
function(get_sub_cmake_cross_args OUT_VAR)
    set(_args
        "-DCMAKE_INSTALL_PREFIX=${BUILD_STAGING_DIR}/usr/local"
        "-DCMAKE_INSTALL_LIBDIR=lib"
        "-DCMAKE_INSTALL_INCLUDEDIR=include"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    )
    if(TARGET_PLATFORM STREQUAL "Android")
        list(APPEND _args
            "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_ANDROID_NDK}/build/cmake/android.toolchain.cmake"
            "-DANDROID_ABI=${ANDROID_ABI}"
            "-DANDROID_PLATFORM=${ANDROID_PLATFORM}"
            "-DANDROID_NDK=${CMAKE_ANDROID_NDK}"
        )
    elseif(TARGET_PLATFORM STREQUAL "iOS")
        list(APPEND _args "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    elseif(TARGET_PLATFORM STREQUAL "macOS")
        if(CMAKE_OSX_ARCHITECTURES)
            list(APPEND _args "-DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}")
        endif()
        if(CMAKE_OSX_DEPLOYMENT_TARGET)
            list(APPEND _args "-DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
        endif()
    endif()
    set(${OUT_VAR} "${_args}" PARENT_SCOPE)
endfunction()

message(STATUS "Generic Build System loaded - NCPUS: ${BUILD_PARALLEL_JOBS}")
