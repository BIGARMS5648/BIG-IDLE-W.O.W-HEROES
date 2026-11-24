-- Stages. Each difficulty has 3 acts of 10 stages: a route through the
-- original game's zones, dungeons, battlegrounds, world bosses and raids,
-- in level order, every stage a different place (or area of one):
--   Normal  - Elwynn Forest .. the Scarlet Monastery
--   Heroic  - the Badlands .. Scholomance
--   Mythic  - the battlegrounds, Dire Maul, the world bosses, the Ruins of
--             Ahn'Qiraj and Zul'Gurub
--   Mythic+ - Molten Core, Onyxia, Blackwing Lair, the Temple of Ahn'Qiraj
--             and Naxxramas
-- A stage is a run of waves that ends with a boss; the 10th stage of an act is
-- a raid boss with its own abilities.
local _, ns = ...

ns.DIFFS = {
	{ name = "일반",   hex = "e8e8e8",
		world = "모험의 시작",
		acts = { "불모의 땅", "그림자송곳니 성채", "붉은십자군 수도원" } },
	{ name = "영웅",   hex = "3ddc5a",
		world = "넓어지는 세계",
		acts = { "울다만", "아탈학카르 신전", "검은바위 첨탑 하층" } },
	{ name = "신화",   hex = "b266ff",
		world = "깨어나는 위협",
		acts = { "검은바위 첨탑 상층", "줄구룹", "세계의 우두머리" } },
	{ name = "신화+", hex = "ff9326",
		world = "최후의 결전",
		acts = { "화산 심장부", "검은날개와 안퀴라즈", "낙스라마스" } },
}

ns.STAGES_PER_ACT = 10
ns.STAGE_COUNT = 30

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

-- place: the dungeon or raid; name: the area of it the stage is fought in
local function st(place, name, theme, mobs, boss)
	return { place = place, name = name, theme = theme, mobs = mobs, boss = boss }
end

ns.STAGES = {}

