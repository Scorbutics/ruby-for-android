# build_physfs.cmake
# Cross-compile libphysfs.a from src/*.c using the env-injected toolchain.
# Invoked via `cmake -P` from physfs.cmake's BUILD_COMMAND.
#
# CWD is the PhysFS source root (BUILD_IN_SOURCE).
#
# Required env vars (set by BUILD_ENV via the wrapping `cmake -E env`):
#   CC      cross C compiler (may include extra args like "clang -target ...")
#   CFLAGS  cross compile flags
#   AR      cross archiver
#
# PhysFS is "drop-in compilable" plain C — see PhysFS's CMakeLists.txt header
# comment. Its own #ifdef-guarded sources select platform code internally,
# so we just compile every src/*.c (plus the Apple .m on darwin) and archive.
#
# Pure CMake (no shell) so the build works identically on Linux, macOS, and
# Windows hosts when cross-compiling to any target.

set(CC      "$ENV{CC}")
set(CFLAGS  "$ENV{CFLAGS}")
set(AR      "$ENV{AR}")

if(NOT CC)
    message(FATAL_ERROR "build_physfs: CC env var not set (BUILD_ENV is missing or stripped).")
endif()
if(NOT AR)
    message(FATAL_ERROR "build_physfs: AR env var not set.")
endif()

# CC may be "clang -target aarch64-linux-android21" (multi-word). Split it
# back into a list so execute_process invokes the binary directly without
# needing a shell.
separate_arguments(CC_LIST     UNIX_COMMAND "${CC}")
separate_arguments(CFLAGS_LIST UNIX_COMMAND "${CFLAGS}")
separate_arguments(AR_LIST     UNIX_COMMAND "${AR}")

set(OBJDIR "physfs_objects")
file(REMOVE_RECURSE "${OBJDIR}")
file(MAKE_DIRECTORY "${OBJDIR}")

file(GLOB PHYSFS_SOURCES "src/*.c")
if(NOT PHYSFS_SOURCES)
    message(FATAL_ERROR "build_physfs: no src/*.c found — wrong CWD? (cwd=${CMAKE_CURRENT_SOURCE_DIR})")
endif()

# Detect Apple-target so we can include the Objective-C platform source.
execute_process(
    COMMAND ${CC_LIST} -dumpmachine
    OUTPUT_VARIABLE  TARGET_TRIPLET
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE  _dm_rv
)
set(IS_APPLE FALSE)
if(_dm_rv EQUAL 0 AND TARGET_TRIPLET MATCHES "darwin|apple|ios")
    set(IS_APPLE TRUE)
endif()

set(OBJS "")
foreach(SRC ${PHYSFS_SOURCES})
    get_filename_component(BASENAME "${SRC}" NAME_WE)
    set(OBJ "${OBJDIR}/${BASENAME}.o")
    execute_process(
        COMMAND ${CC_LIST} -c ${CFLAGS_LIST} -fPIC -DPHYSFS_SUPPORTS_DEFAULT=1 "${SRC}" -o "${OBJ}"
        RESULT_VARIABLE _rv
    )
    if(NOT _rv EQUAL 0)
        message(FATAL_ERROR "build_physfs: failed to compile ${SRC}")
    endif()
    list(APPEND OBJS "${OBJ}")
endforeach()

# Apple platforms (macOS/iOS) need the IOKit/Foundation Objective-C source.
if(IS_APPLE AND EXISTS "src/physfs_platform_apple.m")
    set(OBJ "${OBJDIR}/physfs_platform_apple.o")
    execute_process(
        COMMAND ${CC_LIST} -c ${CFLAGS_LIST} -fPIC -DPHYSFS_SUPPORTS_DEFAULT=1
                "src/physfs_platform_apple.m" -o "${OBJ}"
        RESULT_VARIABLE _rv
    )
    if(NOT _rv EQUAL 0)
        message(FATAL_ERROR "build_physfs: failed to compile physfs_platform_apple.m")
    endif()
    list(APPEND OBJS "${OBJ}")
endif()

execute_process(
    COMMAND ${AR_LIST} crs libphysfs.a ${OBJS}
    RESULT_VARIABLE _rv
)
if(NOT _rv EQUAL 0)
    message(FATAL_ERROR "build_physfs: ar failed")
endif()

file(SIZE "libphysfs.a" LIB_SIZE)
math(EXPR LIB_SIZE_KB "${LIB_SIZE} / 1024")
message(STATUS "[physfs] Built libphysfs.a (${LIB_SIZE_KB} KB)")
