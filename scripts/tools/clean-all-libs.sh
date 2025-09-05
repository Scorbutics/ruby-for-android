#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"

. "$DIR/constants.sh"

ROOT_BUILD_DIR="$SOURCE_DIR/ruby-build"

for item in $(find "$ROOT_BUILD_DIR"/* -maxdepth 0 -type d -print); do
    cmake --build . --target "$(basename $item)_clean"
done
