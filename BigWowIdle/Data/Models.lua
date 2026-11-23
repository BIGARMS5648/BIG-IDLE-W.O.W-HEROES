-- 3D models for the battle: the NPC (creature) id whose model stands in for
-- each monster, boss, summon, companion and hero (UI/Figure3D.lua puts it up
-- by its display id, below). Every id was checked against wowhead's name for
-- it (the English name in the comment); where the game has no such creature
-- the closest look is used.
local _, ns = ...

ns.MODEL = {}

-- the monsters of the stages (Data/Monsters.lua ids)
ns.MODEL.mob = {
	adult_plainstrider             =   2956, -- 다자란 초원타조 · Adult Plainstrider
	anubisath_guardian             =  15355, -- 아누비사스 감시자 · Anubisath Guardian
	anubisath_guardian_2           =  15355, -- 아누비사스 감시자 · Anubisath Guardian
	anubisath_guardian_3           =  15355, -- 아누비사스 감시자 · Anubisath Guardian
	anubisath_warder               =  15311, -- 아누비사스 수호병 · Anubisath Warder
	anubisath_warder_2             =  15311, -- 아누비사스 수호병 · Anubisath Warder
	anvilrage_captain              =   8903, -- 성난모루 대장 · Anvilrage Captain
	anvilrage_guardsman            =   8891, -- 성난모루 보초 · Anvilrage Guardsman
	anvilrage_warden               =   8890, -- 성난모루 교도관 · Anvilrage Warden
	arugals_voidwalker             =   4627, -- 아루갈의 공허방랑자 · Arugal's Voidwalker
	ashenvale_bear                 =   3809, -- 잿빛 골짜기 곰 · Ashenvale Bear
	atalai_warrior                 =   5256, -- 아탈라이 전사 · Atal'ai Warrior
	atalai_witch_doctor            =   5259, -- 아탈라이 의술사 · Atal'ai Witch Doctor
	barbed_lasher                  =  12219, -- 뾰족가시 덩굴손 · Barbed Lasher
	black_broodling                =   7047, -- 검은 새끼용 · Black Broodling
	black_dragonspawn              =   7040, -- 검은용혈족 · Black Dragonspawn
	blackfathom_myrmidon           =   4807, -- 검은심연 미르미돈 · Blackfathom Myrmidon
	blackfathom_tide_priestess     =   4802, -- 검은심연 해일여사제 · Blackfathom Tide Priestess
	blackhand_dreadweaver          =   9817, -- 검은손부대 공포술사 · Blackhand Dreadweaver
	blackhand_elite                =  10317, -- 검은손부대 정예병 · Blackhand Elite
	blackhand_incarcerator         =  10316, -- 검은손부대 집행자 · Blackhand Incarcerator
	blackhand_iron_guard           =  10319, -- 검은손부대 철갑병 · Blackhand Iron Guard
	blackhand_summoner             =   9818, -- 검은손부대 소환사 · Blackhand Summoner
	blackhand_veteran              =   9819, -- 검은손부대 고참병 · Blackhand Veteran
	blackrock_grunt                =    440, -- 검은바위 그런트 · Blackrock Grunt
	blackrock_outrunner            =    485, -- 검은바위 길잡이 · Blackrock Outrunner
	blackrock_soldier              =   7025, -- 검은바위 병사 · Blackrock Soldier
	blackrock_summoner             =   4463, -- 검은바위 소환사 · Blackrock Summoner
	blackwing_guardsman            =  14456, -- 검은날개 수호병 · Blackwing Guardsman
	blackwing_legionnaire          =  12416, -- 검은날개 부대원 · Blackwing Legionnaire
	blackwing_mage                 =  12420, -- 검은날개 마법사 · Blackwing Mage
	blackwing_spellbinder          =  12457, -- 검은날개 역술사 · Blackwing Spellbinder
	blackwing_taskmaster           =  12458, -- 검은날개 작업반장 · Blackwing Taskmaster
	blackwing_technician           =  13996, -- 검은날개 기술병 · Blackwing Technician
	blackwing_technician_2         =  13996, -- 검은날개 기술병 · Blackwing Technician
	blackwing_warlock              =  12459, -- 검은날개 흑마법사 · Blackwing Warlock
	bleak_worg                     =   3861, -- 사나운 검은늑대 · Bleak Worg
	bloodaxe_raider                =   9692, -- 도끼부대 공격대원 · Bloodaxe Raider
	bloodaxe_veteran               =   9583, -- 도끼부대 고참병 · Bloodaxe Veteran
	bloodaxe_worg                  =   9696, -- 도끼부대 검은늑대 · Bloodaxe Worg
	bloodfen_razormaw              =   4356, -- 무쇠턱 붉은늪지랩터 · Bloodfen Razormaw
	bloodscalp_berserker           =    597, -- 붉은머리 광전사 · Bloodscalp Berserker
	bloodseeker_bat                =  11368, -- 흡혈박쥐 · Bloodseeker Bat
	blue_scalebane                 =   6130, -- 푸른용혈족 맹독전사 · Blue Scalebane
	boulderfist_brute              =   2566, -- 돌주먹 투사 · Boulderfist Brute
	bristleback_battleboar         =   2954, -- 뾰족털 전투멧돼지 · Bristleback Battleboar
	bristleback_shaman             =   2953, -- 뾰족털 주술사 · Bristleback Shaman
	burning_blade_apprentice       =   3198, -- 불타는 칼날단 수습흑마법사 · Burning Blade Apprentice
	burning_blade_felsworn         =   4666, -- 불타는 칼날단 악마추종자 · Burning Blade Felsworn
	burning_blade_summoner         =   4668, -- 불타는 칼날단 소환사 · Burning Blade Summoner
	carrion_spinner                =  15975, -- 청소부 그물거미 · Carrion Spinner
	caverndeep_burrower            =   6206, -- 깊은굴 땅꾼 · Caverndeep Burrower
	chromatic_drakonid             =  14302, -- 오색용기병 · Chromatic Drakonid
	chromatic_elite_guard          =  10814, -- 오색용혈족 정예병 · Chromatic Elite Guard
	chromatic_whelp                =  10442, -- 오색 새끼용 · Chromatic Whelp
	claw_tentacle                  =  15725, -- 갈고리 촉수 · Claw Tentacle
	constrictor_vine               =  12220, -- 채찍줄기 덩굴손 · Constrictor Vine
	core_hound                     =  11671, -- 심장부 사냥개 · Core Hound
	core_rager                     =  11672, -- 흉포한 심장부 사냥개 · Core Rager
	core_rager_2                   =  11672, -- 흉포한 심장부 사냥개 · Core Rager
	crag_coyote                    =   2727, -- 바위산코요테 · Crag Coyote
	crimson_gallant                =  10424, -- 되살아난 수행원 · Crimson Gallant
	crimson_monk                   =  11043, -- 되살아난 수도사 · Crimson Monk
	crimson_sorcerer               =  10422, -- 되살아난 마술사 · Crimson Sorcerer
	crimson_templar                =  15209, -- 진홍 기사단 · Crimson Templar
	crypt_horror                   =   8557, -- 공포의 지하마귀 · Crypt Horror
	crypt_reaver                   =  15978, -- 칼날발톱 지하마귀 · Crypt Reaver
	cursed_mage                    =   8524, -- 저주받은 마법사 · Cursed Mage
	dark_iron_agent                =   6212, -- 검은무쇠 첩보원 · Dark Iron Agent
	dark_iron_taskmaster           =   5846, -- 검은무쇠 감독관 · Dark Iron Taskmaster
	darkmist_spider                =   4376, -- 암흑안개거미 · Darkmist Spider
	deadwood_warrior               =   7153, -- 마른가지 전사 · Deadwood Warrior
	death_talon_captain            =  12467, -- 죽음의발톱 부대장 · Death Talon Captain
	death_talon_dragonspawn        =  12422, -- 죽음의발톱 용혈족 · Death Talon Dragonspawn
	death_talon_flamescale         =  12463, -- 죽음의발톱 화염전사 · Death Talon Flamescale
	death_talon_hatcher            =  12468, -- 죽음의발톱 알지기 · Death Talon Hatcher
	death_talon_overseer           =  12461, -- 죽음의발톱 감독관 · Death Talon Overseer
	death_talon_seether            =  12464, -- 죽음의발톱 정예병 · Death Talon Seether
	death_talon_wyrmguard          =  12460, -- 죽음의발톱 고룡수호병 · Death Talon Wyrmguard
	death_talon_wyrmguard_2        =  12460, -- 죽음의발톱 고룡수호병 · Death Talon Wyrmguard
	death_talon_wyrmkin            =  12465, -- 죽음의발톱 고룡족 · Death Talon Wyrmkin
	deathknight                    =  16146, -- 죽음의 기사 · Deathknight
	deathknight_captain            =  16145, -- 죽음의 기사단 대장 · Deathknight Captain
	deathknight_cavalier           =  16163, -- 죽음의 기사단 기병 · Deathknight Cavalier
	deathknight_vindicator         =  16451, -- 죽음의 기사단 근위병 · Deathknight Vindicator
	deaths_head_necromancer        =   7337, -- 죽음의 머리교 강령술사 · Death's Head Necromancer
	deepmoss_creeper               =   4005, -- 동굴이끼 땅거미 · Deepmoss Creeper
	deeprot_tangler                =  13142, -- 올가미의 깊은뿌리정령 · Deeprot Tangler
	defias_miner                   =    598, -- 데피아즈단 광부 · Defias Miner
	defias_overseer                =    634, -- 데피아즈단 감독관 · Defias Overseer
	defias_taskmaster              =   4417, -- 데피아즈단 작업반장 · Defias Taskmaster
	defias_trapper                 =    504, -- 데피아즈단 덫사냥꾼 · Defias Trapper
	deviate_adder                  =   5048, -- 돌연변이 살무사 · Deviate Adder
	deviate_lurker                 =   3641, -- 돌연변이 비늘트레샤돈 · Deviate Lurker
	doomforge_arcanasmith          =   8900, -- 파멸괴철로 신비대장장이 · Doomforge Arcanasmith
	dragonmaw_shadowwarder         =   1038, -- 용아귀 어둠보초병 · Dragonmaw Shadowwarder
	dread_creeper                  =  15974, -- 공포의 암흑거미 · Dread Creeper
	dreadmaul_brute                =   5976, -- 우레망치 투사 · Dreadmaul Brute
	dreadmaul_ogre                 =   5974, -- 우레망치 오우거 · Dreadmaul Ogre
	dreadmaw_crocolisk             =   3110, -- 철갑악어 · Dreadmaw Crocolisk
	druid_of_the_fang              =   3840, -- 송곳니의 드루이드 · Druid of the Fang
	dunemaul_ogre                  =   5471, -- 모래망치 오우거 · Dunemaul Ogre
	dust_stormer                   =  11744, -- 먼지 폭풍 · Dust Stormer
	dustbelcher_brute              =   2715, -- 먼지목도리 투사 · Dustbelcher Brute
	earthborer                     =  11320, -- 땅벌레 · Earthborer
	earthen_guardian               =   7076, -- 토석인 수호자 · Earthen Guardian
	elder_black_bear               =   1186, -- 검은곰 · Elder Black Bear
	elder_moss_creeper             =   2348, -- 덩치 큰 이끼거미 · Elder Moss Creeper
	eldreth_spectre                =  11473, -- 엘드레스 원혼 · Eldreth Spectre
	eye_stalk                      =  16236, -- 추적자의 눈 · Eye Stalk
	eye_tentacle                   =  15726, -- 눈 달린 촉수 · Eye Tentacle
	felguard_sentry                =   6011, -- 지옥수호병 보초 · Felguard Sentry
	felhound                       =   6010, -- 지옥사냥개 · Felhound
	felhound_2                     =   6010, -- 지옥사냥개 · Felhound
	fen_creeper                    =   1040, -- 수렁이끼괴물 · Fen Creeper
	ferocious_grizzled_bear        =   1778, -- 사나운 불곰 · Ferocious Grizzled Bear
	fireguard_destroyer            =   8911, -- 파괴의 화염수호정령 · Fireguard Destroyer
	firegut_ogre_mage              =   7034, -- 불자루 오우거마법사 · Firegut Ogre Mage
	firelord                       =  11668, -- 불의 군주 · Firelord
	firelord_2                     =  11668, -- 불의 군주 · Firelord
	firelord_3                     =  11668, -- 불의 군주 · Firelord
	firesworn                      =  12099, -- 불꽃의 추종자 · Firesworn
	firewalker                     =  11666, -- 불꽃 정령 · Firewalker
	firewalker_2                   =  11666, -- 불꽃 정령 · Firewalker
	firewalker_3                   =  11666, -- 불꽃 정령 · Firewalker
	firewalker_4                   =  11666, -- 불꽃 정령 · Firewalker
	flameguard                     =  11667, -- 화염의수호자 · Flameguard
	flameguard_2                   =  11667, -- 화염의수호자 · Flameguard
	flameguard_3                   =  11667, -- 화염의수호자 · Flameguard
	flamewaker                     =  11661, -- 불꽃꼬리 전사 · Flamewaker
	flamewaker_2                   =  11661, -- 불꽃꼬리 전사 · Flamewaker
	flamewaker_elite               =  11664, -- 불꽃꼬리 정예병 · Flamewaker Elite
	flamewaker_elite_2             =  11664, -- 불꽃꼬리 정예병 · Flamewaker Elite
	flamewaker_elite_3             =  11664, -- 불꽃꼬리 정예병 · Flamewaker Elite
	flamewaker_elite_4             =  11664, -- 불꽃꼬리 정예병 · Flamewaker Elite
	flamewaker_healer              =  11663, -- 불꽃꼬리 치유사 · Flamewaker Healer
	flamewaker_healer_2            =  11663, -- 불꽃꼬리 치유사 · Flamewaker Healer
	flamewaker_priest              =  11662, -- 불꽃꼬리 사제 · Flamewaker Priest
	flamewaker_priest_2            =  11662, -- 불꽃꼬리 사제 · Flamewaker Priest
	flamewaker_protector           =  12119, -- 불꽃꼬리 수호병 · Flamewaker Protector
	flamewaker_protector_2         =  12119, -- 불꽃꼬리 수호병 · Flamewaker Protector
	flesh_hunter                   =  15335, -- 청소부 수액괴물 · Flesh Hunter
	foulweald_shaman               =   3748, -- 썩은나무 주술사 · Foulweald Shaman
	frenzied_bat                   =  16036, -- 광포한 박쥐 · Frenzied Bat
	frenzied_pterrordax            =   9167, -- 광포한 테러닥스 · Frenzied Pterrordax
	frostmane_seer                 =   1397, -- 서리갈기 예언자 · Frostmane Seer
	frostsaber_huntress            =   7433, -- 어미 눈호랑이 · Frostsaber Huntress
	galak_packhound                =   4250, -- 갈라크 하이에나 · Galak Packhound
	galak_scout                    =   4094, -- 갈라크 척후병 · Galak Scout
	galak_windchaser               =   4096, -- 갈라크 바람전사 · Galak Windchaser
	ghost_of_naxxramas             =  16419, -- 낙스라마스의 유령 · Ghost of Naxxramas
	ghostpaw_runner                =   3823, -- 유령발늑대 · Ghostpaw Runner
	gnarlpine_mystic               =   7235, -- 나무옹이 비술사 · Gnarlpine Mystic
	gnarlpine_warrior              =   2008, -- 나무옹이 전사 · Gnarlpine Warrior
	gordok_brute                   =  11441, -- 고르독 투사 · Gordok Brute
	gordok_mage_lord               =  11444, -- 고르독 대마법사 · Gordok Mage-Lord
	gordok_mastiff                 =  13036, -- 고르독 사냥개 · Gordok Mastiff
	gordok_reaver                  =  11450, -- 고르독 약탈자 · Gordok Reaver
	gordunni_mage_lord             =   5239, -- 골두니 대마법사 · Gordunni Mage-Lord
	great_goretusk                 =    547, -- 큰 뿔엄니멧돼지 · Great Goretusk
	greater_kraul_bat              =   4539, -- 거대한 동굴박쥐 · Greater Kraul Bat
	greater_lava_spider            =   5858, -- 거대한 용암거미 · Greater Lava Spider
	grellkin                       =   1989, -- 그렐킨 · Grellkin
	gurubashi_axe_thrower          =  11350, -- 구루바시 도끼 투척병 · Gurubashi Axe Thrower
	gurubashi_bat_rider            =  14750, -- 구루바시 박쥐 기수 · Gurubashi Bat Rider
	gurubashi_berserker            =  11352, -- 구루바시 광전사 · Gurubashi Berserker
	gurubashi_berserker_2          =  11352, -- 구루바시 광전사 · Gurubashi Berserker
	gurubashi_blood_drinker        =  11353, -- 구루바시 흡혈전사 · Gurubashi Blood Drinker
	gurubashi_champion             =  11356, -- 구루바시 용사 · Gurubashi Champion
	gurubashi_headhunter           =  11351, -- 구루바시 인간사냥꾼 · Gurubashi Headhunter
	gurubashi_warrior              =  11355, -- 구루바시 전사 · Gurubashi Warrior
	gurubashi_warrior_2            =  11355, -- 구루바시 전사 · Gurubashi Warrior
	hakkari_blood_priest           =  11340, -- 학카리 혈사제 · Hakkari Blood Priest
	hakkari_bloodkeeper            =   8438, -- 학카리 수호천둥매 · Hakkari Bloodkeeper
	hakkari_oracle                 =  11346, -- 학카리 현자 · Hakkari Oracle
	hakkari_priest                 =  11830, -- 학카리 사제 · Hakkari Priest
	hakkari_priest_2               =  11830, -- 학카리 사제 · Hakkari Priest
	hakkari_shadow_hunter          =  11339, -- 학카리 어둠사냥꾼 · Hakkari Shadow Hunter
	hakkari_shadowcaster           =  11338, -- 학카리 흑마술사 · Hakkari Shadowcaster
	hakkari_shadowcaster_2         =  11338, -- 학카리 흑마술사 · Hakkari Shadowcaster
	hakkari_witch_doctor           =  11831, -- 학카리 의술사 · Hakkari Witch Doctor
	harvest_golem                  =     36, -- 허수아비골렘 · Harvest Golem
	haunting_phantasm              =   6427, -- 음산한 악령 · Haunting Phantasm
	heavy_war_golem                =   5854, -- 육중한 전쟁 골렘 · Heavy War Golem
	highborne_summoner             =  11466, -- 명가의 소환사 · Highborne Summoner
	highland_thrasher              =   2560, -- 외뿔 고원랩터 · Highland Thrasher
	hiveashi_worker                =  11721, -- 일꾼 하이브아쉬 · Hive'Ashi Worker
	hivezara_hatchling             =  15521, -- 새끼 하이브자라 · Hive'Zara Hatchling
	hivezara_sandstalker           =  15323, -- 모래무지 하이브자라 · Hive'Zara Sandstalker
	hivezara_soldier               =  15320, -- 병정 하이브자라 · Hive'Zara Soldier
	hivezara_soldier_2             =  15320, -- 병정 하이브자라 · Hive'Zara Soldier
	hivezara_stinger               =  15327, -- 쐐기 하이브자라 · Hive'Zara Stinger
	hivezara_tail_lasher           =  15336, -- 채찍꼬리 하이브자라 · Hive'Zara Tail Lasher
	hivezara_wasp                  =  15325, -- 독침 하이브자라 · Hive'Zara Wasp
	hoary_templar                  =  15212, -- 백색 기사단 · Hoary Templar
	ice_claw_bear                  =   1196, -- 얼음발톱흰곰 · Ice Claw Bear
	ice_thistle_yeti               =   7458, -- 얼음엉겅퀴설인 · Ice Thistle Yeti
	illusion_of_jandice_barov      =  11439, -- 잔다이스 바로브의 환영 · Illusion of Jandice Barov
	infectious_ghoul               =  16244, -- 전염병 구울 · Infectious Ghoul
	ironhide_devilsaur             =   6499, -- 무쇠가죽 데빌사우루스 · Ironhide Devilsaur
	jadefire_felsworn              =   7109, -- 비취불꽃 악마추종자 · Jadefire Felsworn
	jadefire_satyr                 =   7105, -- 비취불꽃 사티로스 · Jadefire Satyr
	jadespine_basilisk             =   4863, -- 비취돌기바실리스크 · Jadespine Basilisk
	jungle_stalker                 =    687, -- 줄무늬정글랩터 · Jungle Stalker
	kobold_worker                  =    257, -- 코볼트 잡역부 · Kobold Worker
	kolkar_destroyer               =   4637, -- 콜카르 파괴자 · Kolkar Destroyer
	kolkar_marauder                =   3275, -- 콜카르 약탈자 · Kolkar Marauder
	lava_annihilator               =  11665, -- 용암의 파괴자 · Lava Annihilator
	lava_annihilator_2             =  11665, -- 용암의 파괴자 · Lava Annihilator
	lava_spawn                     =  12265, -- 용암 피조물 · Lava Spawn
	legashi_satyr                  =   6200, -- 레가쉬 사티로스 · Legashi Satyr
	leprous_defender               =   6223, -- 오염된 노움 수호병 · Leprous Defender
	living_blaze                   =   6521, -- 살아있는 불길 · Living Blaze
	living_monstrosity             =  16021, -- 살아 움직이는 괴물 · Living Monstrosity
	longtooth_runner               =   5286, -- 긴다리 송곳니늑대 · Longtooth Runner
	mad_scientist                  =  16020, -- 미치광이 과학자 · Mad Scientist
	magram_wrangler                =   4640, -- 마그람 사냥꾼 · Magram Wrangler
	marsh_oracle                   =    752, -- 늪지 점쟁이 · Marsh Oracle
	mirefin_oracle                 =   4363, -- 진흙아가미 점쟁이 · Mirefin Oracle
	mirefin_warrior                =   4360, -- 진흙아가미 전사 · Mirefin Warrior
	mogrosh_ogre                   =   1178, -- 모그로쉬 오우거 · Mo'grosh Ogre
	molten_destroyer               =  11659, -- 파괴의 용암거인 · Molten Destroyer
	molten_destroyer_2             =  11659, -- 파괴의 용암거인 · Molten Destroyer
	molten_destroyer_3             =  11659, -- 파괴의 용암거인 · Molten Destroyer
	molten_elemental               =  11321, -- 녹아내린 정령 · Molten Elemental
	molten_giant                   =  11658, -- 용암거인 · Molten Giant
	molten_giant_2                 =  11658, -- 용암거인 · Molten Giant
	moonrage_darkrunner            =   1770, -- 달분노 어둠의길잡이 · Moonrage Darkrunner
	mosshide_brute                 =   1012, -- 이끼가죽 투사 · Mosshide Brute
	mutated_grub                   =  16297, -- 돌연변이 굼벵이 · Mutated Grub
	naxxramas_acolyte              =  15981, -- 낙스라마스 수행사제 · Naxxramas Acolyte
	naxxramas_cultist              =  15980, -- 낙스라마스 신도 · Naxxramas Cultist
	naxxramas_worshipper           =  16506, -- 낙스라마스 숭배자 · Naxxramas Worshipper
	necro_knight                   =  16165, -- 해골 기사 · Necro Knight
	necro_knight_2                 =  16165, -- 해골 기사 · Necro Knight
	necro_knight_3                 =  16165, -- 해골 기사 · Necro Knight
	necro_stalker                  =  16453, -- 죽음의 동굴거미 · Necro Stalker
	nightbane_vile_fang            =    206, -- 파멸어둠 송곳니투사 · Nightbane Vile Fang
	nightmare_illusion             =  15163, -- 악몽의 환영 · Nightmare Illusion
	nightmare_scalebane            =   5277, -- 악몽의 맹독전사 · Nightmare Scalebane
	nightmare_wyrmkin              =   5280, -- 악몽의 고룡족 · Nightmare Wyrmkin
	noxxions_spawn                 =  13456, -- 녹시온의 피조물 · Noxxion's Spawn
	obsidian_destroyer             =  15338, -- 흑요석 파괴자 · Obsidian Destroyer
	obsidian_eradicator            =  15262, -- 흑요석 파멸자 · Obsidian Eradicator
	obsidian_nullifier             =  15312, -- 흑요석 종결자 · Obsidian Nullifier
	onyxian_drake                  =  12260, -- 오닉시아의 비룡 · Onyxian Drake
	onyxian_warder                 =  12129, -- 오닉시아의 수호병 · Onyxian Warder
	onyxian_whelp                  =  11262, -- 오닉시아의 새끼용 · Onyxian Whelp
	patchwork_horror               =  10414, -- 기워붙인 누더기골렘 · Patchwork Horror
	plague_beast                   =  16034, -- 역병 걸린 괴물 · Plague Beast
	plague_beast_2                 =  16034, -- 역병 걸린 괴물 · Plague Beast
	plague_monstrosity             =   8522, -- 역병의 괴수 · Plague Monstrosity
	plague_slime                   =  16243, -- 역병 걸린 진흙괴물 · Plague Slime
	plagued_gargoyle               =  16446, -- 역병 걸린 가고일 · Plagued Gargoyle
	plagued_ghoul                  =  16447, -- 역병 걸린 구울 · Plagued Ghoul
	primordial_behemoth            =  12206, -- 태초의 거수 · Primordial Behemoth
	prowler                        =    118, -- 굶주린 늑대 · Prowler
	putridus_shadowstalker         =  11792, -- 타락의 그림자추적자 · Putridus Shadowstalker
	pygmy_venom_web_spider         =    539, -- 새끼 그물독거미 · Pygmy Venom Web Spider
	qiraji_champion                =  15252, -- 퀴라지 용사 · Qiraji Champion
	qiraji_gladiator               =  15324, -- 퀴라지 투사 · Qiraji Gladiator
	qiraji_gladiator_2             =  15324, -- 퀴라지 투사 · Qiraji Gladiator
	qiraji_mindslayer              =  15246, -- 퀴라지 정신파괴자 · Qiraji Mindslayer
	qiraji_swarmguard              =  15343, -- 퀴라지 감시병 · Qiraji Swarmguard
	qiraji_swarmguard_2            =  15343, -- 퀴라지 감시병 · Qiraji Swarmguard
	qiraji_warrior                 =  15387, -- 퀴라지 전사 · Qiraji Warrior
	rage_talon_dragonspawn         =   9096, -- 성난발톱용혈족 · Rage Talon Dragonspawn
	rage_talon_fire_tongue         =  10372, -- 성난발톱혈족 화염술사 · Rage Talon Fire Tongue
	rage_talon_flamescale          =  10083, -- 화염비늘 성난발톱용혈족 · Rage Talon Flamescale
	ragereaver_golem               =   8906, -- 맹위의 전투골렘 · Ragereaver Golem
	razorfen_geomancer             =   4520, -- 가시덩굴 흙점쟁이 · Razorfen Geomancer
	razorfen_quilguard             =   4436, -- 가시덩굴 가시경비병 · Razorfen Quilguard
	razorfen_spearhide             =   4438, -- 가시덩굴 가시근위병 · Razorfen Spearhide
	razormane_hunter               =   3265, -- 서슬갈기 사냥꾼 · Razormane Hunter
	razormane_quilboar             =   3111, -- 서슬갈기 가시멧돼지 · Razormane Quilboar
	razzashi_adder                 =  11372, -- 래즈자쉬 살무사 · Razzashi Adder
	razzashi_broodwidow            =  11370, -- 래즈자쉬 과부거미 · Razzashi Broodwidow
	razzashi_raptor                =  14821, -- 래즈자쉬 랩터 · Razzashi Raptor
	razzashi_serpent               =  11371, -- 래즈자쉬 독사 · Razzashi Serpent
	razzashi_venombrood            =  14532, -- 래즈자쉬 독거미 · Razzashi Venombrood
	redridge_mongrel               =    423, -- 붉은마루 싸움꾼 · Redridge Mongrel
	ridge_huntress                 =   2732, -- 덩치 큰 바위산표범 · Ridge Huntress
	risen_bonewarder               =  10491, -- 되살아난 해골문지기 · Risen Bonewarder
	risen_construct                =  10488, -- 되살아난 피조물 · Risen Construct
	risen_guard                    =  10489, -- 되살아난 경비병 · Risen Guard
	risen_guardian                 =  11598, -- 되살아난 수호자 · Risen Guardian
	risen_lackey                   =  10482, -- 되살아난 하인 · Risen Lackey
	riverpaw_gnoll                 =    117, -- 갈퀴발 놀 · Riverpaw Gnoll
	sandfury_blood_drinker         =   5649, -- 성난모래 혈투사 · Sandfury Blood Drinker
	sandfury_executioner           =   7274, -- 성난모래 사형집행인 · Sandfury Executioner
	sandfury_shadowcaster          =   5648, -- 성난모래 흑마술사 · Sandfury Shadowcaster
	sandfury_soul_eater            =   7247, -- 성난모래 영혼사냥꾼 · Sandfury Soul Eater
	savannah_huntress              =   3415, -- 사바나 암사자 · Savannah Huntress
	scarlet_adept                  =   4296, -- 붉은십자군 상급사제 · Scarlet Adept
	scarlet_champion               =   4302, -- 붉은십자군 용사 · Scarlet Champion
	scarlet_chaplain               =   4299, -- 붉은십자군 전도사 · Scarlet Chaplain
	scarlet_convert                =   1506, -- 붉은십자군 순례자 · Scarlet Convert
	scarlet_defender               =   4298, -- 붉은십자군 방어병 · Scarlet Defender
	scarlet_diviner                =   4291, -- 붉은십자군 풍수사 · Scarlet Diviner
	scarlet_gallant                =   4287, -- 붉은십자군 수행원 · Scarlet Gallant
	scarlet_mage                   =   1826, -- 붉은십자군 마법사 · Scarlet Mage
	scarlet_missionary             =   1536, -- 붉은십자군 선교사 · Scarlet Missionary
	scarlet_monk                   =   4540, -- 붉은십자군 수도사 · Scarlet Monk
	scarlet_myrmidon               =   4295, -- 붉은십자군 정예병 · Scarlet Myrmidon
	scarlet_neophyte               =   1539, -- 붉은십자군 수련사 · Scarlet Neophyte
	scarlet_sentinel               =   1827, -- 붉은십자군 파수꾼 · Scarlet Sentinel
	scarlet_torturer               =   4306, -- 붉은십자군 고문관 · Scarlet Torturer
	scarlet_trainee                =   6575, -- 붉은십자군 신병 · Scarlet Trainee
	scarlet_warrior                =   1535, -- 붉은십자군 전사 · Scarlet Warrior
	scholomance_adept              =  10469, -- 스칼로맨스 숙련마술사 · Scholomance Adept
	scholomance_dark_summoner      =  11582, -- 스칼로맨스 암흑소환사 · Scholomance Dark Summoner
	scholomance_necromancer        =  10477, -- 스칼로맨스 강령술사 · Scholomance Necromancer
	scholomance_student            =  10475, -- 스칼로맨스 학생 · Scholomance Student
	scorpid_dunestalker            =   5424, -- 모래언덕전갈 · Scorpid Dunestalker
	searing_blade_cultist          =  11322, -- 이글거리는 칼날단 이교도 · Searing Blade Cultist
	shade_of_jindo                 =  14986, -- 진도의 망령 · Shade of Jin'do
	shade_of_naxxramas             =  16164, -- 낙스라마스의 망령 · Shade of Naxxramas
	shadowfang_darksoul            =   3855, -- 그림자송곳니 검은영혼 · Shadowfang Darksoul
	shadowforge_flame_keeper       =   9956, -- 어둠괴철로 불꽃지기 · Shadowforge Flame Keeper
	shadowforge_senator            =   8904, -- 어둠괴철로 원로원 · Shadowforge Senator
	shadowforge_sharpshooter       =   7290, -- 어둠괴철로 저격수 · Shadowforge Sharpshooter
	shadowmaw_panther              =    684, -- 그림자퓨마 · Shadowmaw Panther
	silicate_feeder                =  15333, -- 소금모래 청소부 · Silicate Feeder
	skeletal_berserker             =  10391, -- 해골 광전사 · Skeletal Berserker
	skeletal_executioner           =   1787, -- 해골 사형집행인 · Skeletal Executioner
	skeletal_highborne             =  11476, -- 해골이 된 명가 · Skeletal Highborne
	skeletal_warrior               =     48, -- 해골 전사 · Skeletal Warrior
	smolderthorn_axe_thrower       =   9267, -- 가시불꽃 도끼 투척병 · Smolderthorn Axe Thrower
	snickerfang_hyena              =   5985, -- 칼송곳니하이에나 · Snickerfang Hyena
	snow_leopard                   =   1201, -- 눈표범 · Snow Leopard
	son_of_flame                   =  12143, -- 화염의 피조물 · Son of Flame
	son_of_hakkar                  =  11357, -- 학카르의 자손 · Son of Hakkar
	soul_weaver                    =  16429, -- 영혼의 마녀 · Soul Weaver
	spawn_of_marli                 =  15041, -- 말리의 새끼거미 · Spawn of Mar'li
	spectral_researcher            =  10499, -- 연구원 유령 · Spectral Researcher
	spirestone_enforcer            =   9199, -- 뾰족바위 집행자 · Spirestone Enforcer
	spirestone_mystic              =   9198, -- 뾰족바위 비술사 · Spirestone Mystic
	spitelash_myrmidon             =   6196, -- 원한꼬리 미르미돈 · Spitelash Myrmidon
	spitelash_warrior              =   6190, -- 원한꼬리 전사 · Spitelash Warrior
	spitting_scarab                =  15462, -- 독액 스카라베 · Spitting Scarab
	splinterbone_warrior           =   7344, -- 가시해골 전사 · Splinterbone Warrior
	spore                          =  16286, -- 포자 · Spore
	steeljaw_snapper               =  14123, -- 강철 무쇠턱거북 · Steeljaw Snapper
	stitched_spewer                =  16025, -- 기워 붙인 거인 · Stitched Spewer
	stone_steward                  =   4860, -- 바위 청지기 · Stone Steward
	stonesplinter_seer             =   1166, -- 가루바위 점쟁이 · Stonesplinter Seer
	stonesplinter_trogg            =   1161, -- 가루바위 트로그 · Stonesplinter Trogg
	stonevault_brawler             =   4855, -- 바위동굴 투사 · Stonevault Brawler
	swamp_jaguar                   =    767, -- 늪지재규어 · Swamp Jaguar
	swamp_talker                   =    950, -- 수다쟁이 늪지 멀록 · Swamp Talker
	syndicate_enforcer             =   2247, -- 비밀결사대 집행자 · Syndicate Enforcer
	syndicate_footpad              =   2240, -- 비밀결사대 노상강도 · Syndicate Footpad
	theradrim_guardian             =  11784, -- 테라드림 수호자 · Theradrim Guardian
	theradrim_shardling            =  11783, -- 테라드림 파편 · Theradrim Shardling
	thistlefur_avenger             =   3925, -- 엉겅퀴 복수자 · Thistlefur Avenger
	thunderhead_stagwing           =   6377, -- 날개발굽 천둥뿔 히포그리프 · Thunderhead Stagwing
	thuzadin_shadowcaster          =  10398, -- 투자딘 흑마술사 · Thuzadin Shadowcaster
	timberling                     =   2022, -- 나무괴물 · Timberling
	tomb_horror                    =  15979, -- 공포의 무덤마귀 · Tomb Horror
	torn_fin_oracle                =   2376, -- 너덜지느러미 점쟁이 · Torn Fin Oracle
	twilight_avenger               =  11880, -- 황혼의 복수자 · Twilight Avenger
	twilight_avenger_2             =  11880, -- 황혼의 복수자 · Twilight Avenger
	twilight_emissary              =   8913, -- 황혼의 밀사 · Twilight Emissary
	twilight_flamereaver           =  15201, -- 황혼의 화염약탈자 · Twilight Flamereaver
	twilight_flamereaver_2         =  15201, -- 황혼의 화염약탈자 · Twilight Flamereaver
	twilight_geolord               =  11881, -- 황혼의 대지술사 · Twilight Geolord
	twilight_master                =  11883, -- 황혼의 장로 · Twilight Master
	twilight_reaver                =   4810, -- 황혼의 약탈자 · Twilight Reaver
	twilight_stonecaller           =  11882, -- 황혼의 돌소환사 · Twilight Stonecaller
	unfettered_spirit              =   4308, -- 해방된 영혼 · Unfettered Spirit
	unholy_staff                   =  16215, -- 악령 깃든 지팡이 · Unholy Staff
	unrelenting_trainee            =  16124, -- 무자비한 수련생 · Unrelenting Trainee
	vault_warder                   =  10120, -- 석실 관리인 · Vault Warder
	vekniss_drone                  =  15300, -- 일꾼 베크니스 · Vekniss Drone
	vekniss_hive_crawler           =  15240, -- 집게발 베크니스 · Vekniss Hive Crawler
	vekniss_soldier                =  15229, -- 병정 베크니스 · Vekniss Soldier
	vekniss_stinger                =  15235, -- 쐐기 베크니스 · Vekniss Stinger
	vekniss_warrior                =  15230, -- 전사 베크니스 · Vekniss Warrior
	vekniss_wasp                   =  15236, -- 독침 베크니스 · Vekniss Wasp
	venom_stalker                  =  15976, -- 맹독 늑대거미 · Venom Stalker
	venture_co_logger              =   3989, -- 투자개발회사 나무꾼 · Venture Co. Logger
	vilebranch_berserker           =   2643, -- 썩은가지 광전사 · Vilebranch Berserker
	vilebranch_raiding_wolf        =   2681, -- 길들인 썩은가지 늑대 · Vilebranch Raiding Wolf
	vilebranch_witch_doctor        =   2640, -- 썩은가지 의술사 · Vilebranch Witch Doctor
	walking_bomb                   =   7915, -- 보행 폭탄 · Walking Bomb
	warpwood_crusher               =  13021, -- 분쇄의 굽이나무정령 · Warpwood Crusher
	wildspawn_felsworn             =  11455, -- 야생혈족 악마추종자 · Wildspawn Felsworn
	wildspawn_satyr                =  11451, -- 야생혈족 사티로스 · Wildspawn Satyr
	windfury_sorceress             =   2964, -- 성난바람 마법사 · Windfury Sorceress
	winterfall_shaman              =   7439, -- 겨울눈 주술사 · Winterfall Shaman
	winterfall_ursa                =   7438, -- 겨울눈 펄볼그 · Winterfall Ursa
	witherbark_axe_thrower         =   2554, -- 마른나무껍질 도끼 투척병 · Witherbark Axe Thrower
	withered_battle_boar           =   7333, -- 썩어버린 전투멧돼지 · Withered Battle Boar
	woodpaw_brute                  =   5253, -- 덩굴발 투사 · Woodpaw Brute
	worg                           =   1765, -- 검은늑대 · Worg
	wrath_hammer_construct         =   8907, -- 징벌의 피조물 · Wrath Hammer Construct
	zulian_crocolisk               =  15043, -- 줄리안 악어 · Zulian Crocolisk
	zulian_guardian                =  15068, -- 줄리안 수호표범 · Zulian Guardian
	zulian_panther                 =  11365, -- 줄리안 표범 · Zulian Panther
	zulian_prowler                 =  15101, -- 굶주린 줄리안 표범 · Zulian Prowler
	zulian_stalker                 =  15067, -- 줄리안 그림자표범 · Zulian Stalker
}

