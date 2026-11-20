-- Account-wide bonuses: runes bought with gold plus unlocked companions.
local _, ns = ...

local Runes = {}
ns.Runes = Runes

Runes.byId = {}
Runes.prev = {}   -- [runeId] = id of the rune that must be learned first

do
	Runes.byId.root = ns.RUNE_ROOT
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		local hub = br.nodes[1].id
		for _, node in ipairs(br.nodes) do
			Runes.byId[node.id] = node
			node.branch = br.key
		end
		Runes.prev[hub] = "root"
		-- the hub forks into the branch's lines (Data/Runes.lua ns.RUNE_TREE)
		for _, line in ipairs(ns.RUNE_TREE[br.key]) do
			local prev = hub
			for _, id in ipairs(line) do
				Runes.prev[id] = prev
				prev = id
			end
		end
	end
	for id in pairs(Runes.byId) do
		if id ~= "root" and not Runes.prev[id] then error("rune " .. id .. " is not on the tree") end
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

-- The rune to buy next on the way to `id` (id itself when it is available),
-- and the gold the whole remaining chain costs.
function Runes.NextStepTo(id)
	local chain = {}
	local cur = id
	while cur and Runes.Level(cur) == 0 do
		table.insert(chain, 1, cur)
		cur = Runes.prev[cur]
	end
	if #chain == 0 then return nil, 0 end
	local total = 0
	for _, rid in ipairs(chain) do total = total + (Runes.NextCost(rid) or 0) end
	return chain[1], total
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
		return false, "이전 룬을 먼저 배워야 합니다."
	end
	local cost = Runes.NextCost(id)
	if not cost then
		return false, "이미 최대 레벨입니다."
	end
	if not ns.SpendGold(cost) then
		return false, "골드가 부족합니다."
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
		return string.format("%s 유형의 적 %s마리 처치", ns.N(ns.MTYPE[u.type]), ns.U.fmt(u.n))
	end
	return "3막의 마지막 우두머리 처치"
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
				ns.Toast(string.format("새 동료 획득: %s", ns.N(pet.name)))
			end
		end
	end
	if changed then
		Runes.Invalidate()
		ns.Fire("PETS")
	end
end
