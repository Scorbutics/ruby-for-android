# ruby.cmake
# Configuration for Ruby itself
#
# RUBY_VERSION, RUBY_MAJOR_VERSION, RUBY_ABI_VERSION and RUBY_TARBALL_SHA256
# come from ruby-versions.cmake.

set(RUBY_URL "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR_VERSION}/ruby-${RUBY_VERSION}.tar.xz")
set(RUBY_HASH "SHA256=${RUBY_TARBALL_SHA256}")

# Configure command (autoconf-based)
# --with-opt-dir: Tell Ruby where to find external libraries (zlib, openssl, readline, gdbm)
#                 This adds the staging directory to both include and library search paths
# Note: We don't use --with-ext because it's EXCLUSIVE (only builds specified extensions)
#       Instead, we let Ruby build all default extensions, and the build will fail naturally
#       if required external dependencies (zlib, openssl, readline, gdbm) are missing
set(RUBY_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --target=${HOST_TRIPLET}
    --with-opt-dir=${BUILD_STAGING_DIR}/usr
    --with-openssl-dir=${BUILD_STAGING_DIR}/usr/local
)

# fiddle and psych always link the libffi and libyaml this project builds
# (installed under usr/local, outside --with-opt-dir). Ruby 3.2+ no longer
# bundles them; Ruby 3.0/3.1 bundle them but only use the copies when no
# libyaml/libffi is found, which would make the result depend on what the
# build host has installed.
list(APPEND RUBY_CONFIGURE_CMD
    --with-libffi-dir=${BUILD_STAGING_DIR}/usr/local
    --with-libyaml-dir=${BUILD_STAGING_DIR}/usr/local
)

# Use BUILD_SHARED_LIBS to control Ruby build mode
if(BUILD_SHARED_LIBS)
    list(APPEND RUBY_CONFIGURE_CMD --enable-shared)
    message(STATUS "Ruby: Building as SHARED library (libruby.so)")
else()
    # Build Ruby as static library with static extension support
    list(APPEND RUBY_CONFIGURE_CMD
        --disable-shared
        --enable-static
        --with-static-linked-ext
        --disable-dln
        --with-pic
    )
    message(STATUS "Ruby: Building as STATIC library (libruby-static.a) with PIC")
endif()


# Disable documentation if requested
if(RUBY_DISABLE_INSTALL_DOC)
    list(APPEND RUBY_CONFIGURE_CMD --disable-install-doc)
endif()

if(NOT BUILD_STAGING_DIR)
    message(FATAL_ERROR "Ruby: BUILD_STAGING_DIR is required for the install")
endif()

# Verification script to check for missing critical extensions
set(VERIFY_EXTENSIONS_SCRIPT "${CMAKE_SOURCE_DIR}/cmake/ruby-app/scripts/verify_ruby_extensions.sh")

string(TOLOWER "${TARGET_PLATFORM}" PLATFORM_LOWER)
set(RUBY_BUILD_DIR "${CMAKE_BINARY_DIR}/ruby/build_dir/${TARGET_ARCH}-${PLATFORM_LOWER}" CACHE PATH "Staging directory for installation")

# Custom install command with validation
# 1. Run make install-nodoc
# 2. Verify critical extensions were built by checking the build log
set(RUBY_INSTALL_CMD
    make install-nodoc DESTDIR=${BUILD_STAGING_DIR}
    COMMAND sh ${VERIFY_EXTENSIONS_SCRIPT} ${RUBY_BUILD_DIR}/stamps/ruby_external-build-out.log
)

# Build Ruby (depends on all other libraries)
# Static dependencies: zlib, gmp, libxcrypt (Linux only)
# Shared dependencies from system: openssl, gdbm, readline, ncurses
set(RUBY_DEPENDENCIES zlib gmp libffi libyaml openssl gdbm readline)

# Add libxcrypt for Linux builds only (Android's Bionic doesn't provide crypt)
if(TARGET_PLATFORM STREQUAL "Linux")
    list(APPEND RUBY_DEPENDENCIES libxcrypt)
endif()

# Platform-specific environment variables
set(RUBY_ENV_VARS "")
if(TARGET_PLATFORM STREQUAL "Android")
    # Ruby needs DLDFLAGS set explicitly for extension builds on Android
    # DLDFLAGS is used by mkmf.rb when building native extensions
    set(RUBY_ENV_VARS "DLDFLAGS=${LDFLAGS}")
endif()

# iOS: disable getattrlist/fgetattrlist. These APIs exist on iOS but use vnode
# constants (VREG, VDIR, VT_HFS) from <sys/vnode.h> which is not in the iOS SDK.
# Ruby falls back to standard POSIX stat()/readdir().
if(TARGET_PLATFORM STREQUAL "iOS")
    list(APPEND RUBY_CONFIGURE_CMD
        ac_cv_func_getattrlist=no
        ac_cv_func_fgetattrlist=no
    )
