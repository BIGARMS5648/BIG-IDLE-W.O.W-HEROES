-- Rune tree: account-wide upgrades bought with gold. One root rune and six
-- branches; every rune needs at least one level in the rune before it.
--
-- Bonus keys are read through ns.Bonus(key) (see Systems/Runes.lua). Keys that
-- match an affix name (atkPct, hpPct, ...) are applied to every hero.
local _, ns = ...

ns.RUNE_ROOT = {
	id = "root", name = "용사의 룬", icon = "INV_Misc_Rune_01",
	max = 1, stat = "atk", per = 2, cost = 50, growth = 1,
}

-- R(id, name, icon, max, stat, per, cost, growth)
local function R(id, name, icon, maxLevel, stat, per, cost, growth)
	return { id = id, name = name, icon = icon, max = maxLevel, stat = stat, per = per, cost = cost, growth = growth or 1.7 }
end

ns.RUNE_BRANCHES = {
	{ key = "war", name = "전쟁", hex = "ff5040", nodes = {
		R("w1", "힘의 룬", "Ability_Warrior_OffensiveStance", 5, "atkPct", 2, 100, 1.6),
		R("w2", "신속의 룬", "Ability_Rogue_Sprint", 5, "aspd", 1.5, 300),
		R("w3", "예리함의 룬", "Ability_CriticalStrike", 5, "crit", 1, 800),
		R("w4", "강력한 힘의 룬", "Ability_Warrior_OffensiveStance", 5, "atkPct", 3, 3000, 1.8),
		R("w5", "파괴의 룬", "Ability_BackStab", 5, "critdmg", 5, 10000, 1.8),
		R("w6", "강력한 신속의 룬", "Ability_Rogue_Sprint", 5, "aspd", 2, 30000, 1.8),
		R("w7", "정복자의 룬", "Ability_Warrior_OffensiveStance", 10, "atkPct", 4, 100000),
		R("w8", "학살의 룬", "Ability_Warrior_WarCry", 10, "dmg_all", 2, 400000),
		R("w9", "전쟁군주의 룬", "Ability_Warrior_OffensiveStance", 10, "atkPct", 6, 10000000, 1.6),
	} },
	{ key = "guard", name = "수호", hex = "4080ff", nodes = {
		R("g1", "활력의 룬", "Spell_Nature_Rejuvenation", 5, "hpPct", 3, 100, 1.6),
		R("g2", "강철의 룬", "INV_Shield_06", 5, "armorPct", 3, 300),
		R("g3", "재생의 룬", "Spell_Nature_ResistNature", 5, "regenPct", 0.05, 800),
		R("g4", "강력한 활력의 룬", "Spell_Nature_Rejuvenation", 5, "hpPct", 4, 3000, 1.8),
		R("g5", "결계의 룬", "Spell_Frost_WizardMark", 5, "allres", 2, 10000, 1.8),
		R("g6", "강력한 강철의 룬", "INV_Shield_06", 5, "armorPct", 4, 30000, 1.8),
		R("g7", "불굴의 룬", "Spell_Nature_Rejuvenation", 10, "hpPct", 5, 100000),
		R("g8", "인내의 룬", "Ability_Defend", 10, "dr", 0.5, 400000),
		R("g9", "수호신의 룬", "Spell_Nature_Rejuvenation", 10, "hpPct", 8, 10000000, 1.6),
	} },
	{ key = "wealth", name = "재물", hex = "ffd100", nodes = {
		R("m1", "재물의 룬", "INV_Misc_Coin_02", 5, "gold", 5, 80, 1.6),
		R("m2", "현상금의 룬", "INV_Misc_Coin_06", 3, "bossGold", 20, 250),
		R("m3", "연금술의 룬", "INV_Misc_Coin_04", 5, "smeltGold", 5, 700),
		R("m4", "강력한 재물의 룬", "INV_Misc_Coin_02", 5, "gold", 6, 2500, 1.8),
		R("m5", "강력한 현상금의 룬", "INV_Misc_Coin_06", 5, "bossGold", 30, 8000, 1.8),
		R("m6", "강력한 연금술의 룬", "INV_Misc_Coin_04", 5, "smeltGold", 6, 25000, 1.8),
		R("m7", "상인의 룬", "INV_Misc_Coin_02", 10, "gold", 8, 90000),
		R("m8", "보물 사냥꾼의 룬", "INV_Misc_Coin_02", 10, "gold", 10, 350000),
		R("m9", "무역왕의 룬", "INV_Misc_Coin_02", 10, "gold", 12, 9000000, 1.6),
	} },
	{ key = "growth", name = "성장", hex = "40d060", nodes = {
		R("x1", "성장의 룬", "INV_Misc_Book_07", 5, "exp", 5, 80, 1.6),
		R("x2", "휴식의 룬", "INV_Misc_PocketWatch_01", 3, "offline", 10, 300),
		R("x3", "단련의 룬", "Trade_BlackSmithing", 5, "forgeExp", 5, 700),
		R("x4", "강력한 성장의 룬", "INV_Misc_Book_07", 5, "exp", 6, 2500, 1.8),
		R("x5", "강력한 휴식의 룬", "INV_Misc_PocketWatch_01", 5, "offline", 10, 8000, 1.8),
		R("x6", "강력한 단련의 룬", "Trade_BlackSmithing", 5, "forgeExp", 8, 25000, 1.8),
		R("x7", "수련의 룬", "INV_Misc_Book_07", 10, "exp", 8, 90000),
		R("x8", "긴 휴식의 룬", "INV_Misc_PocketWatch_02", 4, "offlineCap", 1, 200000, 2.0),
		R("x9", "깨달음의 룬", "INV_Misc_Book_07", 10, "exp", 10, 9000000, 1.6),
	} },
	{ key = "explore", name = "탐험", hex = "c080ff", nodes = {
		R("e1", "탐험의 룬", "INV_Box_01", 5, "chestChance", 1, 120, 1.6),
		R("e2", "보관의 룬", "INV_Misc_Bag_08", 3, "chestCap", 5, 350),
		R("e3", "개봉의 룬", "INV_Misc_Key_03", 1, "autoOpen", 1, 2000),
		R("e4", "강력한 탐험의 룬", "INV_Box_01", 5, "chestChance", 1, 4000, 1.8),
		R("e5", "전리품의 룬", "INV_Box_03", 5, "bossChest", 5, 10000, 1.8),
		R("e6", "태엽의 룬", "INV_Misc_Key_04", 5, "autoCd", 10, 30000, 1.8),
		R("e7", "강력한 보관의 룬", "INV_Misc_Bag_08", 5, "chestCap", 5, 60000),
		R("e8", "행운의 룬", "INV_Misc_Rune_05", 10, "luck", 3, 250000),
		R("e9", "정복의 룬", "INV_Box_03", 10, "bossChest", 5, 8000000, 1.6),
	} },
	{ key = "command", name = "지휘", hex = "ff9040", nodes = {
		R("c1", "지휘의 룬", "INV_Misc_GroupNeedMore", 1, "party", 1, 300),
		R("c2", "확장의 룬", "INV_Misc_Bag_10", 5, "bag", 4, 150, 1.6),
		R("c3", "지휘의 룬 II", "INV_Misc_GroupNeedMore", 1, "party", 1, 5000),
		R("c4", "각성의 룬", "INV_Misc_Book_11", 1, "skillSlot", 1, 20000),
		R("c5", "지휘의 룬 III", "INV_Misc_GroupNeedMore", 1, "party", 1, 40000),
		R("c6", "금고의 룬", "INV_Box_02", 5, "bank", 10, 8000, 1.8),
		R("c7", "지휘의 룬 IV", "INV_Misc_GroupLooking", 1, "party", 1, 150000),
		R("c8", "강력한 확장의 룬", "INV_Misc_Bag_10", 5, "bag", 4, 60000),
		R("c9", "강력한 각성의 룬", "INV_Misc_Book_11", 1, "skillSlot", 1, 400000),
		R("c10", "시간 왜곡의 룬", "Spell_Nature_TimeStop", 5, "speed", 4, 800000, 2.0),
	} },
}

