# libmd.cmake
# Configuration for libmd (BSD Message Digest library)
# Note: Only needed for Linux builds - provides MD5 functions required by libbsd
# This is a dependency for libbsd

set(LIBMD_VERSION "1.1.0")
set(LIBMD_URL "https://archive.hadrons.org/software/libmd/libmd-${LIBMD_VERSION}.tar.xz")
set(LIBMD_HASH "SHA256=1bd6aa42275313af3141c7cf2e5b964e8b1fd488025caf2f971f43b00776b332")

# Configure command (autoconf-based)
# Always build as static library with PIC for Ruby embedding
if(BUILD_SHARED_LIBS)
    set(LIBMD_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(LIBMD_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
        --with-pic
    )
endif()

# Disable symbol versioning for embedded deployment
# These libraries are bundled together for Kotlin Native, not system-wide installation
# Symbol versioning is unnecessary and adds complexity when all deps are self-contained

set(LIBMD_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --prefix=/usr
    ${LIBMD_CONFIGURE_LIB_TYPE}
    # Note: Symbol versioning is disabled via patch in cmake/ruby-app/patches/libmd/linux/
    # because configure doesn't support --disable-symbol-versioning
)

# Build libmd dependency (Linux only)
# Android's Bionic libc provides its own message digest functions
if(TARGET_PLATFORM STREQUAL "Linux")
    add_external_dependency(
        NAME libmd
        VERSION ${LIBMD_VERSION}
        URL ${LIBMD_URL}
        URL_HASH ${LIBMD_HASH}
        CONFIGURE_COMMAND ${LIBMD_CONFIGURE_CMD}
    )
endif()
