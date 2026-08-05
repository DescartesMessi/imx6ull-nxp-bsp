#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/manifest/sources.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "缺少 $ENV_FILE" >&2
  echo "请先执行: cp manifest/sources.env.example manifest/sources.env" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

SOURCES_DIR="$PROJECT_ROOT/sources"
BUILD_DIR="$PROJECT_ROOT/build"
LOG_DIR="$PROJECT_ROOT/logs"
DEPLOY_DIR="$PROJECT_ROOT/deploy"

mkdir -p "$SOURCES_DIR" "$BUILD_DIR" "$LOG_DIR" "$DEPLOY_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1" >&2
    exit 1
  }
}
