-- 3D models for the battle: the NPC (creature) id whose model stands in for
-- each monster, boss, summon and companion, shown with PlayerModel:SetCreature.
-- Every id was checked against wowhead's name for it (the English name in
-- the comment); where the game has no such creature the closest look is used.
local _, ns = ...

ns.MODEL = {}

-- monsters (Data/Monsters.lua ids)
ns.MODEL.mob = {
	abomination            =  10414, -- 누더기골렘 · Patchwork Horror
	acolyte                =  58757, -- 스컬지 수행사제 · Scholomance Acolyte
	ahnkahet_cultist       =  30114, -- 황혼의 수습생 · Twilight Initiate
	amani_axe              =  23542, -- 아마니 도끼 투척꾼 · Amani'shi Axe Thrower
	amani_lynx             =  24043, -- 아마니 스라소니 · Amani Lynx
	amber_shaper           = 157757, -- 호박석 조율사 · Vil'thik Amber-Shaper
	antoran_hound          =   6010, -- 안토란 지옥사냥개 · Felhound
	anubisath              =  15355, -- 아누비사스 수호자 · Anubisath Guardian
	arakkoa                =  18328, -- 아라코아 현자 · Sethekk Oracle
	ashtongue              =  22844, -- 재의 혓바닥 전사 · Ashtongue Battlelord
	azure_invader          =  30961, -- 푸른용군단 침략자 · Azure Invader
	azure_mage             =  27635, -- 푸른용군단 마법사 · Azure Spellbinder
	banshee                =  10464, -- 밴시 · Wailing Banshee
	basilisk               =   5990, -- 바실리스크 · Redstone Basilisk
	blackhand              =  10317, -- 검은손 정예병 · Blackhand Elite
	boar                   =   3100, -- 멧돼지 · Elder Mottled Boar
	bog_lord               =  18127, -- 늪지 군주 · Bog Lord
	bone_construct         =  14605, -- 뼈 구조물 · Bone Construct
	boulderfist            =  17134, -- 돌주먹 오우거 · Boulderfist Crusher
	cabal_cultist          =  18631, -- 비밀결사단 이교도 · Cabal Cultist
	centaur                =   3275, -- 켄타우로스 약탈자 · Kolkar Marauder
	clefthoof              =  18205, -- 갈래발굽 · Clefthoof
	core_hound             =  11671, -- 심장부 사냥개 · Core Hound
	corruption_tentacle    =  56471, -- 타락의 촉수 · Mutated Corruption
	croc                   =   1693, -- 악어 · Loch Crocolisk
	crusader               =   4294, -- 붉은십자군 광신도 · Scarlet Sorcerer
	crypt_fiend            =  25227, -- 지하마귀 · Crypt Crawler
	crystalline            =  26782, -- 수정 수호자 · Crystalline Keeper
	cult_adherent          =  37949, -- 교단 신봉자 · Cult Adherent
	cultist                =  15213, -- 황혼의 망치단 이교도 · Twilight Overlord
	dark_shaman            =  71859, -- 코르크론 암흑주술사 · Earthbreaker Haromm
	darkiron               =   6523, -- 검은무쇠 소총병 · Dark Iron Rifleman
	darkiron_guard         =   8893, -- 검은무쇠 병사 · Anvilrage Soldier
	death_knight           =  16125, -- 죽음의 기사 · Unrelenting Death Knight
	deep_naga              =  40633, -- 심해 나가 집행자 · Naz'jar Honor Guard
	deep_seer              =  40634, -- 심해 바다마녀 · Naz'jar Tempest Witch
	defias                 =     38, -- 데피아즈단 악당 · Two-Bit Thug
	defias_mage            =    619, -- 데피아즈단 마법사 · Defias Conjurer
	deviate_raptor         =   3636, -- 변종 랩터 · Deviate Ravager
	devilsaur              =   6498, -- 데빌사우루스 · Devilsaur
	doomguard              =  11859, -- 파멸의 수호병 · Doomguard
	dragonkin              =   7040, -- 용혈족 · Black Dragonspawn
	drake                  =  34897, -- 검은용 · Black Drake
	drakkari               =  29829, -- 드라카리 광전사 · Drakkari Earthshaker
	drakkari_shaman        =  26639, -- 드라카리 주술사 · Drakkari Shaman
	drogbar                =  96124, -- 드로그바 전사 · Drogbar Rivertroller
	ember_lord             =   5852, -- 잿불 군주 · Inferno Elemental
	eredar                 = 109431, -- 에레다르 흑마법사 · Eredar Warlock
	ethereal               =  18309, -- 에테리얼 약탈자 · Ethereal Scavenger
	eye_tentacle           =  15726, -- 눈달린 촉수 · Eye Tentacle
	faceless               =  33772, -- 얼굴없는 자 · Faceless Horror
	fel_annihilator        =  18733, -- 군단 파괴병기 · Fel Reaver
	fel_bat                =  92113, -- 지옥박쥐 · Fel Bat
	fel_orc                =  17259, -- 지옥 오크 투사 · Bonechewer Hungerer
	fel_orc_warlock        =  17694, -- 지옥 오크 흑마법사 · Shadowmoon Darkcaster
	fel_sentry             =  21949, -- 지옥절단기 파수병 · Fel Reaver Sentinel
	felguard               =  17252, -- 지옥수호병 · Felguard
	felhound               =   6010, -- 지옥사냥개 · Felhound
	fire_elemental         =   5852, -- 불의 정령 · Inferno Elemental
	fjord_worg             =     69, -- 협만 늑대 · Diseased Timber Wolf
	flamewaker             =  11661, -- 불꽃지기 · Flamewaker
	flesh_giant            =  10414, -- 살점 거인 · Patchwork Horror
	frost_elemental        =  50250, -- 얼음 정령 · Ice Avatar
	frost_whelp            =  93549, -- 서리 새끼용 · Frostclutch Whelp
	frost_wyrm             =  15989, -- 서리고룡 · Sapphiron
	frostsaber             =   7431, -- 서리표범 · Frostsaber
	frostwolf              =  12053, -- 서리늑대 전사 · Frostwolf Guardian
	frozen_wraith          =  16427, -- 얼어붙은 망령 · Soldier of the Frozen Wastes
	furbolg                =   3743, -- 펄볼그 전사 · Foulweald Warrior
	gargoyle               =  16168, -- 가고일 · Stoneskin Gargoyle
	geist                  =  27686, -- 가이스트 · Frigid Geist Attacker
	ghost                  =   6427, -- 유령 · Haunting Phantasm
	ghoul                  =    846, -- 구울 · Rotten Ghoul
	gnoll                  =    117, -- 리버포 놀 · Riverpaw Gnoll
	goblin                 =    622, -- 고블린 기술자 · Goblin Engineer
	golem                  =     36, -- 허수아비 골렘 · Harvest Golem
	grizzly                =   1186, -- 회색 곰 · Black Bear
	gronnling              =  21350, -- 새끼 그론 · Gronn-Priest
	guardian_of_yogg       =  33136, -- 요그사론의 수호자 · Guardian of Yogg-Saron
	harpy                  =   2962, -- 하피 · Windfury Harpy
	helboar                =  16880, -- 지옥멧돼지 · Hulking Helboar
	hellfire_channeler     =  17256, -- 지옥불 역술사 · Hellfire Channeler
	hozen                  =  59562, -- 호젠 싸움꾼 · Hozen Brawler
	hyena                  =   4127, -- 하이에나 · Hecklefang Hyena
	ice_troll              =   1123, -- 얼음 트롤 광전사 · Frostmane Headhunter
	illidari               =  22093, -- 일리다리 칼날추적자 · Illidari Watcher
	imp                    =    416, -- 임프 · Imp
	infernal               =     89, -- 지옥불정령 · Infernal
	infinite_slayer        =  18170, -- 무한의 용혈족 · Infinite Slayer
	infinite_whelp         =  21818, -- 무한의 새끼용 · Infinite Whelp
	iron_dwarf             =  29978, -- 무쇠 드워프 · Iron Dwarf Assailant
	iron_golem             =  27985, -- 무쇠 골렘 · Iron Golem Custodian
	jinyu                  =  64659, -- 진위 물예언자 · Jinyu Waterspeaker
	kobold                 =    257, -- 코볼트 일꾼 · Kobold Worker
	korkron                =  35460, -- 코르크론 정예병 · Kor'kron Elite
	korkron_warbringer     =  71979, -- 코르크론 전쟁인도자 · Kor'kron Warbringer
	lava_elemental         =  12265, -- 용암 정령 · Lava Spawn
	lightning_ele          =  28858, -- 번개 정령 · Storm Revenant
	mage_hunter            =  26727, -- 마법사 사냥꾼 · Mage Hunter Ascendant
	magnataur              =  24469, -- 마그나타우르 · Magnataur Huntress
	mammoth                =  24614, -- 털북숭이 매머드 · Wooly Mammoth
	mana_wyrm              =  15274, -- 마나 지룡 · Mana Wyrm
	mantid                 =  62543, -- 사마귀 칼날군주 · Blade Lord Ta'yak
	marsh_crab             =   1216, -- 습지 게 · Shore Crawler
	mechanar_drone         =  19713, -- 메카나르 파괴병 · Mechanar Wrecker
	mogu                   =  61250, -- 모구 전사 · Sorcerer Mogu
	mogu_sorcerer          =  61250, -- 모구 마법사 · Sorcerer Mogu
	molten_giant           =  11658, -- 용암 거인 · Molten Giant
	murloc                 =    515, -- 멀록 약탈자 · Murloc Raider
	mutate_lasher          =  19598, -- 돌연변이 덩굴손 · Mutate Fleshlasher
	naga_myrmidon          =  17800, -- 나가 미르미돈 · Coilfang Myrmidon
	naga_siren             =  17801, -- 나가 세이렌 · Coilfang Siren
	necromancer            =  10477, -- 강령술사 · Scholomance Necromancer
	neferset               =  47753, -- 네페르셋 전사 · Dark Pharaoh Tekahn
	nerubian               =  28732, -- 네루비안 거미전사 · Anub'ar Warrior
	nether_drake           =  18877, -- 황천의 비룡 · Nether Drake
	nexus_lord             =  30245, -- 마력의 군주 · Nexus Lord
	nightborne_guard       = 104247, -- 황혼수호병 · Duskwatch Arcanist
	nightborne_mage        = 104247, -- 나이트본 마법학자 · Duskwatch Arcanist
	nightmare_stalker      =  37736, -- 악몽의 추적자 · Nightmare Stalker
	nightmare_treant       = 105468, -- 악몽의 나무정령 · Nightmare Ancient
	ogre                   =   2701, -- 오우거 · Dustbelcher Ogre
	ooze                   =   6559, -- 수액괴물 · Glutinous Ooze
	orc                    =    440, -- 검은바위 오크 · Blackrock Grunt
	phantom_guest          =  16409, -- 유령 손님 · Phantom Guest
	phoenix                =  21362, -- 불사조 · Phoenix
	pirate                 =   7855, -- 남쪽바다 해적 · Southsea Pirate
	plaguebat              =   8600, -- 역병박쥐 · Plaguebat
	proto_drake            =  23689, -- 원시비룡 · Proto-Drake
	qiraji                 =  15324, -- 퀴라지 검투사 · Qiraji Gladiator
	quilboar               =   3265, -- 가시멧돼지 사냥꾼 · Razormane Hunter
	raging_spirit          =  36701, -- 격노한 영혼 · Raging Spirit
	raptor                 =    685, -- 랩터 · Stranglethorn Raptor
	ravager                =  17199, -- 갈퀴발톱 · Ravager Specimen
	reorigination_module   = 127809, -- 재창조 모듈 · Reorigination Module
	rhino                  =  25489, -- 북녘 코뿔소 · Wooly Rhino Bull
	sand_djinn             =  45269, -- 모래 진 · Servant of Siamat
	sand_troll             = 121017, -- 모래 트롤 · Sandfury Axe Thrower
	sandworm               =  15517, -- 모래벌레 · Ouro
	satyr                  =   4671, -- 사티로스 · Hatefury Trickster
	saurok                 =  58215, -- 사우록 · Wildscale Saurok
	scorpid                =   3124, -- 전갈 · Scorpid Worker
	scourge_champion       =   8529, -- 스컬지 용사 · Scourge Champion
	scourge_troll          =  26635, -- 되살아난 드라카리 · Risen Drakkari Warrior
	serpent                =   5048, -- 변종 독사 · Deviate Adder
	sethekk                =  18323, -- 세데크 수호병 · Sethekk Guard
	sha                    =  58201, -- 샤의 화신 · Sha Manifestation
	shadowsword            =  25484, -- 어둠칼날 암살자 · Shadowsword Assassin
	shattered_hand         =  17465, -- 으스러진 손 백부장 · Shattered Hand Centurion
	shield_orb             =  25502, -- 보호의 수정구 · Shield Orb
	silithid               =  15324, -- 실리시드 일꾼 · Qiraji Gladiator
	skeleton               =     48, -- 해골 전사 · Skeletal Warrior
	skeleton_mage          =   1784, -- 해골 마법사 · Skeletal Sorcerer
	son_of_flame           =  12143, -- 화염의 피조물 · Son of Flame
	spectral_steed         =  15548, -- 망령 군마 · Spectral Stallion
	spider                 =    217, -- 독거미 · Venom Web Spider
	sporebat               =  18129, -- 포자박쥐 · Greater Sporebat
	steam_surger           =  21696, -- 증기 정령 · Steam Surger
	stone_drake            =  34897, -- 돌용 · Black Drake
	stone_giant            =  44080, -- 심원의 바위거인 · Boden the Imposing
	storm_drake            =  94710, -- 폭풍 비룡 · Storm Drake Hunter
	storm_giant            =  29375, -- 폭풍 거인 · Stormforged Iron Giant
	sunblade_knight        =  24684, -- 태양칼날 혈기사 · Sunblade Blood Knight
	sunblade_mage          =  25367, -- 태양칼날 대마법사 · Sunblade Arch Mage
	sunfury_guard          =  18850, -- 태양격노 수호병 · Sunfury Guardsman
	sunfury_mage           =  18855, -- 태양격노 마법학자 · Sunfury Magister
	talbuk                 =  17130, -- 탈부크 · Talbuk Stag
	technician             =  13996, -- 검은날개 기술병 · Blackwing Technician
	thunder_lizard         =   4726, -- 천둥도마뱀 · Raging Thunder Lizard
	tiger                  =    682, -- 호랑이 · Stranglethorn Tiger
	troll                  =    587, -- 정글 트롤 · Bloodscalp Warrior
	twilight_drake         =  34897, -- 황혼의 비룡 · Black Drake
	twilight_shaper        =  39708, -- 황혼의 원소술사 · Twilight Flame Caller
	twilight_zealot        =  15213, -- 황혼의 광신도 · Twilight Overlord
	valarjar               =  23961, -- 발라리아르 용사 · Dragonflayer Ironhelm
	valkyr                 =  36609, -- 발키르 그림자수호병 · Val'kyr Shadowguard
	virmen                 =  56184, -- 버민 · Snagtooth Virmen
	voidwalker             =   1860, -- 공허방랑자 · Voidwalker
	vrykul                 =  23961, -- 브리쿨 전사 · Dragonflayer Ironhelm
	vrykul_seer            =  23960, -- 브리쿨 예언자 · Dragonflayer Runecaster
	warp_stalker           =  18464, -- 차원 추적자 · Warp Stalker
	whelp                  =   7047, -- 검은 새끼용 · Black Broodling
	withered               = 104247, -- 마력에 굶주린 자 · Duskwatch Arcanist
	wolf                   =     69, -- 숲늑대 · Diseased Timber Wolf
	wolvar                 =  28079, -- 울바르 사냥꾼 · Frenzyheart Hunter
	worgen                 =    533, -- 밤그림자 늑대인간 · Nightbane Shadow Weaver
	wrathguard             =  18975, -- 격노수호병 · Wrathguard
	yaungol                =  63318, -- 야운골 전사 · Chagan Firehoof
	yeti                   =   7458, -- 예티 · Ice Thistle Yeti
	ymirjar                =  37132, -- 이미야르 전투마녀 · Ymirjar Battle-Maiden
}

