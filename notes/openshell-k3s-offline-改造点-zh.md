# OpenShell 改造点（k3s 离线）

核心目标：让 k3s 启动和 sandbox 创建阶段不依赖外网拉取关键基础镜像。

## 改造方向
- `openshell gateway start` 增加 `--k3s-image-tar`
- 部署参数透传到 bootstrap/docker
- cluster 容器通过环境变量接收 tar 列表
- entrypoint 在 k3s 启动前预载 tar
- 支持环境变量回退：`OPENSHELL_K3S_IMAGE_TARS`

## 结果
在公司网络受限场景中，可显著降低 `pause`/`namespace not ready` 类故障。
