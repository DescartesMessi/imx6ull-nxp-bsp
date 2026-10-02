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

## 文档（全部含实测数据与测量口径）

| 文档 | 内容 |
|------|------|
| `docs/代码优化记录.md` | ① ~ ⑲ 逐条优化记录：启动链路 12.34s→5.05s、设备树与双网口、8 个板级驱动、CAN/UART3/USB、**GT9147 中断风暴（1480 次/秒 → 0）**、系统时间/RTC 等 |
| `docs/车载系统量化指标.md` | Qt 车载应用量化指标：启动 8.16s→4.98s、体积 -93%、内存 -60%、7 个页面 CPU/RSS、摄像头链路、推流 25fps/22.5Mbps、**各传感器驱动实测能力表** |
| `docs/简历条目与答辩要点.md` | 量化版简历条目 + 每个数字的口径 + 14 条高频追问回答 + 写作红线 |
| `docs/启动时间优化记录.md`、`docs/启动流程.md`、`docs/面试问答记录.md` | 启动链路实测、启动流程说明、网络/PHY 深度问答 |

## 调试与量化工具（`scripts/`）

| 工具 | 用途 | 实测产出 |
|------|------|----------|
| `serial_console.py` | 串口控制台：定时发送、抓取带时间戳的启动日志 | 整机启动 12.34s → 5.05s |
| `drv_rate.c` | 测字符设备固定时间内的最大读取速率 | DHT11 1 次/秒、SR04 20 次/秒、ICM20608 9280 次/秒 |
| `sensor_lat.c` | 测传感器单次 ioctl 阻塞时长 | DHT11 29.3ms/次 |
| `v4l2_enum.c` | 枚举摄像头真实支持的格式/分辨率/帧率 | 发现请求的 320×240 硬件不支持 |
| `touch_multi.c` | 统计多点触控点数与上报帧率 | 最大 5 点，约 20 帧/秒 |
| `fb_raw2png.py` | framebuffer 抓图转 PNG（本板字节序需交换 R/B） | 界面取证截图 |
| `settime.c` | 板上无 `date` applet 时设置/查看时间并写 RTC | 1970 → 当前时间，重启保持 |
| `vs_metrics_run.sh` | 一键：部署应用 → 自动巡检 7 个页面 → 通过 NFS 回收指标日志 | 各页面 CPU/RSS 表 |

交叉编译示例：`arm-linux-gnueabihf-gcc -static -O2 -o drv_rate scripts/drv_rate.c`

## 内核与驱动的改动（patch）

`sources/linux-imx` 是指向 NXP 官方仓库的 submodule（只读引用），本项目在其之上完成的
内核 / 设备树 / 驱动改动以补丁形式保存在 `patches/linux/`：

- `imx6ull-kernel-changes.patch`：板级设备树、defconfig、realtek PHY 驱动、
  `drivers/smarthome/` 系列驱动（含 **GT9147 触摸中断触发方式修复**：
  INT 低有效却按高电平触发申请中断，导致 1480 次/秒中断风暴、占 22~28% CPU）

应用方式：

```bash
cd sources/linux-imx
git apply ../../patches/linux/imx6ull-kernel-changes.patch
```