------------------------------------------------------------------------
-- Normal: Elwynn Forest to the Scarlet Monastery
------------------------------------------------------------------------
ns.STAGES[1] = finish({
	-- Act 1: 불모의 땅
	st("엘윈 숲", "엘윈 숲", "forest", { { "kobold_worker", 50 }, { "prowler", 50 } },
		B("들창코", "INV_Misc_Head_Human_02", "humanoid", 150, 7, 0.7, { skills = { smash(9, 2.2) } })),
	st("던 모로", "던 모로", "snow", { { "ice_claw_bear", 35 }, { "frostmane_seer", 35 }, { "snow_leopard", 30 } },
		B("늙은 얼음수염", "INV_Misc_Head_Human_02", "humanoid", 240, 8, 0.6, { skills = { smash(9, 2.2) } })),
	st("텔드랏실", "텔드랏실", "forest", { { "gnarlpine_warrior", 40 }, { "timberling", 30 }, { "gnarlpine_mystic", 30 } },
		B("제왕 멜레나스", "Spell_Shadow_SummonFelHunter", "demon", 300, 10, 0.9, { skills = { smash(8, 2), summon(18, "grellkin", 2) } })),
	st("듀로타", "듀로타", "desert", { { "dreadmaw_crocolisk", 45 }, { "burning_blade_apprentice", 30 }, { "razormane_quilboar", 25 } },
		B("잘라제인", "INV_Misc_Head_Human_02", "humanoid", 360, 11, 0.7, { skills = { smash(9, 2.2) } })),
	st("멀고어", "멀고어", "plains", { { "bristleback_battleboar", 35 }, { "bristleback_shaman", 35 }, { "adult_plainstrider", 30 } },
		B("족장 칼날엄니", "INV_Misc_Head_Human_02", "humanoid", 460, 11, 0.6, { skills = { smash(9, 2.2), aoe(13, 0.8, "nature", { "poison", 0.5 }) } })),
	st("티리스팔 숲", "티리스팔 숲", "forest", { { "scarlet_convert", 35 }, { "scarlet_neophyte", 30 }, { "scarlet_missionary", 35 } },
		B("대장 페린", "Spell_Shadow_DeathCoil", "humanoid", 440, 13, 1, { skills = { smash(8, 2), summon(20, "scarlet_warrior", 2) } })),
	st("서부 몰락지대", "서부 몰락지대", "plains", { { "riverpaw_gnoll", 35 }, { "defias_trapper", 30 }, { "harvest_golem", 35 } },
		B("허수아비골렘 수확기", "INV_Gizmo_02", "mechanical", 560, 12, 0.6, { skills = { smash(9, 2.2) } })),
	st("모단 호수", "모단 호수", "forest", { { "stonesplinter_seer", 40 }, { "stonesplinter_trogg", 25 }, { "elder_black_bear", 35 } },
		B("마고쉬", "INV_Misc_Head_Human_02", "humanoid", 520, 13, 0.7, { school = "shadow", skills = { aoe(11, 0.9, "shadow"), summon(20, "mogrosh_ogre", 2) } })),
	st("은빛소나무 숲", "은빛소나무 숲", "forest", { { "moonrage_darkrunner", 40 }, { "ferocious_grizzled_bear", 30 }, { "worg", 30 } },
		B("아루갈의 후예", "INV_Misc_MonsterFang_01", "humanoid", 600, 14, 0.8, { skills = { smash(9, 2.2), aoe(12, 0.9, "fire", { "ignite", 0.4 }) } })),
	st("불모의 땅", "불모의 땅", "plains", { { "savannah_huntress", 50 }, { "razormane_hunter", 50 } },
		B("바라크 코도베인", "INV_Misc_Head_Human_02", "humanoid", 1500, 16, 0.6, { school = "fire", res = { fire = 75, frost = -25 }, skills = { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(24, "kolkar_marauder", 3), enrage(0.25, 1.4) } })),
	-- Act 2: 그림자송곳니 성채
	st("성난불길 협곡", "성난불길 협곡", "lava", { { "earthborer", 35 }, { "molten_elemental", 35 }, { "searing_blade_cultist", 30 } },
		B("욕망의 타라가만", "Spell_Shadow_SummonImp", "humanoid", 420, 10, 0.7, { skills = { smash(9, 2.2) } })),
	st("붉은마루 산맥", "붉은마루 산맥", "desert", { { "great_goretusk", 35 }, { "blackrock_outrunner", 30 }, { "redridge_mongrel", 35 } },
		B("가스일조그", "INV_Misc_Head_Human_02", "humanoid", 480, 12, 0.9, { skills = { smash(8, 2), summon(18, "blackrock_grunt", 2) } })),
	st("돌발톱 산맥", "돌발톱 산맥", "desert", { { "venture_co_logger", 35 }, { "deepmoss_creeper", 30 }, { "windfury_sorceress", 35 } },
		B("게렌조 렌치휘슬", "INV_Misc_Head_Human_02", "humanoid", 560, 12, 0.7, { skills = { smash(9, 2.3), aoe(14, 0.8, "nature", { "stun", 0.25 }) } })),
	st("통곡의 동굴", "통곡의 동굴", "cave", { { "druid_of_the_fang", 40 }, { "deviate_lurker", 30 }, { "deviate_adder", 30 } },
		B("걸신들린 무타누스", "INV_Misc_Head_Murloc_01", "humanoid", 680, 12, 0.5, { res = { fire = -30, nature = 50 }, skills = { smash(8, 2.6), shield(22, 6, 60) } })),
	st("죽음의 폐광", "죽음의 폐광", "cave", { { "defias_miner", 40 }, { "defias_overseer", 35 }, { "defias_taskmaster", 25 } },
		B("에드윈 밴클리프", "INV_Misc_Head_Human_01", "humanoid", 540, 14, 0.8, { school = "nature", range = 420, skills = { aoe(10, 1, "nature", { "shock", 0.5 }) } })),
	st("잿빛 골짜기", "잿빛 골짜기", "forest", { { "foulweald_shaman", 30 }, { "ghostpaw_runner", 35 }, { "thistlefur_avenger", 35 } },
		B("우르산고우스", "Ability_Hunter_Pet_Bear", "beast", 620, 14, 0.9, { skills = { smash(8, 2.2), summon(18, "ashenvale_bear", 2) } })),
	st("그늘숲", "그늘숲", "shadow", { { "nightbane_vile_fang", 25 }, { "skeletal_warrior", 40 }, { "pygmy_venom_web_spider", 35 } },
		B("누더기", "Spell_Shadow_RaiseDead", "undead", 820, 15, 0.5, { skills = { smash(7, 2.8), enrage(0.3, 1.4) } })),
	st("힐스브래드 구릉지", "힐스브래드 구릉지", "forest", { { "torn_fin_oracle", 40 }, { "syndicate_footpad", 30 }, { "elder_moss_creeper", 30 } },
		B("앨리덴 페레놀드 경", "INV_Misc_Head_Human_02", "humanoid", 760, 14, 0.8, { skills = { aoe(12, 0.9, "nature", { "poison", 0.6 }), summon(16, "syndicate_enforcer", 3) } })),
	st("저습지", "저습지", "swamp", { { "fen_creeper", 30 }, { "dragonmaw_shadowwarder", 40 }, { "mosshide_brute", 30 } },
		B("마룩 웜스케일", "INV_Misc_Head_Human_02", "humanoid", 900, 16, 0.6, { skills = { smash(8, 2.6), shield(20, 6, 70), enrage(0.3, 1.3) } })),
	st("그림자송곳니 성채", "그림자송곳니 성채", "shadow", { { "shadowfang_darksoul", 40 }, { "bleak_worg", 60 } },
		B("대마법사 아루갈", "Spell_Holy_MagicalSentry", "humanoid", 1900, 15, 0.7, { school = "shadow", res = { shadow = 50 }, skills = { aoe(9, 1, "shadow"), summon(18, "arugals_voidwalker", 2), shield(30, 7, 75), enrage(0.2, 1.5) } })),
	-- Act 3: 붉은십자군 수도원
	st("검은심연 나락", "검은심연 나락", "sea", { { "blackfathom_myrmidon", 35 }, { "twilight_reaver", 35 }, { "blackfathom_tide_priestess", 30 } },
		B("아쿠마이", "Ability_Hunter_Pet_Crocolisk", "humanoid", 700, 13, 0.6, { res = { frost = 50 }, skills = { smash(8, 2.5, nil, { "stun", 0.5 }) } })),
	st("버섯구름 봉우리", "버섯구름 봉우리", "desert", { { "galak_scout", 40 }, { "galak_windchaser", 30 }, { "galak_packhound", 30 } },
		B("아르낙 그림토템", "INV_Misc_Head_Human_02", "humanoid", 760, 14, 0.6, { school = "frost", res = { fire = -30, frost = 75 }, skills = { aoe(10, 1, "frost", { "chill", 1 }) } })),
	st("붉은십자군 수도원", "수도원 묘지", "holy", { { "scarlet_torturer", 35 }, { "haunting_phantasm", 30 }, { "unfettered_spirit", 35 } },
		B("혈법사 탈노스", "Spell_Holy_MagicalSentry", "undead", 980, 14, 0.5, { skills = { smash(7, 2.6), aoe(14, 0.8, "nature", { "poison", 0.6 }) } })),
	st("놈리건", "놈리건", "cave", { { "leprous_defender", 30 }, { "caverndeep_burrower", 40 }, { "dark_iron_agent", 30 } },
		B("기계박사 텔마플러그", "INV_Gizmo_02", "mechanical", 800, 16, 0.6, { school = "shadow", range = 430, skills = { aoe(9, 1, "shadow"), summon(14, "walking_bomb", 3) } })),
	st("가시덩굴 우리", "가시덩굴 우리", "jungle", { { "razorfen_quilguard", 35 }, { "razorfen_geomancer", 35 }, { "greater_kraul_bat", 30 } },
		B("서슬깃 차를가", "INV_Misc_Head_Quillboar_01", "humanoid", 940, 16, 0.8, { school = "shadow", skills = { smash(8, 2.3), summon(16, "razorfen_spearhide", 3), enrage(0.3, 1.3) } })),
	st("붉은십자군 수도원", "수도원 도서관", "holy", { { "scarlet_adept", 30 }, { "scarlet_gallant", 35 }, { "scarlet_diviner", 35 } },
		B("신비술사 도안", "Spell_Holy_MagicalSentry", "humanoid", 1100, 16, 0.7, { school = "shadow", res = { shadow = 50 }, skills = { aoe(8, 1.1, "shadow"), enrage(0.35, 1.5) } })),
	st("아라시 고원", "아라시 고원", "plains", { { "boulderfist_brute", 40 }, { "highland_thrasher", 30 }, { "witherbark_axe_thrower", 30 } },
		B("무쇠주먹 몰로크", "INV_Misc_Head_Human_02", "humanoid", 1150, 17, 0.7, { res = { fire = 50 }, skills = { smash(8, 2.4), aoe(11, 1, "fire", { "ignite", 0.6 }) } })),
	st("잊혀진 땅", "잊혀진 땅", "desert", { { "magram_wrangler", 40 }, { "burning_blade_summoner", 30 }, { "kolkar_destroyer", 30 } },
		B("제왕 아즈레토크", "Spell_Shadow_SummonFelHunter", "demon", 1400, 18, 0.7, { school = "fire", res = { fire = 60 }, skills = { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "burning_blade_felsworn", 2) } })),
	st("가시덤불 골짜기", "가시덤불 골짜기", "jungle", { { "jungle_stalker", 35 }, { "bloodscalp_berserker", 30 }, { "shadowmaw_panther", 35 } },
		B("야수왕 뱅갈라시", "Ability_Hunter_Pet_Bear", "beast", 1700, 17, 1, { skills = { smash(5, 2.6), enrage(0.2, 1.6) } })),
	st("붉은십자군 수도원", "수도원 무기고", "holy", { { "scarlet_myrmidon", 50 }, { "scarlet_defender", 50 } },
		B("헤로드", "Spell_Holy_Excorcism", "humanoid", 2400, 17, 0.7, { school = "frost", res = { frost = 60, shadow = 40 }, range = 600, skills = { aoe(8, 1.1, "frost", { "chill", 1 }), smash(10, 2.4, "shadow", { "freeze", 1 }), summon(16, "scarlet_trainee", 3), shield(32, 6, 70), enrage(0.2, 1.5) } })),
})

