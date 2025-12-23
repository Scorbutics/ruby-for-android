# create_ruby_archive.cmake
# Custom script to create the restructured Ruby archive
#
# Required variables:
#   BUILD_STAGING_DIR    - Directory containing the installed files
#   HOST_TRIPLET         - Host triplet (e.g., aarch64-linux-android, x86_64-linux-gnu)
#   PLATFORM_LOWER       - Platform name in lowercase (e.g., android, linux)
#   BUILD_SHARED_LIBS    - ON for shared, OFF for static
#   ARCHIVE_OUTPUT       - Output archive path
#   RUBY_VERSION         - Ruby version (e.g., 3.1.1)
#   RUBY_ABI_VERSION     - Ruby ABI version (e.g., 3.1.0)

cmake_minimum_required(VERSION 3.10)

# Validate required variables
foreach(VAR BUILD_STAGING_DIR HOST_TRIPLET PLATFORM_LOWER ARCHIVE_OUTPUT RUBY_VERSION RUBY_ABI_VERSION)
    if(NOT DEFINED ${VAR})
        message(FATAL_ERROR "create_ruby_archive.cmake: ${VAR} is required")
    endif()
endforeach()

# Determine build type suffix
if(BUILD_SHARED_LIBS)
    set(BUILD_TYPE "shared")
    set(LIB_EXTENSION "so")
else()
    set(BUILD_TYPE "static")
    set(LIB_EXTENSION "a")
endif()

message(STATUS "Creating Ruby archive: ${ARCHIVE_OUTPUT}")
message(STATUS "  Platform: ${PLATFORM_LOWER}")
message(STATUS "  Host triplet: ${HOST_TRIPLET}")
message(STATUS "  Build type: ${BUILD_TYPE}")

# Create temporary directory for archive staging
set(ARCHIVE_STAGING_DIR "${CMAKE_BINARY_DIR}/archive_staging")
file(REMOVE_RECURSE "${ARCHIVE_STAGING_DIR}")
file(MAKE_DIRECTORY "${ARCHIVE_STAGING_DIR}")

# Step 1: Detect RUBY_PLATFORM_LOWER from config.h
set(CONFIG_H_PATH "${BUILD_STAGING_DIR}/usr/local/include/ruby-${RUBY_ABI_VERSION}")

# Find the platform-specific directory
file(GLOB PLATFORM_DIRS "${CONFIG_H_PATH}/*-${PLATFORM_LOWER}*")
if(NOT PLATFORM_DIRS)
    message(FATAL_ERROR "Could not find platform-specific include directory in ${CONFIG_H_PATH}")
endif()

# Get the first match (should only be one)
list(GET PLATFORM_DIRS 0 PLATFORM_DIR)
get_filename_component(RUBY_PLATFORM_LOWER "${PLATFORM_DIR}" NAME)

set(CONFIG_H "${PLATFORM_DIR}/ruby/config.h")
if(NOT EXISTS "${CONFIG_H}")
    message(FATAL_ERROR "Could not find config.h at ${CONFIG_H}")
endif()

# Read config.h and extract RUBY_PLATFORM
file(READ "${CONFIG_H}" CONFIG_H_CONTENT)
string(REGEX MATCH "#define RUBY_PLATFORM \"([^\"]+)\"" RUBY_PLATFORM_MATCH "${CONFIG_H_CONTENT}")
if(NOT RUBY_PLATFORM_MATCH)
    message(FATAL_ERROR "Could not find RUBY_PLATFORM definition in ${CONFIG_H}")
endif()

set(RUBY_PLATFORM_LOWER "${CMAKE_MATCH_1}")
message(STATUS "  Ruby platform: ${RUBY_PLATFORM_LOWER}")

# Step 2: Create directory structure
set(LIB_DIR "${ARCHIVE_STAGING_DIR}/external/lib/${HOST_TRIPLET}/${BUILD_TYPE}")
set(INCLUDE_DIR "${ARCHIVE_STAGING_DIR}/external/include")
set(PLATFORM_INCLUDE_DIR "${ARCHIVE_STAGING_DIR}/external/include/${HOST_TRIPLET}/${BUILD_TYPE}")
set(ASSETS_DIR "${ARCHIVE_STAGING_DIR}/assets/files")
set(PLATFORM_ASSETS_DIR "${ARCHIVE_STAGING_DIR}/assets/files/${HOST_TRIPLET}/${BUILD_TYPE}")

file(MAKE_DIRECTORY "${LIB_DIR}")
file(MAKE_DIRECTORY "${INCLUDE_DIR}")
file(MAKE_DIRECTORY "${PLATFORM_INCLUDE_DIR}")
file(MAKE_DIRECTORY "${ASSETS_DIR}")
file(MAKE_DIRECTORY "${PLATFORM_ASSETS_DIR}")

# Step 3: Copy libraries (excluding libcurses.a which is just a redirect file)
message(STATUS "Copying libraries...")

