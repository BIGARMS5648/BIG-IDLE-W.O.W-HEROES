-- 무한의 탑 (the endless tower): opens once the last difficulty is cleared to
-- its end (ns.TowerOpen). Every time a floor starts, its place, its monsters
-- and its boss are each picked at random from the stages (Tower.Roll); every
-- tenth floor is a raid boss alone. Monsters grow a little stronger
-- every floor, and every fifth floor adds the next Mythic+ affix
-- (ns.TOWER_AFFIXES, in order). Every chest from the tower holds gear of
-- item level 100, the better grades more often the higher the floor. The
-- first clear of a floor pays gold and one more chest.
local _, ns = ...

local floor, min = math.floor, math.min

local Tower = {}
ns.Tower = Tower

Tower.LEVEL = 95            -- its monsters' level (the last stage's) before the floors' growth
Tower.ITEM_LEVEL = 100      -- the gear in its chests
Tower.WAVES = 5             -- waves of monsters before the boss (a raid floor: the boss alone)
Tower.AFFIX_EVERY = 5       -- one more affix every this many floors
Tower.RAID_EVERY = 10       -- a raid boss every this many floors
Tower.GROW_HP, Tower.GROW_ATK = 1.055, 1.04 -- monsters' health and attack, times this every floor (about 30 floors in its first 100 hours)
Tower.GOLD_STEP = 0.04      -- monster gold +4% every floor
Tower.MRATE, Tower.BRATE = 20, 1000 -- chest chances, per thousand: each monster, the boss
Tower.LUCK_STEP = 0.03      -- better grades: their weight times (1 + this x floor) per grade above 2
Tower.FIRST_GOLD = 3000     -- the first clear's gold: a monster of this much health, times the floor's step
Tower.FIRST_STEP = 0.1

-- the Mythic+ affixes, one more every AFFIX_EVERY floors
ns.TOWER_AFFIXES = {
	{ key = "fortified", name = "경화", icon = "Spell_Holy_DevotionAura",
		text = "일반 몬스터의 생명력이 20%, 공격력이 30% 높습니다." },
	{ key = "tyrannical", name = "폭군", icon = "INV_Misc_Head_Dragon_01",
		text = "우두머리의 생명력이 30%, 공격력이 15% 높습니다." },
	{ key = "raging", name = "분노", icon = "Ability_Racial_BloodRage",
		text = "일반 몬스터가 생명력 30% 아래에서 격노해 공격력이 50% 오릅니다." },
	{ key = "grievous", name = "치명상", icon = "Ability_Rogue_Rupture",
		text = "생명력이 90% 아래인 영웅은 2초마다 최대 생명력의 2%를 잃습니다." },
	{ key = "volcanic", name = "화산", icon = "Spell_Fire_Volcano",
		text = "8초마다 영웅 한 명의 발밑에서 불길이 솟아 최대 생명력의 12% 화염 피해를 줍니다." },
	{ key = "sanguine", name = "피웅덩이", icon = "Spell_Shadow_LifeDrain02",
		text = "일반 몬스터가 죽으면 남은 몬스터가 최대 생명력의 8%를 회복합니다." },
	{ key = "bolstering", name = "강화", icon = "Ability_Warrior_BattleShout",
		text = "일반 몬스터가 죽으면 남은 일반 몬스터의 생명력과 공격력이 10% 오릅니다." },
	{ key = "teeming", name = "무리", icon = "Spell_Nature_InsectSwarm",
		text = "일반 몬스터가 30% 더 많이 나옵니다." },
	{ key = "quaking", name = "전율", icon = "Spell_Nature_Earthquake",
		text = "15초마다 땅이 흔들려 모든 영웅이 최대 생명력의 8% 피해를 받습니다." },
	{ key = "bursting", name = "파열", icon = "Spell_Fire_SelfDestruct",
		text = "일반 몬스터가 죽으면 모든 영웅이 최대 생명력의 2% 피해를 받습니다." },
}
-- what the affixes do in a fight (Systems/Combat.lua)
Tower.FX = {
	fortified = { hp = 1.2, atk = 1.3 },
	tyrannical = { hp = 1.3, atk = 1.15 },
	raging = { below = 0.3, atk = 1.5 },
	grievous = { below = 0.9, every = 2, share = 0.02 },
	volcanic = { every = 8, share = 0.12 },
	sanguine = { share = 0.08 },
	bolstering = { mult = 1.1 },
	teeming = { mult = 1.3 },
	quaking = { every = 15, share = 0.08 },
	bursting = { share = 0.02 },
}

