#!/usr/bin/env bash
set -euo pipefail

GATEWAY_NAME="${1:-nemoclaw}"
PORT="${2:-8089}"
K3S_TAR_PATH="${3:-artifacts/offline-bundle-20260319/k3s-images.tar}"
NEMOCLAW_DOCKERFILE="${4:-/path/to/NemoClaw/Dockerfile}"
SANDBOX_NAME="offline-check-$(date +%H%M%S)"
CLUSTER_CONTAINER="openshell-cluster-${GATEWAY_NAME}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] command not found: $1"
    exit 1
  fi
}

require_cmd openshell
require_cmd docker

if [[ ! -f "${K3S_TAR_PATH}" ]]; then
  echo "[ERROR] k3s image tar not found: ${K3S_TAR_PATH}"
  exit 1
fi

if [[ ! -f "${NEMOCLAW_DOCKERFILE}" ]]; then
  echo "[ERROR] NemoClaw Dockerfile not found: ${NEMOCLAW_DOCKERFILE}"
  exit 1
fi

echo "[1/7] Cleanup old gateway state..."
openshell gateway destroy -g "${GATEWAY_NAME}" >/dev/null 2>&1 || true
openshell gateway stop -g "${GATEWAY_NAME}" >/dev/null 2>&1 || true
docker rm -f "${CLUSTER_CONTAINER}" >/dev/null 2>&1 || true
docker volume rm "openshell-volume-${GATEWAY_NAME}" >/dev/null 2>&1 || true

echo "[2/7] Start gateway with k3s preload tar..."
if openshell gateway start --help 2>/dev/null | grep -q -- "--k3s-image-tar"; then
  openshell gateway start --name "${GATEWAY_NAME}" --port "${PORT}" --recreate --k3s-image-tar "${K3S_TAR_PATH}"
else
  openshell gateway start --name "${GATEWAY_NAME}" --port "${PORT}" --recreate
  docker cp "${K3S_TAR_PATH}" "${CLUSTER_CONTAINER}:/tmp/k3s-images.tar"
  docker exec "${CLUSTER_CONTAINER}" sh -lc "ctr -n k8s.io images import /tmp/k3s-images.tar"
fi

echo "[3/7] Verify key k3s images exist..."
docker exec "${CLUSTER_CONTAINER}" sh -lc "crictl images | grep -E 'rancher/mirrored-pause|openshell/gateway|openshell-server|openshell-sandbox' || true"

echo "[4/7] Block cluster-container egress..."
docker exec "${CLUSTER_CONTAINER}" sh -lc '
  iptables -I OUTPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -I OUTPUT 2 -d 127.0.0.0/8 -j ACCEPT
  iptables -I OUTPUT 3 -d 10.0.0.0/8 -j ACCEPT
  iptables -I OUTPUT 4 -d 172.16.0.0/12 -j ACCEPT
  iptables -I OUTPUT 5 -d 192.168.0.0/16 -j ACCEPT
  iptables -I OUTPUT 6 -j REJECT
'

echo "[5/7] Create sandbox from latest NemoClaw Dockerfile..."
openshell sandbox create -g "${GATEWAY_NAME}" --name "${SANDBOX_NAME}" --from "${NEMOCLAW_DOCKERFILE}" --no-bootstrap -- echo READY

echo "[6/7] Sandbox status..."
openshell sandbox list -g "${GATEWAY_NAME}"

echo "[7/7] Cleanup sandbox..."
openshell sandbox delete -g "${GATEWAY_NAME}" "${SANDBOX_NAME}" >/dev/null 2>&1 || true

echo
echo "PASS: k3s offline path verified."
