# Git 工作流

## 分支

- `main`：顶层工程稳定状态。
- `develop`：阶段集成。
- `feat/uboot-board-port`
- `feat/linux-board-dts`
- `feat/rootfs-busybox`
- `feat/dual-ethernet`
- `feat/ota-ab`

U-Boot/Linux 源码树内部：

- `upstream` remote 指向 NXP 官方仓库。
- `board/imx6ull-jjl` 从固定 NXP tag 创建。
- 每个功能使用短生命周期 feature branch，完成后合并回板级分支。

## 提交规范

- `build:` 构建系统
- `uboot:` U-Boot 板级修改
- `kernel:` 内核通用修改
- `dts:` 设备树
- `rootfs:` 根文件系统
- `net:` 网络
- `docs:` 文档
- `test:` 测试与验收

示例：

```text
dts: add dual FEC PHY nodes for i.MX6ULL JJL board
```
