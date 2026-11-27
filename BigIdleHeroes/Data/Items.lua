-- Item qualities, equipment slots, stat (affix) definitions, materials and chests.
local _, ns = ...

------------------------------------------------------------------------
-- Grades (TBH's ten, Data/TBH.lua): how many random stats and sockets
-- (보석 = 장식, 마법부여 = 세공, 주문각인 = 각인) each carries, what breaking one
-- down gives (gold, forge experience), its colour and its stat multiplier.
------------------------------------------------------------------------
local GRADE_NAME = { "일반", "고급", "희귀", "영웅", "전설", "불멸", "초월", "신성", "천상", "아르카나" }
local GRADE_HEX = { "e4e4e4", "54fc0c", "0c6cfc", "b40cfc", "fc9c0c", "fc2424", "fc246c", "fce976", "00ffff", "8ea6f2" }
-- grad: colours run across the grade's names (cyan, periwinkle, orchid) and
-- its frame is painted in them (frame: Media/<frame>.tga); hex is their middle
local GRADE_GRAD = { [10] = { "45e6e6", "8ea6f2", "d89ee0" } }
local GRADE_FRAME = { [10] = "frame_arcana" }
local GRADE_MULT = { 0.85, 1.00, 1.15, 1.32, 1.52, 1.75, 2.02, 2.35, 2.70, 3.10 }
ns.QUALITY = {}
for i, g in ipairs(ns.TBH.GRADES) do
	ns.QUALITY[i] = { key = g.key, name = GRADE_NAME[i], hex = GRADE_HEX[i], grad = GRADE_GRAD[i], frame = GRADE_FRAME[i],
		affix = g.affix, gem = g.gem, ench = g.ench,
		insc = g.insc, gold = g.gold, fxp = g.cube, mult = GRADE_MULT[i], fuse = g.fuse }
end
ns.MAX_QUALITY = #ns.QUALITY

-- Text in a grade's colour (its colours run across the letters when it has
-- several).
function ns.QText(q, text)
	local g = ns.QUALITY[q]
	if not g then return tostring(text) end
	if g.grad then return ns.U.grad(g.grad, text) end
	return ns.U.col(g.hex, text)
end

------------------------------------------------------------------------
-- Scaling curves by item / stage level.
------------------------------------------------------------------------
ns.Scale = {}
function ns.Scale.A(l) return (1 + 0.22 * (l - 1)) * 1.045 ^ (l - 1) end -- attack-like
function ns.Scale.H(l) return (1 + 0.20 * (l - 1)) * 1.050 ^ (l - 1) end -- health-like
function ns.Scale.R(l) return 1 + 0.50 * (l - 1) end                     -- armor (linear)

------------------------------------------------------------------------
-- Equipment slots. cat decides which affix / socket pool an item uses.
------------------------------------------------------------------------
ns.SLOTS = { "mh", "oh", "head", "chest", "hands", "feet", "wrist", "neck", "ring", "trinket" }

ns.SLOT = {
	mh      = { name = "주무기",  cat = "weapon",    fxp = 1.0, w = 18 },
	oh      = { name = "보조장비", cat = "weapon",    fxp = 2.0, w = 10 },
	head    = { name = "머리",         cat = "armor",     fxp = 0.8, w = 12, tname = "투구",
		base = { hp = 15, armor = 7 },
		icons = { "INV_Helmet_01", "INV_Helmet_03", "INV_Helmet_05", "INV_Helmet_09", "INV_Helmet_13" } },
	chest   = { name = "가슴",        cat = "armor",     fxp = 1.0, w = 12, tname = "갑옷",
		base = { hp = 25, armor = 10 },
		icons = { "INV_Chest_Cloth_01", "INV_Chest_Leather_03", "INV_Chest_Chain_05", "INV_Chest_Plate03", "INV_Chest_Plate10" } },
	hands   = { name = "손",          cat = "armor",     fxp = 0.75, w = 10, tname = "장갑",
		base = { hp = 8, armor = 5 },
		icons = { "INV_Gauntlets_01", "INV_Gauntlets_04", "INV_Gauntlets_10", "INV_Gauntlets_15", "INV_Gauntlets_17" } },
	feet    = { name = "발",           cat = "armor",     fxp = 0.7, w = 10, tname = "장화",
		base = { hp = 8, armor = 5 },
		icons = { "INV_Boots_01", "INV_Boots_03", "INV_Boots_05", "INV_Boots_08", "INV_Boots_Plate_04" } },
	wrist   = { name = "손목",        cat = "accessory", fxp = 3.0, w = 8, tname = "손목보호구",
		base = { hp = 6, armor = 3 }, minLevel = 5,
		icons = { "INV_Bracer_01", "INV_Bracer_03", "INV_Bracer_05", "INV_Bracer_07", "INV_Bracer_09" } },
	neck    = { name = "목",           cat = "accessory", fxp = 4.0, w = 6, tname = "목걸이",
		base = { hp = 14 }, minLevel = 8,
		icons = { "INV_Jewelry_Necklace_01", "INV_Jewelry_Necklace_02", "INV_Jewelry_Necklace_05", "INV_Jewelry_Necklace_07", "INV_Jewelry_Necklace_11" } },
	ring    = { name = "반지",       cat = "accessory", fxp = 3.0, w = 8, tname = "반지",
		base = { atk = 1.5 }, minLevel = 8,
		icons = { "INV_Jewelry_Ring_01", "INV_Jewelry_Ring_03", "INV_Jewelry_Ring_05", "INV_Jewelry_Ring_13", "INV_Jewelry_Ring_15" } },
	trinket = { name = "장신구",    cat = "accessory", fxp = 3.0, w = 6, tname = "부적",
		base = { crit = 2 }, minLevel = 8,
		icons = { "INV_Jewelry_Talisman_01", "INV_Jewelry_Talisman_03", "INV_Jewelry_Talisman_05", "INV_Jewelry_Talisman_07", "INV_Jewelry_Talisman_10" } },
}

