-- Monsters. Stats are level-1 values; Stages.lua scales them by stage level.
-- range: nil = melee, number = ranged. type feeds the companion kill counters.
local _, ns = ...

ns.MTYPE = {
	beast      = "야수",
	humanoid   = "인간형",
	undead     = "언데드",
	elemental  = "정령",
	demon      = "악마",
	dragonkin  = "용족",
	mechanical = "기계",
	giant      = "거인",
	aberration = "변종",
}

ns.MONSTERS = {}

local function M(id, name, icon, mtype, hp, atk, aspd, o)
	o = o or {}
	o.id = id
	o.name = name
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
M("kobold", "코볼트 일꾼", "INV_Misc_Head_Kobold_01", "humanoid", 28, 4, 0.70)
M("wolf", "숲늑대", "Ability_Hunter_Pet_Wolf", "beast", 24, 5, 0.90, { move = 220 })
M("gnoll", "리버포 놀", "INV_Misc_Head_Gnoll_01", "humanoid", 36, 5, 0.70)
M("murloc", "멀록 약탈자", "INV_Misc_Head_Murloc_01", "humanoid", 30, 5, 0.80)
M("defias", "데피아즈단 악당", "INV_Misc_Head_Human_01", "humanoid", 38, 6, 0.80)
M("golem", "허수아비 골렘", "INV_Gizmo_02", "mechanical", 55, 6, 0.60, { move = 130 })
M("defias_mage", "데피아즈단 마법사", "INV_Misc_Head_Human_02", "humanoid", 26, 8, 0.50, { range = 420, school = "fire" })
M("goblin", "고블린 기술자", "INV_Misc_Bomb_01", "humanoid", 32, 7, 0.60, { range = 380, school = "fire" })
M("orc", "검은바위 오크", "INV_Misc_Head_Orc_01", "humanoid", 50, 7, 0.70)
M("worgen", "밤그림자 늑대인간", "INV_Misc_MonsterFang_01", "humanoid", 48, 8, 0.90, { move = 210 })
M("skeleton", "해골 전사", "Spell_Shadow_RaiseDead", "undead", 40, 7, 0.70)
M("spider", "독거미", "Ability_Hunter_Pet_Spider", "beast", 34, 6, 0.80, { status = { "poison", 0.3 } })
M("raptor", "랩터", "Ability_Hunter_Pet_Raptor", "beast", 44, 8, 0.90, { move = 220 })
M("troll", "정글 트롤", "INV_Misc_Head_Troll_01", "humanoid", 36, 8, 0.70, { range = 400 })
M("tiger", "호랑이", "INV_Misc_Head_Tiger_01", "beast", 42, 9, 1.00, { move = 230, status = { "bleed", 0.2 } })
M("croc", "악어", "Ability_Hunter_Pet_Crocolisk", "beast", 70, 7, 0.60, { move = 140 })
M("darkiron", "검은무쇠 소총병", "INV_Misc_Head_Dwarf_01", "humanoid", 40, 9, 0.60, { range = 460 })
M("ghoul", "구울", "INV_Misc_Head_Undead_01", "undead", 60, 8, 0.80)
M("acolyte", "스컬지 수행사제", "Spell_Shadow_ShadowBolt", "humanoid", 34, 10, 0.50, { range = 430, school = "shadow" })
M("plaguebat", "역병박쥐", "Ability_Hunter_Pet_Bat", "beast", 28, 7, 1.10, { move = 240, status = { "poison", 0.25 } })
M("fire_elemental", "불의 정령", "Spell_Fire_Elemental_Totem", "elemental", 48, 10, 0.60,
	{ school = "fire", res = { fire = 60, frost = -30 }, status = { "ignite", 0.25 } })
M("core_hound", "심장부 사냥개", "Spell_Fire_Immolation", "beast", 80, 9, 0.70, { school = "fire", res = { fire = 40 } })
M("darkiron_guard", "검은무쇠 병사", "INV_Misc_Head_Dwarf_02", "humanoid", 65, 9, 0.70)

