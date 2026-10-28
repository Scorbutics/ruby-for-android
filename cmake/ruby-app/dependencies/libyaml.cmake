# libyaml.cmake
# Configuration for libyaml, required by Ruby's psych extension (YAML).
# Built for every Ruby version: 3.2+ no longer bundle it, and 3.0/3.1 are
# pointed at it too so psych never picks up the build host's libyaml.

set(LIBYAML_VERSION "0.2.5")
set(LIBYAML_URL "https://github.com/yaml/libyaml/releases/download/${LIBYAML_VERSION}/yaml-${LIBYAML_VERSION}.tar.gz")
set(LIBYAML_HASH "SHA256=c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4")

# Always static and PIC, also for shared builds: psych then carries libyaml
# itself (psych.so, or libruby-ext.a), so no libyaml.so has to be shipped,
# as when Ruby 3.0/3.1 compiled the bundled copy into psych.
set(LIBYAML_CONFIGURE_LIB_TYPE
    --disable-shared
    --enable-static
    --with-pic
)

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
