#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"

SRC="$SOURCES_DIR/linux-imx"
OUT="$BUILD_DIR/linux"
LOG="$LOG_DIR/linux-$(date +%Y%m%d-%H%M%S).log"

[[ -d "$SRC/.git" ]] || { echo "请先运行 bootstrap_sources.sh" >&2; exit 1; }
[[ -f "$SRC/arch/arm/configs/$LINUX_DEFCONFIG" ]] || {
  echo "不存在 arch/arm/configs/$LINUX_DEFCONFIG" >&2
  exit 1
}

rm -rf "$OUT"
mkdir -p "$OUT"

make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$LINUX_DEFCONFIG"
set -o pipefail
make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" zImage dtbs modules 2>&1 | tee "$LOG"

DTB_PATH="$OUT/arch/arm/boot/dts/$LINUX_DTB"
[[ -f "$DTB_PATH" ]] || {
  echo "未生成 $LINUX_DTB。可用 i.MX6ULL DTB:" >&2
  find "$OUT/arch/arm/boot/dts" -maxdepth 1 -type f -iname '*imx6ull*.dtb' -printf '%f\n' | sort >&2 || true
  exit 1
}

sha256sum "$OUT/arch/arm/boot/zImage" "$DTB_PATH" | tee "$OUT/SHA256SUMS"
ls -lh "$OUT/arch/arm/boot/zImage" "$DTB_PATH"
