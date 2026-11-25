#!/usr/bin/env python3
"""Cut the scroll bar sheet into the addon's bars and grips.

    python3 -I tools/cut_scrollbar.py tools/art/scrollbar_sheet.webp

The sheet (transparent background) holds a bar, a grip and arrows: the
bar is written white (it is tinted in the game: a scroll bar's track, the
lines between stages, the role stripes), made even across, upright and laid
on its side, with a bend (a quarter turn, the same bar bent round its inner
corner) where a line turns; the grip
keeps its own silver, and a blue twin of it is made for the grip in use; the
arrows (left, right, up, down) are written white: every arrow of the
interface (page and step buttons, the list caret, the goal box).
Written to BigIdleHeroes/Media/Art/<id>.tga (Data/Art.lua lists them) with PNG
twins in tests/out/media for the layout preview.
"""
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media", "Art")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
# (left, top, right, bottom) of each piece on the sheet
BAR_V = (541, 700, 550, 963)
GRIP_V = (664, 771, 681, 881)
ARROW_L = (1029, 377, 1056, 424)
ARROW_R = (1231, 377, 1257, 424)
ARROW_U = (621, 388, 666, 412)
ARROW_D = (821, 388, 866, 414)
BLUE = np.array([191.0 / 186.0, 213.0 / 193.0, 233.0 / 202.0])  # the sheet's blue grip against its silver one


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
    print("%-12s %dx%d" % (name, w, h))


def piece(src, box, size):
    crop = src[box[1]:box[3], box[0]:box[2]]
    out = np.zeros((size[1], size[0], 4))
    a = np.asarray(Image.fromarray(crop[..., 3].astype(np.float32), "F").resize(size, Image.LANCZOS), dtype=np.float64)
    a = np.clip(a, 0, 1)
    for c in range(3):
        pm = np.asarray(Image.fromarray((crop[..., c] * crop[..., 3]).astype(np.float32), "F").resize(size, Image.LANCZOS), dtype=np.float64)
        out[..., c] = np.where(a > 1e-4, np.clip(pm / np.maximum(a, 1e-4), 0, 1), 1.0)
    out[..., 3] = a
    return out


def bend(across, n=8, ss=16):
    """The bar turning a quarter (from the left, then down): n x n, its inner
    corner at the bottom left, the bar's profile across (inner to outer)
    swept round it, so it meets a square-ended bar on each side."""
    k = len(across)
    big = n * ss
    c = (np.arange(big) + 0.5) / big
    x = c[None, :]               # 0 at the left
    y = (1.0 - c)[:, None]       # 0 at the bottom
    r = np.sqrt(x * x + y * y)
    idx = np.minimum((r * k).astype(int), k - 1)
    a = np.where(r < 1.0, across[idx], 0.0)
    a = a.reshape(n, ss, n, ss).mean(axis=(1, 3))
    out = np.ones((n, n, 4))
    out[..., 3] = a
    return out


def main(path):
    src = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    bar = piece(src, BAR_V, (8, 256))
    bar[..., :3] = 1.0  # tinted in the game
    bar[..., 3] = (bar[..., 3] + bar[:, ::-1, 3]) / 2  # the same at both edges
    save("sb_bar_v", bar)
    save("sb_bar_h", bar.transpose(1, 0, 2).copy())
    save("sb_bend", bend(bar[128, :, 3]))
    grip = piece(src, GRIP_V, (16, 128))
    save("sb_grip_v", grip)
    hot = grip.copy()
    hot[..., :3] = np.clip(grip[..., :3] * BLUE, 0, 1)
    save("sb_grip_v_hot", hot)
    # the page arrows, white (tinted in the game)
    for name, box, size in (("sb_arrow_left", ARROW_L, (32, 64)), ("sb_arrow_right", ARROW_R, (32, 64)),
                            ("sb_arrow_up", ARROW_U, (64, 32)), ("sb_arrow_down", ARROW_D, (64, 32))):
        p = piece(src, box, size)
        p[..., :3] = 1.0
        save(name, p)


if __name__ == "__main__":
    main(sys.argv[1])
