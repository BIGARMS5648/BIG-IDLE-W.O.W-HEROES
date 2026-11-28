-- Classes and specializations. A hero is created as one specialization of a
-- class; the specialization decides its role, weapons, base stats and talents.
-- The party always has five role slots: 1 tank, 3 damage dealers, 1 healer.
local _, ns = ...

ns.ROLE = {
	TANK   = { name = "방어 전담",   hex = "4c8dff", art = "role_tank" },
	DPS    = { name = "공격 전담", hex = "ff5a47", art = "role_dps" },
	HEALER = { name = "치유 전담", hex = "45d16a", art = "role_heal" },
}

-- Party slot index -> role it accepts.
ns.PARTY_ROLES = { "TANK", "DPS", "DPS", "DPS", "HEALER" }
ns.PARTY_SIZE = 5

ns.HERO_MAX_LEVEL = 100
ns.ROSTER_MAX = 12
ns.TREE_TIER_POINTS = 10 -- points that must be spent to open each further tier

-- Gold needed to create the n-th hero (the first is free).
ns.HERO_COST = { 0, 300, 600, 1200, 2500, 6000, 15000, 40000, 100000, 250000, 600000, 1500000 }

-- Round class portraits (same sheet and layout on every client).
ns.CLASS_ICON_FILE = "Interface\\TargetingFrame\\UI-Classes-Circles"
ns.CLASS_ICON_COORD = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE    = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE   = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID   = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER  = { 0, 0.25, 0.25, 0.5 },
	SHAMAN  = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST  = { 0.49609375, 0.7421875, 0.25, 0.5 },
	WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

ns.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

ns.CLASSES = {
	WARRIOR = { name = "전사",     hex = "c79c6e", specs = { "WARRIOR_ARMS", "WARRIOR_FURY", "WARRIOR_PROT" } },
	PALADIN = { name = "성기사",   hex = "f58cba", specs = { "PALADIN_HOLY", "PALADIN_PROT", "PALADIN_RET" } },
	HUNTER  = { name = "사냥꾼",    hex = "abd473", specs = { "HUNTER_BM", "HUNTER_MM", "HUNTER_SV" } },
	ROGUE   = { name = "도적",       hex = "fff569", specs = { "ROGUE_ASSA", "ROGUE_OUTLAW", "ROGUE_SUB" } },
	PRIEST  = { name = "사제",      hex = "ffffff", specs = { "PRIEST_DISC", "PRIEST_HOLY", "PRIEST_SHADOW" } },
	SHAMAN  = { name = "주술사",    hex = "2e8bff", specs = { "SHAMAN_ELE", "SHAMAN_ENH", "SHAMAN_RESTO" } },
	MAGE    = { name = "마법사",      hex = "69ccf0", specs = { "MAGE_ARCANE", "MAGE_FIRE", "MAGE_FROST" } },
	WARLOCK = { name = "흑마법사", hex = "9482c9", specs = { "WARLOCK_AFF", "WARLOCK_DEMO", "WARLOCK_DESTRO" } },
	DRUID   = { name = "드루이드",   hex = "ff7d0a", specs = { "DRUID_BALANCE", "DRUID_FERAL", "DRUID_GUARDIAN", "DRUID_RESTO" } },
}
for id, c in pairs(ns.CLASSES) do c.id = id end

------------------------------------------------------------------------
-- Talent trees hold passives only: 8 tiers of two stat nodes, one talent point
-- per hero level. The layout comes from the specialization's archetype.
-- Active skills are separate: six per specialization, opened by hero level
-- (ns.SKILL_UNLOCK) and learned and raised with skill points.
------------------------------------------------------------------------
local function P(stat, per, maxLevel) return { p = stat, v = per, max = maxLevel } end

