# NemoClaw 离线部署完整文件说明与执行手册（中文）

> 适用仓库：`https://github.com/Zac-Chen-2001/nemoclaw-.git`  
> 当前基线：`main`（建议始终 `git pull` 到最新）

## 1. 目标与范围
本手册解决的问题是：
- 公司网络下，`k3s` 在 gateway/sandbox 创建时容易拉镜像失败；
- 希望“一条命令”完成 OpenShell 改造版安装 + gateway 启动；
- 保留 NemoClaw 官方链路（最终仍执行 `nemoclaw onboard`）。

## 2. 一步步执行流程（建议照抄）
## 2.1 拉取仓库
```bash
git clone https://github.com/Zac-Chen-2001/nemoclaw-.git
cd nemoclaw-
git lfs pull
```

## 2.2 一键准备 OpenShell + 启动网关
```bash
bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
```

## 2.3 继续 NemoClaw 官方向导
```bash
nemoclaw onboard
```

## 2.4 可选：严格离线验证
```bash
bash scripts/verify-k3s-offline-with-latest-nemoclaw.sh \
  nemoclaw \
  8089 \
  artifacts/offline-bundle-20260319/k3s-images.tar \
  /path/to/NemoClaw/Dockerfile
```

## 3. 验收标准
- `openshell status -g nemoclaw` 显示 `Connected`
- `openshell sandbox create ...` 可创建并到 `Ready`
- `nemoclaw onboard` 能继续执行，不再卡在 k3s 基础镜像拉取阶段

## 4. 全部文件清单与内容说明
以下按目录说明“每个文件做什么 + 核心内容”。

### 4.1 根目录
#### `.gitattributes`
- 作用：把大文件 `artifacts/**/*.tar` 交给 Git LFS。
- 关键内容：
  - `artifacts/**/*.tar filter=lfs diff=lfs merge=lfs -text`

#### `README.md`
- 作用：给出仓库用途和最短使用路径。
- 核心信息：推荐使用 `scripts/one-click-company-start.sh`。

### 4.2 scripts（执行入口）
#### `scripts/one-click-company-start.sh`
- 作用：一键总入口。
- 行为：
  1. 调用 `install-modified-openshell.sh`
  2. 调用 `hybrid-start-nemoclaw.sh`
  3. 提示下一步 `nemoclaw onboard`

#### `scripts/install-modified-openshell.sh`
- 作用：自动构建并安装改造版 OpenShell。
- 行为：
  1. 拉/更新 `NVIDIA/OpenShell` 源码
  2. 用 `openshell-overrides/` 覆盖 5 个改造文件
  3. 在 `rust:1.88-bookworm` 容器内编译 `openshell-cli`
  4. 安装到 `~/.local/bin/openshell`
  5. 校验 `--k3s-image-tar` 参数存在

#### `scripts/hybrid-start-nemoclaw.sh`
- 作用：启动 gateway 并确保 k3s 镜像可用。
- 行为：
  1. 检测 openshell 是否支持 `--k3s-image-tar`
  2. 支持时：启动时直接传 tar 预载
  3. 不支持时：回退到手工 `ctr import`
  4. 打印镜像数量和 gateway 信息
- 已修复点：
  - 自动把 tar 路径转绝对路径，避免 Docker volume name 报错

#### `scripts/verify-k3s-offline-with-latest-nemoclaw.sh`
- 作用：严格验证 k3s 离线路径是否成立。
- 行为：
  1. 清理旧 gateway/容器
  2. 启动并预载 k3s tar
  3. 在 cluster 容器内添加 `iptables OUTPUT REJECT`
  4. 用 latest NemoClaw Dockerfile 创建 sandbox
  5. sandbox `Ready` 即判定通过

### 4.3 openshell-overrides（OpenShell 改造源码）
#### `openshell-overrides/crates/openshell-cli/src/main.rs`
- 作用：CLI 参数层改造。
- 关键改动：新增 `--k3s-image-tar` 参数定义与解析。

#### `openshell-overrides/crates/openshell-cli/src/run.rs`
- 作用：CLI -> deploy 逻辑透传。
- 关键改动：将 `k3s_image_tars` 透传到 `DeployOptions`。

#### `openshell-overrides/crates/openshell-bootstrap/src/lib.rs`
- 作用：部署参数模型扩展。
- 关键改动：`DeployOptions` 增加 `k3s_image_tars` 字段与 builder。

#### `openshell-overrides/crates/openshell-bootstrap/src/docker.rs`
- 作用：cluster 容器创建与环境注入。
- 关键改动：
  - 挂载 tar 到 cluster 容器
  - 注入 `K3S_PRELOAD_IMAGE_TARS`
  - 增加 `OPENSHELL_K3S_IMAGE_TARS` 回退

#### `openshell-overrides/deploy/docker/cluster-entrypoint.sh`
- 作用：k3s 启动前初始化逻辑。
- 关键改动：预加载 tar 到 k3s 自动导入目录，降低 k3s 在线拉取依赖。

### 4.4 artifacts（离线镜像与清单）
#### `artifacts/offline-bundle-20260319/k3s-images.tar`
- 作用：k3s 基础镜像离线包。
- 大小：`164,968,448` bytes（约 `158M`）。

#### `artifacts/offline-bundle-20260319/k3s-images.txt`
- 作用：核心镜像清单（精简集）。
- 典型包含：
  - `rancher/mirrored-pause:3.6`
  - `rancher/mirrored-coredns-coredns`
  - `openshell/gateway`

#### `artifacts/offline-bundle-20260319/k3s-images-all.txt`
- 作用：更完整的镜像列表（用于核对）。

#### `artifacts/offline-bundle-20260319/import-on-server.sh`
- 作用：早期手工导入脚本模板。
- 注意：该脚本包含 `host-images.tar` 路径，当前仓库默认不再提供该大文件，仅作参考。

### 4.5 docs 与 notes
#### `docs/deployment/公司部署执行清单-zh.md`
- 作用：现场执行清单（短版）。

#### `docs/deployment/openshell-nemoclaw-全链路与k3s离线策略-zh.md`
- 作用：链路原理说明（中版）。

#### `notes/openshell-k3s-offline-改造点-zh.md`
- 作用：OpenShell 改造摘要（技术对照）。

## 5. 为什么能解决你的公司问题
- 问题本质：k3s 容器内网络常常无法稳定拉取基础镜像（`pause` 等）。
- 方案核心：把基础镜像提前放到本地 tar，并在 k3s 启动前预载。
- 结果：即使外网环境差，k3s 关键阶段也不依赖实时拉取。

## 6. 常见错误与处理
### 6.1 `includes invalid characters for a local volume name`
- 原因：传了相对 tar 路径。
- 处理：已在脚本内自动转绝对路径（新版本无需手动修复）。

### 6.2 `git clone` 长时间无响应
- 常见原因：
  - 私有仓库凭证等待（非交互环境）
  - LFS 大文件下载慢
- 建议：
  - 先确认凭证可用（PAT/SSH）
  - 再执行 `git lfs pull`

### 6.3 `openshell: command not found`
- 先安装 OpenShell 或先运行 `one-click-company-start.sh`（它会构建并安装）。

## 7. 建议的公司侧最短命令
```bash
git clone https://github.com/Zac-Chen-2001/nemoclaw-.git
cd nemoclaw-
git lfs pull
bash scripts/one-click-company-start.sh nemoclaw 8089 artifacts/offline-bundle-20260319/k3s-images.tar
nemoclaw onboard
```