# Copy dependency libraries from usr/lib
file(GLOB DEPENDENCY_LIBS
    "${BUILD_STAGING_DIR}/usr/lib/lib*.${LIB_EXTENSION}"
    "${BUILD_STAGING_DIR}/usr/lib/lib*.${LIB_EXTENSION}.*"
)
foreach(LIB ${DEPENDENCY_LIBS})
    get_filename_component(LIB_NAME "${LIB}" NAME)
    # Skip libcurses.a (it's a text file redirect to libncurses.a)
    if(NOT LIB_NAME STREQUAL "libcurses.a")
        file(COPY "${LIB}" DESTINATION "${LIB_DIR}")
        message(STATUS "  Copied: ${LIB_NAME}")
    else()
        message(STATUS "  Skipped: ${LIB_NAME} (redirect file)")
    endif()
endforeach()

# Copy Ruby libraries from usr/local/lib
file(GLOB RUBY_LIBS
    "${BUILD_STAGING_DIR}/usr/local/lib/lib*.${LIB_EXTENSION}"
    "${BUILD_STAGING_DIR}/usr/local/lib/lib*.${LIB_EXTENSION}.*"
)
foreach(LIB ${RUBY_LIBS})
    get_filename_component(LIB_NAME "${LIB}" NAME)
    # Skip libcurses.a (it's a text file redirect to libncurses.a)
    if(NOT LIB_NAME STREQUAL "libcurses.a")
        file(COPY "${LIB}" DESTINATION "${LIB_DIR}")
        message(STATUS "  Copied: ${LIB_NAME}")
    else()
        message(STATUS "  Skipped: ${LIB_NAME} (redirect file)")
    endif()
endforeach()

# Step 4: Copy generic Ruby includes (without platform-specific directory)
# Only skip the exact RUBY_PLATFORM_LOWER, but also skip any other platform-specific directories
# Platform directories typically match patterns like: x86_64-*, aarch64-*, arm*, i686-*, etc.
message(STATUS "Copying generic Ruby includes...")
set(RUBY_INCLUDE_BASE "${BUILD_STAGING_DIR}/usr/local/include/ruby-${RUBY_ABI_VERSION}")

file(GLOB GENERIC_INCLUDE_ENTRIES "${RUBY_INCLUDE_BASE}/*")
foreach(ENTRY ${GENERIC_INCLUDE_ENTRIES})
    get_filename_component(ENTRY_NAME "${ENTRY}" NAME)
    # Skip all platform-specific directories (they contain hyphens and match arch patterns)
    # Keep only generic directories like "ruby" and files
    if(ENTRY_NAME MATCHES "^(x86_64|aarch64|arm|i686|powerpc|riscv|mips|s390)-")
        message(STATUS "  Skipped platform-specific: ${ENTRY_NAME}")
    else()
        if(IS_DIRECTORY "${ENTRY}")
            file(COPY "${ENTRY}/" DESTINATION "${INCLUDE_DIR}/${ENTRY_NAME}")
        else()
            file(COPY "${ENTRY}" DESTINATION "${INCLUDE_DIR}")
        endif()
        message(STATUS "  Copied: ${ENTRY_NAME}")
    endif()
endforeach()

# Step 5: Copy platform-specific Ruby includes
# Only copy the exact RUBY_PLATFORM_LOWER directory (e.g., x86_64-linux-gnu)
# not intermediate directories (e.g., x86_64-linux)
message(STATUS "Copying platform-specific Ruby includes...")
set(PLATFORM_INCLUDE_SRC "${RUBY_INCLUDE_BASE}/${RUBY_PLATFORM_LOWER}")
if(EXISTS "${PLATFORM_INCLUDE_SRC}" AND IS_DIRECTORY "${PLATFORM_INCLUDE_SRC}")
    file(COPY "${PLATFORM_INCLUDE_SRC}/" DESTINATION "${PLATFORM_INCLUDE_DIR}")
    message(STATUS "  Copied platform includes from ${RUBY_PLATFORM_LOWER}/")
else()
    message(WARNING "Platform-specific include directory not found: ${PLATFORM_INCLUDE_SRC}")
endif()

# Step 6: Copy extra includes (right now, only zlib ones)
message(STATUS "Copying extra includes...")
set(EXTRA_INCLUDE_BASE "${BUILD_STAGING_DIR}/usr/local/include")
set(EXTRA_INCLUDE_ENTRIES 
    ${EXTRA_INCLUDE_BASE}/zlib.h 
    ${EXTRA_INCLUDE_BASE}/zconf.h
)
foreach(ENTRY ${EXTRA_INCLUDE_ENTRIES})
    get_filename_component(ENTRY_NAME "${ENTRY}" NAME)
    file(COPY "${ENTRY}" DESTINATION "${INCLUDE_DIR}")
    message(STATUS "  Copied: ${ENTRY_NAME}")
endforeach()

# Step 7: Create ruby-stdlib-ext.zip (platform-specific extensions)
message(STATUS "Creating ruby-stdlib-ext.zip...")
set(RUBY_STDLIB_EXT_DIR "${BUILD_STAGING_DIR}/usr/local/lib/ruby/${RUBY_ABI_VERSION}/${RUBY_PLATFORM_LOWER}")

