#!/usr/bin/env python3
"""Tests for tools/import_art.py on synthetic art.

    python3 tests/test_import_art.py

Builds image-model-like sheets in a temporary folder (stick figures with a
detached sword tip, uneven sizes / spacing / baselines, transparent, magenta
and noisy off-white JPEG backgrounds, stray specks, a missing and an extra
frame), runs the importer into a temporary add-on folder and checks the
textures and the manifest (loaded with Lua 5.1 through lupa). Contact sheets
of the run go to tests/out/art_test/ for a look by eye.
Needs Pillow, numpy and lupa.
"""
import hashlib
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, "tools", "import_art.py")
PREVIEW = os.path.join(HERE, "out", "art_test")
REAL_MANIFEST = os.path.join(ROOT, "BigIdleWoWHeroes", "Data", "Art.lua")

SS = 4                       # supersampling for anti-aliased edges
SHEET = (1536, 1024)
OUTLINE = (28, 22, 34, 255)
TIP = (0, 220, 255, 255)     # the detached sword tip: a colour used nowhere else
MAGENTA = (255, 0, 255)
OFFWHITE = (236, 231, 222)

rng = np.random.default_rng(20261120)


# ---------------------------------------------------------------------------
# Drawing helpers (supersampled tiles, downsampled to 1x)
# ---------------------------------------------------------------------------
def seg(d, p, q, col, w):
    for width, c in ((w + 3 * SS, OUTLINE), (w, col)):
        d.line([p, q], fill=c, width=int(width))
        for x, y in (p, q):
            r = width / 2.0
            d.ellipse([x - r, y - r, x + r, y + r], fill=c)


def disc(d, c, r, col):
    d.ellipse([c[0] - r - 1.5 * SS, c[1] - r - 1.5 * SS, c[0] + r + 1.5 * SS, c[1] + r + 1.5 * SS], fill=OUTLINE)
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col)


def poly(d, pts, col):
    d.polygon(pts, fill=col, outline=OUTLINE, width=int(1.5 * SS))


def pol(p, ang, length):
    a = math.radians(ang)
    return (p[0] + length * math.cos(a), p[1] - length * math.sin(a))


