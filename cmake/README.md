# CMake Build System - Modular Architecture

This directory contains the modular CMake-based build system for cross-compiling Ruby across multiple platforms.

## Directory Structure

```
cmake/
├── README.md                    # This file
├── RubyBuildHelpers.cmake      # Common build helper functions
├── PlatformDetection.cmake     # Platform detection and loading
├── Dependencies.cmake           # Dependency orchestration
├── platforms/                   # Platform-specific configurations
│   ├── Android.cmake           # Android build configuration
│   ├── Linux.cmake             # Linux build configuration
│   ├── macOS.cmake             # macOS build configuration
│   └── iOS.cmake               # iOS build configuration
├── dependencies/                # Dependency-specific configurations
│   ├── ruby.cmake              # Ruby interpreter
│   ├── openssl.cmake           # OpenSSL library
│   ├── gdbm.cmake              # GDBM library
│   ├── ncurses.cmake           # ncurses library
│   └── readline.cmake          # readline library
├── toolchains/                  # Platform toolchain files (future)
└── patches/                     # Organized patch directory
    ├── ruby/
    │   ├── common/             # Patches for all platforms
    │   ├── android/            # Android-specific patches
    │   │   └── series          # Patch application order
    │   ├── linux/              # Linux-specific patches
    │   ├── macos/              # macOS-specific patches
    │   └── ios/                # iOS-specific patches
    ├── openssl/
    ├── gdbm/
    ├── ncurses/
    └── readline/
```

## Module Descriptions

### RubyBuildHelpers.cmake

Provides common helper functions:

- **`add_native_dependency()`**: Unified interface for adding dependencies
  - Handles download, extract, patch, configure, build, install
  - Integrates with ExternalProject
  - Automatic patch application from organized directories
  - Idempotent builds via ExternalProject stamps

- **`set_cross_compile_environment()`**: Sets up cross-compilation env vars

- **`apply_platform_patches()`**: Applies patches in correct order

- **`create_archive_target()`**: Creates distribution archives

### PlatformDetection.cmake

Detects the target platform and loads the appropriate platform module:

- Identifies platform: Android, iOS, macOS, Linux, Windows
- Determines architecture: arm64, armv7, x86_64, x86
- Loads platform-specific configuration
- Validates platform module initialization

### Platform Modules (platforms/*.cmake)

Each platform module is responsible for:

1. **Toolchain Configuration**
   - Set `CROSS_CC`, `CROSS_CXX`, `CROSS_AR`, etc.
   - Determine host triplet (e.g., `aarch64-linux-android`)

2. **Compiler Flags**
   - Set `RUBY_CFLAGS`, `RUBY_CXXFLAGS`, `RUBY_LDFLAGS`
   - Include paths to staged headers
   - Library paths to staged libs

3. **Build Environment**
   - Export `RUBY_BUILD_ENV` for autoconf-based builds
   - Set platform-specific environment variables

4. **Validation**
   - Check required tools exist
   - Verify SDK/NDK paths
   - Set `RUBY_PLATFORM_INITIALIZED=TRUE`

### Dependencies.cmake

Orchestrates dependency loading:

- Defines build order in `RUBY_DEPENDENCIES` list
- Loads individual dependency configurations
- Supports both new (`cmake/dependencies/*.cmake`) and legacy (`ruby-build/*/cmake.conf`) formats

### Dependency Modules (dependencies/*.cmake)

Each dependency module defines:

- Version and download URL
- SHA256 hash for verification
- Platform-specific configure commands
- Build and install commands (if custom)
- Dependencies on other libraries

Example:
```cmake
set(OPENSSL_VERSION "1.1.1m")
set(OPENSSL_URL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz")
set(OPENSSL_HASH "SHA256=...")

add_native_dependency(
    NAME openssl
    VERSION ${OPENSSL_VERSION}
    URL ${OPENSSL_URL}
    URL_HASH ${OPENSSL_HASH}
    CONFIGURE_COMMAND ./Configure ${RUBY_HOST_SHORT} shared
)
```

