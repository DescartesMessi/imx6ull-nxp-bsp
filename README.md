# i.MX6ULL NXP Official BSP Project

面向 i.MX6ULL（512 MiB DDR3L、8 GiB eMMC）开发板的可复现 BSP 工程。

## 原则

1. NXP 官方 U-Boot/Linux 源码保持可追溯，不直接把生成物提交到 Git。
2. 板级修改通过独立分支与 patch series 管理。
3. U-Boot、Kernel、DTB、RootFS 分阶段替换，每一步保留可启动基线。
4. `sources/`、`build/`、`deploy/` 不进入主仓库；GitHub 保存脚本、配置、补丁、文档和测试记录。

## 快速开始

```bash
cp manifest/sources.env.example manifest/sources.env
bash scripts/check_host.sh
bash scripts/bootstrap_sources.sh
bash scripts/build_uboot.sh
bash scripts/build_kernel.sh
```

## 目录

- `manifest/`：官方仓库、tag、工具链和锁定提交。
- `scripts/`：下载、编译、部署、导出补丁脚本。
- `configs/`：可复现 defconfig 与 BusyBox 配置。
- `board/imx6ull-jjl/`：板级源码、DTS、RootFS overlay。
- `patches/`：相对 NXP tag 的 U-Boot/Linux patch series。
- `docs/`：架构、里程碑、调试记录。
- `artifacts/`：只放校验清单或 release 索引，不提交大二进制。

## 里程碑

- M0：官方源码/tag 可复现下载。
- M1：官方 EVK U-Boot 编译成功。
- M2：移植自有板卡 U-Boot，SD 启动成功。
- M3：官方 Linux/DTB 编译成功。
- M4：自有板卡 DTS，eMMC RootFS 启动成功。
- M5：BusyBox RootFS + NFS 启动。
- M6：双网口、固定 MAC、LCD、音频、I2C/SPI/CAN/RS485。
- M7：A/B 升级、恢复、产测与文档。


docs/runbooks/
    从零开始复现某项操作的完整指令

docs/milestones/
    记录阶段目标、验收结果和遗留问题

docs/troubleshooting/
    记录错误现象、原因和解决方案

docs/decisions/
    记录为什么选择某种架构、分支或配置

artifacts/
    保存校验值、构建摘要和精简后的测试结果