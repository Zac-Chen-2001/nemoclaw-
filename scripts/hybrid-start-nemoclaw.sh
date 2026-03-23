#!/usr/bin/env bash
set -euo pipefail

# Hybrid mode:
# 1) Host pulls gateway/cluster image online.
# 2) k3s images are imported offline from local tar.

GATEWAY_NAME="${1:-nemoclaw}"
PORT="${2:-18080}"
K3S_TAR_PATH="${3:-./k3s-images.tar}"
CLUSTER_CONTAINER="openshell-cluster-${GATEWAY_NAME}"

if [[ ! -f "${K3S_TAR_PATH}" ]]; then
  echo "[ERROR] k3s image tar not found: ${K3S_TAR_PATH}"
  echo "Usage: $0 [gateway_name] [port] [k3s_images_tar_path]"
  exit 1
fi

# Docker bind mounts in openshell expect absolute host paths.
K3S_TAR_PATH="$(cd "$(dirname "${K3S_TAR_PATH}")" && pwd)/$(basename "${K3S_TAR_PATH}")"

echo "[1/6] Starting gateway '${GATEWAY_NAME}' on port ${PORT}..."
if openshell gateway start --help 2>/dev/null | grep -q -- "--k3s-image-tar"; then
  echo "Detected offline-preload capable openshell; passing k3s tar at gateway start."
  openshell gateway start --name "${GATEWAY_NAME}" --port "${PORT}" --k3s-image-tar "${K3S_TAR_PATH}" || true
else
  openshell gateway start --name "${GATEWAY_NAME}" --port "${PORT}" || true
fi
openshell gateway select "${GATEWAY_NAME}" || true

echo "[2/6] Waiting for cluster container..."
for _ in $(seq 1 30); do
  if docker ps -a --format '{{.Names}}' | grep -q "^${CLUSTER_CONTAINER}$"; then
    break
  fi
  sleep 1
done

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CLUSTER_CONTAINER}$"; then
  echo "[ERROR] Cluster container not found: ${CLUSTER_CONTAINER}"
  echo "Check gateway logs: openshell gateway info -g ${GATEWAY_NAME}"
  exit 1
fi

echo "[3/6] Ensuring cluster container is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CLUSTER_CONTAINER}$"; then
  docker start "${CLUSTER_CONTAINER}" >/dev/null
fi

echo "[4/6] Importing k3s images from ${K3S_TAR_PATH} ..."
if openshell gateway start --help 2>/dev/null | grep -q -- "--k3s-image-tar"; then
  echo "Skip manual import: k3s preload tar was provided during gateway startup."
else
  docker cp "${K3S_TAR_PATH}" "${CLUSTER_CONTAINER}:/tmp/k3s-images.tar"
  docker exec "${CLUSTER_CONTAINER}" sh -lc '
    set -e
    ctr -n k8s.io images import /tmp/k3s-images.tar
  '
fi

echo "[5/6] Quick verification..."
docker exec "${CLUSTER_CONTAINER}" sh -lc '
  set -e
  cnt="$(ctr -n k8s.io images ls -q | grep -v "^sha256:" | wc -l || true)"
  echo "k3s images available: ${cnt}"
'
openshell gateway info -g "${GATEWAY_NAME}" || true

echo "[6/6] Done."
echo "Next step: run 'nemoclaw onboard'"
echo "If UI is local, visit: http://127.0.0.1:18789/"
