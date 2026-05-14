# install_debug_gem_lib.cmake
#
# Companion to integrate_debug_gem.cmake. After `make install-nodoc`, the
# debug gem's pure-Ruby files (lib/debug.rb, lib/debug/*.rb) are not in the
# staging tree because rbinstall.rb skipped the gem entirely (see
# integrate_debug_gem.cmake for context). The C extension is now statically
# linked thanks to the pre-configure step, but the Ruby half of the gem is
# still missing.
#
# This step copies the gem's lib/ tree into
# <staging>/usr/local/lib/ruby/<RUBY_ABI_VERSION>/, so `require 'debug'` and
# `require 'debug/open'` resolve via RUBYLIB without needing a default-gem
# gemspec registration.
#
# Required variables:
#   RUBY_SOURCE_DIR   - Ruby source root (after build)
#   STAGING_DIR       - DESTDIR root (<BUILD_STAGING_DIR>)
#   RUBY_ABI_VERSION  - e.g. "3.1.0"

cmake_minimum_required(VERSION 3.14)

foreach(VAR RUBY_SOURCE_DIR STAGING_DIR RUBY_ABI_VERSION)
    if(NOT DEFINED ${VAR})
        message(FATAL_ERROR "install_debug_gem_lib.cmake: ${VAR} is required")
    endif()
endforeach()

# Auto-detect the bundled debug gem dir. See integrate_debug_gem.cmake for the
# same pattern — the version is coupled to the Ruby release and pinning a
# literal would silently break on a Ruby upgrade.
file(GLOB _DEBUG_GEM_DIRS LIST_DIRECTORIES true "${RUBY_SOURCE_DIR}/.bundle/gems/debug-*")
list(LENGTH _DEBUG_GEM_DIRS _DEBUG_GEM_COUNT)
if(_DEBUG_GEM_COUNT EQUAL 0)
    message(FATAL_ERROR
        "No debug-* gem found under ${RUBY_SOURCE_DIR}/.bundle/gems/.\n"
        "Did integrate_debug_gem.cmake run before this step? Or has the Ruby "
        "version been upgraded to one where `debug` is no longer a bundled gem?")
endif()
if(_DEBUG_GEM_COUNT GREATER 1)
    message(FATAL_ERROR
        "Expected exactly one debug-* gem under ${RUBY_SOURCE_DIR}/.bundle/gems/, found: ${_DEBUG_GEM_DIRS}")
endif()
list(GET _DEBUG_GEM_DIRS 0 _DEBUG_GEM_DIR)
get_filename_component(_DEBUG_GEM_DIRNAME "${_DEBUG_GEM_DIR}" NAME)
message(STATUS "Detected bundled debug gem: ${_DEBUG_GEM_DIRNAME}")

set(DEBUG_GEM_LIB "${_DEBUG_GEM_DIR}/lib")
set(TARGET_LIB_DIR "${STAGING_DIR}/usr/local/lib/ruby/${RUBY_ABI_VERSION}")

if(NOT EXISTS "${DEBUG_GEM_LIB}/debug.rb")
    message(FATAL_ERROR
        "debug gem lib not found at ${DEBUG_GEM_LIB}/debug.rb.\n"
        "The bundled gem dir was detected but its lib/debug.rb is missing — "
        "possibly the gem's layout changed in this Ruby version.")
endif()

if(NOT EXISTS "${TARGET_LIB_DIR}")
    message(FATAL_ERROR
        "Staging stdlib dir ${TARGET_LIB_DIR} does not exist.\n"
        "This step must run after Ruby's install-nodoc step.")
endif()

message(STATUS "Installing debug gem pure-Ruby lib into staging")
message(STATUS "  Source: ${DEBUG_GEM_LIB}/")
message(STATUS "  Target: ${TARGET_LIB_DIR}/")

# Copy debug.rb and the entire debug/ subdir. file(COPY) overwrites, so this
# is safe to re-run.
file(COPY "${DEBUG_GEM_LIB}/debug.rb" DESTINATION "${TARGET_LIB_DIR}")
file(COPY "${DEBUG_GEM_LIB}/debug"    DESTINATION "${TARGET_LIB_DIR}")

# Sanity-check: the files we'll touch from the embedded VM must be present.
foreach(_REQUIRED debug.rb debug/open.rb debug/session.rb debug/server_dap.rb debug/config.rb)
    if(NOT EXISTS "${TARGET_LIB_DIR}/${_REQUIRED}")
        message(FATAL_ERROR "post-install verification failed: missing ${TARGET_LIB_DIR}/${_REQUIRED}")
    endif()
endforeach()

message(STATUS "  Installed: debug.rb + debug/*.rb (verified open.rb, session.rb, server_dap.rb, config.rb)")
