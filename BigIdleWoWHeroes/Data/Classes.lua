-- Classes and specializations. A hero is created as one specialization of a
-- class; the specialization decides its role, weapons, base stats and talents.
-- The party always has five role slots: 1 tank, 3 damage dealers, 1 healer.
local _, ns = ...

ns.ROLE = {
	TANK   = { name = { "탱커", "Tank" },   hex = "4c8dff", art = "role_tank" },
	DPS    = { name = { "딜러", "Damage" }, hex = "ff5a47", art = "role_dps" },
	HEALER = { name = { "힐러", "Healer" }, hex = "45d16a", art = "role_heal" },
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
	WARRIOR = { name = { "전사", "Warrior" },     hex = "c79c6e", specs = { "WARRIOR_ARMS", "WARRIOR_FURY", "WARRIOR_PROT" } },
	PALADIN = { name = { "성기사", "Paladin" },   hex = "f58cba", specs = { "PALADIN_HOLY", "PALADIN_PROT", "PALADIN_RET" } },
	HUNTER  = { name = { "사냥꾼", "Hunter" },    hex = "abd473", specs = { "HUNTER_BM", "HUNTER_MM", "HUNTER_SV" } },
	ROGUE   = { name = { "도적", "Rogue" },       hex = "fff569", specs = { "ROGUE_ASSA", "ROGUE_OUTLAW", "ROGUE_SUB" } },
	PRIEST  = { name = { "사제", "Priest" },      hex = "ffffff", specs = { "PRIEST_DISC", "PRIEST_HOLY", "PRIEST_SHADOW" } },
	SHAMAN  = { name = { "주술사", "Shaman" },    hex = "2e8bff", specs = { "SHAMAN_ELE", "SHAMAN_ENH", "SHAMAN_RESTO" } },
	MAGE    = { name = { "마법사", "Mage" },      hex = "69ccf0", specs = { "MAGE_ARCANE", "MAGE_FIRE", "MAGE_FROST" } },
	WARLOCK = { name = { "흑마법사", "Warlock" }, hex = "9482c9", specs = { "WARLOCK_AFF", "WARLOCK_DEMO", "WARLOCK_DESTRO" } },
	DRUID   = { name = { "드루이드", "Druid" },   hex = "ff7d0a", specs = { "DRUID_BALANCE", "DRUID_FERAL", "DRUID_GUARDIAN", "DRUID_RESTO" } },
}
for id, c in pairs(ns.CLASSES) do c.id = id end

------------------------------------------------------------------------
-- Talent trees. Every specialization has 8 tiers: two passives per tier and
-- six active skills spread over tiers 1-5. The passive layout comes from the
-- specialization's archetype; the actives are what make each one different.
------------------------------------------------------------------------
local function P(stat, per, maxLevel) return { p = stat, v = per, max = maxLevel } end
local function K(id) return { s = id, max = ns.SKILL_MAX } end