-- stage bosses by "difficulty-stage"
ns.MODEL.boss = {
	["1-1"] =    448, -- 들창코 · Hogger
	["1-2"] =    115, -- 미치광이 수확기 · Harvest Reaper
	["1-3"] =    639, -- 에드윈 밴클리프 · Edwin VanCleef
	["1-4"] =    334, -- 검은바위 대장 · Gath'Ilzogg
	["1-5"] =    412, -- 스티치스 · Stitches
	["1-6"] =    731, -- 왕 방갈라쉬 · King Bangalash
	["1-7"] =   1693, -- 늪지대의 거대 악어 · Loch Crocolisk
	["1-8"] =  10826, -- 역병의 군주 · Lord Darkscythe
	["1-9"] =   9019, -- 제왕 다그란 타우릿산 · Emperor Dagran Thaurissan
	["1-10"] =  11502, -- 라그나로스 · Ragnaros
	["1-11"] =   4421, -- 가시멧돼지 족장 · Charlga Razorflank
	["1-12"] =   3275, -- 켄타우로스 칸 · Kolkar Marauder
	["1-13"] =   3654, -- 걸신들린 무타누스 · Mutanus the Devourer
	["1-14"] = 105468, -- 타락한 고대정령 · Nightmare Ancient
	["1-15"] =  99593, -- 하피 여군주 · Cliffclutch Matriarch
	["1-16"] =    647, -- 남쪽바다 선장 · Captain Greenskin
	["1-17"] =   6500, -- 폭군 데빌사우루스 · Tyrant Devilsaur
	["1-18"] =  10041, -- 둥지의 여왕 · Gorishi Hive Queen
	["1-19"] =  15339, -- 무적의 오시리안 · Ossirian the Unscarred
	["1-20"] =  15727, -- 크툰 · C'Thun
	["1-21"] =   7458, -- 설인 왕 · Ice Thistle Yeti
	["1-22"] =  25740, -- 서리 군주 · Ahune
	["1-23"] =  10439, -- 누더기 감독관 · Ramstein the Gorger
	["1-24"] =   1853, -- 암흑스승 간들링 · Darkmaster Gandling
	["1-25"] =  10440, -- 남작 리븐데어 · Baron Rivendare
	["1-26"] =  12397, -- 군주 카자크 · Lord Kazzak
	["1-27"] =  10363, -- 사령관 드라키사스 · General Drakkisath
	["1-28"] =  11583, -- 네파리안 · Nefarian
	["1-29"] =  16028, -- 패치워크 · Patchwerk
	["1-30"] =  15990, -- 켈투자드 · Kel'Thuzad
	["2-1"] =  18733, -- 지옥절단기 · Fel Reaver
	["2-2"] =  17306, -- 감시자 가르골마르 · Watchkeeper Gargolmar
	["2-3"] =  17377, -- 파괴자 켈리단 · Keli'dan the Breaker
	["2-4"] =  16808, -- 대족장 카르가스 · Warchief Kargath Bladefist
	["2-5"] =  17770, -- 헝가르펜 · Hungarfen
	["2-6"] =  17942, -- 쿠아그미란 · Quagmirran
	["2-7"] =  17798, -- 장군 칼리스레쉬 · Warlord Kalithresh
	["2-8"] =  21838, -- 테로크 · Terokk
	["2-9"] =  18473, -- 갈퀴대왕 이키스 · Talon King Ikiss
	["2-10"] =  21174, -- 마그테리돈 · Magtheridon
	["2-11"] =  18411, -- 굶주린 듀른 · Durn the Hungerer
	["2-12"] =  18831, -- 왕 마울가르 · High King Maulgar
	["2-13"] =  19044, -- 용 학살자 그룰 · Gruul the Dragonkiller
	["2-14"] =  18344, -- 연합왕자 샤파르 · Nexus-Prince Shaffar
	["2-15"] =  19220, -- 계산기 파탈리온 · Pathaleon the Calculator
	["2-16"] =  20870, -- 차원의 분리자 · Zereketh the Unbound
	["2-17"] =  20912, -- 선구자 스키리스 · Harbinger Skyriss
	["2-18"] =  15690, -- 말체자르 왕자 · Prince Malchezaar
	["2-19"] =  21212, -- 여군주 바쉬 · Lady Vashj
	["2-20"] =  19622, -- 캘타스 선스트라이더 · Kael'thas Sunstrider
	["2-21"] =  17711, -- 파멸의 절단기 · Doomwalker
	["2-22"] =  17880, -- 울림 · Temporus
	["2-23"] =  18096, -- 시대의 사냥꾼 · Epoch Hunter
	["2-24"] =  17881, -- 아에누스 · Aeonus
	["2-25"] =  17968, -- 아키몬드 · Archimonde
	["2-26"] =  23863, -- 줄진 · Daakara
	["2-27"] =  22917, -- 일리단 스톰레이지 · Illidan Stormrage
	["2-28"] =  24560, -- 여사제 델리사 · Priestess Delrissa
	["2-29"] =  24882, -- 브루탈루스 · Brutallus
	["2-30"] =  25315, -- 킬제덴 · Kil'jaeden
	["3-1"] =  26530, -- 스컬지 군주 살라므 · Salramm the Fleshcrafter
	["3-2"] =  26723, -- 케리스트라자 · Keristrasza
	["3-3"] =  28079, -- 서리송곳니 족장 · Frenzyheart Hunter
	["3-4"] =  23954, -- 약탈자 잉그바르 · Ingvar the Plunderer
	["3-5"] =  26861, -- 왕 이미론 · King Ymiron
	["3-6"] =  24469, -- 마그나타우르 대군주 · Magnataur Huntress
	["3-7"] =  29120, -- 아눕아락 · Anub'arak
	["3-8"] =  29311, -- 전령 볼라즈 · Herald Volazj
	["3-9"] =  28860, -- 살타리온 · Sartharion
	["3-10"] =  28859, -- 말리고스 · Malygos
	["3-11"] = 100497, -- 타락한 우르속 · Ursoc
	["3-12"] =  26632, -- 예언자 타론자 · The Prophet Tharon'ja
	["3-13"] =  26423, -- 군주 드라쿠루 · Drakuru
	["3-14"] =  29306, -- 갈다라 · Gal'darah
	["3-15"] =  15101, -- 표범 여왕 샹고 · Zulian Prowler
	["3-16"] =  31134, -- 시아니고사 · Cyanigosa
	["3-17"] =  32865, -- 폭풍군주 토림 · Thorim
	["3-18"] =  28923, -- 로켄 · Loken
	["3-19"] =  27978, -- 무쇠구체자 쇼니르 · Sjonnir The Ironshaper
	["3-20"] =  33288, -- 요그사론 · Yogg-Saron
	["3-21"] =  34127, -- 스컬지 사령관 · Boneguard Commander
	["3-22"] =  35451, -- 흑기사 · The Black Knight
	["3-23"] =  34797, -- 얼음울음 · Icehowl
	["3-24"] =  36502, -- 영혼의 포식자 · Devourer of Souls
	["3-25"] =  36658, -- 스컬지군주 티라누스 · Scourgelord Tyrannus
	["3-26"] =  38112, -- 팔릭 · Falric
	["3-27"] =  36612, -- 군주 매로우가르 · Lord Marrowgar
	["3-28"] =  36678, -- 교수 퓨트리사이드 · Professor Putricide
	["3-29"] =  36853, -- 신드라고사 · Sindragosa
	["3-30"] =  36597, -- 리치 왕 · The Lich King
	["4-1"] =  12056, -- 남작 게돈 · Baron Geddon
	["4-2"] =  44566, -- 오주마트 · Ozumat
	["4-3"] =  40586, -- 여군주 나즈자르 · Lady Naz'jar
	["4-4"] =  42465, -- 바위어머니 테라제인 · Therazane
	["4-5"] =  42333, -- 대여사제 아질 · High Priestess Azil
	["4-6"] =  47753, -- 암흑 파라오 테카안 · Dark Pharaoh Tekahn
	["4-7"] =  44819, -- 시아마트 · Siamat
	["4-8"] =  43324, -- 초갈 · Cho'gall
	["4-9"] =  52571, -- 청지기 스태그헬름 · Majordomo Staghelm
	["4-10"] =  56173, -- 데스윙 · Deathwing
	["4-11"] =  56439, -- 의심의 샤 · Sha of Doubt
	["4-12"] =  56448, -- 현자 마리 · Wise Mari
	["4-13"] =  56717, -- 버민 왕 훕탈루스 · Hoptallus
	["4-14"] =  59479, -- 옌주 · Yan-Zhu the Uncasked
	["4-15"] =  60491, -- 분노의 샤 · Sha of Anger
	["4-16"] =  60399, -- 황제의 의지 · Qin-xi
	["4-17"] =  62511, -- 호박석 조각가 운속 · Amber-Shaper Un'sok
	["4-18"] =  62837, -- 대여제 셰크지르 · Grand Empress Shek'zeer
	["4-19"] =  68397, -- 천둥왕 레이 션 · Lei Shen
	["4-20"] =  71865, -- 가로쉬 헬스크림 · Garrosh Hellscream
	["4-21"] =  96028, -- 아즈샤라의 분노 · Wrath of Azshara
	["4-22"] =  14887, -- 악몽의 용 이세라 · Ysondre
	["4-23"] =  99192, -- 자비우스의 망령 · Shade of Xavius
	["4-24"] =  91007, -- 지하군주 다르그룰 · Dargrul
	["4-25"] =  95675, -- 신왕 스코발드 · God-King Skovald
	["4-26"] = 106643, -- 대마법학자 엘리산드 · Elisande
	["4-27"] =  17008, -- 굴단 · Gul'dan
	["4-28"] = 116939, -- 타락한 화신 · Fallen Avatar
	["4-29"] = 121975, -- 아그라마르 · Aggramar
	["4-30"] = 124828, -- 파멸자 아르거스 · Argus the Unmaker
}

