-- Long play run for pacing: plays with the bot (tests/bot.lua) and prints
-- when each act is first cleared and the party's top level at set hours,
-- to compare with TBH's hours (Normal 3-10 ~64 h, Torment act 3 ~115 h,
-- everything ~333 h). Used to set ns.MIGHT and ns.EXP_GROW (Data/Stages.lua).
--
--   python3 tests/run.py pace HOURS [STARTER,RECRUIT,RECRUIT,...]
--
-- globals: PACE_PARTY (spec ids), PACE_LOAD (a checkpoint to start from),
-- PACE_SAVE + PACE_SAVE_AT (hours, "tower" or "stop") to write one,
-- PACE_STOP_DIFF + PACE_STOP_STAGE (end once that stage is first cleared),
-- PACE_SEED
local ns = NS
local hours, party = ...
local Bot = dofile(debug.getinfo(1, "S").source:sub(2):gsub("pace%.lua$", "bot.lua"))
if party and party ~= "" then
	PACE_PARTY = {}
	for id in party:gmatch("[%u_]+") do PACE_PARTY[#PACE_PARTY + 1] = id end
end
math.randomseed(PACE_SEED or 20261120)

local function ser(v, out)
	local t = type(v)
	if t == "table" then
		out[#out + 1] = "{"
		for k, x in pairs(v) do
			if type(x) ~= "function" then
				out[#out + 1] = "["
				ser(k, out)
				out[#out + 1] = "]="
				ser(x, out)
				out[#out + 1] = ","
			end
		end
		out[#out + 1] = "}"
	elseif t == "string" then out[#out + 1] = string.format("%q", v)
	elseif t == "number" then
		if v ~= v then out[#out + 1] = "0/0" elseif v == math.huge then out[#out + 1] = "math.huge" elseif v == -math.huge then out[#out + 1] = "-math.huge"
		else out[#out + 1] = string.format("%.17g", v) end
	else out[#out + 1] = tostring(v) end
end

local t = 0
if PACE_LOAD then
	local data = dofile(PACE_LOAD)
	t = data.t
	BigWowIdleDB = data.db
	ns.InitDB()
else
	BigWowIdleDB = nil
	ns.InitDB()
end
local db = ns.db
if PACE_PARTY then Bot.recruit = { PACE_PARTY[2], PACE_PARTY[3], PACE_PARTY[4], PACE_PARTY[5] } end
if not PACE_LOAD then Bot.Start(PACE_PARTY and PACE_PARTY[1] or "HUNTER_MM") else ns.Combat.StartStage() end
local C = ns.Combat
local nextBot = t
local total = hours * 3600
local last = { db.prog[1], db.prog[2], db.prog[3], db.prog[4] }
local lastBest = db.tower.best or 0
local marks = { 8, 28, 64, 90, 115, 160, 200, 250, 300, 333 }
local mi = 1
while marks[mi] and marks[mi] * 3600 <= t do mi = mi + 1 end
local function lv()
	local hi = 0
	for i = 1, ns.PARTY_SIZE do local id = db.party[i] if id then hi = math.max(hi, db.heroes[id].level) end end
	return hi
end
local out = {}
local saved = false
while t < total do
	C.Step()
	local dt = C.STEP / ns.GameSpeed()
	t = t + dt
	ns.Loot.Tick(dt)
	if t >= nextBot then
		nextBot = t + 30
		Bot.Tick()
		-- every rune at its top level
		if not PACE_RUNES_DONE then
			local all = true
			for id, n in pairs(ns.Runes.byId) do if ns.Runes.Level(id) < n.max then all = false break end end
			if all then PACE_RUNES_DONE = t / 3600 end
		end
	end
	for d = 1, 4 do
		if db.prog[d] ~= last[d] then
			last[d] = db.prog[d]
			if db.prog[d] % 10 == 0 or (d == 4 and db.prog[d] > 20) then
				out[#out + 1] = string.format("%s%d=%.1fh(L%d)", ({ "N", "M", "H", "T" })[d], db.prog[d], t / 3600, lv())
			end
		end
	end
	-- the endless tower: every fifth floor first cleared
	if (db.tower.best or 0) ~= lastBest then
		lastBest = db.tower.best
		if lastBest % 5 == 0 then out[#out + 1] = string.format("F%d=%.1fh(L%d)", lastBest, t / 3600, lv()) end
	end
	if marks[mi] and t >= marks[mi] * 3600 then
		out[#out + 1] = string.format("[%dh: %d/%d/%d/%d L%d G%.3g R%.3g F%d]", marks[mi], db.prog[1], db.prog[2], db.prog[3], db.prog[4], lv(),
			db.stat.gold, ns.Runes.Spent and ns.Runes.Spent() or 0, db.tower.best or 0)
		mi = mi + 1
	end
	-- (PACE_STOP_DIFF/STAGE: done once that stage is cleared)
	local stop = PACE_STOP_DIFF and (db.prog[PACE_STOP_DIFF] or 0) >= (PACE_STOP_STAGE or ns.STAGE_COUNT)
	-- (PACE_SAVE_AT "tower": when the tower opens; "stop": at the stop)
	if PACE_SAVE and not saved and ((PACE_SAVE_AT == "tower" and ns.TowerOpen()) or (PACE_SAVE_AT == "stop" and stop)
		or (tonumber(PACE_SAVE_AT) and t >= PACE_SAVE_AT * 3600)) then
		saved = true
		local buf = { "return { t = ", string.format("%.17g", t), ", db = " }
		ser(db, buf)
		buf[#buf + 1] = " }"
		local f = assert(io.open(PACE_SAVE, "w"))
		f:write(table.concat(buf))
		f:close()
	end
	if stop then break end
end
out[#out + 1] = string.format("[end %.0fh %d/%d/%d/%d L%d wipes %d R%.3g F%d]", t / 3600, db.prog[1], db.prog[2], db.prog[3], db.prog[4], lv(), db.stat.wipes,
	ns.Runes.Spent(), db.tower.best or 0)
-- when every rune was learned (PACE_RUNES_DONE: the hour, set below)
if PACE_RUNES_DONE then out[#out + 1] = string.format("runes-all=%.1fh", PACE_RUNES_DONE) end
print("  " .. table.concat(out, " "))
return true
