# openssl.cmake
# Configuration for OpenSSL dependency

set(OPENSSL_VERSION "1.1.1m")
set(OPENSSL_URL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz")
set(OPENSSL_HASH "SHA256=f89199be8b23ca45fc7cb9f1d8d3ee67312318286ad030f5316aca6462db6c96")

# Determine shared/static flag based on ENABLE_SHARED
if(ENABLE_SHARED)
    set(OPENSSL_SHARED_FLAG "shared")
else()
    set(OPENSSL_SHARED_FLAG "no-shared")
endif()

# Platform-specific configure command
if(TARGET_PLATFORM STREQUAL "Android")
    # Android with modern NDK (r19+)
    # OpenSSL needs ANDROID_NDK_ROOT and PATH to include toolchain bin
    # The Configure script will automatically detect and use the appropriate clang
    set(OPENSSL_CONFIGURE_CMD
        ./Configure ${HOST_SHORT} ${OPENSSL_SHARED_FLAG}
            --prefix=/usr/local
            -D__ANDROID_API__=${ANDROID_API_LEVEL}
    )
    # ANDROID_NDK_ROOT and PATH are already set in RUBY_BUILD_ENV
elseif(TARGET_PLATFORM STREQUAL "iOS")
    # iOS needs special configuration
    if(RUBY_IOS_PLATFORM STREQUAL "device")
        set(OPENSSL_CONFIGURE_CMD
            ./Configure ios64-xcrun ${OPENSSL_SHARED_FLAG}
        )
    else()
        set(OPENSSL_CONFIGURE_CMD
            ./Configure iossimulator-xcrun ${OPENSSL_SHARED_FLAG}
        )
    endif()
elseif(TARGET_PLATFORM STREQUAL "macOS")
    # macOS configuration
    if(RUBY_TARGET_ARCH STREQUAL "arm64")
        set(OPENSSL_CONFIGURE_CMD
            ./Configure darwin64-arm64-cc ${OPENSSL_SHARED_FLAG}
        )
    else()
        set(OPENSSL_CONFIGURE_CMD
            ./Configure darwin64-x86_64-cc ${OPENSSL_SHARED_FLAG}
        )
    endif()
else()
    # Linux and other platforms
    set(OPENSSL_CONFIGURE_CMD
        ./config ${OPENSSL_SHARED_FLAG}
    )
endif()

# Build OpenSSL dependency
add_external_dependency(
    NAME openssl
    VERSION ${OPENSSL_VERSION}
    URL ${OPENSSL_URL}
    URL_HASH ${OPENSSL_HASH}
    CONFIGURE_COMMAND ${OPENSSL_CONFIGURE_CMD}
    ENV_VARS ${OPENSSL_ENV_VARS}
)