-- summons (skills that call a creature; the turrets and the drone are old
-- engineering models: the newer ones did not load in game)
ns.MODEL.summon = {
	drone_heal     =   9657, -- Lil' Smoky
	felguard       =  17252, -- Felguard
	hunters_pet    =     69, -- Diseased Timber Wolf
	infernal       =     89, -- Infernal
	turret_gun     =   6233, -- Mechanized Sentry
	turret_heal    =   3527, -- Healing Stream Totem
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

-- heroes: a class trainer (or for the tinker an engineer) of the class's race
-- for the faction (Data/Races.lua ns.CLASS_RACE), in the hero's gender
ns.MODEL.hero = {
	WARRIOR = { ALLIANCE = { M = 912, F = 164939 }, HORDE = { M = 3353, F = 3338 } },    -- Thran Khorman, Signilda Hardforge / Grezz Ragefist, Sergra Darkthorn
	PALADIN = { ALLIANCE = { M = 8140, F = 49741 }, HORDE = { M = 50012, F = 17076 } },  -- Brother Karman, Sister Darnhald / Blood Knight Argaron, Lady Liadrin
	HUNTER  = { ALLIANCE = { M = 3601, F = 4146 }, HORDE = { M = 3406, F = 3154 } },     -- Dazalar, Jocaste / Xor'juul, Jen'shan
	ROGUE   = { ALLIANCE = { M = 205, F = 52636 }, HORDE = { M = 4583, F = 4582 } },     -- Nightbane Dark Runner, Tana Lentner / Miles Dexter, Carolyn Ward
	PRIEST  = { ALLIANCE = { M = 17510, F = 20914 }, HORDE = { M = 3046, F = 48614 } },  -- Izmir, Aalun / Father Cobb, Dark Cleric Claressa
	SHAMAN  = { ALLIANCE = { M = 52292, F = 17219 }, HORDE = { M = 3031, F = 3062 } },   -- Droha, Sulaa / Tigor Skychaser, Meela Dawnstrider
	MAGE    = { ALLIANCE = { M = 198, F = 5497 }, HORDE = { M = 16646, F = 50010 } },    -- Khelden Bremen, Jennea Cannon / Alamma, Alaressa
	WARLOCK = { ALLIANCE = { M = 906, F = 459 }, HORDE = { M = 988, F = 3325 } },        -- Maximillian Crowe, Drusilla La Salle / Kartosh, Mirkat
	DRUID   = { ALLIANCE = { M = 4217, F = 4146 }, HORDE = { M = 3033, F = 1409 } },     -- Mathrengyl Bearwalker, Jocaste / Turak Runetotem, Moorah Stormhoof
	TINKER  = { ALLIANCE = { M = 7937, F = 11037 }, HORDE = { M = 14742, F = 192165 } }, -- High Tinker Mekkatorque, Jenna Lemkenilli / Zap Farflinger, Winnie Fingerspring
}
