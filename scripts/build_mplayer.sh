#!/bin/bash
# 全新编译并部署 ./scripts/build_mplayer.sh --clean
# 如果只使用 4 个线程：JOBS=4 ./scripts/build_mplayer.sh --clean
# 不更新 rootfs，只更新编译结果和 sysroot：DEPLOY_ROOTFS=0 ./scripts/build_mplayer.sh --clean
set -euo pipefail

###############################################################################
# MPlayer 1.4 ARM Cross Build Script
# Target: i.MX6ULL / ARMv7 hard-float
#
# Runtime:
#   Audio: ALSA -> ES8388
#   Video: framebuffer /dev/fb0
###############################################################################

export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MPLAYER_SRC="${PROJECT_ROOT}/build/3rdparty/src/MPlayer-1.4"
MPLAYER_BUILD="${PROJECT_ROOT}/build/3rdparty/mplayer-1.4-arm"
MPLAYER_STAGE="${PROJECT_ROOT}/build/3rdparty/mplayer-1.4-stage"

SYSROOT="${PROJECT_ROOT}/build/sysroot"
ROOTFS="${PROJECT_ROOT}/deploy/nfs/rootfs"

JOBS="${JOBS:-$(nproc)}"
DEPLOY_ROOTFS="${DEPLOY_ROOTFS:-1}"

TARGET_PREFIX="/usr"
HOST_CC="${HOST_CC:-gcc}"
TARGET_TRIPLE="arm-linux-gnueabihf"

###############################################################################
# Functions
###############################################################################

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
    echo "  $0 --clean     清理旧 MPlayer 编译和安装结果"
    echo "  $0 --keep      保留旧编译结果"
    echo "  $0 --help      显示帮助"
    echo ""
    echo "Environment:"
    echo "  JOBS=4                 使用 4 个线程编译"
    echo "  DEPLOY_ROOTFS=0        不更新 rootfs"
    echo "  HOST_CC=gcc            指定主机编译器"
}

###############################################################################
# Parse arguments
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
                "是否清理旧 MPlayer 编译和安装结果？[y/N] " answer

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
# Paths
###############################################################################

STAGE_MPLAYER="${MPLAYER_STAGE}/usr/bin/mplayer"
ROOTFS_MPLAYER="${ROOTFS}/usr/bin/mplayer"

echo "======================================"
echo " Build MPlayer 1.4 for i.MX6ULL"
echo "======================================"
echo "Source        : ${MPLAYER_SRC}"
echo "Build         : ${MPLAYER_BUILD}"
echo "Stage         : ${MPLAYER_STAGE}"
echo "Sysroot       : ${SYSROOT}"
echo "Rootfs        : ${ROOTFS}"
echo "Cross         : ${CROSS_COMPILE}"
echo "Target        : ${TARGET_TRIPLE}"
echo "Jobs          : ${JOBS}"
echo "Clean         : ${CLEAN}"
echo "Deploy rootfs : ${DEPLOY_ROOTFS}"
echo "======================================"

###############################################################################
# Environment checks
###############################################################################

log_info "Checking environment..."

command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}gcc not found"

command -v "${CROSS_COMPILE}g++" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}g++ not found"

command -v "${CROSS_COMPILE}ar" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ar not found"

command -v "${CROSS_COMPILE}as" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}as not found"

command -v "${CROSS_COMPILE}ranlib" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ranlib not found"

command -v "${CROSS_COMPILE}strip" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}strip not found"

command -v "${HOST_CC}" >/dev/null 2>&1 \
    || die "Host compiler ${HOST_CC} not found"

command -v make >/dev/null 2>&1 \
    || die "make not found"

[ -f "${MPLAYER_SRC}/configure" ] \
    || die "MPlayer configure not found: ${MPLAYER_SRC}/configure"

[ -f "${SYSROOT}/usr/include/alsa/asoundlib.h" ] \
    || die "ALSA headers not found: ${SYSROOT}/usr/include/alsa/asoundlib.h"

[ -e "${SYSROOT}/usr/lib/libasound.so" ] \
    || die "ALSA library not found: ${SYSROOT}/usr/lib/libasound.so"

[ -f "${SYSROOT}/usr/include/zlib.h" ] \
    || die "zlib headers not found: ${SYSROOT}/usr/include/zlib.h"

[ -e "${SYSROOT}/usr/lib/libz.so" ] \
    || die "zlib library not found: ${SYSROOT}/usr/lib/libz.so"

[ -d "${ROOTFS}" ] \
    || die "Rootfs not found: ${ROOTFS}"

###############################################################################
# Path safety checks
###############################################################################

EXPECTED_BUILD="${PROJECT_ROOT}/build/3rdparty/mplayer-1.4-arm"
EXPECTED_STAGE="${PROJECT_ROOT}/build/3rdparty/mplayer-1.4-stage"

