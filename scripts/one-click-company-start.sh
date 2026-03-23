#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEWAY_NAME="${1:-nemoclaw}"
PORT="${2:-8089}"
K3S_TAR_PATH="${3:-${REPO_ROOT}/artifacts/offline-bundle-20260319/k3s-images.tar}"
OPEN_SHELL_DIR="${4:-$HOME/openshell-src}"

if [[ "${K3S_TAR_PATH}" != /* ]]; then
  K3S_TAR_PATH="${REPO_ROOT}/${K3S_TAR_PATH}"
fi

if [[ ! -f "${K3S_TAR_PATH}" ]]; then
  echo "[ERROR] k3s image tar not found: ${K3S_TAR_PATH}"
  echo "Run from repo root or pass an absolute tar path."
  exit 1
fi

echo "[A] Install modified OpenShell..."
"${REPO_ROOT}/scripts/install-modified-openshell.sh" "${OPEN_SHELL_DIR}"

echo "[B] Start gateway with hybrid offline strategy..."
"${REPO_ROOT}/scripts/hybrid-start-nemoclaw.sh" "${GATEWAY_NAME}" "${PORT}" "${K3S_TAR_PATH}"

echo
echo "Next step:"
echo "  nemoclaw onboard"