-- stage bosses by "difficulty-stage"
ns.MODEL.boss = {
	["1-1"  ] =    448, -- 들창코 · Hogger
	["1-2"  ] =   1271, -- 늙은 얼음수염 · Old Icebeard
	["1-3"  ] =   2038, -- 제왕 멜레나스 · Lord Melenas
	["1-4"  ] =   3205, -- 잘라제인 · Zalazane
	["1-5"  ] =   8554, -- 족장 칼날엄니 · Chief Sharptusk Thornmantle
	["1-6"  ] =   1662, -- 대장 페린 · Captain Perrine
	["1-7"  ] =    115, -- 허수아비골렘 수확기 · Harvest Reaper
	["1-8"  ] =   1399, -- 마고쉬 · Magosh
	["1-9"  ] =   2529, -- 아루갈의 후예 · Son of Arugal
	["1-10" ] =   3394, -- 바라크 코도베인 · Barak Kodobane
	["1-11" ] =  11520, -- 욕망의 타라가만 · Taragaman the Hungerer
	["1-12" ] =    334, -- 가스일조그 · Gath'Ilzogg
	["1-13" ] =   4202, -- 게렌조 렌치휘슬 · Gerenzo Wrenchwhistle
	["1-14" ] =   3654, -- 걸신들린 무타누스 · Mutanus the Devourer
	["1-15" ] =    639, -- 에드윈 밴클리프 · Edwin VanCleef
	["1-16" ] =  12678, -- 우르산고우스 · Ursangous
	["1-17" ] =    412, -- 누더기 · Stitches
	["1-18" ] =   2423, -- 앨리덴 페레놀드 경 · Lord Aliden Perenolde
	["1-19" ] =   2090, -- 마룩 웜스케일 · Ma'ruk Wyrmscale
	["1-20" ] =   4275, -- 대마법사 아루갈 · Archmage Arugal
	["1-21" ] =   4829, -- 아쿠마이 · Aku'mai
	["1-22" ] =  10896, -- 아르낙 그림토템 · Arnak Grimtotem
	["1-23" ] =   4543, -- 혈법사 탈노스 · Bloodmage Thalnos
	["1-24" ] =   7800, -- 기계박사 텔마플러그 · Mekgineer Thermaplugg
	["1-25" ] =   4421, -- 서슬깃 차를가 · Charlga Razorflank
	["1-26" ] =   6487, -- 신비술사 도안 · Arcanist Doan
	["1-27" ] =   2604, -- 무쇠주먹 몰로크 · Molok the Crusher
	["1-28" ] =   5760, -- 제왕 아즈레토크 · Lord Azrethoc
	["1-29" ] =    731, -- 야수왕 뱅갈라시 · King Bangalash
	["1-30" ] =   3975, -- 헤로드 · Herod
	["2-1"  ] =   2749, -- 철옹성 · Siege Golem
	["2-2"  ] =   4500, -- 대군주 모크모로크 · Overlord Mok'Morokk
	["2-3"  ] =  14445, -- 군주 웜막 · Lord Captain Wyrmak
	["2-4"  ] =   3977, -- 종교재판관 화이트메인 · High Inquisitor Whitemane
	["2-5"  ] =   7358, -- 혹한의 암네나르 · Amnennar the Coldbringer
	["2-6"  ] =   8136, -- 군주 샬자루 · Lord Shalzaru
	["2-7"  ] =   7995, -- 타락한 여사제 헥스 · Vile Priestess Hexx
	["2-8"  ] =   7883, -- 앙드레 파이어비어드 · Andre Firebeard
	["2-9"  ] =   7228, -- 아이로나야 · Ironaya
	["2-10" ] =   2748, -- 아카에다스 · Archaedas
	["2-11" ] =  14621, -- 감독관 말토류스 · Overseer Maltorius
	["2-12" ] =   7267, -- 족장 우코르즈 샌드스칼프 · Chief Ukorz Sandscalp
	["2-13" ] =   6649, -- 여군주 세스피라 · Lady Sesspira
	["2-14" ] =   7846, -- 파멸의 테레무스 · Teremus the Devourer
	["2-15" ] =  13282, -- 녹시온 · Noxxion
	["2-16" ] =  12201, -- 공주 테라드라스 · Princess Theradras
	["2-17" ] =   6584, -- 폭군 모쉬 · King Mosh
	["2-18" ] =   9454, -- 사바스라스 · Xavathras
	["2-19" ] =  14437, -- 고르지키 와일드아이즈 · Gorzeeki Wildeyes
	["2-20" ] =   5709, -- 에라니쿠스의 사령 · Shade of Eranikus
	["2-21" ] =   1852, -- 소환사 아라즈 · Araj the Summoner
	["2-22" ] =   9017, -- 불의 군주 인센디우스 · Lord Incendius
	["2-23" ] =   9938, -- 마그무스 · Magmus
	["2-24" ] =   9019, -- 제왕 다그란 타우릿산 · Emperor Dagran Thaurissan
	["2-25" ] =  10738, -- 대족장 겨울눈 · High Chief Winterfall
	["2-26" ] =  10826, -- 군주 다크사이드 · Lord Darkscythe
	["2-27" ] =  11492, -- 칼날바람 알진 · Alzzin the Wildshaper
	["2-28" ] =  15308, -- 황혼의 예언자 · Twilight Prophet
	["2-29" ] =   9196, -- 대영주 오모크 · Highlord Omokk
	["2-30" ] =   9568, -- 대군주 웜타라크 · Overlord Wyrmthalak
	["3-1"  ] =  11501, -- 왕 고르독 · King Gordok
	["3-2"  ] =  11486, -- 왕자 토르텔드린 · Prince Tortheldrin
	["3-3"  ] =  10503, -- 잔다이스 바로브 · Jandice Barov
	["3-4"  ] =  10813, -- 발나자르 · Balnazzar
	["3-5"  ] =  10429, -- 대족장 렌드 블랙핸드 · Warchief Rend Blackhand
	["3-6"  ] =  10508, -- 라스 프로스트위스퍼 · Ras Frostwhisper
	["3-7"  ] =   1853, -- 암흑스승 간들링 · Darkmaster Gandling
	["3-8"  ] =  10440, -- 남작 리븐데어 · Baron Rivendare
	["3-9"  ] =   9816, -- 불의 수호자 엠버시어 · Pyroguard Emberseer
	["3-10" ] =  10363, -- 사령관 드라키사스 · General Drakkisath
	["3-11" ] =  14507, -- 대사제 베녹시스 · High Priest Venoxis
	["3-12" ] =  14517, -- 대여사제 제클릭 · High Priestess Jeklik
	["3-13" ] =  14510, -- 대여사제 말리 · High Priestess Mar'li
	["3-14" ] =  11382, -- 혈군주 만도키르 · Bloodlord Mandokir
	["3-15" ] =  15083, -- 하자라 · Hazza'rah
	["3-16" ] =  15114, -- 가즈란카 · Gahz'ranka
	["3-17" ] =  14509, -- 대사제 데칼 · High Priest Thekal
	["3-18" ] =  14515, -- 대여사제 알로크 · High Priestess Arlokk
	["3-19" ] =  11380, -- 사술사 진도 · Jin'do the Hexxer
	["3-20" ] =  14834, -- 학카르 · Hakkar
	["3-21" ] =  15203, -- 왕자 스칼레녹스 · Prince Skaldrenox
	["3-22" ] =  15204, -- 대장군 휠락시스 · High Marshal Whirlaxis
	["3-23" ] =  15348, -- 쿠린낙스 · Kurinnaxx
	["3-24" ] =  15341, -- 장군 라작스 · General Rajaxx
	["3-25" ] =  15340, -- 모암 · Moam
	["3-26" ] =  15370, -- 먹보 부루 · Buru the Gorger
	["3-27" ] =  15369, -- 사냥꾼 아야미스 · Ayamiss the Hunter
	["3-28" ] =  15339, -- 무적의 오시리안 · Ossirian the Unscarred
	["3-29" ] =   6109, -- 아주어고스 · Azuregos
	["3-30" ] =  12397, -- 군주 카자크 · Lord Kazzak
	["4-1"  ] =  12118, -- 루시프론 · Lucifron
	["4-2"  ] =  11982, -- 마그마다르 · Magmadar
	["4-3"  ] =  12259, -- 게헨나스 · Gehennas
	["4-4"  ] =  12057, -- 가르 · Garr
	["4-5"  ] =  12264, -- 샤즈라 · Shazzrah
	["4-6"  ] =  12056, -- 남작 게돈 · Baron Geddon
	["4-7"  ] =  11988, -- 초열의 골레마그 · Golemagg the Incinerator
	["4-8"  ] =  12098, -- 설퍼론 선구자 · Sulfuron Harbinger
	["4-9"  ] =  12018, -- 청지기 이그젝큐투스 · Majordomo Executus
	["4-10" ] =  11502, -- 라그나로스 · Ragnaros
	["4-11" ] =  10184, -- 오닉시아 · Onyxia
	["4-12" ] =  12435, -- 폭군 서슬송곳니 · Razorgore the Untamed
	["4-13" ] =  13020, -- 타락한 밸라스트라즈 · Vaelastrasz the Corrupt
	["4-14" ] =  12017, -- 용기대장 래쉬레이어 · Broodlord Lashlayer
	["4-15" ] =  14020, -- 크로마구스 · Chromaggus
	["4-16" ] =  11583, -- 네파리안 · Nefarian
	["4-17" ] =  15263, -- 예언자 스케람 · The Prophet Skeram
	["4-18" ] =  15509, -- 공주 후후란 · Princess Huhuran
	["4-19" ] =  15275, -- 제왕 베크닐라쉬 · Emperor Vek'nilash
	["4-20" ] =  15727, -- 크툰 · C'Thun
	["4-21" ] =  15956, -- 아눕레칸 · Anub'Rekhan
	["4-22" ] =  15953, -- 귀부인 팰리나 · Grand Widow Faerlina
	["4-23" ] =  15952, -- 맥스나 · Maexxna
	["4-24" ] =  15954, -- 역병술사 노스 · Noth the Plaguebringer
	["4-25" ] =  15936, -- 부정의 헤이건 · Heigan the Unclean
	["4-26" ] =  16011, -- 로데브 · Loatheb
	["4-27" ] =  16060, -- 영혼 착취자 고딕 · Gothik the Harvester
	["4-28" ] =  15928, -- 타디우스 · Thaddius
	["4-29" ] =  16062, -- 대영주 모그레인 · Highlord Mograine
	["4-30" ] =  15990, -- 켈투자드 · Kel'Thuzad
}