-- a = main damage school stat, b = second school stat, g = guard stat (block or dodge)
local PASSIVES = {
	TANK = function(a, b, g)
		return {
			{ P("hpPct", 3, 8), P("armorPct", 3, 5) }, { P(g, 1.5, 8), P("atkPct", 3, 5) },
			{ P("regenPct", 0.12, 8), P(a, 3, 8) }, { P("dr", 0.8, 10), P("hpPct", 2.5, 10) },
			{ P("cdr", 1.5, 8), P("allres", 2, 10) }, { P("hpkPct", 0.4, 10), P("armorPct", 3, 10) },
			{ P("aspd", 2, 10), P(g, 1.5, 10) }, { P("dr", 1, 10), P("atkPct", 3, 10) },
		}
	end,
	MELEE = function(a, b)
		return {
			{ P("aspd", 2.5, 8), P("crit", 1.2, 5) }, { P("atkPct", 3, 8), P("dodge", 1, 5) },
			{ P("critdmg", 5, 10), P(a, 3, 8) }, { P("leech", 0.4, 10), P("aspd", 2, 10) },
			{ P("multi", 2, 10), P("cdr", 1.5, 8) }, { P("crit", 1, 10), P("hpPct", 3, 10) },
			{ P("atkPct", 3, 10), P(b, 3, 10) }, { P("critdmg", 5, 10), P("dmg_all", 2, 10) },
		}
	end,
	RANGED = function(a, b)
		return {
			{ P("aspd", 2.5, 8), P("atkPct", 3, 5) }, { P("crit", 1.2, 8), P(a, 3, 5) },
			{ P("critdmg", 4, 10), P(b, 4, 8) }, { P("atkPct", 3, 10), P("multi", 2, 10) },
			{ P("cdr", 1.5, 8), P("aspd", 2, 10) }, { P("crit", 1, 10), P("hpPct", 3, 10) },
			{ P(a, 3, 10), P("leech", 0.3, 10) }, { P("critdmg", 5, 10), P("atkPct", 3, 10) },
		}
	end,
	CASTER = function(a, b)
		return {
			{ P(a, 4, 8), P("atkPct", 3, 5) }, { P("cdr", 1.5, 8), P("cast", 3, 5) },
			{ P("crit", 1.2, 10), P(b, 4, 8) }, { P("critdmg", 5, 10), P("hpPct", 3, 8) },
			{ P("cast", 2.5, 10), P("atkPct", 3, 10) }, { P(a, 3, 10), P("regenPct", 0.1, 10) },
			{ P("cdr", 1.2, 10), P("crit", 1, 10) }, { P("dmg_all", 2, 10), P("atkPct", 3, 10) },
		}
	end,
	HEALER = function(a, b, g)
		return {
			{ P("heal", 4, 8), P("hpPct", 3, 5) }, { P("cdr", 1.5, 8), P("cast", 3, 5) },
			{ P("heal", 3, 10), P("allres", 2, 8) }, { P(a, 4, 10), P("regenPct", 0.1, 10) },
			{ P("cast", 2.5, 10), P("hpPct", 2.5, 10) }, { P("cdr", 1.2, 10), P(g or "dodge", 1, 10) },
			{ P("heal", 3, 10), P("armorPct", 4, 10) }, { P("dr", 1, 10), P("atkPct", 3, 10) },
		}
	end,
}

local function tree(arch, a, b, g, skills)
	local p = PASSIVES[arch](a, b, g)
	return {
		{ p[1][1], p[1][2], K(skills[1]), K(skills[2]) },
		{ p[2][1], p[2][2], K(skills[3]) },
		{ p[3][1], p[3][2], K(skills[4]) },
		{ p[4][1], p[4][2], K(skills[5]) },
		{ p[5][1], p[5][2], K(skills[6]) },
		{ p[6][1], p[6][2] },
		{ p[7][1], p[7][2] },
		{ p[8][1], p[8][2] },
	}
end

------------------------------------------------------------------------
-- Specializations
------------------------------------------------------------------------
ns.SPECS = {}
ns.SPEC_ORDER = {}

-- t: role, school, range, ranged, icon, base, mh, oh, arch + stats for the tree, skills, desc
local function spec(id, class, ko, en, t)
	t.id = id
	t.class = class
	t.name = { ko, en }
	t.tree = tree(t.arch, t.a, t.b, t.g, t.skills)
	ns.SPECS[id] = t
	ns.SPEC_ORDER[#ns.SPEC_ORDER + 1] = id
end

local MELEE, CAST = 150, 680

-- Warrior ---------------------------------------------------------------
spec("WARRIOR_ARMS", "WARRIOR", "무기", "Arms", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Warrior_SavageBlow",
	desc = { "거대한 무기로 묵직한 한 방을 꽂고 약해진 적을 마무리합니다.", "Lands slow, crushing blows and finishes weakened enemies." },
	base = { atk = 13, aspd = 0.75, crit = 5, critdmg = 165, hp = 175, armor = 28 },
	mh = { "sword", "axe", "mace" }, oh = { "whetstone" },
	arch = "MELEE", a = "dmg_phys", b = "dmg_phys",
	skills = { "mortal_strike", "cleave", "rend", "battle_shout", "execute", "bladestorm" },
})
spec("WARRIOR_FURY", "WARRIOR", "분노", "Fury", {
	role = "DPS", school = "phys", range = MELEE, icon = "Spell_Nature_BloodLust",
	desc = { "쌍수 무기를 휘몰아치며 싸울수록 스스로를 회복하는 광전사.", "A dual-wielding berserker who heals through the frenzy." },
	base = { atk = 9, aspd = 1.20, crit = 6, critdmg = 160, hp = 170, armor = 24 },
	mh = { "sword", "axe", "mace" }, oh = { "offblade" },
	arch = "MELEE", a = "dmg_phys", b = "dmg_phys",
	skills = { "bloodthirst", "whirlwind", "raging_blow", "battle_shout", "recklessness", "rampage" },
})
spec("WARRIOR_PROT", "WARRIOR", "방어", "Protection", {
	role = "TANK", school = "phys", range = MELEE, icon = "Ability_Warrior_ShieldWall",
	desc = { "방패로 최전선을 지키는 굳건한 수호자.", "A steadfast guardian holding the line behind a shield." },
	base = { atk = 8, aspd = 0.90, crit = 3, critdmg = 150, hp = 240, armor = 40 },
	mh = { "sword", "axe", "mace" }, oh = { "shield" },
	arch = "TANK", a = "dmg_phys", g = "block",
	skills = { "shield_slam", "thunder_clap", "revenge", "commanding_shout", "shield_wall", "last_stand" },
})

