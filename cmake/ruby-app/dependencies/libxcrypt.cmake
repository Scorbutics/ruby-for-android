# libxcrypt.cmake
# Configuration for libxcrypt (extended crypt library)
# Note: Only needed for Linux builds - Android's Bionic libc doesn't provide crypt functions

set(LIBXCRYPT_VERSION "4.4.36")
set(LIBXCRYPT_URL "https://github.com/besser82/libxcrypt/releases/download/v${LIBXCRYPT_VERSION}/libxcrypt-${LIBXCRYPT_VERSION}.tar.xz")
set(LIBXCRYPT_HASH "SHA256=e5e1f4caee0a01de2aee26e3138807d6d3ca2b8e67287966d1fefd65e1fd8943")

# Configure command (autoconf-based)
# Always build as static library with PIC for Ruby embedding
if(BUILD_SHARED_LIBS)
    set(LIBXCRYPT_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(LIBXCRYPT_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
        --with-pic
    )
endif()

set(LIBXCRYPT_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --prefix=/usr
    ${LIBXCRYPT_CONFIGURE_LIB_TYPE}
    --disable-failure-tokens
    --disable-xcrypt-compat-files
    --enable-hashes=strong,glibc
    --enable-obsolete-api=no
)

# Build libxcrypt dependency (Linux only)
# Android's Bionic libc doesn't provide crypt functions and Ruby doesn't need them there
# libxcrypt depends on libbsd for BSD compatibility functions
if(TARGET_PLATFORM STREQUAL "Linux")
    add_external_dependency(
        NAME libxcrypt
        VERSION ${LIBXCRYPT_VERSION}
        URL ${LIBXCRYPT_URL}
        URL_HASH ${LIBXCRYPT_HASH}
        CONFIGURE_COMMAND ${LIBXCRYPT_CONFIGURE_CMD}
        DEPENDS libbsd
    )
endif()
