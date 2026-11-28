-- Hero stat calculation.
--   final = (base + sum flat) * (1 + sum additive) * product(1 + multiplicative)
-- Sources, in order: class base (by level), gear, talent tree, runes and
-- companions, then battle-only auras and buffs passed in as `extra`.
local _, ns = ...

local floor, min, max = math.floor, math.min, math.max

local Stats = {}
ns.Stats = Stats

local cache = {}

function Stats.Invalidate(heroId)
	if heroId then
		cache[heroId] = nil
	else
		cache = {}
	end
	ns.Fire("STATS", heroId)
end

local function addMod(acc, key, value)
	local a = ns.AFFIX[key]
	if not a then return end
	local e = acc[a.t]
	if not e then
		e = { 0, 0, 1 }
		acc[a.t] = e
	end
	if a.l == "flat" then
		e[1] = e[1] + value
	elseif a.l == "add" then
		e[2] = e[2] + value / 100
	else
		e[3] = e[3] * (1 + value / 100)
	end
end

-- Stats that simply read (class base + modifiers).
local PLAIN = { "crit", "critdmg", "boss", "cdr", "dr", "res", "dodge", "healTaken" }

local CAPS = { dodge = 60, dr = 75, cdr = 60, res = 75 }
Stats.CAPS = CAPS

-- extra: optional array of { affixKey, value } (auras / buffs)
-- gear:  optional replacement gear table (used to preview upgrades)
function Stats.Compute(heroId, extra, gear)
	local h = ns.db.heroes[heroId]
	local c = ns.SPECS[h.spec]
	local acc = {}

	gear = gear or h.gear
	for i = 1, #ns.SLOTS do
		local it = gear[ns.SLOTS[i]]
		if it then
			ns.Items.EachMod(it, addMod, acc)
		end
	end

	for t = 1, #c.tree do
		local tier = c.tree[t]
		for n = 1, #tier do
			local node = tier[n]
			if node.p then
				local lvl = h.tree[t * 10 + n]
				if lvl and lvl > 0 then
					addMod(acc, node.p, node.v * lvl)
				end
			end
		end
	end

	-- Account bonuses that are combat stats apply to every hero (gold and
	-- experience are paid where the reward is, not folded into each hero).
	for key, v in pairs(ns.Runes.All()) do
		if ns.AFFIX[key] then
			addMod(acc, key, v)
		end
	end

	if extra then
		for i = 1, #extra do
			addMod(acc, extra[i][1], extra[i][2])
		end
	end

	local function fin(stat, base)
		local e = acc[stat]
		if e then
			return (base + e[1]) * (1 + e[2]) * e[3]
		end
		return base
	end

	local L = h.level
	local s = { level = L }
	s.atk = max(1, fin("atk", ns.BaseAtLevel(c, "atk", L)) * ns.SpecTune(c.id, "atk"))
	s.hp = max(1, floor(fin("hp", ns.BaseAtLevel(c, "hp", L)) * ns.SpecTune(c.id, "hp")))
	s.armor = max(0, fin("armor", ns.BaseAtLevel(c, "armor", L)))
	s.aspd = max(0.1, fin("aspd", c.base.aspd))
	-- 공격 및 시전 속도 against the spec's own pace: cooldowns run down this
	-- much faster too
	s.speed = s.aspd / c.base.aspd
	for i = 1, #PLAIN do
		local k = PLAIN[i]
		s[k] = fin(k, c.base[k] or 0)
	end
	for k, cap in pairs(CAPS) do
		if s[k] > cap then s[k] = cap end
	end
	s.school = c.school
	s.spec = c.id
	s.range = c.range
	s.role = c.role
	s.healMult = ns.SpecTune(c.id, "heal")
	return s
end

function Stats.Get(heroId)
	local s = cache[heroId]
	if not s then
		s = Stats.Compute(heroId)
		cache[heroId] = s
	end
	return s
end

-- Physical damage reduction from armor at a given enemy level (0..0.75).
function Stats.ArmorDR(armor, level)
	if armor <= 0 then return 0 end
	return min(0.75, armor / (armor + ns.ArmorK(level)))
end

-- What a hit comes to on average with critical hits.
function Stats.CritFactor(s)
	local crit = min(100, max(0, s.crit)) / 100
	return 1 + crit * (s.critdmg / 100 - 1)
end

-- Basic attacks only: attack, speed and critical hits.
function Stats.DPS(s)
	return s.atk * s.aspd * Stats.CritFactor(s)
end

function Stats.EHP(s, level)
	local taken = (1 - Stats.ArmorDR(s.armor, level or s.level)) * (1 - s.dr / 100) * (1 - s.dodge / 100)
	return s.hp / max(0.05, taken)
end

