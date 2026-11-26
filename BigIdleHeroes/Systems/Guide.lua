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
local upCache, upHeroes

function Guide.UpgradeHeroes()
	if upHeroes then return upHeroes end
	upHeroes = {}
	for _, id in ipairs(partyHeroes()) do
		for _, it in ipairs(ns.db.bag) do
			local r = ns.Items.Compare(id, it)
			if r and r > ns.Items.UPGRADE then
				upHeroes[id] = true
				break
			end
		end
	end
	return upHeroes
end

function Guide.UpgradeCount()
	if upCache then return upCache end
	upCache = ns.U.count(Guide.UpgradeHeroes())
	return upCache
end

-- Does this hero have something to do (points to spend or a better item)?
-- Whether unlocking a forge function now leads anywhere: its button lives
-- where it is used, so 추출 needs a filled socket and 굴리기 a lucky seal.
function Guide.UnlockUseful(op)
	if op == "remove" then
		local function filled(it)
			for _, k in ipairs({ "g", "e", "i" }) do
				for _, e in ipairs(it[k] or {}) do if e then return true end end
			end
			return false
		end
		for _, it in ipairs(ns.db.bag) do if filled(it) then return true end end
		for _, id in ipairs(partyHeroes()) do
			for _, it in pairs(ns.db.heroes[id].gear) do if filled(it) then return true end end
		end
		return false
	elseif op == "seal" then
		for _, s in ipairs(ns.SEAL) do if ns.MatCount(s.mat) > 0 then return true end end
		return false
	end
	return true
end

