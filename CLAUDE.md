# CRuby Cross-Platform - Development Guide

## Interaction Rules

- **Challenge architectural decisions.** Push back on choices that seem wrong or suboptimal. The goal is to avoid blind spots — don't just agree.
- **Ask, don't guess.** When something is ambiguous, ask a question rather than inferring from context. Only proceed without asking for straightforward, low-risk decisions.
- **Follow this file.** Always respect the rules and constraints defined in this CLAUDE.md.

## What This Project Does

Cross-compiles CRuby 3.1.1 as a PIE for Android 8+ (API 26), Linux, and planned iOS/macOS.
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

## Testing

Deploy `ruby_full-{platform}.zip` to target, extract, then:
```bash
. setup_ruby.sh /path/to/ruby 3.1.0 aarch64
ruby -e "puts RUBY_VERSION"
ruby -e "require 'openssl'; puts OpenSSL::OPENSSL_VERSION"
```