## Patch Management

Patches are organized by library and platform:

```
patches/{library}/{platform}/
patches/{library}/common/          # Applied to all platforms
```

### Patch Application Order

For each library, patches are searched in this order:

1. `{library}/{platform}/{version}/` - Platform + version specific
2. `{library}/{platform}/` - Platform specific
3. `{library}/{version}/` - Version specific
4. `{library}/common/` - Common to all platforms

### Using Patch Series Files

Create a `series` file to control patch order:

```
# patches/ruby/android/series
001-soname-fix.patch
002-cross-compile.patch
003-api-level.patch
```

Comments (lines starting with `#`) and blank lines are ignored.

If no `series` file exists, all `.patch` files are applied in alphabetical order.

## Adding a New Platform

1. **Create platform module**: `cmake/platforms/YourPlatform.cmake`

```cmake
# YourPlatform.cmake
message(STATUS "Configuring for YourPlatform")

# Set toolchain variables
set(CROSS_CC "/path/to/cc")
set(CROSS_CXX "/path/to/c++")
# ... etc ...

# Determine host triplet
set(YOUR_HOST_TRIPLET "arch-vendor-os")

# Set compiler flags
set(RUBY_CFLAGS "...")
set(RUBY_LDFLAGS "...")

# Export environment
set(RUBY_BUILD_ENV
    CC=${CROSS_CC}
    CXX=${CROSS_CXX}
    CFLAGS=${RUBY_CFLAGS}
    LDFLAGS=${RUBY_LDFLAGS}
    PARENT_SCOPE
)

set(RUBY_BUILD_ENV ${RUBY_BUILD_ENV} PARENT_SCOPE)
set(RUBY_HOST_TRIPLET "${YOUR_HOST_TRIPLET}" PARENT_SCOPE)

# Mark initialized
set(RUBY_PLATFORM_INITIALIZED TRUE PARENT_SCOPE)
```

2. **Update PlatformDetection.cmake** to detect your platform

3. **Create platform-specific patches** in `cmake/patches/{library}/yourplatform/`

4. **Test the build**:
```bash
cmake -DCMAKE_TOOLCHAIN_FILE=/path/to/your/toolchain.cmake ..
cmake --build .
```

## Adding a New Dependency

1. **Create dependency module**: `cmake/dependencies/yourdep.cmake`

```cmake
set(YOURDEP_VERSION "1.2.3")
set(YOURDEP_URL "https://example.com/yourdep-${YOURDEP_VERSION}.tar.gz")
set(YOURDEP_HASH "SHA256=...")

add_native_dependency(
    NAME yourdep
    VERSION ${YOURDEP_VERSION}
    URL ${YOURDEP_URL}
    URL_HASH ${YOURDEP_HASH}
    CONFIGURE_COMMAND ./configure --host=${RUBY_HOST_TRIPLET}
    DEPENDS other_dep_external  # If needed
)
```

2. **Add to dependency list** in `cmake/Dependencies.cmake`:

```cmake
set(RUBY_DEPENDENCIES
    yourdep   # Add here in build order
    ncurses
    readline
    ...
)
```

3. **Add patches if needed** in `cmake/patches/yourdep/`

## Migration from Legacy System

The legacy system (`ruby-build/*/cmake.conf`) is still supported for backward compatibility.

### Key Differences

| Legacy | New Modular System |
|--------|-------------------|
| `ruby-build/CMakeLists.txt` | `cmake/RubyBuildHelpers.cmake` |
| `ruby-build/{lib}/cmake.conf` | `cmake/dependencies/{lib}.cmake` |
| `ruby-build/{lib}/patches/` | `cmake/patches/{lib}/android/` |
| Custom download/extract logic | ExternalProject built-in |
| Manual marker files | ExternalProject stamp files |
| Platform-agnostic | Platform-specific modules |

