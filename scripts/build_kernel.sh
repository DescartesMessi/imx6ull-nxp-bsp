#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/common.sh"

SRC="$SOURCES_DIR/linux-imx"
OUT="$BUILD_DIR/linux"
LOG="$LOG_DIR/linux-$(date +%Y%m%d-%H%M%S).log"

DTS_NAME="${LINUX_DTB%.dtb}.dts"
DTS_SOURCE="$SRC/arch/arm/boot/dts/$DTS_NAME"
DTS_MAKEFILE="$SRC/arch/arm/boot/dts/Makefile"
DEFCONFIG_PATH="$SRC/arch/arm/configs/$LINUX_DEFCONFIG"

ZIMAGE_PATH="$OUT/arch/arm/boot/zImage"
DTB_PATH="$OUT/arch/arm/boot/dts/$LINUX_DTB"
VMLINUX_PATH="$OUT/vmlinux"
SYSTEM_MAP_PATH="$OUT/System.map"
CONFIG_PATH="$OUT/.config"

fail()
{
    echo "错误：$*" >&2
    exit 1
}

require_command()
{
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1 ||
        fail "找不到命令：$command_name"
}

# ---------------------------------------------------------------------------
# 1. 宿主机和源码预检查
# ---------------------------------------------------------------------------

require_command git
require_command make
require_command sha256sum
require_command tee
require_command find
require_command wc
require_command "${CROSS_COMPILE}gcc"

[[ -d "$SRC/.git" ]] ||
    fail "Linux源码仓库不存在，请先运行 scripts/bootstrap_sources.sh"

[[ -f "$DEFCONFIG_PATH" ]] ||
    fail "找不到Linux配置：arch/arm/configs/$LINUX_DEFCONFIG"

[[ -f "$DTS_SOURCE" ]] ||
    fail "找不到设备树源文件：arch/arm/boot/dts/$DTS_NAME"

grep -qF "$LINUX_DTB" "$DTS_MAKEFILE" ||
    fail "$LINUX_DTB 未加入 arch/arm/boot/dts/Makefile"

SOURCE_STATUS_BEFORE="$(git -C "$SRC" status --porcelain)"

if [[ -n "$SOURCE_STATUS_BEFORE" ]]; then
    echo "Linux源码仓库存在未提交修改：" >&2
    echo "$SOURCE_STATUS_BEFORE" >&2
    fail "为保证官方零修改基线，停止编译"
fi

SOURCE_COMMIT="$(git -C "$SRC" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "$SRC" branch --show-current)"
TOOLCHAIN_VERSION="$("${CROSS_COMPILE}gcc" --version | head -n 1)"

# 使用固定构建身份，便于在开发板上确认这是本项目编译的内核。
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-bsp-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-imx6ull-nxp-bsp}"

mkdir -p "$BUILD_DIR" "$LOG_DIR"

# M0官方基线构建采用完全干净的输出目录。
rm -rf "$OUT"
mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# 2. 配置和编译
# ---------------------------------------------------------------------------

{
    echo "============================================================"
    echo "NXP i.MX6ULL Linux baseline build"
    echo "============================================================"
    echo "Source directory : $SRC"
    echo "Output directory : $OUT"
    echo "Source branch    : $SOURCE_BRANCH"
    echo "Source commit    : $SOURCE_COMMIT"
    echo "Defconfig        : $LINUX_DEFCONFIG"
    echo "Device tree      : $LINUX_DTB"
    echo "Architecture     : $ARCH"
    echo "Cross compiler   : $CROSS_COMPILE"
    echo "Parallel jobs    : $JOBS"
    echo "Toolchain        : $TOOLCHAIN_VERSION"
    echo "Build user       : $KBUILD_BUILD_USER"
    echo "Build host       : $KBUILD_BUILD_HOST"
    echo

    echo "===== Generate kernel configuration ====="

    make \
        -C "$SRC" \
        O="$OUT" \
        ARCH="$ARCH" \
        CROSS_COMPILE="$CROSS_COMPILE" \
        "$LINUX_DEFCONFIG"

    echo
    echo "===== Build zImage, DTBs and modules ====="

    make \
        -C "$SRC" \
        O="$OUT" \
        ARCH="$ARCH" \
        CROSS_COMPILE="$CROSS_COMPILE" \
        -j"$JOBS" \
        zImage \
        dtbs \
        modules

    echo
    echo "===== Verify build artifacts ====="

    [[ -f "$ZIMAGE_PATH" ]] ||
        fail "未生成 zImage"

    [[ -f "$DTB_PATH" ]] ||
        fail "未生成 $LINUX_DTB"

    [[ -f "$VMLINUX_PATH" ]] ||
        fail "未生成 vmlinux"

    [[ -f "$SYSTEM_MAP_PATH" ]] ||
        fail "未生成 System.map"

    [[ -f "$CONFIG_PATH" ]] ||
        fail "未生成 .config"

    KERNEL_RELEASE="$(
        make \
            -s \
            -C "$SRC" \
            O="$OUT" \
            ARCH="$ARCH" \
            CROSS_COMPILE="$CROSS_COMPILE" \
            kernelrelease
    )"

    MODULE_COUNT="$(
        find "$OUT" \
            -type f \
            -name '*.ko' \
            | wc -l
    )"

    echo "Kernel release   : $KERNEL_RELEASE"
    echo "Kernel modules   : $MODULE_COUNT"
    echo

    ls -lh \
        "$ZIMAGE_PATH" \
        "$DTB_PATH" \
        "$VMLINUX_PATH" \
        "$SYSTEM_MAP_PATH" \
        "$CONFIG_PATH"

    # -----------------------------------------------------------------------
    # 3. 生成可移植校验文件
    # -----------------------------------------------------------------------

    (
        cd "$OUT"

        sha256sum \
            arch/arm/boot/zImage \
            "arch/arm/boot/dts/$LINUX_DTB" \
            vmlinux \
            System.map \
            > SHA256SUMS
    )

    cat > "$OUT/BUILD_INFO.txt" <<BUILD_INFO_EOF
NXP_BSP_RELEASE=$NXP_LINUX_REF
SOURCE_BRANCH=$SOURCE_BRANCH
SOURCE_COMMIT=$SOURCE_COMMIT
LINUX_DEFCONFIG=$LINUX_DEFCONFIG
LINUX_DTB=$LINUX_DTB
KERNEL_RELEASE=$KERNEL_RELEASE
ARCH=$ARCH
CROSS_COMPILE=$CROSS_COMPILE
TOOLCHAIN=$TOOLCHAIN_VERSION
KBUILD_BUILD_USER=$KBUILD_BUILD_USER
KBUILD_BUILD_HOST=$KBUILD_BUILD_HOST
MODULE_COUNT=$MODULE_COUNT
BUILD_INFO_EOF

    echo
    echo "===== SHA-256 ====="
    cat "$OUT/SHA256SUMS"

    echo
    echo "===== Build information ====="
    cat "$OUT/BUILD_INFO.txt"

    # -----------------------------------------------------------------------
    # 4. 编译后源码洁净性检查
    # -----------------------------------------------------------------------

    SOURCE_STATUS_AFTER="$(git -C "$SRC" status --porcelain)"

    if [[ -n "$SOURCE_STATUS_AFTER" ]]; then
        echo
        echo "编译后Linux源码仓库出现修改：" >&2
        echo "$SOURCE_STATUS_AFTER" >&2
        fail "源码外编译未保持源码树洁净"
    fi

    echo
    echo "Linux source worktree: clean"
    echo "Linux baseline build: SUCCESS"
    echo "Build log: $LOG"

} 2>&1 | tee "$LOG"
