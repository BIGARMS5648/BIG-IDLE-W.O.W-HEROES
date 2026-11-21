-- Specialization benchmark and tuner.
--
-- Damage dealers: every damage specialization joins the same fixed partners
-- (same level, gear rolled from the same random sequence) against monsters
-- that hit for nothing and have a thousand times their health, once alone
-- (single target) and once in a pack of three. That measures pure damage
-- throughput, including what party buffs add to the partners; on normal
-- stages the time monsters spend walking in would decide the result instead.
-- Tanks and healers: measured with real monster damage on a stage a few levels
-- above the party, where their survival decides how much the party gets done.
--
-- One multiplier per specialization (attack for damage dealers, health for
-- tanks, healing for healers) is adjusted until everyone in a role lands in a
-- narrow band. The result is printed as ns.SPEC_TUNE for Data/Classes.lua.
--
--   python3 tests/run.py bench [passes]
local ns = NS
local passes = ... or 3
local Bot = dofile(debug.getinfo(1, "S").source:sub(2):gsub("bench%.lua$", "bot.lua"))
local C = ns.Combat

local PARTNERS = { TANK = "WARRIOR_PROT", HEALER = "PRIEST_HOLY", DPS = { "MAGE_FIRE", "ROGUE_OUTLAW", "HUNTER_MM" } }
-- { hero level, skill slots, gear quality, stage level offset for dps, for tank/healer }
local POINTS = { { 15, 1, 4, 8, 5 }, { 40, 2, 5, 8, 6 }, { 75, 3, 5, 8, 6 } }
local TUNE_KEY = { DPS = "atk", TANK = "hp", HEALER = "heal" }
local GAIN = { TANK = 1.6, HEALER = 1.8 } -- damage dealers use their measured share of party damage
local realMobAtk, realMobHP = ns.MobAtk, ns.MobHP
-- fixed fights for damage dealers: { difficulty, stage } without resistances
local DUMMY = { single = { 1, 1 }, pack = { 2, 11 } }

local realAddXP = ns.Heroes.AddXP

local function stageFor(level)
	local best, bd, bi = 1e9, 1, 1
	for d = 1, #ns.DIFFS do
		for i = 1, ns.STAGE_COUNT do
			if not ns.STAGES[d][i].raid then
				local gap = math.abs(ns.StageLevel(d, i) - level)
				if gap < best then best, bd, bi = gap, d, i end
			end
		end
	end
	return bd, bi
end

local function fresh()
	BigWowHeroesDB = nil
	ns.InitDB()
	local db = ns.db
	db.gold = 1e13
	for _, id in ipairs({ "root", "c1", "c2", "c3", "c6", "c4", "c5", "c7", "c8", "c9" }) do ns.Runes.Buy(id) end
	db.opt.auto, db.opt.retreat = false, false
	db.prog = { 30, 30, 30, 30 }
	ns.Heroes.AddXP = function() return 0 end -- levels stay fixed during a run
	return db
end

local function makeHero(specId, level, quality)
	local h = ns.Heroes.NewRecord(specId)
	h.level = level
	local sp = ns.SPECS[specId]
	-- the same random sequence for everyone, so gear luck does not decide the result
	math.randomseed(7000 + level)
	for _, slot in ipairs(ns.SLOTS) do
		local best, bestP
		for _ = 1, 4 do
			local wtype
			if slot == "mh" then wtype = sp.mh[1] elseif slot == "oh" then wtype = sp.oh[1] end
			local it = ns.Items.New(slot, level, quality, wtype)
			h.gear[slot] = it
			ns.Stats.Invalidate(h.id)
			local p = ns.Stats.Power(h.id)
			if not bestP or p > bestP then best, bestP = it, p end
		end
		h.gear[slot] = best
	end
	ns.Stats.Invalidate(h.id)
	Bot.SpendPoints(h.id)
	h.skills = {}
	return h
end