------------------------------------------------------------------------
-- Heroic: the Badlands to Scholomance
------------------------------------------------------------------------
ns.STAGES[2] = finish({
	-- Act 1: 울다만
	st("황야의 땅", "황야의 땅", "desert", { { "dustbelcher_brute", 40 }, { "ridge_huntress", 35 }, { "crag_coyote", 25 } },
		X("철옹성", "Spell_Shadow_AbominationExplosion", "mechanical", "brute", { smash(8, 2.5), enrage(0.3, 1.3) }, { school = "fire" })),
	st("먼지진흙 습지대", "먼지진흙 습지대", "swamp", { { "bloodfen_razormaw", 45 }, { "mirefin_oracle", 30 }, { "darkmist_spider", 25 } },
		X("대군주 모크모로크", "INV_Misc_Head_Human_02", "humanoid", "lord", { smash(8, 2.2), summon(18, "mirefin_warrior", 2) })),
	st("슬픔의 늪", "슬픔의 늪", "swamp", { { "marsh_oracle", 35 }, { "swamp_talker", 35 }, { "swamp_jaguar", 30 } },
		X("군주 웜막", "Spell_Shadow_DeathCoil", "dragonkin", "caster", { aoe(9, 1, "shadow"), smash(12, 2.2, "fire", { "ignite", 1 }) }, { school = "shadow" })),
	st("붉은십자군 수도원", "수도원 대성당", "holy", { { "scarlet_champion", 45 }, { "scarlet_monk", 30 }, { "scarlet_chaplain", 25 } },
		X("종교재판관 화이트메인", "Spell_Holy_Excorcism", "humanoid", "swift", { smash(6, 2, nil, { "bleed", 1 }), aoe(13, 0.9, "phys") })),
	st("가시덩굴 구릉", "가시덩굴 구릉", "shadow", { { "splinterbone_warrior", 35 }, { "deaths_head_necromancer", 25 }, { "withered_battle_boar", 40 } },
		X("혹한의 암네나르", "Spell_Frost_FrostArmor02", "undead", "brute", { smash(8, 2.3), aoe(12, 0.8, "nature", { "poison", 0.6 }) }, { res = { fire = -25, nature = 50 } })),
	st("페랄라스", "페랄라스", "forest", { { "gordunni_mage_lord", 40 }, { "longtooth_runner", 30 }, { "woodpaw_brute", 30 } },
		X("군주 샬자루", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(7, 2.6), aoe(13, 0.8, "nature", { "poison", 0.7 }) })),
	st("동부 내륙지", "동부 내륙지", "forest", { { "vilebranch_berserker", 35 }, { "vilebranch_witch_doctor", 30 }, { "vilebranch_raiding_wolf", 35 } },
		X("타락한 여사제 헥스", "INV_Misc_Head_Troll_01", "humanoid", "lord", { smash(8, 2.4), enrage(0.35, 1.4), shield(24, 6, 55) })),
	st("타나리스", "타나리스", "desert", { { "steeljaw_snapper", 35 }, { "scorpid_dunestalker", 35 }, { "dunemaul_ogre", 30 } },
		X("앙드레 파이어비어드", "Spell_Fire_Elemental_Totem", "humanoid", "swift", { smash(7, 2.1), shield(22, 6, 60) })),
	st("울다만", "바위 금고", "cave", { { "stonevault_brawler", 40 }, { "shadowforge_sharpshooter", 35 }, { "jadespine_basilisk", 25 } },
		X("아이로나야", "Spell_Nature_Earthquake", "giant", "caster", { aoe(8, 1.1, "arcane"), smash(12, 2, "arcane", { "stun", 0.6 }) }, { school = "arcane" })),
	st("울다만", "고대의 방", "cave", { { "stone_steward", 50 }, { "vault_warder", 50 } },
		X("아카에다스", "Spell_Nature_Earthquake", "giant", "brute", { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(11, 2.6), summon(22, "earthen_guardian", 2), enrage(0.25, 1.4) }, { school = "fire", res = { fire = 60, shadow = 40 } })),
	-- Act 2: 아탈학카르 신전
	st("이글거리는 협곡", "이글거리는 협곡", "lava", { { "dark_iron_taskmaster", 30 }, { "greater_lava_spider", 35 }, { "heavy_war_golem", 35 } },
		X("감독관 말토류스", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(7, 2.7), enrage(0.3, 1.4) })),
	st("줄파락", "줄파락", "desert", { { "sandfury_blood_drinker", 40 }, { "sandfury_shadowcaster", 25 }, { "sandfury_soul_eater", 35 } },
		X("족장 우코르즈 샌드스칼프", "INV_Misc_Head_Troll_01", "humanoid", "lord", { smash(8, 2.4, nil, { "stun", 0.4 }), summon(20, "sandfury_executioner", 2) })),
	st("아즈샤라", "아즈샤라", "sea", { { "spitelash_warrior", 35 }, { "legashi_satyr", 65 } },
		X("여군주 세스피라", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(7, 2.6), aoe(13, 1, "phys", { "stun", 0.3 }), enrage(0.4, 1.5) })),
	st("저주받은 땅", "저주받은 땅", "fel", { { "dreadmaul_brute", 35 }, { "felhound", 35 }, { "snickerfang_hyena", 30 } },
		X("파멸의 테레무스", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(9, 1, "arcane"), summon(16, "black_broodling", 3) }, { school = "arcane" })),
	st("마라우돈", "독기의 동굴", "jungle", { { "putridus_shadowstalker", 35 }, { "deeprot_tangler", 35 }, { "constrictor_vine", 30 } },
		X("녹시온", "INV_Misc_Slime_01", "elemental", "caster", { aoe(10, 1, "arcane"), summon(18, "noxxions_spawn", 2), shield(26, 6, 50) }, { school = "arcane" })),
	st("마라우돈", "대지의 노래 폭포", "jungle", { { "theradrim_guardian", 45 }, { "primordial_behemoth", 25 }, { "barbed_lasher", 30 } },
		X("공주 테라드라스", "Spell_Nature_Thorns", "elemental", "brute", { smash(8, 2.5), summon(15, "theradrim_shardling", 3) }, { res = { fire = -25, nature = 50 } })),
	st("운고로 분화구", "운고로 분화구", "jungle", { { "ironhide_devilsaur", 30 }, { "frenzied_pterrordax", 35 }, { "living_blaze", 35 } },
		X("폭군 모쉬", "Ability_Hunter_Pet_Bear", "beast", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.2, "shadow", { "stun", 0.6 }), enrage(0.3, 1.3) }, { school = "shadow", res = { shadow = 50 } })),
	st("악령의 숲", "악령의 숲", "fel", { { "jadefire_satyr", 40 }, { "jadefire_felsworn", 30 }, { "deadwood_warrior", 30 } },
		X("사바스라스", "Spell_Shadow_SummonFelHunter", "demon", "lord", { smash(8, 2.4, "shadow"), aoe(11, 1, "fire", { "ignite", 0.5 }), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("불타는 평원", "불타는 평원", "lava", { { "blackrock_summoner", 40 }, { "firegut_ogre_mage", 30 }, { "black_dragonspawn", 30 } },
		X("고르지키 와일드아이즈", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(8, 1, "nature", { "shock", 0.5 }), summon(16, "blackrock_soldier", 2), shield(26, 7, 70) }, { school = "nature", res = { frost = 40, nature = 40 } })),
	st("아탈학카르 신전", "아탈학카르 신전", "swamp", { { "atalai_warrior", 40 }, { "atalai_witch_doctor", 35 }, { "nightmare_scalebane", 25 } },
		X("에라니쿠스의 사령", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(12, 2.4, "fire"), summon(22, "nightmare_wyrmkin", 2), shield(32, 6, 60), enrage(0.2, 1.3) }, { school = "fire", res = { fire = 60, arcane = 40 } })),
	-- Act 3: 검은바위 첨탑 하층
	st("서부 역병지대", "서부 역병지대", "shadow", { { "scarlet_sentinel", 30 }, { "scarlet_mage", 30 }, { "skeletal_executioner", 40 } },
		X("소환사 아라즈", "Spell_Shadow_ShadowBolt", "undead", "brute", { smash(7, 2.7), aoe(13, 1, "phys", { "stun", 0.3 }), enrage(0.25, 1.5) })),
	st("검은바위 나락", "검은 모루", "lava", { { "anvilrage_guardsman", 40 }, { "shadowforge_flame_keeper", 30 }, { "ragereaver_golem", 30 } },
		X("불의 군주 인센디우스", "Spell_Fire_Elemental_Totem", "elemental", "brute", { aoe(8, 1.2, "nature"), smash(12, 2.6, nil, { "stun", 0.6 }) }, { school = "nature" })),
	st("검은바위 나락", "제왕의 관문", "lava", { { "anvilrage_warden", 40 }, { "doomforge_arcanasmith", 35 }, { "wrath_hammer_construct", 25 } },
		X("마그무스", "Spell_Fire_Elemental_Totem", "giant", "lord", { smash(8, 2.4), aoe(11, 1, "arcane", { "chill", 0.6 }) }, { school = "arcane" })),
	st("검은바위 나락", "제왕의 옥좌", "lava", { { "anvilrage_captain", 40 }, { "shadowforge_senator", 35 }, { "fireguard_destroyer", 25 } },
		X("제왕 다그란 타우릿산", "INV_Misc_Head_Dwarf_02", "humanoid", "brute", { smash(7, 2.6), aoe(12, 1, "arcane"), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 50 } })),
	st("여명의 설원", "여명의 설원", "snow", { { "frostsaber_huntress", 35 }, { "winterfall_shaman", 30 }, { "ice_thistle_yeti", 35 } },
		X("대족장 겨울눈", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(11, 2.6, "shadow"), summon(20, "winterfall_ursa", 1), enrage(0.2, 1.5) }, { school = "shadow", res = { fire = 50, shadow = 50 } })),
	st("동부 역병지대", "동부 역병지대", "shadow", { { "cursed_mage", 35 }, { "plague_monstrosity", 35 }, { "crypt_horror", 30 } },
		X("군주 다크사이드", "Spell_Shadow_RaiseDead", "undead", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), aoe(12, 1, "nature", { "shock", 0.5 }), enrage(0.4, 1.4) })),
	st("혈투의 전장", "뒤틀린 숲", "forest", { { "warpwood_crusher", 35 }, { "wildspawn_satyr", 35 }, { "wildspawn_felsworn", 30 } },
		X("칼날바람 알진", "Spell_Shadow_UnholyStrength", "demon", "swift", { smash(6, 2.3, "shadow"), aoe(10, 1.1, "fire", { "ignite", 0.6 }), shield(28, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { fire = 40, shadow = 50 } })),
	st("실리더스", "실리더스", "desert", { { "hiveashi_worker", 35 }, { "twilight_avenger", 35 }, { "dust_stormer", 30 } },
		X("황혼의 예언자", "Spell_Shadow_ShadowWordPain", "humanoid", "caster", { aoe(9, 1, "holy"), summon(16, "twilight_flamereaver", 2), shield(24, 6, 60) }, { school = "holy" })),
	st("검은바위 첨탑 하층", "오크 진영", "lava", { { "spirestone_enforcer", 30 }, { "spirestone_mystic", 30 }, { "bloodaxe_worg", 40 } },
		X("대영주 오모크", "Ability_Smash", "humanoid", "brute", { smash(5, 2.6, "fire", { "ignite", 1 }), aoe(12, 1.1, "fire"), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60 } })),
	st("검은바위 첨탑 하층", "대군주의 방", "lava", { { "smolderthorn_axe_thrower", 50 }, { "bloodaxe_raider", 50 } },
		X("대군주 웜타라크", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(10, 2.5, "shadow"), summon(18, "bloodaxe_veteran", 3), shield(30, 6, 70), enrage(0.2, 1.5) }, { school = "shadow", res = { fire = 60, shadow = 60 }, range = 600 })),
})