-- Act 2 - Kalimdor
M("scorpid", "전갈", "Ability_Hunter_Pet_Scorpid", "beast", 36, 6, 0.80, { status = { "poison", 0.3 } })
M("boar", "멧돼지", "Ability_Hunter_Pet_Boar", "beast", 44, 6, 0.80, { move = 210 })
M("quilboar", "가시멧돼지 사냥꾼", "INV_Misc_Head_Quillboar_01", "humanoid", 38, 7, 0.70, { range = 400 })
M("centaur", "켄타우로스 약탈자", "INV_Misc_Head_Centaur_01", "humanoid", 52, 8, 0.80, { move = 220 })
M("thunder_lizard", "천둥도마뱀", "INV_Misc_MonsterScales_05", "beast", 60, 9, 0.60,
	{ school = "nature", res = { nature = 50 }, status = { "shock", 0.2 } })
M("hyena", "하이에나", "Ability_Hunter_Pet_Hyena", "beast", 40, 8, 1.00, { move = 230 })
M("deviate_raptor", "변종 랩터", "Ability_Mount_Raptor", "beast", 48, 9, 0.90, { move = 220 })
M("serpent", "변종 독사", "Ability_Hunter_Pet_WindSerpent", "beast", 36, 10, 0.60, { range = 420, school = "nature" })
M("ooze", "수액괴물", "INV_Misc_Slime_01", "elemental", 75, 6, 0.50, { move = 110, res = { nature = 40 } })
M("furbolg", "펄볼그 전사", "Ability_Hunter_Pet_Bear", "humanoid", 62, 8, 0.70)
M("satyr", "사티로스", "Spell_Shadow_UnholyStrength", "demon", 44, 10, 0.80, { school = "shadow", res = { shadow = 40 } })
M("harpy", "하피", "Ability_Hunter_Pet_Vulture", "humanoid", 34, 9, 0.70, { range = 420, school = "nature" })
M("basilisk", "바실리스크", "INV_Misc_MonsterHead_02", "beast", 70, 8, 0.60, { status = { "stun", 0.12 } })
M("pirate", "남쪽바다 해적", "INV_Misc_Head_Human_01", "humanoid", 50, 10, 0.90)
M("sand_troll", "모래 트롤", "INV_Misc_Head_Troll_02", "humanoid", 52, 10, 0.80)
M("devilsaur", "데빌사우루스", "INV_Misc_MonsterFang_02", "beast", 130, 12, 0.50, { move = 150 })
M("lava_elemental", "용암 정령", "Spell_Fire_Volcano", "elemental", 56, 11, 0.60,
	{ school = "fire", res = { fire = 60, frost = -30 }, status = { "ignite", 0.25 } })
M("silithid", "실리시드 일꾼", "Spell_Nature_InsectSwarm", "beast", 46, 9, 0.90, { move = 220 })
M("cultist", "황혼의 망치단 이교도", "Spell_Shadow_ShadowWordPain", "humanoid", 40, 12, 0.50, { range = 430, school = "shadow" })
M("sandworm", "모래벌레", "INV_Misc_MonsterTail_03", "beast", 66, 10, 0.70, { status = { "poison", 0.25 } })
M("anubisath", "아누비사스 수호자", "INV_Misc_AhnQirajTrinket_04", "giant", 110, 12, 0.50, { move = 130, res = { nature = 30, shadow = 30 } })
M("qiraji", "퀴라지 검투사", "INV_Misc_AhnQirajTrinket_02", "humanoid", 70, 12, 0.80)

-- Act 3 - The frozen north, the plague and the dragons
M("yeti", "예티", "Ability_Hunter_Pet_Gorilla", "humanoid", 90, 10, 0.60, { res = { frost = 30 } })
M("frostsaber", "서리표범", "Ability_Hunter_Pet_Cat", "beast", 55, 11, 1.10, { move = 240, res = { frost = 30 } })
M("frost_elemental", "얼음 정령", "Spell_Frost_SummonWaterElemental", "elemental", 60, 11, 0.60,
	{ range = 420, school = "frost", res = { frost = 60, fire = -30 }, status = { "chill", 0.35 } })
