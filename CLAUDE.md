# CRuby Cross-Platform - Development Guide

## Interaction Rules

- **Challenge architectural decisions.** Push back on choices that seem wrong or suboptimal. The goal is to avoid blind spots — don't just agree.
- **Ask, don't guess.** When something is ambiguous, ask a question rather than inferring from context. Only proceed without asking for straightforward, low-risk decisions.
- **Follow this file.** Always respect the rules and constraints defined in this CLAUDE.md.

## What This Project Does

Cross-compiles CRuby as a PIE for Android 8+ (API 26), Linux, iOS and macOS. One build
targets one Ruby version (3.0.7, 3.1.1, 3.2.11 or 3.3.13; default in
`cmake/ruby-app/ruby-versions.cmake`), selected with `./configure --with-ruby-version=X.Y.Z`.
Output: `ruby_full-{platform}-{arch}.zip` (~27MB full Ruby environment).

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design, patch categories, and artifact structure.

## Build (Standard Linux Workflow)

```bash
# Docker mode (default)
./configure
make
make install                    # Exports to ./target/

# Local mode (no Docker)
./configure --without-docker --with-toolchain-params=x86_64-linux-toolchain.params
make
make install

# Specific toolchain
./configure --with-toolchain-params=arm64-v8a-android-toolchain.params

# Specific Ruby version
./configure --with-ruby-version=3.2.11

# See all options
./configure --help
```

## Docker Workflow

Uses `docker-compose.yml` with named volumes. Source sync via rsync:
```bash
docker-compose run --rm init    # Sync sources to volume
docker-compose run ruby-android-ndk   # Interactive build shell
```

## Cleaning

```bash
make clean              # Build artifacts (keeps downloads)
make clean-libs         # Library build directories
make clean-downloads    # Downloaded source archives
make clean-artifacts    # Target directory
make clean-all          # Everything
```

## Requirements (Local Builds)

- CMake 3.14+, make, autoconf, Ruby 3.0.0+
- Android NDK r23b+ (if targeting Android): `export ANDROID_NDK=/path/to/ndk`

## Project Layout

```
configure                   Standard ./configure script (generates Makefile)
*.params                    Toolchain parameter files
cmake/core/                 Generic reusable build system
cmake/ruby-app/             Ruby-specific configs
  dependencies/             Per-dependency CMake configs
  patches/{lib}/{platform}/ Platform patches with series files
utilities/                  Runtime helper scripts (setup_ruby.sh, etc.)
docker/                     Docker configuration
build/                      Generated build directory (gitignored)
target/                     Final artifacts (gitignored)
```

## Releases

One release per Ruby version: pushing tag `v<ruby version>-<build number>` (e.g. `v3.0.7-1`)
builds every platform for that Ruby version. Adding a version means adding its tarball
SHA-256 to `RUBY_SUPPORTED_VERSIONS` and checking that every Ruby patch still applies
(Ruby patches are strict, the build fails otherwise).

## Testing

Check that every Ruby patch applies on every supported version and platform
(downloads each Ruby tarball once into WORK_DIR; CI runs it before the builds):
```bash
cmake -DWORK_DIR=/tmp/ruby-patches -P cmake/ruby-app/tests/check_ruby_patches.cmake
```

Deploy `ruby_full-{platform}.zip` to target, extract, then:
```bash
. setup_ruby.sh /path/to/ruby <major.minor>.0 aarch64
ruby -e "puts RUBY_VERSION"
ruby -e "require 'openssl'; puts OpenSSL::OPENSSL_VERSION"
```
