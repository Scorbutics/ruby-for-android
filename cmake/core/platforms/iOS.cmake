# iOS.cmake
# Platform-specific configuration for iOS builds

message(STATUS "Configuring for iOS platform")

# Validate iOS SDK is available
if(NOT DEFINED CMAKE_OSX_SYSROOT)
    message(FATAL_ERROR "CMAKE_OSX_SYSROOT not defined. Please specify iOS SDK path.")
endif()

# Determine if building for device or simulator
if(CMAKE_OSX_SYSROOT MATCHES "iPhoneOS")
    set(IOS_PLATFORM_TYPE "device")
    set(IOS_SDK_NAME "iphoneos")
elseif(CMAKE_OSX_SYSROOT MATCHES "iPhoneSimulator")
    set(IOS_PLATFORM_TYPE "simulator")
    set(IOS_SDK_NAME "iphonesimulator")
else()
    message(FATAL_ERROR "Unsupported iOS SDK: ${CMAKE_OSX_SYSROOT}")
endif()

message(STATUS "iOS Platform Type: ${IOS_PLATFORM_TYPE}")
message(STATUS "iOS SDK: ${IOS_SDK_NAME}")

# Set deployment target
if(CMAKE_OSX_DEPLOYMENT_TARGET)
    set(IOS_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}")
else()
    set(IOS_DEPLOYMENT_TARGET "12.0")  # Default to iOS 12
endif()
message(STATUS "iOS Deployment Target: ${IOS_DEPLOYMENT_TARGET}")

# Determine architecture
if(CMAKE_OSX_ARCHITECTURES)
    set(IOS_ARCH "${CMAKE_OSX_ARCHITECTURES}")
else()
    if(IOS_PLATFORM_TYPE STREQUAL "device")
        set(IOS_ARCH "arm64")
    else()
        # Simulator on Apple Silicon or Intel
        if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "arm64")
            set(IOS_ARCH "arm64")
        else()
            set(IOS_ARCH "x86_64")
        endif()
    endif()
endif()

message(STATUS "iOS Architecture: ${IOS_ARCH}")

# Set host triplet
if(IOS_ARCH MATCHES "arm64")
    set(IOS_HOST_TRIPLET "aarch64-apple-darwin")
else()
    set(IOS_HOST_TRIPLET "x86_64-apple-darwin")
endif()

# Find Xcode toolchain
execute_process(
    COMMAND xcrun --sdk ${IOS_SDK_NAME} --find clang
    OUTPUT_VARIABLE IOS_CLANG_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT IOS_CLANG_PATH)
    message(FATAL_ERROR "Could not find clang for iOS SDK")
endif()

get_filename_component(IOS_TOOLCHAIN_BIN "${IOS_CLANG_PATH}" DIRECTORY)
message(STATUS "iOS Toolchain: ${IOS_TOOLCHAIN_BIN}")

# Set cross-compilation tools
set(CROSS_CC "${IOS_CLANG_PATH}")
set(CROSS_CXX "${IOS_TOOLCHAIN_BIN}/clang++")
set(CROSS_AR "${IOS_TOOLCHAIN_BIN}/ar")
set(CROSS_RANLIB "${IOS_TOOLCHAIN_BIN}/ranlib")
set(CROSS_STRIP "${IOS_TOOLCHAIN_BIN}/strip")
set(CROSS_LD "${IOS_TOOLCHAIN_BIN}/ld")

