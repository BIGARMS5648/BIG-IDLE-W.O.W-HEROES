-- Offline rewards: gold and experience for the time spent logged out, based on
-- the income rate measured while playing. Capped at 8 hours (runes add more);
-- an absence of 30 days or longer pays nothing.
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

function Offline.Efficiency()
	return Offline.BASE_RATE * (1 + ns.Bonus("offline") / 100)
end

-- Returns a summary table, or nil when there is nothing to hand out.
function Offline.Claim(now)
	local db = ns.db
	local last = db.lastSeen
	db.lastSeen = now
	if not last or now <= last then return nil end
	local away = now - last
	if away < 60 then return nil end
	if away >= Offline.MAX_AWAY then
		return { away = away, expired = true, gold = 0, xp = 0, levels = 0 }
	end
	if (db.rate.gold or 0) <= 0 or ns.Heroes.PartyCount() == 0 then return nil end

	local counted = min(away, Offline.Cap())
	local eff = Offline.Efficiency()
	local gold = floor(db.rate.gold * counted * eff)
	local baseXP = db.rate.xp * counted * eff
	local stageLevel = db.rate.level or ns.StageLevel(db.stage.diff, db.stage.idx)

	local levels, xpTotal = 0, 0
	local expBonus = ns.Bonus("exp")
	for slot = 1, ns.PARTY_SIZE do
		local id = db.party[slot]
		if id and db.heroes[id] then
			local s = ns.Stats.Get(id)
			local amount = baseXP * (1 + (expBonus + (s.exp or 0)) / 100) * ns.Heroes.XPFactor(db.heroes[id].level, stageLevel)
			xpTotal = xpTotal + amount
			levels = levels + ns.Heroes.AddXP(id, amount)
		end
	end
	ns.AddGold(gold)
	return { away = away, counted = counted, gold = gold, xp = xpTotal, levels = levels, eff = eff }
end

function Offline.Stamp(now)
	if ns.db then ns.db.lastSeen = now end
end
