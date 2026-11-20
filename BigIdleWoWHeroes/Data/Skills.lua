-- Active skills. Every value is { base, perLevel }; level 1-5 comes from skill
-- points, 6-10 only from "+All Skill Levels" gear.
--
-- act:  "count" = fires every n basic attacks, "cd" = cooldown, "aura" = always on.
-- kind: dmg | dot | field | pet | heal | shield | buff | debuff | aura | revive
--
-- Descriptions are generated from these fields (see ns.SkillDesc), so the text
-- a player reads can never drift from what the skill actually does.
local _, ns = ...

-- Passive-only stats that the talent trees use.
ns.AFFIX.regenPct = { t = "regenPct", l = "flat", n = { "초당 최대 생명력 회복", "Max Health Regen/s" }, f = "pct2" }
ns.AFFIX.hpkPct   = { t = "hpkPct",   l = "flat", n = { "처치 시 최대 생명력 회복", "Max Health per Kill" }, f = "pct2" }

ns.SKILL_MAX = 5
ns.SKILL_CAP = 10

-- Status ailments.
--   slow   : attack and move speed reduced by power %
--   cc     : cannot act
--   hitdot : damage per second = power % of the hit that applied it
--   dot    : damage per second set by the skill
--   vuln   : takes more damage (power %, or set by the skill)
--   weak   : deals less damage (set by the skill)
ns.STATUS = {
	chill     = { name = { "냉기 둔화", "Chilled" }, kind = "slow", dur = 4, power = 30 },
	freeze    = { name = { "빙결", "Frozen" },       kind = "cc", dur = 1.5 },
	stun      = { name = { "기절", "Stunned" },      kind = "cc", dur = 2 },
	ignite    = { name = { "발화", "Ignited" },      kind = "hitdot", dur = 4, power = 25, school = "fire" },
	bleed     = { name = { "출혈", "Bleeding" },     kind = "hitdot", dur = 6, power = 20, school = "phys" },
	shock     = { name = { "감전", "Shocked" },      kind = "vuln", dur = 6, power = 20 },
	curse     = { name = { "저주", "Cursed" },       kind = "vuln", dur = 10 },
	weaken    = { name = { "약화", "Weakened" },     kind = "weak", dur = 8 },
	poison    = { name = { "중독", "Poisoned" },     kind = "dot", dur = 6, school = "nature" },
	venom     = { name = { "맹독", "Envenomed" },    kind = "dot", dur = 8, school = "nature" },
	sting     = { name = { "독사 쐐기", "Stung" },   kind = "dot", dur = 6, school = "nature" },
	corrupt   = { name = { "부패", "Corrupted" },    kind = "dot", dur = 9, school = "shadow" },
	ua        = { name = { "불안정한 고통", "Afflicted" }, kind = "dot", dur = 8, school = "shadow" },
	pain      = { name = { "고통", "Pained" },       kind = "dot", dur = 9, school = "shadow" },
	plague    = { name = { "역병", "Plagued" },      kind = "dot", dur = 8, school = "shadow" },
	blackarrow = { name = { "검은 화살", "Black Arrow" }, kind = "dot", dur = 8, school = "shadow" },
	rend      = { name = { "분쇄", "Rent" },         kind = "dot", dur = 8, school = "phys" },
	rupture   = { name = { "파열", "Ruptured" },     kind = "dot", dur = 8, school = "phys" },
	rake      = { name = { "갈퀴 발톱", "Raked" },   kind = "dot", dur = 8, school = "phys" },
	moonfire  = { name = { "달빛섬광", "Moonfire" }, kind = "dot", dur = 8, school = "arcane" },
}

ns.SKILLS = {}

local function S(id, ko, en, icon, t)
	t.id = id
	t.name = { ko, en }
	t.icon = icon
	ns.SKILLS[id] = t
end

-- shorthand constructors keep the table below readable
local function count(n, t) t.act = "count" t.n = n return t end
local function cd(sec, t) t.act = "cd" t.cd = sec return t end
local function aura(t) t.act = "aura" return t end

------------------------------------------------------------------------ Warrior
-- Arms
S("mortal_strike", "죽음의 일격", "Mortal Strike", "Ability_Warrior_SavageBlow",
	count(3, { kind = "dmg", school = "phys", v = { 240, 22 }, targets = 1 }))
S("cleave", "회전베기", "Cleave", "Ability_Warrior_Cleave",
	count(4, { kind = "dmg", school = "phys", v = { 150, 14 }, targets = 3 }))
S("rend", "분쇄", "Rend", "Ability_Gouge",
	count(5, { kind = "dot", school = "phys", status = "rend", v = { 55, 7 }, dur = 8, targets = 1 }))
S("battle_shout", "전투의 외침", "Battle Shout", "Ability_Warrior_WarCry",
	aura({ kind = "aura", mods = { { "atkPct", 5, 1.2 } } }))
S("execute", "마무리 일격", "Execute", "INV_Sword_48",
	cd(8, { kind = "dmg", school = "phys", v = { 300, 30 }, targets = 1, exec = { 30, 2 } }))
S("bladestorm", "칼날폭풍", "Bladestorm", "Ability_Whirlwind",
	cd(30, { kind = "field", school = "phys", v = { 80, 9 }, tick = 0.5, dur = 4, targets = 99 }))
-- Fury
S("bloodthirst", "피의 갈증", "Bloodthirst", "Spell_Nature_BloodLust",
	count(3, { kind = "dmg", school = "phys", v = { 200, 18 }, targets = 1, selfHeal = { 3, 0.4 } }))
S("whirlwind", "소용돌이", "Whirlwind", "Ability_Whirlwind",
	cd(6, { kind = "dmg", school = "phys", v = { 120, 12 }, targets = 5 }))
S("raging_blow", "분노의 강타", "Raging Blow", "Ability_Warrior_DecisiveStrike",
	count(4, { kind = "dmg", school = "phys", v = { 280, 26 }, targets = 1 }))
S("recklessness", "무모한 희생", "Recklessness", "Ability_CriticalStrike",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "crit", 30, 3 }, { "aspdMult", 20, 2 } } }))
S("rampage", "광란", "Rampage", "Ability_Warrior_InnerRage",
	cd(20, { kind = "dmg", school = "phys", v = { 130, 13 }, targets = 1, hits = 4 }))
