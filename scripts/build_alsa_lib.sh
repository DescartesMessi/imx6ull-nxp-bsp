#!/bin/bash
# 全新编译并部署 ./scripts/build_alsa_lib.sh --clean
# 如果只使用 4 个线程：JOBS=4 ./scripts/build_alsa_lib.sh --clean
# 不更新 rootfs，只更新编译结果和 sysroot：DEPLOY_ROOTFS=0 ./scripts/build_alsa_lib.sh --clean  


set -euo pipefail

###############################################################################
# ALSA-Lib 1.2.2 ARM Cross Build Script
# Target: i.MX6ULL / ARMv7 hard-float
###############################################################################

export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ALSA_SRC="${PROJECT_ROOT}/build/3rdparty/src/alsa-lib-1.2.2"
ALSA_BUILD="${PROJECT_ROOT}/build/3rdparty/alsa-lib-1.2.2-arm"
ALSA_STAGE="${PROJECT_ROOT}/build/3rdparty/alsa-lib-1.2.2-stage"

SYSROOT="${PROJECT_ROOT}/build/sysroot"
ROOTFS="${PROJECT_ROOT}/deploy/nfs/rootfs"

JOBS="${JOBS:-$(nproc)}"
DEPLOY_ROOTFS="${DEPLOY_ROOTFS:-1}"

HOST="arm-linux-gnueabihf"

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
    echo "  $0 --clean     清理旧 ALSA-Lib 编译和安装结果"
    echo "  $0 --keep      保留旧编译结果"
    echo "  $0 --help      显示帮助"
    echo ""
    echo "Environment:"
    echo "  JOBS=4                 使用 4 个线程编译"
    echo "  DEPLOY_ROOTFS=0        不更新 rootfs"
}

###############################################################################
# 参数
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
                "是否清理旧 ALSA-Lib 编译和安装结果？[y/N] " answer

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
# 路径显示
###############################################################################

echo "======================================"
echo " Build ALSA-Lib 1.2.2 for i.MX6ULL"
echo "======================================"
echo "Source        : ${ALSA_SRC}"
echo "Build         : ${ALSA_BUILD}"
echo "Stage         : ${ALSA_STAGE}"
echo "Sysroot       : ${SYSROOT}"
echo "Rootfs        : ${ROOTFS}"
echo "Cross         : ${CROSS_COMPILE}"
echo "Jobs          : ${JOBS}"
echo "Clean         : ${CLEAN}"
echo "Deploy rootfs : ${DEPLOY_ROOTFS}"
echo "======================================"

###############################################################################
# 环境检查
###############################################################################

log_info "Checking environment..."

command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}gcc not found"

command -v "${CROSS_COMPILE}g++" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}g++ not found"

command -v "${CROSS_COMPILE}ar" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ar not found"

command -v "${CROSS_COMPILE}ranlib" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ranlib not found"

command -v make >/dev/null 2>&1 \
    || die "make not found"

[ -f "${ALSA_SRC}/configure" ] \
    || die "ALSA-Lib configure not found: ${ALSA_SRC}/configure"

[ -f "${SYSROOT}/usr/include/zlib.h" ] \
    || die "zlib header not found in sysroot"

[ -f "${SYSROOT}/usr/lib/libz.so" ] \
    || die "zlib library not found in sysroot"

[ -d "${ROOTFS}" ] \
    || die "Rootfs not found: ${ROOTFS}"

###############################################################################
# 路径安全检查
###############################################################################

EXPECTED_BUILD="${PROJECT_ROOT}/build/3rdparty/alsa-lib-1.2.2-arm"
EXPECTED_STAGE="${PROJECT_ROOT}/build/3rdparty/alsa-lib-1.2.2-stage"

[ "${ALSA_BUILD}" = "${EXPECTED_BUILD}" ] \
    || die "Unsafe ALSA_BUILD path"

[ "${ALSA_STAGE}" = "${EXPECTED_STAGE}" ] \
    || die "Unsafe ALSA_STAGE path"

###############################################################################
# 清理
###############################################################################

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old ALSA-Lib build and staging directories..."

    rm -rf -- "${ALSA_BUILD}"
    rm -rf -- "${ALSA_STAGE}"
fi

mkdir -p "${ALSA_BUILD}"
mkdir -p "${ALSA_STAGE}"

###############################################################################
# 复制源码到独立构建目录
###############################################################################

if [ ! -f "${ALSA_BUILD}/configure" ]; then
    log_info "Copying ALSA-Lib source to build directory..."
    cp -a "${ALSA_SRC}/." "${ALSA_BUILD}/"
fi

###############################################################################
# 交叉编译环境
###############################################################################

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export AR="${CROSS_COMPILE}ar"
export RANLIB="${CROSS_COMPILE}ranlib"
export STRIP="${CROSS_COMPILE}strip"

