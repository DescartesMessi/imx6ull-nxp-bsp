#!/bin/bash

set -euo pipefail

###############################################################################
# Qt 5.12.9 ARM QtBase Build Script
# Target : i.MX6ULL / ARMv7 hard-float
###############################################################################

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

QT_SRC="${PROJECT_ROOT}/build/3rdparty/src/qt-everywhere-src-5.12.9"
QT_BUILD="${PROJECT_ROOT}/build/3rdparty/qt5-arm"
QT_STAGE="${PROJECT_ROOT}/build/3rdparty/qt5-staging"
SYSROOT="${PROJECT_ROOT}/build/sysroot"

CROSS_BIN="${PROJECT_ROOT}/build/3rdparty/cross-bin"
JOBS="${JOBS:-$(nproc)}"

TARGET_PREFIX="/usr/local/qt5"
XPLATFORM="linux-arm-gnueabi-g++"

log_info()
{
    echo -e "\033[32m[INFO]\033[0m $1"
}

die()
{
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}

echo "======================================"
echo " Build Qt 5.12.9 for i.MX6ULL"
echo "======================================"
echo "Qt Source : ${QT_SRC}"
echo "Qt Build  : ${QT_BUILD}"
echo "Qt Stage  : ${QT_STAGE}"
echo "Sysroot   : ${SYSROOT}"
echo "Jobs      : ${JOBS}"
echo "======================================"

###############################################################################
# Check environment
###############################################################################

log_info "Checking environment..."

command -v arm-linux-gnueabihf-gcc \
    >/dev/null 2>&1 \
    || die "arm-linux-gnueabihf-gcc not found"

command -v arm-linux-gnueabihf-g++ \
    >/dev/null 2>&1 \
    || die "arm-linux-gnueabihf-g++ not found"

[ -f "${QT_SRC}/qtbase/configure" ] \
    || die "Qt source not found: ${QT_SRC}/qtbase/configure"

[ -f "${SYSROOT}/usr/include/stdio.h" ] \
    || die "Sysroot headers not found"

[ -f "${SYSROOT}/usr/lib/crt1.o" ] \
    || die "Sysroot crt1.o not found"

###############################################################################
# Clean old failed configuration
#
# Run with:
# CLEAN_BUILD=1 ./scripts/build_QT.sh
###############################################################################

if [ "${CLEAN_BUILD:-0}" = "1" ]; then

    if [ "${QT_BUILD}" != "${PROJECT_ROOT}/build/3rdparty/qt5-arm" ]; then
        die "Unsafe QT_BUILD path: ${QT_BUILD}"
    fi

    log_info "Removing old Qt build directory..."
    rm -rf "${QT_BUILD}"
fi

if [ -f "${QT_BUILD}/.qmake.cache" ]; then
    die "Old Qt configuration detected.

Run:
CLEAN_BUILD=1 ./scripts/build_QT.sh
"
fi

mkdir -p "${QT_BUILD}"
mkdir -p "${QT_STAGE}"
mkdir -p "${CROSS_BIN}"

###############################################################################
# Create temporary compiler aliases
#
# Qt mkspec expects:
#   arm-linux-gnueabi-g++
#
# Actual compiler is:
#   arm-linux-gnueabihf-g++
###############################################################################

log_info "Preparing temporary ARM compiler aliases..."

for tool in \
    gcc g++ ar as ld nm objcopy objdump ranlib strip readelf strings \
    addr2line size elfedit gcov gcov-dump gcov-tool; do

    REAL_TOOL="arm-linux-gnueabihf-${tool}"
    ALIAS_TOOL="arm-linux-gnueabi-${tool}"

    if command -v "${REAL_TOOL}" >/dev/null 2>&1; then
        ln -sf "$(command -v "${REAL_TOOL}")" \
            "${CROSS_BIN}/${ALIAS_TOOL}"
    fi
done

export PATH="${CROSS_BIN}:${PATH}"

###############################################################################
# pkg-config target configuration
###############################################################################

export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${SYSROOT}/lib/pkgconfig"

unset PKG_CONFIG_PATH

###############################################################################
# Configure QtBase
###############################################################################

cd "${QT_BUILD}"

log_info "Configuring QtBase..."

"${QT_SRC}/qtbase/configure" \
    -release \
    -opensource \
    -confirm-license \
    -prefix "${TARGET_PREFIX}" \
    -xplatform "${XPLATFORM}" \
    -device-option CROSS_COMPILE=arm-linux-gnueabi- \
    -sysroot "${SYSROOT}" \
    -nomake examples \
    -nomake tests \
    -no-opengl \
    -qt-zlib \
    -qt-pcre

log_info "Qt configuration finished"

###############################################################################
# Build
###############################################################################

log_info "Building QtBase..."

make -j"${JOBS}"

log_info "QtBase build finished"

###############################################################################
# Install to staging directory
###############################################################################

log_info "Installing QtBase to staging directory..."

make install INSTALL_ROOT="${QT_STAGE}"

###############################################################################
# Check result
###############################################################################

QT_INSTALL="${QT_STAGE}${SYSROOT}${TARGET_PREFIX}"

[ -d "${QT_INSTALL}/lib" ] \
    || die "Qt lib directory not found"

[ -f "${QT_INSTALL}/lib/libQt5Core.so.5" ] \
    || die "libQt5Core.so.5 not found"

[ -f "${QT_INSTALL}/lib/libQt5Gui.so.5" ] \
    || die "libQt5Gui.so.5 not found"

[ -f "${QT_INSTALL}/lib/libQt5Widgets.so.5" ] \
    || die "libQt5Widgets.so.5 not found"

echo ""
echo "======================================"
echo " QtBase Build Finished"
echo "======================================"

find "${QT_INSTALL}" -maxdepth 3 -type f \
    | grep -E "libQt5(Core|Gui|Widgets)|libqlinuxfb" \
    || true

echo ""
echo "Qt staging directory:"
echo "${QT_INSTALL}"

echo ""
echo "To deploy Qt into rootfs:"
echo "cp -a ${QT_INSTALL} ${PROJECT_ROOT}/deploy/nfs/rootfs/usr/local/"

echo ""
echo "[INFO] DONE!"