endif()

add_external_dependency(
    NAME ruby
    VERSION ${RUBY_VERSION}
    URL ${RUBY_URL}
    URL_HASH ${RUBY_HASH}
    ARCHIVE_NAME "ruby-${RUBY_VERSION}"
    CONFIGURE_COMMAND ${RUBY_CONFIGURE_CMD}
    INSTALL_COMMAND ${RUBY_INSTALL_CMD}
    ENV_VARS ${RUBY_ENV_VARS}
    DEPENDS ${RUBY_DEPENDENCIES}
    STRICT_PATCHES
)

# Recompute SOURCE_DIR the way BuildHelpers does it (see line 87) so we can
# attach extra steps to the externalproject. ExternalProject_Get_Property
# would work too but requires the project to be finalized.
set(_RUBY_SOURCE_DIR "${CMAKE_BINARY_DIR}/ruby/build_dir/${TARGET_ARCH}-${PLATFORM_LOWER}/ruby-${RUBY_VERSION}")

# Ruby bundles the `debug` gem since 3.1. For older versions, fetch the same
# release 3.3 bundles (it supports Ruby >= 2.7) so remote DAP debugging works
# the same on every build.
set(_DEBUG_GEM_ARCHIVE "")
if(RUBY_VERSION VERSION_LESS "3.1")
    set(_DEBUG_GEM_VERSION "1.9.2")
    set(_DEBUG_GEM_ARCHIVE "${BUILD_DOWNLOAD_DIR}/debug-${_DEBUG_GEM_VERSION}.gem")
    file(DOWNLOAD
        "https://rubygems.org/downloads/debug-${_DEBUG_GEM_VERSION}.gem"
        "${_DEBUG_GEM_ARCHIVE}"
        EXPECTED_HASH SHA256=48e026c0852c7a10c60263e2e527968308958e266231e36d64e3efcabec7e7fc
        TLS_VERIFY ON
    )
endif()

# Promote the bundled `debug` gem to a first-class Ruby ext so it gets
# statically linked alongside socket / io_console / objspace. See the script
# header comments for the full rationale. Without this, --with-static-linked-ext
# causes rbinstall.rb to silently drop the gem, breaking remote DAP debugging.
ExternalProject_Add_Step(ruby_external integrate_debug_gem
    COMMAND ${CMAKE_COMMAND}
        -DRUBY_SOURCE_DIR=${_RUBY_SOURCE_DIR}
        -DDEBUG_GEM_ARCHIVE=${_DEBUG_GEM_ARCHIVE}
        -P ${CMAKE_CURRENT_LIST_DIR}/../scripts/integrate_debug_gem.cmake
    DEPENDEES patch
    DEPENDERS configure
    LOG TRUE
    LOG_OUTPUT_ON_FAILURE TRUE
    COMMENT "Promoting bundled `debug` gem ext into Ruby ext/debug/"
)

# Companion post-install: copy the gem's pure-Ruby lib/ into staging so
# `require 'debug'` resolves via RUBYLIB. The C ext was handled above.
ExternalProject_Add_Step(ruby_external install_debug_gem_lib
    COMMAND ${CMAKE_COMMAND}
        -DRUBY_SOURCE_DIR=${_RUBY_SOURCE_DIR}
        -DSTAGING_DIR=${BUILD_STAGING_DIR}
        -DRUBY_ABI_VERSION=${RUBY_ABI_VERSION}
        -P ${CMAKE_CURRENT_LIST_DIR}/../scripts/install_debug_gem_lib.cmake
    DEPENDEES install
    LOG TRUE
    LOG_OUTPUT_ON_FAILURE TRUE
    COMMENT "Installing debug gem pure-Ruby lib into staging"
)

# For static builds, create a combined extensions library (libruby-ext.a)
if(NOT BUILD_SHARED_LIBS)
    set(RUBY_EXT_LIB "${BUILD_STAGING_DIR}/usr/local/lib/libruby-ext.a")

    add_custom_target(ruby_combine_extensions
        COMMAND ${CMAKE_COMMAND} -E echo "Creating combined extensions library: libruby-ext.a"
        COMMAND ${CMAKE_COMMAND}
            -DRUBY_BUILD_DIR=${RUBY_BUILD_DIR}
            -DRUBY_VERSION=${RUBY_VERSION}
            -DOUTPUT_LIB=${RUBY_EXT_LIB}
            -DCROSS_AR=${CROSS_AR}
            -DSTAGING_LIB_DIR=${BUILD_STAGING_DIR}/usr/local/lib
            -P ${CMAKE_CURRENT_LIST_DIR}/../scripts/combine_ruby_extensions.cmake
        DEPENDS ruby_external
        COMMENT "Combining Ruby extension .a files into libruby-ext.a"
    )

    # Make ruby depend on the combined extensions library
    add_dependencies(ruby ruby_combine_extensions)
