# Ruby 3.0+ Cross-Platform Build System

A modern, modular CMake-based build system for compiling Ruby (CRuby/MRI) and its dependencies for multiple target platforms, with primary focus on Android.

## 🎯 Overview

This project provides a complete cross-compilation environment for Ruby 3.0+ with all its native dependencies. It uses a **two-layer architecture** separating generic build infrastructure from application-specific configuration.

**Supported Platforms:**
- ✅ **Android** (ARM64, ARMv7, x86_64, x86) - API 26+ (Android 8.0+)
- 🚧 **Linux** (x86_64, ARM64) - In development
- 🚧 **macOS** - Planned
- 🚧 **iOS** - Planned

**Included Dependencies:**
- **ncurses** 6.4 - Terminal handling
- **readline** 8.1 - Command line editing
- **gdbm** 1.18.1 - Database manager
- **openssl** 1.1.1m - SSL/TLS support
- **Ruby** 3.0+ - Full CRuby with stdlib
- **zlib** - Compression (provided by platform)

The compiled Ruby includes the complete standard library, providing a full-featured CRuby environment running natively on the target platform.

## 🏗️ Architecture

### Two-Layer Design

```
┌─────────────────────────────────────────────┐
│   Application Layer (Ruby-specific)         │
│   - cmake/ruby-app/                         │
│   - Minimal configuration (19 lines)        │
│   - Dependency definitions                  │
│   - Application-specific patches            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│   Core Build System (Generic, Reusable)     │
│   - cmake/core/                             │
│   - Platform detection & configuration      │
│   - Generic build helpers                   │
│   - ExternalProject infrastructure          │
└─────────────────────────────────────────────┘
```

### Key Features

- **🎯 Modular Design**: Clean separation between generic build system and application-specific code
- **🔧 Platform-Aware**: Automatic detection and configuration for target platforms
- **📦 ExternalProject**: Industry-standard CMake approach for dependency management
- **🔄 Reusable Core**: Generic build system can be used for other C/C++ projects
- **📋 Organized Patches**: Systematic patch management with series files per platform
- **✅ Validated Configuration**: Comprehensive pre-build validation of required variables
- **🧹 Granular Control**: Individual build and clean targets for each dependency

### Directory Structure

```
ruby-for-android/
├── CMakeLists.txt                      # Main entry point (19 lines)
├── cmake/
│   ├── core/                           # Generic build system (reusable)
│   │   ├── Main.cmake                  # declare_application() function
│   │   ├── BuildHelpers.cmake          # add_external_dependency()
│   │   ├── PlatformDetection.cmake     # Platform/arch detection
│   │   ├── Validation.cmake            # Configuration validation
│   │   └── platforms/
│   │       ├── Android.cmake           # Android toolchain setup
│   │       ├── Linux.cmake             # Linux configuration
│   │       └── ...
│   └── ruby-app/                       # Ruby application layer
│       ├── Application.cmake           # Optional app initialization
│       ├── dependencies/               # Per-dependency configs
│       │   ├── ncurses.cmake
│       │   ├── readline.cmake
│       │   ├── gdbm.cmake
│       │   ├── openssl.cmake
│       │   └── ruby.cmake
│       └── patches/                    # Organized patches
│           ├── ncurses/
│           │   └── android/
│           │       ├── series          # Patch order
│           │       └── *.patch
│           ├── openssl/
│           └── ruby/
├── scripts/
│   ├── configure.sh                    # Docker-based configuration
│   ├── build.sh                        # Docker-based build
│   └── clean.sh                        # Clean build artifacts
└── build/                              # Generated build directory
    ├── download/                       # Downloaded sources
    └── target/                         # Installed binaries
```

## 🚀 Quick Start

### Prerequisites

