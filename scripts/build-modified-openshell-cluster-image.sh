#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPEN_SHELL_DIR="${1:-$HOME/openshell-src}"
IMAGE_TAG="${2:-offline-patched}"
OUT_TAR="${3:-${REPO_ROOT}/artifacts/full-offline-bundle-$(date +%Y%m%d)/openshell-cluster-${IMAGE_TAG}.tar}"
OPEN_SHELL_REPO="${OPEN_SHELL_REPO:-https://github.com/NVIDIA/OpenShell.git}"
SYNC_MAIN="${SYNC_MAIN:-1}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] command not found: $1"
    exit 1
  fi
}

require_cmd git
require_cmd docker

echo "[1/6] Prepare OpenShell source..."
if [[ ! -d "${OPEN_SHELL_DIR}/.git" ]]; then
  git clone "${OPEN_SHELL_REPO}" "${OPEN_SHELL_DIR}"
fi

if [[ "${SYNC_MAIN}" == "1" ]]; then
  git -C "${OPEN_SHELL_DIR}" fetch origin --prune
  git -C "${OPEN_SHELL_DIR}" checkout main
  git -C "${OPEN_SHELL_DIR}" pull --ff-only origin main
fi

echo "[2/6] Apply cluster-image offline override..."
cp -f \
  "${REPO_ROOT}/openshell-overrides/deploy/docker/cluster-entrypoint.sh" \
  "${OPEN_SHELL_DIR}/deploy/docker/cluster-entrypoint.sh"

# Some local worktrees may carry CRLF; normalize critical shell scripts used
# by the Docker build pipeline to avoid `^M` execution failures on Linux.
sed -i 's/\r$//' \
  "${OPEN_SHELL_DIR}/tasks/scripts/docker-build-image.sh" \
  "${OPEN_SHELL_DIR}/deploy/docker/cross-build.sh" \
  "${OPEN_SHELL_DIR}/deploy/docker/cluster-entrypoint.sh"

echo "[3/6] Build modified openshell cluster image..."
(
  cd "${OPEN_SHELL_DIR}"
  mkdir -p deploy/docker/.build/charts
  if command -v helm >/dev/null 2>&1; then
    helm package deploy/helm/openshell -d deploy/docker/.build/charts/ >/dev/null
  else
    docker run --rm \
      -v "${OPEN_SHELL_DIR}:/work" \
      -w /work \
      alpine/helm:3.17.3 \
      package deploy/helm/openshell -d deploy/docker/.build/charts/ >/dev/null
  fi

  docker buildx build \
    --load \
    -f deploy/docker/Dockerfile.images \
    --target cluster \
    -t "openshell/cluster:${IMAGE_TAG}" \
    --build-arg "CARGO_TARGET_CACHE_SCOPE=offline-patched" \
    --provenance=false \
    .
)

IMAGE_REF="openshell/cluster:${IMAGE_TAG}"

echo "[4/6] Verify image exists..."
docker image inspect "${IMAGE_REF}" >/dev/null

echo "[5/6] Export image tar..."
mkdir -p "$(dirname "${OUT_TAR}")"
docker save "${IMAGE_REF}" -o "${OUT_TAR}"

echo "[6/6] Done."
echo "Image: ${IMAGE_REF}"
echo "Tar:   ${OUT_TAR}"
