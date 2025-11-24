# BuildHelpers.cmake
# Generic cross-platform build helper functions for external dependencies
# This is a reusable core build system that can be applied to any project

include(ExternalProject)

include(PlatformDetection)

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
#   NAME                - Name of the dependency (e.g., "openssl", "ncurses")
#   VERSION             - Version string (e.g., "1.1.1m")
#   URL                 - Download URL
#   URL_HASH            - Hash for verification (e.g., "SHA256=...")
#   CONFIGURE_COMMAND   - Configure command (as list)
#   BUILD_COMMAND       - Build command (as list, optional - defaults to make)
#   INSTALL_COMMAND     - Install command (as list, optional - defaults to make install)
#   EXTRACT_COMMAND     - Custom extract command (optional)
#   PATCH_COMMAND       - Patch command (as list, optional)
#   DEPENDS             - List of dependency targets (optional)
#   ENV_VARS            - Additional environment variables (as list, optional)
#                         Format: VAR1=value1 VAR2=value2
#                         These override/extend variables from BUILD_ENV
#   PATCH_DIR           - Directory containing patches (optional, defaults to cmake/patches/${NAME})
#
function(add_external_dependency)
    set(options "")
    set(oneValueArgs NAME VERSION URL URL_HASH ARCHIVE_NAME PATCH_DIR)
    set(multiValueArgs CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND
                       EXTRACT_COMMAND PATCH_COMMAND DEPENDS ENV_VARS)
    cmake_parse_arguments(DEP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required arguments
    if(NOT DEP_NAME)
        message(FATAL_ERROR "add_external_dependency: NAME is required")
    endif()
    if(NOT DEP_VERSION)
        message(FATAL_ERROR "add_external_dependency: VERSION is required for ${DEP_NAME}")
    endif()
    if(NOT DEP_URL)
        message(FATAL_ERROR "add_external_dependency: URL is required for ${DEP_NAME}")
    endif()

    # Set defaults
    if(NOT DEP_ARCHIVE_NAME)
        set(DEP_ARCHIVE_NAME "${DEP_NAME}-${DEP_VERSION}")
    endif()

    set(BUILD_DIR  "${CMAKE_BINARY_DIR}/${DEP_NAME}/build_dir/${TARGET_ARCH}-${PLATFORM_LOWER}")
    set(SOURCE_DIR "${CMAKE_BINARY_DIR}/${DEP_NAME}/build_dir/${DEP_ARCHIVE_NAME}")

    # Default build and install commands
    if(NOT DEP_BUILD_COMMAND)
        set(DEP_BUILD_COMMAND ${CMAKE_COMMAND} -E env ${BUILD_ENV} make -j${BUILD_PARALLEL_JOBS})
    endif()

    if(NOT DEP_INSTALL_COMMAND)
        set(DEP_INSTALL_COMMAND make install DESTDIR=${BUILD_STAGING_DIR})
    endif()

    # Build patch command using get_platform_patches
    set(PATCH_CMD "")
    
    # Determine base patch directory
    set(PATCH_BASE_DIR "")
    if(DEP_PATCH_DIR AND EXISTS "${DEP_PATCH_DIR}/${DEP_NAME}")
        set(PATCH_BASE_DIR "${DEP_PATCH_DIR}/${DEP_NAME}")
    elseif(DEFINED APP_DIR AND EXISTS "${APP_DIR}/patches/${DEP_NAME}")
        set(PATCH_BASE_DIR "${APP_DIR}/patches/${DEP_NAME}")
    endif()
    
    if(PATCH_BASE_DIR)
        
        # Get the list of patches to apply
        get_platform_patches(
            LIBRARY ${DEP_NAME}
            VERSION ${DEP_VERSION}
            PLATFORM ${PLATFORM_LOWER}
            PATCH_BASE "${PATCH_BASE_DIR}/.."
            OUTPUT_VAR PATCH_LIST
        )
        
        # Build command list from patches
        if(PATCH_LIST)
            set(PATCH_CMD ${CMAKE_COMMAND} -E echo "Applying patches for ${DEP_NAME} ${DEP_VERSION}...")
            
            foreach(PATCH_PATH ${PATCH_LIST})
                get_filename_component(PATCH_FILE "${PATCH_PATH}" NAME)
                list(APPEND PATCH_CMD COMMAND patch -p1 -i "${PATCH_PATH}")
                list(APPEND PATCH_CMD COMMAND ${CMAKE_COMMAND} -E echo "  Applied: ${PATCH_FILE}")
            endforeach()
        endif()
    endif()

    # Allow override with custom patch command
    if(DEP_PATCH_COMMAND)
        set(PATCH_CMD ${DEP_PATCH_COMMAND})
    endif()

    cmake_policy(SET CMP0135 OLD)

    # Create the ExternalProject
    ExternalProject_Add(${DEP_NAME}_external
        URL                 ${DEP_URL}
        URL_HASH            ${DEP_URL_HASH}
        DOWNLOAD_DIR        ${BUILD_DOWNLOAD_DIR}
        PREFIX              ${BUILD_DIR}
        SOURCE_DIR          ${SOURCE_DIR}
        STAMP_DIR           ${BUILD_DIR}/stamps
        TMP_DIR             ${BUILD_DIR}/tmp

        PATCH_COMMAND       ${PATCH_CMD}

        CONFIGURE_COMMAND   ${CMAKE_COMMAND} -E env ${BUILD_ENV} ${DEP_ENV_VARS}
                            ${DEP_CONFIGURE_COMMAND}

        BUILD_COMMAND       ${DEP_BUILD_COMMAND}
        BUILD_IN_SOURCE     TRUE

        INSTALL_COMMAND     ${CMAKE_COMMAND} -E env ${BUILD_ENV}
                            ${DEP_INSTALL_COMMAND}

        LOG_DOWNLOAD        TRUE
        LOG_CONFIGURE       TRUE
        LOG_BUILD           TRUE
        LOG_INSTALL         TRUE

        DEPENDS             ${DEP_DEPENDS}
    )

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
    set(oneValueArgs LIBRARY VERSION PLATFORM PATCH_BASE OUTPUT_VAR)
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

    set(COLLECTED_PATCHES "")

    foreach(SEARCH_PATH ${PATCH_SEARCH_PATHS})
        if(EXISTS "${SEARCH_PATH}/series")
            # Read patch series file
            file(STRINGS "${SEARCH_PATH}/series" PATCH_LIST)
            foreach(PATCH_FILE ${PATCH_LIST})
                string(STRIP "${PATCH_FILE}" PATCH_FILE)
                # Skip comments and empty lines
                if(NOT PATCH_FILE MATCHES "^#" AND NOT PATCH_FILE STREQUAL "")
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
# Creates a target to package the build output
#
# Parameters:
#   NAME        - Target name
#   OUTPUT      - Output filename
#   INCLUDES    - List of paths to include in archive
#   DEPENDS     - List of target dependencies
#   FORMAT      - Archive format (zip, tar.gz, etc.)
#
function(create_archive_target)
    set(options "")
    set(oneValueArgs NAME OUTPUT FORMAT)
    set(multiValueArgs INCLUDES DEPENDS)
    cmake_parse_arguments(ARCHIVE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

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
endfunction()

message(STATUS "Generic Build System loaded - NCPUS: ${BUILD_PARALLEL_JOBS}")
