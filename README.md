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

## Docs
- `docs/deployment/公司部署执行清单-zh.md`（短版执行清单）
- `docs/deployment/openshell-nemoclaw-全链路与k3s离线策略-zh.md`（链路原理）
- `docs/deployment/完整文件说明与执行手册-zh.md`（详细版，含逐文件说明）

## Recommended flow
1. `git lfs pull`
2. `bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar`
3. `nemoclaw onboard`
