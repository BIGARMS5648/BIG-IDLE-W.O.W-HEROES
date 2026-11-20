#!/usr/bin/env python3
"""Draw the addon's UI without the game.

The mocked WoW API records where every frame, texture and text is anchored.
This script arranges a few scenes, exports them, and writes tests/out/preview.html,
a page that resolves the anchors and paints each scene as a wireframe: boxes in
their real colors, icon placeholders with the icon's name, and the actual text.
It is a layout check (overlaps, overflow, missing labels), not a pixel-accurate
rendering of the game.

    python3 tests/preview.py            # Korean
    python3 tests/preview.py enUS       # English
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run  # noqa: E402

SCENES = [
    "bar", "party", "hero", "hero_tooltip", "bag", "bag_tooltip",
    "forge_fuse", "forge_craft", "forge_gem", "forge_remove", "forge_seal",
    "runes", "map", "options",
]

PAGE = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>Layout preview</title>
<style>
  body { background:#20232a; color:#ddd; font:13px sans-serif; margin:16px; }
  h2 { font-size:14px; margin:18px 0 6px; }
  canvas { background:#2c3a2f; display:block; }
</style></head><body>
<h1 style="font-size:16px">Big Idle W.O.W Heroes - layout preview (__LOCALE__)</h1>
<div id="root"></div>
<script>
const SCENES = __DATA__;
const FONT = '"WenQuanYi Zen Hei","Noto Sans CJK KR","Malgun Gothic",sans-serif';
const LAYER = { BACKGROUND:0, BORDER:1, ARTWORK:2, OVERLAY:3, HIGHLIGHT:4 };
const STRATA = { BACKGROUND:0, LOW:1, MEDIUM:2, HIGH:3, DIALOG:4, FULLSCREEN:5, FULLSCREEN_DIALOG:6, TOOLTIP:7 };
const W = 1920, H = 1080;
const mctx = document.createElement('canvas').getContext('2d');

function segments(text) {
  // "|cffRRGGBBtext|r" -> [{color, text}]
  const out = []; let color = null; let i = 0;
  const re = /\|c[0-9a-fA-F]{8}|\|r/g; let m;
  while ((m = re.exec(text))) {
    if (m.index > i) out.push({ color, text: text.slice(i, m.index) });
    color = m[0] === '|r' ? null : '#' + m[0].slice(4);
    i = re.lastIndex;
  }
  if (i < text.length) out.push({ color, text: text.slice(i) });
  return out;
}
function plain(text) { return text.replace(/\|c[0-9a-fA-F]{8}|\|r/g, ''); }

function layoutText(e) {
  mctx.font = e.size + 'px ' + FONT;
  const lines = [];
  for (const raw of e.text.split('\n')) {
    const segs = segments(raw);
    if (!(e.w > 0) || e.nowrap) { lines.push(segs); continue; }
    // greedy wrap; break at spaces, or anywhere inside CJK runs
    let cur = [], width = 0;
    for (const s of segs) {
      const parts = s.text.match(/[　-鿿가-힯]|[^\s　-鿿가-힯]+|\s+/g) || [];
      for (const p of parts) {
        const pw = mctx.measureText(p).width;
        if (width + pw > e.w && width > 0 && p.trim() !== '') { lines.push(cur); cur = []; width = 0; }
        if (cur.length === 0 && p.trim() === '') continue;
        cur.push({ color: s.color, text: p }); width += pw;
      }
    }
    lines.push(cur);
  }
  let maxw = 0;
  for (const l of lines) {
    let w = 0; for (const s of l) w += mctx.measureText(s.text).width;
    l.width = w; if (w > maxw) maxw = w;
  }
  return { lines, width: maxw, height: lines.length * e.size * 1.22 };
}

function draw(scene, title) {
  const byId = {}; for (const e of scene.items) byId[e.id] = e;
  const root = scene.root;
  function point(r, p) {
    const x = p.includes('LEFT') ? r.l : p.includes('RIGHT') ? r.r : (r.l + r.r) / 2;
    const y = p.includes('TOP') ? r.t : p.includes('BOTTOM') ? r.b : (r.b + r.t) / 2;
    return [x, y];
  }
  function rect(e) {
    if (e._r) return e._r;
    if (e.id === root) return (e._r = { l:0, b:0, r:W, t:H });
    e._r = { l:0, b:0, r:0, t:0 }; // guard against cycles
    let w = e.w, h = e.h;
    if (e.kind === 'text') {
      e._t = layoutText(e);
      if (!(w > 0)) w = e._t.width;
      if (!(h > 0)) h = e._t.height;
    }
    let L, R, T, B, CX, CY;
    for (const a of e.anchors) {
      const rel = byId[a[1]]; if (!rel) continue;
      const rr = rect(rel);
      if (a[0] === 'ALL') return (e._r = { l:rr.l, b:rr.b, r:rr.r, t:rr.t });
      const [ax, ay] = point(rr, a[2]); const x = ax + a[3], y = ay + a[4]; const P = a[0];
      if (P.includes('LEFT')) L = x; else if (P.includes('RIGHT')) R = x; else CX = x;
      if (P.includes('TOP')) T = y; else if (P.includes('BOTTOM')) B = y; else CY = y;
    }
    if (L != null && R != null) w = R - L; else if (L != null) R = L + w; else if (R != null) L = R - w;
    else if (CX != null) { L = CX - w / 2; R = CX + w / 2; } else { L = 0; R = w; e._unanchored = true; }
    if (T != null && B != null) h = T - B; else if (T != null) B = T - h; else if (B != null) T = B + h;
    else if (CY != null) { B = CY - h / 2; T = CY + h / 2; } else { B = 0; T = h; e._unanchored = true; }
    return (e._r = { l:L, b:B, r:R, t:T });
  }
  // paint order: strata of the top-level frame, then creation order; inside a
  // frame its own regions by layer, then child frames
  const children = {}; for (const e of scene.items) (children[e.parent] = children[e.parent] || []).push(e);
  const order = [];
  function walk(f) {
    order.push(f);
    const kids = children[f.id] || [];
    kids.filter(k => k.kind !== 'frame').sort((a, b) => (LAYER[a.layer] - LAYER[b.layer]) || (a.order - b.order)).forEach(k => order.push(k));
    kids.filter(k => k.kind === 'frame').sort((a, b) => ((a.level || 0) - (b.level || 0)) || (a.order - b.order)).forEach(walk);
  }
  const tops = scene.items.filter(e => e.kind === 'frame' && (e.parent === root)).sort((a, b) => (STRATA[a.strata || 'MEDIUM'] - STRATA[b.strata || 'MEDIUM']) || (a.order - b.order));
  tops.forEach(walk);

  // bounding box of what is shown
  let bx0 = W, by0 = H, bx1 = 0, by1 = 0;
  for (const e of order) {
    const r = rect(e); if (e._unanchored || r.r - r.l <= 0) continue;
    bx0 = Math.min(bx0, r.l); bx1 = Math.max(bx1, r.r); by0 = Math.min(by0, r.b); by1 = Math.max(by1, r.t);
  }
  const pad = 12; bx0 = Math.max(0, bx0 - pad); by0 = Math.max(0, by0 - pad); bx1 = Math.min(W, bx1 + pad); by1 = Math.min(H, by1 + pad);
  const cw = Math.max(50, bx1 - bx0), ch = Math.max(30, by1 - by0);

  const h2 = document.createElement('h2'); h2.textContent = title; document.getElementById('root').appendChild(h2);
  const c = document.createElement('canvas'); c.id = 'scene-' + title; c.width = cw * 2; c.height = ch * 2; c.style.width = cw + 'px'; c.style.height = ch + 'px';
  document.getElementById('root').appendChild(c);
  const g = c.getContext('2d'); g.scale(2, 2); g.translate(-bx0, 0);
  const Y = y => (by1 - y);

  function alphaOf(e) { let a = 1; for (let x = e; x; x = byId[x.parent]) a *= (x.alpha == null ? 1 : x.alpha); return a; }
  for (const e of order) {
    const r = rect(e); const a = alphaOf(e); if (a <= 0.01) continue;
    g.globalAlpha = a;
    if (e.kind === 'texture') {
      const x = r.l, y = Y(r.t), w = r.r - r.l, h = r.t - r.b; if (w <= 0 || h <= 0) continue;
      if (e.color) {
        g.fillStyle = `rgba(${Math.round(e.color[0]*255)},${Math.round(e.color[1]*255)},${Math.round(e.color[2]*255)},${e.color[3]})`;
        g.fillRect(x, y, w, h);
      } else if (e.tex) {
        const name = String(e.tex).split('\\').pop();
        let hash = 0; for (const ch2 of name) hash = (hash * 31 + ch2.charCodeAt(0)) >>> 0;
        g.fillStyle = `hsl(${hash % 360},35%,32%)`; g.fillRect(x, y, w, h);
        g.fillStyle = 'rgba(255,255,255,0.85)'; g.font = '7px ' + FONT; g.textBaseline = 'top';
        const label = name.replace(/^(INV|Spell|Ability)_/, '').replace(/^Misc_/, '');
        for (let i = 0, yy = y + 1; i < label.length && yy < y + h - 6; i += Math.max(4, Math.floor(w / 4.2)), yy += 7)
          g.fillText(label.slice(i, i + Math.max(4, Math.floor(w / 4.2))), x + 1, yy);
      }
    } else if (e.kind === 'text') {
      if (!e._t) e._t = layoutText(e);
      const t = e._t; g.font = e.size + 'px ' + FONT; g.textBaseline = 'top';
      const base = e.color ? `rgb(${Math.round(e.color[0]*255)},${Math.round(e.color[1]*255)},${Math.round(e.color[2]*255)})` : '#fff';
      const boxW = r.r - r.l, boxH = r.t - r.b;
      let y = Y(r.t); if (e.jv === 'MIDDLE') y += (boxH - t.height) / 2; else if (e.jv === 'BOTTOM') y += boxH - t.height;
      for (const line of t.lines) {
        let x = r.l; if (e.jh === 'CENTER') x += (boxW - line.width) / 2; else if (e.jh === 'RIGHT') x += boxW - line.width;
        for (const s of line) {
          g.fillStyle = '#000'; g.fillText(s.text, x + 1, y + 1);
          g.fillStyle = s.color || base; g.fillText(s.text, x, y);
          x += g.measureText(s.text).width;
        }
        y += e.size * 1.22;
      }
    }
  }
  g.globalAlpha = 1;
}
for (const [title, scene] of SCENES) draw(scene, title);
document.title = 'ready';
</script></body></html>
"""


def main(argv):
    locale = argv[1] if len(argv) > 1 else "koKR"
    lua = run.new_runtime(locale)
    scene = run.run_script(lua, "preview_scene.lua")
    mock = lua.globals().WoWMock
    data = []
    for name in SCENES:
        scene(name)
        data.append([name, json.loads(mock.ExportJSON())])
    out_dir = os.path.join(run.HERE, "out")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "preview_%s.html" % locale)
    with open(path, "w", encoding="utf-8") as f:
        f.write(PAGE.replace("__LOCALE__", locale).replace("__DATA__", json.dumps(data, ensure_ascii=False)))
    print("wrote %s (%d scenes)" % (path, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