-- Paladin ---------------------------------------------------------------
spec("PALADIN_HOLY", "PALADIN", "신성", "Holy", {
	role = "HEALER", school = "holy", range = 520, ranged = true, icon = "Spell_Holy_HolyBolt",
	desc = { "튼튼한 갑옷을 입은 치유사. 한 명을 강하게 살려냅니다.", "An armored healer with powerful single-target heals." },
	base = { atk = 7, aspd = 0.85, crit = 3, critdmg = 150, hp = 170, armor = 26, move = -10 },
	mh = { "mace", "sword" }, oh = { "shield", "relic" },
	arch = "HEALER", a = "dmg_holy", g = "block",
	skills = { "holy_light", "devotion_aura", "judgement", "blessing_of_might", "lay_on_hands", "divine_protection" },
})
spec("PALADIN_PROT", "PALADIN", "보호", "Protection", {
	role = "TANK", school = "phys", range = MELEE, icon = "Spell_Holy_BlessingOfProtection",
	desc = { "신성한 힘으로 적 무리를 붙잡고 스스로를 치유하는 탱커.", "A holy tank who holds packs and heals themselves." },
	base = { atk = 8, aspd = 0.85, crit = 3, critdmg = 150, hp = 235, armor = 38, block = 4 },
	mh = { "sword", "mace", "axe" }, oh = { "shield" },
	arch = "TANK", a = "dmg_holy", g = "block",
	skills = { "shield_of_righteous", "avengers_shield", "consecration", "devotion_aura", "ardent_defender", "word_of_glory" },
})
spec("PALADIN_RET", "PALADIN", "징벌", "Retribution", {
	role = "DPS", school = "phys", range = MELEE, icon = "Spell_Holy_SealOfMight",
	desc = { "신성한 일격으로 적을 심판하는 근접 딜러.", "A melee damage dealer who smites with holy strikes." },
	base = { atk = 12, aspd = 0.80, crit = 5, critdmg = 160, hp = 175, armor = 30 },
	mh = { "sword", "mace", "axe" }, oh = { "whetstone", "relic" },
	arch = "MELEE", a = "dmg_holy", b = "dmg_phys",
	skills = { "crusader_strike", "divine_storm", "judgement", "blessing_of_might", "hammer_of_wrath", "avenging_wrath" },
})

