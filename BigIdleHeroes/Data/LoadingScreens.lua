-- The game's own loading screens, shown in the stage screen: a world's card
-- and each stage's banner show the loading screen of its place. Forever's
-- screens come first (its new continents, Old Ironforge, the Wetlands dig
-- site, the Ruins of Lordaeron); the original game's dungeon and raid
-- screens are kept in Forever; when Forever's file is not in the client the
-- original one is used.
--   kind "forever": 16:9, the picture between dark bands
--   kind "classic": 4:3, the picture inside the bronze frame under the logo
local _, ns = ...

local GLUE = "Interface\\Glues\\LoadingScreens\\"
local function forever(name, fallback)
	return { file = GLUE .. "camelot160\\main\\loadscreen_camelot_" .. name, kind = "forever", fallback = fallback }
end
local function classic(name)
	return { file = GLUE .. "LoadScreen" .. name, kind = "classic" }
end

local EK, KALIMDOR = classic("EasternKingdom"), classic("Kalimdor")
ns.LOADSCREENS = {
	easternkingdom = forever("easternkingdom", EK),
	kalimdor = forever("kalimdor", KALIMDOR),
	oldironforge = forever("oldironforge", EK),
	excavation = forever("excavation", EK),
	ruinsoflordaeron = forever("ruinsoflordaeron", EK),
	ragefire = classic("RagefireChasm"),
	wailing = classic("WailingCaverns"),
	deadmines = classic("Deadmines"),
	shadowfang = classic("ShadowfangKeep"),
	blackfathom = classic("BlackfathomDeeps"),
	monastery = classic("Monastery"),
	gnomeregan = classic("Gnomeregan"),
	razorfenkraul = classic("RazorfenKraul"),
	razorfendowns = classic("RazorfenDowns"),
	uldaman = classic("Uldaman"),
	zulfarrak = classic("ZulFarrak"),
	maraudon = classic("Maraudon"),
	sunkentemple = classic("SunkenTemple"),
	blackrockdepths = classic("BlackrockDepths"),
	diremaul = classic("DireMaul"),
	blackrockspire = classic("BlackrockSpire"),
	scholomance = classic("Scholomance"),
	stratholme = classic("Strathome"), -- (the game's own spelling)
	zulgurub = classic("ZulGurub"),
	ahnqiraj20 = classic("AhnQiraj20man"),
	moltencore = classic("MoltenCore"),
	onyxia = classic("Raid"), -- Onyxia's Lair has the original raid screen
	blackwing = classic("BlackwingLair"),
	ahnqiraj40 = classic("AhnQiraj40man"),
	naxxramas = classic("Naxxramas"),
	-- the endless tower's, used by no stage: its card Dalaran, its floors
	-- Zephra's Isle (Forever's), else original screens no stage uses either
	dalaran = forever("dalaran", classic("PvPBattleground")),
	zephrasisle = forever("zephrasisle", classic("StormwindStockade")),
}

-- each stage's place (Data/Scenery.lua) -> its loading screen
local BY_PLACE = {
	dunmorogh = "oldironforge", wetlands = "excavation", tirisfal = "ruinsoflordaeron",
	ragefire = "ragefire", wailing = "wailing", deadmines = "deadmines", shadowfang = "shadowfang",
	blackfathom = "blackfathom", scarletyard = "monastery", scarletlib = "monastery", scarletarmory = "monastery",
	scarletcathedral = "monastery", gnomeregan = "gnomeregan",
	razorfen = "razorfenkraul", uldaman = "uldaman", zulfarrak = "zulfarrak", maraudon = "maraudon",
	sunkentemple = "sunkentemple", blackrockdepths = "blackrockdepths", diremaul = "diremaul", gordok = "diremaul",
	highborne = "diremaul", blackrockspire = "blackrockspire", scholomance = "scholomance", stratholme = "stratholme", stratslaughter = "stratholme",
	zulgurub = "zulgurub", ahnqiraj = "ahnqiraj20", moltencore = "moltencore", onyxia = "onyxia",
	blackwing = "blackwing", aqtemple = "ahnqiraj40", naxxramas = "naxxramas",
}
-- outdoor places of Kalimdor; the other outdoor places are in the Eastern Kingdoms
local KALIMDOR_PLACES = {
	teldrassil = true, durotar = true, mulgore = true, barrens = true, stonetalon = true, ashenvale = true,
	needles = true, desolace = true, dustwallow = true, feralas = true, tanaris = true, azshara = true,
	ungoro = true, felwood = true, winterspring = true, silithus = true,
}
-- stages whose place shares its scenery with another but has its own screen
local BY_STAGE = { ["2-5"] = "razorfendowns" }
-- the worlds' cards
local BY_WORLD = { "easternkingdom", "kalimdor", "zulgurub", "naxxramas" }

local function inClient(path)
	if type(GetFileIDFromPath) ~= "function" then return true end
	local ok, id = pcall(GetFileIDFromPath, path)
	return not ok or id ~= nil
end

-- the screen to show for a key: Forever's when the client has it, else the original
local function pick(key)
	local ls = ns.LOADSCREENS[key]
	if ls and ls.fallback and not inClient(ls.file) then return ls.fallback end
	return ls
end

function ns.StageLoadingKey(diff, idx)
	local own = BY_STAGE[diff .. "-" .. idx]
	if own then return own end
	local place = ns.SceneryKey and ns.SceneryKey(diff, idx)
	if BY_PLACE[place] then return BY_PLACE[place] end
	return KALIMDOR_PLACES[place] and "kalimdor" or "easternkingdom"
end

function ns.StageLoadingScreen(diff, idx) return pick(ns.StageLoadingKey(diff, idx)) end
function ns.WorldLoadingScreen(d) return pick(BY_WORLD[d] or "easternkingdom") end
-- the endless tower: "card" (its card on top) or "floor" (the floor's banner)
function ns.TowerLoadingScreen(part) return pick(part == "floor" and "zephrasisle" or "dalaran") end
