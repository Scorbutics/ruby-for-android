# PlatformDetection.cmake
# Detects target platform and loads appropriate platform configuration

# Determine target platform
if(ANDROID)
    set(RUBY_TARGET_PLATFORM "Android")
elseif(IOS)
    set(RUBY_TARGET_PLATFORM "iOS")
elseif(APPLE)
    set(RUBY_TARGET_PLATFORM "macOS")
elseif(UNIX)
    set(RUBY_TARGET_PLATFORM "Linux")
elseif(WIN32)
    set(RUBY_TARGET_PLATFORM "Windows")
else()
    message(FATAL_ERROR "Unsupported platform")
endif()

message(STATUS "Target platform: ${RUBY_TARGET_PLATFORM}")

# Detect host architecture
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
    set(RUBY_TARGET_ARCH "arm64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "armv7|armv7-a|armv7l")
    set(RUBY_TARGET_ARCH "armv7")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|amd64|AMD64")
    set(RUBY_TARGET_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i686|i386")
    set(RUBY_TARGET_ARCH "x86")
else()
    set(RUBY_TARGET_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
endif()

message(STATUS "Target architecture: ${RUBY_TARGET_ARCH}")

# Android-specific detection
if(ANDROID)
    if(DEFINED ANDROID_ABI)
        if(ANDROID_ABI STREQUAL "arm64-v8a")
            set(RUBY_TARGET_ARCH "arm64")
        elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
            set(RUBY_TARGET_ARCH "armv7")
        elseif(ANDROID_ABI STREQUAL "x86_64")
            set(RUBY_TARGET_ARCH "x86_64")
        elseif(ANDROID_ABI STREQUAL "x86")
            set(RUBY_TARGET_ARCH "x86")
        endif()
        message(STATUS "Android ABI: ${ANDROID_ABI}")
    endif()

    if(DEFINED ANDROID_PLATFORM)
        message(STATUS "Android Platform: ${ANDROID_PLATFORM}")
    endif()

    if(DEFINED HOST)
        message(STATUS "Android Host Triplet: ${HOST}")
    endif()
endif()

# iOS-specific detection
if(IOS)
    if(CMAKE_OSX_SYSROOT MATCHES "iPhoneOS")
        set(RUBY_IOS_PLATFORM "device")
    elseif(CMAKE_OSX_SYSROOT MATCHES "iPhoneSimulator")
        set(RUBY_IOS_PLATFORM "simulator")
    else()
        set(RUBY_IOS_PLATFORM "unknown")
    endif()
    message(STATUS "iOS Platform: ${RUBY_IOS_PLATFORM}")
endif()

# Load platform-specific configuration
set(PLATFORM_CONFIG "${CMAKE_SOURCE_DIR}/cmake/platforms/${RUBY_TARGET_PLATFORM}.cmake")
if(EXISTS "${PLATFORM_CONFIG}")
    message(STATUS "Loading platform configuration: ${PLATFORM_CONFIG}")
    include("${PLATFORM_CONFIG}")
else()
    message(FATAL_ERROR "Platform configuration not found: ${PLATFORM_CONFIG}")
endif()

# Validate that platform module defined required variables
if(NOT DEFINED RUBY_PLATFORM_INITIALIZED)
    message(FATAL_ERROR "Platform module ${RUBY_TARGET_PLATFORM}.cmake did not set RUBY_PLATFORM_INITIALIZED")
endif()

message(STATUS "Platform configuration loaded successfully")
