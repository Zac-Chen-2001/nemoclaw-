#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${REPO_ROOT}/artifacts/cli-dual-kit-$(date +%Y%m%d)}"
CLI_BIN_SRC="${2:-$HOME/.local/bin/openshell}"
OPEN_SHELL_DIR="${3:-$HOME/openshell-src}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] command not found: $1"
    exit 1
  fi
}

require_cmd tar
require_cmd sha256sum
require_cmd uname

mkdir -p "${OUT_DIR}"
BIN_DIR="${OUT_DIR}/binary-kit"
SRC_DIR="${OUT_DIR}/source-kit"
mkdir -p "${BIN_DIR}" "${SRC_DIR}"

echo "[1/5] Package binary kit..."
if [[ ! -f "${CLI_BIN_SRC}" ]]; then
  echo "[ERROR] openshell binary not found: ${CLI_BIN_SRC}"
  echo "Build/install modified openshell first."
  exit 1
fi

cp -f "${CLI_BIN_SRC}" "${BIN_DIR}/openshell"
chmod +x "${BIN_DIR}/openshell"

{
  echo "arch=$(uname -m)"
  echo "kernel=$(uname -sr)"
  echo "sha256=$(sha256sum "${BIN_DIR}/openshell" | awk '{print $1}')"
} > "${BIN_DIR}/openshell-binary-info.txt"

tar -C "${BIN_DIR}" -czf "${OUT_DIR}/openshell-binary-kit.tar.gz" .

echo "[2/5] Package source fallback kit..."
cp -f "${REPO_ROOT}/scripts/install-modified-openshell.sh" "${SRC_DIR}/install-modified-openshell.sh"
cp -f "${REPO_ROOT}/scripts/build-modified-openshell-cluster-image.sh" "${SRC_DIR}/build-modified-openshell-cluster-image.sh"
cp -f "${REPO_ROOT}/scripts/package-full-offline-images.sh" "${SRC_DIR}/package-full-offline-images.sh"
mkdir -p "${SRC_DIR}/openshell-overrides"
cp -rf "${REPO_ROOT}/openshell-overrides/"* "${SRC_DIR}/openshell-overrides/"

if [[ -d "${OPEN_SHELL_DIR}/.git" ]]; then
  git -C "${OPEN_SHELL_DIR}" rev-parse HEAD > "${SRC_DIR}/openshell-source-commit.txt" || true
fi

tar -C "${SRC_DIR}" -czf "${OUT_DIR}/openshell-source-kit.tar.gz" .

echo "[3/5] Write quickstart..."
cat > "${OUT_DIR}/README-quickstart.txt" <<EOF
[Binary kit - fast]
1) tar -xzf openshell-binary-kit.tar.gz
2) mkdir -p ~/.local/bin
3) cp openshell ~/.local/bin/openshell && chmod +x ~/.local/bin/openshell
4) export PATH="\$HOME/.local/bin:\$PATH"
5) openshell gateway start --help | grep k3s-image-tar

[Source kit - fallback]
1) tar -xzf openshell-source-kit.tar.gz
2) bash install-modified-openshell.sh /path/to/openshell-src
3) openshell gateway start --help | grep k3s-image-tar
EOF

echo "[4/5] Done."
echo "Output dir: ${OUT_DIR}"
echo "Binary kit: ${OUT_DIR}/openshell-binary-kit.tar.gz"
echo "Source kit: ${OUT_DIR}/openshell-source-kit.tar.gz"

echo "[5/5] Summary"
ls -lh "${OUT_DIR}"
