#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# MJPG-streamer ARM Cross Build Script
# Target: i.MX6ULL / ARMv7 hard-float
#
# 使用：
#   ./scripts/build_mjpg_streamer.sh --clean
#   ./scripts/build_mjpg_streamer.sh --keep
#   JOBS=4 ./scripts/build_mjpg_streamer.sh --clean
#   DEPLOY_ROOTFS=0 ./scripts/build_mjpg_streamer.sh --clean
###############################################################################

export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MJPG_SRC="${PROJECT_ROOT}/build/3rdparty/src/mjpg-streamer/mjpg-streamer-experimental"
MJPG_BUILD="${PROJECT_ROOT}/build/3rdparty/mjpg-streamer-arm"
MJPG_STAGE="${PROJECT_ROOT}/build/3rdparty/mjpg-streamer-stage"

SYSROOT="${PROJECT_ROOT}/build/sysroot"
ROOTFS="${PROJECT_ROOT}/deploy/nfs/rootfs"

TARGET_PREFIX="/usr/local"

JOBS="${JOBS:-$(nproc)}"
DEPLOY_ROOTFS="${DEPLOY_ROOTFS:-1}"
CLEAN=0

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
    echo "  $0                 运行时询问是否清理"
    echo "  $0 --clean         清理旧构建和 staging"
    echo "  $0 --keep          保留旧构建结果"
    echo "  $0 --help          显示帮助"
    echo ""
    echo "Environment:"
    echo "  JOBS=4             使用 4 个线程"
    echo "  DEPLOY_ROOTFS=0    不更新 rootfs"
    echo "  CROSS_COMPILE=...  指定交叉编译器前缀"
}

###############################################################################
# 参数处理
###############################################################################

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
                "是否清理旧 MJPG-streamer 构建和 staging？[y/N] " answer

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
        die "未知参数：$1"
        ;;
esac

###############################################################################
# 输出配置
###############################################################################

echo "======================================"
echo " Build MJPG-streamer for i.MX6ULL"
echo "======================================"
echo "Source        : ${MJPG_SRC}"
echo "Build         : ${MJPG_BUILD}"
echo "Stage         : ${MJPG_STAGE}"
echo "Sysroot       : ${SYSROOT}"
echo "Rootfs        : ${ROOTFS}"
echo "Target prefix : ${TARGET_PREFIX}"
echo "Cross         : ${CROSS_COMPILE}"
echo "Jobs          : ${JOBS}"
echo "Clean         : ${CLEAN}"
echo "Deploy rootfs : ${DEPLOY_ROOTFS}"
echo "======================================"

###############################################################################
# 环境检查
###############################################################################

log_info "Checking build environment..."

command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}gcc not found"

command -v "${CROSS_COMPILE}ar" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ar not found"

command -v "${CROSS_COMPILE}ranlib" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}ranlib not found"

command -v "${CROSS_COMPILE}strip" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}strip not found"

command -v "${CROSS_COMPILE}readelf" >/dev/null 2>&1 \
    || die "${CROSS_COMPILE}readelf not found"

command -v cmake >/dev/null 2>&1 \
    || die "cmake not found"

command -v make >/dev/null 2>&1 \
    || die "make not found"

[ -d "${MJPG_SRC}" ] \
    || die "MJPG-streamer source directory not found: ${MJPG_SRC}"

[ -f "${MJPG_SRC}/CMakeLists.txt" ] \
    || die "CMakeLists.txt not found: ${MJPG_SRC}/CMakeLists.txt"

[ -f "${MJPG_SRC}/plugins/input_uvc/CMakeLists.txt" ] \
    || die "input_uvc CMakeLists.txt not found"

[ -f "${MJPG_SRC}/plugins/output_http/CMakeLists.txt" ] \
    || die "output_http CMakeLists.txt not found"

[ -f "${SYSROOT}/usr/include/jpeglib.h" ] \
    || die "jpeglib.h not found in sysroot"

[ -e "${SYSROOT}/usr/lib/libjpeg.so" ] \
    || die "libjpeg.so not found in sysroot"