-- Protection
S("shield_slam", "방패 밀쳐내기", "Shield Slam", "INV_Shield_05",
	count(4, { kind = "dmg", school = "phys", v = { 220, 20 }, targets = 1, status = { "stun", 0.3 } }))
S("thunder_clap", "천둥벼락", "Thunder Clap", "Spell_Nature_ThunderClap",
	cd(9, { kind = "dmg", school = "phys", v = { 110, 12 }, targets = 5, status = { "chill", 1 } }))
S("revenge", "복수", "Revenge", "Ability_Warrior_Revenge",
	count(3, { kind = "dmg", school = "phys", v = { 160, 15 }, targets = 3 }))
S("commanding_shout", "지휘의 외침", "Commanding Shout", "Ability_Warrior_BattleShout",
	aura({ kind = "aura", mods = { { "hpPct", 6, 1.5 } } }))
S("shield_wall", "방패의 벽", "Shield Wall", "Ability_Warrior_ShieldWall",
	cd(35, { kind = "buff", target = "self", dur = 8, mods = { { "dr", 35, 3 } }, when = { self = 0.6 } }))
S("last_stand", "최후의 저항", "Last Stand", "Spell_Holy_AshesToAshes",
	cd(45, { kind = "heal", target = "self", v = { 30, 4 }, when = { self = 0.4 } }))

------------------------------------------------------------------------ Paladin
-- Holy
S("holy_light", "성스러운 빛", "Holy Light", "Spell_Holy_HolyBolt",
	cd(6, { kind = "heal", target = "lowest", v = { 26, 3.5 }, when = { ally = 0.75 } }))
S("devotion_aura", "헌신의 오라", "Devotion Aura", "Spell_Holy_DevotionAura",
	aura({ kind = "aura", mods = { { "armorPct", 12, 3 } } }))
S("judgement", "심판", "Judgement", "Spell_Holy_RighteousFury",
	count(4, { kind = "dmg", school = "holy", v = { 240, 20 }, targets = 1, status = { "stun", 0.2 } }))
S("blessing_of_might", "힘의 축복", "Blessing of Might", "Spell_Holy_FistOfJustice",
	aura({ kind = "aura", mods = { { "atkPct", 6, 1.5 } } }))
S("lay_on_hands", "신의 축복", "Lay on Hands", "Spell_Holy_LayOnHands",
	{ act = "cd", cd = 60, cdPer = -5, kind = "heal", target = "lowest", v = { 100, 0 }, when = { ally = 0.3 } })
S("divine_protection", "신의 가호", "Divine Protection", "Spell_Holy_DivineIntervention",
	cd(50, { kind = "shield", target = "all", v = { 20, 3 }, dur = 6, when = { ally = 0.5 } }))
-- Protection
S("shield_of_righteous", "정의의 방패", "Shield of the Righteous", "Spell_Holy_BlessingOfProtection",
	count(3, { kind = "dmg", school = "holy", v = { 200, 18 }, targets = 1 }))
S("avengers_shield", "응징의 방패", "Avenger's Shield", "INV_Shield_06",
	cd(8, { kind = "dmg", school = "holy", v = { 140, 14 }, targets = 3, status = { "stun", 0.25 } }))
S("consecration", "신성화", "Consecration", "Spell_Holy_InnerFire",
	cd(12, { kind = "field", school = "holy", v = { 32, 4 }, tick = 0.5, dur = 6, targets = 99 }))
S("ardent_defender", "헌신적인 수호자", "Ardent Defender", "Spell_Holy_SealOfProtection",
	cd(40, { kind = "buff", target = "self", dur = 8, mods = { { "dr", 32, 3 } }, when = { self = 0.55 } }))
S("word_of_glory", "영광의 서약", "Word of Glory", "Spell_Holy_FlashHeal",
	cd(22, { kind = "heal", target = "self", v = { 24, 3 }, when = { self = 0.55 } }))
-- Retribution
S("crusader_strike", "성전사의 일격", "Crusader Strike", "Spell_Holy_HolySmite",
	count(3, { kind = "dmg", school = "holy", v = { 220, 20 }, targets = 1 }))
S("divine_storm", "천상의 폭풍", "Divine Storm", "Spell_Holy_SealOfMight",
	cd(7, { kind = "dmg", school = "holy", v = { 135, 13 }, targets = 5 }))
S("hammer_of_wrath", "천벌의 망치", "Hammer of Wrath", "Ability_ThunderClap",
	cd(9, { kind = "dmg", school = "holy", v = { 320, 32 }, targets = 1, exec = { 30, 2 } }))
S("avenging_wrath", "응징의 격노", "Avenging Wrath", "Spell_Holy_SealOfFury",
	cd(45, { kind = "buff", target = "self", dur = 12, mods = { { "atkMult", 25, 3 } } }))

------------------------------------------------------------------------ Hunter
-- Beast Mastery
S("kill_command", "살상 명령", "Kill Command", "Ability_Hunter_BeastCall",
	count(3, { kind = "dmg", school = "phys", v = { 220, 20 }, targets = 1 }))
S("hunters_pet", "야수 동료", "Animal Companion", "Ability_Hunter_Pet_Wolf",
	aura({ kind = "pet", school = "phys", v = { 75, 9 }, tick = 1.5 }))
