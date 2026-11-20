-- Saved data: defaults, migration, repair of missing fields and the gold purse.
local _, ns = ...

local DB_VERSION = 2

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
	heroes = {},                 -- [heroId] = { id, spec, name, level, xp, tree = {}, skills = {}, gear = {} }
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
	opt = { auto = true, retreat = true, retry = true },
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
				id = id, spec = specId, name = ns.Names.Roll(), level = o.level or 1, xp = o.xp or 0,
				tree = { [13] = 1 }, skills = { sp.tree[1][3].s }, gear = type(o.gear) == "table" and o.gear or {},
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
	if type(BigIdleWoWHeroesDB) ~= "table" then
		BigIdleWoWHeroesDB = {}
	end
	local db = BigIdleWoWHeroesDB
	if (db.v or DB_VERSION) < 2 and type(db.heroes) == "table" then
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
	-- drop references to data that no longer exists
	for id, h in pairs(db.heroes) do
		if type(h) ~= "table" or not ns.SPECS[h.spec] then
			db.heroes[id] = nil
		else
			h.id = id
			h.level = h.level or 1
			h.xp = h.xp or 0
			h.tree = h.tree or {}
			h.skills = h.skills or {}
			h.gear = h.gear or {}
			if type(h.name) == "table" then h.name = h.name[1] end -- version 2.0 kept two spellings
			if type(h.name) ~= "string" or h.name == "" then h.name = ns.Names.Roll() end
			local n = tonumber(tostring(id):sub(2)) or 0
			if n > db.heroSeq then db.heroSeq = n end
		end
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
	return db
end

function ns.ResetDB()
	local ui = ns.db and ns.db.ui
	BigIdleWoWHeroesDB = {}
	local db = ns.InitDB()
	if ui then db.ui = ui end
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
