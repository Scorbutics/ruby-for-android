#!/bin/sh

# example of use for Ruby 3.1.0 or 3.1.1: "./setup_ruby.sh . 3.1.0 aarch64"

ROOT="$1"
RUBY_VERSION="$2"
ARCH="$3"

export LD_LIBRARY_PATH="$ROOT/usr/local/lib/ruby/$RUBY_VERSION/:$ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="${PATH:+$PATH:}$ROOT/usr/local/bin"

export GEM_PATH="$ROOT/usr/local/lib/ruby/gems/$RUBY_VERSION/"
export GEM_SPEC_CACHE="$ROOT/usr/local/lib/ruby/gems/$RUBY_VERSION/specifications/"

RUBY_ARCH_LIB_DIR="$(ls -d $ROOT/usr/local/lib/ruby/$RUBY_VERSION/$ARCH*)"
export RUBYLIB="$ROOT/usr/local/lib/ruby/$RUBY_VERSION/:$RUBY_ARCH_LIB_DIR:$ROOT/usr/local/bin/"
