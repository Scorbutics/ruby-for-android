# ruby.cmake
# Configuration for Ruby itself

set(RUBY_MAJOR_VERSION "3.1")
set(RUBY_VERSION "3.1.1")
set(RUBY_URL "http://ftp.ruby-lang.org/pub/ruby/${RUBY_MAJOR_VERSION}/ruby-${RUBY_VERSION}.tar.xz")
set(RUBY_HASH "SHA256=53ec3f2d4ace5e35b3e4e766016e282e4f55dd6e9fac2df730ff9e1be3e15bff")

# Configure command (autoconf-based)
set(RUBY_CONFIGURE_CMD
    ./configure
    --host=${RUBY_HOST_TRIPLET}
    --target=${RUBY_HOST_TRIPLET}
)

# Add shared library option if enabled
if(RUBY_ENABLE_SHARED)
    list(APPEND RUBY_CONFIGURE_CMD --enable-shared)
else()
    list(APPEND RUBY_CONFIGURE_CMD --disable-shared)
endif()

# Disable documentation if requested
if(RUBY_DISABLE_INSTALL_DOC)
    list(APPEND RUBY_CONFIGURE_CMD --disable-install-doc)
endif()

# Custom install command to skip docs
set(RUBY_INSTALL_CMD make install-nodoc DESTDIR=${RUBY_BUILD_STAGING_DIR})

# Build Ruby (depends on all other libraries)
add_native_dependency(
    NAME ruby
    VERSION ${RUBY_VERSION}
    URL ${RUBY_URL}
    URL_HASH ${RUBY_HASH}
    ARCHIVE_NAME "ruby-${RUBY_VERSION}"
    CONFIGURE_COMMAND ${RUBY_CONFIGURE_CMD}
    INSTALL_COMMAND ${RUBY_INSTALL_CMD}
    DEPENDS openssl_external gdbm_external readline_external
)

# Create the final archive
add_custom_target(ruby_archive ALL
    COMMAND zip -q --symlinks -r ruby_full.zip
        usr/local/lib/ruby/
        usr/local/lib/lib*.so*
        usr/local/bin/irb usr/local/bin/gem usr/local/bin/rake
        usr/local/bin/ruby usr/local/bin/bundle usr/local/bin/bundler
    WORKING_DIRECTORY ${RUBY_BUILD_STAGING_DIR}
    DEPENDS ruby_external
    COMMENT "Creating ruby_full.zip archive"
)
