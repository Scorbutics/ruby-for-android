# ruby.cmake
# Configuration for Ruby itself

set(RUBY_MAJOR_VERSION "3.1")
set(RUBY_VERSION "3.1.1")
set(RUBY_URL "http://ftp.ruby-lang.org/pub/ruby/${RUBY_MAJOR_VERSION}/ruby-${RUBY_VERSION}.tar.xz")
set(RUBY_HASH "SHA256=7aefaa6b78b076515d272ec59c4616707a54fc9f2391239737d5f10af7a16caa")

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
    )
    message(STATUS "Ruby: Building as STATIC library (libruby-static.a)")
endif()


# Disable documentation if requested
if(RUBY_DISABLE_INSTALL_DOC)
    list(APPEND RUBY_CONFIGURE_CMD --disable-install-doc)
endif()

if(NOT BUILD_STAGING_DIR)
    message(FATAL_ERROR "Ruby: BUILD_STAGING_DIR is required for the install")
endif()

# Verification script to check for missing critical extensions
set(VERIFY_EXTENSIONS_SCRIPT "${APP_DIR}/scripts/verify_ruby_extensions.sh")

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
add_external_dependency(
    NAME ruby
    VERSION ${RUBY_VERSION}
    URL ${RUBY_URL}
    URL_HASH ${RUBY_HASH}
    ARCHIVE_NAME "ruby-${RUBY_VERSION}"
    CONFIGURE_COMMAND ${RUBY_CONFIGURE_CMD}
    INSTALL_COMMAND ${RUBY_INSTALL_CMD}
    DEPENDS zlib openssl gdbm readline
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
            -P ${CMAKE_CURRENT_LIST_DIR}/../scripts/combine_ruby_extensions.cmake
        DEPENDS ruby_external
        COMMENT "Combining Ruby extension .a files into libruby-ext.a"
    )

    # Make ruby depend on the combined extensions library
    add_dependencies(ruby ruby_combine_extensions)
endif()

# Construct archive name from platform and architecture
string(TOLOWER "${TARGET_PLATFORM}" PLATFORM_LOWER)
set(RUBY_FULL_ARCHIVE_NAME "ruby_full-${PLATFORM_LOWER}-${TARGET_ARCH}.zip")

# Determine archive contents based on BUILD_SHARED_LIBS
if(BUILD_SHARED_LIBS)
    # Shared library build: include .so files
    set(RUBY_LIB_EXTENSION "so")
else()
    # Static library build: include .a files
    set(RUBY_LIB_EXTENSION "a")
endif()

set(RUBY_ARCHIVE_INCLUDES
    usr/lib/lib*.${RUBY_LIB_EXTENSION}
    usr/local/include/ruby-*/
    usr/local/lib/ruby/
    usr/local/lib/lib*.${RUBY_LIB_EXTENSION}
    usr/local/bin/irb
    usr/local/bin/gem
    usr/local/bin/rake
    usr/local/bin/ruby
    usr/local/bin/bundle
    usr/local/bin/bundler
)

# Create archive target (automatically registers in TARGET_ARCHIVES)
# Dependency chain: ruby_external (ExternalProject) → ruby_archive → ruby (alias)
create_archive_target(
    NAME ruby_archive
    OUTPUT ${RUBY_FULL_ARCHIVE_NAME}
    INCLUDES ${RUBY_ARCHIVE_INCLUDES}
    DEPENDS ruby_combine_extensions  # Archive waits for the ExternalProject to complete and the combining of extensions
)

# Make the ruby alias target include the archive
# So 'make ruby' builds: ruby_external → ruby_archive → ruby
add_dependencies(ruby ruby_archive)
