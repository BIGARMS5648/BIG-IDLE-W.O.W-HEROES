-- 3D models for the battle: the NPC (creature) id whose model stands in for
-- each monster, boss, summon, companion and hero (UI/Figure3D.lua puts it up
-- by its display id, below). Every id was checked against wowhead's name for
-- it (the English name in the comment); where the game has no such creature
-- the closest look is used.
local _, ns = ...

ns.MODEL = {}

-- the monsters of the stages (Data/Monsters.lua ids)
ns.MODEL.mob = {
	akumai_fisher                  =   4824, -- 아쿠마이거북 · Aku'mai Fisher
	akumai_servant                 =   4978, -- 아쿠마이의 하수인 · Aku'mai Servant
	akumai_snapjaw                 =   4825, -- 무쇠턱 아쿠마이거북 · Aku'mai Snapjaw
	anubisath_defender             =  15277, -- 아누비사스 문지기 · Anubisath Defender
	anubisath_guardian             =  15355, -- 아누비사스 감시자 · Anubisath Guardian
	anubisath_guardian_2           =  15355, -- 아누비사스 감시자 · Anubisath Guardian
	anubisath_warder               =  15311, -- 아누비사스 수호병 · Anubisath Warder
	anvilrage_guardsman            =   8891, -- 성난모루 보초 · Anvilrage Guardsman
	anvilrage_marshal              =   8898, -- 성난모루 치안대장 · Anvilrage Marshal
	anvilrage_officer              =   8895, -- 성난모루 장교 · Anvilrage Officer
	anvilrage_soldier              =   8893, -- 성난모루 병사 · Anvilrage Soldier
	anvilrage_warden               =   8890, -- 성난모루 교도관 · Anvilrage Warden
	arcane_aberration              =  11480, -- 불가사의한 피조물 · Arcane Aberration
	arcane_nullifier_x_21          =   6232, -- 자동화 마력제거기 X-21 · Arcane Nullifier X-21
	atalai_corpse_eater            =   5270, -- 아탈라이 식인트롤 · Atal'ai Corpse Eater
	atalai_warrior                 =   5256, -- 아탈라이 전사 · Atal'ai Warrior
	atalai_witch_doctor            =   5259, -- 아탈라이 의술사 · Atal'ai Witch Doctor
	barbed_lasher                  =  12219, -- 뾰족가시 덩굴손 · Barbed Lasher
	bile_retcher                   =  16018, -- 부패의 역병골렘 · Bile Retcher
	black_guard_sentry             =  10394, -- 검은호위대 보초병 · Black Guard Sentry
	blackfathom_myrmidon           =   4807, -- 검은심연 미르미돈 · Blackfathom Myrmidon
	blackfathom_myrmidon_2         =   4807, -- 검은심연 미르미돈 · Blackfathom Myrmidon
	blackfathom_myrmidon_3         =   4807, -- 검은심연 미르미돈 · Blackfathom Myrmidon
	blackfathom_sea_witch          =   4805, -- 검은심연 바다 마녀 · Blackfathom Sea Witch
	blackfathom_tide_priestess     =   4802, -- 검은심연 해일여사제 · Blackfathom Tide Priestess
	blackhand_assassin             =  10318, -- 검은손부대 암살자 · Blackhand Assassin
	blackhand_dragon_handler       =  10742, -- 검은손부대 용조련사 · Blackhand Dragon Handler
	blackhand_dreadweaver          =   9817, -- 검은손부대 공포술사 · Blackhand Dreadweaver
	blackhand_elite                =  10317, -- 검은손부대 정예병 · Blackhand Elite
	blackhand_iron_guard           =  10319, -- 검은손부대 철갑병 · Blackhand Iron Guard
	blackhand_summoner             =   9818, -- 검은손부대 소환사 · Blackhand Summoner
	blackhand_thug                 =  10762, -- 검은손부대 암살단원 · Blackhand Thug
	blackhand_veteran              =   9819, -- 검은손부대 고참병 · Blackhand Veteran
	blackwing_guardsman            =  14456, -- 검은날개 수호병 · Blackwing Guardsman
	blackwing_legionnaire          =  12416, -- 검은날개 부대원 · Blackwing Legionnaire
	blackwing_legionnaire_2        =  12416, -- 검은날개 부대원 · Blackwing Legionnaire
	blackwing_mage                 =  12420, -- 검은날개 마법사 · Blackwing Mage
	blackwing_spellbinder          =  12457, -- 검은날개 역술사 · Blackwing Spellbinder
	blackwing_taskmaster           =  12458, -- 검은날개 작업반장 · Blackwing Taskmaster
	blackwing_technician           =  13996, -- 검은날개 기술병 · Blackwing Technician
	blackwing_warlock              =  12459, -- 검은날개 흑마법사 · Blackwing Warlock
	blazing_fireguard              =   8910, -- 타오르는 화염수호정령 · Blazing Fireguard
	bleak_worg                     =   3861, -- 사나운 검은늑대 · Bleak Worg
	bleak_worg_2                   =   3861, -- 사나운 검은늑대 · Bleak Worg
	bloodaxe_evoker                =   9693, -- 도끼부대 기원사 · Bloodaxe Evoker
	bloodaxe_summoner              =   9717, -- 도끼부대 소환사 · Bloodaxe Summoner
	bloodaxe_veteran               =   9583, -- 도끼부대 고참병 · Bloodaxe Veteran
	bloodaxe_worg                  =   9696, -- 도끼부대 검은늑대 · Bloodaxe Worg
	bloodhound                     =   8921, -- 핏빛사냥개 · Bloodhound
	bloodhound_mastiff             =   8922, -- 덩치 큰 핏빛사냥개 · Bloodhound Mastiff
	boneflayer_ghoul               =   7347, -- 강철손톱 구울 · Boneflayer Ghoul
	burning_spirit                 =   9178, -- 불타는 정령 · Burning Spirit
	burning_spirit_2               =   9178, -- 불타는 정령 · Burning Spirit
	burning_spirit_3               =   9178, -- 불타는 정령 · Burning Spirit
	carrion_spinner                =  15975, -- 청소부 그물거미 · Carrion Spinner
	caverndeep_burrower            =   6206, -- 깊은굴 땅꾼 · Caverndeep Burrower
	celebrian_dryad                =  11793, -- 셀레브리안 드리아드 · Celebrian Dryad
	celebrian_dryad_2              =  11793, -- 셀레브리안 드리아드 · Celebrian Dryad
	chromatic_drakonid             =  14302, -- 오색용기병 · Chromatic Drakonid
	chromatic_drakonid_2           =  14302, -- 오색용기병 · Chromatic Drakonid
	chromatic_elite_guard          =  10814, -- 오색용혈족 정예병 · Chromatic Elite Guard
	chromatic_elite_guard_2        =  10814, -- 오색용혈족 정예병 · Chromatic Elite Guard
	chromatic_whelp                =  10442, -- 오색 새끼용 · Chromatic Whelp
	claw_tentacle                  =  15725, -- 갈고리 촉수 · Claw Tentacle
	core_hound                     =  11671, -- 심장부 사냥개 · Core Hound
	core_rager                     =  11672, -- 흉포한 심장부 사냥개 · Core Rager
	core_rager_2                   =  11672, -- 흉포한 심장부 사냥개 · Core Rager
	creeping_sludge                =  12222, -- 끈적거리는 녹괴물 · Creeping Sludge
	crimson_defender               =  10421, -- 되살아난 파수병 · Crimson Defender
	crimson_gallant                =  10424, -- 되살아난 수행원 · Crimson Gallant
	crimson_initiate               =  10420, -- 되살아난 신입회원 · Crimson Initiate
	crimson_monk                   =  11043, -- 되살아난 수도사 · Crimson Monk
	crypt_guard                    =  16573, -- 지하마귀 수호병 · Crypt Guard
	crypt_reaver                   =  15978, -- 칼날발톱 지하마귀 · Crypt Reaver
	crypt_reaver_2                 =  15978, -- 칼날발톱 지하마귀 · Crypt Reaver
	cursed_atalai                  =   5243, -- 저주받은 아탈라이트롤 · Cursed Atal'ai
	dark_iron_agent                =   6212, -- 검은무쇠 첩보원 · Dark Iron Agent
	death_talon_captain            =  12467, -- 죽음의발톱 부대장 · Death Talon Captain
	death_talon_dragonspawn        =  12422, -- 죽음의발톱 용혈족 · Death Talon Dragonspawn
	death_talon_flamescale         =  12463, -- 죽음의발톱 화염전사 · Death Talon Flamescale
	death_talon_hatcher            =  12468, -- 죽음의발톱 알지기 · Death Talon Hatcher
	death_talon_seether            =  12464, -- 죽음의발톱 정예병 · Death Talon Seether
	death_talon_wyrmguard          =  12460, -- 죽음의발톱 고룡수호병 · Death Talon Wyrmguard
	death_talon_wyrmguard_2        =  12460, -- 죽음의발톱 고룡수호병 · Death Talon Wyrmguard
	death_talon_wyrmkin            =  12465, -- 죽음의발톱 고룡족 · Death Talon Wyrmkin
	deathknight                    =  16146, -- 죽음의 기사 · Deathknight
	deathknight_2                  =  16146, -- 죽음의 기사 · Deathknight
	deathknight_captain            =  16145, -- 죽음의 기사단 대장 · Deathknight Captain
	deathknight_cavalier           =  16163, -- 죽음의 기사단 기병 · Deathknight Cavalier
	deathknight_vindicator         =  16451, -- 죽음의 기사단 근위병 · Deathknight Vindicator
	deaths_head_acolyte            =   4515, -- 죽음의 머리교 수행사제 · Death's Head Acolyte
	deaths_head_necromancer        =   7337, -- 죽음의 머리교 강령술사 · Death's Head Necromancer
	deeprot_stomper                =  13141, -- 우레의 깊은뿌리정령 · Deeprot Stomper
	defias_blackguard              =    636, -- 데피아즈단 검은자객 · Defias Blackguard
	defias_blackguard_2            =    636, -- 데피아즈단 검은자객 · Defias Blackguard
	defias_captive                 =   1707, -- 데피아즈단 죄수 · Defias Captive
	defias_convict                 =   1711, -- 무기징역수 · Defias Convict
	defias_convict_2               =   1711, -- 무기징역수 · Defias Convict
	defias_evoker                  =   1729, -- 데피아즈단 기원사 · Defias Evoker
	defias_inmate                  =   1708, -- 데피아즈단 전과자 · Defias Inmate
	defias_inmate_2                =   1708, -- 데피아즈단 전과자 · Defias Inmate
	defias_insurgent               =   1715, -- 반역자 · Defias Insurgent
	defias_miner                   =    598, -- 데피아즈단 광부 · Defias Miner
	defias_overseer                =    634, -- 데피아즈단 감독관 · Defias Overseer
	defias_pirate                  =    657, -- 데피아즈단 해적 · Defias Pirate
	defias_pirate_2                =    657, -- 데피아즈단 해적 · Defias Pirate
	defias_prisoner                =   1706, -- 복역수 · Defias Prisoner
	defias_squallshaper            =   1732, -- 데피아즈단 돌풍술사 · Defias Squallshaper
	defias_taskmaster              =   4417, -- 데피아즈단 작업반장 · Defias Taskmaster
	defias_wizard                  =   4418, -- 데피아즈단 마술사 · Defias Wizard
	deviate_crocolisk              =   5053, -- 돌연변이 악어 · Deviate Crocolisk
	deviate_lurker                 =   3641, -- 돌연변이 비늘트레샤돈 · Deviate Lurker
	deviate_ravager                =   3636, -- 돌연변이 약탈자랩터 · Deviate Ravager
	deviate_ravager_2              =   3636, -- 돌연변이 약탈자랩터 · Deviate Ravager
	deviate_stinglash              =   3631, -- 돌연변이 독침천둥매 · Deviate Stinglash
	deviate_viper                  =   5755, -- 돌연변이 독사 · Deviate Viper
	doomforge_arcanasmith          =   8900, -- 파멸괴철로 신비대장장이 · Doomforge Arcanasmith
	doomforge_dragoon              =   8899, -- 파멸괴철로 용기병 · Doomforge Dragoon
	dread_creeper                  =  15974, -- 공포의 암흑거미 · Dread Creeper
	druid_of_the_fang              =   3840, -- 송곳니의 드루이드 · Druid of the Fang
	druid_of_the_fang_2            =   3840, -- 송곳니의 드루이드 · Druid of the Fang
	druid_of_the_fang_3            =   3840, -- 송곳니의 드루이드 · Druid of the Fang
	earthborer                     =  11320, -- 땅벌레 · Earthborer
	earthen_custodian              =   7309, -- 토석인 유물관리자 · Earthen Custodian
	earthen_guardian               =   7076, -- 토석인 수호자 · Earthen Guardian
	earthen_guardian_2             =   7076, -- 토석인 수호자 · Earthen Guardian
	earthen_hallshaper             =   7077, -- 토석인 조각장이 · Earthen Hallshaper
	earthen_rocksmasher            =   7011, -- 토석인 바위망치장이 · Earthen Rocksmasher
	earthen_sculptor               =   7012, -- 토석인 조각사 · Earthen Sculptor
	earthen_sculptor_2             =   7012, -- 토석인 조각사 · Earthen Sculptor
	eldreth_spectre                =  11473, -- 엘드레스 원혼 · Eldreth Spectre
	eye_tentacle                   =  15726, -- 눈 달린 촉수 · Eye Tentacle
	firebrand_dreadweaver          =   9263, -- 횃불부대 공포술사 · Firebrand Dreadweaver
	firebrand_grunt                =   9259, -- 횃불부대 그런트 · Firebrand Grunt
	firebrand_invoker              =   9262, -- 횃불부대 기원사 · Firebrand Invoker
	firebrand_pyromancer           =   9264, -- 횃불부대 화염술사 · Firebrand Pyromancer
	fireguard                      =   8909, -- 화염수호정령 · Fireguard
	fireguard_destroyer            =   8911, -- 파괴의 화염수호정령 · Fireguard Destroyer
	firelord                       =  11668, -- 불의 군주 · Firelord
	firelord_2                     =  11668, -- 불의 군주 · Firelord
	firelord_3                     =  11668, -- 불의 군주 · Firelord
	firewalker                     =  11666, -- 불꽃 정령 · Firewalker
	firewalker_2                   =  11666, -- 불꽃 정령 · Firewalker
	firewalker_3                   =  11666, -- 불꽃 정령 · Firewalker
	firewalker_4                   =  11666, -- 불꽃 정령 · Firewalker
	flameguard                     =  11667, -- 화염의수호자 · Flameguard
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
	flamewaker_priest_3            =  11662, -- 불꽃꼬리 사제 · Flamewaker Priest
	flamewaker_protector           =  12119, -- 불꽃꼬리 수호병 · Flamewaker Protector
	flamewaker_protector_2         =  12119, -- 불꽃꼬리 수호병 · Flamewaker Protector
	flesh_hunter                   =  15335, -- 청소부 수액괴물 · Flesh Hunter
	ghost_of_naxxramas             =  16419, -- 낙스라마스의 유령 · Ghost of Naxxramas
	goblin_engineer                =    622, -- 고블린 기술자 · Goblin Engineer
	goblin_engineer_2              =    622, -- 고블린 기술자 · Goblin Engineer
	goblin_woodcarver              =    641, -- 고블린 목공 · Goblin Woodcarver
	gordok_brute                   =  11441, -- 고르독 투사 · Gordok Brute
	gordok_mage_lord               =  11444, -- 고르독 대마법사 · Gordok Mage-Lord
	gordok_mastiff                 =  13036, -- 고르독 사냥개 · Gordok Mastiff
	gurubashi_bat_rider            =  14750, -- 구루바시 박쥐 기수 · Gurubashi Bat Rider
	gurubashi_berserker            =  11352, -- 구루바시 광전사 · Gurubashi Berserker
	gurubashi_berserker_2          =  11352, -- 구루바시 광전사 · Gurubashi Berserker
	gurubashi_champion             =  11356, -- 구루바시 용사 · Gurubashi Champion
	gurubashi_champion_2           =  11356, -- 구루바시 용사 · Gurubashi Champion
	gurubashi_headhunter           =  11351, -- 구루바시 인간사냥꾼 · Gurubashi Headhunter
	gurubashi_warrior              =  11355, -- 구루바시 전사 · Gurubashi Warrior
	hakkari_blood_priest           =  11340, -- 학카리 혈사제 · Hakkari Blood Priest
	hakkari_oracle                 =  11346, -- 학카리 현자 · Hakkari Oracle
	hakkari_priest                 =  11830, -- 학카리 사제 · Hakkari Priest
	hakkari_shadow_hunter          =  11339, -- 학카리 어둠사냥꾼 · Hakkari Shadow Hunter
	hakkari_shadowcaster           =  11338, -- 학카리 흑마술사 · Hakkari Shadowcaster
	hakkari_witch_doctor           =  11831, -- 학카리 의술사 · Hakkari Witch Doctor
	haunted_servitor               =   3875, -- 이승을 떠도는 하인 유령 · Haunted Servitor
	haunted_servitor_2             =   3875, -- 이승을 떠도는 하인 유령 · Haunted Servitor
	highborne_summoner             =  11466, -- 명가의 소환사 · Highborne Summoner
	hivezara_hatchling             =  15521, -- 새끼 하이브자라 · Hive'Zara Hatchling
	hivezara_soldier               =  15320, -- 병정 하이브자라 · Hive'Zara Soldier
	hivezara_stinger               =  15327, -- 쐐기 하이브자라 · Hive'Zara Stinger
	hivezara_tail_lasher           =  15336, -- 채찍꼬리 하이브자라 · Hive'Zara Tail Lasher
	hivezara_wasp                  =  15325, -- 독침 하이브자라 · Hive'Zara Wasp
	illusion_of_jandice_barov      =  11439, -- 잔다이스 바로브의 환영 · Illusion of Jandice Barov
	infectious_ghoul               =  16244, -- 전염병 구울 · Infectious Ghoul
	ironhand_guardian              =   8982, -- 폭정의 수호자 · Ironhand Guardian
	irradiated_horror              =   6220, -- 오염된 폐기물 · Irradiated Horror
	irradiated_pillager            =   6329, -- 오염된 약탈자 · Irradiated Pillager
	jadespine_basilisk             =   4863, -- 비취돌기바실리스크 · Jadespine Basilisk
	kraul_bat                      =   4538, -- 동굴박쥐 · Kraul Bat
	lava_annihilator               =  11665, -- 용암의 파괴자 · Lava Annihilator
	leprous_defender               =   6223, -- 오염된 노움 수호병 · Leprous Defender
	leprous_machinesmith           =   6224, -- 오염된 노움 기계공 · Leprous Machinesmith
	leprous_technician             =   6222, -- 오염된 노움 기술병 · Leprous Technician
	living_monstrosity             =  16021, -- 살아 움직이는 괴물 · Living Monstrosity
	mad_magglish                   =   3655, -- 광기의 매글리시 · Mad Magglish
	mad_scientist                  =  16020, -- 미치광이 과학자 · Mad Scientist
	maexxna_spiderling             =  17055, -- 맥스나의 새끼 거미 · Maexxna Spiderling
	mechanized_sentry              =   6233, -- 기계화 보초병 · Mechanized Sentry
	mechano_frostwalker            =   6227, -- 기계화 냉기보행전차 · Mechano-Frostwalker
	mechano_tank                   =   6225, -- 기계보행전차 · Mechano-Tank
	molten_destroyer               =  11659, -- 파괴의 용암거인 · Molten Destroyer
	molten_destroyer_2             =  11659, -- 파괴의 용암거인 · Molten Destroyer
	molten_elemental               =  11321, -- 녹아내린 정령 · Molten Elemental
	molten_giant                   =  11658, -- 용암거인 · Molten Giant
	molten_giant_2                 =  11658, -- 용암거인 · Molten Giant
	murkshallow_snapclaw           =   4815, -- 집게발 검은모래톱마크루라 · Murkshallow Snapclaw
	naxxramas_cultist              =  15980, -- 낙스라마스 신도 · Naxxramas Cultist
	necro_knight                   =  16165, -- 해골 기사 · Necro Knight
	necro_knight_2                 =  16165, -- 해골 기사 · Necro Knight
	necro_knight_3                 =  16165, -- 해골 기사 · Necro Knight
	necro_stalker                  =  16453, -- 죽음의 동굴거미 · Necro Stalker
	necropolis_acolyte             =  16368, -- 죽음의 요새 수행사제 · Necropolis Acolyte
	nightmare_scalebane            =   5277, -- 악몽의 맹독전사 · Nightmare Scalebane
	nightmare_suppressor           =   8497, -- 악몽의 문지기 · Nightmare Suppressor
	nightmare_whelp                =   8319, -- 악몽의 새끼용 · Nightmare Whelp
	nightmare_wyrmkin              =   5280, -- 악몽의 고룡족 · Nightmare Wyrmkin
	noxxious_scion                 =  13696, -- 녹시온의 후예 · Noxxious Scion
	obsidian_destroyer             =  15338, -- 흑요석 파괴자 · Obsidian Destroyer
	obsidian_eradicator            =  15262, -- 흑요석 파멸자 · Obsidian Eradicator
	obsidian_nullifier             =  15312, -- 흑요석 종결자 · Obsidian Nullifier
	onyxian_drake                  =  12260, -- 오닉시아의 비룡 · Onyxian Drake
	onyxian_warder                 =  12129, -- 오닉시아의 수호병 · Onyxian Warder
	onyxian_whelp                  =  11262, -- 오닉시아의 새끼용 · Onyxian Whelp
	onyxian_whelp_2                =  11262, -- 오닉시아의 새끼용 · Onyxian Whelp
	patchwork_golem                =  16017, -- 기워 붙인 누더기골렘 · Patchwork Golem
	patchwork_horror               =  10414, -- 기워붙인 누더기골렘 · Patchwork Horror
	plague_beast                   =  16034, -- 역병 걸린 괴물 · Plague Beast
	plagued_gargoyle               =  16446, -- 역병 걸린 가고일 · Plagued Gargoyle
	poison_sprite                  =  12216, -- 맹독의 마귀 · Poison Sprite
	primordial_behemoth            =  12206, -- 태초의 거수 · Primordial Behemoth
	primordial_behemoth_2          =  12206, -- 태초의 거수 · Primordial Behemoth
	putridus_satyr                 =  11790, -- 타락의 사티로스 · Putridus Satyr
	putridus_shadowstalker         =  11792, -- 타락의 그림자추적자 · Putridus Shadowstalker
	putridus_trickster             =  11791, -- 타락의 요술사 · Putridus Trickster
	qiraji_champion                =  15252, -- 퀴라지 용사 · Qiraji Champion
	qiraji_gladiator               =  15324, -- 퀴라지 투사 · Qiraji Gladiator
	qiraji_mindslayer              =  15246, -- 퀴라지 정신파괴자 · Qiraji Mindslayer
	qiraji_swarmguard              =  15343, -- 퀴라지 감시병 · Qiraji Swarmguard
	qiraji_warrior                 =  15387, -- 퀴라지 전사 · Qiraji Warrior
	qiraji_warrior_2               =  15387, -- 퀴라지 전사 · Qiraji Warrior
	rage_talon_dragon_guard        =  10366, -- 성난발톱혈족 용투사 · Rage Talon Dragon Guard
	rage_talon_dragonspawn         =   9096, -- 성난발톱용혈족 · Rage Talon Dragonspawn
	rage_talon_fire_tongue         =  10372, -- 성난발톱혈족 화염술사 · Rage Talon Fire Tongue
	rage_talon_flamescale          =  10083, -- 화염비늘 성난발톱용혈족 · Rage Talon Flamescale
	ragefire_shaman                =  11319, -- 성난불길 주술사 · Ragefire Shaman
	ragefire_shaman_2              =  11319, -- 성난불길 주술사 · Ragefire Shaman
	ragefire_trogg                 =  11318, -- 성난불길 트로그 · Ragefire Trogg
	ragereaver_golem               =   8906, -- 맹위의 전투골렘 · Ragereaver Golem
	razorfen_beastmaster           =   4532, -- 가시덩굴 야수조련사 · Razorfen Beastmaster
	razorfen_defender              =   4442, -- 가시덩굴 파수병 · Razorfen Defender
	razorfen_geomancer             =   4520, -- 가시덩굴 흙점쟁이 · Razorfen Geomancer
	razorfen_servitor              =   6132, -- 가시덩굴 하수인 · Razorfen Servitor
	razzashi_raptor                =  14821, -- 래즈자쉬 랩터 · Razzashi Raptor
	razzashi_venombrood            =  14532, -- 래즈자쉬 독거미 · Razzashi Venombrood
	reanimated_corpse              =  10481, -- 되살아난 시체 · Reanimated Corpse
	risen_construct                =  10488, -- 되살아난 피조물 · Risen Construct
	risen_guard                    =  10489, -- 되살아난 경비병 · Risen Guard
	risen_guard_2                  =  10489, -- 되살아난 경비병 · Risen Guard
	risen_guardian                 =  11598, -- 되살아난 수호자 · Risen Guardian
	sandfury_acolyte               =   8876, -- 성난모래 수행사제 · Sandfury Acolyte
	sandfury_axe_thrower           =   5646, -- 성난모래 도끼 투척병 · Sandfury Axe Thrower
	sandfury_blood_drinker         =   5649, -- 성난모래 혈투사 · Sandfury Blood Drinker
	sandfury_cretin                =   7789, -- 성난모래 정신병자 · Sandfury Cretin
	sandfury_executioner           =   7274, -- 성난모래 사형집행인 · Sandfury Executioner
	sandfury_executioner_2         =   7274, -- 성난모래 사형집행인 · Sandfury Executioner
	sandfury_guardian              =   7268, -- 성난모래 수호물 · Sandfury Guardian
	sandfury_shadowhunter          =   7246, -- 성난모래 어둠사냥꾼 · Sandfury Shadowhunter
	sandfury_soul_eater            =   7247, -- 성난모래 영혼사냥꾼 · Sandfury Soul Eater
	sandfury_zealot                =   8877, -- 성난모래 광신도 · Sandfury Zealot
	sandfury_zealot_2              =   8877, -- 성난모래 광신도 · Sandfury Zealot
	scarab                         =   7269, -- 왕쇠똥구리 · Scarab
	scarlet_abbot                  =   4303, -- 붉은십자군 대수도원장 · Scarlet Abbot
	scarlet_beastmaster            =   4288, -- 붉은십자군 조련사 · Scarlet Beastmaster
	scarlet_centurion              =   4301, -- 붉은십자군 백인대장 · Scarlet Centurion
	scarlet_champion               =   4302, -- 붉은십자군 용사 · Scarlet Champion
	scarlet_champion_2             =   4302, -- 붉은십자군 용사 · Scarlet Champion
	scarlet_chaplain               =   4299, -- 붉은십자군 전도사 · Scarlet Chaplain
	scarlet_conjuror               =   4297, -- 붉은십자군 요술사 · Scarlet Conjuror
	scarlet_defender               =   4298, -- 붉은십자군 방어병 · Scarlet Defender
	scarlet_evoker                 =   4289, -- 붉은십자군 기원사 · Scarlet Evoker
	scarlet_gallant                =   4287, -- 붉은십자군 수행원 · Scarlet Gallant
	scarlet_monk                   =   4540, -- 붉은십자군 수도사 · Scarlet Monk
	scarlet_myrmidon               =   4295, -- 붉은십자군 정예병 · Scarlet Myrmidon
	scarlet_trainee                =   6575, -- 붉은십자군 신병 · Scarlet Trainee
	scholomance_dark_summoner      =  11582, -- 스칼로맨스 암흑소환사 · Scholomance Dark Summoner
	scholomance_handler            =  11257, -- 스칼로맨스 조련사 · Scholomance Handler
	scholomance_necromancer        =  10477, -- 스칼로맨스 강령술사 · Scholomance Necromancer
	scholomance_student            =  10475, -- 스칼로맨스 학생 · Scholomance Student
	searing_blade_cultist          =  11322, -- 이글거리는 칼날단 이교도 · Searing Blade Cultist
	searing_blade_enforcer         =  11323, -- 이글거리는 칼날단 집행자 · Searing Blade Enforcer
	searing_blade_warlock          =  11324, -- 이글거리는 칼날단 흑마법사 · Searing Blade Warlock
	shade_of_naxxramas             =  16164, -- 낙스라마스의 망령 · Shade of Naxxramas
	shade_of_naxxramas_2           =  16164, -- 낙스라마스의 망령 · Shade of Naxxramas
	shadowfang_darksoul            =   3855, -- 그림자송곳니 검은영혼 · Shadowfang Darksoul
	shadowfang_darksoul_2          =   3855, -- 그림자송곳니 검은영혼 · Shadowfang Darksoul
	shadowfang_darksoul_3          =   3855, -- 그림자송곳니 검은영혼 · Shadowfang Darksoul
	shadowfang_moonwalker          =   3853, -- 그림자송곳니 달전사 · Shadowfang Moonwalker
	shadowfang_ragetooth           =   3859, -- 그림자송곳니 송곳니투사 · Shadowfang Ragetooth
	shadowforge_ambusher           =   7091, -- 어둠괴철로 복병 · Shadowforge Ambusher
	shadowforge_flame_keeper       =   9956, -- 어둠괴철로 불꽃지기 · Shadowforge Flame Keeper
	shadowforge_ruffian            =   4845, -- 어둠괴철로 악당 · Shadowforge Ruffian
	shadowforge_senator            =   8904, -- 어둠괴철로 원로원 · Shadowforge Senator
	shadowforge_sharpshooter       =   7290, -- 어둠괴철로 저격수 · Shadowforge Sharpshooter
	shadowforge_surveyor           =   4844, -- 어둠괴철로 감독관 · Shadowforge Surveyor
	shrike_bat                     =   4861, -- 무덤박쥐 · Shrike Bat
	silicate_feeder                =  15333, -- 소금모래 청소부 · Silicate Feeder
	skeletal_berserker             =  10391, -- 해골 광전사 · Skeletal Berserker
	skeletal_frostweaver           =   7341, -- 해골 냉기술사 · Skeletal Frostweaver
	skeletal_highborne             =  11476, -- 해골이 된 명가 · Skeletal Highborne
	skeletal_summoner              =   7342, -- 해골 소환사 · Skeletal Summoner
	slavering_worg                 =   3862, -- 침 흘리는 검은늑대 · Slavering Worg
	slavering_worg_2               =   3862, -- 침 흘리는 검은늑대 · Slavering Worg
	sludge_belcher                 =  16029, -- 썩은위액 누더기골렘 · Sludge Belcher
	smolderthorn_axe_thrower       =   9267, -- 가시불꽃 도끼 투척병 · Smolderthorn Axe Thrower
	smolderthorn_berserker         =   9268, -- 가시불꽃 광전사 · Smolderthorn Berserker
	snapping_crustacean            =   4822, -- 집게껍질게 · Snapping Crustacean
	son_of_arugal                  =   2529, -- 아루갈의 후예 · Son of Arugal
	son_of_flame                   =  12143, -- 화염의 피조물 · Son of Flame
	son_of_hakkar                  =  11357, -- 학카르의 자손 · Son of Hakkar
	soul_weaver                    =  16429, -- 영혼의 마녀 · Soul Weaver
	spawn_of_marli                 =  15041, -- 말리의 새끼거미 · Spawn of Mar'li
	spire_spider                   =  10374, -- 첨탑거미 · Spire Spider
	spire_spiderling               =  10375, -- 새끼 첨탑거미 · Spire Spiderling
	spirestone_battle_mage         =   9197, -- 뾰족바위 전투 마법사 · Spirestone Battle Mage
	spirestone_enforcer            =   9199, -- 뾰족바위 집행자 · Spirestone Enforcer
	spirestone_ogre_magus          =   9201, -- 뾰족바위 오우거마법사 · Spirestone Ogre Magus
	spirestone_reaver              =   9200, -- 뾰족바위 약탈꾼 · Spirestone Reaver
	spitting_scarab                =  15462, -- 독액 스카라베 · Spitting Scarab
	splinterbone_captain           =   7345, -- 가시해골 대장 · Splinterbone Captain
	splinterbone_warrior           =   7344, -- 가시해골 전사 · Splinterbone Warrior
	stitched_spewer                =  16025, -- 기워 붙인 거인 · Stitched Spewer
	stone_keeper                   =   4857, -- 바위 문지기 · Stone Keeper
	stonevault_ambusher            =   7175, -- 바위동굴 복병 · Stonevault Ambusher
	stonevault_brawler             =   4855, -- 바위동굴 투사 · Stonevault Brawler
	stonevault_geomancer           =   4853, -- 바위동굴 흙점쟁이 · Stonevault Geomancer
	stonevault_oracle              =   4852, -- 바위동굴 현자 · Stonevault Oracle
	subterranean_diemetradon       =  13323, -- 지하 디메트로돈 · Subterranean Diemetradon
	sullithuz_abomination          =   8120, -- 흉포한 술리투즈 · Sul'lithuz Abomination
	sullithuz_broodling            =   8138, -- 어린 술리투즈 · Sul'lithuz Broodling
	sullithuz_sandcrawler          =   8095, -- 모래집게 술리투즈 · Sul'lithuz Sandcrawler
	theradrim_guardian             =  11784, -- 테라드림 수호자 · Theradrim Guardian
	theradrim_guardian_2           =  11784, -- 테라드림 수호자 · Theradrim Guardian
	theradrim_shardling            =  11783, -- 테라드림 파편 · Theradrim Shardling
	theradrim_shardling_2          =  11783, -- 테라드림 파편 · Theradrim Shardling
	theradrim_shardling_3          =  11783, -- 테라드림 파편 · Theradrim Shardling
	thuzadin_shadowcaster          =  10398, -- 투자딘 흑마술사 · Thuzadin Shadowcaster
	tomb_fiend                     =   7349, -- 무덤지하마귀 · Tomb Fiend
	tomb_horror                    =  15979, -- 공포의 무덤마귀 · Tomb Horror
	twilight_acolyte               =   4809, -- 황혼의 수행사제 · Twilight Acolyte
	twilight_bodyguard             =   8914, -- 황혼의 경호원 · Twilight Bodyguard
	twilight_elementalist          =   4814, -- 황혼의 정령술사 · Twilight Elementalist
	twilight_emissary              =   8913, -- 황혼의 밀사 · Twilight Emissary
	twilight_reaver                =   4810, -- 황혼의 약탈자 · Twilight Reaver
	twilights_hammer_executioner   =   9398, -- 황혼의 망치단 집행자 · Twilight's Hammer Executioner
	unholy_staff                   =  16215, -- 악령 깃든 지팡이 · Unholy Staff
	unliving_atalai                =   5267, -- 죽지 못하는 아탈라이트롤 · Unliving Atal'ai
	unrelenting_trainee            =  16124, -- 무자비한 수련생 · Unrelenting Trainee
	vault_warder                   =  10120, -- 석실 관리인 · Vault Warder
	vault_warder_2                 =  10120, -- 석실 관리인 · Vault Warder
	vekniss_drone                  =  15300, -- 일꾼 베크니스 · Vekniss Drone
	vekniss_hive_crawler           =  15240, -- 집게발 베크니스 · Vekniss Hive Crawler
	vekniss_soldier                =  15229, -- 병정 베크니스 · Vekniss Soldier
	vekniss_stinger                =  15235, -- 쐐기 베크니스 · Vekniss Stinger
	vekniss_warrior                =  15230, -- 전사 베크니스 · Vekniss Warrior
	vekniss_wasp                   =  15236, -- 독침 베크니스 · Vekniss Wasp
	venom_belcher                  =  10417, -- 독고름 누더기골렘 · Venom Belcher
	venom_stalker                  =  15976, -- 맹독 늑대거미 · Venom Stalker
	venomlash_scorpid              =   7022, -- 맹독꼬리전갈 · Venomlash Scorpid
	vile_bat                       =   3866, -- 그림자박쥐 · Vile Bat
	wailing_banshee                =  10464, -- 울부짖는 밴시 · Wailing Banshee
	walking_bomb                   =   7915, -- 보행 폭탄 · Walking Bomb
	warpwood_crusher               =  13021, -- 분쇄의 굽이나무정령 · Warpwood Crusher
	warpwood_stomper               =  11465, -- 우레의 굽이나무정령 · Warpwood Stomper
	warpwood_tangler               =  11464, -- 뿌리의 굽이나무정령 · Warpwood Tangler
	wildspawn_betrayer             =  11454, -- 야생혈족 배반자 · Wildspawn Betrayer
	wildspawn_rogue                =  11452, -- 야생혈족 도적 · Wildspawn Rogue
	wildspawn_satyr                =  11451, -- 야생혈족 사티로스 · Wildspawn Satyr
	withered_battle_boar           =   7333, -- 썩어버린 전투멧돼지 · Withered Battle Boar
	withered_reaver                =   7328, -- 썩어버린 도끼전투병 · Withered Reaver
	withered_warrior               =   7327, -- 썩어버린 전사 · Withered Warrior
	wrath_hammer_construct         =   8907, -- 징벌의 피조물 · Wrath Hammer Construct
	zulfarrak_dead_hero            =   7276, -- 죽음의 줄파락 영웅 · Zul'Farrak Dead Hero
	zulfarrak_zombie               =   7286, -- 줄파락 좀비 · Zul'Farrak Zombie
	zulian_prowler                 =  15101, -- 굶주린 줄리안 표범 · Zulian Prowler
}