[ "${MPLAYER_BUILD}" = "${EXPECTED_BUILD}" ] \
    || die "Unsafe MPLAYER_BUILD path: ${MPLAYER_BUILD}"

[ "${MPLAYER_STAGE}" = "${EXPECTED_STAGE}" ] \
    || die "Unsafe MPLAYER_STAGE path: ${MPLAYER_STAGE}"

###############################################################################
# Clean old build
###############################################################################

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old MPlayer build and staging..."

    rm -rf -- "${MPLAYER_BUILD}"
    rm -rf -- "${MPLAYER_STAGE}"
fi

mkdir -p "${MPLAYER_BUILD}"
mkdir -p "${MPLAYER_STAGE}"

###############################################################################
# Copy source to independent build directory
###############################################################################

if [ ! -f "${MPLAYER_BUILD}/configure" ]; then
    log_info "Copying MPlayer source to build directory..."
    cp -a "${MPLAYER_SRC}/." "${MPLAYER_BUILD}/"
fi

###############################################################################
# Cross compiler environment
###############################################################################

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export AR="${CROSS_COMPILE}ar"
export AS="${CROSS_COMPILE}as"
export LD="${CROSS_COMPILE}ld"
export RANLIB="${CROSS_COMPILE}ranlib"
export STRIP="${CROSS_COMPILE}strip"

export CPPFLAGS="--sysroot=${SYSROOT} -I${SYSROOT}/usr/include"

export CFLAGS="--sysroot=${SYSROOT} -O2 -fPIC"

export CXXFLAGS="--sysroot=${SYSROOT} -O2 -fPIC"

export LDFLAGS="--sysroot=${SYSROOT} \
-L${SYSROOT}/usr/lib \
-Wl,-rpath-link,${SYSROOT}/usr/lib \
-lasound -lz -lm -lpthread"

export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${SYSROOT}/lib/pkgconfig"

unset PKG_CONFIG_PATH

###############################################################################
# Read configure supported options
###############################################################################

cd "${MPLAYER_BUILD}"

log_info "Checking MPlayer configure options..."

CONFIGURE_HELP="$("${MPLAYER_BUILD}/configure" --help 2>&1 || true)"

add_option_if_supported()
{
    local option="$1"

    if grep -Eq \
        "(^|[[:space:]])${option}([[:space:]=]|$)" \
        <<< "${CONFIGURE_HELP}"; then

        CONFIGURE_ARGS+=( "${option}" )
    else
        log_warn "Skipping unsupported option: ${option}"
    fi
}

###############################################################################
# Configure arguments
###############################################################################

CONFIGURE_ARGS=(
    "--prefix=${TARGET_PREFIX}"
    "--cc=${CC}"
    "--host-cc=${HOST_CC}"
    "--as=${AS}"
    "--ar=${AR}"
    "--enable-cross-compile"
    "--target=${TARGET_TRIPLE}"
    "--extra-cflags=${CPPFLAGS} ${CFLAGS}"
    "--extra-ldflags=${LDFLAGS}"
)

###############################################################################
# ALSA verification
###############################################################################

log_info "Checking ALSA development files..."

if [ ! -f "${SYSROOT}/usr/include/alsa/asoundlib.h" ]; then
    die "ALSA header is missing"
fi

if [ ! -e "${SYSROOT}/usr/lib/libasound.so" ]; then
    die "libasound.so is missing"
fi

log_info "ALSA headers and library found"
log_info "MPlayer will detect ALSA automatically"

# MPlayer 1.4 不强制传递 --enable-alsa，
# 因为该版本 configure 可能没有这个选项。
#
# 这里不添加：
#   --enable-alsa
#
# ALSA 通过头文件、libasound.so 和链接参数自动检测。

###############################################################################
# Optional features
###############################################################################

# LCD framebuffer 输出
add_option_if_supported "--enable-fbdev"

# 不使用 X11、OpenGL 和桌面音频后端
add_option_if_supported "--disable-x11"
add_option_if_supported "--disable-xv"
add_option_if_supported "--disable-gl"
add_option_if_supported "--disable-vdpau"
add_option_if_supported "--disable-vaapi"
add_option_if_supported "--disable-sdl"
add_option_if_supported "--disable-jack"
add_option_if_supported "--disable-pulse"
add_option_if_supported "--disable-ossaudio"

# 不使用 DVD、电视和 GUI 功能
add_option_if_supported "--disable-dvdnav"
add_option_if_supported "--disable-dvdread"
add_option_if_supported "--disable-tv"
add_option_if_supported "--disable-radio"
add_option_if_supported "--disable-gui"

# 只生成播放器，不生成 mencoder
add_option_if_supported "--disable-mencoder"

