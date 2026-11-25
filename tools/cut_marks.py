#!/usr/bin/env python3
"""Make the item slot's better-gear arrow from the user's picture.

    python3 -I tools/cut_marks.py tools/art/upgrade_arrows.png

upgrade_arrows.png: green up arrows of several sizes, the biggest first in the
top row. The biggest is made the "better gear" arrow, Media/Art/icon_upgrade.tga
(64x64, as tools/cut_icon.py makes icons).
"""
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cut_icon  # noqa: E402

OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media", "Art")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
CUT = 40
CELL_W, CELL_H, COLS, ROWS = 96, 64, 5, 4
NUM_H = 56       # a number's height in its cell
MARGIN = 2       # room at the cell's right edge
W, H = 512, 256


def runs(mask):
    out, start = [], None
    for i, v in enumerate(mask):
        if v and start is None:
            start = i
        if not v and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(mask)))
    return out


def arrow(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[..., 3] > CUT
    rows = runs(a.any(1))
    top = rows[0]
    cols = runs(a[top[0]:top[1]].any(0))
    x0, x1 = cols[0]
    tmp = os.path.join(OUT_PNG, "_arrow_src.png")
    os.makedirs(OUT_PNG, exist_ok=True)
    im.crop((x0, top[0], x1, top[1])).save(tmp)
    cut_icon.main(tmp, "icon_upgrade")
    os.remove(tmp)


if __name__ == "__main__":
    arrow(sys.argv[1])
