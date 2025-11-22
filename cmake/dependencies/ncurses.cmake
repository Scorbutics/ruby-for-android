# ncurses.cmake
# Configuration for ncurses dependency

set(NCURSES_VERSION "6.4")
set(NCURSES_URL "ftp://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz")
set(NCURSES_HASH "SHA256=6931283d9ac87c5073f30b6290c4c75f21632bb4fc3603ac8100812bed248159")

# Configure command (autoconf-based)
set(NCURSES_CONFIGURE_CMD
    ${CMAKE_COMMAND} -E env CPPFLAGS=-P
    ./configure
    --host=${RUBY_HOST_TRIPLET}
    --target=${RUBY_HOST_TRIPLET}
    --enable-term-driver
    --enable-sp-funcs
    --with-shared
    --with-versioned-syms=no
    --disable-stripping
)

# Build ncurses dependency
add_native_dependency(
    NAME ncurses
    VERSION ${NCURSES_VERSION}
    URL ${NCURSES_URL}
    URL_HASH ${NCURSES_HASH}
    CONFIGURE_COMMAND ${NCURSES_CONFIGURE_CMD}
)