-- Hunter ----------------------------------------------------------------
spec("HUNTER_BM", "HUNTER", "야수", "Beast Mastery", {
	role = "DPS", school = "phys", range = 720, ranged = true, icon = "Ability_Hunter_BeastTaming",
	desc = { "늘 야수와 함께 싸웁니다. 소환수가 꾸준히 피해를 보탭니다.", "Never fights alone: a companion beast adds steady damage." },
	base = { atk = 8.5, aspd = 1.05, crit = 5, critdmg = 155, hp = 145, armor = 18 },
	mh = { "bow" }, oh = { "quiver" },
	arch = "RANGED", a = "dmg_phys", b = "dmg_nature",
	skills = { "kill_command", "hunters_pet", "multi_shot", "pack_leader", "bestial_wrath", "stampede" },
})
spec("HUNTER_MM", "HUNTER", "사격", "Marksmanship", {
	role = "DPS", school = "phys", range = 720, ranged = true, icon = "Ability_Marksmanship",
	desc = { "가장 빠른 공격 속도로 먼 거리에서 화살을 퍼붓는 명사수.", "A sharpshooter with the fastest attacks in the game." },
	base = { atk = 9, aspd = 1.10, crit = 6, critdmg = 160, hp = 140, armor = 18 },
	mh = { "bow" }, oh = { "quiver" },
	arch = "RANGED", a = "dmg_phys", b = "dmg_arcane",
	skills = { "aimed_shot", "multi_shot", "arcane_shot", "trueshot_aura", "rapid_fire", "volley" },
})
spec("HUNTER_SV", "HUNTER", "생존", "Survival", {
	role = "DPS", school = "phys", range = 700, ranged = true, icon = "Spell_Fire_SelfDestruct",
	desc = { "덫과 독, 폭발로 적 무리를 한꺼번에 무너뜨립니다.", "Traps, venom and explosives that break whole packs." },
	base = { atk = 9, aspd = 1.00, crit = 6, critdmg = 160, hp = 145, armor = 18 },
	mh = { "bow" }, oh = { "quiver" },
	arch = "RANGED", a = "dmg_phys", b = "dmg_fire",
	skills = { "explosive_shot", "serpent_sting", "explosive_trap", "freezing_trap", "black_arrow", "lock_and_load" },
})

-- Rogue -----------------------------------------------------------------
spec("ROGUE_ASSA", "ROGUE", "암살", "Assassination", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Poisons",
	desc = { "독을 겹겹이 쌓아 한 대상을 녹여 버립니다.", "Stacks poisons that melt a single target." },
	base = { atk = 9, aspd = 1.30, crit = 7, critdmg = 170, hp = 150, armor = 20, move = 10, dodge = 5 },
	mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
	arch = "MELEE", a = "dmg_nature", b = "dmg_phys",
	skills = { "mutilate", "deadly_poison", "envenom", "rupture", "vendetta", "cold_blood" },
})
spec("ROGUE_OUTLAW", "ROGUE", "무법", "Outlaw", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Warrior_PunishingBlow",
	desc = { "쌍수 칼날을 쉼 없이 휘두르는 검객.", "A swashbuckler whose blades never rest." },
	base = { atk = 10, aspd = 1.30, crit = 8, critdmg = 175, hp = 150, armor = 20, move = 10, dodge = 6 },
	mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
	arch = "MELEE", a = "dmg_phys", b = "dmg_phys",
	skills = { "sinister_strike", "blade_flurry", "eviscerate", "evasion", "killing_spree", "adrenaline_rush" },
})
spec("ROGUE_SUB", "ROGUE", "잠행", "Subtlety", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Stealth",
	desc = { "치명타에 모든 것을 거는 그림자 암살자.", "A shadow assassin who lives and dies by critical strikes." },
	base = { atk = 10, aspd = 1.15, crit = 10, critdmg = 185, hp = 145, armor = 20, move = 10, dodge = 7 },
	mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
	arch = "MELEE", a = "dmg_phys", b = "dmg_shadow",
	skills = { "backstab", "hemorrhage", "ambush", "evasion", "shadow_dance", "shadow_blades" },
})

