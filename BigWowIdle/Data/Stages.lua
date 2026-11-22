-- Stages. Each difficulty has 3 acts of 10 stages, all in the dungeons and
-- raids of the original game, from Ragefire Chasm to Naxxramas:
--   Normal  - the first dungeons (Ragefire Chasm .. the Scarlet Monastery)
--   Heroic  - Razorfen Downs .. Blackrock Depths
--   Mythic  - Blackrock Spire, Dire Maul, Stratholme, Scholomance,
--             the Ruins of Ahn'Qiraj and Zul'Gurub
--   Mythic+ - Molten Core, Onyxia, Blackwing Lair, the Temple of Ahn'Qiraj
--             and Naxxramas
-- A stage is a run of waves that ends with a boss; the 10th stage of an act is
-- a raid boss with its own abilities.
local _, ns = ...

ns.DIFFS = {
	{ name = "일반",   hex = "e8e8e8", base = 1,  step = 1.00, mobs = 1, bossHP = 1.0,
		world = "입문 던전",
		acts = { "죽음의 폐광", "검은심연 나락", "붉은십자군 수도원" } },
	{ name = "영웅",   hex = "3ddc5a", base = 32, step = 0.80, mobs = 3, bossHP = 1.5,
		world = "중급 던전",
		acts = { "울다만", "마라우돈", "검은바위 나락" } },
	{ name = "신화",   hex = "b266ff", base = 57, step = 0.70, mobs = 4, bossHP = 2.0,
		world = "상급 던전",
		acts = { "검은바위 첨탑", "혈투와 역병", "안퀴라즈와 줄구룹" } },
	{ name = "신화+", hex = "ff9326", base = 79, step = 0.73, mobs = 5, bossHP = 2.6,
		world = "공격대",
		acts = { "화산 심장부", "검은날개와 안퀴라즈", "낙스라마스" } },
}

ns.STAGES_PER_ACT = 10
ns.STAGE_COUNT = 30
ns.WAVES = 10

-- Scenery behind the battle: shape of the backdrop image and its tint.
ns.THEMES = {
	forest = { art = "scene_hills", rgb = { 0.45, 0.85, 0.50 } },
	plains = { art = "scene_hills", rgb = { 0.85, 0.85, 0.50 } },
	jungle = { art = "scene_hills", rgb = { 0.30, 0.75, 0.45 } },
	swamp  = { art = "scene_hills", rgb = { 0.40, 0.75, 0.70 } },
	desert = { art = "scene_peaks", rgb = { 0.95, 0.80, 0.50 } },
	snow   = { art = "scene_peaks", rgb = { 0.75, 0.90, 1.00 } },
	ice    = { art = "scene_ruins", rgb = { 0.55, 0.80, 1.00 } },
	lava   = { art = "scene_peaks", rgb = { 1.00, 0.50, 0.30 } },
	fel    = { art = "scene_peaks", rgb = { 0.60, 0.95, 0.35 } },
	shadow = { art = "scene_ruins", rgb = { 0.70, 0.50, 0.95 } },
	arcane = { art = "scene_ruins", rgb = { 0.60, 0.60, 1.00 } },
	cave   = { art = "scene_ruins", rgb = { 0.75, 0.65, 0.55 } },
	ruins  = { art = "scene_ruins", rgb = { 0.80, 0.80, 0.80 } },
	sea    = { art = "scene_hills", rgb = { 0.40, 0.65, 1.00 } },
	storm  = { art = "scene_peaks", rgb = { 0.65, 0.72, 0.85 } },
	holy   = { art = "scene_ruins", rgb = { 1.00, 0.90, 0.60 } },
}

------------------------------------------------------------------------
-- Boss abilities:
--   smash  : heavy hit on the current target          { cd, mult }
--   aoe    : hits every hero                          { cd, mult, school, status }
--   summon : calls adds                               { cd, mob, n }
--   enrage : permanent damage bonus below a HP ratio  { hp, mult }
--   shield : temporary damage reduction               { cd, dur, dr }
------------------------------------------------------------------------
local function smash(cd, mult, school, status) return { kind = "smash", cd = cd, mult = mult, school = school, status = status } end
local function aoe(cd, mult, school, status) return { kind = "aoe", cd = cd, mult = mult, school = school, status = status } end
local function summon(cd, mob, n) return { kind = "summon", cd = cd, mob = mob, n = n } end
local function enrage(hp, mult) return { kind = "enrage", hp = hp, mult = mult } end
local function shield(cd, dur, dr) return { kind = "shield", cd = cd, dur = dur, dr = dr } end

-- Normal: numbers written out by hand.
local function B(name, icon, mtype, hp, atk, aspd, o)
	o = o or {}
	o.name = name
	o.icon = icon
	o.type = mtype
	o.hp = hp
	o.atk = atk
	o.aspd = aspd
	o.school = o.school or "phys"
	o.move = o.move or 150
	o.boss = true
	o.skills = o.skills or { smash(9, 2.2) }
	return o
end

-- Heroic and up: a boss is a build (how it fights) and its abilities; health
-- and damage follow from where the stage sits in the difficulty.
local BUILD = {
	brute  = { hp = 1.20, atk = 1.10, aspd = 0.60 },
	lord   = { hp = 1.00, atk = 1.00, aspd = 0.70 },
	swift  = { hp = 0.90, atk = 0.80, aspd = 1.00 },
	caster = { hp = 0.85, atk = 1.00, aspd = 0.60, range = 430 },
}

local function X(name, icon, mtype, build, skills, o)
	o = o or {}
	o.name = name
	o.icon = icon
	o.type = mtype
	o.build = build
	o.school = o.school or "phys"
	o.move = o.move or 150
	o.boss = true
	o.skills = skills
	return o
end

local function finish(list)
	for i, stg in ipairs(list) do
		stg.raid = (i % ns.STAGES_PER_ACT == 0) or nil
		local b = stg.boss
		if b.build then
			local k = BUILD[b.build]
			local hp = (200 + 45 * (i - 1)) * k.hp
			if stg.raid then hp = hp * 2.0 end
			b.hp = math.floor(hp + 0.5)
			b.atk = math.floor((7.5 + 0.36 * (i - 1)) * k.atk * 10 + 0.5) / 10
			b.aspd = k.aspd
			b.range = b.range or k.range
		end
	end
	return list
end

local function st(name, theme, mobs, boss)
	return { name = name, theme = theme, mobs = mobs, boss = boss }
end

ns.STAGES = {}