-- summons (skills that call a creature)
ns.MODEL.summon = {
	felguard       =  17252, -- Felguard
	hunters_pet    =     69, -- Diseased Timber Wolf
	infernal       =     89, -- Infernal
}

-- companions (Data/Pets.lua ids)
ns.MODEL.pet = {
	bigglesworth   =  16998, -- Mr. Bigglesworth
	cat            =   7382, -- Orange Tabby Cat
	chicken        =   8376, -- Mechanical Chicken
	ember          =  12265, -- Lava Spawn
	imp            =    416, -- Imp
	squirrel       =   2671, -- Mechanical Squirrel
	whelp          =   7544, -- Crimson Whelpling
}

-- The forms player druids take in the original game: the night elf's for
-- the Alliance, the tauren's for the Horde, one colour each (creature
-- display ids the classic game gives the shapeshift)
ns.MODEL.form = {
	bear    = { ALLIANCE = 2281,  HORDE = 2289 },  -- 곰 변신 · 광포한 곰 변신
	cat     = { ALLIANCE = 892,   HORDE = 8571 },  -- 표범 변신
	moonkin = { ALLIANCE = 15374, HORDE = 15375 }, -- 달빛야수 변신
}

-- Every spec as one famous NPC of the class, one for each faction, in the
-- version the classic-era game data has (nil: the class trainer below)
ns.MODEL.famous = {
	WARRIOR_ARMS    = { ALLIANCE = { npc = 2784, sex = "M", name = "국왕 마그니 브론즈비어드" }, HORDE = { npc = 25256, sex = "M", name = "대군주 사울팽" } },
	WARRIOR_FURY    = { ALLIANCE = { npc = 29611, sex = "M", name = "국왕 바리안 린" }, HORDE = { npc = 18076, sex = "M", name = "그롬마쉬 헬스크림" } },
	WARRIOR_PROT    = { ALLIANCE = { npc = 36948, sex = "M", name = "무라딘 브론즈비어드" }, HORDE = { npc = 25237, sex = "M", name = "가로쉬 헬스크림" } },
	PALADIN_HOLY    = { ALLIANCE = { npc = 26528, sex = "M", name = "빛의 수호자 우서" }, HORDE = { npc = 17076, sex = "F", name = "여군주 리아드린" } },
	PALADIN_PROT    = { ALLIANCE = { npc = 1748, sex = "M", name = "대영주 볼바르 폴드라곤" }, HORDE = { npc = 17717, sex = "M", name = "기사군주 블러드밸러" } },
	PALADIN_RET     = { ALLIANCE = { npc = 28179, sex = "M", name = "대영주 티리온 폴드링" }, HORDE = { npc = 17076, sex = "F", name = "여군주 리아드린" } },
	HUNTER_BM       = { ALLIANCE = { npc = 27986, sex = "M", name = "헤멧 네싱워리" }, HORDE = { npc = 21984, sex = "M", name = "렉사르" } },
	HUNTER_MM       = { ALLIANCE = { npc = 30115, sex = "F", name = "베리사 윈드러너" }, HORDE = { npc = 10181, sex = "F", name = "여군주 실바나스 윈드러너" } },
	HUNTER_SV       = { ALLIANCE = { npc = 3936, sex = "F", name = "샨드리스 페더문" }, HORDE = { npc = 16801, sex = "M", name = "할두런 브라이트윙" } },
	ROGUE_ASSA      = { ALLIANCE = { npc = 29607, sex = "F", name = "발리라 생귀나르" }, HORDE = { npc = 6768, sex = "M", name = "조라크 라벤홀트 경" } },
	ROGUE_OUTLAW    = { ALLIANCE = { npc = 2496, sex = "M", name = "남작 레빌가즈" }, HORDE = { npc = 2496, sex = "M", name = "남작 레빌가즈" } },
	ROGUE_SUB       = { ALLIANCE = { npc = 332, sex = "M", name = "단장 마티아스 쇼" }, HORDE = nil },
	PRIEST_DISC     = { ALLIANCE = { npc = 1747, sex = "M", name = "안두인 린" }, HORDE = nil },
	PRIEST_HOLY     = { ALLIANCE = { npc = 17468, sex = "M", name = "예언자 벨렌" }, HORDE = nil },
	PRIEST_SHADOW   = { ALLIANCE = { npc = 1284, sex = "M", name = "대주교 베네딕투스" }, HORDE = nil },
	SHAMAN_ELE      = { ALLIANCE = { npc = 17204, sex = "M", name = "선견자 노분도" }, HORDE = { npc = 11946, sex = "M", name = "드렉타르" } },
	SHAMAN_ENH      = { ALLIANCE = nil, HORDE = { npc = 4949, sex = "M", name = "스랄" } },
	SHAMAN_RESTO    = { ALLIANCE = nil, HORDE = { npc = 17123, sex = "F", name = "대지술사 리가" } },
	MAGE_ARCANE     = { ALLIANCE = { npc = 18166, sex = "M", name = "대마법사 카드가" }, HORDE = { npc = 30116, sex = "M", name = "대마법사 에이타스 선리버" } },
	MAGE_FIRE       = { ALLIANCE = { npc = 16128, sex = "M", name = "로닌" }, HORDE = { npc = 19622, sex = "M", name = "캘타스 선스트라이더" } },
	MAGE_FROST      = { ALLIANCE = { npc = 4968, sex = "F", name = "여군주 제이나 프라우드무어" }, HORDE = { npc = 16800, sex = "M", name = "대마법학자 롬매스" } },
	WARLOCK_AFF     = { ALLIANCE = nil, HORDE = nil },
	WARLOCK_DEMO    = { ALLIANCE = { npc = 35458, sex = "M", name = "윌프레드 피즐뱅" }, HORDE = { npc = 17008, sex = "M", name = "굴단" } },
	WARLOCK_DESTRO  = { ALLIANCE = nil, HORDE = nil },
	DRUID_BALANCE   = { ALLIANCE = { npc = 15362, sex = "M", name = "말퓨리온 스톰레이지" }, HORDE = { npc = 5769, sex = "M", name = "대드루이드 하뮬 룬토템" } },
	DRUID_FERAL     = { ALLIANCE = { npc = 15382, sex = "M", name = "판드랄 스태그헬름" }, HORDE = { npc = 3679, sex = "M", name = "나랄렉스" } },
	DRUID_GUARDIAN  = { ALLIANCE = { npc = 29604, sex = "M", name = "브롤 베어맨틀" }, HORDE = { npc = 3057, sex = "M", name = "케른 블러드후프" } },
	DRUID_RESTO     = { ALLIANCE = { npc = 11832, sex = "M", name = "수호자 레물로스" }, HORDE = nil },
}

