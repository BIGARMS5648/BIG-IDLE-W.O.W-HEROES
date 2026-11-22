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
	{ name = "일반",   hex = "e8e8e8", base = 1,  step = 1.00, mobs = 1, bossHP = 1.0,
		world = "모험의 시작",
		acts = { "성난불길 협곡", "검은심연 나락", "붉은십자군 수도원" } },
	{ name = "영웅",   hex = "3ddc5a", base = 32, step = 0.80, mobs = 3, bossHP = 1.5,
		world = "넓어지는 세계",
		acts = { "줄파락", "검은바위 나락", "스칼로맨스" } },
	{ name = "신화",   hex = "b266ff", base = 57, step = 0.70, mobs = 4, bossHP = 2.0,
		world = "전장과 고대의 힘",
		acts = { "전장과 혈투의 전장", "세계의 우두머리", "줄구룹" } },
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

-- place: the dungeon or raid; name: the area of it the stage is fought in
local function st(place, name, theme, mobs, boss)
	return { place = place, name = name, theme = theme, mobs = mobs, boss = boss }
end

ns.STAGES = {}

------------------------------------------------------------------------
-- Normal: Elwynn Forest to the Scarlet Monastery
------------------------------------------------------------------------
ns.STAGES[1] = finish({
	-- Act 1: 성난불길 협곡
	st("엘윈 숲", "엘윈 숲", "forest", { { "kobold_worker", 50 }, { "prowler", 50 } },
		B("들창코", "INV_Misc_Head_Human_02", "humanoid", 150, 7, 0.7, { skills = { smash(9, 2.2) } })),
	st("서부 몰락지대", "서부 몰락지대", "plains", { { "riverpaw_gnoll", 35 }, { "defias_trapper", 35 }, { "harvest_golem", 30 } },
		B("허수아비골렘 수확기", "INV_Gizmo_02", "mechanical", 240, 8, 0.6, { skills = { smash(9, 2.2) } })),
	st("티리스팔 숲", "티리스팔 숲", "forest", { { "scarlet_convert", 40 }, { "scarlet_neophyte", 30 }, { "scarlet_missionary", 30 } },
		B("대장 페린", "Spell_Shadow_DeathCoil", "humanoid", 300, 10, 0.9, { skills = { smash(8, 2), summon(18, "scarlet_warrior", 2) } })),
	st("로데론의 폐허", "로데론의 폐허", "ruins", { { "rotting_dead", 45 }, { "ravaged_corpse", 30 }, { "bleeding_horror", 25 } },
		B("펠리센트의 유령", "Spell_Shadow_Possession", "undead", 360, 11, 0.7, { skills = { smash(9, 2.2) } })),
	st("죽음의 폐광", "죽음의 폐광", "cave", { { "defias_miner", 35 }, { "defias_overseer", 35 }, { "defias_taskmaster", 30 } },
		B("에드윈 밴클리프", "INV_Misc_Head_Human_01", "humanoid", 460, 11, 0.6, { skills = { smash(9, 2.2), aoe(13, 0.8, "nature", { "poison", 0.5 }) } })),
	st("던 모로", "던 모로", "snow", { { "ice_claw_bear", 35 }, { "frostmane_seer", 30 }, { "snow_leopard", 35 } },
		B("늙은 얼음수염", "INV_Misc_Head_Human_02", "humanoid", 440, 13, 1, { skills = { smash(8, 2), summon(20, "ice_claw_bear_2", 2) } })),
	st("듀로타", "듀로타", "desert", { { "dreadmaw_crocolisk", 35 }, { "burning_blade_apprentice", 30 }, { "razormane_quilboar", 35 } },
		B("사르코스", "Ability_Hunter_Pet_Bear", "beast", 560, 12, 0.6, { skills = { smash(9, 2.2) } })),
	st("멀고어", "멀고어", "plains", { { "bristleback_battleboar", 40 }, { "bristleback_shaman", 25 }, { "adult_plainstrider", 35 } },
		B("족장 칼날엄니", "INV_Misc_Head_Human_02", "humanoid", 520, 13, 0.7, { school = "shadow", skills = { aoe(11, 0.9, "shadow"), summon(20, "bristleback_battleboar", 2) } })),
	st("텔드랏실", "텔드랏실", "forest", { { "gnarlpine_warrior", 40 }, { "timberling", 30 }, { "gnarlpine_mystic", 30 } },
		B("제왕 멜레나스", "Spell_Shadow_SummonFelHunter", "demon", 600, 14, 0.8, { skills = { smash(9, 2.2), aoe(12, 0.9, "fire", { "ignite", 0.4 }) } })),
	st("성난불길 협곡", "성난불길 협곡", "lava", { { "earthborer", 50 }, { "molten_elemental", 50 } },
		B("욕망의 타라가만", "Spell_Shadow_SummonImp", "humanoid", 1500, 16, 0.6, { school = "fire", res = { fire = 75, frost = -25 }, skills = { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(24, "searing_blade_cultist", 3), enrage(0.25, 1.4) } })),
	-- Act 2: 검은심연 나락
	st("불모의 땅", "불모의 땅", "plains", { { "savannah_huntress", 35 }, { "sunscale_lashtail", 35 }, { "razormane_hunter", 30 } },
		B("바라크 코도베인", "INV_Misc_Head_Human_02", "humanoid", 420, 10, 0.7, { skills = { smash(9, 2.2) } })),
	st("은빛소나무 숲", "은빛소나무 숲", "forest", { { "moonrage_darkrunner", 35 }, { "ferocious_grizzled_bear", 30 }, { "worg", 35 } },
		B("포악한 이바르", "Spell_Shadow_RaiseDead", "undead", 480, 12, 0.9, { skills = { smash(8, 2), summon(18, "moonrage_glutton", 2) } })),
	st("어둠해안", "어둠해안", "sea", { { "moonstalker", 35 }, { "greymist_seer", 30 }, { "encrusted_tide_crawler", 35 } },
		B("먹구렁", "INV_Misc_Head_Human_02", "humanoid", 560, 12, 0.7, { skills = { smash(9, 2.3), aoe(14, 0.8, "nature", { "stun", 0.25 }) } })),
	st("통곡의 동굴", "통곡의 동굴", "cave", { { "druid_of_the_fang", 40 }, { "deviate_lurker", 30 }, { "deviate_adder", 30 } },
		B("걸신들린 무타누스", "INV_Misc_Head_Murloc_01", "humanoid", 680, 12, 0.5, { res = { fire = -30, nature = 50 }, skills = { smash(8, 2.6), shield(22, 6, 60) } })),
	st("모단 호수", "모단 호수", "forest", { { "stonesplinter_seer", 40 }, { "stonesplinter_trogg", 35 }, { "elder_black_bear", 25 } },
		B("커브", "INV_Misc_Head_Human_02", "humanoid", 540, 14, 0.8, { school = "nature", range = 420, skills = { aoe(10, 1, "nature", { "shock", 0.5 }) } })),
	st("붉은마루 산맥", "붉은마루 산맥", "desert", { { "great_goretusk", 30 }, { "blackrock_grunt", 35 }, { "redridge_mongrel", 35 } },
		B("가스일조그", "INV_Misc_Head_Human_02", "humanoid", 620, 14, 0.9, { skills = { smash(8, 2.2), summon(18, "blackrock_grunt", 2) } })),
	st("그림자송곳니 성채", "그림자송곳니 성채", "shadow", { { "bleak_worg", 25 }, { "slavering_worg", 40 }, { "shadowfang_darksoul", 35 } },
		B("대마법사 아루갈", "Spell_Holy_MagicalSentry", "humanoid", 820, 15, 0.5, { skills = { smash(7, 2.8), enrage(0.3, 1.4) } })),
	st("잿빛 골짜기", "잿빛 골짜기", "forest", { { "ashenvale_bear", 40 }, { "foulweald_shaman", 30 }, { "ghostpaw_runner", 30 } },
		B("우르산고우스", "Ability_Hunter_Pet_Bear", "beast", 760, 14, 0.8, { skills = { aoe(12, 0.9, "nature", { "poison", 0.6 }), summon(16, "ashenvale_bear", 3) } })),
	st("그늘숲", "그늘숲", "shadow", { { "nightbane_vile_fang", 30 }, { "skeletal_warrior", 40 }, { "pygmy_venom_web_spider", 30 } },
		B("누더기", "Spell_Shadow_RaiseDead", "undead", 900, 16, 0.6, { skills = { smash(8, 2.6), shield(20, 6, 70), enrage(0.3, 1.3) } })),
	st("검은심연 나락", "검은심연 나락", "sea", { { "blackfathom_myrmidon", 40 }, { "twilight_reaver", 60 } },
		B("아쿠마이", "Ability_Hunter_Pet_Crocolisk", "aberration", 1900, 15, 0.7, { school = "shadow", res = { shadow = 50 }, skills = { aoe(9, 1, "shadow"), summon(18, "blackfathom_tide_priestess", 2), shield(30, 7, 75), enrage(0.2, 1.5) } })),
	-- Act 3: 붉은십자군 수도원
	st("돌발톱 산맥", "돌발톱 산맥", "desert", { { "venture_co_logger", 35 }, { "deepmoss_creeper", 35 }, { "windfury_sorceress", 30 } },
		B("게렌조 렌치휘슬", "INV_Misc_Head_Human_02", "humanoid", 700, 13, 0.6, { res = { frost = 50 }, skills = { smash(8, 2.5, nil, { "stun", 0.5 }) } })),
	st("스톰윈드 지하감옥", "스톰윈드 지하감옥", "ruins", { { "defias_convict", 40 }, { "defias_inmate", 30 }, { "defias_insurgent", 30 } },
		B("바질 스레드", "INV_Misc_Head_Human_01", "humanoid", 760, 14, 0.6, { school = "frost", res = { fire = -30, frost = 75 }, skills = { aoe(10, 1, "frost", { "chill", 1 }) } })),
	st("저습지", "저습지", "swamp", { { "fen_creeper", 35 }, { "dragonmaw_shadowwarder", 30 }, { "mosshide_brute", 35 } },
		B("마룩 웜스케일", "INV_Misc_Head_Human_02", "humanoid", 980, 14, 0.5, { skills = { smash(7, 2.6), aoe(14, 0.8, "nature", { "poison", 0.6 }) } })),
	st("힐스브래드 구릉지", "힐스브래드 구릉지", "forest", { { "torn_fin_oracle", 30 }, { "syndicate_footpad", 40 }, { "elder_moss_creeper", 30 } },
		B("앨리덴 페레놀드 경", "INV_Misc_Head_Human_02", "humanoid", 800, 16, 0.6, { school = "shadow", range = 430, skills = { aoe(9, 1, "shadow"), summon(14, "syndicate_enforcer", 3) } })),
	st("놈리건", "놈리건", "cave", { { "leprous_defender", 35 }, { "caverndeep_burrower", 35 }, { "dark_iron_agent", 30 } },
		B("기계박사 텔마플러그", "INV_Gizmo_02", "mechanical", 940, 16, 0.8, { school = "shadow", skills = { smash(8, 2.3), summon(16, "walking_bomb", 3), enrage(0.3, 1.3) } })),
	st("버섯구름 봉우리", "버섯구름 봉우리", "desert", { { "galak_scout", 30 }, { "galak_windchaser", 35 }, { "galak_packhound", 35 } },
		B("아르낙 그림토템", "INV_Misc_Head_Human_02", "humanoid", 1100, 16, 0.7, { school = "shadow", res = { shadow = 50 }, skills = { aoe(8, 1.1, "shadow"), enrage(0.35, 1.5) } })),
	st("가시덩굴 우리", "가시덩굴 우리", "jungle", { { "razorfen_quilguard", 40 }, { "razorfen_geomancer", 30 }, { "greater_kraul_bat", 30 } },
		B("서슬깃 차를가", "INV_Misc_Head_Quillboar_01", "humanoid", 1150, 17, 0.7, { res = { fire = 50 }, skills = { smash(8, 2.4), aoe(11, 1, "fire", { "ignite", 0.6 }) } })),
	st("아라시 고원", "아라시 고원", "plains", { { "boulderfist_brute", 40 }, { "highland_thrasher", 30 }, { "witherbark_axe_thrower", 30 } },
		B("왕자 나자크", "INV_Misc_Head_Human_02", "humanoid", 1400, 18, 0.7, { school = "fire", res = { fire = 60 }, skills = { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "daggerspine_shorehunter", 2) } })),
	st("가시덤불 골짜기", "가시덤불 골짜기", "jungle", { { "jungle_stalker", 35 }, { "bloodscalp_berserker", 30 }, { "shadowmaw_panther", 35 } },
		B("야수왕 뱅갈라시", "Ability_Hunter_Pet_Bear", "beast", 1700, 17, 1, { skills = { smash(5, 2.6), enrage(0.2, 1.6) } })),
	st("붉은십자군 수도원", "붉은십자군 수도원", "holy", { { "scarlet_champion", 50 }, { "scarlet_monk", 50 } },
		B("종교재판관 화이트메인", "Spell_Holy_Excorcism", "humanoid", 2400, 17, 0.7, { school = "frost", res = { frost = 60, shadow = 40 }, range = 600, skills = { aoe(8, 1.1, "frost", { "chill", 1 }), smash(10, 2.4, "shadow", { "freeze", 1 }), summon(16, "scarlet_chaplain", 3), shield(32, 6, 70), enrage(0.2, 1.5) } })),
})

