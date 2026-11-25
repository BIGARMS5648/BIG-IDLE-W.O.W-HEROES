#!/usr/bin/env python3
"""Make one interface icon from a picture of a single white icon.

    python3 -I tools/cut_icon.py tools/art/lock.png icon_lock

The picture: one white icon on a clear background. It is cut to what it
covers, centered in a square with a little room around it and written as a
64x64 32-bit TGA to BigIdleHeroes/Media/Art/<id>.tga (Data/Art.lua lists the
ids), with a PNG twin in tests/out/media for the layout preview.
"""
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media", "Art")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
SIZE = 64
CUT = 40       # alpha below this is not the icon
PAD = 0.06     # room around the icon, a share of its square


def resize(chan, size):
    return np.asarray(Image.fromarray(chan.astype(np.float32), "F").resize((size, size), Image.LANCZOS), dtype=np.float64)


def main(path, name):
    src = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    ys, xs = np.nonzero(src[..., 3] * 255.0 > CUT)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = int(max(x1 - x0, y1 - y0) * (1 + 2 * PAD))
    sq = np.zeros((side, side, 4))
    ox, oy = int(round((x0 + x1 - side) / 2.0)), int(round((y0 + y1 - side) / 2.0))
    sx0, sy0 = max(0, ox), max(0, oy)
    sx1, sy1 = min(src.shape[1], ox + side), min(src.shape[0], oy + side)
    sq[sy0 - oy:sy1 - oy, sx0 - ox:sx1 - ox] = src[sy0:sy1, sx0:sx1]
    # resize with premultiplied colour (no dark fringe at the edges)
    a = np.clip(resize(sq[..., 3], SIZE), 0, 1)
    out = np.zeros((SIZE, SIZE, 4))
    for c in range(3):
        pm = resize(sq[..., c] * sq[..., 3], SIZE)
        out[..., c] = np.where(a > 1e-4, np.clip(pm / np.maximum(a, 1e-4), 0, 1), 1.0)
    out[..., 3] = a
    arr = np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)
    os.makedirs(OUT_TGA, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    with open(os.path.join(OUT_TGA, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(arr[::-1, :, [2, 1, 0, 3]].tobytes())
    print("%s from %d,%d %dx%d" % (name, x0, y0, x1 - x0, y1 - y0))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
