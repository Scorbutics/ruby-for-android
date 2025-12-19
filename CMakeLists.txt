cmake_minimum_required(VERSION 3.10)
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
    APP_DEPENDENCIES "zlib;gmp;libmd;libbsd;libxcrypt;ncurses;readline;gdbm;openssl;ruby"
    APP_VERSION "3.1.1"
    APP_DESCRIPTION "Ruby Programming Language for Cross-Platform Targets"
)