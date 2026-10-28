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

# Find the critical encinit.o file (contains Init_enc() that registers all encodings)
# Ruby generates this when built with --with-static-linked-ext. It defines Init_enc()
# which calls ruby_init_ext() for each encoding, replacing the dummy dmyenc.o from
# libruby-static.a that would try (and fail) to load enc/*.so from disk.
set(ENCINIT_OBJ "${RUBY_SRC_DIR}/enc/encinit.o")
if(NOT EXISTS "${ENCINIT_OBJ}")
    message(FATAL_ERROR "encinit.o not found at ${ENCINIT_OBJ}. This file is required for static encoding initialization. Ensure Ruby was built with --with-static-linked-ext.")
endif()
message(STATUS "Found encinit.o: ${ENCINIT_OBJ}")

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

# fiddle and psych link libffi/libyaml with -lffi/-lyaml when they use the
# libraries this project builds (always on Ruby 3.2+, which no longer bundles
# them), instead of compiling bundled copies into their own archive. Fold those
# into libruby-ext.a too, so consumers link the same set of archives whatever
# the Ruby version. The decision comes from each extension's generated
# Makefile: the bundled sources stay in the 3.0/3.1 tree even when unused.
function(_ext_links_external_lib ext lib out_var)
    set(${out_var} FALSE PARENT_SCOPE)
    set(_makefile "${RUBY_SRC_DIR}/ext/${ext}/Makefile")
    if(NOT EXISTS "${_makefile}")
        message(FATAL_ERROR "${_makefile} not found: was ext/${ext} built?")
    endif()
    file(STRINGS "${_makefile}" _libs_line REGEX "^LIBS = ")
    if(_libs_line MATCHES "(^| )-l${lib}( |$)")
        set(${out_var} TRUE PARENT_SCOPE)
    endif()
endfunction()

foreach(_pair "fiddle|ffi|libffi" "psych|yaml|libyaml")
    string(REPLACE "|" ";" _pair "${_pair}")
    list(GET _pair 0 _ext)
    list(GET _pair 1 _lib)
    list(GET _pair 2 _archive)
    _ext_links_external_lib(${_ext} ${_lib} _external)
    if(_ext STREQUAL "fiddle" AND SEEN_LIBFFI)
        # Bundled libffi built as libffi_convenience.a, already included
        set(_external FALSE)
    endif()
    if(_external)
        if(NOT STAGING_LIB_DIR OR NOT EXISTS "${STAGING_LIB_DIR}/${_archive}.a")
            message(FATAL_ERROR "ext/${_ext} links -l${_lib} but there is no ${_archive}.a in STAGING_LIB_DIR='${STAGING_LIB_DIR}'")
        endif()
        message(STATUS "  Including external ${_archive}: ${STAGING_LIB_DIR}/${_archive}.a")
        list(APPEND ALL_EXT_LIBS "${STAGING_LIB_DIR}/${_archive}.a")
    else()
        message(STATUS "  ${_archive} is compiled into ext/${_ext} (bundled copy)")
    endif()
endforeach()

if(NOT ALL_EXT_LIBS)
    message(FATAL_ERROR "No extension .a files found in ${RUBY_SRC_DIR}")
endif()

message(STATUS "Found extension libraries:")
foreach(lib ${ALL_EXT_LIBS})
    file(RELATIVE_PATH rel_path "${RUBY_SRC_DIR}" "${lib}")
    message(STATUS "  - ${rel_path}")
endforeach()

# Create a temporary directory for extracting objects
set(TEMP_DIR "${RUBY_BUILD_DIR}/temp_ext_combine")
file(REMOVE_RECURSE "${TEMP_DIR}")
file(MAKE_DIRECTORY "${TEMP_DIR}")

# Add extinit.o and encinit.o to the objects list first (so they're at the beginning).
# encinit.o defines Init_enc() which shadows dmyenc.o's dummy Init_enc() from
# libruby-static.a, because libruby-ext.a is processed first in the fat library.
set(ALL_OBJECTS "${EXTINIT_OBJ}" "${ENCINIT_OBJ}")
message(STATUS "Including extinit.o for static extension initialization")
message(STATUS "Including encinit.o for static encoding initialization")

# Extract all .o files from each .a file into the temp directory.
# Archive and object names are not unique across extensions (Ruby 3.2+ has
# both ext/cgi/escape/escape.a and ext/erb/escape/escape.a, each with an
# escape.o), and `ar r` replaces a member of the same name: number every
# archive and prefix its objects with that number so none is lost.
set(lib_index 0)
foreach(ext_lib ${ALL_EXT_LIBS})
    math(EXPR lib_index "${lib_index} + 1")
    get_filename_component(lib_name "${ext_lib}" NAME_WE)
    set(extract_dir "${TEMP_DIR}/${lib_index}_${lib_name}")
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

    # Collect all .o files from this extraction, renamed to be unique
    file(GLOB objects "${extract_dir}/*.o")
    foreach(obj ${objects})
        get_filename_component(obj_name "${obj}" NAME)
        set(unique_obj "${extract_dir}/${lib_index}_${obj_name}")
        file(RENAME "${obj}" "${unique_obj}")
        list(APPEND ALL_OBJECTS "${unique_obj}")
    endforeach()
endforeach()

if(NOT ALL_OBJECTS)
    message(FATAL_ERROR "No object files extracted from extension libraries")
endif()

list(LENGTH ALL_OBJECTS total_objects)
message(STATUS "Total object files to combine: ${total_objects}")

# Create the combined archive
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
