#!/usr/bin/env bash
set -euo pipefail

# >>> EDIT THESE TWO LINES <<<
REPO="Causely/causely-deploy"
VERSION="${VERSION:-main}"

TARGET_DIR="${TARGET_DIR:-causely-docker}"
BASE="https://raw.githubusercontent.com/$REPO/$VERSION"

# --- Preflight checks (simple, fast) ---
command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose (v2) is required. Install Docker Desktop or the Compose plugin."
  exit 1
fi

echo "→ Installing Causely Docker bundle from $REPO@$VERSION"
mkdir -p "$TARGET_DIR"

# --- Download files ---
curl -fsSLo "$TARGET_DIR/docker-compose.yaml"       "$BASE/docker/docker-compose.yaml"
curl -fsSLo "$TARGET_DIR/mediator-config.yaml"      "$BASE/docker/mediator-config.yaml"
curl -fsSLo "$TARGET_DIR/beyla-config.yaml"         "$BASE/docker/beyla-config.yaml"
curl -fsSLo "$TARGET_DIR/mediator-ml-config.yaml"   "$BASE/docker/mediator-ml-config.yaml"
curl -fsSLo "$TARGET_DIR/executor-config.yaml"      "$BASE/docker/executor-config.yaml"
curl -fsSLo "$TARGET_DIR/.env"                      "$BASE/docker/.env"

# --- Initialize .env if missing ---
if [ ! -f "$TARGET_DIR/.env" ]; then
  cp "$TARGET_DIR/.env.template" "$TARGET_DIR/.env"
fi

echo ""
echo "✓ Files downloaded to: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "1) Edit $TARGET_DIR/.env and set CAUSELY_GATEWAY_TOKEN and DOCKER_HOST_NAME"
echo "2) Start the stack:"
echo "   cd $TARGET_DIR && docker compose up -d"