#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# GHCR_USERNAME must be set
if [[ -z "${GHCR_USERNAME:-}" ]]; then
    echo "ERROR: GHCR_USERNAME environment variable is not set"
    echo "Set it in docker/.env or your shell profile"
    exit 1
fi

IMAGE="ghcr.io/${GHCR_USERNAME}/openclaw-docker-config/openclaw-gateway"
TAG="${1:-latest}"
SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD)

echo "==> Validating config ..."
"$REPO_ROOT/scripts/validate-config.sh"
echo ""
"$REPO_ROOT/scripts/check-secrets.sh"
echo ""

echo "==> Building image ..."
echo "    Image: $IMAGE"
echo "    Tags:  $TAG, $SHA"
echo ""

docker buildx build --platform linux/amd64 -f "$REPO_ROOT/docker/Dockerfile" -t "$IMAGE:$TAG" -t "$IMAGE:$SHA" --push "$REPO_ROOT"

echo ""
echo "✓ Built and pushed $IMAGE:$TAG (linux/amd64)"
echo "✓ Built and pushed $IMAGE:$SHA (linux/amd64)"
