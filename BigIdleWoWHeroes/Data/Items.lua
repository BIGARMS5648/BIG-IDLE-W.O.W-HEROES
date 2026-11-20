-- Item qualities, equipment slots, stat (affix) definitions, materials and chests.
local _, ns = ...

------------------------------------------------------------------------
-- Qualities: how many inherent affixes and socket slots each one carries,
-- its stat multiplier and what it is worth in the Titan Forge.
------------------------------------------------------------------------
ns.QUALITY = {
	{ key = "poor",      name = { "하급", "Poor" },      hex = "9d9d9d", affix = 0, gem = 0, ench = 0, insc = 0, gold = 4,    fxp = 2,    mult = 0.85 },
	{ key = "common",    name = { "일반", "Common" },    hex = "ffffff", affix = 1, gem = 0, ench = 0, insc = 0, gold = 10,   fxp = 6,    mult = 1.00 },
	{ key = "uncommon",  name = { "고급", "Uncommon" },  hex = "1eff00", affix = 1, gem = 1, ench = 0, insc = 0, gold = 26,   fxp = 18,   mult = 1.15 },
	{ key = "rare",      name = { "희귀", "Rare" },      hex = "0070dd", affix = 2, gem = 2, ench = 0, insc = 0, gold = 65,   fxp = 54,   mult = 1.32 },
	{ key = "epic",      name = { "영웅", "Epic" },      hex = "a335ee", affix = 2, gem = 2, ench = 1, insc = 0, gold = 160,  fxp = 160,  mult = 1.52 },
	{ key = "legendary", name = { "전설", "Legendary" }, hex = "ff8000", affix = 3, gem = 2, ench = 1, insc = 1, gold = 400,  fxp = 500,  mult = 1.75 },
	{ key = "artifact",  name = { "유물", "Artifact" },  hex = "e6cc80", affix = 3, gem = 2, ench = 2, insc = 1, gold = 1000, fxp = 1600, mult = 2.02 },
	{ key = "mythic",    name = { "신화", "Mythic" },    hex = "ff3b5c", affix = 3, gem = 2, ench = 2, insc = 2, gold = 2500, fxp = 5400, mult = 2.35 },
}
ns.MAX_QUALITY = #ns.QUALITY

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
	mh      = { name = { "주무기", "Main Hand" },  cat = "weapon",    fxp = 1.0, w = 18 },
	oh      = { name = { "보조장비", "Off Hand" }, cat = "weapon",    fxp = 2.0, w = 10 },
	head    = { name = { "머리", "Head" },         cat = "armor",     fxp = 0.8, w = 12, tname = { "투구", "Helm" },
		base = { hp = 15, armor = 7 },
		icons = { "INV_Helmet_01", "INV_Helmet_03", "INV_Helmet_05", "INV_Helmet_09", "INV_Helmet_13" } },
	chest   = { name = { "가슴", "Chest" },        cat = "armor",     fxp = 1.0, w = 12, tname = { "갑옷", "Armor" },
		base = { hp = 25, armor = 10 },
		icons = { "INV_Chest_Cloth_01", "INV_Chest_Leather_03", "INV_Chest_Chain_05", "INV_Chest_Plate03", "INV_Chest_Plate10" } },
	hands   = { name = { "손", "Hands" },          cat = "armor",     fxp = 0.75, w = 10, tname = { "장갑", "Gauntlets" },
		base = { hp = 8, armor = 5 },
		icons = { "INV_Gauntlets_01", "INV_Gauntlets_04", "INV_Gauntlets_10", "INV_Gauntlets_15", "INV_Gauntlets_17" } },
	feet    = { name = { "발", "Feet" },           cat = "armor",     fxp = 0.7, w = 10, tname = { "장화", "Boots" },
		base = { hp = 8, armor = 5 },
		icons = { "INV_Boots_01", "INV_Boots_03", "INV_Boots_05", "INV_Boots_08", "INV_Boots_Plate_04" } },
	wrist   = { name = { "손목", "Wrist" },        cat = "accessory", fxp = 3.0, w = 8, tname = { "손목보호구", "Bracers" },
		base = { hp = 6, armor = 3 }, minLevel = 5,
		icons = { "INV_Bracer_01", "INV_Bracer_03", "INV_Bracer_05", "INV_Bracer_07", "INV_Bracer_09" } },
	neck    = { name = { "목", "Neck" },           cat = "accessory", fxp = 4.0, w = 6, tname = { "목걸이", "Amulet" },
		base = { hp = 14 }, minLevel = 8,
		icons = { "INV_Jewelry_Necklace_01", "INV_Jewelry_Necklace_02", "INV_Jewelry_Necklace_05", "INV_Jewelry_Necklace_07", "INV_Jewelry_Necklace_11" } },
	ring    = { name = { "반지", "Finger" },       cat = "accessory", fxp = 3.0, w = 8, tname = { "반지", "Ring" },
		base = { atk = 1.5 }, minLevel = 8,
		icons = { "INV_Jewelry_Ring_01", "INV_Jewelry_Ring_03", "INV_Jewelry_Ring_05", "INV_Jewelry_Ring_13", "INV_Jewelry_Ring_15" } },
	trinket = { name = { "장신구", "Trinket" },    cat = "accessory", fxp = 3.0, w = 6, tname = { "부적", "Charm" },
		base = { crit = 2 }, minLevel = 8,
		icons = { "INV_Jewelry_Talisman_01", "INV_Jewelry_Talisman_03", "INV_Jewelry_Talisman_05", "INV_Jewelry_Talisman_07", "INV_Jewelry_Talisman_10" } },
}

