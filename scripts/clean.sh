#!/bin/sh
ROOT_BUILD_DIR=ruby-build

rm -rf $ROOT_BUILD_DIR/CMakeFiles

TARGETS="$@"

clear_folder() {
  local folder="$1"
  [ -d "$folder" ] && rm -rf "$folder/build_dir/"* && rm -rf "$folder/build_dir/".*
}

if [ -z "$TARGETS" ]; then
  rm -f CMakeCache.txt Makefile cmake_install.cmake
  rm -rf CMakeFiles
  for item in $(find "$ROOT_BUILD_DIR"/* -maxdepth 0 -type d -print); do
    clear_folder "$item"
  done
  rm -f $ROOT_BUILD_DIR/cmake_install.cmake $ROOT_BUILD_DIR/Makefile
  rm -rf target/
else
  for target in $TARGETS; do
    clear_folder "$ROOT_BUILD_DIR/$target"
  done
fi;