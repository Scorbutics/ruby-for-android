# ruby-physfs.cmake
# Configuration for the ruby-physfs gem (https://github.com/Scorbutics/ruby-physfs).
#
# This is a Ruby C-extension on top of PhysicsFS. The gem only ships an
# extconf.rb / Rakefile, both awkward to cross-compile, so we build its
# four .cpp files via a small in-tree CMakeLists.txt
# (scripts/ruby-physfs/CMakeLists.txt). Output is libphysfs-ruby.a, which
# gets linked into embedded-ruby-vm so Init_physfs becomes reachable.
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

set(_RUBY_PHYSFS_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}/scripts/ruby-physfs")

# Reuse the RUBY_ABI_VERSION declared in ruby.cmake (it's loaded earlier
# because Application.cmake processes APP_DEPENDENCIES in the listed order).
if(NOT DEFINED RUBY_ABI_VERSION)
    message(FATAL_ERROR "ruby-physfs requires RUBY_ABI_VERSION to be defined "
                        "(should be set by ruby.cmake — declare ruby earlier "
                        "in APP_DEPENDENCIES).")
endif()

get_sub_cmake_cross_args(_RUBY_PHYSFS_CMAKE_ARGS)

add_external_dependency(
    NAME            ruby-physfs
    VERSION         ${RUBY_PHYSFS_VERSION}
    GIT_REPOSITORY  ${RUBY_PHYSFS_GIT_REPO}
    GIT_TAG         ${RUBY_PHYSFS_GIT_TAG}
    GIT_SHALLOW     TRUE
    ARCHIVE_NAME    "ruby-physfs-${RUBY_PHYSFS_VERSION}"
    BUILD_IN_SOURCE FALSE
    # -S points at our in-tree CMakeLists.txt (NOT the cloned gem repo). The
    # gem source path is forwarded as -DGEM_SOURCE_DIR so the build script
    # can pick up ext/physfs/*.cpp.
    CONFIGURE_COMMAND ${CMAKE_COMMAND}
                      -S "${_RUBY_PHYSFS_CMAKE_DIR}"
                      -B <BINARY_DIR>
                      ${_RUBY_PHYSFS_CMAKE_ARGS}
                      -DGEM_SOURCE_DIR=<SOURCE_DIR>
                      -DRUBY_STAGING_DIR=${BUILD_STAGING_DIR}
                      -DRUBY_ABI_VERSION=${RUBY_ABI_VERSION}
    BUILD_COMMAND     ${CMAKE_COMMAND} --build <BINARY_DIR> -j${BUILD_PARALLEL_JOBS}
    # The gem's lib/physfs.rb is intentionally NOT installed — `require 'physfs'`
    # is satisfied at runtime by extension-init.c calling Init_physfs() +
    # rb_provide("physfs"), and missing wiring would already fail at link time
    # with an "undefined reference to Init_physfs" error.
    INSTALL_COMMAND   ${CMAKE_COMMAND} --install <BINARY_DIR>
    DEPENDS         ruby physfs
)
