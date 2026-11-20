-- Saved data: defaults, repair of missing fields and the gold purse.
local _, ns = ...

local DB_VERSION = 1

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
	v = DB_VERSION,
	gold = 0,
	heroes = {},                 -- [classId] = { level, xp, tree = {}, skills = {}, gear = {} }
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

function ns.InitDB()
	if type(BigIdleWoWHeroesDB) ~= "table" then
		BigIdleWoWHeroesDB = {}
	end
	local db = BigIdleWoWHeroesDB
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
	for id in pairs(db.heroes) do
		if not ns.CLASSES[id] then db.heroes[id] = nil end
	end
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id and not (ns.CLASSES[id] and db.heroes[id]) then db.party[i] = false end
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
	local lang = ns.db and ns.db.lang
	BigIdleWoWHeroesDB = {}
	local db = ns.InitDB()
	if ui then db.ui = ui end
	db.lang = lang
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
