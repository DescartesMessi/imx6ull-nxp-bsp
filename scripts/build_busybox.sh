#!/bin/bash
# 编译出 ARM BusyBox, /bin /sbin /usr/bin /usr/sbin
# 交叉编译 BusyBox，并把 BusyBox 提供的 Linux 用户空间命令安装到 RootFS 中。
###############################################################################
# File       : build_busybox.sh
# Author     : Pointer
# Platform   : i.MX6ULL JJL
#
# Description:
#
# 1. Build BusyBox with independent build directory
# 2. Keep BusyBox source clean
# 3. Install BusyBox into NFS rootfs
#
###############################################################################

set -u


###############################################################################
# Environment
###############################################################################

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BUSYBOX_SOURCE="${PROJECT_ROOT}/sources/busybox/busybox-1.29.0"
BUSYBOX_BUILD="${PROJECT_ROOT}/build/busybox"
ROOTFS_DIR="${PROJECT_ROOT}/deploy/nfs/rootfs"
DEFCONFIG="${BUSYBOX_SOURCE}/configs/imx6ull_jjl_defconfig"

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
echo " Build BusyBox for i.MX6ULL JJL"
echo "======================================"
echo "Source   : ${BUSYBOX_SOURCE}"
echo "Build    : ${BUSYBOX_BUILD}"
echo "Rootfs   : ${ROOTFS_DIR}"
echo "Compiler : ${CROSS_COMPILE}"
echo ""
###############################################################################
# Check
###############################################################################

log_info "Check environment"

if [ ! -d "${BUSYBOX_SOURCE}" ]; then
    die "BusyBox source not found!"
fi
mkdir -p "${BUSYBOX_BUILD}"
mkdir -p "${ROOTFS_DIR}"

###############################################################################
# Load configuration
###############################################################################

log_info "Load BusyBox defconfig"
cp "${DEFCONFIG}" \
   "${BUSYBOX_BUILD}/.config" \
   || die "Copy BusyBox config failed"

###############################################################################
# Configuration update
###############################################################################

log_info "Update BusyBox configuration"
make -C "${BUSYBOX_SOURCE}" \
     O="${BUSYBOX_BUILD}" \
     ARCH=${ARCH} \
     CROSS_COMPILE=${CROSS_COMPILE} \
     oldconfig \
     || die "BusyBox oldconfig failed"

###############################################################################
# Build
###############################################################################

log_info "Build BusyBox"
make -C "${BUSYBOX_SOURCE}" \
     O="${BUSYBOX_BUILD}" \
     ARCH=${ARCH} \
     CROSS_COMPILE=${CROSS_COMPILE} \
     -j$(nproc) \
     || die "BusyBox build failed"

###############################################################################
# Check binary
###############################################################################

BUSYBOX_BIN="${BUSYBOX_BUILD}/busybox"
if [ ! -f "${BUSYBOX_BIN}" ]; then

    die "BusyBox binary not found!"

fi
file "${BUSYBOX_BIN}"

###############################################################################
# Install BusyBox
###############################################################################

log_info "Install BusyBox into rootfs"
make -C "${BUSYBOX_SOURCE}" \
     O="${BUSYBOX_BUILD}" \
     ARCH=${ARCH} \
     CROSS_COMPILE=${CROSS_COMPILE} \
     CONFIG_PREFIX="${ROOTFS_DIR}" \
     install \
     || die "BusyBox install failed"

echo ""
echo "======================================"
echo " BusyBox Build Finished"
echo "======================================"
exit 0