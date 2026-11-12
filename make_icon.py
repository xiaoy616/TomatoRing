#!/usr/bin/env python3
"""生成 macOS 应用图标：深色圆角方块 + 绿色进度圆环，输出 Resources/AppIcon.icns。"""
import os
import shutil
import subprocess

from PIL import Image, ImageDraw

S = 1024
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_ICNS = os.path.join(ROOT, "Resources", "AppIcon.icns")
ICONSET = os.path.join(ROOT, "build", "AppIcon.iconset")

GREEN = (41, 196, 118, 255)
GREEN_DARK = (26, 122, 78, 255)
GREEN_LIGHT = (126, 240, 173, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def main():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bgd = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / S
        bgd.line([(0, y), (S, y)], fill=lerp((44, 46, 50), (22, 23, 26), t) + (255,))
    bg.putalpha(rounded_mask(S, 228))
    img.alpha_composite(bg)

    d = ImageDraw.Draw(img)
    cx = cy = S // 2
    outer, width = 300, 76
    box = [cx - outer, cy - outer, cx + outer, cy + outer]

    # 轨道：暗绿整圈
    d.ellipse(box, outline=GREEN_DARK, width=width)

    # 进度：亮绿 270°
    d.arc(box, start=-90, end=180, fill=GREEN, width=width)

    # 进度端点做圆头
    import math

    r = outer - width / 2
    for deg in (-90, 180):
        x = cx + r * math.cos(math.radians(deg))
        y = cy + r * math.sin(math.radians(deg))
        d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=GREEN)

    # 起点高光
    hx = cx + r * math.cos(math.radians(-90))
    hy = cy + r * math.sin(math.radians(-90))
    d.ellipse([hx - width / 3, hy - width / 3, hx + width / 3, hy + width / 3], fill=GREEN_LIGHT)

    shutil.rmtree(ICONSET, ignore_errors=True)
    os.makedirs(ICONSET, exist_ok=True)

    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in sizes.items():
        img.resize((size, size), Image.LANCZOS).save(os.path.join(ICONSET, name))

    subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", OUT_ICNS], check=True)
    print("wrote", OUT_ICNS)


if __name__ == "__main__":
    main()
