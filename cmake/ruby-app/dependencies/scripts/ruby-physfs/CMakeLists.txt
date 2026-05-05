# Builds libphysfs-ruby.a — the C++ side of the ruby-physfs gem.
#
# The gem ships only an extconf.rb / Rakefile, which is awkward to
# cross-compile. Its native part is just a handful of .cpp files we can
# build directly with the cross toolchain. The output static lib gets
# linked into embedded-ruby-vm so that Init_physfs() becomes a reachable
# symbol — see ruby-physfs.cmake for how the embedder calls it.
#
# Required cache vars (passed via -D from ruby-physfs.cmake):
#   GEM_SOURCE_DIR     Root of the cloned ruby-physfs repo (contains ext/physfs).
#   RUBY_STAGING_DIR   Staging dir where Ruby + PhysFS were installed.
#   RUBY_ABI_VERSION   e.g. "3.1.0" — to locate Ruby's platform include dir.

cmake_minimum_required(VERSION 3.14)
project(ruby_physfs LANGUAGES CXX)

foreach(_v GEM_SOURCE_DIR RUBY_STAGING_DIR RUBY_ABI_VERSION)
    if(NOT ${_v})
        message(FATAL_ERROR "ruby-physfs: -D${_v}=... is required")
    endif()
endforeach()

# Locate Ruby's platform-specific include dir (where ruby/config.h lives).
# The directory name varies by target (aarch64-linux-android, x86_64-linux-gnu,
# arm64-darwin, ...), so we glob and pick the first one with ruby/config.h.
set(_RUBY_INC_BASE "${RUBY_STAGING_DIR}/usr/local/include/ruby-${RUBY_ABI_VERSION}")
if(NOT IS_DIRECTORY "${_RUBY_INC_BASE}")
    message(FATAL_ERROR
        "ruby-physfs: Ruby headers not found at ${_RUBY_INC_BASE}\n"
        "  — was Ruby built first? (ruby must precede ruby-physfs in APP_DEPENDENCIES)")
endif()

set(_RUBY_PLATFORM_INC "")
file(GLOB _candidates "${_RUBY_INC_BASE}/*")
foreach(_c ${_candidates})
    if(IS_DIRECTORY "${_c}" AND EXISTS "${_c}/ruby/config.h")
        set(_RUBY_PLATFORM_INC "${_c}")
        break()
    endif()
endforeach()
if(NOT _RUBY_PLATFORM_INC)
    message(FATAL_ERROR
        "ruby-physfs: could not locate ruby/config.h under ${_RUBY_INC_BASE}/<platform>/\n"
        "  Available subdirs: ${_candidates}")
endif()

file(GLOB _SRCS CONFIGURE_DEPENDS "${GEM_SOURCE_DIR}/ext/physfs/*.cpp")
if(NOT _SRCS)
    message(FATAL_ERROR "ruby-physfs: no .cpp sources under ${GEM_SOURCE_DIR}/ext/physfs/")
endif()

add_library(physfs-ruby STATIC ${_SRCS})
target_compile_features(physfs-ruby PRIVATE cxx_std_17)
set_target_properties(physfs-ruby PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(physfs-ruby PRIVATE
    "${_RUBY_INC_BASE}"
    "${_RUBY_PLATFORM_INC}"
    "${RUBY_STAGING_DIR}/usr/local/include"
)

install(TARGETS physfs-ruby ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
