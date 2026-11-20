-- Monsters. Stats are level-1 values; Stages.lua scales them by stage level.
-- range: nil = melee, number = ranged. type feeds the companion kill counters.
local _, ns = ...

ns.MTYPE = {
	beast      = { "야수", "Beast" },
	humanoid   = { "인간형", "Humanoid" },
	undead     = { "언데드", "Undead" },
	elemental  = { "정령", "Elemental" },
	demon      = { "악마", "Demon" },
	dragonkin  = { "용족", "Dragonkin" },
	mechanical = { "기계", "Mechanical" },
	giant      = { "거인", "Giant" },
}

ns.MONSTERS = {}

local function M(id, ko, en, icon, mtype, hp, atk, aspd, o)
	o = o or {}
	o.id = id
	o.name = { ko, en }
	o.icon = icon
	o.type = mtype
	o.hp = hp
	o.atk = atk
	o.aspd = aspd
	o.school = o.school or "phys"
	o.move = o.move or 170
	ns.MONSTERS[id] = o
end

-- Act 1 - Eastern Kingdoms
M("kobold", "코볼트 일꾼", "Kobold Worker", "INV_Misc_Head_Kobold_01", "humanoid", 28, 4, 0.70)
M("wolf", "숲늑대", "Forest Wolf", "Ability_Hunter_Pet_Wolf", "beast", 24, 5, 0.90, { move = 220 })
M("gnoll", "리버포 놀", "Riverpaw Gnoll", "INV_Misc_Head_Gnoll_01", "humanoid", 36, 5, 0.70)
M("murloc", "멀록 약탈자", "Murloc Raider", "INV_Misc_Head_Murloc_01", "humanoid", 30, 5, 0.80)
M("defias", "데피아즈단 악당", "Defias Thug", "INV_Misc_Head_Human_01", "humanoid", 38, 6, 0.80)
M("golem", "허수아비 골렘", "Harvest Golem", "INV_Gizmo_02", "mechanical", 55, 6, 0.60, { move = 130 })
M("defias_mage", "데피아즈단 마법사", "Defias Pillager", "INV_Misc_Head_Human_02", "humanoid", 26, 8, 0.50, { range = 420, school = "fire" })
M("goblin", "고블린 기술자", "Goblin Engineer", "INV_Misc_Bomb_01", "humanoid", 32, 7, 0.60, { range = 380, school = "fire" })
M("orc", "검은바위 오크", "Blackrock Grunt", "INV_Misc_Head_Orc_01", "humanoid", 50, 7, 0.70)
M("worgen", "밤그림자 늑대인간", "Nightbane Worgen", "INV_Misc_MonsterFang_01", "humanoid", 48, 8, 0.90, { move = 210 })
M("skeleton", "해골 전사", "Skeletal Warrior", "Spell_Shadow_RaiseDead", "undead", 40, 7, 0.70)
M("spider", "독거미", "Venom Web Spider", "Ability_Hunter_Pet_Spider", "beast", 34, 6, 0.80, { status = { "poison", 0.3 } })
M("raptor", "랩터", "Stranglethorn Raptor", "Ability_Hunter_Pet_Raptor", "beast", 44, 8, 0.90, { move = 220 })
M("troll", "정글 트롤", "Bloodscalp Axe Thrower", "INV_Misc_Head_Troll_01", "humanoid", 36, 8, 0.70, { range = 400 })
M("tiger", "호랑이", "Stranglethorn Tiger", "INV_Misc_Head_Tiger_01", "beast", 42, 9, 1.00, { move = 230, status = { "bleed", 0.2 } })
M("croc", "악어", "Mottled Crocolisk", "Ability_Hunter_Pet_Crocolisk", "beast", 70, 7, 0.60, { move = 140 })
M("darkiron", "검은무쇠 소총병", "Dark Iron Rifleman", "INV_Misc_Head_Dwarf_01", "humanoid", 40, 9, 0.60, { range = 460 })
M("ghoul", "구울", "Ravenous Ghoul", "INV_Misc_Head_Undead_01", "undead", 60, 8, 0.80)
M("acolyte", "스컬지 수행사제", "Scourge Acolyte", "Spell_Shadow_ShadowBolt", "humanoid", 34, 10, 0.50, { range = 430, school = "shadow" })
M("plaguebat", "역병박쥐", "Plaguebat", "Ability_Hunter_Pet_Bat", "beast", 28, 7, 1.10, { move = 240, status = { "poison", 0.25 } })
M("fire_elemental", "불의 정령", "Fire Elemental", "Spell_Fire_Elemental_Totem", "elemental", 48, 10, 0.60,
	{ school = "fire", res = { fire = 60, frost = -30 }, status = { "ignite", 0.25 } })