[ -d "${ROOTFS}" ] \
    || die "rootfs not found: ${ROOTFS}"

###############################################################################
# 工具绝对路径
###############################################################################

CROSS_GCC="$(command -v "${CROSS_COMPILE}gcc")"
CROSS_AR="$(command -v "${CROSS_COMPILE}ar")"
CROSS_RANLIB="$(command -v "${CROSS_COMPILE}ranlib")"
CROSS_STRIP="$(command -v "${CROSS_COMPILE}strip")"
CROSS_READELF="$(command -v "${CROSS_COMPILE}readelf")"

log_info "Cross GCC    : ${CROSS_GCC}"
log_info "Cross AR     : ${CROSS_AR}"
log_info "Cross RANLIB : ${CROSS_RANLIB}"
log_info "Cross STRIP  : ${CROSS_STRIP}"
log_info "Cross READELF: ${CROSS_READELF}"

###############################################################################
# 路径安全检查
###############################################################################

EXPECTED_BUILD="${PROJECT_ROOT}/build/3rdparty/mjpg-streamer-arm"
EXPECTED_STAGE="${PROJECT_ROOT}/build/3rdparty/mjpg-streamer-stage"

[ "${MJPG_BUILD}" = "${EXPECTED_BUILD}" ] \
    || die "Unsafe MJPG_BUILD path"

[ "${MJPG_STAGE}" = "${EXPECTED_STAGE}" ] \
    || die "Unsafe MJPG_STAGE path"

[ "${SYSROOT}" = "${PROJECT_ROOT}/build/sysroot" ] \
    || die "Unsafe SYSROOT path"

[ "${ROOTFS}" = "${PROJECT_ROOT}/deploy/nfs/rootfs" ] \
    || die "Unsafe ROOTFS path"

###############################################################################
# 清理
###############################################################################

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old MJPG-streamer build and stage directories..."

    rm -rf -- "${MJPG_BUILD}"
    rm -rf -- "${MJPG_STAGE}"
fi

mkdir -p "${MJPG_BUILD}"
mkdir -p "${MJPG_STAGE}"

###############################################################################
# CMake 配置
###############################################################################

cd "${MJPG_BUILD}"

log_info "Configuring MJPG-streamer with CMake..."

cmake "${MJPG_SRC}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=arm \
    -DCMAKE_C_COMPILER="${CROSS_GCC}" \
    -DCMAKE_AR="${CROSS_AR}" \
    -DCMAKE_RANLIB="${CROSS_RANLIB}" \
    -DCMAKE_STRIP="${CROSS_STRIP}" \
    -DCMAKE_SYSROOT="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="--sysroot=${SYSROOT} -O2 -fPIC -Wno-error" \
    -DCMAKE_EXE_LINKER_FLAGS="--sysroot=${SYSROOT}" \
    -DCMAKE_SHARED_LINKER_FLAGS="--sysroot=${SYSROOT}" \
    -DCMAKE_INSTALL_PREFIX="${TARGET_PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DPLUGIN_INPUT_FILE=OFF \
    -DPLUGIN_INPUT_HTTP=OFF \
    -DPLUGIN_INPUT_OPENCV=OFF \
    -DPLUGIN_INPUT_RASPICAM=OFF \
    -DPLUGIN_INPUT_PTP2=OFF \
    -DPLUGIN_INPUT_UVC=ON \
    -DPLUGIN_OUTPUT_FILE=OFF \
    -DPLUGIN_OUTPUT_HTTP=ON \
    -DPLUGIN_OUTPUT_RTSP=OFF \
    -DPLUGIN_OUTPUT_UDP=OFF \
    -DPLUGIN_OUTPUT_VIEWER=OFF \
    -DPLUGIN_OUTPUT_ZMQSERVER=OFF \
    -DJPEG_LIB="${SYSROOT}/usr/lib/libjpeg.so"

log_info "CMake configuration completed"

echo ""
echo "Enabled plugins:"
grep -E \
    "PLUGIN_(INPUT_UVC|OUTPUT_HTTP)" \
    CMakeCache.txt \
    || true

