#!/bin/bash

# 使用方式 运行时询问是否清理：
# cd /home/pointer/imx6ull/projects/imx6ull-nxp-bsp
# ./scripts/build_QT_full.sh
# 直接清理后全新编译：./scripts/build_QT_full.sh --clean
# 保留旧目录： ./scripts/build_QT_full.sh --keep
# 不更新 rootfs： DEPLOY_ROOTFS=0 ./scripts/build_QT_full.sh --clean

set -euo pipefail

###############################################################################
# Qt 5.12.9 Full Cross Build
# Target: i.MX6ULL / ARMv7 hard-float
###############################################################################

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

QT_SRC="${PROJECT_ROOT}/build/3rdparty/src/qt-everywhere-src-5.12.9"
QT_BUILD="${PROJECT_ROOT}/build/3rdparty/qt5-arm"
QT_STAGE="${PROJECT_ROOT}/build/3rdparty/qt5-staging"
SYSROOT="${PROJECT_ROOT}/build/sysroot"
ROOTFS="${PROJECT_ROOT}/deploy/nfs/rootfs"
CROSS_BIN="${PROJECT_ROOT}/build/3rdparty/cross-bin"

TARGET_PREFIX="/usr/local/qt5"

# Qt 实际安装目录
QT_INSTALL="${QT_STAGE}${TARGET_PREFIX}"

# Qt 主机工具目录，例如 qmake、moc、uic
QT_HOST="${QT_STAGE}/host"

# sysroot 中的 Qt 目录
SYSROOT_QT="${SYSROOT}${TARGET_PREFIX}"

# rootfs 中的 Qt 目录
ROOTFS_QT="${ROOTFS}${TARGET_PREFIX}"

JOBS="${JOBS:-$(nproc)}"
SKIP_QTWEBENGINE="${SKIP_QTWEBENGINE:-1}"
DEPLOY_ROOTFS="${DEPLOY_ROOTFS:-1}"

XPLATFORM="linux-arm-gnueabi-g++"

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
    echo "  $0 --clean     清理旧构建、旧安装和 rootfs Qt"
    echo "  $0 --keep      保留旧构建目录"
    echo ""
    echo "Environment:"
    echo "  JOBS=4                 使用 4 个线程编译"
    echo "  DEPLOY_ROOTFS=0        不更新 rootfs"
    echo "  SKIP_QTWEBENGINE=0     尝试编译 QtWebEngine"
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
                "是否清理旧 Qt 构建、staging、sysroot 和 rootfs Qt？[y/N] " \
                answer

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
# 输出环境
###############################################################################

echo "======================================"
echo " Build Qt 5.12.9 Full Modules"
echo "======================================"
echo "Qt Source      : ${QT_SRC}"
echo "Qt Build       : ${QT_BUILD}"
echo "Qt Stage       : ${QT_STAGE}"
echo "Qt Install     : ${QT_INSTALL}"
echo "Qt Host Tools  : ${QT_HOST}"
echo "Sysroot        : ${SYSROOT}"
echo "Sysroot Qt     : ${SYSROOT_QT}"
echo "Rootfs         : ${ROOTFS}"
echo "Rootfs Qt      : ${ROOTFS_QT}"
echo "Jobs           : ${JOBS}"
echo "Clean           : ${CLEAN}"
echo "Deploy rootfs  : ${DEPLOY_ROOTFS}"
echo "======================================"

###############################################################################
# 环境检查
###############################################################################

log_info "Checking build environment..."

command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1 \
    || die "arm-linux-gnueabihf-gcc not found"

command -v arm-linux-gnueabihf-g++ >/dev/null 2>&1 \
    || die "arm-linux-gnueabihf-g++ not found"

command -v make >/dev/null 2>&1 \
    || die "make not found"

if command -v python >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python)"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python3)"
else
    die "Python is required to build QtQml. Install python3 first."
fi

export PYTHON="${PYTHON_CMD}"

log_info "Host Python: ${PYTHON_CMD}"
"${PYTHON_CMD}" --version

[ -f "${QT_SRC}/configure" ] \
    || die "Qt source not found: ${QT_SRC}/configure"

