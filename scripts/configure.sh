#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"

. "$DIR/tools/constants.sh"

export DOCKER_ENV="-e "TOOLCHAIN_PARAMS=$TOOLCHAIN_PARAMS""
"$DIR/tools/docker-dev-action.sh" "$SOURCE_DIR/configure"