------------------------------------------------------------------------
-- Heroic: the Badlands to Scholomance
------------------------------------------------------------------------
ns.STAGES[2] = finish({
	-- Act 1: 줄파락
	st("황야의 땅", "황야의 땅", "desert", { { "dustbelcher_brute", 40 }, { "ridge_huntress", 35 }, { "crag_coyote", 25 } },
		X("철옹성", "Spell_Shadow_AbominationExplosion", "mechanical", "brute", { smash(8, 2.5), enrage(0.3, 1.3) }, { school = "fire" })),
	st("가시덩굴 구릉", "가시덩굴 구릉", "shadow", { { "splinterbone_warrior", 45 }, { "deaths_head_necromancer", 30 }, { "withered_battle_boar", 25 } },
		X("혹한의 암네나르", "Spell_Frost_FrostArmor02", "undead", "lord", { smash(8, 2.2), summon(18, "skeletal_summoner", 2) })),
	st("잊혀진 땅", "잊혀진 땅", "desert", { { "magram_wrangler", 35 }, { "burning_blade_summoner", 35 }, { "kolkar_destroyer", 30 } },
		X("제왕 아즈레토크", "Spell_Shadow_SummonFelHunter", "demon", "caster", { aoe(9, 1, "shadow"), smash(12, 2.2, "fire", { "ignite", 1 }) }, { school = "shadow" })),
	st("먼지진흙 습지대", "먼지진흙 습지대", "swamp", { { "mirefin_warrior", 45 }, { "bloodfen_razormaw", 30 }, { "mirefin_oracle", 25 } },
		X("대군주 모크모로크", "INV_Misc_Head_Human_02", "humanoid", "swift", { smash(6, 2, nil, { "bleed", 1 }), aoe(13, 0.9, "phys") })),
	st("슬픔의 늪", "슬픔의 늪", "swamp", { { "marsh_oracle", 35 }, { "swamp_talker", 25 }, { "swamp_jaguar", 40 } },
		X("군주 웜막", "Spell_Shadow_DeathCoil", "dragonkin", "brute", { smash(8, 2.3), aoe(12, 0.8, "nature", { "poison", 0.6 }) }, { res = { fire = -25, nature = 50 } })),
	st("울다만", "울다만", "cave", { { "stonevault_brawler", 40 }, { "shadowforge_sharpshooter", 30 }, { "jadespine_basilisk", 30 } },
		X("아카에다스", "Spell_Nature_Earthquake", "giant", "brute", { smash(7, 2.6), aoe(13, 0.8, "nature", { "poison", 0.7 }) })),
	st("무법항", "무법항", "sea", { { "bloodsail_swashbuckler", 35 }, { "bloodsail_mage", 30 }, { "bloodsail_warlock", 35 } },
		X("함장 피랠론", "INV_Misc_Head_Human_02", "humanoid", "lord", { smash(8, 2.4), enrage(0.35, 1.4), shield(24, 6, 55) })),
	st("페랄라스", "페랄라스", "forest", { { "gordunni_mage_lord", 35 }, { "longtooth_runner", 35 }, { "woodpaw_brute", 30 } },
		X("군주 샬자루", "INV_Misc_Head_Human_02", "humanoid", "swift", { smash(7, 2.1), shield(22, 6, 60) })),
	st("동부 내륙지", "동부 내륙지", "forest", { { "vilebranch_berserker", 40 }, { "vilebranch_witch_doctor", 35 }, { "vilebranch_raiding_wolf", 25 } },
		X("타락한 여사제 헥스", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(8, 1.1, "arcane"), smash(12, 2, "arcane", { "stun", 0.6 }) }, { school = "arcane" })),
	st("줄파락", "줄파락", "desert", { { "sandfury_blood_drinker", 50 }, { "sandfury_shadowcaster", 50 } },
		X("족장 우코르즈 샌드스칼프", "INV_Misc_Head_Troll_01", "humanoid", "brute", { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(11, 2.6), summon(22, "sandfury_shadowhunter", 2), enrage(0.25, 1.4) }, { school = "fire", res = { fire = 60, shadow = 40 } })),
	-- Act 2: 검은바위 나락
	st("타나리스", "타나리스", "desert", { { "steeljaw_snapper", 30 }, { "scorpid_dunestalker", 35 }, { "dunemaul_ogre", 35 } },
		X("앙드레 파이어비어드", "Spell_Fire_Elemental_Totem", "humanoid", "brute", { smash(7, 2.7), enrage(0.3, 1.4) })),
	st("이글거리는 협곡", "이글거리는 협곡", "lava", { { "dark_iron_taskmaster", 40 }, { "greater_lava_spider", 25 }, { "heavy_war_golem", 35 } },
		X("감독관 말토류스", "INV_Misc_Head_Human_02", "humanoid", "lord", { smash(8, 2.4, nil, { "stun", 0.4 }), summon(20, "dark_iron_slaver", 2) })),
	st("마라우돈", "마라우돈", "jungle", { { "theradrim_guardian", 35 }, { "primordial_behemoth", 65 } },
		X("공주 테라드라스", "Spell_Nature_Thorns", "elemental", "brute", { smash(7, 2.6), aoe(13, 1, "phys", { "stun", 0.3 }), enrage(0.4, 1.5) })),
	st("아즈샤라", "아즈샤라", "sea", { { "spitelash_warrior", 35 }, { "blue_dragonspawn", 35 }, { "legashi_satyr", 30 } },
		X("여군주 세스피라", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(9, 1, "arcane"), summon(16, "blue_dragonspawn", 3) }, { school = "arcane" })),
	st("운고로 분화구", "운고로 분화구", "jungle", { { "ironhide_devilsaur", 35 }, { "frenzied_pterrordax", 35 }, { "living_blaze", 30 } },
		X("불바람", "Spell_Nature_StoneClawTotem", "elemental", "caster", { aoe(10, 1, "arcane"), summon(18, "living_blaze_2", 2), shield(26, 6, 50) }, { school = "arcane" })),
	st("아탈학카르 신전", "아탈학카르 신전", "swamp", { { "atalai_warrior", 45 }, { "atalai_witch_doctor", 25 }, { "nightmare_scalebane", 30 } },
		X("에라니쿠스의 사령", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(8, 2.5), summon(15, "nightmare_wyrmkin", 3) }, { res = { fire = -25, nature = 50 } })),
	st("악령의 숲", "악령의 숲", "fel", { { "jadefire_satyr", 30 }, { "jadefire_felsworn", 35 }, { "deadwood_warrior", 35 } },
		X("사바스라스", "Spell_Shadow_SummonFelHunter", "demon", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.2, "shadow", { "stun", 0.6 }), enrage(0.3, 1.3) }, { school = "shadow", res = { shadow = 50 } })),
	st("저주받은 땅", "저주받은 땅", "fel", { { "dreadmaul_brute", 40 }, { "felhound", 30 }, { "snickerfang_hyena", 30 } },
		X("파멸의 테레무스", "INV_Misc_Head_Dragon_Black", "dragonkin", "lord", { smash(8, 2.4, "shadow"), aoe(11, 1, "fire", { "ignite", 0.5 }), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("불타는 평원", "불타는 평원", "lava", { { "blackrock_soldier", 40 }, { "blackrock_summoner", 30 }, { "firegut_ogre_mage", 30 } },
		X("고르지키 와일드아이즈", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(8, 1, "nature", { "shock", 0.5 }), summon(16, "blackrock_soldier", 2), shield(26, 7, 70) }, { school = "nature", res = { frost = 40, nature = 40 } })),
	st("검은바위 나락", "검은바위 나락", "lava", { { "anvilrage_guardsman", 40 }, { "shadowforge_flame_keeper", 35 }, { "ragereaver_golem", 25 } },
		X("제왕 다그란 타우릿산", "INV_Misc_Head_Dwarf_02", "humanoid", "caster", { aoe(9, 1, "fire", { "ignite", 0.5 }), smash(12, 2.4, "fire"), summon(22, "fireguard_destroyer", 2), shield(32, 6, 60), enrage(0.2, 1.3) }, { school = "fire", res = { fire = 60, arcane = 40 } })),
	-- Act 3: 스칼로맨스
	st("서부 역병지대", "서부 역병지대", "shadow", { { "scarlet_sentinel", 30 }, { "scarlet_mage", 30 }, { "skeletal_executioner", 40 } },
		X("소환사 아라즈", "Spell_Shadow_ShadowBolt", "undead", "brute", { smash(7, 2.7), aoe(13, 1, "phys", { "stun", 0.3 }), enrage(0.25, 1.5) })),
	st("동부 역병지대", "동부 역병지대", "shadow", { { "cursed_mage", 40 }, { "plague_monstrosity", 30 }, { "crypt_horror", 30 } },
		X("군주 다크사이드", "Spell_Shadow_RaiseDead", "undead", "brute", { aoe(8, 1.2, "nature"), smash(12, 2.6, nil, { "stun", 0.6 }) }, { school = "nature" })),
	st("검은바위 첨탑 하층", "검은바위 첨탑 하층", "lava", { { "spirestone_enforcer", 40 }, { "bloodaxe_worg", 35 }, { "smolderthorn_axe_thrower", 25 } },
		X("대군주 웜타라크", "INV_Misc_Head_Dragon_Black", "dragonkin", "lord", { smash(8, 2.4), aoe(11, 1, "arcane", { "chill", 0.6 }) }, { school = "arcane" })),
	st("여명의 설원", "여명의 설원", "snow", { { "frostsaber_huntress", 40 }, { "winterfall_ursa", 35 }, { "ice_thistle_yeti", 25 } },
		X("아주로우스", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.6), aoe(12, 1, "arcane"), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 50 } })),
	st("실리더스", "실리더스", "desert", { { "hiveashi_worker", 35 }, { "twilight_avenger", 30 }, { "dust_stormer", 35 } },
		X("왕자 스칼레녹스", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(11, 2.6, "shadow"), summon(20, "twilight_flamereaver", 1), enrage(0.2, 1.5) }, { school = "shadow", res = { fire = 50, shadow = 50 } })),
	st("검은바위 첨탑 상층", "검은바위 첨탑 상층", "lava", { { "blackhand_dreadweaver", 35 }, { "rage_talon_dragonspawn", 35 }, { "chromatic_whelp", 30 } },
		X("대족장 렌드 블랙핸드", "INV_Misc_Head_Orc_01", "humanoid", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), aoe(12, 1, "nature", { "shock", 0.5 }), enrage(0.4, 1.4) })),
	st("혈투의 전장", "뒤틀린 숲", "forest", { { "warpwood_crusher", 35 }, { "wildspawn_satyr", 35 }, { "wildspawn_felsworn", 30 } },
		X("칼날바람 알진", "Spell_Shadow_UnholyStrength", "demon", "swift", { smash(6, 2.3, "shadow"), aoe(10, 1.1, "fire", { "ignite", 0.6 }), shield(28, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { fire = 40, shadow = 50 } })),
	st("스트라솔름", "스트라솔름 광장", "holy", { { "crimson_gallant", 35 }, { "crimson_sorcerer", 35 }, { "crimson_monk", 30 } },
		X("발나자르", "Spell_Shadow_SummonFelHunter", "demon", "caster", { aoe(9, 1, "holy"), summon(16, "crimson_initiate", 2), shield(24, 6, 60) }, { school = "holy" })),
	st("스칼로맨스", "스칼로맨스 강의실", "ruins", { { "scholomance_student", 30 }, { "scholomance_necromancer", 30 }, { "risen_guard", 40 } },
		X("들창엄니", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(5, 2.6, "fire", { "ignite", 1 }), aoe(12, 1.1, "fire"), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60 } })),
	st("스칼로맨스", "간들링의 강당", "shadow", { { "risen_construct", 50 }, { "scholomance_dark_summoner", 50 } },
		X("암흑스승 간들링", "Spell_Shadow_ShadowBolt", "humanoid", "caster", { aoe(8, 1.2, "fire", { "ignite", 0.6 }), smash(10, 2.5, "shadow"), summon(18, "risen_guardian", 3), shield(30, 6, 70), enrage(0.2, 1.5) }, { school = "shadow", res = { fire = 60, shadow = 60 }, range = 600 })),
})