endif()

# Construct archive name from platform and architecture
string(TOLOWER "${TARGET_PLATFORM}" PLATFORM_LOWER)
# For iOS, include device/simulator variant so archives don't collide
if(IOS AND DEFINED IOS_PLATFORM)
    set(_ARCHIVE_PLATFORM "${PLATFORM_LOWER}-${IOS_PLATFORM}")
else()
    set(_ARCHIVE_PLATFORM "${PLATFORM_LOWER}")
endif()
set(RUBY_FULL_ARCHIVE_NAME "ruby_full-${_ARCHIVE_PLATFORM}-${TARGET_ARCH}.zip")

# Create custom archive target using our restructuring script
# This replaces the simple create_archive_target() with a custom command
# that reorganizes the directory structure according to project requirements

# Set the output path for the archive
set(RUBY_ARCHIVE_OUTPUT "${BUILD_STAGING_DIR}/${RUBY_FULL_ARCHIVE_NAME}")

# Determine dependencies based on build type
if(BUILD_SHARED_LIBS)
    set(RUBY_ARCHIVE_DEPS ruby_external)
else()
    set(RUBY_ARCHIVE_DEPS ruby_combine_extensions)
endif()

add_custom_target(ruby_archive
    COMMAND ${CMAKE_COMMAND}
        -DBUILD_STAGING_DIR=${BUILD_STAGING_DIR}
        -DHOST_TRIPLET=${HOST_TRIPLET}
        -DPLATFORM_LOWER=${PLATFORM_LOWER}
        -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
        -DARCHIVE_OUTPUT=${RUBY_ARCHIVE_OUTPUT}
        -DRUBY_VERSION=${RUBY_VERSION}
        -DRUBY_ABI_VERSION=${RUBY_ABI_VERSION}
        -P ${CMAKE_CURRENT_LIST_DIR}/../scripts/create_ruby_archive.cmake
    DEPENDS ${RUBY_ARCHIVE_DEPS}
    COMMENT "Creating restructured Ruby archive: ${RUBY_FULL_ARCHIVE_NAME}"
)

# Register this archive for export
if(NOT DEFINED TARGET_ARCHIVES)
    set(TARGET_ARCHIVES "" CACHE STRING "List of archives to export (relative to BUILD_STAGING_DIR)" FORCE)
endif()
set(TARGET_ARCHIVES "${TARGET_ARCHIVES};${RUBY_FULL_ARCHIVE_NAME}" CACHE STRING "List of archives to export (relative to BUILD_STAGING_DIR)" FORCE)
message(STATUS "Registered archive for export: ${RUBY_FULL_ARCHIVE_NAME}")

# Make the ruby alias target include the archive
# So 'make ruby' builds: ruby_external → ruby_archive → ruby
add_dependencies(ruby ruby_archive)

# --- Link test target ---
# Compile and link a minimal C program against the built static libraries
# to verify no symbols are missing. Only for static builds.
#
# We write a config file because CROSS_CC, CFLAGS, and LDFLAGS contain spaces
# that get mangled when passed via -D on a COMMAND line.
if(NOT BUILD_SHARED_LIBS)
    set(LINK_TEST_SRC "${CMAKE_SOURCE_DIR}/cmake/ruby-app/tests/link_test.c")
    set(LINK_TEST_BIN "${CMAKE_BINARY_DIR}/link_test_${PLATFORM_LOWER}_${TARGET_ARCH}")
    set(LINK_TEST_SCRIPT "${CMAKE_SOURCE_DIR}/cmake/ruby-app/scripts/link_test.cmake")
    set(LINK_TEST_CONFIG "${CMAKE_BINARY_DIR}/link_test_config.cmake")

    file(WRITE "${LINK_TEST_CONFIG}"
        "set(BUILD_STAGING_DIR \"${BUILD_STAGING_DIR}\")\n"
        "set(RUBY_ABI_VERSION \"${RUBY_ABI_VERSION}\")\n"
        "set(CROSS_CC \"${CROSS_CC}\")\n"
        "set(CFLAGS \"${CFLAGS}\")\n"
        "set(LDFLAGS \"${LDFLAGS}\")\n"
        "set(TARGET_PLATFORM \"${TARGET_PLATFORM}\")\n"
        "set(LINK_TEST_SRC \"${LINK_TEST_SRC}\")\n"
        "set(LINK_TEST_BIN \"${LINK_TEST_BIN}\")\n"
    )

    add_custom_target(link_test
        COMMAND ${CMAKE_COMMAND}
            -DLINK_TEST_CONFIG=${LINK_TEST_CONFIG}
            -P ${LINK_TEST_SCRIPT}
        DEPENDS ruby_archive
        COMMENT "Running link test: verifying no missing symbols"
    )
endif()
