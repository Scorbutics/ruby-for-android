# gdbm.cmake
# Configuration for GDBM (GNU Database Manager) dependency

set(GDBM_VERSION "1.18.1")
# Use HTTPS instead of FTP to avoid firewall/Docker networking issues
set(GDBM_URL "https://ftp.gnu.org/gnu/gdbm/gdbm-${GDBM_VERSION}.tar.gz")
set(GDBM_HASH "SHA256=86e613527e5dba544e73208f42b78b7c022d4fa5a6d5498bf18c8d6f745b91dc")

# Configure command (autoconf-based)
if(BUILD_SHARED_LIBS)
    set(GDBM_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(GDBM_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
    )
endif()

set(GDBM_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --target=${HOST_TRIPLET}
    ${GDBM_CONFIGURE_LIB_TYPE}
    --enable-libgdbm-compat
)

# Platform-specific adjustments
set(GDBM_ENV_VARS "")
if(TARGET_PLATFORM STREQUAL "Android")
    # Android needs -fcommon flag for compatibility
    set(GDBM_CFLAGS "${CFLAGS} -fcommon -fPIC")
    set(GDBM_ENV_VARS "CFLAGS=${GDBM_CFLAGS}")
endif()

# Build GDBM dependency
add_external_dependency(
    NAME gdbm
    VERSION ${GDBM_VERSION}
    URL ${GDBM_URL}
    URL_HASH ${GDBM_HASH}
    CONFIGURE_COMMAND ${GDBM_CONFIGURE_CMD}
    ENV_VARS ${GDBM_ENV_VARS}
)
