#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"

for cmd in git make "${CROSS_COMPILE}gcc" "${CROSS_COMPILE}ld" sha256sum; do
  require_cmd "$cmd"
done

printf 'PROJECT_ROOT=%s\n' "$PROJECT_ROOT"
printf 'ARCH=%s\n' "$ARCH"
printf 'CROSS_COMPILE=%s\n' "$CROSS_COMPILE"
"${CROSS_COMPILE}gcc" --version | head -n 1
"${CROSS_COMPILE}gcc" -dumpmachine
