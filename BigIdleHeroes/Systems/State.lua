-- Saved data: defaults, migration, repair of missing fields and the gold purse.
local _, ns = ...

local DB_VERSION = 7

-- the runes before version 7: id = { top level, gold of level 1, growth per level }
local OLD_RUNE = {
	root = { 1, 50, 1 },
	w1 = { 5, 100, 1.6 }, w2 = { 5, 300, 1.7 }, w3 = { 5, 800, 1.7 }, w4 = { 5, 3000, 1.8 }, w5 = { 5, 10000, 1.8 },
	w6 = { 5, 30000, 1.8 }, w7 = { 10, 100000, 1.7 }, w8 = { 10, 400000, 1.7 }, w9 = { 10, 10000000, 1.6 },
	g1 = { 5, 100, 1.6 }, g2 = { 5, 300, 1.7 }, g3 = { 5, 800, 1.7 }, g4 = { 5, 3000, 1.8 }, g5 = { 5, 10000, 1.8 },
	g6 = { 5, 30000, 1.8 }, g7 = { 10, 100000, 1.7 }, g8 = { 10, 400000, 1.7 }, g9 = { 10, 10000000, 1.6 },
	m1 = { 5, 80, 1.6 }, m2 = { 3, 250, 1.7 }, m3 = { 5, 700, 1.7 }, m4 = { 5, 2500, 1.8 }, m5 = { 5, 8000, 1.8 },
	m6 = { 5, 25000, 1.8 }, m7 = { 10, 90000, 1.7 }, m8 = { 10, 350000, 1.7 }, m9 = { 10, 9000000, 1.6 },
	x1 = { 5, 80, 1.6 }, x2 = { 3, 300, 1.7 }, x3 = { 5, 700, 1.7 }, x4 = { 5, 2500, 1.8 }, x5 = { 5, 8000, 1.8 },
	x6 = { 5, 25000, 1.8 }, x7 = { 10, 90000, 1.7 }, x8 = { 4, 200000, 2.0 }, x9 = { 10, 9000000, 1.6 },
	e1 = { 5, 120, 1.6 }, e2 = { 3, 350, 1.7 }, e3 = { 1, 2000, 1.7 }, e4 = { 5, 4000, 1.8 }, e5 = { 5, 10000, 1.8 },
	e6 = { 5, 30000, 1.8 }, e7 = { 5, 60000, 1.7 }, e8 = { 10, 250000, 1.7 }, e9 = { 10, 8000000, 1.6 },
	c1 = { 1, 300, 1.7 }, c2 = { 5, 150, 1.6 }, c3 = { 1, 5000, 1.7 }, c4 = { 1, 20000, 1.7 }, c5 = { 1, 40000, 1.7 },
	c6 = { 5, 8000, 1.8 }, c7 = { 1, 150000, 1.7 }, c8 = { 5, 60000, 1.7 }, c9 = { 1, 400000, 1.7 }, c10 = { 5, 800000, 2.0 },
}

-- The gold the runes of a save before version 7 cost (their prices then);
-- those runes are taken back. Returns the gold.
local function refundOldRunes(db)
	if type(db.runes) ~= "table" then return 0 end
	local gold = 0
	for id, lvl in pairs(db.runes) do
		local old = OLD_RUNE[id]
		lvl = math.floor(tonumber(lvl) or 0)
		if old then
			for l = 1, math.min(lvl, old[1]) do
				local c = old[2] * old[3] ^ (l - 1)
				if c >= 1000 then c = math.floor(c / 100 + 0.5) * 100 else c = math.floor(c / 10 + 0.5) * 10 end
				gold = gold + c
			end
		end
	end
	db.runes = {}
	return gold
