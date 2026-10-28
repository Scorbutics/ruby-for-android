# PlatformPatches.cmake
# Patch selection for external dependencies. Kept free of ExternalProject so
# that script-mode checks (cmake -P) can include it.

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
    # 2. Platform + minor version specific: patches/{library}/{platform}/{major.minor}/
    # 3. Platform specific: patches/{library}/{platform}/
    # 4. Version specific: patches/{library}/{version}/
    # 5. Minor version specific: patches/{library}/{major.minor}/
    # 6. Common: patches/{library}/common/
    #
    # A series file entry may carry conditions after the file name, e.g.
    # "file.patch [static]" or "file.patch [>=3.1]": a build type (shared,
    # static) or a version comparison (<, <=, >, >=, ==) against VERSION.

    set(PATCH_SEARCH_PATHS "${PATCH_BASE}/${PATCH_PLATFORM}/${PATCH_VERSION}")
    set(PATCH_MINOR_VERSION "")
    if(PATCH_VERSION MATCHES "^([0-9]+\\.[0-9]+)\\.")
        set(PATCH_MINOR_VERSION "${CMAKE_MATCH_1}")
        list(APPEND PATCH_SEARCH_PATHS "${PATCH_BASE}/${PATCH_PLATFORM}/${PATCH_MINOR_VERSION}")
    endif()
    list(APPEND PATCH_SEARCH_PATHS
        "${PATCH_BASE}/${PATCH_PLATFORM}"
        "${PATCH_BASE}/${PATCH_VERSION}"
    )
    if(PATCH_MINOR_VERSION)
        list(APPEND PATCH_SEARCH_PATHS "${PATCH_BASE}/${PATCH_MINOR_VERSION}")
    endif()
    list(APPEND PATCH_SEARCH_PATHS "${PATCH_BASE}/common")

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
                    # Parse optional conditions: "file.patch [static] [>=3.1]"
                    set(PATCH_CONDITIONS "")
                    while(PATCH_FILE MATCHES "^(.+[^ \t])[ \t]+\\[([a-zA-Z0-9.<>=]+)\\]$")
                        set(PATCH_FILE "${CMAKE_MATCH_1}")
                        list(APPEND PATCH_CONDITIONS "${CMAKE_MATCH_2}")
                    endwhile()

                    # Skip patch if any condition doesn't match
                    set(PATCH_SKIP "")
                    foreach(PATCH_CONDITION ${PATCH_CONDITIONS})
                        if(PATCH_CONDITION MATCHES "^(<=|>=|==|<|>)[ \t]*([0-9.]+)$")
                            set(_OP "${CMAKE_MATCH_1}")
                            set(_WANT "${CMAKE_MATCH_2}")
                            set(_OK FALSE)
                            if((_OP STREQUAL "<"  AND PATCH_VERSION VERSION_LESS _WANT) OR
                               (_OP STREQUAL "<=" AND PATCH_VERSION VERSION_LESS_EQUAL _WANT) OR
                               (_OP STREQUAL ">"  AND PATCH_VERSION VERSION_GREATER _WANT) OR
                               (_OP STREQUAL ">=" AND PATCH_VERSION VERSION_GREATER_EQUAL _WANT) OR
                               (_OP STREQUAL "==" AND PATCH_VERSION VERSION_EQUAL _WANT))
                                set(_OK TRUE)
                            endif()
                            if(NOT _OK)
                                set(PATCH_SKIP "version ${PATCH_VERSION}")
                            endif()
                        elseif(PATCH_CONDITION MATCHES "^(shared|static)$")
                            if(PATCH_BUILD_TYPE AND NOT PATCH_CONDITION STREQUAL PATCH_BUILD_TYPE)
                                set(PATCH_SKIP "build type: ${PATCH_BUILD_TYPE}")
                            endif()
                        else()
                            message(FATAL_ERROR "Unknown patch condition [${PATCH_CONDITION}] for ${PATCH_FILE} in ${SEARCH_PATH}/series")
                        endif()
                    endforeach()
                    if(PATCH_SKIP)
                        message(STATUS "    Skipping ${PATCH_FILE} (conditions [${PATCH_CONDITIONS}], ${PATCH_SKIP})")
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