S("pack_leader", "야수의 상", "Aspect of the Pack", "Ability_Hunter_BeastTaming",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("bestial_wrath", "야수의 격노", "Bestial Wrath", "Ability_Druid_FerociousBite",
	cd(40, { kind = "field", school = "phys", v = { 110, 15 }, tick = 1, dur = 12, targets = 1 }))
S("stampede", "쇄도", "Stampede", "Ability_Hunter_Pet_Boar",
	cd(45, { kind = "field", school = "phys", v = { 100, 12 }, tick = 1, dur = 10, targets = 3 }))
-- Marksmanship
S("multi_shot", "일제 사격", "Multi-Shot", "Ability_UpwardArrow",
	count(4, { kind = "dmg", school = "phys", v = { 130, 12 }, targets = 3 }))
S("aimed_shot", "조준 사격", "Aimed Shot", "INV_Spear_07",
	cd(7, { kind = "dmg", school = "phys", v = { 320, 35 }, targets = 1, critBonus = 50 }))
S("arcane_shot", "신비한 사격", "Arcane Shot", "Ability_ImpalingBolt",
	count(3, { kind = "dmg", school = "arcane", v = { 190, 18 }, targets = 1 }))
S("trueshot_aura", "정조준 오라", "Trueshot Aura", "Ability_TrueShot",
	aura({ kind = "aura", mods = { { "atkPct", 5, 1.2 } } }))
S("rapid_fire", "속사", "Rapid Fire", "Ability_Hunter_RunningShot",
	cd(30, { kind = "buff", target = "self", dur = 8, mods = { { "aspdMult", 40, 6 } } }))
S("volley", "연발 사격", "Volley", "Ability_Marksmanship",
	cd(14, { kind = "field", school = "phys", v = { 45, 6 }, tick = 0.5, dur = 4, targets = 99 }))
-- Survival
S("explosive_shot", "폭발 사격", "Explosive Shot", "Spell_Fire_SelfDestruct",
	cd(5, { kind = "dmg", school = "fire", v = { 200, 20 }, targets = 3, status = { "ignite", 0.4 } }))
S("serpent_sting", "독사 쐐기", "Serpent Sting", "Ability_Hunter_Quickshot",
	count(5, { kind = "dot", school = "nature", status = "sting", v = { 45, 6 }, dur = 6, targets = 1 }))
S("explosive_trap", "폭발의 덫", "Explosive Trap", "INV_Misc_Bomb_05",
	cd(12, { kind = "field", school = "fire", v = { 48, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "ignite", 0.2 } }))
S("freezing_trap", "얼음의 덫", "Freezing Trap", "Spell_Frost_ChainsOfIce",
	cd(14, { kind = "dmg", school = "frost", v = { 80, 8 }, targets = 99, status = { "freeze", 0.7 } }))
S("black_arrow", "검은 화살", "Black Arrow", "Spell_Shadow_ShadowBolt",
	count(4, { kind = "dot", school = "shadow", status = "blackarrow", v = { 70, 8 }, dur = 8, targets = 1 }))
S("lock_and_load", "실탄 장전", "Lock and Load", "Ability_Hunter_SniperShot",
	cd(30, { kind = "buff", target = "self", dur = 10, mods = { { "multi", 40, 5 }, { "crit", 15, 2 } } }))

------------------------------------------------------------------------ Rogue
-- Assassination
S("mutilate", "절단", "Mutilate", "Ability_BackStab",
	count(3, { kind = "dmg", school = "phys", v = { 120, 11 }, targets = 1, hits = 2 }))
S("deadly_poison", "맹독", "Deadly Poison", "Ability_Poisons",
	count(4, { kind = "dot", school = "nature", status = "venom", v = { 55, 7 }, dur = 8, targets = 1 }))
S("envenom", "독살", "Envenom", "Ability_Creature_Poison_06",
	count(6, { kind = "dmg", school = "nature", v = { 480, 46 }, targets = 1 }))
S("rupture", "파열", "Rupture", "Ability_Rogue_Rupture",
	count(5, { kind = "dot", school = "phys", status = "rupture", v = { 60, 8 }, dur = 8, targets = 1 }))
S("vendetta", "원한", "Vendetta", "Spell_Shadow_ShadowWordDominate",
	cd(30, { kind = "debuff", status = "curse", v = { 20, 2 }, dur = 10, targets = 1 }))
S("cold_blood", "냉혈", "Cold Blood", "Spell_Ice_Lament",
	cd(20, { kind = "dmg", school = "phys", v = { 600, 60 }, targets = 1, critBonus = 100 }))
-- Outlaw
S("sinister_strike", "사악한 일격", "Sinister Strike", "Spell_Shadow_RitualOfSacrifice",
	count(3, { kind = "dmg", school = "phys", v = { 190, 18 }, targets = 1 }))
S("blade_flurry", "폭풍의 칼날", "Blade Flurry", "Ability_Warrior_PunishingBlow",
	cd(25, { kind = "buff", target = "self", dur = 10, mods = { { "multi", 60, 8 }, { "aspdMult", 15, 2 } } }))
S("eviscerate", "절개", "Eviscerate", "Ability_Rogue_Eviscerate",
	count(6, { kind = "dmg", school = "phys", v = { 520, 50 }, targets = 1 }))
S("evasion", "회피", "Evasion", "Spell_Shadow_ShadowWard",
	cd(30, { kind = "buff", target = "self", dur = 8, mods = { { "dodge", 40, 4 } }, when = { self = 0.7 } }))
S("killing_spree", "난도질", "Killing Spree", "Ability_Rogue_SliceDice",
	cd(25, { kind = "dmg", school = "phys", v = { 110, 11 }, targets = 1, hits = 5 }))
S("adrenaline_rush", "아드레날린 촉진", "Adrenaline Rush", "Spell_Shadow_ShadowWordDominate",
	cd(45, { kind = "buff", target = "self", dur = 10, mods = { { "aspdMult", 50, 8 } } }))
-- Subtlety
S("backstab", "기습", "Backstab", "Ability_BackStab",
	count(3, { kind = "dmg", school = "phys", v = { 230, 22 }, targets = 1, critBonus = 20 }))
S("hemorrhage", "과다출혈", "Hemorrhage", "Spell_Shadow_LifeDrain",
	count(4, { kind = "dmg", school = "phys", v = { 170, 16 }, targets = 1, status = { "bleed", 1 } }))
S("ambush", "매복", "Ambush", "Ability_Rogue_Ambush",
	cd(9, { kind = "dmg", school = "phys", v = { 380, 38 }, targets = 1, critBonus = 30 }))
S("shadow_dance", "어둠의 춤", "Shadow Dance", "Ability_Stealth",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "critdmg", 50, 6 }, { "aspdMult", 20, 2 } } }))
S("shadow_blades", "어둠의 칼날", "Shadow Blades", "Spell_Shadow_Curse",
	cd(40, { kind = "buff", target = "self", dur = 12, mods = { { "dmg_all", 25, 3 } } }))

