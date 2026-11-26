#!/usr/bin/env python3
"""Make the minimap button's icon from the user's square logo.

    python3 -I tools/cut_minimap_icon.py tools/art/minimap_logo.png

The logo's middle (inside its rounded frame) is cut as a circle and written
as a 64x64 32-bit TGA, clear outside the circle, to
BigIdleHeroes/Media/Art/icon_minimap.tga, with a PNG twin in tests/out/media
for the layout preview. The circle is drawn at four times the size and
shrunk, so its edge is smooth.
"""
import os
import struct
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media", "Art")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
SIZE = 64
RADIUS = 0.458   # the circle's radius, a share of the logo's width (inside its frame)


def write_tga(img, path):
    w, h = img.size
    px = img.load()
    data = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            data += bytes((b, g, r, a))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    with open(path, "wb") as f:
        f.write(header + data)


def main(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    r = w * RADIUS
    cx, cy = w / 2, h / 2
    big = im.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r))).resize((SIZE * 4, SIZE * 4), Image.LANCZOS)
    mask = Image.new("L", big.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big.size[0] - 1, big.size[1] - 1), fill=255)
    big.putalpha(mask)
    icon = big.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(OUT_PNG, exist_ok=True)
    write_tga(icon, os.path.join(OUT_TGA, "icon_minimap.tga"))
    icon.save(os.path.join(OUT_PNG, "icon_minimap.png"))
    print("wrote icon_minimap (%dx%d)" % (SIZE, SIZE))


if __name__ == "__main__":
    main(sys.argv[1])
