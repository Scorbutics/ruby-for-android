#!/bin/sh

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT_DIR/scripts/tools/docker-dev-action.sh" cmake --build .

echo "Copying build/target content to host..."

PROJECT_NAME="$(basename $ROOT_DIR)"
CONTAINER="${PROJECT_NAME}_dev"
rm -rf "$ROOT_DIR/target"
docker cp "$CONTAINER":/opt/current/build/target "$ROOT_DIR"