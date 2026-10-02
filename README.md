# i.MX6ULL BSP 与板级驱动开发

面向正点原子 i.MX6ULL V2.8（eMMC 版）的板级支持包：从 U-Boot 到 Qt 应用的完整嵌入式 Linux 平台，
覆盖**启动链路、设备树、板级驱动、交叉编译体系**，全部指标均在实机测得并记录了测量口径。

[![Platform](https://img.shields.io/badge/Platform-i.MX6ULL-orange)]()
[![Kernel](https://img.shields.io/badge/Linux-4.1.15-green)]()
[![Bootloader](https://img.shields.io/badge/U--Boot-2016.03-blue)]()
[![Toolchain](https://img.shields.io/badge/GCC-arm--linux--gnueabihf--4.9.4-yellow)]()
[![Rootfs](https://img.shields.io/badge/Rootfs-BusyBox%20%2B%20eMMC-lightgrey)]()

## 📌 项目简介

本仓库提供一条可复现的 i.MX6ULL 板级开发链路：

```
U-Boot  →  Linux Kernel + Device Tree  →  BusyBox 根文件系统  →  Qt 5.12.9 应用
```

- **启动**：U-Boot 环境配置、内核/DTB 编译烧录、NFS 与 eMMC 两种根文件系统启动
- **设备树**：LCD、触摸、双网口、CAN、UART、USB、I2C/SPI 传感器节点的引脚复用与资源描述
- **驱动**：GT9147（触摸）、DHT11、ICM20608、AP3216C、SR04、SR501、蜂鸣器、背光按键共 8 个
- **工具链**：Qt / ALSA-Lib / libjpeg-turbo / MJPG-streamer / MPlayer 的交叉编译与 sysroot 部署
- **量化**：每个优化都有实机数据、对照组与测量口径，记录在 `docs/` 下

## ✨ 项目亮点（实测数据）

| 方向 | 结果 |
|------|------|
| **启动链路** | 整机启动（U-Boot banner → 控制台就绪）**12.34s → 5.05s，缩短 59.1%** |
| **设备树** | 973 行板级 DTS、39 个 pinctrl 引脚组；启动告警 **3 条 → 0** |
| **有线网络** | 双网口（内部双 MAC + RTL8201F PHY）全部可用，**TCP 吞吐 91.7 Mbps（线速 91.8%）**，MAC 地址不冲突 |
| **板级驱动** | 8 个驱动：ICM20608 经 SPI 8MHz **读取 9280 次/秒**、SR04 测距 **49.7ms/次（20 次/秒）**、DHT11 **1 次/秒**（协议上限）、SR501 中断事件驱动 |
| **显示与输入** | 800×480 LCD（32bpp，单帧 1.5MB，800×480p-60）+ GT9147 **五点触控**（I2C 100kHz + 下降沿中断） |
| **性能定位** | 触摸中断风暴：**中断 1480 次/秒 → 0、中断线程 CPU 22~28% → 0、空闲系统 CPU 30% → 9%** |
| **总线与外设** | CAN **500kbps 回环 0 错误**、UART3 回环 **9600/115200 通过**、USB 驱动补齐后**启动报错清零** |
| **系统时间** | **1970 → 当前时间**（自研 `settime` + 时区），重启由 SNVS RTC 保持 |

## 🏗️ 系统分层

```
┌─────────────────── 应用层 ───────────────────┐
│  Qt 5.12.9（LinuxFB）/ 板载设备测试程序       │
├──────────────── 设备节点 / 子系统 ───────────┤
│  /dev/fb0  /dev/input/event*  /dev/video1    │
│  /dev/dht11 /dev/icm20608 /dev/ap3216c       │
│  /dev/sr04 /dev/sr501 /dev/beep_device       │
├─────────────────── 内核 ─────────────────────┤
│  字符设备驱动 · Input 子系统 · V4L2 · 网络栈  │
├─────────────────── 平台 ─────────────────────┤
│  设备树：pinctrl / I2C / SPI / GPIO / 中断    │
├─────────────────── 引导 ─────────────────────┤
│  U-Boot → zImage + DTB → BusyBox Rootfs(eMMC)│
└──────────────────────────────────────────────┘
```

## 📁 目录结构

```
imx6ull-nxp-bsp/
├── sources/            # 源码（linux-imx / uboot-imx / busybox / 第三方库，均为 submodule）
├── scripts/            # 编译脚本 + 调试与量化工具
├── build/              # 编译中间产物（已 gitignore）
├── deploy/
│   ├── nfs/rootfs/     # NFS 根文件系统（含 Qt、驱动测试程序、板端配置）
│   └── tftp/           # zImage / dtb
├── patches/            # 内核与驱动改动补丁
└── docs/               # 优化记录、量化指标、面试问答、简历要点
```

## 🚀 快速开始

### 1. 编译

```bash
# 基础平台
bash scripts/build_uboot.sh
bash scripts/build_kernel.sh
bash scripts/build_busybox.sh
bash scripts/create_rootfs.sh

# 第三方库（按需）
bash scripts/build_QT_full.sh
bash scripts/build_alsa_lib.sh
bash scripts/build_alsa_utils.sh
bash scripts/build_libjpeg_turbo.sh
bash scripts/build_mjpg_streamer.sh
bash scripts/build_mplayer.sh
```

### 2. 启动方式

**NFS 根文件系统（开发阶段）**

```bash
setenv bootargs 'console=tty0 console=ttymxc0,115200n8 root=/dev/nfs rw init=/linuxrc \
nfsroot=192.168.31.218:/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/deploy/nfs/rootfs,v3,tcp,nolock \
ip=192.168.31.50:192.168.31.218:192.168.31.1:255.255.255.0::eth0:off ipv6.disable=1'
setenv bootcmd 'tftp 80800000 zImage; tftp 83000000 imx6ull-alientek-jjl.dtb; bootz 80800000 - 83000000'
saveenv
```

**eMMC 本地根文件系统（当前默认）**

```bash
setenv bootargs 'console=tty0 console=ttymxc0,115200n8 root=/dev/mmcblk1p2 rootwait rw ipv6.disable=1'
setenv bootcmd 'fatload mmc 1:1 80800000 zImage; fatload mmc 1:1 83000000 imx6ull-alientek-jjl.dtb; bootz 80800000 - 83000000'
saveenv
```

## 📊 实测指标（节选）

| 场景 | 指标 | 数值 |
|------|------|------|
| 整机启动 | U-Boot banner → 控制台就绪 | 12.34s → **5.05s** |
| 双网口 | iperf3 TCP 吞吐 | **91.7 Mbps** |
| ICM20608 | SPI 8MHz 单帧读取速率 | **9280 次/秒**（0.1ms/次） |
| SR04 | 超声测距周期 | **49.7ms/次（20 次/秒）** |
| DHT11 | 采样率（协议上限 1Hz） | **0.9~1.1 次/秒** |
| GT9147 | 同时触点数 / 上报帧率 | **5 点 / ~20 帧/秒** |
| 触摸中断 | 空闲 / 活动 | **0 次/秒 / ~186 次/秒** |
| CAN | can0 回环收发 | **500kbps，0 错误** |

完整口径与测量方法见 [`docs/代码优化记录.md`](docs/代码优化记录.md)。

## 📚 文档索引

| 文档 | 内容 |
|------|------|
| [`docs/代码优化记录.md`](docs/代码优化记录.md) | ①~⑲ 逐条优化记录：启动链路、设备树与双网口、驱动协议层、CAN/UART3/USB、中断风暴、系统时间等，每条含实测数据与口径 |
| [`docs/车载系统量化指标.md`](docs/车载系统量化指标.md) | 上层 Qt 车载应用的量化指标与传感器驱动能力表 |
| [`docs/简历条目与答辩要点.md`](docs/简历条目与答辩要点.md) | 量化版简历条目 + 每个数字的口径 + 高频追问回答 |
| [`docs/启动时间优化记录.md`](docs/启动时间优化记录.md) | 启动各阶段耗时实测 |
| [`docs/启动流程.md`](docs/启动流程.md) | U-Boot → 内核 → 根文件系统 的完整启动流程说明 |
| [`docs/面试问答记录.md`](docs/面试问答记录.md) | 网络 / PHY 等深度问答 |

## 🧰 调试与量化工具

| 工具 | 用途 | 典型产出 |
|------|------|----------|
| [`scripts/serial_console.py`](scripts/serial_console.py) | 串口控制台：定时发送、抓取带时间戳的启动日志 | 启动 12.34s → 5.05s |
| [`scripts/drv_rate.c`](scripts/drv_rate.c) | 测字符设备固定时间内的最大读取速率 | DHT11 1 次/秒、SR04 20 次/秒、ICM20608 9280 次/秒 |
| [`scripts/sensor_lat.c`](scripts/sensor_lat.c) | 测传感器单次 ioctl 阻塞时长 | DHT11 29.3ms/次 |
| [`scripts/v4l2_enum.c`](scripts/v4l2_enum.c) | 枚举摄像头真实支持的格式 / 分辨率 / 帧率 | 定位"请求 320×240 但硬件不支持" |
| [`scripts/touch_multi.c`](scripts/touch_multi.c) | 统计多点触控点数与上报帧率 | 最大 5 点、约 20 帧/秒 |
| [`scripts/fb_raw2png.py`](scripts/fb_raw2png.py) | framebuffer 抓图转 PNG（本板字节序需交换 R/B） | 界面取证截图 |
| [`scripts/settime.c`](scripts/settime.c) | 板上无 `date` applet 时设置 / 查看时间并写 RTC | 1970 → 当前时间，重启保持 |
| [`scripts/vs_metrics_run.sh`](scripts/vs_metrics_run.sh) | 一键：部署应用 → 自动巡检 → 回收指标日志 | 各页面 CPU/RSS 表 |

交叉编译示例：

```bash
arm-linux-gnueabihf-gcc -static -O2 -o drv_rate scripts/drv_rate.c
```

## 🩹 内核与驱动改动

`sources/linux-imx` 是指向 NXP 官方仓库的 submodule（作为只读基线），本项目在其之上完成的
内核 / 设备树 / 驱动改动以补丁形式保存在 [`patches/linux/`](patches/linux/)：

- `imx6ull-kernel-changes.patch`：板级设备树、defconfig、realtek PHY 驱动、
  `drivers/smarthome/` 系列驱动（含 **GT9147 触摸中断触发方式修复**：
  INT 引脚低有效却按"高电平触发"申请中断，导致 1480 次/秒中断风暴、占用 22~28% CPU）

应用方式：

```bash
cd sources/linux-imx
git apply ../../patches/linux/imx6ull-kernel-changes.patch
```

## ⚠️ 已知限制

- RS232 / RS485 / GPS 共用 UART3：**控制器回环已验证，物理层待接对端或回环插头验证**
- CAN 只验证到控制器回环收发，**实总线通信需要第二个 CAN 节点**才能完成 ACK
- 板上无 RTC 后备电池，**完全断电后时间会丢失**，需重新校时（NTP 或串口下发）
- 摄像头不支持 320×240，实际按 640×480 采集，预览丢帧 20~28%（改进方向见量化文档）

## 🙏 致谢

- NXP 官方 [`linux-imx`](https://github.com/nxp-imx/linux-imx)、`uboot-imx`
- 正点原子 ALPHA i.MX6ULL 开发板资料
