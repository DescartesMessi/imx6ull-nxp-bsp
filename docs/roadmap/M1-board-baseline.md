# M1：正点原子 i.MX6ULL 板级基础平台闭环

## 1. 阶段定位

本项目的最终目标不是让 Linux 内核“能够启动”，而是以正点原子 i.MX6ULL 开发板为硬件平台，建立一套可持续维护、可重复构建、可升级、可恢复、可测试的软件平台。

最终平台需要实现：

- 从源码编译并维护 U-Boot；
- 从源码编译并维护 Linux 内核；
- 自主维护板级设备树；
- 使用 Buildroot 构建根文件系统；
- 支持 SD 卡和 eMMC 启动；
- 支持网络、USB、存储、LCD、触摸等基础外设；
- 支持 A/B 系统升级；
- 支持升级失败自动回滚；
- 支持硬件看门狗和异常恢复；
- 提供板级测试、日志采集和故障诊断工具；
- 支持版本锁定、构建追踪、产物校验和发布管理。

M0 阶段已经完成了 NXP 官方源码的导入、锁定、编译和实机启动验证。

M1 阶段的任务是从“NXP EVK 官方基线”过渡到“正点原子 i.MX6ULL 自主板级基线”。

---

## 2. 当前项目状态

### 2.1 已完成内容

- [x] 建立顶层 GitHub 工程仓库；
- [x] 导入 NXP U-Boot 官方源码；
- [x] 导入 NXP Linux 官方源码；
- [x] 锁定 BSP 版本：
  - `rel_imx_4.1.15_2.1.0_ga`
- [x] 锁定 U-Boot 版本：
  - `U-Boot 2016.03`
- [x] 锁定 Linux 版本：
  - `Linux 4.1.15`
- [x] 锁定交叉编译工具链：
  - `Linaro GCC 4.9.4`
- [x] 完成 U-Boot 源码外构建；
- [x] 完成 Linux 源码外构建；
- [x] 生成：
  - `u-boot.bin`
  - `u-boot.imx`
  - `zImage`
  - `imx6ull-14x14-evk-emmc.dtb`
  - Linux 内核模块
- [x] 使用已有可靠 U-Boot，通过 TFTP 启动自主编译的 Linux；
- [x] 成功识别 SD 卡和板载 eMMC；
- [x] 成功挂载 eMMC 第二分区作为根文件系统；
- [x] 成功进入 Linux Shell；
- [x] 确认运行内核构建身份：

```text
bsp-builder@imx6ull-nxp-bsp
```

### 2.2 当前仍依赖的外部内容

当前实机启动链仍然存在以下临时依赖：

```text
已有开发板 U-Boot
        ↓
自主编译 NXP Linux
        ↓
NXP 官方 EVK 设备树
        ↓
原厂或旧系统 RootFS
```

因此当前系统还不能称为自主维护的板级软件平台。

### 2.3 当前主要问题

- U-Boot 仍不是本项目维护的正点原子板级版本；
- Linux 仍使用 NXP EVK 设备树；
- RootFS 仍使用旧系统已有根文件系统；
- 当前启动方式主要依赖手工 U-Boot 命令；
- 尚未建立标准 SD 卡和 eMMC 镜像；
- 尚未定义面向 A/B 升级的分区布局；
- 尚未形成板级外设验收矩阵；
- 尚未建立统一的板级诊断工具。

---

## 3. M1 阶段总目标

M1 阶段完成后，应形成第一版自主维护的正点原子 i.MX6ULL 板级基础系统：

```text
本项目维护的 U-Boot
        ↓
本项目维护的设备树
        ↓
本项目编译的 Linux
        ↓
本项目生成的 Buildroot RootFS
        ↓
从 SD 卡或 eMMC 启动
        ↓
进入可诊断、可测试的用户空间
```

M1 的目标版本定义为：

```text
Board Platform Baseline v0.1
```

M1 重点解决以下问题：

1. 板级硬件描述由本项目维护；
2. U-Boot 和 Linux 使用统一的板级名称；
3. RootFS 不再依赖旧厂商系统；
4. 建立标准构建、部署和启动流程；
5. 为后续 A/B 升级、回滚、恢复和量产测试预留架构。

---

## 4. M1 阶段范围

M1 分为以下八个子阶段：

```text
M1-A  产品启动架构和存储布局设计
M1-B  板级硬件资源清单
M1-C  正点原子 Linux DTS 基线
M1-D  正点原子 U-Boot 板级基线
M1-E  Buildroot 最小根文件系统
M1-F  SD 卡启动闭环
M1-G  eMMC 启动闭环
M1-H  板级诊断和验收框架
```