-- Every node is one of the twelve stats (Data/Items.lua ns.AFFIX).
-- g = the tank's guard: dodge (a druid's) or else 받는 피해 감소.
local PASSIVES = {
	TANK = function(g)
		local gv = g == "dodge" and 1.5 or 0.75
		return {
			{ P("hpPct", 3, 8), P("armorPct", 3, 5) }, { P(g, gv, 8), P("atkPct", 3, 5) },
			{ P("healTaken", 1.5, 8), P("atkPct", 3, 8) }, { P("dr", 0.8, 10), P("hpPct", 2.5, 10) },
			{ P("cdr", 1.5, 8), P("res", 2, 10) }, { P("healTaken", 1.5, 10), P("armorPct", 3, 10) },
			{ P("aspd", 2, 10), P(g, gv, 10) }, { P("dr", 1, 10), P("boss", 3, 10) },
		}
	end,
	MELEE = function()
		return {
			{ P("aspd", 2.5, 8), P("crit", 1.2, 5) }, { P("atkPct", 3, 8), P("dodge", 1, 5) },
			{ P("critdmg", 5, 10), P("atkPct", 3, 8) }, { P("dr", 0.5, 10), P("aspd", 2, 10) },
			{ P("boss", 2, 10), P("cdr", 1.5, 8) }, { P("crit", 1, 10), P("hpPct", 3, 10) },
			{ P("atkPct", 3, 10), P("boss", 3, 10) }, { P("critdmg", 5, 10), P("atkPct", 2, 10) },
		}
	end,
	RANGED = function()
		return {
			{ P("aspd", 2.5, 8), P("atkPct", 3, 5) }, { P("crit", 1.2, 8), P("atkPct", 3, 5) },
			{ P("critdmg", 4, 10), P("boss", 4, 8) }, { P("atkPct", 3, 10), P("aspd", 1, 10) },
			{ P("cdr", 1.5, 8), P("aspd", 2, 10) }, { P("crit", 1, 10), P("hpPct", 3, 10) },
			{ P("atkPct", 3, 10), P("dr", 0.4, 10) }, { P("critdmg", 5, 10), P("atkPct", 3, 10) },
		}
	end,
	CASTER = function()
		return {
			{ P("atkPct", 4, 8), P("atkPct", 3, 5) }, { P("cdr", 1.5, 8), P("aspd", 3, 5) },
			{ P("crit", 1.2, 10), P("boss", 4, 8) }, { P("critdmg", 5, 10), P("hpPct", 3, 8) },
			{ P("aspd", 2.5, 10), P("atkPct", 3, 10) }, { P("atkPct", 3, 10), P("healTaken", 1.5, 10) },
			{ P("cdr", 1.2, 10), P("crit", 1, 10) }, { P("boss", 2, 10), P("atkPct", 3, 10) },
		}
	end,
	-- a healer's heals come from its 공격력
	HEALER = function(g)
		return {
			{ P("atkPct", 4, 8), P("hpPct", 3, 5) }, { P("cdr", 1.5, 8), P("aspd", 3, 5) },
			{ P("atkPct", 3, 10), P("res", 2, 8) }, { P("crit", 1, 10), P("healTaken", 1.5, 10) },
			{ P("aspd", 2.5, 10), P("hpPct", 2.5, 10) }, { P("cdr", 1.2, 10), P(g or "dodge", g == "dr" and 0.5 or 1, 10) },
			{ P("atkPct", 3, 10), P("armorPct", 4, 10) }, { P("dr", 1, 10), P("critdmg", 4, 10) },
		}
	end,
}

local function tree(arch, g)
	local p = PASSIVES[arch](g)
	local t = {}
	for i = 1, #p do t[i] = { p[i][1], p[i][2] } end
	return t
end

-- Hero level at which each of a specialization's six skills opens (the first
-- two from the start; every specialization's first one fights or heals).
ns.SKILL_UNLOCK = { 1, 1, 10, 20, 30, 40 }

------------------------------------------------------------------------
-- Specializations
------------------------------------------------------------------------
ns.SPECS = {}
ns.SPEC_ORDER = {}

