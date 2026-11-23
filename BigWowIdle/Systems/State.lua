-- Saved data: defaults, migration, repair of missing fields and the gold purse.
local _, ns = ...

local DB_VERSION = 4

-- skills that became other classic spells (version 4): old id -> new id
local OLD_SKILL = {
	arcane_barrage = "blast_wave", arcane_blast = "presence_of_mind", ardent_defender = "blessing_of_sanctuary",
	avengers_shield = "exorcism", avenging_wrath = "seal_of_the_crusader", berserk = "enrage",
	black_arrow = "wyvern_sting", bladestorm = "sweeping_strikes", bloodlust = "strength_of_earth",
	chaos_bolt = "soul_fire", commanding_shout = "defensive_stance", crusader_strike = "seal_of_command",
	divine_storm = "holy_wrath", earth_shield = "stoneskin_totem", envenom = "instant_poison",
	explosive_shot = "immolation_trap", felguard = "summon_felhunter", feral_spirit = "searing_totem",
	hand_of_guldan = "death_coil", haunt = "siphon_life", hunters_pet = "call_pet", ice_lance = "cone_of_cold",
	incinerate = "searing_pain", kill_command = "intimidation", killing_spree = "riposte",
	lava_burst = "flame_shock", lava_lash = "flametongue_weapon", lock_and_load = "aspect_of_the_hawk",
	metamorphosis = "demonic_sacrifice", moonkin_aura = "moonkin_form", mutilate = "ghostly_strike",
	pack_leader = "aspect_of_the_wild", pain_suppression = "power_infusion", penance = "flash_heal",
	pw_barrier = "prayer_of_fortitude", raging_blow = "heroic_strike", rampage = "overpower",
	riptide = "lesser_healing_wave", seed_of_corruption = "hellfire", shadow_blades = "slice_and_dice",
	shadow_dance = "vanish", shadowfiend = "shadowguard", shield_of_righteous = "holy_shield",
	stampede = "screech", starfall = "insect_swarm", summon_infernal = "inferno",
	totem_of_wrath = "flametongue_totem", unstable_affliction = "curse_of_agony", vendetta = "expose_armor",
	water_elemental = "ice_armor", wild_growth = "regrowth", word_of_glory = "flash_of_light",
}

-- a hero's learned and equipped skills under their new ids
local function renameSkills(h)
	local sk = {}
	for id, lv in pairs(h.sk or {}) do sk[OLD_SKILL[id] or id] = lv end
	h.sk = sk
	for i, id in ipairs(h.skills or {}) do h.skills[i] = OLD_SKILL[id] or id end
end

-- weapon types that were dropped, and what their items became
local OLD_WTYPE = { gun = "bow", gadget = "orb" }

local function fill(t, defaults)
	for k, v in pairs(defaults) do
		if t[k] == nil then
			t[k] = ns.U.copy(v)
		elseif type(v) == "table" and type(t[k]) == "table" then
			-- only recurse into plain option tables, never into arrays of game data
			if next(v) ~= nil and #v == 0 then
				fill(t[k], v)
			end
		end
	end
end

local DEFAULTS = {
	gold = 0,
	-- faction = "ALLIANCE" | "HORDE", chosen on first start (nil until then)
	heroes = {},                 -- [heroId] = { id, spec, sex, name, level, xp, tree = {}, sk = {}, skills = {}, gear = {} }
	heroSeq = 0,
	party = { false, false, false, false, false },
	bag = {},                    -- array of item tables
	bank = {},
	mats = {},                   -- [matId] = count
	chests = {},                 -- array of { t = chestType, l = level, d = difficulty }
	runes = {},                  -- [runeId] = level
	forge = { level = 1, xp = 0, ops = { fuse = true }, craft = { true } },
	stage = { diff = 1, idx = 1 },
	prog = { 0, 0, 0, 0 },       -- stages cleared per difficulty
	kills = {},                  -- [monsterType] = count
	pets = {},                   -- [petId] = true
	opt = { auto = true, retreat = true, retry = true, druidForm = true },
	ui = { scale = 1, locked = false, shown = true, sound = true },
	stat = { kills = 0, gold = 0, clears = 0, wipes = 0, time = 0, chests = 0 },
	rate = { gold = 0, xp = 0 }, -- smoothed income per second, used for offline rewards
	autoT = { 0, 0, 0 },         -- auto-open timers per chest type
	retry = 0,                   -- clears since the last failed push
}

-- Version 1 kept one hero per class, keyed by class. Each becomes a hero of
-- the specialization that played the same role, keeps its level and gear, and
-- gets its talent points back (the trees are different now).
local V1_SPEC = {
	WARRIOR = "WARRIOR_PROT", DRUID = "DRUID_GUARDIAN", HUNTER = "HUNTER_MM", MAGE = "MAGE_FIRE", ROGUE = "ROGUE_OUTLAW",
	WARLOCK = "WARLOCK_DESTRO", SHAMAN = "SHAMAN_ELE", PRIEST = "PRIEST_HOLY", PALADIN = "PALADIN_HOLY",
}

