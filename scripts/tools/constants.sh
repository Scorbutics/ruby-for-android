#!/bin/sh
PROJECT_NAME="$(basename "$(cd "$DIR/../.." && pwd)")"
CONTAINER="${PROJECT_NAME}_dev"
IMAGE="scor/ruby-android-ndk:latest"
WORKDIR="/opt/current"
BUILD_DIR="$WORKDIR/build"
SOURCE_DIR="../src"