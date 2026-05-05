# Build scripts for ruby-for-android dependencies

In-tree build helpers for dependencies whose upstream build systems don't
fit the canonical autoconf `./configure && make` flow.

| Path | Used by | Purpose |
|---|---|---|
| `ruby-physfs/CMakeLists.txt` | `ruby-physfs.cmake` | Builds `libphysfs-ruby.a` from the gem's `ext/physfs/*.cpp`. The gem only ships an extconf.rb / Rakefile, both awkward to cross-compile, so we provide our own CMakeLists.txt and invoke it as a sub-CMake build. |

Sub-CMake builds inherit cross-compile settings from the parent via
`get_sub_cmake_cross_args()` (defined in `cmake/core/BuildHelpers.cmake`),
which forwards the right toolchain file / arch flags depending on
`TARGET_PLATFORM`.

## How `require 'physfs'` works without an .so

The static integration produces no `physfs.so` — the gem's C-extension is
compiled into `libphysfs-ruby.a` and linked into `libembedded-ruby-vm`. To
make `require 'physfs'` succeed at runtime:

1. The embedder (e.g., litergss-everywhere's `extension-init.c`) registers a
   callback via `ruby_set_custom_ext_init()` that calls `Init_physfs()`
   followed by `rb_provide("physfs")`.
2. embedded-ruby-vm invokes this callback during VM bootstrap, after Ruby's
   own `Init_ext()` and before the user script runs.
3. `rb_provide("physfs")` adds `"physfs"` to `$LOADED_FEATURES`, so any
   subsequent `require 'physfs'` is a no-op.

If `Init_physfs` is never wired in, the build fails at link time with an
"undefined reference to Init_physfs" error — loud and immediate, before any
runtime fallback could kick in. So no shim/stub `.rb` file is shipped.
