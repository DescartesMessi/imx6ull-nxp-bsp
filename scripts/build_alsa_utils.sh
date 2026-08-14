#!/bin/bash

# chmod +x scripts/build_alsa_utils.sh
# 编译和部署 alsa-utils 1.2.2 到 i.MX6ULL 的 rootfs
# 全新编译并部署 ./scripts/build_alsa_utils.sh --clean
# 如果只使用 4 个线程：JOBS=4 ./scripts/build_alsa_utils.sh --clean
# 不更新 rootfs，只更新编译结果和 sysroot：DEPLOY_ROOTFS=0 ./scripts/build_alsa_utils.sh --clean


set -euo pipefail

export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ALSA_UTILS_SRC="${PROJECT_ROOT}/build/3rdparty/src/alsa-utils-1.2.2"
ALSA_UTILS_BUILD="${PROJECT_ROOT}/build/3rdparty/alsa-utils-1.2.2-arm"
ALSA_UTILS_STAGE="${PROJECT_ROOT}/build/3rdparty/alsa-utils-1.2.2-stage"

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
    echo "  $0 --clean     清理旧编译结果"
    echo "  $0 --keep      保留旧编译结果"
    echo "  $0 --help      显示帮助"
}

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
                "是否清理旧 alsa-utils 编译结果？[y/N] " answer

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

echo "======================================"
echo " Build alsa-utils 1.2.2 for i.MX6ULL"
echo "======================================"
echo "Source        : ${ALSA_UTILS_SRC}"
echo "Build         : ${ALSA_UTILS_BUILD}"
echo "Stage         : ${ALSA_UTILS_STAGE}"
echo "Sysroot       : ${SYSROOT}"
echo "Rootfs        : ${ROOTFS}"
echo "Cross         : ${CROSS_COMPILE}"
echo "Jobs          : ${JOBS}"
echo "Clean         : ${CLEAN}"
echo "======================================"

command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}gcc not found"

command -v "${CROSS_COMPILE}g++" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}g++ not found"

command -v make >/dev/null 2>&1 \
    || die "make not found"

[ -f "${ALSA_UTILS_SRC}/configure" ] \
    || die "alsa-utils configure not found"

[ -f "${SYSROOT}/usr/include/alsa/asoundlib.h" ] \
    || die "ALSA headers not found in sysroot"

[ -f "${SYSROOT}/usr/lib/libasound.so" ] \
    || die "libasound.so not found in sysroot"

[ -d "${ROOTFS}" ] \
    || die "Rootfs not found"

EXPECTED_BUILD="${PROJECT_ROOT}/build/3rdparty/alsa-utils-1.2.2-arm"
EXPECTED_STAGE="${PROJECT_ROOT}/build/3rdparty/alsa-utils-1.2.2-stage"

[ "${ALSA_UTILS_BUILD}" = "${EXPECTED_BUILD}" ] \
    || die "Unsafe build path"

[ "${ALSA_UTILS_STAGE}" = "${EXPECTED_STAGE}" ] \
    || die "Unsafe stage path"

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old alsa-utils build and staging..."

    rm -rf -- "${ALSA_UTILS_BUILD}"
    rm -rf -- "${ALSA_UTILS_STAGE}"
fi

mkdir -p "${ALSA_UTILS_BUILD}"
mkdir -p "${ALSA_UTILS_STAGE}"

if [ ! -f "${ALSA_UTILS_BUILD}/configure" ]; then
    log_info "Copying alsa-utils source..."
    cp -a "${ALSA_UTILS_SRC}/." "${ALSA_UTILS_BUILD}/"
fi

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export AR="${CROSS_COMPILE}ar"
export RANLIB="${CROSS_COMPILE}ranlib"
export STRIP="${CROSS_COMPILE}strip"

export CPPFLAGS="--sysroot=${SYSROOT} -I${SYSROOT}/usr/include"
export CFLAGS="--sysroot=${SYSROOT} -O2"
export CXXFLAGS="--sysroot=${SYSROOT} -O2"
export LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib -Wl,-rpath-link,${SYSROOT}/usr/lib"

export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${SYSROOT}/lib/pkgconfig"

unset PKG_CONFIG_PATH

cd "${ALSA_UTILS_BUILD}"

log_info "Configuring alsa-utils..."

./configure \
    --build="$(gcc -dumpmachine)" \
    --host=arm-linux-gnueabihf \
    --prefix=/usr \
    --bindir=/usr/bin \
    --sbindir=/usr/sbin \
    --sysconfdir=/etc \
    --disable-nls \
    --disable-xmlto \
    --disable-alsamixer \
    --disable-alsatop \
    --disable-alsaloop \
    --disable-bat

log_info "Building alsa-utils..."

make -j"${JOBS}"

log_info "Installing alsa-utils to staging..."

make -j1 install DESTDIR="${ALSA_UTILS_STAGE}"

STAGE_BIN="${ALSA_UTILS_STAGE}/usr/bin"
STAGE_SBIN="${ALSA_UTILS_STAGE}/usr/sbin"

[ -f "${STAGE_BIN}/aplay" ] \
    || die "aplay was not built"

[ -f "${STAGE_BIN}/arecord" ] \
    || die "arecord was not built"

[ -f "${STAGE_BIN}/amixer" ] \
    || die "amixer was not built"

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying alsa-utils to rootfs..."

    mkdir -p "${ROOTFS}/usr/bin"
    mkdir -p "${ROOTFS}/usr/sbin"

    for program in aplay arecord amixer
    do
        if [ -f "${STAGE_BIN}/${program}" ]; then
            install -m 0755 \
                "${STAGE_BIN}/${program}" \
                "${ROOTFS}/usr/bin/${program}"
        fi
    done

    if [ -f "${STAGE_BIN}/alsactl" ]; then
        install -m 0755 \
            "${STAGE_BIN}/alsactl" \
            "${ROOTFS}/usr/sbin/alsactl"
    fi

    if [ -d "${ALSA_UTILS_STAGE}/etc" ]; then
        cp -a \
            "${ALSA_UTILS_STAGE}/etc/." \
            "${ROOTFS}/etc/"
    fi
else
    log_warn "DEPLOY_ROOTFS=0, rootfs was not modified"
fi

echo ""
echo "======================================"
echo " alsa-utils 1.2.2 Build Finished"
echo "======================================"

echo ""
echo "Generated programs:"
find "${ALSA_UTILS_STAGE}" \
    -type f \
    \( -name aplay -o -name arecord -o -name amixer -o -name alsactl \) \
    -print

echo ""
echo "Rootfs programs:"
ls -l \
    "${ROOTFS}/usr/bin/aplay" \
    "${ROOTFS}/usr/bin/arecord" \
    "${ROOTFS}/usr/bin/amixer" \
    2>/dev/null || true

echo ""
echo "[INFO] DONE!"