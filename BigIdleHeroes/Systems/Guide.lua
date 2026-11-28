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
-- where it is used, so 추출 needs a filled socket. (행운의 인장 is a forge
-- function of its own: like the others, it is worth it from its level on.)
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
	end
	return true
end

-- A forge function that can be unlocked right now and is worth it: the red
-- dot on its menu, its list row and its unlock buttons
function Guide.CanUnlock(op)
	local d = ns.Forge.OpDef(op)
	return d and not ns.Forge.Unlocked(op) and ns.db.forge.level >= d.level and ns.CanAfford(d.cost)
		and Guide.UnlockUseful(op) or false
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

Guide.LAST_SEAT_CLEARS = 10 -- 일반 stages cleared before the last seat's rune is suggested

local function nextCommandRune()
	local id = ns.Runes.FirstFor("party")
	return id and ns.Runes.byId[id]
end

-- The role of the next hero for the party (within the party limit), the
-- healer third: before it a tank and a damage dealer (whichever the party
-- lacks, the tank first), after it the damage dealers. A damage dealer first
-- goes tank, healer, damage, damage; a tank first damage, healer, damage,
-- damage; a healer first tank, damage, damage, damage.
local function missingRole()
	local db = ns.db
	local n = ns.Heroes.PartyCount()
	if n >= ns.PartyLimit() then return nil end
	local have = { TANK = 0, DPS = 0, HEALER = 0 }
	for i = 1, ns.PARTY_SIZE do
		if db.party[i] then
			local r = ns.PARTY_ROLES[i]
			have[r] = have[r] + 1
		end
	end
	local room = { TANK = 0, DPS = 0, HEALER = 0 }
	for _, r in ipairs(ns.PARTY_ROLES) do room[r] = room[r] + 1 end
	if n >= 2 and have.HEALER < room.HEALER then return "HEALER" end
	if have.TANK < room.TANK then return "TANK" end
	if have.DPS < room.DPS then return "DPS" end
	if have.HEALER < room.HEALER then return "HEALER" end
end
Guide.MissingRole = missingRole

-- The step that brings the next hero into the party: a waiting hero sent
-- out, a hero recruited, or (every seat taken) the rune on the way to the
-- next party seat. nil when there is none.
local function nextRecruit(heroes)
	local role = missingRole()
	if role then
		-- a waiting hero of that role goes out first (no gold)
		for _, id in ipairs(ns.Heroes.List()) do
			if not ns.Heroes.PartySlot(id) and ns.Heroes.Role(id) == role and ns.Heroes.FreeSlot(role) then
				return { text = ns.Heroes.ShortName(id) .. " 출전시키기", tab = "party", act = function() ns.Heroes.Deploy(id) end, cost = 0 }
			end
		end
		if heroes >= ns.ROSTER_MAX then return nil end
		local cost = ns.Heroes.CreateCost()
		return { text = string.format("%s 영웅 모집하기 (%s G)", ns.ROLE[role].name, ns.U.fmt(cost)),
			tab = "hero", create = role, wait = not ns.CanAfford(cost), cost = cost }
	end
	local cmd = nextCommandRune()
	-- the last seat's rune (60,000 gold) waits until 일반 1-10 is cleared
	if ns.PartyLimit() > ns.PARTY_BASE and (ns.db.prog[1] or 0) < Guide.LAST_SEAT_CLEARS then return nil end
	if cmd and ns.PartyLimit() < ns.PARTY_SIZE then
		local step = ns.Runes.NextStepTo(cmd.id)
		if step then
			local cost = ns.Runes.NextCost(step)
			return { text = "룬 배우기: " .. ns.N(ns.Runes.byId[step].name), tab = "runes", rune = step,
				wait = not ns.CanAfford(cost), cost = cost }
		end
	end
end

-- The clockwork runes of the monster and boss chests: on the way to them
-- with the next hero (see candidates).
Guide.CLOCK_RUNES = { 13002, 15001 }

Guide.CLOCK_AFTER_HEROES = 3 -- party heroes before the clockwork runes join

-- The next rune on the way to a rune not learned yet (a clockwork rune,
-- 각성의 룬), as a goal.
local function clockStep(rid)
	local node = ns.Runes.byId[rid]
	if not node or ns.Runes.Level(rid) >= node.max then return nil end
	local step = ns.Runes.NextStepTo(rid)
	if not step then return nil end
	local cost = ns.Runes.NextCost(step)
	return { text = "룬 배우기: " .. ns.N(ns.Runes.byId[step].name), tab = "runes", rune = step,
		wait = not ns.CanAfford(cost), cost = cost }
end

