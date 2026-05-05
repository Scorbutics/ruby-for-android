# ruby-physfs.cmake
# Configuration for the ruby-physfs gem (https://github.com/Scorbutics/ruby-physfs).
#
# This is a Ruby C-extension on top of PhysicsFS. We bypass the gem's
# mkmf-based extconf.rb (mkmf is awkward to cross-compile) and instead
# compile the four .cpp files directly with the cross-toolchain. Output
# is libphysfs-ruby.a, which gets linked into embedded-ruby-vm so that
# Init_physfs becomes a reachable symbol.
#
# DEPENDS on:
#   - ruby   (we need its installed headers to compile against)
#   - physfs (we need libphysfs.a to link against, plus physfs.h)
#
# The embedder is responsible for calling Init_physfs() + rb_provide("physfs")
# from a RubyCustomExtInit callback — see scripts/README.md for the contract.
# Forgetting the wiring fails fast at link time with an "undefined reference
# to Init_physfs" error, so no runtime stub .rb is needed.

set(RUBY_PHYSFS_VERSION "0.1.0")
set(RUBY_PHYSFS_GIT_REPO "https://github.com/Scorbutics/ruby-physfs.git")
# Pin to a specific tag/commit when the gem stabilizes; for now track master.
set(RUBY_PHYSFS_GIT_TAG "master")

set(_RUBY_PHYSFS_SCRIPTS "${CMAKE_CURRENT_LIST_DIR}/scripts")

# Reuse the RUBY_ABI_VERSION declared in ruby.cmake (it's loaded earlier
# because Application.cmake processes APP_DEPENDENCIES in the listed order).
if(NOT DEFINED RUBY_ABI_VERSION)
    message(FATAL_ERROR "ruby-physfs requires RUBY_ABI_VERSION to be defined "
                        "(should be set by ruby.cmake — declare ruby earlier "
                        "in APP_DEPENDENCIES).")
endif()

add_external_dependency(
    NAME            ruby-physfs
    VERSION         ${RUBY_PHYSFS_VERSION}
    GIT_REPOSITORY  ${RUBY_PHYSFS_GIT_REPO}
    GIT_TAG         ${RUBY_PHYSFS_GIT_TAG}
    GIT_SHALLOW     TRUE
    ARCHIVE_NAME    "ruby-physfs-${RUBY_PHYSFS_VERSION}"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E true
    # Build is a pure-CMake script (no shell) — works on Linux/macOS/Windows
    # build hosts. The script reads CXX/CFLAGS/AR from the env that
    # add_external_dependency injects via `cmake -E env ${BUILD_ENV}`,
    # and STAGING_DIR / RUBY_ABI_VERSION via -D arguments.
    BUILD_COMMAND   ${CMAKE_COMMAND}
                    -DSTAGING_DIR=${BUILD_STAGING_DIR}
                    -DRUBY_ABI_VERSION=${RUBY_ABI_VERSION}
                    -P "${_RUBY_PHYSFS_SCRIPTS}/build_ruby_physfs.cmake"
    # Install: copy the static lib into staging. The gem's lib/physfs.rb
    # is intentionally NOT installed — `require 'physfs'` is satisfied at
    # runtime by extension-init.c calling Init_physfs() + rb_provide("physfs"),
    # and missing wiring would already fail at link time with an
    # "undefined reference to Init_physfs" error.
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory "${BUILD_STAGING_DIR}/usr/local/lib"
            COMMAND ${CMAKE_COMMAND} -E copy libphysfs-ruby.a "${BUILD_STAGING_DIR}/usr/local/lib/"
    DEPENDS         ruby physfs
)
