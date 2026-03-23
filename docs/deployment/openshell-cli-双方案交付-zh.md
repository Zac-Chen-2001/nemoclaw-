# OpenShell CLI 双方案交付（公司 Ubuntu）

目标：同时准备两套可落地方案，避免现场卡住。

## A 方案：预编译二进制（最快）
- 适用：公司机器与本机架构一致（常见 `x86_64`）。
- 优点：无需现场编译，直接拷贝可用。

## B 方案：源码兜底（最稳）
- 适用：二进制不兼容或现场需要重编译。
- 优点：不依赖你本机编译产物，现场可重新构建。

## 一键打包（本机执行）
```bash
bash scripts/package-openshell-cli-dual-kit.sh
```

产物目录示例：
- `artifacts/cli-dual-kit-YYYYMMDD/openshell-binary-kit.tar.gz`
- `artifacts/cli-dual-kit-YYYYMMDD/openshell-source-kit.tar.gz`
- `artifacts/cli-dual-kit-YYYYMMDD/README-quickstart.txt`

## 现场使用（公司机）

### 先试 A（快）
```bash
tar -xzf openshell-binary-kit.tar.gz
mkdir -p ~/.local/bin
cp openshell ~/.local/bin/openshell
chmod +x ~/.local/bin/openshell
export PATH="$HOME/.local/bin:$PATH"
openshell gateway start --help | grep k3s-image-tar
```

### A 不通就切 B（稳）
```bash
tar -xzf openshell-source-kit.tar.gz
bash install-modified-openshell.sh /path/to/openshell-src
openshell gateway start --help | grep k3s-image-tar
```

## 成功判据
- `which openshell` 指向 `~/.local/bin/openshell`
- `openshell gateway start --help` 含 `--k3s-image-tar`
