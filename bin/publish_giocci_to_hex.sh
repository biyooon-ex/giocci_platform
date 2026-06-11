#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
versions_src="${root_dir}/VERSIONS"
versions_dst="${root_dir}/apps/giocci/VERSIONS"

cleanup() {
  rm -f "$versions_dst"
}

trap cleanup EXIT

cp "$versions_src" "$versions_dst"

cd "${root_dir}/apps/giocci"
mix hex.publish "$@"