-- Version 2 kept skills inside the talent tree (nodes 3 and 4 of tier 1, node
-- 3 of tiers 2-5). They move to the hero's own skill ranks; points beyond what
-- the new skill-point budget allows are taken back from the highest ranks.
local V2_SKILL_NODE = { [13] = 1, [14] = 2, [23] = 3, [33] = 4, [43] = 5, [53] = 6 }

local function migrateV2Hero(h)
	local sp = ns.SPECS[h.spec]
	h.sk = h.sk or {}
	for key, i in pairs(V2_SKILL_NODE) do
		local pts = h.tree[key]
		if pts then
			if type(pts) == "number" and pts > 0 and sp.skills[i] then h.sk[sp.skills[i]] = math.min(ns.SKILL_MAX, pts) end
			h.tree[key] = nil
		end
	end
end

local function clampHero(h)
	local sp = ns.SPECS[h.spec]
	-- talent nodes that no longer exist, or more talent points than levels
	local spent = 0
	for key, v in pairs(h.tree) do
		local t, n = math.floor(key / 10), key % 10
		if not (sp.tree[t] and sp.tree[t][n]) or type(v) ~= "number" or v <= 0 then
			h.tree[key] = nil
		else
			h.tree[key] = math.min(v, sp.tree[t][n].max)
			spent = spent + h.tree[key]
		end
	end
	if spent > h.level then h.tree = {} end
	-- skills of another specialization, skills above the hero's level
	local own = {}
	for i, sid in ipairs(sp.skills) do own[sid] = i end
	for sid, v in pairs(h.sk) do
		if not own[sid] or type(v) ~= "number" or v <= 0 or h.level < ns.SKILL_UNLOCK[own[sid]] then h.sk[sid] = nil end
	end
	h.sk[sp.skills[1]] = math.max(1, h.sk[sp.skills[1]] or 0)
	local budget = 1 + math.floor(h.level / 4)
	local function total()
		local n = 0
		for _, v in pairs(h.sk) do n = n + v end
		return n
	end
	for i = #sp.skills, 1, -1 do -- lower ranks first, latest skills first
		local sid = sp.skills[i]
		while total() > budget and (h.sk[sid] or 0) > 1 do h.sk[sid] = h.sk[sid] - 1 end
	end
	for i = #sp.skills, 2, -1 do -- then forget the latest skills
		if total() > budget then h.sk[sp.skills[i]] = nil end
	end
	local eq = {}
	for _, sid in ipairs(h.skills) do
		if h.sk[sid] and #eq < 3 then eq[#eq + 1] = sid end
	end
	h.skills = eq
end