-- Priest ----------------------------------------------------------------
spec("PRIEST_DISC", "PRIEST", "수양", "Discipline", {
	role = "HEALER", school = "holy", range = 700, ranged = true, icon = "Spell_Holy_PowerWordShield",
	desc = { "보호막과 피해 감소로 다치기 전에 막아 주는 치유사.", "Prevents damage with shields and mitigation." },
	base = { atk = 6.5, aspd = 0.80, crit = 3, critdmg = 150, hp = 140, armor = 12, move = -10 },
	mh = { "mace", "staff", "dagger" }, oh = { "orb" },
	arch = "HEALER", a = "dmg_holy",
	skills = { "penance", "pw_shield", "smite", "fortitude", "pain_suppression", "pw_barrier" },
})
spec("PRIEST_HOLY", "PRIEST", "신성", "Holy", {
	role = "HEALER", school = "holy", range = 700, ranged = true, icon = "Spell_Holy_Heal",
	desc = { "파티 전체를 치유하고 쓰러진 동료를 되살립니다.", "Heals the whole party and raises the fallen." },
	base = { atk = 6, aspd = 0.80, crit = 3, critdmg = 150, hp = 140, armor = 12, move = -10 },
	mh = { "mace", "staff", "dagger" }, oh = { "orb" },
	arch = "HEALER", a = "dmg_holy",
	skills = { "heal", "renew", "holy_nova", "fortitude", "prayer_of_healing", "resurrection" },
})
spec("PRIEST_SHADOW", "PRIEST", "암흑", "Shadow", {
	role = "DPS", school = "shadow", range = CAST, ranged = true, icon = "Spell_Shadow_ShadowWordPain",
	desc = { "고통과 역병으로 적을 갉아먹고 그 피해로 파티를 회복시킵니다.", "Gnaws at enemies and turns the damage into party healing." },
	base = { atk = 10, aspd = 0.68, crit = 5, critdmg = 160, hp = 125, armor = 10, move = -5 },
	mh = { "mace", "staff", "dagger" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_shadow", b = "dmg_shadow",
	skills = { "mind_blast", "sw_pain", "mind_flay", "vampiric_embrace", "devouring_plague", "shadowfiend" },
})

-- Shaman ----------------------------------------------------------------
spec("SHAMAN_ELE", "SHAMAN", "정기", "Elemental", {
	role = "DPS", school = "nature", range = 640, ranged = true, icon = "Spell_Nature_Lightning",
	desc = { "번개와 용암으로 싸우는 원소술사. 피의 욕망으로 파티를 가속합니다.", "Hurls lightning and lava; Bloodlust speeds up the party." },
	base = { atk = 10, aspd = 0.75, crit = 5, critdmg = 160, hp = 160, armor = 24 },
	mh = { "mace", "staff", "dagger" }, oh = { "shield", "relic" },
	arch = "CASTER", a = "dmg_nature", b = "dmg_fire",
	skills = { "lightning_bolt", "chain_lightning", "earth_shock", "totem_of_wrath", "lava_burst", "bloodlust" },
})
spec("SHAMAN_ENH", "SHAMAN", "고양", "Enhancement", {
	role = "DPS", school = "phys", range = MELEE, icon = "Spell_Nature_Windfury",
	desc = { "원소의 힘을 무기에 실어 근접에서 몰아치는 전사 주술사.", "A melee shaman whose weapons carry the elements." },
	base = { atk = 10, aspd = 1.10, crit = 6, critdmg = 160, hp = 165, armor = 26 },
	mh = { "mace", "axe" }, oh = { "offblade" },
	arch = "MELEE", a = "dmg_nature", b = "dmg_fire",
	skills = { "stormstrike", "lava_lash", "windfury_totem", "feral_spirit", "fire_nova", "bloodlust" },
})
spec("SHAMAN_RESTO", "SHAMAN", "복원", "Restoration", {
	role = "HEALER", school = "nature", range = 640, ranged = true, icon = "Spell_Nature_HealingWaveGreater",
	desc = { "연쇄 치유와 토템으로 여럿을 한꺼번에 돌보는 치유사.", "Chain heals and totems that look after many at once." },
	base = { atk = 6.5, aspd = 0.80, crit = 3, critdmg = 150, hp = 160, armor = 22, move = -10 },
	mh = { "mace", "staff" }, oh = { "shield", "relic" },
	arch = "HEALER", a = "dmg_nature", g = "block",
	skills = { "healing_wave", "chain_heal", "earth_shield", "healing_stream", "riptide", "ancestral_spirit" },
})

-- Mage ------------------------------------------------------------------
spec("MAGE_ARCANE", "MAGE", "비전", "Arcane", {
	role = "DPS", school = "arcane", range = CAST, ranged = true, icon = "Spell_Holy_MagicalSentry",
	desc = { "순수한 마력을 한 대상에 쏟아붓는 폭딜 마법사.", "Pours raw arcane power into a single target." },
	base = { atk = 11, aspd = 0.65, crit = 6, critdmg = 165, hp = 110, armor = 8, move = -5 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_arcane", b = "dmg_arcane",
	skills = { "arcane_blast", "arcane_missiles", "arcane_explosion", "arcane_intellect", "arcane_power", "arcane_barrage" },
})
spec("MAGE_FIRE", "MAGE", "화염", "Fire", {
	role = "DPS", school = "fire", range = CAST, ranged = true, icon = "Spell_Fire_FlameBolt",
	desc = { "폭발하는 화염으로 적 무리를 태우는 광역 마법사.", "Burns packs down with exploding fire." },
	base = { atk = 11, aspd = 0.60, crit = 6, critdmg = 170, hp = 110, armor = 8, move = -5 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_fire", b = "dmg_fire",
	skills = { "fireball", "scorch", "fire_blast", "flamestrike", "combustion", "pyroblast" },
})
spec("MAGE_FROST", "MAGE", "냉기", "Frost", {
	role = "DPS", school = "frost", range = CAST, ranged = true, icon = "Spell_Frost_FrostBolt02",
	desc = { "적을 얼리고 늦춰 파티가 받는 피해까지 줄여 줍니다.", "Freezes and slows enemies, sparing the party damage." },
	base = { atk = 10.5, aspd = 0.62, crit = 6, critdmg = 165, hp = 115, armor = 8, move = -5 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_frost", b = "dmg_frost",
	skills = { "frostbolt", "frost_nova", "ice_lance", "ice_barrier", "blizzard", "water_elemental" },
})

-- Warlock ---------------------------------------------------------------
spec("WARLOCK_AFF", "WARLOCK", "고통", "Affliction", {
	role = "DPS", school = "shadow", range = CAST, ranged = true, icon = "Spell_Shadow_AbominationExplosion",
	desc = { "여러 적에게 지속 피해를 걸고 저주로 파티 전체의 피해를 올립니다.", "Spreads lingering damage and curses that amplify the party." },
	base = { atk = 10, aspd = 0.65, crit = 5, critdmg = 160, hp = 130, armor = 8, move = -5 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_shadow", b = "dmg_shadow",
	skills = { "corruption", "unstable_affliction", "drain_life", "curse_of_elements", "haunt", "seed_of_corruption" },
})
spec("WARLOCK_DEMO", "WARLOCK", "악마", "Demonology", {
	role = "DPS", school = "shadow", range = CAST, ranged = true, icon = "Spell_Shadow_SummonFelHunter",
	desc = { "악마를 부리고 스스로도 악마로 변신하는 튼튼한 술사.", "Commands demons and becomes one; sturdier than other casters." },
	base = { atk = 9.5, aspd = 0.65, crit = 5, critdmg = 160, hp = 140, armor = 10, move = -5 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_shadow", b = "dmg_fire",
	skills = { "shadow_bolt", "felguard", "soul_link", "hand_of_guldan", "metamorphosis", "summon_infernal" },
})
spec("WARLOCK_DESTRO", "WARLOCK", "파괴", "Destruction", {
	role = "DPS", school = "fire", range = CAST, ranged = true, icon = "Spell_Fire_Immolation",
	desc = { "불과 혼돈의 큰 한 방. 치명타가 터지면 무엇이든 무너집니다.", "Fire and chaos in huge single hits." },
	base = { atk = 10.5, aspd = 0.62, crit = 6, critdmg = 165, hp = 125, armor = 8, move = -5 },
	mh = { "staff", "dagger", "sword" }, oh = { "orb" },
	arch = "CASTER", a = "dmg_fire", b = "dmg_shadow",
	skills = { "immolate", "incinerate", "rain_of_fire", "conflagrate", "shadowburn", "chaos_bolt" },
})

-- Druid -----------------------------------------------------------------
spec("DRUID_BALANCE", "DRUID", "조화", "Balance", {
	role = "DPS", school = "nature", range = CAST, ranged = true, icon = "Spell_Nature_StarFall",
	desc = { "달과 별의 힘으로 싸우는 원거리 마법 딜러.", "A ranged caster wielding moon and stars." },
	base = { atk = 10, aspd = 0.70, crit = 5, critdmg = 160, hp = 140, armor = 14, move = -5 },
	mh = { "staff", "mace", "dagger" }, oh = { "relic", "orb" },
	arch = "CASTER", a = "dmg_nature", b = "dmg_arcane",
	skills = { "wrath", "moonfire", "starfire", "moonkin_aura", "hurricane", "starfall" },
})
spec("DRUID_FERAL", "DRUID", "야성", "Feral", {
	role = "DPS", school = "phys", range = MELEE, icon = "Ability_Druid_FerociousBite",
	desc = { "표범으로 변신해 찢고 물어뜯는 근접 딜러.", "A cat-form shredder who rips and bites in melee." },
	base = { atk = 10, aspd = 1.20, crit = 8, critdmg = 170, hp = 160, armor = 22, move = 10, dodge = 5 },
	mh = { "staff", "mace", "dagger" }, oh = { "relic", "whetstone" },
	arch = "MELEE", a = "dmg_phys", b = "dmg_phys",
	skills = { "shred", "rake", "ferocious_bite", "leader_of_pack", "tigers_fury", "berserk" },
})
spec("DRUID_GUARDIAN", "DRUID", "수호", "Guardian", {
	role = "TANK", school = "phys", range = MELEE, icon = "Ability_Druid_Maul",
	desc = { "곰으로 변신해 두꺼운 가죽과 재생력으로 버티는 탱커.", "A bear-form tank with thick hide and regeneration." },
	base = { atk = 9, aspd = 0.80, crit = 4, critdmg = 150, hp = 270, armor = 30, dodge = 5 },
	mh = { "mace", "staff" }, oh = { "relic" },
	arch = "TANK", a = "dmg_phys", g = "dodge",
	skills = { "maul", "swipe", "demo_roar", "thorns", "frenzied_regen", "barkskin" },
})
spec("DRUID_RESTO", "DRUID", "회복", "Restoration", {
	role = "HEALER", school = "nature", range = CAST, ranged = true, icon = "Spell_Nature_Rejuvenation",
	desc = { "지속 치유를 겹겹이 걸어 파티를 천천히, 꾸준히 회복시킵니다.", "Layers heal-over-time effects for slow, steady recovery." },
	base = { atk = 6, aspd = 0.80, crit = 3, critdmg = 150, hp = 150, armor = 14, move = -10 },
	mh = { "staff", "mace" }, oh = { "relic", "orb" },
	arch = "HEALER", a = "dmg_nature",
	skills = { "rejuvenation", "healing_touch", "wild_growth", "mark_of_wild", "tranquility", "rebirth" },
})

------------------------------------------------------------------------
-- Balance multipliers found with tests/bench.lua (see README). They scale a
-- specialization's final attack, final health or healing so that every choice
-- within a role performs within a narrow band of the others.
------------------------------------------------------------------------
ns.SPEC_TUNE = {
	WARRIOR_ARMS = { atk = 1.31 },
	WARRIOR_FURY = { atk = 0.95 },
	WARRIOR_PROT = { hp = 0.94 },
	PALADIN_HOLY = { heal = 0.94 },
	PALADIN_PROT = { hp = 1.00 },
	PALADIN_RET = { atk = 1.43 },
	HUNTER_BM = { atk = 0.87 },
	HUNTER_MM = { atk = 0.85 },
	HUNTER_SV = { atk = 0.96 },
	ROGUE_ASSA = { atk = 0.76 },
	ROGUE_OUTLAW = { atk = 0.74 },
	ROGUE_SUB = { atk = 0.76 },
	PRIEST_DISC = { heal = 0.89 },
	PRIEST_HOLY = { heal = 0.97 },
	PRIEST_SHADOW = { atk = 1.30 },
	SHAMAN_ELE = { atk = 0.81 },
	SHAMAN_ENH = { atk = 1.00 },
	SHAMAN_RESTO = { heal = 1.15 },
	MAGE_ARCANE = { atk = 1.11 },
	MAGE_FIRE = { atk = 0.73 },
	MAGE_FROST = { atk = 1.15 },
	WARLOCK_AFF = { atk = 1.22 },
	WARLOCK_DEMO = { atk = 1.13 },
	WARLOCK_DESTRO = { atk = 1.14 },
	DRUID_BALANCE = { atk = 1.19 },
	DRUID_FERAL = { atk = 0.91 },
	DRUID_GUARDIAN = { hp = 1.04 },
	DRUID_RESTO = { heal = 1.14 },
}

function ns.SpecTune(specId, what)
	local t = ns.SPEC_TUNE[specId]
	return t and t[what] or 1
end

-- Experience needed to go from level L to L+1.
function ns.XPForLevel(l)
	return math.floor(78 * l * l * 1.0812 ^ l + 20)
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
