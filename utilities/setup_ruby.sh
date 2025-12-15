#!/bin/sh

# example of use for Ruby 3.1.0 or 3.1.1: "./setup_ruby.sh . 3.1.0 aarch64"

export ROOT="$1"
export RUBY_VERSION="$2"
export ARCH="$3"

. constants.sh
