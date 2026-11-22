-- Stages. Each difficulty is its own world with 3 acts of 10 stages, so the
-- 120 stages are 120 different places:
--   Normal  - Azeroth          Heroic  - Outland
--   Mythic  - Northrend        Mythic+ - the Cataclysm, Pandaria and the Legion
-- A stage is a run of waves that ends with a boss; the 10th stage of an act is
-- a raid boss with its own abilities.
local _, ns = ...

ns.DIFFS = {
	{ name = "일반",   hex = "e8e8e8", base = 1,  step = 1.00, mobs = 1, bossHP = 1.0,
		world = "아제로스",
		acts = { "동부 왕국", "칼림도어", "북녘의 겨울" } },
	{ name = "영웅",   hex = "3ddc5a", base = 32, step = 0.80, mobs = 3, bossHP = 1.5,
		world = "아웃랜드",
		acts = { "지옥불과 습지", "황천의 바람", "어둠달과 태양샘" } },
	{ name = "신화",   hex = "b266ff", base = 57, step = 0.70, mobs = 4, bossHP = 2.0,
		world = "노스렌드",
		acts = { "북풍과 협만", "폭풍과 티탄", "얼음왕관" } },
	{ name = "신화+", hex = "ff9326", base = 79, step = 0.73, mobs = 5, bossHP = 2.6,
		world = "부서진 세계",
		acts = { "대격변", "판다리아", "불타는 군단" } },
}

ns.STAGES_PER_ACT = 10
ns.STAGE_COUNT = 30
ns.WAVES = 10