-- The class trainer of the class's race for the faction (Data/Races.lua
-- ns.CLASS_RACE): the look of a spec without a famous NPC, and the one that
-- stands in when the game cannot show the famous one
ns.MODEL.trainer = {
	WARRIOR = { ALLIANCE = { npc =    912, sex = "M" }, HORDE = { npc =   3353, sex = "M" } },
	PALADIN = { ALLIANCE = { npc =   8140, sex = "M" }, HORDE = { npc =  17076, sex = "F" } },
	HUNTER  = { ALLIANCE = { npc =   3601, sex = "M" }, HORDE = { npc =   3406, sex = "M" } },
	ROGUE   = { ALLIANCE = { npc =    205, sex = "M" }, HORDE = { npc =   4583, sex = "M" } },
	PRIEST  = { ALLIANCE = { npc =  17510, sex = "M" }, HORDE = { npc =   3046, sex = "M" } },
	SHAMAN  = { ALLIANCE = { npc =  17219, sex = "F" }, HORDE = { npc =   3031, sex = "M" } },
	MAGE    = { ALLIANCE = { npc =    198, sex = "M" }, HORDE = { npc =  16646, sex = "M" } },
	WARLOCK = { ALLIANCE = { npc =    906, sex = "M" }, HORDE = { npc =    988, sex = "M" } },
	DRUID   = { ALLIANCE = { npc =   4217, sex = "M" }, HORDE = { npc =   3033, sex = "M" } },
}