---

# 5. M1-A：产品启动架构和存储布局设计

## 5.1 目标

在继续修改 U-Boot、设备树和根文件系统之前，先明确整个产品平台的启动契约。

本阶段不立即实现完整 A/B 升级，但必须提前为 A/B 系统保留合理的存储和启动架构，避免后续重新设计整个分区系统。

## 5.2 需要定义的启动链

目标启动链：

```text
i.MX6ULL Boot ROM
        ↓
U-Boot
        ↓
读取启动状态
        ↓
选择系统槽位 A 或 B
        ↓
加载对应 Kernel、DTB 和 RootFS
        ↓
Linux 启动
        ↓
用户空间确认系统健康状态
```

M1 暂时只启用单系统启动，但 U-Boot 环境变量和分区命名不得与未来 A/B 架构冲突。

## 5.3 建议的逻辑分区模型

最终 eMMC 逻辑布局预留如下：

| 区域 | 用途 | M1 状态 |
|---|---|---|
| Bootloader | U-Boot 启动镜像 | 启用 |
| Environment Primary | U-Boot 主环境区 | 预留 |
| Environment Redundant | U-Boot 冗余环境区 | 预留 |
| Boot A | A 槽 Kernel 和 DTB | 启用或预留 |
| Boot B | B 槽 Kernel 和 DTB | 预留 |
| RootFS A | A 槽根文件系统 | 启用 |
| RootFS B | B 槽根文件系统 | 预留 |
| Recovery | 恢复系统 | 预留 |
| Data | 持久化用户和设备数据 | 预留或启用 |
| Logs | 升级、启动和故障日志 | 可合并至 Data |

M1 不立即确定所有分区的最终大小。

最终分区大小需要根据以下实测结果确定：

- U-Boot 镜像大小；
- Kernel 最大预留空间；
- DTB 和 Overlay 空间；
- Buildroot RootFS 实际大小；
- 恢复系统大小；
- 日志增长策略；
- 未来应用程序空间；
- eMMC 擦写和升级冗余需求。

## 5.4 启动命名规范

统一采用以下板级名称：

```text
项目板级 ID：
imx6ull-jjl

硬件显示名称：
ALIENTEK i.MX6ULL Development Board

Linux DTS：
imx6ull-jjl-emmc.dts

Linux DTB：
imx6ull-jjl-emmc.dtb

U-Boot defconfig：
mx6ull_jjl_emmc_defconfig

Buildroot defconfig：
imx6ull_jjl_defconfig
```

暂时保留 `jjl` 作为工程内部板级 ID，避免已有目录和脚本大规模重命名。

## 5.5 交付物

- [ ] `docs/architecture/boot-flow.md`
- [ ] `docs/architecture/storage-layout.md`
- [ ] `docs/architecture/board-naming.md`
- [ ] `docs/decisions/ADR-0002-ab-ready-storage-layout.md`
- [ ] 初始分区布局草案
- [ ] U-Boot 启动变量命名草案

## 5.6 验收标准

- [ ] 明确 Boot ROM 到用户空间的完整启动链；
- [ ] 明确 SD 卡和 eMMC 的启动职责；
- [ ] 分区模型能够兼容未来 A/B 系统；
- [ ] 板级命名在 U-Boot、Linux、Buildroot 和脚本之间保持一致；
- [ ] 不再使用含义模糊的 EVK 文件名作为最终产物名。

---

# 6. M1-B：板级硬件资源清单

## 6.1 目标

建立正点原子 i.MX6ULL 开发板的唯一硬件事实来源。

不能长期依赖以下方式维护硬件：

- 只查看厂商 DTS；
- 只参考旧 U-Boot 代码；
- 只根据启动日志猜测；
- 在不同文档中重复记录 GPIO 和引脚；
- 每次开发驱动时重新查原理图。

## 6.2 建立硬件资源矩阵

创建：

```text
board/imx6ull-jjl/hardware/
```

建议文件：

```text
board/imx6ull-jjl/hardware/
├── board-summary.md
├── pinmux-matrix.csv
├── gpio-matrix.csv
├── clock-matrix.md
├── regulator-matrix.md
├── peripheral-matrix.md
├── storage-layout.md
└── source-references.md
```

## 6.3 外设资源清单

至少整理以下内容：

### 核心硬件

- CPU 型号；
- i.MX6ULL 封装类型；
- DDR 型号和容量；
- eMMC 型号和容量；
- SD 卡控制器；
- 启动拨码或启动模式；
- 调试串口；
- 系统时钟源；
- 电源树。

### 网络

