-- Hero roster. A hero is an individual: created as one specialization of a
-- class, given a random name, and identified by its own id ("h1", "h2", ...).
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Heroes = {}
ns.Heroes = Heroes

function Heroes.Get(id)
	return ns.db.heroes[id]
end

function Heroes.Count()
	return ns.U.count(ns.db.heroes)
end

function Heroes.Spec(id)
	local h = ns.db.heroes[id]
	return h and ns.SPECS[h.spec]
end

function Heroes.Class(id)
	local sp = Heroes.Spec(id)
	return sp and ns.CLASSES[sp.class]
end

function Heroes.Role(id)
	local sp = Heroes.Spec(id)
	return sp and sp.role
end

function Heroes.Name(id)
	local h = ns.db.heroes[id]
	return h and ns.N(h.name) or "?"
end

-- "Arden" in class color
function Heroes.ColorName(id)
	local c = Heroes.Class(id)
	return ns.U.col(c and c.hex or "ffffff", Heroes.Name(id))
end

-- Roster in creation order.
function Heroes.List()
	local list = {}
	for id in pairs(ns.db.heroes) do list[#list + 1] = id end
	table.sort(list, function(a, b)
		return (tonumber(a:sub(2)) or 0) < (tonumber(b:sub(2)) or 0)
	end)
	return list
end

------------------------------------------------------------------------
-- Creating and dismissing
------------------------------------------------------------------------
function Heroes.CreateCost()
	local n = Heroes.Count() + 1
	return ns.HERO_COST[n] or ns.HERO_COST[#ns.HERO_COST]
end

local function takenNames()
	local t = {}
	for _, h in pairs(ns.db.heroes) do
		t[ns.N(h.name)] = true
	end
	return t
end

-- Builds the record without charging anything (also used by save migration).
function Heroes.NewRecord(specId)
	local sp = ns.SPECS[specId]
	local db = ns.db
	db.heroSeq = (db.heroSeq or 0) + 1
	local h = {
		id = "h" .. db.heroSeq, spec = specId, name = ns.Names.Roll(takenNames()),
		level = 1, xp = 0, tree = {}, skills = {}, gear = {},
	}
	-- starter weapon so a fresh hero is never empty-handed
	h.gear.mh = ns.Items.New("mh", 1, 1, sp.mh[1])
	-- the first skill is learned and slotted for free
	h.tree[13] = 1
	h.skills[1] = sp.tree[1][3].s
	db.heroes[h.id] = h
	return h
end

function Heroes.Create(specId)
	local sp = ns.SPECS[specId]
	if not sp then return false end
	if Heroes.Count() >= ns.ROSTER_MAX then
		return false, string.format("영웅은 최대 %d명까지 보유할 수 있습니다.", ns.ROSTER_MAX)
	end
	local cost = Heroes.CreateCost()
	if cost > 0 and not ns.SpendGold(cost) then
		return false, "골드가 부족합니다."
	end
	local h = Heroes.NewRecord(specId)
	ns.Stats.Invalidate(h.id)
	Heroes.Deploy(h.id) -- joins the party if its role slot is free
	ns.Fire("HEROES")
	return true, h.id
end

function Heroes.RerollName(id)
	local h = ns.db.heroes[id]
	if not h then return false end
	h.name = ns.Names.Roll(takenNames())
	ns.Fire("HEROES")
	return true
end

function Heroes.Dismiss(id)
	local db = ns.db
	local h = db.heroes[id]
	if not h then return false end
	if Heroes.Count() <= 1 then
		return false, "마지막 영웅은 떠나보낼 수 없습니다."
	end
	local n = 0
	for _ in pairs(h.gear) do n = n + 1 end
	if n > ns.Items.BagFree() then
		return false, "가방에 장비를 돌려받을 자리가 부족합니다."
	end
	for _, slot in ipairs(ns.SLOTS) do
		if h.gear[slot] then db.bag[#db.bag + 1] = h.gear[slot] end
	end
	local slot = Heroes.PartySlot(id)
	if slot then db.party[slot] = false end
	db.heroes[id] = nil
	ns.Stats.Invalidate(id)
	if Heroes.PartyCount() == 0 then Heroes.ValidateParty() end
	ns.Fire("BAG")
	ns.Fire("HEROES")
	ns.Fire("PARTY")
	return true
end

------------------------------------------------------------------------
-- Experience
------------------------------------------------------------------------
function Heroes.AddXP(id, amount)
	local h = ns.db.heroes[id]
	if not h or amount <= 0 then return 0 end
	if h.level >= ns.HERO_MAX_LEVEL then
		h.xp = 0
		return 0
	end
	h.xp = h.xp + amount
	local gained = 0
	while h.level < ns.HERO_MAX_LEVEL do
		local need = ns.XPForLevel(h.level)
		if h.xp < need then break end
		h.xp = h.xp - need
		h.level = h.level + 1
		gained = gained + 1
	end
	if h.level >= ns.HERO_MAX_LEVEL then h.xp = 0 end
	if gained > 0 then
		ns.Stats.Invalidate(id)
		ns.Fire("LEVEL", id, h.level)
	end
	return gained
end

-- Experience is best near your own level: far above or below, it drops off.
function Heroes.XPFactor(heroLevel, stageLevel)
	local d = heroLevel - stageLevel
	if d > 5 then
		return max(0.05, 1 - 0.10 * (d - 5))
	elseif d < -10 then
		return max(0.25, 1 - 0.05 * (-d - 10))
	end
	return 1
end

------------------------------------------------------------------------
-- Talent tree (1 point per level)
------------------------------------------------------------------------
function Heroes.Tree(id)
	return Heroes.Spec(id).tree
end

function Heroes.PointsSpent(id)
	local n = 0
	for _, v in pairs(ns.db.heroes[id].tree) do n = n + v end
	return n
end

function Heroes.PointsFree(id)
	return ns.db.heroes[id].level - Heroes.PointsSpent(id)
end

function Heroes.TierOpen(id, tier)
	return Heroes.PointsSpent(id) >= (tier - 1) * ns.TREE_TIER_POINTS
end

function Heroes.NodeLevel(id, tier, n)
	return ns.db.heroes[id].tree[tier * 10 + n] or 0
end

function Heroes.CanSpend(id, tier, n)
	local tree = Heroes.Tree(id)
	local node = tree[tier] and tree[tier][n]
	if not node then return false end
	if Heroes.PointsFree(id) <= 0 then
		return false, "기술 점수가 없습니다."
	end
	if not Heroes.TierOpen(id, tier) then
		return false, string.format("기술 점수를 %d점 사용해야 열립니다.", (tier - 1) * ns.TREE_TIER_POINTS)
	end
	if Heroes.NodeLevel(id, tier, n) >= node.max then
		return false, "이미 최대 레벨입니다."
	end
	return true
end

function Heroes.SpendPoint(id, tier, n)
	local ok, why = Heroes.CanSpend(id, tier, n)
	if not ok then return false, why end
	local h = ns.db.heroes[id]
	local node = Heroes.Tree(id)[tier][n]
	local key = tier * 10 + n
	local lvl = h.tree[key] or 0
	h.tree[key] = lvl + 1
	if node.s and lvl == 0 then
		Heroes.EquipSkill(id, node.s, true) -- newly learned: slot it if there is room
	end
	ns.Stats.Invalidate(id)
	ns.Fire("TREE", id)
	return true
end

-- Spends every free point: first learns each reachable active skill, then
-- raises passives, then raises skills; finally fills empty skill slots.
function Heroes.AutoSpend(id)
	local tree = Heroes.Tree(id)
	local spent = 0
	for _ = 1, 400 do
		if Heroes.PointsFree(id) <= 0 then break end
		local done = false
		for pass = 1, 3 do
			for t = 1, #tree do
				if Heroes.TierOpen(id, t) then
					for n = 1, #tree[t] do
						local node = tree[t][n]
						local lvl = Heroes.NodeLevel(id, t, n)
						local want = (pass == 1 and node.s and lvl == 0) or (pass == 2 and node.p and lvl < node.max)
							or (pass == 3 and node.s and lvl < node.max)
						if want and Heroes.SpendPoint(id, t, n) then
							done = true
							spent = spent + 1
							break
						end
					end
				end
				if done then break end
			end
			if done then break end
		end
		if not done then break end
	end
	for t = 1, #tree do
		for n = 1, #tree[t] do
			local node = tree[t][n]
			if node.s and Heroes.NodeLevel(id, t, n) > 0 then Heroes.EquipSkill(id, node.s, true) end
		end
	end
	return spent
end

function Heroes.ResetCost(id)
	return floor(20 * ns.db.heroes[id].level ^ 1.6)
end

function Heroes.ResetTree(id)
	local h = ns.db.heroes[id]
	if Heroes.PointsSpent(id) == 0 then return false end
	if not ns.SpendGold(Heroes.ResetCost(id)) then
		return false, "골드가 부족합니다."
	end
	h.tree = {}
	h.skills = {}
	ns.Stats.Invalidate(id)
	ns.Fire("TREE", id)
	ns.Fire("SKILLS", id)
	return true
end

------------------------------------------------------------------------
-- Skills
------------------------------------------------------------------------
-- Points invested in a skill (0 = not learned).
function Heroes.SkillPoints(id, skillId)
	local tree = Heroes.Tree(id)
	local h = ns.db.heroes[id]
	for t = 1, #tree do
		for n = 1, #tree[t] do
			if tree[t][n].s == skillId then
				return h.tree[t * 10 + n] or 0
			end
		end
	end
	return 0
end

-- Effective level including "+All Skill Levels" gear.
function Heroes.SkillLevel(id, skillId, stats)
	local pts = Heroes.SkillPoints(id, skillId)
	if pts <= 0 then return 0 end
	stats = stats or ns.Stats.Get(id)
	return min(ns.SKILL_CAP, pts + (stats.skills or 0))
end

function Heroes.IsSkillEquipped(id, skillId)
	local sk = ns.db.heroes[id].skills
	for i = 1, 3 do
		if sk[i] == skillId then return i end
	end
end

function Heroes.EquipSkill(id, skillId, quiet)
	local h = ns.db.heroes[id]
	if Heroes.SkillPoints(id, skillId) <= 0 then
		return false, "아직 배우지 않은 기술입니다."
	end
	if Heroes.IsSkillEquipped(id, skillId) then return true end
	for i = 1, ns.SkillSlots() do
		if not h.skills[i] then
			h.skills[i] = skillId
			ns.Fire("SKILLS", id)
			return true
		end
	end
	if quiet then return false end
	return false, "기술 슬롯이 가득 찼습니다. 다른 기술을 먼저 해제하세요."
end

function Heroes.UnequipSkill(id, skillId)
	local h = ns.db.heroes[id]
	local i = Heroes.IsSkillEquipped(id, skillId)
	if not i then return false end
	h.skills[i] = nil
	local packed = {}
	for k = 1, 3 do
		if h.skills[k] then packed[#packed + 1] = h.skills[k] end
	end
	h.skills = packed
	ns.Fire("SKILLS", id)
	return true
end

-- Skills that are actually active (respects the slot limit).
function Heroes.ActiveSkills(id)
	local h = ns.db.heroes[id]
	local out = {}
	for i = 1, ns.SkillSlots() do
		local sid = h.skills[i]
		if sid and ns.SKILLS[sid] and Heroes.SkillPoints(id, sid) > 0 then
			out[#out + 1] = sid
		end
	end
	return out
end

------------------------------------------------------------------------
-- Party: slot 1 tank, slots 2-4 damage, slot 5 healer
------------------------------------------------------------------------
function Heroes.PartyCount()
	local n = 0
	for i = 1, ns.PARTY_SIZE do
		if ns.db.party[i] then n = n + 1 end
	end
	return n
end

function Heroes.PartySlot(id)
	for i = 1, ns.PARTY_SIZE do
		if ns.db.party[i] == id then return i end
	end
end

-- First free slot of a role, or nil.
function Heroes.FreeSlot(role)
	for i = 1, ns.PARTY_SIZE do
		if ns.PARTY_ROLES[i] == role and not ns.db.party[i] then return i end
	end
end

function Heroes.Deploy(id, slot)
	local db = ns.db
	if not db.heroes[id] then return false end
	if Heroes.PartySlot(id) then return true end
	local role = Heroes.Role(id)
	if slot then
		if ns.PARTY_ROLES[slot] ~= role then
			return false, "그 자리는 다른 역할 전용입니다."
		end
	else
		slot = Heroes.FreeSlot(role)
		if not slot then
			return false, string.format("%s 자리가 모두 찼습니다. 먼저 다른 영웅을 쉬게 하세요.", ns.N(ns.ROLE[role].name))
		end
	end
	if not db.party[slot] and Heroes.PartyCount() >= ns.PartyLimit() then
		return false, "파티 슬롯이 부족합니다. '지휘의 룬'을 배우세요."
	end
	db.party[slot] = id
	ns.Fire("PARTY")
	return true
end

function Heroes.Withdraw(id)
	local slot = Heroes.PartySlot(id)
	if not slot then return false end
	if Heroes.PartyCount() <= 1 then
		return false, "파티에는 최소 한 명이 있어야 합니다."
	end
	ns.db.party[slot] = false
	ns.Fire("PARTY")
	return true
end

-- Put `id` into the party in place of whoever holds a slot of its role.
function Heroes.Swap(id, slot)
	local db = ns.db
	if not db.heroes[id] or ns.PARTY_ROLES[slot] ~= Heroes.Role(id) then return false end
	local old = Heroes.PartySlot(id)
	if old then db.party[old] = false end
	db.party[slot] = id
	ns.Fire("PARTY")
	return true
end

-- Enforce roles and the party limit (after loading or editing a save).
function Heroes.ValidateParty()
	local db = ns.db
	local limit = ns.PartyLimit()
	local n = 0
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id then
			if not db.heroes[id] or Heroes.Role(id) ~= ns.PARTY_ROLES[i] or n >= limit then
				db.party[i] = false
			else
				n = n + 1
			end
		end
	end
	if n == 0 then
		local list = Heroes.List()
		if list[1] then Heroes.Deploy(list[1]) end
	end
end
