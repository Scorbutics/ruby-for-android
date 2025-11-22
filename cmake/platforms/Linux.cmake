# Linux.cmake
# Platform-specific configuration for Linux builds

message(STATUS "Configuring for Linux platform")

# For native Linux builds, we can use the system compiler
set(CROSS_CC "${CMAKE_C_COMPILER}")
set(CROSS_CXX "${CMAKE_CXX_COMPILER}")
set(CROSS_AR "${CMAKE_AR}")
set(CROSS_RANLIB "${CMAKE_RANLIB}")
set(CROSS_STRIP "${CMAKE_STRIP}")
set(CROSS_LD "${CMAKE_LINKER}")

# Determine host triplet
execute_process(
    COMMAND ${CMAKE_C_COMPILER} -dumpmachine
    OUTPUT_VARIABLE LINUX_HOST_TRIPLET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT LINUX_HOST_TRIPLET)
    # Fallback
    set(LINUX_HOST_TRIPLET "${CMAKE_SYSTEM_PROCESSOR}-linux-gnu")
endif()

message(STATUS "Linux Host Triplet: ${LINUX_HOST_TRIPLET}")

# Set compiler and linker flags
set(RUBY_CFLAGS "-I${RUBY_BUILD_STAGING_DIR}/usr/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -I${RUBY_BUILD_STAGING_DIR}/usr/local/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -O3 -DNDEBUG")

set(RUBY_CXXFLAGS "${RUBY_CFLAGS}")
set(RUBY_CPPFLAGS "${RUBY_CFLAGS}")

set(RUBY_LDFLAGS "-L${RUBY_BUILD_STAGING_DIR}/usr/lib")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -L${RUBY_BUILD_STAGING_DIR}/usr/local/lib")

# Set environment variables for autoconf-based builds
set(RUBY_BUILD_ENV
    CC=${CROSS_CC}
    CXX=${CROSS_CXX}
    AR=${CROSS_AR}
    RANLIB=${CROSS_RANLIB}
    STRIP=${CROSS_STRIP}
    LD=${CROSS_LD}
    CFLAGS=${RUBY_CFLAGS}
    CXXFLAGS=${RUBY_CXXFLAGS}
    CPPFLAGS=${RUBY_CPPFLAGS}
    LDFLAGS=${RUBY_LDFLAGS}
    PARENT_SCOPE
)

# Export for use in dependency builds
set(RUBY_BUILD_ENV ${RUBY_BUILD_ENV} PARENT_SCOPE)
set(RUBY_HOST_TRIPLET "${LINUX_HOST_TRIPLET}" PARENT_SCOPE)
set(RUBY_HOST_SHORT "linux-${RUBY_TARGET_ARCH}" PARENT_SCOPE)

# Platform-specific build options
set(RUBY_ENABLE_SHARED ON CACHE BOOL "Build shared libraries")
set(RUBY_DISABLE_INSTALL_DOC ON CACHE BOOL "Disable documentation installation")

# Mark platform as initialized
set(RUBY_PLATFORM_INITIALIZED TRUE PARENT_SCOPE)

message(STATUS "Linux platform configuration complete")