------------------------------------------------------------------------ Priest
-- Discipline
S("penance", "회개", "Penance", "Spell_Holy_SearingLight",
	cd(5, { kind = "heal", target = "lowest", v = { 19, 2.6 }, when = { ally = 0.8 } }))
S("pw_shield", "신의 권능: 보호막", "Power Word: Shield", "Spell_Holy_PowerWordShield",
	cd(11, { kind = "shield", target = "lowest", v = { 18, 3 }, dur = 10, when = { ally = 0.9 } }))
S("smite", "성스러운 일격", "Smite", "Spell_Holy_HolySmite",
	count(3, { kind = "dmg", school = "holy", v = { 180, 17 }, targets = 1, atone = { 4, 0.5 } }))
S("fortitude", "신의 권능: 인내", "Power Word: Fortitude", "Spell_Holy_WordFortitude",
	aura({ kind = "aura", mods = { { "hpPct", 8, 2 } } }))
S("pain_suppression", "고통 억제", "Pain Suppression", "Spell_Holy_PowerInfusion",
	cd(30, { kind = "buff", target = "lowest", dur = 8, mods = { { "dr", 35, 3 } }, when = { ally = 0.45 } }))
S("pw_barrier", "신의 권능: 방벽", "Power Word: Barrier", "Spell_Holy_PrayerOfFortitude",
	cd(45, { kind = "buff", target = "party", dur = 8, mods = { { "dr", 18, 2 } }, when = { ally = 0.6 } }))
-- Holy
S("heal", "치유", "Heal", "Spell_Holy_Heal",
	cd(5, { kind = "heal", target = "lowest", v = { 22, 3 }, when = { ally = 0.8 } }))
S("renew", "소생", "Renew", "Spell_Holy_Renew",
	cd(7, { kind = "heal", target = "lowest", v = { 4.5, 0.6 }, hot = 6, when = { ally = 0.9 } }))
S("holy_nova", "신성한 폭발", "Holy Nova", "Spell_Holy_HolyNova",
	cd(10, { kind = "dmg", school = "holy", v = { 120, 12 }, targets = 99, healAll = { 6, 1 } }))
S("prayer_of_healing", "치유의 기원", "Prayer of Healing", "Spell_Holy_PrayerOfHealing02",
	cd(14, { kind = "heal", target = "all", v = { 14, 2 }, when = { ally = 0.7 } }))
S("resurrection", "부활", "Resurrection", "Spell_Holy_Resurrection",
	cd(45, { kind = "revive", v = { 30, 5 } }))
-- Shadow
S("mind_blast", "정신 분열", "Mind Blast", "Spell_Shadow_UnholyFrenzy",
	cd(5, { kind = "dmg", school = "shadow", v = { 240, 24 }, targets = 1 }))
S("sw_pain", "어둠의 권능: 고통", "Shadow Word: Pain", "Spell_Shadow_ShadowWordPain",
	count(4, { kind = "dot", school = "shadow", status = "pain", v = { 45, 6 }, dur = 9, targets = 2 }))
S("mind_flay", "정신의 채찍", "Mind Flay", "Spell_Shadow_SiphonMana",
	count(2, { kind = "dmg", school = "shadow", v = { 150, 14 }, targets = 1, status = { "chill", 0.5 } }))
S("vampiric_embrace", "흡혈의 선물", "Vampiric Embrace", "Spell_Shadow_UnsummonBuilding",
	aura({ kind = "aura", mods = { { "leech", 1.5, 0.4 } } }))
S("devouring_plague", "파멸의 역병", "Devouring Plague", "Spell_Shadow_BlackPlague",
	cd(10, { kind = "dot", school = "shadow", status = "plague", v = { 90, 10 }, dur = 8, targets = 1 }))
S("shadowfiend", "어둠의 마귀", "Shadowfiend", "Spell_Shadow_SummonVoidWalker",
	cd(40, { kind = "field", school = "shadow", v = { 110, 14 }, tick = 1, dur = 12, targets = 1 }))

------------------------------------------------------------------------ Shaman
-- Elemental
S("lightning_bolt", "번개 화살", "Lightning Bolt", "Spell_Nature_Lightning",
	count(2, { kind = "dmg", school = "nature", v = { 210, 20 }, targets = 1, status = { "shock", 0.25 } }))
S("chain_lightning", "연쇄 번개", "Chain Lightning", "Spell_Nature_ChainLightning",
	cd(7, { kind = "dmg", school = "nature", v = { 170, 17 }, targets = 4, status = { "shock", 0.3 } }))
S("earth_shock", "대지 충격", "Earth Shock", "Spell_Nature_EarthShock",
	cd(8, { kind = "dmg", school = "nature", v = { 240, 24 }, targets = 1, status = { "stun", 0.4 } }))