- ENET1 MAC；
- ENET2 MAC；
- PHY 型号；
- PHY 地址；
- MDIO/MDC；
- PHY 复位 GPIO；
- PHY 电源控制；
- RMII 时钟方向；
- 网口 LED。

### USB

- USB OTG；
- USB Host；
- VBUS 控制；
- ID 引脚；
- 过流检测；
- USB Hub。

### 显示和输入

- LCDIF 数据引脚；
- LCD 分辨率；
- Pixel Clock；
- DE、HSYNC、VSYNC；
- 背光 PWM；
- LCD 电源；
- 触摸控制器；
- 触摸中断 GPIO；
- 触摸复位 GPIO。

### I2C

- I2C 控制器编号；
- AP3216C；
- 触摸控制器；
- 音频 Codec；
- 摄像头或其他传感器；
- 各设备地址。

### SPI

- ECSPI 控制器；
- ICM20608；
- SPI Flash；
- 片选 GPIO；
- SPI mode；
- 最大时钟频率。

### 其他外设

- CAN；
- RS485；
- RS232；
- 蜂鸣器；
- LED；
- 按键；
- RTC；
- Watchdog；
- Audio；
- Camera。

## 6.4 信息来源优先级

硬件信息按以下优先级确认：

```text
1. 正点原子开发板原理图
2. 芯片 Datasheet
3. 正点原子已验证的板级源码
4. NXP 官方 EVK 源码
5. 实机测量和启动日志
```

厂商源码仅作为硬件参考，不直接作为本项目源码基线。

## 6.5 交付物

- [ ] 完整外设资源矩阵；
- [ ] GPIO 和 pinmux 对照表；
- [ ] PHY 地址和复位逻辑记录；
- [ ] SD/eMMC 控制器对应关系；
- [ ] LCD 和触摸硬件参数；
- [ ] 所有信息来源记录。

## 6.6 验收标准

- [ ] 每个板级外设都能定位到对应 SoC 控制器；
- [ ] 每个 GPIO 都记录 bank、index、方向、有效电平和功能；
- [ ] 每个 I2C/SPI 设备都记录总线号和地址；
- [ ] Linux DTS 和 U-Boot 板级代码均以该矩阵为依据。

---

# 7. M1-C：正点原子 Linux DTS 基线

## 7.1 目标

创建本项目自主维护的：

```text
imx6ull-jjl-emmc.dts
```

不再把 NXP EVK DTS 作为最终板级设备树。

## 7.2 移植原则

采用增量式设备树移植：

```text
NXP 官方 imx6ull.dtsi
        ↓
NXP EVK DTS 作为结构参考
        +
正点原子旧 DTS 作为硬件参考
        ↓
创建本项目专用 DTS
        ↓
逐类外设验证
```

禁止一次性将旧厂商 DTS 全部复制到 NXP 源码中。

原因：

- 难以确认每一项配置的来源；
- 难以判断旧代码是否包含临时修复；
- 难以定位启动故障；
- Git 补丁缺少可审查性；
- 不利于后续升级内核。

## 7.3 DTS 迭代顺序

### M1-C1：DTS 骨架

第一版只包含：

- model；
- compatible；
- memory；
- chosen；
- debug UART；
- SD；
- eMMC；
- 必需 regulator；
- 必需 pinctrl。

验收重点：

```text
/proc/device-tree/model
```

必须显示本项目板级名称。

### M1-C2：存储和控制台

验证：

- UART 控制台；
- SD 卡；
- eMMC；
- 分区识别；
- RootFS 挂载；
- devtmpfs；
- reboot。

### M1-C3：网络基础

优先适配一个主网口：

- FEC；
- PHY 地址；
- PHY reset GPIO；
- MDIO；
- RMII；
- MAC 地址来源；
- DHCP；
- Ping；
- TFTP；
- NFS RootFS。

第一个网口稳定后再启用第二个网口。

### M1-C4：USB 基础

验证：

- USB Host；
- U 盘；
- USB Hub；
- USB 键鼠；
- USB OTG 角色；
- VBUS 控制。

### M1-C5：关闭无关 EVK 节点

删除或禁用实际板卡不存在的设备：

- EVK QSPI；
- EVK 传感器；
- EVK 音频节点；
- 不存在的 regulator；
- 不存在的 display 节点；
- 无效 GPIO。

## 7.4 Linux 源码文件

预计新增或修改：

```text
sources/linux-imx/arch/arm/boot/dts/imx6ull-jjl-emmc.dts
sources/linux-imx/arch/arm/boot/dts/Makefile
```

必要时可以增加板级公共 `.dtsi`：

```text
imx6ull-jjl.dtsi
imx6ull-jjl-emmc.dts
```

