# CRuby Cross-Platform - Context Guide for Claude Code

## Project Overview

**Purpose**: Cross-compile CRuby 3.1.1 (MRI - Matz's Ruby Interpreter) as a Position Independent Executable (PIE) for Android 8+ (API 26).

**Origin**: Forked from https://github.com/sfrieske/ruby-for-android5 (2015, now outdated).

**Target Platform**: Android 8+ (API Level 26), ARM64-v8a and x86_64 architectures.

**Output**: A full-featured CRuby environment (~27MB) with complete stdlib and native extensions.

## Architecture

### Build System

The project uses a **CMake-based** build system with Docker containerization for cross-platform builds.

#### Key Build Flow

The project follows the **standard Linux build convention**: `./configure`, `make`, `make install`

```
./configure [options] → make → make install
     ↓                    ↓           ↓
Generate Makefile    CMake build   Export artifacts
```

1. **Configuration Phase** (`./configure`)
   - Parses command-line options (--without-docker, --with-toolchain-params, etc.)
   - Validates toolchain parameters and dependencies
   - Generates a Makefile configured for Docker or local build
   - Sets up build environment

2. **Build Phase** (`make`)
   - Runs CMake configuration (calls internal configure script)
   - Downloads dependencies
   - Extracts source archives
   - Applies platform-specific patches
   - Configures and builds each dependency
   - Builds Ruby and creates `ruby_full.zip` archive
   - Works in Docker mode (default) or local mode (--without-docker)

3. **Install Phase** (`make install`)
   - Exports build artifacts from Docker container (Docker mode)
   - Or copies from build directory (local mode)
   - Places artifacts in `./target/` directory
   - Makes `ruby_full.zip` available on the host

4. **Docker Workflow** (when using Docker mode)
   - Uses `scor/ruby-android-ndk:latest` Docker image
   - Syncs source via rsync to named volume
   - Persistent dev container for iterative builds
   - Isolates build environment from host

### Directory Structure

TODO: update

## Dependencies

TODO:update

### Current Versions

| Dependency | Version | Purpose |
|------------|---------|---------|
| Ruby | 3.1.1 | Main CRuby interpreter |
| OpenSSL | 1.1.1m | SSL/TLS support |
| GDBM | 1.18.1 | DBM database support |
| ncurses | 6.4 | Terminal control |
| readline | 8.1 | Line editing/history |

### Build Process for Each Dependency

The build system implements a **generic build pattern**:

1. **Download**: Fetch source tarball from upstream
2. **Extract**: Unpack the download
3. **Patch**: Apply Android compatibility patches
4. **Configure**: Run autoconf/configure with cross-compile flags
5. **Build**: Run make (or custom build command)
6. **Install**: Install to `CMAKE_BINARY_DIR/target/` as DESTDIR

## Android-Specific Modifications

### Patch Categories

1. **SONAME Versioning Removal**
   - All libs: Remove version suffix from shared library SONAME
   - Reason: Android's linker expects unversioned libraries
   - Files: `patches/soname-without-version*.patch`

2. **Ruby Type Redefinition Fix** (Ruby 3.0.0 only)
   - File: `ruby/android/3.0.0-cross-compile.patch`
   - Issue: Clang has built-in types (`size_t`, `intptr_t`, etc.)
   - Fix: Remove redundant type definitions in configure script
   - Note: Not needed for Ruby 3.1.1+

3. **OpenSSL Android NDK r22+ Support** (OpenSSL 1.1.1k only)
   - File: `openssl/android/1.1.1k-ndk-r22.patch`
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

### Quick Start (Standard Linux Workflow)

```sh
# 1. Configure the build (uses Docker by default)
./configure

# 2. Build the project
make

# 3. Export/install artifacts to ./target/
make install

# Output: ./target/ruby_full.zip
```

### Configuration Options

```sh
# Build with Docker (default - requires Docker image)
./configure

# Build without Docker (local toolchain)
./configure --without-docker

# Use a different toolchain
./configure --with-toolchain-params=x86_64-android-toolchain.params

# Combine options
./configure --without-docker --with-toolchain-params=x86_64-linux-toolchain.params

# See all options
./configure --help
```

### Initial Setup (Docker-based builds)

If using Docker mode (default):

1. Clone `https://github.com/Scorbutics/ruby-android-ndk-docker`
2. Run `build.sh` to create Docker image `scor/ruby-android-ndk:latest`
3. Return to this project and run `./configure && make`

### Manual Build (Without Docker)

For local builds without Docker:

1. Install required tools:
   - CMake 3.10+
   - make
   - Ruby 3.0.0+ (needed by Ruby's `make install` step)
   - Android NDK r23b+ (if targeting Android)

2. Set environment variables (for Android builds):
   ```sh
   export ANDROID_NDK=/path/to/android/ndk
   ```

3. Configure and build:
   ```sh
   ./configure --without-docker --with-toolchain-params=your-toolchain.params
   make
   make install
   ```

### Cleaning

```sh
# Clean build artifacts (keeps downloads)
make clean

# Clean library build directories
make clean-libs

# Clean downloaded source archives
make clean-downloads

# Clean target directory
make clean-artifacts

# Clean everything (libs + downloads + artifacts)
make clean-all
```


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
2. Deploy `ruby_full.zip` to your target device
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

## References

- CRuby: https://www.ruby-lang.org/
- Android NDK: https://developer.android.com/ndk
- CMake Android: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-android
- Original Project: https://github.com/sfrieske/ruby-for-android5
- Docker Image: https://github.com/Scorbutics/ruby-android-ndk-docker
