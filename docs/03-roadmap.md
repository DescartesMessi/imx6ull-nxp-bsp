# 开发路线

1. 固定 NXP 官方 tag 与工具链。
2. 编译官方 EVK U-Boot/Kernel，建立“零修改可复现”基线。
3. 新建 JJL 板级 U-Boot 目录与 defconfig。
4. 完成 DDR、串口、MMC/eMMC、单网口启动。
5. 新建 JJL DTS，启动自编译 Kernel。
6. 构建 BusyBox RootFS，先 NFS 后 eMMC。
7. 双网口、固定 MAC、PHY 地址与 reset GPIO。
8. LCD/触摸、I2C、SPI、CAN、RS485、音频。
9. A/B 分区、升级回滚、恢复模式。
10. 产测脚本、CI、Release 与求职文档。