-- Scenery behind the battle: the colour of the zone.
ns.THEMES = {
	forest = { rgb = { 0.45, 0.85, 0.50 } },
	plains = { rgb = { 0.85, 0.85, 0.50 } },
	jungle = { rgb = { 0.30, 0.75, 0.45 } },
	swamp  = { rgb = { 0.40, 0.75, 0.70 } },
	desert = { rgb = { 0.95, 0.80, 0.50 } },
	snow   = { rgb = { 0.75, 0.90, 1.00 } },
	ice    = { rgb = { 0.55, 0.80, 1.00 } },
	lava   = { rgb = { 1.00, 0.50, 0.30 } },
	fel    = { rgb = { 0.60, 0.95, 0.35 } },
	shadow = { rgb = { 0.70, 0.50, 0.95 } },
	arcane = { rgb = { 0.60, 0.60, 1.00 } },
	cave   = { rgb = { 0.75, 0.65, 0.55 } },
	ruins  = { rgb = { 0.80, 0.80, 0.80 } },
	sea    = { rgb = { 0.40, 0.65, 1.00 } },
	storm  = { rgb = { 0.65, 0.72, 0.85 } },
	holy   = { rgb = { 1.00, 0.90, 0.60 } },
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

-- Normal: stats written out by hand.
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

-- Later worlds: a boss is a build (how it fights) and its abilities; health
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
-- Normal: Azeroth
------------------------------------------------------------------------
ns.STAGES[1] = finish({
	st("엘윈 숲", "forest", { { "kobold", 50 }, { "wolf", 50 } },
		B("들창코", "INV_Misc_Head_Gnoll_01", "humanoid", 150, 7, 0.7)),
	st("서부 몰락지대", "plains", { { "gnoll", 35 }, { "defias", 35 }, { "golem", 30 } },
		B("미치광이 수확기", "INV_Gizmo_02", "mechanical", 240, 8, 0.6)),
	st("죽음의 폐광", "cave", { { "defias", 40 }, { "defias_mage", 30 }, { "goblin", 30 } },
		B("에드윈 밴클리프", "INV_Misc_Head_Human_02", "humanoid", 300, 10, 0.9,
			{ skills = { smash(8, 2.0), summon(18, "defias", 2) } })),
	st("붉은마루 산맥", "desert", { { "orc", 45 }, { "gnoll", 30 }, { "murloc", 25 } },
		B("검은바위 대장", "INV_Misc_Head_Orc_01", "humanoid", 360, 11, 0.7)),
	st("그늘숲", "shadow", { { "skeleton", 35 }, { "worgen", 35 }, { "spider", 30 } },
		B("스티치스", "Spell_Shadow_AbominationExplosion", "undead", 460, 11, 0.6,
			{ skills = { smash(9, 2.2), aoe(13, 0.8, "nature", { "poison", 0.5 }) } })),
	st("가시덤불 골짜기", "jungle", { { "raptor", 35 }, { "troll", 30 }, { "tiger", 35 } },
		B("왕 방갈라쉬", "INV_Misc_Head_Tiger_01", "beast", 440, 13, 1.0,
			{ skills = { smash(8, 2.0), summon(20, "tiger", 2) } })),
	st("저습지", "swamp", { { "croc", 35 }, { "darkiron", 30 }, { "murloc", 35 } },
		B("늪지대의 거대 악어", "Ability_Hunter_Pet_Crocolisk", "beast", 560, 12, 0.6)),
	st("동부 역병지대", "shadow", { { "ghoul", 40 }, { "acolyte", 25 }, { "plaguebat", 35 } },
		B("역병의 군주", "INV_Misc_Head_Scourge_01", "undead", 520, 13, 0.7,
			{ school = "shadow", skills = { aoe(11, 0.9, "shadow"), summon(20, "ghoul", 2) } })),
	st("검은바위 나락", "lava", { { "darkiron_guard", 40 }, { "fire_elemental", 30 }, { "darkiron", 30 } },
		B("제왕 다그란 타우릿산", "INV_Misc_Head_Dwarf_02", "humanoid", 600, 14, 0.8,
			{ skills = { smash(9, 2.2), aoe(12, 0.9, "fire", { "ignite", 0.4 }) } })),
	st("화산 심장부", "lava", { { "core_hound", 50 }, { "fire_elemental", 50 } },
		B("라그나로스", "Spell_Fire_LavaSpawn", "elemental", 1500, 16, 0.6,
			{ school = "fire", res = { fire = 75, frost = -25 }, skills = {
				aoe(9, 1.0, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(24, "son_of_flame", 3), enrage(0.25, 1.4) } })),
	-- Act 2
	st("듀로타", "desert", { { "scorpid", 35 }, { "boar", 35 }, { "quilboar", 30 } },
		B("가시멧돼지 족장", "INV_Misc_Head_Quillboar_01", "humanoid", 420, 10, 0.7)),
	st("불모의 땅", "plains", { { "centaur", 35 }, { "thunder_lizard", 30 }, { "hyena", 35 } },
		B("켄타우로스 칸", "INV_Misc_Head_Centaur_01", "humanoid", 480, 12, 0.9,
			{ skills = { smash(8, 2.0), summon(18, "centaur", 2) } })),
	st("통곡의 동굴", "cave", { { "deviate_raptor", 35 }, { "serpent", 30 }, { "ooze", 35 } },
		B("걸신들린 무타누스", "INV_Misc_Head_Murloc_01", "humanoid", 560, 12, 0.7,
			{ skills = { smash(9, 2.3), aoe(14, 0.8, "nature", { "stun", 0.25 }) } })),
	st("잿빛 골짜기", "forest", { { "furbolg", 40 }, { "satyr", 30 }, { "spider", 30 } },
		B("타락한 고대정령", "Spell_Nature_StoneClawTotem", "elemental", 680, 12, 0.5,
			{ res = { nature = 50, fire = -30 }, skills = { smash(8, 2.6), shield(22, 6, 60) } })),
	st("버섯구름 봉우리", "desert", { { "harpy", 40 }, { "centaur", 35 }, { "hyena", 25 } },
		B("하피 여군주", "Ability_Hunter_Pet_Vulture", "humanoid", 540, 14, 0.8,
			{ range = 420, school = "nature", skills = { aoe(10, 1.0, "nature", { "shock", 0.5 }) } })),
	st("타나리스", "desert", { { "basilisk", 30 }, { "pirate", 35 }, { "sand_troll", 35 } },
		B("남쪽바다 선장", "INV_Misc_Head_Human_01", "humanoid", 620, 14, 0.9,
			{ skills = { smash(8, 2.2), summon(18, "pirate", 2) } })),
	st("운고로 분화구", "jungle", { { "devilsaur", 25 }, { "deviate_raptor", 40 }, { "lava_elemental", 35 } },
		B("폭군 데빌사우루스", "INV_Misc_MonsterFang_02", "beast", 820, 15, 0.5,
			{ skills = { smash(7, 2.8), enrage(0.3, 1.4) } })),
	st("실리더스", "desert", { { "silithid", 40 }, { "cultist", 30 }, { "sandworm", 30 } },
		B("둥지의 여왕", "Spell_Nature_InsectSwarm", "beast", 760, 14, 0.8,
			{ skills = { aoe(12, 0.9, "nature", { "poison", 0.6 }), summon(16, "silithid", 3) } })),
	st("안퀴라즈 폐허", "ruins", { { "anubisath", 30 }, { "qiraji", 40 }, { "silithid", 30 } },
		B("무적의 오시리안", "INV_Misc_AhnQirajTrinket_04", "giant", 900, 16, 0.6,
			{ skills = { smash(8, 2.6), shield(20, 6, 70), enrage(0.3, 1.3) } })),
	st("안퀴라즈 사원", "shadow", { { "anubisath", 40 }, { "qiraji", 60 } },
		B("크툰", "INV_Misc_Eye_01", "aberration", 1900, 15, 0.7,
			{ school = "shadow", res = { shadow = 50 }, skills = {
				aoe(9, 1.0, "shadow"), summon(18, "eye_tentacle", 2), shield(30, 7, 75), enrage(0.2, 1.5) } })),
	-- Act 3
	st("여명의 설원", "snow", { { "yeti", 35 }, { "frostsaber", 35 }, { "frost_elemental", 30 } },
		B("설인 왕", "Ability_Hunter_Pet_Gorilla", "humanoid", 700, 13, 0.6,
			{ res = { frost = 50 }, skills = { smash(8, 2.5, nil, { "stun", 0.5 }) } })),
	st("알터랙 계곡", "snow", { { "frostwolf", 40 }, { "ice_troll", 30 }, { "frost_elemental", 30 } },
		B("서리 군주", "Spell_Frost_Glacier", "elemental", 760, 14, 0.6,
			{ school = "frost", res = { frost = 75, fire = -30 }, skills = { aoe(10, 1.0, "frost", { "chill", 1 }) } })),
	st("서부 역병지대", "shadow", { { "ghoul", 35 }, { "skeleton_mage", 30 }, { "abomination", 35 } },
		B("누더기 감독관", "Spell_Shadow_AbominationExplosion", "undead", 980, 14, 0.5,
			{ skills = { smash(7, 2.6), aoe(14, 0.8, "nature", { "poison", 0.6 }) } })),
	st("스칼로맨스", "ruins", { { "necromancer", 30 }, { "skeleton", 40 }, { "ghost", 30 } },
		B("암흑스승 간들링", "Spell_Shadow_AnimateDead", "humanoid", 800, 16, 0.6,
			{ range = 430, school = "shadow", skills = { aoe(9, 1.0, "shadow"), summon(14, "skeleton", 3) } })),
	st("스트라솔름", "lava", { { "crusader", 35 }, { "gargoyle", 35 }, { "banshee", 30 } },
		B("남작 리븐데어", "Spell_Shadow_DeathCoil", "undead", 940, 16, 0.8,
			{ school = "shadow", skills = { smash(8, 2.3), summon(16, "skeleton", 3), enrage(0.3, 1.3) } })),
	st("저주받은 땅", "fel", { { "voidwalker", 30 }, { "imp", 35 }, { "felhound", 35 } },
		B("군주 카자크", "Spell_Shadow_SummonInfernal", "demon", 1100, 16, 0.7,
			{ school = "shadow", res = { shadow = 50 }, skills = { aoe(8, 1.1, "shadow"), enrage(0.35, 1.5) } })),
	st("검은바위 첨탑", "lava", { { "blackhand", 40 }, { "whelp", 30 }, { "ogre", 30 } },
		B("사령관 드라키사스", "INV_Misc_Head_Dragon_01", "dragonkin", 1150, 17, 0.7,
			{ res = { fire = 50 }, skills = { smash(8, 2.4), aoe(11, 1.0, "fire", { "ignite", 0.6 }) } })),
	st("검은날개 둥지", "lava", { { "dragonkin", 40 }, { "drake", 30 }, { "technician", 30 } },
		B("네파리안", "INV_Misc_Head_Dragon_Black", "dragonkin", 1400, 18, 0.7,
			{ school = "fire", res = { fire = 60 }, skills = {
				aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "dragonkin", 2) } })),
	st("낙스라마스", "ice", { { "crypt_fiend", 35 }, { "death_knight", 30 }, { "abomination", 35 } },
		B("패치워크", "Spell_Shadow_AbominationExplosion", "undead", 1700, 17, 1.0,
			{ skills = { smash(5, 2.6), enrage(0.2, 1.6) } })),
	st("켈투자드의 방", "ice", { { "death_knight", 50 }, { "crypt_fiend", 50 } },
		B("켈투자드", "Spell_Frost_FrostArmor02", "undead", 2400, 17, 0.7,
			{ range = 600, school = "frost", res = { frost = 60, shadow = 40 }, skills = {
				aoe(8, 1.1, "frost", { "chill", 1 }), smash(10, 2.4, "shadow", { "freeze", 1 }),
				summon(16, "frozen_wraith", 3), shield(32, 6, 70), enrage(0.2, 1.5) } })),
})

------------------------------------------------------------------------
-- Heroic: Outland
------------------------------------------------------------------------
ns.STAGES[2] = finish({
	st("지옥불 반도", "fel", { { "fel_orc", 40 }, { "helboar", 35 }, { "ravager", 25 } },
		X("지옥절단기", "INV_Misc_Gear_01", "mechanical", "brute", { smash(8, 2.5), enrage(0.3, 1.3) }, { school = "fire" })),
	st("지옥불 성루", "fel", { { "fel_orc", 45 }, { "fel_orc_warlock", 30 }, { "helboar", 25 } },
		X("감시자 가르골마르", "INV_Misc_Head_Orc_02", "humanoid", "lord", { smash(8, 2.2), summon(18, "fel_orc_warlock", 2) })),
	st("피의 용광로", "lava", { { "fel_orc", 35 }, { "fel_orc_warlock", 35 }, { "shattered_hand", 30 } },
		X("파괴자 켈리단", "Spell_Shadow_ShadowBolt", "humanoid", "caster", { aoe(9, 1.0, "shadow"), smash(12, 2.2, "fire", { "ignite", 1 }) }, { school = "shadow" })),
	st("으스러진 손의 전당", "ruins", { { "shattered_hand", 45 }, { "fel_orc", 30 }, { "fel_orc_warlock", 25 } },
		X("대족장 카르가스", "INV_Misc_Head_Orc_01", "humanoid", "swift", { smash(6, 2.0, nil, { "bleed", 1 }), aoe(13, 0.9, "phys") })),
	st("장가르 습지대", "swamp", { { "sporebat", 35 }, { "bog_lord", 25 }, { "marsh_crab", 40 } },
		X("헝가르펜", "Spell_Nature_StoneClawTotem", "elemental", "brute", { smash(8, 2.3), aoe(12, 0.8, "nature", { "poison", 0.6 }) }, { res = { nature = 50, fire = -25 } })),
	st("강제 노역소", "swamp", { { "naga_myrmidon", 40 }, { "naga_siren", 30 }, { "marsh_crab", 30 } },
		X("쿠아그미란", "Ability_Hunter_Pet_Crocolisk", "beast", "brute", { smash(7, 2.6), aoe(13, 0.8, "nature", { "poison", 0.7 }) })),
	st("증기 저장고", "sea", { { "naga_myrmidon", 35 }, { "naga_siren", 30 }, { "steam_surger", 35 } },
		X("장군 칼리스레쉬", "INV_Misc_MonsterScales_03", "humanoid", "lord", { smash(8, 2.4), enrage(0.35, 1.4), shield(24, 6, 55) })),
	st("테로카르 숲", "forest", { { "arakkoa", 35 }, { "warp_stalker", 35 }, { "sethekk", 30 } },
		X("테로크", "Ability_Hunter_Pet_Owl", "humanoid", "swift", { smash(7, 2.1), shield(22, 6, 60) })),
	st("세데크 전당", "arcane", { { "sethekk", 40 }, { "arakkoa", 35 }, { "phantom_guest", 25 } },
		X("갈퀴대왕 이키스", "Spell_Holy_MagicalSentry", "humanoid", "caster", { aoe(8, 1.1, "arcane"), smash(12, 2.0, "arcane", { "stun", 0.6 }) }, { school = "arcane" })),
	st("마그테리돈의 둥지", "fel", { { "fel_orc", 50 }, { "fel_orc_warlock", 50 } },
		X("마그테리돈", "Spell_Shadow_SummonInfernal", "demon", "brute",
			{ aoe(9, 1.0, "fire", { "ignite", 0.5 }), smash(11, 2.6), summon(22, "hellfire_channeler", 2), enrage(0.25, 1.4) },
			{ school = "fire", res = { fire = 60, shadow = 40 } })),
	-- Act 2
	st("나그란드", "plains", { { "clefthoof", 30 }, { "talbuk", 35 }, { "boulderfist", 35 } },
		X("굶주린 듀른", "INV_Misc_MonsterHead_03", "giant", "brute", { smash(7, 2.7), enrage(0.3, 1.4) })),
	st("칼날 산맥", "desert", { { "boulderfist", 40 }, { "gronnling", 25 }, { "ravager", 35 } },
		X("왕 마울가르", "Ability_Smash", "giant", "lord", { smash(8, 2.4, nil, { "stun", 0.4 }), summon(20, "boulderfist", 2) })),
	st("그룰의 둥지", "cave", { { "gronnling", 35 }, { "boulderfist", 65 } },
		X("용 학살자 그룰", "INV_Misc_MonsterHead_03", "giant", "brute", { smash(7, 2.6), aoe(13, 1.0, "phys", { "stun", 0.3 }), enrage(0.4, 1.5) })),
	st("황천의 폭풍", "arcane", { { "ethereal", 35 }, { "mana_wyrm", 35 }, { "fel_sentry", 30 } },
		X("연합왕자 샤파르", "Spell_Holy_MagicalSentry", "humanoid", "caster", { aoe(9, 1.0, "arcane"), summon(16, "mana_wyrm", 3) }, { school = "arcane" })),
	st("메카나르", "arcane", { { "mechanar_drone", 35 }, { "sunfury_guard", 35 }, { "sunfury_mage", 30 } },
		X("계산기 파탈리온", "INV_Misc_Head_Elf_02", "humanoid", "caster", { aoe(10, 1.0, "arcane"), summon(18, "mechanar_drone", 2), shield(26, 6, 50) }, { school = "arcane" })),
	st("신록의 정원", "jungle", { { "mutate_lasher", 45 }, { "sunfury_mage", 25 }, { "sunfury_guard", 30 } },
		X("차원의 분리자", "Spell_Nature_ForceOfNature", "elemental", "brute", { smash(8, 2.5), summon(15, "mutate_lasher", 3) }, { res = { nature = 50, fire = -25 } })),
	st("알카트라즈", "shadow", { { "ethereal", 30 }, { "voidwalker", 35 }, { "sunfury_guard", 35 } },
		X("선구자 스키리스", "Spell_Shadow_EvilEye", "aberration", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.2, "shadow", { "stun", 0.6 }), enrage(0.3, 1.3) }, { school = "shadow", res = { shadow = 50 } })),
	st("카라잔", "ruins", { { "phantom_guest", 40 }, { "spectral_steed", 30 }, { "mana_wyrm", 30 } },
		X("말체자르 왕자", "Spell_Shadow_SummonInfernal", "demon", "lord", { smash(8, 2.4, "shadow"), aoe(11, 1.0, "fire", { "ignite", 0.5 }), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("불뱀 제단", "sea", { { "naga_myrmidon", 40 }, { "naga_siren", 30 }, { "steam_surger", 30 } },
		X("여군주 바쉬", "Spell_Frost_FrostNova", "humanoid", "caster", { aoe(8, 1.0, "nature", { "shock", 0.5 }), summon(16, "naga_myrmidon", 2), shield(26, 7, 70) }, { school = "nature", res = { nature = 40, frost = 40 } })),
	st("폭풍우 요새", "arcane", { { "sunfury_guard", 40 }, { "sunfury_mage", 35 }, { "mechanar_drone", 25 } },
		X("캘타스 선스트라이더", "Spell_Fire_FlameBolt", "humanoid", "caster",
			{ aoe(9, 1.0, "fire", { "ignite", 0.5 }), smash(12, 2.4, "fire"), summon(22, "phoenix", 2), shield(32, 6, 60), enrage(0.2, 1.3) },
			{ school = "fire", res = { fire = 60, arcane = 40 } })),
	-- Act 3
	st("어둠달 골짜기", "fel", { { "fel_orc", 30 }, { "nether_drake", 30 }, { "wrathguard", 40 } },
		X("파멸의 절단기", "INV_Misc_Gear_02", "mechanical", "brute", { smash(7, 2.7), aoe(13, 1.0, "phys", { "stun", 0.3 }), enrage(0.25, 1.5) })),
	st("어둠의 미궁", "shadow", { { "cabal_cultist", 40 }, { "wrathguard", 30 }, { "voidwalker", 30 } },
		X("울림", "Spell_Nature_Earthquake", "elemental", "brute", { aoe(8, 1.2, "nature"), smash(12, 2.6, nil, { "stun", 0.6 }) }, { school = "nature" })),
	st("옛 언덕마루 구릉지", "forest", { { "infinite_slayer", 40 }, { "infinite_whelp", 35 }, { "darkiron", 25 } },
		X("시대의 사냥꾼", "INV_Misc_Head_Dragon_Bronze", "dragonkin", "lord", { smash(8, 2.4), aoe(11, 1.0, "arcane", { "chill", 0.6 }) }, { school = "arcane" })),
	st("검은늪", "swamp", { { "infinite_whelp", 40 }, { "infinite_slayer", 35 }, { "croc", 25 } },
		X("아에누스", "INV_Misc_Head_Dragon_Bronze", "dragonkin", "brute", { smash(7, 2.6), aoe(12, 1.0, "arcane"), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 50 } })),
	st("하이잘 정상 전투", "forest", { { "ghoul", 35 }, { "abomination", 30 }, { "infernal", 35 } },
		X("아키몬드", "Spell_Shadow_SummonInfernal", "demon", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(11, 2.6, "shadow"), summon(20, "infernal", 1), enrage(0.2, 1.5) }, { school = "shadow", res = { shadow = 50, fire = 50 } })),
	st("줄아만", "jungle", { { "amani_axe", 35 }, { "amani_lynx", 35 }, { "troll", 30 } },
		X("줄진", "INV_Misc_Head_Troll_02", "humanoid", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), aoe(12, 1.0, "nature", { "shock", 0.5 }), enrage(0.4, 1.4) })),
	st("검은 사원", "shadow", { { "ashtongue", 35 }, { "illidari", 35 }, { "wrathguard", 30 } },
		X("일리단 스톰레이지", "Ability_Warrior_PunishingBlow", "demon", "swift", { smash(6, 2.3, "shadow"), aoe(10, 1.1, "fire", { "ignite", 0.6 }), shield(28, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50, fire = 40 } })),
	st("마법학자의 정원", "holy", { { "sunblade_knight", 35 }, { "sunblade_mage", 35 }, { "mana_wyrm", 30 } },
		X("여사제 델리사", "INV_Misc_Head_Elf_02", "humanoid", "caster", { aoe(9, 1.0, "holy"), summon(16, "sunblade_knight", 2), shield(24, 6, 60) }, { school = "holy" })),
	st("태양샘 고원", "holy", { { "sunblade_knight", 30 }, { "sunblade_mage", 30 }, { "shadowsword", 40 } },
		X("브루탈루스", "Spell_Shadow_SummonInfernal", "demon", "brute", { smash(5, 2.6, "fire", { "ignite", 1 }), aoe(12, 1.1, "fire"), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60 } })),
	st("태양샘", "fel", { { "shadowsword", 50 }, { "wrathguard", 50 } },
		X("킬제덴", "Spell_Shadow_ShadowBolt", "demon", "caster",
			{ aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(10, 2.5, "shadow"), summon(18, "shield_orb", 3), shield(30, 6, 70), enrage(0.2, 1.5) },
			{ school = "shadow", res = { shadow = 60, fire = 60 }, range = 600 })),
})