M("core_hound", "심장부 사냥개", "Core Hound", "Spell_Fire_Immolation", "beast", 80, 9, 0.70, { school = "fire", res = { fire = 40 } })
M("darkiron_guard", "검은무쇠 병사", "Anvilrage Guard", "INV_Misc_Head_Dwarf_02", "humanoid", 65, 9, 0.70)

-- Act 2 - Kalimdor
M("scorpid", "전갈", "Clattering Scorpid", "Ability_Hunter_Pet_Scorpid", "beast", 36, 6, 0.80, { status = { "poison", 0.3 } })
M("boar", "멧돼지", "Dire Mottled Boar", "Ability_Hunter_Pet_Boar", "beast", 44, 6, 0.80, { move = 210 })
M("quilboar", "가시멧돼지 사냥꾼", "Razormane Hunter", "INV_Misc_Head_Quillboar_01", "humanoid", 38, 7, 0.70, { range = 400 })
M("centaur", "켄타우로스 약탈자", "Kolkar Marauder", "INV_Misc_Head_Centaur_01", "humanoid", 52, 8, 0.80, { move = 220 })
M("thunder_lizard", "천둥도마뱀", "Thunder Lizard", "INV_Misc_MonsterScales_05", "beast", 60, 9, 0.60,
	{ school = "nature", res = { nature = 50 }, status = { "shock", 0.2 } })
M("hyena", "하이에나", "Barrens Hyena", "Ability_Hunter_Pet_Hyena", "beast", 40, 8, 1.00, { move = 230 })
M("deviate_raptor", "변종 랩터", "Deviate Raptor", "Ability_Mount_Raptor", "beast", 48, 9, 0.90, { move = 220 })
M("serpent", "변종 독사", "Deviate Viper", "Ability_Hunter_Pet_WindSerpent", "beast", 36, 10, 0.60, { range = 420, school = "nature" })
M("ooze", "수액괴물", "Evolving Ectoplasm", "INV_Misc_Slime_01", "elemental", 75, 6, 0.50, { move = 110, res = { nature = 40 } })
M("furbolg", "펄볼그 전사", "Foulweald Warrior", "Ability_Hunter_Pet_Bear", "humanoid", 62, 8, 0.70)
M("satyr", "사티로스", "Xavian Rogue", "Spell_Shadow_UnholyStrength", "demon", 44, 10, 0.80, { school = "shadow", res = { shadow = 40 } })
M("harpy", "하피", "Screeching Harpy", "Ability_Hunter_Pet_Vulture", "humanoid", 34, 9, 0.70, { range = 420, school = "nature" })
M("basilisk", "바실리스크", "Glasshide Basilisk", "INV_Misc_MonsterHead_02", "beast", 70, 8, 0.60, { status = { "stun", 0.12 } })
M("pirate", "남쪽바다 해적", "Southsea Pirate", "INV_Misc_Head_Human_01", "humanoid", 50, 10, 0.90)
M("sand_troll", "모래 트롤", "Sandfury Hideskinner", "INV_Misc_Head_Troll_02", "humanoid", 52, 10, 0.80)
M("devilsaur", "데빌사우루스", "Devilsaur", "INV_Misc_MonsterFang_02", "beast", 130, 12, 0.50, { move = 150 })
M("lava_elemental", "용암 정령", "Living Blaze", "Spell_Fire_Volcano", "elemental", 56, 11, 0.60,
	{ school = "fire", res = { fire = 60, frost = -30 }, status = { "ignite", 0.25 } })
M("silithid", "실리시드 일꾼", "Hive'Ashi Worker", "Spell_Nature_InsectSwarm", "beast", 46, 9, 0.90, { move = 220 })
M("cultist", "황혼의 망치단 이교도", "Twilight Cultist", "Spell_Shadow_ShadowWordPain", "humanoid", 40, 12, 0.50, { range = 430, school = "shadow" })
M("sandworm", "모래벌레", "Dredge Striker", "INV_Misc_MonsterTail_03", "beast", 66, 10, 0.70, { status = { "poison", 0.25 } })
M("anubisath", "아누비사스 수호자", "Anubisath Guardian", "INV_Misc_AhnQirajTrinket_04", "giant", 110, 12, 0.50, { move = 130, res = { nature = 30, shadow = 30 } })
M("qiraji", "퀴라지 검투사", "Qiraji Gladiator", "INV_Misc_AhnQirajTrinket_02", "humanoid", 70, 12, 0.80)