------------------------------------------------------------------------
-- Normal: the first dungeons
------------------------------------------------------------------------
ns.STAGES[1] = finish({
	-- Act 1: 죽음의 폐광
	st("성난불길 협곡", "cave", { { "ragefire_trogg", 50 }, { "earthborer", 50 } },
		B("오글플린트", "INV_Misc_Head_Kobold_01", "humanoid", 150, 7, 0.7, { skills = { smash(9, 2.2) } })),
	st("성난불길 협곡", "lava", { { "ragefire_shaman", 35 }, { "searing_blade_cultist", 35 }, { "molten_elemental", 30 } },
		B("욕망의 타라가만", "Spell_Shadow_SummonImp", "humanoid", 240, 8, 0.6, { skills = { smash(9, 2.2) } })),
	st("성난불길 협곡", "lava", { { "searing_blade_enforcer", 40 }, { "searing_blade_warlock", 30 }, { "ragefire_shaman_2", 30 } },
		B("기원사 제르고쉬", "Spell_Shadow_ShadowBolt", "humanoid", 300, 10, 0.9, { skills = { smash(8, 2), summon(18, "searing_blade_cultist", 2) } })),
	st("통곡의 동굴", "cave", { { "druid_of_the_fang", 45 }, { "mad_magglish", 30 }, { "deviate_crocolisk", 25 } },
		B("여군주 아나콘드라", "Ability_Hunter_Pet_WindSerpent", "humanoid", 360, 11, 0.7, { skills = { smash(9, 2.2) } })),
	st("통곡의 동굴", "cave", { { "deviate_lurker", 35 }, { "druid_of_the_fang_2", 35 }, { "deviate_viper", 30 } },
		B("군주 피타스", "Ability_Hunter_Pet_WindSerpent", "humanoid", 460, 11, 0.6, { skills = { smash(9, 2.2), aoe(13, 0.8, "nature", { "poison", 0.5 }) } })),
	st("통곡의 동굴", "jungle", { { "deviate_ravager", 35 }, { "druid_of_the_fang_3", 30 }, { "deviate_stinglash", 35 } },
		B("걸신들린 무타누스", "INV_Misc_Head_Murloc_01", "humanoid", 440, 13, 1, { skills = { smash(8, 2), summon(20, "deviate_ravager_2", 2) } })),
	st("죽음의 폐광", "cave", { { "defias_miner", 35 }, { "defias_evoker", 30 }, { "defias_overseer", 35 } },
		B("라크조르", "INV_Misc_Head_Human_01", "humanoid", 560, 12, 0.6, { skills = { smash(9, 2.2) } })),
	st("죽음의 폐광", "cave", { { "defias_taskmaster", 40 }, { "defias_wizard", 25 }, { "goblin_woodcarver", 35 } },
		B("스니드의 벌목기", "INV_Gizmo_02", "mechanical", 520, 13, 0.7, { school = "shadow", skills = { aoe(11, 0.9, "shadow"), summon(20, "goblin_engineer", 2) } })),
	st("죽음의 폐광", "sea", { { "defias_pirate", 40 }, { "goblin_engineer_2", 30 }, { "defias_squallshaper", 30 } },
		B("선장 그린스킨", "Spell_Shadow_DeathCoil", "humanoid", 600, 14, 0.8, { skills = { smash(9, 2.2), aoe(12, 0.9, "fire", { "ignite", 0.4 }) } })),
	st("죽음의 폐광", "sea", { { "defias_blackguard", 50 }, { "defias_pirate_2", 50 } },
		B("에드윈 밴클리프", "INV_Misc_Head_Human_01", "humanoid", 1500, 16, 0.6, { school = "fire", res = { fire = 75, frost = -25 }, skills = { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(24, "defias_blackguard_2", 3), enrage(0.25, 1.4) } })),
	-- Act 2: 검은심연 나락
	st("그림자송곳니 성채", "shadow", { { "bleak_worg", 35 }, { "slavering_worg", 35 }, { "shadowfang_darksoul", 30 } },
		B("레실고어", "INV_Misc_MonsterFang_01", "humanoid", 420, 10, 0.7, { skills = { smash(9, 2.2) } })),
	st("그림자송곳니 성채", "shadow", { { "shadowfang_moonwalker", 35 }, { "haunted_servitor", 30 }, { "slavering_worg_2", 35 } },
		B("늑대왕 난도스", "Ability_Hunter_Pet_Wolf", "humanoid", 480, 12, 0.9, { skills = { smash(8, 2), summon(18, "bleak_worg_2", 2) } })),
	st("그림자송곳니 성채", "shadow", { { "shadowfang_ragetooth", 35 }, { "shadowfang_darksoul_2", 30 }, { "haunted_servitor_2", 35 } },
		B("남작 실버레인", "INV_Misc_MonsterFang_01", "undead", 560, 12, 0.7, { skills = { smash(9, 2.3), aoe(14, 0.8, "nature", { "stun", 0.25 }) } })),
	st("그림자송곳니 성채", "shadow", { { "son_of_arugal", 40 }, { "shadowfang_darksoul_3", 30 }, { "vile_bat", 30 } },
		B("대마법사 아루갈", "Spell_Holy_MagicalSentry", "humanoid", 680, 12, 0.5, { res = { fire = -30, nature = 50 }, skills = { smash(8, 2.6), shield(22, 6, 60) } })),
	st("스톰윈드 지하감옥", "ruins", { { "defias_insurgent", 40 }, { "defias_convict", 35 }, { "defias_inmate", 25 } },
		B("캄 딥퓨리", "INV_Misc_Head_Dwarf_02", "humanoid", 540, 14, 0.8, { school = "nature", range = 420, skills = { aoe(10, 1, "nature", { "shock", 0.5 }) } })),
	st("스톰윈드 지하감옥", "ruins", { { "defias_captive", 30 }, { "defias_prisoner", 35 }, { "defias_convict_2", 35 } },
		B("바질 스레드", "INV_Misc_Head_Human_01", "humanoid", 620, 14, 0.9, { skills = { smash(8, 2.2), summon(18, "defias_inmate_2", 2) } })),
	st("검은심연 나락", "sea", { { "akumai_snapjaw", 25 }, { "blackfathom_myrmidon", 40 }, { "twilight_elementalist", 35 } },
		B("가무라", "Ability_Hunter_Pet_Crab", "beast", 820, 15, 0.5, { skills = { smash(7, 2.8), enrage(0.3, 1.4) } })),
	st("검은심연 나락", "sea", { { "murkshallow_snapclaw", 40 }, { "twilight_acolyte", 30 }, { "akumai_fisher", 30 } },
		B("여왕 사레베스", "INV_Misc_MonsterScales_03", "humanoid", 760, 14, 0.8, { skills = { aoe(12, 0.9, "nature", { "poison", 0.6 }), summon(16, "blackfathom_myrmidon_2", 3) } })),
	st("검은심연 나락", "shadow", { { "twilight_reaver", 30 }, { "blackfathom_myrmidon_3", 40 }, { "snapping_crustacean", 30 } },
		B("황혼의 군주 켈리스", "Spell_Shadow_ShadowWordPain", "humanoid", 900, 16, 0.6, { skills = { smash(8, 2.6), shield(20, 6, 70), enrage(0.3, 1.3) } })),
	st("검은심연 나락", "sea", { { "akumai_servant", 40 }, { "blackfathom_sea_witch", 60 } },
		B("아쿠마이", "Ability_Hunter_Pet_Crocolisk", "aberration", 1900, 15, 0.7, { school = "shadow", res = { shadow = 50 }, skills = { aoe(9, 1, "shadow"), summon(18, "blackfathom_tide_priestess", 2), shield(30, 7, 75), enrage(0.2, 1.5) } })),
	-- Act 3: 붉은십자군 수도원
	st("놈리건", "cave", { { "caverndeep_burrower", 35 }, { "irradiated_pillager", 35 }, { "mechano_frostwalker", 30 } },
		B("그루비스", "INV_Misc_Head_Kobold_01", "humanoid", 700, 13, 0.6, { res = { frost = 50 }, skills = { smash(8, 2.5, nil, { "stun", 0.5 }) } })),
	st("놈리건", "cave", { { "leprous_defender", 40 }, { "leprous_technician", 30 }, { "mechano_frostwalker", 30 } },
		B("방사성 폐기물", "INV_Misc_Slime_01", "elemental", 760, 14, 0.6, { school = "frost", res = { fire = -30, frost = 75 }, skills = { aoe(10, 1, "frost", { "chill", 1 }) } })),
	st("놈리건", "cave", { { "irradiated_horror", 35 }, { "arcane_nullifier_x_21", 30 }, { "mechano_tank", 35 } },
		B("기계화 문지기 6000", "INV_Gizmo_02", "mechanical", 980, 14, 0.5, { skills = { smash(7, 2.6), aoe(14, 0.8, "nature", { "poison", 0.6 }) } })),
	st("놈리건", "cave", { { "dark_iron_agent", 30 }, { "mechanized_sentry", 40 }, { "leprous_machinesmith", 30 } },
		B("기계박사 텔마플러그", "INV_Gizmo_02", "mechanical", 800, 16, 0.6, { school = "shadow", range = 430, skills = { aoe(9, 1, "shadow"), summon(14, "walking_bomb", 3) } })),
	st("가시덩굴 우리", "jungle", { { "razorfen_defender", 35 }, { "kraul_bat", 35 }, { "deaths_head_acolyte", 30 } },
		B("죽음예언자 잘그바", "Spell_Shadow_ShadowBolt", "humanoid", 940, 16, 0.8, { school = "shadow", skills = { smash(8, 2.3), summon(16, "razorfen_servitor", 3), enrage(0.3, 1.3) } })),
	st("가시덩굴 우리", "jungle", { { "tomb_fiend", 30 }, { "razorfen_geomancer", 35 }, { "razorfen_beastmaster", 35 } },
		B("서슬깃 차를가", "INV_Misc_Head_Quillboar_01", "humanoid", 1100, 16, 0.7, { school = "shadow", res = { shadow = 50 }, skills = { aoe(8, 1.1, "shadow"), enrage(0.35, 1.5) } })),
	st("붉은십자군 수도원", "holy", { { "scarlet_gallant", 40 }, { "scarlet_conjuror", 30 }, { "scarlet_beastmaster", 30 } },
		B("신비술사 도안", "Spell_Holy_MagicalSentry", "humanoid", 1150, 17, 0.7, { res = { fire = 50 }, skills = { smash(8, 2.4), aoe(11, 1, "fire", { "ignite", 0.6 }) } })),
	st("붉은십자군 수도원", "holy", { { "scarlet_myrmidon", 40 }, { "scarlet_champion", 30 }, { "scarlet_evoker", 30 } },
		B("헤로드", "Spell_Holy_Excorcism", "humanoid", 1400, 18, 0.7, { school = "fire", res = { fire = 60 }, skills = { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "scarlet_trainee", 2) } })),
	st("붉은십자군 수도원", "holy", { { "scarlet_monk", 35 }, { "scarlet_centurion", 30 }, { "scarlet_defender", 35 } },
		B("붉은십자군 사령관 모그레인", "Spell_Shadow_DeathCoil", "humanoid", 1700, 17, 1, { skills = { smash(5, 2.6), enrage(0.2, 1.6) } })),
	st("붉은십자군 수도원", "holy", { { "scarlet_champion_2", 50 }, { "scarlet_abbot", 50 } },
		B("종교재판관 화이트메인", "Spell_Holy_Excorcism", "humanoid", 2400, 17, 0.7, { school = "frost", res = { frost = 60, shadow = 40 }, range = 600, skills = { aoe(8, 1.1, "frost", { "chill", 1 }), smash(10, 2.4, "shadow", { "freeze", 1 }), summon(16, "scarlet_chaplain", 3), shield(32, 6, 70), enrage(0.2, 1.5) } })),
})

