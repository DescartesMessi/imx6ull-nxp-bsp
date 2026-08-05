#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

if [[ ! -d .git ]]; then
  git init -b main
fi

git add .
git commit -m "chore: initialize reproducible i.MX6ULL NXP BSP project" || true

cat <<'MSG'
本地仓库已初始化。

方式 A（已安装并登录 GitHub CLI）：
  gh repo create OWNER/imx6ull-nxp-bsp --public --source=. --remote=origin --push

方式 B（先在 GitHub 创建空仓库，不要勾选 README/.gitignore/license）：
  git remote add origin git@github.com:OWNER/imx6ull-nxp-bsp.git
  git push -u origin main

不要把密码、Token、私钥、Wi-Fi 密码或设备密钥提交到仓库。
MSG