export CFLAGS="--sysroot=${SYSROOT} -O2 -fPIC"
export CXXFLAGS="--sysroot=${SYSROOT} -O2 -fPIC"
export LDFLAGS="--sysroot=${SYSROOT}"

export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${SYSROOT}/lib/pkgconfig"
unset PKG_CONFIG_PATH

###############################################################################
# 配置
###############################################################################

cd "${ALSA_BUILD}"

log_info "Configuring ALSA-Lib..."

./configure \
    --build="$(gcc -dumpmachine)" \
    --host="${HOST}" \
    --prefix=/usr \
    --libdir=/usr/lib \
    --sysconfdir=/etc \
    --with-configdir=/usr/share/alsa \
    --with-plugindir=/usr/lib/alsa-lib \
    --with-pkgconfdir=/usr/lib/pkgconfig \
    --disable-python \
    --enable-shared \
    --disable-static \
    ac_cv_func_malloc_0_nonnull=yes \
    ac_cv_func_realloc_0_nonnull=yes

log_info "ALSA-Lib configuration completed"

###############################################################################
# 编译
###############################################################################

log_info "Building ALSA-Lib..."

make -j"${JOBS}"

log_info "ALSA-Lib build completed"

###############################################################################
# 安装到 staging
###############################################################################

log_info "Installing ALSA-Lib to staging..."

make -j1 install DESTDIR="${ALSA_STAGE}"

###############################################################################
# 检查 staging
###############################################################################

ALSA_STAGE_LIB="${ALSA_STAGE}/usr/lib"
ALSA_STAGE_INC="${ALSA_STAGE}/usr/include"
ALSA_STAGE_SHARE="${ALSA_STAGE}/usr/share/alsa"

[ -d "${ALSA_STAGE_LIB}" ] \
    || die "ALSA-Lib staging lib directory not found"

[ -d "${ALSA_STAGE_INC}/alsa" ] \
    || die "ALSA headers not found in staging"

[ -e "${ALSA_STAGE_LIB}/libasound.so" ] \
    || die "libasound.so not found in staging"

###############################################################################
# 更新交叉编译 sysroot
###############################################################################

log_info "Updating cross-compilation sysroot..."

mkdir -p "${SYSROOT}/usr/include"
mkdir -p "${SYSROOT}/usr/lib"
mkdir -p "${SYSROOT}/usr/share"

cp -a \
    "${ALSA_STAGE_INC}/." \
    "${SYSROOT}/usr/include/"

cp -a \
    "${ALSA_STAGE_LIB}/." \
    "${SYSROOT}/usr/lib/"

if [ -d "${ALSA_STAGE_SHARE}" ]; then
    mkdir -p "${SYSROOT}/usr/share/alsa"
    cp -a \
        "${ALSA_STAGE_SHARE}/." \
        "${SYSROOT}/usr/share/alsa/"
fi

###############################################################################
# 更新 rootfs
###############################################################################

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying ALSA-Lib runtime to rootfs..."

    mkdir -p "${ROOTFS}/usr/lib"
    mkdir -p "${ROOTFS}/usr/share"

    # libasound.so.2 运行时库
    find "${ALSA_STAGE_LIB}" \
        -maxdepth 1 \
        \( -type f -o -type l \) \
        -name "libasound.so*" \
        -exec cp -a {} "${ROOTFS}/usr/lib/" \;

    # ALSA 插件，例如 pcm、ctl、mix 等
    if [ -d "${ALSA_STAGE_LIB}/alsa-lib" ]; then
        rm -rf -- "${ROOTFS}/usr/lib/alsa-lib"
        cp -a \
            "${ALSA_STAGE_LIB}/alsa-lib" \
            "${ROOTFS}/usr/lib/"
    fi

    # ALSA 配置文件
    if [ -d "${ALSA_STAGE_SHARE}" ]; then
        rm -rf -- "${ROOTFS}/usr/share/alsa"
        cp -a \
            "${ALSA_STAGE_SHARE}" \
            "${ROOTFS}/usr/share/"
    fi

    log_info "ALSA-Lib runtime deployed"
else
    log_warn "DEPLOY_ROOTFS=0, rootfs was not modified"
fi

###############################################################################
# 检查结果
###############################################################################

echo ""
echo "======================================"
echo " ALSA-Lib 1.2.2 Build Finished"
echo "======================================"

echo ""
echo "Staging libraries:"
find "${ALSA_STAGE_LIB}" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    -name "libasound.so*" \
    -print

echo ""
echo "Staging headers:"
find "${ALSA_STAGE_INC}/alsa" \
    -maxdepth 1 \
    -type f \
    -print \
    | head -n 20

echo ""
echo "Rootfs libraries:"
find "${ROOTFS}/usr/lib" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    -name "libasound.so*" \
    -print

echo ""
echo "[INFO] DONE!"