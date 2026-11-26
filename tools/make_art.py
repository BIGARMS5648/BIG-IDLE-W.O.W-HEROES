#!/usr/bin/env python3
"""Generate the addon's UI art.

Everything in BigIdleHeroes/Media is drawn by this script: panels, buttons,
slots, rings, glyphs and the scenery behind the battle. Nothing is copied from
any game. Output is 32-bit uncompressed TGA with power-of-two sizes (the format
every WoW client reads); PNG twins go to tests/out/media for the layout preview.

    pip install pillow numpy
    python3 tools/make_art.py
"""
import math
import os
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TGA = os.path.join(ROOT, "BigIdleHeroes", "Media")
OUT_PNG = os.path.join(ROOT, "tests", "out", "media")
SS = 4  # supersampling factor for anti-aliased edges


# ---------------------------------------------------------------- helpers
def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def blank(w, h):
    return np.zeros((h, w, 4), dtype=np.float64)


def mask_from(draw_fn, w, h, blur=0.0):
    """Anti-aliased 0..1 mask: draw_fn(draw, scale) paints white on black."""
    im = Image.new("L", (w * SS, h * SS), 0)
    draw_fn(ImageDraw.Draw(im), SS)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur * SS))
    im = im.resize((w, h), Image.LANCZOS)
    return np.asarray(im, dtype=np.float64) / 255.0


def rr(w, h, r, inset=0.0, blur=0.0):
    def fn(d, s):
        d.rounded_rectangle([inset * s, inset * s, w * s - 1 - inset * s, h * s - 1 - inset * s],
                            radius=max(0.0, (r - inset)) * s, fill=255)
    return mask_from(fn, w, h, blur)


