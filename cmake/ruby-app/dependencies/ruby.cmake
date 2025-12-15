# ruby.cmake
# Configuration for Ruby itself

set(RUBY_MAJOR_VERSION "3.1")
set(RUBY_VERSION "3.1.1")
set(RUBY_URL "http://ftp.ruby-lang.org/pub/ruby/${RUBY_MAJOR_VERSION}/ruby-${RUBY_VERSION}.tar.xz")
set(RUBY_HASH "SHA256=7aefaa6b78b076515d272ec59c4616707a54fc9f2391239737d5f10af7a16caa")

# Configure command (autoconf-based)
set(RUBY_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    --target=${HOST_TRIPLET}
)

# Add shared library option if enabled
if(RUBY_ENABLE_SHARED)
    list(APPEND RUBY_CONFIGURE_CMD --enable-shared)
else()
    list(APPEND RUBY_CONFIGURE_CMD --disable-shared --enable-static)
endif()

# Disable documentation if requested
if(RUBY_DISABLE_INSTALL_DOC)
    list(APPEND RUBY_CONFIGURE_CMD --disable-install-doc)
endif()

if(NOT BUILD_STAGING_DIR)
    message(FATAL_ERROR "Ruby: BUILD_STAGING_DIR is required for the install")
endif()

# Custom install command to skip docs
set(RUBY_INSTALL_CMD make install-nodoc DESTDIR=${BUILD_STAGING_DIR})

# Build Ruby (depends on all other libraries)
add_external_dependency(
    NAME ruby
    VERSION ${RUBY_VERSION}
    URL ${RUBY_URL}
    URL_HASH ${RUBY_HASH}
    ARCHIVE_NAME "ruby-${RUBY_VERSION}"
    CONFIGURE_COMMAND ${RUBY_CONFIGURE_CMD}
    INSTALL_COMMAND ${RUBY_INSTALL_CMD}
    DEPENDS openssl gdbm readline
)

# Construct archive name from platform and architecture
string(TOLOWER "${TARGET_PLATFORM}" PLATFORM_LOWER)
set(RUBY_FULL_ARCHIVE_NAME "ruby_full-${PLATFORM_LOWER}-${TARGET_ARCH}.zip")

# Determine archive contents based on ENABLE_SHARED
if(ENABLE_SHARED)
    # Shared library build: include .so files
    set(RUBY_LIB_EXTENSION "so")
else()
    # Static library build: include .a files
    set(RUBY_LIB_EXTENSION "a")
endif()

set(RUBY_ARCHIVE_INCLUDES
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
    DEPENDS ruby_external  # Archive waits for the ExternalProject to complete
)

# Make the ruby alias target include the archive
# So 'make ruby' builds: ruby_external → ruby_archive → ruby
add_dependencies(ruby ruby_archive)