M("frostwolf", "서리늑대 전사", "INV_Misc_Head_Orc_02", "humanoid", 75, 11, 0.80)
M("ice_troll", "얼음 트롤 광전사", "INV_Misc_Head_Troll_01", "humanoid", 65, 12, 0.90)
M("skeleton_mage", "해골 마법사", "Spell_Frost_FrostBolt02", "undead", 42, 13, 0.50,
	{ range = 430, school = "frost", status = { "chill", 0.3 } })
M("abomination", "누더기골렘", "Spell_Shadow_AbominationExplosion", "undead", 150, 12, 0.50, { move = 130 })
M("necromancer", "강령술사", "Spell_Shadow_AnimateDead", "humanoid", 46, 14, 0.50, { range = 430, school = "shadow" })
M("ghost", "유령", "Spell_Shadow_Possession", "undead", 50, 11, 0.80, { res = { phys = 30 } })
M("crusader", "붉은십자군 광신도", "Spell_Holy_Excorcism", "humanoid", 70, 12, 0.80, { school = "holy" })
M("gargoyle", "가고일", "Spell_Shadow_GatherShadows", "undead", 60, 12, 1.00, { move = 240 })
M("banshee", "밴시", "Spell_Shadow_Charm", "undead", 44, 14, 0.60, { range = 420, school = "shadow" })
M("voidwalker", "공허방랑자", "Spell_Shadow_SummonVoidWalker", "demon", 100, 11, 0.60, { school = "shadow", res = { shadow = 50 } })
M("imp", "임프", "Spell_Shadow_SummonImp", "demon", 36, 13, 0.70, { range = 430, school = "fire", res = { fire = 40 } })
M("felhound", "지옥사냥개", "Spell_Shadow_SummonFelHunter", "demon", 64, 12, 0.90, { move = 220 })
M("blackhand", "검은손 정예병", "INV_Misc_Head_Orc_01", "humanoid", 90, 13, 0.80)
M("whelp", "검은 새끼용", "INV_Misc_Head_Dragon_Black", "dragonkin", 50, 14, 0.70, { range = 400, school = "fire", res = { fire = 40 } })
M("ogre", "오우거", "Ability_Smash", "giant", 140, 13, 0.50, { move = 140, status = { "stun", 0.1 } })
M("dragonkin", "용혈족", "INV_Misc_Head_Dragon_01", "dragonkin", 110, 14, 0.70, { res = { fire = 30 } })
M("drake", "검은용", "INV_Misc_Head_Dragon_Red", "dragonkin", 130, 15, 0.60, { school = "fire", res = { fire = 50 }, status = { "ignite", 0.3 } })
M("technician", "검은날개 기술병", "INV_Misc_Bomb_03", "humanoid", 48, 14, 0.60, { range = 400, school = "fire" })
M("crypt_fiend", "지하마귀", "Spell_Nature_Web", "undead", 85, 13, 0.80, { status = { "poison", 0.3 } })
M("death_knight", "죽음의 기사", "Spell_Shadow_DeathCoil", "undead", 110, 15, 0.80, { school = "shadow", res = { shadow = 30, frost = 30 } })

-- Summoned by raid bosses
M("son_of_flame", "화염의 피조물", "Spell_Fire_Fire", "elemental", 60, 10, 0.80, { school = "fire", res = { fire = 80, frost = -30 } })
M("eye_tentacle", "눈달린 촉수", "INV_Misc_Eye_01", "beast", 45, 12, 0.60, { range = 430, school = "shadow" })
M("frozen_wraith", "얼어붙은 망령", "Spell_Frost_FreezingBreath", "undead", 70, 12, 0.80, { school = "frost", res = { frost = 60 }, status = { "chill", 0.4 } })