-- The 전투력 shown on every screen, the same for every role and spec so any
-- two heroes compare: the geometric mean of offense and effective health
-- (the damage it takes to fell the hero), raised by skill speed. Offense is
-- attack with critical hits, boss damage and speed gained from gear and
-- buffs. Each spec's kit (its own attack speed, how much of its damage
-- comes from skills) is evened out by its tuning in Data/Classes.lua
-- (SPEC_TUNE); that tuning is taken back out here, so a tank, a damage
-- dealer and a healer of the same level and gear land close together.
function Stats.CombatPower(s)
	local offense = s.atk / ns.SpecTune(s.spec, "atk") * Stats.CritFactor(s) * s.speed * (1 + s.boss / 200)
	local ehp = Stats.EHP(s) / ns.SpecTune(s.spec, "hp") * (1 + s.res / 400) * (1 + s.healTaken / 400)
	local skill = 1 / max(0.4, 1 - s.cdr / 200)
	return math.sqrt(offense * ehp) * skill
end

------------------------------------------------------------------------
-- Gear score (auto-equip, the upgrade marks, protection from breaking down)
------------------------------------------------------------------------
-- About half of what a hero does comes from its equipped skills, the rest
-- from basic attacks (the specs are tuned around that, Data/Classes.lua).
local SKILL_SHARE = 0.5
-- how much of a hero's worth is against bosses (the walls of every act)
local BOSS_SHARE = 0.5
-- the healing a hero takes over a stretch of fighting, as a share of its
-- health (the tank takes the most)
local HEALED = { TANK = 1.0, DPS = 0.3, HEALER = 0.3 }

-- Where the damage taken comes from, the same wherever the party fights (so
-- one item scores the same on every stage): half physical (armor), half the
-- elements (원소 저항).
local THREAT = { phys = 0.5, elem = 0.5 }
function Stats.ThreatMix()
	return THREAT
end

-- Damage taken, as a share, against that mix: armor against foes of the
-- hero's own level, resistance, reduction and dodge.
local function takenShare(s)
	local by = THREAT.phys * (1 - Stats.ArmorDR(s.armor, s.level)) + THREAT.elem * (1 - min(CAPS.res, s.res) / 100)
	return max(0.05, by * (1 - s.dr / 100) * (1 - s.dodge / 100))
end

-- 재사용 대기시간 감소 counts for the skills with a cooldown only: share = how
-- much of the output comes from skills, cdShare = the share of the skill
-- slots holding a cooldown skill.
local function cooldownFactor(s, share, cdShare)
	local part = share * cdShare
	return (1 - part) + part / max(0.4, 1 - s.cdr / 100)
end

-- The share of the hero's skill slots holding a cooldown skill (allCd: as
-- if every one did).
local function cdShareOf(h, allCd)
	if allCd then return 1 end
	local cd, slots = Stats.CooldownSkills(nil, h)
	return slots > 0 and cd / slots or 0
end

-- Damage a second and effective health as gear changes them.
function Stats.GearValues(s, h, allCd)
	local f = cdShareOf(h, allCd)
	local dps = Stats.DPS(s) * (1 + BOSS_SHARE * s.boss / 100) * cooldownFactor(s, SKILL_SHARE, f)
	local ehp = s.hp * (1 + (HEALED[s.role] or 0.3) * (1 + s.healTaken / 100)) / takenShare(s)
	return dps, ehp, f
end

-- One number used to compare gear FOR ONE HERO (is this item better for
-- them?); the weights depend on the role, so it is not for comparing heroes.
-- allCd: 재사용 대기시간 감소 weighed as if every skill slot held a cooldown
-- skill (what keeps gear from breaking down while a skill is out).
function Stats.Power(heroId, gear, allCd)
	local s = gear and Stats.Compute(heroId, nil, gear) or Stats.Get(heroId)
	local h = ns.db.heroes[heroId]
	local role = s.role
	local dps, ehp, f = Stats.GearValues(s, h, allCd)
	if role == "TANK" then
		return dps ^ 0.35 * ehp ^ 0.65
	elseif role == "HEALER" then
		-- heals come from 공격력, sped up, critical, and mostly cooldown skills
		local healing = s.atk * s.speed * Stats.CritFactor(s) * cooldownFactor(s, 1, f)
		return dps ^ 0.25 * ehp ^ 0.5 * healing ^ 0.6 * 3
	end
	return dps ^ 0.75 * ehp ^ 0.25
end

------------------------------------------------------------------------
-- Display helpers
------------------------------------------------------------------------
function Stats.FormatValue(key, value)
	local a = ns.AFFIX[key]
	local f = a and a.f or "num"
	if f == "pct" then
		return ns.U.num(value, 1) .. "%"
	elseif f == "pct2" then
		return ns.U.num(value, 2) .. "%"
	elseif f == "int" then
		return tostring(floor(value + 0.5))
	end
	if value >= 100 then
		return ns.U.fmt(value)
	end
	return ns.U.num(value, 1)
