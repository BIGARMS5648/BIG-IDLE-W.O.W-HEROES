-- "Next goal" guide and notification badges.
-- The guide always names the single most useful thing to do next and how to
-- do it; badges mark which menu has something waiting.
local _, ns = ...

local Guide = {}
ns.Guide = Guide

local cache, badges
local stamp = 0

local function partyHeroes()
	local out = {}
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id and ns.db.heroes[id] then out[#out + 1] = id end
	end
	return out
end

-- Heroes in the party who would gain from an item in the bags. Comparing
-- gear is not free, so the answer is kept until the bags or gear change.
local upCache

function Guide.UpgradeCount()
	if upCache then return upCache end
	local n = 0
	for _, id in ipairs(partyHeroes()) do
		for _, it in ipairs(ns.db.bag) do
			if not it.lock then
				local r = ns.Items.Compare(id, it)
				if r and r > 1.01 then
					n = n + 1
					break
				end
			end
		end
	end
	upCache = n
	return n
end

local function cheapestRune()
	local bestId, bestCost
	for id in pairs(ns.Runes.byId) do
		if ns.Runes.Available(id) then
			local c = ns.Runes.NextCost(id)
			if c and (not bestCost or c < bestCost) then bestId, bestCost = id, c end
		end
	end
	return bestId, bestCost
end

local function nextCommandRune()
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		for _, node in ipairs(br.nodes) do
			if node.stat == "party" and ns.Runes.Level(node.id) == 0 then return node end
		end
	end
end


-- Returns { text = string, tab = key, hero = id, sub = key, act = fn, done = bool }
local function compute()
	local db = ns.db
	local heroes = ns.Heroes.Count()
	if heroes == 0 then
		return { text = "첫 영웅을 만드세요 (무료)", tab = "party", create = true }
	end
	for _, id in ipairs(partyHeroes()) do
		local free = ns.Heroes.PointsFree(id)
		if free > 0 then
			return { text = string.format("%s: 기술 점수 %d점 사용", ns.Heroes.Name(id), free),
				tab = "hero", hero = id, sub = "tree" }
		end
	end
	local chests = ns.Loot.Count()
	if chests >= 3 and ns.Items.BagFree() > 0 then
		return { text = string.format("상자 %d개 열기", chests), tab = "bag",
			act = function() ns.Loot.OpenAll() end }
	end
	if ns.Items.BagFree() <= 3 and ns.Forge.Unlocked("smelt") then
		return { text = "가방이 가득 찼어요: 일괄 분해", tab = "bag" }
	end
	if Guide.UpgradeCount() > 0 then
		return { text = "더 좋은 장비가 있어요: 일괄 장착", tab = "hero",
			act = function()
				for _, id in ipairs(partyHeroes()) do ns.Items.AutoEquip(id) end
			end }
	end
	if not ns.Forge.Unlocked("smelt") and db.gold >= 10 then
		return { text = "용광로의 '용해' 해금 (10 G)", tab = "forge", sub = "smelt" }
	end
	local limit = ns.PartyLimit()
	if ns.Heroes.PartyCount() < limit then
		-- a bench hero could fill the slot
		for _, id in ipairs(ns.Heroes.List()) do
			if not ns.Heroes.PartySlot(id) and ns.Heroes.FreeSlot(ns.Heroes.Role(id)) then
				return { text = ns.Heroes.Name(id) .. " 출전시키기", tab = "party",
					act = function() ns.Heroes.Deploy(id) end }
			end
		end
		if heroes < ns.ROSTER_MAX then
			local cost = ns.Heroes.CreateCost()
			local role
			for i = 1, ns.PARTY_SIZE do
				if not db.party[i] then role = ns.PARTY_ROLES[i] break end
			end
			local rn = role and ns.ROLE[role].name or "영웅"
			return { text = string.format("%s 영웅 만들기 (%s G)", rn, ns.U.fmt(cost)),
				tab = "party", create = true, wait = not ns.CanAfford(cost) }
		end
	end
	local cmd = nextCommandRune()
	if cmd and limit < ns.PARTY_SIZE then
		local cost = ns.Runes.NextCost(cmd.id)
		return { text = string.format("지휘의 룬: 파티 %d명으로 (%s G)", limit + 1, ns.U.fmt(cost)),
			tab = "runes", rune = cmd.id, wait = not (ns.Runes.Available(cmd.id) and ns.CanAfford(cost)) }
	end
	for _, op in ipairs(ns.FORGE_OPS) do
		if not ns.Forge.Unlocked(op.key) and db.forge.level >= op.level and ns.CanAfford(op.cost) then
			return { text = string.format("용광로 '%s' 해금", ns.N(op.name)), tab = "forge", sub = op.key }
		end
	end
	local rid, rcost = cheapestRune()
	if rid and ns.CanAfford(rcost) then
		local n = ns.Runes.byId[rid].name
		return { text = "룬 배우기: " .. ns.N(n), tab = "runes", rune = rid }
	end
	local st = ns.Combat.state
	local stg = ns.Stage(db.stage.diff, db.stage.idx)
	if stg.raid then
		return { text = "공격대 우두머리 처치: " .. ns.N(stg.boss.name), tab = "map", done = true }
	end
	return { text = "다음 지역으로: " .. ns.N(stg.name), tab = "map", done = true, phase = st.phase }
end

local function computeBadges()
	local db = ns.db
	local b = {}
	-- party: an empty slot that could be filled right now
	if ns.Heroes.PartyCount() < ns.PartyLimit() then
		local can = ns.Heroes.Count() < ns.ROSTER_MAX and ns.CanAfford(ns.Heroes.CreateCost())
		for _, id in ipairs(ns.Heroes.List()) do
			if not ns.Heroes.PartySlot(id) and ns.Heroes.FreeSlot(ns.Heroes.Role(id)) then can = true end
		end
		b.party = can or nil
	end
	-- hero: skill points or upgrades for someone in the party
	local pts = 0
	for _, id in ipairs(partyHeroes()) do
		if ns.Heroes.PointsFree(id) > 0 then pts = pts + 1 end
	end
	local up = Guide.UpgradeCount()
	if pts + up > 0 then b.hero = pts + up end
	-- bags: chests waiting
	local chests = ns.Loot.Count()
	if chests > 0 then b.bag = chests end
	-- forge: an operation that can be unlocked now
	for _, op in ipairs(ns.FORGE_OPS) do
		if not ns.Forge.Unlocked(op.key) and db.forge.level >= op.level and ns.CanAfford(op.cost) then b.forge = true end
	end
	-- runes: something affordable
	local _, rcost = cheapestRune()
	if rcost and ns.CanAfford(rcost) then b.runes = true end
	return b
end

function Guide.Invalidate()
	cache, badges = nil, nil
end

local function fresh()
	local now = GetTime and GetTime() or 0
	if not cache or now - stamp > 1 then
		stamp = now
		cache = compute()
		badges = computeBadges()
	end
end

function Guide.Current()
	fresh()
	return cache
end

function Guide.Badges()
	fresh()
	return badges
end

for _, ev in ipairs({ "HEROES", "PARTY", "LEVEL", "TREE", "BAG", "GEAR", "CHESTS", "RUNES", "FORGE", "PROGRESS", "RESET" }) do
	ns.On(ev, Guide.Invalidate)
end
for _, ev in ipairs({ "HEROES", "PARTY", "LEVEL", "BAG", "GEAR", "RESET" }) do
	ns.On(ev, function() upCache = nil end)
end
