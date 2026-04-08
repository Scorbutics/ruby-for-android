# ncurses.cmake
# Configuration for ncurses dependency

set(NCURSES_VERSION "6.4")
# Use HTTPS instead of FTP to avoid firewall/Docker networking issues
set(NCURSES_URL "https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz")
set(NCURSES_HASH "SHA256=6931283d9ac87c5073f30b6290c4c75f21632bb4fc3603ac8100812bed248159")

# Configure command (autoconf-based)
# When cross-compiling, ncurses needs separate compilers for:
# - BUILD tools (native, to generate terminfo): --with-build-cc
# - TARGET libraries (cross-compiled): CC from environment

if(BUILD_SHARED_LIBS)
    set(NCURSES_CONFIGURE_LIB_TYPE
        --with-shared
    )
else()
    set(NCURSES_CONFIGURE_LIB_TYPE
        --without-shared
        --enable-static
        --with-pic
    )
endif()

# Detect build (host) CC for ncurses cross-compilation
# macOS/iOS builds run on macOS hosts which only have clang via Xcode
if(CMAKE_HOST_APPLE)
    set(NCURSES_BUILD_CC "clang")
else()
    set(NCURSES_BUILD_CC "gcc")
endif()

    # iOS SDK doesn't have sys/ttydev.h (exists on macOS but not iOS).
    # Since the host triplet looks like macOS (aarch64-apple-darwin),
    # autoconf's cross-compile guess wrongly assumes the header exists.
    set(NCURSES_PLATFORM_CONFIGURE_ARGS "")
    if(TARGET_PLATFORM STREQUAL "iOS")
        set(NCURSES_PLATFORM_CONFIGURE_ARGS
            ac_cv_header_sys_ttydev_h=no
        )
    endif()

    set(NCURSES_CONFIGURE_CMD
        ./configure
        --host=${HOST_TRIPLET}
        --target=${HOST_TRIPLET}
        --with-build-cc=${NCURSES_BUILD_CC}
        --enable-term-driver
        --enable-sp-funcs
        ${NCURSES_CONFIGURE_LIB_TYPE}
        --with-versioned-syms=no
        --disable-stripping
        ${NCURSES_PLATFORM_CONFIGURE_ARGS}
    )

# Build ncurses dependency
# Note: ncurses requires CPPFLAGS=-P for proper preprocessing
# We need to append it to the existing CPPFLAGS from RUBY_BUILD_ENV
add_external_dependency(
    NAME ncurses
    VERSION ${NCURSES_VERSION}
    URL ${NCURSES_URL}
    URL_HASH ${NCURSES_HASH}
    CONFIGURE_COMMAND ${NCURSES_CONFIGURE_CMD}
    ENV_VARS "CPPFLAGS=${CPPFLAGS} -P"
)
