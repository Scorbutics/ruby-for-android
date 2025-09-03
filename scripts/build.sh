#!/bin/sh

#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/docker-dev-action.sh" cmake --build .