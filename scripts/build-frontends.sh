#!/usr/bin/env bash
# Builds the ES-translated frontend images the docker-compose.yml expects.
# (Upstream only publishes Estonian/English images on Docker Hub, so these
# have to be built locally from the translated forks.)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Building byk-chat-widget:es-local"
docker build -t byk-chat-widget:es-local "$ROOT_DIR/Chat-Widget"

echo "==> Building byk-customer-service:es-local"
# Dockerfile.local-preview skips the internal nexus.riaint.ee npm registry and
# the SonarQube stage from the upstream Dockerfile — neither is reachable/needed
# for a local build.
docker build -t byk-customer-service:es-local \
  -f "$ROOT_DIR/Customer-service/Dockerfile.local-preview" "$ROOT_DIR/Customer-service"

echo "Frontend images built."
