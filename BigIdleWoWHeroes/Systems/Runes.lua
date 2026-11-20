-- Account-wide bonuses: runes bought with gold plus unlocked companions.
local _, ns = ...

local Runes = {}
ns.Runes = Runes

Runes.byId = {}
Runes.prev = {}   -- [runeId] = id of the rune that must be learned first

do
	Runes.byId.root = ns.RUNE_ROOT
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		local prev = "root"
		for _, node in ipairs(br.nodes) do
			Runes.byId[node.id] = node
			Runes.prev[node.id] = prev
			node.branch = br.key
			prev = node.id
		end
	end
end

local cache

function Runes.Invalidate()
	cache = nil
	if ns.Stats then ns.Stats.Invalidate() end
end

local function build()
	cache = {}
	local db = ns.db
	for id, lvl in pairs(db.runes) do
		local node = Runes.byId[id]
		if node and lvl > 0 then
			cache[node.stat] = (cache[node.stat] or 0) + node.per * lvl
		end
	end
	for _, pet in ipairs(ns.PETS) do
		if db.pets[pet.id] then
			for k, v in pairs(pet.bonus) do
				cache[k] = (cache[k] or 0) + v
			end
		end
	end
end

-- Total account bonus for a key (0 when nothing grants it).
function ns.Bonus(key)
	if not cache then build() end
	return cache[key] or 0
end

function Runes.All()
	if not cache then build() end
	return cache
end

function Runes.Level(id)
	return ns.db.runes[id] or 0
end

function Runes.Available(id)
	local prev = Runes.prev[id]
	if not prev then return true end
	return Runes.Level(prev) > 0
end

function Runes.NextCost(id)
	local node = Runes.byId[id]
	local lvl = Runes.Level(id)
	if lvl >= node.max then return nil end
	return ns.RuneCost(node, lvl + 1)
end

function Runes.Buy(id)
	local node = Runes.byId[id]
	if not node then return false end
	if not Runes.Available(id) then
		return false, ns.T("이전 룬을 먼저 배워야 합니다.", "Learn the previous rune first.")
	end
	local cost = Runes.NextCost(id)
	if not cost then
		return false, ns.T("이미 최대 레벨입니다.", "Already at maximum level.")
	end
	if not ns.SpendGold(cost) then
		return false, ns.T("골드가 부족합니다.", "Not enough gold.")
	end
	ns.db.runes[id] = Runes.Level(id) + 1
	Runes.Invalidate()
	ns.Fire("RUNES")
	return true
end

------------------------------------------------------------------------
-- Derived account limits
------------------------------------------------------------------------
function ns.PartyLimit()
	return math.min(ns.PARTY_SIZE, 1 + ns.Bonus("party"))
end

function ns.SkillSlots()
	return math.min(3, 1 + ns.Bonus("skillSlot"))
end

function ns.BagSize()
	return 30 + ns.Bonus("bag")
end

function ns.BankSize()
	return 10 + ns.Bonus("bank")
end

function ns.ChestCap(chestType)
	return ns.CHEST[chestType].cap + ns.Bonus("chestCap")
end

function ns.GameSpeed()
	return 1 + ns.Bonus("speed") / 100
end

------------------------------------------------------------------------
-- Companions
------------------------------------------------------------------------
function ns.PetProgress(pet)
	local u = pet.unlock
	if u.type then
		return math.min(u.n, ns.db.kills[u.type] or 0), u.n
	end
	local best = 0
	for d = 1, #ns.DIFFS do
		best = math.max(best, ns.db.prog[d] or 0)
	end
	return math.min(u.raid, best), u.raid
end

function ns.PetUnlockText(pet)
	local u = pet.unlock
	if u.type then
		if ns.lang == "ko" then
			return string.format("%s 유형의 적 %s마리 처치", ns.N(ns.MTYPE[u.type]), ns.U.fmt(u.n))
		end
		return string.format("Defeat %s %s enemies", ns.U.fmt(u.n), ns.N(ns.MTYPE[u.type]))
	end
	return ns.T("3막의 마지막 우두머리 처치", "Defeat the final boss of Act 3")
end

function ns.CheckPets()
	local db = ns.db
	local changed = false
	for _, pet in ipairs(ns.PETS) do
		if not db.pets[pet.id] then
			local have, need = ns.PetProgress(pet)
			if have >= need then
				db.pets[pet.id] = true
				if not db.pet then db.pet = pet.id end
				changed = true
				ns.Toast(string.format(ns.T("새 동료 획득: %s", "New companion: %s"), ns.N(pet.name)))
			end
		end
	end
	if changed then
		Runes.Invalidate()
		ns.Fire("PETS")
	end
end
