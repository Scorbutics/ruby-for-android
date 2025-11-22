# Dependencies.cmake
# Central configuration for all Ruby dependencies

# Include dependency-specific configurations
set(DEPS_DIR "${CMAKE_SOURCE_DIR}/cmake/dependencies")

# Check if dependency configs exist, otherwise fall back to ruby-build configs
macro(include_dependency DEP_NAME)
    if(EXISTS "${DEPS_DIR}/${DEP_NAME}.cmake")
        include("${DEPS_DIR}/${DEP_NAME}.cmake")
    elseif(EXISTS "${CMAKE_SOURCE_DIR}/ruby-build/${DEP_NAME}/cmake.conf")
        # Legacy support: include old-style config
        include("${CMAKE_SOURCE_DIR}/ruby-build/${DEP_NAME}/cmake.conf")
    else()
        message(WARNING "No configuration found for dependency: ${DEP_NAME}")
    endif()
endmacro()

# Define build order (dependencies first, then Ruby)
set(RUBY_DEPENDENCIES
    ncurses
    readline
    gdbm
    openssl
    ruby
)

message(STATUS "Loading dependency configurations...")

foreach(DEP ${RUBY_DEPENDENCIES})
    message(STATUS "  - ${DEP}")
    include_dependency(${DEP})
endforeach()

message(STATUS "All dependency configurations loaded")