-- Weapon / off-hand types. Each class lists which of these it can wield.
ns.WTYPE = {
	sword    = { slot = "mh", name = "도검",        base = { atk = 5.0, crit = 1 },
		icons = { "INV_Sword_04", "INV_Sword_10", "INV_Sword_20", "INV_Sword_27", "INV_Sword_39" } },
	axe      = { slot = "mh", name = "도끼",          base = { atk = 5.5 },
		icons = { "INV_Axe_01", "INV_Axe_03", "INV_Axe_06", "INV_Axe_09", "INV_Axe_12" } },
	mace     = { slot = "mh", name = "둔기",         base = { atk = 4.6, hp = 8 },
		icons = { "INV_Mace_01", "INV_Mace_03", "INV_Mace_04", "INV_Mace_07", "INV_Mace_13" } },
	dagger   = { slot = "mh", name = "단검",       base = { atk = 4.3, aspd = 8 },
		icons = { "INV_Weapon_ShortBlade_01", "INV_Weapon_ShortBlade_03", "INV_Weapon_ShortBlade_05", "INV_Weapon_ShortBlade_07", "INV_Weapon_ShortBlade_12" } },
	staff    = { slot = "mh", name = "지팡이",      base = { atk = 5.2, cast = 5 },
		icons = { "INV_Staff_08", "INV_Staff_10", "INV_Staff_13", "INV_Staff_20", "INV_Staff_30" } },
	bow      = { slot = "mh", name = "활",            base = { atk = 5.0, crit = 2 },
		icons = { "INV_Weapon_Bow_01", "INV_Weapon_Bow_02", "INV_Weapon_Bow_05", "INV_Weapon_Bow_07", "INV_Weapon_Bow_08" } },
	shield   = { slot = "oh", name = "방패",       base = { armor = 14, block = 8 },
		icons = { "INV_Shield_02", "INV_Shield_04", "INV_Shield_05", "INV_Shield_06", "INV_Shield_09" } },
	orb      = { slot = "oh", name = "마법 보주",     base = { atk = 1.6, crit = 2 },
		icons = { "INV_Misc_Orb_01", "INV_Misc_Orb_02", "INV_Misc_Orb_03", "INV_Misc_Orb_04", "INV_Misc_Orb_05" } },
	quiver   = { slot = "oh", name = "화살통",     base = { atk = 1.4, aspd = 6 },
		icons = { "INV_Misc_Quiver_01", "INV_Misc_Quiver_02", "INV_Misc_Quiver_03", "INV_Misc_Quiver_05", "INV_Misc_Quiver_07" } },
	offblade = { slot = "oh", name = "보조 칼날", base = { atk = 2.2 },
		icons = { "INV_Weapon_ShortBlade_02", "INV_Weapon_ShortBlade_04", "INV_Weapon_ShortBlade_06", "INV_Weapon_ShortBlade_14", "INV_Weapon_ShortBlade_15" } },
	relic    = { slot = "oh", name = "성물",        base = { hp = 16, heal = 8 },
		icons = { "INV_Misc_Idol_01", "INV_Misc_Idol_02", "INV_Misc_Idol_03", "INV_Misc_Book_09", "INV_Misc_Book_11" } },
	whetstone = { slot = "oh", name = "숫돌",   base = { atk = 2.0, critdmg = 6 },
		icons = { "INV_Stone_SharpeningStone_01", "INV_Stone_SharpeningStone_02", "INV_Stone_SharpeningStone_03", "INV_Stone_SharpeningStone_04", "INV_Stone_SharpeningStone_05" } },
}
ns.WTYPES_MH = { "sword", "axe", "mace", "dagger", "staff", "bow" }
ns.WTYPES_OH = { "shield", "orb", "quiver", "offblade", "relic", "whetstone" }

-- Material tier names by item level (one per 10 levels).
ns.ITEM_TIER = {
	"낡은", "구리", "청동", "철제", "강철",
	"미스릴", "토륨", "검은무쇠", "아케이나이트", "엘레멘티움",
}

