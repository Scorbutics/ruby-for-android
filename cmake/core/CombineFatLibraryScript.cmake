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

# Set CMAKE_AR, CMAKE_RANLIB, and CMAKE_NM for the function
set(CMAKE_AR "${COMBINE_AR}")
set(CMAKE_RANLIB "${COMBINE_RANLIB}")
set(CMAKE_NM "${COMBINE_NM}")

# Convert semicolon-separated string to list
string(REPLACE ";" "\\;" LIBS_LIST "${COMBINE_LIBS}")
set(LIBS_LIST "${COMBINE_LIBS}")

# Optional parameters
if(NOT DEFINED COMBINE_WORKDIR)
    set(COMBINE_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/fat_library_workdir")
endif()

# Call the function
combine_fat_library(
    OUTPUT ${COMBINE_OUTPUT}
    WORKDIR ${COMBINE_WORKDIR}
    LIBS ${LIBS_LIST}
)
