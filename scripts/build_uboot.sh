#!/bin/bash
###############################################################################
# File       : build_uboot.sh
# Author     : Pointer (Refactored)
# Platform   : i.MX6ULL
# U-Boot     : NXP U-Boot 4.1.15 BSP
#
# Description:
#   1. 使用独立 build 目录进行 U-Boot 编译，不污染源码目录 (O=build)
#   2. 自动配置目标开发板的 defconfig
#   3. 使用多核并行编译生成 u-boot.bin 和 u-boot.imx
#   4. 自动部署编译产物到 TFTP 服务器目录
###############################################################################

# 开启严格模式：未定义变量、命令失败、管道失败都会立即退出
set -euo pipefail

###############################################################################
# 1. 基础环境与变量配置区
###############################################################################

# 交叉编译链配置 (如果外部没有传入，则使用默认值)
export ARCH=${ARCH:-arm}
export CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabihf-}

# 路径获取与定义
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"          # 工程根目录 (scripts目录的上一级)

UBOOT_SOURCE="${PROJECT_ROOT}/sources/uboot-imx"   # U-Boot 源码目录
UBOOT_BUILD="${PROJECT_ROOT}/build/uboot"          # 编译过程文件输出目录
TFTP_DIR="${PROJECT_ROOT}/deploy/tftp"             # TFTP 镜像发布目录

# 目标板配置名称 (位于 sources/uboot-imx/configs/ 目录下)
BOARD_DEFCONFIG="mx6ull_alientek_jjl_defconfig"

###############################################################################
# 2. 公共函数定义区
###############################################################################

# 打印信息日志 (绿色)
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

# 打印错误日志并退出 (红色)
die() {
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}

###############################################################################
# 3. 脚本主逻辑执行区
###############################################################################

# --- 打印编译环境信息 ---
echo "======================================"
echo " Build U-Boot for i.MX6ULL"
echo "======================================"
echo "Project Root  : ${PROJECT_ROOT}"
echo "U-Boot Source : ${UBOOT_SOURCE}"
echo "Build Output  : ${UBOOT_BUILD}"
echo "TFTP Deploy   : ${TFTP_DIR}"
echo "Cross Compile : ${CROSS_COMPILE}"
echo "======================================"
echo ""

# --- 阶段 1: 检查源码环境并创建必要目录 ---
log_info "Check environment and create directories..."

if [ ! -d "${UBOOT_SOURCE}" ]; then
    die "Cannot find U-Boot source at: ${UBOOT_SOURCE}"
fi

mkdir -p "${UBOOT_BUILD}" || die "Failed to create build directory: ${UBOOT_BUILD}"
mkdir -p "${TFTP_DIR}"    || die "Failed to create TFTP directory: ${TFTP_DIR}"

# --- 阶段 2: 配置 U-Boot ---
log_info "Configure U-Boot for ${BOARD_DEFCONFIG}..."
# make -C : 临时切换到源码目录执行
# O=...   : 指定输出目录，保持源码干净
make -C "${UBOOT_SOURCE}" O="${UBOOT_BUILD}" "${BOARD_DEFCONFIG}" || die "U-Boot configure failed!"
log_info "U-Boot configuration success!"

# --- 阶段 3: 编译 U-Boot ---
log_info "Compile U-Boot (using $(nproc) cores)..."
make -C "${UBOOT_SOURCE}" O="${UBOOT_BUILD}" -j"$(nproc)" || die "U-Boot compile failed!"
log_info "U-Boot compile success!"

# --- 阶段 4: 检查编译产物 ---
log_info "Check output files..."

UBOOT_BIN="${UBOOT_BUILD}/u-boot.bin"
UBOOT_IMX="${UBOOT_BUILD}/u-boot.imx"

if [ ! -f "${UBOOT_BIN}" ]; then
    die "u-boot.bin not found! Expected at: ${UBOOT_BIN}"
fi

if [ ! -f "${UBOOT_IMX}" ]; then
    die "u-boot.imx not found! Expected at: ${UBOOT_IMX}"
fi

log_info "Found U-Boot binaries successfully."

# --- 阶段 5: 部署到 TFTP 目录 ---
log_info "Deploy to TFTP directory..."

cp "${UBOOT_BIN}" "${TFTP_DIR}/" || die "Failed to copy u-boot.bin to TFTP directory!"
cp "${UBOOT_IMX}" "${TFTP_DIR}/" || die "Failed to copy u-boot.imx to TFTP directory!"

# --- 阶段 6: 结束并展示结果 ---
echo ""
echo "======================================"
echo -e "\033[32m U-Boot Build Finished Successfully \033[0m"
echo "======================================"
echo "TFTP directory contents:"
ls -lh "${TFTP_DIR}" | grep "u-boot" || true

echo ""
log_info "DONE!"
exit 0
