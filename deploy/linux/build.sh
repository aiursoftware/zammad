#!/usr/bin/env bash
# Builds the WCL Zammad image from this repository (the commit checked out now).
set -euo pipefail
cd "$(dirname "$0")"
export COMMIT_SHA="$(git rev-parse HEAD)"
docker compose --profile build build zammad-image
echo "Built $(docker compose config --images | grep -m1 zammad) from ${COMMIT_SHA:0:8}."

# The Zammad containers run as uid 1000 and write backups to ./backup and log files to ./log; a
# folder Docker created (owned by root) makes them fail with "Permission denied".
for dir in backup log; do
  mkdir -p "$dir"
  if [ "$(stat -c %u "$dir")" != "1000" ]; then
    echo "Giving ./$dir to uid 1000 (the Zammad user) so it can be written; sudo may ask for your password."
    sudo chown -R 1000:1000 "$dir"
  fi
done
