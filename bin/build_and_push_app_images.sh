#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

builder="giocci_builder"

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

# Build and push images
docker compose -f "${root_dir}/apps/giocci/docker-compose.yml" build --push giocci

docker compose -f "${root_dir}/apps/giocci_relay/docker-compose.yml" build --push giocci_relay

docker compose -f "${root_dir}/apps/giocci_engine/docker-compose.yml" build --push giocci_engine
