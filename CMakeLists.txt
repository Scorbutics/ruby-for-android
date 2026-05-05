cmake_minimum_required(VERSION 3.14)
project(cruby-cross-platform)

# ============================================================================
# CORE BUILD SYSTEM - Generic cross-platform infrastructure
# ============================================================================
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/core")

include(Main)

# ============================================================================
# APPLICATION DECLARATION - Ruby-specific configuration
# ============================================================================
declare_application(
    APP_NAME "CRuby"
    APP_DIR "${CMAKE_SOURCE_DIR}/cmake/ruby-app"
    # Order matters: physfs builds independently, ruby-physfs depends on
    # `ruby` (for headers) and `physfs` (for libphysfs.a + physfs.h),
    # so both must precede it in this list.
    APP_DEPENDENCIES "zlib;gmp;libffi;ncurses;readline;gdbm;openssl;libmd;libbsd;libxcrypt;ruby;physfs;ruby-physfs"
    APP_VERSION "3.1.1"
    APP_DESCRIPTION "Ruby Programming Language for Cross-Platform Targets"
)