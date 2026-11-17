#!/usr/bin/env bash
# Builds the WCL Zammad image from this repository (the commit checked out now).
set -euo pipefail
cd "$(dirname "$0")"
export COMMIT_SHA="$(git rev-parse HEAD)"
docker compose --profile build build zammad-image
echo "Built $(docker compose config --images | grep -m1 zammad) from ${COMMIT_SHA:0:8}."

# The backup container runs as uid 1000 and writes to ./backup; a folder Docker created (owned by
# root) makes every backup fail with "Permission denied".
mkdir -p backup
if [ "$(stat -c %u backup)" != "1000" ]; then
  echo "Giving ./backup to uid 1000 (the Zammad user) so backups can be written; sudo may ask for your password."
  sudo chown -R 1000:1000 backup
fi
