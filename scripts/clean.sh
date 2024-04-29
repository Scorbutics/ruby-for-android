#!/bin/sh

rm -f CMakeCache.txt Makefile cmake_install.cmake
rm -rf CMakeFiles
rm -rf ruby-build/CMakeFiles
for item in "ruby-build"/*
do
  [ -d "$item" ] && rm -rf $item/build_dir/*
done
rm -f ruby-build/cmake_install.cmake ruby-build/Makefile

rm -rf target/