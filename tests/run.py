#!/usr/bin/env python3
"""Load the addon into a Lua 5.1 runtime with a mocked WoW API and run test scripts.

    python3 tests/run.py                 # all checks (systems, UI smoke test, short balance run)
    python3 tests/run.py balance 40      # only the balance run, 40 simulated hours
    python3 tests/run.py balance 2 MAGE_FIRE   # ... starting with another specialization
    python3 tests/run.py cover           # line coverage of the addon under the tests
    python3 tests/run.py ui              # only the UI smoke test
    python3 tests/run.py audit           # combat formulas measured in controlled fights

Needs:  pip install lupa
"""
import os
import sys

try:
    import lupa.lua51 as lupa
except ImportError:  # pragma: no cover
    sys.exit("lupa with a bundled Lua 5.1 is required:  pip install lupa")

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON_NAME = "BigWowIdle"
ADDON_DIR = os.path.join(HERE, "..", ADDON_NAME)


def toc_files():
    files = []
    with open(os.path.join(ADDON_DIR, ADDON_NAME + ".toc"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                files.append(line.replace("\\", "/"))
    return files


COVER_HOOK = """
COVERAGE = {}
debug.sethook(function(_, line)
    local src = debug.getinfo(2, "S").source
    local t = COVERAGE[src]
    if not t then t = {} COVERAGE[src] = t end
    t[line] = true
end, "l")
"""


def new_runtime(locale="koKR", partial=False, cover=False):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    lua.execute("package.path = package.path .. ';%s/?.lua'" % HERE.replace("\\", "/"))
    lua.execute("dofile(%r)" % os.path.join(HERE, "wowmock.lua"))
    if cover:
        lua.execute(COVER_HOOK)
    g.WoWMock.locale = locale
    lua.execute("NS = {}")
    loader = lua.eval(
        """function(path, name)
            local chunk, err = loadfile(path)
            if not chunk then error(err, 0) end
            return chunk(name, NS)
        end"""
    )
    missing = []
    for rel in toc_files():
        path = os.path.join(ADDON_DIR, rel)
        if not os.path.exists(path):
            if partial:
                missing.append(rel)
                continue
            raise SystemExit("TOC lists a missing file: " + rel)
        loader(path, ADDON_NAME)
    if missing:
        print("  (partial load, skipped: %s)" % ", ".join(missing))
    return lua


def run_script(lua, name, *args):
    fn = lua.eval("function(path, ...) return assert(loadfile(path))(...) end")
    return fn(os.path.join(HERE, name), *args)


def report_coverage(lua):
    """Print, per addon file, the code lines the tests never executed."""
    import re

    skip = re.compile(r"^\s*(--.*|end[,)]*|else|\}[,)]*|\{|\)|local function .*|function .*|[\w.]+ = function.*)?\s*$")
    cov = lua.globals().COVERAGE
    hit_by_file = {}
    for src in cov:
        name = str(src)
        if ADDON_NAME in name:
            hit_by_file[os.path.normpath(name.lstrip("@"))] = set(int(k) for k in cov[src])
    total_code = total_hit = 0
    for rel in toc_files():
        path = os.path.normpath(os.path.join(ADDON_DIR, rel))
        hits = hit_by_file.get(path, set())
        missed = []
        code = 0
        with open(path, encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                if skip.match(line.rstrip("\n")):
                    continue
                code += 1
                if n not in hits:
                    missed.append(n)
        total_code += code
        total_hit += code - len(missed)
        pct = 100.0 * (code - len(missed)) / max(1, code)
        print("  %-22s %5.1f%%  missed: %s" % (rel, pct, " ".join(map(str, missed[:60])) + (" ..." if len(missed) > 60 else "")))
    print("  total %.1f%% of %d code lines" % (100.0 * total_hit / max(1, total_code), total_code))


def main(argv):
    what = argv[1] if len(argv) > 1 else "all"
    ok = True

    if what in ("all", "systems"):
        print("== systems ==")
        lua = new_runtime()
        ok = run_script(lua, "test_systems.lua") and ok

    if what in ("all", "ui"):
        for locale in ("koKR", "enUS"):  # a Korean client, and any other client (font fallback)
            print("== ui test (game client %s, interface in Korean) ==" % locale)
            lua = new_runtime(locale)
            ok = run_script(lua, "test_ui.lua") and ok

    if what in ("all", "uiart"):
        # the same UI test with every interface picture and icon of
        # tools/asset_spec.py imported (as if the art were finished)
        print("== ui test with all interface art imported ==")
        sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
        import asset_spec
        lua = new_runtime("koKR")
        art = lua.globals().NS.ART
        for a in asset_spec.ASSETS:
            if a["kind"] == "ui":
                e = lua.table_from({"file": a["id"], "w": a["size"][0], "h": a["size"][1]})
                if a.get("slice") is not None:
                    e.slice = a["slice"]
                art.ui[a["id"]] = e
            elif a["kind"] == "icons":
                for i in a["icons"]:
                    art.icons[i] = lua.table_from({"file": i, "w": 128, "h": 128})
        ok = run_script(lua, "test_ui.lua") and ok

    if what in ("all", "layout"):
        # every scene of tests/preview.py drawn in a browser and checked for
        # text that is cut off, spills out or wraps badly, overlaps, things
        # hidden under other things, things outside the window, the same
        # button twice and text smaller than 10
        print("== layout check (tests/preview.py + tests/layout_check.js) ==")
        import subprocess
        here = os.path.dirname(os.path.abspath(__file__))
        r1 = subprocess.run([sys.executable, os.path.join(here, "preview.py")], capture_output=True, text=True)
        if r1.returncode != 0:
            print(r1.stdout[-2000:] + r1.stderr[-2000:])
            ok = False
        else:
            r2 = subprocess.run(["node", os.path.join(here, "layout_check.js")], capture_output=True, text=True)
            lines = (r2.stdout or "").splitlines()
            bad = [l for l in lines if not l.startswith("ok ")]
            print("\n".join(bad[-60:]) if bad else "")
            print("  %d scenes checked" % sum(1 for l in lines if l.startswith(("ok ", "FAIL "))))
            if r2.returncode != 0:
                ok = False

    if what in ("all", "balance"):
        hours = float(argv[2]) if len(argv) > 2 else 6
        starter = argv[3] if len(argv) > 3 else "HUNTER_MM"
        print("== balance run (%g simulated hours, starting as %s) ==" % (hours, starter))
        lua = new_runtime()
        ok = run_script(lua, "test_balance.lua", hours, starter) and ok

    if what == "audit":
        # every combat formula measured in controlled fights (tests/combat_audit.lua)
        print("== combat audit ==")
        lua = new_runtime()
        ok = run_script(lua, "combat_audit.lua") and ok

    if what == "bench":
        # specialization benchmark / tuner (takes several minutes)
        passes = int(argv[2]) if len(argv) > 2 else 3
        lua = new_runtime()
        ok = run_script(lua, "bench.lua", passes) and ok

    if what == "cover":
        # line coverage of the addon under the systems + UI tests (slow)
        lua = new_runtime(cover=True)
        ok = run_script(lua, "test_systems.lua") and ok
        ok = run_script(lua, "test_ui.lua") and ok
        ok = run_script(lua, "test_balance.lua", 1) and ok
        report_coverage(lua)

    if what == "partial":
        hours = float(argv[2]) if len(argv) > 2 else 6
        lua = new_runtime(partial=True)
        ok = run_script(lua, "test_systems.lua") and ok
        ok = run_script(lua, "test_balance.lua", hours) and ok

    print("RESULT: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
