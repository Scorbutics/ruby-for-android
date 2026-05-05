# physfs.cmake
# Configuration for PhysicsFS (libphysfs) — virtual filesystem for game/asset
# bundles. Used by the ruby-physfs gem to expose mount/read/glob to Ruby.
#
# We compile src/*.c directly with the cross-toolchain rather than fighting
# CMake-vs-autoconf cross-build differences. PhysFS's own #ifdef-guarded
# sources select platform code at preprocessor time. See:
#   cmake/ruby-app/dependencies/scripts/{build,install}_physfs.sh

set(PHYSFS_VERSION "3.2.0")
set(PHYSFS_URL "https://github.com/icculus/physfs/archive/refs/tags/release-${PHYSFS_VERSION}.tar.gz")
set(PHYSFS_HASH "SHA256=58aa7eb5824f3c61c19d0334a39c129a2885d9c72bd13bbef7af553e6c92a9f3")

set(_PHYSFS_SCRIPTS "${CMAKE_CURRENT_LIST_DIR}/scripts")

add_external_dependency(
    NAME physfs
    VERSION ${PHYSFS_VERSION}
    URL ${PHYSFS_URL}
    URL_HASH ${PHYSFS_HASH}
    ARCHIVE_NAME "physfs-release-${PHYSFS_VERSION}"
    # No-op configure — the build script doesn't need autoconf/cmake.
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E true
    # Build is a pure-CMake script (no shell) — works on Linux/macOS/Windows
    # build hosts. The script reads CC/CFLAGS/AR from the env that
    # add_external_dependency injects via `cmake -E env ${BUILD_ENV}`.
    BUILD_COMMAND     ${CMAKE_COMMAND} -P "${_PHYSFS_SCRIPTS}/build_physfs.cmake"
    # Install: copy the static lib + public header into staging. Two
    # files; not worth a dedicated script.
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory "${BUILD_STAGING_DIR}/usr/local/lib"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${BUILD_STAGING_DIR}/usr/local/include"
            COMMAND ${CMAKE_COMMAND} -E copy libphysfs.a   "${BUILD_STAGING_DIR}/usr/local/lib/"
            COMMAND ${CMAKE_COMMAND} -E copy src/physfs.h  "${BUILD_STAGING_DIR}/usr/local/include/"
)