-- t: role, school, range, ranged, icon, base, mh, oh, arch (+ g, the guard stat) for the tree, skills, desc
local function spec(id, class, name, t)
	t.id = id
	t.class = class
	t.name = name
	t.tree = tree(t.arch, t.g)
	ns.SPECS[id] = t
	ns.SPEC_ORDER[#ns.SPEC_ORDER + 1] = id
end

local MELEE, CAST = 150, 680

-- Warrior ---------------------------------------------------------------
spec("WARRIOR_ARMS", "WARRIOR", "무기", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Warrior_SavageBlow",
	desc = "거대한 무기로 묵직한 한 방을 꽂고 약해진 적을 마무리합니다.",
	base = { atk = 13, aspd = 0.75, crit = 5, critdmg = 165, hp = 175, armor = 28 },
	mh = { "sword", "axe", "mace" }, oh = { "whetstone" },
	arch = "MELEE",
	skills = { "charge", "rend", "cleave", "execute", "sweeping_strikes", "mortal_strike" },
})
spec("WARRIOR_FURY", "WARRIOR", "분노", {
	role = "DPS", school = "phys", range = MELEE, icon = "Spell_Nature_BloodLust",
	desc = "쌍수 무기를 휘몰아치며 싸울수록 스스로를 회복하는 광전사.",
	base = { atk = 9, aspd = 1.20, crit = 6, critdmg = 160, hp = 170, armor = 24 },
	mh = { "sword", "axe", "mace" }, oh = { "offblade" },
	arch = "MELEE",
	skills = { "heroic_strike", "battle_shout", "overpower", "whirlwind", "bloodthirst", "recklessness" },
})
spec("WARRIOR_PROT", "WARRIOR", "방어", {
	role = "TANK", school = "phys", range = MELEE, icon = "Ability_Warrior_ShieldWall",
	desc = "방패로 최전선을 지키는 굳건한 수호자.",
	base = { atk = 8, aspd = 0.90, crit = 3, critdmg = 150, hp = 240, armor = 40 },
	mh = { "sword", "axe", "mace" }, oh = { "shield" },
	arch = "TANK", g = "dr",
	skills = { "thunder_clap", "defensive_stance", "revenge", "last_stand", "shield_wall", "shield_slam" },
})

-- Paladin ---------------------------------------------------------------
spec("PALADIN_HOLY", "PALADIN", "신성", {
	role = "HEALER", school = "holy", range = 520, ranged = true, icon = "Spell_Holy_HolyBolt",
	desc = "튼튼한 갑옷을 입은 치유사. 한 명을 강하게 살려냅니다.",
	base = { atk = 7, aspd = 0.85, crit = 3, critdmg = 150, hp = 170, armor = 26 },
	mh = { "mace", "sword" }, oh = { "shield", "relic" },
	arch = "HEALER", g = "dr",
	skills = { "holy_light", "devotion_aura", "judgement", "blessing_of_might", "divine_protection", "lay_on_hands" },
})
spec("PALADIN_PROT", "PALADIN", "보호", {
	role = "TANK", school = "phys", range = MELEE, icon = "Spell_Holy_BlessingOfProtection",
	desc = "신성한 힘으로 적 무리를 붙잡고 스스로를 치유하는 방어 전담.",
	base = { atk = 8, aspd = 0.85, crit = 3, critdmg = 150, hp = 235, armor = 38, dr = 2 },
	mh = { "sword", "mace", "axe" }, oh = { "shield" },
	arch = "TANK", g = "dr",
	skills = { "seal_of_righteousness", "exorcism", "consecration", "flash_of_light", "blessing_of_sanctuary", "holy_shield" },
})
spec("PALADIN_RET", "PALADIN", "징벌", {
	role = "DPS", school = "phys", range = MELEE, icon = "Spell_Holy_SealOfMight",
	desc = "신성한 일격으로 적을 심판하는 근접 공격 전담.",
	base = { atk = 12, aspd = 0.80, crit = 5, critdmg = 160, hp = 175, armor = 30 },
	mh = { "sword", "mace", "axe" }, oh = { "whetstone", "relic" },
	arch = "MELEE",
	skills = { "judgement", "blessing_of_might", "seal_of_the_crusader", "seal_of_command", "hammer_of_wrath", "holy_wrath" },
})

