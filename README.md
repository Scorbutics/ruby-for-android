Ruby 3.X.X for Android 8 (API 26)
===

This is a project to compile Ruby 3 (the official CRuby one, also called MRI) as position independent executable (PIE) for Android.
You need an Unix based environment to build.

It originated from https://github.com/sfrieske/ruby-for-android5 that has been created in 2015 but is now outdated.

The compiled Ruby comes with :
    - zlib
    - gdbm
    - openssl
    - readline
    - the full set of Ruby's stdlib
Which are all the gems embedded in ruby basic install, meaning that you will have a full featured CRuby env running on Android.
You can of course omit some gems and not use all those libraries.

At the moment, it will run on Android 8.0+. Also, only arm64-v8a is currently tested. A support of armeabi-v7a is also planned, but I do not know when it will be achieved.

For now, as the CMake build system here is quite generic, I think you can adapt it quite easily to add the support yourself.

Note for those who are on Windows
===

You should be able to build everything with docker, just look at the shell scripts that are mentioned here and create your own docker command line.
It should not be really complicated.

Preparation
===
1. Install docker, if not already present on your host
2. Clone the following repository: https://github.com/Scorbutics/ruby-android-ndk-docker
3. Execute the "build.sh" script of this existing repository, it will build your docker environment required to compile

Old Preparation (DEPRECATED MANUAL VERSION)
===

1. Download the Android NDK [here](https://developer.android.com/ndk/downloads). Version r23b (23.1.7779620) is the LTS at the time of this writing, it works well.
2. Unpack the NDK
3. Edit the `arm64-v8a-android-toolchain.params` file (or you can create a custom one) and the NDK directory to locate your installation
4. Install Ruby 3.0.0+ on your host with `rvm` or `rbenv` (ruby on the host side is currently required by the `make install` step of ruby package)
5. Download a CMake 3.10+. The minor version is important to ensure the latest NDKs (r19+) are automatically detected

Build
===
Patches
====

 - CRuby 3.1.1 with the current NDK release does not require patching anymore.

 - openssl-1.1.1m does not require patching anymore with NDK versions => r22

Old notes on Patches
====

 - CRuby 3.0.0 configuration step is currently patched to support a NDK <= r22 based clang compilation environment.
    In particular, clang embeds some compiler type definition inside itself and does not support later redefinitions.
    `size_t`, `uint8_t`, `intptr_t`, ... are some examples of those dependent on compiler implementation types.

 - As a ruby dependency for handling ssl, openssl-1.1.1k also needs a patch for any NDK >= r22 release.

Compilation
====

Start the CMake configuration of the project:

With docker:
    `./scripts/configure.sh` from the root folder

Without docker:
    `./configure` from the root folder

Installation
====

The generated binaries are installed in the `target` directory in the root folder. It proceeds as if it was an host machine root and therefore puts everything in `/usr/libs`, `/usr/local/libs`, etc... folders. You will see. It's easy.

A `target/ruby_full.zip` file will then be generated, holding the executables and shared libraries.

There is no reason to separate the stdlib from the binaries except that the original project was targeted at SL4A that encouraged this separation.

To build the zip files simply:

With docker:
    `./scripts/build.sh` from the root folder

Without docker:
    run `make` in `ruby-build`.

Usage
===

Once deployed on the Android device (either manually or as part of an APK) ruby needs to know about the libraries.

For quality of life purpose, I provided a plain `setup_ruby.sh` shell script that exports every required variables for ruby to find either shared libs, gems, or gems specifications when running.

Limitations
===

- I currently do not support Android version < 8 (and I am not sure I will)
- You need docker, or an Unix-based environment to build.
- Full ruby output is ~27Mo, that's HUGE on embedded devices. If you're looking for a lightweight ruby implementation, look at [MRuby](https://github.com/mruby/mruby) instead
