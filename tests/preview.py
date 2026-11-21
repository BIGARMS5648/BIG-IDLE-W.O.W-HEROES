#!/usr/bin/env python3
"""Draw the addon's UI without the game.

The mocked WoW API records where every frame, texture and text is anchored.
This script arranges a few scenes, exports them, and writes
tests/out/preview_<locale>.html, a page that resolves the anchors and paints
each scene: the addon's own textures (Media/, embedded as PNG) with their
texture coordinates and tints, the real text, and stand-ins for game art the
repository cannot contain (item / spell icons and class portraits).
It is a layout check, not a pixel-accurate rendering of the game.

    python3 tools/make_art.py          # once, to have the PNG twins of Media/
    python3 tests/preview.py
"""
import base64
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run  # noqa: E402

SCENES = [
    "bar", "bar_boss", "bar_wipe", "faction", "create", "create_druid", "pets", "pets_locked", "rename",
    "party", "party_bench", "party_slot", "party_dismiss",
    "hero", "hero_slot", "hero_slot_empty", "hero_reset", "hero_skills", "hero_skill_locked", "hero_tree", "hero_tree_locked", "hero_bench",
    "bag", "bag_tooltip", "bag_locked", "bag_weapon", "bag_mats", "bag_mats_sorted", "bag_sockets", "bag_sockets_tip", "bag_sockets_mixed", "bag_sockets_mixed_tip", "bag_smelt_one", "bag_smelt_all", "bag_smelt_list", "bag_fuse_mats", "bag_bank_empty", "bag_bank", "bag_max", "bag_gem_mats", "bag_seal_mats", "bag_full",
    "forge_fuse", "forge_fuse_grade", "forge_fuse_kind", "forge_fuse_ready", "forge_smelt", "forge_craft", "forge_craft_locked", "forge_craft_far", "forge_gem", "forge_gem_sockets", "forge_ench", "forge_ench_sockets",
    "forge_remove", "forge_remove_sockets", "forge_seal", "forge_locked",
    "runes", "runes_locked", "runes_total",
    "map", "map_heroic", "map_raid", "map_locked",
    "options", "options_game", "options_info", "options_reset",
    "new_party", "new_hero", "new_bag", "new_bag_mats", "new_forge", "new_one", "new_one_slot", "new_one_hero", "new_map", "new_runes",
]

