-- The battle simulation. It runs in fixed 0.1 s steps on a 1-D lane
-- (x = 0 on the left, 1000 on the right): heroes hold a formation on the left,
-- monsters walk in from the right. The UI only reads this state.
local _, ns = ...

local floor, max, min, random = math.floor, math.max, math.min, math.random
local U = ns.U

local Combat = {}
ns.Combat = Combat

local STEP = 0.1
-- Timers count down by STEP; 0.5 - 0.1 * 5 is a hair above zero in floating
-- point, so "is it done?" compares against EPS, not 0 (else every timer ran
-- one step late: a 0.5 s tick every 0.6 s, a 6 s cooldown every 6.1 s).
local EPS = 1e-6
local LANE = 1000
local FRONT_X = 400
local REVIVE_TIME = 20
local SOFT_ENRAGE = 75      -- seconds into a wave before monsters start to ramp up
local MAX_MOBS = 12

Combat.STEP = STEP
Combat.heroes = {}
Combat.mobs = {}
Combat.fields = {}
Combat.fx = {}
Combat.meter = {}      -- [heroId] = { dmg, heal, taken, deaths } for the running stage
Combat.lastMeter = {}  -- the same for the stage before
Combat.sum = {}        -- [heroId] = totals across stages (filled in by tests/bench.lua)
Combat.state = { phase = "idle", wave = 0, waves = 0, timer = 0, time = 0 }

local heroes, mobs, fields, fxList = Combat.heroes, Combat.mobs, Combat.fields, Combat.fx
local st = Combat.state