def finish_tile(im, rotate=0.0, pivot=None, mirror=False):
    if rotate:
        im = im.rotate(rotate, resample=Image.Resampling.BICUBIC, center=pivot)
    if mirror:
        im = ImageOps.mirror(im)
    small = im.resize((im.width // SS, im.height // SS), Image.Resampling.LANCZOS)
    return small.crop(small.getbbox())


def hero_tile(S, anim, k, body):
    """A stick-figure hero facing right, feet on the tile bottom; the sword tip is detached."""
    T = int(2.2 * S)
    u = S * SS
    im = Image.new("RGBA", (T * SS, T * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, base = T * SS / 2.0, T * SS - 0.06 * u
    bob = 0.015 * u * (k % 2) if anim == "idle" else 0.0
    lean = -(0.05 + 0.04 * k) * u if anim == "hit" else 0.0
    spread = 0.12
    if anim == "walk":
        spread = 0.04 + 0.16 * abs(math.cos(k * math.pi / 3))
    hip = (cx, base - 0.42 * u - bob)
    neck = (cx + lean, base - 0.72 * u - bob)
    head = (cx + 1.2 * lean, base - 0.84 * u - bob)
    shoulder = (neck[0], neck[1] + 0.05 * u)
    hand_a, sword_a = {
        "idle": (-35, 55 + 3 * k), "walk": (-35 + 8 * math.sin(k), 55), "attack": (10, (80, 64, 48, 40)[min(k, 3)]),
        "cast": (40, 50), "hit": (-50, 30), "death": (-35, 55),
    }[anim]
    seg(d, hip, (cx - spread * u, base), body, 0.07 * u)
    seg(d, hip, neck, body, 0.11 * u)
    seg(d, hip, (cx + spread * u, base), body, 0.07 * u)
    disc(d, head, 0.11 * u, (240, 200, 170, 255))
    hand = pol(shoulder, hand_a, 0.26 * u)
    seg(d, shoulder, hand, body, 0.06 * u)
    blade = pol(hand, sword_a, 0.20 * u)
    seg(d, hand, blade, (190, 190, 200, 255), 0.035 * u)
    b0 = pol(blade, sword_a, 0.09 * u)               # a gap of ~9% of the height: wider than the merge dilation
    apex = pol(b0, sword_a, 0.08 * u)
    c1, c2 = pol(b0, sword_a + 90, 0.035 * u), pol(b0, sword_a - 90, 0.035 * u)
    poly(d, [apex, c1, c2], TIP)
    if anim == "cast":
        disc(d, (hand[0], hand[1] - 0.07 * u), 0.06 * u, (255, 230, 80, 255))
    rot = {0: 0, 1: 25, 2: 55, 3: 90}[k] if anim == "death" else 0
    return finish_tile(im, rot, (cx, base))


def wolf_tile(S, anim, k, fur=(120, 110, 100, 255)):
    """A four-legged beast drawn facing right, then mirrored (monsters face left)."""
    T = int(2.2 * S)
    u = S * SS
    im = Image.new("RGBA", (T * SS, T * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, base = T * SS / 2.0, T * SS - 0.06 * u
    sh = (0.02 * k * u) if anim == "attack" else (-0.05 * u if anim == "hit" else 0.0)
    step = 0.06 * math.sin(k * math.pi / 2) * u if anim == "walk" else 0.0
    by = base - 0.42 * u
    for lx, off in ((-0.3, step), (-0.18, -step), (0.18, step), (0.3, -step)):
        seg(d, (cx + lx * u, by), (cx + lx * u + off, base), fur, 0.07 * u)
    seg(d, (cx - 0.42 * u, by - 0.06 * u), (cx - 0.62 * u, by - 0.25 * u), fur, 0.05 * u)
    d.ellipse([cx - 0.45 * u, by - 0.19 * u, cx + 0.45 * u, by + 0.15 * u], fill=OUTLINE)
    d.ellipse([cx - 0.42 * u, by - 0.16 * u, cx + 0.42 * u, by + 0.12 * u], fill=fur)
    head = (cx + 0.47 * u + sh, by - 0.18 * u)
    poly(d, [(head[0] - 0.08 * u, head[1] - 0.1 * u), (head[0] - 0.02 * u, head[1] - 0.26 * u), (head[0] + 0.04 * u, head[1] - 0.08 * u)], fur)
    disc(d, head, 0.14 * u, fur)
    poly(d, [(head[0] + 0.1 * u, head[1] - 0.04 * u), (head[0] + 0.3 * u, head[1] + 0.02 * u), (head[0] + 0.1 * u, head[1] + 0.08 * u)], (200, 60, 50, 255))
    rot = {0: 0, 1: 20, 2: 45, 3: 80}[k] if anim == "death" else 0
    return finish_tile(im, rot, (cx, base), mirror=True)


def fx_tile(kind, k):
    T = 180
    u = SS
    im = Image.new("RGBA", (T * SS, T * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (T * SS / 2.0, T * SS / 2.0)
    if kind == "proj_arrow":
        seg(d, (c[0] - 45 * u, c[1]), (c[0] + 40 * u, c[1] + k * u), (150, 110, 60, 255), 4 * u)
        poly(d, [(c[0] + 58 * u, c[1] + k * u), (c[0] + 38 * u, c[1] - 9 * u), (c[0] + 38 * u, c[1] + 9 * u)], (200, 200, 210, 255))
        poly(d, [(c[0] - 60 * u, c[1] - 8 * u), (c[0] - 52 * u, c[1]), (c[0] - 60 * u, c[1] + 8 * u), (c[0] - 70 * u, c[1])], (230, 230, 240, 255))
    elif kind == "proj_bullet":
        disc(d, c, (12 + k) * u, (255, 220, 60, 255))
        for i, dist in enumerate((34, 50, 64)):
            disc(d, (c[0] - dist * u, c[1]), (5 - i) * u, (255, 200, 80, 255))
    elif kind == "proj_fire":
        r = (16 + 6 * k) * u
        glow = Image.new("L", im.size, 0)
        ImageDraw.Draw(glow).ellipse([c[0] - 1.6 * r, c[1] - 1.6 * r, c[0] + 1.6 * r, c[1] + 1.6 * r], fill=150)
        glow = glow.filter(ImageFilter.GaussianBlur(4 * u))
        im.paste((255, 150, 40, 255), (0, 0), glow)
        d = ImageDraw.Draw(im)
        disc(d, c, r, (255, 120, 30, 255))
    else:
        s = (22 + 5 * k) * u
        poly(d, [(c[0], c[1] - s), (c[0] + 0.7 * s, c[1]), (c[0], c[1] + s), (c[0] - 0.7 * s, c[1])], (150, 220, 255, 255))
    return finish_tile(im)


def icon_tile(i):
    T = 240
    u = SS
    im = Image.new("RGBA", (T * SS, T * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = T * SS / 2.0, T * SS / 2.0
    s = (60 + 6 * (i % 3)) * u
    if i == 0:      # three heads, apart from each other: must become one icon
        for dx in (-74, 0, 74):
            disc(d, (cx + dx * u, cy), 28 * u, (90, 140, 230, 255))
    elif i == 1:
        d.pieslice([cx - s, cy - s, cx + s, cy + s], 180, 360, fill=(200, 200, 220, 255), outline=OUTLINE, width=6 * u)
        poly(d, [(cx - s, cy), (cx + s, cy), (cx + s, cy + 0.4 * s), (cx - s, cy + 0.4 * s)], (160, 160, 190, 255))
    elif i == 2:
        d.rounded_rectangle([cx - s, cy - 0.8 * s, cx + s, cy + 0.9 * s], radius=20 * u, fill=(140, 90, 50, 255), outline=OUTLINE, width=6 * u)
    elif i == 3:    # anvil with a flame floating above it
        poly(d, [(cx - s, cy), (cx + s, cy), (cx + 0.5 * s, cy + 0.8 * s), (cx - 0.5 * s, cy + 0.8 * s)], (90, 90, 100, 255))
        poly(d, [(cx, cy - 1.1 * s), (cx + 0.3 * s, cy - 0.2 * s), (cx - 0.3 * s, cy - 0.2 * s)], (255, 140, 30, 255))
    elif i == 4:    # a ring: the hole must come out transparent
        d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=OUTLINE)
        d.ellipse([cx - s + 6 * u, cy - s + 6 * u, cx + s - 6 * u, cy + s - 6 * u], fill=(120, 120, 140, 255))
        d.ellipse([cx - 0.55 * s - 6 * u, cy - 0.55 * s - 6 * u, cx + 0.55 * s + 6 * u, cy + 0.55 * s + 6 * u], fill=OUTLINE)
        d.ellipse([cx - 0.55 * s, cy - 0.55 * s, cx + 0.55 * s, cy + 0.55 * s], fill=(0, 0, 0, 0))
    elif i == 5:
        poly(d, [(cx - s, cy - 0.7 * s), (cx + s, cy - 0.7 * s), (cx + s, cy + 0.7 * s), (cx - s, cy + 0.7 * s)], (215, 190, 140, 255))
    elif i == 6:
        pts = []
        for j in range(16):
            r = s if j % 2 == 0 else 0.75 * s
            pts.append(pol((cx, cy), j * 22.5, r))
        poly(d, pts, (150, 150, 160, 255))
    else:
        pts = [pol((cx, cy), 90 + j * 36, s if j % 2 == 0 else 0.45 * s) for j in range(10)]
        poly(d, pts, (255, 210, 60, 255))
    return finish_tile(im)


# ---------------------------------------------------------------------------
# Sheets
# ---------------------------------------------------------------------------
def layout(rows, make, jitter_size=0.05, jitter_base=8, spread=1.0):
    """Place tiles on a transparent sheet: rows of drawings with uneven size, spacing and baselines."""
    W, H = SHEET
    sheet = Image.new("RGBA", SHEET, (0, 0, 0, 0))
    R = len(rows)
    for ri, (anim, n) in enumerate(rows):
        base = int((ri + 0.82) * H / R)
        for k in range(n):
            tile = make(anim, k, 1.0 + rng.uniform(-jitter_size, jitter_size))
            cx = (k + 0.5) * W / n + rng.uniform(-14, 14) * spread
            by = base + int(rng.integers(-jitter_base, jitter_base + 1))
            sheet.alpha_composite(tile, (int(cx - tile.width / 2), int(by - tile.height)))
    return sheet


def add_specks(sheet, n=4):
    d = ImageDraw.Draw(sheet)
    W, H = sheet.size
    for i in range(n):
        x, y = int(rng.integers(20, W - 20)), int(rng.integers(4, 14))     # along the top margin
        s = 1 + i % 3
        d.rectangle([x, y, x + s, y + s], fill=(30, 30, 30, 255))
    return sheet


def on_magenta(sheet):
    bg = Image.new("RGBA", sheet.size, MAGENTA + (255,))
    bg.alpha_composite(sheet)
    return bg.convert("RGB")


def with_matte(sheet):
    """A transparent PNG whose cut-out is a pixel too loose: a rim of the magenta it was cut from."""
    arr = np.asarray(sheet).astype(np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3] * a + np.array(MAGENTA, np.float32) * (1 - a)
    grown = np.asarray(Image.fromarray(arr[..., 3].astype(np.uint8)).filter(ImageFilter.MaxFilter(3)))
    return Image.fromarray(np.dstack([rgb, grown]).astype(np.uint8), "RGBA")


def on_busy(sheet):
    """No usable background: random colour blotches right up to the border."""
    small = rng.integers(0, 256, (SHEET[1] // 32, SHEET[0] // 32, 3)).astype(np.uint8)
    bg = Image.fromarray(small, "RGB").resize(SHEET, Image.Resampling.NEAREST).convert("RGBA")
    bg.alpha_composite(sheet)
    return bg.convert("RGB")


def on_noisy(sheet, path, colour=OFFWHITE):
    W, H = sheet.size
    yy, xx = np.mgrid[0:H, 0:W]
    base = np.array(colour, np.float32)[None, None, :] + (xx / W - 0.5)[..., None] * 6 + (yy / H - 0.5)[..., None] * 4
    base += rng.normal(0, 2.5, base.shape)
    bg = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    bg.alpha_composite(sheet)
    jpg = path + ".jpg"
    bg.convert("RGB").save(jpg, quality=82)       # real JPEG artefacts ...
    Image.open(jpg).convert("RGB").save(path)    # ... handed over as a PNG
    os.remove(jpg)


def build_art(src):
    os.makedirs(src, exist_ok=True)
    S = 150
    warrior = (60, 110, 220, 255)
    A = [("idle", 4), ("walk", 6)]
    B = [("attack", 4), ("cast", 4), ("hit", 2), ("death", 4)]
    add_specks(layout(A, lambda a, k, j: hero_tile(S * j, a, k, warrior))).save(os.path.join(src, "hero_warrior_alliance_m_A.png"))
    on_magenta(add_specks(layout(B, lambda a, k, j: hero_tile(S * j * 0.98, a, k, warrior)))).save(
        os.path.join(src, "hero_warrior_alliance_m_B.png"))
    on_noisy(layout(A, lambda a, k, j: hero_tile(S * 1.1 * j, a, k, (220, 170, 50, 255))), os.path.join(src, "hero_paladin_alliance_m_A.png"))
    mob_rows = [("idle", 4), ("walk", 3), ("attack", 4), ("hit", 2), ("death", 4)]       # one walk frame missing
    on_magenta(layout(mob_rows, lambda a, k, j: wolf_tile(120 * j, a, k), jitter_base=5)).save(os.path.join(src, "mob_wolf.png"))
    bear_rows = [("idle", 4), ("walk", 4), ("attack", 4), ("death", 4)]                   # the 'hit' row is missing
    with_matte(layout(bear_rows, lambda a, k, j: wolf_tile(140 * j, a, k, (90, 60, 40, 255)), jitter_base=6)).save(
        os.path.join(src, "mob_bear.png"))
    on_busy(layout([("idle", 4), ("walk", 4)], lambda a, k, j: wolf_tile(100 * j, a, k))).save(os.path.join(src, "pet_cat.png"))
    fx_rows = [("proj_arrow", 4), ("proj_bullet", 5), ("proj_fire", 4), ("proj_frost", 4)]  # one bullet frame too many
    layout(fx_rows, lambda a, k, j: fx_tile(a, k), jitter_size=0, jitter_base=10).save(os.path.join(src, "fx_projectiles_1.png"))

    # background pair
    W, H = SHEET
    yy, xx = np.mgrid[0:H, 0:W]
    t = (yy / H)[..., None]
    sky = np.array([90, 150, 225])[None, None, :] * (1 - t) + np.array([210, 225, 240])[None, None, :] * t
    far = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(far)
    for amp, y0, col in ((60, 520, (110, 150, 120)), (40, 640, (70, 120, 80)), (30, 760, (50, 95, 60))):
        pts = [(x, y0 + amp * math.sin(x / 140.0 + amp)) for x in range(0, W + 8, 8)]
        d.polygon(pts + [(W, H), (0, H)], fill=col)
    d.ellipse([1100, 160, 1220, 280], fill=(255, 240, 180))
    far.save(os.path.join(src, "bg_forest_far.png"))
    near = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(near)
    pts = [(x, 2 * (720 + 25 * math.sin(x / 180.0))) for x in range(0, 2 * W + 8, 8)]
    d.polygon(pts + [(2 * W, 2 * H), (0, 2 * H)], fill=(120, 85, 50, 255))
    for i in range(30):
        x = int(rng.integers(0, 2 * W))
        y = 2 * (720 + 25 * math.sin(x / 180.0))
        d.polygon([(x - 12, y + 4), (x, y - 40), (x + 12, y + 4)], fill=(70, 140, 60, 255))
    for i in range(12):
        x, y = int(rng.integers(0, 2 * W)), int(rng.integers(2 * 800, 2 * 980))
        d.ellipse([x - 30, y - 18, x + 30, y + 18], fill=(130, 130, 135, 255))
    near.resize(SHEET, Image.Resampling.LANCZOS).save(os.path.join(src, "bg_forest_near.png"))

    # interface frame on magenta
    ui = Image.new("RGBA", (1024 * SS // 2, 1024 * SS // 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(ui)
    k = SS // 2
    d.rounded_rectangle([120 * k, 120 * k, 904 * k, 904 * k], radius=40 * k, fill=(205, 165, 70, 255), outline=OUTLINE, width=6 * k)
    d.rounded_rectangle([170 * k, 170 * k, 854 * k, 854 * k], radius=20 * k, fill=(25, 35, 70, 255), outline=OUTLINE, width=4 * k)
    for gx, gy in ((140, 140), (884, 140), (140, 884), (884, 884)):
        d.ellipse([(gx - 26) * k, (gy - 26) * k, (gx + 26) * k, (gy + 26) * k], fill=(200, 30, 40, 255), outline=OUTLINE, width=4 * k)
    on_magenta(ui.resize((1024, 1024), Image.Resampling.LANCZOS)).save(os.path.join(src, "ui_window.png"))

    # icons on noisy off-white
    icons = Image.new("RGBA", SHEET, (0, 0, 0, 0))
    for i in range(8):
        tile = icon_tile(i)
        cx = (i % 4 + 0.5) * W / 4 + rng.uniform(-20, 20)
        cy = (i // 4 + 0.5) * H / 2 + rng.uniform(-25, 25)
        icons.alpha_composite(tile, (int(cx - tile.width / 2), int(cy - tile.height / 2)))
    on_noisy(add_specks(icons), os.path.join(src, "icons_menu.png"))

    # files the --check listing must call unexpected
    shutil.copy(os.path.join(src, "mob_wolf.png"), os.path.join(src, "hero_warior_alliance_m_A.png"))
    with open(os.path.join(src, "notes.txt"), "w") as f:
        f.write("not art\n")


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
class Checks:
    def __init__(self):
        self.passed = 0
        self.failed = []

    def __call__(self, cond, what):
        if cond:
            self.passed += 1
        else:
            self.failed.append(what)
            print("FAIL: " + what)
        return cond


def run(*args):
    p = subprocess.run([sys.executable, TOOL] + list(args), capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def load_lua(path):
    import lupa.lua51 as lua51
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    loader = lua.eval("function(src) local f, err = loadstring(src, '=Art.lua') if not f then return nil, err end "
                      "local ns = {} f('BigIdleWoWHeroes', ns) return ns.ART end")
    with open(path, encoding="utf-8") as f:
        res = loader(f.read())
    art, err = res if isinstance(res, tuple) else (res, None)

    def py(v):
        if lua51.lua_type(v) == "table":
            d = {k: py(x) for k, x in v.items()}
            if d and all(isinstance(k, int) for k in d) and sorted(d) == list(range(1, len(d) + 1)):
                return [d[i] for i in range(1, len(d) + 1)]
            return d
        return v
    return (py(art) if art is not None else None), err


def read_tga(path):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGBA"))


def is_pot(n):
    return n > 0 and n & (n - 1) == 0


def digest(folder):
    out = {}
    for root, _, files in os.walk(folder):
        for fn in files:
            p = os.path.join(root, fn)
            with open(p, "rb") as f:
                out[os.path.relpath(p, folder)] = hashlib.sha1(f.read()).hexdigest()
    return out


def cells(tex, e, n):
    for k in range(n):
        c, r = k % e["cols"], k // e["cols"]
        yield k, tex[r * e["ch"]:(r + 1) * e["ch"], c * e["cw"]:(c + 1) * e["cw"]]


def main():
    t0 = time.time()
    ok = Checks()
    tmp = tempfile.mkdtemp(prefix="import_art_test_")
    try:
        src = os.path.join(tmp, "art_src")
        out = os.path.join(tmp, "addon")
        media = os.path.join(out, "Media", "Art")
        man_path = os.path.join(out, "Data", "Art.lua")
        build_art(src)
        os.makedirs(media)
        os.makedirs(os.path.dirname(man_path))
        shutil.copy(REAL_MANIFEST, man_path)
        with open(os.path.join(media, "old_unused.tga"), "wb") as f:
            f.write(b"stale")
        shutil.rmtree(PREVIEW, ignore_errors=True)

        # --check: lists, writes nothing
        before = digest(out)
        rc, text = run("--check", "--src", src, "--out", out)
        ok(rc == 0, "--check exits 0")
        ok(digest(out) == before, "--check writes nothing")
        ok("ok       hero_warrior_alliance_m" in text, "--check: hero_warrior complete")
        ok("partial  hero_paladin_alliance_m" in text, "--check: hero_paladin partial")
        ok("missing  hero_mage_horde_f" in text, "--check: missing assets listed")
        ok("hero_warior_alliance_m_A.png   (did you mean hero_warrior_alliance_m_A.png?)" in text, "--check: unexpected typo file with hint")
        ok("notes.txt" not in text and "1 unexpected file" in text, "--check: only image files can be unexpected (notes are ignored)")

        # full import
        rc, text = run("--src", src, "--out", out, "--preview", PREVIEW)
        print(text)
        ok(rc == 0, "import exits 0")
        warns = [ln for ln in text.splitlines() if ln.startswith("  ! ")]
        ok(any("mob_wolf.png: row 'walk': found 3 frames, expected 4" in w for w in warns), "warning: missing monster frame")
        ok(any("fx_projectiles_1.png: row 'proj_bullet': found 5 frames, expected 4" in w for w in warns), "warning: extra effect frame")
        ok(any("mob_bear.png: missing row 'hit' (found 4 of 5 rows)" in w for w in warns), "warning: missing row")
        ok(any("pet_cat: pet_cat.png: background not detected" in w and "not imported" in w for w in warns), "warning: background not detected")
        ok(len(warns) == 4, "no other warnings (got %d: %s)" % (len(warns), warns))
        ok("not supplied, so attack, cast, hit, death are not imported yet" in text, "note: paladin sheet B not supplied")
        ok("removed stale texture old_unused.tga" in text and not os.path.exists(os.path.join(media, "old_unused.tga")), "stale TGA removed")

        art, err = load_lua(man_path)
        ok(art is not None, "manifest loads in Lua 5.1 (%s)" % err)
        if art is None:
            raise SystemExit(1)
        sp = art.get("sprites", {})

        # sprite entries
        w = sp.get("hero_warrior_alliance_m", {})
        ok(w.get("anims") == {"idle": [0, 4], "walk": [4, 6], "attack": [10, 4], "cast": [14, 4], "hit": [18, 2], "death": [20, 4]},
           "warrior anims %s" % w.get("anims"))
        ok((w.get("file"), w.get("w"), w.get("h"), w.get("cw"), w.get("ch"), w.get("cols"), w.get("facing")) ==
           ("hero_warrior_alliance_m", 1024, 1024, 256, 170, 4, "right"), "warrior geometry (wide cells, 4 per row)")
        ok(w.get("game") == {"class": "WARRIOR", "faction": "ALLIANCE", "sex": "M", "race": "DWARF"}, "warrior game hints %s" % w.get("game"))
        p = sp.get("hero_paladin_alliance_m", {})
        ok(p.get("anims") == {"idle": [0, 4], "walk": [4, 6]} and (p.get("w"), p.get("h")) == (1024, 512), "paladin A-only: anims and 1024x512")
        m = sp.get("mob_wolf", {})
        ok(m.get("anims") == {"idle": [0, 4], "walk": [4, 3], "attack": [7, 4], "hit": [11, 2], "death": [13, 4]}, "wolf anims %s" % m.get("anims"))
        ok(m.get("facing") == "left" and m.get("cols") == 4 and (m.get("w"), m.get("h")) == (1024, 1024), "wolf geometry")
        ok("wolf" in (m.get("game") or {}).get("monsters", []), "wolf game.monsters list")
        ok((sp.get("mob_bear") or {}).get("anims") == {"idle": [0, 4], "walk": [4, 4], "attack": [8, 4], "death": [12, 4]},
           "bear without its hit row: anims %s" % (sp.get("mob_bear") or {}).get("anims"))
        ok(set(sp) == {"hero_warrior_alliance_m", "hero_paladin_alliance_m", "mob_wolf", "mob_bear"}, "sprite ids %s" % sorted(sp))

        for sid, e in sp.items():
            n = sum(c for _, c in e["anims"].values())
            for a0, c in e["anims"].values():
                ok(0 <= a0 and a0 + c <= n, "%s anim range" % sid)
            ok(is_pot(e["w"]) and is_pot(e["h"]) and e["w"] <= 2048 and e["h"] <= 2048, "%s power-of-two size" % sid)
            tex = read_tga(os.path.join(media, e["file"] + ".tga"))
            ok(tex.shape == (e["h"], e["w"], 4), "%s TGA size" % sid)
            foot_row = e["ch"] - int(round(e["foot"] * e["ch"])) - 1
            bottoms, centres, heights = [], [], {}
            for k, cell in cells(tex, e, n):
                al = cell[..., 3] >= 128
                ys, xs = np.nonzero(al)
                if not ok(len(ys) > 50, "%s frame %d has content" % (sid, k)):
                    continue
                bottoms.append(int(ys.max()))
                h = int(ys.max() - ys.min() + 1)
                sel = ys >= ys.max() - (h - 1) * 0.25
                centres.append(float(xs[sel].mean()) + 0.5)
                heights[k] = h
                ok(not cell[0].any() or cell[0, :, 3].max() < 26, "%s frame %d not touching the cell top" % (sid, k))
            ok(max(abs(b - foot_row) for b in bottoms) <= 1, "%s feet on the baseline (rows %s, want %d)" % (sid, sorted(set(bottoms)), foot_row))
            ok(max(abs(c - e["cw"] / 2.0) for c in centres) <= 2.0, "%s feet centred (max off %.1f)" % (sid, max(abs(c - e["cw"] / 2.0) for c in centres)))
            idle, walk = e["anims"]["idle"], e["anims"]["walk"]
            normal = [heights[k] for k in list(range(idle[0], idle[0] + idle[1])) + list(range(walk[0], walk[0] + walk[1])) if k in heights]
            if sid.startswith("hero"):
                # 86% unless another frame (here the half-fallen death pose) needs the character smaller
                ok(0.75 * e["ch"] <= max(normal) <= 0.86 * e["ch"] + 2, "%s tallest idle/walk frame fills ~86%% (%d of %d)" % (sid, max(normal), e["ch"]))
            else:   # a beast wider than tall is sized by how far its idle/walk frames reach from the feet
                reach = max(float(np.abs(np.nonzero(c[..., 3] > 5)[1] + 0.5 - e["cw"] / 2.0).max())
                            for k, c in cells(tex, e, idle[1] + walk[1]))
                ok(0.88 * e["cw"] / 2.0 <= reach <= e["cw"] / 2.0, "%s widest idle/walk frame reaches the cell side (%.1f of %d)" % (sid, reach, e["cw"] // 2))
            if sid.startswith("hero"):
                tips = [int(((cell[..., 3] > 128) & (cell[..., 0] < 100) & (cell[..., 1] > 150) & (cell[..., 2] > 180)).sum())
                        for _, cell in cells(tex, e, n)]
                ok(min(tips) >= 6, "%s detached sword tip kept in every frame (min %d px)" % (sid, min(tips)))
            opaque = tex[..., 3] > 25
            mag = opaque & (np.minimum(tex[..., 0].astype(int), tex[..., 2]) - tex[..., 1] > 70) & (tex[..., 0] > 110) & (tex[..., 2] > 110)
            ok(mag.sum() <= 0.002 * opaque.sum(), "%s no magenta fringe (%d px)" % (sid, mag.sum()))
        w_tex = read_tga(os.path.join(media, "hero_warrior_alliance_m.tga"))
        hit_h = [int(np.ptp(np.nonzero(c[..., 3] >= 128)[0])) for k, c in cells(w_tex, w, 24) if 18 <= k < 20]
        idle_h = [int(np.ptp(np.nonzero(c[..., 3] >= 128)[0])) for k, c in cells(w_tex, w, 24) if k < 4]
        ok(0.8 <= np.median(hit_h) / np.median(idle_h) <= 1.15, "sheets A and B keep one character size")
        p_tex = read_tga(os.path.join(media, "hero_paladin_alliance_m.tga"))
        op = p_tex[..., 3] >= 128
        bgish = op & (np.abs(p_tex[..., :3].astype(int) - np.array(OFFWHITE)).max(axis=2) < 20)
        ok(bgish.sum() <= 0.01 * op.sum(), "off-white background gone (%d px left)" % bgish.sum())
        ok(p_tex.shape[0] == 512 and not p_tex[510:, :, 3].any() and p_tex[340:510, :512, 3].any(),
           "paladin: 10 frames fill three rows of four (TGA orientation)")

        # raw TGA layout: type 2, 32 bpp, descriptor 8 (8 alpha bits, bottom-left origin)
        with open(os.path.join(media, "hero_paladin_alliance_m.tga"), "rb") as f:
            raw = f.read()
        ok(raw[2] == 2 and raw[16] == 32 and raw[17] == 8 and raw[0] == 0, "TGA header: uncompressed, 32 bpp, bottom-left origin")
        rawpx = np.frombuffer(raw[18:], np.uint8).reshape(512, 1024, 4)
        ok(np.array_equal(rawpx[::-1, :, 3], p_tex[..., 3]) and not rawpx[:2, :, 3].any(), "TGA stores the bottom row first")

        # effects
        fx = art.get("fx", {})
        ok(set(fx) == {"proj_arrow", "proj_bullet", "proj_fire", "proj_frost"}, "fx ids %s" % sorted(fx))
        ok({k: v.get("n") for k, v in fx.items()} == {"proj_arrow": 4, "proj_bullet": 5, "proj_fire": 4, "proj_frost": 4}, "fx frame counts")
        for k, e in fx.items():
            tex = read_tga(os.path.join(media, e["file"] + ".tga"))
            ok(is_pot(e["w"]) and is_pot(e["h"]) and tex.shape == (e["h"], e["w"], 4) and e["cw"] == e["ch"] == 128, "%s texture" % k)
            ok(e["cols"] * e["cw"] <= e["w"] and math.ceil(e["n"] / e["cols"]) * e["ch"] <= e["h"], "%s grid fits" % k)
            for j, cell in cells(tex, e, e["n"]):
                ys, xs = np.nonzero(cell[..., 3] > 128)
                ok(len(ys) > 20 and abs((xs.min() + xs.max() + 1) / 2.0 - 64) <= 2 and abs((ys.min() + ys.max() + 1) / 2.0 - 64) <= 3,
                   "%s frame %d centred" % (k, j))
        arrow = read_tga(os.path.join(media, "proj_arrow.tga"))
        ok(all(int((c[..., 3] > 128)[:, :40].sum()) > 20 for _, c in cells(arrow, fx["proj_arrow"], 4)), "arrow keeps its detached feathers")

        # background
        bg = art.get("bg", {}).get("forest", {})
        ok(bg.get("far") == {"file": "bg_forest_far", "w": 1024, "h": 256} and bg.get("near") == {"file": "bg_forest_near", "w": 1024, "h": 256},
           "bg forest entries %s" % bg)
        far = read_tga(os.path.join(media, "bg_forest_far.tga")).astype(int)
        near = read_tga(os.path.join(media, "bg_forest_near.tga")).astype(int)
        ok(far.shape == (256, 1024, 4) and (far[..., 3] == 255).all(), "far layer opaque 1024x256")
        seam = np.abs(far[:, 0, :3] - far[:, -1, :3]).mean()
        inner = np.abs(far[:, 1:, :3] - far[:, :-1, :3]).mean()
        ok(seam <= 3 * inner + 2, "far layer wraps seamlessly (seam %.1f vs %.1f)" % (seam, inner))
        ok(near.shape == (256, 1024, 4) and (near[-1, :, 3] == 255).all() and (near[0, :, 3] == 0).mean() > 0.9, "near layer: ground at the bottom, clear above")
        nseam = np.abs(near[:, 0] - near[:, -1]).mean()
        ok(nseam <= 3 * np.abs(near[:, 1:] - near[:, :-1]).mean() + 2, "near layer wraps seamlessly")

        # interface + icons
        ui = art.get("ui", {}).get("ui_window", {})
        ok(ui == {"file": "ui_window", "w": 512, "h": 512, "slice": 96}, "ui_window entry %s" % ui)
        uit = read_tga(os.path.join(media, "ui_window.tga"))
        ok(uit.shape == (512, 512, 4) and uit[256, 256, 3] == 255 and uit[256, 256, 2] > uit[256, 256, 0], "ui_window fills 512x512, navy centre")
        top_edge = int(np.argmax(uit[:, 256, 3] > 200))
        left_edge = int(np.argmax(uit[256, :, 3] > 200))
        ok(top_edge <= 8 and left_edge <= 8, "ui_window trimmed to its frame (edges at %d, %d; the corner gems stick out)" % (top_edge, left_edge))
        ic = art.get("icons", {})
        want = SPEC_ICONS
        ok(set(ic) == set(want), "icon ids %s" % sorted(ic))
        for iid in want:
            e = ic.get(iid, {})
            ok(e == {"file": iid, "w": 128, "h": 128}, "%s entry" % iid)
        ring = read_tga(os.path.join(media, want[4] + ".tga"))
        ok(ring[64, 64, 3] == 0 and ring[64, 10:30, 3].max() == 255, "ring icon hole is transparent")
        party = read_tga(os.path.join(media, want[0] + ".tga"))
        ys, xs = np.nonzero(party[..., 3] > 128)
        ok(xs.max() - xs.min() > 100, "three separate heads became one icon")
        ok(all(os.path.isfile(os.path.join(PREVIEW, a + ".png")) for a in
               ("hero_warrior_alliance_m", "hero_paladin_alliance_m", "mob_wolf", "fx_projectiles_1", "bg_forest", "ui_window", "icons_menu")),
           "contact sheets written")
        expected_files = {"hero_warrior_alliance_m", "hero_paladin_alliance_m", "mob_wolf", "mob_bear", "bg_forest_far", "bg_forest_near",
                          "ui_window", "proj_arrow", "proj_bullet", "proj_fire", "proj_frost"} | set(want)
        ok({f[:-4] for f in os.listdir(media)} == expected_files, "exactly the expected textures")

        # --only keeps everything else and is deterministic
        first = digest(out)
        with open(man_path, encoding="utf-8") as f:
            text1 = f.read()
        rc, text = run("--only", "mob_wolf", "--src", src, "--out", out, "--no-preview")
        ok(rc == 0 and "1 asset imported" in text, "--only run")
        ok(digest(out) == first, "--only keeps other entries and textures; output is byte-identical")
        rc, text = run("--only", "mob_wolf_x", "--src", src, "--out", out, "--no-preview")
        ok(rc != 0 and "did you mean mob_wolf" in text, "--only with an unknown id fails with a hint")

        # a removed source image drops its texture and entry on the next full import
        os.remove(os.path.join(src, "bg_forest_near.png"))
        rc, text = run("--src", src, "--out", out, "--no-preview")
        art2, _ = load_lua(man_path)
        ok(rc == 0 and art2["bg"]["forest"] == {"far": {"file": "bg_forest_far", "w": 1024, "h": 256}}, "bg without near layer")
        ok(not os.path.exists(os.path.join(media, "bg_forest_near.tga")), "texture of the removed image deleted")
        with open(man_path, encoding="utf-8") as f:
            text2 = f.read()
        ok(text2.split("ns.ART")[0] == text1.split("ns.ART")[0], "manifest header kept")

        # nothing to import: the manifest is the empty one shipped with the add-on
        empty_src = os.path.join(tmp, "empty")
        empty_out = os.path.join(tmp, "empty_out")
        os.makedirs(empty_src)
        os.makedirs(os.path.join(empty_out, "Data"))
        shutil.copy(REAL_MANIFEST, os.path.join(empty_out, "Data", "Art.lua"))
        rc, _ = run("--src", empty_src, "--out", empty_out, "--no-preview")
        art3, _ = load_lua(os.path.join(empty_out, "Data", "Art.lua"))
        ok(rc == 0 and art3 == {"sprites": {}, "fx": {}, "bg": {}, "ui": {}, "icons": {}}, "empty import gives empty tables")
        with open(REAL_MANIFEST, encoding="utf-8") as f:
            real = f.read()
        with open(os.path.join(empty_out, "Data", "Art.lua"), encoding="utf-8") as f:
            mine = f.read()
        real_art, _ = load_lua(REAL_MANIFEST)
        if real_art == art3:
            ok(mine == real, "empty import reproduces the shipped Data/Art.lua byte for byte")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("test_import_art: %d checks passed, %d failed  (%.1fs; contact sheets in %s)"
          % (ok.passed, len(ok.failed), time.time() - t0, os.path.relpath(PREVIEW, ROOT)))
    return 1 if ok.failed else 0


sys.path.insert(0, os.path.join(ROOT, "tools"))
import asset_spec  # noqa: E402

SPEC_ICONS = next(a for a in asset_spec.ASSETS if a["id"] == "icons_menu")["icons"]

if __name__ == "__main__":
    sys.exit(main())