# i.MX6ULL 固定为 ARMv7，关闭运行时 CPU 自动检测
add_option_if_supported "--disable-runtime-cpudetection"

###############################################################################
# Configure
###############################################################################

log_info "Configuring MPlayer..."

"${MPLAYER_BUILD}/configure" "${CONFIGURE_ARGS[@]}"

log_info "MPlayer configuration completed"

###############################################################################
# Check configure result
###############################################################################

log_info "Checking ALSA configure result..."

ALSA_RESULT=""

if [ -f "${MPLAYER_BUILD}/config.log" ]; then
    ALSA_RESULT="$(
        grep -Ei \
        "checking for.*alsa|checking for.*asound|alsa.*yes|asound.*yes|HAVE_ALSA|CONFIG_ALSA" \
        "${MPLAYER_BUILD}/config.log" \
        2>/dev/null \
        | tail -n 20 || true
    )"
fi

if [ -f "${MPLAYER_BUILD}/config.mak" ]; then
    ALSA_RESULT="${ALSA_RESULT}
$(
    grep -Ei \
    "ALSA|ASOUND|CONFIG_ALSA" \
    "${MPLAYER_BUILD}/config.mak" \
    2>/dev/null \
    | tail -n 20 || true
)"
fi

echo "${ALSA_RESULT}"

if ! grep -Eiq \
    "alsa.*(yes|1)|asound.*(yes|1)|HAVE_ALSA|CONFIG_ALSA" \
    <<< "${ALSA_RESULT}"; then

    log_warn "ALSA was not clearly detected by MPlayer configure"
    log_warn "MPlayer may be built without ALSA output"
    log_warn "Check: ${MPLAYER_BUILD}/config.log"
fi

###############################################################################
# Build
###############################################################################

log_info "Building MPlayer..."

make -j"${JOBS}"

[ -f "${MPLAYER_BUILD}/mplayer" ] \
    || die "MPlayer binary was not generated"

log_info "MPlayer build completed"

###############################################################################
# Install to staging
###############################################################################

log_info "Installing MPlayer to staging..."

make -j1 install \
    DESTDIR="${MPLAYER_STAGE}" \
    || log_warn "make install returned an error"

###############################################################################
# Ensure staging binary exists
###############################################################################

if [ ! -f "${STAGE_MPLAYER}" ]; then
    log_warn "MPlayer was not found in staging"
    log_info "Installing MPlayer binary manually"

    mkdir -p "${MPLAYER_STAGE}/usr/bin"

    install -m 0755 \
        "${MPLAYER_BUILD}/mplayer" \
        "${STAGE_MPLAYER}"
fi

[ -f "${STAGE_MPLAYER}" ] \
    || die "MPlayer staging binary not found"

###############################################################################
# Deploy MPlayer to rootfs
###############################################################################

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying MPlayer to rootfs..."

    mkdir -p "${ROOTFS}/usr/bin"

    install -m 0755 \
        "${STAGE_MPLAYER}" \
        "${ROOTFS_MPLAYER}"

    if [ -d "${MPLAYER_STAGE}/etc/mplayer" ]; then
        mkdir -p "${ROOTFS}/etc"

        rm -rf -- "${ROOTFS}/etc/mplayer"

        cp -a \
            "${MPLAYER_STAGE}/etc/mplayer" \
            "${ROOTFS}/etc/"
    fi

    if [ -d "${MPLAYER_STAGE}/usr/share/mplayer" ]; then
        mkdir -p "${ROOTFS}/usr/share"

        rm -rf -- "${ROOTFS}/usr/share/mplayer"

        cp -a \
            "${MPLAYER_STAGE}/usr/share/mplayer" \
            "${ROOTFS}/usr/share/"
    fi

    log_info "MPlayer deployed to ${ROOTFS_MPLAYER}"
else
    log_warn "DEPLOY_ROOTFS=0, rootfs was not modified"
fi

###############################################################################
# Final result
###############################################################################

echo ""
echo "======================================"
echo " MPlayer 1.4 Build Finished"
echo "======================================"

echo ""
echo "Staging binary:"
ls -lh "${STAGE_MPLAYER}"

echo ""
echo "Rootfs binary:"
if [ -f "${ROOTFS_MPLAYER}" ]; then
    ls -lh "${ROOTFS_MPLAYER}"
else
    echo "not deployed"
fi

echo ""
echo "Binary type:"
file "${STAGE_MPLAYER}" || true

echo ""
echo "MPlayer configure summary:"
grep -Ei \
"ALSA|ASOUND|FBDEV|X11|XV|SDL|PULSE|JACK|OSS|MENCODER" \
"${MPLAYER_BUILD}/config.mak" \
2>/dev/null \
|| true

echo ""
echo "[INFO] DONE!"