#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# libjpeg-turbo 2.1.5.1 ARM Cross Build Script
# Target: i.MX6ULL / ARMv7 hard-float
#
# 使用：
#   ./scripts/build_libjpeg_turbo.sh --clean
#   ./scripts/build_libjpeg_turbo.sh --keep
#   JOBS=4 ./scripts/build_libjpeg_turbo.sh --clean
#   DEPLOY_ROOTFS=0 ./scripts/build_libjpeg_turbo.sh --clean
###############################################################################

export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

JPEG_VERSION="2.1.5.1"

JPEG_SRC="${PROJECT_ROOT}/build/3rdparty/src/libjpeg-turbo-${JPEG_VERSION}"
JPEG_BUILD="${PROJECT_ROOT}/build/3rdparty/libjpeg-turbo-${JPEG_VERSION}-arm"
JPEG_STAGE="${PROJECT_ROOT}/build/3rdparty/libjpeg-turbo-${JPEG_VERSION}-stage"

SYSROOT="${PROJECT_ROOT}/build/sysroot"
ROOTFS="${PROJECT_ROOT}/deploy/nfs/rootfs"

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
                "是否清理旧 libjpeg-turbo 构建和安装结果？[y/N] " answer

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
echo " Build libjpeg-turbo ${JPEG_VERSION}"
echo "======================================"
echo "Source        : ${JPEG_SRC}"
echo "Build         : ${JPEG_BUILD}"
echo "Stage         : ${JPEG_STAGE}"
echo "Sysroot       : ${SYSROOT}"
echo "Rootfs        : ${ROOTFS}"
echo "Cross         : ${CROSS_COMPILE}"
echo "Jobs          : ${JOBS}"
echo "Clean         : ${CLEAN}"
echo "Deploy rootfs : ${DEPLOY_ROOTFS}"
echo "======================================"

###############################################################################
# 基础环境检查
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

command -v make >/dev/null 2>&1 \
    || die "make not found"

command -v cmake >/dev/null 2>&1 \
    || die "cmake not found"

[ -d "${JPEG_SRC}" ] \
    || die "libjpeg-turbo source directory not found: ${JPEG_SRC}"

[ -f "${JPEG_SRC}/CMakeLists.txt" ] \
    || die "CMakeLists.txt not found: ${JPEG_SRC}/CMakeLists.txt"

[ -f "${JPEG_SRC}/jpeglib.h" ] \
    || die "jpeglib.h not found: ${JPEG_SRC}/jpeglib.h"

[ -d "${SYSROOT}" ] \
    || die "sysroot not found: ${SYSROOT}"

[ -d "${ROOTFS}" ] \
    || die "rootfs not found: ${ROOTFS}"

###############################################################################
# 获取绝对工具路径
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

EXPECTED_BUILD="${PROJECT_ROOT}/build/3rdparty/libjpeg-turbo-${JPEG_VERSION}-arm"
EXPECTED_STAGE="${PROJECT_ROOT}/build/3rdparty/libjpeg-turbo-${JPEG_VERSION}-stage"

[ "${JPEG_BUILD}" = "${EXPECTED_BUILD}" ] \
    || die "Unsafe JPEG_BUILD path"

[ "${JPEG_STAGE}" = "${EXPECTED_STAGE}" ] \
    || die "Unsafe JPEG_STAGE path"

[ "${SYSROOT}" = "${PROJECT_ROOT}/build/sysroot" ] \
    || die "Unsafe SYSROOT path"

[ "${ROOTFS}" = "${PROJECT_ROOT}/deploy/nfs/rootfs" ] \
    || die "Unsafe ROOTFS path"

###############################################################################
# 清理
###############################################################################

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old libjpeg-turbo build and stage directories..."

    rm -rf -- "${JPEG_BUILD}"
    rm -rf -- "${JPEG_STAGE}"
fi

mkdir -p "${JPEG_BUILD}"
mkdir -p "${JPEG_STAGE}"

###############################################################################
# CMake 配置
###############################################################################

cd "${JPEG_BUILD}"

log_info "Configuring libjpeg-turbo with CMake..."

cmake "${JPEG_SRC}" \
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
    -DCMAKE_C_FLAGS="--sysroot=${SYSROOT} -O2 -fPIC" \
    -DCMAKE_EXE_LINKER_FLAGS="--sysroot=${SYSROOT}" \
    -DCMAKE_SHARED_LINKER_FLAGS="--sysroot=${SYSROOT}" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=/usr/lib \
    -DCMAKE_INSTALL_INCLUDEDIR=/usr/include \
    -DENABLE_SHARED=ON \
    -DENABLE_STATIC=OFF \
    -DWITH_SIMD=OFF \
    -DWITH_TURBOJPEG=ON

log_info "CMake configuration completed"

###############################################################################
# 显示安装路径
###############################################################################

echo ""
echo "CMake install configuration:"
grep -E \
    "CMAKE_INSTALL_(PREFIX|LIBDIR|INCLUDEDIR)" \
    CMakeCache.txt \
    || true
echo ""

###############################################################################
# 编译
###############################################################################

log_info "Building libjpeg-turbo..."

cmake --build . --parallel "${JOBS}"

log_info "libjpeg-turbo build completed"

