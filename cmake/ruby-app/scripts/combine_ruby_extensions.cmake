# combine_ruby_extensions.cmake
# Script to combine all Ruby extension .a files into a single libruby-ext.a
#
# Required variables:
#   RUBY_BUILD_DIR - Ruby build directory
#   RUBY_VERSION   - Ruby version (e.g., 3.1.1)
#   OUTPUT_LIB     - Output library path (libruby-ext.a)
#   CROSS_AR       - AR tool for creating archives

if(NOT RUBY_BUILD_DIR OR NOT RUBY_VERSION OR NOT OUTPUT_LIB OR NOT CROSS_AR)
    message(FATAL_ERROR "Missing required variables for combine_ruby_extensions.cmake")
endif()

# Find the Ruby source directory within the build directory
set(RUBY_SRC_DIR "${RUBY_BUILD_DIR}/ruby-${RUBY_VERSION}")

if(NOT EXISTS "${RUBY_SRC_DIR}")
    message(FATAL_ERROR "Ruby source directory not found: ${RUBY_SRC_DIR}")
endif()

message(STATUS "Scanning for Ruby extension .a files in: ${RUBY_SRC_DIR}")

# Find the critical extinit.o file (contains Init_ext() that registers all extensions)
set(EXTINIT_OBJ "${RUBY_SRC_DIR}/ext/extinit.o")
if(NOT EXISTS "${EXTINIT_OBJ}")
    message(FATAL_ERROR "extinit.o not found at ${EXTINIT_OBJ}. This file is required for static extension initialization.")
endif()
message(STATUS "Found extinit.o: ${EXTINIT_OBJ}")

# Find all extension .a files
# Extensions are typically in ext/ and enc/ directories
file(GLOB_RECURSE EXT_LIBS_ENC "${RUBY_SRC_DIR}/enc/*.a")
file(GLOB_RECURSE EXT_LIBS_EXT "${RUBY_SRC_DIR}/ext/*.a")

# Combine the lists
set(ALL_EXT_LIBS ${EXT_LIBS_ENC} ${EXT_LIBS_EXT})

# Filter out duplicate internal libraries
# libffi is built as both libffi.a and libffi_convenience.a
# We only need one of them (the convenience library is the one used by fiddle)
set(FILTERED_EXT_LIBS "")
set(SEEN_LIBFFI FALSE)
foreach(lib ${ALL_EXT_LIBS})
    get_filename_component(lib_name "${lib}" NAME)

    # For libffi, only include libffi_convenience.a (skip libffi.a to avoid duplicates)
    if(lib_name STREQUAL "libffi.a")
        message(STATUS "  Skipping duplicate: ${lib_name} (using libffi_convenience.a instead)")
    else()
        if(lib_name STREQUAL "libffi_convenience.a")
            set(SEEN_LIBFFI TRUE)
            message(STATUS "  Including libffi implementation: ${lib_name}")
        endif()
        list(APPEND FILTERED_EXT_LIBS "${lib}")
    endif()
endforeach()

# Use the filtered list
set(ALL_EXT_LIBS ${FILTERED_EXT_LIBS})

if(NOT ALL_EXT_LIBS)
    message(FATAL_ERROR "No extension .a files found in ${RUBY_SRC_DIR}")
endif()

message(STATUS "Found ${CMAKE_MATCH_COUNT} extension libraries:")
foreach(lib ${ALL_EXT_LIBS})
    file(RELATIVE_PATH rel_path "${RUBY_SRC_DIR}" "${lib}")
    message(STATUS "  - ${rel_path}")
endforeach()

# Create a temporary directory for extracting objects
set(TEMP_DIR "${RUBY_BUILD_DIR}/temp_ext_combine")
file(REMOVE_RECURSE "${TEMP_DIR}")
file(MAKE_DIRECTORY "${TEMP_DIR}")

# Add extinit.o to the objects list first (so it's at the beginning)
set(ALL_OBJECTS "${EXTINIT_OBJ}")
message(STATUS "Including extinit.o for static extension initialization")

# Extract all .o files from each .a file into the temp directory
foreach(ext_lib ${ALL_EXT_LIBS})
    # Get the library name for creating a unique subdirectory
    get_filename_component(lib_name "${ext_lib}" NAME_WE)
    set(extract_dir "${TEMP_DIR}/${lib_name}")
    file(MAKE_DIRECTORY "${extract_dir}")

    # Extract objects from this archive
    execute_process(
        COMMAND ${CROSS_AR} x "${ext_lib}"
        WORKING_DIRECTORY "${extract_dir}"
        RESULT_VARIABLE ar_result
    )

    if(NOT ar_result EQUAL 0)
        message(FATAL_ERROR "Failed to extract objects from ${ext_lib}")
    endif()

    # Collect all .o files from this extraction
    file(GLOB objects "${extract_dir}/*.o")
    list(APPEND ALL_OBJECTS ${objects})
endforeach()

if(NOT ALL_OBJECTS)
    message(FATAL_ERROR "No object files extracted from extension libraries")
endif()

message(STATUS "Extracted ${CMAKE_MATCH_COUNT} object files")

# Create the combined archive
# We need to create it in the temp directory first to use relative paths
get_filename_component(OUTPUT_DIR "${OUTPUT_LIB}" DIRECTORY)
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

# Create a list file with all objects (to avoid command line length limits)
set(OBJECTS_LIST_FILE "${TEMP_DIR}/objects.txt")
file(WRITE "${OBJECTS_LIST_FILE}" "")
foreach(obj ${ALL_OBJECTS})
    file(APPEND "${OBJECTS_LIST_FILE}" "${obj}\n")
endforeach()

# Create the combined archive using ar
# Use 'ar crs' (create, replace, index) with all object files
execute_process(
    COMMAND ${CROSS_AR} crs "${OUTPUT_LIB}" ${ALL_OBJECTS}
    WORKING_DIRECTORY "${TEMP_DIR}"
    RESULT_VARIABLE ar_result
    OUTPUT_VARIABLE ar_output
    ERROR_VARIABLE ar_error
)

if(NOT ar_result EQUAL 0)
    message(FATAL_ERROR "Failed to create combined library ${OUTPUT_LIB}\nError: ${ar_error}")
endif()

# Verify the output exists
if(NOT EXISTS "${OUTPUT_LIB}")
    message(FATAL_ERROR "Combined library was not created: ${OUTPUT_LIB}")
endif()

# Get the file size
file(SIZE "${OUTPUT_LIB}" lib_size)
math(EXPR lib_size_kb "${lib_size} / 1024")

message(STATUS "Successfully created libruby-ext.a (${lib_size_kb} KB) at: ${OUTPUT_LIB}")

# Cleanup temp directory
file(REMOVE_RECURSE "${TEMP_DIR}")