推荐结构：

```text
imx6ull.dtsi
        ↓
imx6ull-jjl.dtsi
        ↓
imx6ull-jjl-emmc.dts
```

这样未来可以扩展：

```text
imx6ull-jjl-sd.dts
imx6ull-jjl-recovery.dts
imx6ull-jjl-factory.dts
```

## 7.5 Linux Git 策略

Linux 源码仓库使用独立分支：

```text
nxp-baseline
    └── board/imx6ull-jjl
            └── feat/jjl-dts-base
```

每类修改单独提交：

```text
dts: add JJL board skeleton
dts: enable debug UART and eMMC
dts: enable primary Ethernet
dts: enable USB host
dts: disable unused EVK peripherals
```

完成后导出补丁：

```bash
git -C sources/linux-imx \
    format-patch \
    nxp-baseline..HEAD \
    -o patches/linux
```

顶层 GitHub 仓库提交补丁，而不是提交完整 Linux 源码。

## 7.6 交付物

- [ ] `imx6ull-jjl.dtsi`
- [ ] `imx6ull-jjl-emmc.dts`
- [ ] DTS Makefile 入口；
- [ ] Linux patch series；
- [ ] DTS 编译脚本；
- [ ] TFTP 部署脚本；
- [ ] 实机启动日志；
- [ ] DTS 节点验收表。

## 7.7 验收标准

- [ ] DTB 能正常编译；
- [ ] `/proc/device-tree/model` 显示正点原子/JJL；
- [ ] 串口控制台正常；
- [ ] SD 卡正常；
- [ ] eMMC 正常；
- [ ] eMMC RootFS 正常挂载；
- [ ] 至少一个网口正常；
- [ ] USB Host 能识别 U 盘；
- [ ] 无明显 EVK 无关设备探测错误；
- [ ] Linux 源码修改已经形成可重放补丁。

---

# 8. M1-D：正点原子 U-Boot 板级基线

## 8.1 目标

创建本项目自主维护的 U-Boot 板级目标：

```text
mx6ull_jjl_emmc_defconfig
```

最终不再依赖厂商预编译或历史 U-Boot。

## 8.2 板级代码范围

预计建立：

```text
board/alientek/mx6ull_jjl/
├── Kconfig
├── Makefile
├── imximage.cfg
└── mx6ull_jjl.c
```

以及：

```text
include/configs/mx6ull_jjl.h
configs/mx6ull_jjl_emmc_defconfig
```

实际目录命名根据当前 NXP U-Boot 版本的 Kconfig 和板级组织方式确定。

## 8.3 首轮功能范围

首轮 U-Boot 只要求：

- DDR 初始化；
- UART 调试输出；
- eMMC；
- SD 卡；
- 环境变量；
- 倒计时；
- `mmc` 命令；
- `fatload` 或 `ext4load`；
- `bootz`；
- 一个可工作的网口；
- `ping`；
- `tftp`；
- `dhcp`；
- reset；
- watchdog 基础支持。

## 8.4 启动变量设计

避免直接把所有逻辑写入单个 `bootcmd`。

推荐拆分：

```text
load_kernel
load_fdt
set_bootargs
boot_from_mmc
boot_from_sd
boot_from_net
boot_recovery
select_slot
```

M1 暂时使用单槽启动：

```text
active_slot=A
upgrade_available=0
bootcount=0
bootlimit=3
```

这些变量先预留，为后续 A/B 和自动回滚提供兼容接口。

## 8.5 U-Boot 环境存储

需要明确：

- 环境位于 eMMC 用户区还是 boot 分区；
- 主环境偏移；
- 冗余环境偏移；
- 环境大小；
- 擦除块和对齐要求；
- 环境损坏时默认行为；
- 环境恢复命令。

M1 至少需要支持冗余环境设计，即使暂时只启用主环境。

## 8.6 U-Boot Git 策略

U-Boot 源码仓库使用：

```text
nxp-baseline
    └── board/imx6ull-jjl
            └── feat/jjl-board-port
```

提交粒度建议：

```text
uboot: add JJL board target
uboot: add JJL DDR configuration
uboot: enable eMMC and SD
uboot: enable primary Ethernet
uboot: add board boot environment
```

完成后导出：

```bash
git -C sources/uboot-imx \
    format-patch \
    nxp-baseline..HEAD \
    -o patches/uboot
```

## 8.7 交付物

- [ ] `mx6ull_jjl_emmc_defconfig`
- [ ] JJL 板级目录；
- [ ] JJL DDR 配置；
- [ ] SD/eMMC 初始化；
- [ ] 网络初始化；
- [ ] 标准启动环境；
- [ ] U-Boot patch series；
- [ ] U-Boot 实机日志；
- [ ] U-Boot 命令验收表。

