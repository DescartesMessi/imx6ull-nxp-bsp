#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

ENV_FILE="$PROJECT_ROOT/manifest/sources.env"
SOURCES_DIR="$PROJECT_ROOT/sources"
LOCK_FILE="$PROJECT_ROOT/manifest/locked-revisions.local"
CHECKSUM_DIR="$PROJECT_ROOT/manifest/archive-checksums"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "错误：找不到配置文件：$ENV_FILE" >&2
    echo "请先复制并配置 manifest/sources.env。" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

SOURCE_MODE="${SOURCE_MODE:-archive}"

mkdir -p \
    "$SOURCES_DIR" \
    "$CHECKSUM_DIR"

require_command()
{
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "错误：找不到命令：$command_name" >&2
        exit 1
    fi
}

require_command tar
require_command bzip2
require_command git
require_command sha256sum
require_command awk
require_command sort
require_command wc

check_git_identity()
{
    if [[ -z "$(git config --global user.name || true)" ]]; then
        echo "错误：尚未设置 Git user.name。" >&2
        echo "请执行：git config --global user.name \"你的名称\"" >&2
        exit 1
    fi

    if [[ -z "$(git config --global user.email || true)" ]]; then
        echo "错误：尚未设置 Git user.email。" >&2
        echo "请执行：git config --global user.email \"你的邮箱\"" >&2
        exit 1
    fi
}

validate_archive()
{
    local name="$1"
    local archive="$2"

    if [[ ! -f "$archive" ]]; then
        echo "错误：找不到 $name 压缩包：" >&2
        echo "  $archive" >&2
        exit 1
    fi

    echo "[$name] 检查 bzip2 数据完整性"
    bzip2 -t "$archive"

    echo "[$name] 检查归档路径安全性"

    if tar -tjf "$archive" \
        | grep -E '(^/|(^|/)\.\.(/|$))' \
        >/dev/null; then

        echo "错误：$name 压缩包中包含不安全路径。" >&2
        exit 1
    fi

    echo "[$name] SHA-256："
    sha256sum "$archive"
}

extract_archive()
{
    local name="$1"
    local archive="$2"
    local destination="$3"
    local upstream_url="$4"
    local upstream_ref="$5"

    if [[ -d "$destination/.git" ]]; then
        echo "[$name] 本地 Git 仓库已存在，跳过导入："
        echo "  $destination"
        return
    fi

    if [[ -e "$destination" ]]; then
        if [[ -n "$(find "$destination" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
            echo "错误：目标目录已存在并且不为空：" >&2
            echo "  $destination" >&2
            echo "请先检查该目录，避免覆盖已有源码。" >&2
            exit 1
        fi
    fi

    mkdir -p "$destination"

    local top_level_count

    top_level_count="$(
        tar -tjf "$archive" \
            | awk -F/ 'NF > 0 && $1 != "" && $1 != "." { print $1 }' \
            | sort -u \
            | wc -l
    )"

    echo "[$name] 归档顶层项目数量：$top_level_count"
    echo "[$name] 解压到：$destination"

    if [[ "$top_level_count" -eq 1 ]]; then
        tar \
            -xjf "$archive" \
            -C "$destination" \
            --strip-components=1
    else
        tar \
            -xjf "$archive" \
            -C "$destination"
    fi

    if [[ ! -f "$destination/Makefile" ]]; then
        echo "错误：解压后的 $name 目录中找不到顶层 Makefile。" >&2
        exit 1
    fi

    echo "[$name] 初始化本地 Git 基线仓库"

    git -C "$destination" init

    git -C "$destination" remote add \
        upstream \
        "$upstream_url"

    git -C "$destination" add -A

    git -C "$destination" commit \
        -m "baseline: import NXP ${upstream_ref} source archive"

    git -C "$destination" tag \
        -a nxp-baseline \
        -m "NXP ${upstream_ref} local archive baseline"

    git -C "$destination" checkout \
        -b board/imx6ull-jjl

    echo "[$name] 本地开发分支创建完成：board/imx6ull-jjl"
}

if [[ "$SOURCE_MODE" != "archive" ]]; then
    echo "错误：当前脚本只接受 SOURCE_MODE=archive。" >&2
    exit 1
fi

: "${NXP_UBOOT_ARCHIVE:?未设置 NXP_UBOOT_ARCHIVE}"
: "${NXP_LINUX_ARCHIVE:?未设置 NXP_LINUX_ARCHIVE}"
: "${NXP_UBOOT_URL:?未设置 NXP_UBOOT_URL}"
: "${NXP_LINUX_URL:?未设置 NXP_LINUX_URL}"
: "${NXP_UBOOT_REF:?未设置 NXP_UBOOT_REF}"
: "${NXP_LINUX_REF:?未设置 NXP_LINUX_REF}"

check_git_identity

validate_archive \
    "uboot" \
    "$NXP_UBOOT_ARCHIVE"

validate_archive \
    "linux" \
    "$NXP_LINUX_ARCHIVE"

UBOOT_DIR="$SOURCES_DIR/uboot-imx"
LINUX_DIR="$SOURCES_DIR/linux-imx"

extract_archive \
    "uboot" \
    "$NXP_UBOOT_ARCHIVE" \
    "$UBOOT_DIR" \
    "$NXP_UBOOT_URL" \
    "$NXP_UBOOT_REF"

extract_archive \
    "linux" \
    "$NXP_LINUX_ARCHIVE" \
    "$LINUX_DIR" \
    "$NXP_LINUX_URL" \
    "$NXP_LINUX_REF"

UBOOT_BASELINE_COMMIT="$(
    git -C "$UBOOT_DIR" rev-parse nxp-baseline^{}
)"

LINUX_BASELINE_COMMIT="$(
    git -C "$LINUX_DIR" rev-parse nxp-baseline^{}
)"

UBOOT_ARCHIVE_SHA256="$(
    sha256sum "$NXP_UBOOT_ARCHIVE" |
    awk '{print $1}'
)"

LINUX_ARCHIVE_SHA256="$(
    sha256sum "$NXP_LINUX_ARCHIVE" |
    awk '{print $1}'
)"

cat > "$LOCK_FILE" <<LOCK_EOF
# Local reproducible source lock.
#
# The baseline commit hashes below are local snapshot commits created from
# the source archives. They are not claimed to be the original NXP Git
# commit hashes.

SOURCE_MODE="archive"

NXP_UBOOT_URL="$NXP_UBOOT_URL"
NXP_UBOOT_REF="$NXP_UBOOT_REF"
NXP_UBOOT_ARCHIVE="$NXP_UBOOT_ARCHIVE"
NXP_UBOOT_ARCHIVE_SHA256="$UBOOT_ARCHIVE_SHA256"
NXP_UBOOT_LOCAL_BASELINE_COMMIT="$UBOOT_BASELINE_COMMIT"

NXP_LINUX_URL="$NXP_LINUX_URL"
NXP_LINUX_REF="$NXP_LINUX_REF"
NXP_LINUX_ARCHIVE="$NXP_LINUX_ARCHIVE"
NXP_LINUX_ARCHIVE_SHA256="$LINUX_ARCHIVE_SHA256"
NXP_LINUX_LOCAL_BASELINE_COMMIT="$LINUX_BASELINE_COMMIT"
LOCK_EOF

echo
echo "NXP 本地源码导入完成。"
echo
echo "U-Boot：$UBOOT_DIR"
echo "Linux ：$LINUX_DIR"
echo "锁文件：$LOCK_FILE"