-- The dungeon set each class wears (the original game's first dungeon sets,
-- item ids): Valor, Lightforge, Beaststalker, Shadowcraft, Devout, the
-- Elements, Magister's, Dreadmist and Wildheart
ns.MODEL.dungeonSet = {
	WARRIOR = { name = "용맹의 전투장비", items = { 16731, 16733, 16730, 16737, 16736, 16732, 16734, 16735 } },
	PALADIN = { name = "성전사 방어구", items = { 16727, 16729, 16726, 16724, 16723, 16728, 16725, 16722 } },
	HUNTER  = { name = "야수추적자 갑옷", items = { 16677, 16679, 16674, 16676, 16680, 16678, 16675, 16681 } },
	ROGUE   = { name = "어둠추적자 갑옷", items = { 16707, 16708, 16721, 16712, 16713, 16709, 16711, 16710 } },
	PRIEST  = { name = "기원의 의복", items = { 16693, 16695, 16690, 16692, 16696, 16694, 16691, 16697 } },
	SHAMAN  = { name = "정령의 방어구", items = { 16667, 16669, 16666, 16672, 16673, 16668, 16670, 16671 } },
	MAGE    = { name = "원소술사 의복", items = { 16686, 16689, 16688, 16684, 16685, 16687, 16682, 16683 } },
	WARLOCK = { name = "공포안개 의복", items = { 16698, 16701, 16700, 16705, 16702, 16699, 16704, 16703 } },
	DRUID   = { name = "자연의정수 의복", items = { 16720, 16718, 16706, 16717, 16716, 16719, 16715, 16714 } },
}
-- The weapons each spec holds: its best weapons from the original game's
-- level 60 five-man dungeons (Blackrock Depths, Lower and Upper Blackrock
-- Spire, Dire Maul, Scholomance, Stratholme), item ids; mh = main hand (a
-- two-hander or, for hunters, the bow or crossbow they shoot with), oh = off
-- hand (a weapon, shield or held item).
ns.MODEL.weapons = {
	WARRIOR_ARMS   = { mh = 12592 },                -- 샤크람의 흑도 (검은바위 첨탑 상층: 장군 드라키사스)
	WARRIOR_FURY   = { mh = 12940, oh = 12939 },    -- 달렌드의 성검 · 부족 수호검 (검은바위 첨탑 상층: 대족장 렌드 블랙핸드)
	WARRIOR_PROT   = { mh = 11684, oh = 12602 },    -- 무쇠폭군 (검은바위 나락: 제왕 다그란 타우릿산) · 용족 굴절방패 (첨탑 상층: 드라키사스)
	PALADIN_HOLY   = { mh = 11923, oh = 11928 },    -- 은총의 망치 · 제왕 타우릿산의 홀 (검은바위 나락)
	PALADIN_PROT   = { mh = 11684, oh = 12602 },    -- 무쇠폭군 · 용족 굴절방패
	PALADIN_RET    = { mh = 18538 },                -- 나무정령 파멸의 도끼 (혈투의 전장 북부: 공물)
	HUNTER_BM      = { mh = 18680 },                -- 고대의 해골 장궁 (스칼로맨스: 교관 말리시아)
	HUNTER_MM      = { mh = 12651 },                -- 검은까마귀 (검은바위 첨탑 하층: 그림자사냥꾼 보쉬가진)
	HUNTER_SV      = { mh = 18680 },                -- 고대의 해골 장궁
	ROGUE_ASSA     = { mh = 12590, oh = 13368 },    -- 필살의 비수 (첨탑 상층: 렌드) · 해골 절단기 (스트라솔름: 남작 리븐데어)
	ROGUE_OUTLAW   = { mh = 12940, oh = 12939 },    -- 달렌드의 성검 · 부족 수호검
	ROGUE_SUB      = { mh = 12590, oh = 18392 },    -- 필살의 비수 · 혼돈의 단검 (혈투의 전장 서부: 왕자 토르텔드린)
	PRIEST_DISC    = { mh = 11923, oh = 11928 },    -- 은총의 망치 · 제왕 타우릿산의 홀
	PRIEST_HOLY    = { mh = 22406 },                -- 구원의 지팡이 (스트라솔름: 포병대장 윌리)
	PRIEST_SHADOW  = { mh = 22335 },                -- 군주 발타라크의 지휘봉 (첨탑 상층: 군주 발타라크)
	SHAMAN_ELE     = { mh = 13964, oh = 22336 },    -- 마녀의 비수 (스칼로맨스: 암흑스승 간들링) · 군단 용기병 아이기스 (첨탑 상층: 발타라크)
	SHAMAN_ENH     = { mh = 18538 },                -- 나무정령 파멸의 도끼
	SHAMAN_RESTO   = { mh = 11923, oh = 18523 },    -- 은총의 망치 · 밝게 빛나는 돌 (혈투의 전장 북부: 왕 고르독)
	MAGE_ARCANE    = { mh = 13964, oh = 22253 },    -- 마녀의 비수 · 길잃은자의 고서 (첨탑 상층: 드라키사스)
	MAGE_FIRE      = { mh = 13964, oh = 22253 },
	MAGE_FROST     = { mh = 13964, oh = 22253 },
	WARLOCK_AFF    = { mh = 18372, oh = 22253 },    -- 초승달 단도 (혈투의 전장 서부: 이몰타르) · 길잃은자의 고서
	WARLOCK_DEMO   = { mh = 18372, oh = 22253 },
	WARLOCK_DESTRO = { mh = 13964, oh = 22253 },    -- 마녀의 비수 · 길잃은자의 고서
	DRUID_BALANCE  = { mh = 23124 },                -- 발자폰의 지팡이 (스트라솔름: 발자폰)
	DRUID_FERAL    = { mh = 13372 },                -- 노예감독의 지팡이 (스트라솔름: 게걸먹보 램스타인)
	DRUID_GUARDIAN = { mh = 18531 },                -- 단호의 마울 (혈투의 전장 북부: 공물)
	DRUID_RESTO    = { mh = 11932 },                -- 지혜의 지팡이 (검은바위 나락: 타우릿산)
}

