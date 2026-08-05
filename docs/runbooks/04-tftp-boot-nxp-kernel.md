# Runbook 04：通过 TFTP 启动自主编译的 NXP Linux

## 目标

使用已经验证可工作的开发板 U-Boot，通过 TFTP 加载本项目自主编译的：

- Linux `zImage`
- NXP EVK eMMC DTB

根文件系统继续使用 eMMC 第二分区。

## 网络参数

| 设备 | 地址 |
|---|---|
| Ubuntu TFTP 服务器 | `192.168.31.218` |
| i.MX6ULL 开发板 | `192.168.31.50` |
| 子网掩码 | `255.255.255.0` |

## 部署文件

Ubuntu 上的部署目录：

```text
/home/pointer/linux/tftpboot/m0-nxp-official/
部署文件：
zImage-nxp-4.1.15
imx6ull-14x14-evk-emmc-m0.dtb


Ubuntu 部署命令
TFTP_M0="/home/pointer/linux/tftpboot/m0-nxp-official"

mkdir -p "$TFTP_M0"

cp -av \
    build/linux/arch/arm/boot/zImage \
    "$TFTP_M0/zImage-nxp-4.1.15"

cp -av \
    build/linux/arch/arm/boot/dts/imx6ull-14x14-evk-emmc.dtb \
    "$TFTP_M0/imx6ull-14x14-evk-emmc-m0.dtb"

U-Boot 网络参数
以下命令在开发板 U-Boot 提示符 => 中执行：
setenv ethaddr 02:11:22:33:44:50
setenv ipaddr 192.168.31.50
setenv serverip 192.168.31.218
setenv netmask 255.255.255.0

ping ${serverip}
所有参数仅在本次启动中生效。

TFTP 加载内核
tftp 0x80800000 m0-nxp-official/zImage-nxp-4.1.15

检查 zImage 魔数：
md.l 0x80800024 1

TFTP 加载设备树
tftp 0x83000000 m0-nxp-official/imx6ull-14x14-evk-emmc-m0.dtb
检查 DTB 魔数:
md.b 0x83000000 4

设置根文件系统
setenv bootargs 'console=ttymxc0,115200 root=PARTUUID=81b220c7-02 rootfstype=ext4 rootwait rw'

参数说明：

console=ttymxc0,115200：串口控制台。
root=PARTUUID=81b220c7-02：使用 eMMC 第二分区。
rootfstype=ext4：根文件系统格式为 ext4。
rootwait：等待 eMMC 初始化完成。
rw：以读写模式挂载根文件系统。

启动 Linux:
bootz 0x80800000 - 0x83000000

三个地址参数分别表示：

0x80800000    zImage 地址
-             不使用 initramfs
0x83000000    DTB 地址

Linux 启动后验证

以下命令在开发板 Linux Shell / # 中执行：
uname -a
cat /proc/version
cat /proc/cmdline

cat /proc/device-tree/model
echo

cat /proc/partitions
cat /proc/mounts | grep ' / '

重点确认 /proc/version 中包含：
bsp-builder@imx6ull-nxp-bsp

重点确认根文件系统已成功挂载：
VFS: Mounted root (ext4 filesystem)
