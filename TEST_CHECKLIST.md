# Refactoring Test Checklist

## Pre-Test Setup

- [ ] Clean any existing build artifacts
  ```bash
  rm -rf build/ target/
  ```

- [ ] Verify Docker is running
  ```bash
  docker --version
  ```

- [ ] Ensure ruby-android-ndk-docker image exists
  ```bash
  docker images | grep ruby-android-ndk
  ```

## Test 1: Configuration Phase

- [ ] Run configure script
  ```bash
  ./scripts/configure.sh
  ```

- [ ] Verify no errors in output

- [ ] Check for modular system messages
  - [ ] "Ruby Cross-Platform Build System" banner
  - [ ] "Target platform: Android"
  - [ ] "Loading platform configuration"
  - [ ] "RubyBuildHelpers loaded"

- [ ] Verify build directory created
  ```bash
  ls build/
  ```

- [ ] Check CMakeCache.txt exists
  ```bash
  ls build/CMakeCache.txt
  ```

## Test 2: Dry-Run Build (Configure Check)

- [ ] Check that CMake finds all modules
  ```bash
  docker exec ruby-for-android_dev cmake --build . --target help
  ```

- [ ] Verify targets exist:
  - [ ] `ruby_archive`
  - [ ] `ruby_external`
  - [ ] `openssl_external`
  - [ ] `gdbm_external`
  - [ ] `ncurses_external`
  - [ ] `readline_external`
  - [ ] `clean-all`
  - [ ] Individual `{dep}_clean` targets

## Test 3: Build Single Dependency

- [ ] Build ncurses (smallest dependency)
  ```bash
  ./scripts/tools/docker-dev-action.sh cmake --build . --target ncurses
  ```

- [ ] Check download succeeded
  ```bash
  ls build/download/ncurses-6.4*
  ```

- [ ] Check extraction succeeded
  ```bash
  ls build/ncurses/build_dir/ncurses-6.4/
  ```

- [ ] Check build succeeded
  ```bash
  ls build/target/usr/local/lib/libncurses*
  ```

## Test 4: Full Build

- [ ] Run full build
  ```bash
  ./scripts/build.sh
  ```

- [ ] Monitor for errors (should complete successfully)

- [ ] Verify all dependencies built
  ```bash
  ls build/target/usr/local/lib/
  ```
  Expected libraries:
  - [ ] `libncurses.so`
  - [ ] `libreadline.so`
  - [ ] `libgdbm.so`
  - [ ] `libssl.so`
  - [ ] `libcrypto.so`
  - [ ] `libruby.so`

- [ ] Verify Ruby built
  ```bash
  file build/target/usr/local/bin/ruby
  ```
  Should show: ELF 64-bit LSB pie executable, ARM aarch64

- [ ] Verify archive created
  ```bash
  ls -lh target/ruby_full.zip
  ```
  Expected size: ~25-30 MB

## Test 5: Verify Archive Contents

- [ ] Extract and verify contents
  ```bash
  mkdir -p /tmp/ruby-test
  cd /tmp/ruby-test
  unzip ~/Desktop/dev/ruby-for-android/target/ruby_full.zip
  ```

- [ ] Check binaries present
  ```bash
  ls usr/local/bin/
  ```
  - [ ] `ruby`
  - [ ] `irb`
  - [ ] `gem`
  - [ ] `rake`
  - [ ] `bundle`
  - [ ] `bundler`

- [ ] Check libraries present
  ```bash
  ls usr/local/lib/*.so
  ```

- [ ] Check stdlib present
  ```bash
  ls usr/local/lib/ruby/3.1.0/
  ```

## Test 6: Clean Targets

- [ ] Test individual clean
  ```bash
  ./scripts/tools/docker-dev-action.sh cmake --build . --target ruby_clean
  ```

- [ ] Verify ruby build dir removed
  ```bash
  ls build/ruby/build_dir/  # Should be empty or not exist
  ```

- [ ] Test clean-all
  ```bash
  ./scripts/clean.sh
  ```

- [ ] Verify all cleaned
  ```bash
  ls build/*/build_dir/  # Should be empty
  ```

## Test 7: Incremental Build

- [ ] Make a small change (e.g., touch a file)
  ```bash
  touch cmake/dependencies/ruby.cmake
  ```

- [ ] Rebuild
  ```bash
  ./scripts/build.sh
  ```

- [ ] Verify only necessary parts rebuilt (should be fast)

## Test 8: Patch Application

- [ ] Check patch logs
  ```bash
  grep -r "Applying patch" build/*/stamps/*.log
  ```

- [ ] Verify patches applied
  - [ ] Android SONAME patches applied
  - [ ] No patch failures in logs

## Test 9: Error Handling

- [ ] Test with invalid NDK (optional - requires editing)
  ```bash
  # Edit arm64-v8a-android-toolchain.params to point to bad path
  # Configure should fail with clear error
  ```

- [ ] Restore valid configuration

## Post-Test Validation

- [ ] Compare with previous build (if available)
  ```bash
  # Size should be similar
  ls -lh target/ruby_full.zip
  ls -lh /path/to/old/ruby_full.zip
  ```

- [ ] Deploy to Android device (optional but recommended)
  ```bash
  adb push target/ruby_full.zip /data/local/tmp/
  adb shell
  cd /data/local/tmp
  unzip ruby_full.zip
  . setup_ruby.sh . 3.1 aarch64
  ruby -v
  ```

- [ ] Run basic Ruby test
  ```bash
  ruby -e "puts 'Hello from refactored build!'"
  ruby -e "require 'openssl'; puts OpenSSL::OPENSSL_VERSION"
  ```

## Issues Found

Document any issues here:

```
Issue:
Steps to reproduce:
Error message:
Resolution:
```

## Sign-Off

- [ ] All tests passed
- [ ] No regressions found
- [ ] Build output identical to previous system
- [ ] Documentation reviewed
- [ ] Ready to proceed with new platform support

**Tested by:** _________________

**Date:** _________________

**Notes:**