end

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
		-- a missing value, or a damaged one of the wrong kind (a number or a
		-- table where one belongs), takes the default
		if t[k] == nil or ((type(v) == "table" or type(v) == "number") and type(t[k]) ~= type(v)) then
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
	tower = { on = false, floor = 1, best = 0 }, -- the endless tower: fighting there, the floor, the best cleared
	prog = { 0, 0, 0, 0 },       -- stages cleared per difficulty
	kills = {},                  -- [monsterType] = count
	pets = {},                   -- [petId] = true
	opt = { auto = true, retreat = true, retry = true, druidForm = true, scenery = true, keepBench = false },
	ui = { scale = 1, locked = false, shown = true, sound = true },
	stat = { kills = 0, gold = 0, clears = 0, wipes = 0, time = 0, chests = 0 },
	rate = { gold = 0, xp = 0 }, -- smoothed income per second (the stage screen's recent income)
	hunt = {},                   -- ["diff-idx"] = { g =, x = }: kill gold and experience per second of the stage's last clear (offline rewards)
	autoT = { 0, 0, 0 },         -- auto-open timers per chest type
	autoStop = {},               -- [chest type] = true: its auto-open stopped by hand
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
		local t, n
		if type(key) == "number" then t, n = math.floor(key / 10), key % 10 end
		if not (t and sp.tree[t] and sp.tree[t][n]) or type(v) ~= "number" or v <= 0 then
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
		if not own[sid] or type(v) ~= "number" or v <= 0 or h.level < ns.SKILL_UNLOCK[own[sid]] then
			h.sk[sid] = nil
		else
			h.sk[sid] = math.min(math.floor(v), ns.SKILL_MAX) -- learned ranks stop at the skill's top
		end
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
		-- BigIdleWoWHeroes): its file copied to SavedVariables/BigIdleHeroes.lua
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
	local from = tonumber(db.v)
	if not from then
		-- no version number: the first saves kept one hero per class, keyed
		-- by the class; anything else is taken as current
		from = DB_VERSION
		if type(db.heroes) == "table" then
			for _, classId in ipairs({ "WARRIOR", "DRUID", "HUNTER", "MAGE", "ROGUE", "WARLOCK", "SHAMAN", "PRIEST", "PALADIN" }) do
				if type(db.heroes[classId]) == "table" then from = 1 break end
			end
		end
	end
	if from < 2 and type(db.heroes) == "table" then
		migrateV1(db)
	end
	local refund = from < 7 and refundOldRunes(db) or 0
	fill(db, DEFAULTS)
	if refund > 0 then
		db.gold = (tonumber(db.gold) or 0) + refund
	end
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
	db.autoStop = db.autoStop or {}
	-- weapon types that no longer exist become the nearest kept one
	local function retype(it)
		if type(it) == "table" and it.t and not ns.WTYPE[it.t] then
			it.t = OLD_WTYPE[it.t] or (it.s == "oh" and "orb" or "sword")
		end
	end
	for _, list in ipairs({ db.bag, db.bank }) do
		for _, it in ipairs(list) do retype(it) end
	end
	-- version 5: gear comes in TBH's item levels and is worn from its own
	-- level; an older piece takes the item level at or below the level it
	-- was worn from (so it stays wearable by whoever wears it)
	if from < 5 then
		local function snap(it)
			if type(it) == "table" and type(it.l) == "number" then
				local was = it.l
				it.l = ns.Items.SnapLevel(math.max(1, it.l - 2))
				ns.Items.FitAffixes(it, was)
			end
		end
		for _, list in ipairs({ db.bag, db.bank }) do
			for _, it in ipairs(list) do snap(it) end
		end
		for _, h in pairs(db.heroes) do
			if type(h) == "table" and type(h.gear) == "table" then
				for _, it in pairs(h.gear) do snap(it) end
			end
		end
	end
	if from < 6 and type(db.mats) == "table" then
		-- socket materials by tier become TBH's materials of that grade,
		-- shared out over the grade's kinds
		for _, kind in ipairs({ "gem", "dust", "scroll" }) do
			for tier = 1, 6 do
				local n = tonumber(db.mats[kind .. tier]) or 0
				db.mats[kind .. tier] = nil
				local list = ns.SOCKET_MATS_BY[kind][tier]
				for i = 1, n do
					local id = list[(i - 1) % #list + 1]
					db.mats[id] = (db.mats[id] or 0) + 1
				end
			end
		end
	end
	for _, h in pairs(db.heroes) do
		if type(h) == "table" and type(h.gear) == "table" then
			for _, it in pairs(h.gear) do retype(it) end
		end
	end
	-- every item checked: values put back in range, broken stats dropped;
	-- one that cannot be read (no known slot) is set aside, not deleted
	local repaired, setAside = 0, 0
	local function fixItem(it)
		if type(it) ~= "table" or not ns.SLOT[it.s] then return false end
		local changed = false
		local function set(k, v) if it[k] ~= v then it[k] = v changed = true end end
		set("q", ns.U.clamp(math.floor(tonumber(it.q) or 1), 1, ns.MAX_QUALITY))
		set("l", ns.Items.SnapLevel(ns.U.clamp(math.floor(tonumber(it.l) or 1), 1, ns.HERO_MAX_LEVEL)))
		local up = math.floor(tonumber(it.up) or 0)
		set("up", up > 0 and math.min(up, ns.Upgrade and ns.Upgrade.MAX or 20) or nil)
		if it.lock ~= nil and it.lock ~= true then set("lock", it.lock and true or nil) end
		if it.a ~= nil then
			if type(it.a) ~= "table" then
				set("a", nil)
			else
				for i = #it.a, 1, -1 do
					local a = it.a[i]
					if type(a) ~= "table" or not ns.AFFIX[a[1]] or type(a[2]) ~= "number" or a[2] ~= a[2] then
						table.remove(it.a, i)
						changed = true
					end
				end
			end
		end
		for kind, f in pairs(ns.SOCKET_FIELD) do
			local l = it[f]
			if l ~= nil then
				if type(l) ~= "table" then
					set(f, nil)
				else
					for i = #l, 1, -1 do
						local e = l[i]
						if type(e) ~= "table" or not ns.AFFIX[e[1]] or type(e[2]) ~= "number" or i > ns.Items.SocketCount(it, kind) then
							table.remove(l, i)
							changed = true
						end
					end
				end
			end
		end
		if changed then repaired = repaired + 1 end
		return true
	end
	db.setAside = type(db.setAside) == "table" and db.setAside or {}
	for _, list in ipairs({ db.bag, db.bank }) do
		for i = #list, 1, -1 do
			if not fixItem(list[i]) then
				if type(list[i]) == "table" then db.setAside[#db.setAside + 1] = list[i] end
				table.remove(list, i)
				setAside = setAside + 1
			end
		end
	end
	local misplaced = {}
	for _, h in pairs(db.heroes) do
		if type(h) == "table" and type(h.gear) == "table" then
			for slot, it in pairs(h.gear) do
				if not fixItem(it) then
					if type(it) == "table" then db.setAside[#db.setAside + 1] = it end
					h.gear[slot] = nil
					setAside = setAside + 1
				elseif it.s ~= slot then
					-- worn in a slot it does not belong to: back to the bag
					h.gear[slot] = nil
					misplaced[#misplaced + 1] = it
				end
			end
		end
	end
	if #db.setAside == 0 then db.setAside = nil end
	if repaired + setAside > 0 then
		ns.loadNote = (ns.loadNote and ns.loadNote .. " " or "") .. string.format("저장된 장비 중 %d개의 잘못된 값을 고쳤습니다.%s", repaired,
			setAside > 0 and string.format(" 읽을 수 없는 장비 %d개는 따로 보관했습니다.", setAside) or "")
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
			h.level = ns.U.clamp(math.floor(tonumber(h.level) or 1), 1, ns.HERO_MAX_LEVEL)
			h.xp = math.max(0, tonumber(h.xp) or 0)
			if type(h.tree) ~= "table" then h.tree = {} end
			if type(h.skills) ~= "table" then h.skills = {} end
			if type(h.gear) ~= "table" then h.gear = {} end
			if h.sk ~= nil and type(h.sk) ~= "table" then h.sk = nil end
			if from < 3 then migrateV2Hero(h) end
			if from < 4 then renameSkills(h) end
			h.sk = h.sk or {}
			clampHero(h)
			h.sex = nil -- heroes take the player's gender now
			if type(h.name) == "table" then h.name = h.name[1] end -- version 2.0 kept two spellings
			if type(h.name) ~= "string" or h.name == "" then
				h.name = nil -- named below, once every other name is known
			elseif not h.name:find(" ") then -- before 2.1 heroes had no family name
				local race = ns.RACES[ns.ClassRace(ns.SPECS[h.spec].class, ns.FACTIONS[db.faction] and db.faction or nil)]
				local pool = race and ns.NAME_POOLS[race.names]
				if pool then h.name = h.name .. " " .. ns.Names.Family(pool) end
			end
			local n = tonumber(tostring(id):sub(2)) or 0
			if n > db.heroSeq then db.heroSeq = n end
		end
	end
	if db.faction ~= "ALLIANCE" and db.faction ~= "HORDE" then db.faction = nil end
	ns.db = db
	for _, h in pairs(db.heroes) do
		if not h.name then h.name = ns.Heroes.RollName(h.spec) end
	end
	-- party slots: heroes that exist, each in one slot only
	local seated = {}
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id and (type(id) ~= "string" or not db.heroes[id] or seated[id]) then db.party[i] = false end
		if db.party[i] then seated[db.party[i]] = true end
	end
	for id in pairs(db.mats) do
		if not ns.MATS[id] then db.mats[id] = nil end
	end
	-- runes that exist, at levels they have
	for id, lvl in pairs(db.runes) do
		local node = ns.Runes and ns.Runes.byId[id]
		lvl = math.floor(tonumber(lvl) or 0)
		if not node or lvl <= 0 then db.runes[id] = nil else db.runes[id] = math.min(lvl, node.max) end
	end
	db.stage.diff = ns.U.clamp(db.stage.diff or 1, 1, #ns.DIFFS)
	db.stage.idx = ns.U.clamp(db.stage.idx or 1, 1, ns.STAGE_COUNT)
	db.tower.best = math.max(0, math.floor(tonumber(db.tower.best) or 0))
	db.tower.floor = ns.U.clamp(math.floor(tonumber(db.tower.floor) or 1), 1, db.tower.best + 1)
	db.tower.on = db.tower.on == true
	ns.db = db
	-- gear of dropped heroes: the bag, the bank once the bag is full (the bag
	-- past its size when both are)
	for _, it in ipairs(misplaced) do orphans[#orphans + 1] = it end
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
	-- the old runes' bonuses (bag and party size ...) go with them
	if ns.Runes then ns.Runes.Invalidate() end
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

-- The endless tower opens once the last difficulty is cleared to its end.
function ns.TowerOpen()
	local prog = ns.db and ns.db.prog
	return prog ~= nil and (prog[#ns.DIFFS] or 0) >= ns.STAGE_COUNT
end

-- How far the account has come: one for every difficulty cleared to its last
-- stage, in order (0 .. #ns.DIFFS). Heroes dress by it (ns.MODEL.armorTier).
function ns.GearTier()
	local prog = ns.db and ns.db.prog
	if not prog then return 0 end
	local n = 0
	for d = 1, #ns.DIFFS do
		if (prog[d] or 0) >= ns.STAGE_COUNT then n = d else break end
	end
	return n
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
