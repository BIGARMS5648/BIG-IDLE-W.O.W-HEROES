-- Active skills. Every value is { base, perLevel }; levels 1-5 come from
-- skill points.
--
-- act:  "count" = fires every n basic attacks, "cd" = cooldown, "aura" = always on.
-- kind: dmg | dot | field | pet | heal | shield | buff | debuff | aura | revive
--
-- Descriptions are generated from these fields (see ns.SkillDesc), so the text
-- a player reads can never drift from what the skill actually does.
local _, ns = ...

ns.SKILL_MAX = 5

-- Status ailments.
--   slow   : attack and move speed reduced by power %
--   cc     : cannot act
--   hitdot : damage per second = power % of the hit that applied it
--   dot    : damage per second set by the skill
--   vuln   : takes more damage (power %, or set by the skill)
--   weak   : deals less damage (set by the skill)
ns.STATUS = {
	chill     = { name = "냉기 둔화", kind = "slow", dur = 4, power = 30 },
	freeze    = { name = "빙결",       kind = "cc", dur = 1.5 },
	stun      = { name = "기절",      kind = "cc", dur = 2 },
	ignite    = { name = "발화",      kind = "hitdot", dur = 4, power = 25, school = "fire" },
	bleed     = { name = "출혈",     kind = "hitdot", dur = 6, power = 20, school = "phys" },
	shock     = { name = "감전",      kind = "vuln", dur = 6, power = 20 },
	curse     = { name = "저주",       kind = "vuln", dur = 10 },
	weaken    = { name = "약화",     kind = "weak", dur = 8 },
	poison    = { name = "중독",     kind = "dot", dur = 6, school = "nature" },
	venom     = { name = "맹독",    kind = "dot", dur = 8, school = "nature" },
	sting     = { name = "독사 쐐기",   kind = "dot", dur = 6, school = "nature" },
	corrupt   = { name = "부패",    kind = "dot", dur = 9, school = "shadow" },
	agony     = { name = "고통의 저주", kind = "dot", dur = 8, school = "shadow" },
	pain      = { name = "고통",       kind = "dot", dur = 9, school = "shadow" },
	plague    = { name = "역병",      kind = "dot", dur = 8, school = "shadow" },
	wyvern    = { name = "비룡 쐐기", kind = "dot", dur = 8, school = "nature" },
	rend      = { name = "분쇄",         kind = "dot", dur = 8, school = "phys" },
	rupture   = { name = "파열",     kind = "dot", dur = 8, school = "phys" },
	rake      = { name = "갈퀴 발톱",   kind = "dot", dur = 8, school = "phys" },
	moonfire  = { name = "달빛 섬광", kind = "dot", dur = 8, school = "arcane" },
	garrote   = { name = "목조르기", kind = "dot", dur = 6, school = "phys" },
}

ns.SKILLS = {}

local function S(id, name, icon, t)
	t.id = id
	t.name = name
	t.icon = icon
	ns.SKILLS[id] = t
end

-- shorthand constructors keep the table below readable
local function count(n, t) t.act = "count" t.n = n return t end
local function cd(sec, t) t.act = "cd" t.cd = sec return t end
local function aura(t) t.act = "aura" return t end

------------------------------------------------------------------------ Warrior
-- Arms
S("charge", "돌진", "Ability_Warrior_Charge",
	count(4, { kind = "dmg", school = "phys", v = { 220, 20 }, targets = 1, status = { "stun", 0.3 } }))
S("mortal_strike", "죽음의 일격", "Ability_Warrior_SavageBlow",
	count(3, { kind = "dmg", school = "phys", v = { 240, 22 }, targets = 1 }))
S("cleave", "회전베기", "Ability_Warrior_Cleave",
	count(4, { kind = "dmg", school = "phys", v = { 150, 14 }, targets = 3 }))
S("rend", "분쇄", "Ability_Gouge",
	count(5, { kind = "dot", school = "phys", status = "rend", v = { 55, 7 }, dur = 8, targets = 1 }))
S("battle_shout", "전투의 외침", "Ability_Warrior_BattleShout",
	aura({ kind = "aura", mods = { { "atkPct", 5, 1.2 } } }))
S("execute", "마무리 일격", "INV_Sword_48",
	cd(8, { kind = "dmg", school = "phys", v = { 300, 30 }, targets = 1, exec = { 30, 2 } }))
S("sweeping_strikes", "휩쓸기 일격", "Ability_Rogue_SliceDice",
	cd(30, { kind = "field", school = "phys", v = { 80, 9 }, tick = 0.5, dur = 4, targets = 99 }))
-- Fury
S("bloodthirst", "피의 갈증", "Spell_Nature_BloodLust",
	count(3, { kind = "dmg", school = "phys", v = { 200, 18 }, targets = 1, selfHeal = { 3, 0.4 } }))
S("whirlwind", "소용돌이", "Ability_Whirlwind",
	cd(6, { kind = "dmg", school = "phys", v = { 120, 12 }, targets = 5 }))
S("heroic_strike", "영웅의 일격", "Ability_Rogue_Ambush",
	count(4, { kind = "dmg", school = "phys", v = { 280, 26 }, targets = 1 }))
S("recklessness", "무모한 희생", "Ability_CriticalStrike",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "crit", 30, 3 }, { "aspdMult", 20, 2 } } }))
S("overpower", "제압", "Ability_MeleeDamage",
	cd(20, { kind = "dmg", school = "phys", v = { 130, 13 }, targets = 1, hits = 4 }))
-- Protection
S("shield_slam", "방패 밀쳐내기", "INV_Shield_05",
	count(4, { kind = "dmg", school = "phys", v = { 220, 20 }, targets = 1, status = { "stun", 0.3 } }))
S("thunder_clap", "천둥벼락", "Spell_Nature_ThunderClap",
	cd(9, { kind = "dmg", school = "phys", v = { 110, 12 }, targets = 5, status = { "chill", 1 } }))
S("revenge", "복수", "Ability_Warrior_Revenge",
	count(3, { kind = "dmg", school = "phys", v = { 160, 15 }, targets = 3 }))