-- Talent or skill points to spend (the hero screen's red dots); better gear
-- shows on the equipment screen instead.
function Guide.HeroNeeds(id)
	return ns.Heroes.PointsFree(id) > 0 or ns.Heroes.SkillPointsFree(id) > 0
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
	local id = ns.Runes.FirstFor("party")
	return id and ns.Runes.byId[id]
end

-- A role the party still has an open slot for (within the party limit).
local function missingRole()
	local db = ns.db
	if ns.Heroes.PartyCount() >= ns.PartyLimit() then return nil end
	for i = 1, ns.PARTY_SIZE do
		if not db.party[i] then return ns.PARTY_ROLES[i] end
	end
end
Guide.MissingRole = missingRole

-- Candidate goals in order of usefulness. A goal with wait = true is shown
-- only when nothing actionable comes after it.
-- Goal: { text, tab, hero, sub, act = fn, create = role|true, rune, wait, done }
local function candidates()
	local db = ns.db
	local out = {}
	local function add(g) out[#out + 1] = g end
	local heroes = ns.Heroes.Count()
	if heroes == 0 then
		add({ text = "첫 영웅을 만드세요 (무료)", tab = "hero", create = true })
		return out
	end
	for _, id in ipairs(partyHeroes()) do
		local free = ns.Heroes.PointsFree(id)
		if free > 0 then
			add({ text = string.format("%s: 특성 점수 %d점 쓰기", ns.Heroes.ShortName(id), free),
				tab = "hero", hero = id, sub = "tree" })
			break
		end
	end
	for _, id in ipairs(partyHeroes()) do
		local free = ns.Heroes.SkillPointsFree(id)
		if free > 0 then
			add({ text = string.format("%s: 기술 점수 %d점 쓰기", ns.Heroes.ShortName(id), free),
				tab = "hero", hero = id, sub = "skills" })
			break
		end
	end
	local chests = ns.Loot.Count()
	if chests >= 3 and ns.Items.BagFree() > 0 then
		-- (all at once with its rune, else one)
		local all = ns.Loot.CanOpen("all")
		add({ text = all and string.format("상자 %d개 열기", chests) or "상자 열기", tab = "equip", sub = "bag",
			act = function() ns.Loot.OpenByHand(nil, all and "all" or "one") end })
	end
	if ns.Items.BagFree() <= 3 then
		if not ns.Forge.Unlocked("smelt") then
			add({ text = "가방이 가득 찼어요: 분해 해금 (10 G)", tab = "equip", sub = "bag", wait = not ns.CanAfford(10) })
		elseif #ns.Forge.PickByQuality(ns.U.clamp(db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)) > 0 then -- the bag's 분해 등급
			add({ text = "가방이 가득 찼어요: 일괄 분해", tab = "equip", sub = "bag", bulk = true })
		else
			add({ text = "가방이 가득 찼어요: 분해 기준 등급 올리기", tab = "equip", sub = "bag", bulk = true })
		end
	end
	if Guide.UpgradeCount() > 0 then
		add({ text = "더 좋은 장비가 있어요: 일괄 장착",
			act = function()
				ns.Items.AutoEquipParty()
			end })
	end
	if not ns.Forge.Unlocked("smelt") then
		add({ text = "분해 해금하기 (장비 > 가방, 10 G)", tab = "equip", sub = "bag", wait = not ns.CanAfford(10) })
	end
	local limit = ns.PartyLimit()
	local role = missingRole()
	if role then
		-- a bench hero could fill the slot
		local bench
		for _, id in ipairs(ns.Heroes.List()) do
			if not ns.Heroes.PartySlot(id) and ns.Heroes.FreeSlot(ns.Heroes.Role(id)) then bench = id break end
		end
		if bench then
			add({ text = ns.Heroes.ShortName(bench) .. " 출전시키기", tab = "party", act = function() ns.Heroes.Deploy(bench) end })
		elseif heroes < ns.ROSTER_MAX then
			local cost = ns.Heroes.CreateCost()
			add({ text = string.format("%s 영웅 모집하기 (%s G)", ns.ROLE[role].name, ns.U.fmt(cost)),
				tab = "hero", create = role, wait = not ns.CanAfford(cost) })
		end
	end
	local cmd = nextCommandRune()
	if cmd and limit < ns.PARTY_SIZE then
		local step = ns.Runes.NextStepTo(cmd.id)
		if step then
			local cost = ns.Runes.NextCost(step)
			add({ text = "룬 배우기: " .. ns.N(ns.Runes.byId[step].name), tab = "runes", rune = step, wait = not ns.CanAfford(cost) })
		end
	end
	for _, op in ipairs(ns.FORGE_OPS) do
		if not ns.Forge.Unlocked(op.key) and db.forge.level >= op.level and Guide.UnlockUseful(op.key) then
			-- where its button is: 분해 under the bag, the rest on the forge screen
			if op.key == "smelt" then
				add({ text = string.format("'%s' 해금 (장비 > 가방, %s G)", ns.N(op.name), ns.U.fmt(op.cost)), tab = "equip", sub = "bag",
					wait = not ns.CanAfford(op.cost) })
			else
				local where = ({ remove = "보석", seal = "재료", fuse = "융합", craft = "제작",
					gem = "보석", ench = "마법부여", insc = "주문각인" })[op.key] or ""
				add({ text = string.format("'%s' 해금 (대장간 > %s, %s G)", ns.N(op.name), where, ns.U.fmt(op.cost)), tab = "forge",
					sub = op.key == "remove" and "gem" or op.key, wait = not ns.CanAfford(op.cost) })
			end
			break
		end
	end
	local rid, rcost = cheapestRune()
	if rid and ns.CanAfford(rcost) then
		add({ text = "룬 배우기: " .. ns.N(ns.Runes.byId[rid].name), tab = "runes", rune = rid })
	end
	-- the endless tower, once open: go there, then climb it
	if ns.Tower.Open() and not db.tower.on then
		add({ text = "무한의 탑 도전하기", tab = "map", tower = true })
	end
	if db.tower.on then
		add({ text = string.format("무한의 탑 %d층 공략 중 (최고 %d층)", db.tower.floor, db.tower.best or 0), tab = "map", done = true })
		return out
	end
	local stg = ns.Stage(db.stage.diff, db.stage.idx)
	if stg.raid then
		add({ text = "공격대 우두머리 처치: " .. ns.N(stg.boss.name), tab = "map", done = true })
	else
		add({ text = "지금 지역 공략 중: " .. ns.N(stg.name), tab = "map", done = true })
	end
	return out
end
Guide.Candidates = candidates -- every goal there is now, best first (the checks read their texts)

local function compute()
	local list = candidates()
	for _, g in ipairs(list) do
		if not g.wait and not g.done then return g end
	end
	for _, g in ipairs(list) do
		if g.wait then return g end
	end
	return list[#list]
end

local function computeBadges()
	local db = ns.db
	local b = {}
	-- party: an empty slot a waiting hero could fill right now; hero: a
	-- missing role that a new hero (made on the hero screen) could fill
	local create
	if missingRole() then
		for _, id in ipairs(ns.Heroes.List()) do
			if not ns.Heroes.PartySlot(id) and ns.Heroes.FreeSlot(ns.Heroes.Role(id)) then b.party = true end
		end
		create = ns.Heroes.Count() < ns.ROSTER_MAX and ns.CanAfford(ns.Heroes.CreateCost())
	end
	-- hero: party heroes with talent or skill points to spend
	local n = 0
	for _, id in ipairs(partyHeroes()) do
		if ns.Heroes.PointsFree(id) + ns.Heroes.SkillPointsFree(id) > 0 then n = n + 1 end
	end
	if n > 0 then b.hero = n elseif create then b.hero = true end
	-- equipment: chests waiting, a better item for the party
	local chests = ns.Loot.Count()
	if chests > 0 then b.equip = chests end
	if not b.equip and next(Guide.UpgradeHeroes()) then b.equip = true end
	-- forge: a function that can be unlocked now (분해 is unlocked under the bag)
	for _, op in ipairs(ns.FORGE_OPS) do
		if not ns.Forge.Unlocked(op.key) and db.forge.level >= op.level and ns.CanAfford(op.cost) and Guide.UnlockUseful(op.key) then
			if op.key == "smelt" then b.equip = b.equip or true else b.forge = true end
		end
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

for _, ev in ipairs({ "HEROES", "PARTY", "LEVEL", "TREE", "SKILLS", "BAG", "GEAR", "CHESTS", "RUNES", "FORGE", "PROGRESS", "RESET" }) do
	ns.On(ev, Guide.Invalidate)
end
for _, ev in ipairs({ "HEROES", "PARTY", "LEVEL", "BAG", "GEAR", "RESET", "STATS" }) do
	ns.On(ev, function() upCache, upHeroes = nil, nil end)
end