-- stage bosses by "difficulty-stage"
ns.MODEL.boss = {
	["1-1"  ] =  11517, -- 오글플린트 · Oggleflint
	["1-2"  ] =  11520, -- 욕망의 타라가만 · Taragaman the Hungerer
	["1-3"  ] =  11518, -- 기원사 제르고쉬 · Jergosh the Invoker
	["1-4"  ] =   3671, -- 여군주 아나콘드라 · Lady Anacondra
	["1-5"  ] =   3670, -- 군주 피타스 · Lord Pythas
	["1-6"  ] =   3654, -- 걸신들린 무타누스 · Mutanus the Devourer
	["1-7"  ] =    644, -- 라크조르 · Rhahk'Zor
	["1-8"  ] =    642, -- 스니드의 벌목기 · Sneed's Shredder
	["1-9"  ] =    647, -- 선장 그린스킨 · Captain Greenskin
	["1-10" ] =    639, -- 에드윈 밴클리프 · Edwin VanCleef
	["1-11" ] =   3914, -- 레실고어 · Rethilgore
	["1-12" ] =   3927, -- 늑대왕 난도스 · Wolf Master Nandos
	["1-13" ] =   3887, -- 남작 실버레인 · Baron Silverlaine
	["1-14" ] =   4275, -- 대마법사 아루갈 · Archmage Arugal
	["1-15" ] =   1666, -- 캄 딥퓨리 · Kam Deepfury
	["1-16" ] =   1716, -- 바질 스레드 · Bazil Thredd
	["1-17" ] =   4887, -- 가무라 · Ghamoo-ra
	["1-18" ] =   4831, -- 여왕 사레베스 · Lady Sarevess
	["1-19" ] =   4832, -- 황혼의 군주 켈리스 · Twilight Lord Kelris
	["1-20" ] =   4829, -- 아쿠마이 · Aku'mai
	["1-21" ] =   7361, -- 그루비스 · Grubbis
	["1-22" ] =   7079, -- 방사성 폐기물 · Viscous Fallout
	["1-23" ] =   6235, -- 기계화 문지기 6000 · Electrocutioner 6000
	["1-24" ] =   7800, -- 기계박사 텔마플러그 · Mekgineer Thermaplugg
	["1-25" ] =   4428, -- 죽음예언자 잘그바 · Death Speaker Jargba
	["1-26" ] =   4421, -- 서슬깃 차를가 · Charlga Razorflank
	["1-27" ] =   6487, -- 신비술사 도안 · Arcanist Doan
	["1-28" ] =   3975, -- 헤로드 · Herod
	["1-29" ] =   3976, -- 붉은십자군 사령관 모그레인 · Scarlet Commander Mograine
	["1-30" ] =   3977, -- 종교재판관 화이트메인 · High Inquisitor Whitemane
	["2-1"  ] =   7355, -- 투텐카쉬 · Tuten'kash
	["2-2"  ] =   7357, -- 불꽃눈 모드레쉬 · Mordresh Fire Eye
	["2-3"  ] =   7358, -- 혹한의 암네나르 · Amnennar the Coldbringer
	["2-4"  ] =   6910, -- 레벨로쉬 · Revelosh
	["2-5"  ] =   7228, -- 아이로나야 · Ironaya
	["2-6"  ] =   4854, -- 그림로크 · Grimlok
	["2-7"  ] =   7291, -- 갈간 파이어해머 · Galgann Firehammer
	["2-8"  ] =   6906, -- 밸로그 · Baelog
	["2-9"  ] =   7023, -- 흑요석 파수꾼 · Obsidian Sentinel
	["2-10" ] =   2748, -- 아카에다스 · Archaedas
	["2-11" ] =   7273, -- 가즈릴라 · Gahz'rilla
	["2-12" ] =   8127, -- 안투술 · Antu'sul
	["2-13" ] =   7796, -- 네크룸 거트츄어 · Nekrum Gutchewer
	["2-14" ] =   7271, -- 의술사 줌라 · Witch Doctor Zum'rah
	["2-15" ] =   7267, -- 족장 우코르즈 샌드스칼프 · Chief Ukorz Sandscalp
	["2-16" ] =  13282, -- 녹시온 · Noxxion
	["2-17" ] =  12236, -- 군주 바일텅 · Lord Vyletongue
	["2-18" ] =  12225, -- 저주받은 셀레브라스 · Celebras the Cursed
	["2-19" ] =  12203, -- 산사태 · Landslide
	["2-20" ] =  12201, -- 공주 테라드라스 · Princess Theradras
	["2-21" ] =   8580, -- 아탈알라리온 · Atal'alarion
	["2-22" ] =   5710, -- 예언자 잠말란 · Jammal'an the Prophet
	["2-23" ] =   5709, -- 에라니쿠스의 사령 · Shade of Eranikus
	["2-24" ] =   9016, -- 밸가르 · Bael'Gar
	["2-25" ] =   9017, -- 불의 군주 인센디우스 · Lord Incendius
	["2-26" ] =   9033, -- 사령관 앵거포지 · General Angerforge
	["2-27" ] =   8983, -- 골렘 군주 아젤마크 · Golem Lord Argelmach
	["2-28" ] =   9156, -- 사자 화염채찍 · Ambassador Flamelash
	["2-29" ] =   9938, -- 마그무스 · Magmus
	["2-30" ] =   9019, -- 제왕 다그란 타우릿산 · Emperor Dagran Thaurissan
	["3-1"  ] =   9236, -- 어둠사냥꾼 보쉬가진 · Shadow Hunter Vosh'gajin
	["3-2"  ] =   9196, -- 대영주 오모크 · Highlord Omokk
	["3-3"  ] =  10596, -- 여왕 불그물거미 · Mother Smolderweb
	["3-4"  ] =  10584, -- 우로크 둠하울 · Urok Doomhowl
	["3-5"  ] =   9568, -- 대군주 웜타라크 · Overlord Wyrmthalak
	["3-6"  ] =   9816, -- 불의 수호자 엠버시어 · Pyroguard Emberseer
	["3-7"  ] =  10429, -- 대족장 렌드 블랙핸드 · Warchief Rend Blackhand
	["3-8"  ] =  16042, -- 군주 발타라크 · Lord Valthalak
	["3-9"  ] =  10430, -- 괴수 · The Beast
	["3-10" ] =  10363, -- 사령관 드라키사스 · General Drakkisath
	["3-11" ] =  11490, -- 제브림 쏜후프 · Zevrim Thornhoof
	["3-12" ] =  11492, -- 칼날바람 알진 · Alzzin the Wildshaper
	["3-13" ] =  11496, -- 이몰타르 · Immol'thar
	["3-14" ] =  11501, -- 왕 고르독 · King Gordok
	["3-15" ] =  10813, -- 발나자르 · Balnazzar
	["3-16" ] =  10436, -- 남작부인 아나스타리 · Baroness Anastari
	["3-17" ] =  10440, -- 남작 리븐데어 · Baron Rivendare
	["3-18" ] =  10508, -- 라스 프로스트위스퍼 · Ras Frostwhisper
	["3-19" ] =  10503, -- 잔다이스 바로브 · Jandice Barov
	["3-20" ] =   1853, -- 암흑스승 간들링 · Darkmaster Gandling
	["3-21" ] =  15348, -- 쿠린낙스 · Kurinnaxx
	["3-22" ] =  15341, -- 장군 라작스 · General Rajaxx
	["3-23" ] =  15370, -- 먹보 부루 · Buru the Gorger
	["3-24" ] =  15339, -- 무적의 오시리안 · Ossirian the Unscarred
	["3-25" ] =  11382, -- 혈군주 만도키르 · Bloodlord Mandokir
	["3-26" ] =  14507, -- 대사제 베녹시스 · High Priest Venoxis
	["3-27" ] =  14517, -- 대여사제 제클릭 · High Priestess Jeklik
	["3-28" ] =  14510, -- 대여사제 말리 · High Priestess Mar'li
	["3-29" ] =  14509, -- 대사제 데칼 · High Priest Thekal
	["3-30" ] =  14834, -- 학카르 · Hakkar
	["4-1"  ] =  11982, -- 마그마다르 · Magmadar
	["4-2"  ] =  12118, -- 루시프론 · Lucifron
	["4-3"  ] =  12259, -- 게헨나스 · Gehennas
	["4-4"  ] =  12057, -- 가르 · Garr
	["4-5"  ] =  12264, -- 샤즈라 · Shazzrah
	["4-6"  ] =  12098, -- 설퍼론 선구자 · Sulfuron Harbinger
	["4-7"  ] =  12056, -- 남작 게돈 · Baron Geddon
	["4-8"  ] =  11988, -- 초열의 골레마그 · Golemagg the Incinerator
	["4-9"  ] =  12018, -- 청지기 이그젝큐투스 · Majordomo Executus
	["4-10" ] =  11502, -- 라그나로스 · Ragnaros
	["4-11" ] =  10184, -- 오닉시아 · Onyxia
	["4-12" ] =  13020, -- 타락한 밸라스트라즈 · Vaelastrasz the Corrupt
	["4-13" ] =  12435, -- 폭군 서슬송곳니 · Razorgore the Untamed
	["4-14" ] =  12017, -- 용기대장 래쉬레이어 · Broodlord Lashlayer
	["4-15" ] =  14020, -- 크로마구스 · Chromaggus
	["4-16" ] =  11583, -- 네파리안 · Nefarian
	["4-17" ] =  15263, -- 예언자 스케람 · The Prophet Skeram
	["4-18" ] =  15509, -- 공주 후후란 · Princess Huhuran
	["4-19" ] =  15275, -- 제왕 베크닐라쉬 · Emperor Vek'nilash
	["4-20" ] =  15727, -- 크툰 · C'Thun
	["4-21" ] =  15953, -- 귀부인 팰리나 · Grand Widow Faerlina
	["4-22" ] =  15956, -- 아눕레칸 · Anub'Rekhan
	["4-23" ] =  15989, -- 사피론 · Sapphiron
	["4-24" ] =  16061, -- 훈련교관 라주비어스 · Instructor Razuvious
	["4-25" ] =  16028, -- 패치워크 · Patchwerk
	["4-26" ] =  15952, -- 맥스나 · Maexxna
	["4-27" ] =  16060, -- 영혼 착취자 고딕 · Gothik the Harvester
	["4-28" ] =  15928, -- 타디우스 · Thaddius
	["4-29" ] =  16062, -- 대영주 모그레인 · Highlord Mograine
	["4-30" ] =  15990, -- 켈투자드 · Kel'Thuzad
}

