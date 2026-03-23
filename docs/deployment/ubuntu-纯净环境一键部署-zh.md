# Ubuntu 纯净环境一键部署（公司实战版）

本文目标：在一台“纯净 Ubuntu Linux 服务器”上，尽量一次完成 NemoClaw 部署，并验证 k3s 路径可离线运行。

## 1. 适用前提

- 系统：Ubuntu（建议 22.04 / 24.04）
- 账号：具备 `sudo` 权限
- 已安装或可安装：`docker`、`git`、`git-lfs`、`bash`
- 公司 8080 可能占用，统一使用 `8089`

## 2. 一次执行脚本（推荐）

将下面内容保存为 `run-company-offline.sh`，然后执行：

```bash
chmod +x run-company-offline.sh
bash run-company-offline.sh
```

脚本内容：

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===== 可改参数 =====
REPO_URL="https://github.com/Zac-Chen-2001/nemoclaw-.git"
WORKDIR="${HOME}/nemoclaw-offline-run"
GATEWAY_NAME="nemoclaw"
PORT="8089"
K3S_TAR_REL="artifacts/offline-bundle-20260319/k3s-images.tar"

echo "[0/10] Preflight..."
command -v docker >/dev/null || { echo "[ERR] docker 未安装"; exit 1; }
command -v git >/dev/null || { echo "[ERR] git 未安装"; exit 1; }
if ! command -v git-lfs >/dev/null; then
  echo "[WARN] 未检测到 git-lfs，尝试安装（Debian/Ubuntu）..."
  if command -v apt-get >/dev/null; then
    sudo apt-get update && sudo apt-get install -y git-lfs
  else
    echo "[ERR] 请先手动安装 git-lfs"; exit 1
  fi
fi

echo "[1/10] 启动 Docker..."
sudo systemctl enable --now docker || true
docker version >/dev/null

echo "[2/10] 检查端口 ${PORT}..."
if ss -ltn | awk '{print $4}' | grep -q ":${PORT}$"; then
  echo "[ERR] 端口 ${PORT} 已占用，请换端口"; exit 1
fi

echo "[3/10] 准备工作目录..."
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "[4/10] 拉代码..."
git clone "${REPO_URL}" repo
cd repo

echo "[5/10] 拉 LFS 大文件..."
git lfs install
git lfs pull

echo "[6/10] 校验离线包..."
K3S_TAR="${PWD}/${K3S_TAR_REL}"
[[ -f "${K3S_TAR}" ]] || { echo "[ERR] 找不到 ${K3S_TAR_REL}"; exit 1; }
SIZE=$(stat -c%s "${K3S_TAR}" 2>/dev/null || stat -f%z "${K3S_TAR}")
if [[ "${SIZE}" -lt 50000000 ]]; then
  echo "[ERR] k3s-images.tar 体积异常（可能是 LFS 指针）: ${SIZE} bytes"; exit 1
fi
echo "[OK] k3s-images.tar size=${SIZE} bytes"

echo "[7/10] 一键启动网关（离线k3s方案）..."
bash scripts/one-click-company-start.sh "${GATEWAY_NAME}" "${PORT}" "${K3S_TAR_REL}"

echo "[8/10] 严格离线验证..."
bash scripts/verify-k3s-offline-with-latest-nemoclaw.sh "${GATEWAY_NAME}" "${PORT}" "${K3S_TAR_REL}"

echo "[9/10] 网关状态..."
openshell gateway info -g "${GATEWAY_NAME}" || true

echo "[10/10] 下一步：运行 nemo 向导"
echo "命令: nemoclaw onboard"
echo "注意: 向导里端口保持 ${PORT}"
```

## 3. 成功判据（必须满足）

- 离线验证脚本最终输出：
  - `PASS: k3s offline path verified.`
- `openshell gateway info -g nemoclaw` 显示网关健康
- `nemoclaw onboard` 能继续并完成向导

补充自检（建议执行）：
```bash
docker exec openshell-cluster-nemoclaw sh -lc "ctr -n k8s.io images ls | grep -E 'mirrored-pause|rancher/mirrored-pause' || true"
```
如果没有任何输出，说明离线包里缺少 `pause` 镜像引用，后续可能触发在线拉取。

## 4. 现场高频问题与处理

### 问题 A：`git: 'lfs' is not a git command`

处理：
```bash
sudo apt-get update
sudo apt-get install -y git-lfs
git lfs install
git lfs pull
```

### 问题 B：`openshell: command not found`

处理：
- 说明改造版 OpenShell 未安装成功，重跑：
```bash
bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
```

### 问题 C：UI 打不开 / 连接拒绝

处理：
```bash
openshell gateway info -g nemoclaw
openshell gateway logs -g nemoclaw --follow
docker ps -a
```

## 5. 安全提醒

- API Key 不要写入仓库，现场输入即可。
- 你曾在聊天中粘贴过密钥，建议在控制台旋转新 key 后再去公司部署。
