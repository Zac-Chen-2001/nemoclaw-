# 公司环境部署执行清单（Linux）

## 1. 前置检查
- `docker`、`git`、`git-lfs`、`openshell` 已安装
- 端口冲突时用 `8089`

## 2. 拉取仓库
```bash
git clone https://github.com/Zac-Chen-2001/nemoclaw-.git
cd nemoclaw-
git lfs pull
```

## 3. 启动（推荐）
```bash
bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
```

## 4. 继续向导
```bash
nemoclaw onboard
```

上面的 one-click 脚本会自动：
- 拉取并更新 OpenShell 源码
- 覆盖 `openshell-overrides/` 中的离线改造文件
- 在 Docker 中编译并安装改造版 `openshell`
- 以混合离线方式启动 gateway

## 5. 严格验证（可选）
```bash
bash scripts/verify-k3s-offline-with-latest-nemoclaw.sh \
  nemoclaw \
  8089 \
  artifacts/offline-bundle-20260319/k3s-images.tar \
  /path/to/NemoClaw/Dockerfile
```