-- party: 5 spec ids in slot order; loadouts[slot] = list of skill ids
local function run(party, loadouts, level, quality, stageLevel, seconds, seed, dummy)
	local db = fresh()
	if dummy then
		ns.MobAtk = function() return 0 end
		ns.MobHP = function(b, l) return realMobHP(b, l) * 1000 end
	else
		ns.MobAtk, ns.MobHP = realMobAtk, realMobHP
	end
	local ids = {}
	for slot = 1, 5 do
		local h = makeHero(party[slot], level, quality)
		h.skills = loadouts[slot]
		db.party[slot] = h.id
		ids[slot] = h.id
	end
	if dummy then
		db.stage.diff, db.stage.idx = DUMMY[dummy][1], DUMMY[dummy][2]
	else
		db.stage.diff, db.stage.idx = stageFor(stageLevel)
	end
	math.randomseed(seed)
	C.sum = {}
	for slot = 1, 5 do C.sum[ids[slot]] = { dmg = 0, heal = 0, taken = 0, deaths = 0 } end
	C.StartStage()
	for _ = 1, seconds * 10 do C.Step() end
	local total, deaths = 0, 0
	for slot = 1, 5 do
		total = total + C.sum[ids[slot]].dmg
		deaths = deaths + C.sum[ids[slot]].deaths
	end
	local r = { party = total / seconds, deaths = deaths, by = {} }
	for slot = 1, 5 do r.by[slot] = C.sum[ids[slot]] end
	C.sum = {}
	ns.MobAtk, ns.MobHP = realMobAtk, realMobHP
	return r
end

-- default loadout: the first skills the bot would have slotted
local function defaultLoadout(specId, slots)
	local out = {}
	for i = 1, slots do out[i] = ns.SPECS[specId].skills[i] end
	return out
end