S("totem_of_wrath", "격노의 토템", "Totem of Wrath", "Spell_Fire_SealOfFire",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("lava_burst", "용암 폭발", "Lava Burst", "Spell_Fire_Volcano",
	cd(8, { kind = "dmg", school = "fire", v = { 330, 33 }, targets = 1, critBonus = 40 }))
S("bloodlust", "피의 욕망", "Bloodlust", "Spell_Nature_Bloodlust",
	cd(60, { kind = "buff", target = "party", dur = 10, mods = { { "aspdMult", 30, 4 }, { "atkPct", 10, 1 } } }))
-- Enhancement
S("stormstrike", "폭풍의 일격", "Stormstrike", "Spell_Holy_SealOfMight",
	count(3, { kind = "dmg", school = "nature", v = { 120, 11 }, targets = 1, hits = 2 }))
S("lava_lash", "용암 채찍", "Lava Lash", "Spell_Fire_FlameTounge",
	count(4, { kind = "dmg", school = "fire", v = { 250, 24 }, targets = 1, status = { "ignite", 0.4 } }))
S("windfury_totem", "질풍의 토템", "Windfury Totem", "Spell_Nature_Windfury",
	aura({ kind = "aura", mods = { { "aspd", 6, 1.5 } } }))
S("feral_spirit", "야수 정령", "Feral Spirit", "Ability_Mount_WhiteDireWolf",
	cd(30, { kind = "field", school = "phys", v = { 90, 11 }, tick = 1, dur = 12, targets = 2 }))
S("fire_nova", "불꽃 회오리", "Fire Nova", "Spell_Fire_SealOfFire",
	cd(10, { kind = "dmg", school = "fire", v = { 170, 17 }, targets = 99 }))
-- Restoration
S("healing_wave", "치유의 물결", "Healing Wave", "Spell_Nature_MagicImmunity",
	cd(5, { kind = "heal", target = "lowest", v = { 22, 3 }, when = { ally = 0.8 } }))
S("chain_heal", "연쇄 치유", "Chain Heal", "Spell_Nature_HealingWaveGreater",
	cd(9, { kind = "heal", target = "lowest", targets = 3, v = { 12, 1.6 }, when = { ally = 0.8 } }))
S("earth_shield", "대지의 보호막", "Earth Shield", "Spell_Nature_StoneSkinTotem",
	cd(14, { kind = "shield", target = "tank", v = { 20, 3 }, dur = 12 }))
S("healing_stream", "치유의 토템", "Healing Stream Totem", "INV_Spear_04",
	aura({ kind = "aura", mods = { { "regenPct", 0.35, 0.09 } } }))
S("riptide", "성난 해일", "Riptide", "Spell_Frost_SummonWaterElemental",
	cd(7, { kind = "heal", target = "lowest", v = { 3.5, 0.5 }, hot = 6, instant = { 9, 1.2 }, when = { ally = 0.85 } }))
S("ancestral_spirit", "고대의 영혼", "Ancestral Spirit", "Spell_Nature_Regenerate",
	cd(50, { kind = "revive", v = { 25, 5 } }))

------------------------------------------------------------------------ Mage
-- Arcane
S("arcane_blast", "비전 작렬", "Arcane Blast", "Spell_Nature_AbolishMagic",
	count(2, { kind = "dmg", school = "arcane", v = { 200, 19 }, targets = 1 }))
S("arcane_missiles", "신비한 화살", "Arcane Missiles", "Spell_Nature_StarFall",
	count(3, { kind = "dmg", school = "arcane", v = { 70, 8 }, targets = 1, hits = 3 }))
S("arcane_explosion", "신비한 폭발", "Arcane Explosion", "Spell_Nature_WispSplode",
	cd(7, { kind = "dmg", school = "arcane", v = { 130, 13 }, targets = 99 }))
S("arcane_intellect", "신비한 지능", "Arcane Intellect", "Spell_Holy_MagicalSentry",
	aura({ kind = "aura", mods = { { "cast", 6, 1.5 } } }))
S("arcane_power", "신비의 마법 강화", "Arcane Power", "Spell_Nature_Lightning",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "atkMult", 30, 3 } } }))
S("arcane_barrage", "비전 탄막", "Arcane Barrage", "Spell_Nature_EnchantArmor",
	cd(12, { kind = "dmg", school = "arcane", v = { 300, 30 }, targets = 3 }))
-- Fire
S("fireball", "화염구", "Fireball", "Spell_Fire_FlameBolt",
	cd(4, { kind = "dmg", school = "fire", v = { 220, 22 }, targets = 3, status = { "ignite", 0.4 } }))
S("scorch", "불태우기", "Scorch", "Spell_Fire_SoulBurn",
	count(2, { kind = "dmg", school = "fire", v = { 160, 15 }, targets = 1, status = { "ignite", 0.5 } }))
S("fire_blast", "화염 작렬", "Fire Blast", "Spell_Fire_Fireball",
	cd(6, { kind = "dmg", school = "fire", v = { 240, 24 }, targets = 1, critBonus = 30 }))
S("flamestrike", "불기둥", "Flamestrike", "Spell_Fire_SelfDestruct",
	cd(12, { kind = "dmg", school = "fire", v = { 340, 34 }, targets = 5, status = { "ignite", 0.5 } }))
S("combustion", "발화", "Combustion", "Spell_Fire_SealOfFire",
	cd(35, { kind = "buff", target = "self", dur = 10, mods = { { "crit", 40, 4 } } }))
S("pyroblast", "불덩이 작렬", "Pyroblast", "Spell_Fire_Fireball02",
	cd(18, { kind = "dmg", school = "fire", v = { 850, 85 }, targets = 1, status = { "ignite", 1 } }))
-- Frost
S("frostbolt", "얼음 화살", "Frostbolt", "Spell_Frost_FrostBolt02",
	count(2, { kind = "dmg", school = "frost", v = { 190, 18 }, targets = 1, status = { "chill", 1 } }))
S("frost_nova", "얼음 회오리", "Frost Nova", "Spell_Frost_FrostNova",
	cd(10, { kind = "dmg", school = "frost", v = { 100, 10 }, targets = 99, status = { "freeze", 0.6 } }))
S("ice_lance", "얼음창", "Ice Lance", "Spell_Frost_Glacier",
	count(3, { kind = "dmg", school = "frost", v = { 240, 23 }, targets = 1 }))
S("ice_barrier", "얼음 보호막", "Ice Barrier", "Spell_Ice_Lament",
	cd(20, { kind = "shield", target = "self", v = { 30, 4 }, dur = 10, when = { self = 0.9 } }))
S("blizzard", "눈보라", "Blizzard", "Spell_Frost_IceStorm",
	cd(14, { kind = "field", school = "frost", v = { 50, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "chill", 0.5 } }))
S("water_elemental", "물의 정령 소환", "Summon Water Elemental", "Spell_Frost_SummonWaterElemental",
	cd(40, { kind = "field", school = "frost", v = { 110, 14 }, tick = 1, dur = 15, targets = 1, status = { "chill", 0.3 } }))

------------------------------------------------------------------------ Warlock
-- Affliction
S("corruption", "부패", "Corruption", "Spell_Shadow_AbominationExplosion",
	cd(6, { kind = "dot", school = "shadow", status = "corrupt", v = { 45, 6 }, dur = 9, targets = 3 }))
S("unstable_affliction", "불안정한 고통", "Unstable Affliction", "Spell_Shadow_CurseOfSargeras",
	count(3, { kind = "dot", school = "shadow", status = "ua", v = { 80, 9 }, dur = 8, targets = 1 }))
