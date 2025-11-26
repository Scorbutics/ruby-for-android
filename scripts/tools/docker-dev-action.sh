#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
. "$DIR/constants.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo "${GREEN}[OK]${NC} $*" >&2
}

log_warn() {
  echo "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
  echo "${RED}[ERROR]${NC} $*" >&2
}

usage() {
  cat >&2 << EOF
Usage: $0 [OPTIONS] <command> [args...]

OPTIONS:
  -q, --quiet         Suppress informational output
  -f, --force-sync    Force source synchronization even if container is running
  -r, --rebuild       Force rebuild of Docker images
  -h, --help          Show this help message

EXAMPLES:
  $0 ./configure
  $0 cmake --build .
  $0 --force-sync ./scripts/build.sh
  $0 --rebuild make clean

DESCRIPTION:
  Executes commands inside the Docker development container.
  Automatically builds and starts the Docker stack if needed.
EOF
  exit 1
}

# Parse options
FORCE_SYNC=0
REBUILD=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    -q|--quiet)
      QUIET=1
      shift
      ;;
    -f|--force-sync)
      FORCE_SYNC=1
      shift
      ;;
    -r|--rebuild)
      REBUILD=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -lt 1 ]; then
  log_error "No command specified"
  usage
fi

# Quiet mode: redirect info/success logs to /dev/null
if [ $QUIET -eq 1 ]; then
  exec 3>&2
  exec 2>/dev/null
fi

# Navigate to docker-compose directory
COMPOSE_DIR="$(cd "$DIR/../.." && pwd)"
cd "$COMPOSE_DIR"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  log_error "Docker daemon is not running. Please start Docker and try again."
  exit 1
fi

log_info "Using project: $PROJECT_NAME"
log_info "Container name: $CONTAINER"

# Function to check if container is running
is_container_running() {
  docker ps --filter "name=${CONTAINER}" --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER}$"
}

# Function to check if container exists (running or stopped)
container_exists() {
  docker ps -a --filter "name=${CONTAINER}" --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER}$"
}

# Function to check if volume exists
volume_exists() {
  docker volume ls --format "{{.Name}}" 2>/dev/null | grep -q "^${PROJECT_NAME}_currentdata$"
}

# Function to sync sources
sync_sources() {
  log_info "Synchronizing source files to Docker volume..."
  if docker compose run --rm --remove-orphans init >/dev/null 2>&1; then
    log_success "Source synchronization complete"
    return 0
  else
    log_error "Failed to synchronize sources"
    return 1
  fi
}

# Function to build and start the dev container
start_dev_container() {
  local rebuild_flag=""
  if [ $REBUILD -eq 1 ]; then
    log_info "Forcing rebuild of Docker images..."
    rebuild_flag="--build"
  fi

  log_info "Starting development container..."
  if docker compose up $rebuild_flag -d ruby-android-ndk 2>&1 | grep -q "Started\|Running"; then
    log_success "Development container started"
    return 0
  else
    # Container might already be running
    if is_container_running; then
      log_success "Development container already running"
      return 0
    else
      log_error "Failed to start development container"
      return 1
    fi
  fi
}

# Function to wait for container to be ready
wait_for_container() {
  local max_attempts=30
  local attempt=0

  log_info "Waiting for container to be ready..."

  while [ $attempt -lt $max_attempts ]; do
    if is_container_running; then
      # Verify the container is actually responsive
      if docker exec "$CONTAINER" echo "ready" >/dev/null 2>&1; then
        log_success "Container is ready"
        return 0
      fi
    fi

    attempt=$((attempt + 1))
    sleep 1
  done

  log_error "Container failed to become ready within ${max_attempts} seconds"
  return 1
}

# Main initialization logic
initialize_dev_environment() {
  local needs_sync=0
  local needs_start=0

  # Check if container is running
  if is_container_running; then
    log_info "Container is already running"

    # Check if force sync is requested
    if [ $FORCE_SYNC -eq 1 ]; then
      log_warn "Force sync requested - stopping container for synchronization"
      docker compose stop ruby-android-ndk >/dev/null 2>&1 || true
      needs_sync=1
      needs_start=1
    fi
  else
    log_info "Container is not running"
    needs_start=1

    # Check if we need to sync (volume doesn't exist or container never ran)
    if ! volume_exists || [ $FORCE_SYNC -eq 1 ]; then
      needs_sync=1
    fi
  fi

  # Perform synchronization if needed
  if [ $needs_sync -eq 1 ]; then
    if ! sync_sources; then
      return 1
    fi
  else
    log_info "Skipping source sync (use --force-sync to override)"
  fi

  # Start container if needed
  if [ $needs_start -eq 1 ]; then
    if ! start_dev_container; then
      return 1
    fi

    if ! wait_for_container; then
      return 1
    fi
  fi

  return 0
}

# Initialize the development environment
log_info "Initializing Docker development environment..."
if ! initialize_dev_environment; then
  log_error "Failed to initialize development environment"
  exit 1
fi

# Get container ID
CONTAINER_ID=$(docker ps --filter "name=${CONTAINER}" --format "{{.ID}}" 2>/dev/null)

if [ -z "$CONTAINER_ID" ]; then
  log_error "Container '$CONTAINER' is not running"
  exit 1
fi

log_info "Executing command in container: $*"

# Restore stderr if in quiet mode
if [ $QUIET -eq 1 ]; then
  exec 2>&3
  exec 3>&-
fi

# Execute the requested command inside the build container
# Detect if we're in an interactive terminal
if [ -t 0 ]; then
  # Interactive mode (with TTY)
  docker exec ${DOCKER_ENV} -it "$CONTAINER_ID" "$@"
else
  # Non-interactive mode (no TTY - useful for CI/CD)
  docker exec ${DOCKER_ENV} "$CONTAINER_ID" "$@"
fi
