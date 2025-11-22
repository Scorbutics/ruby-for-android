# RubyBuildHelpers.cmake
# Common build helper functions for cross-compiling Ruby and dependencies

include(ExternalProject)

# Global configuration
set(RUBY_BUILD_DOWNLOAD_DIR "${CMAKE_BINARY_DIR}/download" CACHE PATH "Download directory for sources")
set(RUBY_BUILD_STAGING_DIR "${CMAKE_BINARY_DIR}/target" CACHE PATH "Staging directory for installation")

file(MAKE_DIRECTORY "${RUBY_BUILD_DOWNLOAD_DIR}")
file(MAKE_DIRECTORY "${RUBY_BUILD_STAGING_DIR}")

# Set number of parallel jobs for builds
include(ProcessorCount)
ProcessorCount(NCPUS)
if(NCPUS EQUAL 0)
    set(NCPUS 1)
endif()
set(RUBY_BUILD_PARALLEL_JOBS ${NCPUS} CACHE STRING "Number of parallel build jobs")

#
# add_native_dependency()
#
# Adds a native library dependency using ExternalProject
#
# Parameters:
#   NAME                - Name of the dependency (e.g., "openssl", "ruby")
#   VERSION             - Version string (e.g., "1.1.1m")
#   URL                 - Download URL
#   URL_HASH            - Hash for verification (e.g., "SHA256=...")
#   CONFIGURE_COMMAND   - Configure command (as list)
#   BUILD_COMMAND       - Build command (as list, optional - defaults to make)
#   INSTALL_COMMAND     - Install command (as list, optional - defaults to make install)
#   EXTRACT_COMMAND     - Custom extract command (optional)
#   PATCH_COMMAND       - Patch command (as list, optional)
#   DEPENDS             - List of dependency targets (optional)
#
function(add_native_dependency)
    set(options "")
    set(oneValueArgs NAME VERSION URL URL_HASH ARCHIVE_NAME)
    set(multiValueArgs CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND
                       EXTRACT_COMMAND PATCH_COMMAND DEPENDS)
    cmake_parse_arguments(DEP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required arguments
    if(NOT DEP_NAME)
        message(FATAL_ERROR "add_native_dependency: NAME is required")
    endif()
    if(NOT DEP_VERSION)
        message(FATAL_ERROR "add_native_dependency: VERSION is required for ${DEP_NAME}")
    endif()
    if(NOT DEP_URL)
        message(FATAL_ERROR "add_native_dependency: URL is required for ${DEP_NAME}")
    endif()

    # Set defaults
    if(NOT DEP_ARCHIVE_NAME)
        set(DEP_ARCHIVE_NAME "${DEP_NAME}-${DEP_VERSION}")
    endif()

    set(BUILD_DIR "${CMAKE_BINARY_DIR}/${DEP_NAME}/build_dir")
    set(SOURCE_DIR "${BUILD_DIR}/${DEP_ARCHIVE_NAME}")

    # Default build and install commands
    if(NOT DEP_BUILD_COMMAND)
        set(DEP_BUILD_COMMAND ${CMAKE_COMMAND} -E env ${RUBY_BUILD_ENV} make -j${RUBY_BUILD_PARALLEL_JOBS})
    endif()

    if(NOT DEP_INSTALL_COMMAND)
        set(DEP_INSTALL_COMMAND make install DESTDIR=${RUBY_BUILD_STAGING_DIR})
    endif()

    # Apply platform-specific patches if available
    set(PATCH_DIRS "")
    if(EXISTS "${CMAKE_SOURCE_DIR}/ruby-build/${DEP_NAME}/patches-${DEP_VERSION}")
        list(APPEND PATCH_DIRS "${CMAKE_SOURCE_DIR}/ruby-build/${DEP_NAME}/patches-${DEP_VERSION}")
    endif()
    if(EXISTS "${CMAKE_SOURCE_DIR}/ruby-build/${DEP_NAME}/patches")
        list(APPEND PATCH_DIRS "${CMAKE_SOURCE_DIR}/ruby-build/${DEP_NAME}/patches")
    endif()

    # Build patch command
    set(PATCH_CMD "")
    if(PATCH_DIRS)
        set(PATCH_CMD ${CMAKE_COMMAND} -E echo "Applying patches for ${DEP_NAME}...")
        foreach(PATCH_DIR ${PATCH_DIRS})
            file(GLOB PATCHES "${PATCH_DIR}/*.patch")
            foreach(PATCH ${PATCHES})
                list(APPEND PATCH_CMD COMMAND patch -p1 -i "${PATCH}")
            endforeach()
        endforeach()
    endif()

    # Allow override with custom patch command
    if(DEP_PATCH_COMMAND)
        set(PATCH_CMD ${DEP_PATCH_COMMAND})
    endif()

    # Create the ExternalProject
    ExternalProject_Add(${DEP_NAME}_external
        URL                 ${DEP_URL}
        URL_HASH            ${DEP_URL_HASH}
        DOWNLOAD_DIR        ${RUBY_BUILD_DOWNLOAD_DIR}
        PREFIX              ${BUILD_DIR}
        SOURCE_DIR          ${SOURCE_DIR}
        STAMP_DIR           ${BUILD_DIR}/stamps
        TMP_DIR             ${BUILD_DIR}/tmp

        PATCH_COMMAND       ${PATCH_CMD}

        CONFIGURE_COMMAND   ${CMAKE_COMMAND} -E env ${RUBY_BUILD_ENV}
                            ${DEP_CONFIGURE_COMMAND}

        BUILD_COMMAND       ${DEP_BUILD_COMMAND}
        BUILD_IN_SOURCE     TRUE

        INSTALL_COMMAND     ${CMAKE_COMMAND} -E env ${RUBY_BUILD_ENV}
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
# set_cross_compile_environment()
#
# Sets up environment variables for cross-compilation
# Creates RUBY_BUILD_ENV list that can be used with ExternalProject
#
function(set_cross_compile_environment)
    # This will be populated by platform modules
    # Platform modules should append to RUBY_BUILD_ENV
    set(RUBY_BUILD_ENV "" PARENT_SCOPE)
endfunction()

#
# apply_platform_patches()
#
# Helper to apply platform-specific patches in order
#
# Parameters:
#   LIBRARY     - Library name (e.g., "ruby", "openssl")
#   VERSION     - Library version
#   PLATFORM    - Platform name (e.g., "android", "ios")
#   SOURCE_DIR  - Source directory to patch
#
function(apply_platform_patches)
    set(options "")
    set(oneValueArgs LIBRARY VERSION PLATFORM SOURCE_DIR)
    set(multiValueArgs "")
    cmake_parse_arguments(PATCH "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(PATCH_BASE "${CMAKE_SOURCE_DIR}/cmake/patches/${PATCH_LIBRARY}")

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
                        message(STATUS "Applying patch: ${PATCH_FILE}")
                        execute_process(
                            COMMAND patch -p1 -i "${PATCH_PATH}"
                            WORKING_DIRECTORY "${PATCH_SOURCE_DIR}"
                            RESULT_VARIABLE PATCH_RESULT
                        )
                        if(NOT PATCH_RESULT EQUAL 0)
                            message(WARNING "Failed to apply patch: ${PATCH_FILE}")
                        endif()
                    endif()
                endif()
            endforeach()
        else
            # No series file, apply all .patch files in alphabetical order
            file(GLOB PATCHES "${SEARCH_PATH}/*.patch")
            list(SORT PATCHES)
            foreach(PATCH_PATH ${PATCHES})
                get_filename_component(PATCH_FILE "${PATCH_PATH}" NAME)
                message(STATUS "Applying patch: ${PATCH_FILE}")
                execute_process(
                    COMMAND patch -p1 -i "${PATCH_PATH}"
                    WORKING_DIRECTORY "${PATCH_SOURCE_DIR}"
                    RESULT_VARIABLE PATCH_RESULT
                )
                if(NOT PATCH_RESULT EQUAL 0)
                    message(WARNING "Failed to apply patch: ${PATCH_FILE}")
                endif()
            endforeach()
        endif()
    endforeach()
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
#   FORMAT      - Archive format (zip, tar.gz, etc.)
#
function(create_archive_target)
    set(options "")
    set(oneValueArgs NAME OUTPUT FORMAT)
    set(multiValueArgs INCLUDES)
    cmake_parse_arguments(ARCHIVE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARCHIVE_FORMAT)
        set(ARCHIVE_FORMAT "zip")
    endif()

    if(ARCHIVE_FORMAT STREQUAL "zip")
        add_custom_target(${ARCHIVE_NAME}
            COMMAND zip -q --symlinks -r ${ARCHIVE_OUTPUT} ${ARCHIVE_INCLUDES}
            WORKING_DIRECTORY ${RUBY_BUILD_STAGING_DIR}
            COMMENT "Creating archive: ${ARCHIVE_OUTPUT}"
        )
    elseif(ARCHIVE_FORMAT STREQUAL "tar.gz")
        add_custom_target(${ARCHIVE_NAME}
            COMMAND tar czf ${ARCHIVE_OUTPUT} ${ARCHIVE_INCLUDES}
            WORKING_DIRECTORY ${RUBY_BUILD_STAGING_DIR}
            COMMENT "Creating archive: ${ARCHIVE_OUTPUT}"
        )
    else()
        message(FATAL_ERROR "Unsupported archive format: ${ARCHIVE_FORMAT}")
    endif()
endfunction()

message(STATUS "RubyBuildHelpers loaded - NCPUS: ${RUBY_BUILD_PARALLEL_JOBS}")
