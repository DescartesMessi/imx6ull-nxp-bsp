#!/bin/bash
###############################################################################
# File       : vs_metrics_run.sh
# Platform   : i.MX6ULL JJL
#
# 作用：把"带指标采集的车载终端"部署到板子并跑一轮自动巡检，回收指标日志。
#
# 前置条件：
#   - 板子已启动、串口可用（默认 /dev/ttyUSB0）
#   - 应用已按 /home/pointer/imx6ull/projects/Vehicle-system/scripts/build_app.sh
#     交叉编译，产物在 deploy/nfs/rootfs/usr/local/bin/VehicleSystem
#   - 板端应用支持 VS_METRICS / VS_AUTOPILOT / VS_AUTOPILOT_EXIT 三个环境变量
#
# 用法:
#   scripts/vs_metrics_run.sh [串口设备] [每步停留ms] [总运行秒数]
#
# 产物:
#   deploy/nfs/rootfs/photo/vs_metrics.log   板端原始日志（含每个页面的
#                                            METRIC / CAMERA / RENDER / SENTINEL 行）
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ROOTFS_DIR="${PROJECT_ROOT}/deploy/nfs/rootfs"
BOARD_LOG="${ROOTFS_DIR}/photo/vs_metrics.log"

SERIAL_DEV="${1:-/dev/ttyUSB0}"
DWELL_MS="${2:-4000}"
RUN_SECONDS="${3:-170}"

[ -e "${SERIAL_DEV}" ] || { echo "找不到串口设备 ${SERIAL_DEV}" >&2; exit 1; }

echo "== 部署并启动自动巡检 =="
python3 "${SCRIPT_DIR}/serial_console.py" --dev "${SERIAL_DEV}" \
    --send "" \
    --send-at "3=grep -q /mnt/nfs /proc/mounts || mount -t nfs -o \
nolock,vers=3,proto=tcp,timeo=50,retrans=2 \
192.168.31.218:${ROOTFS_DIR} /mnt/nfs; \
cp -f /mnt/nfs/usr/local/bin/VehicleSystem /usr/local/bin/VehicleSystem; \
cd /usr/local/bin; \
VS_METRICS=1 VS_AUTOPILOT=${DWELL_MS} VS_AUTOPILOT_EXIT=1 \
nohup ./VehicleSystem >/mnt/nfs/photo/vs_metrics.log 2>&1 & \
sleep 5; pidof VehicleSystem"$'\r' \
    --capture 14

echo
echo "== 巡检进行中，等待 ${RUN_SECONDS}s =="
sleep "${RUN_SECONDS}"

echo
echo "== 板端日志（已通过 NFS 写回主机） =="
if [ -f "${BOARD_LOG}" ]; then
    wc -l "${BOARD_LOG}"
    grep -E "\[VS" "${BOARD_LOG}" | tail -60
else
    echo "未找到 ${BOARD_LOG}" >&2
    exit 1
fi
