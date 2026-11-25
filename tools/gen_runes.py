#!/usr/bin/env python3
"""Write BigIdleHeroes/Data/Runes.lua: TBH's rune tree.

    python3 -I tools/gen_runes.py RUNES_PAGE_JSON RUNES_TABLE_JSON

RUNES_PAGE_JSON: the rune list of taskbarhero.wiki/runes (each rune's place on
the tree, names, levels with value and gold cost); RUNES_TABLE_JSON:
taskbarhero.wiki/data/t/runes.json (which runes follow which, and the level a
rune needs in the one before it).

Every rune has one rune before it (its parent), except the first. A rune
opens once its parent is at the level PrevNodeRequiredLevel names, or at its
full level when none is named. Rune 1133 has no parent in TBH's data; it
stands next to 113 on the tree and is put under it.
"""
import json
import os
import sys

page = {r["key"]: r for r in json.load(open(sys.argv[1], encoding="utf-8"))}
table = json.load(open(sys.argv[2], encoding="utf-8"))
rows = table if isinstance(table, list) else table.get("rows", table)
info = {r["RuneKey"]: r for r in rows}

parent = {}
for key, r in info.items():
    nxt = r.get("NextRuneKey")
    if nxt is None:
        continue
    for child in str(nxt).split():
        c = int(child)
        assert c not in parent, ("two parents", c)
        parent[c] = key
parent.setdefault(1133, 113)
roots = [k for k in page if k not in parent]
assert roots == [1] or sorted(roots) == [1], roots

GRID = 72.0


def node(key):
    p = page[key]
    r = info[key]
    m = int(p["maxLevel"])
    levels = sorted(p["levels"], key=lambda l: l["level"])[:m]  # (409 lists its last level six times)
    assert [l["level"] for l in levels] == list(range(1, m + 1)), key
    assert all(l["stat"] == p["stat"] for l in levels), key
    assert all(l["costItem"] == 100001 for l in levels), key   # gold
    # (TBH's y runs down; 409 stands 2 units off its cell)
    x, y = round(p["x"] / GRID), round(-p["y"] / GRID)
    assert abs(x * GRID - p["x"]) < 4 and abs(-y * GRID - p["y"]) < 4, key
    out = ['n = "%s"' % p["name"]["ko-KR"], "x = %d" % x, "y = %d" % y, "m = %d" % m]
    if key in parent:
        out.append("p = %d" % parent[key])
    req = r.get("PrevNodeRequiredLevel")
    if req is not None:
        out.append("q = %d" % req)
    out.append('s = "%s"' % p["stat"])
    out.append("v = { %s }" % ", ".join(str(l["value"]) for l in levels))
    out.append("c = { %s }" % ", ".join(str(l["costValue"]) for l in levels))
    return "\t[%d] = { %s }," % (key, ", ".join(out))


# parents before children (a walk from the first rune), siblings by key
order, todo = [], [1]
kids = {}
for c, p in parent.items():
    kids.setdefault(p, []).append(c)
while todo:
    k = todo.pop(0)
    order.append(k)
    todo.extend(sorted(kids.get(k, [])))
assert len(order) == len(page), (len(order), len(page))

L = [
    "-- TBH's rune tree (tools/gen_runes.py writes this file from TBH's data).",
    "-- Account-wide upgrades bought with gold: the first rune (1) opens the",
    "-- rest, each rune after the one before it (p).",
    "--",
    "-- [key] = { n = name, x, y = place on the tree (cells, y up), m = top level,",
    "--   p = the rune before it, q = the level it must have (none: its top",
    "--   level), s = what it gives (Systems/Runes.lua ns.RUNE_STAT),",
    "--   v = value at each level, c = TBH's gold cost of each level }",
    "local _, ns = ...",
    "",
    "ns.RUNE_FIRST = 1",
    "ns.RUNES = {",
]
L += [node(k) for k in order]
L += ["}", ""]
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "BigIdleHeroes", "Data", "Runes.lua")
with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(L))
print("wrote %s (%d runes)" % (out, len(order)))