------------------------------------------------------------------------
-- Mythic: the battlegrounds, the world bosses, Ahn'Qiraj and Zul'Gurub
------------------------------------------------------------------------
ns.STAGES[3] = finish({
	-- Act 1: 검은바위 첨탑 상층
	st("혈투의 전장", "고르독 왕좌", "ruins", { { "gordok_reaver", 35 }, { "gordok_mage_lord", 25 }, { "gordok_mastiff", 40 } },
		X("왕 고르독", "Ability_Smash", "humanoid", "caster", { aoe(9, 1, "shadow"), summon(16, "gordok_brute", 3) }, { school = "shadow" })),
	st("혈투의 전장", "명가의 궁정", "arcane", { { "highborne_summoner", 35 }, { "eldreth_spectre", 30 }, { "skeletal_highborne", 35 } },
		X("왕자 토르텔드린", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(8, 2.4, "frost", { "chill", 1 }), aoe(11, 1, "frost", { "freeze", 0.3 }), enrage(0.25, 1.4) }, { school = "frost", res = { fire = -25, frost = 60 } })),
	st("스칼로맨스", "스칼로맨스 강의실", "ruins", { { "scholomance_student", 40 }, { "scholomance_necromancer", 30 }, { "risen_guard", 30 } },
		X("잔다이스 바로브", "Spell_Shadow_AnimateDead", "undead", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(18, "illusion_of_jandice_barov", 3) })),
	st("스트라솔름", "스트라솔름 광장", "holy", { { "crimson_gallant", 45 }, { "crimson_sorcerer", 30 }, { "crimson_monk", 25 } },
		X("발나자르", "Spell_Shadow_SummonFelHunter", "demon", "brute", { smash(7, 2.6, nil, { "stun", 0.4 }), aoe(13, 1, "shadow"), enrage(0.5, 1.3) })),
	st("검은바위 첨탑 상층", "검은손 투기장", "lava", { { "blackhand_dreadweaver", 35 }, { "rage_talon_dragonspawn", 35 }, { "blackhand_summoner", 30 } },
		X("대족장 렌드 블랙핸드", "INV_Misc_Head_Orc_01", "humanoid", "lord", { smash(8, 2.5), aoe(11, 1, "shadow"), summon(20, "chromatic_whelp", 2) })),
	st("스칼로맨스", "냉기의 서재", "ice", { { "risen_lackey", 25 }, { "scholomance_adept", 35 }, { "spectral_researcher", 40 } },
		X("라스 프로스트위스퍼", "Spell_Frost_FrostArmor02", "undead", "brute", { smash(7, 2.8), enrage(0.3, 1.4) })),
	st("스칼로맨스", "간들링의 강당", "shadow", { { "risen_construct", 50 }, { "scholomance_dark_summoner", 30 }, { "risen_bonewarder", 20 } },
		X("암흑스승 간들링", "Spell_Shadow_ShadowBolt", "humanoid", "brute", { smash(8, 2.5, nil, { "poison", 1 }), summon(15, "risen_guardian", 3), shield(26, 6, 65) })),
	st("스트라솔름", "도살장", "shadow", { { "skeletal_berserker", 35 }, { "thuzadin_shadowcaster", 40 }, { "patchwork_horror", 25 } },
		X("남작 리븐데어", "Spell_Shadow_DeathCoil", "undead", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.6 }), enrage(0.3, 1.4) }, { school = "shadow", res = { shadow = 60 } })),
	st("검은바위 첨탑 상층", "불꽃 감시자의 방", "lava", { { "blackhand_veteran", 40 }, { "rage_talon_flamescale", 35 }, { "blackhand_iron_guard", 25 } },
		X("불의 수호자 엠버시어", "Spell_Fire_Elemental_Totem", "elemental", "brute", { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "blackhand_incarcerator", 1) }, { school = "fire", res = { fire = 60 } })),
	st("검은바위 첨탑 상층", "드라키사스의 전당", "lava", { { "blackhand_elite", 50 }, { "rage_talon_fire_tongue", 50 } },
		X("사령관 드라키사스", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "arcane"), smash(11, 2.6, "frost", { "chill", 1 }), summon(20, "chromatic_elite_guard", 2), shield(30, 6, 70), enrage(0.2, 1.5) }, { school = "arcane", res = { frost = 60, arcane = 60 }, range = 600 })),
	-- Act 2: 줄구룹
	st("줄구룹", "뱀의 신전", "jungle", { { "hakkari_shadow_hunter", 35 }, { "hakkari_shadowcaster", 35 }, { "razzashi_serpent", 30 } },
		X("대사제 베녹시스", "Ability_Hunter_Pet_WindSerpent", "humanoid", "brute", { smash(7, 2.7, nil, { "bleed", 1 }), enrage(0.35, 1.5) })),
	st("줄구룹", "박쥐 신전", "jungle", { { "gurubashi_bat_rider", 40 }, { "hakkari_oracle", 30 }, { "bloodseeker_bat", 30 } },
		X("대여사제 제클릭", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(9, 1.1, "shadow"), smash(12, 2.3, "nature", { "poison", 1 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("줄구룹", "거미 신전", "jungle", { { "gurubashi_berserker", 40 }, { "razzashi_venombrood", 30 }, { "razzashi_broodwidow", 30 } },
		X("대여사제 말리", "INV_Misc_Head_Troll_01", "humanoid", "lord", { smash(8, 2.5), summon(16, "spawn_of_marli", 3), enrage(0.3, 1.4) })),
	st("줄구룹", "만도키르 고원", "jungle", { { "gurubashi_champion", 35 }, { "razzashi_raptor", 35 }, { "gurubashi_headhunter", 30 } },
		X("혈군주 만도키르", "INV_Misc_Head_Troll_01", "humanoid", "swift", { smash(6, 2.3), aoe(12, 1, "phys", { "stun", 0.3 }), enrage(0.5, 1.3) })),
	st("줄구룹", "광기의 경계", "jungle", { { "gurubashi_axe_thrower", 40 }, { "hakkari_priest", 25 }, { "zulian_stalker", 35 } },
		X("하자라", "Spell_Shadow_RaiseDead", "undead", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(16, "nightmare_illusion", 3) })),
	st("줄구룹", "가즈란카의 물가", "jungle", { { "gurubashi_warrior", 40 }, { "zulian_crocolisk", 35 }, { "razzashi_adder", 25 } },
		X("가즈란카", "INV_Misc_MonsterHead_02", "dragonkin", "caster", { aoe(8, 1.1, "arcane"), smash(11, 2.4, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 60 } })),
	st("줄구룹", "호랑이 신전", "jungle", { { "zulian_guardian", 40 }, { "hakkari_witch_doctor", 25 }, { "hakkari_blood_priest", 35 } },
		X("대사제 데칼", "INV_Misc_Head_Troll_01", "humanoid", "lord", { smash(8, 2.5, "nature", { "shock", 1 }), aoe(10, 1.1, "nature", { "stun", 0.25 }), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("줄구룹", "표범 신전", "jungle", { { "zulian_prowler", 35 }, { "zulian_panther", 30 }, { "gurubashi_blood_drinker", 35 } },
		X("대여사제 알로크", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), shield(26, 6, 60) }, { school = "nature", res = { nature = 70 } })),
	st("줄구룹", "진도의 신전", "jungle", { { "hakkari_bloodkeeper", 40 }, { "gurubashi_berserker_2", 35 }, { "hakkari_witch_doctor", 25 } },
		X("사술사 진도", "INV_Misc_Head_Human_02", "humanoid", "lord", { smash(8, 2.5), summon(14, "shade_of_jindo", 3), enrage(0.3, 1.4) }, { school = "nature" })),
	st("줄구룹", "학카르의 제단", "jungle", { { "gurubashi_warrior_2", 40 }, { "hakkari_shadowcaster_2", 30 }, { "hakkari_priest_2", 30 } },
		X("학카르", "INV_Misc_Head_Troll_01", "aberration", "caster", { aoe(10, 1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.4 }), summon(20, "son_of_hakkar", 2), shield(32, 6, 60), enrage(0.2, 1.3) }, { school = "shadow", res = { shadow = 60 } })),
	-- Act 3: 세계의 우두머리
	st("실리더스", "황혼의 기지", "desert", { { "twilight_flamereaver_2", 40 }, { "twilight_geolord", 35 }, { "twilight_master", 25 } },
		X("왕자 스칼레녹스", "INV_Misc_Head_Human_02", "humanoid", "lord", { smash(8, 2.5, "shadow"), summon(16, "crimson_templar", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("실리더스", "수정 골짜기", "desert", { { "twilight_avenger_2", 40 }, { "twilight_stonecaller", 30 }, { "twilight_emissary", 30 } },
		X("대장군 휠락시스", "INV_Helmet_08", "beast", "swift", { smash(6, 2.3, "shadow"), summon(16, "hoary_templar", 3), shield(26, 6, 60) }, { school = "shadow" })),
	st("안퀴라즈 폐허", "폐허 입구", "desert", { { "hivezara_soldier", 30 }, { "qiraji_swarmguard", 40 }, { "obsidian_destroyer", 30 } },
		X("쿠린낙스", "Ability_Hunter_Pet_Scorpid", "beast", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "frost", { "chill", 1 }), enrage(0.3, 1.5) }, { res = { frost = 60 } })),
	st("안퀴라즈 폐허", "라작스 전장", "desert", { { "qiraji_gladiator", 35 }, { "anubisath_guardian", 35 }, { "flesh_hunter", 30 } },
		X("장군 라작스", "INV_Misc_AhnQirajTrinket_02", "undead", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.4, "shadow"), summon(18, "qiraji_warrior", 2) }, { school = "shadow", res = { shadow = 60 } })),
	st("안퀴라즈 폐허", "모암의 제단", "desert", { { "obsidian_destroyer", 35 }, { "anubisath_guardian_2", 35 }, { "qiraji_gladiator_2", 30 } },
		X("모암", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(7, 2.7, "frost", { "chill", 1 }), aoe(11, 1.1, "frost"), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 60 } })),
	st("안퀴라즈 폐허", "부루의 웅덩이", "desert", { { "hivezara_stinger", 35 }, { "silicate_feeder", 35 }, { "hivezara_soldier_2", 30 } },
		X("먹보 부루", "INV_Misc_AhnQirajTrinket_04", "undead", "lord", { smash(8, 2.5, "shadow"), aoe(10, 1.1, "shadow", { "stun", 0.25 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("안퀴라즈 폐허", "아야미스의 둥지", "desert", { { "hivezara_wasp", 40 }, { "hivezara_tail_lasher", 30 }, { "hivezara_sandstalker", 30 } },
		X("사냥꾼 아야미스", "Spell_Nature_InsectSwarm", "undead", "brute", { smash(6, 2.6), aoe(11, 1.2, "frost", { "chill", 0.6 }), enrage(0.3, 1.5) })),
	st("안퀴라즈 폐허", "수정 신전", "ruins", { { "spitting_scarab", 35 }, { "qiraji_swarmguard_2", 35 }, { "anubisath_guardian_3", 30 } },
		X("무적의 오시리안", "INV_Misc_AhnQirajTrinket_04", "undead", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "hivezara_hatchling", 2), shield(28, 6, 65), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("아즈샤라", "아주어고스의 호수", "sea", { { "blue_scalebane", 35 }, { "spitelash_myrmidon", 35 }, { "thunderhead_stagwing", 30 } },
		X("아주어고스", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { aoe(8, 1.2, "frost", { "chill", 1 }), smash(11, 2.7, "frost", { "freeze", 1 }), enrage(0.25, 1.6) }, { school = "frost", res = { fire = -20, frost = 80 } })),
	st("저주받은 땅", "오염된 흉터", "fel", { { "felguard_sentry", 50 }, { "dreadmaul_ogre", 50 } },
		X("군주 카자크", "Spell_Shadow_SummonFelHunter", "demon", "lord", { aoe(8, 1.2, "shadow"), smash(9, 2.7, "frost", { "freeze", 0.7 }), summon(16, "felhound_2", 3), shield(30, 6, 70), enrage(0.2, 1.6) }, { school = "frost", res = { frost = 60, shadow = 60 } })),
})

------------------------------------------------------------------------
-- Mythic+: the raids, from Molten Core to Naxxramas
------------------------------------------------------------------------
ns.STAGES[4] = finish({
	-- Act 1: 화산 심장부
	st("화산 심장부", "화산 심장부 입구", "lava", { { "flamewaker_protector", 40 }, { "firewalker", 30 }, { "molten_giant", 30 } },
		X("루시프론", "Spell_Fire_Elemental_Totem", "humanoid", "brute", { aoe(8, 1.1, "fire", { "ignite", 0.7 }), smash(11, 2.6, "fire"), enrage(0.3, 1.4) }, { school = "fire", res = { fire = 70, frost = -25 } })),
	st("화산 심장부", "마그마다르의 굴", "lava", { { "flameguard", 40 }, { "flamewaker_priest", 30 }, { "lava_annihilator", 30 } },
		X("마그마다르", "Spell_Fire_Elemental_Totem", "beast", "brute", { smash(7, 2.7, "shadow"), summon(16, "core_hound", 2), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("화산 심장부", "게헨나스의 길", "lava", { { "flamewaker_elite", 35 }, { "firewalker_2", 35 }, { "molten_destroyer", 30 } },
		X("게헨나스", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(8, 1.2, "frost", { "chill", 1 }), summon(16, "flamewaker", 2), shield(26, 6, 65) }, { school = "frost", res = { frost = 60 } })),
	st("화산 심장부", "가르의 용암지", "lava", { { "firesworn", 30 }, { "firelord", 35 }, { "flameguard_2", 35 } },
		X("가르", "Spell_Fire_Elemental_Totem", "elemental", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "nature"), shield(26, 6, 65) }, { res = { phys = 20, nature = 60 } })),
	st("화산 심장부", "샤즈라의 동굴", "lava", { { "molten_destroyer_2", 35 }, { "flamewaker_2", 35 }, { "firelord_2", 30 } },
		X("샤즈라", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.5, "nature", { "stun", 0.6 }), summon(16, "flamewaker_elite_2", 3) }, { school = "shadow" })),
	st("화산 심장부", "게돈의 섬", "lava", { { "flamewaker_elite_3", 40 }, { "flamewaker_healer", 30 }, { "molten_giant_2", 30 } },
		X("남작 게돈", "Spell_Fire_Elemental_Totem", "elemental", "lord", { smash(8, 2.6, "shadow"), summon(16, "lava_spawn", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("화산 심장부", "골레마그의 다리", "lava", { { "core_rager", 35 }, { "firewalker_3", 40 }, { "flameguard_3", 25 } },
		X("초열의 골레마그", "Spell_Shadow_AbominationExplosion", "mechanical", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), enrage(0.3, 1.5) }, { school = "nature", res = { nature = 70 } })),
	st("화산 심장부", "설퍼론의 통로", "lava", { { "flamewaker_protector_2", 35 }, { "firewalker_4", 35 }, { "core_rager_2", 30 } },
		X("설퍼론 선구자", "Spell_Fire_Elemental_Totem", "humanoid", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "fire", { "ignite", 0.6 }), summon(18, "flamewaker_priest_2", 2), enrage(0.25, 1.5) }, { school = "shadow", res = { fire = 50, shadow = 50 } })),
	st("화산 심장부", "청지기의 방", "lava", { { "flamewaker_elite_4", 40 }, { "flamewaker_healer_2", 25 }, { "lava_annihilator_2", 35 } },
		X("청지기 이그젝큐투스", "Spell_Fire_Elemental_Totem", "humanoid", "swift", { smash(5, 2.4, "fire", { "ignite", 1 }), aoe(11, 1.2, "fire"), enrage(0.4, 1.5) }, { school = "fire", res = { fire = 70 } })),
	st("화산 심장부", "라그나로스의 영역", "lava", { { "firelord_3", 50 }, { "molten_destroyer_3", 50 } },
		X("라그나로스", "Spell_Fire_Elemental_Totem", "elemental", "brute", { aoe(9, 1.05, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(20, "son_of_flame", 2), shield(32, 6, 60), enrage(0.2, 1.4) }, { school = "fire", res = { fire = 70, shadow = 50 } })),
	-- Act 2: 검은날개와 안퀴라즈
	st("오닉시아의 둥지", "오닉시아의 둥지", "cave", { { "onyxian_warder", 40 }, { "onyxian_drake", 30 }, { "onyxian_whelp", 30 } },
		X("오닉시아", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "shadow"), summon(16, "onyxian_whelp", 2), shield(26, 6, 65) }, { school = "shadow", res = { shadow = 70 } })),
	st("검은날개 둥지", "알 부화장", "lava", { { "death_talon_hatcher", 40 }, { "blackwing_taskmaster", 30 }, { "death_talon_dragonspawn", 30 } },
		X("폭군 서슬송곳니", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "frost", { "chill", 0.7 }), smash(12, 2.5, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "frost", res = { frost = 60 } })),
	st("검은날개 둥지", "타락한 용의 방", "lava", { { "blackwing_mage", 45 }, { "blackwing_warlock", 30 }, { "blackwing_legionnaire", 25 } },
		X("타락한 밸라스트라즈", "INV_Misc_Head_Dragon_Black", "dragonkin", "swift", { smash(6, 2.3), summon(13, "blackwing_technician", 3), enrage(0.3, 1.4) })),
	st("검은날개 둥지", "감시의 통로", "lava", { { "blackwing_technician_2", 40 }, { "death_talon_seether", 35 }, { "blackwing_guardsman", 25 } },
		X("용기대장 래쉬레이어", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7), aoe(11, 1.2, "nature", { "stun", 0.3 }), summon(18, "death_talon_wyrmguard", 2) }, { res = { nature = 50 } })),
	st("검은날개 둥지", "크로마구스의 굴", "lava", { { "death_talon_flamescale", 40 }, { "death_talon_wyrmguard_2", 25 }, { "death_talon_captain", 35 } },
		X("크로마구스", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "shadow"), enrage(0.4, 1.6) }, { school = "shadow", res = { shadow = 70 } })),
	st("검은날개 둥지", "네파리안의 방", "lava", { { "blackwing_spellbinder", 35 }, { "death_talon_wyrmkin", 35 }, { "death_talon_overseer", 30 } },
		X("네파리안", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(6, 2.8, nil, { "stun", 0.4 }), summon(16, "chromatic_drakonid", 2), shield(26, 6, 65), enrage(0.3, 1.5) })),
	st("안퀴라즈 사원", "예언자의 계단", "shadow", { { "vekniss_soldier", 40 }, { "vekniss_wasp", 30 }, { "qiraji_mindslayer", 30 } },
		X("예언자 스케람", "INV_Misc_AhnQirajTrinket_02", "beast", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "vekniss_warrior", 2), shield(26, 6, 65) }, { school = "nature", res = { nature = 60 } })),
	st("안퀴라즈 사원", "벌레 둥지", "shadow", { { "vekniss_warrior", 45 }, { "vekniss_stinger", 30 }, { "vekniss_drone", 25 } },
		X("공주 후후란", "Spell_Nature_InsectSwarm", "beast", "lord", { smash(7, 2.6, nil, { "poison", 1 }), aoe(10, 1.2, "shadow", { "stun", 0.3 }), summon(18, "vekniss_hive_crawler", 3), enrage(0.3, 1.5) }, { school = "shadow" })),
	st("안퀴라즈 사원", "쌍둥이 황제의 방", "shadow", { { "qiraji_champion", 35 }, { "obsidian_eradicator", 30 }, { "anubisath_warder", 35 } },
		X("제왕 베크닐라쉬", "INV_Misc_AhnQirajTrinket_02", "humanoid", "lord", { aoe(7, 1.3, "nature", { "shock", 0.7 }), smash(10, 2.7, "nature", { "stun", 0.5 }), shield(28, 6, 70), enrage(0.25, 1.5) }, { school = "nature", res = { nature = 80 } })),
	st("안퀴라즈 사원", "크툰의 방", "shadow", { { "anubisath_warder_2", 45 }, { "obsidian_nullifier", 30 }, { "eye_tentacle", 25 } },
		X("크툰", "INV_Misc_Eye_01", "humanoid", "lord", { smash(8, 2.4, nil, { "bleed", 0.6 }), aoe(11, 1.05, "shadow"), summon(20, "claw_tentacle", 2), shield(32, 6, 55), enrage(0.2, 1.4) }, { res = { shadow = 40 } })),
	-- Act 3: 낙스라마스
	st("낙스라마스", "아눕레칸의 방", "ice", { { "crypt_reaver", 40 }, { "necro_stalker", 30 }, { "venom_stalker", 30 } },
		X("아눕레칸", "Spell_Shadow_RaiseDead", "undead", "caster", { aoe(7, 1.3, "frost", { "chill", 1 }), smash(11, 2.6, "nature", { "shock", 1 }), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 70, nature = 50 } })),
	st("낙스라마스", "파르리나의 방", "ice", { { "naxxramas_cultist", 30 }, { "naxxramas_acolyte", 35 }, { "necro_knight", 35 } },
		X("귀부인 팰리나", "INV_Misc_Head_Human_02", "humanoid", "brute", { aoe(8, 1.3, "nature", { "poison", 0.7 }), smash(11, 2.7, "shadow"), summon(18, "naxxramas_worshipper", 2) }, { school = "nature", res = { nature = 70 } })),
	st("낙스라마스", "맥스나의 둥지", "ice", { { "carrion_spinner", 40 }, { "dread_creeper", 30 }, { "tomb_horror", 30 } },
		X("맥스나", "Ability_Hunter_Pet_Spider", "beast", "caster", { aoe(7, 1.3, "shadow"), smash(11, 2.6, "shadow", { "stun", 0.6 }), shield(26, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 70 } })),
	st("낙스라마스", "역병 지구", "ice", { { "plague_beast", 40 }, { "infectious_ghoul", 30 }, { "plagued_gargoyle", 30 } },
		X("역병술사 노스", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(6, 2.9, nil, { "stun", 0.5 }), aoe(11, 1.2, "nature"), enrage(0.3, 1.5) })),
	st("낙스라마스", "헤이건의 방", "ice", { { "plague_slime", 40 }, { "mutated_grub", 30 }, { "frenzied_bat", 30 } },
		X("부정의 헤이건", "Spell_Shadow_RaiseDead", "undead", "lord", { smash(7, 2.7, "fire", { "ignite", 1 }), aoe(10, 1.2, "fire"), shield(26, 6, 70), enrage(0.3, 1.5) }, { school = "fire" })),
	st("낙스라마스", "로데브의 방", "ice", { { "eye_stalk", 35 }, { "plagued_ghoul", 35 }, { "plague_beast_2", 30 } },
		X("로데브", "Spell_Shadow_RaiseDead", "undead", "caster", { aoe(7, 1.3, "arcane"), smash(11, 2.6, "arcane", { "freeze", 0.6 }), summon(18, "spore", 2), shield(28, 6, 70) }, { school = "arcane", res = { arcane = 70 } })),
	st("낙스라마스", "수확의 방", "ice", { { "deathknight_captain", 35 }, { "necro_knight_2", 30 }, { "shade_of_naxxramas", 35 } },
		X("영혼 착취자 고딕", "Spell_Shadow_DeathCoil", "undead", "caster", { aoe(7, 1.3, "fire", { "ignite", 0.7 }), smash(10, 2.7, "shadow"), summon(16, "unrelenting_trainee", 2), enrage(0.25, 1.6) }, { school = "shadow", res = { fire = 60, shadow = 60 } })),
	st("낙스라마스", "타디우스의 실험실", "ice", { { "living_monstrosity", 35 }, { "mad_scientist", 35 }, { "stitched_spewer", 30 } },
		X("타디우스", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(6, 2.9), aoe(9, 1.3, "fire"), shield(28, 6, 70), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60, shadow = 60 } })),
	st("낙스라마스", "네 기사의 방", "ice", { { "deathknight_vindicator", 35 }, { "ghost_of_naxxramas", 30 }, { "unholy_staff", 35 } },
		X("대영주 모그레인", "Spell_Shadow_DeathCoil", "undead", "brute", { smash(5, 2.8, "fire", { "ignite", 1 }), aoe(9, 1.3, "fire"), summon(18, "deathknight_cavalier", 2), enrage(0.3, 1.6) }, { school = "fire", res = { fire = 80 } })),
	st("낙스라마스", "켈투자드의 방", "ice", { { "deathknight", 50 }, { "necro_knight_3", 50 } },
		X("켈투자드", "Spell_Frost_FrostArmor02", "undead", "lord", { aoe(7, 1.4, "shadow"), smash(9, 2.9, "fire", { "ignite", 1 }), summon(15, "soul_weaver", 3), shield(30, 7, 75), enrage(0.2, 1.7) }, { school = "shadow", res = { fire = 70, shadow = 70, arcane = 50 } })),
})

