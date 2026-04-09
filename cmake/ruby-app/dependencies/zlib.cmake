# zlib.cmake
# Configuration for zlib compression library

set(ZLIB_VERSION "1.3.2")
set(ZLIB_URL "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz")
set(ZLIB_HASH "SHA256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16")

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
