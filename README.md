# nemoclaw- (private deploy bundle)

This repository is a deployment bundle for NemoClaw in restricted enterprise environments.

## Included
- `artifacts/offline-bundle-20260319/k3s-images.tar` (Git LFS)
- `scripts/hybrid-start-nemoclaw.sh`
- `scripts/verify-k3s-offline-with-latest-nemoclaw.sh`
- `scripts/install-modified-openshell.sh`
- `scripts/one-click-company-start.sh`
- `openshell-overrides/` (offline-capable OpenShell source overrides)
- deployment docs under `docs/deployment/`

## Recommended flow
1. `git lfs pull`
2. `bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar`
3. `nemoclaw onboard`