S("drain_life", "생명력 흡수", "Drain Life", "Spell_Shadow_LifeDrain02",
	cd(9, { kind = "dmg", school = "shadow", v = { 250, 25 }, targets = 1, drain = 100 }))
S("curse_of_elements", "원소의 저주", "Curse of the Elements", "Spell_Shadow_ChillTouch",
	cd(20, { kind = "debuff", status = "curse", v = { 12, 1.6 }, dur = 10, targets = 99 }))
S("haunt", "유령 출몰", "Haunt", "Spell_Shadow_Haunting",
	cd(10, { kind = "dmg", school = "shadow", v = { 340, 34 }, targets = 1 }))
S("seed_of_corruption", "부패의 씨앗", "Seed of Corruption", "Spell_Shadow_ScourgeBuild",
	cd(14, { kind = "dmg", school = "shadow", v = { 230, 23 }, targets = 99 }))
-- Demonology
S("shadow_bolt", "어둠의 화살", "Shadow Bolt", "Spell_Shadow_ShadowBolt",
	count(2, { kind = "dmg", school = "shadow", v = { 220, 21 }, targets = 1 }))
S("felguard", "지옥수호병", "Felguard", "Spell_Shadow_SummonFelHunter",
	aura({ kind = "pet", school = "phys", v = { 80, 10 }, tick = 1.5 }))
S("soul_link", "영혼의 고리", "Soul Link", "Spell_Shadow_GatherShadows",
	aura({ kind = "aura", self = true, mods = { { "dr", 8, 1.5 }, { "hpPct", 6, 1.5 } } }))
S("hand_of_guldan", "굴단의 손", "Hand of Gul'dan", "Spell_Shadow_DeathPact",
	cd(9, { kind = "dmg", school = "shadow", v = { 190, 19 }, targets = 4, status = { "stun", 0.2 } }))
S("metamorphosis", "탈태", "Metamorphosis", "Spell_Shadow_PsychicScream",
	cd(45, { kind = "buff", target = "self", dur = 12, mods = { { "atkMult", 30, 3 }, { "dr", 20, 0 } } }))
S("summon_infernal", "지옥불정령 소환", "Summon Infernal", "Spell_Shadow_SummonInfernal",
	cd(40, { kind = "field", school = "fire", v = { 65, 8 }, tick = 1, dur = 12, targets = 99, status = { "ignite", 0.15 } }))
-- Destruction
S("immolate", "제물", "Immolate", "Spell_Fire_Immolation",
	count(3, { kind = "dmg", school = "fire", v = { 150, 14 }, targets = 1, status = { "ignite", 1 } }))
S("incinerate", "소각", "Incinerate", "Spell_Fire_FlameShock",
	count(2, { kind = "dmg", school = "fire", v = { 210, 20 }, targets = 1 }))
S("rain_of_fire", "불의 비", "Rain of Fire", "Spell_Shadow_RainOfFire",
	cd(13, { kind = "field", school = "fire", v = { 45, 5 }, tick = 0.5, dur = 4, targets = 99, status = { "ignite", 0.15 } }))
S("conflagrate", "점화", "Conflagrate", "Spell_Fire_Fireball",
	cd(8, { kind = "dmg", school = "fire", v = { 310, 31 }, targets = 1, critBonus = 25 }))
S("shadowburn", "어둠의 연소", "Shadowburn", "Spell_Shadow_ScourgeBuild",
	cd(9, { kind = "dmg", school = "shadow", v = { 300, 30 }, targets = 1, exec = { 30, 2 } }))
S("chaos_bolt", "혼돈의 화살", "Chaos Bolt", "Spell_Fire_Fireball02",
	cd(14, { kind = "dmg", school = "fire", v = { 420, 42 }, targets = 1, critBonus = 100 }))

------------------------------------------------------------------------ Druid
-- Balance
S("wrath", "천벌", "Wrath", "Spell_Nature_AbolishMagic",
	count(2, { kind = "dmg", school = "nature", v = { 200, 19 }, targets = 1 }))
S("moonfire", "달빛섬광", "Moonfire", "Spell_Nature_StarFall",
	count(4, { kind = "dot", school = "arcane", status = "moonfire", v = { 50, 6 }, dur = 8, targets = 2 }))
S("starfire", "별빛 화살", "Starfire", "Spell_Arcane_StarFire",
	cd(6, { kind = "dmg", school = "arcane", v = { 290, 29 }, targets = 1 }))