function Tower.Open()
	return ns.TowerOpen() and true or false
end

-- The floor a player may go to: up to one past the best cleared.
function Tower.Top()
	local t = ns.db and ns.db.tower
	return ((t and t.best) or 0) + 1
end

function Tower.Label(f)
	return string.format("무한의 탑 %d층", f)
end

function Tower.IsRaid(f)
	return f % Tower.RAID_EVERY == 0
end

-- The affixes of a floor, in the order they came.
function Tower.Affixes(f)
	local n = min(#ns.TOWER_AFFIXES, floor(f / Tower.AFFIX_EVERY))
	local list = {}
	for i = 1, n do list[i] = ns.TOWER_AFFIXES[i] end
	return list
end

-- The floor where an affix comes (its place in the list x AFFIX_EVERY).
function Tower.AffixFloor(i)
	return i * Tower.AFFIX_EVERY
end

function Tower.Set(f)
	local set = {}
	for _, a in ipairs(Tower.Affixes(f)) do set[a.key] = true end
	return set
end

-- What a floor can be made of: the places and monster packs of every stage,
-- the bosses of the stages and, for the raid floors, the raid bosses.
local pools
local function stagePools()
	if pools then return pools end
	pools = { all = {}, stage = {}, raid = {} }
	for d = 1, #ns.DIFFS do
		for i = 1, ns.STAGE_COUNT do
			local e = { d, i }
			pools.all[#pools.all + 1] = e
			local list = ns.STAGES[d][i].raid and pools.raid or pools.stage
			list[#list + 1] = e
		end
	end
	return pools
end

local function pick(list)
	local e = list[math.random(#list)]
	return e[1], e[2]
end

-- A floor's fight, rolled each time it starts: a place (any stage's), the
-- monsters (a stage's pack) and the boss (a stage's, a raid boss on the raid
-- floors), each picked at random on its own.
-- Returns { place = { diff, idx }, mobs = { diff, idx }, boss = { diff, idx } }.
function Tower.Roll(f)
	local p = stagePools()
	local r = {}
	r.place = { pick(p.all) }
	r.mobs = { pick(p.stage) }
	r.boss = { pick(Tower.IsRaid(f) and p.raid or p.stage) }
	return r
end

-- Monster strength of a floor on top of the last stage's level.
function Tower.HPMult(f) return Tower.GROW_HP ^ (f - 1) end
function Tower.AtkMult(f) return Tower.GROW_ATK ^ (f - 1) end
function Tower.GoldMult(f) return 1 + Tower.GOLD_STEP * (f - 1) end

-- Monsters before the boss (none on a raid floor), how many at once, waves
-- with the boss's.
function Tower.MobsPerWave()
	return ns.MAX_WAVE_MOBS
end
function Tower.Kills(f)
	if Tower.IsRaid(f) then return 0 end
	local n = Tower.WAVES * Tower.MobsPerWave()
	if Tower.Set(f).teeming then n = floor(n * Tower.FX.teeming.mult + 0.5) end
	return n
end
function Tower.Waves(f)
	local kills, per = Tower.Kills(f), Tower.MobsPerWave()
	return (kills > 0 and math.ceil(kills / per) or 0) + 1
end

-- The chests of a floor: the box each chest kind rolls from (the last
-- stages' boxes, with gear of ITEM_LEVEL) and their chances.
function Tower.Box(chestType)
	return ns.Loot.BoxFor(ns.CHEST[chestType].box, Tower.ITEM_LEVEL)
end
function Tower.Drops(f)
	return { mbox = Tower.Box(1), mrate = Tower.MRATE, bbox = Tower.Box(Tower.IsRaid(f) and 3 or 2), brate = Tower.BRATE }
end
-- the weight of a grade above 2 is raised this much per grade
function Tower.Luck(f)
	return 1 + Tower.LUCK_STEP * f
end

-- The first clear of a floor: gold, and one more chest of its boss's kind.
function Tower.FirstGold(f)
	return floor(ns.MobGold(Tower.FIRST_GOLD, Tower.LEVEL) * (1 + Tower.FIRST_STEP * (f - 1)))
end
