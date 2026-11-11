#!/usr/bin/env bash
# Builds the WCL Zammad image from this repository (the commit checked out now).
set -euo pipefail
cd "$(dirname "$0")"
export COMMIT_SHA="$(git rev-parse HEAD)"
docker compose --profile build build zammad-image
echo "Built $(docker compose config --images | grep -m1 zammad) from ${COMMIT_SHA:0:8}."
