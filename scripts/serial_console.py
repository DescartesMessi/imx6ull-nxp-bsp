#!/usr/bin/env python3
"""i.MX6ULL 串口控制台工具

用于通过 USB 转串口与开发板交互：发送命令、抓取带时间戳的启动日志，
便于测量 U-Boot 与内核各阶段耗时。

只用标准库（termios），不依赖 pyserial。

用法示例：
    # 抓取 5 秒输出（先发一个回车唤醒提示符）
    scripts/serial_console.py --dev /dev/ttyUSB0 --send "" --capture 5

    # 触发重启并抓取 40 秒启动日志，原始输出存文件
    scripts/serial_console.py --dev /dev/ttyUSB0 --send reboot --capture 40 \
        --raw-out /tmp/boot.log

    # 重启后在 4.5~7.0 秒之间反复发送空格，打断 U-Boot autoboot
    scripts/serial_console.py --dev /dev/ttyUSB0 --send reboot \
        --spam 4.5=7.0=" " --capture 12
"""

import argparse
import os
import select
import sys
import termios
import time


def configure_port(fd, baud):
    """把串口配置成 8N1 raw 模式，不做任何输入输出加工。"""
    baud_const = getattr(termios, "B%d" % baud)
    attrs = termios.tcgetattr(fd)
    iflag, oflag, cflag, lflag = attrs[0], attrs[1], attrs[2], attrs[3]

    iflag &= ~(termios.IGNBRK | termios.BRKINT | termios.PARMRK |
               termios.ISTRIP | termios.INLCR | termios.IGNCR |
               termios.ICRNL | termios.IXON | termios.IXOFF)
    oflag &= ~termios.OPOST
    lflag &= ~(termios.ECHO | termios.ECHONL | termios.ICANON |
               termios.ISIG | termios.IEXTEN)
    cflag &= ~(termios.CSIZE | termios.PARENB | termios.CSTOPB)
    cflag |= termios.CS8 | termios.CREAD | termios.CLOCAL

    attrs[0], attrs[1], attrs[2], attrs[3] = iflag, oflag, cflag, lflag
    attrs[4] = baud_const
    attrs[5] = baud_const
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0

    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)


def capture(fd, seconds, raw_out, start=None, actions=None):
    """按行读取串口数据，输出带时间戳的日志，并按时间点发送字符串。"""
    if start is None:
        start = time.monotonic()
    deadline = start + seconds
    buf = b""
    raw = bytearray()
    pending = sorted(actions or [])

    while time.monotonic() < deadline:
        now = time.monotonic()
        while pending and now - start >= pending[0][0]:
            _, text = pending.pop(0)
            os.write(fd, text.encode())

        remaining = deadline - now
        ready, _, _ = select.select([fd], [], [], min(remaining, 0.5))
        if not ready:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            continue
        if not chunk:
            continue
        raw.extend(chunk)
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            ts = time.monotonic() - start
            text = line.decode("utf-8", "replace").rstrip("\r")
            print("[%8.3f] %s" % (ts, text), flush=True)

    if buf:
        ts = time.monotonic() - start
        print("[%8.3f] %s" % (ts, buf.decode("utf-8", "replace").rstrip("\r")),
              flush=True)

    if raw_out:
        with open(raw_out, "wb") as fh:
            fh.write(bytes(raw))

    return start


def main():
    parser = argparse.ArgumentParser(description="i.MX6ULL 串口控制台工具")
    parser.add_argument("--dev", default="/dev/ttyUSB0", help="串口设备节点")
    parser.add_argument("--baud", type=int, default=115200, help="波特率")
    parser.add_argument("--send", default=None,
                        help="capture 前发送的命令（空串表示只发一个回车）")
    parser.add_argument("--capture", type=float, default=5.0,
                        help="抓取时长（秒）")
    parser.add_argument("--settle", type=float, default=0.3,
                        help="发送命令前的静默等待（秒）")
    parser.add_argument("--send-at", action="append", default=[],
                        metavar="SEC=TEXT",
                        help="在抓取开始后第 SEC 秒发送 TEXT（可重复）")
    parser.add_argument("--spam", action="append", default=[],
                        metavar="START=END=TEXT",
                        help="在 START~END 秒之间每 250ms 发送一次 TEXT（可重复）")
    parser.add_argument("--raw-out", default=None, help="原始字节输出文件")
    args = parser.parse_args()

    if not os.path.exists(args.dev):
        print("串口设备不存在: %s" % args.dev, file=sys.stderr)
        return 1

    fd = os.open(args.dev, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        configure_port(fd, args.baud)
        time.sleep(args.settle)
        # 先把已有的残留输出读掉，避免污染时间戳
        capture(fd, 0.2, None)

        actions = []
        for item in args.send_at:
            sec, _, text = item.partition("=")
            actions.append((float(sec), text))
        for item in args.spam:
            start_s, _, rest = item.partition("=")
            end_s, _, text = rest.partition("=")
            t = float(start_s)
            while t <= float(end_s):
                actions.append((t, text))
                t += 0.25

        start = time.monotonic()
        print("== 抓取开始 ==", flush=True)
        if args.send is not None:
            os.write(fd, (args.send + "\r").encode())
        capture(fd, args.capture, args.raw_out, start, actions)
        print("== 抓取结束 ==", flush=True)
    finally:
        os.close(fd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