PAGE = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>Layout preview</title>
<style>
  body { background:#1b1f27; color:#ddd; font:13px sans-serif; margin:16px; }
  h2 { font-size:14px; margin:18px 0 6px; }
  canvas { background:#3b4a40; display:block; }
</style></head><body>
<h1 style="font-size:16px">BIG W.O.W HEROES - 화면 미리보기</h1>
<div id="root"></div>
<script>
const SCENES = __DATA__;
const MEDIA = __MEDIA__;
const FONT = '"WenQuanYi Zen Hei","Noto Sans CJK KR","Malgun Gothic",sans-serif';
const LAYER = { BACKGROUND:0, BORDER:1, ARTWORK:2, OVERLAY:3, HIGHLIGHT:4 };
const STRATA = { BACKGROUND:0, LOW:1, MEDIUM:2, HIGH:3, DIALOG:4, FULLSCREEN:5, FULLSCREEN_DIALOG:6, TOOLTIP:7 };
const W = 1920, H = 1080;
const CLASS = { // texcoord left,top of the class circle sheet (2 decimals) -> color, initial
  '0,0':['#c79c6e','W'], '0.25,0':['#69ccf0','M'], '0.5,0':['#fff569','R'], '0.74,0':['#ff7d0a','D'],
  '0,0.25':['#abd473','H'], '0.25,0.25':['#2e8bff','S'], '0.5,0.25':['#ffffff','P'], '0.74,0.25':['#9482c9','L'],
  '0,0.5':['#f58cba','Pa'] };
const mctx = document.createElement('canvas').getContext('2d');
const images = {};

function segments(text) {
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

// Lines as the game would wrap them: at spaces between words; a word longer
// than the line is split (e._split marks that, the layout check reports it).
function layoutText(e, wrapW) {
  mctx.font = e.size + 'px ' + FONT;
  const lines = [];
  e._split = false;
  for (const raw of e.text.split('\n')) {
    const segs = segments(raw);
    if (!(wrapW > 0) || e.nowrap) { lines.push(segs); continue; }
    let cur = [], width = 0;
    const push = () => { lines.push(cur); cur = []; width = 0; };
    for (const s of segs) {
      const parts = s.text.match(/\S+|\s+/g) || [];
      for (const p of parts) {
        const pw = mctx.measureText(p).width;
        if (p.trim() === '') {
          if (cur.length === 0) continue;
          cur.push({ color: s.color, text: p }); width += pw; continue;
        }
        if (width + pw <= wrapW + 0.5) { cur.push({ color: s.color, text: p }); width += pw; continue; }
        if (cur.length > 0) push();
        if (pw <= wrapW + 0.5) { cur.push({ color: s.color, text: p }); width += pw; continue; }
        // the word alone is too long: split it
        e._split = true;
        for (const ch of Array.from(p)) {
          const cw = mctx.measureText(ch).width;
          if (width + cw > wrapW + 0.5 && cur.length > 0) push();
          cur.push({ color: s.color, text: ch }); width += cw;
        }
      }
    }
    // drop trailing spaces
    while (cur.length && cur[cur.length - 1].text.trim() === '') cur.pop();
    lines.push(cur);
  }
  let maxw = 0;
  for (const l of lines) {
    while (l.length && l[l.length - 1].text.trim() === '') l.pop();
    let w = 0; for (const s of l) w += mctx.measureText(s.text).width;
    l.width = w; if (w > maxw) maxw = w;
  }
  return { lines, width: maxw, height: lines.length * e.size * 1.22 };
}

function hash(s) { let h = 0; for (const c of s) h = (h * 31 + c.charCodeAt(0)) >>> 0; return h; }

// rotated or skewed texture coordinates (SetTexCoord with 8 numbers: the
// corners UL, LL, UR, LR): map the image so each corner lands on its own
function drawTex8(g, img, e, x, y, w, h) {
  const [ulx, uly, llx, lly, urx, ury] = e.tc8;
  const iw = img.width, ih = img.height;
  const S = 2, cw = Math.max(1, Math.ceil(w * S)), ch = Math.max(1, Math.ceil(h * S));
  const off = document.createElement('canvas'); off.width = cw; off.height = ch;
  const o = off.getContext('2d');
  const p0x = ulx * iw, p0y = uly * ih;
  const ax = (urx - ulx) * iw, ay = (ury - uly) * ih;   // along the rect's width
  const bx = (llx - ulx) * iw, by = (lly - uly) * ih;   // along its height
  const det = ax * by - bx * ay;
  if (Math.abs(det) < 1e-9) return;
  const A = cw * by / det, C = -cw * bx / det, B = -ch * ay / det, D = ch * ax / det;
  o.setTransform(A, B, C, D, -(A * p0x + C * p0y), -(B * p0x + D * p0y));
  o.drawImage(img, 0, 0);
  o.setTransform(1, 0, 0, 1, 0, 0);
  const v = e.vertex;
  if (v && (v[0] < 0.999 || v[1] < 0.999 || v[2] < 0.999)) {
    o.globalCompositeOperation = 'multiply';
    o.fillStyle = `rgb(${v[0]*255},${v[1]*255},${v[2]*255})`;
    o.fillRect(0, 0, cw, ch);
    o.globalCompositeOperation = 'destination-in';
    o.setTransform(A, B, C, D, -(A * p0x + C * p0y), -(B * p0x + D * p0y));
    o.drawImage(img, 0, 0);
    o.setTransform(1, 0, 0, 1, 0, 0);
  }
  g.save();
  g.globalAlpha *= (v && v[3] != null ? v[3] : 1);
  g.drawImage(off, x, y, w, h);
  g.restore();
}

// draw part of an image (texture coordinates), tinted, into the rect
function drawTex(g, img, e, x, y, w, h) {
  if (e.tc8) return drawTex8(g, img, e, x, y, w, h);
  const tc = e.tc || [0, 1, 0, 1];
  const iw = img.width, ih = img.height;
  let [u0, u1, v0, v1] = tc;
  const flipX = u1 < u0, flipY = v1 < v0;
  const sx = Math.min(u0, u1) * iw, sw = Math.max(1e-3, Math.abs(u1 - u0) * iw);
  const sy = Math.min(v0, v1) * ih, sh = Math.max(1e-3, Math.abs(v1 - v0) * ih);
  const S = 2, cw = Math.max(1, Math.ceil(w * S)), ch = Math.max(1, Math.ceil(h * S));
  const off = document.createElement('canvas'); off.width = cw; off.height = ch;
  const o = off.getContext('2d');
  o.save();
  o.translate(flipX ? cw : 0, flipY ? ch : 0); o.scale(flipX ? -1 : 1, flipY ? -1 : 1);
  o.drawImage(img, sx, sy, sw, sh, 0, 0, cw, ch);
  o.restore();
  const v = e.vertex;
  if (v && (v[0] < 0.999 || v[1] < 0.999 || v[2] < 0.999)) {
    o.globalCompositeOperation = 'multiply';
    o.fillStyle = `rgb(${v[0]*255},${v[1]*255},${v[2]*255})`;
    o.fillRect(0, 0, cw, ch);
    o.globalCompositeOperation = 'destination-in';
    o.save(); o.translate(flipX ? cw : 0, flipY ? ch : 0); o.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    o.drawImage(img, sx, sy, sw, sh, 0, 0, cw, ch); o.restore();
  }
  if (e.desat) g.filter = 'grayscale(1)';
  const a = g.globalAlpha;
  if (v && v[3] != null) g.globalAlpha = a * v[3];
  g.drawImage(off, x, y, w, h);
  g.globalAlpha = a;
  g.filter = 'none';
}

// Where everything is: rectangles (WoW coordinates, y up) and the draw order.
function resolve(scene) {
  const byId = {}; for (const e of scene.items) { byId[e.id] = e; delete e._r; delete e._t; delete e._unanchored; }
  const root = scene.root;
  function point(r, p) {
    const x = p.includes('LEFT') ? r.l : p.includes('RIGHT') ? r.r : (r.l + r.r) / 2;
    const y = p.includes('TOP') ? r.t : p.includes('BOTTOM') ? r.b : (r.b + r.t) / 2;
    return [x, y];
  }
  function rect(e) {
    if (e._r) return e._r;
    if (e.id === root) return (e._r = { l:0, b:0, r:W, t:H });
    e._r = { l:0, b:0, r:0, t:0 };
    let w = e.w, h = e.h;
    let L, R, T, B, CX, CY, all = null;
    for (const a of e.anchors) {
      const rel = byId[a[1]]; if (!rel) continue;
      const rr = rect(rel);
      if (a[0] === 'ALL') { all = rr; break; }
      const [ax, ay] = point(rr, a[2]); const x = ax + a[3], y = ay + a[4]; const P = a[0];
      if (P.includes('LEFT')) L = x; else if (P.includes('RIGHT')) R = x; else CX = x;
      if (P.includes('TOP')) T = y; else if (P.includes('BOTTOM')) B = y; else CY = y;
    }
    if (all) { L = all.l; R = all.r; T = all.t; B = all.b; }
    if (e.kind === 'text') {
      // the wrap width: both side anchors, else an explicit width, else none
      const wrapW = (L != null && R != null) ? R - L : (w > 0 ? w : 0);
      e._t = layoutText(e, wrapW);
      e._wrapW = wrapW;
      if (!(w > 0)) w = e._t.width;
      if (!(h > 0)) h = e._t.height;
    }
    if (L != null && R != null) w = R - L; else if (L != null) R = L + w; else if (R != null) L = R - w;
    else if (CX != null) { L = CX - w / 2; R = CX + w / 2; } else { L = 0; R = w; e._unanchored = true; }
    if (T != null && B != null) h = T - B; else if (T != null) B = T - h; else if (B != null) T = B + h;
    else if (CY != null) { B = CY - h / 2; T = CY + h / 2; } else { B = 0; T = h; e._unanchored = true; }
    return (e._r = { l:L, b:B, r:R, t:T });
  }
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
  order.forEach((e, i) => { e._i = i; rect(e); });
  // what a clipping ancestor (SetClipsChildren) lets show
  for (const e of order) {
    e._clip = null;
    for (let x = byId[e.parent]; x; x = byId[x.parent]) if (x.clips) { e._clip = x._r; break; }
  }
  return { byId, order, rect, root, children };
}

// The area a text really paints (lines placed by its justification).
function textBox(e) {
  const r = e._r, t = e._t; if (!t) return r;
  const boxW = r.r - r.l, boxH = r.t - r.b;
  let top = r.t; if (e.jv === 'MIDDLE') top -= (boxH - t.height) / 2; else if (e.jv === 'BOTTOM') top -= boxH - t.height;
  let l = Infinity, rr = -Infinity;
  for (const line of t.lines) {
    if (!line.width) continue;
    let x = r.l; if (e.jh === 'CENTER') x += (boxW - line.width) / 2; else if (e.jh === 'RIGHT') x += boxW - line.width;
    l = Math.min(l, x); rr = Math.max(rr, x + line.width);
  }
  if (l === Infinity) return null;
  // glyphs sit inside the line box: trim the leading so touching lines are not "overlaps"
  const pad = e.size * 0.11;
  return { l, r: rr, t: top - pad, b: top - t.height + pad };
}

function draw(scene, title) {
  const R = resolve(scene);
  const byId = R.byId, order = R.order, rect = R.rect;
  let bx0 = W, by0 = H, bx1 = 0, by1 = 0;
  for (const e of order) {
    const r = rect(e); if (e._unanchored || r.r - r.l <= 0) continue;
    bx0 = Math.min(bx0, r.l); bx1 = Math.max(bx1, r.r); by0 = Math.min(by0, r.b); by1 = Math.max(by1, r.t);
  }
  const pad = 16; bx0 = Math.max(0, bx0 - pad); by0 = Math.max(0, by0 - pad); bx1 = Math.min(W, bx1 + pad); by1 = Math.min(H, by1 + pad);
  const cw = Math.max(50, bx1 - bx0), ch = Math.max(30, by1 - by0);

  const h2 = document.createElement('h2'); h2.textContent = title; document.getElementById('root').appendChild(h2);
  const c = document.createElement('canvas'); c.id = 'scene-' + title; c.width = cw * 2; c.height = ch * 2; c.style.width = cw + 'px'; c.style.height = ch + 'px';
  document.getElementById('root').appendChild(c);
  const g = c.getContext('2d'); g.scale(2, 2); g.translate(-bx0, 0);
  // a stand-in for the game world behind the UI
  const bg = g.createLinearGradient(0, 0, 0, ch); bg.addColorStop(0, '#41566a'); bg.addColorStop(1, '#2a3a2e');
  g.fillStyle = bg; g.fillRect(bx0, 0, cw, ch);
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
        const path = String(e.tex);
        const name = path.split('\\').pop().replace(/\.tga$/i, '');
        if (path.includes('\\Media\\') && images[name]) {
          drawTex(g, images[name], e, x, y, w, h);
        } else if (path.includes('UI-Classes-Circles')) {
          const r2 = v => String(Math.round(v * 100) / 100);
          const key = e.tc ? r2(e.tc[0]) + ',' + r2(e.tc[2]) : '0,0';
          const [col, ini] = CLASS[key] || ['#888', '?'];
          if (e.desat) g.filter = 'grayscale(1)';
          g.fillStyle = col; g.beginPath(); g.arc(x + w / 2, y + h / 2, Math.min(w, h) / 2, 0, Math.PI * 2); g.fill();
          g.fillStyle = 'rgba(0,0,0,0.55)'; g.font = 'bold ' + Math.round(h * 0.42) + 'px ' + FONT; g.textAlign = 'center'; g.textBaseline = 'middle';
          g.fillText(ini, x + w / 2, y + h / 2 + 1); g.textAlign = 'left'; g.filter = 'none';
        } else {
          // a game icon: a shaded tile with a short label
          const hue = hash(name) % 360;
          if (e.desat) g.filter = 'grayscale(1)';
          const grd = g.createLinearGradient(x, y, x, y + h);
          grd.addColorStop(0, `hsl(${hue},45%,46%)`); grd.addColorStop(1, `hsl(${hue},50%,22%)`);
          g.fillStyle = grd; g.fillRect(x, y, w, h);
          if (w >= 18) {
            const label = name.replace(/^(INV|Spell|Ability|Trade)_/, '').replace(/^(Misc|Nature|Holy|Shadow|Fire|Frost|Hunter|Warrior|Rogue|Druid)_/, '');
            g.fillStyle = 'rgba(255,255,255,0.8)'; g.font = Math.max(6, Math.round(w / 6)) + 'px ' + FONT; g.textBaseline = 'top';
            g.fillText(label.slice(0, Math.max(3, Math.floor(w / 5))), x + 2, y + 2);
          }
          g.filter = 'none';
        }
      }
    } else if (e.kind === 'text') {
      if (!e._t) e._t = layoutText(e, e._wrapW || 0);
      const t = e._t; g.font = e.size + 'px ' + FONT; g.textBaseline = 'top';
      const base = e.color ? `rgb(${Math.round(e.color[0]*255)},${Math.round(e.color[1]*255)},${Math.round(e.color[2]*255)})` : '#fff';
      const boxW = r.r - r.l, boxH = r.t - r.b;
      let y = Y(r.t); if (e.jv === 'MIDDLE') y += (boxH - t.height) / 2; else if (e.jv === 'BOTTOM') y += boxH - t.height;
      for (const line of t.lines) {
        let x = r.l; if (e.jh === 'CENTER') x += (boxW - line.width) / 2; else if (e.jh === 'RIGHT') x += boxW - line.width;
        for (const s of line) {
          g.fillStyle = 'rgba(0,0,0,0.85)'; g.fillText(s.text, x + 1, y + 1);
          g.fillStyle = s.color || base; g.fillText(s.text, x, y);
          x += g.measureText(s.text).width;
        }
        y += e.size * 1.22;
      }
    }
  }
  g.globalAlpha = 1;
}

