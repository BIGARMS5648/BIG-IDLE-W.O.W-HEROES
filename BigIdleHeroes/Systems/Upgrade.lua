-- Equipment enhancement (강화): every piece starts at +0 and goes up to +20,
-- one step a try, bought with gold. Each step raises the item's base stats.
-- Any try can fail (the gold is gone, the item stays as it was): 65% a step
-- up to +10, then lower and lower, 10% for the last. Opens with 신화+, once 신화 is cleared to
-- its end. An item's steps can be moved onto another piece of the same slot
-- (계승): 70% of what they are worth in gold becomes steps on the new piece,
-- what is set in its sockets moves along, and the old piece is used up.
-- Stored on the item as it.up (nil = +0).
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Upgrade = {}
ns.Upgrade = Upgrade

Upgrade.MAX = 20
Upgrade.SAFE = 10 -- up to this step every try has the same chance
Upgrade.LOW = 0.65 -- that chance
-- the chance of a try from +n (n = 10 .. 19) to +n+1
Upgrade.CHANCE = { [10] = 0.6, [11] = 0.55, [12] = 0.5, [13] = 0.45, [14] = 0.4,
	[15] = 0.35, [16] = 0.3, [17] = 0.2, [18] = 0.15, [19] = 0.1 }
Upgrade.GROWTH = 1.3 -- each step costs this much more than the one before
Upgrade.BASE = 400 -- the first step: this many level-l monsters' gold
Upgrade.KEEP = 0.7 -- 계승: this share of the old piece's worth goes on

-- Base stats times this at +n: 4% a step up to +10, 6% a step after.
function Upgrade.Bonus(n)
	n = n or 0
	return 1 + 0.04 * min(n, 10) + 0.06 * max(0, n - 10)
end

function Upgrade.Level(it) return it and it.up or 0 end

-- Open with the last difficulty (신화+): once the one before it is cleared
-- to its end.
function Upgrade.Open()
	local prog = ns.db and ns.db.prog
	return prog ~= nil and (prog[#ns.DIFFS - 1] or 0) >= ns.STAGE_COUNT
end

function Upgrade.Chance(n)
	if n < Upgrade.SAFE then return Upgrade.LOW end
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

-- how it opens (it opens with 신화+), wherever it is locked
Upgrade.LOCKED_TEXT = "신화+ 난이도에 도달하면 해금할 수 있습니다."
local function lockedText()
	return Upgrade.LOCKED_TEXT
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

------------------------------------------------------------------------
-- 계승: moving the steps of one piece onto another of the same slot
------------------------------------------------------------------------
-- the gold the steps up to +n cost on average (failed tries counted)
function Upgrade.Worth(it, n)
	n = n or Upgrade.Level(it)
	local total = 0
	for k = 0, n - 1 do total = total + Upgrade.Cost(it, k) / Upgrade.Chance(k) end
	return total
end

-- the step `to` ends at with `from`'s steps moved onto it: its own worth plus
-- KEEP of `from`'s, spent on its own steps from where it is
function Upgrade.MoveResult(from, to)
	local n = Upgrade.Level(to)
	local have = Upgrade.Worth(to, n)
	local gold = have + Upgrade.Worth(from) * Upgrade.KEEP
	while n < Upgrade.MAX do
		local step = Upgrade.Cost(to, n) / Upgrade.Chance(n)
		if have + step > gold then break end
		have, n = have + step, n + 1
	end
	return n
end

-- worn by a hero or in the bag (not the bank)
local function reachable(it)
	return ns.Items.Wearer(it) ~= nil or ns.Items.IndexInBag(it) ~= nil
end

function Upgrade.CanMove(from, to)
	if not Upgrade.Open() then return false, lockedText() end
	if not from or not to or from == to then return false, "계승할 장비가 없습니다." end
	if from.s ~= to.s then return false, "같은 부위의 장비끼리만 계승할 수 있습니다." end
	if Upgrade.Level(from) == 0 then return false, "계승할 강화 단계가 없습니다." end
	if from.lock then return false, "보호한 장비는 계승에 쓰지 않습니다." end
	if not reachable(from) or not reachable(to) then return false, "착용한 장비나 가방의 장비만 계승할 수 있습니다." end
	if Upgrade.MoveResult(from, to) <= Upgrade.Level(to) then return false, "계승해도 강화 단계가 오르지 않습니다." end
	return true
end

-- The piece of the same slot (worn by any hero or in the bag, not a
-- protected one) whose steps would take `to` the highest, the one worth less
-- on a tie; nil when none would raise it.
function Upgrade.SourceFor(to)
	if not to then return nil end
	local best, bestN, bestWorth
	local function consider(it)
		if it ~= to and it.s == to.s and Upgrade.Level(it) > 0 and not it.lock then
			local n, w = Upgrade.MoveResult(it, to), Upgrade.Worth(it)
			if n > Upgrade.Level(to) and (not best or n > bestN or (n == bestN and w < bestWorth)) then
				best, bestN, bestWorth = it, n, w
			end
		end
	end
	for _, h in pairs(ns.db.heroes) do
		for _, it in pairs(h.gear) do consider(it) end
	end
	for _, it in ipairs(ns.db.bag) do consider(it) end
	return best
end

-- What is set in the old piece's sockets goes into the new piece's free
-- sockets of the same kind, in the order it was set; what finds no free
-- socket is lost with the old piece. Per kind the old piece has something
-- in: { moved = n, lost = n }.
function Upgrade.SocketPlan(from, to)
	local plan = {}
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		local l = ns.Items.SocketList(from, kind)
		if l and #l > 0 then
			local n = min(#l, max(0, ns.Items.FreeSockets(to, kind)))
			plan[kind] = { moved = n, lost = #l - n }
		end
	end
	return plan
end

-- Moves the steps and what is set in the sockets (Upgrade.SocketPlan); the
-- old piece is gone. When it was worn and the new piece was in the bag, the
-- new piece takes its place on that hero if the hero can wear it. Returns
-- true and the new step.
function Upgrade.Move(from, to)
	local ok, why = Upgrade.CanMove(from, to)
	if not ok then return false, why end
	local n = Upgrade.MoveResult(from, to)
	for kind, p in pairs(Upgrade.SocketPlan(from, to)) do
		if p.moved > 0 then
			local src, dst = ns.Items.SocketList(from, kind), ns.Items.SocketList(to, kind, true)
			for i = 1, p.moved do dst[#dst + 1] = src[i] end
		end
	end
	local db = ns.db
	local fromHero, toHero = ns.Items.Wearer(from), ns.Items.Wearer(to)
	if fromHero then
		db.heroes[fromHero].gear[from.s] = nil
	else
		table.remove(db.bag, ns.Items.IndexInBag(from))
	end
	to.up = n
	if fromHero and not toHero and ns.Items.CanEquip(fromHero, to) then
		ns.Items.Equip(fromHero, ns.Items.IndexInBag(to))
	end
	db.stat.upMoves = (db.stat.upMoves or 0) + 1
	-- the heroes wearing pieces now (the old piece's hero, the new piece's)
	local done = {}
	for _, id in pairs({ fromHero or false, toHero or false, ns.Items.Wearer(to) or false }) do
		if id and not done[id] then
			done[id] = true
			ns.Stats.Invalidate(id)
			ns.Fire("GEAR", id)
		end
	end
	ns.Fire("BAG")
	return true, n
end

