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

# Set compiler and linker flags
set(RUBY_CFLAGS "-isysroot ${IOS_SDK_PATH}")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -arch ${IOS_ARCH}")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -miphoneos-version-min=${IOS_DEPLOYMENT_TARGET}")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -I${RUBY_BUILD_STAGING_DIR}/usr/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -I${RUBY_BUILD_STAGING_DIR}/usr/local/include")
set(RUBY_CFLAGS "${RUBY_CFLAGS} -O3 -DNDEBUG")

# Simulator-specific flags
if(IOS_PLATFORM_TYPE STREQUAL "simulator")
    set(RUBY_CFLAGS "${RUBY_CFLAGS} -D__IPHONE_SIMULATOR__")
endif()

set(RUBY_CXXFLAGS "${RUBY_CFLAGS}")
set(RUBY_CPPFLAGS "${RUBY_CFLAGS}")

set(RUBY_LDFLAGS "-isysroot ${IOS_SDK_PATH}")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -arch ${IOS_ARCH}")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -miphoneos-version-min=${IOS_DEPLOYMENT_TARGET}")
set(RUBY_LDFLAGS "${RUBY_LDFLAGS} -L${RUBY_BUILD_STAGING_DIR}/usr/lib")
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
    IPHONEOS_DEPLOYMENT_TARGET=${IOS_DEPLOYMENT_TARGET}
    PARENT_SCOPE
)

# Export for use in dependency builds
set(RUBY_BUILD_ENV ${RUBY_BUILD_ENV} PARENT_SCOPE)
set(RUBY_HOST_TRIPLET "${IOS_HOST_TRIPLET}" PARENT_SCOPE)
set(RUBY_HOST_SHORT "ios-${IOS_ARCH}" PARENT_SCOPE)

# Platform-specific build options
set(RUBY_ENABLE_SHARED OFF CACHE BOOL "Build static libraries for iOS")
set(RUBY_DISABLE_INSTALL_DOC ON CACHE BOOL "Disable documentation installation")

# Note: iOS requires static linking for App Store apps
message(STATUS "iOS builds will use static libraries (required for App Store)")

# Mark platform as initialized
set(RUBY_PLATFORM_INITIALIZED TRUE PARENT_SCOPE)

message(STATUS "iOS platform configuration complete")
