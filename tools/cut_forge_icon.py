#!/usr/bin/env python3
"""Make the 대장간 menu icon from the user's smithy picture, without its smoke.

    python3 -I tools/cut_forge_icon.py tools/art/forge_house.png

The picture: a house with a chimney, a forge and an anvil, and two puffs of
smoke above the chimney. The puffs (the parts that lie wholly above the
house) are left out; what remains is cut as tools/cut_icon.py cuts an icon
(centred in its square) to BigIdleHeroes/Media/Art/icon_forge.tga.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cut_icon  # noqa: E402

CUT = 40


def main(path):
    im = np.asarray(Image.open(path).convert("RGBA")).copy()
    lab, n = ndimage.label(im[..., 3] > CUT)
    sizes = [(int((lab == i).sum()), i) for i in range(1, n + 1)]
    house = max(sizes)[1]
    top = np.nonzero(lab == house)[0].min()
    # every part whose lowest point is above the house's top is smoke
    drop = np.zeros(lab.shape, dtype=bool)
    for _, i in sizes:
        ys = np.nonzero(lab == i)[0]
        if ys.max() < top + 20 and i != house:
            drop |= lab == i
    drop = ndimage.binary_dilation(drop, iterations=3)
    im[drop, 3] = 0
    tmp = os.path.join(ROOT, "tests", "out", "media", "_forge_src.png")
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    Image.fromarray(im, "RGBA").save(tmp)
    cut_icon.main(tmp, "icon_forge")
    os.remove(tmp)


if __name__ == "__main__":
    main(sys.argv[1])