-- 각성의 룬 (one more skill slot for every hero): wanted once a party hero
-- has reached the level of the skill that has no slot yet (the 3rd skill,
-- level 10).
function Guide.WantsSkillSlot()
	local slots = ns.SkillSlots()
	local id = ns.Runes.FirstFor("skillSlot")
	if not id or slots >= 3 then return nil end
	local need = ns.SKILL_UNLOCK[slots + 1]
	if not need then return nil end
	for _, hid in ipairs(partyHeroes()) do
		if ns.db.heroes[hid].level >= need then return id end
	end
	return nil
end

-- The first goals, in turn: the heroes up to the third alone; then the
-- monster chest's clockwork rune alone; then the step that brings the next
-- hero in, the boss chest's clockwork rune and (once a hero has a skill with
-- no slot) 각성의 룬 side by side, the cheapest first (one goal per rune).
local function firstGoals(heroes)
	local recruit = nextRecruit(heroes)
	if ns.Heroes.PartyCount() < Guide.CLOCK_AFTER_HEROES then
		return recruit and { recruit } or {}
	end
	local monster = clockStep(Guide.CLOCK_RUNES[1])
	if monster then return { monster } end
	local list, seen = {}, {}
	if recruit then
		list[#list + 1] = recruit
		if recruit.rune then seen[recruit.rune] = true end
	end
	local runes = {}
	for i = 2, #Guide.CLOCK_RUNES do runes[#runes + 1] = Guide.CLOCK_RUNES[i] end
	runes[#runes + 1] = Guide.WantsSkillSlot()
	for _, rid in ipairs(runes) do
		local g = clockStep(rid)
		if g and not seen[g.rune] then
			seen[g.rune] = true
			list[#list + 1] = g
		end
	end
	table.sort(list, function(a, b)
		if (a.cost or 0) ~= (b.cost or 0) then return (a.cost or 0) < (b.cost or 0) end
		return (a.create or a.act) and not (b.create or b.act) or false
	end)
	return list
end

-- Candidate goals in order of usefulness. A goal with wait = true is shown
-- only when nothing actionable comes after it. Early on (until all five
-- party seats are filled) the next hero comes first: its step leads the
-- list when it can be done now, and while its gold is saved up nothing else
-- that costs gold is suggested (only what is free, and the bag's 분해 when
-- it is full).
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
	-- the next hero and the clockwork runes lead: those that can be done now
	-- (the cheapest first); none of them yet: the cheapest is saved up for
	-- and nothing else that costs gold is suggested
	local ready, saveFor = {}, nil
	for _, g in ipairs(firstGoals(heroes)) do
		if g.wait then saveFor = saveFor or g else ready[#ready + 1] = g end
	end
	local saving = #ready == 0 and saveFor ~= nil
	local firstRune = {}
	for _, g in ipairs(ready) do
		add(g)
		if g.rune then firstRune[g.rune] = true end
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
	if not ns.Forge.Unlocked("smelt") and not saving then
		add({ text = "분해 해금하기 (장비 > 가방, 10 G)", tab = "equip", sub = "bag", wait = not ns.CanAfford(10) })
	end
	if saveFor then
		add(saveFor)
		if saveFor.rune then firstRune[saveFor.rune] = true end
	end
	for _, op in ipairs(saving and {} or ns.FORGE_OPS) do
		if not ns.Forge.Unlocked(op.key) and db.forge.level >= op.level and Guide.UnlockUseful(op.key) then
			-- where its button is: 분해 under the bag, the rest on the forge screen
			if op.key == "smelt" then
				add({ text = string.format("'%s' 해금 (장비 > 가방, %s G)", ns.N(op.name), ns.U.fmt(op.cost)), tab = "equip", sub = "bag",
					wait = not ns.CanAfford(op.cost) })
			else
				local where = ({ remove = "보석", seal = "행운의 인장", fuse = "융합", craft = "제작",
					gem = "보석", ench = "마법부여", insc = "주문각인" })[op.key] or ""
				add({ text = string.format("'%s' 해금 (대장간 > %s, %s G)", ns.N(op.name), where, ns.U.fmt(op.cost)), tab = "forge",
					sub = op.key == "remove" and "gem" or op.key, wait = not ns.CanAfford(op.cost) })
			end
			break
		end
	end
	local rid, rcost = cheapestRune()
	if rid and ns.CanAfford(rcost) and not saving and not firstRune[rid] then
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
	-- equipment: a better item for the party (chests waiting are opened on
	-- the battle window: no dot for them)
	if next(Guide.UpgradeHeroes()) then b.equip = true end
	-- forge: a function that can be unlocked now (분해 is unlocked under the bag)
	for _, op in ipairs(ns.FORGE_OPS) do
		if Guide.CanUnlock(op.key) then
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
-- (a skill put on or taken off changes what 재사용 대기시간 감소 is worth)
for _, ev in ipairs({ "HEROES", "PARTY", "LEVEL", "BAG", "GEAR", "RESET", "STATS", "SKILLS" }) do
	ns.On(ev, function() upCache, upHeroes = nil, nil end)
end