S("defensive_stance", "방어 태세", "Ability_Warrior_DefensiveStance",
	aura({ kind = "aura", mods = { { "hpPct", 6, 1.5 } } }))
S("shield_wall", "방패의 벽", "Ability_Warrior_ShieldWall",
	cd(35, { kind = "buff", target = "self", dur = 8, mods = { { "dr", 35, 3 } }, when = { self = 0.6 } }))
S("last_stand", "최후의 저항", "Spell_Holy_AshesToAshes",
	cd(45, { kind = "heal", target = "self", v = { 30, 4 }, when = { self = 0.4 } }))

------------------------------------------------------------------------ Paladin
-- Holy
S("holy_light", "성스러운 빛", "Spell_Holy_HolyBolt",
	cd(6, { kind = "heal", target = "lowest", v = { 26, 3.5 }, when = { ally = 0.75 } }))
S("devotion_aura", "기원의 오라", "Spell_Holy_DevotionAura",
	aura({ kind = "aura", mods = { { "armorPct", 12, 3 } } }))
S("judgement", "심판", "Spell_Holy_RighteousFury",
	count(4, { kind = "dmg", school = "holy", v = { 240, 20 }, targets = 1, status = { "stun", 0.2 } }))
S("blessing_of_might", "힘의 축복", "Spell_Holy_FistOfJustice",
	aura({ kind = "aura", mods = { { "atkPct", 6, 1.5 } } }))
S("lay_on_hands", "신의 축복", "Spell_Holy_LayOnHands",
	{ act = "cd", cd = 60, cdPer = -5, kind = "heal", target = "lowest", v = { 100, 0 }, ofHealth = true, when = { ally = 0.3 } })
S("divine_protection", "신의 가호", "Spell_Holy_Restoration",
	cd(50, { kind = "shield", target = "all", v = { 20, 3 }, dur = 6, when = { ally = 0.5 } }))
-- Protection
S("seal_of_righteousness", "정의의 문장", "Ability_ThunderBolt",
	count(3, { kind = "dmg", school = "holy", v = { 180, 17 }, targets = 1 }))
S("holy_shield", "신성한 방패", "Spell_Holy_BlessingOfProtection",
	count(3, { kind = "dmg", school = "holy", v = { 200, 18 }, targets = 1 }))
S("exorcism", "퇴마술", "Spell_Holy_Excorcism_02",
	cd(8, { kind = "dmg", school = "holy", v = { 140, 14 }, targets = 3, status = { "stun", 0.25 } }))
S("consecration", "신성화", "Spell_Holy_InnerFire",
	cd(12, { kind = "field", school = "holy", v = { 32, 4 }, tick = 0.5, dur = 6, targets = 99 }))
S("blessing_of_sanctuary", "성역의 축복", "Spell_Nature_LightningShield",
	cd(40, { kind = "buff", target = "self", dur = 8, mods = { { "dr", 32, 3 } }, when = { self = 0.55 } }))
S("flash_of_light", "빛의 섬광", "Spell_Holy_FlashHeal",
	cd(22, { kind = "heal", target = "self", v = { 24, 3 }, when = { self = 0.55 } }))
-- Retribution
S("seal_of_command", "지휘의 문장", "Ability_Warrior_InnerRage",
	count(3, { kind = "dmg", school = "holy", v = { 220, 20 }, targets = 1 }))
S("holy_wrath", "신의 격노", "Spell_Holy_Excorcism",
	cd(7, { kind = "dmg", school = "holy", v = { 135, 13 }, targets = 5 }))
S("hammer_of_wrath", "천벌의 망치", "Ability_ThunderClap",
	cd(9, { kind = "dmg", school = "holy", v = { 320, 32 }, targets = 1, exec = { 30, 2 } }))
S("seal_of_the_crusader", "성전사의 문장", "Spell_Holy_HolySmite",
	cd(45, { kind = "buff", target = "self", dur = 12, mods = { { "atkMult", 25, 3 } } }))

------------------------------------------------------------------------ Hunter
-- Beast Mastery
S("intimidation", "위협", "Ability_Devour",
	count(3, { kind = "dmg", school = "phys", v = { 220, 20 }, targets = 1 }))
S("call_pet", "야수 부르기", "Ability_Hunter_BeastCall",
	aura({ kind = "pet", school = "phys", v = { 75, 9 }, tick = 1.5 }))
