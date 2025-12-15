#!/bin/bash
set -euo pipefail

VERSION_URL="https://docs.causely.ai/meta/version.json"
KUSTOMIZATION_FILE="kubernetes/fluxcd/causely/kustomization.yaml"

# Fetch latest version
VERSION_JSON=$(curl -s "$VERSION_URL")
IMAGE_VERSION=$(echo "$VERSION_JSON" | jq -r '.versions[0].imageVersion')

if [ -z "$IMAGE_VERSION" ] || [ "$IMAGE_VERSION" == "null" ]; then
  echo "Error: Failed to extract imageVersion from version.json"
  exit 1
fi

echo "Found latest version: $IMAGE_VERSION"

# Update kustomization.yaml
if [ ! -f "$KUSTOMIZATION_FILE" ]; then
  echo "Error: File $KUSTOMIZATION_FILE not found"
  exit 1
fi

# Create backup
cp "$KUSTOMIZATION_FILE" "${KUSTOMIZATION_FILE}.bak"

# Update version
if sed -i.bak "s/CAUSELY_VERSION: \".*\"/CAUSELY_VERSION: \"$IMAGE_VERSION\"/" "$KUSTOMIZATION_FILE" 2>/dev/null || \
   sed -i '' "s/CAUSELY_VERSION: \".*\"/CAUSELY_VERSION: \"$IMAGE_VERSION\"/" "$KUSTOMIZATION_FILE" 2>/dev/null; then
  rm -f "${KUSTOMIZATION_FILE}.bak"
else
  echo "Error: Failed to update $KUSTOMIZATION_FILE"
  mv "${KUSTOMIZATION_FILE}.bak" "$KUSTOMIZATION_FILE"
  exit 1
fi

# Check if changes were made
if git diff --quiet "$KUSTOMIZATION_FILE" 2>/dev/null || ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "No changes detected or not in a git repository"
  exit 0
else
  echo "Updated $KUSTOMIZATION_FILE with version $IMAGE_VERSION"
  exit 0
fi