------------------------------------------------------------------------
-- Monsters of the later worlds are built from archetypes: the archetype sets
-- the level-1 shape of the monster, the act it first appears in scales it.
------------------------------------------------------------------------
local ARCH = {
	swarm   = { hp = 28,  atk = 5.0, aspd = 1.00, move = 220 },
	grunt   = { hp = 42,  atk = 6.5, aspd = 0.80, move = 170 },
	stalker = { hp = 36,  atk = 7.5, aspd = 1.00, move = 230 },
	brute   = { hp = 72,  atk = 7.5, aspd = 0.60, move = 140 },
	hulk    = { hp = 115, atk = 9.5, aspd = 0.50, move = 130 },
	archer  = { hp = 32,  atk = 7.5, aspd = 0.70, move = 170, range = 420 },
	caster  = { hp = 28,  atk = 9.0, aspd = 0.50, move = 160, range = 430 },
}
local ACT_HP = { 1.0, 1.35, 1.8 }
local ACT_ATK = { 1.0, 1.35, 1.85 }

local function A(id, name, icon, mtype, arch, act, o)
	local a = ARCH[arch]
	o = o or {}
	o.move = o.move or a.move
	o.range = o.range or a.range
	M(id, name, icon, mtype, math.floor(a.hp * ACT_HP[act] + 0.5), math.floor(a.atk * ACT_ATK[act] * 10 + 0.5) / 10, a.aspd, o)
end

