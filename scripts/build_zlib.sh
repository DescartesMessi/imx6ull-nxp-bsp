#!/bin/bash
# 编译结果放到 build/3rdparty/zlib-1.2.11-arm
# 临时安装目录放到 build/3rdparty/zlib-1.2.11-stage
# 头文件和库同步到 build/sysroot
# 运行库同步到 deploy/nfs/rootfs/usr/lib

# 全新编译并部署 ./scripts/build_zlib.sh --clean
# 如果只使用 4 个线程：JOBS=4 ./scripts/build_zlib.sh --clean
# 不更新 rootfs，只更新编译结果和 sysroot：DEPLOY_ROOTFS=0 ./scripts/build_zlib.sh --clean
set -euo pipefail


###############################################################################
# zlib 1.2.11 ARM Cross Build Script
# Target: i.MX6ULL / ARMv7 hard-float
###############################################################################

export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ZLIB_SRC="${PROJECT_ROOT}/build/3rdparty/src/zlib-1.2.11"
ZLIB_BUILD="${PROJECT_ROOT}/build/3rdparty/zlib-1.2.11-arm"
ZLIB_STAGE="${PROJECT_ROOT}/build/3rdparty/zlib-1.2.11-stage"

SYSROOT="${PROJECT_ROOT}/build/sysroot"
ROOTFS="${PROJECT_ROOT}/deploy/nfs/rootfs"

JOBS="${JOBS:-$(nproc)}"
DEPLOY_ROOTFS="${DEPLOY_ROOTFS:-1}"

log_info()
{
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_warn()
{
    echo -e "\033[33m[WARN]\033[0m $1"
}

die()
{
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}

usage()
{
    echo "Usage:"
    echo "  $0             运行时询问是否清理"
    echo "  $0 --clean     清理旧 zlib 编译和安装结果"
    echo "  $0 --keep      保留旧编译结果"
    echo "  $0 --help      显示帮助"
    echo ""
    echo "Environment:"
    echo "  JOBS=4                 使用 4 个线程编译"
    echo "  DEPLOY_ROOTFS=0        不更新 rootfs"
}

###############################################################################
# 参数处理
###############################################################################

CLEAN=0

case "${1:-ask}" in
    --clean)
        CLEAN=1
        ;;
    --keep)
        CLEAN=0
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    ask)
        if [ -t 0 ]; then
            read -r -p \
                "是否清理旧 zlib 编译和安装结果？[y/N] " answer

            case "${answer}" in
                y|Y|yes|YES)
                    CLEAN=1
                    ;;
                *)
                    CLEAN=0
                    ;;
            esac
        fi
        ;;
    *)
        usage
        exit 1
        ;;
esac

###############################################################################
# 路径
###############################################################################

echo "======================================"
echo " Build zlib 1.2.11 for i.MX6ULL"
echo "======================================"
echo "Source       : ${ZLIB_SRC}"
echo "Build        : ${ZLIB_BUILD}"
echo "Stage        : ${ZLIB_STAGE}"
echo "Sysroot      : ${SYSROOT}"
echo "Rootfs       : ${ROOTFS}"
echo "Cross        : ${CROSS_COMPILE}"
echo "Jobs         : ${JOBS}"
echo "Clean        : ${CLEAN}"
echo "Deploy rootfs: ${DEPLOY_ROOTFS}"
echo "======================================"

###############################################################################
# 环境检查
###############################################################################

log_info "Checking environment..."

command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}gcc not found"

command -v "${CROSS_COMPILE}ar" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ar not found"

command -v "${CROSS_COMPILE}ranlib" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ranlib not found"

[ -f "${ZLIB_SRC}/configure" ] \
    || die "zlib configure not found: ${ZLIB_SRC}/configure"

[ -f "${SYSROOT}/usr/include/stdio.h" ] \
    || die "Sysroot headers not found: ${SYSROOT}/usr/include"

[ -d "${ROOTFS}" ] \
    || die "Rootfs not found: ${ROOTFS}"

###############################################################################
# 路径安全检查
###############################################################################

EXPECTED_BUILD="${PROJECT_ROOT}/build/3rdparty/zlib-1.2.11-arm"
EXPECTED_STAGE="${PROJECT_ROOT}/build/3rdparty/zlib-1.2.11-stage"

[ "${ZLIB_BUILD}" = "${EXPECTED_BUILD}" ] \
    || die "Unsafe ZLIB_BUILD path"

[ "${ZLIB_STAGE}" = "${EXPECTED_STAGE}" ] \
    || die "Unsafe ZLIB_STAGE path"

