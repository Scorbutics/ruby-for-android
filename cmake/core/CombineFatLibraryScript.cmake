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

# Filter out libraries that don't exist at build time
# This handles platform differences (e.g., Android doesn't have libcrypt.a)
set(EXISTING_LIBS)
foreach(lib ${LIBS_LIST})
    if(EXISTS "${lib}")
        list(APPEND EXISTING_LIBS "${lib}")
    else()
        message(STATUS "Skipping non-existent library: ${lib}")
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