-- Hunter ----------------------------------------------------------------
spec("HUNTER_BM", "HUNTER", "야수", {
	role = "DPS", school = "phys", range = 720, ranged = true, icon = "Ability_Hunter_BeastTaming",
	desc = "늘 야수와 함께 싸웁니다. 소환수가 꾸준히 피해를 보탭니다.",
	base = { atk = 8.5, aspd = 1.05, crit = 5, critdmg = 155, hp = 145, armor = 18 },
	mh = { "bow" }, oh = { "quiver" },
	arch = "RANGED",
	skills = { "call_pet", "screech", "multi_shot", "intimidation", "bestial_wrath", "aspect_of_the_wild" },
})
spec("HUNTER_MM", "HUNTER", "사격", {
	role = "DPS", school = "phys", range = 720, ranged = true, icon = "Ability_Marksmanship",
	desc = "가장 빠른 공격 속도로 먼 거리에서 화살을 퍼붓는 명사수.",
	base = { atk = 9, aspd = 1.10, crit = 6, critdmg = 160, hp = 140, armor = 18 },
	mh = { "bow" }, oh = { "quiver" },
	arch = "RANGED",
	skills = { "arcane_shot", "multi_shot", "aimed_shot", "rapid_fire", "trueshot_aura", "volley" },
})
spec("HUNTER_SV", "HUNTER", "생존", {
	role = "DPS", school = "phys", range = 700, ranged = true, icon = "Spell_Fire_SelfDestruct",
	desc = "덫과 독, 폭발로 적 무리를 한꺼번에 무너뜨립니다.",
	base = { atk = 9, aspd = 1.00, crit = 6, critdmg = 160, hp = 145, armor = 18 },
	mh = { "bow" }, oh = { "quiver" },
	arch = "RANGED",
	skills = { "serpent_sting", "aspect_of_the_hawk", "immolation_trap", "freezing_trap", "explosive_trap", "wyvern_sting" },
})

-- Rogue -----------------------------------------------------------------
spec("ROGUE_ASSA", "ROGUE", "암살", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Poisons",
	desc = "독을 겹겹이 쌓아 한 대상을 녹여 버립니다.",
	base = { atk = 9, aspd = 1.30, crit = 7, critdmg = 170, hp = 150, armor = 20, dodge = 5 },
	mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
	arch = "MELEE",
	skills = { "garrote", "ghostly_strike", "instant_poison", "rupture", "deadly_poison", "cold_blood" },
})
spec("ROGUE_OUTLAW", "ROGUE", "무법", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Warrior_PunishingBlow",
	desc = "쌍수 칼날을 쉼 없이 휘두르는 검객.",
	base = { atk = 10, aspd = 1.30, crit = 8, critdmg = 175, hp = 150, armor = 20, dodge = 6 },
	mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
	arch = "MELEE",
	skills = { "sinister_strike", "eviscerate", "evasion", "riposte", "blade_flurry", "adrenaline_rush" },
})
spec("ROGUE_SUB", "ROGUE", "잠행", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Stealth",
	desc = "치명타에 모든 것을 거는 그림자 암살자.",
	base = { atk = 10, aspd = 1.15, crit = 10, critdmg = 185, hp = 145, armor = 20, dodge = 7 },
	mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
	arch = "MELEE",
	skills = { "backstab", "evasion", "slice_and_dice", "ambush", "vanish", "hemorrhage" },
})

-- Priest ----------------------------------------------------------------
spec("PRIEST_DISC", "PRIEST", "수양", {
	role = "HEALER", school = "holy", range = 700, ranged = true, icon = "Spell_Holy_PowerWordShield",
	desc = "보호막과 피해 감소로 다치기 전에 막아 주는 치유사.",
	base = { atk = 6.5, aspd = 0.80, crit = 3, critdmg = 150, hp = 140, armor = 12 },
	mh = { "mace", "staff", "dagger" }, oh = { "orb" },
	arch = "HEALER",
	skills = { "smite", "fortitude", "pw_shield", "flash_heal", "power_infusion", "prayer_of_fortitude" },
})
spec("PRIEST_HOLY", "PRIEST", "신성", {
	role = "HEALER", school = "holy", range = 700, ranged = true, icon = "Spell_Holy_Heal",
	desc = "파티 전체를 치유하고 쓰러진 동료를 되살립니다.",
	base = { atk = 6, aspd = 0.80, crit = 3, critdmg = 150, hp = 140, armor = 12 },
	mh = { "mace", "staff", "dagger" }, oh = { "orb" },
	arch = "HEALER",
	skills = { "lesser_heal", "renew", "resurrection", "heal", "holy_nova", "prayer_of_healing" },
})
spec("PRIEST_SHADOW", "PRIEST", "암흑", {
	role = "DPS", school = "shadow", range = CAST, ranged = true, icon = "Spell_Shadow_ShadowWordPain",
	desc = "고통과 역병으로 적을 갉아먹고 그 피해로 파티를 회복시킵니다.",
	base = { atk = 10, aspd = 0.68, crit = 5, critdmg = 160, hp = 125, armor = 10 },
	mh = { "mace", "staff", "dagger" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "sw_pain", "mind_blast", "mind_flay", "devouring_plague", "shadowguard", "vampiric_embrace" },
})