S("aspect_of_the_wild", "야생의 상", "Spell_Nature_ProtectionformNature",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("bestial_wrath", "야수의 격노", "Ability_Druid_FerociousBite",
	cd(40, { kind = "field", school = "phys", v = { 110, 15 }, tick = 1, dur = 12, targets = 1 }))
S("screech", "날카로운 울음소리", "Ability_Hunter_Pet_Bat",
	cd(45, { kind = "field", school = "phys", v = { 100, 12 }, tick = 1, dur = 10, targets = 3 }))
-- Marksmanship
S("multi_shot", "일제 사격", "Ability_UpgradeMoonGlaive",
	count(4, { kind = "dmg", school = "phys", v = { 130, 12 }, targets = 3 }))
S("aimed_shot", "조준 사격", "INV_Spear_07",
	cd(7, { kind = "dmg", school = "phys", v = { 320, 35 }, targets = 1, critBonus = 50 }))
S("arcane_shot", "신비한 사격", "Ability_ImpalingBolt",
	count(3, { kind = "dmg", school = "arcane", v = { 190, 18 }, targets = 1 }))
S("trueshot_aura", "정조준 오라", "Ability_TrueShot",
	aura({ kind = "aura", mods = { { "atkPct", 5, 1.2 } } }))
S("rapid_fire", "속사", "Ability_Hunter_RunningShot",
	cd(30, { kind = "buff", target = "self", dur = 8, mods = { { "aspdMult", 40, 6 } } }))
S("volley", "연발 사격", "Ability_Marksmanship",
	cd(14, { kind = "field", school = "phys", v = { 45, 6 }, tick = 0.5, dur = 4, targets = 99 }))
-- Survival
S("immolation_trap", "제물의 덫", "Spell_Fire_FlameShock",
	cd(5, { kind = "dmg", school = "fire", v = { 200, 20 }, targets = 3, status = { "ignite", 0.4 } }))
S("serpent_sting", "독사 쐐기", "Ability_Hunter_Quickshot",
	count(5, { kind = "dot", school = "nature", status = "sting", v = { 45, 6 }, dur = 6, targets = 1 }))
S("explosive_trap", "폭발의 덫", "Spell_Fire_SelfDestruct",
	cd(12, { kind = "field", school = "fire", v = { 48, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "ignite", 0.2 } }))
S("freezing_trap", "얼음의 덫", "Spell_Frost_ChainsOfIce",
	cd(14, { kind = "dmg", school = "frost", v = { 80, 8 }, targets = 99, status = { "freeze", 0.7 } }))
S("wyvern_sting", "비룡 쐐기", "INV_Spear_02",
	count(4, { kind = "dot", school = "nature", status = "wyvern", v = { 70, 8 }, dur = 8, targets = 1 }))
S("aspect_of_the_hawk", "매의 상", "Spell_Nature_RavenForm",
	cd(30, { kind = "buff", target = "self", dur = 10, mods = { { "aspdMult", 20, 2.5 }, { "crit", 15, 2 } } }))

------------------------------------------------------------------------ Rogue
-- Assassination
S("ghostly_strike", "그림자 일격", "Spell_Shadow_Curse",
	count(3, { kind = "dmg", school = "phys", v = { 120, 11 }, targets = 1, hits = 2 }))
S("deadly_poison", "맹독", "Ability_Rogue_DualWeild",
	count(4, { kind = "dot", school = "nature", status = "venom", v = { 55, 7 }, dur = 8, targets = 1 }))
S("instant_poison", "순간 효과 독", "Ability_Poisons",
	count(6, { kind = "dmg", school = "nature", v = { 480, 46 }, targets = 1 }))
S("rupture", "파열", "Ability_Rogue_Rupture",
	count(5, { kind = "dot", school = "phys", status = "rupture", v = { 60, 8 }, dur = 8, targets = 1 }))
S("garrote", "목조르기", "Ability_Rogue_Garrote",
	count(4, { kind = "dot", school = "phys", status = "garrote", v = { 60, 7 }, dur = 6, targets = 1 }))
S("cold_blood", "냉혈", "Spell_Ice_Lament",
	cd(20, { kind = "dmg", school = "phys", v = { 600, 60 }, targets = 1, critBonus = 100 }))
-- Outlaw
S("sinister_strike", "사악한 일격", "Spell_Shadow_RitualOfSacrifice",
	count(3, { kind = "dmg", school = "phys", v = { 190, 18 }, targets = 1 }))
S("blade_flurry", "폭풍의 칼날", "Ability_Warrior_PunishingBlow",
	cd(25, { kind = "buff", target = "self", dur = 10, mods = { { "aspdMult", 45, 6 } } }))
S("eviscerate", "절개", "Ability_Rogue_Eviscerate",
	count(6, { kind = "dmg", school = "phys", v = { 520, 50 }, targets = 1 }))
S("evasion", "회피", "Spell_Shadow_ShadowWard",
	cd(30, { kind = "buff", target = "self", dur = 8, mods = { { "dodge", 40, 4 } }, when = { self = 0.7 } }))
S("riposte", "반격", "Ability_Warrior_Challange",
	cd(25, { kind = "dmg", school = "phys", v = { 110, 11 }, targets = 1, hits = 5 }))
S("adrenaline_rush", "아드레날린 촉진", "Spell_Shadow_ShadowWordDominate",
	cd(45, { kind = "buff", target = "self", dur = 10, mods = { { "aspdMult", 50, 8 } } }))
-- Subtlety
S("backstab", "기습", "Ability_BackStab",
	count(3, { kind = "dmg", school = "phys", v = { 230, 22 }, targets = 1, critBonus = 20 }))
S("hemorrhage", "과다출혈", "Spell_Shadow_LifeDrain",
	count(4, { kind = "dmg", school = "phys", v = { 170, 16 }, targets = 1, status = { "bleed", 1 } }))
S("ambush", "매복", "Ability_Rogue_Ambush",
	cd(9, { kind = "dmg", school = "phys", v = { 380, 38 }, targets = 1, critBonus = 30 }))
S("vanish", "소멸", "Ability_Vanish",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "critdmg", 50, 6 }, { "aspdMult", 20, 2 } } }))
S("slice_and_dice", "난도질", "Ability_Rogue_SliceDice",
	cd(40, { kind = "buff", target = "self", dur = 12, mods = { { "atkMult", 25, 3 } } }))

------------------------------------------------------------------------ Priest
-- Discipline
S("flash_heal", "순간 치유", "Spell_Holy_FlashHeal",
	cd(5, { kind = "heal", target = "lowest", v = { 19, 2.6 }, when = { ally = 0.8 } }))
S("pw_shield", "신의 권능: 보호막", "Spell_Holy_PowerWordShield",
	cd(11, { kind = "shield", target = "lowest", v = { 18, 3 }, dur = 10, when = { ally = 0.9 } }))
S("smite", "성스러운 일격", "Spell_Holy_HolySmite",
	count(3, { kind = "dmg", school = "holy", v = { 180, 17 }, targets = 1, atone = { 4, 0.5 } }))
S("fortitude", "신의 권능: 인내", "Spell_Holy_WordFortitude",
	aura({ kind = "aura", mods = { { "hpPct", 8, 2 } } }))
S("power_infusion", "마력 주입", "Spell_Holy_PowerInfusion",
	cd(30, { kind = "buff", target = "lowest", dur = 8, mods = { { "dr", 35, 3 } }, when = { ally = 0.45 } }))
S("prayer_of_fortitude", "인내의 기원", "Spell_Holy_PrayerOfFortitude",
	cd(45, { kind = "buff", target = "party", dur = 8, mods = { { "dr", 18, 2 } }, when = { ally = 0.6 } }))
-- Holy
S("lesser_heal", "하급 치유", "Spell_Holy_LesserHeal",
	cd(4, { kind = "heal", target = "lowest", v = { 16, 2.2 }, when = { ally = 0.85 } }))
