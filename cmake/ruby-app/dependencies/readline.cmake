# readline.cmake
# Configuration for readline dependency

set(READLINE_VERSION "8.1")
# Use HTTPS instead of FTP to avoid firewall/Docker networking issues
set(READLINE_URL "https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz")
set(READLINE_HASH "SHA256=f8ceb4ee131e3232226a17f51b164afc46cd0b9e6cef344be87c65962cb82b02")

# Configure command (autoconf-based)
# Note: readline needs autoconf to be run first
if(BUILD_SHARED_LIBS)
    set(READLINE_CONFIGURE_LIB_TYPE
        --enable-shared
    )
else()
    set(READLINE_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
    )
endif()

set(READLINE_CONFIGURE_CMD
    autoconf
    COMMAND ./configure
    --host=${HOST_TRIPLET}
    --target=${HOST_TRIPLET}
    ${READLINE_CONFIGURE_LIB_TYPE}
    --disable-install-examples
)

# Build readline dependency (depends on ncurses)
add_external_dependency(
    NAME readline
    VERSION ${READLINE_VERSION}
    URL ${READLINE_URL}
    URL_HASH ${READLINE_HASH}
    CONFIGURE_COMMAND ${READLINE_CONFIGURE_CMD}
    DEPENDS ncurses
)
