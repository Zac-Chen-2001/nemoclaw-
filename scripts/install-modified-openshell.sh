#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPEN_SHELL_DIR="${1:-$HOME/openshell-src}"
OPEN_SHELL_REPO="${OPEN_SHELL_REPO:-https://github.com/NVIDIA/OpenShell.git}"

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

git -C "${OPEN_SHELL_DIR}" fetch origin --prune
git -C "${OPEN_SHELL_DIR}" checkout main
git -C "${OPEN_SHELL_DIR}" pull --ff-only origin main

echo "[2/6] Apply local offline overrides..."
for rel in \
  "crates/openshell-cli/src/main.rs" \
  "crates/openshell-cli/src/run.rs" \
  "crates/openshell-bootstrap/src/lib.rs" \
  "crates/openshell-bootstrap/src/docker.rs" \
  "deploy/docker/cluster-entrypoint.sh"
do
  cp -f "${REPO_ROOT}/openshell-overrides/${rel}" "${OPEN_SHELL_DIR}/${rel}"
done

echo "[3/6] Build openshell CLI in Docker..."
docker run --rm \
  -v "${OPEN_SHELL_DIR}:/work" \
  -w /work \
  rust:1.88-bookworm \
  bash -lc '
    set -euo pipefail
    source /usr/local/cargo/env
    rustup set profile minimal
    rustup default stable
    apt-get update
    apt-get install -y --no-install-recommends pkg-config libssl-dev clang
    cargo build -p openshell-cli --release
  '

echo "[4/6] Install modified openshell..."
mkdir -p "$HOME/.local/bin"
cp -f "${OPEN_SHELL_DIR}/target/release/openshell" "$HOME/.local/bin/openshell"
chmod +x "$HOME/.local/bin/openshell"

echo "[5/6] Verify feature flag..."
if ! "$HOME/.local/bin/openshell" gateway start --help | grep -q -- "--k3s-image-tar"; then
  echo "[ERROR] modified openshell verification failed: --k3s-image-tar not found"
  exit 1
fi

echo "[6/6] Done."
echo "Installed: $HOME/.local/bin/openshell"
echo "Version: $("$HOME/.local/bin/openshell" --version)"
