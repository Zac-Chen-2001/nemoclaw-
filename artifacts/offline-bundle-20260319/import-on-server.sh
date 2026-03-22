#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
GATEWAY_NAME="${1:-nemoclaw}"
CLUSTER_CONTAINER="openshell-cluster-${GATEWAY_NAME}"

echo "[1/5] Load host images"
docker load -i "${BUNDLE_DIR}/host-images.tar"

echo "[2/5] Start gateway"
openshell gateway start --name "${GATEWAY_NAME}" || true

echo "[3/5] Ensure cluster container is running"
if ! docker ps --format '{{.Names}}' | grep -q "^${CLUSTER_CONTAINER}$"; then
  docker start "${CLUSTER_CONTAINER}" >/dev/null
fi

echo "[4/5] Import k3s images into cluster containerd"
docker cp "${BUNDLE_DIR}/k3s-images.tar" "${CLUSTER_CONTAINER}:/tmp/k3s-images.tar"
docker exec "${CLUSTER_CONTAINER}" sh -lc '
  ctr -n k8s.io images import /tmp/k3s-images.tar
  ctr -n k8s.io images ls -q | grep -v "^sha256:" | sort -u | head -n 20
'

echo "[5/5] Done"
echo "Run next: nemoclaw onboard"
