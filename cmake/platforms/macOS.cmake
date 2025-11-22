# macOS.cmake
# Platform-specific configuration for macOS builds

message(STATUS "Configuring for macOS platform")

# For native macOS builds, use system compiler
set(CROSS_CC "${CMAKE_C_COMPILER}")
set(CROSS_CXX "${CMAKE_CXX_COMPILER}")
set(CROSS_AR "${CMAKE_AR}")
set(CROSS_RANLIB "${CMAKE_RANLIB}")
set(CROSS_STRIP "${CMAKE_STRIP}")
set(CROSS_LD "${CMAKE_LINKER}")

# Determine host triplet
execute_process(
    COMMAND ${CMAKE_C_COMPILER} -dumpmachine
    OUTPUT_VARIABLE MACOS_HOST_TRIPLET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT MACOS_HOST_TRIPLET)
    # Fallback based on architecture
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|ARM64")
        set(MACOS_HOST_TRIPLET "arm64-apple-darwin")
    else()
        set(MACOS_HOST_TRIPLET "x86_64-apple-darwin")
    endif()
endif()

message(STATUS "macOS Host Triplet: ${MACOS_HOST_TRIPLET}")

# Handle universal binary builds if requested
if(CMAKE_OSX_ARCHITECTURES)
    message(STATUS "macOS Universal Binary Architectures: ${CMAKE_OSX_ARCHITECTURES}")
    set(RUBY_OSX_ARCHS "${CMAKE_OSX_ARCHITECTURES}")
else()
    set(RUBY_OSX_ARCHS "${CMAKE_SYSTEM_PROCESSOR}")
endif()

# Set deployment target if specified
if(CMAKE_OSX_DEPLOYMENT_TARGET)
    message(STATUS "macOS Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    set(RUBY_MACOS_MIN_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}")
else()
    set(RUBY_MACOS_MIN_VERSION "10.15")  # Default to Catalina
endif()

# Set compiler and linker flags
set(RUBY_CFLAGS "-I${RUBY_BUILD_STAGING_DIR}/usr/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -I${RUBY_BUILD_STAGING_DIR}/usr/local/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -O3 -DNDEBUG")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -mmacosx-version-min=${RUBY_MACOS_MIN_VERSION}")

# Handle universal binaries
if(CMAKE_OSX_ARCHITECTURES)
    foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
        set(RUBY_CFLAGS "${RUBY_CFLAGS} -arch ${ARCH}")
    endforeach()
endif()

set(RUBY_CXXFLAGS "${RUBY_CFLAGS}")
set(RUBY_CPPFLAGS "${RUBY_CFLAGS}")

set(RUBY_LDFLAGS "-L${RUBY_BUILD_STAGING_DIR}/usr/lib")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -L${RUBY_BUILD_STAGING_DIR}/usr/local/lib")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -mmacosx-version-min=${RUBY_MACOS_MIN_VERSION}")

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
    MACOSX_DEPLOYMENT_TARGET=${RUBY_MACOS_MIN_VERSION}
    PARENT_SCOPE
)

# Export for use in dependency builds
set(RUBY_BUILD_ENV ${RUBY_BUILD_ENV} PARENT_SCOPE)
set(RUBY_HOST_TRIPLET "${MACOS_HOST_TRIPLET}" PARENT_SCOPE)
set(RUBY_HOST_SHORT "macos-${RUBY_TARGET_ARCH}" PARENT_SCOPE)

# Platform-specific build options
set(RUBY_ENABLE_SHARED ON CACHE BOOL "Build shared libraries")
set(RUBY_DISABLE_INSTALL_DOC ON CACHE BOOL "Disable documentation installation")

# Mark platform as initialized
set(RUBY_PLATFORM_INITIALIZED TRUE PARENT_SCOPE)

message(STATUS "macOS platform configuration complete")
