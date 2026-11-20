-- Plays the game with the bot for a number of simulated hours and prints how
-- far it gets. Used to tune progression, and as an endurance test.
local ns = NS
local hours, starter = ...
hours = hours or 6
starter = starter or "HUNTER_MM"
local Bot = dofile(debug.getinfo(1, "S").source:sub(2):gsub("test_balance%.lua$", "bot.lua"))

math.randomseed(20261120)
BigIdleWoWHeroesDB = nil
ns.DetectLang()
ns.InitDB()
local db = ns.db
Bot.Start(starter)

local C = ns.Combat
local STEP = C.STEP
local simTime, nextBot, nextReport = 0, 0, 0
local total = hours * 3600
local firstClear = {}
local lastProg = { 0, 0, 0, 0 }
local ok, err = true, nil

local function partyText()
	local parts = {}
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id then
			local sp = ns.SPECS[db.heroes[id].spec]
			parts[#parts + 1] = sp.class:sub(1, 3) .. "/" .. sp.id:match("_(%a+)$"):sub(1, 3) .. db.heroes[id].level
		end
	end
	return table.concat(parts, " ")
end

local function report(tag)
	print(string.format("  %6.2fh %-9s stage %s-%2d (L%3d) | prog %2d/%2d/%2d/%2d | %s | gold %s | forge %d | wipes %d | chests %d",
		simTime / 3600, tag, ns.N(ns.DIFFS[db.stage.diff].name), db.stage.idx, ns.StageLevel(db.stage.diff, db.stage.idx),
		db.prog[1], db.prog[2], db.prog[3], db.prog[4], partyText(), ns.U.fmt(db.gold), db.forge.level, db.stat.wipes, db.stat.chests))
end

while simTime < total do
	local good, e = pcall(C.Step)
	if not good then ok, err = false, e break end
	local dt = STEP / ns.GameSpeed()
	simTime = simTime + dt
	ns.Loot.Tick(dt)
	if simTime >= nextBot then
		nextBot = simTime + 30
		good, e = pcall(Bot.Tick)
		if not good then ok, err = false, e break end
	end
	for d = 1, 4 do
		if db.prog[d] ~= lastProg[d] then
			lastProg[d] = db.prog[d]
			if db.prog[d] % 10 == 0 then report("act clear") end
		end
	end
	if simTime >= nextReport then
		nextReport = simTime + math.max(1800, total / 12)
		report("")
	end
end
report("end")
if not ok then
	print("  ERROR during simulation: " .. tostring(err))
	return false
end
print(string.format("  kills %d, clears %d, wipes %d, gold earned %s", db.stat.kills, db.stat.clears, db.stat.wipes, ns.U.fmt(db.stat.gold)))
return true