------------------------------------------------------------------------
-- Heroic: Razorfen Downs to Blackrock Depths
------------------------------------------------------------------------
ns.STAGES[2] = finish({
	-- Act 1: 울다만
	st("가시덩굴 구릉", "shadow", { { "withered_warrior", 40 }, { "withered_battle_boar", 35 }, { "boneflayer_ghoul", 25 } },
		X("투텐카쉬", "Ability_Hunter_Pet_Boar", "undead", "brute", { smash(8, 2.5), enrage(0.3, 1.3) }, { school = "fire" })),
	st("가시덩굴 구릉", "shadow", { { "splinterbone_warrior", 45 }, { "deaths_head_necromancer", 30 }, { "withered_battle_boar", 25 } },
		X("불꽃눈 모드레쉬", "Spell_Fire_Elemental_Totem", "undead", "lord", { smash(8, 2.2), summon(18, "skeletal_summoner", 2) })),
	st("가시덩굴 구릉", "ice", { { "splinterbone_captain", 35 }, { "skeletal_frostweaver", 35 }, { "withered_reaver", 30 } },
		X("혹한의 암네나르", "Spell_Frost_FrostArmor02", "undead", "caster", { aoe(9, 1, "shadow"), smash(12, 2.2, "fire", { "ignite", 1 }) }, { school = "shadow" })),
	st("울다만", "cave", { { "stonevault_brawler", 45 }, { "shadowforge_ruffian", 30 }, { "shadowforge_sharpshooter", 25 } },
		X("레벨로쉬", "INV_Misc_Head_Kobold_01", "humanoid", "swift", { smash(6, 2, nil, { "bleed", 1 }), aoe(13, 0.9, "phys") })),
	st("울다만", "cave", { { "stonevault_geomancer", 35 }, { "earthen_rocksmasher", 25 }, { "jadespine_basilisk", 40 } },
		X("아이로나야", "Spell_Nature_Earthquake", "giant", "brute", { smash(8, 2.3), aoe(12, 0.8, "nature", { "poison", 0.6 }) }, { res = { fire = -25, nature = 50 } })),
	st("울다만", "cave", { { "shadowforge_ambusher", 40 }, { "shadowforge_surveyor", 30 }, { "venomlash_scorpid", 30 } },
		X("그림로크", "INV_Misc_Head_Kobold_01", "humanoid", "brute", { smash(7, 2.6), aoe(13, 0.8, "nature", { "poison", 0.7 }) })),
	st("울다만", "ruins", { { "earthen_guardian", 35 }, { "earthen_sculptor", 30 }, { "stone_keeper", 35 } },
		X("갈간 파이어해머", "Spell_Fire_Elemental_Totem", "humanoid", "lord", { smash(8, 2.4), enrage(0.35, 1.4), shield(24, 6, 55) })),
	st("울다만", "ruins", { { "stonevault_oracle", 35 }, { "shrike_bat", 35 }, { "stonevault_ambusher", 30 } },
		X("밸로그", "INV_Misc_Head_Dwarf_02", "humanoid", "swift", { smash(7, 2.1), shield(22, 6, 60) })),
	st("울다만", "ruins", { { "earthen_hallshaper", 40 }, { "earthen_sculptor_2", 35 }, { "vault_warder", 25 } },
		X("흑요석 파수꾼", "INV_Misc_AhnQirajTrinket_04", "mechanical", "caster", { aoe(8, 1.1, "arcane"), smash(12, 2, "arcane", { "stun", 0.6 }) }, { school = "arcane" })),
	st("울다만", "ruins", { { "earthen_guardian_2", 50 }, { "earthen_custodian", 50 } },
		X("아카에다스", "Spell_Nature_Earthquake", "giant", "brute", { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(11, 2.6), summon(22, "vault_warder_2", 2), enrage(0.25, 1.4) }, { school = "fire", res = { fire = 60, shadow = 40 } })),
	-- Act 2: 마라우돈
	st("줄파락", "desert", { { "sullithuz_abomination", 30 }, { "sullithuz_sandcrawler", 35 }, { "sandfury_guardian", 35 } },
		X("가즈릴라", "INV_Misc_MonsterHead_02", "giant", "brute", { smash(7, 2.7), enrage(0.3, 1.4) })),
	st("줄파락", "desert", { { "sandfury_executioner", 40 }, { "sandfury_zealot", 25 }, { "scarab", 35 } },
		X("안투술", "INV_Misc_Head_Troll_01", "humanoid", "lord", { smash(8, 2.4, nil, { "stun", 0.4 }), summon(20, "sullithuz_broodling", 2) })),
	st("줄파락", "desert", { { "zulfarrak_dead_hero", 35 }, { "sandfury_blood_drinker", 65 } },
		X("네크룸 거트츄어", "INV_Misc_Head_Troll_01", "undead", "brute", { smash(7, 2.6), aoe(13, 1, "phys", { "stun", 0.3 }), enrage(0.4, 1.5) })),
	st("줄파락", "desert", { { "sandfury_soul_eater", 35 }, { "sandfury_cretin", 35 }, { "sandfury_acolyte", 30 } },
		X("의술사 줌라", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(9, 1, "arcane"), summon(16, "zulfarrak_zombie", 3) }, { school = "arcane" })),
	st("줄파락", "desert", { { "sandfury_axe_thrower", 35 }, { "sandfury_zealot_2", 35 }, { "sandfury_shadowhunter", 30 } },
		X("족장 우코르즈 샌드스칼프", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(10, 1, "arcane"), summon(18, "sandfury_executioner_2", 2), shield(26, 6, 50) }, { school = "arcane" })),
	st("마라우돈", "jungle", { { "barbed_lasher", 45 }, { "celebrian_dryad", 25 }, { "putridus_satyr", 30 } },
		X("녹시온", "INV_Misc_Slime_01", "elemental", "brute", { smash(8, 2.5), summon(15, "noxxious_scion", 3) }, { res = { fire = -25, nature = 50 } })),
	st("마라우돈", "jungle", { { "putridus_trickster", 30 }, { "putridus_shadowstalker", 35 }, { "deeprot_stomper", 35 } },
		X("군주 바일텅", "Spell_Shadow_UnholyStrength", "demon", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.2, "shadow", { "stun", 0.6 }), enrage(0.3, 1.3) }, { school = "shadow", res = { shadow = 50 } })),
	st("마라우돈", "forest", { { "celebrian_dryad_2", 40 }, { "subterranean_diemetradon", 30 }, { "poison_sprite", 30 } },
		X("저주받은 셀레브라스", "Spell_Nature_Thorns", "humanoid", "lord", { smash(8, 2.4, "shadow"), aoe(11, 1, "fire", { "ignite", 0.5 }), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("마라우돈", "cave", { { "theradrim_guardian", 40 }, { "creeping_sludge", 30 }, { "primordial_behemoth", 30 } },
		X("산사태", "Spell_Nature_Earthquake", "giant", "caster", { aoe(8, 1, "nature", { "shock", 0.5 }), summon(16, "theradrim_shardling", 2), shield(26, 7, 70) }, { school = "nature", res = { frost = 40, nature = 40 } })),
	st("마라우돈", "cave", { { "theradrim_guardian_2", 40 }, { "theradrim_shardling_2", 35 }, { "primordial_behemoth_2", 25 } },
		X("공주 테라드라스", "Spell_Nature_Thorns", "elemental", "caster", { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(12, 2.4, "fire"), summon(22, "theradrim_shardling_3", 2), shield(32, 6, 60), enrage(0.2, 1.3) }, { school = "fire", res = { fire = 60, arcane = 40 } })),
	-- Act 3: 검은바위 나락
	st("아탈학카르 신전", "swamp", { { "atalai_warrior", 30 }, { "nightmare_whelp", 30 }, { "cursed_atalai", 40 } },
		X("아탈알라리온", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(7, 2.7), aoe(13, 1, "phys", { "stun", 0.3 }), enrage(0.25, 1.5) })),
	st("아탈학카르 신전", "swamp", { { "atalai_witch_doctor", 40 }, { "atalai_corpse_eater", 30 }, { "unliving_atalai", 30 } },
		X("예언자 잠말란", "INV_Misc_Head_Troll_01", "humanoid", "brute", { aoe(8, 1.2, "nature"), smash(12, 2.6, nil, { "stun", 0.6 }) }, { school = "nature" })),
	st("아탈학카르 신전", "shadow", { { "nightmare_scalebane", 40 }, { "nightmare_wyrmkin", 35 }, { "nightmare_suppressor", 25 } },
		X("에라니쿠스의 사령", "INV_Misc_Head_Dragon_Black", "dragonkin", "lord", { smash(8, 2.4), aoe(11, 1, "arcane", { "chill", 0.6 }) }, { school = "arcane" })),
	st("검은바위 나락", "lava", { { "burning_spirit", 40 }, { "fireguard", 35 }, { "bloodhound", 25 } },
		X("밸가르", "Spell_Fire_Elemental_Totem", "giant", "brute", { smash(7, 2.6), aoe(12, 1, "arcane"), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 50 } })),
	st("검은바위 나락", "lava", { { "anvilrage_guardsman", 35 }, { "ragereaver_golem", 30 }, { "blazing_fireguard", 35 } },
		X("불의 군주 인센디우스", "Spell_Fire_Elemental_Totem", "elemental", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(11, 2.6, "shadow"), summon(20, "fireguard_destroyer", 1), enrage(0.2, 1.5) }, { school = "shadow", res = { fire = 50, shadow = 50 } })),
	st("검은바위 나락", "lava", { { "doomforge_dragoon", 35 }, { "bloodhound_mastiff", 35 }, { "twilight_emissary", 30 } },
		X("사령관 앵거포지", "INV_Misc_Head_Dwarf_02", "humanoid", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), aoe(12, 1, "nature", { "shock", 0.5 }), enrage(0.4, 1.4) })),
	st("검은바위 나락", "lava", { { "anvilrage_warden", 35 }, { "twilight_bodyguard", 35 }, { "wrath_hammer_construct", 30 } },
		X("골렘 군주 아젤마크", "Spell_Shadow_AbominationExplosion", "humanoid", "swift", { smash(6, 2.3, "shadow"), aoe(10, 1.1, "fire", { "ignite", 0.6 }), shield(28, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { fire = 40, shadow = 50 } })),
	st("검은바위 나락", "lava", { { "anvilrage_officer", 35 }, { "doomforge_arcanasmith", 35 }, { "burning_spirit_2", 30 } },
		X("사자 화염채찍", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(9, 1, "holy"), summon(16, "burning_spirit_3", 2), shield(24, 6, 60) }, { school = "holy" })),
	st("검은바위 나락", "lava", { { "anvilrage_soldier", 30 }, { "shadowforge_flame_keeper", 30 }, { "twilights_hammer_executioner", 40 } },
		X("마그무스", "Spell_Fire_Elemental_Totem", "giant", "brute", { smash(5, 2.6, "fire", { "ignite", 1 }), aoe(12, 1.1, "fire"), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60 } })),
	st("검은바위 나락", "lava", { { "anvilrage_marshal", 50 }, { "ironhand_guardian", 50 } },
		X("제왕 다그란 타우릿산", "INV_Misc_Head_Dwarf_02", "humanoid", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(10, 2.5, "shadow"), summon(18, "shadowforge_senator", 3), shield(30, 6, 70), enrage(0.2, 1.5) }, { school = "shadow", res = { fire = 60, shadow = 60 }, range = 600 })),
})

