#!/usr/bin/env python3
"""Make the faction picker's two crests from the user's faction logos.

    python3 -I tools/cut_faction_logos.py tools/art/faction_alliance.avif tools/art/faction_horde.png

Each logo (already on a clear background) is drawn as tall as a SIZE x SIZE
square, centred, its own proportions kept, to BigIdleHeroes/Media/Art/
icon_alliance.tga and icon_horde.tga (32-bit TGA), with PNG twins in
tests/out/media for the layout preview. Colours are resized premultiplied,
so the clear background leaves no dark fringe.
"""
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media", "Art")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
SIZE = 256
CUT = 8  # alpha below this is empty


def resize(chan, w, h):
    return np.asarray(Image.fromarray(chan.astype(np.float32), "F").resize((w, h), Image.LANCZOS), dtype=np.float64)


def cut(path, name):
    src = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    ys, xs = np.nonzero(src[..., 3] * 255 > CUT)
    src = src[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h0, w0 = src.shape[:2]
    scale = SIZE / max(h0, w0)
    w, h = max(1, round(w0 * scale)), max(1, round(h0 * scale))
    a = np.clip(resize(src[..., 3], w, h), 0, 1)
    rgb = np.zeros((h, w, 3))
    for c in range(3):
        pm = resize(src[..., c] * src[..., 3], w, h)
        rgb[..., c] = np.where(a > 1e-4, np.clip(pm / np.maximum(a, 1e-4), 0, 1), 0)
    out = np.zeros((SIZE, SIZE, 4))
    ox, oy = (SIZE - w) // 2, (SIZE - h) // 2
    out[oy:oy + h, ox:ox + w, :3] = rgb
    out[oy:oy + h, ox:ox + w, 3] = a
    arr = np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)
    os.makedirs(OUT_TGA, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    with open(os.path.join(OUT_TGA, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(arr[::-1, :, [2, 1, 0, 3]].tobytes())
    print("%s: %dx%d logo in a %dx%d square" % (name, w, h, SIZE, SIZE))


if __name__ == "__main__":
    cut(sys.argv[1], "icon_alliance")
    cut(sys.argv[2], "icon_horde")