**Option 1: Docker (Recommended)**
- Docker installed on your system
- Clone and build the Docker environment from [ruby-android-ndk-docker](https://github.com/Scorbutics/ruby-android-ndk-docker)

**Option 2: Manual Setup**
- Unix-based system (Linux, macOS, WSL)
- CMake 3.10+
- Android NDK r22+ (for Android builds)
- Build essentials (gcc, make, etc.)
- Ruby 3.0+ on host (required by Ruby's `make install`)

### Building with Docker (Recommended)

```bash
# 1. Clone this repository
git clone https://github.com/Scorbutics/ruby-for-android.git
cd ruby-for-android

# 2. Configure the build
./scripts/configure.sh

# 3. Build all dependencies and Ruby
./scripts/build.sh

# 4. Output will be in build/target/
# Ruby archive: build/target/ruby_full.zip
```

### Building Manually

```bash
# 1. Set up your environment
export ANDROID_NDK=/path/to/android-ndk
export PATH=$PATH:$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

# 2. Configure with parameters file
./configure --toolchain-params arm64-v8a-android-toolchain.params

# 3. Build
cd build
cmake --build .

# 4. Create archive (optional)
cmake --build . --target ruby_archive
```

### Platform-Specific Toolchain Parameters

Edit or create a toolchain parameters file for your target:

**Android ARM64** (`arm64-v8a-android-toolchain.params`):
```bash
ANDROID_ABI=arm64-v8a
ANDROID_PLATFORM=android-26
ANDROID_NDK=/path/to/android-ndk
```

**Android x86_64** (`x86_64-android-toolchain.params`):
```bash
ANDROID_ABI=x86_64
ANDROID_PLATFORM=android-26
ANDROID_NDK=/path/to/android-ndk
```

## 📦 Build Targets

```bash
# Build everything (default)
cmake --build .

# Build specific dependency
cmake --build . --target ncurses
cmake --build . --target openssl
cmake --build . --target ruby

# Clean specific dependency
cmake --build . --target ncurses_clean
cmake --build . --target ruby_clean

# Clean everything
cmake --build . --target clean-all

# Clean only libraries (keep downloads)
cmake --build . --target clean-libs

# Clean downloads
cmake --build . --target clean-downloads

# Create Ruby archive
cmake --build . --target ruby_archive
```

## 🔧 Configuration

### Application Declaration

The build is configured through a single `declare_application()` call in `CMakeLists.txt`:

```cmake
declare_application(
    APP_NAME "Ruby"
    APP_DIR "${CMAKE_SOURCE_DIR}/cmake/ruby-app"
    APP_DEPENDENCIES "ncurses;readline;gdbm;openssl;ruby"
    APP_VERSION "3.0.0"
    APP_DESCRIPTION "Ruby Programming Language for Cross-Platform Targets"
)
```

### Adding a New Dependency

1. Create `cmake/ruby-app/dependencies/mydep.cmake`:

```cmake
add_external_dependency(
    NAME mydep
    VERSION 1.0.0
    URL https://example.com/mydep-1.0.0.tar.gz
    URL_HASH SHA256=...
    CONFIGURE_COMMAND ./configure --host=${HOST_TRIPLET} --prefix=/usr
    BUILD_COMMAND make -j${NCPUS}
    INSTALL_COMMAND make install DESTDIR=${BUILD_STAGING_DIR}
    DEPENDS other_dep  # Optional
)
```

2. Add patches in `cmake/ruby-app/patches/mydep/android/`:
   - Create `series` file listing patches in order
   - Add patch files

3. Update `APP_DEPENDENCIES` in `CMakeLists.txt`

### Platform-Specific Configuration

Platform modules (`cmake/core/platforms/*.cmake`) must set:

**Required Variables:**
- `TARGET_PLATFORM` - Platform name (Android, Linux, etc.)
- `TARGET_ARCH` - Architecture (arm64, x86_64, etc.)
- `HOST_TRIPLET` - Cross-compilation target (e.g., aarch64-linux-android)
- `HOST_SHORT` - Short platform name (e.g., android-arm64)
- `BUILD_ENV` - Environment variables for external builds (CC, CXX, CFLAGS, etc.)
- `BUILD_DOWNLOAD_DIR` - Where to download sources
- `BUILD_STAGING_DIR` - Where to install binaries
- `PLATFORM_INITIALIZED` - Set to TRUE when complete

**Recommended Variables:**
- `CFLAGS`, `CXXFLAGS`, `LDFLAGS` - Compilation flags

## 📱 Usage on Android

### Deploying

1. Extract `build/target/ruby_full.zip` to your Android device (e.g., `/data/local/tmp/ruby`)

2. Set up environment using the provided script:

```bash
# On Android device
source /path/to/ruby/setup_ruby.sh
```

3. Run Ruby:

```bash
ruby --version
irb
```

### Environment Setup

The `setup_ruby.sh` script configures:
- `PATH` - Ruby binaries location
- `LD_LIBRARY_PATH` - Shared libraries
- `GEM_PATH`, `GEM_HOME` - RubyGems directories
- Other Ruby-specific variables

### Integration in APK

For embedding in an Android application:
1. Include the extracted Ruby directory in your APK assets
2. Extract to app's data directory on first run
3. Set environment variables programmatically
4. Execute Ruby through JNI or shell commands

## 🔍 Troubleshooting

### Configuration Issues

```bash
# Check what variables are set
./scripts/configure.sh

# The validation step will show all required variables
# and indicate any missing ones
```

### Build Failures

```bash
# Check individual dependency logs
cat build/{dependency}/build_dir/stamps/*-err.log

# Rebuild specific dependency
cmake --build build --target dependency_clean
cmake --build build --target dependency

# Full clean rebuild
./scripts/clean.sh
./scripts/configure.sh
./scripts/build.sh
```

### Common Issues

**Issue**: `cmake: command not found`
- Install CMake 3.10 or later

**Issue**: `Cannot find Android NDK`
- Set `ANDROID_NDK` environment variable
- Update toolchain params file

**Issue**: OpenSSL configuration fails
- Ensure NDK bin directory is in `PATH`
- Check that `ANDROID_NDK_ROOT` is set in `BUILD_ENV`

**Issue**: Cross-compilation produces wrong architecture
- Verify `--host` triplet in configure commands
- Check that `BUILD_ENV` sets correct target flags

## 🎓 Advanced Topics

### Creating a New Application Layer

The core build system is generic and can be reused for other C/C++ projects:

```cmake
# YourProject/CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
project(YourProject)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/core")
include(Main)

declare_application(
    APP_NAME "YourApp"
    APP_DIR "${CMAKE_SOURCE_DIR}/cmake/your-app"
    APP_DEPENDENCIES "lib1;lib2;lib3"
    APP_VERSION "1.0.0"
)
```

### Adding Platform Support

1. Create `cmake/core/platforms/YourPlatform.cmake`
2. Implement required variable setup
3. Set `PLATFORM_INITIALIZED=TRUE`
4. Test with a simple dependency first

### Custom Patch Management

Patches are organized by library and platform:
```
patches/
└── library/
    ├── android/
    │   ├── series           # Order of patches
    │   ├── fix-build.patch
    │   └── soname.patch
    └── linux/
        └── series
```

The `series` file lists patches in application order (one per line).

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original inspiration: [ruby-for-android5](https://github.com/sfrieske/ruby-for-android5) (2015)
- Ruby core team for CRuby
- Android NDK team
- All dependency library maintainers

## 🤝 Contributing

Contributions welcome! Areas of interest:
- Testing on different platforms
- Additional platform support (macOS, iOS, Windows)
- Documentation improvements
- Build optimization
- Bug fixes

## 📚 Documentation

- [REFACTORING.md](REFACTORING.md) - Detailed architecture documentation
- [TEST_CHECKLIST.md](TEST_CHECKLIST.md) - Testing procedures
- [CLAUDE.MD](CLAUDE.MD) - Development notes

## ⚠️ Limitations

- **Android API Level**: Requires API 26+ (Android 8.0+). No support for earlier versions.
- **Build Environment**: Requires Unix-based system or Docker
- **Size**: Full Ruby installation is ~27MB - consider [mruby](https://github.com/mruby/mruby) for lightweight needs
- **Host Ruby**: Ruby 3.0+ must be installed on build host (required by Ruby's build process)
- **Supported NDK**: Android NDK r22+ recommended (r23b LTS tested)
