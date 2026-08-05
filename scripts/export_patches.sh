#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"

export_one() {
  local name="$1" dir="$2" base_ref="$3" out="$4"
  [[ -d "$dir/.git" ]] || return 0
  rm -rf "$out"
  mkdir -p "$out"
  git -C "$dir" format-patch --no-signature --output-directory "$out" "$base_ref"..HEAD
  git -C "$dir" status --short
}

export_one uboot "$SOURCES_DIR/uboot-imx" "$NXP_UBOOT_REF" "$PROJECT_ROOT/patches/uboot"
export_one linux "$SOURCES_DIR/linux-imx" "$NXP_LINUX_REF" "$PROJECT_ROOT/patches/linux"
