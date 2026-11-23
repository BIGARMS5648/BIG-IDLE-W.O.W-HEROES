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
Stats.AddMod = addMod

-- Stats that simply read (class base + modifiers).
local PLAIN = {
	"crit", "critdmg", "regen", "regenPct", "hph", "hpk", "hpkPct", "leech", "dodge", "block", "dr", "absorb",
	"cdr", "cast", "move", "heal", "multi", "thorns", "exp", "gold", "skills", "allres",
	"dmg_phys", "dmg_fire", "dmg_frost", "dmg_nature", "dmg_shadow", "dmg_holy", "dmg_arcane", "dmg_all",
	"res_fire", "res_frost", "res_nature", "res_shadow",
}

local CAPS = { dodge = 60, block = 75, dr = 75, cdr = 60, res_fire = 75, res_frost = 75, res_nature = 75, res_shadow = 75, allres = 75, skills = 5 }

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

	-- Account bonuses that are combat stats apply to every hero. Gold and
	-- experience bonuses are account-wide too, but they are added once where the
	-- reward is paid out, not folded into each hero.
	for key, v in pairs(ns.Runes.All()) do
		if ns.AFFIX[key] and key ~= "exp" and key ~= "gold" then
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
	for i = 1, #PLAIN do
		local k = PLAIN[i]
		s[k] = fin(k, c.base[k] or 0)
	end
	for k, cap in pairs(CAPS) do
		if s[k] > cap then s[k] = cap end
	end
	s.skills = floor(s.skills + 0.001)
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

function Stats.DPS(s)
	local crit = min(100, max(0, s.crit)) / 100
	local school = (s["dmg_" .. s.school] or 0) + s.dmg_all
	return s.atk * s.aspd * (1 + crit * (s.critdmg / 100 - 1)) * (1 + school / 100) * (1 + s.multi / 200)
end

function Stats.EHP(s, level)
	local taken = (1 - Stats.ArmorDR(s.armor, level or s.level)) * (1 - s.dr / 100)
		* (1 - s.dodge / 100) * (1 - s.block / 200)
	return s.hp / max(0.05, taken)
end

-- The 전투력 shown on every screen, the same for every role and spec so any
-- two heroes compare: the geometric mean of offense and effective health
-- (the damage it takes to fell the hero), raised by skill speed and healing
-- power. Offense is attack with critical hits, element damage, multistrike
-- and attack speed gained from gear and buffs. Each spec's kit (its own
-- attack speed, how much of its damage comes from skills) is evened out by
-- its tuning in Data/Classes.lua (SPEC_TUNE); that tuning is taken back out
-- here, so a tank, a damage dealer and a healer of the same level and gear
-- land close together.
function Stats.CombatPower(s)
	local sp = ns.SPECS[s.spec]
	local crit = min(100, max(0, s.crit)) / 100
	local school = (s["dmg_" .. s.school] or 0) + s.dmg_all
	local speed = s.aspd / max(0.1, sp and sp.base.aspd or s.aspd)
	local offense = s.atk / ns.SpecTune(s.spec, "atk") * (1 + crit * (s.critdmg / 100 - 1)) * (1 + school / 100)
		* (1 + s.multi / 200) * speed
	local ehp = Stats.EHP(s) / ns.SpecTune(s.spec, "hp")
	local skill = (1 + s.cast / 200) / max(0.4, 1 - s.cdr / 200)
	local heal = 1 + s.heal / 200
	return math.sqrt(offense * ehp) * skill * heal
end

-- One number used to compare gear FOR ONE HERO (is this item better for
-- them?); the weights depend on the role, so it is not for comparing heroes.
function Stats.Power(heroId, gear)
	local s = gear and Stats.Compute(heroId, nil, gear) or Stats.Get(heroId)
	local role = s.role
	local dps, ehp = Stats.DPS(s), Stats.EHP(s)
	if role == "TANK" then
		return dps ^ 0.35 * ehp ^ 0.65
	elseif role == "HEALER" then
		local healing = (1 + s.heal / 100) * (1 + s.cast / 100) / max(0.4, 1 - s.cdr / 100)
		return dps ^ 0.25 * ehp ^ 0.5 * healing ^ 0.6 * 3
	end
	local cool = (1 + s.cast / 200) / max(0.4, 1 - s.cdr / 200)
	return dps ^ 0.75 * ehp ^ 0.25 * cool ^ 0.4
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