## 8.8 验收标准

- [ ] 本项目 U-Boot 能在目标板上输出串口日志；
- [ ] DDR 容量识别正确；
- [ ] SD 卡识别正确；
- [ ] eMMC 识别正确；
- [ ] 一个网口能够 Ping 和 TFTP；
- [ ] 能加载本项目 Kernel 和 DTB；
- [ ] 能启动 Buildroot RootFS；
- [ ] 环境变量恢复默认值后仍可启动；
- [ ] U-Boot 修改已导出为可重放补丁。

---

# 9. M1-E：Buildroot 最小根文件系统

## 9.1 目标

停止使用原有厂商根文件系统，建立本项目自己的用户空间。

Buildroot 版本必须在项目中锁定，不能使用不确定的滚动版本。

版本选择完成后记录：

- 官方源码地址；
- Git tag 或归档版本；
- SHA-256；
- 本地基线提交；
- 工具链模式；
- libc 类型；
- BusyBox 配置。

## 9.2 第一版 RootFS 范围

第一版 Buildroot RootFS 只包含必要功能：

- BusyBox；
- init；
- devtmpfs；
- procfs；
- sysfs；
- tmpfs；
- mdev 或 udev；
- serial getty；
- mount；
- dmesg；
- ip；
- ping；
- udhcpc；
- ethtool；
- wget；
- dropbear SSH；
- ext4 工具；
- e2fsck；
- fdisk 或 sfdisk；
- mmc-utils；
- USB 存储支持；
- watchdog 工具；
- 日志工具；
- 板级信息脚本。

## 9.3 文件系统格式

M1 至少生成：

```text
rootfs.tar
rootfs.ext4
```

可选生成：

```text
rootfs.cpio.gz
```

用途：

| 文件 | 用途 |
|---|---|
| `rootfs.tar` | 解压部署、NFS RootFS |
| `rootfs.ext4` | SD/eMMC 分区镜像 |
| `rootfs.cpio.gz` | initramfs 或恢复系统原型 |

## 9.4 Overlay 目录

建立：

```text
board/imx6ull-jjl/rootfs-overlay/
├── etc/
│   ├── hostname
│   ├── issue
│   ├── profile
│   └── init.d/
├── usr/bin/
│   ├── board-info
│   ├── board-selftest
│   └── collect-diagnostics
└── var/
```

## 9.5 系统身份

系统必须能够输出：

```text
Project: imx6ull-nxp-bsp
Board: imx6ull-jjl
Release: <version>
Build ID: <git commit>
Kernel: <kernel version>
RootFS: <buildroot version>
Active slot: A
Boot reason: normal
```

## 9.6 交付物

- [ ] Buildroot 源码版本锁定；
- [ ] `configs/buildroot/imx6ull_jjl_defconfig`；
- [ ] BusyBox 配置；
- [ ] RootFS overlay；
- [ ] `rootfs.tar`；
- [ ] `rootfs.ext4`；
- [ ] RootFS SHA-256；
- [ ] Buildroot 构建信息；
- [ ] RootFS 部署 Runbook。

## 9.7 验收标准

- [ ] 不依赖原厂 RootFS；
- [ ] 正常执行 `/sbin/init`；
- [ ] 串口登录正常；
- [ ] `/dev`、`/proc`、`/sys` 正常；
- [ ] 网络能够获取地址；
- [ ] SSH 能够登录；
- [ ] eMMC 和 SD 工具可用；
- [ ] watchdog 用户空间工具可用；
- [ ] 系统版本信息可追踪。

---

# 10. M1-F：SD 卡启动闭环

## 10.1 目标

生成可以直接写入 SD 卡的完整镜像。

目标产物：

```text
imx6ull-jjl-sdcard.img
```

镜像应包含：

- U-Boot；
- Boot 分区；
- Kernel；
- DTB；
- RootFS；
- 分区表；
- 版本信息；
- SHA-256。

## 10.2 启动模式

至少支持以下一种标准方式：

```text
SD Boot ROM
    ↓
SD U-Boot
    ↓
SD Boot Partition
    ↓
SD RootFS
```

同时保留以下测试方式：

```text
SD U-Boot
    ↓
TFTP Kernel/DTB
    ↓
NFS RootFS
```

## 10.3 自动化脚本

建立：

```text
scripts/image/create_sd_image.sh
scripts/deploy/flash_sd_image.sh
scripts/test/verify_sd_image.sh
```

脚本必须具备：