// ---------------------------------------------------------------------------
// Layout check: problems a player would see. Every visible item of a scene is
// tested; tests/layout_check.js prints the list and fails on any problem.
// ---------------------------------------------------------------------------
const SEE_THROUGH = new Set(['glow','ring','frame','shadow','grad_h','grad_v','check','lock','star','crown','arrow','plus',
  'close','auto','skull','role_tank','role_dps','role_heal','circle','bar']);
const SLICES = new Set(['panel','card','inset','button','pill','slot','menu']);
function texName(e) { return e.tex ? String(e.tex).split('\\').pop().replace(/\.tga$/i, '') : null; }

function lint(scene, title) {
  const R = resolve(scene); const byId = R.byId, order = R.order, root = R.root;
  const out = [];
  const alpha = e => { let a = 1; for (let x = e; x; x = byId[x.parent]) a *= (x.alpha == null ? 1 : x.alpha); return a; };
  const topOf = e => { let x = e; while (x && x.parent !== root && byId[x.parent]) x = byId[x.parent]; return x; };
  const isAnc = (a, b) => { for (let x = byId[b.parent]; x; x = byId[x.parent]) if (x === a) return true; return false; };
  const area = r => Math.max(0, r.r - r.l) * Math.max(0, r.t - r.b);
  const inter = (a, b) => ({ l: Math.max(a.l, b.l), r: Math.min(a.r, b.r), t: Math.min(a.t, b.t), b: Math.max(a.b, b.b) });
  const contains = (a, b) => a.l <= b.l + 0.5 && a.r >= b.r - 0.5 && a.t >= b.t - 0.5 && a.b <= b.b + 0.5;
  const vis = e => alpha(e) > 0.05;
  const opaque = e => {
    if (e.kind !== 'texture' || !vis(e)) return false;
    const a = alpha(e);
    if (e.color) return e.color[3] * a >= 0.8;
    const n = texName(e); if (!n) return false;
    const va = (e.vertex && e.vertex[3] != null) ? e.vertex[3] : 1;
    if (String(e.tex).includes('\\Media\\') && !String(e.tex).includes('\\Art\\')) {
      if (SEE_THROUGH.has(n) || !SLICES.has(n)) return false;
      return va * a >= 0.8;
    }
    return va * a >= 0.8;
  };
  const label = f => {
    const kids = (R.children[f.id] || []).filter(k => k.kind === 'text' && vis(k) && k.text);
    return kids.map(k => k.text.replace(/\|c[0-9a-fA-F]{8}|\|r/g, '')).join(' ').trim();
  };
  const name = e => {
    if (e.kind === 'text') return '"' + e.text.replace(/\|c[0-9a-fA-F]{8}|\|r/g, '').replace(/\n/g, '⏎').slice(0, 40) + '"';
    if (e.kind === 'frame') { const l = label(e); return (e.ftype === 'Button' ? '버튼' : '틀') + (l ? ' "' + l.slice(0, 30) + '"' : '#' + e.id); }
    return '그림 ' + (texName(e) || 'color') + '#' + e.id;
  };
  const add = (kind, msg, ...items) => out.push({ scene: title, kind, msg, items: items.map(name) });

  const live = order.filter(e => vis(e) && !(e.kind === 'frame' && e.id === root));
  const tops = new Map(); live.forEach(e => tops.set(e, topOf(e)));
  // modal dimmers, and the click catcher of an open list: what is drawn before
  // them in the same window is out of play
  const dims = live.filter(e => (e.kind === 'texture' && e.color && e.color[3] * alpha(e) >= 0.4 && tops.get(e)
    && area(e._r) >= 0.85 * area(tops.get(e)._r)) || (e.kind === 'frame' && e.catcher));
  const owner = d => d.kind === 'frame' ? d : byId[d.parent];
  const behind = e => dims.some(d => d._i > e._i && tops.get(d) === tops.get(e) && !isAnc(owner(d), e) && owner(d) !== e);
  const act = live.filter(e => !behind(e));
  const tooltip = e => (tops.get(e) && tops.get(e).strata === 'TOOLTIP');
  const texts = act.filter(e => e.kind === 'text' && e.text && e.text.trim() && !tooltip(e) && !e.moving);
  const buttons = act.filter(e => e.kind === 'frame' && (e.ftype === 'Button' || e.ftype === 'CheckButton') && e.click && !e.nomouse
    && area(e._r) > 4 && !tooltip(e));
  const covers = act.filter(e => opaque(e) && area(e._r) > 30);
  const box = e => e.kind === 'text' ? textBox(e) : e._r;

  for (const e of act) {
    if (e._unanchored && (e.kind !== 'frame' || e.parent !== root) && area(e._r) > 0) add('unanchored', '위치가 지정되지 않음', e);
  }
  for (const e of texts) {
    const r = e._r, t = e._t, tb = textBox(e); if (!tb) continue;
    const boxW = r.r - r.l, boxH = r.t - r.b;
    if (e.size < 10) add('small', '글자 크기 ' + e.size + ' (최소 10)', e);
    if (e.nowrap && e._wrapW > 0 && t.width > e._wrapW + 1) add('clip', '한 줄 글자가 칸보다 김: ' + Math.round(t.width) + ' > ' + Math.round(e._wrapW) + ' (잘려서 …로 보임)', e);
    if (t.lines.length > 1 && t.height > boxH + e.size * 0.35) add('clip', '여러 줄 글자가 높이를 넘침: ' + t.lines.length + '줄, 높이 ' + Math.round(boxH), e);
    if (e._split) add('wrap', '단어가 중간에서 끊겨 다음 줄로 넘어감', e);
    const plain = e.text.replace(/\|c[0-9a-fA-F]{8}|\|r/g, '');
    if (t.lines.length > 1 && !plain.includes('\n') && plain.length <= 14) add('wrap', '짧은 글자가 두 줄로 나뉨', e);
    const p = byId[e.parent];
    if (p && p.kind === 'frame' && p.id !== root && area(p._r) > 16) {
      const pr = p._r;
      if (tb.l < pr.l - 2 || tb.r > pr.r + 2 || tb.t > pr.t + 3 || tb.b < pr.b - 3)
        add('outside', '글자가 자기 틀 밖으로 나감 (' + name(p) + ')', e);
    }
  }
  // outside the window
  for (const e of act) {
    const top = tops.get(e); if (!top || top === e || tooltip(e)) continue;
    const n = texName(e);
    if (e.kind === 'texture' && (!opaque(e) || SEE_THROUGH.has(n))) continue;
    if (e.kind === 'frame' && !(buttons.includes(e))) continue;
    let b = box(e); if (!b || area(b) <= 0) continue;
    if (e._clip) { b = inter(b, e._clip); if (b.r - b.l <= 0 || b.t - b.b <= 0) continue; }
    const tr = top._r, tol = 6;
    if (b.l < tr.l - tol || b.r > tr.r + tol || b.t > tr.t + tol || b.b < tr.b - tol) add('window', '창 밖으로 나감', e);
  }
  // overlaps between texts, and text on someone else's button
  const coveredBetween = (a, b, ir) => covers.some(c => c._i > a._i && c._i < b._i && contains(c._r, ir) && !isAnc(c, a));
  for (let i = 0; i < texts.length; i++) {
    const A = texts[i], ab = textBox(A); if (!ab) continue;
    for (let j = i + 1; j < texts.length; j++) {
      const B = texts[j], bb = textBox(B); if (!bb) continue;
      const ir = inter(ab, bb);
      if (ir.r - ir.l > 2 && ir.t - ir.b > 2) {
        const [x, y] = A._i < B._i ? [A, B] : [B, A];
        if (!coveredBetween(x, y, ir)) add('overlap', '글자끼리 겹침', A, B);
      }
    }
    for (const Bt of buttons) {
      if (isAnc(Bt, A) || tops.get(Bt) !== tops.get(A)) continue;
      const ir = inter(ab, Bt._r);
      if (ir.r - ir.l > 2 && ir.t - ir.b > 2 && area(ir) > 6) {
        if (A._i > Bt._i && !coveredBetween(Bt, A, ir)) add('onbutton', '글자가 다른 버튼 위에 겹침', A, Bt);
      }
    }
  }
  // hidden under something drawn later
  for (const X of texts.concat(buttons)) {
    const xb = box(X); if (!xb || area(xb) <= 0) continue;
    let covered = 0, by = null;
    for (const c of covers) {
      if (c._i <= X._i || isAnc(X, c) || tooltip(c)) continue;
      // another window over this one: only a problem when it covers a button
      if (tops.get(c) !== tops.get(X) && X.kind === 'text') continue;
      const ir = inter(xb, c._r);
      if (ir.r - ir.l > 1 && ir.t - ir.b > 1 && area(ir) > 20) { covered += area(ir); by = by || c; }
    }
    // text under something solid is (partly) unreadable; a button under it cannot be clicked there
    if (covered >= (X.kind === 'text' ? 0.08 : 0.3) * area(xb)) add('hidden', '다른 것에 가려짐 (' + name(byId[by.parent] || by) + ')', X);
  }
  // buttons on top of each other; the same button twice
  const seen = new Map();
  for (let i = 0; i < buttons.length; i++) {
    const A = buttons[i];
    for (let j = i + 1; j < buttons.length; j++) {
      const B = buttons[j];
      if (isAnc(A, B) || isAnc(B, A) || tops.get(A) !== tops.get(B)) continue;
      const ir = inter(A._r, B._r);
      if (ir.r - ir.l > 2 && ir.t - ir.b > 2) add('overlap', '버튼끼리 겹침', A, B);
    }
    const l = label(A);
    if (l && l.length >= 2 && !A.item && !/^[0-9.,\s/%+:-]+$/.test(l)) {
      const key = tops.get(A).id + '|' + l;
      if (seen.has(key)) add('duplicate', '같은 버튼이 두 번 있음', seen.get(key), A); else seen.set(key, A);
    }
    const hasLook = (function walk(f) {
      for (const k of (R.children[f.id] || [])) {
        if (!vis(k)) continue;
        if (k.kind === 'text' && k.text && k.text.trim()) return true;
        if (k.kind === 'texture' && area(k._r) > 0) return true;
        if (k.kind === 'frame' && walk(k)) return true;
      }
      return false;
    })(A);
    if (!hasLook) add('invisible', '보이지 않는 버튼(누를 수 있는 빈 칸)', A);
  }
  return out;
}

const loads = Object.entries(MEDIA).map(([k, src]) => new Promise(res => {
  const im = new Image(); im.onload = () => { images[k] = im; res(); }; im.onerror = res; im.src = src;
}));
Promise.all(loads).then(() => {
  for (const [title, scene] of SCENES) draw(scene, title);
  window.LINT = [];
  for (const [title, scene] of SCENES) window.LINT.push(...lint(scene, title));
  document.title = 'ready';
});
</script></body></html>
"""


def media():
    d = os.path.join(run.HERE, "out", "media")
    out = {}
    if not os.path.isdir(d):
        sys.exit("run tools/make_art.py first (it writes the PNG twins of Media/)")
    for f in sorted(os.listdir(d)):
        if f.endswith(".png"):
            with open(os.path.join(d, f), "rb") as fh:
                out[f[:-4]] = "data:image/png;base64," + base64.b64encode(fh.read()).decode("ascii")
    return out


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
    page = PAGE.replace("__LOCALE__", locale).replace("__MEDIA__", json.dumps(media())).replace("__DATA__", json.dumps(data, ensure_ascii=False))
    with open(path, "w", encoding="utf-8") as f:
        f.write(page)
    print("wrote %s (%d scenes)" % (path, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
