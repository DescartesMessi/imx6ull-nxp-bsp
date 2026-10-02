#!/usr/bin/env python3
"""把板端抓到的裸 framebuffer 转成 PNG。

板端抓图：
    dd if=/dev/fb0 of=/mnt/nfs/photo/fb_shot.raw bs=4096 count=400 ; sync
主机转换：
    scripts/fb_raw2png.py fb_shot.raw fb_shot.png

踩过的坑：
    本板 linuxfb 为 800x480 / 32bpp / stride 3200，像素字节序是 B,G,R,X。
    Pillow 的原始解码模式里没有 'BGRA'，按 'RGBA' 读会把红蓝两个通道对调，
    截图上"温度"会显示成蓝色、红色文字会显示成蓝色，看着像是界面配色错了，
    其实是抓图解码错了。因此这里读进来后固定做一次 R/B 交换（--no-swap 可关闭，
    用于复现这种错误观感）。
"""

import argparse
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("需要 Pillow：python3 -m pip install pillow")


def main():
    parser = argparse.ArgumentParser(description="framebuffer raw -> PNG")
    parser.add_argument("raw", help="dd 导出的 .raw 文件")
    parser.add_argument("png", help="输出的 .png 文件")
    parser.add_argument("--size", default="800x480",
                        help="分辨率，默认 800x480")
    parser.add_argument("--mode", default="RGBA",
                        help="Pillow 原始解码模式，本板固定 RGBA")
    parser.add_argument("--no-swap", action="store_true",
                        help="不做 R/B 交换（复现错误观感用）")
    args = parser.parse_args()

    width, height = (int(v) for v in args.size.lower().split("x"))
    expect = width * height * 4

    with open(args.raw, "rb") as fp:
        data = fp.read(expect)

    if len(data) < expect:
        sys.exit("数据不足：期望 %d 字节，实际 %d 字节" % (expect, len(data)))

    image = Image.frombytes(args.mode, (width, height), data).convert("RGB")

    if not args.no_swap:
        red, green, blue = image.split()
        image = Image.merge("RGB", (blue, green, red))

    image.save(args.png)
    print("已保存 %s (%dx%d)" % (args.png, width, height))


if __name__ == "__main__":
    main()
