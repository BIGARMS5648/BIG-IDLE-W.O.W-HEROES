-- Offline rewards: gold and experience for the time spent logged out, once
-- their rune is learned: what the party would earn hunting the highest stage
-- it has cleared, over and over (the kill gold and experience a second of that
-- stage's last clear, at the game speed of now). Capped at 8 hours; an absence
-- of 30 days or longer pays nothing. Runes and companions raise the gold and
-- the experience.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Offline = {}
ns.Offline = Offline

Offline.BASE_CAP = 8 * 3600
Offline.MAX_AWAY = 30 * 86400
Offline.BASE_RATE = 0.5

function Offline.Cap()
	return Offline.BASE_CAP + ns.Bonus("offlineCap") * 3600
end

-- The share of the hunting income paid: gold, then experience.
function Offline.Efficiency()
	return Offline.BASE_RATE * (1 + (ns.Bonus("offline") + ns.Bonus("offGold")) / 100)
end

function Offline.ExpEfficiency()
	return Offline.BASE_RATE * (1 + (ns.Bonus("offline") + ns.Bonus("offExp")) / 100)
end

-- The highest stage cleared (the last difficulty with a clear, its furthest
-- stage), or nil.
function Offline.Stage()
	local db = ns.db
	for d = #ns.DIFFS, 1, -1 do
		local i = db.prog[d] or 0
		if i > 0 then return d, min(i, ns.STAGE_COUNT) end
	end
end

-- Gold and experience a real second while hunting there, and the stage's
-- level; nil when that stage has no clear on record (a save from before the
-- record was kept: then the income measured while playing stands in).
function Offline.Income()
	local db = ns.db
	local d, i = Offline.Stage()
	if not d then return nil end
	local h = db.hunt and db.hunt[d .. "-" .. i]
	local speed = ns.GameSpeed()
	if h and (h.g or 0) > 0 then
		return h.g * speed, (h.x or 0) * speed, ns.StageLevel(d, i)
	end
	if (db.rate.gold or 0) > 0 then
		return db.rate.gold, db.rate.xp or 0, ns.StageLevel(d, i)
	end
end

-- One hero's experience over `seconds` at `perSec` (before the hero's own
-- bonus and the level gap): level by level, so the cut for a hero far below
-- the stage shrinks as it catches up. Returns levels gained and experience.
local function heroXP(id, perSec, seconds, stageLevel)
	local h = ns.db.heroes[id]
	local s = ns.Stats.Get(id)
	local mult = 1 + (ns.Bonus("exp") + (s.exp or 0)) / 100
	local levels, used = 0, 0
	for _ = 1, ns.HERO_MAX_LEVEL do
		if seconds <= 0 or h.level >= ns.HERO_MAX_LEVEL then break end
		local rate = perSec * mult * ns.Heroes.XPFactor(h.level, stageLevel)
		if rate <= 0 then break end
		local need = ns.XPForLevel(h.level) - (h.xp or 0)
		if need / rate >= seconds then
			local g, u = ns.Heroes.AddXP(id, rate * seconds)
			return levels + g, used + u
		end
		local g, u = ns.Heroes.AddXP(id, need)
		levels, used = levels + g, used + u
		seconds = seconds - need / rate
	end
	return levels, used
end

-- Returns a summary table, or nil when there is nothing to hand out.
function Offline.Claim(now)
	local db = ns.db
	local last = db.lastSeen
	-- a clock set back: keep the later time so the same span is never paid twice
	if last and now < last then return nil end
	db.lastSeen = now
	if not last or now == last then return nil end
	local away = now - last
	if away < 60 then return nil end
	if away >= Offline.MAX_AWAY then
		return { away = away, expired = true, gold = 0, xp = 0, levels = 0 }
	end
	if ns.Heroes.PartyCount() == 0 or not ns.OfflineOn() then return nil end
	local goldPerSec, xpPerSec, stageLevel = Offline.Income()
	if not goldPerSec then return nil end

	local counted = min(away, Offline.Cap())
	local eff = Offline.Efficiency()
	local gold = floor(goldPerSec * counted * eff)
	local xpRate = xpPerSec * Offline.ExpEfficiency()

	local levels, xpTotal = 0, 0
	for slot = 1, ns.PARTY_SIZE do
		local id = db.party[slot]
		if id and db.heroes[id] then
			local gained, used = heroXP(id, xpRate, counted, stageLevel)
			xpTotal = xpTotal + used
			levels = levels + gained
		end
	end
	ns.AddGold(gold)
	return { away = away, counted = counted, gold = gold, xp = xpTotal, levels = levels, eff = eff }
end

function Offline.Stamp(now)
	local db = ns.db
	if not db then return end
	if ns.Combat and ns.Combat.FoldRate then ns.Combat.FoldRate(1) end
	if not db.lastSeen or now > db.lastSeen then db.lastSeen = now end
end
