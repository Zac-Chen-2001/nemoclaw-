#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE_TAG="$(date +%Y%m%d)"
OUT_DIR="${1:-${REPO_ROOT}/artifacts/full-offline-bundle-${DATE_TAG}}"
DOCKERFILE_PATH="${2:-}"

mkdir -p "${OUT_DIR}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] command not found: $1"
    exit 1
  fi
}

require_cmd docker
require_cmd sort
require_cmd awk
require_cmd sed

TMP_LIST="$(mktemp)"
trap 'rm -f "${TMP_LIST}"' EXIT

cat > "${TMP_LIST}" <<'EOF'
rancher/mirrored-pause:3.6
rancher/mirrored-metrics-server:v0.8.1
rancher/local-path-provisioner:v0.0.34
rancher/klipper-helm:v0.9.14-build20260210
rancher/mirrored-library-busybox:1.37.0
registry.k8s.io/agent-sandbox/agent-sandbox-controller:v0.1.0
ghcr.io/nvidia/openshell/gateway:0.0.10
ghcr.io/nvidia/openshell/gateway:dev
ghcr.io/nvidia/openshell-community/sandboxes/base:latest
EOF

if [[ -n "${DOCKERFILE_PATH}" ]]; then
  if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
    echo "[ERROR] Dockerfile not found: ${DOCKERFILE_PATH}"
    exit 1
  fi
  echo "[+] Extracting FROM images from ${DOCKERFILE_PATH}"
  awk 'toupper($1)=="FROM"{print $2}' "${DOCKERFILE_PATH}" \
    | sed 's/\r$//' \
    | sed 's/[[:space:]]*#.*$//' \
    | sed '/^$/d' \
    | grep -E '^[[:alnum:]./_-]+(:[[:alnum:]._-]+)?$' \
    | grep -vE '^(scratch|urllib\.parse)$' >> "${TMP_LIST}"
fi

IMAGE_LIST="${OUT_DIR}/full-images.txt"
sort -u "${TMP_LIST}" > "${IMAGE_LIST}"

echo "[+] Image list:"
cat "${IMAGE_LIST}"

echo "[+] Pull images..."
while IFS= read -r image; do
  [[ -z "${image}" ]] && continue
  echo "  - docker pull ${image}"
  docker pull "${image}"
done < "${IMAGE_LIST}"

OUT_TAR="${OUT_DIR}/full-images.tar"
echo "[+] Saving offline tar: ${OUT_TAR}"
docker save $(cat "${IMAGE_LIST}") -o "${OUT_TAR}"

echo "[+] Done."
echo "Bundle dir: ${OUT_DIR}"
echo "Tar file:   ${OUT_TAR}"