- 目标设备检查；
- 防止误写系统磁盘；
- 分区创建；
- 文件系统格式化；
- 文件复制；
- `sync`；
- SHA-256；
- 写入结果验证。

## 10.4 验收标准

- [ ] 一条命令生成 SD 卡镜像；
- [ ] 镜像写入后能够独立启动；
- [ ] 不依赖 TFTP；
- [ ] 不依赖旧 RootFS；
- [ ] U-Boot、Kernel、DTB、RootFS 均来自本项目；
- [ ] 镜像可以通过校验值验证。

---

# 11. M1-G：eMMC 启动闭环

## 11.1 目标

通过 SD 卡或网络启动维护系统，将完整软件平台安装到板载 eMMC。

## 11.2 安装流程

建议流程：

```text
从 SD 卡启动安装系统
        ↓
检查目标板身份
        ↓
检查 eMMC 型号和容量
        ↓
备份旧分区信息
        ↓
创建新分区表
        ↓
写入 U-Boot
        ↓
写入 Boot 分区
        ↓
写入 RootFS A
        ↓
预留 RootFS B 和 Recovery
        ↓
写入版本元数据
        ↓
校验所有镜像
        ↓
重启并从 eMMC 启动
```

## 11.3 安全要求

eMMC 安装脚本必须：

- 明确要求目标设备路径；
- 检查设备是否为 eMMC；
- 显示设备容量；
- 检查当前根文件系统是否位于目标设备；
- 禁止擦除正在运行的根文件系统；
- 提供 `--dry-run`；
- 提供二次确认；
- 记录写入日志；
- 写后重新读取校验；
- 失败时停止后续操作。

## 11.4 交付物

- [ ] eMMC 分区脚本；
- [ ] eMMC 安装脚本；
- [ ] eMMC 校验脚本；
- [ ] eMMC 恢复脚本；
- [ ] eMMC 安装日志格式；
- [ ] eMMC 启动 Runbook。

## 11.5 验收标准

- [ ] eMMC 可独立启动；
- [ ] 不插入 SD 卡也可进入系统；
- [ ] Kernel、DTB 和 RootFS 均来自本项目；
- [ ] 安装脚本具有防误操作机制；
- [ ] 预留 A/B 和 Recovery 空间；
- [ ] 能恢复到默认启动配置。

---

# 12. M1-H：板级诊断和验收框架

## 12.1 目标

从 M1 开始建立统一测试体系，而不是等系统全部完成后再补测试。

## 12.2 板级信息工具

建立：

```text
/usr/bin/board-info
```

输出至少包含：

```text
Board model
CPU model
DDR capacity
Kernel version
Device tree model
U-Boot version
RootFS version
Build ID
Active slot
Boot source
eMMC information
SD information
Network interfaces
Watchdog state
System uptime
```

## 12.3 自检工具

建立：

```text
/usr/bin/board-selftest
```

支持：

```text
board-selftest all
board-selftest storage
board-selftest network
board-selftest usb
board-selftest display
board-selftest touch
board-selftest watchdog
```

第一版实现：

- 串口；
- SD；
- eMMC；
- 文件系统；
- 网口；
- USB Host；
- RTC；
- watchdog 设备节点。

## 12.4 日志采集工具

建立：

```text
/usr/bin/collect-diagnostics
```

采集：

- `/proc/cmdline`
- `/proc/version`
- `/proc/meminfo`
- `/proc/partitions`
- `/proc/device-tree/model`
- `dmesg`
- `mount`
- `df`
- `ip addr`
- `ip route`
- `ethtool`
- `lsusb`
- `ls /dev`
- U-Boot 环境摘要
- Build ID
- 最近启动状态
- 最近升级状态

输出：

```text
/var/log/diagnostics/diagnostics-YYYYMMDD-HHMMSS.tar.gz
```

## 12.5 验收报告

每次里程碑测试生成：

```text
artifacts/<milestone>/
├── build-info.txt
├── SHA256SUMS
├── boot-summary.txt
├── selftest-results.txt
├── known-issues.md
└── verification.md
```

## 12.6 验收标准

- [ ] 板级信息可一条命令查看；
- [ ] 基础硬件可自动测试；
- [ ] 故障信息可自动打包；
- [ ] 测试结果包含时间、版本和 Git 提交；
- [ ] GitHub 中保存精简测试证据；
- [ ] 完整原始日志保存在本地。

---

# 13. M1 不包含的内容

以下功能属于后续阶段，不在 M1 中一次性完成：

