# OpenShell + NemoClaw 全链路与 k3s 离线策略（中文）

## 三者关系
- `OpenShell`：负责 gateway/sandbox 生命周期。
- `NemoClaw`：业务插件和向导，调用 OpenShell CLI。
- `OpenClaw`：运行在 sandbox 内的 agent/UI 层。

你在公司环境碰到的核心故障点通常是 OpenShell 的 k3s 拉镜像路径，不是 NemoClaw 配置本身。

## 从 `nemoclaw onboard` 到 sandbox Ready 的链路
1. `nemoclaw onboard` 调用 `openshell gateway start`
2. k3s 在 cluster 容器启动并准备基础镜像
3. `--from Dockerfile` 时，镜像在宿主机构建后导入网关
4. k3s 创建 sandbox pod 并 Ready

## 我们采用的方案
- 宿主机可联网（允许构建和必要下载）
- k3s 侧离线（通过 `k3s-images.tar` 预载）

目标是先稳定通过 gateway/sandbox 创建，避免 k3s 内部拉镜像失败。

## 一键入口
```bash
bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
nemoclaw onboard
```

## 关键能力
- 改造版 OpenShell 支持 `--k3s-image-tar`
- 回退支持 `OPENSHELL_K3S_IMAGE_TARS`
- k3s 启动前预载基础镜像

## 实测结论（2026-03-22）
- 基线：NemoClaw latest `04012f7b301ebc6658ec005ef90ad85778c2dc8f`
- 动作：清缓存冷启动 -> 阻断 cluster 外网 -> 从 latest NemoClaw Dockerfile 创建 sandbox
- 结果：sandbox 仍成功 Ready

结论：k3s 离线路径可用，满足你公司环境的核心诉求。
