#!/bin/sh

docker run \
    -v $(pwd):/opt/current \
    -u $(id -u ${USER}):$(id -g ${USER}) \
    -e TOOLCHAIN_FILE=${TOOLCHAIN_FILE} \
    scor/ruby-android-ndk:latest \
    bash \
    -c './configure'