-- summons (skills that call a creature): engineering models; the healing
-- turret is the field repair robot
ns.MODEL.summon = {
	drone_heal     =   9657, -- Lil' Smoky (꼬마 폴폴이)
	felguard       =  17252, -- Felguard
	hunters_pet    =     69, -- Diseased Timber Wolf
	infernal       =     89, -- Infernal
	turret_gun     =   6233, -- Mechanized Sentry (기계화 보초병)
	turret_heal    =  14337, -- Field Repair Bot 74A (야전수리로봇 74A)
	turret_rocket  =   6233, -- Mechanized Sentry
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

-- tinker: the mech the 기갑 tank fights in (Alliance: picked in game)
ns.MODEL.tinker = {
	mech_alliance  =   7800, -- Mekgineer Thermaplugg
	mech_horde     =    642, -- Sneed's Shredder
	mech_alt       =   6225, -- Mechano-Tank
}

-- druid forms
ns.MODEL.form = {
	bear           =   1186, -- Black Bear
	cat            =   7431, -- Frostsaber
	moonkin        =  10157, -- Moonkin Oracle
	tree           =   1964, -- Treant
}

-- The 기갑 tinker in battle: Alliance in Mimiron's Leviathan Mk II (Ulduar;
-- Mekgineer Thermaplugg behind it), Horde in Sneed's Shredder
ns.MODEL.mech = { ALLIANCE = { 33432, 7800 }, HORDE = { 642 } }

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
	TINKER_MECH     = { ALLIANCE = { npc = 7937, sex = "M", name = "땜장이왕 멕카토크" }, HORDE = { npc = 3391, sex = "M", name = "가즈로" } },
	TINKER_TURRET   = { ALLIANCE = { npc = 7937, sex = "M", name = "땜장이왕 멕카토크" }, HORDE = { npc = 3391, sex = "M", name = "가즈로" } },
	TINKER_MEDIC    = { ALLIANCE = { npc = 7937, sex = "M", name = "땜장이왕 멕카토크" }, HORDE = { npc = 3391, sex = "M", name = "가즈로" } },
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
	TINKER  = { ALLIANCE = { npc =   7937, sex = "M" }, HORDE = { npc =  14742, sex = "M" } },
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
-- the game's race ids (SetCustomRace)
ns.MODEL.raceId = { HUMAN = 1, ORC = 2, DWARF = 3, NIGHTELF = 4, UNDEAD = 5, TAUREN = 6, GNOME = 7, TROLL = 8, GOBLIN = 9 }