- 完整 A/B 在线升级实现；
- 自动回滚状态机；
- Recovery 系统完整实现；
- 安全启动；
- 镜像签名；
- 加密升级包；
- 云端升级服务器；
- 完整量产烧写系统；
- 全部应用层业务；
- 长时间可靠性测试；
- 完整功耗优化。

但 M1 的设计不得阻碍这些功能。

---

# 14. 后续总体路线图

## M0：官方源码和构建基线

状态：已完成

- NXP U-Boot 源码导入；
- NXP Linux 源码导入；
- 版本锁定；
- 官方基线编译；
- 自主内核实机启动。

## M1：板级基础平台闭环

状态：当前阶段

- 自主 U-Boot；
- 自主 DTS；
- 自主 Buildroot RootFS；
- SD 启动；
- eMMC 启动；
- 基础网络和 USB；
- 基础诊断工具。

## M2：完整基础外设平台

- 双网口；
- LCD；
- 背光；
- 触摸；
- I2C 传感器；
- SPI 传感器；
- CAN；
- RS485；
- RS232；
- Audio；
- Camera；
- GPIO、LED、KEY、Buzzer；
- Suspend/Resume 基础验证。

## M3：A/B 系统升级

- Slot A/Slot B；
- 升级包格式；
- 升级写入；
- 升级状态管理；
- bootcount；
- bootlimit；
- 用户空间确认；
- 升级失败自动回滚；
- 断电恢复；
- 升级日志；
- 版本兼容策略。

## M4：异常恢复和看门狗

- U-Boot watchdog；
- Linux hardware watchdog；
- 用户空间 watchdog daemon；
- Kernel panic 恢复；
- RootFS 损坏恢复；
- Recovery 系统；
- 启动失败计数；
- 只读根文件系统方案；
- 日志持久化；
- Crash dump 策略。

## M5：板级测试和诊断

- 自动化板级测试；
- 工厂测试模式；
- 老化测试；
- 网络压力测试；
- 存储读写测试；
- USB 测试；
- LCD 色块测试；
- 触摸校准和测试；
- CAN/RS485 回环测试；
- Watchdog 测试；
- 统一测试报告。

## M6：产品化发布系统

- 统一版本号；
- Release Notes；
- SBOM；
- 构建容器；
- CI 构建；
- 自动生成镜像；
- 自动生成校验值；
- 自动生成升级包；
- Git tag；
- GitHub Release；
- 发布签名；
- 可重复构建验证。

---

# 15. M1 分支规划

## 15.1 顶层仓库

建议建立：

```text
main
└── develop
    └── feat/m1-board-baseline
```

当前 M0 功能分支完成后，应先合并到 `develop` 或 `main`，再创建 M1 分支。

推荐命令：

```bash
cd /home/pointer/imx6ull/projects/imx6ull-nxp-bsp

git switch main
git pull --ff-only origin main

git switch -c feat/m1-board-baseline
git push -u origin feat/m1-board-baseline
```

## 15.2 Linux 源码仓库

```text
nxp-baseline
└── board/imx6ull-jjl
    └── feat/jjl-dts-base
```

## 15.3 U-Boot 源码仓库

```text
nxp-baseline
└── board/imx6ull-jjl
    └── feat/jjl-board-port
```

## 15.4 Buildroot 源码仓库

导入 Buildroot 后建立：

```text
buildroot-baseline
└── board/imx6ull-jjl
    └── feat/jjl-rootfs-base
```

---

# 16. M1 推荐执行顺序

严格按照以下顺序推进：

```text
第一步：M1-A 启动架构和分区布局
        ↓
第二步：M1-B 硬件资源矩阵
        ↓
第三步：M1-C 最小 Linux DTS
        ↓
第四步：使用已有可靠 U-Boot 验证新 DTS
        ↓
第五步：M1-D 自主 U-Boot 板级端口
        ↓
第六步：自主 U-Boot + 自主 Kernel + 自主 DTS
        ↓
第七步：M1-E Buildroot RootFS
        ↓
第八步：完整自主软件栈启动
        ↓
第九步：M1-F SD 卡完整镜像
        ↓
第十步：M1-G eMMC 安装和启动
        ↓
第十一步：M1-H 板级诊断工具
```

禁止同时大规模修改 U-Boot、DTS 和 RootFS。

每次实机测试只引入一个主要变量，便于定位故障。

---

# 17. M1 阶段最终验收标准

只有同时满足以下条件，M1 才能标记为完成。

## 17.1 源码和构建

- [ ] U-Boot 从源码构建；
- [ ] Linux 从源码构建；
- [ ] Buildroot 从源码构建；
- [ ] 所有源码版本已锁定；
- [ ] 所有构建均使用源码外输出；
- [ ] 构建过程可通过统一脚本执行；
- [ ] 构建产物具备 SHA-256；
- [ ] 构建信息包含 Git 提交。