------------------------------------------------------------------------
-- Mythic: Blackrock Spire, Dire Maul, the Plaguelands, Ahn'Qiraj and Zul'Gurub
------------------------------------------------------------------------
ns.STAGES[3] = finish({
	-- Act 1: 검은바위 첨탑
	st("검은바위 첨탑 하층", "lava", { { "spirestone_enforcer", 35 }, { "bloodaxe_worg", 25 }, { "smolderthorn_berserker", 40 } },
		X("어둠사냥꾼 보쉬가진", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(9, 1, "shadow"), summon(16, "smolderthorn_berserker", 3) }, { school = "shadow" })),
	st("검은바위 첨탑 하층", "lava", { { "spirestone_battle_mage", 35 }, { "spirestone_reaver", 30 }, { "smolderthorn_axe_thrower", 35 } },
		X("대영주 오모크", "Ability_Smash", "humanoid", "brute", { smash(8, 2.4, "frost", { "chill", 1 }), aoe(11, 1, "frost", { "freeze", 0.3 }), enrage(0.25, 1.4) }, { school = "frost", res = { fire = -25, frost = 60 } })),
	st("검은바위 첨탑 하층", "cave", { { "spirestone_ogre_magus", 40 }, { "spire_spider", 30 }, { "firebrand_pyromancer", 30 } },
		X("여왕 불그물거미", "Ability_Hunter_Pet_Spider", "beast", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(18, "spire_spiderling", 3) })),
	st("검은바위 첨탑 하층", "lava", { { "firebrand_grunt", 45 }, { "firebrand_invoker", 30 }, { "firebrand_dreadweaver", 25 } },
		X("우로크 둠하울", "Ability_Smash", "humanoid", "brute", { smash(7, 2.6, nil, { "stun", 0.4 }), aoe(13, 1, "shadow"), enrage(0.5, 1.3) })),
	st("검은바위 첨탑 하층", "lava", { { "bloodaxe_veteran", 35 }, { "bloodaxe_evoker", 35 }, { "bloodaxe_summoner", 30 } },
		X("대군주 웜타라크", "INV_Misc_Head_Dragon_Black", "dragonkin", "lord", { smash(8, 2.5), aoe(11, 1, "shadow"), summon(20, "bloodaxe_veteran", 2) })),
	st("검은바위 첨탑 상층", "lava", { { "rage_talon_dragon_guard", 25 }, { "chromatic_whelp", 35 }, { "blackhand_veteran", 40 } },
		X("불의 수호자 엠버시어", "Spell_Fire_Elemental_Totem", "elemental", "brute", { smash(7, 2.8), enrage(0.3, 1.4) })),
	st("검은바위 첨탑 상층", "lava", { { "blackhand_elite", 50 }, { "blackhand_assassin", 30 }, { "blackhand_dreadweaver", 20 } },
		X("대족장 렌드 블랙핸드", "INV_Misc_Head_Orc_01", "humanoid", "brute", { smash(8, 2.5, nil, { "poison", 1 }), summon(15, "blackhand_elite", 3), shield(26, 6, 65) })),
	st("검은바위 첨탑 상층", "lava", { { "blackhand_summoner", 35 }, { "blackhand_thug", 40 }, { "blackhand_iron_guard", 25 } },
		X("군주 발타라크", "INV_Misc_Head_Orc_01", "humanoid", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.6 }), enrage(0.3, 1.4) }, { school = "shadow", res = { shadow = 60 } })),
	st("검은바위 첨탑 상층", "lava", { { "rage_talon_dragonspawn", 40 }, { "rage_talon_flamescale", 35 }, { "rage_talon_fire_tongue", 25 } },
		X("괴수", "INV_Misc_MonsterFang_02", "beast", "brute", { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "rage_talon_flamescale", 1) }, { school = "fire", res = { fire = 60 } })),
	st("검은바위 첨탑 상층", "lava", { { "blackhand_dragon_handler", 50 }, { "chromatic_elite_guard", 50 } },
		X("사령관 드라키사스", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "arcane"), smash(11, 2.6, "frost", { "chill", 1 }), summon(20, "chromatic_elite_guard_2", 2), shield(30, 6, 70), enrage(0.2, 1.5) }, { school = "arcane", res = { frost = 60, arcane = 60 }, range = 600 })),
	-- Act 2: 혈투와 역병
	st("혈투의 전장", "forest", { { "warpwood_crusher", 35 }, { "wildspawn_rogue", 35 }, { "wildspawn_betrayer", 30 } },
		X("제브림 쏜후프", "Spell_Shadow_UnholyStrength", "demon", "brute", { smash(7, 2.7, nil, { "bleed", 1 }), enrage(0.35, 1.5) })),
	st("혈투의 전장", "forest", { { "warpwood_stomper", 40 }, { "wildspawn_satyr", 30 }, { "warpwood_tangler", 30 } },
		X("칼날바람 알진", "Spell_Shadow_UnholyStrength", "demon", "caster", { aoe(9, 1.1, "shadow"), smash(12, 2.3, "nature", { "poison", 1 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("혈투의 전장", "arcane", { { "eldreth_spectre", 40 }, { "highborne_summoner", 30 }, { "skeletal_highborne", 30 } },
		X("이몰타르", "Spell_Holy_MagicalSentry", "demon", "lord", { smash(8, 2.5), summon(16, "arcane_aberration", 3), enrage(0.3, 1.4) })),
	st("혈투의 전장", "ruins", { { "gordok_brute", 35 }, { "gordok_mage_lord", 35 }, { "gordok_mastiff", 30 } },
		X("왕 고르독", "Ability_Smash", "humanoid", "swift", { smash(6, 2.3), aoe(12, 1, "phys", { "stun", 0.3 }), enrage(0.5, 1.3) })),
	st("스트라솔름", "holy", { { "crimson_gallant", 40 }, { "crimson_defender", 25 }, { "crimson_monk", 35 } },
		X("발나자르", "Spell_Shadow_SummonFelHunter", "demon", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(16, "crimson_initiate", 3) })),
	st("스트라솔름", "shadow", { { "skeletal_berserker", 40 }, { "thuzadin_shadowcaster", 35 }, { "wailing_banshee", 25 } },
		X("남작부인 아나스타리", "Spell_Shadow_Charm", "undead", "caster", { aoe(8, 1.1, "arcane"), smash(11, 2.4, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 60 } })),
	st("스트라솔름", "shadow", { { "black_guard_sentry", 40 }, { "patchwork_horror", 25 }, { "venom_belcher", 35 } },
		X("남작 리븐데어", "Spell_Shadow_DeathCoil", "undead", "lord", { smash(8, 2.5, "nature", { "shock", 1 }), aoe(10, 1.1, "nature", { "stun", 0.25 }), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("스칼로맨스", "ruins", { { "scholomance_student", 35 }, { "reanimated_corpse", 30 }, { "scholomance_necromancer", 35 } },
		X("라스 프로스트위스퍼", "Spell_Frost_FrostArmor02", "undead", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), shield(26, 6, 60) }, { school = "nature", res = { nature = 70 } })),
	st("스칼로맨스", "ruins", { { "scholomance_handler", 40 }, { "risen_construct", 35 }, { "risen_guard", 25 } },
		X("잔다이스 바로브", "Spell_Shadow_AnimateDead", "undead", "lord", { smash(8, 2.5), summon(14, "illusion_of_jandice_barov", 3), enrage(0.3, 1.4) }, { school = "nature" })),
	st("스칼로맨스", "shadow", { { "risen_construct", 40 }, { "scholomance_dark_summoner", 30 }, { "risen_guard_2", 30 } },
		X("암흑스승 간들링", "Spell_Shadow_ShadowBolt", "humanoid", "caster", { aoe(10, 1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.4 }), summon(20, "risen_guardian", 2), shield(32, 6, 60), enrage(0.2, 1.3) }, { school = "shadow", res = { shadow = 60 } })),
	-- Act 3: 안퀴라즈와 줄구룹
	st("안퀴라즈 폐허", "desert", { { "hivezara_soldier", 40 }, { "qiraji_warrior", 35 }, { "obsidian_destroyer", 25 } },
		X("쿠린낙스", "Ability_Hunter_Pet_Scorpid", "undead", "lord", { smash(8, 2.5, "shadow"), summon(16, "hivezara_hatchling", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("안퀴라즈 폐허", "desert", { { "qiraji_gladiator", 40 }, { "anubisath_guardian", 30 }, { "flesh_hunter", 30 } },
		X("장군 라작스", "INV_Misc_AhnQirajTrinket_02", "undead", "swift", { smash(6, 2.3, "shadow"), summon(16, "qiraji_warrior_2", 3), shield(26, 6, 60) }, { school = "shadow" })),
	st("안퀴라즈 폐허", "desert", { { "anubisath_guardian_2", 30 }, { "hivezara_stinger", 40 }, { "silicate_feeder", 30 } },
		X("먹보 부루", "INV_Misc_AhnQirajTrinket_04", "beast", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "frost", { "chill", 1 }), enrage(0.3, 1.5) }, { res = { frost = 60 } })),
	st("안퀴라즈 폐허", "ruins", { { "spitting_scarab", 35 }, { "qiraji_swarmguard", 35 }, { "hivezara_tail_lasher", 30 } },
		X("무적의 오시리안", "INV_Misc_AhnQirajTrinket_04", "undead", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.4, "shadow"), summon(18, "hivezara_wasp", 2) }, { school = "shadow", res = { shadow = 60 } })),
	st("줄구룹", "jungle", { { "gurubashi_berserker", 35 }, { "razzashi_raptor", 35 }, { "gurubashi_headhunter", 30 } },
		X("혈군주 만도키르", "INV_Misc_Head_Troll_01", "humanoid", "brute", { smash(7, 2.7, "frost", { "chill", 1 }), aoe(11, 1.1, "frost"), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 60 } })),
	st("줄구룹", "jungle", { { "hakkari_shadow_hunter", 35 }, { "hakkari_shadowcaster", 35 }, { "hakkari_priest", 30 } },
		X("대사제 베녹시스", "Ability_Hunter_Pet_WindSerpent", "humanoid", "lord", { smash(8, 2.5, "shadow"), aoe(10, 1.1, "shadow", { "stun", 0.25 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("줄구룹", "jungle", { { "gurubashi_champion", 40 }, { "hakkari_oracle", 30 }, { "gurubashi_bat_rider", 30 } },
		X("대여사제 제클릭", "INV_Misc_Head_Troll_01", "humanoid", "brute", { smash(6, 2.6), aoe(11, 1.2, "frost", { "chill", 0.6 }), enrage(0.3, 1.5) })),
	st("줄구룹", "jungle", { { "gurubashi_berserker_2", 35 }, { "zulian_prowler", 35 }, { "razzashi_venombrood", 30 } },
		X("대여사제 말리", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "spawn_of_marli", 2), shield(28, 6, 65), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("줄구룹", "jungle", { { "hakkari_witch_doctor", 35 }, { "hakkari_blood_priest", 35 }, { "gurubashi_champion_2", 30 } },
		X("대사제 데칼", "INV_Misc_Head_Troll_01", "humanoid", "brute", { aoe(8, 1.2, "frost", { "chill", 1 }), smash(11, 2.7, "frost", { "freeze", 1 }), enrage(0.25, 1.6) }, { school = "frost", res = { fire = -20, frost = 80 } })),
	st("줄구룹", "jungle", { { "gurubashi_warrior", 50 }, { "hakkari_shadowcaster", 50 } },
		X("학카르", "INV_Misc_Head_Troll_01", "undead", "lord", { aoe(8, 1.2, "shadow"), smash(9, 2.7, "frost", { "freeze", 0.7 }), summon(16, "son_of_hakkar", 3), shield(30, 6, 70), enrage(0.2, 1.6) }, { school = "frost", res = { frost = 60, shadow = 60 } })),
})

------------------------------------------------------------------------
-- Mythic+: the raids, from Molten Core to Naxxramas
------------------------------------------------------------------------
ns.STAGES[4] = finish({
	-- Act 1: 화산 심장부
	st("화산 심장부", "lava", { { "flameguard", 40 }, { "flamewaker_priest", 30 }, { "core_hound", 30 } },
		X("마그마다르", "Spell_Fire_Elemental_Totem", "beast", "brute", { aoe(8, 1.1, "fire", { "ignite", 0.7 }), smash(11, 2.6, "fire"), enrage(0.3, 1.4) }, { school = "fire", res = { fire = 70, frost = -25 } })),
	st("화산 심장부", "lava", { { "flamewaker", 40 }, { "flamewaker_healer", 30 }, { "firewalker", 30 } },
		X("루시프론", "Spell_Fire_Elemental_Totem", "humanoid", "brute", { smash(7, 2.7, "shadow"), summon(16, "flamewaker_protector", 2), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("화산 심장부", "lava", { { "flamewaker_elite", 35 }, { "flamewaker_priest_2", 35 }, { "firewalker_2", 30 } },
		X("게헨나스", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(8, 1.2, "frost", { "chill", 1 }), summon(16, "flamewaker", 2), shield(26, 6, 65) }, { school = "frost", res = { frost = 60 } })),
	st("화산 심장부", "lava", { { "molten_giant", 30 }, { "firelord", 35 }, { "flameguard", 35 } },
		X("가르", "Spell_Fire_Elemental_Totem", "elemental", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "nature"), shield(26, 6, 65) }, { res = { phys = 20, nature = 60 } })),
	st("화산 심장부", "lava", { { "molten_destroyer", 35 }, { "flamewaker_2", 35 }, { "firelord_2", 30 } },
		X("샤즈라", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.5, "nature", { "stun", 0.6 }), summon(16, "flamewaker_elite_2", 3) }, { school = "shadow" })),
	st("화산 심장부", "lava", { { "flamewaker_protector_2", 40 }, { "firewalker_3", 30 }, { "core_rager", 30 } },
		X("설퍼론 선구자", "Spell_Fire_Elemental_Totem", "humanoid", "lord", { smash(8, 2.6, "shadow"), summon(16, "flamewaker_priest_3", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("화산 심장부", "lava", { { "flamewaker_elite_3", 35 }, { "flamewaker_healer_2", 40 }, { "firelord", 25 } },
		X("남작 게돈", "Spell_Fire_Elemental_Totem", "elemental", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), enrage(0.3, 1.5) }, { school = "nature", res = { nature = 70 } })),
	st("화산 심장부", "lava", { { "firewalker_4", 35 }, { "flameguard", 35 }, { "flamewaker_priest", 30 } },
		X("초열의 골레마그", "Spell_Shadow_AbominationExplosion", "giant", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "fire", { "ignite", 0.6 }), summon(18, "core_rager_2", 2), enrage(0.25, 1.5) }, { school = "shadow", res = { fire = 50, shadow = 50 } })),
	st("화산 심장부", "lava", { { "flamewaker_elite_4", 40 }, { "molten_giant_2", 25 }, { "lava_annihilator", 35 } },
		X("청지기 이그젝큐투스", "Spell_Fire_Elemental_Totem", "humanoid", "swift", { smash(5, 2.4, "fire", { "ignite", 1 }), aoe(11, 1.2, "fire"), enrage(0.4, 1.5) }, { school = "fire", res = { fire = 70 } })),
	st("화산 심장부", "lava", { { "firelord_3", 50 }, { "molten_destroyer_2", 50 } },
		X("라그나로스", "Spell_Fire_Elemental_Totem", "elemental", "brute", { aoe(9, 1.05, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(20, "son_of_flame", 2), shield(32, 6, 60), enrage(0.2, 1.4) }, { school = "fire", res = { fire = 70, shadow = 50 } })),
	-- Act 2: 검은날개와 안퀴라즈
	st("오닉시아의 둥지", "cave", { { "onyxian_warder", 40 }, { "onyxian_whelp", 30 }, { "onyxian_drake", 30 } },
		X("오닉시아", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "shadow"), summon(16, "onyxian_whelp_2", 2), shield(26, 6, 65) }, { school = "shadow", res = { shadow = 70 } })),
	st("검은날개 둥지", "lava", { { "blackwing_mage", 40 }, { "blackwing_warlock", 30 }, { "blackwing_legionnaire", 30 } },
		X("타락한 밸라스트라즈", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "frost", { "chill", 0.7 }), smash(12, 2.5, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "frost", res = { frost = 60 } })),
	st("검은날개 둥지", "lava", { { "death_talon_hatcher", 45 }, { "blackwing_taskmaster", 30 }, { "death_talon_dragonspawn", 25 } },
		X("폭군 서슬송곳니", "INV_Misc_Head_Dragon_Black", "dragonkin", "swift", { smash(6, 2.3), summon(13, "blackwing_legionnaire_2", 3), enrage(0.3, 1.4) })),
	st("검은날개 둥지", "lava", { { "blackwing_technician", 40 }, { "death_talon_seether", 35 }, { "blackwing_guardsman", 25 } },
		X("용기대장 래쉬레이어", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7), aoe(11, 1.2, "nature", { "stun", 0.3 }), summon(18, "death_talon_wyrmguard", 2) }, { res = { nature = 50 } })),
	st("검은날개 둥지", "lava", { { "death_talon_flamescale", 40 }, { "death_talon_wyrmguard_2", 25 }, { "death_talon_captain", 35 } },
		X("크로마구스", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "shadow"), enrage(0.4, 1.6) }, { school = "shadow", res = { shadow = 70 } })),
	st("검은날개 둥지", "lava", { { "blackwing_spellbinder", 35 }, { "death_talon_wyrmkin", 35 }, { "chromatic_drakonid", 30 } },
		X("네파리안", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(6, 2.8, nil, { "stun", 0.4 }), summon(16, "chromatic_drakonid_2", 2), shield(26, 6, 65), enrage(0.3, 1.5) })),
	st("안퀴라즈 사원", "shadow", { { "vekniss_soldier", 40 }, { "vekniss_wasp", 30 }, { "qiraji_mindslayer", 30 } },
		X("예언자 스케람", "INV_Misc_AhnQirajTrinket_02", "beast", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "vekniss_warrior", 2), shield(26, 6, 65) }, { school = "nature", res = { nature = 60 } })),
	st("안퀴라즈 사원", "shadow", { { "vekniss_warrior", 45 }, { "vekniss_stinger", 30 }, { "vekniss_drone", 25 } },
		X("공주 후후란", "Spell_Nature_InsectSwarm", "beast", "lord", { smash(7, 2.6, nil, { "poison", 1 }), aoe(10, 1.2, "shadow", { "stun", 0.3 }), summon(18, "vekniss_hive_crawler", 3), enrage(0.3, 1.5) }, { school = "shadow" })),
	st("안퀴라즈 사원", "shadow", { { "qiraji_champion", 35 }, { "obsidian_eradicator", 30 }, { "anubisath_defender", 35 } },
		X("제왕 베크닐라쉬", "INV_Misc_AhnQirajTrinket_02", "humanoid", "lord", { aoe(7, 1.3, "nature", { "shock", 0.7 }), smash(10, 2.7, "nature", { "stun", 0.5 }), shield(28, 6, 70), enrage(0.25, 1.5) }, { school = "nature", res = { nature = 80 } })),
	st("안퀴라즈 사원", "shadow", { { "anubisath_warder", 45 }, { "obsidian_nullifier", 30 }, { "eye_tentacle", 25 } },
		X("크툰", "INV_Misc_Eye_01", "humanoid", "lord", { smash(8, 2.4, nil, { "bleed", 0.6 }), aoe(11, 1.05, "shadow"), summon(20, "claw_tentacle", 2), shield(32, 6, 55), enrage(0.2, 1.4) }, { res = { shadow = 40 } })),
	-- Act 3: 낙스라마스
	st("낙스라마스", "ice", { { "naxxramas_cultist", 40 }, { "crypt_reaver", 30 }, { "necro_knight", 30 } },
		X("귀부인 팰리나", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(7, 1.3, "frost", { "chill", 1 }), smash(11, 2.6, "nature", { "shock", 1 }), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 70, nature = 50 } })),
	st("낙스라마스", "ice", { { "tomb_horror", 30 }, { "necro_stalker", 35 }, { "venom_stalker", 35 } },
		X("아눕레칸", "Spell_Shadow_RaiseDead", "undead", "brute", { aoe(8, 1.3, "nature", { "poison", 0.7 }), smash(11, 2.7, "shadow"), summon(18, "crypt_guard", 2) }, { school = "nature", res = { nature = 70 } })),
	st("낙스라마스", "ice", { { "plagued_gargoyle", 40 }, { "plague_beast", 30 }, { "infectious_ghoul", 30 } },
		X("사피론", "INV_Misc_Head_Dragon_Black", "undead", "caster", { aoe(7, 1.3, "shadow"), smash(11, 2.6, "shadow", { "stun", 0.6 }), shield(26, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 70 } })),
	st("낙스라마스", "ice", { { "deathknight", 40 }, { "shade_of_naxxramas", 30 }, { "necropolis_acolyte", 30 } },
		X("훈련교관 라주비어스", "Spell_Shadow_DeathCoil", "undead", "brute", { smash(6, 2.9, nil, { "stun", 0.5 }), aoe(11, 1.2, "nature"), enrage(0.3, 1.5) })),
	st("낙스라마스", "ice", { { "patchwork_golem", 40 }, { "bile_retcher", 30 }, { "sludge_belcher", 30 } },
		X("패치워크", "Spell_Shadow_AbominationExplosion", "undead", "lord", { smash(7, 2.7, "fire", { "ignite", 1 }), aoe(10, 1.2, "fire"), shield(26, 6, 70), enrage(0.3, 1.5) }, { school = "fire" })),
	st("낙스라마스", "ice", { { "carrion_spinner", 35 }, { "dread_creeper", 35 }, { "crypt_reaver_2", 30 } },
		X("맥스나", "Ability_Hunter_Pet_Spider", "beast", "caster", { aoe(7, 1.3, "arcane"), smash(11, 2.6, "arcane", { "freeze", 0.6 }), summon(18, "maexxna_spiderling", 2), shield(28, 6, 70) }, { school = "arcane", res = { arcane = 70 } })),
	st("낙스라마스", "ice", { { "deathknight_captain", 35 }, { "necro_knight_2", 30 }, { "shade_of_naxxramas_2", 35 } },
		X("영혼 착취자 고딕", "Spell_Shadow_DeathCoil", "undead", "caster", { aoe(7, 1.3, "fire", { "ignite", 0.7 }), smash(10, 2.7, "shadow"), summon(16, "unrelenting_trainee", 2), enrage(0.25, 1.6) }, { school = "shadow", res = { fire = 60, shadow = 60 } })),
	st("낙스라마스", "ice", { { "living_monstrosity", 35 }, { "mad_scientist", 35 }, { "stitched_spewer", 30 } },
		X("타디우스", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(6, 2.9), aoe(9, 1.3, "fire"), shield(28, 6, 70), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60, shadow = 60 } })),
	st("낙스라마스", "ice", { { "deathknight_vindicator", 35 }, { "ghost_of_naxxramas", 30 }, { "unholy_staff", 35 } },
		X("대영주 모그레인", "Spell_Shadow_DeathCoil", "undead", "brute", { smash(5, 2.8, "fire", { "ignite", 1 }), aoe(9, 1.3, "fire"), summon(18, "deathknight_cavalier", 2), enrage(0.3, 1.6) }, { school = "fire", res = { fire = 80 } })),
	st("낙스라마스", "ice", { { "deathknight_2", 50 }, { "necro_knight_3", 50 } },
		X("켈투자드", "Spell_Frost_FrostArmor02", "undead", "lord", { aoe(7, 1.4, "shadow"), smash(9, 2.9, "fire", { "ignite", 1 }), summon(15, "soul_weaver", 3), shield(30, 7, 75), enrage(0.2, 1.7) }, { school = "shadow", res = { fire = 70, shadow = 70, arcane = 50 } })),
})