------------------------------------------------------------------------
-- Mythic: Northrend
------------------------------------------------------------------------
ns.STAGES[3] = finish({
	st("북풍의 땅", "snow", { { "nerubian", 35 }, { "mammoth", 25 }, { "ghoul", 40 } },
		X("스컬지 군주 살라므", "Spell_Shadow_AnimateDead", "undead", "caster", { aoe(9, 1.0, "shadow"), summon(16, "ghoul", 3) }, { school = "shadow" })),
	st("마력의 탑", "arcane", { { "mage_hunter", 35 }, { "crystalline", 30 }, { "frost_whelp", 35 } },
		X("케리스트라자", "INV_Misc_Head_Dragon_Red", "dragonkin", "brute", { smash(8, 2.4, "frost", { "chill", 1 }), aoe(11, 1.0, "frost", { "freeze", 0.3 }), enrage(0.25, 1.4) }, { school = "frost", res = { frost = 60, fire = -25 } })),
	st("울부짖는 협만", "snow", { { "vrykul", 40 }, { "fjord_worg", 30 }, { "proto_drake", 30 } },
		X("서리송곳니 족장", "Ability_Hunter_Pet_Wolf", "beast", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(18, "fjord_worg", 3) })),
	st("우트가드 성채", "ruins", { { "vrykul", 45 }, { "vrykul_seer", 30 }, { "proto_drake", 25 } },
		X("약탈자 잉그바르", "INV_Helmet_08", "giant", "brute", { smash(7, 2.6, nil, { "stun", 0.4 }), aoe(13, 1.0, "shadow"), enrage(0.5, 1.3) })),
	st("우트가드 첨탑", "ice", { { "vrykul", 35 }, { "vrykul_seer", 35 }, { "frost_whelp", 30 } },
		X("왕 이미론", "INV_Helmet_08", "giant", "lord", { smash(8, 2.5), aoe(11, 1.0, "shadow"), summon(20, "vrykul", 2) })),
	st("용의 안식처", "snow", { { "magnataur", 25 }, { "frost_whelp", 35 }, { "nerubian", 40 } },
		X("마그나타우르 대군주", "INV_Misc_MonsterHorn_03", "giant", "brute", { smash(7, 2.8), enrage(0.3, 1.4) })),
	st("아졸네룹", "cave", { { "nerubian", 50 }, { "crypt_fiend", 30 }, { "faceless", 20 } },
		X("아눕아락", "Spell_Nature_Web", "undead", "brute", { smash(8, 2.5, nil, { "poison", 1 }), summon(15, "nerubian", 3), shield(26, 6, 65) })),
	st("안카헤트: 고대 왕국", "shadow", { { "faceless", 35 }, { "ahnkahet_cultist", 40 }, { "nerubian", 25 } },
		X("전령 볼라즈", "Spell_Shadow_EvilEye", "aberration", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.6 }), enrage(0.3, 1.4) }, { school = "shadow", res = { shadow = 60 } })),
	st("흑요석 성소", "lava", { { "dragonkin", 40 }, { "drake", 35 }, { "whelp", 25 } },
		X("살타리온", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "drake", 1) }, { school = "fire", res = { fire = 60 } })),
	st("영원의 눈", "arcane", { { "mage_hunter", 50 }, { "crystalline", 50 } },
		X("말리고스", "INV_Misc_Head_Dragon_Blue", "dragonkin", "caster",
			{ aoe(8, 1.2, "arcane"), smash(11, 2.6, "frost", { "chill", 1 }), summon(20, "nexus_lord", 2), shield(30, 6, 70), enrage(0.2, 1.5) },
			{ school = "arcane", res = { arcane = 60, frost = 60 }, range = 600 })),
	-- Act 2
	st("회색 구릉지", "forest", { { "grizzly", 35 }, { "worgen", 35 }, { "drakkari", 30 } },
		X("타락한 우르속", "Ability_Hunter_Pet_Bear", "beast", "brute", { smash(7, 2.7, nil, { "bleed", 1 }), enrage(0.35, 1.5) })),
	st("드락타론 성채", "ruins", { { "scourge_troll", 40 }, { "drakkari", 30 }, { "ghoul", 30 } },
		X("예언자 타론자", "INV_Misc_Bone_HumanSkull_01", "undead", "caster", { aoe(9, 1.1, "shadow"), smash(12, 2.3, "nature", { "poison", 1 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("줄드락", "snow", { { "drakkari", 40 }, { "drakkari_shaman", 30 }, { "scourge_troll", 30 } },
		X("군주 드라쿠루", "INV_Misc_Head_Troll_01", "humanoid", "lord", { smash(8, 2.5), summon(16, "scourge_troll", 3), enrage(0.3, 1.4) })),
	st("군드락", "jungle", { { "drakkari", 35 }, { "drakkari_shaman", 35 }, { "rhino", 30 } },
		X("갈다라", "Ability_Mount_Kodo_03", "humanoid", "swift", { smash(6, 2.3), aoe(12, 1.0, "phys", { "stun", 0.3 }), enrage(0.5, 1.3) })),
	st("숄라자르 분지", "jungle", { { "wolvar", 40 }, { "rhino", 25 }, { "raptor", 35 } },
		X("표범 여왕 샹고", "Ability_Hunter_Pet_Cat", "beast", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(16, "wolvar", 3) })),
	st("보랏빛 요새", "arcane", { { "azure_invader", 40 }, { "azure_mage", 35 }, { "crystalline", 25 } },
		X("시아니고사", "INV_Misc_Head_Dragon_Blue", "dragonkin", "caster", { aoe(8, 1.1, "arcane"), smash(11, 2.4, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 60 } })),
	st("폭풍우 봉우리", "storm", { { "iron_dwarf", 40 }, { "storm_giant", 25 }, { "lightning_ele", 35 } },
		X("폭풍군주 토림", "Spell_Nature_CallStorm", "giant", "lord", { smash(8, 2.5, "nature", { "shock", 1 }), aoe(10, 1.1, "nature", { "stun", 0.25 }), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("번개의 전당", "storm", { { "iron_dwarf", 35 }, { "iron_golem", 30 }, { "lightning_ele", 35 } },
		X("로켄", "Spell_Nature_ChainLightning", "giant", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), shield(26, 6, 60) }, { school = "nature", res = { nature = 70 } })),
	st("돌의 전당", "cave", { { "iron_dwarf", 40 }, { "iron_golem", 35 }, { "storm_giant", 25 } },
		X("무쇠구체자 쇼니르", "INV_Misc_Head_Dwarf_02", "humanoid", "lord", { smash(8, 2.5), summon(14, "iron_dwarf", 3), enrage(0.3, 1.4) }, { school = "nature" })),
	st("울두아르", "storm", { { "iron_golem", 40 }, { "faceless", 30 }, { "iron_dwarf", 30 } },
		X("요그사론", "Spell_Shadow_EvilEye", "aberration", "caster",
			{ aoe(10, 1.0, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.4 }), summon(20, "guardian_of_yogg", 2), shield(32, 6, 60), enrage(0.2, 1.3) },
			{ school = "shadow", res = { shadow = 60 } })),
	-- Act 3
	st("얼음왕관", "ice", { { "geist", 40 }, { "scourge_champion", 35 }, { "flesh_giant", 25 } },
		X("스컬지 사령관", "Spell_Shadow_DeathCoil", "undead", "lord", { smash(8, 2.5, "shadow"), summon(16, "geist", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("용사의 시험장", "holy", { { "scourge_champion", 40 }, { "bone_construct", 30 }, { "ghoul", 30 } },
		X("흑기사", "Ability_Mount_Undeadhorse", "undead", "swift", { smash(6, 2.3, "shadow"), summon(16, "ghoul", 3), shield(26, 6, 60) }, { school = "shadow" })),
	st("십자군의 시험장", "snow", { { "magnataur", 30 }, { "nerubian", 40 }, { "ymirjar", 30 } },
		X("얼음울음", "Ability_Hunter_Pet_Gorilla", "beast", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "frost", { "chill", 1 }), enrage(0.3, 1.5) }, { res = { frost = 60 } })),
	st("영혼의 제련소", "shadow", { { "cult_adherent", 35 }, { "scourge_champion", 35 }, { "bone_construct", 30 } },
		X("영혼의 포식자", "Spell_Shadow_Possession", "undead", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.4, "shadow"), summon(18, "raging_spirit", 2) }, { school = "shadow", res = { shadow = 60 } })),
	st("사론의 구덩이", "ice", { { "ymirjar", 35 }, { "geist", 35 }, { "frost_wyrm", 30 } },
		X("스컬지군주 티라누스", "Spell_Frost_FreezingBreath", "undead", "brute", { smash(7, 2.7, "frost", { "chill", 1 }), aoe(11, 1.1, "frost"), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 60 } })),
	st("투영의 전당", "ice", { { "scourge_champion", 35 }, { "valkyr", 35 }, { "cult_adherent", 30 } },
		X("팔릭", "Spell_Shadow_DeathCoil", "undead", "lord", { smash(8, 2.5, "shadow"), aoe(10, 1.1, "shadow", { "stun", 0.25 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("얼음왕관 성채", "ice", { { "bone_construct", 40 }, { "cult_adherent", 30 }, { "valkyr", 30 } },
		X("군주 매로우가르", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(6, 2.6), aoe(11, 1.2, "frost", { "chill", 0.6 }), enrage(0.3, 1.5) })),
	st("역병작업장", "swamp", { { "flesh_giant", 35 }, { "geist", 35 }, { "crypt_fiend", 30 } },
		X("교수 퓨트리사이드", "Spell_Shadow_AbominationExplosion", "undead", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "ooze", 2), shield(28, 6, 65), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("서리날개 전당", "ice", { { "frost_wyrm", 35 }, { "valkyr", 35 }, { "ymirjar", 30 } },
		X("신드라고사", "Spell_Frost_FreezingBreath", "dragonkin", "brute", { aoe(8, 1.2, "frost", { "chill", 1 }), smash(11, 2.7, "frost", { "freeze", 1 }), enrage(0.25, 1.6) }, { school = "frost", res = { frost = 80, fire = -20 } })),
	st("얼어붙은 왕좌", "ice", { { "scourge_champion", 50 }, { "valkyr", 50 } },
		X("리치 왕", "Spell_Frost_FrostArmor02", "undead", "lord",
			{ aoe(8, 1.2, "shadow"), smash(9, 2.7, "frost", { "freeze", 0.7 }), summon(16, "raging_spirit", 3), shield(30, 6, 70), enrage(0.2, 1.6) },
			{ school = "frost", res = { frost = 60, shadow = 60 } })),
})

------------------------------------------------------------------------
-- Mythic+: the Cataclysm, Pandaria and the Legion
------------------------------------------------------------------------
ns.STAGES[4] = finish({
	st("하이잘 산", "lava", { { "twilight_zealot", 40 }, { "twilight_shaper", 30 }, { "ember_lord", 30 } },
		X("남작 게돈", "Spell_Fire_Elemental_Totem", "elemental", "brute", { aoe(8, 1.1, "fire", { "ignite", 0.7 }), smash(11, 2.6, "fire"), enrage(0.3, 1.4) }, { school = "fire", res = { fire = 70, frost = -25 } })),
	st("바쉬르", "sea", { { "deep_naga", 40 }, { "deep_seer", 30 }, { "faceless", 30 } },
		X("오주마트", "Spell_Shadow_EvilEye", "aberration", "brute", { smash(7, 2.7, "shadow"), summon(16, "faceless", 2), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("파도의 왕좌", "sea", { { "deep_naga", 35 }, { "deep_seer", 35 }, { "steam_surger", 30 } },
		X("여군주 나즈자르", "Spell_Frost_FrostNova", "humanoid", "caster", { aoe(8, 1.2, "frost", { "chill", 1 }), summon(16, "deep_naga", 2), shield(26, 6, 65) }, { school = "frost", res = { frost = 60 } })),
	st("심원의 영지", "cave", { { "stone_giant", 30 }, { "stone_drake", 35 }, { "twilight_zealot", 35 } },
		X("바위어머니 테라제인", "Spell_Nature_Earthquake", "elemental", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "nature"), shield(26, 6, 65) }, { res = { nature = 60, phys = 20 } })),
	st("바위심장부", "cave", { { "stone_giant", 35 }, { "twilight_zealot", 35 }, { "twilight_shaper", 30 } },
		X("대여사제 아질", "Spell_Shadow_Twilight", "humanoid", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.5, "nature", { "stun", 0.6 }), summon(16, "twilight_zealot", 3) }, { school = "shadow" })),
	st("울둠", "desert", { { "neferset", 40 }, { "sand_djinn", 30 }, { "sandworm", 30 } },
		X("암흑 파라오 테카안", "INV_Misc_Head_Centaur_01", "humanoid", "lord", { smash(8, 2.6, "shadow"), summon(16, "neferset", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("톨비르의 잃어버린 도시", "desert", { { "neferset", 35 }, { "sand_djinn", 40 }, { "stone_drake", 25 } },
		X("시아마트", "Spell_Nature_Cyclone", "elemental", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), enrage(0.3, 1.5) }, { school = "nature", res = { nature = 70 } })),
	st("황혼의 고원", "shadow", { { "twilight_drake", 35 }, { "twilight_zealot", 35 }, { "twilight_shaper", 30 } },
		X("초갈", "Ability_Smash", "giant", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "fire", { "ignite", 0.6 }), summon(18, "twilight_zealot", 2), enrage(0.25, 1.5) }, { school = "shadow", res = { shadow = 50, fire = 50 } })),
	st("불의 땅", "lava", { { "flamewaker", 40 }, { "molten_giant", 25 }, { "ember_lord", 35 } },
		X("청지기 스태그헬름", "Spell_Fire_Fire", "elemental", "swift", { smash(5, 2.4, "fire", { "ignite", 1 }), aoe(11, 1.2, "fire"), enrage(0.4, 1.5) }, { school = "fire", res = { fire = 70 } })),
	st("용의 영혼", "lava", { { "twilight_drake", 50 }, { "molten_giant", 50 } },
		X("데스윙", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute",
			{ aoe(9, 1.05, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(20, "corruption_tentacle", 2), shield(32, 6, 60), enrage(0.2, 1.4) },
			{ school = "fire", res = { fire = 70, shadow = 50 } })),
	-- Act 2
	st("비취 숲", "jungle", { { "hozen", 40 }, { "jinyu", 30 }, { "sha", 30 } },
		X("의심의 샤", "Spell_Shadow_Possession", "aberration", "caster", { aoe(8, 1.2, "shadow"), summon(16, "sha", 2), shield(26, 6, 65) }, { school = "shadow", res = { shadow = 70 } })),
	st("옥룡사", "holy", { { "sha", 40 }, { "jinyu", 30 }, { "hozen", 30 } },
		X("현자 마리", "Spell_Frost_SummonWaterElemental", "humanoid", "caster", { aoe(8, 1.2, "frost", { "chill", 0.7 }), smash(12, 2.5, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "frost", res = { frost = 60 } })),
	st("네 바람의 계곡", "plains", { { "virmen", 45 }, { "hozen", 30 }, { "saurok", 25 } },
		X("버민 왕 훕탈루스", "INV_Misc_MonsterFang_01", "beast", "swift", { smash(6, 2.3), summon(13, "virmen", 3), enrage(0.3, 1.4) })),
	st("스톰스타우트 양조장", "plains", { { "hozen", 40 }, { "virmen", 35 }, { "ooze", 25 } },
		X("옌주", "INV_Misc_Slime_01", "elemental", "brute", { smash(7, 2.7), aoe(11, 1.2, "nature", { "stun", 0.3 }), summon(18, "ooze", 2) }, { res = { nature = 50 } })),
	st("쿤라이 봉우리", "snow", { { "yaungol", 40 }, { "mogu", 25 }, { "hozen", 35 } },
		X("분노의 샤", "Spell_Shadow_UnholyFrenzy", "aberration", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "shadow"), enrage(0.4, 1.6) }, { school = "shadow", res = { shadow = 70 } })),
	st("모구샨 금고", "ruins", { { "mogu", 35 }, { "mogu_sorcerer", 35 }, { "anubisath", 30 } },
		X("황제의 의지", "INV_Misc_MonsterHead_04", "mechanical", "brute", { smash(6, 2.8, nil, { "stun", 0.4 }), summon(16, "mogu", 2), shield(26, 6, 65), enrage(0.3, 1.5) })),
	st("공포의 황무지", "shadow", { { "mantid", 40 }, { "amber_shaper", 30 }, { "sha", 30 } },
		X("호박석 조각가 운속", "INV_Misc_AhnQirajTrinket_04", "beast", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "mantid", 2), shield(26, 6, 65) }, { school = "nature", res = { nature = 60 } })),
	st("공포의 심장", "shadow", { { "mantid", 45 }, { "amber_shaper", 30 }, { "silithid", 25 } },
		X("대여제 셰크지르", "INV_Misc_AhnQirajTrinket_02", "beast", "lord", { smash(7, 2.6, nil, { "poison", 1 }), aoe(10, 1.2, "shadow", { "stun", 0.3 }), summon(18, "mantid", 3), enrage(0.3, 1.5) }, { school = "shadow" })),
	st("천둥의 왕좌", "storm", { { "mogu", 35 }, { "mogu_sorcerer", 30 }, { "saurok", 35 } },
		X("천둥왕 레이 션", "Spell_Nature_CallStorm", "humanoid", "lord", { aoe(7, 1.3, "nature", { "shock", 0.7 }), smash(10, 2.7, "nature", { "stun", 0.5 }), shield(28, 6, 70), enrage(0.25, 1.5) }, { school = "nature", res = { nature = 80 } })),
	st("오그리마 공성전", "desert", { { "korkron", 45 }, { "dark_shaman", 30 }, { "sha", 25 } },
		X("가로쉬 헬스크림", "INV_Misc_Head_Orc_02", "humanoid", "lord",
			{ smash(8, 2.4, nil, { "bleed", 0.6 }), aoe(11, 1.05, "shadow"), summon(20, "korkron_warbringer", 2), shield(32, 6, 55), enrage(0.2, 1.4) },
			{ res = { shadow = 40 } })),
	-- Act 3
	st("아즈스나", "sea", { { "withered", 40 }, { "deep_naga", 30 }, { "deep_seer", 30 } },
		X("아즈샤라의 분노", "Spell_Frost_SummonWaterElemental", "elemental", "caster", { aoe(7, 1.3, "frost", { "chill", 1 }), smash(11, 2.6, "nature", { "shock", 1 }), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 70, nature = 50 } })),
	st("발샤라", "forest", { { "nightmare_treant", 30 }, { "nightmare_stalker", 35 }, { "satyr", 35 } },
		X("악몽의 용 이세라", "INV_Misc_Head_Dragon_Green", "dragonkin", "brute", { aoe(8, 1.3, "nature", { "poison", 0.7 }), smash(11, 2.7, "shadow"), summon(18, "nightmare_stalker", 2) }, { school = "nature", res = { nature = 70 } })),
	st("어둠심장 숲", "shadow", { { "nightmare_stalker", 40 }, { "nightmare_treant", 30 }, { "satyr", 30 } },
		X("자비우스의 망령", "Spell_Shadow_UnholyStrength", "demon", "caster", { aoe(7, 1.3, "shadow"), smash(11, 2.6, "shadow", { "stun", 0.6 }), shield(26, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 70 } })),
	st("높은산", "storm", { { "drogbar", 40 }, { "harpy", 30 }, { "storm_drake", 30 } },
		X("지하군주 다르그룰", "Spell_Nature_Earthquake", "humanoid", "brute", { smash(6, 2.9, nil, { "stun", 0.5 }), aoe(11, 1.2, "nature"), enrage(0.3, 1.5) })),
	st("스톰하임", "storm", { { "valarjar", 40 }, { "storm_drake", 30 }, { "valkyr", 30 } },
		X("신왕 스코발드", "INV_Helmet_08", "giant", "lord", { smash(7, 2.7, "fire", { "ignite", 1 }), aoe(10, 1.2, "fire"), shield(26, 6, 70), enrage(0.3, 1.5) }, { school = "fire" })),
	st("수라마르", "arcane", { { "nightborne_guard", 35 }, { "nightborne_mage", 35 }, { "withered", 30 } },
		X("대마법학자 엘리산드", "INV_Misc_Head_Elf_02", "humanoid", "caster", { aoe(7, 1.3, "arcane"), smash(11, 2.6, "arcane", { "freeze", 0.6 }), summon(18, "nightborne_guard", 2), shield(28, 6, 70) }, { school = "arcane", res = { arcane = 70 } })),
	st("밤의 요새", "fel", { { "felguard", 35 }, { "nightborne_mage", 30 }, { "eredar", 35 } },
		X("굴단", "Spell_Shadow_ShadowBolt", "humanoid", "caster", { aoe(7, 1.3, "fire", { "ignite", 0.7 }), smash(10, 2.7, "shadow"), summon(16, "felguard", 2), enrage(0.25, 1.6) }, { school = "shadow", res = { shadow = 60, fire = 60 } })),
	st("살게라스의 무덤", "fel", { { "felguard", 35 }, { "fel_bat", 35 }, { "doomguard", 30 } },
		X("타락한 화신", "INV_Misc_Gear_04", "mechanical", "brute", { smash(6, 2.9), aoe(9, 1.3, "fire"), shield(28, 6, 70), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60, shadow = 60 } })),
	st("안토러스: 불타는 왕좌", "fel", { { "antoran_hound", 35 }, { "eredar", 30 }, { "fel_annihilator", 35 } },
		X("아그라마르", "Spell_Fire_Volcano", "giant", "brute", { smash(5, 2.8, "fire", { "ignite", 1 }), aoe(9, 1.3, "fire"), summon(18, "ember_lord", 2), enrage(0.3, 1.6) }, { school = "fire", res = { fire = 80 } })),
	st("만신전의 옥좌", "arcane", { { "doomguard", 50 }, { "eredar", 50 } },
		X("파멸자 아르거스", "Spell_Shadow_SummonInfernal", "giant", "lord",
			{ aoe(7, 1.4, "shadow"), smash(9, 2.9, "fire", { "ignite", 1 }), summon(15, "reorigination_module", 3), shield(30, 7, 75), enrage(0.2, 1.7) },
			{ school = "shadow", res = { shadow = 70, fire = 70, arcane = 50 } })),
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