[ -f "${SYSROOT}/usr/include/stdio.h" ] \
    || die "Sysroot headers not found"

[ -f "${SYSROOT}/usr/lib/crt1.o" ] \
    || die "Sysroot crt1.o not found"

[ -d "${ROOTFS}" ] \
    || die "Rootfs not found: ${ROOTFS}"

###############################################################################
# 路径安全检查
###############################################################################

[ "${QT_BUILD}" = "${PROJECT_ROOT}/build/3rdparty/qt5-arm" ] \
    || die "Unsafe QT_BUILD path"

[ "${QT_STAGE}" = "${PROJECT_ROOT}/build/3rdparty/qt5-staging" ] \
    || die "Unsafe QT_STAGE path"

[ "${SYSROOT_QT}" = "${PROJECT_ROOT}/build/sysroot/usr/local/qt5" ] \
    || die "Unsafe SYSROOT_QT path"

[ "${ROOTFS_QT}" = "${PROJECT_ROOT}/deploy/nfs/rootfs/usr/local/qt5" ] \
    || die "Unsafe ROOTFS_QT path"

###############################################################################
# 清理旧文件
###############################################################################

if [ "${CLEAN}" = "1" ]; then
    log_info "Removing old Qt build and installation..."

    rm -rf -- "${QT_BUILD}"
    rm -rf -- "${QT_STAGE}"
    rm -rf -- "${SYSROOT_QT}"
    rm -rf -- "${ROOTFS_QT}"
fi

mkdir -p "${QT_BUILD}"
mkdir -p "${QT_STAGE}"
mkdir -p "${CROSS_BIN}"

###############################################################################
# 建立 Qt 需要的 arm-linux-gnueabi 工具别名
###############################################################################

log_info "Preparing compiler aliases..."

for tool in \
    gcc g++ ar as ld nm objcopy objdump ranlib strip readelf strings \
    addr2line size elfedit gcov gcov-dump gcov-tool
do
    real_tool="arm-linux-gnueabihf-${tool}"
    alias_tool="arm-linux-gnueabi-${tool}"

    if command -v "${real_tool}" >/dev/null 2>&1; then
        ln -sfn \
            "$(command -v "${real_tool}")" \
            "${CROSS_BIN}/${alias_tool}"
    fi
done

export PATH="${CROSS_BIN}:${PATH}"

command -v arm-linux-gnueabi-g++ >/dev/null 2>&1 \
    || die "arm-linux-gnueabi-g++ alias not found"

###############################################################################
# pkg-config 交叉编译配置
###############################################################################

export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig:${SYSROOT}/lib/arm-linux-gnueabihf/pkgconfig"

unset PKG_CONFIG_PATH

###############################################################################
# Qt 配置参数
###############################################################################

CONFIGURE_ARGS=(
    -release
    -opensource
    -confirm-license

    # 目标板运行时路径
    -prefix "${TARGET_PREFIX}"

    # 主机实际安装路径，关键参数
    -extprefix "${QT_INSTALL}"

    # 主机工具安装路径
    -hostprefix "${QT_HOST}"

    -xplatform "${XPLATFORM}"
    -device-option CROSS_COMPILE=arm-linux-gnueabi-
    -sysroot "${SYSROOT}"

    -nomake examples
    -nomake tests

    -no-fontconfig
    -no-opengl
    -no-xcb
    -no-dbus
    -no-icu
    -no-cups

    -qt-zlib
    -qt-pcre
    -qt-libpng
    -qt-libjpeg
    -qt-freetype
)

if [ "${SKIP_QTWEBENGINE}" = "1" ] &&
   [ -d "${QT_SRC}/qtwebengine" ]; then
    log_warn "Skipping QtWebEngine"
    CONFIGURE_ARGS+=( -skip qtwebengine )
fi

if [ -d "${QT_SRC}/qtwayland" ]; then
    log_warn "Skipping QtWayland"
    CONFIGURE_ARGS+=( -skip qtwayland )
fi

if [ -f "${SYSROOT}/usr/include/alsa/asoundlib.h" ]; then
    log_info "ALSA headers found, enabling ALSA support"
    CONFIGURE_ARGS+=( -alsa )
else
    log_warn "ALSA headers not found"
    log_warn "QtMultimedia ALSA backend will not be enabled"
