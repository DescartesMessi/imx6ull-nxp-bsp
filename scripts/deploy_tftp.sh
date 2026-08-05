#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"

VERSION="${1:-dev}"
SRC_ZIMAGE="$BUILD_DIR/linux/arch/arm/boot/zImage"
SRC_DTB="$BUILD_DIR/linux/arch/arm/boot/dts/$LINUX_DTB"
DEST="$TFTP_DIR/$VERSION"

[[ -f "$SRC_ZIMAGE" && -f "$SRC_DTB" ]] || {
  echo "缺少内核产物，请先运行 build_kernel.sh" >&2
  exit 1
}

mkdir -p "$DEST"
install -m 0644 "$SRC_ZIMAGE" "$DEST/zImage"
install -m 0644 "$SRC_DTB" "$DEST/$LINUX_DTB"
sha256sum "$DEST/zImage" "$DEST/$LINUX_DTB" > "$DEST/SHA256SUMS"
ls -lh "$DEST"
