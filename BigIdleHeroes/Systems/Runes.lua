-- Account-wide bonuses: TBH's rune tree (Data/Runes.lua), bought with gold,
-- plus unlocked companions.
local _, ns = ...

local floor, min, max = math.floor, math.min, math.max

local Runes = {}
ns.Runes = Runes

-- Gold prices and gold rewards of the runes: TBH's times this (our monsters
-- pay a share of TBH's gold).
ns.RUNE_GOLD = 0.4

------------------------------------------------------------------------
-- What each of TBH's rune stats does here
------------------------------------------------------------------------
-- key: the bonus it adds to (ns.Bonus); k: what one point of TBH's value is
-- worth (TBH keeps percents in tenths); gold: a gold amount (times
-- ns.RUNE_GOLD); text: how a total reads (%s the amount); time: the amount
-- is a wait in seconds; flag: learned or not (sum: its line in the totals).
ns.RUNE_STAT = {
	AllHeroAttackDamage = { key = "atk", text = "모든 영웅 공격력 +%s", icon = "Ability_Warrior_OffensiveStance" },
	AllHeroAttackDamagePercent = { key = "atkPct", k = 0.1, text = "모든 영웅 공격력 +%s%%", icon = "Ability_Warrior_BattleShout" },
	AllHeroAttackSpeed = { key = "aspd", k = 0.1, text = "모든 영웅 공격 및 시전 속도 +%s%%", icon = "Spell_Nature_Bloodlust" },
	-- (TBH's moving speed: 우두머리 피해 here)
	AllHeroMoveSpeed = { key = "boss", k = 0.1, text = "모든 영웅 우두머리 피해 +%s%%", icon = "INV_Misc_Head_Dragon_01" },
	AllHeroArmor = { key = "armor", text = "모든 영웅 방어력 +%s", icon = "INV_Shield_06" },
	AllHeroArmorPercent = { key = "armorPct", k = 0.1, text = "모든 영웅 방어력 +%s%%", icon = "Ability_Warrior_DefensiveStance" },
	IncreaseGoldAmount = { key = "gold", k = 0.1, text = "몬스터 처치 골드 +%s%%", icon = "INV_Misc_Coin_02" },
	IncreaseExpAmount = { key = "exp", k = 0.1, text = "경험치 획득 +%s%%", icon = "INV_Misc_Book_07" },
	AdditionalGold = { key = "goldKill", gold = true, text = "몬스터 처치마다 골드 +%s", icon = "INV_Misc_Coin_01" },
	AdditionalExp = { key = "expKill", text = "몬스터 처치마다 경험치 +%s", icon = "INV_Misc_Book_09" },
	AdditionalGoldNormalMonster = { key = "goldMob", gold = true, text = "일반 몬스터 처치 골드 +%s", icon = "INV_Misc_Coin_06" },
	AdditionalExpNormalMonster = { key = "expMob", text = "일반 몬스터 처치 경험치 +%s", icon = "INV_Misc_Book_08" },
	AdditionalGoldStageBoss = { key = "goldBoss", gold = true, text = "우두머리 처치 골드 +%s", icon = "INV_Misc_Coin_04" },
	AdditionalExpStageBoss = { key = "expBoss", text = "우두머리 처치 경험치 +%s", icon = "INV_Misc_Book_11" },
	AdditionalGoldActBoss = { key = "goldAct", gold = true, text = "막 우두머리 처치 골드 +%s", icon = "INV_Misc_Coin_03" },
	AdditionalExpActBoss = { key = "expAct", text = "막 우두머리 처치 경험치 +%s", icon = "INV_Misc_Book_06" },
	DropChanceNormalChestPercent = { key = "chestChance", k = 0.1, text = "몬스터 상자가 나올 확률 +%s%%", icon = "INV_Box_01" },
	DropChanceStageBossChestPercent = { key = "bossRate", k = 0.1, text = "우두머리 상자가 나올 확률 +%s%%", icon = "INV_Box_03" },
	MaxAmountNormalChest = { key = "cap1", text = "몬스터 상자 보관 한도 +%s", icon = "INV_Misc_Bag_08" },
	MaxAmountStageBossChest = { key = "cap2", text = "우두머리 상자 보관 한도 +%s", icon = "INV_Box_02" },
	MaxAmountActBossChest = { key = "cap3", text = "막 우두머리 상자 보관 한도 +%s", icon = "INV_Box_04" },
	UnlockAutoOpenNormalChest = { key = "auto1", time = true, text = "몬스터 상자 자동 열기 (%s마다)", icon = "INV_Misc_Key_03" },
	UnlockAutoOpenStageBossChest = { key = "auto2", time = true, text = "우두머리 상자 자동 열기 (%s마다)", icon = "INV_Misc_Key_03" },
	UnlockAutoOpenActBossChest = { key = "auto3", time = true, text = "막 우두머리 상자 자동 열기 (%s마다)", icon = "INV_Misc_Key_03" },
	ReduceAutoOpenNormalChestTime = { key = "autoCut1", text = "몬스터 상자 자동 열기 간격 -%s초", icon = "INV_Misc_PocketWatch_01" },
	ReduceAutoOpenStageBossChestTime = { key = "autoCut2", text = "우두머리 상자 자동 열기 간격 -%s초", icon = "INV_Misc_PocketWatch_01" },
	ReduceAutoOpenActBossChestTime = { key = "autoCut3", text = "막 우두머리 상자 자동 열기 간격 -%s초", icon = "INV_Misc_PocketWatch_01" },
	OpenOneTypeChestAllAtOnce = { key = "openKind", flag = true, text = "상자를 클릭하면 그 종류를 모두 엽니다", sum = "상자 종류별로 모두 열기 (클릭)", icon = "INV_Misc_Key_04" },
	OpenAllTypeChestAllAtOnce = { key = "openAll", flag = true, text = "상자를 Shift+클릭하면 모든 종류를 한 번에 엽니다", sum = "모든 상자 한 번에 열기 (Shift+클릭)", icon = "INV_Misc_Key_01" },
	MaxInventorySlot = { key = "bag", text = "가방 칸 +%s", icon = "INV_Misc_Bag_10" },
	UnlockStashPageCount = { key = "stash", text = "창고 칸 +%s", per = 20, icon = "INV_Misc_Bag_09" },
	UnlockArrangeSlotCount = { key = "party", text = "파티 자리 +%s", icon = "INV_Misc_GroupNeedMore" },
	UnlockSkillSlotCount = { key = "skillSlot", text = "모든 영웅 기술 칸 +%s", icon = "INV_Misc_Book_11" },
	UnlockOfflineReward = { key = "offlineOn", flag = true, text = "오프라인 보상: 접속하지 않은 동안에도 골드와 경험치를 얻습니다", sum = "오프라인 보상 받기", icon = "Spell_Nature_Sleep" },
	OfflineRewardGoldPercent = { key = "offGold", k = 0.1, text = "오프라인 보상 골드 +%s%%", icon = "INV_Misc_Coin_05" },
	OfflineRewardExpPercent = { key = "offExp", k = 0.1, text = "오프라인 보상 경험치 +%s%%", icon = "INV_Misc_Book_10" },
	CubeExpPercent = { key = "forgeExp", k = 0.1, text = "대장간 경험치 +%s%%", icon = "Trade_BlackSmithing" },
	CubeAlchemyGoldPercent = { key = "smeltGold", k = 0.1, text = "분해 골드 +%s%%", icon = "Trade_Alchemy" },
	WaveCountReduction = { key = "waves", text = "스테이지마다 웨이브 -%s", icon = "Spell_Nature_TimeStop" },
	-- the first rune: its amount goes to each of these stats' bonuses
	StartGoldExp = { key = "start", k = 0.1, adds = { "IncreaseGoldAmount", "IncreaseExpAmount" }, text = "몬스터 처치 골드·경험치 획득 +%s%%", icon = "INV_Misc_Rune_01" },
}

-- The kinds of rune (the colour of a rune's border on the tree), in the
-- order the tree's key lists them, and the kind of each bonus key.
ns.RUNE_GROUPS = {
	{ key = "fight", name = "전투", rgb = { 1, 0.36, 0.3 } },
	{ key = "gold", name = "골드", rgb = { 1, 0.82, 0.22 } },
	{ key = "exp", name = "경험치", rgb = { 0.38, 0.7, 1 } },
	{ key = "chest", name = "상자", rgb = { 0.78, 0.5, 1 } },
	{ key = "bag", name = "가방", rgb = { 0.3, 0.88, 0.76 } },
	{ key = "unlock", name = "해금", rgb = { 1, 0.5, 0.78 } },
	{ key = "forge", name = "대장간", rgb = { 0.95, 0.56, 0.2 } },
}
ns.RUNE_GROUP_OF = {
	atk = "fight", atkPct = "fight", aspd = "fight", boss = "fight", armor = "fight", armorPct = "fight", waves = "fight",
	gold = "gold", goldKill = "gold", goldMob = "gold", goldBoss = "gold", goldAct = "gold", offGold = "gold",
	exp = "exp", expKill = "exp", expMob = "exp", expBoss = "exp", expAct = "exp", offExp = "exp",
	chestChance = "chest", bossRate = "chest", cap1 = "chest", cap2 = "chest", cap3 = "chest",
	auto1 = "chest", auto2 = "chest", auto3 = "chest", autoCut1 = "chest", autoCut2 = "chest", autoCut3 = "chest",
	openKind = "chest", openAll = "chest",
	bag = "bag", stash = "bag",
	party = "unlock", skillSlot = "unlock", offlineOn = "unlock",
	forgeExp = "forge", smeltGold = "forge",
}
-- the first rune's own kind: in none of the kinds under the map (no check
-- lights it up), its border silver
ns.RUNE_START_GROUP = { key = "start", name = "시작", rgb = { 0.78, 0.82, 0.88 } }
do
	local byKey = {}
	for _, g in ipairs(ns.RUNE_GROUPS) do byKey[g.key] = g end
	byKey.start = ns.RUNE_START_GROUP
	ns.RUNE_GROUP_OF.start = "start"
	for _, def in pairs(ns.RUNE_STAT) do
		def.group = byKey[ns.RUNE_GROUP_OF[def.key]]
		if not def.group then error("rune stat " .. def.key .. " has no kind") end
	end
end

-- How the other bonuses (the companions') read, %s for the value.
ns.BONUS_TEXT = {
	gold        = "몬스터 처치 골드 +%s%%",
	exp         = "경험치 획득 +%s%%",
	smeltGold   = "분해 골드 +%s%%",
	forgeExp    = "대장간 경험치 +%s%%",
	offline     = "오프라인 보상 +%s%%",
	chestChance = "몬스터 상자가 나올 확률 +%s%%",
	chestCap    = "상자 보관 한도 +%s",
	bossChest   = "우두머리 상자 하나 더 받을 확률 +%s%%",
	autoCd      = "자동 열기 간격 -%s%%",
}
-- (a rune stat's own key reads as the rune does)
for _, def in pairs(ns.RUNE_STAT) do
	if not ns.BONUS_TEXT[def.key] and not def.flag and not def.time and not def.adds then ns.BONUS_TEXT[def.key] = def.text end
end

function ns.BonusText(key, value)
	local t = ns.BONUS_TEXT[key]
	if t then
		return string.format(ns.N(t), ns.U.num(value, 2))
	end
	local a = ns.AFFIX[key]
	if a then
		local unit = (a.f == "num" or a.f == "int") and "" or "%"
		return string.format("모든 영웅 %s +%s%s", ns.N(a.n), ns.U.num(value, 2), unit)
	end
	return key
end

------------------------------------------------------------------------
-- The tree
------------------------------------------------------------------------
Runes.byId = {} -- [key] = { id, name, icon, x, y, max, need, kind (TBH stat), stat (bonus key), def, v, c }
Runes.prev = {} -- [key] = the rune before it
Runes.kids = {} -- [key] = the runes after it

-- runes with a name or picture of their own (over Data/Runes.lua's): the
-- first rune, at the middle of the map
local OWN = { [1] = { name = "시작의 룬", icon = "INV_Misc_Rune_01" } } -- the hearthstone

do
	for key, r in pairs(ns.RUNES) do
		local def = ns.RUNE_STAT[r.s]
		if not def then error("rune " .. key .. ": unknown stat " .. tostring(r.s)) end
		local own = OWN[key] or {}
		Runes.byId[key] = {
			id = key, name = own.name or r.n, icon = own.icon or def.icon, x = r.x, y = r.y, max = r.m, req = r.q,
			kind = r.s, stat = def.key, def = def, group = def.group, v = r.v, c = r.c,
		}
		Runes.prev[key] = r.p
	end
	for key, p in pairs(Runes.prev) do
		if not Runes.byId[p] then error("rune " .. key .. " follows a rune that is not there: " .. p) end
		Runes.kids[p] = Runes.kids[p] or {}
		table.insert(Runes.kids[p], key)
	end
	for _, list in pairs(Runes.kids) do table.sort(list) end
end

-- What a rune's levels 1..lvl add up to, as its bonus key's amount.
function Runes.Amount(id, lvl)
	local node = Runes.byId[id]
	local sum = 0
	for l = 1, min(lvl, node.max) do sum = sum + node.v[l] end
	local def = node.def
	if def.flag then return sum > 0 and 1 or 0 end
	sum = sum * (def.k or 1) * (def.per or 1)
	if def.gold and sum > 0 then sum = max(1, floor(sum * ns.RUNE_GOLD + 0.5)) end
	return sum
end

-- How an amount of a stat reads (short: as a line of the totals list).
function Runes.StatText(def, amount, short)
	if def.flag then return ns.N(short and def.sum or def.text) end
	if def.time then return string.format(ns.N(def.text), ns.U.time(amount)) end
	return string.format(ns.N(def.text), ns.U.num(amount, 2))
end
-- How an amount of a rune's stat reads (short: as a line of the totals list).
function Runes.Text(id, amount, short)
	local def = Runes.byId[id].def
	if def.flag then return ns.N(short and def.sum or def.text) end
	if def.time then return string.format(ns.N(def.text), ns.U.time(amount)) end
	return string.format(ns.N(def.text), ns.U.num(amount, 2))
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
			local amount = Runes.Amount(id, lvl)
			if node.def.adds then
				for _, kind in ipairs(node.def.adds) do
					local k = ns.RUNE_STAT[kind].key
					cache[k] = (cache[k] or 0) + amount
				end
			else
				cache[node.stat] = (cache[node.stat] or 0) + amount
			end
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

-- The level the rune before it must have: TBH's number, else its top level.
function Runes.Need(id)
	local node = Runes.byId[id]
	local prev = Runes.prev[id]
	if not prev then return 0 end
	return node.req or Runes.byId[prev].max
end

function Runes.Available(id)
	local prev = Runes.prev[id]
	if not prev then return true end
	return Runes.Level(prev) >= Runes.Need(id)
end

-- Gold for level `level` of a rune (1-based), rounded to a plain number.
function Runes.Cost(id, level)
	local node = Runes.byId[id]
	local c = node.c[level]
	if not c then return nil end
	c = c * ns.RUNE_GOLD
	local step = c >= 100000 and 1000 or (c >= 1000 and 100 or (c >= 100 and 10 or 1))
	return max(1, floor(c / step + 0.5) * step)
end

function Runes.NextCost(id)
	local node = Runes.byId[id]
	local lvl = Runes.Level(id)
	if lvl >= node.max then return nil end
	return Runes.Cost(id, lvl + 1)
end

-- The rune to buy next on the way to `id` (id itself when it is open), and
-- the gold the whole way costs: the runes before it to the levels they must
-- have, then its next level.
function Runes.NextStepTo(id)
	local chain = { { id = id, to = Runes.Level(id) + 1 } }
	local cur = id
	while not Runes.Available(cur) do
		local prev = Runes.prev[cur]
		table.insert(chain, 1, { id = prev, to = Runes.Need(cur) })
		cur = prev
	end
	if Runes.Level(id) >= Runes.byId[id].max then return nil, 0 end
	local total, step = 0, nil
	for _, c in ipairs(chain) do
		for l = Runes.Level(c.id) + 1, c.to do
			total = total + (Runes.Cost(c.id, l) or 0)
			step = step or c.id
		end
	end
	return step, total
end

-- Gold spent on the runes learned so far.
function Runes.Spent()
	local total = 0
	for id, lvl in pairs(ns.db.runes) do
		if Runes.byId[id] then
			for l = 1, min(lvl, Runes.byId[id].max) do total = total + (Runes.Cost(id, l) or 0) end
		end
	end
	return total
end

function Runes.Buy(id)
	local node = Runes.byId[id]
	if not node then return false end
	if not Runes.Available(id) then
		return false, string.format("%s을(를) %d레벨까지 먼저 배워야 합니다.", ns.N(Runes.byId[Runes.prev[id]].name), Runes.Need(id))
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

-- The first rune (by key) that gives a bonus key and is not learned yet, or nil.
function Runes.FirstFor(stat)
	local best
	for id, node in pairs(Runes.byId) do
		if node.stat == stat and Runes.Level(id) < node.max and (not best or id < best) then best = id end
	end
	return best
end

------------------------------------------------------------------------
-- Derived account limits
------------------------------------------------------------------------
ns.PARTY_BASE, ns.SKILL_BASE = 3, 2

function ns.PartyLimit()
	return min(ns.PARTY_SIZE, ns.PARTY_BASE + ns.Bonus("party"))
end

function ns.SkillSlots()
	return min(3, ns.SKILL_BASE + ns.Bonus("skillSlot"))
end

function ns.BagSize()
	return 30 + ns.Bonus("bag")
end

function ns.BankSize()
	return 10 + ns.Bonus("stash")
end

function ns.ChestCap(chestType)
	return ns.CHEST[chestType].cap + ns.Bonus("chestCap") + ns.Bonus("cap" .. chestType)
end

function ns.GameSpeed()
	return 1 + ns.Bonus("speed") / 100
end

-- Offline rewards are paid once their rune is learned.
function ns.OfflineOn()
	return ns.Bonus("offlineOn") > 0
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
