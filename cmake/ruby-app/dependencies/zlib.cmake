# zlib.cmake
# Configuration for zlib compression library

set(ZLIB_VERSION "1.3.1")
set(ZLIB_URL "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz")
set(ZLIB_HASH "SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23")

# Configure command (autoconf-based)
if(BUILD_SHARED_LIBS)
    set(ZLIB_CONFIGURE_LIB_TYPE
        --shared
    )
else()
    set(ZLIB_CONFIGURE_LIB_TYPE
        --static
    )
endif()

set(ZLIB_CONFIGURE_CMD
    ./configure
    ${ZLIB_CONFIGURE_LIB_TYPE}
)

# Build zlib dependency
add_external_dependency(
    NAME zlib
    VERSION ${ZLIB_VERSION}
    URL ${ZLIB_URL}
    URL_HASH ${ZLIB_HASH}
    CONFIGURE_COMMAND ${ZLIB_CONFIGURE_CMD}
)
