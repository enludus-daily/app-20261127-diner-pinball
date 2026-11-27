#!/usr/bin/env python3
"""まんぷくピンボールのアイコン（1024x1024、透過なし）。木の台・銅の鍋・トマトと卵のバンパー・銀の玉・フライ返し。
使い方: python3 scripts/make-icon-diner.py（Pillow が要る）"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 4096
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def radial(size, inner, outer, center=(0.35, 0.3)):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    cx, cy = center[0] * w, center[1] * h
    maxd = math.hypot(max(cx, w - cx), max(cy, h - cy))
    for y in range(h):
        for x in range(w):
            t = min(1, math.hypot(x - cx, y - cy) / maxd)
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img


def disc(img, c, r, inner, outer, shadow=True):
    d = ImageDraw.Draw(img, "RGBA")
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse([c[0] - r * 0.95, c[1] - r * 0.6, c[0] + r * 0.95, c[1] + r * 1.25], fill=(58, 36, 24, 90))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(r * 0.12)))
    g = radial((int(r * 2), int(r * 2)), inner, outer).convert("RGBA")
    mask = Image.new("L", g.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, g.size[0] - 1, g.size[1] - 1], fill=255)
    img.paste(g, (int(c[0] - r), int(c[1] - r)), mask)
    d.ellipse([c[0] - r * 0.6, c[1] - r * 0.72, c[0] - r * 0.1, c[1] - r * 0.42], fill=(255, 255, 255, 170))


def main():
    img = Image.new("RGBA", (S, S), (240, 211, 166, 255))
    d = ImageDraw.Draw(img, "RGBA")
    # 木の板
    for i, y in enumerate(range(0, S, 420)):
        d.rectangle([0, y, S, y + 10], fill=(185, 129, 77, 150))
        off = 600 if i % 2 else 1700
        for x in range(off, S, 2200):
            d.rectangle([x, y, x + 8, y + 420], fill=(185, 129, 77, 110))
        for k in (140, 280):
            d.line([(0, y + k), (S, y + k + 20)], fill=(185, 129, 77, 50), width=8)
    # 銅の鍋（真上から）
    c = (S * 0.5, S * 0.6)
    for dx in (-1, 1):
        d.rounded_rectangle([c[0] + dx * 1080 - 260, c[1] - 140, c[0] + dx * 1080 + 260, c[1] + 140], radius=110, fill=(142, 68, 32, 255))
    disc(img, c, 1000, (240, 178, 124), (142, 68, 32))
    disc(img, c, 800, (201, 118, 47), (110, 52, 20), shadow=False)
    # 湯気
    st = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    for (x, y, r) in [(-180, -820, 230), (160, -1120, 280), (-60, -1480, 320)]:
        sd.ellipse([c[0] + x - r, c[1] + y - r, c[0] + x + r, c[1] + y + r], fill=(255, 255, 255, 120))
    img.alpha_composite(st.filter(ImageFilter.GaussianBlur(60)))
    # トマトと卵のバンパー
    disc(img, (S * 0.2, S * 0.22), 520, (243, 125, 112), (170, 40, 30))
    d = ImageDraw.Draw(img, "RGBA")
    for k in range(5):
        a = k / 5 * 2 * math.pi - math.pi / 2
        x, y = S * 0.2 + math.cos(a) * 120, S * 0.22 - 400 + math.sin(a) * 70
        d.ellipse([x - 70, y - 120, x + 70, y + 120], fill=(63, 143, 58, 255))
    disc(img, (S * 0.8, S * 0.2), 480, (255, 252, 240), (220, 205, 180))
    disc(img, (S * 0.82, S * 0.22), 230, (255, 222, 110), (240, 160, 40), shadow=False)
    # 銀の玉
    disc(img, (S * 0.56, S * 0.33), 300, (255, 255, 255), (100, 112, 120))
    # フライ返し（左下から）
    fl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(fl)
    a, b = (S * 0.02, S * 0.86), (S * 0.42, S * 0.98)
    fd.line([a, b], fill=(142, 68, 32, 255), width=300)
    fd.line([a, b], fill=(199, 112, 58, 255), width=210)
    for t in (0.5, 0.65, 0.8):
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        fd.ellipse([x - 30, y - 30, x + 30, y + 30], fill=(142, 68, 32, 255))
    img.alpha_composite(fl)
    img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
