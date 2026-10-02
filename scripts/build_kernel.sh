#!/bin/bash

###############################################################################
# File       : build_kernel.sh
# Author     : Pointer
# Platform   : i.MX6ULL
#
# Description:
#
# 1. 使用独立 build 目录编译 Linux Kernel
# 2. 不污染 linux-imx 源码
# 3. 自动配置 defconfig
# 4. 编译指定 zImage 和 dtb
# 5. 自动部署到 TFTP目录
#
###############################################################################

set -euo pipefail

###############################################################################
# Environment
###############################################################################

export ARCH=${ARCH:-arm}
export CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabihf-}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
KERNEL_SOURCE="${PROJECT_ROOT}/sources/linux-imx"
KERNEL_BUILD="${PROJECT_ROOT}/build/kernel"
TFTP_DIR="${PROJECT_ROOT}/deploy/tftp"
BOARD_DEFCONFIG="imx6ull_alientek_jjl_defconfig"
DTB_NAME="imx6ull-alientek-jjl.dtb"
BUILD_LOG="${PROJECT_ROOT}/build/kernel_build.log"

###############################################################################
# Functions
###############################################################################

log_info()
{
    echo -e "\033[32m[INFO]\033[0m $1"
}
die()
{
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}

###############################################################################
# Main
###############################################################################
echo "======================================"
echo " Build Linux Kernel for i.MX6ULL"
echo "======================================"
echo "Kernel Source : ${KERNEL_SOURCE}"
echo "Kernel Build  : ${KERNEL_BUILD}"
echo "TFTP Deploy   : ${TFTP_DIR}"
echo "Cross Compile : ${CROSS_COMPILE}"
echo "Build Log     : ${BUILD_LOG}"
echo ""

###############################################################################
# Check Environment
###############################################################################
log_info "Check environment..."
if [ ! -d "${KERNEL_SOURCE}" ]; then

    die "Kernel source not found!"

fi
mkdir -p "${KERNEL_BUILD}" \
    || die "Create build directory failed"

mkdir -p "${TFTP_DIR}" \
    || die "Create tftp directory failed"

# 防止源码污染

if [ -f "${KERNEL_SOURCE}/.config" ]; then

    die "
Kernel source tree is polluted!

Found:
${KERNEL_SOURCE}/.config

Please remove it:
rm -f ${KERNEL_SOURCE}/.config

"

fi



###############################################################################
# Configure Kernel
###############################################################################


log_info "Configure Kernel..."
if ! make \
-C "${KERNEL_SOURCE}" \
O="${KERNEL_BUILD}" \
${BOARD_DEFCONFIG}; then

    die "Kernel configuration failed!"

fi
log_info "Kernel configuration success!"

###############################################################################
# Build Kernel
###############################################################################
log_info "Build Kernel..."
if ! make \
-C "${KERNEL_SOURCE}" \
O="${KERNEL_BUILD}" \
-j"$(nproc)" \
zImage \
${DTB_NAME} \
2>&1 | tee "${BUILD_LOG}"; then

    die "Kernel build failed!"

fi



log_info "Kernel build success!"



###############################################################################
# Check Output
###############################################################################


log_info "Check kernel images..."



ZIMAGE="${KERNEL_BUILD}/arch/arm/boot/zImage"


DTB="${KERNEL_BUILD}/arch/arm/boot/dts/${DTB_NAME}"



if [ ! -f "${ZIMAGE}" ]; then

    die "zImage not found:
${ZIMAGE}"

fi



if [ ! -f "${DTB}" ]; then

    die "DTB not found:
${DTB}"

fi



log_info "Kernel images found"



###############################################################################
# Deploy
###############################################################################


log_info "Deploy kernel image..."



cp "${ZIMAGE}" \
"${TFTP_DIR}/" \
|| die "Copy zImage failed"



cp "${DTB}" \
"${TFTP_DIR}/" \
|| die "Copy dtb failed"



###############################################################################
# Result
###############################################################################


echo ""

echo "======================================"

echo -e "\033[32m Linux Kernel Build Finished \033[0m"

echo "======================================"


echo ""

echo "Deploy files:"

ls -lh "${TFTP_DIR}" | grep -E "zImage|dtb" || true



echo ""

log_info "DONE!"

exit 0