-- Other models to look at (/bwi model, 다른 후보)
ns.MODEL.candidates = {
	{ npc = 33651, name = "VX-001" },  -- VX-001 (Mimiron)
	{ npc = 33670, name = "공중 지휘기" },  -- Aerial Command Unit (Mimiron)
	{ npc = 34147, name = "화재경보로봇" },  -- Emergency Fire Bot
	{ npc = 24780, name = "야전수리로봇 110G" },  -- Field Repair Bot 110G
	{ npc = 6225, name = "기계보행전차" },   -- Mechano-Tank
}

-- The model each NPC above is drawn with (its creature display id), in the
-- classic-era game data: the vanilla, then Burning Crusade, then Wrath of the
-- Lich King version (CMaNGOS databases; the famous NPCs in their latest of
-- those), and for the few NPCs from later only, the retail one (TrinityCore).
-- A model put up by its display id comes straight from the game's data,
-- without asking the server about the NPC.
ns.MODEL.display = {
	[69] = 604, [89] = 169, [198] = 5001, [205] = 736, [332] = 1736, [416] = 4449,
	[598] = 308, [622] = 7109, [634] = 2316, [636] = 2314, [639] = 2029, [641] = 7111,
	[642] = 1269, [644] = 14403, [647] = 7113, [657] = 2347, [906] = 3271, [912] = 3399,
	[988] = 4567, [1186] = 707, [1284] = 5072, [1666] = 825, [1706] = 2148, [1707] = 2144,
	[1708] = 2146, [1711] = 2145, [1715] = 2147, [1716] = 1621, [1729] = 2318, [1732] = 2349,
	[1747] = 31201, [1748] = 5566, [1853] = 11070, [1964] = 864, [2496] = 7167, [2529] = 1098,
	[2671] = 7937, [2748] = 5988, [2784] = 3597, [3031] = 2102, [3033] = 2106, [3046] = 2137,
	[3057] = 4307, [3353] = 1374, [3391] = 7052, [3406] = 4239, [3601] = 1703, [3631] = 4091,
	[3636] = 1747, [3641] = 1752, [3654] = 4088, [3655] = 7221, [3670] = 4214, [3671] = 4313,
	[3679] = 4216, [3840] = 4211, [3853] = 729, [3855] = 657, [3859] = 736, [3861] = 801,
	[3862] = 11421, [3866] = 8808, [3875] = 3229, [3887] = 3222, [3914] = 524, [3927] = 11179,
	[3936] = 2035, [3975] = 2041, [3976] = 2042, [3977] = 2043, [4217] = 2261, [4275] = 2353,
	[4287] = 2463, [4288] = 2497, [4289] = 2509, [4295] = 2514, [4297] = 2503, [4298] = 2462,
	[4299] = 2501, [4301] = 2499, [4302] = 2460, [4303] = 2492, [4417] = 2440, [4418] = 2447,
	[4421] = 4642, [4428] = 4644, [4442] = 6103, [4515] = 6093, [4520] = 4647, [4532] = 6105,
	[4538] = 1955, [4540] = 2603, [4583] = 2639, [4802] = 4983, [4805] = 4982, [4807] = 4762,
	[4809] = 2882, [4810] = 2898, [4814] = 2890, [4815] = 2835, [4822] = 1001, [4824] = 1244,
	[4825] = 5026, [4829] = 2837, [4831] = 4979, [4832] = 4939, [4844] = 6051, [4845] = 6053,
	[4852] = 160, [4853] = 1194, [4854] = 11165, [4855] = 11166, [4857] = 10805, [4861] = 1954,
	[4863] = 4486, [4887] = 5027, [4949] = 4527, [4968] = 30863, [4978] = 110, [5053] = 2996,
	[5243] = 4779, [5256] = 7709, [5259] = 6670, [5267] = 4771, [5270] = 4778, [5277] = 7903,
	[5280] = 7863, [5646] = 6411, [5649] = 6423, [5709] = 7806, [5710] = 6708, [5755] = 4312,
	[5769] = 4519, [6132] = 1343, [6206] = 830, [6212] = 3456, [6220] = 4907, [6222] = 6932,
	[6223] = 6982, [6224] = 6936, [6225] = 5926, [6227] = 6891, [6232] = 6889, [6233] = 6978,
	[6235] = 6915, [6329] = 976, [6487] = 5266, [6575] = 2467, [6768] = 6572, [6906] = 5710,
	[6910] = 5945, [7011] = 6010, [7012] = 6009, [7022] = 2488, [7023] = 5285, [7076] = 6026,
	[7077] = 6025, [7079] = 5497, [7091] = 5991, [7175] = 763, [7228] = 6089, [7246] = 6425,
	[7247] = 6427, [7267] = 6439, [7268] = 4305, [7269] = 7470, [7271] = 6434, [7273] = 7271,
	[7274] = 6440, [7276] = 6436, [7286] = 6417, [7290] = 6057, [7291] = 6059, [7309] = 6025,
	[7327] = 11386, [7328] = 11384, [7333] = 6121, [7337] = 11381, [7341] = 9783, [7342] = 1245,
	[7344] = 5231, [7345] = 7847, [7347] = 1065, [7349] = 6842, [7355] = 7845, [7357] = 8055,
	[7358] = 7971, [7361] = 6533, [7382] = 5554, [7431] = 9953, [7544] = 6290, [7789] = 6682,
	[7796] = 6690, [7800] = 6980, [7915] = 6977, [7937] = 31658, [8095] = 7345, [8120] = 7345,
	[8127] = 7353, [8138] = 1075, [8140] = 7356, [8319] = 621, [8376] = 7920, [8497] = 7974,
	[8580] = 7873, [8876] = 6411, [8877] = 6423, [8890] = 8758, [8891] = 8750, [8893] = 8757,
	[8895] = 8753, [8898] = 8751, [8899] = 8820, [8900] = 8812, [8904] = 8825, [8906] = 8177,
	[8907] = 8178, [8909] = 2172, [8910] = 1070, [8911] = 5488, [8913] = 8772, [8914] = 9346,
	[8921] = 8180, [8922] = 8181, [8982] = 9189, [8983] = 8759, [9016] = 12162, [9017] = 1204,
	[9019] = 8807, [9033] = 8756, [9096] = 2554, [9156] = 8329, [9178] = 4607, [9196] = 11565,
	[9197] = 11543, [9199] = 11577, [9200] = 11581, [9201] = 11562, [9236] = 9732, [9259] = 9664,
	[9262] = 9648, [9263] = 9652, [9264] = 9656, [9267] = 9674, [9268] = 7803, [9398] = 8706,
	[9568] = 8711, [9583] = 9633, [9657] = 8910, [9693] = 9625, [9696] = 9562, [9717] = 9613,
	[9816] = 2172, [9817] = 9670, [9818] = 9849, [9819] = 9686, [9938] = 12162, [9956] = 9309,
	[10083] = 8249, [10120] = 5989, [10157] = 12236, [10181] = 28213, [10184] = 8570, [10317] = 9734,
	[10318] = 9691, [10319] = 9696, [10363] = 10115, [10366] = 9753, [10372] = 8309, [10374] = 9755,
	[10375] = 9756, [10391] = 9784, [10394] = 775, [10398] = 10631, [10414] = 1693, [10417] = 12819,
	[10420] = 10496, [10421] = 10500, [10424] = 10512, [10429] = 9778, [10430] = 10193, [10436] = 10698,
	[10440] = 10729, [10442] = 10095, [10464] = 8782, [10475] = 11161, [10477] = 11163, [10481] = 10975,
	[10488] = 12074, [10489] = 7848, [10503] = 11073, [10508] = 7919, [10584] = 11583, [10596] = 9929,
	[10742] = 10176, [10762] = 10172, [10813] = 10691, [10814] = 10116, [11043] = 10463, [11257] = 11161,
	[11262] = 397, [11318] = 11609, [11319] = 11610, [11320] = 11010, [11321] = 2075, [11322] = 11434,
	[11323] = 11430, [11324] = 11438, [11338] = 11229, [11339] = 11225, [11340] = 11221, [11346] = 11158,
	[11351] = 11109, [11352] = 14832, [11355] = 11167, [11356] = 11100, [11357] = 15275, [11382] = 11288,
	[11439] = 11073, [11441] = 12473, [11444] = 11537, [11451] = 11345, [11452] = 2021, [11454] = 10032,
	[11464] = 9592, [11465] = 6350, [11466] = 11207, [11473] = 14366, [11476] = 11078, [11480] = 14253,
	[11490] = 11335, [11492] = 14416, [11496] = 14173, [11501] = 11583, [11502] = 11121, [11517] = 11611,
	[11518] = 11429, [11520] = 7970, [11582] = 11163, [11583] = 11380, [11598] = 775, [11658] = 8269,
	[11659] = 12162, [11661] = 12030, [11662] = 12030, [11663] = 13029, [11664] = 12002, [11665] = 12164,
	[11666] = 1070, [11667] = 5488, [11668] = 12231, [11671] = 12168, [11672] = 11997, [11783] = 12310,
	[11784] = 11712, [11790] = 11345, [11791] = 11338, [11792] = 2021, [11793] = 11714, [11830] = 11758,
	[11831] = 11762, [11832] = 11906, [11946] = 11894, [11982] = 10193, [11988] = 11986, [12017] = 14308,
	[12018] = 12029, [12056] = 12129, [12057] = 12110, [12098] = 13030, [12118] = 13031, [12119] = 12030,
	[12129] = 8711, [12143] = 5488, [12201] = 12292, [12203] = 12293, [12206] = 12309, [12216] = 2452,
	[12219] = 12347, [12222] = 14350, [12225] = 12350, [12236] = 12334, [12259] = 13030, [12260] = 6369,
	[12264] = 13032, [12265] = 2172, [12416] = 12024, [12420] = 11979, [12422] = 2554, [12435] = 10115,
	[12457] = 7923, [12458] = 11967, [12459] = 14292, [12460] = 14308, [12463] = 8310, [12464] = 12893,
	[12465] = 12894, [12467] = 14544, [12468] = 12892, [13020] = 13992, [13021] = 12929, [13036] = 12966,
	[13141] = 2079, [13282] = 11172, [13323] = 13209, [13696] = 13749, [13996] = 13991, [14020] = 14367,
	[14302] = 14352, [14337] = 14379, [14456] = 12024, [14507] = 15217, [14509] = 15216, [14510] = 15220,
	[14517] = 15219, [14532] = 14950, [14742] = 14775, [14750] = 15303, [14821] = 2571, [14834] = 15295,
	[15041] = 15136, [15101] = 613, [15229] = 15434, [15230] = 15334, [15235] = 15338, [15236] = 15335,
	[15240] = 15533, [15246] = 15740, [15252] = 15340, [15262] = 15346, [15263] = 15345, [15275] = 15761,
	[15277] = 15351, [15300] = 15362, [15311] = 15351, [15312] = 15346, [15320] = 15439, [15324] = 15741,
	[15325] = 11142, [15327] = 9229, [15333] = 13509, [15335] = 15463, [15336] = 15336, [15338] = 15343,
	[15339] = 15432, [15341] = 15376, [15343] = 15465, [15348] = 15742, [15355] = 15347, [15362] = 15399,
	[15370] = 15654, [15382] = 15421, [15387] = 15437, [15462] = 15464, [15509] = 15739, [15521] = 11095,
	[15725] = 15789, [15726] = 15788, [15727] = 15787, [15928] = 16137, [15952] = 15928, [15953] = 15940,
	[15956] = 15931, [15974] = 15937, [15975] = 15938, [15976] = 15939, [15978] = 15941, [15979] = 15942,
	[15980] = 16594, [15989] = 16033, [15990] = 15945, [16017] = 9760, [16018] = 15958, [16020] = 16063,
	[16021] = 16175, [16025] = 15961, [16028] = 16174, [16029] = 15962, [16034] = 9013, [16042] = 14308,
	[16060] = 16279, [16061] = 16582, [16062] = 16139, [16124] = 16608, [16128] = 16024, [16145] = 16513,
	[16146] = 16508, [16163] = 10729, [16164] = 14703, [16165] = 11396, [16215] = 15294, [16244] = 10627,
	[16368] = 16160, [16419] = 14368, [16429] = 16178, [16446] = 14710, [16451] = 10729, [16453] = 15939,
	[16573] = 14698, [16646] = 16787, [16800] = 19706, [16801] = 19707, [16998] = 16622, [17008] = 16642,
	[17055] = 13111, [17076] = 16820, [17123] = 16867, [17204] = 17600, [17219] = 16914, [17252] = 14255,
	[17468] = 17822, [17510] = 17249, [17717] = 17199, [18076] = 17470, [18166] = 18921, [19622] = 20023,
	[21984] = 20918, [24780] = 15200, [25237] = 23006, [25256] = 23033, [26528] = 23889, [27986] = 24969,
	[28179] = 22209, [29604] = 26364, [29607] = 26365, [29611] = 28127, [30115] = 28222, [30116] = 26770,
	[33432] = 28831, [33651] = 28841, [33670] = 28979, [34147] = 6888, [35458] = 29814, [36948] = 30508,
}
