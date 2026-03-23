# NemoClaw 企业离线部署包（私有）

这个仓库用于在受限网络（尤其是公司内网）环境部署 NemoClaw，重点解决：
- 宿主机可联网，但 k3s 内部拉镜像失败
- Gateway / Sandbox 创建过程中因镜像拉取失败导致安装中断
- 需要可重复执行、可验证的“半离线/离线优先”流程

当前默认策略为“强制离线优先”：
- k3s 启动参数包含 `--disable-default-registry-endpoint`
- 启动脚本会校验离线包必须包含 `rancher/mirrored-pause:3.6`，缺失即失败

## 快速开始（Ubuntu）
1. 拉取仓库并下载 LFS 大文件
```bash
git clone https://github.com/Zac-Chen-2001/nemoclaw-.git
cd nemoclaw-
git lfs install
git lfs pull
```
2. 一键启动（公司建议端口 `8089`）
```bash
bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
```
3. 严格离线校验（推荐必须执行）
```bash
bash scripts/verify-k3s-offline-with-latest-nemoclaw.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
```
4. 业务向导
```bash
nemoclaw onboard
```

## 仓库结构与用途

### `artifacts/`
- `artifacts/offline-bundle-20260319/k3s-images.tar`
  - k3s 关键镜像离线包（Git LFS 管理），用于避免 k3s 在公司网络中在线拉取失败。

### `scripts/`
- `scripts/one-click-company-start.sh`
  - 公司环境推荐入口：安装/应用改造后的 OpenShell，并启动 gateway。
- `scripts/verify-k3s-offline-with-latest-nemoclaw.sh`
  - 严格离线验证：会检查镜像导入、封禁 cluster 容器外网并创建 sandbox，最终给出 PASS/FAIL。
- `scripts/install-modified-openshell.sh`
  - 仅负责安装改造版 OpenShell（将 `openshell-overrides/` 应用到 OpenShell 源码后构建安装）。
- `scripts/hybrid-start-nemoclaw.sh`
  - 混合启动脚本（更底层），支持显式传入 gateway 名称、端口、离线 tar 包路径。

### `openshell-overrides/`
- OpenShell 源码覆盖补丁（核心离线能力改造），用于让 k3s 优先/强制使用本地镜像而不是外网拉取。

### `docs/deployment/`
- `公司部署执行清单-zh.md`
  - 现场执行短清单，适合快速照抄。
- `openshell-nemoclaw-全链路与k3s离线策略-zh.md`
  - 原理文档，讲清楚 OpenShell / NemoClaw / k3s 的完整关系。
- `完整文件说明与执行手册-zh.md`
  - 详细手册，包含文件级说明与完整操作链路。
- `ubuntu-纯净环境一键部署-zh.md`
  - 新增：针对“公司纯净 Ubuntu”从 0 到 PASS 的一步步指令。

## 成功判据
- `verify-k3s-offline-with-latest-nemoclaw.sh` 输出：
  - `PASS: k3s offline path verified.`
- `openshell gateway info -g nemoclaw` 显示健康
- `nemoclaw onboard` 可继续完成向导