-- Outland --------------------------------------------------------------
A("fel_orc", "지옥 오크 투사", "INV_Misc_Head_Orc_02", "humanoid", "grunt", 1)
A("fel_orc_warlock", "지옥 오크 흑마법사", "Spell_Shadow_ShadowBolt", "humanoid", "caster", 1, { school = "shadow" })
A("helboar", "지옥멧돼지", "Ability_Hunter_Pet_Boar", "beast", "stalker", 1, { school = "fire", res = { fire = 30 } })
A("ravager", "갈퀴발톱", "INV_Misc_MonsterClaw_04", "beast", "stalker", 1, { status = { "bleed", 0.25 } })
A("shattered_hand", "으스러진 손 백부장", "INV_Misc_Head_Orc_01", "humanoid", "brute", 1)
A("sporebat", "포자박쥐", "Ability_Hunter_Pet_Bat", "beast", "archer", 1, { school = "nature", status = { "poison", 0.3 } })
A("bog_lord", "늪지 군주", "Spell_Nature_StoneClawTotem", "elemental", "hulk", 1, { res = { nature = 40, fire = -25 } })
A("naga_myrmidon", "나가 미르미돈", "INV_Misc_MonsterScales_03", "humanoid", "grunt", 1, { res = { frost = 25 } })
A("naga_siren", "나가 세이렌", "Spell_Frost_FrostBolt02", "humanoid", "caster", 1, { school = "frost", status = { "chill", 0.35 } })
A("marsh_crab", "습지 게", "Ability_Hunter_Pet_Crab", "beast", "brute", 1)
A("steam_surger", "증기 정령", "Spell_Frost_SummonWaterElemental", "elemental", "caster", 1, { school = "frost", res = { frost = 50, nature = -25 } })
A("arakkoa", "아라코아 현자", "Ability_Hunter_Pet_Owl", "humanoid", "caster", 1, { school = "arcane" })
A("warp_stalker", "차원 추적자", "INV_Misc_MonsterScales_07", "beast", "stalker", 1)
A("sethekk", "세데크 수호병", "Ability_Hunter_Pet_Vulture", "humanoid", "grunt", 1)
A("clefthoof", "갈래발굽", "Ability_Mount_Kodo_01", "beast", "hulk", 2)
A("boulderfist", "돌주먹 오우거", "Ability_Smash", "giant", "brute", 2, { status = { "stun", 0.1 } })
A("talbuk", "탈부크", "Ability_Mount_MountainRam", "beast", "stalker", 2)
A("gronnling", "새끼 그론", "INV_Misc_MonsterHead_03", "giant", "hulk", 2)
A("ethereal", "에테리얼 약탈자", "Spell_Holy_MagicalSentry", "humanoid", "grunt", 2, { school = "arcane", res = { arcane = 30 } })
A("mana_wyrm", "마나 지룡", "Spell_Nature_StarFall", "dragonkin", "swarm", 2, { school = "arcane" })
A("fel_sentry", "지옥절단기 파수병", "INV_Misc_Gear_01", "mechanical", "hulk", 2, { school = "fire" })
A("sunfury_mage", "태양격노 마법학자", "INV_Misc_Head_Elf_02", "humanoid", "caster", 2, { school = "fire", status = { "ignite", 0.25 } })
A("sunfury_guard", "태양격노 수호병", "INV_Misc_Head_Elf_02", "humanoid", "grunt", 2)
A("mutate_lasher", "돌연변이 덩굴손", "Spell_Nature_Thorns", "elemental", "stalker", 2, { school = "nature", status = { "poison", 0.25 } })
A("phantom_guest", "유령 손님", "Spell_Shadow_Possession", "undead", "grunt", 2, { res = { phys = 25 } })
A("spectral_steed", "망령 군마", "Ability_Mount_Undeadhorse", "undead", "stalker", 2)
A("mechanar_drone", "메카나르 파괴병", "INV_Misc_Gear_02", "mechanical", "brute", 2)
A("nether_drake", "황천의 비룡", "INV_Misc_Head_Dragon_Blue", "dragonkin", "archer", 3, { school = "arcane", res = { arcane = 40 } })
A("wrathguard", "격노수호병", "Spell_Shadow_SummonFelHunter", "demon", "brute", 3, { res = { shadow = 30, fire = 30 } })
A("cabal_cultist", "비밀결사단 이교도", "Spell_Shadow_ShadowWordPain", "humanoid", "caster", 3, { school = "shadow" })
A("infinite_slayer", "무한의 용혈족", "INV_Misc_Head_Dragon_Bronze", "dragonkin", "grunt", 3)
A("infinite_whelp", "무한의 새끼용", "INV_Misc_Head_Dragon_Bronze", "dragonkin", "swarm", 3, { school = "arcane" })
A("infernal", "지옥불정령", "Spell_Shadow_SummonInfernal", "demon", "hulk", 3, { school = "fire", res = { fire = 60, frost = -25 }, status = { "ignite", 0.3 } })
A("amani_axe", "아마니 도끼 투척꾼", "INV_Misc_Head_Troll_02", "humanoid", "archer", 3)
A("amani_lynx", "아마니 스라소니", "Ability_Hunter_Pet_Cat", "beast", "stalker", 3, { status = { "bleed", 0.25 } })
A("ashtongue", "재의 혓바닥 전사", "INV_Misc_Bone_ElfSkull_01", "humanoid", "grunt", 3)
A("illidari", "일리다리 칼날추적자", "Ability_Warrior_PunishingBlow", "demon", "stalker", 3)
A("sunblade_knight", "태양칼날 혈기사", "INV_Misc_Head_Elf_02", "humanoid", "brute", 3, { school = "holy" })
A("sunblade_mage", "태양칼날 대마법사", "Spell_Fire_FlameBolt", "humanoid", "caster", 3, { school = "arcane" })
A("shadowsword", "어둠칼날 암살자", "Spell_Shadow_SummonVoidWalker", "demon", "stalker", 3, { school = "shadow", res = { shadow = 40 } })