------------------------------------------------------------------------
-- Derived values
------------------------------------------------------------------------
function ns.Stage(diff, idx)
	return ns.STAGES[diff][idx]
end

-- idx: 1..30 (act and stage folded into one running index); TBH's stage
-- levels (Data/TBH.lua)
function ns.StageLevel(diff, idx)
	return ns.TBH.STAGES[diff][idx].lv
end

function ns.StageAct(idx)
	return math.floor((idx - 1) / ns.STAGES_PER_ACT) + 1, (idx - 1) % ns.STAGES_PER_ACT + 1
end

function ns.StageLabel(diff, idx)
	local act, n = ns.StageAct(idx)
	return string.format("%d-%d %s", act, n, ns.N(ns.STAGES[diff][idx].name))
end

-- A stage's monsters are TBH's (waves x per wave): as many in all, but at
-- most WAVE_CAP[difficulty] at once (what a fight here is built for), then
-- the boss alone.
ns.WAVE_CAP = { 4, 5, 6, 7 }
ns.MAX_WAVE_MOBS = 7
function ns.StageKills(diff, idx)
	local t = ns.TBH.STAGES[diff][idx]
	return t.waves * t.per
end
function ns.MobsPerWave(diff, idx)
	return math.min(ns.WAVE_CAP[diff] or ns.MAX_WAVE_MOBS, ns.TBH.STAGES[diff][idx].per)