-- How each bonus key reads in tooltips, with %s for the value.
ns.BONUS_TEXT = {
	gold        = "골드 획득 +%s%%",
	bossGold    = "우두머리 처치 골드 +%s%%",
	smeltGold   = "분해 골드 +%s%%",
	exp         = "경험치 획득 +%s%%",
	offline     = "오프라인 보상 +%s%%",
	offlineCap  = "오프라인 보상 최대 시간 +%s시간",
	forgeExp    = "용광로 경험치 +%s%%",
	chestChance = "낡은 상자 획득 확률 +%s%%p",
	chestCap    = "상자 보관 한도 +%s",
	autoOpen    = "상자 자동 개봉",
	bossChest   = "우두머리 추가 궤짝 확률 +%s%%",
	autoCd      = "자동 개봉 주기 -%s%%",
	luck        = "높은 등급 장비 확률 +%s%%",
	party       = "파티 슬롯 +%s",
	bag         = "가방 칸 +%s",
	bank        = "은행 칸 +%s",
	skillSlot   = "영웅 기술 슬롯 +%s",
	speed       = "전투 진행 속도 +%s%%",
}

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

function ns.RuneCost(node, level)
	-- cost of buying `level` (1-based)
	local c = node.cost * node.growth ^ (level - 1)
	if c >= 1000 then
		c = math.floor(c / 100 + 0.5) * 100
	else
		c = math.floor(c / 10 + 0.5) * 10
	end
	return c
end