S("heal", "치유", "Spell_Holy_Heal02",
	cd(5, { kind = "heal", target = "lowest", v = { 22, 3 }, when = { ally = 0.8 } }))
S("renew", "소생", "Spell_Holy_Renew",
	cd(7, { kind = "heal", target = "lowest", v = { 4.5, 0.6 }, hot = 6, when = { ally = 0.9 } }))
S("holy_nova", "신성한 폭발", "Spell_Holy_HolyNova",
	cd(10, { kind = "dmg", school = "holy", v = { 120, 12 }, targets = 99, healAll = { 6, 1 } }))
S("prayer_of_healing", "치유의 기원", "Spell_Holy_PrayerOfHealing02",
	cd(14, { kind = "heal", target = "all", v = { 14, 2 }, when = { ally = 0.7 } }))
S("resurrection", "부활", "Spell_Holy_Resurrection",
	cd(45, { kind = "revive", v = { 30, 5 } }))
-- Shadow
S("mind_blast", "정신 분열", "Spell_Shadow_UnholyFrenzy",
	cd(5, { kind = "dmg", school = "shadow", v = { 240, 24 }, targets = 1 }))
S("sw_pain", "어둠의 권능: 고통", "Spell_Shadow_ShadowWordPain",
	count(4, { kind = "dot", school = "shadow", status = "pain", v = { 45, 6 }, dur = 9, targets = 2 }))
S("mind_flay", "정신의 채찍", "Spell_Shadow_SiphonMana",
	count(2, { kind = "dmg", school = "shadow", v = { 150, 14 }, targets = 1, status = { "chill", 0.5 } }))
S("vampiric_embrace", "흡혈의 선물", "Spell_Shadow_UnsummonBuilding",
	aura({ kind = "aura", mods = { { "healTaken", 6, 1.5 } } }))
S("devouring_plague", "파멸의 역병", "Spell_Shadow_BlackPlague",
	cd(10, { kind = "dot", school = "shadow", status = "plague", v = { 90, 10 }, dur = 8, targets = 1 }))
S("shadowguard", "어둠의 수호", "Spell_Nature_LightningShield",
	cd(40, { kind = "field", school = "shadow", v = { 110, 14 }, tick = 1, dur = 12, targets = 1 }))

------------------------------------------------------------------------ Shaman
-- Elemental
S("lightning_bolt", "번개 화살", "Spell_Nature_Lightning",
	count(2, { kind = "dmg", school = "nature", v = { 210, 20 }, targets = 1, status = { "shock", 0.25 } }))
S("chain_lightning", "연쇄 번개", "Spell_Nature_ChainLightning",
	cd(7, { kind = "dmg", school = "nature", v = { 170, 17 }, targets = 4, status = { "shock", 0.3 } }))
S("earth_shock", "대지 충격", "Spell_Nature_EarthShock",
	cd(8, { kind = "dmg", school = "nature", v = { 240, 24 }, targets = 1, status = { "stun", 0.4 } }))
S("flametongue_totem", "불꽃의 토템", "Spell_Nature_GuardianWard",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("flame_shock", "화염 충격", "Spell_Fire_FlameShock",
	cd(8, { kind = "dmg", school = "fire", v = { 330, 33 }, targets = 1, critBonus = 40 }))
S("strength_of_earth", "대지력 토템", "Spell_Nature_EarthBindTotem",
	cd(60, { kind = "buff", target = "party", dur = 10, mods = { { "aspdMult", 30, 4 }, { "atkPct", 10, 1 } } }))
-- Enhancement
S("stormstrike", "폭풍의 일격", "Spell_Holy_SealOfMight",
	count(3, { kind = "dmg", school = "nature", v = { 120, 11 }, targets = 1, hits = 2 }))
S("flametongue_weapon", "불꽃의 무기", "Spell_Fire_FlameTounge",
	count(4, { kind = "dmg", school = "fire", v = { 250, 24 }, targets = 1, status = { "ignite", 0.4 } }))
S("windfury_totem", "질풍의 토템", "Spell_Nature_Windfury",
	aura({ kind = "aura", mods = { { "aspd", 6, 1.5 } } }))
S("searing_totem", "불타는 토템", "Spell_Fire_SearingTotem",
	cd(30, { kind = "field", school = "fire", v = { 90, 11 }, tick = 1, dur = 12, targets = 2 }))
S("fire_nova", "불꽃 회오리 토템", "Spell_Fire_SealOfFire",
	cd(10, { kind = "dmg", school = "fire", v = { 170, 17 }, targets = 99 }))
-- Restoration
S("healing_wave", "치유의 물결", "Spell_Nature_MagicImmunity",
	cd(5, { kind = "heal", target = "lowest", v = { 22, 3 }, when = { ally = 0.8 } }))
S("chain_heal", "연쇄 치유", "Spell_Nature_HealingWaveGreater",
	cd(9, { kind = "heal", target = "lowest", targets = 3, v = { 12, 1.6 }, when = { ally = 0.8 } }))
S("stoneskin_totem", "돌가죽 토템", "Spell_Nature_StoneSkinTotem",
	cd(14, { kind = "shield", target = "tank", v = { 20, 3 }, dur = 12 }))
S("healing_stream", "치유의 토템", "INV_Spear_04",
	aura({ kind = "aura", mods = { { "healTaken", 8, 2 } } }))
S("lesser_healing_wave", "하급 치유의 물결", "Spell_Nature_HealingWaveLesser",
	cd(7, { kind = "heal", target = "lowest", v = { 3.5, 0.5 }, hot = 6, instant = { 9, 1.2 }, when = { ally = 0.85 } }))
S("ancestral_spirit", "고대의 영혼", "Spell_Nature_Regenerate",
	cd(50, { kind = "revive", v = { 25, 5 } }))

------------------------------------------------------------------------ Mage
-- Arcane
S("presence_of_mind", "냉정", "Spell_Nature_EnchantArmor",
	count(2, { kind = "dmg", school = "arcane", v = { 200, 19 }, targets = 1 }))
S("arcane_missiles", "신비한 화살", "Spell_Nature_StarFall",
	count(3, { kind = "dmg", school = "arcane", v = { 70, 8 }, targets = 1, hits = 3 }))
S("arcane_explosion", "신비한 폭발", "Spell_Nature_WispSplode",
	cd(7, { kind = "dmg", school = "arcane", v = { 130, 13 }, targets = 99 }))
S("mana_shield", "마나 보호막", "Spell_Shadow_DetectLesserInvisibility",
	cd(20, { kind = "shield", target = "self", v = { 25, 3.5 }, dur = 10, when = { self = 0.9 } }))
S("arcane_power", "신비의 마법 강화", "Spell_Nature_Lightning",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "atkMult", 30, 3 } } }))
S("blast_wave", "화염 폭풍", "Spell_Holy_Excorcism_02",
	cd(12, { kind = "dmg", school = "fire", v = { 300, 30 }, targets = 3 }))
