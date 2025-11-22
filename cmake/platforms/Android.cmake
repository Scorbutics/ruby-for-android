# Android.cmake
# Platform-specific configuration for Android builds

message(STATUS "Configuring for Android platform")

# Validate Android NDK is available
if(NOT DEFINED CMAKE_ANDROID_NDK)
    message(FATAL_ERROR "CMAKE_ANDROID_NDK is not defined. Please specify Android NDK path.")
endif()

if(NOT EXISTS "${CMAKE_ANDROID_NDK}")
    message(FATAL_ERROR "Android NDK not found at: ${CMAKE_ANDROID_NDK}")
endif()

message(STATUS "Android NDK: ${CMAKE_ANDROID_NDK}")

# Validate required Android variables
if(NOT DEFINED ANDROID_PLATFORM)
    message(FATAL_ERROR "ANDROID_PLATFORM not defined (e.g., android-26)")
endif()

if(NOT DEFINED ANDROID_ABI)
    message(FATAL_ERROR "ANDROID_ABI not defined (e.g., arm64-v8a)")
endif()

# Extract API level from ANDROID_PLATFORM
string(REGEX MATCH "[0-9]+" ANDROID_API_LEVEL "${ANDROID_PLATFORM}")
message(STATUS "Android API Level: ${ANDROID_API_LEVEL}")

# Determine host triplet based on ABI
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(ANDROID_HOST_TRIPLET "aarch64-linux-android")
    set(ANDROID_HOST_SHORT "android-arm64")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(ANDROID_HOST_TRIPLET "armv7a-linux-androideabi")
    set(ANDROID_HOST_SHORT "android-armv7")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(ANDROID_HOST_TRIPLET "x86_64-linux-android")
    set(ANDROID_HOST_SHORT "android-x86_64")
elseif(ANDROID_ABI STREQUAL "x86")
    set(ANDROID_HOST_TRIPLET "i686-linux-android")
    set(ANDROID_HOST_SHORT "android-x86")
else()
    message(FATAL_ERROR "Unsupported ANDROID_ABI: ${ANDROID_ABI}")
endif()

# Allow override via HOST variable (for compatibility)
if(DEFINED HOST)
    set(ANDROID_HOST_TRIPLET "${HOST}")
endif()
if(DEFINED HOST_SHORT)
    set(ANDROID_HOST_SHORT "${HOST_SHORT}")
endif()

message(STATUS "Android Host Triplet: ${ANDROID_HOST_TRIPLET}")
message(STATUS "Android Host Short: ${ANDROID_HOST_SHORT}")

# Detect toolchain paths
if(DEFINED CMAKE_CXX_ANDROID_TOOLCHAIN_PREFIX)
    set(TOOLCHAIN_PREFIX "${CMAKE_CXX_ANDROID_TOOLCHAIN_PREFIX}")
else()
    # Fallback: construct from NDK path
    set(TOOLCHAIN_PREFIX "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/")
endif()

get_filename_component(TOOLCHAIN_BIN "${TOOLCHAIN_PREFIX}" DIRECTORY)
message(STATUS "Toolchain bin directory: ${TOOLCHAIN_BIN}")

# Set cross-compilation tools
set(CLANG_TARGET "${ANDROID_HOST_TRIPLET}${ANDROID_API_LEVEL}")

set(CROSS_CC "${TOOLCHAIN_BIN}/clang")
set(CROSS_CXX "${TOOLCHAIN_BIN}/clang++")
set(CROSS_AR "${TOOLCHAIN_BIN}/llvm-ar")
set(CROSS_RANLIB "${TOOLCHAIN_BIN}/llvm-ranlib")
set(CROSS_STRIP "${TOOLCHAIN_BIN}/llvm-strip")
set(CROSS_LD "${TOOLCHAIN_BIN}/ld")
set(CROSS_AS "${CROSS_CC}")

# Verify tools exist
foreach(TOOL CC CXX AR RANLIB STRIP LD)
    if(NOT EXISTS "${CROSS_${TOOL}}")
        message(WARNING "Tool not found: ${CROSS_${TOOL}}")
    endif()
endforeach()

# Build environment configuration
set(ANDROID_SYSROOT "${TOOLCHAIN_BIN}/../sysroot")

# Set compiler and linker flags
set(RUBY_CFLAGS "-target ${CLANG_TARGET}")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -I${RUBY_BUILD_STAGING_DIR}/usr/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -I${RUBY_BUILD_STAGING_DIR}/usr/local/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -O3 -DNDEBUG")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -U__ANDROID_API__ -D__ANDROID_API__=${ANDROID_API_LEVEL}")

set(RUBY_CXXFLAGS "${RUBY_CFLAGS}")
set(RUBY_CPPFLAGS "${RUBY_CFLAGS}")

set(RUBY_LDFLAGS "-L${RUBY_BUILD_STAGING_DIR}/usr/lib")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -L${RUBY_BUILD_STAGING_DIR}/usr/local/lib")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -lz -lm")

# Set environment variables for autoconf-based builds
set(RUBY_BUILD_ENV
    CC=${CROSS_CC} -target ${CLANG_TARGET}
    CXX=${CROSS_CXX} -target ${CLANG_TARGET}
    AR=${CROSS_AR}
    RANLIB=${CROSS_RANLIB}
    STRIP=${CROSS_STRIP}
    LD=${CROSS_LD}
    AS=${CROSS_AS}
    ANDROID_API=${ANDROID_API_LEVEL}
    ANDROID_NDK=${CMAKE_ANDROID_NDK}
    API=${ANDROID_API_LEVEL}
    TARGET=${ANDROID_HOST_TRIPLET}
    TOOLCHAIN=${TOOLCHAIN_BIN}/../
    CFLAGS=${RUBY_CFLAGS}
    CXXFLAGS=${RUBY_CXXFLAGS}
    CPPFLAGS=${RUBY_CPPFLAGS}
    LDFLAGS=${RUBY_LDFLAGS}
    PARENT_SCOPE
)

# Export for use in dependency builds
set(RUBY_BUILD_ENV ${RUBY_BUILD_ENV} PARENT_SCOPE)
set(RUBY_HOST_TRIPLET "${ANDROID_HOST_TRIPLET}" PARENT_SCOPE)
set(RUBY_HOST_SHORT "${ANDROID_HOST_SHORT}" PARENT_SCOPE)

# Platform-specific build options
set(RUBY_ENABLE_SHARED ON CACHE BOOL "Build shared libraries")
set(RUBY_DISABLE_INSTALL_DOC ON CACHE BOOL "Disable documentation installation")

# Mark platform as initialized
set(RUBY_PLATFORM_INITIALIZED TRUE PARENT_SCOPE)

message(STATUS "Android platform configuration complete")