-- Shaman ----------------------------------------------------------------
spec("SHAMAN_ELE", "SHAMAN", "정기", {
	role = "DPS", school = "nature", range = 640, ranged = true, icon = "Spell_Nature_Lightning",
	desc = "번개와 불꽃으로 싸우는 원소술사. 대지력 토템으로 파티를 강화합니다.",
	base = { atk = 10, aspd = 0.75, crit = 5, critdmg = 160, hp = 160, armor = 24 },
	mh = { "mace", "staff", "dagger" }, oh = { "shield", "relic" },
	arch = "CASTER",
	skills = { "lightning_bolt", "earth_shock", "flame_shock", "strength_of_earth", "flametongue_totem", "chain_lightning" },
})
spec("SHAMAN_ENH", "SHAMAN", "고양", {
	role = "DPS", school = "phys", range = MELEE, icon = "Spell_Nature_Windfury",
	desc = "원소의 힘을 무기에 실어 근접에서 몰아치는 전사 주술사.",
	base = { atk = 10, aspd = 1.10, crit = 6, critdmg = 160, hp = 165, armor = 26 },
	mh = { "mace", "axe" }, oh = { "offblade" },
	arch = "MELEE",
	skills = { "flametongue_weapon", "searing_totem", "strength_of_earth", "fire_nova", "windfury_totem", "stormstrike" },
})
spec("SHAMAN_RESTO", "SHAMAN", "복원", {
	role = "HEALER", school = "nature", range = 640, ranged = true, icon = "Spell_Nature_HealingWaveGreater",
	desc = "연쇄 치유와 토템으로 여럿을 한꺼번에 돌보는 치유사.",
	base = { atk = 6.5, aspd = 0.80, crit = 3, critdmg = 150, hp = 160, armor = 22 },
	mh = { "mace", "staff" }, oh = { "shield", "relic" },
	arch = "HEALER", g = "dr",
	skills = { "healing_wave", "stoneskin_totem", "ancestral_spirit", "healing_stream", "lesser_healing_wave", "chain_heal" },
})

-- Mage ------------------------------------------------------------------
spec("MAGE_ARCANE", "MAGE", "비전", {
	role = "DPS", school = "arcane", range = CAST, ranged = true, icon = "Spell_Holy_MagicalSentry",
	desc = "순수한 마력을 한 대상에 쏟아붓는 폭딜 마법사.",
	base = { atk = 11, aspd = 0.65, crit = 6, critdmg = 165, hp = 110, armor = 8 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "arcane_missiles", "arcane_explosion", "mana_shield", "blast_wave", "presence_of_mind", "arcane_power" },
})
spec("MAGE_FIRE", "MAGE", "화염", {
	role = "DPS", school = "fire", range = CAST, ranged = true, icon = "Spell_Fire_FlameBolt",
	desc = "폭발하는 화염으로 적 무리를 태우는 광역 마법사.",
	base = { atk = 11, aspd = 0.60, crit = 6, critdmg = 170, hp = 110, armor = 8 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "fireball", "fire_blast", "flamestrike", "pyroblast", "scorch", "combustion" },
})
spec("MAGE_FROST", "MAGE", "냉기", {
	role = "DPS", school = "frost", range = CAST, ranged = true, icon = "Spell_Frost_FrostBolt02",
	desc = "적을 얼리고 늦춰 파티가 받는 피해까지 줄여 줍니다.",
	base = { atk = 10.5, aspd = 0.62, crit = 6, critdmg = 165, hp = 115, armor = 8 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "frostbolt", "frost_nova", "blizzard", "cone_of_cold", "ice_armor", "ice_barrier" },
})