-- Fire
S("fireball", "화염구", "Spell_Fire_FlameBolt",
	cd(5, { kind = "dmg", school = "fire", v = { 220, 22 }, targets = 3, status = { "ignite", 0.4 } }))
S("scorch", "불태우기", "Spell_Fire_SoulBurn",
	count(2, { kind = "dmg", school = "fire", v = { 160, 15 }, targets = 1, status = { "ignite", 0.5 } }))
S("fire_blast", "화염 작열", "Spell_Fire_Fireball",
	cd(6, { kind = "dmg", school = "fire", v = { 240, 24 }, targets = 1, critBonus = 30 }))
S("flamestrike", "불기둥", "Spell_Fire_SelfDestruct",
	cd(12, { kind = "dmg", school = "fire", v = { 340, 34 }, targets = 5, status = { "ignite", 0.5 } }))
S("combustion", "발화", "Spell_Fire_SealOfFire",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "crit", 40, 4 } } }))
S("pyroblast", "불덩이 작열", "Spell_Fire_Fireball02",
	cd(18, { kind = "dmg", school = "fire", v = { 850, 85 }, targets = 1, status = { "ignite", 1 } }))
-- Frost
S("frostbolt", "얼음 화살", "Spell_Frost_FrostBolt02",
	count(2, { kind = "dmg", school = "frost", v = { 190, 18 }, targets = 1, status = { "chill", 1 } }))
S("frost_nova", "얼음 회오리", "Spell_Frost_FrostNova",
	cd(10, { kind = "dmg", school = "frost", v = { 100, 10 }, targets = 99, status = { "freeze", 0.6 } }))
S("cone_of_cold", "냉기 돌풍", "Spell_Frost_Glacier",
	count(3, { kind = "dmg", school = "frost", v = { 240, 23 }, targets = 1 }))
S("ice_barrier", "얼음 보호막", "Spell_Ice_Lament",
	cd(20, { kind = "shield", target = "self", v = { 30, 4 }, dur = 10, when = { self = 0.9 } }))
S("blizzard", "눈보라", "Spell_Frost_IceStorm",
	cd(14, { kind = "field", school = "frost", v = { 50, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "chill", 0.5 } }))
S("ice_armor", "얼음 갑옷", "Spell_Frost_FrostArmor02",
	aura({ kind = "aura", self = true, mods = { { "armorPct", 30, 6 }, { "dr", 5, 1 } } }))

------------------------------------------------------------------------ Warlock
-- Affliction
S("corruption", "부패", "Spell_Shadow_AbominationExplosion",
	cd(6, { kind = "dot", school = "shadow", status = "corrupt", v = { 45, 6 }, dur = 9, targets = 3 }))
S("curse_of_agony", "고통의 저주", "Spell_Shadow_CurseOfSargeras",
	count(3, { kind = "dot", school = "shadow", status = "agony", v = { 80, 9 }, dur = 8, targets = 1 }))
S("drain_life", "생명력 흡수", "Spell_Shadow_LifeDrain02",
	cd(9, { kind = "dmg", school = "shadow", v = { 250, 25 }, targets = 1, drain = 100 }))
S("curse_of_elements", "원소의 저주", "Spell_Shadow_ChillTouch",
	cd(20, { kind = "debuff", status = "curse", v = { 12, 1.6 }, dur = 10, targets = 99 }))
S("siphon_life", "생명력 착취", "Spell_Shadow_Requiem",
	cd(10, { kind = "dmg", school = "shadow", v = { 340, 34 }, targets = 1 }))
S("hellfire", "지옥의 불길", "Spell_Fire_Incinerate",
	cd(14, { kind = "dmg", school = "fire", v = { 230, 23 }, targets = 99 }))
-- Demonology
S("shadow_bolt", "어둠의 화살", "Spell_Shadow_ShadowBolt",
	count(2, { kind = "dmg", school = "shadow", v = { 220, 21 }, targets = 1 }))
S("summon_felhunter", "지옥사냥개 소환", "Spell_Shadow_SummonFelHunter",
	aura({ kind = "pet", school = "phys", v = { 80, 10 }, tick = 1.5 }))
S("soul_link", "영혼의 고리", "Spell_Shadow_GatherShadows",
	aura({ kind = "aura", self = true, mods = { { "dr", 8, 1.5 }, { "hpPct", 6, 1.5 } } }))
S("death_coil", "죽음의 고리", "Spell_Shadow_DeathCoil",
	cd(9, { kind = "dmg", school = "shadow", v = { 190, 19 }, targets = 4, status = { "stun", 0.2 } }))
S("demonic_sacrifice", "악의 제물", "Spell_Shadow_PsychicScream",
	cd(45, { kind = "buff", target = "self", dur = 12, mods = { { "atkMult", 30, 3 }, { "dr", 20, 0 } } }))
S("inferno", "불지옥", "Spell_Shadow_SummonInfernal",
	cd(40, { kind = "field", school = "fire", v = { 65, 8 }, tick = 1, dur = 12, targets = 99, status = { "ignite", 0.15 } }))
-- Destruction
S("immolate", "제물", "Spell_Fire_Immolation",
	count(3, { kind = "dmg", school = "fire", v = { 150, 14 }, targets = 1, status = { "ignite", 1 } }))