local function migrateV1(db)
	local old = db.heroes or {}
	local oldParty = db.party or {}
	db.heroes = {}
	db.heroSeq = 0
	local newId = {}
	for _, classId in ipairs({ "WARRIOR", "DRUID", "HUNTER", "MAGE", "ROGUE", "WARLOCK", "SHAMAN", "PRIEST", "PALADIN" }) do
		local o = old[classId]
		local specId = V1_SPEC[classId]
		if type(o) == "table" and ns.SPECS[specId] then
			local sp = ns.SPECS[specId]
			db.heroSeq = db.heroSeq + 1
			local id = "h" .. db.heroSeq
			local h = {
				id = id, spec = specId, level = o.level or 1, xp = o.xp or 0,
				tree = {}, sk = { [sp.skills[1]] = 1 }, skills = { sp.skills[1] }, gear = type(o.gear) == "table" and o.gear or {},
			}
			-- gear the new specialization cannot wield goes back to the bag
			for _, slot in ipairs({ "mh", "oh" }) do
				local it = h.gear[slot]
				if it and not ns.U.contains(sp[slot], it.t) then
					h.gear[slot] = nil
					db.bag = db.bag or {}
					db.bag[#db.bag + 1] = it
				end
			end
			db.heroes[id] = h
			newId[classId] = id
		end
	end
	db.party = { false, false, false, false, false }
	for i = 1, 5 do
		local id = newId[oldParty[i]]
		if id then db.party[i] = id end
	end
	db.ui = db.ui or {}
	db.ui.barPos, db.ui.mainPos, db.ui.tab = nil, nil, nil -- the windows changed shape
end

function ns.InitDB()
	if type(BigWowIdleDB) ~= "table" then
		-- a save from before the add-on was renamed (BigWowHeroes, before that
		-- BigIdleWoWHeroes): its file copied to SavedVariables/BigWowIdle.lua
		-- still loads under the old variable name
		if type(BigWowHeroesDB) == "table" then
			BigWowIdleDB = BigWowHeroesDB
		elseif type(BigIdleWoWHeroesDB) == "table" then
			BigWowIdleDB = BigIdleWoWHeroesDB
		else
			BigWowIdleDB = {}
		end
	end
	BigWowHeroesDB, BigIdleWoWHeroesDB = nil, nil
	local db = BigWowIdleDB
	local from = db.v or DB_VERSION
	if from < 2 and type(db.heroes) == "table" then
		migrateV1(db)
	end
	fill(db, DEFAULTS)
	db.v = DB_VERSION
	for i = 1, ns.PARTY_SIZE do
		if db.party[i] == nil then db.party[i] = false end
	end
	for i = 1, #ns.DIFFS do
		db.prog[i] = db.prog[i] or 0
	end
	for i = 1, #ns.CHEST do
		db.autoT[i] = db.autoT[i] or 0
	end
	-- weapon types that no longer exist become the nearest kept one
	local function retype(it)
		if type(it) == "table" and it.t and not ns.WTYPE[it.t] then
			it.t = OLD_WTYPE[it.t] or (it.s == "oh" and "orb" or "sword")
		end
	end
	for _, list in ipairs({ db.bag, db.bank }) do
		for _, it in ipairs(list) do retype(it) end
	end
	for _, h in pairs(db.heroes) do
		if type(h) == "table" and type(h.gear) == "table" then
			for _, it in pairs(h.gear) do retype(it) end
		end
	end
	-- drop references to data that no longer exists; a dropped hero's gear
	-- is kept (put in the bag below)
	local orphans = {}
	for id, h in pairs(db.heroes) do
		if type(h) ~= "table" or not ns.SPECS[h.spec] then
			if type(h) == "table" and type(h.gear) == "table" then
				for _, it in pairs(h.gear) do
					if type(it) == "table" then orphans[#orphans + 1] = it end
				end
			end
			db.heroes[id] = nil
		else
			h.id = id
			h.level = h.level or 1
			h.xp = h.xp or 0
			h.tree = h.tree or {}
			h.skills = h.skills or {}
			h.gear = h.gear or {}
			if from < 3 then migrateV2Hero(h) end
			if from < 4 then renameSkills(h) end
			h.sk = h.sk or {}
			clampHero(h)
			if h.sex ~= "M" and h.sex ~= "F" then h.sex = math.random() < 0.5 and "M" or "F" end
			if type(h.name) == "table" then h.name = h.name[1] end -- version 2.0 kept two spellings
			if type(h.name) ~= "string" or h.name == "" then
				h.name = nil -- named below, once every other name is known
			elseif not h.name:find(" ") then -- before 2.1 heroes had no family name
				local race = ns.RACES[ns.ClassRace(ns.SPECS[h.spec].class, db.faction)]
				h.name = h.name .. " " .. ns.Names.Family(ns.NAME_POOLS[race.names])
			end
			local n = tonumber(tostring(id):sub(2)) or 0
			if n > db.heroSeq then db.heroSeq = n end
		end
	end
	if db.faction ~= "ALLIANCE" and db.faction ~= "HORDE" then db.faction = nil end
	ns.db = db
	for _, h in pairs(db.heroes) do
		if not h.name then h.name = ns.Heroes.RollName(h.spec, h.sex) end
	end
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id and not db.heroes[id] then db.party[i] = false end
	end
	for id in pairs(db.mats) do
		if not ns.MATS[id] then db.mats[id] = nil end
	end
	db.stage.diff = ns.U.clamp(db.stage.diff or 1, 1, #ns.DIFFS)
	db.stage.idx = ns.U.clamp(db.stage.idx or 1, 1, ns.STAGE_COUNT)
	ns.db = db
	-- gear of dropped heroes: the bag, the bank once the bag is full (the bag
	-- past its size when both are)
	if #orphans > 0 and ns.Runes then ns.Runes.Invalidate() end
	for _, it in ipairs(orphans) do
		local to = (#db.bag >= ns.BagSize() and #db.bank < ns.BankSize()) and db.bank or db.bag
		to[#to + 1] = it
	end
	return db
end

function ns.ResetDB()
	local ui = ns.db and ns.db.ui
	BigWowIdleDB = {}
	local db = ns.InitDB()
	if ui then db.ui = ui end -- keeps window settings; the faction is chosen again
	ns.Fire("RESET")
end

------------------------------------------------------------------------
-- Gold
------------------------------------------------------------------------
function ns.AddGold(n)
	if n <= 0 then return end
	local db = ns.db
	db.gold = db.gold + n
	db.stat.gold = db.stat.gold + n
	ns.Fire("GOLD")
end

function ns.CanAfford(n)
	return ns.db.gold >= n
end

function ns.SpendGold(n)
	local db = ns.db
	if db.gold < n then return false end
	db.gold = db.gold - n
	ns.Fire("GOLD")
	return true
end

------------------------------------------------------------------------
-- Materials
------------------------------------------------------------------------
function ns.MatCount(id)
	return ns.db.mats[id] or 0
end

function ns.AddMat(id, n)
	local m = ns.db.mats
	m[id] = (m[id] or 0) + n
	if m[id] <= 0 then m[id] = nil end
	ns.Fire("MATS")
end