------------------------------------------------------------------------
-- Stats. An affix key maps onto a target stat and one of three layers:
--   final = (base + sum flat) * (1 + sum add) * product(1 + mult)
-- f: display format, s: scaling curve for rolled flat values.
------------------------------------------------------------------------
ns.AFFIX = {
	atk        = { t = "atk",   l = "flat", n = "공격력",                 f = "num", s = "A" },
	atkPct     = { t = "atk",   l = "add",  n = "공격력",                 f = "pct" },
	atkMult    = { t = "atk",   l = "mult", n = "공격력",                 f = "pct" },
	hp         = { t = "hp",    l = "flat", n = "생명력",                 f = "num", s = "H" },
	hpPct      = { t = "hp",    l = "add",  n = "생명력",                 f = "pct" },
	armor      = { t = "armor", l = "flat", n = "방어도",                  f = "num", s = "R" },
	armorPct   = { t = "armor", l = "add",  n = "방어도",                  f = "pct" },
	aspd       = { t = "aspd",  l = "add",  n = "공격 속도",        f = "pct" },
	aspdMult   = { t = "aspd",  l = "mult", n = "공격 속도",        f = "pct" },
	crit       = { t = "crit",    l = "flat", n = "치명타 확률",     f = "pct" },
	critdmg    = { t = "critdmg", l = "flat", n = "치명타 피해",     f = "pct" },
	regen      = { t = "regen", l = "flat", n = "초당 생명력 회복", f = "num", s = "H" },
	hph        = { t = "hph",   l = "flat", n = "적중 시 생명력", f = "num", s = "H" },
	hpk        = { t = "hpk",   l = "flat", n = "처치 시 생명력", f = "num", s = "H" },
	leech      = { t = "leech", l = "flat", n = "생명력 흡수",        f = "pct" },
	dodge      = { t = "dodge", l = "flat", n = "회피 확률",        f = "pct" },
	block      = { t = "block", l = "flat", n = "막기 확률",        f = "pct" },
	dr         = { t = "dr",    l = "flat", n = "받는 피해 감소", f = "pct" },
	absorb     = { t = "absorb", l = "flat", n = "피해 흡수",  f = "num", s = "H" },
	cdr        = { t = "cdr",   l = "flat", n = "재사용 대기시간 감소", f = "pct" },
	cast       = { t = "cast",  l = "flat", n = "시전 속도",          f = "pct" },
	move       = { t = "move",  l = "flat", n = "이동 속도",      f = "pct" },
	heal       = { t = "heal",  l = "flat", n = "치유량 증가",      f = "pct" },
	multi      = { t = "multi", l = "flat", n = "연속 타격",         f = "pct" },
	dmg_phys   = { t = "dmg_phys",   l = "flat", n = "물리 피해", f = "pct" },
	dmg_fire   = { t = "dmg_fire",   l = "flat", n = "화염 피해",    f = "pct" },
	dmg_frost  = { t = "dmg_frost",  l = "flat", n = "냉기 피해",   f = "pct" },
	dmg_nature = { t = "dmg_nature", l = "flat", n = "자연 피해",  f = "pct" },
	dmg_shadow = { t = "dmg_shadow", l = "flat", n = "암흑 피해",  f = "pct" },
	dmg_holy   = { t = "dmg_holy",   l = "flat", n = "신성 피해",    f = "pct" },
	dmg_arcane = { t = "dmg_arcane", l = "flat", n = "비전 피해",  f = "pct" },
	dmg_all    = { t = "dmg_all",    l = "flat", n = "모든 피해",     f = "pct" },
	res_fire   = { t = "res_fire",   l = "flat", n = "화염 저항",   f = "pct" },
	res_frost  = { t = "res_frost",  l = "flat", n = "냉기 저항",  f = "pct" },
	res_nature = { t = "res_nature", l = "flat", n = "자연 저항", f = "pct" },
	res_shadow = { t = "res_shadow", l = "flat", n = "암흑 저항", f = "pct" },
	allres     = { t = "allres", l = "flat", n = "모든 원소 저항", f = "pct" },
	exp        = { t = "exp",   l = "flat", n = "경험치 획득",   f = "pct" },
	gold       = { t = "gold",  l = "flat", n = "골드 획득",           f = "pct" },
	skills     = { t = "skills", l = "flat", n = "모든 기술 레벨", f = "int" },
	thorns     = { t = "thorns", l = "flat", n = "가시 반사",             f = "pct" },
}

ns.SCHOOL = {
	phys   = { name = "물리", hex = "ffffff" },
	fire   = { name = "화염",     hex = "ff8040" },
	frost  = { name = "냉기",    hex = "80c0ff" },
	nature = { name = "자연",   hex = "70e070" },
	shadow = { name = "암흑",   hex = "b080ff" },
	holy   = { name = "신성",     hex = "ffe680" },
	arcane = { name = "비전",   hex = "ff80ff" },
}

-- Roll ranges at item level 1 / quality multiplier 1. { key, lo, hi, weight }
ns.AFFIX_POOL = {
	weapon = {
		{ "atk", 1.2, 2.4, 10 }, { "atkPct", 6, 12, 10 }, { "aspd", 4, 9, 8 }, { "crit", 2, 5, 8 },
		{ "critdmg", 8, 20, 8 }, { "hph", 0.6, 1.2, 4 }, { "cdr", 2, 6, 4 }, { "cast", 4, 10, 3 },
		{ "leech", 0.5, 1.5, 2 }, { "multi", 3, 8, 2 },
		{ "dmg_phys", 6, 14, 3 }, { "dmg_fire", 6, 14, 2 }, { "dmg_frost", 6, 14, 2 }, { "dmg_nature", 6, 14, 2 },
		{ "dmg_shadow", 6, 14, 2 }, { "dmg_holy", 6, 14, 2 }, { "dmg_arcane", 6, 14, 1 },
	},
	armor = {
		{ "hp", 10, 20, 10 }, { "hpPct", 5, 10, 8 }, { "armor", 3, 6, 10 }, { "armorPct", 6, 12, 6 },
		{ "regen", 0.4, 0.9, 5 }, { "dodge", 1.5, 4, 4 }, { "block", 2, 5, 3 }, { "dr", 1, 3, 3 },
		{ "absorb", 0.5, 1.0, 3 }, { "allres", 2, 6, 3 }, { "hpk", 2, 4, 3 },
		{ "res_fire", 5, 12, 2 }, { "res_frost", 5, 12, 2 }, { "res_nature", 5, 12, 2 }, { "res_shadow", 5, 12, 2 },
	},
	accessory = {
		{ "atk", 0.8, 1.6, 8 }, { "atkPct", 4, 9, 6 }, { "crit", 2, 5, 8 }, { "critdmg", 8, 20, 8 },
		{ "aspd", 3, 7, 6 }, { "cdr", 2, 6, 5 }, { "leech", 0.5, 1.5, 3 }, { "exp", 3, 7, 4 },
		{ "gold", 3, 7, 4 }, { "heal", 6, 14, 4 }, { "move", 3, 8, 3 }, { "hpPct", 4, 9, 4 },
	},
}