if(EXISTS "${RUBY_STDLIB_EXT_DIR}")
    # Create temporary directory for the archive
    set(TEMP_STDLIB_EXT_DIR "${CMAKE_BINARY_DIR}/temp_stdlib_ext")
    file(REMOVE_RECURSE "${TEMP_STDLIB_EXT_DIR}")
    file(MAKE_DIRECTORY "${TEMP_STDLIB_EXT_DIR}/ruby/${RUBY_ABI_VERSION}")

    # Copy to temporary location with full path
    file(COPY "${RUBY_STDLIB_EXT_DIR}" DESTINATION "${TEMP_STDLIB_EXT_DIR}/ruby/${RUBY_ABI_VERSION}")

    # Create zip archive
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E tar cf "${PLATFORM_ASSETS_DIR}/ruby-stdlib-ext.zip" --format=zip ruby
        WORKING_DIRECTORY "${TEMP_STDLIB_EXT_DIR}"
        RESULT_VARIABLE ZIP_RESULT
    )

    if(NOT ZIP_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to create ruby-stdlib-ext.zip")
    endif()

    # Clean up
    file(REMOVE_RECURSE "${TEMP_STDLIB_EXT_DIR}")
    message(STATUS "  Created ruby-stdlib-ext.zip")
else()
    message(WARNING "Platform-specific stdlib directory not found: ${RUBY_STDLIB_EXT_DIR}")
endif()

# Step 8: Create ruby-stdlib.zip (generic Ruby stdlib)
message(STATUS "Creating ruby-stdlib.zip...")
set(RUBY_STDLIB_DIR "${BUILD_STAGING_DIR}/usr/local/lib/ruby")

# Create temporary directory for the archive
set(TEMP_STDLIB_DIR "${CMAKE_BINARY_DIR}/temp_stdlib")
file(REMOVE_RECURSE "${TEMP_STDLIB_DIR}")
file(MAKE_DIRECTORY "${TEMP_STDLIB_DIR}/ruby")

# Copy all content from ruby directory, excluding platform-specific subdirectory
file(GLOB RUBY_STDLIB_ENTRIES "${RUBY_STDLIB_DIR}/*")
foreach(ENTRY ${RUBY_STDLIB_ENTRIES})
    get_filename_component(ENTRY_NAME "${ENTRY}" NAME)

    # Check if this is the version directory
    if(ENTRY_NAME STREQUAL "${RUBY_ABI_VERSION}")
        # Copy version directory but exclude ALL platform-specific subdirectories
        file(MAKE_DIRECTORY "${TEMP_STDLIB_DIR}/ruby/${RUBY_ABI_VERSION}")

        file(GLOB VERSION_ENTRIES "${ENTRY}/*")
        foreach(VERSION_ENTRY ${VERSION_ENTRIES})
            get_filename_component(VERSION_ENTRY_NAME "${VERSION_ENTRY}" NAME)

            # Skip ALL platform-specific directories (match arch patterns)
            if(VERSION_ENTRY_NAME MATCHES "^(x86_64|aarch64|arm|i686|powerpc|riscv|mips|s390)-")
                # Skip platform-specific directory from previous or current builds
            else()
                if(IS_DIRECTORY "${VERSION_ENTRY}")
                    file(COPY "${VERSION_ENTRY}/" DESTINATION "${TEMP_STDLIB_DIR}/ruby/${RUBY_ABI_VERSION}/${VERSION_ENTRY_NAME}")
                else()
                    file(COPY "${VERSION_ENTRY}" DESTINATION "${TEMP_STDLIB_DIR}/ruby/${RUBY_ABI_VERSION}")
                endif()
            endif()
        endforeach()
    else()
        # Copy other entries as-is
        if(IS_DIRECTORY "${ENTRY}")
            file(COPY "${ENTRY}/" DESTINATION "${TEMP_STDLIB_DIR}/ruby/${ENTRY_NAME}")
        else()
            file(COPY "${ENTRY}" DESTINATION "${TEMP_STDLIB_DIR}/ruby")
        endif()
    endif()
endforeach()

# Create zip archive
execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar cf "${ASSETS_DIR}/ruby-stdlib.zip" --format=zip ruby
    WORKING_DIRECTORY "${TEMP_STDLIB_DIR}"
    RESULT_VARIABLE ZIP_RESULT
)

if(NOT ZIP_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create ruby-stdlib.zip")
endif()

# Clean up
file(REMOVE_RECURSE "${TEMP_STDLIB_DIR}")
message(STATUS "  Created ruby-stdlib.zip")

# Step 9: Create final archive
message(STATUS "Creating final archive...")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar cf "${ARCHIVE_OUTPUT}" --format=zip external assets
    WORKING_DIRECTORY "${ARCHIVE_STAGING_DIR}"
    RESULT_VARIABLE ZIP_RESULT
)

if(NOT ZIP_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create final archive: ${ARCHIVE_OUTPUT}")
endif()

# Clean up staging directory
file(REMOVE_RECURSE "${ARCHIVE_STAGING_DIR}")

message(STATUS "Successfully created: ${ARCHIVE_OUTPUT}")