local function combos(list, k)
	local out = {}
	local function rec(start, cur)
		if #cur == k then
			local c = {}
			for i = 1, k do c[i] = cur[i] end
			out[#out + 1] = c
			return
		end
		for i = start, #list do
			cur[#cur + 1] = list[i]
			rec(i + 1, cur)
			cur[#cur] = nil
		end
	end
	rec(1, {})
	return out
end

local function partyFor(specId)
	local role = ns.SPECS[specId].role
	local party = { PARTNERS.TANK, PARTNERS.DPS[1], PARTNERS.DPS[2], PARTNERS.DPS[3], PARTNERS.HEALER }
	local slot
	if role == "TANK" then slot = 1 elseif role == "HEALER" then slot = 5 else slot = 2 end
	party[slot] = specId
	return party, slot
end

local bestLoadout = {} -- [specId][pointIndex] = skills

local function evaluate(specId, pi, search)
	local pt = POINTS[pi]
	local level, slots, quality = pt[1], pt[2], pt[3]
	local sp = ns.SPECS[specId]
	local stageLevel = level + (sp.role == "DPS" and pt[4] or pt[5])
	local party, slot = partyFor(specId)
	local loadouts = {}
	for i = 1, 5 do loadouts[i] = defaultLoadout(party[i], slots) end
	bestLoadout[specId] = bestLoadout[specId] or {}
	if search and not bestLoadout[specId][pi] then
		local best, bestScore
		for _, combo in ipairs(combos(sp.skills, slots)) do
			loadouts[slot] = combo
			local r
			if sp.role == "DPS" then
				local a = run(party, loadouts, level, quality, stageLevel, 120, 99, "single")
				local b = run(party, loadouts, level, quality, stageLevel, 120, 99, "pack")
				r = { party = math.sqrt(a.party * b.party) }
			else
				r = run(party, loadouts, level, quality, stageLevel, 240, 99)
			end
			if not bestScore or r.party > bestScore then best, bestScore = combo, r.party end
		end
		bestLoadout[specId][pi] = best
	end
	loadouts[slot] = bestLoadout[specId][pi] or defaultLoadout(specId, slots)
	-- two seeds, averaged
	if sp.role == "DPS" then
		-- geometric mean of the single-target and the pack fight
		local a = run(party, loadouts, level, quality, stageLevel, 300, 11, "single")
		local b = run(party, loadouts, level, quality, stageLevel, 300, 23, "pack")
		local partyDps = math.sqrt(a.party * b.party)
		local own = (a.by[slot].dmg / a.party + b.by[slot].dmg / b.party) / 600
		return partyDps, a.deaths + b.deaths, own
	end
	local a = run(party, loadouts, level, quality, stageLevel, 600, 11)
	local b = run(party, loadouts, level, quality, stageLevel, 600, 23)
	return (a.party + b.party) / 2, a.deaths + b.deaths, 0.25
end

local function median(t)
	local s = {}
	for _, v in ipairs(t) do s[#s + 1] = v end
	table.sort(s)
	local n = #s
	if n % 2 == 1 then return s[(n + 1) / 2] end
	return (s[n / 2] + s[n / 2 + 1]) / 2
end

local roles = { DPS = {}, TANK = {}, HEALER = {} }
for _, sid in ipairs(ns.SPEC_ORDER) do
	local r = roles[ns.SPECS[sid].role]
	r[#r + 1] = sid
end

for pass = 1, passes do
	print(string.format("  pass %d", pass))
	local worst = 0
	for _, role in ipairs({ "DPS", "TANK", "HEALER" }) do
		local list = roles[role]
		local score = {}   -- [specId] = geometric mean of (party dps / median) over the points
		local share = {}   -- [specId] = average share of party damage dealt by the spec itself
		local rows = {}
		for _, sid in ipairs(list) do score[sid] = 1 share[sid] = 0 rows[sid] = {} end
		for pi = 1, #POINTS do
			local vals, raw = {}, {}
			for _, sid in ipairs(list) do
				local party, deaths, ownShare = evaluate(sid, pi, pass == 1)
				raw[sid] = { party, deaths }
				share[sid] = share[sid] + ownShare / #POINTS
				vals[#vals + 1] = party
			end
			local med = median(vals)
			for _, sid in ipairs(list) do
				local rel = raw[sid][1] / med
				score[sid] = score[sid] * rel
				rows[sid][pi] = string.format("L%d %5.2f d%-2d", POINTS[pi][1], rel, raw[sid][2])
			end
		end
		for _, sid in ipairs(list) do
			local s = score[sid] ^ (1 / #POINTS)
			local key = TUNE_KEY[role]
			ns.SPEC_TUNE[sid] = ns.SPEC_TUNE[sid] or {}
			local cur = ns.SPEC_TUNE[sid][key] or 1
			-- a damage dealer's own share of party damage is how strongly its
			-- attack moves the party total, so the step is 1 / share
			local gain = GAIN[role] or (1 / math.max(0.12, share[sid]))
			local step = math.max(0.75, math.min(1.33, (1 / s) ^ gain))
			local nextv = math.max(0.5, math.min(2.0, cur * step))
			print(string.format("    %-7s %-16s %s | score %.3f | %s %.3f -> %.3f", role, sid, table.concat(rows[sid], "  "), s, key, cur, nextv))
			ns.SPEC_TUNE[sid][key] = nextv
			worst = math.max(worst, math.abs(s - 1))
		end
	end
	print(string.format("  largest gap from the median this pass: %.1f%%", worst * 100))
end

ns.Heroes.AddXP = realAddXP
ns.MobAtk, ns.MobHP = realMobAtk, realMobHP

print("ns.SPEC_TUNE = {")
for _, sid in ipairs(ns.SPEC_ORDER) do
	local key = TUNE_KEY[ns.SPECS[sid].role]
	print(string.format("\t%s = { %s = %.2f },", sid, key, ns.SPEC_TUNE[sid][key]))
end
print("}")
print("-- best loadouts found (level " .. POINTS[#POINTS][1] .. ")")
for _, sid in ipairs(ns.SPEC_ORDER) do
	local l = bestLoadout[sid] and bestLoadout[sid][#POINTS]
	if l then print("--   " .. sid .. ": " .. table.concat(l, ", ")) end
end
return true