-- Sockets (TBH's cube): 보석 세공 = 장식, 마법부여 = 세공, 주문각인 = 각인.
-- Each material gives its line's stat for the gear group, at one of its
-- tiers (ns.SOCKET_LINES below).
ns.SOCKET = {
	gem  = { name = "보석 세공", mat = "gem", short = "보석" },
	ench = { name = "마법부여", mat = "dust", short = "마법부여" },
	insc = { name = "주문각인", mat = "scroll", short = "주문각인" },
}
ns.SOCKET_KINDS = { "gem", "ench", "insc" }
ns.SOCKET_FIELD = { gem = "g", ench = "e", insc = "i" }
-- the item level a socket tier's flat stats (attack, health, armor ...) are
-- sized for
ns.SOCKET_TIER_LEVEL = { 1, 5, 10, 15, 20, 30, 40, 50, 65, 80 }

-- TBH's stats as ours. A percent is TBH's number / div (TBH keeps tenths);
-- flat numbers are ours at the tier's level (coefficient times the stat's
-- level scale), rolled as widely as TBH's; fixed is a stat TBH counts in
-- whole steps. Stats without a match here take the nearest one: lightning
-- is nature, chaos is shadow, area / melee / projectile / summon damage is
-- all damage (half for area size), projectiles and extra strikes are
-- 연속 타격, fewer basic attacks per skill is attack speed.
ns.SOCKET_STAT = {
	["AttackDamage:FLAT"]                  = { "atk", flat = 1.1 },
	["AttackDamage:ADDITIVE"]              = { "atkPct", div = 10 },
	["AttackSpeed:ADDITIVE"]               = { "aspd", div = 10 },
	["CriticalChance:FLAT"]                = { "crit", div = 10 },
	["CriticalChance:ADDITIVE"]            = { "crit", div = 200 }, -- TBH: "increased", of a ~5% base
	["CriticalDamage:FLAT"]                = { "critdmg", div = 10 },
	["MaxHp:FLAT"]                         = { "hp", flat = 10 },
	["MaxHp:ADDITIVE"]                     = { "hpPct", div = 10 },
	["Armor:FLAT"]                         = { "armor", flat = 3 },
	["Armor:ADDITIVE"]                     = { "armorPct", div = 10 },
	["CooldownReduction:FLAT"]             = { "cdr", div = 10 },
	["MovementSpeed:ADDITIVE"]             = { "move", div = 10 },
	["MovementSpeed:FLAT"]                 = { "move", div = 5 },
	["AreaOfEffect:ADDITIVE"]              = { "dmg_all", div = 20 },
	["BaseAttackCountReduction:FLAT"]      = { "aspd", fixed = 10 },
	["FireResistance:FLAT"]                = { "res_fire" },
	["ColdResistance:FLAT"]                = { "res_frost" },
	["LightningResistance:FLAT"]           = { "res_nature" },
	["ChaosResistance:FLAT"]               = { "res_shadow" },
	["AllElementalResistance:FLAT"]        = { "allres" },
	["DodgeChance:FLAT"]                   = { "dodge", div = 10 },
	["BlockChance:FLAT"]                   = { "block", div = 10 },
	["Multistrike:FLAT"]                   = { "multi", fixed = 15 },
	["ProjectileCount:FLAT"]               = { "multi", fixed = 15 },
	["HpLeech:FLAT"]                       = { "leech", div = 10 },
	["HpRegenPerSec:FLAT"]                 = { "regen", flat = 0.6 },
	["PhysicalDamagePercent:FLAT"]         = { "dmg_phys", div = 10 },
	["FireDamagePercent:FLAT"]             = { "dmg_fire", div = 10 },
	["ColdDamagePercent:FLAT"]             = { "dmg_frost", div = 10 },
	["LightningDamagePercent:FLAT"]        = { "dmg_nature", div = 10 },
	["AddHpPerHit:FLAT"]                   = { "hph", flat = 0.9 },
	["AddHpPerKill:FLAT"]                  = { "hpk", flat = 3 },
	["DamageReduction:FLAT"]               = { "dr", div = 10 },
	["DamageAbsorption:FLAT"]              = { "absorb", flat = 0.75 },
	["CastSpeed:ADDITIVE"]                 = { "cast", div = 10 },
	["IncreaseAreaOfEffectDamage:ADDITIVE"] = { "dmg_all", div = 20 },
	["IncreaseMeleeDamage:ADDITIVE"]       = { "dmg_all", div = 20 },
	["IncreaseProjectileDamage:ADDITIVE"]  = { "dmg_all", div = 20 },
	["IncreaseSummonDamage:ADDITIVE"]      = { "dmg_all", div = 20 },
	["SkillDurationIncrease:ADDITIVE"]     = { "cdr", div = 30 },
	["SkillHealIncrease:ADDITIVE"]         = { "heal", div = 10 },
	-- (not TBH's: added below for the shadow, holy and arcane gems)
	["ShadowDamagePercent:FLAT"]           = { "dmg_shadow", div = 10 },
	["HolyDamagePercent:FLAT"]             = { "dmg_holy", div = 10 },
	["ArcaneDamagePercent:FLAT"]           = { "dmg_arcane", div = 10 },
}

-- Our stat and its value for a TBH stat mod rolled at a tier (raw: TBH's
-- number in that tier's range).
function ns.SocketStat(modKey, tier, raw)
	local mod = ns.TBH.STAT_MODS[modKey]
	local d = ns.SOCKET_STAT[mod.stat .. ":" .. mod.mod]
	if d.fixed then return d[1], d.fixed end
	if d.flat then
		local r = mod[tier]
		local a = ns.AFFIX[d[1]]
		return d[1], d.flat * ns.Scale[a.s](ns.SOCKET_TIER_LEVEL[tier]) * raw / ((r[1] + r[2]) / 2)
	end
	return d[1], raw / (d.div or 1)
end

------------------------------------------------------------------------
-- Materials (stackable; kept in the reagent bag, not the main bag).
------------------------------------------------------------------------
ns.MATS = {}
ns.MAT_ORDER = {}

local function mat(id, kind, tier, name, icon)
	ns.MATS[id] = { id = id, kind = kind, tier = tier, name = name, icon = icon, q = math.min(8, tier + 1) }
	ns.MAT_ORDER[#ns.MAT_ORDER + 1] = id
end

mat("bar1", "bar", 1, "구리 주괴", "INV_Ingot_02")
mat("bar2", "bar", 2, "철 주괴", "INV_Ingot_05")
mat("bar3", "bar", 3, "미스릴 주괴", "INV_Ingot_06")
mat("bar4", "bar", 4, "토륨 주괴", "INV_Ingot_07")
mat("bar5", "bar", 5, "아케이나이트 주괴", "INV_Ingot_08")
mat("leather1", "leather", 1, "얇은 가죽", "INV_Misc_LeatherScrap_03")
mat("leather2", "leather", 2, "일반 가죽", "INV_Misc_LeatherScrap_05")
mat("leather3", "leather", 3, "질긴 가죽", "INV_Misc_LeatherScrap_07")
mat("leather4", "leather", 4, "두꺼운 가죽", "INV_Misc_LeatherScrap_08")
mat("leather5", "leather", 5, "튼튼한 가죽", "INV_Misc_LeatherScrap_02")
mat("cloth1", "cloth", 1, "리넨 옷감", "INV_Fabric_Linen_01")
mat("cloth2", "cloth", 2, "양모 옷감", "INV_Fabric_Wool_01")
mat("cloth3", "cloth", 3, "비단 옷감", "INV_Fabric_Silk_01")
mat("cloth4", "cloth", 4, "마법 옷감", "INV_Fabric_Mageweave_01")
mat("cloth5", "cloth", 5, "룬무늬 옷감", "INV_Fabric_PurpleFire_01")
-- Socket materials (not TBH's): lines of ten grades. A line gives the same
-- stats at every grade, one for each gear group and never one twice; its
-- grade sets their tier (weapon: one above the grade; armour and
-- accessory: the grade; a scroll: the grade to two above, at random). Nine
-- of a line fuse into one of the same line a grade up (Forge.NextMat).
-- 보석 = the schools (damage, its defence, a stat of its own), 마법부여 =
-- the basics, 주문서 = the rarer ones. id = kind .. (base + line * 100 +
-- grade), e.g. gem300103 = 정교한 루비.
do
	-- the shadow, holy and arcane damage stat mods (TBH has only physical,
	-- fire, cold and lightning): fire's numbers
	local T = ns.TBH
	local NEW = { 902801, 902901, 903001 }
	for i, stat in ipairs({ "ShadowDamagePercent", "HolyDamagePercent", "ArcaneDamagePercent" }) do
		local m = { stat = stat, mod = "FLAT" }
		for t, r in ipairs(T.STAT_MODS[102501]) do m[t] = { r[1], r[2] } end
		T.STAT_MODS[NEW[i]] = m
	end
end
-- the stat mod (Data/TBH.lua STAT_MODS) each of our stats is read from
local SOCKET_MOD = {
	dmg_fire = 102501, dmg_frost = 102601, dmg_nature = 102701, dmg_phys = 102401,
	dmg_shadow = 902801, dmg_holy = 902901, dmg_arcane = 903001,
	res_fire = 101201, res_frost = 101301, res_nature = 101401, res_shadow = 101501, allres = 105201,
	atk = 100101, atkPct = 100102, aspd = 100201, cast = 104901, crit = 100302, critdmg = 100401,
	dmg_all = 100901, multi = 102001, cdr = 100701, move = 100801,
	hp = 100501, hpPct = 100502, armor = 100601, armorPct = 100602, dodge = 101601, block = 101701,
	dr = 103401, absorb = 104001, regen = 102301, hph = 103301, hpk = 105301, leech = 102101, heal = 105901,
}
-- the grades' words, as in every material's name (희미한 루비, 고대 가루)
ns.SOCKET_GRADE_WORD = { "희미한", "선명한", "정교한", "고대", "용의", "티탄", "별빛", "신성한", "천상의", "태초의" }
-- each line: its name, the noun after the grade's word, icons (spread over
-- the grades), and its stat for weapons, armour and accessories
ns.SOCKET_LINES = {
	gem = { base = 300000, lines = {
		{ name = "화염", noun = "루비", icons = { "INV_Misc_Gem_Ruby_02", "INV_Misc_Gem_Ruby_01", "INV_Misc_Gem_Ruby_03" },
			weapon = "dmg_fire", armor = "res_fire", accessory = "atk" },
		{ name = "냉기", noun = "사파이어", icons = { "INV_Misc_Gem_Sapphire_02", "INV_Misc_Gem_Sapphire_01", "INV_Misc_Gem_Sapphire_03" },
			weapon = "dmg_frost", armor = "res_frost", accessory = "crit" },
		{ name = "자연", noun = "에메랄드", icons = { "INV_Misc_Gem_Emerald_03", "INV_Misc_Gem_Emerald_01", "INV_Misc_Gem_Emerald_02" },
			weapon = "dmg_nature", armor = "res_nature", accessory = "cast" },
		{ name = "물리", noun = "토파즈", icons = { "INV_Misc_Gem_Topaz_02", "INV_Misc_Gem_Topaz_01", "INV_Misc_Gem_Topaz_03" },
			weapon = "dmg_phys", armor = "hp", accessory = "cdr" },
		{ name = "암흑", noun = "자수정", icons = { "INV_Misc_Gem_Amethyst_01", "INV_Misc_Gem_Amethyst_02", "INV_Misc_Gem_Amethyst_03" },
			weapon = "dmg_shadow", armor = "res_shadow", accessory = "leech" },
		{ name = "신성", noun = "진주", icons = { "INV_Misc_Gem_Pearl_03", "INV_Misc_Gem_Pearl_01", "INV_Misc_Gem_Pearl_02" },
			weapon = "dmg_holy", armor = "regen", accessory = "heal" },
		{ name = "비전", noun = "다이아몬드", icons = { "INV_Misc_Gem_Diamond_01", "INV_Misc_Gem_Crystal_02", "INV_Misc_Gem_Diamond_02" },
			weapon = "dmg_arcane", armor = "allres", accessory = "critdmg" },
	} },
	dust = { base = 310000, lines = {
		{ name = "힘", noun = "가루", icons = { "INV_Enchant_DustStrange", "INV_Enchant_DustSoul", "INV_Enchant_DustVision", "INV_Enchant_DustDream", "INV_Enchant_DustIllusion" },
			weapon = "atkPct", armor = "armor", accessory = "hp" },
		{ name = "신속", noun = "조각", icons = { "INV_Enchant_ShardGlimmeringSmall", "INV_Enchant_ShardGlowingSmall", "INV_Enchant_ShardRadientSmall", "INV_Enchant_ShardBrilliantSmall" },
			weapon = "aspd", armor = "dodge", accessory = "move" },
		{ name = "정밀", noun = "결정", icons = { "INV_Enchant_ShardGlimmeringLarge", "INV_Enchant_ShardGlowingLarge", "INV_Enchant_ShardRadientLarge", "INV_Enchant_ShardBrilliantLarge", "INV_Enchant_ShardNexusLarge" },
			weapon = "crit", armor = "block", accessory = "critdmg" },
		{ name = "활력", noun = "정수", icons = { "INV_Enchant_EssenceMagicSmall", "INV_Enchant_EssenceMagicLarge", "INV_Enchant_EssenceAstralSmall", "INV_Enchant_EssenceAstralLarge", "INV_Enchant_EssenceMysticalSmall", "INV_Enchant_EssenceMysticalLarge", "INV_Enchant_EssenceNetherSmall", "INV_Enchant_EssenceNetherLarge", "INV_Enchant_EssenceEternalSmall", "INV_Enchant_EssenceEternalLarge" },
			weapon = "hph", armor = "absorb", accessory = "regen" },
	} },
	scroll = { base = 320000, lines = {
		{ name = "파괴", noun = "파괴 주문서", icons = { "INV_Scroll_04" }, weapon = "dmg_all", armor = "dr", accessory = "hpk" },
		{ name = "연속", noun = "연속 주문서", icons = { "INV_Scroll_05" }, weapon = "multi", armor = "armorPct", accessory = "aspd" },
		{ name = "생명", noun = "생명 주문서", icons = { "INV_Scroll_01" }, weapon = "leech", armor = "hpPct", accessory = "heal" },
		{ name = "시간", noun = "시간 주문서", icons = { "INV_Scroll_03" }, weapon = "cdr", armor = "allres", accessory = "move" },
	} },
}
ns.SOCKET_MATS_BY = { gem = {}, dust = {}, scroll = {} } -- [kind][grade] = { id, ... } in line order
do
	local GROUPS = { "weapon", "armor", "accessory" }
	for _, kind in ipairs({ "gem", "dust", "scroll" }) do
		local def = ns.SOCKET_LINES[kind]
		for grade = 1, 10 do
			ns.SOCKET_MATS_BY[kind][grade] = {}
			for li, line in ipairs(def.lines) do
				local id = kind .. (def.base + li * 100 + grade)
				local icon = line.icons[math.ceil(grade * #line.icons / 10)]
				mat(id, kind, grade, ns.SOCKET_GRADE_WORD[grade] .. " " .. line.noun, icon)
				local m = ns.MATS[id]
				m.q, m.line = grade, li
				-- { stat mod, lowest tier, highest tier } for each gear group
				m.sock = {}
				for _, g in ipairs(GROUPS) do
					local lo, hi = grade, grade
					if kind == "scroll" then hi = math.min(10, grade + 2)
					elseif g == "weapon" then lo = math.min(10, grade + 1) hi = lo end
					m.sock[g] = { { SOCKET_MOD[line[g]], lo, hi } }
				end
				table.insert(ns.SOCKET_MATS_BY[kind][grade], id)
			end
		end
	end
end
-- the material of a line a grade up (nil at the top)
function ns.SocketMatUp(id)
	local m = ns.MATS[id]
	if not m or not m.line or m.tier >= 10 then return nil end
	return ns.SOCKET_MATS_BY[m.kind][m.tier + 1][m.line]
end
-- (saves from before the lines: each old material as the nearest line of
-- its grade; an old scroll's count is shared over the four lines)
ns.SOCKET_MAT_RENAMED = {
	gem110001 = "gem300101", -- 호안석
	gem110002 = "gem300201", -- 하급 월장석
	gem110003 = "gem300301", -- 공작석
	gem110004 = "gem300101", -- 이끼 마노
	gem110005 = "gem300401", -- 그림자석
	gem110006 = "gem300501", -- 공허 수정
	gem110007 = "gem300601", -- 빛의 진주
	gem110008 = "gem300701", -- 마나 마노
	gem111001 = "gem300102", -- 흑요석 조각
	gem111002 = "gem300502", -- 작고 빛나는 진주
	gem111003 = "gem300102", -- 비취
	gem111004 = "gem300102", -- 황수정
	gem112001 = "gem300103", -- 별루비
	gem112002 = "gem300203", -- 푸른 사파이어
	gem112003 = "gem300303", -- 큰 오팔
	gem112004 = "gem300503", -- 거대한 에메랄드
	gem112005 = "gem300403", -- 그림자 드레나이트
	gem112006 = "gem300503", -- 황혼의 자수정
	gem112007 = "gem300603", -- 태양석
	gem112008 = "gem300703", -- 마나 비취
	gem113001 = "gem300604", -- 신비한 수정
	gem113002 = "gem300204", -- 검은 진주
	gem113003 = "gem300104", -- 남옥
	gem113004 = "gem300104", -- 피의 석류석
	gem114001 = "gem300705", -- 아제로스 다이아몬드
	gem114002 = "gem300105", -- 새벽의 돌
	gem114003 = "gem300105", -- 엘룬의 별
	gem114004 = "gem300305", -- 무지갯빛 진주
	gem115001 = "gem300706", -- 밤눈
	gem115002 = "gem300306", -- 고귀한 토파즈
	gem115003 = "gem300106", -- 살아있는 루비
	gem115004 = "gem300206", -- 하늘빛 사파이어
	gem115005 = "gem300506", -- 어둠의 흑요석
	gem115006 = "gem300606", -- 나루의 결정
	gem115007 = "gem300706", -- 마나 루비
	gem116001 = "gem300107", -- 사자의 눈
	gem116002 = "gem300707", -- 검은 다이아몬드
	gem116003 = "gem300507", -- 바다물보라 에메랄드
	gem116004 = "gem300407", -- 어둠노래 자수정
	gem117001 = "gem300208", -- 황금 진주
	gem117002 = "gem300708", -- 용의 눈
	gem118001 = "gem300109", -- 악몽의 눈물
	gem118002 = "gem300509", -- 산의 피
	gem119001 = "gem300110", -- 대지폭풍 다이아몬드
	gem119002 = "gem300710", -- 하늘불꽃 다이아몬드
	dust120001 = "dust310101", -- 이상한 가루
	dust120002 = "dust310101", -- 하급 마법 정수
	dust120003 = "dust310201", -- 작은 빛나는 결정
	dust121001 = "dust310302", -- 영혼 가루
	dust121002 = "dust310102", -- 상급 마법 정수
	dust121003 = "dust310102", -- 하급 별의 정수
	dust121004 = "dust310202", -- 큰 빛나는 결정
	dust122001 = "dust310303", -- 환상 가루
	dust122002 = "dust310103", -- 상급 별의 정수
	dust122003 = "dust310403", -- 하급 신비의 정수
	dust122004 = "dust310303", -- 작은 광채 결정
	dust123001 = "dust310304", -- 꿈 가루
	dust123002 = "dust310104", -- 상급 신비의 정수
	dust123003 = "dust310404", -- 하급 황천의 정수
	dust123004 = "dust310304", -- 큰 광채 결정
	dust124001 = "dust310205", -- 환영 가루
	dust124002 = "dust310405", -- 상급 황천의 정수
	dust124003 = "dust310205", -- 하급 영원의 정수
	dust124004 = "dust310205", -- 작은 찬란한 결정
	dust125001 = "dust310206", -- 상급 영원의 정수
	dust125002 = "dust310306", -- 큰 찬란한 결정
	dust125003 = "dust310306", -- 작은 눈부신 결정
	dust125004 = "dust310306", -- 큰 눈부신 결정
	dust126001 = "dust310307", -- 연결의 결정
	dust126002 = "dust310207", -- 신비한 가루
	dust126003 = "dust310107", -- 하급 세계의 정수
	dust126004 = "dust310307", -- 상급 세계의 정수
	dust127001 = "dust310208", -- 공허 결정
	dust127002 = "dust310208", -- 큰 프리즘 조각
	dust128001 = "dust310209", -- 무한의 가루
	dust128002 = "dust310209", -- 우주의 정수
	dust129001 = "dust310310", -- 심연의 결정
	dust129002 = "dust310110", -- 천상의 조각
	scroll130001 = { "scroll320101", "scroll320201", "scroll320301", "scroll320401" },
	scroll131001 = { "scroll320102", "scroll320202", "scroll320302", "scroll320402" },
	scroll132001 = { "scroll320103", "scroll320203", "scroll320303", "scroll320403" },
	scroll133001 = { "scroll320104", "scroll320204", "scroll320304", "scroll320404" },
	scroll134001 = { "scroll320105", "scroll320205", "scroll320305", "scroll320405" },
	scroll135001 = { "scroll320106", "scroll320206", "scroll320306", "scroll320406" },
	scroll136001 = { "scroll320107", "scroll320207", "scroll320307", "scroll320407" },
	scroll137001 = { "scroll320108", "scroll320208", "scroll320308", "scroll320408" },
	scroll138001 = { "scroll320109", "scroll320209", "scroll320309", "scroll320409" },
	scroll139001 = { "scroll320110", "scroll320210", "scroll320310", "scroll320410" },
}

mat("seal1", "seal", 1, "낡은 행운의 인장", "INV_Misc_Coin_05")
mat("seal2", "seal", 2, "용사의 인장", "INV_Misc_Coin_03")
mat("seal3", "seal", 3, "운명의 인장", "INV_Misc_Coin_02")
mat("seal4", "seal", 4, "티탄의 인장", "INV_Misc_Coin_01")

-- the n-th socket material of a kind and grade (gem 3 -> "gem300103")
function ns.SocketMat(kind, grade, n)
	local list = ns.SOCKET_MATS_BY[kind][grade]
	return list and list[n or 1]
end

ns.MAT_KIND_NAME = {
	bar = "주괴", leather = "가죽", cloth = "옷감",
	gem = "보석", dust = "마법부여 재료", scroll = "주문서",
	seal = "행운의 인장",
}
ns.MAT_MAX_TIER = { bar = 5, leather = 5, cloth = 5, gem = 10, dust = 10, scroll = 10, seal = 4 }

-- Gold / forge experience a material is worth.
function ns.MatValue(id)
	local m = ns.MATS[id]
	local mult = (m.kind == "bar" or m.kind == "leather" or m.kind == "cloth") and 1 or 2.5
	if m.kind == "seal" then mult = 12 end
	local gold = math.floor(4 * 3 ^ (m.tier - 1) * mult)
	return gold, math.floor(gold * 1.2)
end

------------------------------------------------------------------------
-- Bonus-roll seals: gold fee and the quality odds of the item they roll.
------------------------------------------------------------------------
ns.SEAL = {
	{ mat = "seal1", gold = 200,    q = { 0, 10, 35, 35, 17, 3, 0, 0, 0, 0 } },
	{ mat = "seal2", gold = 2500,   q = { 0, 0, 12, 38, 34, 13, 3, 0, 0, 0 } },
	{ mat = "seal3", gold = 30000,  q = { 0, 0, 0, 20, 40, 28, 10, 2, 0, 0 } },
	{ mat = "seal4", gold = 250000, q = { 0, 0, 0, 0, 30, 40, 22, 7.5, 0.5, 0 } },
}

------------------------------------------------------------------------
-- Chests dropped by stages: kept by kind (monster, boss, act boss); what
-- each one holds is its stage's TBH box (Data/TBH.lua, Systems/Loot.lua).
------------------------------------------------------------------------
ns.CHEST = {
	-- rgb: the box's border on the battle window (bronze, silver, gold; red
	-- is kept for a full store)
	{ key = "common", name = "몬스터 상자",   icon = "INV_Box_01", cap = 20, box = "monster", rgb = { 0.80, 0.52, 0.30 } },
	{ key = "boss",   name = "우두머리 상자", icon = "INV_Box_03", cap = 10, box = "boss", rgb = { 0.70, 0.75, 0.83 } },
	{ key = "raid",   name = "막 우두머리 상자", icon = "INV_Box_04", cap = 5, box = "act", rgb = { 1.00, 0.80, 0.25 } },
}

------------------------------------------------------------------------
-- Crafting: slot groups, tiers and what each recipe costs.
------------------------------------------------------------------------
ns.CRAFT_GROUPS = {
	{ key = "mh",    name = "주무기",  slots = { "mh" },    cost = { bar = 6, leather = 2 } },
	{ key = "oh",    name = "보조장비", slots = { "oh" },    cost = { bar = 4, cloth = 2 } },
	{ key = "head",  name = "머리",         slots = { "head" },  cost = { leather = 3, cloth = 3 } },
	{ key = "chest", name = "가슴",        slots = { "chest" }, cost = { leather = 5, cloth = 4 } },
	{ key = "hands", name = "손",    slots = { "hands" }, cost = { leather = 3, bar = 2 } },
	{ key = "feet",  name = "발",        slots = { "feet" },  cost = { leather = 4, cloth = 1 } },
	{ key = "acc",   name = "액세서리", slots = { "wrist", "neck", "ring", "trinket" }, cost = { bar = 3, cloth = 3 } },
}

ns.CRAFT_TIERS = {
	-- levels: the item levels a tier makes, one picked evenly
	{ levels = { 5, 10 },     forge = 5,  gold = 60,    q = { 0, 45, 40, 13, 2, 0, 0, 0, 0, 0 } },
	{ levels = { 15, 20 },    forge = 15, gold = 500,   q = { 0, 25, 48, 22, 4.5, 0.5, 0, 0, 0, 0 } },
	{ levels = { 30, 40 },    forge = 30, gold = 4000,  q = { 0, 0, 50, 35, 12, 2.7, 0.3, 0, 0, 0 } },
	{ levels = { 50, 65 },    forge = 45, gold = 30000, q = { 0, 0, 30, 45, 19, 5, 1, 0, 0, 0 } },
	{ levels = { 80 },        forge = 60, gold = 200000, q = { 0, 0, 0, 55, 30, 11, 3.5, 0.5, 0, 0 } },
}

------------------------------------------------------------------------
-- Titan Forge operations: forge level needed and the one-time unlock fee.
------------------------------------------------------------------------
ns.FORGE_OPS = {
	{ key = "fuse",   name = "융합",          level = 1,  cost = 0, short = "장비 9개 → 1개",
		desc = "같은 등급 장비 9개를 합쳐 장비 1개를 만듭니다. 보통 한 등급 위가 나오고, 전설 등급부터는 같은 등급에 머물 수도 있습니다." },
	{ key = "smelt",  name = "분해",           level = 1,  cost = 10, short = "장비 → 골드, 경험치",
		desc = "아이템을 녹여 골드와 대장간 경험치를 얻습니다. 해금하면 가방에서 분해할 수 있습니다." },
	{ key = "craft",  name = "제작",           level = 5,  cost = 100, short = "원하는 부위 만들기",
		desc = "재료로 원하는 부위의 무작위 장비를 만듭니다." },
	{ key = "gem",    name = "보석 세공", level = 8,  cost = 300, short = "보석 홈 채우기",
		desc = "장비의 보석 홈에 무작위 능력치를 부여합니다." },
	{ key = "remove", name = "추출",      level = 10, cost = 1000, short = "부여한 능력치 지우기",
		desc = "부여된 능력치를 제거해 홈을 비웁니다. 재료는 돌려받지 못합니다." },
	{ key = "ench",   name = "마법부여",     level = 15, cost = 1000, short = "마법 홈 채우기",
		desc = "전설 등급 이상 장비에 마법을 부여합니다." },
	{ key = "seal",   name = "인장 굴리기", level = 20, cost = 3000, short = "인장으로 장비 얻기",
		desc = "행운의 인장과 골드를 바쳐 무작위 장비를 얻습니다." },
	{ key = "insc",   name = "주문각인",  level = 25, cost = 10000, short = "주문각인 홈 채우기",
		desc = "불멸 등급 이상 장비의 주문각인 홈에 주문서의 힘을 새깁니다." },
}
ns.FORGE_MAX = 100
