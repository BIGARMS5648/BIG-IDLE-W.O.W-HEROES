-- Plays the game with the bot (as the balance run does) and keeps a book of
-- every gold piece: where it came from, where it went, and how much was left,
-- hour by hour. Used to check that gold neither runs dry nor piles up.
--   python3 tests/run.py gold 240
local ns = NS
local hours, starter = ...
hours = hours or 24
starter = starter or "HUNTER_MM"
local Bot = dofile(debug.getinfo(1, "S").source:sub(2):gsub("gold_audit%.lua$", "bot.lua"))

math.randomseed(20261120)
BigWowIdleDB = nil
ns.InitDB()
local db = ns.db

-- which part of the game moved the gold: the calling file and function
local function source(level)
	local info = debug.getinfo(level, "Sn")
	local file = info and info.short_src and info.short_src:match("([%w_]+)%.lua") or "?"
	local fn = info and info.name or ("line " .. tostring(info and info.linedefined))
	return file .. ":" .. fn
end
local NAMES = {
	["Combat:killReward"] = "kills", ["Combat:victory"] = "first clears", ["Forge:Smelt"] = "salvage items",
	["Forge:SmeltMat"] = "salvage materials", ["Offline:Apply"] = "offline",
}
local book = { inc = {}, out = {} }
local hour = { inc = {}, out = {} }
local addGold, spendGold = ns.AddGold, ns.SpendGold
ns.AddGold = function(n)
	if n and n > 0 then
		local k = source(3)
		k = NAMES[k] or k
		book.inc[k] = (book.inc[k] or 0) + n
		hour.inc[k] = (hour.inc[k] or 0) + n
	end
	return addGold(n)
end
ns.SpendGold = function(n)
	local before = db.gold
	local ok = spendGold(n)
	if ok and n > 0 then
		local k = source(3)
		book.out[k] = (book.out[k] or 0) + (before - db.gold)
		hour.out[k] = (hour.out[k] or 0) + (before - db.gold)
	end
	return ok
end

Bot.Start(starter)
local C = ns.Combat
local STEP = C.STEP
local simTime, nextBot, nextReport = 0, 0, 3600
local total = hours * 3600
local ok, err = true, nil
local rows = {}

local function sum(t) local s = 0 for _, v in pairs(t) do s = s + v end return s end
local function top(t, n)
	local list = {}
	for k, v in pairs(t) do list[#list + 1] = { k, v } end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	local out = {}
	for i = 1, math.min(n, #list) do out[#out + 1] = string.format("%s %s", list[i][1], ns.U.fmt(list[i][2])) end
	return table.concat(out, ", ")
end

local function report()
	local inc, out = sum(hour.inc), sum(hour.out)
	rows[#rows + 1] = { h = simTime / 3600, inc = inc, out = out, gold = db.gold }
	print(string.format("  %5.1fh %-12s L%3d | in %8s  out %8s  left %8s (%5.1fh of income) | in: %s | out: %s",
		simTime / 3600, ns.N(ns.DIFFS[db.stage.diff].name) .. "-" .. db.stage.idx, ns.StageLevel(db.stage.diff, db.stage.idx),
		ns.U.fmt(inc), ns.U.fmt(out), ns.U.fmt(db.gold), inc > 0 and db.gold / inc or 0, top(hour.inc, 3), top(hour.out, 3)))
	hour = { inc = {}, out = {} }
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
	if simTime >= nextReport then
		nextReport = simTime + 3600
		report()
	end
end
if not ok then
	print("  ERROR during simulation: " .. tostring(err))
	return false
end
print("  income:   " .. top(book.inc, 12))
print("  spending: " .. top(book.out, 12))
print(string.format("  earned %s, spent %s, left %s", ns.U.fmt(sum(book.inc)), ns.U.fmt(sum(book.out)), ns.U.fmt(db.gold)))
-- gold left over, measured in hours of income: it should not keep climbing
local worst, at = 0, 0
for i = 4, #rows do
	local r = rows[i]
	local ratio = r.inc > 0 and r.gold / r.inc or 0
	if ratio > worst then worst, at = ratio, r.h end
end
print(string.format("  most gold sitting unused: %.1f hours of income (at %.0fh)", worst, at))
return true