-- the game's race ids (SetCustomRace)
ns.MODEL.raceId = { HUMAN = 1, ORC = 2, DWARF = 3, NIGHTELF = 4, UNDEAD = 5, TAUREN = 6, GNOME = 7, TROLL = 8 }
-- Each race's own body with nothing on (the game's base display of the race,
-- ChrRaces Male/FemaleDisplayID)
ns.MODEL.raceBody = {
	HUMAN = { M = 49, F = 50 }, ORC = { M = 51, F = 52 }, DWARF = { M = 53, F = 54 },
	NIGHTELF = { M = 55, F = 56 }, UNDEAD = { M = 57, F = 58 }, TAUREN = { M = 59, F = 60 },
	GNOME = { M = 1563, F = 1564 }, TROLL = { M = 1478, F = 1479 },
}

-- The model each NPC above is drawn with (its creature display id), in the
-- classic-era game data: the vanilla, then Burning Crusade, then Wrath of the
-- Lich King version (CMaNGOS databases; the famous NPCs in their latest of
-- those), and for the few NPCs from later only, the retail one (TrinityCore).
-- A model put up by its display id comes straight from the game's data,
-- without asking the server about the NPC.
ns.MODEL.display = {
	[36] = 367, [48] = 200, [49] = 159, [54] = 1287, [55] = 17, [60] = 2153,
	[69] = 604, [89] = 169, [115] = 379, [117] = 175, [118] = 11415, [198] = 5001,
	[205] = 736, [206] = 522, [257] = 10912, [332] = 1736, [334] = 6050, [412] = 1693,
	[416] = 4449, [423] = 487, [440] = 6033, [448] = 384, [485] = 6034, [504] = 2331,
	[539] = 958, [547] = 3035, [597] = 4579, [598] = 308, [634] = 2316, [639] = 2029,
	[684] = 633, [687] = 11317, [731] = 616, [752] = 386, [767] = 632,
	[906] = 3271, [912] = 3399, [950] = 5243, [988] = 4567, [1012] = 3196, [1038] = 4924,
	[1040] = 2023, [1140] = 11316, [1161] = 763, [1166] = 764, [1178] = 1122, [1186] = 707,
	[1196] = 8840, [1201] = 954, [1271] = 1050, [1284] = 5072, [1397] = 5610, [1399] = 160,
	[1478] = 1519, [1479] = 3506, [1506] = 2403, [1535] = 2471, [1536] = 2468, [1539] = 2469,
	[1563] = 796, [1564] = 4461, [1662] = 1738, [1747] = 31201, [1748] = 5566, [1765] = 11421,
	[1770] = 729, [1778] = 902, [1787] = 11401, [1826] = 10286, [1827] = 10350, [1852] = 7919,
	[1853] = 11070, [1964] = 864, [1989] = 3023, [2008] = 6800, [2022] = 3033, [2038] = 1013,
	[2090] = 4914, [2240] = 3706, [2247] = 3729, [2348] = 8014, [2376] = 4920, [2423] = 1833,
	[2496] = 7167, [2529] = 1098, [2554] = 3991, [2560] = 180, [2566] = 3193, [2604] = 536,
	[2640] = 6542, [2643] = 6493, [2671] = 7937, [2681] = 782, [2715] = 10714, [2727] = 161,
	[2732] = 1055, [2748] = 5988, [2749] = 13869, [2784] = 3597, [2953] = 6090, [2954] = 6807,
	[2956] = 1220, [2964] = 1255, [3031] = 2102, [3033] = 2106, [3046] = 2137, [3057] = 4307,
	[3110] = 1250, [3111] = 1218, [3198] = 4190, [3205] = 4078, [3265] = 6094, [3275] = 4874,
	[3353] = 1374, [3394] = 4874, [3406] = 4239, [3415] = 1056, [3601] = 1703,
	[3641] = 1752, [3654] = 4088, [3679] = 4216, [3748] = 6822, [3809] = 820, [3823] = 802,
	[3840] = 4211, [3855] = 657, [3861] = 801, [3925] = 6823, [3936] = 2035, [3975] = 2041,
	[3977] = 2043, [3989] = 7228, [4005] = 760, [4094] = 9411, [4096] = 9412, [4202] = 3885,
	[4217] = 2261, [4250] = 2726, [4275] = 2353, [4287] = 2463, [4291] = 2507, [4295] = 2514,
	[4296] = 5726, [4298] = 2462, [4299] = 2501, [4302] = 2460, [4306] = 2607, [4308] = 5430,
	[4356] = 11315, [4360] = 5243, [4363] = 5286, [4376] = 545, [4417] = 2440, [4421] = 4642,
	[4436] = 6108, [4438] = 6078, [4463] = 6030, [4500] = 11571, [4520] = 4647, [4539] = 1954,
	[4540] = 2603, [4543] = 11396, [4583] = 2639, [4627] = 1131, [4637] = 9446, [4640] = 2293,
	[4666] = 4701, [4668] = 4709, [4802] = 4983, [4807] = 4762, [4810] = 2898, [4829] = 2837,
	[4855] = 11166, [4860] = 2234, [4863] = 4486, [4949] = 4527, [4968] = 30863, [5048] = 4317,
	[5239] = 11556, [5253] = 543, [5256] = 7709, [5259] = 6670, [5277] = 7903, [5280] = 7863,
	[5286] = 165, [5424] = 10986, [5471] = 11545, [5648] = 6419, [5649] = 6423, [5709] = 7806,
	[5760] = 4426, [5769] = 4519, [5846] = 7798, [5854] = 10801, [5858] = 7510, [5974] = 14402,
	[5976] = 11584, [5985] = 2714, [6010] = 1913, [6011] = 9017, [6109] = 11460, [6130] = 6760,
	[6190] = 6747, [6196] = 11265, [6200] = 2878, [6206] = 830, [6212] = 3456, [6223] = 6982,
	[6377] = 10894, [6427] = 4629, [6487] = 5266, [6499] = 5238,
	[6521] = 5488, [6575] = 2467, [6584] = 5305, [6649] = 11261, [6768] = 6572, [7025] = 6045,
	[7034] = 11550, [7040] = 143, [7047] = 397, [7076] = 6026, [7105] = 2019, [7109] = 11334,
	[7153] = 2000, [7228] = 6089, [7235] = 6804, [7247] = 6427, [7267] = 6439, [7274] = 6440,
	[7290] = 6057, [7333] = 6121, [7337] = 11381, [7344] = 5231, [7358] = 7971, [7382] = 5554,
	[7431] = 9953, [7433] = 11444, [7438] = 6829, [7439] = 6830, [7458] = 10579, [7544] = 6290,
	[7800] = 6980, [7846] = 6378, [7883] = 9073, [7915] = 6977, [7995] = 7121,
	[8136] = 11257, [8140] = 7356, [8376] = 7920, [8438] = 7829, [8522] = 11172, [8524] = 11397,
	[8554] = 1346, [8557] = 6841, [8890] = 8758, [8891] = 8750, [8900] = 8812, [8903] = 8749,
	[8904] = 8825, [8906] = 8177, [8907] = 8178, [8911] = 5488, [8913] = 8772, [9017] = 1204,
	[9019] = 8807, [9096] = 2554, [9167] = 8412, [9196] = 11565, [9198] = 11579, [9199] = 11577,
	[9267] = 9674, [9454] = 2880, [9568] = 8711, [9583] = 9633, [9692] = 9602,
	[9696] = 9562, [9816] = 2172, [9817] = 9670, [9818] = 9849, [9819] = 9686, [9938] = 12162,
	[9956] = 9309, [10083] = 8249, [10120] = 5989, [10157] = 12236, [10181] = 28213, [10184] = 8570,
	[10316] = 9690, [10317] = 9734, [10319] = 9696, [10363] = 10115, [10372] = 8309, [10391] = 9784,
	[10398] = 10631, [10414] = 1693, [10422] = 10504, [10424] = 10512, [10429] = 9778, [10440] = 10729,
	[10442] = 10095, [10469] = 11161, [10475] = 11161, [10477] = 11163, [10482] = 9786, [10488] = 12074,
	[10489] = 7848, [10491] = 11397, [10499] = 3942, [10503] = 11073, [10508] = 7919, [10738] = 9491,
	[10813] = 10691, [10814] = 10116, [10826] = 7847, [10896] = 10243, [11043] = 10463, [11262] = 397,
	[11320] = 11010, [11321] = 2075, [11322] = 11434, [11338] = 11229, [11339] = 11225, [11340] = 11221,
	[11346] = 11158, [11350] = 11074, [11351] = 11109, [11352] = 14832, [11353] = 11080, [11355] = 11167,
	[11356] = 11100, [11357] = 15275, [11365] = 633, [11368] = 14562, [11370] = 963, [11371] = 15182,
	[11372] = 15150, [11380] = 11311, [11382] = 11288, [11439] = 11073, [11441] = 12473, [11444] = 11537,
	[11450] = 10709, [11451] = 11345, [11455] = 7649, [11466] = 11207, [11473] = 14366, [11476] = 11078,
	[11486] = 11256, [11492] = 14416, [11501] = 11583, [11502] = 11121, [11520] = 7970, [11582] = 11163,
	[11583] = 11380, [11598] = 775, [11658] = 8269, [11659] = 12162, [11661] = 12030, [11662] = 12030,
	[11663] = 13029, [11664] = 12002, [11665] = 12164, [11666] = 1070, [11667] = 5488, [11668] = 12231,
	[11671] = 12168, [11672] = 11997, [11721] = 12151, [11744] = 8715, [11783] = 12310, [11784] = 11712,
	[11792] = 2021, [11830] = 11758, [11831] = 11762, [11832] = 11906, [11880] = 11811, [11881] = 11819,
	[11882] = 11815, [11883] = 11824, [11946] = 11894, [11982] = 10193, [11988] = 11986, [12017] = 14308,
	[12018] = 12029, [12056] = 12129, [12057] = 12110, [12098] = 13030, [12099] = 5781, [12118] = 13031,
	[12119] = 12030, [12129] = 8711, [12143] = 5488, [12201] = 12292, [12206] = 12309, [12219] = 12347,
	[12220] = 12348, [12259] = 13030, [12260] = 6369, [12264] = 13032, [12265] = 2172, [12397] = 12449,
	[12416] = 12024, [12420] = 11979, [12422] = 2554, [12435] = 10115, [12457] = 7923, [12458] = 11967,
	[12459] = 14292, [12460] = 14308, [12461] = 14355, [12463] = 8310, [12464] = 12893, [12465] = 12894,
	[12467] = 14544, [12468] = 12892, [12678] = 2281, [13020] = 13992, [13021] = 12929, [13036] = 12966,
	[13142] = 13098, [13282] = 11172, [13456] = 5492, [13996] = 13991, [14020] = 14367, [14123] = 7114,
	[14302] = 14352, [14437] = 14566, [14445] = 7976, [14456] = 12024, [14507] = 15217,
	[14509] = 15216, [14510] = 15220, [14515] = 15218, [14517] = 15219, [14532] = 14950, [14621] = 14665,
	[14750] = 15303, [14821] = 2571, [14834] = 15295, [14986] = 15233, [15041] = 15136,
	[15043] = 833, [15067] = 14572, [15068] = 11029, [15083] = 15267, [15101] = 613, [15114] = 15288,
	[15163] = 15301, [15201] = 2896, [15203] = 12002, [15204] = 7691, [15209] = 1204, [15212] = 8716,
	[15229] = 15434, [15230] = 15334, [15235] = 15338, [15236] = 15335, [15240] = 15533, [15246] = 15740,
	[15252] = 15340, [15262] = 15346, [15263] = 15345, [15275] = 15761, [15300] = 15362, [15308] = 15373,
	[15311] = 15351, [15312] = 15346, [15320] = 15439, [15323] = 11084, [15324] = 15741, [15325] = 11142,
	[15327] = 9229, [15333] = 13509, [15335] = 15463, [15336] = 15336, [15338] = 15343, [15339] = 15432,
	[15340] = 15392, [15341] = 15376, [15343] = 15465, [15348] = 15742, [15355] = 15347, [15362] = 15399,
	[15369] = 15431, [15370] = 15654, [15382] = 15421, [15387] = 15437, [15462] = 15464, [15509] = 15739,
	[15521] = 11095, [15725] = 15789, [15726] = 15788, [15727] = 15787, [15928] = 16137, [15936] = 16309,
	[15952] = 15928, [15953] = 15940, [15954] = 16590, [15956] = 15931, [15974] = 15937, [15975] = 15938,
	[15976] = 15939, [15978] = 15941, [15979] = 15942, [15980] = 16594, [15981] = 16598, [15990] = 15945,
	[16011] = 16110, [16020] = 16063, [16021] = 16175, [16025] = 15961, [16034] = 9013, [16036] = 7896,
	[16060] = 16279, [16062] = 16139, [16124] = 16608, [16128] = 16024, [16145] = 16513, [16146] = 16508,
	[16163] = 10729, [16164] = 14703, [16165] = 11396, [16215] = 15294, [16236] = 15788, [16243] = 11140,
	[16244] = 10627, [16286] = 16111, [16297] = 7898, [16419] = 14368, [16429] = 16178, [16446] = 14710,
	[16447] = 10627, [16451] = 10729, [16453] = 15939, [16506] = 16603, [16646] = 16787, [16800] = 19706,
	[16801] = 19707, [16998] = 16622, [17008] = 16642, [17076] = 16820, [17123] = 16867, [17204] = 17600,
	[17219] = 16914, [17252] = 14255, [17468] = 17822, [17510] = 17249, [17717] = 17199, [18076] = 17470,
	[18166] = 18921, [19622] = 20023, [21984] = 20918, [25237] = 23006, [25256] = 23033,
	[26528] = 23889, [27986] = 24969, [28179] = 22209, [29604] = 26364, [29607] = 26365, [29611] = 28127,
	[30115] = 28222, [30116] = 26770, [35458] = 29814, [36948] = 30508,
}
