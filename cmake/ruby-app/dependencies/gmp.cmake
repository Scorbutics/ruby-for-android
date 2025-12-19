# gmp.cmake
# Configuration for GMP (GNU Multiple Precision Arithmetic Library)

set(GMP_VERSION "6.3.0")
set(GMP_URL "https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.xz")
set(GMP_HASH "SHA256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898")

# Configure command (autoconf-based)
# Always build as static library with PIC for Ruby embedding
if(BUILD_SHARED_LIBS)
    set(GMP_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(GMP_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
        --with-pic
    )
endif()

set(GMP_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --prefix=/usr
    ${GMP_CONFIGURE_LIB_TYPE}
)

# Build GMP dependency
add_external_dependency(
    NAME gmp
    VERSION ${GMP_VERSION}
    URL ${GMP_URL}
    URL_HASH ${GMP_HASH}
    CONFIGURE_COMMAND ${GMP_CONFIGURE_CMD}
)
