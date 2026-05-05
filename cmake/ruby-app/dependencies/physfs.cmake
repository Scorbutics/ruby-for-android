# physfs.cmake
# Configuration for PhysicsFS (libphysfs) — virtual filesystem for game/asset
# bundles. Used by the ruby-physfs gem to expose mount/read/glob to Ruby.
#
# PhysFS ships its own CMakeLists.txt; we use it directly. Cross-compile
# settings reach the child CMake via get_sub_cmake_cross_args().

set(PHYSFS_VERSION "3.2.0")
set(PHYSFS_URL "https://github.com/icculus/physfs/archive/refs/tags/release-${PHYSFS_VERSION}.tar.gz")
set(PHYSFS_HASH "SHA256=1991500eaeb8d5325e3a8361847ff3bf8e03ec89252b7915e1f25b3f8ab5d560")

get_sub_cmake_cross_args(_PHYSFS_CMAKE_ARGS)

add_external_dependency(
    NAME physfs
    VERSION ${PHYSFS_VERSION}
    URL ${PHYSFS_URL}
    URL_HASH ${PHYSFS_HASH}
    ARCHIVE_NAME "physfs-release-${PHYSFS_VERSION}"
    BUILD_IN_SOURCE FALSE
    CONFIGURE_COMMAND ${CMAKE_COMMAND}
                      -S <SOURCE_DIR>
                      -B <BINARY_DIR>
                      ${_PHYSFS_CMAKE_ARGS}
                      -DPHYSFS_BUILD_STATIC=ON
                      -DPHYSFS_BUILD_SHARED=OFF
                      -DPHYSFS_BUILD_TEST=OFF
                      -DPHYSFS_BUILD_DOCS=OFF
                      -DPHYSFS_DISABLE_INSTALL=OFF
    BUILD_COMMAND     ${CMAKE_COMMAND} --build <BINARY_DIR> -j${BUILD_PARALLEL_JOBS}
    INSTALL_COMMAND   ${CMAKE_COMMAND} --install <BINARY_DIR>
)
