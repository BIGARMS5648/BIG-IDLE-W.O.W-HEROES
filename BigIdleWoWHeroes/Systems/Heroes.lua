-- Hero roster: unlocking, experience, talent tree, skill loadout and the party.
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

------------------------------------------------------------------------
-- Unlocking
------------------------------------------------------------------------
function Heroes.UnlockCost()
	if Heroes.Count() == 0 then return 0 end
	return ns.HERO_UNLOCK_COST
end

local function create(id)
	local c = ns.CLASSES[id]
	local h = { level = 1, xp = 0, tree = {}, skills = {}, gear = {} }
	-- starter weapon so a fresh hero is never empty-handed
	h.gear.mh = ns.Items.New("mh", 1, 1, c.mh[1])
	-- first skill is learned and slotted for free
	local first = c.tree[1][3]
	h.tree[13] = 1
	h.skills[1] = first.s
	ns.db.heroes[id] = h
	return h
end

function Heroes.Unlock(id)
	if not ns.CLASSES[id] then return false end
	if ns.db.heroes[id] then return false end
	local cost = Heroes.UnlockCost()
	if cost > 0 and not ns.SpendGold(cost) then
		return false, ns.T("골드가 부족합니다.", "Not enough gold.")
	end
	create(id)
	ns.Stats.Invalidate(id)
	if Heroes.PartyCount() < ns.PartyLimit() then
		Heroes.Deploy(id)
	end
	ns.Fire("HEROES")
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
function Heroes.PointsSpent(id)
	local h = ns.db.heroes[id]
	local n = 0
	for _, v in pairs(h.tree) do
		n = n + v
	end
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

function Heroes.SpendPoint(id, tier, n)
	local h = ns.db.heroes[id]
	local node = ns.CLASSES[id].tree[tier] and ns.CLASSES[id].tree[tier][n]
	if not node then return false end
	if Heroes.PointsFree(id) <= 0 then
		return false, ns.T("기술 점수가 없습니다.", "No skill points left.")
	end
	if not Heroes.TierOpen(id, tier) then
		return false, string.format(ns.T("기술 점수를 %d점 사용해야 열립니다.", "Spend %d skill points to unlock this tier."), (tier - 1) * ns.TREE_TIER_POINTS)
	end
	local key = tier * 10 + n
	local lvl = h.tree[key] or 0
	if lvl >= node.max then
		return false, ns.T("이미 최대 레벨입니다.", "Already at maximum level.")
	end
	h.tree[key] = lvl + 1
	if node.s and lvl == 0 then
		-- newly learned active skill: slot it if there is room
		Heroes.EquipSkill(id, node.s, true)
	end
	ns.Stats.Invalidate(id)
	ns.Fire("TREE", id)
	return true
end

function Heroes.ResetCost(id)
	local l = ns.db.heroes[id].level
	return floor(20 * l ^ 1.6)
end

function Heroes.ResetTree(id)
	local h = ns.db.heroes[id]
	if Heroes.PointsSpent(id) == 0 then return false end
	if not ns.SpendGold(Heroes.ResetCost(id)) then
		return false, ns.T("골드가 부족합니다.", "Not enough gold.")
	end
	h.tree = {}
	h.skills = {}
	ns.Stats.Invalidate(id)
	ns.Fire("TREE", id)
	return true
end

------------------------------------------------------------------------
-- Skills
------------------------------------------------------------------------
-- Points invested in a skill (0 = not learned).
function Heroes.SkillPoints(id, skillId)
	local c = ns.CLASSES[id]
	local h = ns.db.heroes[id]
	for t = 1, #c.tree do
		for n = 1, #c.tree[t] do
			if c.tree[t][n].s == skillId then
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
		return false, ns.T("아직 배우지 않은 기술입니다.", "You have not learned that skill.")
	end
	if Heroes.IsSkillEquipped(id, skillId) then return true end
	local slots = ns.SkillSlots()
	for i = 1, slots do
		if not h.skills[i] then
			h.skills[i] = skillId
			ns.Fire("SKILLS", id)
			return true
		end
	end
	if quiet then return false end
	return false, ns.T("기술 슬롯이 가득 찼습니다. 다른 기술을 먼저 해제하세요.", "All skill slots are in use. Remove another skill first.")
end

function Heroes.UnequipSkill(id, skillId)
	local h = ns.db.heroes[id]
	local i = Heroes.IsSkillEquipped(id, skillId)
	if not i then return false end
	h.skills[i] = nil
	-- keep the list packed
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
	local slots = ns.SkillSlots()
	for i = 1, slots do
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

function Heroes.Deploy(id, slot)
	local db = ns.db
	if not db.heroes[id] then return false end
	if Heroes.PartySlot(id) then return true end
	local role = ns.CLASSES[id].role
	if slot then
		if ns.PARTY_ROLES[slot] ~= role then
			return false, ns.T("그 자리는 다른 역할 전용입니다.", "That slot is reserved for another role.")
		end
	else
		for i = 1, ns.PARTY_SIZE do
			if ns.PARTY_ROLES[i] == role and not db.party[i] then
				slot = i
				break
			end
		end
		if not slot then
			return false, string.format(ns.T("%s 자리가 모두 찼습니다. 먼저 다른 영웅을 내보내세요.", "All %s slots are taken. Remove another hero first."), ns.N(ns.ROLE[role].name))
		end
	end
	if not db.party[slot] and Heroes.PartyCount() >= ns.PartyLimit() then
		return false, ns.T("파티 슬롯이 부족합니다. '지휘의 룬'을 배우세요.", "No free party slot. Learn a Rune of Command.")
	end
	db.party[slot] = id
	ns.Fire("PARTY")
	return true
end

function Heroes.Withdraw(id)
	local slot = Heroes.PartySlot(id)
	if not slot then return false end
	if Heroes.PartyCount() <= 1 then
		return false, ns.T("파티에는 최소 한 명이 있어야 합니다.", "The party needs at least one hero.")
	end
	ns.db.party[slot] = false
	ns.Fire("PARTY")
	return true
end

-- Enforce the party limit (for example after a save edit).
function Heroes.ValidateParty()
	local db = ns.db
	local limit = ns.PartyLimit()
	local n = 0
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id then
			if not db.heroes[id] or ns.CLASSES[id].role ~= ns.PARTY_ROLES[i] or n >= limit then
				db.party[i] = false
			else
				n = n + 1
			end
		end
	end
	if n == 0 then
		for _, id in ipairs(ns.CLASS_ORDER) do
			if db.heroes[id] then
				Heroes.Deploy(id)
				break
			end
		end
	end
end
