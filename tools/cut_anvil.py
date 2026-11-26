#!/usr/bin/env python3
"""Cut the anvil and the hammer of the old forge icon apart, for 강화's strikes.

    python3 -I tools/cut_anvil.py tools/art/icons_sheet.webp

The sheet is the one tools/cut_icons.py reads; its third icon of the top row
is an anvil, a hammer above it and two spark marks. The marks are left out.
Written (64x64 32-bit TGA in BigIdleHeroes/Media/Art, PNG twins in
tests/out/media):
  fx_anvil   the anvil, in the icon's own square (it stays where it was)
  fx_hammer  the hammer in a square whose middle is the end of its handle,
             so turning the square about its middle swings the hammer
The numbers printed go into UI/TabForge.lua (UpFx.HAMMER): where the handle's
end is in the icon's square, how big the hammer's square is, and how far the
hammer turns down to land on the anvil.
"""
import math
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media", "Art")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
SIZE = 64
CUT = 40       # alpha below this is the drop shadow
GAP = 8        # columns closer than this belong to one icon
PAD = 0.06     # room around an icon, a share of its square (as cut_icons.py)


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


def resize(chan, size):
    return np.asarray(Image.fromarray(chan.astype(np.float32), "F").resize((size, size), Image.LANCZOS), dtype=np.float64)


def save(name, sq):
    """sq: a square float RGBA picture, written at SIZE x SIZE."""
    a2 = np.clip(resize(sq[..., 3], SIZE), 0, 1)
    out = np.zeros((SIZE, SIZE, 4))
    for c in range(3):
        pm = resize(sq[..., c] * sq[..., 3], SIZE)
        out[..., c] = np.where(a2 > 1e-4, np.clip(pm / np.maximum(a2, 1e-4), 0, 1), 1.0)
    out[..., 3] = a2
    arr = np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)
    os.makedirs(OUT_TGA, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    with open(os.path.join(OUT_TGA, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(arr[::-1, :, [2, 1, 0, 3]].tobytes())


def square(src, alpha, keep, cx, cy, side):
    """The side x side square of src around (cx, cy), only where keep is set."""
    sq = np.zeros((side, side, 4))
    ox, oy = int(round(cx - side / 2.0)), int(round(cy - side / 2.0))
    for yy in range(side):
        sy = oy + yy
        if 0 <= sy < src.shape[0]:
            sx0, sx1 = max(0, ox), min(src.shape[1], ox + side)
            sq[yy, sx0 - ox:sx1 - ox, :3] = src[sy, sx0:sx1, :3]
            sq[yy, sx0 - ox:sx1 - ox, 3] = alpha[sy, sx0:sx1] * keep[sy, sx0:sx1]
    return sq, ox, oy


def main(path):
    src = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    alpha = np.clip((src[..., 3] * 255.0 - CUT) / (255.0 - CUT), 0, 1)
    y0, y1 = runs((alpha > 0).sum(axis=1) > 0, GAP)[0]
    x0, x1 = runs((alpha[y0:y1] > 0).sum(axis=0) > 0, GAP)[2]
    ys = np.nonzero(alpha[y0:y1, x0:x1].sum(axis=1) > 0)[0]
    by0, by1 = y0 + ys[0], y0 + ys[-1] + 1
    side = int(max(x1 - x0, by1 - by0) * (1 + 2 * PAD))
    icx, icy = (x0 + x1) / 2.0, (by0 + by1) / 2.0
    # the parts: the biggest is the anvil, the next the hammer (the marks and
    # specks are smaller); each keeps its soft edge (grown by two pixels)
    solid = np.zeros_like(alpha, dtype=bool)
    solid[by0:by1, x0:x1] = alpha[by0:by1, x0:x1] > 0.5
    lab, n = ndimage.label(solid)
    sizes = sorted(((int((lab == i).sum()), i) for i in range(1, n + 1)), reverse=True)
    anvil = ndimage.binary_dilation(lab == sizes[0][1], iterations=2)
    hammer = ndimage.binary_dilation(lab == sizes[1][1], iterations=2)
    sq, ox, oy = square(src, alpha, anvil, icx, icy, side)
    save("fx_anvil", sq)
    # the handle's end: the hammer's point farthest from its head, a little in
    hy, hx = np.nonzero(lab == sizes[1][1])
    mx, my = hx.mean(), hy.mean()
    far = np.argmax((hx - mx) ** 2 + (hy - my) ** 2)
    tx, ty = hx[far], hy[far]
    d = math.hypot(mx - tx, my - ty)
    px, py = tx + (mx - tx) / d * 6, ty + (my - ty) / d * 6
    r = math.sqrt(((hx - px) ** 2 + (hy - py) ** 2).max()) * 1.08 + 3
    hside = int(2 * r)
    hq, _, _ = square(src, alpha, hammer, px, py, hside)
    save("fx_hammer", hq)
    # how far it turns down (anticlockwise on screen) until its head meets the
    # anvil, a degree short of touching
    ay, ax = np.nonzero(lab == sizes[0][1])
    anv = set(zip(ax.tolist(), ay.tolist()))
    land = None
    for k in range(0, 900):
        a = math.radians(k / 10.0)
        c, s = math.cos(a), math.sin(a)
        # screen y points down: turning anticlockwise on screen
        rx = px + (hx - px) * c + (hy - py) * s
        ry = py - (hx - px) * s + (hy - py) * c
        if any((int(round(x)), int(round(y))) in anv for x, y in zip(rx, ry)):
            land = k / 10.0 - 1.0
            break
    print("icon square %d px; anvil cut; hammer square %d px" % (side, hside))
    print("UpFx.HAMMER = { x = %.3f, y = %.3f, size = %.3f, down = %.1f }"
          % ((px - ox) / side, (py - oy) / side, hside / side, land))


if __name__ == "__main__":
    main(sys.argv[1])
