-- Offline rewards: gold and experience for the time spent logged out, based on
-- the income rate measured while playing, once their rune is learned. Capped
-- at 8 hours; an absence of 30 days or longer pays nothing. Runes and
-- companions raise the gold and the experience.
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

-- The share of the measured rate paid: gold, then experience.
function Offline.Efficiency()
	return Offline.BASE_RATE * (1 + (ns.Bonus("offline") + ns.Bonus("offGold")) / 100)
end

function Offline.ExpEfficiency()
	return Offline.BASE_RATE * (1 + (ns.Bonus("offline") + ns.Bonus("offExp")) / 100)
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
	if (db.rate.gold or 0) <= 0 or ns.Heroes.PartyCount() == 0 or not ns.OfflineOn() then return nil end

	local counted = min(away, Offline.Cap())
	local eff = Offline.Efficiency()
	local gold = floor(db.rate.gold * counted * eff)
	local baseXP = db.rate.xp * counted * Offline.ExpEfficiency()
	local stageLevel = db.rate.level or ns.StageLevel(db.stage.diff, db.stage.idx)

	local levels, xpTotal = 0, 0
	local expBonus = ns.Bonus("exp")
	for slot = 1, ns.PARTY_SIZE do
		local id = db.party[slot]
		if id and db.heroes[id] then
			local s = ns.Stats.Get(id)
			local amount = baseXP * (1 + (expBonus + (s.exp or 0)) / 100) * ns.Heroes.XPFactor(db.heroes[id].level, stageLevel)
			local gained, used = ns.Heroes.AddXP(id, amount)
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