------------------------------------------------------------------------
-- Visual events (consumed by the battle bar; capped so they never pile up)
------------------------------------------------------------------------
-- Visual events for the battle window's effects (shots and impacts). Only
-- drawn when effect art exists; the window empties the list every frame.
Combat.vfx = {}
local function vfx(e)
	local list = Combat.vfx
	if #list >= 30 then table.remove(list, 1) end
	list[#list + 1] = e
end
Combat.VFX = vfx

local function fx(x, text, r, g, b, big, side)
	if #fxList >= 40 then table.remove(fxList, 1) end
	fxList[#fxList + 1] = { x = x, text = text, r = r, g = g, b = b, big = big, side = side }
end

local function fxSkill(u, icon)
	u.castIcon = icon
	u.castT = 0.8
end

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
local function aliveHeroes()
	local n = 0
	for i = 1, #heroes do
		if not heroes[i].dead then n = n + 1 end
	end
	return n
end

local function aliveMobs()
	local n = 0
	for i = 1, #mobs do
		if not mobs[i].dead then n = n + 1 end
	end
	return n
end

-- The hero monsters run at: the tank while it stands, otherwise whoever is in front.
local function frontHero()
	local best
	for i = 1, #heroes do
		local h = heroes[i]
		if not h.dead then
			if h.role == "TANK" then return h end
			if not best or h.x > best.x then best = h end
		end
	end
	return best
end

-- The melee heroes behind the leader: this one's place among them (1 for
-- the one nearest the front, by where they started) and how many there are.
local MELEE_GAP = 28
local function meleeRank(u, front)
	local k, n = 1, 0
	for i = 1, #heroes do
		local h = heroes[i]
		if h ~= front and not h.dead and not h.ranged then
			n = n + 1
			if h ~= u and (h.homeX > u.homeX or (h.homeX == u.homeX and h.slot < u.slot)) then k = k + 1 end
		end
	end
	return k, n
end

local function nearestMob()
	local best
	for i = 1, #mobs do
		local m = mobs[i]
		if not m.dead and (not best or m.x < best.x) then best = m end
	end
	return best
end

local function lowestAlly(maxRatio)
	local best, bestR
	for i = 1, #heroes do
		local h = heroes[i]
		if not h.dead then
			local r = h.hp / h.maxhp
			if r < (maxRatio or 2) and (not bestR or r < bestR) then
				best, bestR = h, r
			end
		end
	end
	return best
end

local function isDisabled(u)
	return u.st.stun ~= nil or u.st.freeze ~= nil
end

------------------------------------------------------------------------
-- Stats of a hero unit, including auras and timed buffs
------------------------------------------------------------------------
local function collectAuras()
	local mods = {}
	for i = 1, #heroes do
		local u = heroes[i]
		if not u.dead then
			for _, sid in ipairs(u.skills) do
				local sk = ns.SKILLS[sid]
				if sk.kind == "aura" and not sk.self then
					local lvl = u.slv[sid] or 1
					for _, m in ipairs(sk.mods) do
						mods[#mods + 1] = { m[1], m[2] + m[3] * (lvl - 1) }
					end
				end
			end
		end
	end
	return mods
end

local function recalc(u, auras)
	local extra = {}
	for i = 1, #auras do extra[#extra + 1] = auras[i] end
	for _, b in ipairs(u.buffs) do
		for _, m in ipairs(b.mods) do extra[#extra + 1] = m end
	end
	for _, sid in ipairs(u.skills) do -- auras that only affect their owner
		local sk = ns.SKILLS[sid]
		if sk.kind == "aura" and sk.self then
			local lvl = u.slv[sid] or 1
			for _, m in ipairs(sk.mods) do
				extra[#extra + 1] = { m[1], m[2] + m[3] * (lvl - 1) }
			end
		end
	end
	local s = ns.Stats.Compute(u.id, extra)
	u.s = s
	local oldMax = u.maxhp
	u.maxhp = s.hp
	if not oldMax or oldMax <= 0 then
		u.hp = s.hp
	elseif s.hp ~= oldMax then
		-- the same share of health as before: a buff, an aura or a piece of
		-- gear coming and going heals nothing
		u.hp = s.hp * max(0, min(1, u.hp / oldMax))
	end
end

local function loadSkills(u)
	local s = ns.Stats.Get(u.id)
	u.skills = ns.Heroes.ActiveSkills(u.id)
	u.slv = {}
	u.cd = u.cd or {}
	u.cnt = u.cnt or {}
	for n, sid in ipairs(u.skills) do
		u.slv[sid] = max(1, ns.Heroes.SkillLevel(u.id, sid, s))
		if ns.SKILLS[sid].act == "cd" and not u.cd[sid] then
			u.cd[sid] = 1 + n * 0.7 -- stagger the opening casts
		end
		u.cnt[sid] = u.cnt[sid] or 0
	end
	-- permanent companions (pet skills): each attacks on its own timer
	local pets = {}
	for _, sid in ipairs(u.skills) do
		local sk = ns.SKILLS[sid]
		if sk.kind == "pet" then
			local old = u.pets and u.pets[sid]
			pets[sid] = { sk = sk, mult = ns.SkillValue(sid, u.slv[sid]) / 100, t = old and old.t or sk.tick }
		end
	end
	u.pets = pets
end

local function recalcAll()
	-- the roster changed under us (save replaced or edited): start over
	for i = 1, #heroes do
		local u = heroes[i]
		if not ns.db.heroes[u.id] or ns.db.party[u.slot] ~= u.id then
			Combat.dirty = false
			Combat.StartStage()
			return
		end
	end
	for i = 1, #heroes do loadSkills(heroes[i]) end
	local auras = collectAuras()
	for i = 1, #heroes do recalc(heroes[i], auras) end
	Combat.dirty = false
end

------------------------------------------------------------------------
-- Healing and shields
------------------------------------------------------------------------
local function meter(u, key, amount)
	local m = Combat.meter[u.id]
	if m then m[key] = m[key] + amount end
	m = Combat.sum[u.id] -- running totals, only kept when a benchmark asks for them
	if m then m[key] = (m[key] or 0) + amount end
end

local function heal(src, tgt, amount, quiet)
	if tgt.dead or amount <= 0 then return 0 end
	if src and src.s then amount = amount * (1 + (src.s.heal or 0) / 100) * (src.s.healMult or 1) end
	local before = tgt.hp
	tgt.hp = min(tgt.maxhp, tgt.hp + amount)
	local done = tgt.hp - before
	if src and done > 0 then meter(src, "heal", done) end
	if not quiet and done >= tgt.maxhp * 0.03 then
		fx(tgt.x, "+" .. U.fmt(done), 0.3, 1, 0.3, false, "hero")
	end
	return done
end

------------------------------------------------------------------------
-- Status ailments (both sides)
------------------------------------------------------------------------
-- src: who applied it. A damage over time keeps the stronger of the old and
-- the new; whoever's that is gets the damage it deals. hit: the blow that
-- applied it as it came in, before the target's resistances and armor (its
-- ticks go through them).
local function applyStatus(tgt, kind, hit, power, dur, school, src)
	if tgt.dead then return end
	local def = ns.STATUS[kind]
	if not def then return end
	dur = dur or def.dur
	if def.kind == "cc" then
		if (tgt.ccImmune or 0) > 0 then return end
		if tgt.boss then dur = dur * 0.5 end
		tgt.ccImmune = dur + (tgt.boss and 8 or 4)
	end
	local e = tgt.st[kind]
	if not e then
		e = {}
		tgt.st[kind] = e
		fx(tgt.x, ns.N(def.name), 1, 0.9, 0.4, false, tgt.hero and "hero" or "mob")
	end
	e.t = max(e.t or 0, dur)
	local k = def.kind
	if k == "hitdot" or k == "dot" then
		local dps = k == "hitdot" and (hit or 0) * def.power / 100 or (power or ((hit or 0) * 0.2))
		if dps >= (e.dps or 0) then
			e.dps = dps
			e.school = k == "hitdot" and def.school or (school or def.school)
			e.src = src
		end
	elseif k == "slow" then
		e.v = def.power
	elseif k == "vuln" or k == "weak" then
		e.v = max(e.v or 0, power or def.power or 0)
	end
end

------------------------------------------------------------------------
-- Rewards
------------------------------------------------------------------------
local function killReward(m, killer)
	local db = ns.db
	local goldPct = ns.Bonus("gold")
	for i = 1, #heroes do goldPct = goldPct + (heroes[i].s.gold or 0) end
	-- the runes' gold and experience on top: every kill, then by kind (a
	-- monster, a stage's boss, an act's boss); the gold bonus counts them too
	local addG, addX = ns.Bonus("goldKill"), ns.Bonus("expKill")
	if m.boss then
		local k = st.raid and "Act" or "Boss"
		addG, addX = addG + ns.Bonus("gold" .. k), addX + ns.Bonus("exp" .. k)
	elseif not m.summoned then
		addG, addX = addG + ns.Bonus("goldMob"), addX + ns.Bonus("expMob")
	end
	local gold = (m.gold + addG) * (1 + goldPct / 100)
	gold = max(1, floor(gold + 0.5))
	local exp = m.exp + addX
	ns.AddGold(gold)
	st.gGold = st.gGold + gold
	st.gXP = st.gXP + exp
	Combat.earn.g = Combat.earn.g + gold
	Combat.earn.x = Combat.earn.x + exp

	local expBonus = ns.Bonus("exp")
	for i = 1, #heroes do
		local u = heroes[i]
		local h = db.heroes[u.id]
		local amount = exp * (1 + (expBonus + (u.s.exp or 0)) / 100) * ns.Heroes.XPFactor(h.level, st.level)
		if ns.Heroes.AddXP(u.id, amount) > 0 then
			fx(u.x, "레벨 업!", 1, 0.85, 0.1, true, "hero")
			ns.Sound("level")
			Combat.dirty = true
		end
	end

	db.kills[m.type] = (db.kills[m.type] or 0) + 1
	db.stat.kills = db.stat.kills + 1
	ns.CheckPets()

	-- the stage's TBH boxes: the monster box at its rate each kill and the
	-- boss box at its rate (an act boss always drops its box), both raised by
	-- their runes, and a second boss box by the companions' bonus
	-- (a floor of the endless tower: its own chests, gear of the tower's level)
	local tf = st.tower
	local tb = tf and ns.Tower.Drops(tf) or ns.TBH.STAGES[st.diff][st.idx]
	local lvl = tf and ns.Tower.ITEM_LEVEL or st.level
	if m.boss then
		local chest = st.raid and 3 or 2
		if random() * 1000 < tb.brate * (1 + ns.Bonus("bossRate") / 100) then
			if not ns.Loot.AddChest(chest, lvl, st.diff, tb.bbox, tf) then ns.Loot.Lost(chest) end
		end
		if random() * 100 < ns.Bonus("bossChest") then
			if not ns.Loot.AddChest(chest, lvl, st.diff, tb.bbox, tf) then ns.Loot.Lost(chest) end
		end
	elseif not m.summoned and tb.mbox then
		if random() * 1000 < tb.mrate * (1 + ns.Bonus("chestChance") / 100) then
			if not ns.Loot.AddChest(1, lvl, st.diff, tb.mbox, tf) then ns.Loot.Lost(1) end
		end
	end

	if killer and killer.hero and not killer.dead then
		local s = killer.s
		local amount = (s.hpk or 0) + killer.maxhp * (s.hpkPct or 0) / 100
		if amount > 0 then heal(nil, killer, amount) end
	end
end

------------------------------------------------------------------------
-- Damage
------------------------------------------------------------------------
local towerDeath -- (below: the tower's affixes when a monster dies)

-- dot: a damage-over-time tick (no floor of 1: that would add up every tick)
-- Returns what landed and the blow as it came (before resistances).
local function damageMob(src, m, amount, school, crit, quiet, dot)
	if m.dead then return 0 end
	local came = amount
	local res = m.res and m.res[school]
	if res then amount = amount * (1 - res / 100) end
	if m.st.shock then amount = amount * (1 + m.st.shock.v / 100) end
	if m.st.curse then amount = amount * (1 + m.st.curse.v / 100) end
	if (m.drT or 0) > 0 then amount = amount * (1 - m.dr / 100) end
	if not dot then amount = max(1, amount) end
	-- what landed (not past the monster's health): the meter, life drain and
	-- leech all go by this
	local landed = min(amount, m.hp)
	if src and src.hero then meter(src, "dmg", landed) end
	m.hp = m.hp - amount
	m.flash = 0.12
	-- the tower's 분노: a monster low on health rages
	local a = st.affix
	if a and a.raging and not m.boss and not m.raged and m.hp > 0 and m.hp < m.maxhp * ns.Tower.FX.raging.below then
		m.raged = true
		m.atk = m.atk * ns.Tower.FX.raging.atk
		fx(m.x, "격노!", 1, 0.3, 0.2, false, "mob")
	end
	if not quiet then
		if crit then
			fx(m.x, U.fmt(amount) .. "!", 1, 0.9, 0.2, true, "mob")
		else
			local c = ns.SCHOOL[school]
			local r, g, b = 1, 1, 1
			if c and school ~= "phys" then r, g, b = U.rgb(c.hex) end
			fx(m.x, U.fmt(amount), r, g, b, false, "mob")
		end
	end
	if m.hp <= 0 then
		m.hp = 0
		m.dead = true
		m.fade = 0.4
		killReward(m, src)
		if st.affix then towerDeath(m) end
	end
	return landed, came
end

-- Returns what landed, "dodge" when it missed, and the blow as it came
-- (blocked or not, before armor and resistances).
local function damageHero(h, amount, school, src, isDot)
	if h.dead then return 0 end
	local s = h.s
	if not isDot then
		if random() * 100 < s.dodge then
			fx(h.x, "회피", 0.7, 0.7, 0.7, false, "hero")
			return 0, "dodge" -- missed: nothing landed (no thorns, no ailment)
		end
		if random() * 100 < s.block then
			amount = amount * 0.5
		end
	end
	local came = amount
	-- "pure": a share of health (the tower's affixes), past armor and resistances
	if school == "phys" then
		amount = amount * (1 - ns.Stats.ArmorDR(s.armor, st.level))
	elseif school ~= "pure" then
		local res = (s["res_" .. school] or 0) + s.allres
		if res > 75 then res = 75 end
		amount = amount * (1 - res / 100)
	end
	if school ~= "pure" then amount = amount * (1 - s.dr / 100) end
	if h.st.shock then amount = amount * (1 + h.st.shock.v / 100) end
	if not isDot then
		amount = amount - s.absorb
		if amount < 1 then amount = 1 end
	end
	if h.shield > 0 then
		local a = min(h.shield, amount)
		h.shield = h.shield - a
		amount = amount - a
		if h.shieldSrc then meter(h.shieldSrc, "heal", a) end
		if amount <= 0 then return 0, nil, came end
	end
	meter(h, "taken", amount)
	h.hp = h.hp - amount
	h.flash = 0.12
	if not isDot and amount >= h.maxhp * 0.04 then
		fx(h.x, "-" .. U.fmt(amount), 1, 0.3, 0.3, false, "hero")
	end
	if h.hp <= 0 then
		h.hp = 0
		h.dead = true
		h.reviveT = REVIVE_TIME
		h.st = {}
		h.buffs = {}
		h.shield = 0
		h.hots = {}
		meter(h, "deaths", 1)
		fx(h.x, "쓰러짐!", 1, 0.2, 0.2, true, "hero")
		Combat.dirty = true -- auras from this hero end
	end
	return amount, nil, came
end

------------------------------------------------------------------------
-- The endless tower's affixes (ns.TOWER_AFFIXES; their numbers in
-- ns.Tower.FX)
------------------------------------------------------------------------
-- a monster died: 피웅덩이 heals the others, 강화 makes the other monsters
-- stronger, 파열 hurts every hero
towerDeath = function(m)
	local a = st.affix
	if m.boss then return end
	local T = ns.Tower.FX
	if a.sanguine or a.bolstering then
		for i = 1, #mobs do
			local o = mobs[i]
			if o ~= m and not o.dead then
				if a.sanguine then o.hp = min(o.maxhp, o.hp + o.maxhp * T.sanguine.share) end
				if a.bolstering and not o.boss then
					o.maxhp = o.maxhp * T.bolstering.mult
					o.hp = o.hp * T.bolstering.mult
					o.atk = o.atk * T.bolstering.mult
				end
			end
		end
	end
	if a.bursting then
		for i = 1, #heroes do
			local h = heroes[i]
			if not h.dead then damageHero(h, h.maxhp * T.bursting.share, "pure", nil, true) end
		end
	end
end

-- every step of a fight: 치명상 on hurt heroes, 화산 under one hero, 전율 on all
local function towerTick()
	local a = st.affix
	if not a then return end
	local T, t = ns.Tower.FX, st.affT
	local function due(key, every)
		t[key] = (t[key] or 0) + STEP
		if t[key] >= every - EPS then
			t[key] = t[key] - every
			return true
		end
	end
	if a.grievous and due("grievous", T.grievous.every) then
		for i = 1, #heroes do
			local h = heroes[i]
			if not h.dead and h.hp < h.maxhp * T.grievous.below then damageHero(h, h.maxhp * T.grievous.share, "pure", nil, true) end
		end
	end
	if a.volcanic and due("volcanic", T.volcanic.every) then
		local alive = {}
		for i = 1, #heroes do if not heroes[i].dead then alive[#alive + 1] = heroes[i] end end
		local h = alive[1] and alive[random(#alive)]
		if h then
			fx(h.x, "화산", 1, 0.45, 0.1, false, "hero")
			damageHero(h, h.maxhp * T.volcanic.share, "fire", nil, true)
		end
	end
	if a.quaking and due("quaking", T.quaking.every) then
		local first = true
		for i = 1, #heroes do
			local h = heroes[i]
			if not h.dead then
				if first then fx(h.x, "전율", 0.85, 0.7, 0.45, false, "hero") first = false end
				damageHero(h, h.maxhp * T.quaking.share, "pure", nil, true)
			end
		end
	end
end

local function revive(h, ratio)
	h.dead = false
	h.hp = max(1, floor(h.maxhp * ratio))
	h.reviveT = 0
	h.atkT = 0.5
	fx(h.x, "부활", 0.6, 1, 0.6, true, "hero")
	Combat.dirty = true
end

------------------------------------------------------------------------
-- Monsters
------------------------------------------------------------------------
-- The stage the monsters, or the boss, come from: the stage fought, or on a
-- floor of the tower the stage rolled for them.
local function sourceOf(isBoss)
	local s2 = st.tower and (isBoss and st.bossStage or st.mobStage)
	if s2 then return s2[1], s2[2] end
	return st.diff, st.idx
end
Combat.SourceOf = sourceOf

local function newMob(def, isBoss, index, summoned)
	local l = st.level
	local hp, atk = ns.MobHP(def.hp, l, st.might), ns.MobAtk(def.atk, l, st.might)
	-- a stage of the game (not a test's): its monsters on one footing
	local sd, si = sourceOf(isBoss)
	local norm = not summoned and ns.Stage(sd, si) == ns.STAGES[sd][si] and ns.StageNorm(sd, si)
	if norm then
		hp = hp * (isBoss and norm.bossHP or norm.hp)
		atk = atk * (isBoss and norm.bossAtk or norm.atk)
	end
	-- a floor of the endless tower: stronger every floor, and 폭군 / 경화
	local tf = st.tower
	if tf then
		hp, atk = hp * ns.Tower.HPMult(tf), atk * ns.Tower.AtkMult(tf)
		local T = ns.Tower.FX
		if isBoss then
			if st.affix.tyrannical then hp, atk = hp * T.tyrannical.hp, atk * T.tyrannical.atk end
		elseif st.affix.fortified then
			hp, atk = hp * T.fortified.hp, atk * T.fortified.atk
		end
	end
	hp = floor(hp + 0.5)
	local m = {
		mob = true, def = def, name = def.name, icon = def.icon, type = def.type, boss = isBoss, summoned = summoned,
		hp = hp, maxhp = hp, atk = atk, aspd = def.aspd, range = def.range,
		school = def.school, move = def.move, res = def.res, status = def.status,
		gold = ns.MobGold(1 + def.hp / 14, l), exp = ns.MobExp(1 + def.hp / 10, l),
		x = LANE + (index - 1) * 45 + random(0, 20), off = ((index - 1) % 4) * 12,
		atkT = 0.3 + random() * 0.6, st = {}, enr = 1, drT = 0, dr = 0, flash = 0, anim = 0,
	}
	if summoned then
		m.gold = m.gold * 0.25
		m.exp = m.exp * 0.25
	end
	if tf then m.gold = m.gold * ns.Tower.GoldMult(tf) end
	if def.skills then
		m.sk = {}
		for i, sk in ipairs(def.skills) do
			m.sk[i] = { def = sk, cd = (sk.cd or 0) * 0.6 + i }
		end
	end
	return m
end

local function spawnWave()
	local stage = ns.Stage(sourceOf(false))
	local bossStage = ns.Stage(sourceOf(true))
	local n = st.tower and ns.Tower.MobsPerWave() or ns.MobsPerWave(st.diff, st.idx)
	local isBossWave = st.wave == st.waves
	local index = 1
	if isBossWave then
		-- the boss alone (its stage's monsters all came in the waves before)
		mobs[#mobs + 1] = newMob(bossStage.boss, true, index)
		index = index + 1
		n = 0
		if st.raid then ns.Sound("boss") end
	else
		-- the last of the waves takes what is left of the stage's monsters
		local kills = st.tower and ns.Tower.Kills(st.tower) or ns.StageKills(st.diff, st.idx)
		local left = kills - (st.wave - 1) * n
		n = max(0, min(n, left))
	end
	local pool = {}
	for _, e in ipairs(stage.mobs) do
		pool[#pool + 1] = { id = e[1], w = e[2] }
	end
	for _ = 1, n do
		local pick = U.weighted(pool)
		mobs[#mobs + 1] = newMob(ns.MONSTERS[pick.id], false, index)
		index = index + 1
	end
	st.waveT = 0
	ns.Fire("WAVE")
end

-- the classic spell a boss ability is (Data/Effects.lua): its name shows
-- when it is used and its effect plays on whom it reaches
local function mobSpell(m, kind, school, to)
	local sp = ns.MobFx and ns.MobFx(kind, school)
	vfx({ k = "mob", u = m, kind = kind, school = school, to = to })
	return sp and sp.name
end

local function mobSkill(m, entry)
	local sk = entry.def
	local kind = sk.kind
	if kind == "enrage" then
		if not entry.done and m.hp / m.maxhp <= sk.hp then
			entry.done = true
			m.enr = sk.mult
			fx(m.x, (mobSpell(m, "enrage", m.school, { m }) or "격노") .. "!", 1, 0.2, 0.2, true, "mob")
		end
		return
	end
	entry.cd = entry.cd - STEP
	if entry.cd > EPS then return end
	entry.cd = sk.cd
	local school = sk.school or m.school
	local weak = m.st.weaken and (1 - m.st.weaken.v / 100) or 1
	if kind == "smash" then
		local t = frontHero()
		if t then
			m.anim = 0.25
			local name = mobSpell(m, "smash", school, { t })
			if name then fx(m.x - 40, name .. "!", 1, 0.75, 0.4, false, "mob") end
			local dealt, _, came = damageHero(t, m.atk * sk.mult * m.enr * st.rage * weak, school, m)
			if dealt > 0 and sk.status and random() < sk.status[2] then
				applyStatus(t, sk.status[1], came)
			end
		end
	elseif kind == "aoe" then
		m.anim = 0.25
		local to = {}
		for i = 1, #heroes do
			if not heroes[i].dead then to[#to + 1] = heroes[i] end
		end
		fx(m.x - 80, (mobSpell(m, "aoe", school, to) or "광역 공격") .. "!", 1, 0.6, 0.2, false, "mob")
		for i = 1, #heroes do
			local t = heroes[i]
			if not t.dead then
				local dealt, _, came = damageHero(t, m.atk * sk.mult * m.enr * st.rage * weak, school, m)
				if dealt > 0 and sk.status and random() < sk.status[2] then
					applyStatus(t, sk.status[1], came)
				end
			end
		end
	elseif kind == "summon" then
		local def = ns.MONSTERS[sk.mob]
		-- adds do not pile up without limit while the party is busy with the boss
		local out = 0
		for i = 1, #mobs do
			if mobs[i].summoned and not mobs[i].dead then out = out + 1 end
		end
		for i = 1, sk.n do
			if #mobs < MAX_MOBS and out + i <= 4 then
				local add = newMob(def, false, i, true)
				add.x = min(LANE, m.x + 40 + i * 35)
				mobs[#mobs + 1] = add
			end
		end
		mobSpell(m, "summon", school, { m })
		fx(m.x, def.name .. " 소환!", 0.8, 0.6, 1, false, "mob")
	elseif kind == "shield" then
		m.drT = sk.dur
		m.dr = sk.dr
		fx(m.x, (mobSpell(m, "shield", school, { m }) or "보호막") .. "!", 0.6, 0.8, 1, false, "mob")
	end
end

local function stepMob(m)
	if m.dead then
		m.fade = m.fade - STEP
		return
	end
	if m.flash > 0 then m.flash = m.flash - STEP end
	if m.anim > 0 then m.anim = m.anim - STEP end
	if m.drT > 0 then m.drT = m.drT - STEP end
	if (m.ccImmune or 0) > 0 then m.ccImmune = m.ccImmune - STEP end

	-- ailments: one that has run out goes before it acts again, so a 2 s
	-- stun holds for 20 steps and a 4 s damage over time ticks 40 times
	for kind, e in pairs(m.st) do
		e.t = e.t - STEP
		if e.t < -EPS then
			m.st[kind] = nil
		elseif e.dps then
			local dealt = damageMob(e.src, m, e.dps * STEP, e.school or "phys", false, true, true)
			e.acc = (e.acc or 0) + dealt
			e.show = (e.show or 1) - STEP
			if e.show <= EPS then
				e.show = 1
				-- (under 1 a second it keeps adding up until there is a number)
				if e.acc >= 1 then
					local c = ns.SCHOOL[e.school or "phys"]
					local r, g, b = U.rgb(c.hex)
					fx(m.x, U.fmt(e.acc), r, g, b, false, "mob")
					e.acc = 0
				end
			end
			if m.dead then return end
		end
	end
	if isDisabled(m) then return end

	local front = frontHero()
	if not front then return end
	local slow = m.st.chill and (1 - m.st.chill.v / 100) or 1

	-- movement
	local stopX
	if m.range then
		stopX = front.x + 230 + m.off * 2
	else
		stopX = front.x + 75 + m.off * 1.5
	end
	if m.x > stopX then
		m.x = max(stopX, m.x - m.move * slow * STEP)
	end

	-- abilities
	if m.sk then
		for i = 1, #m.sk do
			mobSkill(m, m.sk[i])
			if m.dead then return end
		end
	end

	-- an ability may have just felled the hero this monster was facing
	front = frontHero()
	if not front then return end

	-- basic attack
	m.atkT = m.atkT - STEP * slow
	local inReach
	if m.range then
		inReach = (m.x - front.x) <= m.range
	else
		inReach = m.x <= stopX + 25
	end
	-- out of reach, a ready swing waits instead of piling up time (else two
	-- would land at once on arrival)
	if not inReach and m.atkT < 0 then m.atkT, m.waited = 0, true end
	if m.atkT <= EPS and inReach then
		-- keep the remainder (else a slowed monster loses time each swing);
		-- after waiting there is none
		m.atkT = (m.waited and 0 or m.atkT) + 1 / m.aspd
		m.waited = nil
		if m.atkT < 0 then m.atkT = 0 end
		local t = front
		if m.range then
			-- ranged monsters harass anyone
			local pool = {}
			for i = 1, #heroes do
				if not heroes[i].dead then pool[#pool + 1] = heroes[i] end
			end
			if #pool > 0 then t = pool[random(1, #pool)] end
		end
		m.anim = 0.15
		local weak = m.st.weaken and (1 - m.st.weaken.v / 100) or 1
		local amount = m.atk * U.rnd(0.9, 1.1) * m.enr * st.rage * weak
		local dealt, how, came = damageHero(t, amount, m.school, m)
		if dealt > 0 and m.status and random() < m.status[2] then
			applyStatus(t, m.status[1], came)
		end
		-- thorns answer a melee blow that landed (a dodged one did not)
		if not m.range and how ~= "dodge" and not t.dead and (t.s.thorns or 0) > 0 then
			damageMob(t, m, t.s.atk * t.s.thorns / 100, "nature", false)
		end
	end
end

------------------------------------------------------------------------
-- Hero skills
------------------------------------------------------------------------
local function schoolMult(s, school)
	return 1 + ((s["dmg_" .. school] or 0) + s.dmg_all) / 100
end

local function rollCrit(s, bonus)
	return random() * 100 < s.crit + (bonus or 0)
end

-- up to n living monsters, closest to `first` first
local function pickTargets(first, n)
	local list = {}
	for i = 1, #mobs do
		if not mobs[i].dead then list[#list + 1] = mobs[i] end
	end
	if n >= #list then return list end
	local fx0 = first and first.x or 0
	table.sort(list, function(a, b) return math.abs(a.x - fx0) < math.abs(b.x - fx0) end)
	local out = {}
	for i = 1, n do out[i] = list[i] end
	return out
end

local function heroHit(u, m, mult, school, critBonus, quiet)
	local s = u.s
	local amount = s.atk * mult * U.rnd(0.95, 1.05) * schoolMult(s, school)
	local crit = rollCrit(s, critBonus)
	if crit then amount = amount * s.critdmg / 100 end
	local dealt, came = damageMob(u, m, amount, school, crit, quiet)
	if dealt > 0 and s.leech > 0 and not u.dead then
		heal(nil, u, dealt * s.leech / 100)
	end
	return dealt, came
end

local function needsMet(u, sk)
	local w = sk.when
	if not w then return true end
	if w.self then return u.hp / u.maxhp < w.self end
	if w.ally then return lowestAlly(w.ally) ~= nil end
	return true
end

-- Returns true if the skill was actually used.
local function cast(u, sid, target)
	local sk = ns.SKILLS[sid]
	local lvl = u.slv[sid] or 1
	local v = ns.SkillValue(sid, lvl)
	local kind = sk.kind
	if not needsMet(u, sk) then return false end
	local to = {} -- whom the skill reached (for the battle window's effects)

	if kind == "dmg" then
		if not target then return false end
		local list = pickTargets(target, sk.targets or 1)
		for _, m in ipairs(list) do
			to[#to + 1] = m
			for _ = 1, sk.hits or 1 do
				local mult = v / 100
				if sk.exec and m.hp / m.maxhp * 100 <= sk.exec[1] then mult = mult * sk.exec[2] end
				local dealt, came = heroHit(u, m, mult, sk.school, sk.critBonus)
				if dealt > 0 then
					if sk.status and random() < sk.status[2] then
						applyStatus(m, sk.status[1], came, nil, nil, nil, u)
					end
					if sk.drain and not u.dead then
						heal(u, u, min(dealt * sk.drain / 100, u.maxhp * 0.3))
					end
				end
			end
		end
		if sk.healAll then
			local pct = sk.healAll[1] + sk.healAll[2] * (lvl - 1)
			for i = 1, #heroes do
				heal(u, heroes[i], heroes[i].maxhp * pct / 100)
			end
		end
		if sk.atone then
			local t = lowestAlly(1)
			if t then heal(u, t, t.maxhp * (sk.atone[1] + sk.atone[2] * (lvl - 1)) / 100) end
		end
		if sk.selfHeal and not u.dead then
			heal(u, u, u.maxhp * (sk.selfHeal[1] + sk.selfHeal[2] * (lvl - 1)) / 100)
		end
	elseif kind == "dot" then
		if not target then return false end
		local list = pickTargets(target, sk.targets or 1)
		local dps = u.s.atk * v / 100 * schoolMult(u.s, sk.school)
		for _, m in ipairs(list) do
			to[#to + 1] = m
			applyStatus(m, sk.status, nil, dps, sk.dur, sk.school, u)
		end
	elseif kind == "field" and sk.heal then
		if lowestAlly(sk.when and sk.when.ally or 1) == nil then return false end
		fields[#fields + 1] = { src = u, sk = sk, mult = v / 100, t = sk.dur, tickT = 0 }
	elseif kind == "field" then
		if not target then return false end
		to[1] = target
		fields[#fields + 1] = { src = u, sk = sk, mult = v / 100, t = sk.dur, tickT = 0 }
	elseif kind == "debuff" then
		if not target then return false end
		local list = pickTargets(target, sk.targets or 1)
		for _, m in ipairs(list) do
			to[#to + 1] = m
			applyStatus(m, sk.status, nil, v, sk.dur, nil, u)
		end
	elseif kind == "heal" then
		-- one application: instant, or a heal over time keyed by the skill
		local function apply(t)
			if t.dead then return end
			to[#to + 1] = t
			if sk.hot then
				t.hots[sid] = { t = sk.hot, per = t.maxhp * v / 100, src = u }
				if sk.instant then heal(u, t, t.maxhp * (sk.instant[1] + sk.instant[2] * (lvl - 1)) / 100) end
			else
				heal(u, t, t.maxhp * v / 100)
			end
		end
		if sk.target == "self" then
			apply(u)
		elseif sk.target == "all" then
			for i = 1, #heroes do apply(heroes[i]) end
		else
			local list = {}
			for i = 1, #heroes do
				local t = heroes[i]
				if not t.dead and t.hp < t.maxhp then list[#list + 1] = t end
			end
			if #list == 0 then return false end
			table.sort(list, function(a, b) return a.hp / a.maxhp < b.hp / b.maxhp end)
			if list[1].hp / list[1].maxhp >= (sk.when and sk.when.ally or 1) then return false end
			for i = 1, min(sk.targets or 1, #list) do apply(list[i]) end
		end
	elseif kind == "shield" then
		local function shield(t)
			if not t.dead then
				to[#to + 1] = t
				-- the stronger shield stays, with its own time and caster
				local amount = t.maxhp * v / 100 * (1 + (u.s.heal or 0) / 100) * (u.s.healMult or 1)
				if amount >= t.shield then
					t.shield = amount
					t.shieldT = sk.dur
					t.shieldSrc = u
				end
			end
		end
		if sk.target == "all" then
			for i = 1, #heroes do shield(heroes[i]) end
		elseif sk.target == "self" then
			shield(u)
		elseif sk.target == "tank" then
			local t = frontHero()
			if not t or t.shield > 0 then return false end
			shield(t)
		else
			local t = lowestAlly(sk.when and sk.when.ally or 1)
			if not t then return false end
			shield(t)
		end
	elseif kind == "buff" then
		if not target and not sk.when then return false end
		local mods = {}
		for _, m in ipairs(sk.mods) do
			mods[#mods + 1] = { m[1], m[2] + m[3] * (lvl - 1) }
		end
		if sk.target == "party" then
			for i = 1, #heroes do
				local t = heroes[i]
				if not t.dead then
					t.buffs[#t.buffs + 1] = { mods = mods, t = sk.dur }
					to[#to + 1] = t
				end
			end
		elseif sk.target == "lowest" then
			local t = lowestAlly(sk.when and sk.when.ally or 1)
			if not t then return false end
			t.buffs[#t.buffs + 1] = { mods = mods, t = sk.dur }
			to[1] = t
		else
			u.buffs[#u.buffs + 1] = { mods = mods, t = sk.dur }
			to[1] = u
		end
		Combat.dirty = true
	elseif kind == "revive" then
		local t
		for i = 1, #heroes do
			if heroes[i].dead then t = heroes[i] break end
		end
		if not t then return false end
		to[1] = t
		revive(t, v / 100)
	else
		return false
	end
	fxSkill(u, sk.icon)
	vfx({ k = "skill", u = u, sid = sid, to = to })
	return true
end

------------------------------------------------------------------------
-- Heroes
------------------------------------------------------------------------
local function heroSpeed(u)
	return 240 * (1 + (u.s.move or 0) / 100)
end
-- falling back into formation goes this much faster than walking up
local BACK_PACE = 1.5
Combat.HeroSpeed, Combat.BACK_PACE = heroSpeed, BACK_PACE

local function stepHero(u)
	if u.flash > 0 then u.flash = u.flash - STEP end
	if u.anim > 0 then u.anim = u.anim - STEP end
	if (u.castT or 0) > 0 then u.castT = u.castT - STEP end
	if u.dead then
		u.reviveT = u.reviveT - STEP
		if u.reviveT <= EPS then revive(u, 0.4) end
		return
	end
	local s = u.s

	-- regeneration, heal over time, shields
	local regen = s.regen + u.maxhp * s.regenPct / 100
	if regen > 0 and u.hp < u.maxhp then
		u.hp = min(u.maxhp, u.hp + regen * STEP)
	end
	for key, hot in pairs(u.hots) do
		hot.t = hot.t - STEP
		heal(hot.src, u, hot.per * STEP, true)
		if hot.t <= EPS then u.hots[key] = nil end
	end
	if u.shield > 0 then
		u.shieldT = u.shieldT - STEP
		if u.shieldT <= EPS then u.shield = 0 end
	end
	if (u.ccImmune or 0) > 0 then u.ccImmune = u.ccImmune - STEP end

	-- buffs
	for i = #u.buffs, 1, -1 do
		local b = u.buffs[i]
		b.t = b.t - STEP
		if b.t <= EPS then
			table.remove(u.buffs, i)
			Combat.dirty = true
		end
	end

	-- ailments (as for monsters: gone before acting once they run out)
	for kind, e in pairs(u.st) do
		e.t = e.t - STEP
		if e.t < -EPS then
			u.st[kind] = nil
		elseif e.dps then
			damageHero(u, e.dps * STEP, e.school or "phys", nil, true)
			if u.dead then return end
		end
	end
	if isDisabled(u) then return end

	local target = nearestMob()
	local front = frontHero()
	local inRange = false
	if target then
		-- every hero reaches from where it stands
		inRange = target.x - u.x <= u.range
		-- the melee heroes behind whoever leads each walk up to their own
		-- spot behind it, spread out but all within reach; the others
		-- advance until they reach
		local follow = not u.ranged and front and front ~= u
		if follow or not inRange then
			local limit = target.x - (u.ranged and (u.range - 20) or 60)
			if follow then
				local lead = min(limit, front.x)
				local k, n = meleeRank(u, front)
				local room = max(0, lead - (target.x - u.range + 10))
				limit = lead - k * min(MELEE_GAP, room / max(1, n))
			end
			-- (a chill slows a hero's steps as it does a monster's)
			local chill = u.st.chill and (1 - u.st.chill.v / 100) or 1
			local step = heroSpeed(u) * chill * STEP
			if u.x < limit then
				u.x = min(limit, u.x + step)
			elseif follow and u.x > limit + 1 then
				u.x = max(limit, u.x - step) -- a step back to its spot
			end
		end
	end

	-- companions attack whatever is closest, wherever the hero stands;
	-- healing companions mend the most wounded ally instead
	for _, pet in pairs(u.pets) do
		pet.t = pet.t - STEP
		if pet.t <= EPS then
			pet.t = pet.sk.tick
			if pet.sk.heal then
				local t = lowestAlly(0.999)
				if t then
					heal(u, t, t.maxhp * pet.mult)
					pet.anim = 0.3
				end
			elseif target and not target.dead then
				heroHit(u, target, pet.mult, pet.sk.school)
				pet.anim = 0.3
			end
		end
		if pet.anim then pet.anim = max(0, pet.anim - STEP) end
	end

	-- cooldown skills (support skills work without an enemy in range)
	-- every cooldown runs down each step; then the first ready one is used
	-- (one cast a step)
	local castSpeed = 1 + s.cast / 100
	for _, sid in ipairs(u.skills) do
		if ns.SKILLS[sid].act == "cd" then u.cd[sid] = u.cd[sid] - STEP * castSpeed end
	end
	for _, sid in ipairs(u.skills) do
		local sk = ns.SKILLS[sid]
		if sk.act == "cd" and u.cd[sid] <= EPS then
			local t = inRange and target or nil
			if cast(u, sid, t) then
				u.cd[sid] = ns.SkillCooldown(sid, u.slv[sid]) * (1 - s.cdr / 100)
				break
			else
				u.cd[sid] = 0.3 -- try again shortly
			end
		end
	end
	if u.dead then return end

	-- basic attack
	local slow = u.st.chill and (1 - u.st.chill.v / 100) or 1
	u.atkT = u.atkT - STEP * slow
	-- (out of range a ready swing waits; it does not pile up)
	if not (target and inRange and not target.dead) and u.atkT < 0 then u.atkT, u.waited = 0, true end
	if u.atkT <= EPS and target and inRange and not target.dead then
		u.atkT = (u.waited and 0 or u.atkT) + 1 / s.aspd
		u.waited = nil
		if u.atkT < 0 then u.atkT = 0 end
		u.anim = 0.15
		if u.ranged then
			vfx({ k = "shot", u = u, to = { target }, x1 = u.x, x2 = target.x, school = u.school, gun = u.gun })
		end
		heroHit(u, target, 1, u.school)
		vfx({ k = "hit", x = target.x, school = u.school, mob = true })
		if s.hph > 0 then heal(nil, u, s.hph) end
		if s.multi > 0 and random() * 100 < s.multi and not target.dead then
			heroHit(u, target, 0.5, u.school)
		end
		for _, sid in ipairs(u.skills) do
			local sk = ns.SKILLS[sid]
			if sk.act == "count" then
				u.cnt[sid] = u.cnt[sid] + 1
				if u.cnt[sid] >= sk.n then
					local t = target
					if t.dead then t = nearestMob() end
					if t and cast(u, sid, t) then
						u.cnt[sid] = 0
					end
				end
			end
		end
	end
end

local function stepFields()
	for i = #fields, 1, -1 do
		local f = fields[i]
		f.t = f.t - STEP
		f.tickT = f.tickT - STEP
		local u = f.src
		if f.tickT <= EPS and not u.dead and f.sk.heal then
			f.tickT = f.sk.tick
			for k = 1, #heroes do
				heal(u, heroes[k], heroes[k].maxhp * f.mult, true)
			end
		elseif f.tickT <= EPS and not u.dead then
			f.tickT = f.sk.tick
			local first = nearestMob()
			if first then
				local list = pickTargets(first, f.sk.targets or 1)
				for _, m in ipairs(list) do
					local dealt, came = heroHit(u, m, f.mult, f.sk.school)
					if dealt > 0 and f.sk.status and random() < f.sk.status[2] then
						applyStatus(m, f.sk.status[1], came, nil, nil, nil, u)
					end
				end
			end
		end
		if f.t <= EPS or u.dead then table.remove(fields, i) end
	end
end

------------------------------------------------------------------------
-- Stage flow
------------------------------------------------------------------------
local function wipe(list)
	for i = #list, 1, -1 do list[i] = nil end
end

local function layoutParty()
	-- tank first, then melee, then ranged damage, healer last
	local order = {}
	for i = 1, #heroes do order[i] = heroes[i] end
	local function rank(u)
		if u.role == "TANK" then return 1 end
		if u.role == "HEALER" then return 4 end
		return u.ranged and 3 or 2
	end
	table.sort(order, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then return ra < rb end
		return a.slot < b.slot
	end)
	local x = FRONT_X
	local wasRanged = false
	for _, u in ipairs(order) do
		if u.ranged and not wasRanged and x < FRONT_X then
			x = x - 10
		end
		wasRanged = u.ranged
		u.homeX = x
		u.x = x
		x = x - (u.ranged and 72 or 78)
	end
end

function Combat.StartStage()
	local db = ns.db
	wipe(heroes)
	wipe(mobs)
	wipe(fields)
	ns.Heroes.ValidateParty()
	for slot = 1, ns.PARTY_SIZE do
		local id = db.party[slot]
		if id and db.heroes[id] then
			local c = ns.SPECS[db.heroes[id].spec]
			heroes[#heroes + 1] = {
				hero = true, id = id, slot = slot, role = c.role, class = c.class, spec = c.id, name = db.heroes[id].name,
				gun = c.mh[1] == "gun",
				ranged = c.ranged or false, range = c.range, school = c.school, x = 0, homeX = 0, atkT = 0.2 + random() * 0.4,
				buffs = {}, st = {}, hots = {}, pets = {}, skills = {}, slv = {},
				shield = 0, shieldT = 0, flash = 0, anim = 0, dead = false, reviveT = 0,
			}
		end
	end
	-- keep the finished stage's numbers around for the statistics display
	if next(Combat.meter) then Combat.lastMeter = Combat.meter end
	Combat.meter = {}
	for i = 1, #heroes do
		Combat.meter[heroes[i].id] = { dmg = 0, heal = 0, taken = 0, deaths = 0 }
	end
	if #heroes == 0 then
		st.phase = "idle"
		return
	end
	local tw = db.tower
	if tw.on and not ns.Tower.Open() then tw.on = false end
	if tw.on then
		-- a floor of the endless tower: a place, monsters and a boss rolled
		-- anew each time, the last stage's level, its affixes
		local f = U.clamp(tw.floor or 1, 1, ns.Tower.Top())
		tw.floor = f
		st.tower, st.affix = f, ns.Tower.Set(f)
		local roll = ns.Tower.Roll(f)
		st.diff, st.idx = roll.place[1], roll.place[2]
		st.mobStage, st.bossStage = roll.mobs, roll.boss
		st.level = ns.Tower.LEVEL
		st.might = ns.StageMight(#ns.DIFFS, ns.STAGE_COUNT)
		st.raid = ns.Tower.IsRaid(f)
		st.waves = ns.Tower.Waves(f)
	else
		st.tower, st.affix, st.mobStage, st.bossStage = nil, nil, nil, nil
		st.diff = db.stage.diff
		st.idx = db.stage.idx
		st.level = ns.StageLevel(st.diff, st.idx)
		st.might = ns.StageMight(st.diff, st.idx)
		st.raid = ns.Stage(st.diff, st.idx).raid or false
		st.waves = ns.StageWaves(st.diff, st.idx)
	end
	st.affT = {}
	st.wave = 0
	st.phase = "travel"
	st.timer = 0.8
	st.time = 0
	st.waveT = 0
	st.rage = 1
	st.gGold = 0
	st.gXP = 0
	st.result = nil
	recalcAll()
	for i = 1, #heroes do
		heroes[i].hp = heroes[i].maxhp
	end
	layoutParty()
	ns.Fire("STAGE")
end

local function travelTime()
	local total, n = 0, 0
	for i = 1, #heroes do
		if not heroes[i].dead then
			total = total + (heroes[i].s.move or 0)
			n = n + 1
		end
	end
	local avg = n > 0 and total / n or 0
	return max(0.4, 1.2 / (1 + avg / 100))
end

-- Income per real second (the offline reward and the map use it): the gold
-- and experience of kills over the real time spent fighting, whatever the
-- stages' results, folded into a running average weighted by time.
local earn = { g = 0, x = 0, t = 0 }
Combat.earn = earn
local stepReal = STEP -- real seconds per step at the current game speed

function Combat.FoldRate(minTime)
	local db = ns.db
	if not db or earn.t < (minTime or 5) then return end
	local g, x = earn.g / earn.t, earn.x / earn.t
	local rate = db.rate
	if (rate.gold or 0) <= 0 then
		rate.gold, rate.xp = g, x
	else
		local w = 1 - 0.7 ^ (earn.t / 60)
		rate.gold = rate.gold * (1 - w) + g * w
		rate.xp = (rate.xp or 0) * (1 - w) + x * w
	end
	rate.level = st.level or rate.level
	earn.g, earn.x, earn.t = 0, 0, 0
end

local function updateRate()
	Combat.FoldRate(5)
end

local function nextAfterVictory()
	local db = ns.db
	if not db.opt.auto then
		db.retry = 0
		return
	end
	if (db.retry or 0) > 0 then
		if not db.opt.retry then
			-- the option was turned off while farming: keep farming this stage
			db.retry = 0
			db.opt.auto = false
			ns.Fire("OPTIONS")
			return
		end
		-- farming after a failed push: count clears, then try again
		db.retry = db.retry - 1
		if db.retry > 0 then return end
	end
	if st.tower then
		db.tower.floor = st.tower + 1
		return
	end
	if db.stage.idx < ns.STAGE_COUNT then
		db.stage.idx = db.stage.idx + 1
	elseif db.stage.diff < #ns.DIFFS then
		db.stage.diff = db.stage.diff + 1
		db.stage.idx = 1
	end
end

local function victory()
	local db = ns.db
	st.phase = "result"
	st.result = "win"
	st.timer = 1.5
	db.stat.clears = db.stat.clears + 1
	updateRate()
	if not st.tower then
		-- what hunting this stage over and over pays a second (the pause
		-- before the next run counted): the offline reward goes by it
		local t = st.time + st.timer
		db.hunt[st.diff .. "-" .. st.idx] = { g = st.gGold / t, x = st.gXP / t }
	end
	if st.tower then
		-- the first clear of a floor: a new best, gold and one more chest
		local f, tw = st.tower, db.tower
		if f > (tw.best or 0) then
			tw.best = f
			local gold = ns.Tower.FirstGold(f)
			ns.AddGold(gold)
			local chest = st.raid and 3 or 2
			local got = ns.Loot.AddChest(chest, ns.Tower.ITEM_LEVEL, st.diff, ns.Tower.Box(chest), f)
			if not got then ns.Loot.Lost(chest, true) end
			ns.Toast(string.format("첫 공략! %s (+%s 골드, %s)", ns.Tower.Label(f), U.fmt(gold),
				got and "상자 1개" or "상자 보관함이 가득 차 상자를 받지 못함"))
			ns.Fire("PROGRESS")
		end
	elseif (db.prog[st.diff] or 0) < st.idx then
		db.prog[st.diff] = st.idx
		local bonus = floor(ns.MobGold(40, st.level))
		ns.AddGold(bonus)
		local tb = ns.TBH.STAGES[st.diff][st.idx]
		local chest = st.raid and 3 or 2
		local got = ns.Loot.AddChest(chest, st.level, st.diff, tb.bbox)
		if not got then ns.Loot.Lost(chest, true) end
		ns.Toast(string.format("첫 공략! %s (+%s 골드, %s)",
			ns.StageLabel(st.diff, st.idx), U.fmt(bonus), got and "궤짝 1개" or "궤짝 보관함이 가득 차 궤짝을 받지 못함"))
		if st.idx == ns.STAGE_COUNT and st.diff < #ns.DIFFS then
			ns.Toast(string.format("새 난이도 개방: %s", ns.N(ns.DIFFS[st.diff + 1].name)))
		end
		ns.Fire("PROGRESS")
	end
	ns.CheckPets()
	nextAfterVictory()
	ns.Fire("RESULT", "win")
end

local function defeat()
	local db = ns.db
	st.phase = "result"
	st.result = "lose"
	st.timer = 2.5
	db.stat.wipes = db.stat.wipes + 1
	updateRate()
	if st.tower then
		-- the tower: one floor down, that floor again (then, with the retry
		-- option, up again after eight clears)
		local label = ns.Tower.Label(st.tower)
		if st.tower > 1 then
			db.tower.floor = st.tower - 1
			if db.opt.retry and db.opt.auto then
				db.retry = 8
				ns.Toast(string.format("%s 실패. %d층에서 힘을 기릅니다.", label, st.tower - 1))
			else
				db.opt.auto = false
				ns.Toast(string.format("%s 실패. %d층을 반복합니다.", label, st.tower - 1))
			end
		else
			ns.Toast(string.format("%s 실패. 다시 도전합니다.", label))
		end
		ns.Fire("RESULT", "lose")
		return
	end
	local label = ns.StageLabel(st.diff, st.idx)
	if db.opt.retreat and (db.stage.idx > 1 or db.stage.diff > 1) then
		if db.stage.idx > 1 then
			db.stage.idx = db.stage.idx - 1
		else
			db.stage.diff = db.stage.diff - 1
			db.stage.idx = ns.STAGE_COUNT
		end
		if db.opt.retry and db.opt.auto then
			db.retry = 8
			ns.Toast(string.format("%s 공략 실패. 힘을 기른 뒤 다시 도전합니다.", label))
		else
			db.opt.auto = false
			ns.Toast(string.format("%s 공략 실패. 앞 스테이지를 반복합니다.", label))
		end
	else
		ns.Toast(string.format("%s 공략 실패. 다시 도전합니다.", label))
	end
	ns.Fire("RESULT", "lose")
end

-- Jump to any stage that is already unlocked.
function Combat.CanTravel(diff, idx)
	if diff < 1 or diff > #ns.DIFFS or idx < 1 or idx > ns.STAGE_COUNT then return false end
	local db = ns.db
	if diff > 1 and (db.prog[diff - 1] or 0) < ns.STAGE_COUNT then return false end
	return idx <= (db.prog[diff] or 0) + 1
end

function Combat.Travel(diff, idx)
	if not Combat.CanTravel(diff, idx) then
		return false, "아직 갈 수 없는 스테이지입니다."
	end
	ns.db.stage.diff = diff
	ns.db.stage.idx = idx
	ns.db.tower.on = false
	ns.db.retry = 0
	Combat.StartStage()
	return true
end

-- Go to a floor of the endless tower (up to one past the best cleared).
function Combat.EnterTower(f)
	if not ns.Tower.Open() then
		return false, string.format("%s의 30개 스테이지를 모두 깨면 열립니다.", ns.N(ns.DIFFS[#ns.DIFFS].world))
	end
	local top = ns.Tower.Top()
	f = math.floor(tonumber(f) or top)
	if f < 1 or f > top then
		return false, "아직 갈 수 없는 층입니다."
	end
	local tw = ns.db.tower
	tw.on, tw.floor = true, f
	ns.db.retry = 0
	Combat.StartStage()
	return true
end

------------------------------------------------------------------------
-- One fixed step
------------------------------------------------------------------------
function Combat.Step()
	if st.phase == "idle" then
		if ns.Heroes.PartyCount() > 0 then Combat.StartStage() end
		return
	end
	if Combat.dirty then recalcAll() end
	st.time = st.time + STEP
	earn.t = earn.t + stepReal
	if earn.t >= 60 then Combat.FoldRate(60) end

	if st.phase == "travel" then
		st.timer = st.timer - STEP
		for i = 1, #heroes do
			local u = heroes[i]
			stepHero(u)
			if not u.dead then
				-- fall back into formation
				local sp = heroSpeed(u) * BACK_PACE * STEP
				if u.x > u.homeX then u.x = max(u.homeX, u.x - sp) elseif u.x < u.homeX then u.x = min(u.homeX, u.x + sp) end
			end
		end
		if st.timer <= EPS then
			st.wave = st.wave + 1
			st.phase = "fight"
			spawnWave()
		end
		return
	end

	if st.phase == "fight" then
		st.waveT = st.waveT + STEP
		st.rage = 1 + max(0, (st.waveT - SOFT_ENRAGE) / 5) * 0.1
		for i = 1, #heroes do stepHero(heroes[i]) end
		for i = 1, #mobs do stepMob(mobs[i]) end
		stepFields()
		towerTick()
		for i = #mobs, 1, -1 do
			if mobs[i].dead and mobs[i].fade <= 0 then table.remove(mobs, i) end
		end
		if aliveHeroes() == 0 then
			defeat()
		elseif aliveMobs() == 0 then
			wipe(fields)
			if st.wave >= st.waves then
				victory()
			else
				st.phase = "travel"
				st.timer = travelTime()
			end
		end
		return
	end

	if st.phase == "result" then
		st.timer = st.timer - STEP
		for i = #mobs, 1, -1 do
			mobs[i].fade = (mobs[i].fade or 0) - STEP
			if mobs[i].dead and mobs[i].fade <= 0 then table.remove(mobs, i) end
		end
		if st.timer <= EPS then Combat.StartStage() end
	end
end

-- Called every frame with real elapsed seconds.
-- Fight time is not dropped after a long frame (a loading screen, the game
-- busy for a moment): at most PER_FRAME seconds of it run in one frame and
-- the rest waits for the next frames. Beyond BACKLOG seconds the rest goes
-- (a long absence is what the offline reward is for).
local acc = 0
local PER_FRAME, BACKLOG = 3, 120
Combat.PER_FRAME, Combat.BACKLOG = PER_FRAME, BACKLOG
function Combat.Update(elapsed)
	local speed = ns.GameSpeed()
	stepReal = STEP / speed
	acc = acc + elapsed * speed
	if acc > BACKLOG then acc = BACKLOG end
	local n = 0
	while acc >= STEP and n < PER_FRAME / STEP do
		acc = acc - STEP
		n = n + 1
		Combat.Step()
	end
end
function Combat.Backlog() return acc end

------------------------------------------------------------------------
-- React to changes made in the UI
------------------------------------------------------------------------
-- A change of party starts the stage over; the heroes who stay keep their
-- share of health, their revival time and their cooldowns.
ns.On("PARTY", function()
	if not ns.db then return end
	local keep = {}
	if st.phase == "travel" or st.phase == "fight" then
		for i = 1, #heroes do
			local u = heroes[i]
			local cd = {}
			for sid, t in pairs(u.cd or {}) do cd[sid] = t end
			keep[u.id] = { share = u.maxhp and u.maxhp > 0 and u.hp / u.maxhp or 1,
				dead = u.dead, reviveT = u.reviveT, cd = cd }
		end
	end
	Combat.StartStage()
	for i = 1, #heroes do
		local u, k = heroes[i], keep[heroes[i].id]
		if k then
			u.hp = u.maxhp * max(0, min(1, k.share))
			if k.dead then
				u.hp, u.dead, u.reviveT = 0, true, k.reviveT
			end
			for sid, t in pairs(k.cd) do
				if u.cd[sid] then u.cd[sid] = t end
			end
		end
	end
end)
ns.On("STATS", function() Combat.dirty = true end)
ns.On("SKILLS", function() Combat.dirty = true end)
ns.On("RESET", function()
	st.phase = "idle"
	earn.g, earn.x, earn.t = 0, 0, 0
	wipe(heroes)
	wipe(mobs)
	wipe(fields)
end)
