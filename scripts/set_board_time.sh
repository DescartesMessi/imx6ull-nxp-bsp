#!/bin/bash
###############################################################################
# File       : set_board_time.sh
# Platform   : i.MX6ULL JJL
#
# 作用：把开发板的系统时间 / RTC 设置为**开发主机当前时间**。
#
# 背景：本板 busybox 没有 date applet，hwclock 也不支持 --set，
#       板上唯一的设置手段是 /usr/bin/settime（源码 scripts/settime.c，
#       静态交叉编译，见 docs/代码优化记录.md ⑮）。
#
# 原理：主机算好 Unix 时间戳，在串口命令里直接下发 --epoch，
#       板上不做任何时区换算，因此不会出现 8 小时偏差。
#
# 用法:
#   scripts/set_board_time.sh [串口设备]      # 默认 /dev/ttyUSB0
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

SERIAL_DEV="${1:-/dev/ttyUSB0}"
# 串口工具在抓取开始后第 3 秒发送，这里预留 4 秒补偿延迟
SEND_DELAY=4

[ -e "${SERIAL_DEV}" ] || { echo "找不到串口设备 ${SERIAL_DEV}" >&2; exit 1; }

EPOCH=$(( $(date +%s) + SEND_DELAY ))
echo "主机时间 : $(date -d "@${EPOCH}" '+%F %T %z')"
echo "下发 epoch: ${EPOCH}  (设备 ${SERIAL_DEV})"

python3 "${SCRIPT_DIR}/serial_console.py" --dev "${SERIAL_DEV}" \
    --send "" \
    --send-at "3=settime --epoch ${EPOCH}; echo; settime --show"$'\r' \
    --capture 10
