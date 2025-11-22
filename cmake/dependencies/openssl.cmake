# openssl.cmake
# Configuration for OpenSSL dependency

set(OPENSSL_VERSION "1.1.1m")
set(OPENSSL_URL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz")
set(OPENSSL_HASH "SHA256=f89199be8b23ca45fc7cb9f1d8d3ee67312318286ad030f5316aca6462db6c96")

# Platform-specific configure command
if(RUBY_TARGET_PLATFORM STREQUAL "Android")
    # Android uses clang with specific target
    set(OPENSSL_CONFIGURE_CMD
        ${CMAKE_COMMAND} -E env CC=clang
        ./Configure ${RUBY_HOST_SHORT} shared
    )
elseif(RUBY_TARGET_PLATFORM STREQUAL "iOS")
    # iOS needs special configuration
    if(RUBY_IOS_PLATFORM STREQUAL "device")
        set(OPENSSL_CONFIGURE_CMD
            ./Configure ios64-xcrun shared
        )
    else()
        set(OPENSSL_CONFIGURE_CMD
            ./Configure iossimulator-xcrun shared
        )
    endif()
elseif(RUBY_TARGET_PLATFORM STREQUAL "macOS")
    # macOS configuration
    if(RUBY_TARGET_ARCH STREQUAL "arm64")
        set(OPENSSL_CONFIGURE_CMD
            ./Configure darwin64-arm64-cc shared
        )
    else()
        set(OPENSSL_CONFIGURE_CMD
            ./Configure darwin64-x86_64-cc shared
        )
    endif()
else()
    # Linux and other platforms
    set(OPENSSL_CONFIGURE_CMD
        ./config shared
    )
endif()

# Build OpenSSL dependency
add_native_dependency(
    NAME openssl
    VERSION ${OPENSSL_VERSION}
    URL ${OPENSSL_URL}
    URL_HASH ${OPENSSL_HASH}
    CONFIGURE_COMMAND ${OPENSSL_CONFIGURE_CMD}
)