------------------------------------------------------------------------
-- Derived values
------------------------------------------------------------------------
function ns.Stage(diff, idx)
	return ns.STAGES[diff][idx]
end

-- idx: 1..30 (act and stage folded into one running index)
function ns.StageLevel(diff, idx)
	local d = ns.DIFFS[diff]
	return math.min(100, math.floor(d.base + (idx - 1) * d.step))
end

function ns.StageAct(idx)
	return math.floor((idx - 1) / ns.STAGES_PER_ACT) + 1, (idx - 1) % ns.STAGES_PER_ACT + 1
end

function ns.StageLabel(diff, idx)
	local act, n = ns.StageAct(idx)
	return string.format("%d-%d %s", act, n, ns.N(ns.STAGES[diff][idx].name))
end

function ns.MobsPerWave(diff, idx)
	return ns.DIFFS[diff].mobs + math.floor((idx - 1) / (ns.STAGE_COUNT - 1) * 2.5)
end

-- Monsters past level MIGHT.from grow a little faster than the gear the
-- party can wear (chest gear follows the party's level, Systems/Loot.lua).
ns.MIGHT = { from = 25, rate = 0.035 }
function ns.MobMight(l) return math.exp(ns.MIGHT.rate * math.max(0, l - ns.MIGHT.from)) end
function ns.MobHP(base, l)   return base * (1 + 0.25 * (l - 1)) * 1.07 ^ (l - 1) * ns.MobMight(l) end
function ns.MobAtk(base, l)  return base * (1 + 0.12 * (l - 1)) * 1.05 ^ (l - 1) * ns.MobMight(l) end
function ns.MobGold(base, l) return base * (1 + 0.15 * (l - 1)) * 1.04 ^ (l - 1) end
function ns.MobExp(base, l)  return ns.EXP_RATE * base * (1 + 0.20 * (l - 1)) * 1.045 ^ (l - 1) end
ns.EXP_RATE = 1.2 -- every monster's experience

-- Physical mitigation threshold: armor equal to this halves physical damage.
function ns.ArmorK(l)
	return 30 + 20 * l
end
