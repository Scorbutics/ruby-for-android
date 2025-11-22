# gdbm.cmake
# Configuration for GDBM (GNU Database Manager) dependency

set(GDBM_VERSION "1.18.1")
set(GDBM_URL "ftp://ftp.gnu.org/gnu/gdbm/gdbm-${GDBM_VERSION}.tar.gz")
set(GDBM_HASH "SHA256=86e613527e5dba544e73208f42b78b7c022d4fa5a6d5498bf18c8d6f745b91dc")

# Configure command (autoconf-based)
set(GDBM_CONFIGURE_CMD
    ./configure
    --host=${RUBY_HOST_TRIPLET}
    --target=${RUBY_HOST_TRIPLET}
    --enable-shared
    --disable-static
    --enable-libgdbm-compat
)

# Platform-specific adjustments
if(RUBY_TARGET_PLATFORM STREQUAL "Android")
    # Android needs -fcommon flag for compatibility
    set(GDBM_EXTRA_CFLAGS "-fcommon -fPIC")
endif()

# Prepend extra CFLAGS if needed
if(GDBM_EXTRA_CFLAGS)
    list(INSERT GDBM_CONFIGURE_CMD 0
        ${CMAKE_COMMAND} -E env "CFLAGS=\$CFLAGS ${GDBM_EXTRA_CFLAGS}"
    )
endif()

# Build GDBM dependency
add_native_dependency(
    NAME gdbm
    VERSION ${GDBM_VERSION}
    URL ${GDBM_URL}
    URL_HASH ${GDBM_HASH}
    CONFIGURE_COMMAND ${GDBM_CONFIGURE_CMD}
)