def vgrad(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    return np.broadcast_to(np.asarray(top)[None, None, :] * (1 - t) + np.asarray(bottom)[None, None, :] * t, (h, w, 3)).copy()


def over(dst, rgb, alpha):
    """Composite a color (array or constant) with an alpha mask over dst (RGBA float)."""
    a = np.clip(alpha, 0, 1)[..., None]
    rgb = np.broadcast_to(np.asarray(rgb, dtype=np.float64), dst[..., :3].shape)
    out_a = a + dst[..., 3:4] * (1 - a)
    safe = np.where(out_a > 1e-6, out_a, 1)
    dst[..., :3] = (rgb * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / safe
    dst[..., 3:4] = out_a
    return dst


def save(name, img):
    arr = np.clip(img * 255.0 + 0.5, 0, 255).astype(np.uint8)
    h, w = arr.shape[:2]
    assert w & (w - 1) == 0 and h & (h - 1) == 0, "%s: sizes must be powers of two" % name
    os.makedirs(OUT_TGA, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))
    # TGA: type 2 (uncompressed true color), 32 bpp, 8 alpha bits, bottom-left origin
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    bgra = arr[::-1, :, [2, 1, 0, 3]]
    with open(os.path.join(OUT_TGA, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(bgra.tobytes())
    return name


WHITE = np.array([1.0, 1.0, 1.0])


# ---------------------------------------------------------------- chrome
def panel():
    w = h = 64
    img = blank(w, h)
    over(img, vgrad(w, h, hexrgb("b9c8e2"), hexrgb("55688c")), rr(w, h, 14))            # border (silver)
    over(img, hexrgb("2f7bff"), rr(w, h, 14, inset=1.5))                                 # the logo's blue line
    over(img, vgrad(w, h, hexrgb("16223a"), hexrgb("0b1222")), rr(w, h, 14, inset=2.5)) # body
    hl = rr(w, h, 14, inset=2) - rr(w, h, 14, inset=3)                                  # inner highlight, top only
    fade = np.clip(1 - np.linspace(0, 1, h) * 3.0, 0, 1)[:, None]
    over(img, WHITE, np.clip(hl, 0, 1) * fade * 0.22)
    return save("panel", img)


def card():
    w = h = 64
    img = blank(w, h)
    over(img, vgrad(w, h, hexrgb("7d93bd"), hexrgb("34466c")), rr(w, h, 10))
    over(img, vgrad(w, h, hexrgb("1c2a46"), hexrgb("121c32")), rr(w, h, 10, inset=1.5))
    return save("card", img)


def inset():
    w = h = 32
    img = blank(w, h)
    over(img, hexrgb("26324f"), rr(w, h, 8))
    over(img, vgrad(w, h, hexrgb("070a12"), hexrgb("0d1220")), rr(w, h, 8, inset=1))
    return save("inset", img)


def button():
    # light, glossy, meant to be tinted with SetVertexColor
    w, h = 64, 32
    img = blank(w, h)
    over(img, np.array([0.0, 0.0, 0.0]), rr(w, h, 10) * 0.75)                            # dark outline
    body = vgrad(w, h, np.array([1.0, 1.0, 1.0]), np.array([0.62, 0.62, 0.62]))
    over(img, body, rr(w, h, 10, inset=1.5))
    gloss = rr(w, h, 10, inset=3) * np.clip(1 - np.linspace(0, 1, h) * 2.4, 0, 1)[:, None]
    over(img, WHITE, gloss * 0.35)
    rim = rr(w, h, 10, inset=1.5) - rr(w, h, 10, inset=2.5)                              # darker bottom rim
    over(img, np.array([0.25, 0.25, 0.25]), np.clip(rim, 0, 1) * np.clip(np.linspace(-1, 1, h), 0, 1)[:, None] * 0.8)
    return save("button", img)


def pill():
    # white capsule; tint and fade it from Lua
    w, h = 64, 32
    img = blank(w, h)
    over(img, vgrad(w, h, np.array([1.0, 1.0, 1.0]), np.array([0.82, 0.82, 0.82])), rr(w, h, 16))
    return save("pill", img)


def slot():
    w = h = 64
    img = blank(w, h)
    over(img, hexrgb("2e3b5c"), rr(w, h, 9))
    over(img, vgrad(w, h, hexrgb("0a0e18"), hexrgb("121829")), rr(w, h, 9, inset=1.5))
    return save("slot", img)


def frame():
    # rounded outline with a soft outer glow, tinted by quality / state color
    w = h = 64
    img = blank(w, h)
    ring = rr(w, h, 9) - rr(w, h, 9, inset=3)
    glow = rr(w, h, 9, inset=1, blur=2.0) - rr(w, h, 9, inset=4)
    over(img, WHITE, np.clip(glow, 0, 1) * 0.35)
    over(img, WHITE, np.clip(ring, 0, 1))
    return save("frame", img)


def frame_grad(name, stops):
    # frame painted in colours running corner to corner (bottom left to top
    # right): a grade whose colours run across its name (Data/Items.lua)
    w = h = 64
    img = blank(w, h)
    ring = rr(w, h, 9) - rr(w, h, 9, inset=3)
    glow = rr(w, h, 9, inset=1, blur=2.0) - rr(w, h, 9, inset=4)
    t = (np.arange(w)[None, :] + (h - 1 - np.arange(h))[:, None]) / float(w + h - 2)
    cols = [hexrgb(c) for c in stops]
    x = t * (len(cols) - 1)
    i = np.minimum(np.floor(x).astype(int), len(cols) - 2)
    f = (x - i)[..., None]
    rgb = np.stack(cols)[i] * (1 - f) + np.stack(cols)[i + 1] * f
    over(img, rgb, np.clip(glow, 0, 1) * 0.35)
    over(img, rgb, np.clip(ring, 0, 1))
    return save(name, img)


def frame_arcana():
    # the colours of the user's badge picture: cyan, periwinkle, orchid
    return frame_grad("frame_arcana", ["45e6e6", "8ea6f2", "d89ee0"])


def corners():
    # what lies outside frame's rounded outline (reaching half into its line),
    # white: laid over a picture's corners in the colour around the picture,
    # with frame over it, it rounds the picture's corners
    w = h = 64
    img = blank(w, h)
    over(img, WHITE, np.clip(1 - rr(w, h, 9, inset=1.5), 0, 1))
    return save("corners", img)


def fades():
    # grad_v with rounded corners, as 9-slices: shading across the top or the
    # bottom of a rounded window keeps inside its corners
    w = h = 64
    shape = rr(w, h, 16)
    for name, fade in (("fade_down", np.linspace(1, 0, h)), ("fade_up", np.linspace(0, 1, h))):
        img = blank(w, h)
        img[..., :3] = 1.0
        img[..., 3] = shape * fade[:, None]
        save(name, img)
    return "fades"


def ring():
    w = h = 128

    def circ(r, blur=0.0):
        return mask_from(lambda d, s: d.ellipse([(64 - r) * s, (64 - r) * s, (64 + r) * s, (64 + r) * s], fill=255), w, h, blur)

    img = blank(w, h)
    over(img, np.array([0.0, 0.0, 0.0]), np.clip(circ(63) - circ(52), 0, 1) * 0.55)       # dark seat
    band = np.clip(circ(61) - circ(54), 0, 1)
    over(img, vgrad(w, h, np.array([1.0, 1.0, 1.0]), np.array([0.68, 0.68, 0.68])), band)
    return save("ring", img)


def circle():
    w = h = 64
    img = blank(w, h)
    m = mask_from(lambda d, s: d.ellipse([1 * s, 1 * s, 63 * s - 1, 63 * s - 1], fill=255), w, h)
    over(img, vgrad(w, h, np.array([1.0, 1.0, 1.0]), np.array([0.8, 0.8, 0.8])), m)
    return save("circle", img)


def bar():
    w, h = 64, 16
    img = blank(w, h)
    body = vgrad(w, h, np.array([1.0, 1.0, 1.0]), np.array([0.6, 0.6, 0.6]))
    img[..., :3] = body
    img[..., 3] = 1.0
    gloss = np.clip(1 - np.linspace(0, 1, h) * 2.6, 0, 1)[:, None] * np.ones((h, w))
    over(img, WHITE, gloss * 0.3)
    return save("bar", img)


def badge():
    """The notification dot: a glossy red ball with a dark red rim and a white
    shine at the upper left. Painted in its own colours (never tinted)."""
    w = h = 64
    img = blank(w, h)

    def disc(cx, cy, r, blur=0.0):
        return mask_from(lambda d, s: d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=255), w, h, blur)

    outer = disc(32, 32, 30.5)
    inner = disc(32, 32, 27.5)
    over(img, hexrgb("8a0000"), outer)                                  # rim
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip(((xx - 14) + (yy - 12)) / 70.0, 0, 1)[..., None]        # top-left bright → bottom-right deep
    body = hexrgb("ff2a2a") * (1 - t) + hexrgb("ad0005") * t
    over(img, body, inner)
    edge = np.clip(inner - disc(32, 32, 25.5), 0, 1) * np.clip((xx + yy - 64) / 30.0, 0, 1)
    over(img, hexrgb("ff3b3b"), edge * 0.7)                              # light lower-right edge inside the rim

    # a crescent along the upper-left edge, brightest at the top
    crescent = np.clip(disc(32, 32, 24.5, blur=0.5) - disc(37.5, 38.5, 25.5, blur=0.8), 0, 1)
    crescent *= np.clip(1 - (xx - 34) / 12.0, 0, 1) * np.clip(1 - (yy - 26) / 10.0, 0, 1)
    fade = np.clip(1 - (yy - 9) / 26.0, 0.25, 1)
    over(img, WHITE, crescent * fade * 0.9)
    dot = mask_from(lambda d, s: d.ellipse([11 * s, 30 * s, 15.5 * s, 36 * s], fill=255), w, h, blur=0.4)
    over(img, WHITE, dot * 0.5)
    return save("badge", img)


def glow():
    w = h = 64
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - 31.5) ** 2 + (yy - 31.5) ** 2) / 31.5
    a = np.clip(1 - d, 0, 1) ** 1.8
    img = blank(w, h)
    img[..., :3] = 1.0
    img[..., 3] = a
    return save("glow", img)


