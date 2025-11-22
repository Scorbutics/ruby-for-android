# Ruby for Android - Context Guide for Claude Code

## Project Overview

**Purpose**: Cross-compile CRuby 3.1.1 (MRI - Matz's Ruby Interpreter) as a Position Independent Executable (PIE) for Android 8+ (API 26).

**Origin**: Forked from https://github.com/sfrieske/ruby-for-android5 (2015, now outdated).

**Target Platform**: Android 8+ (API Level 26), ARM64-v8a and x86_64 architectures.

**Output**: A full-featured CRuby environment (~27MB) with complete stdlib and native extensions.

## Architecture

### Build System

The project uses a **CMake-based** build system with Docker containerization for cross-platform builds.

#### Key Build Flow

```
configure.sh → CMake configure → build.sh → CMake build → target/ruby_full.zip
```

1. **Configuration Phase** (`./scripts/configure.sh`)
   - Sets up CMake with Android NDK toolchain
   - Reads toolchain params from `arm64-v8a-android-toolchain.params`
   - Configures environment variables for cross-compilation

2. **Build Phase** (`./scripts/build.sh`)
   - Downloads dependencies
   - Extracts source archives
   - Applies platform-specific patches
   - Configures each dependency
   - Builds and installs to `target/` directory
   - Creates `ruby_full.zip` archive

3. **Docker Workflow**
   - Uses `scor/ruby-android-ndk:latest` Docker image
   - Syncs source via rsync to named volume
   - Persistent dev container for iterative builds
   - Isolates build environment from host

### Directory Structure

```
.
├── CMakeLists.txt              # Root CMake configuration
├── configure                   # Manual configure script (legacy)
├── docker-compose.yml          # Docker services definition
├── arm64-v8a-android-toolchain.params  # ARM64 build params
├── x86_64-android-toolchain.params     # x86_64 build params
├── ruby-build/                 # Dependency build configurations
│   ├── CMakeLists.txt          # Generic build system for all deps
│   ├── gdbm/                   # GNU DBM library
│   ├── ncurses/                # Terminal handling library
│   ├── openssl/                # SSL/TLS library
│   ├── readline/               # Command-line editing
│   └── ruby/                   # CRuby itself
├── scripts/
│   ├── configure.sh            # Docker-based configure wrapper
│   ├── build.sh                # Docker-based build wrapper
│   ├── clean.sh                # Cleaning utilities
│   └── tools/
│       ├── constants.sh        # Docker container config
│       ├── docker-dev-action.sh # Docker execution helper
│       └── clean-all-libs.sh   # Clean all library builds
└── tools/
    ├── env.src.template        # Environment setup template
    └── setup_ruby.sh           # Runtime environment setup for Android
```

## Dependencies

Each dependency in `ruby-build/` has:
- `cmake.conf`: Version, download URL, configure/build/install commands
- `patches/`: Android compatibility patches
- `patches-{version}/`: Version-specific patches (if needed)

### Current Versions

| Dependency | Version | Purpose |
|------------|---------|---------|
| Ruby | 3.1.1 | Main CRuby interpreter |
| OpenSSL | 1.1.1m | SSL/TLS support |
| GDBM | 1.18.1 | DBM database support |
| ncurses | 6.4 | Terminal control |
| readline | 8.1 | Line editing/history |

### Build Process for Each Dependency

The `ruby-build/CMakeLists.txt` implements a **generic build pattern**:

1. **Download**: Fetch source tarball from upstream
2. **Extract**: Unpack to `build_dir/{lib}-{version}/`
3. **Patch**: Apply Android compatibility patches
4. **Configure**: Run autoconf/configure with cross-compile flags
5. **Build**: Run make (or custom build command)
6. **Install**: Install to `CMAKE_BINARY_DIR/target/` as DESTDIR

Each step has an **idempotent marker** (`.{step}.done`) to skip on re-runs.

## Android-Specific Modifications

### Toolchain Configuration

File: `env.src.template` (generated as `build/target/env.src`)

Key environment variables:
- `CC`: clang with target triplet (e.g., `aarch64-linux-android26`)
- `CXX`: clang++ with target triplet
- `AR`, `RANLIB`, `STRIP`: LLVM toolchain binaries
- `CFLAGS`: Include paths to staged headers, `-O3 -DNDEBUG`, API level override
- `LDFLAGS`: Library paths to staged libs, link against libz and libm

### Patch Categories

1. **SONAME Versioning Removal**
   - All libs: Remove version suffix from shared library SONAME
   - Reason: Android's linker expects unversioned libraries
   - Files: `patches/soname-without-version*.patch`

2. **Ruby Type Redefinition Fix** (Ruby 3.0.0 only)
   - File: `ruby/patches-3.0.0/android-cross-ruby-3.0.0.patch`
   - Issue: Clang has built-in types (`size_t`, `intptr_t`, etc.)
   - Fix: Remove redundant type definitions in configure script
   - Note: Not needed for Ruby 3.1.1+

3. **OpenSSL Android NDK r22+ Support** (OpenSSL 1.1.1k only)
   - File: `openssl/patches-1.1.1k/android-ndk-r22-support.patch`
   - Issue: Type compatibility with newer NDK
   - Note: Not needed for OpenSSL 1.1.1m+

## Build Artifacts

### Target Directory Structure

```
target/
├── usr/
│   ├── include/              # Headers from dependencies
│   ├── lib/                  # Shared libraries from deps
│   └── local/
│       ├── bin/              # ruby, irb, gem, rake, bundle executables
│       └── lib/
│           ├── ruby/
│           │   ├── 3.1.0/    # Ruby stdlib
│           │   │   └── aarch64-linux-android/ # Native extensions
│           │   └── gems/     # Gem specifications
│           └── lib*.so*      # Ruby runtime libraries
└── ruby_full.zip             # Final deliverable
```

### Ruby Full ZIP Contents

Includes:
- Ruby interpreter and utilities (ruby, irb, gem, rake, bundle)
- All shared libraries (libruby.so, libssl.so, libcrypto.so, etc.)
- Complete Ruby standard library
- Native extension gems (compiled against Android libs)

## Runtime Deployment

### On Android Device

1. Extract `ruby_full.zip` to device (e.g., `/data/local/tmp/ruby/`)
2. Source the environment setup:
   ```sh
   . /data/local/tmp/ruby/setup_ruby.sh /data/local/tmp/ruby 3.1 aarch64
   ```
3. Run Ruby:
   ```sh
   ruby -v
   ```

### Environment Variables Set by setup_ruby.sh

- `LD_LIBRARY_PATH`: Points to Ruby's shared libraries
- `PATH`: Includes Ruby's bin directory
- `GEM_PATH`: Gem installation directory
- `GEM_SPEC_CACHE`: Gem specifications directory
- `RUBYLIB`: Ruby library search paths

## Development Workflows

### Initial Setup (Docker-based)

1. Clone `https://github.com/Scorbutics/ruby-android-ndk-docker`
2. Run `build.sh` to create Docker image
3. Return to this project

### Building

```sh
# Configure
./scripts/configure.sh

# Build all dependencies + Ruby
./scripts/build.sh

# Output: ./target/ruby_full.zip
```

### Cleaning

```sh
# Clean specific library (e.g., ruby)
./scripts/clean.sh ruby

# Clean all libraries
./scripts/clean.sh

# Clean artifacts only
cmake --build . --target clean-artifacts

# Clean everything (libs + downloads + artifacts)
cmake --build . --target clean-all
```

### Manual Build (Without Docker - DEPRECATED)

1. Install Android NDK r23b+
2. Install Ruby 3.0.0+ on host (needed by `make install` step)
3. Install CMake 3.10+
4. Edit `arm64-v8a-android-toolchain.params` with NDK path
5. Run `./configure`
6. Run `make` in `ruby-build/`

## Key Implementation Details

### CMake Targets

Each dependency gets these targets:
- `{lib}_download`: Fetch source
- `{lib}_extract`: Unpack source
- `{lib}_patch`: Apply patches
- `{lib}_configure`: Run configure script
- `{lib}_build`: Compile
- `{lib}_install`: Install to target/
- `{lib}_clean`: Remove build directory
- `{lib}`: Alias for `{lib}_install`

Global targets:
- `zip`: Create ruby_full.zip (runs after all deps)
- `clean-libs`: Clean all library builds
- `clean-artifacts`: Remove target/
- `clean-downloads`: Remove download/
- `clean-all`: All of the above

### Dependency Chain

```
ncurses → readline → ruby
         openssl  ↗
         gdbm    ↗
```

Ruby depends on all other libraries. The CMake build system handles ordering.

### Docker Persistence

The `docker-dev-action.sh` script:
1. Runs `init` container to sync host sources to named volume
2. Creates/reuses a persistent `{project}_dev` container
3. Executes build commands inside the persistent container
4. Keeps container running between builds (faster iterations)

## Common Issues & Solutions

### Build Not Finding Dependencies

**Symptom**: Ruby configure can't find OpenSSL/GDBM/readline

**Solution**: Ensure dependencies built first. CMake handles this automatically, but if manually building:
```sh
cmake --build . --target openssl
cmake --build . --target gdbm
cmake --build . --target readline
cmake --build . --target ruby
```

### Type Redefinition Errors (Legacy)

**Symptom**: `error: typedef redefinition with different types`

**Solution**: Use Ruby 3.1.1+ with NDK r22+. Older versions need patches.

### Runtime Library Not Found on Android

**Symptom**: `error: library "libruby.so" not found`

**Solution**: Run `setup_ruby.sh` with correct paths before executing Ruby.

### Size Concerns

**Note**: Full Ruby is ~27MB. For embedded devices needing smaller footprint, consider mRuby instead.

## Important Configuration Files

### arm64-v8a-android-toolchain.params

Single-line CMake arguments:
```
-DANDROID_STL=c++_shared
-DANDROID_PLATFORM=android-26
-DANDROID_ABI=arm64-v8a
-DHOST=aarch64-linux-android
-DHOST_SHORT=android-arm64
```

### docker-compose.yml

Two services:
- `init`: rsync source to named volume
- `debug`: Interactive shell in build container

## Cross-Compilation Glossary

- **Host**: Machine running the build (e.g., x86_64 Linux)
- **Target**: Machine running the binary (e.g., aarch64 Android)
- **Toolchain**: Compiler and tools for cross-compilation
- **DESTDIR**: Staging directory for install (not final runtime path)
- **PIE**: Position Independent Executable (required for Android 5+)
- **SONAME**: Shared object name embedded in ELF binary

## Testing Strategy

1. Build for target architecture
2. Deploy `ruby_full.zip` to Android device
3. Extract and source `setup_ruby.sh`
4. Run test suite:
   ```sh
   ruby -e "puts RUBY_VERSION"
   ruby -e "require 'openssl'; puts OpenSSL::OPENSSL_VERSION"
   ruby -e "require 'gdbm'"
   ruby -e "require 'readline'"
   irb  # Interactive Ruby
   ```

## Future Considerations

- Android version < 8 not supported (no plans to support)
- Windows hosts should use Docker workflow
- Updating Ruby version: Edit `ruby-build/ruby/cmake.conf`
- Adding new dependencies: Create subdirectory in `ruby-build/` with `cmake.conf`
- Custom architectures: Create new `{arch}-android-toolchain.params` file

## Useful Commands

```sh
# Check Android NDK version
cat $ANDROID_NDK/source.properties

# Verify cross-compilation setup
file target/usr/local/bin/ruby
# Should show: ELF 64-bit LSB pie executable, ARM aarch64...

# Test library dependencies
readelf -d target/usr/local/lib/libruby.so

# Check build directory contents
tree build/ -L 2

# Monitor Docker build
docker logs -f ruby-for-android_dev

# Access build container directly
./scripts/tools/docker-dev-action.sh bash
```

## References

- CRuby: https://www.ruby-lang.org/
- Android NDK: https://developer.android.com/ndk
- CMake Android: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-android
- Original Project: https://github.com/sfrieske/ruby-for-android5
- Docker Image: https://github.com/Scorbutics/ruby-android-ndk-docker
