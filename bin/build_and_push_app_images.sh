#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

builder="giocci_builder"

# Usage function
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [SERVICE...]

Build and push Docker images for specified services.

Options:
  --dry-run     Build images without pushing to registry
  --load        Build images and load into local Docker daemon
  -h, --help    Show this help message

Available services:
  all           - All services
  zenohd        - Zenoh daemon
  giocci        - Giocci application
  giocci_relay  - Giocci relay service
  giocci_engine - Giocci engine service

Examples:
  $0 all                      # Build and push all services
  $0 --dry-run all            # Build all services without pushing
  $0 --load all               # Build all services and load into local Docker daemon
  $0 zenohd                   # Build and push only zenohd
  $0 --dry-run giocci zenohd  # Build giocci and zenohd without pushing
  $0 --load giocci zenohd     # Build giocci and zenohd and load locally

EOF
  exit 1
}

# Parse arguments
DRY_RUN=false
LOAD=false
SERVICES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --load)
      LOAD=true
      shift
      ;;
    *)
      SERVICES+=("$1")
      shift
      ;;
  esac
done

# Check if any services were specified
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  usage
fi

# Check mutually exclusive options
if [[ "$DRY_RUN" == "true" && "$LOAD" == "true" ]]; then
  echo "Error: --dry-run and --load are mutually exclusive" >&2
  exit 1
fi

# Define all available services
ALL_SERVICES=("zenohd" "giocci" "giocci_relay" "giocci_engine")
VALID_SERVICES=("all" "${ALL_SERVICES[@]}")

# Validate services before expansion
for service in "${SERVICES[@]}"; do
  if [[ ! " ${VALID_SERVICES[@]} " =~ " ${service} " ]]; then
    echo "Error: Unknown service '${service}'" >&2
    echo "Valid services: ${VALID_SERVICES[*]}" >&2
    exit 1
  fi
done

# Expand "all" to all services
if [[ " ${SERVICES[@]} " =~ " all " ]]; then
  SERVICES=("${ALL_SERVICES[@]}")
fi

# Remove duplicates while preserving order
declare -A seen
UNIQUE_SERVICES=()
for service in "${SERVICES[@]}"; do
  if [[ ! ${seen[$service]:-} ]]; then
    UNIQUE_SERVICES+=("$service")
    seen[$service]=1
  fi
done
SERVICES=("${UNIQUE_SERVICES[@]}")

# Cleanup function to ensure builder is removed even on error
cleanup() {
  if docker buildx inspect "$builder" &>/dev/null; then
    echo "Removing builder: $builder"
    docker buildx rm "$builder" || true
  fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Remove existing builder if it exists
if docker buildx inspect "$builder" &>/dev/null; then
  echo "Removing existing builder: $builder"
  docker buildx rm "$builder"
fi

# Create and use new builder
docker buildx create --name "$builder"
docker buildx use "$builder"

# Helper function to build service
build_service() {
  local compose_file="$1"
  local service_name="$2"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    docker compose -f "$compose_file" build "$service_name"
  elif [[ "$LOAD" == "true" ]]; then
    docker buildx bake -f "$compose_file" --load "$service_name"
  else
    docker compose -f "$compose_file" build --push "$service_name"
  fi
}

# Build images for selected services
for service in "${SERVICES[@]}"; do
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Building (dry-run): ${service}"
  elif [[ "$LOAD" == "true" ]]; then
    echo "Building and loading locally: ${service}"
  else
    echo "Building and pushing: ${service}"
  fi
  
  case "${service}" in
    zenohd)
      build_service "${root_dir}/docker-compose.yml" zenohd
      ;;
    giocci)
      build_service "${root_dir}/apps/giocci/docker-compose.yml" giocci
      ;;
    giocci_relay)
      build_service "${root_dir}/apps/giocci_relay/docker-compose.yml" giocci_relay
      ;;
    giocci_engine)
      build_service "${root_dir}/apps/giocci_engine/docker-compose.yml" giocci_engine
      ;;
  esac
done

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Successfully built (without pushing): ${SERVICES[*]}"
elif [[ "$LOAD" == "true" ]]; then
  echo "Successfully built and loaded locally: ${SERVICES[*]}"
else
  echo "Successfully built and pushed: ${SERVICES[*]}"
fi
