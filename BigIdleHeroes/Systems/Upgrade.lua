-- Equipment enhancement (강화): every piece starts at +0 and goes up to +20,
-- one step a try, bought with gold. Each step raises the item's base stats;
-- from +0 to +10 every try succeeds, from +10 on a try can fail (the gold is gone, the item stays as it was). An
-- item's enhancement can be moved to another piece of the same slot for gold
-- (계승). Opens with the endless tower, once Mythic+ is cleared to its end.
-- Stored on the item as it.up (nil = +0).
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Upgrade = {}
ns.Upgrade = Upgrade

Upgrade.MAX = 20
Upgrade.SAFE = 10 -- every try up to this step succeeds
-- the chance of a try from +n (n = 10 .. 19) to +n+1
Upgrade.CHANCE = { [10] = 0.9, [11] = 0.8, [12] = 0.7, [13] = 0.6, [14] = 0.5,
	[15] = 0.4, [16] = 0.35, [17] = 0.3, [18] = 0.25, [19] = 0.2 }
Upgrade.GROWTH = 1.3 -- each step costs this much more than the one before
Upgrade.BASE = 400 -- the first step: this many level-l monsters' gold
Upgrade.MOVE = 0.2 -- moving: this share of what the steps cost to make

-- Base stats times this at +n: 4% a step up to +10, 6% a step after.
function Upgrade.Bonus(n)
	n = n or 0
	return 1 + 0.04 * min(n, 10) + 0.06 * max(0, n - 10)
end

function Upgrade.Level(it) return it and it.up or 0 end

-- Open once the last difficulty is cleared to its end (the endless tower).
function Upgrade.Open()
	return ns.TowerOpen and ns.TowerOpen() or false
end

function Upgrade.Chance(n)
	if n < Upgrade.SAFE then return 1 end
	return Upgrade.CHANCE[n] or 0
end

-- gold for a try from +n: grows with the item's level and quality
local function base(it)
	return Upgrade.BASE * ns.MobGold(1, it.l or 1) * (0.5 + 0.25 * (it.q or 1))
end
function Upgrade.Cost(it, n)
	n = n or Upgrade.Level(it)
	return floor(base(it) * Upgrade.GROWTH ^ n + 0.5)
end

-- what the steps up to +n cost when every try succeeds
local function made(it, n)
	local total = 0
	for k = 0, n - 1 do total = total + Upgrade.Cost(it, k) end
	return total
end

local function lockedText()
	return string.format("%s 난이도를 끝까지(%d 스테이지) 깨면 쓸 수 있습니다.", ns.N(ns.DIFFS[#ns.DIFFS].name), ns.STAGE_COUNT)
end

-- why an item cannot be enhanced now (nil when it can)
function Upgrade.Why(it)
	if not Upgrade.Open() then return lockedText() end
	if not it then return "강화할 장비를 고르세요." end
	local n = Upgrade.Level(it)
	if n >= Upgrade.MAX then return "최고 강화 단계입니다." end
	if not ns.CanAfford(Upgrade.Cost(it, n)) then return "골드가 부족합니다." end
	return nil
end

-- One try. Returns ok (the try was made), success, the new step or why not.
function Upgrade.Try(it, heroId)
	local why = Upgrade.Why(it)
	if why then return false, why end
	local n = Upgrade.Level(it)
	if not ns.SpendGold(Upgrade.Cost(it, n)) then return false, "골드가 부족합니다." end
	local db = ns.db
	db.stat.upTries = (db.stat.upTries or 0) + 1
	local success = math.random() < Upgrade.Chance(n)
	if success then
		it.up = n + 1
		-- the hero wearing it now (whatever hero the caller had in mind)
		local wearer = ns.Items.Wearer(it)
		ns.Stats.Invalidate(wearer)
		if wearer then ns.Fire("GEAR", wearer) end
	end
	ns.Fire("BAG")
	return true, success, Upgrade.Level(it)
end

-- Moving the steps of one piece onto another of the same slot.
function Upgrade.MoveCost(from, to)
	return floor(made(to, Upgrade.Level(from)) * Upgrade.MOVE + 0.5)
end

function Upgrade.CanMove(from, to)
	if not Upgrade.Open() then return false, lockedText() end
	if not from or not to or from == to then return false, "옮길 장비가 없습니다." end
	if from.s ~= to.s then return false, "같은 부위의 장비끼리만 옮길 수 있습니다." end
	if Upgrade.Level(from) <= Upgrade.Level(to) then return false, "이 장비보다 강화 단계가 높은 장비가 없습니다." end
	if not ns.CanAfford(Upgrade.MoveCost(from, to)) then return false, "골드가 부족합니다." end
	return true
end

-- The piece of the same slot with the highest step above `to`'s (worn by any
-- hero or in the bag), or nil: what 계승 would move onto it.
function Upgrade.SourceFor(to)
	if not to then return nil end
	local best, bestHero
	local function consider(it, heroId)
		if it ~= to and it.s == to.s and Upgrade.Level(it) > Upgrade.Level(to)
			and (not best or Upgrade.Level(it) > Upgrade.Level(best)) then
			best, bestHero = it, heroId
		end
	end
	for id, h in pairs(ns.db.heroes) do
		for _, it in pairs(h.gear) do consider(it, id) end
	end
	for _, it in ipairs(ns.db.bag) do consider(it) end
	return best, bestHero
end

function Upgrade.Move(from, to, fromHero, toHero)
	local ok, why = Upgrade.CanMove(from, to)
	if not ok then return false, why end
	if not ns.SpendGold(Upgrade.MoveCost(from, to)) then return false, "골드가 부족합니다." end
	to.up = from.up
	from.up = nil
	-- the heroes wearing the two pieces now (whatever the caller had in mind)
	fromHero, toHero = ns.Items.Wearer(from), ns.Items.Wearer(to)
	ns.Stats.Invalidate(fromHero)
	ns.Stats.Invalidate(toHero)
	if fromHero then ns.Fire("GEAR", fromHero) end
	if toHero and toHero ~= fromHero then ns.Fire("GEAR", toHero) end
	ns.Fire("BAG")
	return true, Upgrade.Level(to)
end