## 17.2 板级维护

- [ ] 拥有专用 U-Boot defconfig；
- [ ] 拥有专用 Linux DTS；
- [ ] 拥有专用 Buildroot defconfig；
- [ ] 不再使用 NXP EVK model；
- [ ] 不再依赖旧厂商 RootFS；
- [ ] 所有板级修改能够由 patch 重放。

## 17.3 启动

- [ ] SD 卡能够独立启动；
- [ ] eMMC 能够独立启动；
- [ ] U-Boot 能加载 Kernel 和 DTB；
- [ ] Linux 能挂载 Buildroot RootFS；
- [ ] 串口控制台正常；
- [ ] 系统能够正常重启和关机。

## 17.4 基础硬件

- [ ] SD 正常；
- [ ] eMMC 正常；
- [ ] 至少一个以太网接口正常；
- [ ] DHCP、Ping、TFTP 正常；
- [ ] USB Host 能识别 U 盘；
- [ ] Watchdog 设备节点存在；
- [ ] 基础 RTC 或系统时间机制可用。

## 17.5 产品架构预留

- [ ] 分区布局兼容 A/B；
- [ ] U-Boot 环境预留 slot 变量；
- [ ] 预留冗余环境；
- [ ] 预留 Recovery；
- [ ] 预留持久化 Data；
- [ ] 版本信息可在运行系统中查询。

## 17.6 文档和测试

- [ ] 每个关键操作有 Runbook；
- [ ] 每个里程碑有验收文档；
- [ ] 每次构建有 Build Info；
- [ ] 每次实机启动有精简日志；
- [ ] 提供 `board-info`；
- [ ] 提供 `board-selftest`；
- [ ] 提供 `collect-diagnostics`。

---

# 18. M1 第一批实际任务

当前不直接开始复制设备树。

先完成以下三项基础工作。

## Task 1：建立产品架构目录

```bash
mkdir -p \
    docs/architecture \
    docs/roadmap \
    docs/decisions \
    board/imx6ull-jjl/hardware \
    board/imx6ull-jjl/rootfs-overlay \
    scripts/image \
    scripts/deploy \
    scripts/test
```

## Task 2：建立四份基础架构文档

```text
docs/architecture/boot-flow.md
docs/architecture/storage-layout.md
docs/architecture/build-and-release.md
board/imx6ull-jjl/hardware/board-summary.md
```

## Task 3：收集硬件基线

优先确认：

1. DDR 型号和容量；
2. eMMC 型号和容量；
3. 调试串口；
4. SD 和 eMMC 分别使用哪个 USDHC；
5. ENET1 和 ENET2 的 PHY 型号、地址和复位 GPIO；
6. LCD 型号、分辨率和时序；
7. 触摸芯片、I2C 地址、中断和复位 GPIO；
8. USB Host 和 OTG 的 VBUS 控制；
9. ICM20608 的 SPI 控制器和片选；
10. CAN、RS485、RS232 的控制器和 GPIO。

完成硬件基线后，再创建第一版：

```text
imx6ull-jjl.dtsi
imx6ull-jjl-emmc.dts
```

---

# 19. M1 提交规范

推荐提交顺序：

```text
docs: define M1 board platform roadmap
docs: add boot and storage architecture
docs: add JJL hardware resource matrix
dts: add JJL board device tree skeleton
dts: enable JJL console and storage
dts: enable JJL primary Ethernet
uboot: add JJL board target
uboot: enable JJL storage and network
buildroot: add JJL minimal root filesystem
image: add SD card image generator
deploy: add safe eMMC installer
test: add JJL baseline self-test
```

每一个提交都应满足：

- 能解释修改目的；
- 修改范围单一；
- 能独立审查；
- 能独立回退；
- 有相应测试记录；
- 不包含完整上游源码；
- 不包含本机密码、Token 和私钥；
- 不包含不必要的绝对路径。

---

# 20. M1 完成后的系统形态

M1 完成后，系统应达到：

```text
正点原子 i.MX6ULL 开发板
        +
自主维护 U-Boot
        +
自主维护 Linux DTS
        +
自主编译 Linux Kernel
        +
自主 Buildroot RootFS
        +
标准 SD/eMMC 镜像
        +
基础网络和 USB
        +
板级诊断工具
        ↓
Board Platform Baseline v0.1
```

这将成为后续以下功能的稳定基础：

```text
LCD和触摸
完整外设驱动
A/B升级
自动回滚
Recovery
Watchdog
工厂测试
故障诊断
产品发布
```