S("searing_pain", "불타는 고통", "Spell_Fire_SoulBurn",
	count(2, { kind = "dmg", school = "fire", v = { 210, 20 }, targets = 1 }))
S("rain_of_fire", "불의 비", "Spell_Shadow_RainOfFire",
	cd(13, { kind = "field", school = "fire", v = { 45, 5 }, tick = 0.5, dur = 4, targets = 99, status = { "ignite", 0.15 } }))
S("conflagrate", "점화", "Spell_Fire_Fireball",
	cd(8, { kind = "dmg", school = "fire", v = { 310, 31 }, targets = 1, critBonus = 25 }))
S("shadowburn", "어둠의 연소", "Spell_Shadow_ScourgeBuild",
	cd(9, { kind = "dmg", school = "shadow", v = { 300, 30 }, targets = 1, exec = { 30, 2 } }))
S("soul_fire", "영혼의 불꽃", "Spell_Fire_Fireball02",
	cd(14, { kind = "dmg", school = "fire", v = { 420, 42 }, targets = 1, critBonus = 100 }))

------------------------------------------------------------------------ Druid
-- Balance
S("wrath", "천벌", "Spell_Nature_AbolishMagic",
	count(2, { kind = "dmg", school = "nature", v = { 200, 19 }, targets = 1 }))
S("moonfire", "달빛 섬광", "Spell_Nature_StarFall",
	count(4, { kind = "dot", school = "arcane", status = "moonfire", v = { 50, 6 }, dur = 8, targets = 2 }))
S("starfire", "별빛 화살", "Spell_Arcane_StarFire",
	cd(6, { kind = "dmg", school = "arcane", v = { 290, 29 }, targets = 1 }))
