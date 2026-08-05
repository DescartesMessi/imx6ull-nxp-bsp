# i.MX6ULL BSP 项目文档

## Runbooks

按照执行顺序排列：

1. NXP 源码归档导入
2. NXP U-Boot 官方基线构建
3. NXP Linux 官方基线构建
4. [通过 TFTP 启动自主编译的 NXP Linux](runbooks/04-tftp-boot-nxp-kernel.md)

## Milestones

- M0-A：NXP 原版源码导入与版本锁定
- M0-B：NXP 官方 U-Boot 和 Linux 零修改构建
- [M0-C：自主编译 NXP Linux 实机启动](milestones/M0-C-official-kernel-board-boot.md)

## 文档分类

```text
runbooks/
    可直接复现的命令与步骤

milestones/
    已完成阶段的结果和验收标准

troubleshooting/
    错误、原因、排查过程和解决方法

decisions/
    重要架构决策及其理由