-- Northrend ------------------------------------------------------------
A("nerubian", "네루비안 거미전사", "Spell_Nature_Web", "undead", "stalker", 1, { status = { "poison", 0.3 } })
A("mammoth", "털북숭이 매머드", "Ability_Mount_Kodo_01", "beast", "hulk", 1, { res = { frost = 30 } })
A("mage_hunter", "마법사 사냥꾼", "INV_Misc_Head_Human_02", "humanoid", "caster", 1, { school = "arcane" })
A("crystalline", "수정 수호자", "INV_Misc_Gem_Crystal_02", "elemental", "brute", 1, { school = "arcane", res = { arcane = 50 } })
A("vrykul", "브리쿨 전사", "INV_Helmet_08", "giant", "grunt", 1)
A("vrykul_seer", "브리쿨 예언자", "Spell_Frost_FrostArmor02", "giant", "caster", 1, { school = "frost", status = { "chill", 0.35 } })
A("proto_drake", "원시비룡", "INV_Misc_Head_Dragon_Red", "dragonkin", "archer", 1, { school = "fire", status = { "ignite", 0.25 } })
A("fjord_worg", "협만 늑대", "Ability_Hunter_Pet_Wolf", "beast", "stalker", 1)
A("magnataur", "마그나타우르", "INV_Misc_MonsterHorn_03", "giant", "hulk", 1)
A("frost_whelp", "서리 새끼용", "INV_Misc_Head_Dragon_Blue", "dragonkin", "archer", 1, { school = "frost", res = { frost = 50, fire = -25 } })
A("faceless", "얼굴없는 자", "Spell_Shadow_EvilEye", "aberration", "caster", 1, { school = "shadow", res = { shadow = 40 } })
A("ahnkahet_cultist", "황혼의 수습생", "Spell_Shadow_Twilight", "humanoid", "grunt", 1, { school = "shadow" })
A("grizzly", "회색 곰", "Ability_Hunter_Pet_Bear", "beast", "brute", 2)
A("drakkari", "드라카리 광전사", "INV_Misc_Head_Troll_01", "humanoid", "grunt", 2)
A("drakkari_shaman", "드라카리 주술사", "Spell_Nature_Lightning", "humanoid", "caster", 2, { school = "nature", status = { "shock", 0.25 } })
A("scourge_troll", "되살아난 드라카리", "INV_Misc_Head_Undead_02", "undead", "stalker", 2)
A("wolvar", "울바르 사냥꾼", "Ability_Hunter_Pet_Hyena", "humanoid", "swarm", 2)
A("rhino", "북녘 코뿔소", "Ability_Mount_Kodo_03", "beast", "hulk", 2)
A("azure_invader", "푸른용군단 침략자", "INV_Misc_Head_Dragon_Blue", "dragonkin", "grunt", 2, { res = { arcane = 30 } })
A("azure_mage", "푸른용군단 마법사", "Spell_Frost_IceShock", "dragonkin", "caster", 2, { school = "arcane" })
A("iron_dwarf", "무쇠 드워프", "INV_Misc_Head_Dwarf_02", "humanoid", "grunt", 2)
A("iron_golem", "무쇠 골렘", "INV_Misc_Gear_03", "mechanical", "hulk", 2, { res = { nature = 30 } })
A("storm_giant", "폭풍 거인", "Spell_Nature_CallStorm", "giant", "hulk", 2, { school = "nature", status = { "shock", 0.2 } })
A("lightning_ele", "번개 정령", "Spell_Nature_ChainLightning", "elemental", "caster", 2, { school = "nature", res = { nature = 60 } })
A("geist", "가이스트", "INV_Misc_Bone_HumanSkull_01", "undead", "swarm", 3)
A("valkyr", "발키르 그림자수호병", "Spell_Shadow_Twilight", "undead", "archer", 3, { school = "shadow" })
A("frost_wyrm", "서리고룡", "Spell_Frost_FreezingBreath", "dragonkin", "hulk", 3, { school = "frost", range = 380, res = { frost = 60, fire = -25 }, status = { "chill", 0.4 } })
A("cult_adherent", "교단 신봉자", "Spell_Frost_FrostBolt02", "humanoid", "caster", 3, { school = "frost", status = { "chill", 0.3 } })
A("bone_construct", "뼈 구조물", "Spell_Shadow_RaiseDead", "undead", "brute", 3)
A("flesh_giant", "살점 거인", "Spell_Shadow_AbominationExplosion", "undead", "hulk", 3, { status = { "poison", 0.3 } })
A("ymirjar", "이미야르 전투마녀", "INV_Helmet_08", "giant", "stalker", 3)
A("scourge_champion", "스컬지 용사", "Spell_Shadow_DeathCoil", "undead", "grunt", 3, { school = "shadow" })