###############################################################################
# 安装到 staging
###############################################################################

log_info "Installing libjpeg-turbo to staging..."

DESTDIR="${JPEG_STAGE}" \
cmake --install . \
    --config Release

###############################################################################
# 规范化 staging 目录
###############################################################################

EXPECTED_STAGE_INC="${JPEG_STAGE}/usr/include"
EXPECTED_STAGE_LIB="${JPEG_STAGE}/usr/lib"

mkdir -p "${EXPECTED_STAGE_INC}"
mkdir -p "${EXPECTED_STAGE_LIB}"

ACTUAL_HEADER_FILE="$(
    find "${JPEG_STAGE}" \
        -type f \
        -name "jpeglib.h" \
        -print -quit
)"

ACTUAL_LIBRARY_FILE="$(
    find "${JPEG_STAGE}" \
        -type f \
        -name "libjpeg.so.*" \
        -print -quit
)"

[ -n "${ACTUAL_HEADER_FILE}" ] \
    || die "jpeglib.h not found after installation"

[ -n "${ACTUAL_LIBRARY_FILE}" ] \
    || die "libjpeg.so runtime library not found after installation"

ACTUAL_HEADER_DIR="$(dirname "${ACTUAL_HEADER_FILE}")"
ACTUAL_LIBRARY_DIR="$(dirname "${ACTUAL_LIBRARY_FILE}")"

log_info "Actual staging include: ${ACTUAL_HEADER_DIR}"
log_info "Actual staging lib    : ${ACTUAL_LIBRARY_DIR}"

if [ "${ACTUAL_HEADER_DIR}" != "${EXPECTED_STAGE_INC}" ]; then
    log_warn "Normalizing staging include directory..."

    cp -a \
        "${ACTUAL_HEADER_DIR}/." \
        "${EXPECTED_STAGE_INC}/"
fi

if [ "${ACTUAL_LIBRARY_DIR}" != "${EXPECTED_STAGE_LIB}" ]; then
    log_warn "Normalizing staging library directory..."

    cp -a \
        "${ACTUAL_LIBRARY_DIR}/." \
        "${EXPECTED_STAGE_LIB}/"
fi

###############################################################################
# staging 检查
###############################################################################

[ -f "${EXPECTED_STAGE_INC}/jpeglib.h" ] \
    || die "jpeglib.h not found in normalized staging"

find "${EXPECTED_STAGE_LIB}" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    -name "libjpeg.so*" \
    | grep -q . \
    || die "libjpeg.so not found in normalized staging"

###############################################################################
# 更新 sysroot
###############################################################################

log_info "Updating cross-compilation sysroot..."

mkdir -p "${SYSROOT}/usr/include"
mkdir -p "${SYSROOT}/usr/lib"

cp -a \
    "${EXPECTED_STAGE_INC}/." \
    "${SYSROOT}/usr/include/"

cp -a \
    "${EXPECTED_STAGE_LIB}/." \
    "${SYSROOT}/usr/lib/"

###############################################################################
# 更新 rootfs
###############################################################################

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying libjpeg runtime to rootfs..."

    mkdir -p "${ROOTFS}/usr/lib"

    find "${EXPECTED_STAGE_LIB}" \
        -maxdepth 1 \
        \( -type f -o -type l \) \
        \( -name "libjpeg.so*" -o -name "libturbojpeg.so*" \) \
        -exec cp -a {} "${ROOTFS}/usr/lib/" \;

    log_info "libjpeg runtime deployed"
else
    log_warn "DEPLOY_ROOTFS=0, rootfs was not modified"
fi

###############################################################################
# 目标架构检查
###############################################################################

JPEG_RUNTIME_LIB="$(
    find "${EXPECTED_STAGE_LIB}" \
        -maxdepth 1 \
        -type f \
        -name "libjpeg.so.*" \
        -print -quit
)"

if [ -n "${JPEG_RUNTIME_LIB}" ]; then
    log_info "Checking target library architecture..."

    "${CROSS_READELF}" -h "${JPEG_RUNTIME_LIB}" \
        | grep -E "Class|Machine"
fi

###############################################################################
# 最终检查
###############################################################################

echo ""
echo "======================================"
echo " libjpeg-turbo Build Finished"
echo "======================================"

echo ""
echo "Staging headers:"
find "${EXPECTED_STAGE_INC}" \
    -maxdepth 1 \
    -type f \
    \( -name "jconfig.h" \
    -o -name "jmorecfg.h" \
    -o -name "jpeglib.h" \) \
    -print

echo ""
echo "Staging libraries:"
find "${EXPECTED_STAGE_LIB}" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    \( -name "libjpeg.so*" -o -name "libturbojpeg.so*" \) \
    -print

echo ""
echo "Sysroot libraries:"
find "${SYSROOT}/usr/lib" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    \( -name "libjpeg.so*" -o -name "libturbojpeg.so*" \) \
    -print

echo ""
echo "Rootfs libraries:"
find "${ROOTFS}/usr/lib" \
    -maxdepth 1 \
    \( -type f -o -type l \) \
    \( -name "libjpeg.so*" -o -name "libturbojpeg.so*" \) \
    -print

echo ""
echo "[INFO] DONE!"