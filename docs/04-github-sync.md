# GitHub 同步

推荐只把顶层编排仓库同步到 GitHub；NXP 完整源码由脚本按 tag 下载。

## SSH 方式

```bash
bash scripts/init_github_repo.sh
git remote add origin git@github.com:OWNER/imx6ull-nxp-bsp.git
git push -u origin main
```

## GitHub CLI 方式

```bash
bash scripts/init_github_repo.sh
gh auth status
gh repo create OWNER/imx6ull-nxp-bsp --public --source=. --remote=origin --push
```

## 每个阶段

```bash
bash scripts/export_patches.sh
git status
git add patches docs configs board scripts manifest

git commit -m "dts: add JJL board baseline"
git push
```