-- Warlock ---------------------------------------------------------------
spec("WARLOCK_AFF", "WARLOCK", "고통", {
	role = "DPS", school = "shadow", range = CAST, ranged = true, icon = "Spell_Shadow_AbominationExplosion",
	desc = "여러 적에게 지속 피해를 걸고 저주로 파티 전체의 피해를 올립니다.",
	base = { atk = 10, aspd = 0.65, crit = 5, critdmg = 160, hp = 130, armor = 8 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "corruption", "curse_of_agony", "drain_life", "siphon_life", "hellfire", "curse_of_elements" },
})
spec("WARLOCK_DEMO", "WARLOCK", "악마", {
	role = "DPS", school = "shadow", range = CAST, ranged = true, icon = "Spell_Shadow_SummonFelHunter",
	desc = "지옥사냥개를 부리고 악마의 힘을 제물로 삼아 버티는 튼튼한 술사.",
	base = { atk = 9.5, aspd = 0.65, crit = 5, critdmg = 160, hp = 140, armor = 10 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "shadow_bolt", "summon_felhunter", "demonic_sacrifice", "soul_link", "death_coil", "inferno" },
})
spec("WARLOCK_DESTRO", "WARLOCK", "파괴", {
	role = "DPS", school = "fire", range = CAST, ranged = true, icon = "Spell_Fire_Immolation",
	desc = "불과 그림자의 큰 한 방. 치명타가 터지면 무엇이든 무너집니다.",
	base = { atk = 10.5, aspd = 0.62, crit = 6, critdmg = 165, hp = 125, armor = 8 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER",
	skills = { "immolate", "searing_pain", "rain_of_fire", "shadowburn", "conflagrate", "soul_fire" },
})

-- Druid -----------------------------------------------------------------
spec("DRUID_BALANCE", "DRUID", "조화", {
	role = "DPS", school = "nature", range = CAST, ranged = true, icon = "Spell_Nature_StarFall",
	desc = "달과 별의 힘으로 싸우는 원거리 마법 공격 전담.",
	base = { atk = 10, aspd = 0.70, crit = 5, critdmg = 160, hp = 140, armor = 14 },
	mh = { "staff", "mace", "dagger" }, oh = { "relic", "orb" },
	arch = "CASTER",
	skills = { "wrath", "moonfire", "starfire", "insect_swarm", "moonkin_form", "hurricane" },
})
spec("DRUID_FERAL", "DRUID", "야성", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Druid_FerociousBite",
	desc = "표범으로 변신해 찢고 물어뜯는 근접 공격 전담.",
	base = { atk = 10, aspd = 1.20, crit = 8, critdmg = 170, hp = 160, armor = 22, dodge = 5 },
	mh = { "staff", "mace", "dagger" }, oh = { "relic", "whetstone" },
	arch = "MELEE",
	skills = { "claw", "shred", "rake", "tigers_fury", "ferocious_bite", "leader_of_pack" },
})
spec("DRUID_GUARDIAN", "DRUID", "수호", {
	role = "TANK", school = "phys", range = MELEE, icon = "Ability_Druid_Maul",
	desc = "곰으로 변신해 두꺼운 가죽과 재생력으로 버티는 방어 전담.",
	base = { atk = 9, aspd = 0.80, crit = 4, critdmg = 150, hp = 270, armor = 30, dodge = 5 },
	mh = { "mace", "staff" }, oh = { "relic" },
	arch = "TANK", g = "dodge",
	skills = { "maul", "demo_roar", "bash", "swipe", "frenzied_regen", "barkskin" },
})
spec("DRUID_RESTO", "DRUID", "회복", {
	role = "HEALER", school = "nature", range = CAST, ranged = true, icon = "Spell_Nature_Rejuvenation",
	desc = "지속 치유를 겹겹이 걸어 파티를 천천히, 꾸준히 회복시킵니다.",
	base = { atk = 6, aspd = 0.80, crit = 3, critdmg = 150, hp = 150, armor = 14 },
	mh = { "staff", "mace" }, oh = { "relic", "orb" },
	arch = "HEALER",
	skills = { "healing_touch", "mark_of_wild", "rejuvenation", "regrowth", "rebirth", "tranquility" },
})

