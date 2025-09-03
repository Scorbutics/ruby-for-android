#!/bin/sh

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/docker-dev-action.sh" cmake --build .

echo "Copying build/target content to host..."

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="$(basename $ROOT_DIR)"
CONTAINER="${PROJECT_NAME}_dev"
rm -rf "$ROOT_DIR/target"
docker cp "$CONTAINER":/opt/current/build/target "$ROOT_DIR"