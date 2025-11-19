#!/usr/bin/env bash
set -euo pipefail

# ===== config =====
IMAGE="joshuapfritz/hak5c2"
ARCH_SUFFIX="amd64"        # used in the tag :<version>-amd64
TARGET="amd64_linux"       # passed to Dockerfile as --build-arg TARGET
# ===================

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version> [release-suffix]"
  echo "Example: $0 3.5.2 stable   # => RELEASE=3.5.2-stable"
  exit 1
fi

VERSION="$1"                   # e.g. 3.5.2
RELEASE_SUFFIX="${2:-stable}"  # default: 'stable'
RELEASE="${VERSION}-${RELEASE_SUFFIX}"

TAG_ARCH="${IMAGE}:${VERSION}-${ARCH_SUFFIX}"
TAG_VERSION="${IMAGE}:${VERSION}"
TAG_LATEST="${IMAGE}:latest"

echo "==============================="
echo "Image:        ${IMAGE}"
echo "Version:      ${VERSION}"
echo "Release ID:   ${RELEASE}"
echo "Target:       ${TARGET}"
echo "Tags:         ${TAG_ARCH}, ${TAG_VERSION}, ${TAG_LATEST}"
echo "==============================="

echo "[1/4] docker login (if needed)..."
docker login

echo "[2/4] Building ${TAG_ARCH}..."
DOCKER_BUILDKIT=1 docker build \
  --build-arg RELEASE="${RELEASE}" \
  --build-arg TARGET="${TARGET}" \
  -t "${TAG_ARCH}" .

echo "[3/4] Tagging..."
docker tag "${TAG_ARCH}" "${TAG_VERSION}"
docker tag "${TAG_ARCH}" "${TAG_LATEST}"

echo "[4/4] Pushing..."
docker push "${TAG_ARCH}"
docker push "${TAG_VERSION}"
docker push "${TAG_LATEST}"

echo "Done."
