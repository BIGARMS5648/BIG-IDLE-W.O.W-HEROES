#!/usr/bin/env python3
"""Cut the interface icon sheet into the addon's menu and forge icons.

    python3 -I tools/cut_icons.py tools/art/icons_sheet.webp

The sheet: white icons on a transparent background, two rows (ICONS below,
left to right). Each icon is cut on its own, its soft drop shadow dropped,
centered in a square and written as a 64x64 32-bit TGA to
BigIdleHeroes/Media/Art/<id>.tga (the ids Data/Art.lua lists), with a PNG twin
in tests/out/media for the layout preview.
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
CUT = 40       # alpha below this is the drop shadow
GAP = 8        # columns closer than this belong to one icon
PAD = 0.06     # room around an icon, a share of its square

ICONS = [
    # top row
    ["icon_hero", "icon_bag", "icon_forge", "icon_party", "icon_runes", "icon_map", "icon_pets", "forge_fuse", "forge_craft"],
    # bottom row
    ["forge_gem", "forge_ench", "forge_insc", "forge_up", "forge_smelt", "forge_mats", "icon_settings"],
]


def runs(v, gap=0):
    out, start, last = [], None, None
    for i, x in enumerate(v):
        if x:
            if start is None:
                start = i
            elif i - last > gap:
                out.append((start, last + 1))
                start = i
            last = i
    if start is not None:
        out.append((start, last + 1))
    return out


def save(name, rgba):
    arr = np.clip(rgba * 255.0 + 0.5, 0, 255).astype(np.uint8)
    h, w = arr.shape[:2]
    os.makedirs(OUT_TGA, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    with open(os.path.join(OUT_TGA, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(arr[::-1, :, [2, 1, 0, 3]].tobytes())


def resize(chan, size):
    return np.asarray(Image.fromarray(chan.astype(np.float32), "F").resize((size, size), Image.LANCZOS), dtype=np.float64)


def main(path):
    src = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    alpha = np.clip((src[..., 3] * 255.0 - CUT) / (255.0 - CUT), 0, 1)
    rows = runs((alpha > 0).sum(axis=1) > 0, GAP)
    assert len(rows) == len(ICONS), "expected %d rows, found %d" % (len(ICONS), len(rows))
    for (y0, y1), names in zip(rows, ICONS):
        cols = runs((alpha[y0:y1] > 0).sum(axis=0) > 0, GAP)
        assert len(cols) == len(names), "row %d-%d: expected %d icons, found %d" % (y0, y1, len(names), len(cols))
        for (x0, x1), name in zip(cols, names):
            a = alpha[y0:y1, x0:x1]
            ys = np.nonzero(a.sum(axis=1) > 0)[0]
            by0, by1 = y0 + ys[0], y0 + ys[-1] + 1
            side = int(max(x1 - x0, by1 - by0) * (1 + 2 * PAD))
            cx, cy = (x0 + x1) / 2.0, (by0 + by1) / 2.0
            sq = np.zeros((side, side, 4))
            ox, oy = int(round(cx - side / 2.0)), int(round(cy - side / 2.0))
            for yy in range(side):
                sy = oy + yy
                if 0 <= sy < src.shape[0]:
                    sx0, sx1 = max(0, ox), min(src.shape[1], ox + side)
                    sq[yy, sx0 - ox:sx1 - ox, :3] = src[sy, sx0:sx1, :3]
                    sq[yy, sx0 - ox:sx1 - ox, 3] = alpha[sy, sx0:sx1]
            # resize with premultiplied colour (no dark fringe at the edges)
            a2 = np.clip(resize(sq[..., 3], SIZE), 0, 1)
            out = np.zeros((SIZE, SIZE, 4))
            for c in range(3):
                pm = resize(sq[..., c] * sq[..., 3], SIZE)
                out[..., c] = np.where(a2 > 1e-4, np.clip(pm / np.maximum(a2, 1e-4), 0, 1), 1.0)
            out[..., 3] = a2
            save(name, out)
            print("%-14s from %4d,%4d  %dx%d" % (name, x0, by0, x1 - x0, by1 - by0))


if __name__ == "__main__":
    main(sys.argv[1])
