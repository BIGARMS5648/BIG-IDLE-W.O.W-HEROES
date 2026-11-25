#!/usr/bin/env python3
"""Make the main window's logo (Media/logo.tga) from the wide logo picture.

    python3 -I tools/cut_logo.py tools/art/logo_wide.webp [--panel]

The picture: the logo on a dark slate panel inside a glowing rounded frame.
The panel's frame is cut away and its dark background made transparent (the
logo's silver and its blue glow kept, by how much brighter or bluer than the
background they are), so the logo sits on the window's own header. Written
512 wide at the top of a 512x256 texture (USED_H rows used; the rest clear),
with a PNG twin in tests/out/media for the layout preview.
"""
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CROP = (28, 30, 1972, 626)     # inside the picture's own frame
BG_L, SPAN_L = 72.0, 90.0      # brightness of the background, and the ramp above it
BG_B, SPAN_B = 40.0, 50.0      # blueness (b - (r+g)/2) of the background, and its ramp
W, H = 512, 256
CORNER = 110                   # the corners of the crop, left clear
# --panel: the whole picture kept; clear only outside its rounded frame
PANEL_INSET, PANEL_RADIUS, PANEL_FADE = 3, 118, 6


def panel(path):
    """The picture as it is, its glowing frame and dark panel kept: only what
    lies outside the frame's rounded corners is left clear."""
    im = Image.open(path).convert("RGB")
    a = np.asarray(im, dtype=np.float64)
    h, w = a.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    m, r = PANEL_INSET, PANEL_RADIUS
    # distance outside a rounded rectangle m from the picture's edges
    dx = np.maximum(np.maximum(m + r - xs, xs - (w - 1 - m - r)), 0)
    dy = np.maximum(np.maximum(m + r - ys, ys - (h - 1 - m - r)), 0)
    out_d = np.hypot(dx, dy) - r
    alpha = np.clip(1 - out_d / PANEL_FADE, 0, 1)
    return a, alpha


def write(a, alpha, name, used_note):
    rgba = np.dstack([a / 255.0, alpha])
    hgt, wid = a.shape[:2]
    used = int(round(W * hgt / wid))
    out = np.zeros((H, W, 4))

    def rs(ch):
        return np.asarray(Image.fromarray(ch.astype(np.float32), "F").resize((W, used), Image.LANCZOS), dtype=np.float64)

    al = np.clip(rs(rgba[..., 3]), 0, 1)
    for c in range(3):
        pm = rs(rgba[..., c] * rgba[..., 3])
        out[:used, :, c] = np.where(al > 1e-4, np.clip(pm / np.maximum(al, 1e-4), 0, 1), 0)
    out[:used, :, 3] = al
    arr = np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8)
    png = os.path.join(ROOT, "tests", "out", "media")
    os.makedirs(png, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(png, name + ".png"))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 8)
    with open(os.path.join(ROOT, "BigIdleHeroes", "Media", name + ".tga"), "wb") as f:
        f.write(header)
        f.write(arr[::-1, :, [2, 1, 0, 3]].tobytes())
    print("%s: %dx%d used of %dx%d (aspect %.3f) %s" % (name, W, used, W, H, wid / hgt, used_note))


def main(path):
    im = Image.open(path).convert("RGB").crop(CROP)
    a = np.asarray(im, dtype=np.float64)
    lum = a.mean(axis=2)
    blue = a[..., 2] - (a[..., 0] + a[..., 1]) / 2
    alpha = np.maximum(np.clip((lum - BG_L) / SPAN_L, 0, 1), np.clip((blue - BG_B) / SPAN_B, 0, 1) * 0.9)
    # the frame's rounded corners reach into the crop: the logo never does
    c = CORNER
    for ys in (slice(0, c), slice(-c, None)):
        for xs in (slice(0, c), slice(-c, None)):
            alpha[ys, xs] = 0
    rgba = np.dstack([a / 255.0, alpha])
    used = int(round(W * im.height / im.width))
    # resize with premultiplied colour
    out = np.zeros((H, W, 4))

    def rs(ch):
        return np.asarray(Image.fromarray(ch.astype(np.float32), "F").resize((W, used), Image.LANCZOS), dtype=np.float64)

    al = np.clip(rs(rgba[..., 3]), 0, 1)
    for c in range(3):
        pm = rs(rgba[..., c] * rgba[..., 3])
        out[:used, :, c] = np.where(al > 1e-4, np.clip(pm / np.maximum(al, 1e-4), 0, 1), 0)
    out[:used, :, 3] = al
    arr = np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8)
    png = os.path.join(ROOT, "tests", "out", "media")
    os.makedirs(png, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(png, "logo.png"))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 8)
    with open(os.path.join(ROOT, "BigIdleHeroes", "Media", "logo.tga"), "wb") as f:
        f.write(header)
        f.write(arr[::-1, :, [2, 1, 0, 3]].tobytes())
    print("logo: %dx%d used of %dx%d (aspect %.3f)" % (W, used, W, H, im.width / im.height))


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "--panel":
        a, alpha = panel(sys.argv[1])
        write(a, alpha, "logo", "(panel kept)")
    else:
        main(sys.argv[1])
