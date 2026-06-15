#!/bin/bash
set -euo pipefail

VERSION_URL="https://docs.causely.ai/meta/version.json"
FLUX_KUSTOMIZATION_FILE="kubernetes/fluxcd/causely/kustomization.yaml"
ARGOCD_APPLICATION_FILE="kubernetes/argocd/components/applications/causely/causely.yaml"
UPDATED_FILES=()

# Fetch latest version
VERSION_JSON=$(curl -s "$VERSION_URL")
IMAGE_VERSION=$(echo "$VERSION_JSON" | jq -r '.versions[0].imageVersion')

if [ -z "$IMAGE_VERSION" ] || [ "$IMAGE_VERSION" == "null" ]; then
  echo "Error: Failed to extract imageVersion from version.json"
  exit 1
fi

echo "Found latest version: $IMAGE_VERSION"

update_file_version() {
  local file=$1
  local pattern=$2

  if [ ! -f "$file" ]; then
    echo "Error: File $file not found"
    exit 1
  fi

  cp "$file" "${file}.bak"

  if sed -i.bak "$pattern" "$file" 2>/dev/null || \
     sed -i '' "$pattern" "$file" 2>/dev/null; then
    rm -f "${file}.bak"
  else
    echo "Error: Failed to update $file"
    mv "${file}.bak" "$file"
    exit 1
  fi

  UPDATED_FILES+=("$file")
  echo "Updated $file with version $IMAGE_VERSION"
}

update_file_version "$FLUX_KUSTOMIZATION_FILE" \
  "s/CAUSELY_VERSION: \".*\"/CAUSELY_VERSION: \"$IMAGE_VERSION\"/"

update_file_version "$ARGOCD_APPLICATION_FILE" \
  "s/targetRevision: \".*\"/targetRevision: \"$IMAGE_VERSION\"/"

# Check if changes were made
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not in a git repository"
  exit 0
fi

changed=false
for file in "${UPDATED_FILES[@]}"; do
  if ! git diff --quiet "$file" 2>/dev/null; then
    changed=true
    break
  fi
done

if [ "$changed" = false ]; then
  echo "No changes detected"
fi

exit 0
