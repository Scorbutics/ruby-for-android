# Build scripts for ruby-for-android dependencies

Pure-CMake scripts (`cmake -P`) that handle the **build** step of dependencies
whose upstream build systems don't fit the canonical autoconf
`./configure && make` flow. CMake invokes the toolchain directly via
`execute_process` — no shell needed, so these work identically on Linux,
macOS, and Windows build hosts.

Install steps are inlined into the cmake files themselves (`${CMAKE_COMMAND}
-E copy`) — no separate scripts.

| File | Used by | Purpose |
|---|---|---|
| `build_physfs.cmake` | `physfs.cmake` | Compile PhysicsFS sources directly with the cross-toolchain (PhysFS is "drop-in compilable" plain C — no autoconf/cmake of its own needed). |
| `build_ruby_physfs.cmake` | `ruby-physfs.cmake` | Cross-compile the [ruby-physfs gem](https://github.com/Scorbutics/ruby-physfs)'s C++ sources into `libphysfs-ruby.a` (bypasses mkmf, which is awkward to cross-compile). |

Both scripts read the cross-toolchain from env vars (`CC` / `CXX` / `CFLAGS`
/ `AR`) injected by `BUILD_ENV` via the wrapping `cmake -E env ...` from
`add_external_dependency`.

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