###############################################################################
# 清理
###############################################################################

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old zlib build and staging directories..."

    rm -rf -- "${ZLIB_BUILD}"
    rm -rf -- "${ZLIB_STAGE}"
fi

mkdir -p "${ZLIB_BUILD}"
mkdir -p "${ZLIB_STAGE}"

###############################################################################
# 复制源码到独立构建目录
#
# zlib 1.2.11 的 configure 不适合直接使用普通 out-of-tree 构建。
# 因此复制一份源码到 build/3rdparty/zlib-1.2.11-arm 中编译。
###############################################################################

if [ ! -f "${ZLIB_BUILD}/configure" ]; then
    log_info "Copying zlib source to independent build directory..."
    cp -a "${ZLIB_SRC}/." "${ZLIB_BUILD}/"
fi

###############################################################################
# 交叉编译环境
###############################################################################

export CC="${CROSS_COMPILE}gcc"
export AR="${CROSS_COMPILE}ar"
export RANLIB="${CROSS_COMPILE}ranlib"
export STRIP="${CROSS_COMPILE}strip"

export CFLAGS="--sysroot=${SYSROOT} -O2 -fPIC"
export LDFLAGS="--sysroot=${SYSROOT}"

###############################################################################
# 配置 zlib
###############################################################################

cd "${ZLIB_BUILD}"

log_info "Configuring zlib..."

CROSS_PREFIX="${CROSS_COMPILE}" \
CC="${CC}" \
AR="${AR}" \
RANLIB="${RANLIB}" \
STRIP="${STRIP}" \
./configure \
    --prefix=/usr \
    --shared

###############################################################################
# 编译
###############################################################################

log_info "Building zlib..."

make -j"${JOBS}"

log_info "zlib build finished"

###############################################################################
# 安装到临时 staging
###############################################################################

log_info "Installing zlib to staging..."

make -j1 install DESTDIR="${ZLIB_STAGE}"

###############################################################################
# 检查 staging
###############################################################################

ZLIB_STAGE_LIB="${ZLIB_STAGE}/usr/lib"
ZLIB_STAGE_INC="${ZLIB_STAGE}/usr/include"

[ -d "${ZLIB_STAGE_LIB}" ] \
    || die "zlib staging lib directory not found"

[ -f "${ZLIB_STAGE_INC}/zlib.h" ] \
    || die "zlib.h not found in staging"

[ -f "${ZLIB_STAGE_INC}/zconf.h" ] \
    || die "zconf.h not found in staging"

[ -e "${ZLIB_STAGE_LIB}/libz.so" ] \
    || die "libz.so not found in staging"

###############################################################################
# 更新交叉编译 sysroot
###############################################################################

log_info "Updating cross-compilation sysroot..."

mkdir -p "${SYSROOT}/usr/include"
mkdir -p "${SYSROOT}/usr/lib"

cp -a \
    "${ZLIB_STAGE_INC}/." \
    "${SYSROOT}/usr/include/"

cp -a \
    "${ZLIB_STAGE_LIB}/." \
    "${SYSROOT}/usr/lib/"

###############################################################################
# 更新 rootfs
###############################################################################

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying zlib runtime to rootfs..."

    mkdir -p "${ROOTFS}/usr/lib"

    # 目标板只需要运行库，不需要 zlib.h 和静态开发文件
    find "${ZLIB_STAGE_LIB}" \
        -maxdepth 1 \
        \( -type f -o -type l \) \
        -name "libz.so*" \
        -exec cp -a {} "${ROOTFS}/usr/lib/" \;

    log_info "zlib runtime deployed to ${ROOTFS}/usr/lib"
else
    log_warn "DEPLOY_ROOTFS=0, rootfs was not modified"
fi

###############################################################################
# 检查 ARM 文件格式
###############################################################################

log_info "Checking generated library..."

find "${ZLIB_STAGE_LIB}" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    -name "libz.so*" \
    -print

REAL_LIB="$(find "${ZLIB_STAGE_LIB}" \
    -maxdepth 1 \
    -type f \
    -name "libz.so.*" \
    | head -n 1 || true)"

if [ -n "${REAL_LIB}" ]; then
    file "${REAL_LIB}"
fi

echo ""
echo "======================================"
echo " zlib 1.2.11 Build Finished"
echo "======================================"

echo ""
echo "Staging:"
echo "${ZLIB_STAGE}"

echo ""
echo "Sysroot:"
echo "${SYSROOT}/usr/include/zlib.h"
echo "${SYSROOT}/usr/lib/libz.so"

echo ""
echo "Rootfs:"
echo "${ROOTFS}/usr/lib/libz.so"

echo ""
echo "[INFO] DONE!"