------------------------------------------------------------------------
-- Mythic: the battlegrounds, the world bosses, Ahn'Qiraj and Zul'Gurub
------------------------------------------------------------------------
ns.STAGES[3] = finish({
	-- Act 1: 전장과 혈투의 전장
	st("전쟁노래 협곡", "전쟁노래 협곡", "forest", { { "horde_elite", 35 }, { "silverwing_elite", 25 }, { "warsong_outrider", 40 } },
		X("케르굴 블러드액스", "INV_Misc_Head_Orc_01", "humanoid", "caster", { aoe(9, 1, "shadow"), summon(16, "horde_elite_2", 3) }, { school = "shadow" })),
	st("아라시 분지", "아라시 분지", "plains", { { "defiler_elite", 35 }, { "league_of_arathor_elite", 30 }, { "highland_strider", 35 } },
		X("엘파란", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(8, 2.4, "frost", { "chill", 1 }), aoe(11, 1, "frost", { "freeze", 0.3 }), enrage(0.25, 1.4) }, { school = "frost", res = { fire = -25, frost = 60 } })),
	st("알터랙 계곡", "알터랙 계곡", "snow", { { "frostwolf_legionnaire", 40 }, { "frostwolf_shaman", 30 }, { "frostwolf_bowman", 30 } },
		X("드렉타르", "INV_Misc_Head_Human_02", "humanoid", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(18, "frostwolf_legionnaire_2", 3) })),
	st("알터랙 계곡", "던 발다르", "snow", { { "stormpike_defender", 45 }, { "stormpike_bowman", 30 }, { "stormpike_ram_rider", 25 } },
		X("반다르 스톰파이크", "INV_Misc_Head_Human_02", "humanoid", "brute", { smash(7, 2.6, nil, { "stun", 0.4 }), aoe(13, 1, "shadow"), enrage(0.5, 1.3) })),
	st("혈투의 전장", "명가의 궁정", "arcane", { { "highborne_summoner", 35 }, { "eldreth_spectre", 35 }, { "skeletal_highborne", 30 } },
		X("왕자 토르텔드린", "INV_Misc_Head_Human_02", "humanoid", "lord", { smash(8, 2.5), aoe(11, 1, "shadow"), summon(20, "arcane_aberration", 2) })),
	st("혈투의 전장", "고르독 왕좌", "ruins", { { "gordok_brute", 25 }, { "gordok_mastiff", 35 }, { "gordok_mage_lord", 40 } },
		X("왕 고르독", "Ability_Smash", "humanoid", "brute", { smash(7, 2.8), enrage(0.3, 1.4) })),
	st("스트라솔름", "도살장", "shadow", { { "skeletal_berserker", 50 }, { "thuzadin_shadowcaster", 30 }, { "patchwork_horror", 20 } },
		X("남작 리븐데어", "Spell_Shadow_DeathCoil", "undead", "brute", { smash(8, 2.5, nil, { "poison", 1 }), summon(15, "skeletal_guardian", 3), shield(26, 6, 65) })),
	st("검은바위 첨탑 상층", "드라키사스의 전당", "lava", { { "chromatic_elite_guard", 35 }, { "blackhand_elite", 40 }, { "rage_talon_fire_tongue", 25 } },
		X("사령관 드라키사스", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.6 }), enrage(0.3, 1.4) }, { school = "shadow", res = { shadow = 60 } })),
	st("검은바위 나락", "제왕의 관문", "lava", { { "anvilrage_warden", 40 }, { "doomforge_arcanasmith", 35 }, { "wrath_hammer_construct", 25 } },
		X("마그무스", "Spell_Fire_Elemental_Totem", "giant", "brute", { aoe(9, 1.1, "fire", { "ignite", 0.6 }), smash(11, 2.6), summon(20, "ironhand_guardian", 1) }, { school = "fire", res = { fire = 60 } })),
	st("실리더스", "안퀴라즈의 관문", "desert", { { "qiraji_gladiator", 50 }, { "hivezara_sandstalker", 50 } },
		X("아누비사스 문지기", "INV_Misc_AhnQirajTrinket_04", "dragonkin", "caster", { aoe(8, 1.2, "arcane"), smash(11, 2.6, "frost", { "chill", 1 }), summon(20, "obsidian_eradicator", 2), shield(30, 6, 70), enrage(0.2, 1.5) }, { school = "arcane", res = { frost = 60, arcane = 60 }, range = 600 })),
	-- Act 2: 세계의 우두머리
	st("아즈샤라", "아주어고스의 호수", "sea", { { "blue_scalebane", 35 }, { "spitelash_myrmidon", 35 }, { "thunderhead_stagwing", 30 } },
		X("아주어고스", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7, nil, { "bleed", 1 }), enrage(0.35, 1.5) })),
	st("저주받은 땅", "오염된 흉터", "fel", { { "felguard_sentry", 40 }, { "felhunter", 30 }, { "dreadmaul_ogre", 30 } },
		X("군주 카자크", "Spell_Shadow_SummonFelHunter", "demon", "caster", { aoe(9, 1.1, "shadow"), smash(12, 2.3, "nature", { "poison", 1 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("페랄라스", "꿈의 나무", "forest", { { "ironfur_bear", 40 }, { "feral_scar_yeti", 30 }, { "wandering_forest_walker", 30 } },
		X("이손드레", "INV_Misc_Head_Dragon_Black", "dragonkin", "lord", { smash(8, 2.5), summon(16, "demented_druid_spirit", 3), enrage(0.3, 1.4) })),
	st("동부 내륙지", "세라데인", "forest", { { "silvermane_stalker", 35 }, { "vilebranch_kidnapper", 35 }, { "green_sludge", 30 } },
		X("레손", "INV_Misc_Head_Dragon_Black", "dragonkin", "swift", { smash(6, 2.3), aoe(12, 1, "phys", { "stun", 0.3 }), enrage(0.5, 1.3) })),
	st("그늘숲", "황혼의 숲", "shadow", { { "nightbane_worgen", 40 }, { "plague_spreader", 25 }, { "skeletal_mage", 35 } },
		X("에메리스", "INV_Misc_Head_Dragon_Black", "dragonkin", "swift", { smash(6, 2.2, nil, { "bleed", 1 }), summon(16, "plague_spreader_2", 3) })),
	st("잿빛 골짜기", "그늘 나무", "forest", { { "shadethicket_raincaller", 40 }, { "shadethicket_moss_eater", 35 }, { "felmusk_satyr", 25 } },
		X("타에라", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.1, "arcane"), smash(11, 2.4, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "arcane", res = { arcane = 60 } })),
	st("악령의 숲", "저주의 둥지", "fel", { { "jadefire_rogue", 40 }, { "felmusk_felsworn", 25 }, { "entropic_horror", 35 } },
		X("어둠의 군주 펠단", "Spell_Shadow_SummonImp", "humanoid", "lord", { smash(8, 2.5, "nature", { "shock", 1 }), aoe(10, 1.1, "nature", { "stun", 0.25 }), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("여명의 설원", "마즈소리스의 동굴", "snow", { { "winterfall_shaman", 35 }, { "ice_thistle_patriarch", 30 }, { "frostmaul_giant", 35 } },
		X("겨울눈 보초", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), shield(26, 6, 60) }, { school = "nature", res = { nature = 70 } })),
	st("동부 역병지대", "망령의 대저택", "shadow", { { "death_singer", 40 }, { "scourge_warder", 35 }, { "gibbering_ghoul", 25 } },
		X("침투요원 하메야", "Spell_Shadow_RaiseDead", "undead", "lord", { smash(8, 2.5), summon(14, "scourge_warder_2", 3), enrage(0.3, 1.4) }, { school = "nature" })),
	st("실리더스", "황혼의 망치단 성채", "desert", { { "twilight_geolord", 40 }, { "twilight_master", 30 }, { "twilight_stonecaller", 30 } },
		X("황혼의 타락자", "Spell_Shadow_ShadowWordPain", "demon", "caster", { aoe(10, 1, "shadow"), smash(12, 2.3, "shadow", { "stun", 0.4 }), summon(20, "twilight_avenger_2", 2), shield(32, 6, 60), enrage(0.2, 1.3) }, { school = "shadow", res = { shadow = 60 } })),
	-- Act 3: 줄구룹
	st("안퀴라즈 폐허", "폐허 입구", "desert", { { "hivezara_soldier", 40 }, { "qiraji_warrior", 35 }, { "obsidian_destroyer", 25 } },
		X("쿠린낙스", "Ability_Hunter_Pet_Scorpid", "undead", "lord", { smash(8, 2.5, "shadow"), summon(16, "hivezara_hatchling", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("안퀴라즈 폐허", "라작스 전장", "desert", { { "qiraji_gladiator_2", 40 }, { "anubisath_guardian", 30 }, { "flesh_hunter", 30 } },
		X("장군 라작스", "INV_Misc_AhnQirajTrinket_02", "undead", "swift", { smash(6, 2.3, "shadow"), summon(16, "qiraji_warrior_2", 3), shield(26, 6, 60) }, { school = "shadow" })),
	st("안퀴라즈 폐허", "부루의 웅덩이", "desert", { { "anubisath_guardian_2", 30 }, { "hivezara_stinger", 40 }, { "silicate_feeder", 30 } },
		X("먹보 부루", "INV_Misc_AhnQirajTrinket_04", "beast", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "frost", { "chill", 1 }), enrage(0.3, 1.5) }, { res = { frost = 60 } })),
	st("안퀴라즈 폐허", "수정 신전", "ruins", { { "spitting_scarab", 35 }, { "qiraji_swarmguard", 35 }, { "hivezara_tail_lasher", 30 } },
		X("무적의 오시리안", "INV_Misc_AhnQirajTrinket_04", "undead", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.4, "shadow"), summon(18, "hivezara_wasp", 2) }, { school = "shadow", res = { shadow = 60 } })),
	st("줄구룹", "만도키르 고원", "jungle", { { "gurubashi_berserker", 35 }, { "razzashi_raptor", 35 }, { "gurubashi_headhunter", 30 } },
		X("혈군주 만도키르", "INV_Misc_Head_Troll_01", "humanoid", "brute", { smash(7, 2.7, "frost", { "chill", 1 }), aoe(11, 1.1, "frost"), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 60 } })),
	st("줄구룹", "뱀의 신전", "jungle", { { "hakkari_shadow_hunter", 35 }, { "hakkari_shadowcaster", 35 }, { "hakkari_priest", 30 } },
		X("대사제 베녹시스", "Ability_Hunter_Pet_WindSerpent", "humanoid", "lord", { smash(8, 2.5, "shadow"), aoe(10, 1.1, "shadow", { "stun", 0.25 }), shield(26, 6, 60) }, { school = "shadow" })),
	st("줄구룹", "박쥐 신전", "jungle", { { "gurubashi_champion", 40 }, { "hakkari_oracle", 30 }, { "gurubashi_bat_rider", 30 } },
		X("대여사제 제클릭", "INV_Misc_Head_Troll_01", "humanoid", "brute", { smash(6, 2.6), aoe(11, 1.2, "frost", { "chill", 0.6 }), enrage(0.3, 1.5) })),
	st("줄구룹", "거미 신전", "jungle", { { "gurubashi_berserker_2", 35 }, { "zulian_prowler", 35 }, { "razzashi_venombrood", 30 } },
		X("대여사제 말리", "INV_Misc_Head_Troll_01", "humanoid", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "spawn_of_marli", 2), shield(28, 6, 65), enrage(0.3, 1.4) }, { school = "nature", res = { nature = 60 } })),
	st("줄구룹", "호랑이 신전", "jungle", { { "hakkari_witch_doctor", 35 }, { "hakkari_blood_priest", 35 }, { "gurubashi_champion_2", 30 } },
		X("대사제 데칼", "INV_Misc_Head_Troll_01", "humanoid", "brute", { aoe(8, 1.2, "frost", { "chill", 1 }), smash(11, 2.7, "frost", { "freeze", 1 }), enrage(0.25, 1.6) }, { school = "frost", res = { fire = -20, frost = 80 } })),
	st("줄구룹", "학카르의 제단", "jungle", { { "gurubashi_warrior", 50 }, { "hakkari_shadowcaster", 50 } },
		X("학카르", "INV_Misc_Head_Troll_01", "undead", "lord", { aoe(8, 1.2, "shadow"), smash(9, 2.7, "frost", { "freeze", 0.7 }), summon(16, "son_of_hakkar", 3), shield(30, 6, 70), enrage(0.2, 1.6) }, { school = "frost", res = { frost = 60, shadow = 60 } })),
})