-- Weapon / off-hand types. Each class lists which of these it can wield.
ns.WTYPE = {
	sword    = { slot = "mh", name = { "도검", "Sword" },        base = { atk = 5.0, crit = 1 },
		icons = { "INV_Sword_04", "INV_Sword_10", "INV_Sword_20", "INV_Sword_27", "INV_Sword_39" } },
	axe      = { slot = "mh", name = { "도끼", "Axe" },          base = { atk = 5.5 },
		icons = { "INV_Axe_01", "INV_Axe_03", "INV_Axe_06", "INV_Axe_09", "INV_Axe_12" } },
	mace     = { slot = "mh", name = { "둔기", "Mace" },         base = { atk = 4.6, hp = 8 },
		icons = { "INV_Mace_01", "INV_Mace_03", "INV_Mace_04", "INV_Mace_07", "INV_Mace_13" } },
	dagger   = { slot = "mh", name = { "단검", "Dagger" },       base = { atk = 4.3, aspd = 8 },
		icons = { "INV_Weapon_ShortBlade_01", "INV_Weapon_ShortBlade_03", "INV_Weapon_ShortBlade_05", "INV_Weapon_ShortBlade_07", "INV_Weapon_ShortBlade_12" } },
	staff    = { slot = "mh", name = { "지팡이", "Staff" },      base = { atk = 5.2, cast = 5 },
		icons = { "INV_Staff_08", "INV_Staff_10", "INV_Staff_13", "INV_Staff_20", "INV_Staff_30" } },
	bow      = { slot = "mh", name = { "활", "Bow" },            base = { atk = 5.0, crit = 2 },
		icons = { "INV_Weapon_Bow_01", "INV_Weapon_Bow_02", "INV_Weapon_Bow_05", "INV_Weapon_Bow_07", "INV_Weapon_Bow_08" } },
	shield   = { slot = "oh", name = { "방패", "Shield" },       base = { armor = 14, block = 8 },
		icons = { "INV_Shield_02", "INV_Shield_04", "INV_Shield_05", "INV_Shield_06", "INV_Shield_09" } },
	orb      = { slot = "oh", name = { "마법 보주", "Orb" },     base = { atk = 1.6, crit = 2 },
		icons = { "INV_Misc_Orb_01", "INV_Misc_Orb_02", "INV_Misc_Orb_03", "INV_Misc_Orb_04", "INV_Misc_Orb_05" } },
	quiver   = { slot = "oh", name = { "화살통", "Quiver" },     base = { atk = 1.4, aspd = 6 },
		icons = { "INV_Misc_Quiver_01", "INV_Misc_Quiver_02", "INV_Misc_Quiver_03", "INV_Misc_Quiver_05", "INV_Misc_Quiver_07" } },
	offblade = { slot = "oh", name = { "보조 칼날", "Off-hand Blade" }, base = { atk = 2.2 },
		icons = { "INV_Weapon_ShortBlade_02", "INV_Weapon_ShortBlade_04", "INV_Weapon_ShortBlade_06", "INV_Weapon_ShortBlade_14", "INV_Weapon_ShortBlade_15" } },
	relic    = { slot = "oh", name = { "성물", "Relic" },        base = { hp = 16, heal = 8 },
		icons = { "INV_Misc_Idol_01", "INV_Misc_Idol_02", "INV_Misc_Idol_03", "INV_Misc_Book_09", "INV_Misc_Book_11" } },
	whetstone = { slot = "oh", name = { "숫돌", "Whetstone" },   base = { atk = 2.0, critdmg = 6 },
		icons = { "INV_Stone_SharpeningStone_01", "INV_Stone_SharpeningStone_02", "INV_Stone_SharpeningStone_03", "INV_Stone_SharpeningStone_04", "INV_Stone_SharpeningStone_05" } },
}
ns.WTYPES_MH = { "sword", "axe", "mace", "dagger", "staff", "bow" }
ns.WTYPES_OH = { "shield", "orb", "quiver", "offblade", "relic", "whetstone" }

