#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"

. "$DIR/tools/constants.sh"

export DOCKER_ENV="-e "TOOLCHAIN_FILE=$TOOLCHAIN_FILE""
"$DIR/tools/docker-dev-action.sh" "$SOURCE_DIR/configure"