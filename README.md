# i.MX6ULL NXP Official BSP Project
针对正点原子imx6ull v2.8（emmc版本）设计的板级支持包，通过Uboot-->linux内核、dtb设备树-->rootfs根文件系统全路径，并且完善了板级设备驱动(编译进内核)；让你的开发板不在是砖；包含 U-Boot、LinuxKernel、设备树、BusyBox、RootFS、Qt5、ALSA 和 MPlayer 等组件的构建脚本。

## 快速开始
在开始之前，你需要在你的Ubuntu设备上安装好tftp与nfs，这里/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/nfs/rootfs是nfs文件夹，/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/tftp是tftp传输的文件夹；
首先你可以直接通过正点原子的imxdownload文件下载Uboot到SD卡中，在通过emmc启动Uboot，之后设置Uboot变量；你就可以启动开发板，/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/nfs/rootfs/usr/local/bin路径下面是各个板载设备驱动的测试文件
```bash
setenv bootargs 'console=tty0 console=ttymxc0,115200n8 root=/dev/nfs rw init=/linuxrc nfsroot=192.168.31.218:/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/nfs/rootfs,v3,tcp,nolock ip=192.168.31.50:192.168.31.218:192.168.31.1:255.255.255.0::eth0:off ipv6.disable=1'
setenv bootcmd 'tftp 80800000 zImage; tftp 83000000 imx6ull-alientek-jjl.dtb; bootz 80800000 - 83000000'
saveenv 
run bootcmd
```

## 目录

- `/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources`：源码文件，Uboot、LInux、第三方库源码文件；基于源码文件进行修改；
- `/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/scripts`：编译脚本文件
- `/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/docs`：等待完善的项目文件
- `/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/build`：编译中间产物；

## 编译顺序
```bash
bash scripts/build_uboot.sh
bash scripts/build_kernel.sh
bash scripts/build_busybox.sh
bash scripts/create_rootfs.sh

编译 Qt5、ALSA 和 MPlayer：
bash scripts/build_QT_full.sh
bash scripts/build_alsa_lib.sh
bash scripts/build_alsa_utils.sh
bash scripts/build_mplayer.sh
```
## Linux 内核和设备树
内核默认配置：imx6ull_alientek_jjl_defconfig
常用输出文件：zImage\imx6ull-alientek-jjl.dtb
主机 NFS RootFS：/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/nfs/rootfs
开发板网络参数示例：开发板 IP：192.168.31.50
Ubuntu IP：192.168.31.218
网关：192.168.31.1
U-Boot NFS 启动参数：setenv bootargs 'console=tty0 console=ttymxc0,115200n8 root=/dev/nfs rw init=/linuxrc nfsroot=192.168.31.218:/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/nfs/rootfs,v3,tcp,nolock ip=192.168.31.50:192.168.31.218:192.168.31.1:255.255.255.0::eth0:off ipv6.disable=1'
TFTP 启动命令：setenv bootcmd 'tftp 80800000 zImage; tftp 83000000 imx6ull-alientek-jjl.dtb; bootz 80800000 - 83000000'
saveenv