-- Material tier names by item level (one per 10 levels).
ns.ITEM_TIER = {
	{ "낡은", "Worn" }, { "구리", "Copper" }, { "청동", "Bronze" }, { "철제", "Iron" }, { "강철", "Steel" },
	{ "미스릴", "Mithril" }, { "토륨", "Thorium" }, { "검은무쇠", "Dark Iron" }, { "아케이나이트", "Arcanite" }, { "엘레멘티움", "Elementium" },
}

------------------------------------------------------------------------
-- Stats. An affix key maps onto a target stat and one of three layers:
--   final = (base + sum flat) * (1 + sum add) * product(1 + mult)
-- f: display format, s: scaling curve for rolled flat values.
------------------------------------------------------------------------
ns.AFFIX = {
	atk        = { t = "atk",   l = "flat", n = { "공격력", "Attack" },                 f = "num", s = "A" },
	atkPct     = { t = "atk",   l = "add",  n = { "공격력", "Attack" },                 f = "pct" },
	atkMult    = { t = "atk",   l = "mult", n = { "공격력", "Attack" },                 f = "pct" },
	hp         = { t = "hp",    l = "flat", n = { "생명력", "Health" },                 f = "num", s = "H" },
	hpPct      = { t = "hp",    l = "add",  n = { "생명력", "Health" },                 f = "pct" },
	armor      = { t = "armor", l = "flat", n = { "방어도", "Armor" },                  f = "num", s = "R" },
	armorPct   = { t = "armor", l = "add",  n = { "방어도", "Armor" },                  f = "pct" },
	aspd       = { t = "aspd",  l = "add",  n = { "공격 속도", "Attack Speed" },        f = "pct" },
	aspdMult   = { t = "aspd",  l = "mult", n = { "공격 속도", "Attack Speed" },        f = "pct" },
	crit       = { t = "crit",    l = "flat", n = { "치명타 확률", "Crit Chance" },     f = "pct" },
	critdmg    = { t = "critdmg", l = "flat", n = { "치명타 피해", "Crit Damage" },     f = "pct" },
	regen      = { t = "regen", l = "flat", n = { "초당 생명력 회복", "Health Regen/s" }, f = "num", s = "H" },
	hph        = { t = "hph",   l = "flat", n = { "적중 시 생명력", "Health per Hit" }, f = "num", s = "H" },
	hpk        = { t = "hpk",   l = "flat", n = { "처치 시 생명력", "Health per Kill" }, f = "num", s = "H" },
	leech      = { t = "leech", l = "flat", n = { "생명력 흡수", "Life Leech" },        f = "pct" },
	dodge      = { t = "dodge", l = "flat", n = { "회피 확률", "Dodge Chance" },        f = "pct" },
	block      = { t = "block", l = "flat", n = { "방어 확률", "Block Chance" },        f = "pct" },
	dr         = { t = "dr",    l = "flat", n = { "받는 피해 감소", "Damage Reduction" }, f = "pct" },
	absorb     = { t = "absorb", l = "flat", n = { "피해 흡수", "Damage Absorption" },  f = "num", s = "H" },
	cdr        = { t = "cdr",   l = "flat", n = { "재사용 대기시간 감소", "Cooldown Reduction" }, f = "pct" },
	cast       = { t = "cast",  l = "flat", n = { "시전 속도", "Cast Speed" },          f = "pct" },
	move       = { t = "move",  l = "flat", n = { "이동 속도", "Movement Speed" },      f = "pct" },
	heal       = { t = "heal",  l = "flat", n = { "치유량 증가", "Healing Done" },      f = "pct" },
	multi      = { t = "multi", l = "flat", n = { "연속 타격", "Multistrike" },         f = "pct" },
	dmg_phys   = { t = "dmg_phys",   l = "flat", n = { "물리 피해", "Physical Damage" }, f = "pct" },
	dmg_fire   = { t = "dmg_fire",   l = "flat", n = { "화염 피해", "Fire Damage" },    f = "pct" },
	dmg_frost  = { t = "dmg_frost",  l = "flat", n = { "냉기 피해", "Frost Damage" },   f = "pct" },
	dmg_nature = { t = "dmg_nature", l = "flat", n = { "자연 피해", "Nature Damage" },  f = "pct" },
	dmg_shadow = { t = "dmg_shadow", l = "flat", n = { "암흑 피해", "Shadow Damage" },  f = "pct" },
	dmg_holy   = { t = "dmg_holy",   l = "flat", n = { "신성 피해", "Holy Damage" },    f = "pct" },
	dmg_arcane = { t = "dmg_arcane", l = "flat", n = { "비전 피해", "Arcane Damage" },  f = "pct" },
	dmg_all    = { t = "dmg_all",    l = "flat", n = { "모든 피해", "All Damage" },     f = "pct" },
	res_fire   = { t = "res_fire",   l = "flat", n = { "화염 저항", "Fire Resistance" },   f = "pct" },
	res_frost  = { t = "res_frost",  l = "flat", n = { "냉기 저항", "Frost Resistance" },  f = "pct" },
	res_nature = { t = "res_nature", l = "flat", n = { "자연 저항", "Nature Resistance" }, f = "pct" },
	res_shadow = { t = "res_shadow", l = "flat", n = { "암흑 저항", "Shadow Resistance" }, f = "pct" },
	allres     = { t = "allres", l = "flat", n = { "모든 원소 저항", "All Resistance" }, f = "pct" },
	exp        = { t = "exp",   l = "flat", n = { "경험치 획득", "Experience Gain" },   f = "pct" },
	gold       = { t = "gold",  l = "flat", n = { "골드 획득", "Gold Gain" },           f = "pct" },
	skills     = { t = "skills", l = "flat", n = { "모든 기술 레벨", "All Skill Levels" }, f = "int" },
	thorns     = { t = "thorns", l = "flat", n = { "가시 반사", "Thorns" },             f = "pct" },
}