end
-- every wave, the boss's last
function ns.StageWaves(diff, idx)
	local per = ns.MobsPerWave(diff, idx)
	local kills = ns.StageKills(diff, idx)
	return (per > 0 and math.ceil(kills / per) or 0) + 1
end

-- Every stage's monsters on one footing: their average health and attack,
-- and the boss's, come to the same base, so how hard a stage is comes from
-- its level (TBH's) alone; each monster keeps its build next to the others.
local NORM = { hp = 65.7, dps = 5.44, bossHP = 750, bossThreat = 4.0 }
-- how hard a monster hits: armor takes about half of a physical blow, and a
-- burning, poisoning or bleeding hit keeps on hurting
function ns.MobThreat(m)
	local t = m.atk * (m.aspd or 1)
	if not m.school or m.school == "phys" then t = t * 0.5 end
	if m.status then t = t * (1 + (m.status[2] or 0)) end
	return t
end
function ns.StageNorm(diff, idx)
	local stg = ns.STAGES[diff] and ns.STAGES[diff][idx]
	if not stg then return nil end
	if not stg.norm then
		local hp, dps, w = 0, 0, 0
		for _, e in ipairs(stg.mobs) do
			local m = ns.MONSTERS[e[1]]
			hp = hp + m.hp * e[2]
			dps = dps + ns.MobThreat(m) * e[2]
			w = w + e[2]
		end
		local b = stg.boss
		local k = b.build and BUILD[b.build]
		stg.norm = {
			hp = NORM.hp * w / hp, atk = NORM.dps * w / dps,
			bossHP = NORM.bossHP * (k and k.hp or 1) * (stg.raid and 2 or 1) / b.hp,
			bossAtk = NORM.bossThreat * (k and k.atk or 1) / ns.MobThreat(b),
		}
	end
	return stg.norm
end

-- Monster strength on top of the base growth, by stage level: { level,
-- times } points, followed in a straight line on a log scale between them.
-- It sets how long each part of the climb takes (tests/pace: TBH's hours).
ns.MIGHT = { { 1, 1 }, { 25, 1 }, { 100, 13.8 } }
function ns.MobMight(l)
	local k = ns.MIGHT
	if l <= k[1][1] then return k[1][2] end
	for i = 2, #k do
		local a, b = k[i - 1], k[i]
		if l <= b[1] then
			local f = (l - a[1]) / (b[1] - a[1])
			return a[2] * (b[2] / a[2]) ^ f
		end
	end
	return k[#k][2]
end
-- The gear level a party has at stage level l: boxes give gear in TBH's
-- steps (1, 5, 10, ... 100), and the first stages of a step are fought with
-- the step before's gear, so it climbs from that step to this one.
function ns.GearAt(l)
	local L = ns.TBH.ITEM_LEVELS
	for i = 2, #L do
		if l < L[i] then
			local lo, hi, prev = L[i - 1], L[i], L[i - 2] or L[1]
			return prev + (lo - prev) * (l - lo) / (hi - lo)
		end
	end
	return L[#L]
end
-- Monsters grow with that gear level, and a little (MOB_BAND) with the
-- stage level past it, which the heroes' own levels make up for.
ns.MOB_BAND = 0.3
function ns.MobLevel(l)
	local g = ns.GearAt(l)
	return g + ns.MOB_BAND * (l - g)
end
function ns.MobHP(base, l)
	local m = ns.MobLevel(l)
	return base * (1 + 0.25 * (m - 1)) * 1.07 ^ (m - 1) * ns.MobMight(l)
end
function ns.MobAtk(base, l)
	local m = ns.MobLevel(l)
	return base * (1 + 0.12 * (m - 1)) * 1.05 ^ (m - 1) * ns.MobMight(l)
end
function ns.MobGold(base, l) return base * (1 + 0.15 * (l - 1)) * 1.04 ^ (l - 1) end
-- experience grows with the stage level as TBH's (Data/TBH.lua)
function ns.MobExp(base, l)  return ns.EXP_RATE * base * ns.TBH.MULT[math.max(1, math.min(100, l))][4] end
ns.EXP_RATE = 1.2 -- every monster's experience

-- Physical mitigation threshold: armor equal to this halves physical damage.
function ns.ArmorK(l)
	return 30 + 20 * l
end