# Get SDK path
execute_process(
    COMMAND xcrun --sdk ${IOS_SDK_NAME} --show-sdk-path
    OUTPUT_VARIABLE IOS_SDK_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

message(STATUS "iOS SDK Path: ${IOS_SDK_PATH}")

# Set the correct min-version flag based on device vs simulator
if(IOS_PLATFORM_TYPE STREQUAL "simulator")
    set(IOS_MIN_VERSION_FLAG "-mios-simulator-version-min=${IOS_DEPLOYMENT_TARGET}")
else()
    set(IOS_MIN_VERSION_FLAG "-miphoneos-version-min=${IOS_DEPLOYMENT_TARGET}")
endif()

# Set compiler and linker flags
set(CFLAGS "-isysroot ${IOS_SDK_PATH}")
set(CFLAGS "${CFLAGS} -arch ${IOS_ARCH}")
set(CFLAGS "${CFLAGS} ${IOS_MIN_VERSION_FLAG}")
set(CFLAGS "${CFLAGS} -I${BUILD_STAGING_DIR}/usr/include")
set(CFLAGS "${CFLAGS} -I${BUILD_STAGING_DIR}/usr/local/include")
set(CFLAGS "${CFLAGS} -O3 -DNDEBUG")

# Simulator-specific flags
if(IOS_PLATFORM_TYPE STREQUAL "simulator")
    set(CFLAGS "${CFLAGS} -D__IPHONE_SIMULATOR__")
endif()

# Add -fPIC for static builds (required for linking static libraries into executables)
if(NOT BUILD_SHARED_LIBS)
    set(CFLAGS "${CFLAGS} -fPIC")
endif()

set(CXXFLAGS "${CFLAGS}")
set(CPPFLAGS "${CFLAGS}")

# Assembly flags: Ruby compiles coroutine .S files with ASFLAGS (not CFLAGS).
# Without the sysroot/arch/min-version, the assembler produces macOS-tagged objects
# that the linker rejects when building for iOS.
set(ASFLAGS "-isysroot ${IOS_SDK_PATH} -arch ${IOS_ARCH} ${IOS_MIN_VERSION_FLAG}")

set(LDFLAGS "-isysroot ${IOS_SDK_PATH}")
set(LDFLAGS "${LDFLAGS} -arch ${IOS_ARCH}")
set(LDFLAGS "${LDFLAGS} ${IOS_MIN_VERSION_FLAG}")
set(LDFLAGS "${LDFLAGS} -L${BUILD_STAGING_DIR}/usr/lib")
set(LDFLAGS "${LDFLAGS} -L${BUILD_STAGING_DIR}/usr/local/lib")

# Set environment variables for autoconf-based builds
# CC_FOR_BUILD is needed by autoconf projects (e.g. GMP) that compile and run
# test programs on the host during ./configure.  Without it the iOS cross-compiler
# is used, which links against the iOS SDK and fails with "library 'System' not found".
set(BUILD_ENV
    CC=${CROSS_CC}
    CXX=${CROSS_CXX}
    AR=${CROSS_AR}
    RANLIB=${CROSS_RANLIB}
    STRIP=${CROSS_STRIP}
    LD=${CROSS_LD}
    CC_FOR_BUILD=/usr/bin/clang
    CFLAGS_FOR_BUILD=
    CPPFLAGS_FOR_BUILD=
    LDFLAGS_FOR_BUILD=
    ASFLAGS=${ASFLAGS}
    CFLAGS=${CFLAGS}
    CXXFLAGS=${CXXFLAGS}
    CPPFLAGS=${CPPFLAGS}
    LDFLAGS=${LDFLAGS}
)

# Export for use in dependency builds
set(BUILD_ENV ${BUILD_ENV} PARENT_SCOPE)
set(HOST_TRIPLET "${IOS_HOST_TRIPLET}" PARENT_SCOPE)
set(HOST_SHORT "ios-${IOS_ARCH}" PARENT_SCOPE)
set(CFLAGS "${CFLAGS}" PARENT_SCOPE)
set(CXXFLAGS "${CXXFLAGS}" PARENT_SCOPE)
set(CPPFLAGS "${CPPFLAGS}" PARENT_SCOPE)
set(LDFLAGS "${LDFLAGS}" PARENT_SCOPE)
set(CROSS_CC "${CROSS_CC}" PARENT_SCOPE)
set(CROSS_AR "${CROSS_AR}" PARENT_SCOPE)
set(CROSS_RANLIB "${CROSS_RANLIB}" PARENT_SCOPE)
set(RUBY_IOS_PLATFORM "${IOS_PLATFORM_TYPE}" PARENT_SCOPE)
set(RUBY_TARGET_ARCH "${IOS_ARCH}" PARENT_SCOPE)

# Platform-specific build options
# iOS ALWAYS requires static linking for App Store apps - override user setting
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries for iOS" FORCE)
set(DISABLE_INSTALL_DOC ON CACHE BOOL "Disable documentation installation")

# Note: iOS requires static linking for App Store apps
message(STATUS "iOS builds will use STATIC libraries (required for App Store - cannot be changed)")

# Generate an iOS CMake toolchain file so that ExternalProject sub-builds
# (which run their own CMake process) inherit the iOS cross-compilation settings
# via -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}.
set(_IOS_TOOLCHAIN_FILE "${CMAKE_BINARY_DIR}/ios-toolchain.cmake")
file(WRITE "${_IOS_TOOLCHAIN_FILE}"
"# Auto-generated iOS toolchain file
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_SYSROOT \"${CMAKE_OSX_SYSROOT}\")
set(CMAKE_OSX_ARCHITECTURES \"${IOS_ARCH}\")
set(CMAKE_OSX_DEPLOYMENT_TARGET \"${IOS_DEPLOYMENT_TARGET}\")
")
set(CMAKE_TOOLCHAIN_FILE "${_IOS_TOOLCHAIN_FILE}" CACHE FILEPATH "iOS toolchain file" FORCE)
set(CMAKE_TOOLCHAIN_FILE "${_IOS_TOOLCHAIN_FILE}" PARENT_SCOPE)
message(STATUS "Generated iOS toolchain file: ${_IOS_TOOLCHAIN_FILE}")

# Mark platform as initialized
set(PLATFORM_INITIALIZED TRUE PARENT_SCOPE)

message(STATUS "iOS platform configuration complete")