------------------------------------------------------------------------
-- Mythic+: the raids, from Molten Core to Naxxramas
------------------------------------------------------------------------
ns.STAGES[4] = finish({
	-- Act 1: 화산 심장부
	st("화산 심장부", "마그마다르의 굴", "lava", { { "flameguard", 40 }, { "flamewaker_priest", 30 }, { "core_hound", 30 } },
		X("마그마다르", "Spell_Fire_Elemental_Totem", "beast", "brute", { aoe(8, 1.1, "fire", { "ignite", 0.7 }), smash(11, 2.6, "fire"), enrage(0.3, 1.4) }, { school = "fire", res = { fire = 70, frost = -25 } })),
	st("화산 심장부", "화산 심장부 입구", "lava", { { "flamewaker", 40 }, { "flamewaker_healer", 30 }, { "firewalker", 30 } },
		X("루시프론", "Spell_Fire_Elemental_Totem", "humanoid", "brute", { smash(7, 2.7, "shadow"), summon(16, "flamewaker_protector", 2), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 50 } })),
	st("화산 심장부", "게헨나스의 길", "lava", { { "flamewaker_elite", 35 }, { "flamewaker_priest_2", 35 }, { "firewalker_2", 30 } },
		X("게헨나스", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(8, 1.2, "frost", { "chill", 1 }), summon(16, "flamewaker", 2), shield(26, 6, 65) }, { school = "frost", res = { frost = 60 } })),
	st("화산 심장부", "가르의 용암지", "lava", { { "molten_giant", 30 }, { "firelord", 35 }, { "flameguard", 35 } },
		X("가르", "Spell_Fire_Elemental_Totem", "elemental", "brute", { smash(7, 2.8, nil, { "stun", 0.5 }), aoe(12, 1.1, "nature"), shield(26, 6, 65) }, { res = { phys = 20, nature = 60 } })),
	st("화산 심장부", "샤즈라의 동굴", "lava", { { "molten_destroyer", 35 }, { "flamewaker_2", 35 }, { "firelord_2", 30 } },
		X("샤즈라", "Spell_Fire_Elemental_Totem", "humanoid", "caster", { aoe(8, 1.2, "shadow"), smash(12, 2.5, "nature", { "stun", 0.6 }), summon(16, "flamewaker_elite_2", 3) }, { school = "shadow" })),
	st("화산 심장부", "설퍼론의 통로", "lava", { { "flamewaker_protector_2", 40 }, { "firewalker_3", 30 }, { "core_rager", 30 } },
		X("설퍼론 선구자", "Spell_Fire_Elemental_Totem", "humanoid", "lord", { smash(8, 2.6, "shadow"), summon(16, "flamewaker_priest_3", 3), enrage(0.3, 1.4) }, { school = "shadow" })),
	st("화산 심장부", "게돈의 섬", "lava", { { "flamewaker_elite_3", 35 }, { "flamewaker_healer_2", 40 }, { "firelord", 25 } },
		X("남작 게돈", "Spell_Fire_Elemental_Totem", "elemental", "caster", { aoe(7, 1.2, "nature", { "shock", 0.6 }), smash(12, 2.5, "nature"), enrage(0.3, 1.5) }, { school = "nature", res = { nature = 70 } })),
	st("화산 심장부", "골레마그의 다리", "lava", { { "firewalker_4", 35 }, { "flameguard", 35 }, { "flamewaker_priest", 30 } },
		X("초열의 골레마그", "Spell_Shadow_AbominationExplosion", "mechanical", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "fire", { "ignite", 0.6 }), summon(18, "core_rager_2", 2), enrage(0.25, 1.5) }, { school = "shadow", res = { fire = 50, shadow = 50 } })),
	st("화산 심장부", "청지기의 방", "lava", { { "flamewaker_elite_4", 40 }, { "molten_giant_2", 25 }, { "lava_annihilator", 35 } },
		X("청지기 이그젝큐투스", "Spell_Fire_Elemental_Totem", "humanoid", "swift", { smash(5, 2.4, "fire", { "ignite", 1 }), aoe(11, 1.2, "fire"), enrage(0.4, 1.5) }, { school = "fire", res = { fire = 70 } })),
	st("화산 심장부", "라그나로스의 영역", "lava", { { "firelord_3", 50 }, { "molten_destroyer_2", 50 } },
		X("라그나로스", "Spell_Fire_Elemental_Totem", "elemental", "brute", { aoe(9, 1.05, "fire", { "ignite", 0.5 }), smash(12, 2.6), summon(20, "son_of_flame", 2), shield(32, 6, 60), enrage(0.2, 1.4) }, { school = "fire", res = { fire = 70, shadow = 50 } })),
	-- Act 2: 검은날개와 안퀴라즈
	st("오닉시아의 둥지", "오닉시아의 둥지", "cave", { { "onyxian_warder", 40 }, { "onyxian_whelp", 30 }, { "onyxian_drake", 30 } },
		X("오닉시아", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "shadow"), summon(16, "onyxian_whelp_2", 2), shield(26, 6, 65) }, { school = "shadow", res = { shadow = 70 } })),
	st("검은날개 둥지", "타락한 용의 방", "lava", { { "blackwing_mage", 40 }, { "blackwing_warlock", 30 }, { "blackwing_legionnaire", 30 } },
		X("타락한 밸라스트라즈", "INV_Misc_Head_Dragon_Black", "dragonkin", "caster", { aoe(8, 1.2, "frost", { "chill", 0.7 }), smash(12, 2.5, "frost", { "freeze", 0.6 }), enrage(0.3, 1.4) }, { school = "frost", res = { frost = 60 } })),
	st("검은날개 둥지", "알 부화장", "lava", { { "death_talon_hatcher", 45 }, { "blackwing_taskmaster", 30 }, { "death_talon_dragonspawn", 25 } },
		X("폭군 서슬송곳니", "INV_Misc_Head_Dragon_Black", "dragonkin", "swift", { smash(6, 2.3), summon(13, "blackwing_legionnaire_2", 3), enrage(0.3, 1.4) })),
	st("검은날개 둥지", "감시의 통로", "lava", { { "blackwing_technician", 40 }, { "death_talon_seether", 35 }, { "blackwing_guardsman", 25 } },
		X("용기대장 래쉬레이어", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7), aoe(11, 1.2, "nature", { "stun", 0.3 }), summon(18, "death_talon_wyrmguard", 2) }, { res = { nature = 50 } })),
	st("검은날개 둥지", "크로마구스의 굴", "lava", { { "death_talon_flamescale", 40 }, { "death_talon_wyrmguard_2", 25 }, { "death_talon_captain", 35 } },
		X("크로마구스", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(7, 2.7, "shadow"), aoe(10, 1.2, "shadow"), enrage(0.4, 1.6) }, { school = "shadow", res = { shadow = 70 } })),
	st("검은날개 둥지", "네파리안의 방", "lava", { { "blackwing_spellbinder", 35 }, { "death_talon_wyrmkin", 35 }, { "chromatic_drakonid", 30 } },
		X("네파리안", "INV_Misc_Head_Dragon_Black", "dragonkin", "brute", { smash(6, 2.8, nil, { "stun", 0.4 }), summon(16, "chromatic_drakonid_2", 2), shield(26, 6, 65), enrage(0.3, 1.5) })),
	st("안퀴라즈 사원", "예언자의 계단", "shadow", { { "vekniss_soldier", 40 }, { "vekniss_wasp", 30 }, { "qiraji_mindslayer", 30 } },
		X("예언자 스케람", "INV_Misc_AhnQirajTrinket_02", "beast", "caster", { aoe(8, 1.2, "nature", { "poison", 0.8 }), summon(16, "vekniss_warrior", 2), shield(26, 6, 65) }, { school = "nature", res = { nature = 60 } })),
	st("안퀴라즈 사원", "벌레 둥지", "shadow", { { "vekniss_warrior", 45 }, { "vekniss_stinger", 30 }, { "vekniss_drone", 25 } },
		X("공주 후후란", "Spell_Nature_InsectSwarm", "beast", "lord", { smash(7, 2.6, nil, { "poison", 1 }), aoe(10, 1.2, "shadow", { "stun", 0.3 }), summon(18, "vekniss_hive_crawler", 3), enrage(0.3, 1.5) }, { school = "shadow" })),
	st("안퀴라즈 사원", "쌍둥이 황제의 방", "shadow", { { "qiraji_champion", 35 }, { "obsidian_eradicator_2", 30 }, { "anubisath_warder", 35 } },
		X("제왕 베크닐라쉬", "INV_Misc_AhnQirajTrinket_02", "humanoid", "lord", { aoe(7, 1.3, "nature", { "shock", 0.7 }), smash(10, 2.7, "nature", { "stun", 0.5 }), shield(28, 6, 70), enrage(0.25, 1.5) }, { school = "nature", res = { nature = 80 } })),
	st("안퀴라즈 사원", "크툰의 방", "shadow", { { "anubisath_warder_2", 45 }, { "obsidian_nullifier", 30 }, { "eye_tentacle", 25 } },
		X("크툰", "INV_Misc_Eye_01", "humanoid", "lord", { smash(8, 2.4, nil, { "bleed", 0.6 }), aoe(11, 1.05, "shadow"), summon(20, "claw_tentacle", 2), shield(32, 6, 55), enrage(0.2, 1.4) }, { res = { shadow = 40 } })),
	-- Act 3: 낙스라마스
	st("낙스라마스", "거미 지구", "ice", { { "naxxramas_cultist", 40 }, { "crypt_reaver", 30 }, { "necro_knight", 30 } },
		X("귀부인 팰리나", "INV_Misc_Head_Human_02", "humanoid", "caster", { aoe(7, 1.3, "frost", { "chill", 1 }), smash(11, 2.6, "nature", { "shock", 1 }), enrage(0.3, 1.5) }, { school = "frost", res = { frost = 70, nature = 50 } })),
	st("낙스라마스", "아눕레칸의 방", "ice", { { "tomb_horror", 30 }, { "necro_stalker", 35 }, { "venom_stalker", 35 } },
		X("아눕레칸", "Spell_Shadow_RaiseDead", "undead", "brute", { aoe(8, 1.3, "nature", { "poison", 0.7 }), smash(11, 2.7, "shadow"), summon(18, "crypt_guard", 2) }, { school = "nature", res = { nature = 70 } })),
	st("낙스라마스", "서리고룡 둥지", "ice", { { "plagued_gargoyle", 40 }, { "plague_beast", 30 }, { "infectious_ghoul", 30 } },
		X("사피론", "INV_Misc_Head_Dragon_Black", "undead", "caster", { aoe(7, 1.3, "shadow"), smash(11, 2.6, "shadow", { "stun", 0.6 }), shield(26, 6, 65), enrage(0.3, 1.5) }, { school = "shadow", res = { shadow = 70 } })),
	st("낙스라마스", "군사 지구", "ice", { { "deathknight", 40 }, { "shade_of_naxxramas", 30 }, { "necropolis_acolyte", 30 } },
		X("훈련교관 라주비어스", "Spell_Shadow_DeathCoil", "undead", "brute", { smash(6, 2.9, nil, { "stun", 0.5 }), aoe(11, 1.2, "nature"), enrage(0.3, 1.5) })),
	st("낙스라마스", "피조물 지구", "ice", { { "patchwork_golem", 40 }, { "bile_retcher", 30 }, { "sludge_belcher", 30 } },
		X("패치워크", "Spell_Shadow_AbominationExplosion", "undead", "lord", { smash(7, 2.7, "fire", { "ignite", 1 }), aoe(10, 1.2, "fire"), shield(26, 6, 70), enrage(0.3, 1.5) }, { school = "fire" })),
	st("낙스라마스", "맥스나의 둥지", "ice", { { "carrion_spinner", 35 }, { "dread_creeper", 35 }, { "crypt_reaver_2", 30 } },
		X("맥스나", "Ability_Hunter_Pet_Spider", "beast", "caster", { aoe(7, 1.3, "arcane"), smash(11, 2.6, "arcane", { "freeze", 0.6 }), summon(18, "maexxna_spiderling", 2), shield(28, 6, 70) }, { school = "arcane", res = { arcane = 70 } })),
	st("낙스라마스", "수확의 방", "ice", { { "deathknight_captain", 35 }, { "necro_knight_2", 30 }, { "shade_of_naxxramas_2", 35 } },
		X("영혼 착취자 고딕", "Spell_Shadow_DeathCoil", "undead", "caster", { aoe(7, 1.3, "fire", { "ignite", 0.7 }), smash(10, 2.7, "shadow"), summon(16, "unrelenting_trainee", 2), enrage(0.25, 1.6) }, { school = "shadow", res = { fire = 60, shadow = 60 } })),
	st("낙스라마스", "타디우스의 실험실", "ice", { { "living_monstrosity", 35 }, { "mad_scientist", 35 }, { "stitched_spewer", 30 } },
		X("타디우스", "Spell_Shadow_RaiseDead", "undead", "brute", { smash(6, 2.9), aoe(9, 1.3, "fire"), shield(28, 6, 70), enrage(0.25, 1.6) }, { school = "fire", res = { fire = 60, shadow = 60 } })),
	st("낙스라마스", "네 기사의 방", "ice", { { "deathknight_vindicator", 35 }, { "ghost_of_naxxramas", 30 }, { "unholy_staff", 35 } },
		X("대영주 모그레인", "Spell_Shadow_DeathCoil", "undead", "brute", { smash(5, 2.8, "fire", { "ignite", 1 }), aoe(9, 1.3, "fire"), summon(18, "deathknight_cavalier", 2), enrage(0.3, 1.6) }, { school = "fire", res = { fire = 80 } })),
	st("낙스라마스", "켈투자드의 방", "ice", { { "deathknight_2", 50 }, { "necro_knight_3", 50 } },
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
