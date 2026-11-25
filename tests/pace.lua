-- Long play run for pacing: plays with the bot (tests/bot.lua) and prints
-- when each act is first cleared and the party's top level at set hours,
-- to compare with TBH's hours (Normal 3-10 ~64 h, Torment act 3 ~115 h,
-- everything ~333 h). Used to set ns.MIGHT and ns.EXP_GROW (Data/Stages.lua).
--
--   python3 tests/run.py pace HOURS [STARTER,RECRUIT,RECRUIT,...]
--
-- globals: PACE_PARTY (spec ids), PACE_LOAD (a checkpoint to start from),
-- PACE_SAVE + PACE_SAVE_AT (hours) to write one, PACE_SEED
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
	if t >= nextBot then nextBot = t + 30 Bot.Tick() end
	for d = 1, 4 do
		if db.prog[d] ~= last[d] then
			last[d] = db.prog[d]
			if db.prog[d] % 10 == 0 or (d == 4 and db.prog[d] > 20) then
				out[#out + 1] = string.format("%s%d=%.1fh(L%d)", ({ "N", "M", "H", "T" })[d], db.prog[d], t / 3600, lv())
			end
		end
	end
	if marks[mi] and t >= marks[mi] * 3600 then
		out[#out + 1] = string.format("[%dh: %d/%d/%d/%d L%d G%.3g R%.3g]", marks[mi], db.prog[1], db.prog[2], db.prog[3], db.prog[4], lv(),
			db.stat.gold, ns.Runes.Spent and ns.Runes.Spent() or 0)
		mi = mi + 1
	end
	if PACE_SAVE and not saved and t >= PACE_SAVE_AT * 3600 then
		saved = true
		local buf = { "return { t = ", string.format("%.17g", t), ", db = " }
		ser(db, buf)
		buf[#buf + 1] = " }"
		local f = assert(io.open(PACE_SAVE, "w"))
		f:write(table.concat(buf))
		f:close()
	end
end
out[#out + 1] = string.format("[end %.0fh %d/%d/%d/%d L%d wipes %d]", t / 3600, db.prog[1], db.prog[2], db.prog[3], db.prog[4], lv(), db.stat.wipes)
print("  " .. table.concat(out, " "))
return true