fi

###############################################################################
# 配置
###############################################################################

cd "${QT_BUILD}"

log_info "Configuring Qt full source tree..."

"${QT_SRC}/configure" "${CONFIGURE_ARGS[@]}"

log_info "Qt configuration completed"

###############################################################################
# 全量编译
###############################################################################

log_info "Building Qt..."

make -j"${JOBS}"

log_info "Qt build completed"

###############################################################################
# 安装到 QT_STAGE/usr/local/qt5
###############################################################################

log_info "Installing Qt to staging..."

# 注意：这里不能再使用 INSTALL_ROOT
# -extprefix 已经指定了最终安装目录
make -j1 install

###############################################################################
# 检查安装结果
###############################################################################

echo "Checking Qt installation:"
echo "QT_INSTALL=${QT_INSTALL}"

[ -d "${QT_INSTALL}" ] \
    || die "Qt installation directory not found: ${QT_INSTALL}"

[ -d "${QT_INSTALL}/lib" ] \
    || die "Qt lib directory not found: ${QT_INSTALL}/lib"

[ -f "${QT_INSTALL}/lib/libQt5Core.so.5" ] \
    || die "libQt5Core.so.5 not found"

[ -f "${QT_INSTALL}/lib/libQt5Gui.so.5" ] \
    || die "libQt5Gui.so.5 not found"

[ -f "${QT_INSTALL}/lib/libQt5Widgets.so.5" ] \
    || die "libQt5Widgets.so.5 not found"

if [ -f "${QT_INSTALL}/lib/libQt5Multimedia.so.5" ]; then
    log_info "QtMultimedia installed"
else
    log_warn "QtMultimedia library not found"
fi

if [ -f "${QT_INSTALL}/lib/libQt5MultimediaWidgets.so.5" ]; then
    log_info "QtMultimediaWidgets installed"
else
    log_warn "QtMultimediaWidgets library not found"
fi

[ -f "${QT_INSTALL}/plugins/platforms/libqlinuxfb.so" ] \
    || die "libqlinuxfb.so not found"

###############################################################################
# 更新交叉编译 sysroot
###############################################################################

log_info "Updating sysroot Qt files..."

mkdir -p "${SYSROOT_QT}"

for item in include lib mkspecs plugins qml translations
do
    if [ -e "${QT_INSTALL}/${item}" ]; then
        rm -rf -- "${SYSROOT_QT:?}/${item}"
        cp -a \
            "${QT_INSTALL}/${item}" \
            "${SYSROOT_QT}/"
    fi
done

###############################################################################
# 更新 rootfs
###############################################################################

if [ "${DEPLOY_ROOTFS}" = "1" ]; then
    log_info "Deploying Qt runtime to rootfs..."

    mkdir -p "${ROOTFS_QT}"

    # 开发板只需要运行时文件
    for item in lib plugins qml translations
    do
        if [ -e "${QT_INSTALL}/${item}" ]; then
            rm -rf -- "${ROOTFS_QT:?}/${item}"
            cp -a \
                "${QT_INSTALL}/${item}" \
                "${ROOTFS_QT}/"
        fi
    done

    # 不复制 bin/include/mkspecs 到开发板
    log_info "Qt runtime deployed to: ${ROOTFS_QT}"
else
    log_info "DEPLOY_ROOTFS=0, rootfs not modified"
fi

###############################################################################
# 最终检查
###############################################################################

echo ""
echo "======================================"
echo " Qt 5.12.9 Full Build Finished"
echo "======================================"

echo ""
echo "Staging Qt:"
echo "${QT_INSTALL}"

echo ""
echo "Rootfs Qt:"
echo "${ROOTFS_QT}"

echo ""
echo "Qt libraries:"
find "${QT_INSTALL}/lib" \
    -maxdepth 1 \
    -type f \
    | grep -E "libQt5(Core|Gui|Widgets|Multimedia)" \
    || true

echo ""
echo "Qt platform plugins:"
find "${QT_INSTALL}/plugins" \
    -type f \
    | grep -E "libqlinuxfb|multimedia|audio|video" \
    || true

echo ""
echo "[INFO] DONE!"