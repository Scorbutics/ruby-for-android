#!/bin/sh

TARGETS="$@"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$TARGETS" ]; then
  "$DIR/tools/docker-dev-action.sh" cmake --build . --target clean-all
else
  for target in $TARGETS; do
    "$DIR/tools/docker-dev-action.sh" cmake --build . --target "${target}_clean"
  done
fi;