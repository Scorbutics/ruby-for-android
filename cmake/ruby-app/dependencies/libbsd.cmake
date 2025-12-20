# libbsd.cmake
# Configuration for libbsd (BSD compatibility library)
# Note: Only needed for Linux builds - provides BSD functions commonly found on BSD systems
# This is a dependency for libxcrypt

set(LIBBSD_VERSION "0.12.2")
set(LIBBSD_URL "https://libbsd.freedesktop.org/releases/libbsd-${LIBBSD_VERSION}.tar.xz")
set(LIBBSD_HASH "SHA256=b88cc9163d0c652aaf39a99991d974ddba1c3a9711db8f1b5838af2a14731014")

# Configure command (autoconf-based)
# Always build as static library with PIC for Ruby embedding
if(BUILD_SHARED_LIBS)
    set(LIBBSD_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(LIBBSD_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
        --with-pic
    )
endif()

# Disable symbol versioning for embedded deployment
# These libraries are bundled together for Kotlin Native, not system-wide installation
# Symbol versioning is unnecessary and adds complexity when all deps are self-contained

set(LIBBSD_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --prefix=/usr
    ${LIBBSD_CONFIGURE_LIB_TYPE}
    # Note: Symbol versioning is disabled via patch in cmake/ruby-app/patches/libbsd/linux/
    # because configure doesn't support --disable-symbol-versioning
)

# Build libbsd dependency (Linux only)
# Android's Bionic libc provides its own BSD compatibility
# libbsd depends on libmd for MD5 functions
if(TARGET_PLATFORM STREQUAL "Linux")
    add_external_dependency(
        NAME libbsd
        VERSION ${LIBBSD_VERSION}
        URL ${LIBBSD_URL}
        URL_HASH ${LIBBSD_HASH}
        CONFIGURE_COMMAND ${LIBBSD_CONFIGURE_CMD}
        DEPENDS libmd
    )
endif()
