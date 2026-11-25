-- Combat lab (used by tests/combat_audit.lua): drives the real combat code in
-- controlled fights and checks that every number comes out the way the
-- formulas, the stat sheet and the skill texts say.
--
--   (python3 tests/run.py audit)
--
-- Nothing in the add-on is changed: the combat's own local functions
-- (damageMob, damageHero, heal, heroHit, cast, applyStatus, killReward) are
-- wrapped through debug.setupvalue so every call is recorded on its way
-- through. Hero stats are pinned per test by wrapping Stats.Compute, and the
-- monsters come from a made-up stage whose monsters, numbers and skills each
-- test chooses.
local ns = NS
local C = ns.Combat
local st = C.state
local floor, abs, max, min = math.floor, math.abs, math.max, math.min

------------------------------------------------------------------------
-- Report
------------------------------------------------------------------------
local R = { pass = 0, fail = 0, fails = {} }
local function check(ok, name, detail)
	if ok then R.pass = R.pass + 1 else
		R.fail = R.fail + 1
		R.fails[#R.fails + 1] = name .. (detail and ("  — " .. detail) or "")
	end
	print(string.format("  %s %s%s", ok and "ok  " or "FAIL", name, detail and ("  — " .. detail) or ""))
end
local function section(name) print("\n== " .. name) end
local function near(a, b, tol) return abs(a - b) <= tol * max(abs(b), 1e-9) end
local function f(x, d) return string.format("%." .. (d or 3) .. "f", x) end
local function mean(t) local s = 0 for _, v in ipairs(t) do s = s + v end return #t > 0 and s / #t or 0 end

------------------------------------------------------------------------
-- Watching the combat's own functions
------------------------------------------------------------------------
local slots = {}
local function scan(fn, seen)
	if seen[fn] then return end
	seen[fn] = true
	local i = 1
	while true do
		local name, v = debug.getupvalue(fn, i)
		if not name then break end
		if type(v) == "function" then
			slots[name] = slots[name] or { value = v, at = {} }
			if slots[name].value == v then table.insert(slots[name].at, { fn, i }) end
			scan(v, seen)
		end
		i = i + 1
	end
end
do
	local seen = {}
	scan(C.Step, seen) scan(C.StartStage, seen) scan(C.Update, seen)
end
local ORIG = {}
local function hook(name, make)
	local s = assert(slots[name], "combat has no local function " .. name)
	ORIG[name] = s.value
	local new = make(s.value)
	for _, a in ipairs(s.at) do debug.setupvalue(a[1], a[2], new) end
end

local LOG
local function clearLog()
	LOG = { mob = {}, hero = {}, heal = {}, cast = {}, status = {}, kill = {}, xp = {}, revive = {}, bad = {} }
end
clearLog()
local casting, curMult
local function bad(msg) if #LOG.bad < 20 then LOG.bad[#LOG.bad + 1] = msg end end
local function finite(x) return type(x) == "number" and x == x and x > -1e300 and x < 1e300 end

hook("damageMob", function(orig) return function(src, m, amount, school, crit, quiet, dot)
	local alive = not m.dead
	if not finite(amount) or amount < 0 then bad("damageMob amount " .. tostring(amount)) end
	if alive and src and src.hero and not quiet and (src.st.stun or src.st.freeze) and casting == nil and curMult then
		bad("a stunned hero hit a monster")
	end
	local r, r2 = orig(src, m, amount, school, crit, quiet, dot)
	if alive then
		LOG.mob[#LOG.mob + 1] = { t = st.time, src = src, m = m, a = amount, school = school, crit = crit, out = r,
			dot = quiet, cast = casting, mult = curMult, srcDead = src and src.dead }
	end
	return r, r2
end end)
hook("heroHit", function(orig) return function(u, m, mult, school, critBonus, quiet)
	local prev = curMult
	curMult = mult
	local r, r2 = orig(u, m, mult, school, critBonus, quiet)
	curMult = prev
	return r, r2
end end)
hook("damageHero", function(orig) return function(h, amount, school, src, isDot)
	if not finite(amount) or amount < 0 then bad("damageHero amount " .. tostring(amount)) end
	if src and src.mob and src.dead then bad("a dead monster dealt damage") end
	local alive, shield0 = not h.dead, h.shield
	local r, how = orig(h, amount, school, src, isDot)
	if alive then
		LOG.hero[#LOG.hero + 1] = { t = st.time, wt = st.waveT, h = h, a = amount, school = school, src = src, dot = isDot, out = r, how = how, shield0 = shield0 }
	end
	return r, how
end end)
hook("heal", function(orig) return function(src, tgt, amount, quiet)
	if not finite(amount) then bad("heal amount " .. tostring(amount)) end
	local hp0, dead0 = tgt.hp, tgt.dead
	local r = orig(src, tgt, amount, quiet)
	LOG.heal[#LOG.heal + 1] = { t = st.time, src = src, tgt = tgt, a = amount, out = r, cast = casting, hp0 = hp0, dead0 = dead0 }
	return r
end end)
hook("cast", function(orig) return function(u, sid, target)
	local wasDead = u.dead
	local prev = casting
	casting = sid
	local ok = orig(u, sid, target)
	casting = prev
	if ok then
		if wasDead then bad("a dead hero cast " .. sid) end
		LOG.cast[#LOG.cast + 1] = { t = st.time, u = u, sid = sid }
	end
	return ok
end end)
hook("applyStatus", function(orig) return function(tgt, kind, hit, power, dur, school, src)
	local r = orig(tgt, kind, hit, power, dur, school, src)
	LOG.status[#LOG.status + 1] = { t = st.time, tgt = tgt, kind = kind, hit = hit, power = power, dur = dur, cast = casting }
	return r
end end)
hook("revive", function(orig) return function(h, ratio)
	local r = orig(h, ratio)
	LOG.revive[#LOG.revive + 1] = { t = st.time, h = h, ratio = ratio, hp = h.hp / h.maxhp, cast = casting }
	return r
end end)
hook("killReward", function(orig) return function(m, killer)
	local g0 = ns.db.gold
	local r = orig(m, killer)
	LOG.kill[#LOG.kill + 1] = { t = st.time, m = m, killer = killer, gold = ns.db.gold - g0 }
	return r
end end)

------------------------------------------------------------------------
-- The lab: a made-up stage and pinned hero stats
------------------------------------------------------------------------
local real = {
	Stage = ns.Stage, MobsPerWave = ns.MobsPerWave, MobAtk = ns.MobAtk, MobHP = ns.MobHP,
	Compute = ns.Stats.Compute, AddXP = ns.Heroes.AddXP, StageWaves = ns.StageWaves, StageKills = ns.StageKills,
}
local LAB
local OVR = {}
ns.Stats.Compute = function(id, extra, gear)
	local s = real.Compute(id, extra, gear)
	local o = OVR[id]
	if o then for k, v in pairs(o) do s[k] = v end end
	return s
end
ns.Stage = function(d, i) if LAB then return LAB.stage end return real.Stage(d, i) end
ns.MobsPerWave = function(d, i) if LAB then return LAB.n end return real.MobsPerWave(d, i) end
-- a lab stage: nine waves of LAB.n, then the boss (o.boss: the boss alone)
ns.StageWaves = function(d, i) if LAB then return LAB.boss and 1 or 10 end return real.StageWaves(d, i) end
ns.StageKills = function(d, i) if LAB then return LAB.boss and 0 or 9 * LAB.n end return real.StageKills(d, i) end
ns.MobAtk = function(b, l, m) if LAB and LAB.atk then return LAB.atk end return real.MobAtk(b, l, m) end
ns.MobHP = function(b, l, m) if LAB and LAB.hp then return LAB.hp end return real.MobHP(b, l, m) end
ns.Heroes.AddXP = function(id, amount)
	LOG.xp[#LOG.xp + 1] = { id = id, a = amount }
	return 0 -- levels stay put during a test
end

-- every stat a hero has, at neutral values; a test sets what it measures
local NEUTRAL = {
	atk = 100, hp = 100000, armor = 0, aspd = 1, crit = 0, critdmg = 150, regen = 0, regenPct = 0,
	hph = 0, hpk = 0, hpkPct = 0, leech = 0, dodge = 0, block = 0, dr = 0, absorb = 0, cdr = 0,
	cast = 0, move = 0, heal = 0, multi = 0, thorns = 0, exp = 0, gold = 0, skills = 0, allres = 0,
	dmg_phys = 0, dmg_fire = 0, dmg_frost = 0, dmg_nature = 0, dmg_shadow = 0, dmg_holy = 0,
	dmg_arcane = 0, dmg_all = 0, res_fire = 0, res_frost = 0, res_nature = 0, res_shadow = 0, healMult = 1,
}

local function dummy(o)
	local d = { id = "__dummy", name = "허수아비", icon = "INV_Misc_QuestionMark", type = "humanoid",
		hp = 1, atk = 1, aspd = 0.001, school = "phys", move = 600 }
	for k, v in pairs(o or {}) do d[k] = v end
	return d
end

local ROLE_SLOT = { TANK = { 1 }, DPS = { 2, 3, 4 }, HEALER = { 5 } }

-- o.heroes = { { spec =, level =, skills = { sid, ... }, slv =, stats = {...}, free = { key = true } }, ... }
-- o.mob = dummy fields, o.boss = boss fields (one wave: the boss wave), o.n = monsters per wave,
-- o.atk / o.hp = monster attack / health, o.seconds, o.each(step) called every step
local function lab(o)
	BigWowIdleDB = nil
	ns.InitDB()
	local db = ns.db
	db.faction = "ALLIANCE"
	db.gold = 1e12
	-- the party and skill-slot runes, the runes before them first
	for _, id in ipairs({ 21, 24, ns.Runes.FirstFor("skillSlot") }) do
		for _ = 1, 100 do
			if ns.Runes.Level(id) >= ns.Runes.byId[id].max or not ns.Runes.Buy(ns.Runes.NextStepTo(id)) then break end
		end
	end
	db.opt.auto, db.opt.retreat, db.opt.retry = false, false, false
	db.party = { false, false, false, false, false }
	for k in pairs(OVR) do OVR[k] = nil end
	local used, ids = {}, {}
	for i, spec in ipairs(o.heroes) do
		local h = ns.Heroes.NewRecord(spec.spec)
		h.level = spec.level or 40
		h.gear = {}
		h.sk, h.skills = {}, {}
		for k, sid in ipairs(spec.skills or {}) do
			h.sk[sid] = spec.slv or 1
			h.skills[k] = sid
		end
		local role = ns.SPECS[spec.spec].role
		for _, slot in ipairs(ROLE_SLOT[role]) do
			if not used[slot] then used[slot] = true db.party[slot] = h.id break end
		end
		if spec.gear then
			-- real gear of the hero's level instead of pinned stats
			local sp = ns.SPECS[spec.spec]
			for _, slot in ipairs(ns.SLOTS) do
				local w
				if slot == "mh" then w = sp.mh[1] elseif slot == "oh" then w = sp.oh and sp.oh[1] end
				if slot ~= "oh" or w then h.gear[slot] = ns.Items.New(slot, h.level, spec.gear, w) end
			end
		else
			local pin = {}
			for k, v in pairs(NEUTRAL) do if not (spec.free and spec.free[k]) then pin[k] = v end end
			for k, v in pairs(spec.stats or {}) do pin[k] = v end
			for k in pairs(spec.free or {}) do pin[k] = nil end
			OVR[h.id] = pin
		end
		ids[i] = h.id
	end
	ns.Stats.Invalidate()
	ns.MONSTERS.__dummy = dummy(o.mob)
	local stage = {}
	for k, v in pairs(real.Stage(1, 1)) do stage[k] = v end
	stage.mobs = { { "__dummy", 1 } }
	stage.boss = o.boss and dummy(o.boss) or dummy({ boss = true })
	stage.raid = false
	LAB = { stage = stage, n = o.n or 1, atk = o.atk, hp = o.hp, boss = o.boss and true }
	if o.realStage then LAB = nil end -- a real stage of the game
	db.stage = { diff = o.diff or 1, idx = o.idx or 10 }
	clearLog()
	C.StartStage()
	local units = {}
	for i, id in ipairs(ids) do
		for _, u in ipairs(C.heroes) do if u.id == id then units[i] = u end end
	end
	for step = 1, (o.seconds or 60) * 10 do
		if o.each then o.each(step, units) end
		C.Step()
	end
	return units, LOG
end
local function endLab()
	LAB = nil
	ns.MONSTERS.__dummy = nil
	for k in pairs(OVR) do OVR[k] = nil end
end

-- basic attacks: hits from heroHit outside a skill, at full strength (mult 1)
local function basics(log, u, multVal)
	local out = {}
	for _, e in ipairs(log.mob) do
		if e.src == u and e.cast == nil and e.mult == (multVal or 1) and not e.dot then out[#out + 1] = e end
	end
	return out
end

-- fells a hero on the spot (to test reviving)
local function kill(u) if not u.dead then ORIG.damageHero(u, 1e15, "phys", nil, true) end end

return {
	kill = kill, real = real, OVR = OVR,
	check = check, section = section, near = near, f = f, mean = mean, lab = lab, endLab = endLab,
	basics = basics, ORIG = ORIG, R = R, LOGF = function() return LOG end, NEUTRAL = NEUTRAL, st = st,
}