S("moonkin_form", "달빛야수 변신", "Spell_Nature_ForceOfNature",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("hurricane", "허리케인", "Spell_Nature_Cyclone",
	cd(14, { kind = "field", school = "nature", v = { 50, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "chill", 0.5 } }))
S("insect_swarm", "곤충 떼", "Spell_Nature_InsectSwarm",
	cd(25, { kind = "field", school = "nature", v = { 85, 10 }, tick = 0.5, dur = 6, targets = 3 }))
-- Feral
S("claw", "할퀴기", "Ability_Druid_Rake",
	count(3, { kind = "dmg", school = "phys", v = { 190, 18 }, targets = 1 }))
S("shred", "칼날 발톱", "Spell_Shadow_VampiricAura",
	count(3, { kind = "dmg", school = "phys", v = { 230, 22 }, targets = 1 }))
S("rake", "갈퀴 발톱", "Ability_Druid_Disembowel",
	count(4, { kind = "dot", school = "phys", status = "rake", v = { 60, 7 }, dur = 8, targets = 1 }))
S("ferocious_bite", "흉포한 이빨", "Ability_Druid_FerociousBite",
	count(6, { kind = "dmg", school = "phys", v = { 520, 50 }, targets = 1 }))
S("leader_of_pack", "무리의 우두머리", "Spell_Nature_UnyeildingStamina",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("tigers_fury", "맹공격", "Ability_Mount_JungleTiger",
	cd(30, { kind = "buff", target = "self", dur = 8, mods = { { "atkMult", 25, 3 } } }))
-- Guardian
S("maul", "후려치기", "Ability_Druid_Maul",
	count(3, { kind = "dmg", school = "phys", v = { 200, 18 }, targets = 1 }))
S("swipe", "휘둘러치기", "INV_Misc_MonsterClaw_03",
	cd(6, { kind = "dmg", school = "phys", v = { 90, 10 }, targets = 4, status = { "bleed", 0.5 } }))
S("demo_roar", "위협의 포효", "Ability_Druid_DemoralizingRoar",
	cd(18, { kind = "debuff", status = "weaken", v = { 20, 2 }, dur = 8, targets = 99 }))
S("bash", "강타", "Ability_Druid_Bash",
	cd(10, { kind = "dmg", school = "phys", v = { 150, 15 }, targets = 1, status = { "stun", 0.6 } }))
S("frenzied_regen", "광포한 재생력", "Ability_BullRush",
	cd(30, { kind = "heal", target = "self", v = { 4, 0.5 }, hot = 8, when = { self = 0.6 } }))
S("barkskin", "나무 껍질", "Spell_Nature_StoneClawTotem",
	cd(40, { kind = "buff", target = "party", dur = 8, mods = { { "dr", 15, 2 } }, when = { ally = 0.6 } }))
-- Restoration
S("rejuvenation", "회복", "Spell_Nature_Rejuvenation",
	cd(5, { kind = "heal", target = "lowest", v = { 5, 0.7 }, hot = 5, when = { ally = 0.9 } }))
S("healing_touch", "치유의 손길", "Spell_Nature_HealingTouch",
	cd(8, { kind = "heal", target = "lowest", v = { 30, 4 }, when = { ally = 0.7 } }))
S("regrowth", "재생", "Spell_Nature_ResistNature",
	cd(12, { kind = "heal", target = "all", v = { 2.4, 0.35 }, hot = 6, when = { ally = 0.8 } }))
S("mark_of_wild", "야생의 징표", "Spell_Nature_Regeneration",
	aura({ kind = "aura", mods = { { "hpPct", 5, 1.2 }, { "res", 4, 1 } } }))
S("tranquility", "평온", "Spell_Nature_Tranquility",
	cd(40, { kind = "heal", target = "all", v = { 25, 3.5 }, when = { ally = 0.5 } }))
S("rebirth", "환생", "Spell_Nature_Reincarnation",
	cd(50, { kind = "revive", v = { 30, 5 } }))

-- The level a character learns each spell at in the original game (a
-- talent: the level its talent row opens, 10 + 5 per row). Every spec's six
-- skills open in this order (Data/Classes.lua, ns.SKILL_UNLOCK).
ns.SKILL_LEARN = {
	battle_shout = 1, devotion_aura = 1, eviscerate = 1, lesser_heal = 1, seal_of_righteousness = 1, fireball = 1, fortitude = 1,
	healing_touch = 1, healing_wave = 1, heroic_strike = 1, holy_light = 1, immolate = 1, lightning_bolt = 1,
	mark_of_wild = 1, shadow_bolt = 1, sinister_strike = 1, smite = 1, wrath = 1, backstab = 4,
	blessing_of_might = 4, corruption = 4, earth_shock = 4, frostbolt = 4, judgement = 4, moonfire = 4,
	rejuvenation = 4, rend = 4, serpent_sting = 4, stoneskin_totem = 4, sw_pain = 4, arcane_shot = 6,
	divine_protection = 6, fire_blast = 6, pw_shield = 6, seal_of_the_crusader = 6, charge = 4,
	thunder_clap = 6, arcane_missiles = 8, curse_of_agony = 8, evasion = 8, renew = 8, aspect_of_the_hawk = 10,
	call_pet = 10, defensive_stance = 10, demo_roar = 10, flame_shock = 10, flametongue_weapon = 10,
	frost_nova = 10, lay_on_hands = 10, maul = 10, mind_blast = 10, resurrection = 10, screech = 10,
	searing_totem = 10, slice_and_dice = 10, strength_of_earth = 10, ancestral_spirit = 12, bash = 14, garrote = 14,
	fire_nova = 12, overpower = 12, regrowth = 12, arcane_explosion = 14, drain_life = 14, claw = 20, mana_shield = 20,
	revenge = 14, flamestrike = 16, heal = 16, immolation_trap = 16, swipe = 16, ambush = 18, multi_shot = 18,
	searing_pain = 18, aimed_shot = 20, blizzard = 20, cleave = 20, consecration = 20, devouring_plague = 20,
	exorcism = 20, flash_heal = 20, flash_of_light = 20, freezing_trap = 20, ghostly_strike = 20,
	healing_stream = 20, holy_nova = 20, insect_swarm = 20, instant_poison = 20, last_stand = 20,
	lesser_healing_wave = 20, mind_flay = 20, pyroblast = 20, rain_of_fire = 20, rebirth = 20, riposte = 20,
	rupture = 20, seal_of_command = 20, shadowburn = 20, shadowguard = 20, starfire = 20, scorch = 22,
	shred = 22, vanish = 22, execute = 24, rake = 24, tigers_fury = 24, cone_of_cold = 26, rapid_fire = 26,
	flametongue_totem = 28, shield_wall = 28, blade_flurry = 30, blast_wave = 30, blessing_of_sanctuary = 30,
	cold_blood = 30, deadly_poison = 30, demonic_sacrifice = 30, hellfire = 30, hemorrhage = 30, ice_armor = 30,
	intimidation = 30, prayer_of_healing = 30, siphon_life = 30, summon_felhunter = 30, sweeping_strikes = 30,
	tranquility = 30, vampiric_embrace = 30, chain_lightning = 32, curse_of_elements = 32, ferocious_bite = 32,
	windfury_totem = 32, explosive_trap = 34, presence_of_mind = 35, frenzied_regen = 36, whirlwind = 36,
	adrenaline_rush = 40, arcane_power = 40, bestial_wrath = 40, bloodthirst = 40, chain_heal = 40,
	combustion = 40, conflagrate = 40, holy_shield = 40, hurricane = 40, ice_barrier = 40, leader_of_pack = 40,
	moonkin_form = 40, mortal_strike = 40, power_infusion = 40, shield_slam = 40, soul_link = 40,
	stormstrike = 40, trueshot_aura = 40, volley = 40, wyvern_sting = 40, death_coil = 42, barkskin = 44,
	hammer_of_wrath = 44, aspect_of_the_wild = 46, prayer_of_fortitude = 48, soul_fire = 48, holy_wrath = 50,
	inferno = 50, recklessness = 50,
}

------------------------------------------------------------------------
-- Values and generated text
------------------------------------------------------------------------
local function at(v, lvl)
	return v[1] + v[2] * (math.max(1, lvl) - 1)
end

function ns.SkillValue(id, lvl)
	local sk = ns.SKILLS[id]
	local v = sk.v or (sk.mods and { sk.mods[1][2], sk.mods[1][3] }) or { 0, 0 }
	return at(v, lvl)
end

function ns.SkillCooldown(id, lvl)
	local sk = ns.SKILLS[id]
	if not sk.cd then return 0 end
	return math.max(5, sk.cd + (sk.cdPer or 0) * (math.max(1, lvl) - 1))
end

function ns.SkillMods(id, lvl)
	local sk = ns.SKILLS[id]
	local out = {}
	for i, m in ipairs(sk.mods or {}) do
		out[i] = { m[1], m[2] + m[3] * (math.max(1, lvl) - 1) }
	end
	return out
end

local function num(v) return ns.U.num(v, 1) end

local function targetText(n)
	if not n or n <= 1 then return "대상" end
	if n >= 99 then return "모든 적" end
	return "적 " .. n .. "명"
end

local function modsText(id, lvl)
	local parts = {}
	for _, m in ipairs(ns.SkillMods(id, lvl)) do
		parts[#parts + 1] = ns.Stats.ModText(m[1], m[2])
	end
	return table.concat(parts, ", ")
end

local function whenText(sk)
	local w = sk.when
	if not w then return "" end
	if w.self then
		return string.format("자신의 생명력이 %d%% 아래일 때: ", w.self * 100)
	end
	if w.ally and (sk.kind == "heal" or sk.kind == "shield") then
		-- (it is only used then)
		return string.format("아군 생명력이 %d%% 아래일 때: ", w.ally * 100)
	end
	if w.ally then
		return string.format("아군 생명력이 %d%% 아래로 떨어지면: ", w.ally * 100)
	end
	return ""
end

-- How a heal of `pct` reads: a healer's skill mends out of 공격력 (its
-- number for the hero's level and spec when heroId is given), anything else
-- a share of the target's health.
local function healOf(sk, pct, heroId)
	if not sk.byAtk then return "최대 생명력의 " .. num(pct) .. "%" end
	local h = heroId and ns.db and ns.db.heroes[heroId]
	local level = h and h.level or 1
	local spec = h and h.spec or sk.byAtk
	return "공격력의 " .. num(pct * ns.HealAtk(level) * ns.SpecTune(spec, "heal")) .. "%"
end

function ns.SkillDesc(id, lvl, heroId)
	local sk = ns.SKILLS[id]
	lvl = math.max(1, lvl or 1)
	local v = sk.v and at(sk.v, lvl) or 0
	local school = sk.school and ns.N(ns.SCHOOL[sk.school].name) or ""
	local kind = sk.kind
	local s

	if kind == "dmg" then
		s = string.format("%s에게 %s%% %s 피해를 %s줍니다.", targetText(sk.targets), num(v), school, (sk.hits or 1) > 1 and (sk.hits .. "번 ") or "")
		if sk.status then
			local st = ns.N(ns.STATUS[sk.status[1]].name)
			if sk.status[2] >= 1 then
				s = s .. " " .. st .. " 상태로 만듭니다."
			else
				s = s .. string.format(" %d%% 확률로 %s.", sk.status[2] * 100, st)
			end
		end
		if sk.critBonus then s = s .. string.format(" 치명타 확률 +%d%%.", sk.critBonus) end
		if sk.exec then s = s .. string.format(" 생명력 %d%% 이하의 적에게는 %d배.", sk.exec[1], sk.exec[2]) end
		if sk.drain then
			s = s .. (sk.drain >= 100 and " 준 피해만큼" or string.format(" 준 피해의 %d%%만큼", sk.drain))
				.. " 자신의 생명력을 회복합니다 (한 번에 최대 생명력의 30%까지)."
		end
		if sk.selfHeal then s = s .. string.format(" 자신의 최대 생명력 %s%% 회복.", num(at(sk.selfHeal, lvl))) end
		if sk.healAll then s = s .. string.format(" 파티 전원이 %s 회복.", healOf(sk, at(sk.healAll, lvl), heroId)) end
		if sk.atone then s = s .. string.format(" 가장 다친 아군이 %s 회복.", healOf(sk, at(sk.atone, lvl), heroId)) end
	elseif kind == "dot" then
		s = string.format("%s에게 %s초 동안 매초 %s%% %s 피해를 줍니다.", targetText(sk.targets), num(sk.dur), num(v), school)
	elseif kind == "field" and sk.heal then
		s = string.format("%s초 동안 %s초마다 파티 전원이 %s를 회복합니다.", num(sk.dur), num(sk.tick), healOf(sk, v, heroId))
	elseif kind == "field" then
		s = string.format("%s초 동안 %s초마다 %s에게 %s%% %s 피해를 줍니다.", num(sk.dur), num(sk.tick), targetText(sk.targets), num(v), school)
		if sk.status then
			s = s .. string.format(" %d%% 확률로 %s.", sk.status[2] * 100, ns.N(ns.STATUS[sk.status[1]].name))
		end
	elseif kind == "pet" and sk.heal then
		s = string.format("늘 곁을 따라다니며 %s초마다 가장 다친 아군의 생명력을 %s만큼 회복합니다.", num(sk.tick), healOf(sk, v, heroId))
	elseif kind == "pet" then
		s = string.format("늘 곁에서 싸우는 소환수가 %s초마다 가장 가까운 적에게 %s%% %s 피해를 줍니다.", num(sk.tick), num(v), school)
	elseif kind == "heal" then
		local who
		if sk.target == "self" then
			who = "자신"
		elseif sk.target == "all" then
			who = "파티 전원"
		elseif (sk.targets or 1) > 1 then
			who = "가장 다친 아군 " .. sk.targets .. "명"
		else
			who = "가장 다친 아군"
		end
		if sk.hot then
			s = string.format("%s: %s초 동안 매초 %s 회복.", who, num(sk.hot), healOf(sk, v, heroId))
			if sk.instant then s = s .. string.format(" 즉시 %s 추가 회복.", healOf(sk, at(sk.instant, lvl), heroId)) end
		else
			s = string.format("%s: %s 회복.", who, healOf(sk, v, heroId))
		end
	elseif kind == "shield" then
		local who = ({ self = "자신", all = "파티 전원", tank = "방어 전담" })[sk.target] or "가장 다친 아군"
		s = string.format("%s에게 %s를 흡수하는 보호막을 %s초 동안 씌웁니다.", who, healOf(sk, v, heroId), num(sk.dur))
	elseif kind == "buff" then
		local who = ({ party = "파티 전원", lowest = "가장 다친 아군" })[sk.target] or "자신"
		s = string.format("%s초 동안 %s: %s", num(sk.dur), who, modsText(id, lvl))
	elseif kind == "debuff" then
		if sk.status == "weaken" then
			s = string.format("%s초 동안 %s이(가) 주는 피해가 %s%% 감소합니다.", num(sk.dur), targetText(sk.targets), num(v))
		else
			s = string.format("%s초 동안 %s이(가) 받는 피해가 %s%% 증가합니다.", num(sk.dur), targetText(sk.targets), num(v))
		end
	elseif kind == "aura" then
		s = string.format("장착하는 동안 %s: %s", sk.self and "자신" or "파티 전원", modsText(id, lvl))
	elseif kind == "revive" then
		s = string.format("쓰러진 아군을 최대 생명력의 %s%%로 되살립니다.", num(v))
	else
		s = ""
	end
	return whenText(sk) .. s
end

function ns.SkillActText(id, lvl)
	local sk = ns.SKILLS[id]
	if sk.act == "aura" then
		return "지속 효과"
	elseif sk.act == "count" then
		return string.format("기본 공격 %d회마다 발동", sk.n)
	end
	return string.format("재사용 대기시간 %s초", ns.U.num(ns.SkillCooldown(id, lvl), 1))
end

-- One-word role of a skill, used for badges in the UI.
function ns.SkillTag(id)
	local k = ns.SKILLS[id].kind
	if k == "heal" or k == "revive" or ns.SKILLS[id].heal then return "치유" end
	if k == "shield" then return "보호" end
	if k == "aura" then return "오라" end
	if k == "pet" then return "소환수" end
	if k == "buff" then return "강화" end
	if k == "debuff" then return "약화" end
	if (ns.SKILLS[id].targets or 1) > 1 or k == "field" then return "광역" end
	return "단일"
end
