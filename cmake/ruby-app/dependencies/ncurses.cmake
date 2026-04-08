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

    # iOS: the host triplet aarch64-apple-darwin defines __APPLE__, which
    # makes ncurses assume ospeed is 'short' (NCURSES_OSPEED_COMPAT=1).
    # That triggers #include <sys/ttydev.h> in lib_baudrate.c, but the
    # iOS SDK doesn't ship that header. --with-ospeed=unsigned sets
    # NCURSES_OSPEED_COMPAT=0, skipping the problematic include entirely.
    set(NCURSES_PLATFORM_CONFIGURE_ARGS "")
    if(TARGET_PLATFORM STREQUAL "iOS")
        set(NCURSES_PLATFORM_CONFIGURE_ARGS
            --with-ospeed=unsigned
            --without-progs
            --without-tests
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