-- Cataclysm, Pandaria and the Legion ------------------------------------
A("twilight_zealot", "황혼의 광신도", "INV_Misc_Head_Human_01", "humanoid", "grunt", 1, { school = "shadow" })
A("twilight_shaper", "황혼의 원소술사", "Spell_Fire_FlameBolt", "humanoid", "caster", 1, { school = "fire", status = { "ignite", 0.3 } })
A("ember_lord", "잿불 군주", "Spell_Fire_Elemental_Totem", "elemental", "brute", 1, { school = "fire", res = { fire = 60, frost = -25 } })
A("deep_naga", "심해 나가 집행자", "INV_Misc_MonsterScales_03", "humanoid", "brute", 1, { res = { frost = 30 } })
A("deep_seer", "심해 바다마녀", "Spell_Frost_FrostNova", "humanoid", "caster", 1, { school = "frost", status = { "chill", 0.35 } })
A("stone_giant", "심원의 바위거인", "Spell_Nature_Earthquake", "elemental", "hulk", 1, { res = { nature = 40, phys = 15 } })
A("stone_drake", "돌용", "INV_Misc_Head_Dragon_Bronze", "dragonkin", "archer", 1, { school = "nature" })
A("neferset", "네페르셋 전사", "INV_Misc_Head_Centaur_01", "humanoid", "stalker", 1)
A("sand_djinn", "모래 진", "Spell_Nature_Cyclone", "elemental", "caster", 1, { school = "nature", res = { nature = 50 } })
A("twilight_drake", "황혼의 비룡", "INV_Misc_Head_Dragon_Black", "dragonkin", "archer", 1, { school = "shadow", res = { shadow = 40 } })
A("flamewaker", "불꽃지기", "Spell_Fire_Fire", "elemental", "grunt", 1, { school = "fire", res = { fire = 60 } })
A("molten_giant", "용암 거인", "Spell_Fire_Volcano", "giant", "hulk", 1, { school = "fire", res = { fire = 60, frost = -25 }, status = { "ignite", 0.3 } })
A("hozen", "호젠 싸움꾼", "Ability_Hunter_Pet_Gorilla", "humanoid", "swarm", 2)
A("jinyu", "진위 물예언자", "Spell_Frost_SummonWaterElemental", "humanoid", "caster", 2, { school = "frost", status = { "chill", 0.3 } })
A("sha", "샤의 화신", "Spell_Shadow_Possession", "aberration", "caster", 2, { school = "shadow", res = { shadow = 50 } })
A("virmen", "버민", "INV_Misc_MonsterFang_01", "beast", "swarm", 2)
A("yaungol", "야운골 전사", "INV_Misc_Head_Tauren_01", "humanoid", "brute", 2, { school = "fire" })
A("mogu", "모구 전사", "INV_Misc_MonsterHead_04", "humanoid", "hulk", 2)
A("mogu_sorcerer", "모구 마법사", "Spell_Nature_Lightning", "humanoid", "caster", 2, { school = "arcane" })
A("mantid", "사마귀 칼날군주", "INV_Misc_AhnQirajTrinket_02", "beast", "stalker", 2, { status = { "bleed", 0.3 } })
A("amber_shaper", "호박석 조율사", "INV_Misc_AhnQirajTrinket_04", "beast", "caster", 2, { school = "nature", status = { "poison", 0.3 } })
A("saurok", "사우록", "Ability_Hunter_Pet_Crocolisk", "humanoid", "stalker", 2, { status = { "poison", 0.2 } })
A("korkron", "코르크론 정예병", "INV_Misc_Head_Orc_01", "humanoid", "brute", 2)
A("dark_shaman", "코르크론 암흑주술사", "Spell_Fire_Elemental_Totem", "humanoid", "caster", 2, { school = "fire", status = { "ignite", 0.3 } })
A("withered", "마력에 굶주린 자", "Spell_Shadow_UnholyFrenzy", "humanoid", "swarm", 3, { school = "arcane" })
A("felguard", "지옥수호병", "Spell_Shadow_AntiShadow", "demon", "brute", 3, { res = { fire = 30, shadow = 30 } })
A("fel_bat", "지옥박쥐", "Ability_Hunter_Pet_Bat", "demon", "swarm", 3, { school = "fire" })
A("nightmare_treant", "악몽의 나무정령", "Spell_Nature_ForceOfNature", "elemental", "hulk", 3, { school = "nature", res = { nature = 40, fire = -25 } })
A("nightmare_stalker", "악몽의 추적자", "Spell_Shadow_Twilight", "aberration", "stalker", 3, { school = "shadow" })
A("drogbar", "드로그바 전사", "Spell_Nature_Earthquake", "humanoid", "brute", 3, { status = { "stun", 0.1 } })
A("storm_drake", "폭풍 비룡", "INV_Misc_Head_Dragon_Blue", "dragonkin", "archer", 3, { school = "nature", status = { "shock", 0.25 } })
A("valarjar", "발라리아르 용사", "INV_Helmet_08", "giant", "grunt", 3, { school = "holy" })
A("nightborne_mage", "나이트본 마법학자", "INV_Misc_Head_Elf_02", "humanoid", "caster", 3, { school = "arcane" })
A("nightborne_guard", "황혼수호병", "INV_Misc_Head_Elf_02", "humanoid", "grunt", 3)
A("doomguard", "파멸의 수호병", "Spell_Shadow_SummonInfernal", "demon", "hulk", 3, { school = "shadow", res = { shadow = 40, fire = 40 } })
A("eredar", "에레다르 흑마법사", "Spell_Shadow_ShadowBolt", "demon", "caster", 3, { school = "shadow", res = { shadow = 40 } })
A("fel_annihilator", "군단 파괴병기", "INV_Misc_Gear_04", "mechanical", "hulk", 3, { school = "fire", range = 380 })
A("antoran_hound", "안토란 지옥사냥개", "Spell_Shadow_SummonFelHunter", "demon", "stalker", 3, { school = "fire", status = { "ignite", 0.25 } })