-- The stats in four groups for the hero screen (기본, 공격, 방어, 특화):
-- { { title, { { label, text, tone }, ... } }, ... }; tone "up" for a bonus
-- the hero has, "zero" for one it has none of.
function Stats.Groups(heroId)
	local s = Stats.Get(heroId)
	local U = ns.U
	local function v(x) return x or 0 end
	local function pct(x, d) return U.num(v(x), d or 1) .. "%" end
	local function bonus(label, x, d, flat)
		x = v(x)
		local text = flat and U.fmt(x) or ((x > 0 and "+" or "") .. U.num(x, d or 1) .. "%")
		return { label, text, x > 0 and "up" or "zero" }
	end
	local school = v(s["dmg_" .. s.school]) + v(s.dmg_all)
	local stage = ns.db and ns.db.stage
	local stageLv = stage and ns.StageLevel(stage.diff, stage.idx) or s.level
	-- resistances: every element's own plus 모든 원소 저항, each capped like in combat
	local RES = { { "fire", "화염" }, { "frost", "냉기" }, { "nature", "자연" }, { "shadow", "암흑" } }
	local lo, hi, resTip = nil, nil, { { "원소 저항", nil, 1, 0.82, 0 } }
	for _, e in ipairs(RES) do
		local r = math.min(CAPS.allres, v(s["res_" .. e[1]]) + v(s.allres))
		lo, hi = math.min(lo or r, r), math.max(hi or r, r)
		resTip[#resTip + 1] = { e[2] .. " 저항", U.num(r, 1) .. "%", 1, 1, 1 }
	end
	resTip[#resTip + 1] = { "신성 · 비전 저항", U.num(math.min(CAPS.allres, v(s.allres)), 1) .. "%", 1, 1, 1 }
	resTip[#resTip + 1] = { string.format("모든 원소 저항 %s%% 포함 · 각각 최대 %d%%", U.num(v(s.allres), 1), CAPS.allres), nil, 0.7, 0.7, 0.75 }
	local resText = (lo == hi) and ((hi > 0 and "+" or "") .. U.num(hi, 1) .. "%") or (U.num(lo, 1) .. "~" .. U.num(hi, 1) .. "%")
	-- on a kill: a flat amount and a share of the maximum
	local hpk, hpkPct = v(s.hpk), v(s.hpkPct)
	local hpkText = (hpkPct > 0 and hpk > 0) and (U.fmt(hpk) .. " + " .. U.num(hpkPct, 1) .. "%")
		or (hpkPct > 0 and ("최대의 " .. U.num(hpkPct, 1) .. "%") or U.fmt(hpk))
	return {
		{ "기본", {
			{ "공격력", U.fmt(s.atk) },
			{ "생명력", U.fmt(s.hp) },
			{ "방어도", U.fmt(s.armor) },
			-- armor works against the level of the monsters: the stage being fought
			{ "물리 피해 감소", pct(Stats.ArmorDR(s.armor, stageLv) * 100), nil,
				{ { "물리 피해 감소", nil, 1, 0.82, 0 },
					{ string.format("지금 싸우는 지역(Lv %d)의 몬스터에게 받는 물리 피해가 이만큼 줄어듭니다.", stageLv), nil, 1, 1, 1, true },
					{ string.format("같은 레벨(Lv %d) 몬스터 기준: %s", s.level, pct(Stats.ArmorDR(s.armor, s.level) * 100)), nil, 0.7, 0.7, 0.75 } } },
			{ "초당 피해(추정)", U.fmt(Stats.DPS(s)), nil,
				{ { "초당 피해(추정)", nil, 1, 0.82, 0 },
					{ "기본 공격만 계산한 값입니다 (공격력 × 공격 속도 × 치명타 × 원소 피해 × 연속 타격). 기술 피해는 들어가지 않습니다.", nil, 1, 1, 1, true } } },
			{ "초당 생명력 회복", U.fmt(v(s.regen) + s.hp * v(s.regenPct) / 100) },
		} },
		{ "공격", {
			{ "치명타 확률", pct(s.crit) },
			{ "치명타 피해", pct(s.critdmg, 0) },
			{ "공격 속도", U.num(s.aspd, 2) .. "/초" },
			bonus("시전 속도", s.cast),
			bonus("연속 타격", s.multi),
			bonus(ns.N(ns.SCHOOL[s.school].name) .. " 피해", school),
			bonus("재사용 대기시간 감소", s.cdr),
		} },
		{ "방어", {
			{ "회피 확률", pct(s.dodge) },
			{ "막기 확률", pct(s.block) },
			bonus("받는 피해 감소", s.dr),
			bonus("생명력 흡수", s.leech),
			bonus("피해 흡수", s.absorb, nil, true),
			{ "원소 저항", resText, hi > 0 and "up" or "zero", resTip },
			bonus("가시 반사", s.thorns),
		} },
		{ "특화", {
			bonus("치유량 증가", s.heal),
			bonus("적중 시 생명력", s.hph, nil, true),
			{ "처치 시 생명력", hpkText, (hpk > 0 or hpkPct > 0) and "up" or "zero" },
			bonus("이동 속도", s.move),
			bonus("경험치 획득", s.exp),
			bonus("골드 획득", s.gold),
			{ "모든 기술 레벨", (v(s.skills) > 0 and "+" or "") .. v(s.skills), v(s.skills) > 0 and "up" or "zero" },
		} },
	}
end

-- Rows for the character sheet: { label, text }
function Stats.Sheet(heroId)
	local s = Stats.Get(heroId)
	local U = ns.U
	local rows = {}
	local function row(label, text)
		rows[#rows + 1] = { label, text }
	end
	row("공격력", U.fmt(s.atk))
	row("공격 속도", U.num(s.aspd, 2) .. "/s")
	row("치명타 확률", U.num(s.crit, 1) .. "%")
	row("치명타 피해", U.num(s.critdmg, 0) .. "%")
	row("초당 피해(추정)", U.fmt(Stats.DPS(s)))
	row("생명력", U.fmt(s.hp))
	row("방어도", U.fmt(s.armor) .. " (" .. U.num(Stats.ArmorDR(s.armor, s.level) * 100, 0) .. "%)")
	row("회피 / 막기", U.num(s.dodge, 1) .. "% / " .. U.num(s.block, 1) .. "%")
	row("받는 피해 감소", U.num(s.dr, 1) .. "%")
	row("초당 생명력 회복", U.fmt(s.regen + s.hp * s.regenPct / 100))
	row("재사용 대기시간 감소", U.num(s.cdr, 1) .. "%")
	row("시전 속도", "+" .. U.num(s.cast, 1) .. "%")
	if s.heal > 0 then row("치유량 증가", "+" .. U.num(s.heal, 1) .. "%") end
	if s.leech > 0 then row("생명력 흡수", U.num(s.leech, 1) .. "%") end
	if s.multi > 0 then row("연속 타격", U.num(s.multi, 1) .. "%") end
	local school = (s["dmg_" .. s.school] or 0) + s.dmg_all
	if school > 0 then row(ns.N(ns.SCHOOL[s.school].name) .. " 피해", "+" .. U.num(school, 1) .. "%") end
	if s.allres > 0 then row("모든 원소 저항", U.num(s.allres, 1) .. "%") end
	if s.exp > 0 then row("경험치 획득", "+" .. U.num(s.exp, 1) .. "%") end
	if s.gold > 0 then row("골드 획득", "+" .. U.num(s.gold, 1) .. "%") end
	if s.skills > 0 then row("모든 기술 레벨", "+" .. s.skills) end
	return rows
end