###############################################################################
# 编译
###############################################################################

log_info "Building MJPG-streamer..."

cmake --build . --parallel "${JOBS}"

log_info "MJPG-streamer build completed"

###############################################################################
# 安装到 staging
###############################################################################

log_info "Installing MJPG-streamer to staging..."

DESTDIR="${MJPG_STAGE}" \
cmake --install . \
    --config Release

###############################################################################
# 目标路径
###############################################################################

STAGE_BIN="${MJPG_STAGE}${TARGET_PREFIX}/bin"
STAGE_PLUGIN="${MJPG_STAGE}${TARGET_PREFIX}/lib/mjpg-streamer"
STAGE_WEB="${MJPG_STAGE}${TARGET_PREFIX}/share/mjpg-streamer/www"

[ -f "${STAGE_BIN}/mjpg_streamer" ] \
    || die "mjpg_streamer binary not found: ${STAGE_BIN}"

[ -f "${STAGE_PLUGIN}/input_uvc.so" ] \
    || die "input_uvc.so not found: ${STAGE_PLUGIN}"

[ -f "${STAGE_PLUGIN}/output_http.so" ] \
    || die "output_http.so not found: ${STAGE_PLUGIN}"

[ -d "${STAGE_WEB}" ] \
    || die "MJPG-streamer web directory not found: ${STAGE_WEB}"

###############################################################################
# 检查目标架构
###############################################################################

log_info "Checking target binary architecture..."

"${CROSS_READELF}" -h "${STAGE_BIN}/mjpg_streamer" \
    | grep -E "Class|Machine"

log_info "Checking input_uvc architecture..."

"${CROSS_READELF}" -h "${STAGE_PLUGIN}/input_uvc.so" \
    | grep -E "Class|Machine"

###############################################################################
# 更新 rootfs
###############################################################################

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying MJPG-streamer to rootfs..."

    ROOTFS_BIN="${ROOTFS}${TARGET_PREFIX}/bin"
    ROOTFS_PLUGIN="${ROOTFS}${TARGET_PREFIX}/lib/mjpg-streamer"
    ROOTFS_WEB="${ROOTFS}/www"

    mkdir -p "${ROOTFS_BIN}"
    mkdir -p "${ROOTFS_PLUGIN}"
    mkdir -p "${ROOTFS_WEB}"

    install -m 0755 \
        "${STAGE_BIN}/mjpg_streamer" \
        "${ROOTFS_BIN}/mjpg_streamer"

    install -m 0755 \
        "${STAGE_PLUGIN}/input_uvc.so" \
        "${ROOTFS_PLUGIN}/input_uvc.so"

    install -m 0755 \
        "${STAGE_PLUGIN}/output_http.so" \
        "${ROOTFS_PLUGIN}/output_http.so"

    cp -a \
        "${STAGE_WEB}/." \
        "${ROOTFS_WEB}/"

    log_info "MJPG-streamer deployed"
else
    log_warn "DEPLOY_ROOTFS=0, rootfs was not modified"
fi

###############################################################################
# 最终检查
###############################################################################

echo ""
echo "======================================"
echo " MJPG-streamer Build Finished"
echo "======================================"

echo ""
echo "Staging executable:"
ls -lh "${STAGE_BIN}/mjpg_streamer"

echo ""
echo "Staging plugins:"
ls -lh \
    "${STAGE_PLUGIN}/input_uvc.so" \
    "${STAGE_PLUGIN}/output_http.so"

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    echo ""
    echo "Rootfs executable:"
    ls -lh "${ROOTFS}/usr/local/bin/mjpg_streamer"

    echo ""
    echo "Rootfs plugins:"
    ls -lh \
        "${ROOTFS}/usr/local/lib/mjpg-streamer/input_uvc.so" \
        "${ROOTFS}/usr/local/lib/mjpg-streamer/output_http.so"

    echo ""
    echo "Rootfs web files:"
    find "${ROOTFS}/www" \
        -maxdepth 2 \
        -type f \
        | head -n 20
fi

echo ""
echo "[INFO] DONE!"