ns.SCHOOL = {
	phys   = { name = { "물리", "Physical" }, hex = "ffffff" },
	fire   = { name = { "화염", "Fire" },     hex = "ff8040" },
	frost  = { name = { "냉기", "Frost" },    hex = "80c0ff" },
	nature = { name = { "자연", "Nature" },   hex = "70e070" },
	shadow = { name = { "암흑", "Shadow" },   hex = "b080ff" },
	holy   = { name = { "신성", "Holy" },     hex = "ffe680" },
	arcane = { name = { "비전", "Arcane" },   hex = "ff80ff" },
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

-- Socketed stats: three socket kinds, each with its own pool per category.
ns.SOCKET = {
	gem = {
		name = { "보석 세공", "Gem Socket" }, mat = "gem", short = { "보석", "Gem" },
		weapon    = { { "atkPct", 5, 9 }, { "crit", 2, 4 }, { "critdmg", 8, 16 }, { "dmg_all", 3, 6 } },
		armor     = { { "hpPct", 4, 8 }, { "armorPct", 5, 10 }, { "regen", 0.5, 0.9 }, { "allres", 2, 5 } },
		accessory = { { "atk", 0.8, 1.4 }, { "aspd", 3, 6 }, { "crit", 2, 4 }, { "cdr", 2, 4 } },
	},
	ench = {
		name = { "마법부여", "Enchant" }, mat = "dust", short = { "마법부여", "Enchant" },
		weapon    = { { "aspd", 4, 8 }, { "hph", 0.7, 1.2 }, { "leech", 0.6, 1.4 }, { "cast", 5, 10 } },
		armor     = { { "dr", 1.5, 3 }, { "dodge", 2, 4 }, { "block", 2, 5 }, { "absorb", 0.6, 1.0 } },
		accessory = { { "critdmg", 10, 20 }, { "heal", 8, 16 }, { "move", 4, 8 }, { "cdr", 3, 5 } },
	},
	insc = {
		name = { "룬 각인", "Inscription" }, mat = "scroll", short = { "각인", "Inscription" },
		weapon    = { { "multi", 4, 8 }, { "atkPct", 8, 14 }, { "dmg_all", 5, 9 } },
		armor     = { { "hpPct", 7, 12 }, { "dr", 2, 4 }, { "hpk", 3, 5 } },
		accessory = { { "exp", 4, 8 }, { "gold", 4, 8 }, { "cdr", 3, 6 }, { "skills", 1, 1 } },
	},
}
ns.SOCKET_KINDS = { "gem", "ench", "insc" }
ns.SOCKET_FIELD = { gem = "g", ench = "e", insc = "i" }
-- Socket material tier -> value multiplier, and the level its flat stats scale to.
ns.SOCKET_TIER_MULT = { 0.75, 1.0, 1.25, 1.5, 1.75, 2.1 }
ns.SOCKET_TIER_LEVEL = { 5, 20, 35, 50, 70, 90 }

------------------------------------------------------------------------
-- Materials (stackable; kept in the reagent bag, not the main bag).
------------------------------------------------------------------------
ns.MATS = {}
ns.MAT_ORDER = {}

local function mat(id, kind, tier, ko, en, icon)
	ns.MATS[id] = { id = id, kind = kind, tier = tier, name = { ko, en }, icon = icon, q = math.min(8, tier + 1) }
	ns.MAT_ORDER[#ns.MAT_ORDER + 1] = id
end

mat("bar1", "bar", 1, "구리 주괴", "Copper Bar", "INV_Ingot_02")
mat("bar2", "bar", 2, "철 주괴", "Iron Bar", "INV_Ingot_05")
mat("bar3", "bar", 3, "미스릴 주괴", "Mithril Bar", "INV_Ingot_06")
mat("bar4", "bar", 4, "토륨 주괴", "Thorium Bar", "INV_Ingot_07")
mat("bar5", "bar", 5, "아케이나이트 주괴", "Arcanite Bar", "INV_Ingot_08")
mat("leather1", "leather", 1, "얇은 가죽", "Light Leather", "INV_Misc_LeatherScrap_03")
mat("leather2", "leather", 2, "일반 가죽", "Medium Leather", "INV_Misc_LeatherScrap_05")
mat("leather3", "leather", 3, "질긴 가죽", "Heavy Leather", "INV_Misc_LeatherScrap_07")
mat("leather4", "leather", 4, "두꺼운 가죽", "Thick Leather", "INV_Misc_LeatherScrap_08")
mat("leather5", "leather", 5, "튼튼한 가죽", "Rugged Leather", "INV_Misc_LeatherScrap_02")
mat("cloth1", "cloth", 1, "리넨 옷감", "Linen Cloth", "INV_Fabric_Linen_01")
mat("cloth2", "cloth", 2, "양모 옷감", "Wool Cloth", "INV_Fabric_Wool_01")
mat("cloth3", "cloth", 3, "비단 옷감", "Silk Cloth", "INV_Fabric_Silk_01")
mat("cloth4", "cloth", 4, "마법 옷감", "Mageweave Cloth", "INV_Fabric_Mageweave_01")
mat("cloth5", "cloth", 5, "룬무늬 옷감", "Runecloth", "INV_Fabric_PurpleFire_01")
mat("gem1", "gem", 1, "공작석", "Malachite", "INV_Misc_Gem_Emerald_03")
mat("gem2", "gem", 2, "그림자석", "Shadowgem", "INV_Misc_Gem_Amethyst_01")
mat("gem3", "gem", 3, "황수정", "Citrine", "INV_Misc_Gem_Opal_02")
mat("gem4", "gem", 4, "별루비", "Star Ruby", "INV_Misc_Gem_Ruby_02")
mat("gem5", "gem", 5, "아제로스 다이아몬드", "Azerothian Diamond", "INV_Misc_Gem_Diamond_01")
mat("gem6", "gem", 6, "신비한 수정", "Arcane Crystal", "INV_Misc_Gem_Crystal_02")
mat("dust1", "dust", 1, "이상한 가루", "Strange Dust", "INV_Enchant_DustStrange")
mat("dust2", "dust", 2, "영혼 가루", "Soul Dust", "INV_Enchant_DustSoul")
mat("dust3", "dust", 3, "환상 가루", "Vision Dust", "INV_Enchant_DustVision")
mat("dust4", "dust", 4, "꿈 가루", "Dream Dust", "INV_Enchant_DustDream")
mat("dust5", "dust", 5, "환영 가루", "Illusion Dust", "INV_Enchant_DustIllusion")
mat("dust6", "dust", 6, "눈부신 큰 결정", "Large Brilliant Shard", "INV_Enchant_ShardBrilliantLarge")
mat("scroll1", "scroll", 1, "희미한 룬 주문서", "Faded Rune Scroll", "INV_Scroll_01")
mat("scroll2", "scroll", 2, "선명한 룬 주문서", "Clear Rune Scroll", "INV_Scroll_02")
mat("scroll3", "scroll", 3, "정교한 룬 주문서", "Intricate Rune Scroll", "INV_Scroll_03")
mat("scroll4", "scroll", 4, "고대 룬 주문서", "Ancient Rune Scroll", "INV_Scroll_04")
mat("scroll5", "scroll", 5, "용의 룬 주문서", "Draconic Rune Scroll", "INV_Scroll_05")
mat("scroll6", "scroll", 6, "티탄 룬 주문서", "Titan Rune Scroll", "INV_Scroll_06")
mat("seal1", "seal", 1, "낡은 행운의 주화", "Worn Coin of Fortune", "INV_Misc_Coin_05")
mat("seal2", "seal", 2, "용사의 인장", "Seal of Valor", "INV_Misc_Coin_03")
mat("seal3", "seal", 3, "운명의 인장", "Seal of Fate", "INV_Misc_Coin_02")
mat("seal4", "seal", 4, "티탄의 인장", "Seal of the Titans", "INV_Misc_Coin_01")

ns.MAT_KIND_NAME = {
	bar = { "주괴", "Bars" }, leather = { "가죽", "Leather" }, cloth = { "옷감", "Cloth" },
	gem = { "보석", "Gems" }, dust = { "마법부여 재료", "Enchanting" }, scroll = { "룬 주문서", "Rune Scrolls" },
	seal = { "행운의 인장", "Seals" },
}
ns.MAT_MAX_TIER = { bar = 5, leather = 5, cloth = 5, gem = 6, dust = 6, scroll = 6, seal = 4 }

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
	{ mat = "seal1", gold = 200,    q = { 0, 10, 35, 35, 17, 3, 0, 0 } },
	{ mat = "seal2", gold = 2500,   q = { 0, 0, 12, 38, 34, 13, 3, 0 } },
	{ mat = "seal3", gold = 30000,  q = { 0, 0, 0, 20, 40, 28, 10, 2 } },
	{ mat = "seal4", gold = 250000, q = { 0, 0, 0, 0, 30, 40, 22, 8 } },
}

------------------------------------------------------------------------
-- Chests dropped by stages.
------------------------------------------------------------------------
ns.CHEST = {
	{ key = "common", name = { "낡은 상자", "Battered Chest" },   icon = "INV_Box_01", cap = 20, auto = 300,
		q = { 30, 45, 20, 4.5, 0.5, 0.02, 0.002, 0.0002 }, gear = 78, mat = 20, seal = 2 },
	{ key = "boss",   name = { "우두머리의 궤짝", "Boss Cache" }, icon = "INV_Box_03", cap = 10, auto = 600,
		q = { 0, 30, 42, 22, 5.4, 0.6, 0.03, 0.002 }, gear = 72, mat = 22, seal = 6 },
	{ key = "raid",   name = { "공격대 보물 상자", "Raid Hoard" }, icon = "INV_Box_04", cap = 5, auto = 600,
		q = { 0, 0, 25, 45, 24, 5.5, 0.5, 0.03 }, gear = 66, mat = 24, seal = 10 },
}

------------------------------------------------------------------------
-- Crafting: slot groups, tiers and what each recipe costs.
------------------------------------------------------------------------
ns.CRAFT_GROUPS = {
	{ key = "mh",    name = { "주무기", "Main Hand" },  slots = { "mh" },    cost = { bar = 6, leather = 2 } },
	{ key = "oh",    name = { "보조장비", "Off Hand" }, slots = { "oh" },    cost = { bar = 4, cloth = 2 } },
	{ key = "head",  name = { "투구", "Helm" },         slots = { "head" },  cost = { leather = 3, cloth = 3 } },
	{ key = "chest", name = { "갑옷", "Armor" },        slots = { "chest" }, cost = { leather = 5, cloth = 4 } },
	{ key = "hands", name = { "장갑", "Gauntlets" },    slots = { "hands" }, cost = { leather = 3, bar = 2 } },
	{ key = "feet",  name = { "장화", "Boots" },        slots = { "feet" },  cost = { leather = 4, cloth = 1 } },
	{ key = "acc",   name = { "장신구류", "Accessory" }, slots = { "wrist", "neck", "ring", "trinket" }, cost = { bar = 3, cloth = 3 } },
}

ns.CRAFT_TIERS = {
	{ lo = 1,  hi = 15,  forge = 5,  gold = 60,    q = { 0, 45, 40, 13, 2, 0, 0, 0 } },
	{ lo = 15, hi = 30,  forge = 15, gold = 500,   q = { 0, 25, 48, 22, 4.5, 0.5, 0, 0 } },
	{ lo = 30, hi = 50,  forge = 30, gold = 4000,  q = { 0, 0, 50, 35, 12, 2.7, 0.3, 0 } },
	{ lo = 50, hi = 70,  forge = 45, gold = 30000, q = { 0, 0, 30, 45, 19, 5, 1, 0 } },
	{ lo = 70, hi = 100, forge = 60, gold = 200000, q = { 0, 0, 0, 55, 30, 11, 3.5, 0.5 } },
}

------------------------------------------------------------------------
-- Titan Forge operations: forge level needed and the one-time unlock fee.
------------------------------------------------------------------------
ns.FORGE_OPS = {
	{ key = "fuse",   name = { "융합", "Fusion" },          level = 1,  cost = 0,
		desc = { "같은 등급 장비 9개를 더 높은 등급 1개로 융합합니다.", "Fuse 9 items of one quality into one of a higher quality." } },
	{ key = "smelt",  name = { "용해", "Smelt" },           level = 1,  cost = 10,
		desc = { "아이템을 녹여 골드와 용광로 경험치를 얻습니다.", "Melt items down into gold and forge experience." } },
	{ key = "craft",  name = { "제작", "Craft" },           level = 5,  cost = 100,
		desc = { "재료로 원하는 부위의 무작위 장비를 만듭니다.", "Turn materials into a random item for a chosen slot." } },
	{ key = "gem",    name = { "보석 세공", "Gem Socket" }, level = 8,  cost = 300,
		desc = { "장비의 보석 홈에 무작위 능력치를 부여합니다.", "Add a random stat to a gem socket." } },
	{ key = "remove", name = { "추출", "Extraction" },      level = 10, cost = 1000,
		desc = { "부여된 능력치를 제거해 홈을 비웁니다. 재료는 돌려받지 못합니다.", "Clear an applied stat. The material is not refunded." } },
	{ key = "ench",   name = { "마법부여", "Enchant" },     level = 15, cost = 1000,
		desc = { "영웅 등급 이상 장비에 마법을 부여합니다.", "Enchant items of Epic quality or better." } },
	{ key = "seal",   name = { "보너스 굴림", "Bonus Roll" }, level = 20, cost = 3000,
		desc = { "행운의 인장과 골드를 바쳐 무작위 장비를 얻습니다.", "Offer a seal and gold for one random item." } },
	{ key = "insc",   name = { "룬 각인", "Inscription" },  level = 25, cost = 10000,
		desc = { "전설 등급 이상 장비에 룬을 새깁니다.", "Inscribe runes on Legendary or better items." } },
}
ns.FORGE_MAX = 100
