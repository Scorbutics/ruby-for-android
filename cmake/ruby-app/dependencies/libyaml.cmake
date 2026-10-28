# libyaml.cmake
# Configuration for libyaml, required by Ruby's psych extension (YAML).
# Ruby 3.0/3.1 bundle the libyaml sources inside ext/psych; Ruby 3.2 dropped
# them, so this dependency is only declared for 3.2+ (see ruby-versions.cmake).

set(LIBYAML_VERSION "0.2.5")
set(LIBYAML_URL "https://github.com/yaml/libyaml/releases/download/${LIBYAML_VERSION}/yaml-${LIBYAML_VERSION}.tar.gz")
set(LIBYAML_HASH "SHA256=c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4")

# Configure command (autoconf-based)
if(BUILD_SHARED_LIBS)
    set(LIBYAML_CONFIGURE_LIB_TYPE
        --enable-shared
        --disable-static
    )
else()
    set(LIBYAML_CONFIGURE_LIB_TYPE
        --disable-shared
        --enable-static
        --with-pic
    )
endif()

set(LIBYAML_CONFIGURE_CMD
    ./configure
    --host=${HOST_TRIPLET}
    ${LIBYAML_CONFIGURE_LIB_TYPE}
)

# Build libyaml dependency
add_external_dependency(
    NAME libyaml
    VERSION ${LIBYAML_VERSION}
    URL ${LIBYAML_URL}
    URL_HASH ${LIBYAML_HASH}
    ARCHIVE_NAME "yaml-${LIBYAML_VERSION}"
    CONFIGURE_COMMAND ${LIBYAML_CONFIGURE_CMD}
)