def shadow():
    w = h = 64
    img = blank(w, h)
    img[..., 3] = rr(w, h, 14, inset=10, blur=5.0) * 0.8
    return save("shadow", img)


def gradients():
    w, h = 64, 8
    img = blank(w, h)
    img[..., :3] = 1.0
    img[..., 3] = np.linspace(1, 0, w)[None, :] * np.ones((h, w))
    save("grad_h", img)
    w, h = 8, 64
    img = blank(w, h)
    img[..., :3] = 1.0
    img[..., 3] = np.linspace(1, 0, h)[:, None] * np.ones((h, w))
    return save("grad_v", img)


# ---------------------------------------------------------------- glyphs
def glyph(name, draw_fn):
    w = h = 64
    img = blank(w, h)
    m = mask_from(draw_fn, w, h)
    over(img, np.array([0.0, 0.0, 0.0]), np.clip(mask_from(draw_fn, w, h, blur=1.6) * 1.4, 0, 1) * 0.6)  # soft shadow
    over(img, WHITE, m)
    return save(name, img)


def P(s, *pts):
    return [(x * s, y * s) for x, y in pts]


def glyphs():
    glyph("lock", lambda d, s: (
        d.arc([20 * s, 8 * s, 44 * s, 36 * s], 180, 360, fill=255, width=6 * s),
        d.line([23 * s, 22 * s, 23 * s, 30 * s], fill=255, width=6 * s),
        d.line([41 * s, 22 * s, 41 * s, 30 * s], fill=255, width=6 * s),
        d.rounded_rectangle([14 * s, 28 * s, 50 * s, 56 * s], radius=5 * s, fill=255),
        d.ellipse([28 * s, 36 * s, 36 * s, 44 * s], fill=0),
        d.rectangle([30 * s, 42 * s, 34 * s, 50 * s], fill=0)))
    glyph("check", lambda d, s: d.line(P(s, (12, 34), (26, 48), (52, 16)), fill=255, width=9 * s, joint="curve"))
    glyph("plus", lambda d, s: (
        d.rounded_rectangle([27 * s, 12 * s, 37 * s, 52 * s], radius=3 * s, fill=255),
        d.rounded_rectangle([12 * s, 27 * s, 52 * s, 37 * s], radius=3 * s, fill=255)))
    glyph("close", lambda d, s: (
        d.line(P(s, (16, 16), (48, 48)), fill=255, width=9 * s),
        d.line(P(s, (48, 16), (16, 48)), fill=255, width=9 * s)))
    glyph("arrow", lambda d, s: d.line(P(s, (24, 12), (44, 32), (24, 52)), fill=255, width=9 * s, joint="curve"))

    def star(d, s):
        pts = []
        for i in range(10):
            r = 26 if i % 2 == 0 else 11
            a = -math.pi / 2 + i * math.pi / 5
            pts.append(((32 + r * math.cos(a)) * s, (33 + r * math.sin(a)) * s))
        d.polygon(pts, fill=255)
    glyph("star", star)

    def crown(d, s):
        d.polygon(P(s, (8, 46), (10, 18), (22, 32), (32, 12), (42, 32), (54, 18), (56, 46)), fill=255)
        d.rounded_rectangle([8 * s, 48 * s, 56 * s, 55 * s], radius=2 * s, fill=255)
    glyph("crown", crown)

    def stroke(d, s, pts, w):
        """A polyline with rounded joints and rounded ends."""
        d.line(P(s, *pts), fill=255, width=int(w * s), joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse([(x - w / 2) * s, (y - w / 2) * s, (x + w / 2) * s, (y + w / 2) * s], fill=255)

    # auto advance: two chevrons pointing right (on to the next stage)
    # (a chevron's weight sits on its open side: drawn a little right of
    # the middle so the pair looks centred)
    def auto(d, s):
        stroke(d, s, [(18, 15), (33, 32), (18, 49)], 8)
        stroke(d, s, [(37, 15), (52, 32), (37, 49)], 8)
    glyph("auto", auto)

    # repeat: one clockwise loop; the head sits on the end of the arc and
    # points along it
    def repeat(d, s):
        cx, cy, r, w = 32.0, 33.0, 17.0, 7.0
        a0, a1 = 20.0, 285.0  # degrees, clockwise from 3 o'clock (y down)
        R = r + w / 2
        d.arc([(cx - R) * s, (cy - R) * s, (cx + R) * s, (cy + R) * s], a0, a1, fill=255, width=int(w * s))
        sx, sy = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
        d.ellipse([(sx - w / 2) * s, (sy - w / 2) * s, (sx + w / 2) * s, (sy + w / 2) * s], fill=255)
        t = math.radians(a1)
        ex, ey = cx + r * math.cos(t), cy + r * math.sin(t)
        fx, fy = -math.sin(t), math.cos(t)   # direction of travel at the end
        nx, ny = math.cos(t), math.sin(t)    # outward
        bx, by = ex - fx * 3, ey - fy * 3
        d.polygon(P(s, (bx + nx * 10, by + ny * 10), (ex + fx * 12, ey + fy * 12), (bx - nx * 10, by - ny * 10)), fill=255)
    glyph("repeat", repeat)

    def skull(d, s):
        d.ellipse([12 * s, 8 * s, 52 * s, 44 * s], fill=255)
        d.rounded_rectangle([22 * s, 36 * s, 42 * s, 54 * s], radius=3 * s, fill=255)
        d.ellipse([19 * s, 21 * s, 29 * s, 32 * s], fill=0)
        d.ellipse([35 * s, 21 * s, 45 * s, 32 * s], fill=0)
        d.polygon(P(s, (32, 33), (29, 40), (35, 40)), fill=0)
        for x in (27, 32, 37):
            d.line([x * s, 46 * s, x * s, 54 * s], fill=0, width=2 * s)
    glyph("skull", skull)


# ---------------------------------------------------------------- scenery
def scenery(name, ridge):
    """Layered grey silhouettes; Lua tints the whole image per zone."""
    w, h = 512, 128
    img = np.zeros((h, w, 4))
    img[..., 3] = 1.0
    img[..., :3] = vgrad(w, h, np.array([0.42] * 3), np.array([0.95] * 3))
    xs = np.arange(w)
    yy = np.arange(h)[:, None]
    rng = np.random.default_rng(len(name) * 7 + 3)
    # sun / moon disc
    cy, cx = 34, 396
    d = np.sqrt((np.arange(w)[None, :] - cx) ** 2 + (yy - cy) ** 2)
    img[..., :3] += (np.clip(1 - d / 26, 0, 1) ** 2 * 0.35)[..., None]
    img[..., :3] += (np.clip(1 - d / 70, 0, 1) ** 2 * 0.12)[..., None]
    for layer, (base, amp, lum) in enumerate([(58, 20, 0.62), (74, 16, 0.44), (90, 11, 0.30)]):
        line = ridge(xs, layer, rng) * amp + base
        m = np.clip((yy - line[None, :]) / 1.5, 0, 1)
        fade = np.clip((yy - line[None, :]) / 60.0, 0, 1) * 0.12   # a little depth haze
        col = np.broadcast_to((lum - fade)[..., None], (h, w, 3))
        img[..., :3] = img[..., :3] * (1 - m[..., None]) + col * m[..., None]
    # ground
    g = np.clip((yy - 106) / 1.5, 0, 1) * np.ones((h, w))
    ground = vgrad(w, h, np.array([0.34] * 3), np.array([0.16] * 3))
    ground[:106] = 0.34
    ground[106:] = np.linspace(0.34, 0.17, h - 106)[:, None, None]
    img[..., :3] = img[..., :3] * (1 - g[..., None]) + ground * g[..., None]
    edge = np.clip(1 - np.abs(yy - 106.5) / 1.2, 0, 1) * np.ones((h, w))
    img[..., :3] = np.clip(img[..., :3] + edge[..., None] * 0.10, 0, 1)
    return save(name, np.clip(img, 0, 1))


def ridge_hills(xs, layer, rng):
    out = np.zeros(len(xs))
    for k in range(1, 5):
        out += np.sin(xs / (90.0 / k) * (1 + layer * 0.35) + rng.uniform(0, 6.28)) / k
    return out / 2.2


def ridge_peaks(xs, layer, rng):
    period = 110 - layer * 22
    phase = rng.uniform(0, period)
    tri = np.abs(((xs + phase) % period) / period * 2 - 1) * 2 - 1
    period2 = period * 0.37
    tri2 = np.abs(((xs + phase * 2) % period2) / period2 * 2 - 1) * 2 - 1
    return tri * 0.75 + tri2 * 0.25


def ridge_ruins(xs, layer, rng):
    out = np.ones(len(xs)) * 0.6
    x = 0
    while x < len(xs):
        wdt = int(rng.integers(14, 46))
        if rng.random() < 0.55:
            out[x:x + wdt] = rng.uniform(-1.0, 0.3)
            if rng.random() < 0.4:  # a broken top
                out[x + wdt // 3:x + wdt // 2] += 0.35
        x += wdt + int(rng.integers(4, 30))
    return out


def main():
    for make in (panel, card, inset, button, pill, slot, frame, frame_arcana, corners, fades, ring, circle,
                 badge, bar, glow, shadow, gradients):
        make()
    glyphs()
    scenery("scene_hills", ridge_hills)
    scenery("scene_peaks", ridge_peaks)
    scenery("scene_ruins", ridge_ruins)
    files = sorted(os.listdir(OUT_TGA))
    total = sum(os.path.getsize(os.path.join(OUT_TGA, f)) for f in files)
    print("wrote %d textures to %s (%.1f KB)" % (len(files), OUT_TGA, total / 1024.0))


if __name__ == "__main__":
    main()
