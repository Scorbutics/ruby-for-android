#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
. "$DIR/constants.sh"

function usage() {
  echo "Usage: $0 <command> [args...]"
  echo "  Example: $0 ./configure"
  echo "           $0 cmake --build ."
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

# 1. Sync host sources into named volume via init container
(cd "$DIR/.." && docker compose run --rm --remove-orphans init)

# 2. Ensure persistent build container exists and is running
if [ "$(docker ps -q -f name=$CONTAINER | wc -l)" -gt 0 ]; then
  # running container present
  :
else 
  if [ "$(docker ps -a -q -f name=$CONTAINER | wc -l)" -gt 0 ]; then
    # stopped container exists, remove it
    docker rm $CONTAINER
  fi
  docker run -d --name $CONTAINER -v $VOLUME:$WORKDIR -e "SOURCE_DIR=$SOURCE_DIR" -w /$BUILD_DIR $IMAGE sleep infinity
fi

# 3. Execute the requested command inside the build container
docker exec ${DOCKER_ENV} -it $CONTAINER "$@"