S("moonkin_aura", "달빛야수 오라", "Moonkin Aura", "Spell_Nature_ForceOfNature",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("hurricane", "허리케인", "Hurricane", "Spell_Nature_Cyclone",
	cd(14, { kind = "field", school = "nature", v = { 50, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "chill", 0.5 } }))
S("starfall", "별똥별", "Starfall", "Spell_Arcane_StarFire",
	cd(25, { kind = "field", school = "arcane", v = { 85, 10 }, tick = 0.5, dur = 6, targets = 3 }))
-- Feral
S("shred", "칼날 발톱", "Shred", "Spell_Shadow_VampiricAura",
	count(3, { kind = "dmg", school = "phys", v = { 230, 22 }, targets = 1 }))
S("rake", "갈퀴 발톱", "Rake", "Ability_Druid_Disembowel",
	count(4, { kind = "dot", school = "phys", status = "rake", v = { 60, 7 }, dur = 8, targets = 1 }))
S("ferocious_bite", "흉포한 이빨", "Ferocious Bite", "Ability_Druid_FerociousBite",
	count(6, { kind = "dmg", school = "phys", v = { 520, 50 }, targets = 1 }))
S("leader_of_pack", "무리의 우두머리", "Leader of the Pack", "Spell_Nature_UnyeildingStamina",
	aura({ kind = "aura", mods = { { "crit", 3, 0.7 } } }))
S("tigers_fury", "호랑이의 분노", "Tiger's Fury", "Ability_Mount_JungleTiger",
	cd(30, { kind = "buff", target = "self", dur = 8, mods = { { "atkMult", 25, 3 } } }))
S("berserk", "광폭화", "Berserk", "Ability_Druid_Enrage",
	cd(45, { kind = "buff", target = "self", dur = 10, mods = { { "aspdMult", 40, 6 } } }))
-- Guardian
S("maul", "후려갈기기", "Maul", "Ability_Druid_Maul",
	count(3, { kind = "dmg", school = "phys", v = { 200, 18 }, targets = 1 }))
S("swipe", "휘둘러치기", "Swipe", "INV_Misc_MonsterClaw_03",
	cd(6, { kind = "dmg", school = "phys", v = { 90, 10 }, targets = 4, status = { "bleed", 0.5 } }))
S("demo_roar", "위협의 포효", "Demoralizing Roar", "Ability_Druid_DemoralizingRoar",
	cd(18, { kind = "debuff", status = "weaken", v = { 20, 2 }, dur = 8, targets = 99 }))
S("thorns", "가시", "Thorns", "Spell_Nature_Thorns",
	aura({ kind = "aura", mods = { { "thorns", 60, 15 } } }))
S("frenzied_regen", "광포한 재생력", "Frenzied Regeneration", "Ability_BullRush",
	cd(30, { kind = "heal", target = "self", v = { 4, 0.5 }, hot = 8, when = { self = 0.6 } }))
S("barkskin", "나무 껍질", "Barkskin", "Spell_Nature_StoneClawTotem",
	cd(40, { kind = "buff", target = "party", dur = 8, mods = { { "dr", 15, 2 } }, when = { ally = 0.6 } }))
-- Restoration
S("rejuvenation", "회복", "Rejuvenation", "Spell_Nature_Rejuvenation",
	cd(5, { kind = "heal", target = "lowest", v = { 5, 0.7 }, hot = 5, when = { ally = 0.9 } }))
S("healing_touch", "치유의 손길", "Healing Touch", "Spell_Nature_HealingTouch",
	cd(8, { kind = "heal", target = "lowest", v = { 30, 4 }, when = { ally = 0.7 } }))
S("wild_growth", "급속 성장", "Wild Growth", "Spell_Nature_ResistNature",
	cd(12, { kind = "heal", target = "all", v = { 2.4, 0.35 }, hot = 6, when = { ally = 0.8 } }))
S("mark_of_wild", "야생의 징표", "Mark of the Wild", "Spell_Nature_Regeneration",
	aura({ kind = "aura", mods = { { "hpPct", 5, 1.2 }, { "allres", 4, 1 } } }))
S("tranquility", "평온", "Tranquility", "Spell_Nature_Tranquility",
	cd(40, { kind = "heal", target = "all", v = { 25, 3.5 }, when = { ally = 0.5 } }))
S("rebirth", "환생", "Rebirth", "Spell_Nature_Reincarnation",
	cd(50, { kind = "revive", v = { 30, 5 } }))

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

local function targetText(n, ko)
	if not n or n <= 1 then return ko and "대상" or "the target" end
	if n >= 99 then return ko and "모든 적" or "all enemies" end
	return ko and ("적 " .. n .. "명") or (n .. " enemies")
end

local function modsText(id, lvl)
	local parts = {}
	for _, m in ipairs(ns.SkillMods(id, lvl)) do
		if m[1] == "thorns" then
			parts[#parts + 1] = string.format(ns.T("근접 공격자에게 공격력의 %s%% 자연 피해 반사", "reflects %s%% of attack as nature damage to melee attackers"), num(m[2]))
		else
			parts[#parts + 1] = ns.Stats.ModText(m[1], m[2])
		end
	end
	return table.concat(parts, ", ")
end

local function whenText(sk, ko)
	local w = sk.when
	if not w then return "" end
	if w.self then
		return ko and string.format("자신의 생명력이 %d%% 아래일 때: ", w.self * 100) or string.format("Below %d%% health: ", w.self * 100)
	end
	if w.ally and sk.kind ~= "heal" and sk.kind ~= "shield" then
		return ko and string.format("아군 생명력이 %d%% 아래로 떨어지면: ", w.ally * 100) or string.format("When an ally drops below %d%% health: ", w.ally * 100)
	end
	return ""
end

function ns.SkillDesc(id, lvl)
	local sk = ns.SKILLS[id]
	local ko = ns.lang == "ko"
	lvl = math.max(1, lvl or 1)
	local v = sk.v and at(sk.v, lvl) or 0
	local school = sk.school and ns.N(ns.SCHOOL[sk.school].name) or ""
	local kind = sk.kind
	local s

	if kind == "dmg" then
		local t = targetText(sk.targets, ko)
		if ko then
			s = string.format("%s에게 %s%% %s 피해를 %s줍니다.", t, num(v), school, (sk.hits or 1) > 1 and (sk.hits .. "번 ") or "")
		else
			s = string.format("Deals %s%% %s damage to %s%s.", num(v), school, t, (sk.hits or 1) > 1 and (" " .. sk.hits .. " times") or "")
		end
		if sk.status then
			local st = ns.N(ns.STATUS[sk.status[1]].name)
			if sk.status[2] >= 1 then
				s = s .. (ko and (" " .. st .. " 상태로 만듭니다.") or (" Applies " .. st .. "."))
			else
				s = s .. string.format(ko and " %d%% 확률로 %s." or " %d%% chance of %s.", sk.status[2] * 100, st)
			end
		end
		if sk.critBonus then s = s .. string.format(ko and " 치명타 확률 +%d%%." or " +%d%% crit chance.", sk.critBonus) end
		if sk.exec then
			if ko then
				s = s .. string.format(" 생명력 %d%% 이하의 적에게는 %d배.", sk.exec[1], sk.exec[2])
			else
				s = s .. string.format(" %dx against enemies below %d%% health.", sk.exec[2], sk.exec[1])
			end
		end
		if sk.drain then s = s .. (ko and " 준 피해만큼 자신의 생명력을 회복합니다." or " Heals you for the damage dealt.") end
		if sk.selfHeal then s = s .. string.format(ko and " 자신의 최대 생명력 %s%% 회복." or " Restores %s%% of your maximum health.", num(at(sk.selfHeal, lvl))) end
		if sk.healAll then s = s .. string.format(ko and " 파티 전원이 최대 생명력의 %s%% 회복." or " Heals the party for %s%% of maximum health.", num(at(sk.healAll, lvl))) end
		if sk.atone then s = s .. string.format(ko and " 가장 다친 아군이 최대 생명력의 %s%% 회복." or " Heals the most injured ally for %s%% of maximum health.", num(at(sk.atone, lvl))) end
	elseif kind == "dot" then
		local t = targetText(sk.targets, ko)
		if ko then
			s = string.format("%s에게 %s초 동안 매초 %s%% %s 피해를 줍니다.", t, num(sk.dur), num(v), school)
		else
			s = string.format("Deals %s%% %s damage per sec to %s for %s sec.", num(v), school, t, num(sk.dur))
		end
	elseif kind == "field" then
		local t = targetText(sk.targets, ko)
		if ko then
			s = string.format("%s초 동안 %s초마다 %s에게 %s%% %s 피해를 줍니다.", num(sk.dur), num(sk.tick), t, num(v), school)
		else
			s = string.format("For %s sec, deals %s%% %s damage to %s every %s sec.", num(sk.dur), num(v), school, t, num(sk.tick))
		end
		if sk.status then
			s = s .. string.format(ko and " %d%% 확률로 %s." or " %d%% chance of %s.", sk.status[2] * 100, ns.N(ns.STATUS[sk.status[1]].name))
		end
	elseif kind == "pet" then
		if ko then
			s = string.format("늘 곁에서 싸우는 소환수가 %s초마다 가장 가까운 적에게 %s%% %s 피해를 줍니다.", num(sk.tick), num(v), school)
		else
			s = string.format("A permanent companion deals %s%% %s damage to the nearest enemy every %s sec.", num(v), school, num(sk.tick))
		end
	elseif kind == "heal" then
		local who
		if sk.target == "self" then
			who = ko and "자신" or "yourself"
		elseif sk.target == "all" then
			who = ko and "파티 전원" or "the whole party"
		elseif (sk.targets or 1) > 1 then
			who = ko and ("가장 다친 아군 " .. sk.targets .. "명") or ("the " .. sk.targets .. " most injured allies")
		else
			who = ko and "가장 다친 아군" or "the most injured ally"
		end
		if sk.hot then
			if ko then
				s = string.format("%s: %s초 동안 매초 최대 생명력의 %s%% 회복.", who, num(sk.hot), num(v))
			else
				s = string.format("Heals %s for %s%% of maximum health per sec for %s sec.", who, num(v), num(sk.hot))
			end
			if sk.instant then
				s = s .. string.format(ko and " 즉시 %s%% 추가 회복." or " Also heals %s%% instantly.", num(at(sk.instant, lvl)))
			end
		else
			if ko then
				s = string.format("%s: 최대 생명력의 %s%% 회복.", who, num(v))
			else
				s = string.format("Heals %s for %s%% of maximum health.", who, num(v))
			end
		end
	elseif kind == "shield" then
		local who
		if sk.target == "self" then who = ko and "자신" or "yourself"
		elseif sk.target == "all" then who = ko and "파티 전원" or "the whole party"
		elseif sk.target == "tank" then who = ko and "탱커" or "the tank"
		else who = ko and "가장 다친 아군" or "the most injured ally" end
		if ko then
			s = string.format("%s에게 최대 생명력의 %s%%를 흡수하는 보호막을 %s초 동안 씌웁니다.", who, num(v), num(sk.dur))
		else
			s = string.format("Shields %s for %s%% of maximum health for %s sec.", who, num(v), num(sk.dur))
		end
	elseif kind == "buff" then
		local who
		if sk.target == "party" then who = ko and "파티 전원" or "the whole party"
		elseif sk.target == "lowest" then who = ko and "가장 다친 아군" or "the most injured ally"
		else who = ko and "자신" or "yourself" end
		if ko then
			s = string.format("%s초 동안 %s: %s", num(sk.dur), who, modsText(id, lvl))
		else
			s = string.format("For %s sec, %s: %s", num(sk.dur), who, modsText(id, lvl))
		end
	elseif kind == "debuff" then
		local t = targetText(sk.targets, ko)
		if sk.status == "weaken" then
			s = string.format(ko and "%s초 동안 %s이(가) 주는 피해가 %s%% 감소합니다." or "For %s sec, %s deal %s%% less damage.", num(sk.dur), t, num(v))
		else
			s = string.format(ko and "%s초 동안 %s이(가) 받는 피해가 %s%% 증가합니다." or "For %s sec, %s take %s%% more damage.", num(sk.dur), t, num(v))
		end
	elseif kind == "aura" then
		local who = sk.self and (ko and "자신" or "you") or (ko and "파티 전원" or "the whole party")
		s = string.format(ko and "장착하는 동안 %s: %s" or "While equipped, %s: %s", who, modsText(id, lvl))
	elseif kind == "revive" then
		s = string.format(ko and "쓰러진 아군을 최대 생명력의 %s%%로 되살립니다." or "Revives a fallen ally at %s%% health.", num(v))
	else
		s = ""
	end
	return whenText(sk, ko) .. s
end

function ns.SkillActText(id, lvl)
	local sk = ns.SKILLS[id]
	if sk.act == "aura" then
		return ns.T("지속 효과", "Always active")
	elseif sk.act == "count" then
		return string.format(ns.T("기본 공격 %d회마다 발동", "Every %d basic attacks"), sk.n)
	end
	return string.format(ns.T("재사용 대기시간 %s초", "%s sec cooldown"), ns.U.num(ns.SkillCooldown(id, lvl), 1))
end

-- One-word role of a skill, used for badges in the UI.
function ns.SkillTag(id)
	local k = ns.SKILLS[id].kind
	if k == "heal" or k == "revive" then return ns.T("치유", "Heal") end
	if k == "shield" then return ns.T("보호", "Shield") end
	if k == "aura" then return ns.T("오라", "Aura") end
	if k == "pet" then return ns.T("소환수", "Pet") end
	if k == "buff" then return ns.T("강화", "Buff") end
	if k == "debuff" then return ns.T("약화", "Debuff") end
	if (ns.SKILLS[id].targets or 1) > 1 or k == "field" then return ns.T("광역", "Area") end
	return ns.T("단일", "Single")
end