### Migrating a Dependency

1. Copy settings from `ruby-build/{lib}/cmake.conf`
2. Create `cmake/dependencies/{lib}.cmake`
3. Use `add_native_dependency()` helper
4. Move patches to `cmake/patches/{lib}/{platform}/`
5. Create `series` file for patch order
6. Test build

## Build Variables

### User-Configurable

- `RUBY_BUILD_DOWNLOAD_DIR` - Download directory (default: `${CMAKE_BINARY_DIR}/download`)
- `RUBY_BUILD_STAGING_DIR` - Installation staging (default: `${CMAKE_BINARY_DIR}/target`)
- `RUBY_BUILD_PARALLEL_JOBS` - Parallel make jobs (default: CPU count)
- `RUBY_ENABLE_SHARED` - Build shared libraries (default: ON, except iOS)
- `RUBY_DISABLE_INSTALL_DOC` - Skip documentation (default: ON)

### Platform-Set Variables

- `RUBY_TARGET_PLATFORM` - Platform name (Android, Linux, macOS, iOS)
- `RUBY_TARGET_ARCH` - Architecture (arm64, armv7, x86_64, x86)
- `RUBY_HOST_TRIPLET` - GNU triplet (e.g., aarch64-linux-android)
- `RUBY_HOST_SHORT` - Short host name (e.g., android-arm64)
- `RUBY_BUILD_ENV` - Environment variables for builds

## Common Tasks

### Build for Different Platform

```bash
# Android
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      ..

# Linux (native)
cmake ..

# macOS (universal binary)
cmake -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" ..

# iOS (device)
cmake -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
      -DPLATFORM=OS64 \
      ..
```

### Clean Specific Dependency

```bash
cmake --build . --target openssl_clean
cmake --build . --target openssl
```

### Update Dependency Version

Edit `cmake/dependencies/{lib}.cmake`:

```cmake
set(OPENSSL_VERSION "1.1.1n")  # Update version
set(OPENSSL_HASH "SHA256=...")  # Update hash
```

Then rebuild:

```bash
cmake --build . --target openssl_clean
cmake --build . --target openssl
```

### Debug Build Issues

Enable verbose logging:

```bash
cmake --build . --target openssl -- VERBOSE=1
```

Check ExternalProject logs:

```bash
cat build/{dep}/stamps/{dep}_external-configure-out.log
cat build/{dep}/stamps/{dep}_external-build-out.log
```

## Best Practices

1. **Always use `add_native_dependency()`** instead of raw ExternalProject
2. **Create `series` files** for patches to document application order
3. **Use platform detection** instead of manual platform checks
4. **Test cross-platform** changes on at least 2 platforms
5. **Document platform quirks** in platform module comments
6. **Version your patches** clearly (e.g., `001-description.patch`)
7. **Keep patches minimal** - only what's necessary for cross-compilation

## Troubleshooting

### "Platform configuration not found"

Ensure `cmake/platforms/{Platform}.cmake` exists and PlatformDetection.cmake recognizes your platform.

### "RUBY_PLATFORM_INITIALIZED not set"

Platform module must set `RUBY_PLATFORM_INITIALIZED` to `TRUE` with `PARENT_SCOPE`.

### Patches not applying

- Check patch file exists in search path
- Verify `series` file syntax (no trailing spaces)
- Test patch manually: `patch -p1 -i patch_file.patch`

### Dependency build fails

- Check ExternalProject logs in `build/{dep}/stamps/`
- Verify `RUBY_BUILD_ENV` is set correctly for platform
- Test configure command manually in `build/{dep}/build_dir/{dep}-{version}/`

## Future Enhancements

- [ ] vcpkg integration for dependency management
- [ ] Toolchain file generation
- [ ] Binary caching support
- [ ] Cross-compilation testing framework
- [ ] Automated patch rebasing on version updates
- [ ] Multi-architecture builds (fat binaries)
- [ ] Code signing integration for iOS/macOS
