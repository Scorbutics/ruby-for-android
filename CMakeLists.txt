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
include("${CMAKE_SOURCE_DIR}/cmake/ruby-app/ruby-versions.cmake")

set(RUBY_APP_DEPENDENCIES zlib gmp libffi ncurses readline gdbm openssl libmd libbsd libxcrypt)
if(RUBY_NEEDS_LIBYAML)
    list(APPEND RUBY_APP_DEPENDENCIES libyaml)
endif()
list(APPEND RUBY_APP_DEPENDENCIES ruby)

declare_application(
    APP_NAME "CRuby"
    APP_DIR "${CMAKE_SOURCE_DIR}/cmake/ruby-app"
    APP_DEPENDENCIES "${RUBY_APP_DEPENDENCIES}"
    APP_VERSION "${RUBY_VERSION}"
    APP_DESCRIPTION "Ruby Programming Language for Cross-Platform Targets"
)