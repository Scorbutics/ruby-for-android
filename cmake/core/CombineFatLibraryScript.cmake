# CombineFatLibraryScript.cmake
# Script wrapper to call the combine_fat_library function from command line

# Include the function definition
include(${CMAKE_CURRENT_LIST_DIR}/CombineFatLibrary.cmake)

# Parse command-line arguments
if(NOT DEFINED COMBINE_OUTPUT)
    message(FATAL_ERROR "COMBINE_OUTPUT must be defined")
endif()

if(NOT DEFINED COMBINE_LIBS)
    message(FATAL_ERROR "COMBINE_LIBS must be defined")
endif()

if(NOT DEFINED COMBINE_AR)
    message(FATAL_ERROR "COMBINE_AR must be defined")
endif()

if(NOT DEFINED COMBINE_RANLIB)
    message(FATAL_ERROR "COMBINE_RANLIB must be defined")
endif()

if(NOT DEFINED COMBINE_NM)
    message(FATAL_ERROR "COMBINE_NM must be defined")
endif()

# Set CMAKE_AR, CMAKE_RANLIB, CMAKE_NM, and CMAKE_OBJCOPY for the function
set(CMAKE_AR "${COMBINE_AR}")
set(CMAKE_RANLIB "${COMBINE_RANLIB}")
set(CMAKE_NM "${COMBINE_NM}")
if(DEFINED COMBINE_OBJCOPY AND NOT "${COMBINE_OBJCOPY}" STREQUAL "")
    set(CMAKE_OBJCOPY "${COMBINE_OBJCOPY}")
else()
    # Fallback: try to find objcopy on the system
    find_program(CMAKE_OBJCOPY NAMES objcopy llvm-objcopy)
    if(CMAKE_OBJCOPY)
        message(STATUS "COMBINE_OBJCOPY not provided, found objcopy: ${CMAKE_OBJCOPY}")
    else()
        message(WARNING "objcopy not found — duplicate symbol localization will be skipped")
    endif()
endif()

# Convert semicolon-separated string to list
string(REPLACE ";" "\\;" LIBS_LIST "${COMBINE_LIBS}")
set(LIBS_LIST "${COMBINE_LIBS}")

# Filter out libraries that don't exist at build time.
# When a library is missing, try a build-time glob to find versioned variants
# (e.g., libruby-static.a → libruby.3.4-static.a on macOS).
# This is needed because configure-time globs run before dependencies are built.
set(EXISTING_LIBS)
foreach(lib ${LIBS_LIST})
    if(EXISTS "${lib}")
        list(APPEND EXISTING_LIBS "${lib}")
    else()
        # Try globbing for versioned variants: insert ".*" or "*" before the
        # first hyphen in the basename.  libruby-static.a → libruby*-static.a
        get_filename_component(_dir "${lib}" DIRECTORY)
        get_filename_component(_name "${lib}" NAME)
        # Build glob pattern: libruby-static.a → libruby*-static.a
        string(REGEX REPLACE "^(lib[^-]+)(-.+)$" "\\1*\\2" _glob_pattern "${_name}")
        if(NOT "${_glob_pattern}" STREQUAL "${_name}")
            file(GLOB _glob_matches "${_dir}/${_glob_pattern}")
            # Filter out any -ext variants to avoid picking up libruby-ext.a
            list(FILTER _glob_matches EXCLUDE REGEX "-ext[.-]")
            if(_glob_matches)
                list(GET _glob_matches 0 _resolved)
                get_filename_component(_resolved_name "${_resolved}" NAME)
                message(STATUS "Resolved missing ${_name} → ${_resolved_name}")
                list(APPEND EXISTING_LIBS "${_resolved}")
            else()
                message(STATUS "Skipping non-existent library: ${lib}")
            endif()
        else()
            message(STATUS "Skipping non-existent library: ${lib}")
        endif()
    endif()
endforeach()

if(NOT EXISTING_LIBS)
    message(FATAL_ERROR "No libraries found to combine. Check that dependencies were built successfully.")
endif()

# Optional parameters
if(NOT DEFINED COMBINE_WORKDIR)
    set(COMBINE_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/fat_library_workdir")
endif()

# Call the function
combine_fat_library(
    OUTPUT ${COMBINE_OUTPUT}
    WORKDIR ${COMBINE_WORKDIR}
    LIBS ${EXISTING_LIBS}
)
