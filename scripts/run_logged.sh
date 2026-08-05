#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

if [[ "$#" -lt 2 ]]; then
    echo "用法：" >&2
    echo "  $0 <记录名称> <命令> [参数...]" >&2
    echo >&2
    echo "示例：" >&2
    echo "  $0 build-linux bash scripts/build_kernel.sh" >&2
    exit 1
fi

NAME="$1"
shift

SAFE_NAME="$(
    printf '%s' "$NAME" |
    tr -cs 'A-Za-z0-9._-' '-'
)"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$PROJECT_ROOT/logs/commands"
LOG_FILE="$LOG_DIR/${TIMESTAMP}-${SAFE_NAME}.log"

mkdir -p "$LOG_DIR"

{
    echo "============================================================"
    echo "Command execution record"
    echo "============================================================"
    echo "Timestamp : $(date -Iseconds)"
    echo "Directory : $(pwd)"
    echo "User      : $(id -un)"
    echo "Host      : $(hostname)"
    echo "Git branch: $(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)"
    echo "Git commit: $(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || true)"
    echo -n "Command   :"

    printf ' %q' "$@"
    echo
    echo "============================================================"
    echo
} | tee "$LOG_FILE"

set +e

"$@" 2>&1 | tee -a "$LOG_FILE"
COMMAND_STATUS="${PIPESTATUS[0]}"

set -e

{
    echo
    echo "============================================================"
    echo "Exit status: $COMMAND_STATUS"
    echo "Log file   : $LOG_FILE"
    echo "============================================================"
} | tee -a "$LOG_FILE"

exit "$COMMAND_STATUS"