-- Summoned by later raid bosses
M("hellfire_channeler", "지옥불 역술사", "Spell_Shadow_ShadowBolt", "humanoid", 55, 11, 0.6, { range = 430, school = "shadow" })
M("phoenix", "불사조", "Spell_Fire_Fire", "elemental", 60, 12, 0.8, { school = "fire", res = { fire = 80, frost = -25 } })
M("shield_orb", "보호의 수정구", "Spell_Shadow_SummonVoidWalker", "demon", 45, 12, 0.6, { range = 430, school = "shadow" })
M("nexus_lord", "마력의 군주", "INV_Misc_Head_Dragon_Blue", "dragonkin", 70, 12, 0.8, { school = "arcane" })
M("guardian_of_yogg", "요그사론의 수호자", "Spell_Shadow_EvilEye", "aberration", 65, 12, 0.8, { school = "shadow", res = { shadow = 50 } })
M("raging_spirit", "격노한 영혼", "Spell_Shadow_Possession", "undead", 70, 13, 0.8, { school = "shadow" })
M("corruption_tentacle", "타락의 촉수", "Spell_Shadow_Twilight", "aberration", 70, 12, 0.7, { range = 430, school = "shadow" })
M("korkron_warbringer", "코르크론 전쟁인도자", "INV_Misc_Head_Orc_02", "humanoid", 75, 12, 0.8)
M("reorigination_module", "재창조 모듈", "INV_Misc_Gear_04", "mechanical", 80, 12, 0.6, { range = 430, school = "arcane" })

