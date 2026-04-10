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
# Use a stable, unversioned triplet so that archive paths are portable across
# macOS versions (clang -dumpmachine returns e.g. arm64-apple-darwin24.0.0).
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|ARM64|aarch64")
    set(MACOS_HOST_TRIPLET "aarch64-apple-darwin")
else()
    set(MACOS_HOST_TRIPLET "x86_64-apple-darwin")
endif()

message(STATUS "macOS Host Triplet: ${MACOS_HOST_TRIPLET}")

# Handle universal binary builds if requested
if(CMAKE_OSX_ARCHITECTURES)
    message(STATUS "macOS Universal Binary Architectures: ${CMAKE_OSX_ARCHITECTURES}")
    set(OSX_ARCHS "${CMAKE_OSX_ARCHITECTURES}")
else()
    set(OSX_ARCHS "${CMAKE_SYSTEM_PROCESSOR}")
endif()

# Set deployment target if specified
if(CMAKE_OSX_DEPLOYMENT_TARGET)
    message(STATUS "macOS Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    set(MACOS_MIN_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}")
else()
    set(MACOS_MIN_VERSION "10.15")  # Default to Catalina
endif()

# Set compiler and linker flags
set(CFLAGS "-I${BUILD_STAGING_DIR}/usr/include")
set(CFLAGS "${CFLAGS} -I${BUILD_STAGING_DIR}/usr/local/include")
set(CFLAGS "${CFLAGS} -O3 -DNDEBUG")
set(CFLAGS "${CFLAGS} -mmacosx-version-min=${MACOS_MIN_VERSION}")

# Handle universal binaries
if(CMAKE_OSX_ARCHITECTURES)
    foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
        set(CFLAGS "${CFLAGS} -arch ${ARCH}")
    endforeach()
endif()

# Add -fPIC for static builds (required for linking static libraries into executables)
if(NOT BUILD_SHARED_LIBS)
    set(CFLAGS "${CFLAGS} -fPIC")
endif()

set(CXXFLAGS "${CFLAGS}")
set(CPPFLAGS "${CFLAGS}")

# Assembly flags: Ruby compiles coroutine .S files with ASFLAGS (not CFLAGS).
# Without the arch/min-version, the assembler may produce incorrect objects.
set(ASFLAGS "-mmacosx-version-min=${MACOS_MIN_VERSION}")
if(CMAKE_OSX_ARCHITECTURES)
    foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
        set(ASFLAGS "${ASFLAGS} -arch ${ARCH}")
    endforeach()
endif()

set(LDFLAGS "-L${BUILD_STAGING_DIR}/usr/lib")
set(LDFLAGS "${LDFLAGS} -L${BUILD_STAGING_DIR}/usr/local/lib")
set(LDFLAGS "${LDFLAGS} -mmacosx-version-min=${MACOS_MIN_VERSION}")

# Set environment variables for autoconf-based builds
# PKG_CONFIG_LIBDIR: restrict pkg-config to only find packages in the staging
# directory, preventing Homebrew's OpenSSL (or other libs) from being picked up
set(BUILD_ENV
    CC=${CROSS_CC}
    CXX=${CROSS_CXX}
    AR=${CROSS_AR}
    RANLIB=${CROSS_RANLIB}
    STRIP=${CROSS_STRIP}
    LD=${CROSS_LD}
    ASFLAGS=${ASFLAGS}
    CFLAGS=${CFLAGS}
    CXXFLAGS=${CXXFLAGS}
    CPPFLAGS=${CPPFLAGS}
    LDFLAGS=${LDFLAGS}
    MACOSX_DEPLOYMENT_TARGET=${MACOS_MIN_VERSION}
    PKG_CONFIG_LIBDIR=${BUILD_STAGING_DIR}/usr/lib/pkgconfig:${BUILD_STAGING_DIR}/usr/local/lib/pkgconfig
)

# Export for use in dependency builds
set(BUILD_ENV ${BUILD_ENV} PARENT_SCOPE)
set(HOST_TRIPLET "${MACOS_HOST_TRIPLET}" PARENT_SCOPE)
set(HOST_SHORT "macos-${TARGET_ARCH}" PARENT_SCOPE)
set(CFLAGS "${CFLAGS}" PARENT_SCOPE)
set(CXXFLAGS "${CXXFLAGS}" PARENT_SCOPE)
set(CPPFLAGS "${CPPFLAGS}" PARENT_SCOPE)
set(LDFLAGS "${LDFLAGS}" PARENT_SCOPE)
set(CROSS_CC "${CROSS_CC}" PARENT_SCOPE)
set(CROSS_AR "${CROSS_AR}" PARENT_SCOPE)
set(CROSS_RANLIB "${CROSS_RANLIB}" PARENT_SCOPE)
set(RUBY_TARGET_ARCH "${TARGET_ARCH}" PARENT_SCOPE)

# Platform-specific build options
set(DISABLE_INSTALL_DOC ON CACHE BOOL "Disable documentation installation")

# Report build mode
if(BUILD_SHARED_LIBS)
    message(STATUS "macOS: Using DYNAMIC libraries (BUILD_SHARED_LIBS=ON)")
else()
    message(STATUS "macOS: Using STATIC libraries (BUILD_SHARED_LIBS=OFF)")
endif()

# Mark platform as initialized
set(PLATFORM_INITIALIZED TRUE PARENT_SCOPE)

message(STATUS "macOS platform configuration complete")
