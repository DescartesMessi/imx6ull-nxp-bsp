#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"

SRC="$SOURCES_DIR/uboot-imx"
OUT="$BUILD_DIR/uboot"
LOG="$LOG_DIR/uboot-$(date +%Y%m%d-%H%M%S).log"

[[ -d "$SRC/.git" ]] || { echo "请先运行 bootstrap_sources.sh" >&2; exit 1; }
[[ -f "$SRC/configs/$UBOOT_DEFCONFIG" ]] || {
  echo "不存在 configs/$UBOOT_DEFCONFIG，可选 i.MX6ULL 配置:" >&2
  find "$SRC/configs" -maxdepth 1 -type f -iname '*mx6ull*defconfig' -printf '%f\n' | sort >&2
  exit 1
}

rm -rf "$OUT"
mkdir -p "$OUT"

make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$UBOOT_DEFCONFIG"
set -o pipefail
make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" 2>&1 | tee "$LOG"

(
    cd "$OUT"

    sha256sum \
        u-boot \
        u-boot.bin \
        u-boot.imx \
        System.map \
        > SHA256SUMS

    ls -lh \
        u-boot \
        u-boot.bin \
        u-boot.imx \
        System.map \
        .config
)

cat "$OUT/SHA256SUMS"