------------------------------------------------------------------------
-- Balance multipliers found with tests/bench.lua (see README). They scale a
-- specialization's final attack, final health or healing so that every choice
-- within a role performs within a narrow band of the others. (The healers'
-- were set again when heals came to be made of 공격력: party deaths and damage
-- at levels 15, 40 and 75 within a band.)
------------------------------------------------------------------------
ns.SPEC_TUNE = {
	WARRIOR_ARMS = { atk = 1.37 },
	WARRIOR_FURY = { atk = 0.89 },
	WARRIOR_PROT = { hp = 0.79 },
	PALADIN_HOLY = { heal = 0.95 },
	PALADIN_PROT = { hp = 1.00 },
	PALADIN_RET = { atk = 1.39 },
	HUNTER_BM = { atk = 0.89 },
	HUNTER_MM = { atk = 0.79 },
	HUNTER_SV = { atk = 0.92 },
	ROGUE_ASSA = { atk = 0.77 },
	ROGUE_OUTLAW = { atk = 0.74 },
	ROGUE_SUB = { atk = 0.76 },
	PRIEST_DISC = { heal = 3.3 }, -- its heals are atonement and shields: kept level with the other healers
	PRIEST_HOLY = { heal = 0.85 }, -- two heals from the start (하급 치유, 소생)
	PRIEST_SHADOW = { atk = 1.24 },
	SHAMAN_ELE = { atk = 0.81 },
	SHAMAN_ENH = { atk = 0.96 },
	SHAMAN_RESTO = { heal = 0.75 }, -- heals and its totem's shield: kept level with the other healers
	MAGE_ARCANE = { atk = 1.24 },
	MAGE_FIRE = { atk = 0.71 },
	MAGE_FROST = { atk = 1.13 },
	WARLOCK_AFF = { atk = 1.13 },
	WARLOCK_DEMO = { atk = 1.23 },
	WARLOCK_DESTRO = { atk = 1.17 },
	DRUID_BALANCE = { atk = 1.22 },
	DRUID_FERAL = { atk = 0.95 },
	DRUID_GUARDIAN = { hp = 1.14 },
	DRUID_RESTO = { heal = 1.2 },
}

function ns.SpecTune(specId, what)
	local t = ns.SPEC_TUNE[specId]
	return t and t[what] or 1
end

-- A healer's heals come from its 공격력: a skill's number times this at the
-- healer's level is its percent of 공격력. The numbers are what a heal of 1%
-- used to mend (a share of the party's health, times the healing bonus a
-- healer had then from talents and gear) over a healer's 공격력 at those
-- levels, gear of the level as tests/bench.lua gives it; so heals keep their
-- weight against the party's health as heroes grow. Between them it runs in
-- a straight line.
ns.HEAL_ATK = { { 1, 17.6 }, { 15, 13.9 }, { 40, 9.9 }, { 75, 19.3 }, { 100, 31.8 } }
function ns.HealAtk(level)
	local t = ns.HEAL_ATK
	if level <= t[1][1] then return t[1][2] end
	for i = 2, #t do
		if level <= t[i][1] then
			local a, b = t[i - 1], t[i]
			return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1])
		end
	end
	return t[#t][2]
end

-- The healing skills of the healers (Systems/Combat.lua skillHeal): byAtk =
-- the spec they belong to. A skill that mends a share of health (ofHealth)
-- stays so.
do
	local HEALING = { heal = true, shield = true }
	for _, id in ipairs(ns.SPEC_ORDER) do
		local sp = ns.SPECS[id]
		if sp.role == "HEALER" then
			for _, sid in ipairs(sp.skills) do
				local sk = ns.SKILLS[sid]
				if sk and not sk.ofHealth and (HEALING[sk.kind] or sk.atone or sk.healAll or sk.heal) then
					sk.byAtk = id
				end
			end
		end
	end
end

-- Experience needed to go from level L to L+1 (TBH's table).
function ns.XPForLevel(l)
	return ns.TBH.XP[math.max(1, math.min(100, l))]
end

-- Level-based growth of the base stats.
function ns.BaseAtLevel(sp, stat, level)
	local b = sp.base[stat] or 0
	if stat == "atk" then
		return b * (1 + 0.08 * (level - 1))
	elseif stat == "hp" then
		return b * (1 + 0.12 * (level - 1))
	elseif stat == "armor" then
		return b * (1 + 0.10 * (level - 1))
	end
	return b
end

function ns.SpecLabel(specId)
	local sp = ns.SPECS[specId]
	return ns.N(sp.name) .. " " .. ns.N(ns.CLASSES[sp.class].name)
end