-- Act 3 - The frozen north, the plague and the dragons
M("yeti", "예티", "Ice Thistle Yeti", "Ability_Hunter_Pet_Gorilla", "humanoid", 90, 10, 0.60, { res = { frost = 30 } })
M("frostsaber", "서리표범", "Frostsaber Stalker", "Ability_Hunter_Pet_Cat", "beast", 55, 11, 1.10, { move = 240, res = { frost = 30 } })
M("frost_elemental", "얼음 정령", "Ice Elemental", "Spell_Frost_SummonWaterElemental", "elemental", 60, 11, 0.60,
	{ range = 420, school = "frost", res = { frost = 60, fire = -30 }, status = { "chill", 0.35 } })
M("frostwolf", "서리늑대 전사", "Frostwolf Warrior", "INV_Misc_Head_Orc_02", "humanoid", 75, 11, 0.80)
M("ice_troll", "얼음 트롤 광전사", "Winterax Berserker", "INV_Misc_Head_Troll_01", "humanoid", 65, 12, 0.90)
M("skeleton_mage", "해골 마법사", "Skeletal Sorcerer", "Spell_Frost_FrostBolt02", "undead", 42, 13, 0.50,
	{ range = 430, school = "frost", status = { "chill", 0.3 } })
M("abomination", "누더기골렘", "Abomination", "Spell_Shadow_AbominationExplosion", "undead", 150, 12, 0.50, { move = 130 })
M("necromancer", "강령술사", "Scholomance Necromancer", "Spell_Shadow_AnimateDead", "humanoid", 46, 14, 0.50, { range = 430, school = "shadow" })
M("ghost", "유령", "Spectral Tutor", "Spell_Shadow_Possession", "undead", 50, 11, 0.80, { res = { phys = 30 } })
M("crusader", "붉은십자군 광신도", "Crimson Zealot", "Spell_Holy_Excorcism", "humanoid", 70, 12, 0.80, { school = "holy" })
M("gargoyle", "가고일", "Stonespine Gargoyle", "Spell_Shadow_GatherShadows", "undead", 60, 12, 1.00, { move = 240 })
M("banshee", "밴시", "Wailing Banshee", "Spell_Shadow_Charm", "undead", 44, 14, 0.60, { range = 420, school = "shadow" })
M("voidwalker", "공허방랑자", "Voidwalker", "Spell_Shadow_SummonVoidWalker", "demon", 100, 11, 0.60, { school = "shadow", res = { shadow = 50 } })
M("imp", "임프", "Fel Imp", "Spell_Shadow_SummonImp", "demon", 36, 13, 0.70, { range = 430, school = "fire", res = { fire = 40 } })
M("felhound", "지옥사냥개", "Felhunter", "Spell_Shadow_SummonFelHunter", "demon", 64, 12, 0.90, { move = 220 })
M("blackhand", "검은손 정예병", "Blackhand Elite", "INV_Misc_Head_Orc_01", "humanoid", 90, 13, 0.80)
M("whelp", "검은 새끼용", "Black Whelp", "INV_Misc_Head_Dragon_Black", "dragonkin", 50, 14, 0.70, { range = 400, school = "fire", res = { fire = 40 } })
M("ogre", "오우거", "Firegut Ogre", "Ability_Smash", "giant", 140, 13, 0.50, { move = 140, status = { "stun", 0.1 } })
M("dragonkin", "용혈족", "Death Talon Dragonspawn", "INV_Misc_Head_Dragon_01", "dragonkin", 110, 14, 0.70, { res = { fire = 30 } })
M("drake", "검은용", "Black Drake", "INV_Misc_Head_Dragon_Red", "dragonkin", 130, 15, 0.60, { school = "fire", res = { fire = 50 }, status = { "ignite", 0.3 } })
M("technician", "검은날개 기술병", "Blackwing Technician", "INV_Misc_Bomb_03", "humanoid", 48, 14, 0.60, { range = 400, school = "fire" })
M("crypt_fiend", "지하마귀", "Crypt Fiend", "Spell_Nature_Web", "undead", 85, 13, 0.80, { status = { "poison", 0.3 } })
M("death_knight", "죽음의 기사", "Death Knight Captain", "Spell_Shadow_DeathCoil", "undead", 110, 15, 0.80, { school = "shadow", res = { shadow = 30, frost = 30 } })

-- Summoned by raid bosses
M("son_of_flame", "화염의 피조물", "Son of Flame", "Spell_Fire_Fire", "elemental", 60, 10, 0.80, { school = "fire", res = { fire = 80, frost = -30 } })
M("eye_tentacle", "눈달린 촉수", "Eye Tentacle", "INV_Misc_Eye_01", "beast", 45, 12, 0.60, { range = 430, school = "shadow" })
M("frozen_wraith", "얼어붙은 망령", "Frozen Wraith", "Spell_Frost_FreezingBreath", "undead", 70, 12, 0.80, { school = "frost", res = { frost = 60 }, status = { "chill", 0.4 } })
