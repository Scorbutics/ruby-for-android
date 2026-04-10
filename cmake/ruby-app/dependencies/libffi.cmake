# libffi.cmake
# Configuration for libffi (Foreign Function Interface) dependency
# Required by Ruby's fiddle extension for calling native C functions at runtime

set(LIBFFI_VERSION "3.4.6")
set(LIBFFI_URL "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz")
set(LIBFFI_HASH "SHA256=b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e")

# Configure command (autoconf-based)
if(BUILD_SHARED_LIBS)
    set(LIBFFI_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(LIBFFI_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
        --with-pic
    )
endif()

set(LIBFFI_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --target=${HOST_TRIPLET}
    ${LIBFFI_CONFIGURE_LIB_TYPE}
    --includedir=/usr/local/include
)

# Platform-specific adjustments
set(LIBFFI_ENV_VARS "")

# Build libffi dependency
add_external_dependency(
    NAME libffi
    VERSION ${LIBFFI_VERSION}
    URL ${LIBFFI_URL}
    URL_HASH ${LIBFFI_HASH}
    CONFIGURE_COMMAND ${LIBFFI_CONFIGURE_CMD}
    ENV_VARS ${LIBFFI_ENV_VARS}
)