end

-- "+12.5% Attack Speed"
function Stats.ModText(key, value)
	local a = ns.AFFIX[key]
	if not a then return key end
	return "+" .. Stats.FormatValue(key, value) .. " " .. ns.N(a.n)
end

-- How many of the hero's skill slots hold a skill with a cooldown, and how
-- many slots there are (재사용 대기시간 감소 counts only for those skills).
function Stats.CooldownSkills(heroId, h)
	h = h or ns.db.heroes[heroId]
	local slots = ns.SkillSlots()
	local cd = 0
	for i = 1, slots do
		local sk = h and h.skills and ns.SKILLS[h.skills[i]]
		if sk and sk.act == "cd" then cd = cd + 1 end
	end
	return cd, slots
end

-- The stats in groups for the hero screen (기본, 공격, 방어, 전투):
-- { { title, { { label, text, tone, tip }, ... }, col }, ... }; tone "up" for
-- a bonus the hero has, "zero" for one it has none of; col = the column.
function Stats.Groups(heroId)
	local s = Stats.Get(heroId)
	local U = ns.U
	local function v(x) return x or 0 end
	local function pct(x, d) return U.num(v(x), d or 1) .. "%" end
	local function bonus(label, x, d, tip)
		x = v(x)
		return { label, (x > 0 and "+" or "") .. U.num(x, d or 1) .. "%", x > 0 and "up" or "zero", tip }
	end
	local function tip(title, ...)
		local t = { { title, nil, 1, 0.82, 0 } }
		for _, line in ipairs({ ... }) do
			if type(line) == "table" then t[#t + 1] = line else t[#t + 1] = { line, nil, 1, 1, 1, true } end
		end
		return t
	end
	local stage = ns.db and ns.db.stage
	local stageLv = stage and ns.StageLevel(stage.diff, stage.idx) or s.level
	local cd, slots = Stats.CooldownSkills(heroId)
	local groups = {
		{ "기본", {
			{ "공격력", U.fmt(s.atk) },
			{ "생명력", U.fmt(s.hp) },
			{ "방어력", U.fmt(s.armor), nil, tip("방어력", "몬스터에게 받는 물리 피해가 줄어듭니다. 몬스터 레벨이 높을수록 덜 줄어듭니다.") },
			{ "공격 및 시전 속도", U.num(s.aspd, 2) .. "/초", nil, tip("공격 및 시전 속도",
				"1초에 하는 기본 공격 횟수입니다. 기술 시전도 같은 비율로 빨라집니다.") },
		}, 1 },
		{ "공격", {
			{ "치명타 확률", pct(s.crit) },
			{ "치명타 피해", pct(s.critdmg, 0) },
			bonus("우두머리 피해", s.boss, 1, tip("우두머리 피해", "우두머리와 막 우두머리에게 주는 피해가 늘어납니다.")),
			bonus("재사용 대기시간 감소", s.cdr, 1, tip("재사용 대기시간 감소",
				"재사용 대기시간이 있는 기술이 더 자주 나갑니다.",
				{ string.format("지금 낀 쿨타임 기술 %d/%d개", cd, slots), nil, 0.7, 0.7, 0.75 })),
		}, 1 },
		{ "방어", {
			bonus("받는 피해 감소", s.dr),
			bonus("원소 저항", s.res, 1, tip("원소 저항", "화염·냉기·자연·암흑·신성·비전 피해가 줄어듭니다. 최대 75%입니다.")),
			{ "회피", pct(s.dodge), v(s.dodge) > 0 and "up" or "zero", tip("회피", "공격을 아예 맞지 않을 확률입니다. 피하면 상태이상도 걸리지 않습니다. 최대 60%입니다.") },
			bonus("받는 치유량 증가", s.healTaken, 1, tip("받는 치유량 증가", "받는 치유와 보호막이 커집니다.")),
		}, 2 },
	}
	-- what the numbers come to: damage a second, and armor as a share
	groups[4] = { "전투", {
		{ "예상 초당 피해", U.fmt(Stats.DPS(s)), nil, tip("예상 초당 피해",
			"기본 공격만 계산한 값입니다. 기술 피해는 들어가지 않습니다.") },
		{ "물리 피해 감소", pct(Stats.ArmorDR(s.armor, stageLv) * 100), nil, tip("물리 피해 감소",
			string.format("방어력이 지금 싸우는 지역(Lv %d)의 몬스터에게 받는 물리 피해를 이만큼 줄여 줍니다. 최대 75%%입니다.", stageLv),
			{ string.format("같은 레벨(Lv %d) 몬스터 기준: %s", s.level, pct(Stats.ArmorDR(s.armor, s.level) * 100)), nil, 0.7, 0.7, 0.75 }) },
	}, 2 }
	return groups
end
