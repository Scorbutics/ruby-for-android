#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"
export DOCKER_ENV="-e "TOOLCHAIN_FILE=$TOOLCHAIN_FILE""
"$DIR/docker-dev-action.sh" ../src/configure