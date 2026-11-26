-- Spell effects of the original game: per
-- spell the visual kits of its spell visual (precast = while casting, cast =
-- the release, impact = on the target) and the model files of its effects
-- (missile = what flies, hand = the glow in the hands, hit = the impact).
-- Kit ids and effect paths are the 1.12 client's (SpellVisual,
-- SpellVisualKit, SpellVisualEffectName); file ids come from the community
-- listfile (spells/<name>.m2).
-- self = it lands on the caster (a heal); omni = cast all around (anims
-- 52/54) instead of at the target (51/53).
local _, ns = ...

ns.SPELL_FX = {
	{ key = "lightning_bolt", name = "번개 화살", class = "SHAMAN", spell = 403,
		precast = 124, cast = 72, impact = 283, missile = 166497, hand = 166492, hit = 166496 },
	{ key = "fireball", name = "화염구", class = "MAGE", spell = 133,
		precast = 30, cast = 38, impact = 286, missile = 166129, hand = 166120, hit = 166583 },
	{ key = "frostbolt", name = "얼음 화살", class = "MAGE", spell = 116,
		precast = 194, cast = 202, impact = 4991, missile = 166214, hand = 166381, hit = 166370 },
	{ key = "shadow_bolt", name = "어둠의 화살", class = "WARLOCK", spell = 686,
		precast = 114, cast = 118, impact = 219, missile = 165891, hand = 166807, hit = 165890 },
	{ key = "wrath", name = "천벌", class = "DRUID", spell = 5176,
		precast = 3290, cast = 3291, impact = 3292, missile = 167213, hand = 167214, hit = 167212 },
	{ key = "arcane_shot", name = "신비한 사격", class = "HUNTER", spell = 3044,
		impact = 419, missile = 165592, hit = 166525 },
	{ key = "smite", name = "성스러운 일격", class = "PRIEST", spell = 585,
		precast = 184, cast = 119, impact = 291, hand = 166336, hit = 166354 },
	{ key = "heal", name = "치유", class = "PRIEST", spell = 2054, self = true, omni = true,
		precast = 99, cast = 270, impact = 232, hand = 166336, hit = 166292 },
	{ key = "healing_wave", name = "치유의 물결", class = "SHAMAN", spell = 331, self = true, omni = true,
		precast = 100, cast = 183, impact = 101, hand = 166605, hit = 166703 },
}

ns.SPELL_FX_BY = {}
for _, e in ipairs(ns.SPELL_FX) do ns.SPELL_FX_BY[e.key] = e end

-- What every hero skill shows in battle: the classic spell it is (spell id)
-- and that spell's visual - cast = the kit played on the caster, missile =
-- the model flying to each target, hit = the model on each one reached (low =
-- at the feet, a base effect), self = the model on the caster itself
-- (selfLow = at its feet). Kits and files are the 1.12 client's
-- (SpellVisual, SpellVisualKit, SpellVisualEffectName; file ids from the
-- community listfile); traps, totems and poisons show their effect spell.
ns.SKILL_FX = {
	mortal_strike          = { spell = 21553, cast = 324, hit = 166986 }, -- 죽음의 일격 · strike_impact_chest.m2
	cleave                 = { spell = 20569, self = 165796, selfLow = true, hit = 165798 }, -- 회전베기 · cleave_impact_chest.m2
	rend                   = { spell = 11574, cast = 324, hit = 165737 }, -- 분쇄 · bloodyexplosion.m2
	battle_shout           = { spell = 25289, self = 165658, selfLow = true, hit = 165658, low = true }, -- 전투의 외침 · battleshout_cast_base.m2
	execute                = { spell = 20662, cast = 394, hit = 165737 }, -- 마무리 일격 · bloodyexplosion.m2
	sweeping_strikes       = { spell = 12292, cast = 270, hit = 166417, low = true }, -- 휩쓸기 일격 · innerfire_base.m2
	bloodthirst            = { spell = 23894, cast = 324, hit = 165737 }, -- 피의 갈증 · bloodyexplosion.m2
	whirlwind              = { spell = 1680, self = 167199, selfLow = true, hit = 166986 }, -- 소용돌이 · strike_impact_chest.m2
	heroic_strike          = { spell = 25286, cast = 324, hit = 166986 }, -- 영웅의 일격 · strike_impact_chest.m2
	recklessness           = { spell = 1719, cast = 379, hit = 166685 }, -- 무모한 희생 · recklessness_impact_chest.m2
	overpower              = { spell = 11585, cast = 324, hit = 166986 }, -- 제압 · strike_impact_chest.m2
	shield_slam            = { spell = 23925, cast = 468, hit = 166841 }, -- 방패 밀쳐내기 · shieldbash_impact_chest.m2
	thunder_clap           = { spell = 11581, self = 167120, selfLow = true, hit = 166496 }, -- 천둥벼락 · lightningbolt_impact_chest.m2
	revenge                = { spell = 25288, cast = 506, hit = 166986 }, -- 복수 · strike_impact_chest.m2
	defensive_stance       = { spell = 71, self = 165915, hit = 165915 }, -- 방어 태세 · defensivestance_impact_head.m2
	shield_wall            = { spell = 871, hit = 165914, low = true }, -- 방패의 벽 · defensivestance_impact_chest.m2
	last_stand             = { spell = 12976, self = 165725, hit = 165725 }, -- 최후의 저항 · bloodlust_cast_hand.m2
	holy_light             = { spell = 25292, cast = 270, hit = 166349 }, -- 성스러운 빛 · holylight_low_head.m2
	devotion_aura          = { spell = 10293, self = 165948, selfLow = true, hit = 165948, low = true }, -- 기원의 오라 · devotionaura_base.m2
	judgement              = { spell = 20271, cast = 119, hit = 166326 }, -- 심판 · holy_impactdd_low_chest.m2
	blessing_of_might      = { spell = 25291, cast = 189, hit = 166774, low = true }, -- 힘의 축복 · sealofmight_impact_base.m2
	lay_on_hands           = { spell = 10310, cast = 119, hit = 166452 }, -- 신의 축복 · layonhands_low_chest.m2
	divine_protection      = { spell = 5573, cast = 417, hit = 165961, low = true }, -- 신의 가호 · divineshield_low_base.m2
	holy_shield            = { spell = 20928, self = 166324, selfLow = true, hit = 166324, low = true }, -- 신성한 방패 · holy_impactdd_high_base.m2
	exorcism               = { spell = 10314, cast = 119, hit = 166049 }, -- 퇴마술 · exorcism_impact_chest.m2
	consecration           = { spell = 20924, self = 166338, selfLow = true, hit = 166326 }, -- 신성화 · holy_impactdd_low_chest.m2
	blessing_of_sanctuary  = { spell = 20914, cast = 189, hit = 166772, low = true }, -- 성역의 축복 · sealoffury_impact_base.m2
	flash_of_light         = { spell = 19943, cast = 270, hit = 166349 }, -- 빛의 섬광 · holylight_low_head.m2
	seal_of_command        = { spell = 20920, hit = 166417, low = true }, -- 지휘의 문장 · innerfire_base.m2
	holy_wrath             = { spell = 10318, self = 166732, missile = 166332, hit = 166325 }, -- 신의 격노 · holy_impactdd_high_chest.m2
	hammer_of_wrath        = { spell = 24239, self = 166323, missile = 166323, hit = 166329 }, -- 천벌의 망치 · holy_impactdd_uber_chest.m2
	seal_of_the_crusader   = { spell = 20308, hit = 166417, low = true }, -- 성전사의 문장 · innerfire_base.m2
	intimidation           = { spell = 19577, cast = 189, hit = 166774, low = true }, -- 위협 · sealofmight_impact_base.m2
	call_pet               = { spell = 883, cast = 3032 }, -- 야수 부르기
	multi_shot             = { spell = 25294, missile = 166598, hit = 166597 }, -- 일제 사격 · multishot_impact.m2
	aspect_of_the_wild     = { spell = 20190, cast = 2810, hit = 166664 }, -- 야생의 상 · protectionfromnature_chest.m2
	bestial_wrath          = { spell = 19574, cast = 730, hit = 165672 }, -- 야수의 격노 · beastragecaster.m2
	screech                = { spell = 24580, cast = 179, hit = 166457, low = true }, -- 날카로운 울음소리 · learn_impact_base.m2
	aimed_shot             = { spell = 20904, missile = 165592, hit = 166525 }, -- 조준 사격 · magic_impact_chest.m2
	arcane_shot            = { spell = 14287, missile = 165592, hit = 166525 }, -- 신비한 사격 · magic_impact_chest.m2
	trueshot_aura          = { spell = 20906, self = 166658, selfLow = true, hit = 166658, low = true }, -- 정조준 오라 · presenceofmind_cast_base.m2
	rapid_fire             = { spell = 3045, cast = 6383, hit = 166682, low = true }, -- 속사 · rapidfire_base.m2
	volley                 = { spell = 14295, missile = 165596, hit = 166525 }, -- 연발 사격 · magic_impact_chest.m2
	immolation_trap        = { spell = 14305, cast = 61, hit = 166401 }, -- 제물의 덫 · immolate_impact_chest.m2
	serpent_sting          = { spell = 25295, missile = 166648, hit = 165679 }, -- 독사 쐐기 · bestowdisease_impact_chest.m2
	explosive_trap         = { spell = 14317, hit = 166583 }, -- 폭발의 덫 · moltenblast_impact_chest.m2
	freezing_trap          = { spell = 14311, hit = 166388, low = true }, -- 얼음의 덫 · icebarrier_state.m2
	wyvern_sting           = { spell = 24133, missile = 166767, hit = 166891 }, -- 비룡 쐐기 · sleep_state_head.m2
	aspect_of_the_hawk     = { spell = 25296, cast = 2810, hit = 165615 }, -- 매의 상 · aspecthawk_impact_head.m2
	ghostly_strike         = { spell = 14278, cast = 3529, hit = 166239 }, -- 그림자 일격 · ghostlystrike_impact_chest.m2
	deadly_poison          = { spell = 25349, cast = 37, hit = 166643 }, -- 맹독 · poison_impact_chest.m2
	instant_poison         = { spell = 11340, cast = 37, hit = 166643 }, -- 순간 효과 독 · poison_impact_chest.m2
	rupture                = { spell = 11275, cast = 394, hit = 165737 }, -- 파열 · bloodyexplosion.m2
	expose_armor           = { spell = 11198, cast = 394, hit = 166055 }, -- 약점 노출 · exposearmor_head.m2
	cold_blood             = { spell = 14177, cast = 3770, hit = 165646 }, -- 냉혈 · backstab_impact_chest.m2
	sinister_strike        = { spell = 11294, cast = 399, hit = 166878 }, -- 사악한 일격 · sinisterstrike_impact_chest.m2
	blade_flurry           = { spell = 13877, cast = 270, hit = 166417, low = true }, -- 폭풍의 칼날 · innerfire_base.m2
	eviscerate             = { spell = 31016, cast = 733, hit = 166068 }, -- 절개 · feint_impact_chest.m2
	evasion                = { spell = 5277, cast = 425, hit = 166431 }, -- 회피 · invisibility_impact_chest.m2
	riposte                = { spell = 14251, cast = 547, hit = 165949 }, -- 반격 · disarm_impact_chest.m2
	adrenaline_rush        = { spell = 13750, self = 165554, selfLow = true, hit = 165554, low = true }, -- 아드레날린 촉진 · adrenalinerush_cast_base.m2
	backstab               = { spell = 25300, self = 165645, selfLow = true, hit = 165646 }, -- 기습 · backstab_impact_chest.m2
	hemorrhage             = { spell = 17348, cast = 4491, hit = 165737 }, -- 과다출혈 · bloodyexplosion.m2
	ambush                 = { spell = 11269, self = 165645, selfLow = true, hit = 165646 }, -- 매복 · backstab_impact_chest.m2
	vanish                 = { spell = 1857, self = 167151, selfLow = true, hit = 167151, low = true }, -- 소멸 · vanish_cast_base.m2
	slice_and_dice         = { spell = 6774, self = 166892, hit = 166892 }, -- 난도질 · slicedice_chest.m2
	flash_heal             = { spell = 10917, cast = 270, hit = 166197, low = true }, -- 순간 치유 · flashheal_base.m2
	pw_shield              = { spell = 10901, cast = 270, hit = 166342, low = true }, -- 신의 권능: 보호막 · holydivineshield_state_base.m2
	smite                  = { spell = 10934, cast = 119, hit = 166354 }, -- 성스러운 일격 · holysmite_low_chest.m2
	fortitude              = { spell = 10938, cast = 270, hit = 166356, low = true }, -- 신의 권능: 인내 · holyword_fortitude_impact_base.m2
	power_infusion         = { spell = 10060, cast = 191, hit = 165589 }, -- 마력 주입 · arcanepower_state_chest.m2
	prayer_of_fortitude    = { spell = 21564, cast = 270, hit = 166356, low = true }, -- 인내의 기원 · holyword_fortitude_impact_base.m2
	heal                   = { spell = 6064, cast = 270, hit = 166292, low = true }, -- 치유 · heal_low_base.m2
	renew                  = { spell = 25315, cast = 270, hit = 166697 }, -- 소생 · renew_chest.m2
	holy_nova              = { spell = 27801, self = 166350, selfLow = true, hit = 166325 }, -- 신성한 폭발 · holy_impactdd_high_chest.m2
	prayer_of_healing      = { spell = 25316, self = 166656, hit = 166348 }, -- 치유의 기원 · holylight_impact_head.m2
	resurrection           = { spell = 20770, cast = 191, hit = 166704, low = true }, -- 부활 · resurrection_low_base.m2
	mind_blast             = { spell = 10947, cast = 218, hit = 166558 }, -- 정신 분열 · mindblast_head.m2
	sw_pain                = { spell = 10894, cast = 218, hit = 166835 }, -- 어둠의 권능: 고통 · shadowwordpain_chest.m2
	mind_flay              = { spell = 18807, self = 166538, hit = 166538 }, -- 정신의 채찍 · manafunnel_impact_chest.m2
	vampiric_embrace       = { spell = 15286, cast = 218, hit = 166922 }, -- 흡혈의 선물 · soothingkiss_impact_head.m2
	devouring_plague       = { spell = 19280, cast = 218, hit = 165854 }, -- 파멸의 역병 · curseofmannoroth_head.m2
	shadowguard            = { spell = 19312, cast = 224, hit = 166499, low = true }, -- 어둠의 수호 · lightningshield_impact_base.m2
	lightning_bolt         = { spell = 15208, cast = 72, missile = 166497, hit = 166496 }, -- 번개 화살 · lightningbolt_impact_chest.m2
	chain_lightning        = { spell = 10605, cast = 321, hit = 165780 }, -- 연쇄 번개 · chainlightning_impact_chest.m2
	earth_shock            = { spell = 10414, cast = 3054, hit = 165987 }, -- 대지 충격 · earthshock_impact_chest.m2
	flametongue_totem      = { spell = 16387, cast = 352 }, -- 불꽃의 토템
	flame_shock            = { spell = 10448, cast = 38, missile = 166128, hit = 166186 }, -- 화염 충격 · flameshock_impact_chest.m2
	strength_of_earth      = { spell = 25361, cast = 270, hit = 166463, low = true }, -- 대지력 토템 · lesserheal_base.m2
	stormstrike            = { spell = 17364, cast = 324, hit = 166844 }, -- 폭풍의 일격 · shock_impact_chest.m2
	flametongue_weapon     = { spell = 16342, cast = 38, missile = 166135, hit = 166134 }, -- 불꽃의 무기 · firebolt_impactdd_med_chest.m2
	windfury_totem         = { spell = 10614, cast = 352 }, -- 질풍의 토템
	searing_totem          = { spell = 10438, cast = 38, missile = 166129, hit = 166583 }, -- 불타는 토템 · moltenblast_impact_chest.m2
	fire_nova              = { spell = 11315, self = 166144, selfLow = true, hit = 166147, low = true }, -- 불꽃 회오리 토템 · firenova_state.m2
	healing_wave           = { spell = 25357, cast = 183, hit = 166703, low = true }, -- 치유의 물결 · restoration_impact_base.m2
	chain_heal             = { spell = 10623, cast = 3169, hit = 166326 }, -- 연쇄 치유 · holy_impactdd_low_chest.m2
	stoneskin_totem        = { spell = 10408, cast = 270, hit = 166463, low = true }, -- 돌가죽 토템 · lesserheal_base.m2
	healing_stream         = { spell = 10463, cast = 270, hit = 166463, low = true }, -- 치유의 토템 · lesserheal_base.m2
	lesser_healing_wave    = { spell = 10468, cast = 183, hit = 166703, low = true }, -- 하급 치유의 물결 · restoration_impact_base.m2
	ancestral_spirit       = { spell = 20777, cast = 181, hit = 166704, low = true }, -- 고대의 영혼 · resurrection_low_base.m2
	presence_of_mind       = { spell = 12043, self = 166658, selfLow = true, hit = 166658, low = true }, -- 냉정 · presenceofmind_cast_base.m2
	arcane_missiles        = { spell = 25345, cast = 4509, missile = 165570, hit = 166525 }, -- 신비한 화살 · magic_impact_chest.m2
	arcane_explosion       = { spell = 10202, self = 165576, selfLow = true, hit = 165578 }, -- 신비한 폭발 · arcaneexplosion_impact_chest.m2
	arcane_intellect       = { spell = 10157, cast = 267, hit = 165585 }, -- 신비한 지능 · arcaneintellect_impact_base.m2
	arcane_power           = { spell = 12042, cast = 224, hit = 165589 }, -- 신비의 마법 강화 · arcanepower_state_chest.m2
	blast_wave             = { spell = 13021, self = 166144, selfLow = true, hit = 166147, low = true }, -- 화염 폭풍 · firenova_state.m2
	fireball               = { spell = 25306, cast = 38, missile = 166129, hit = 166583 }, -- 화염구 · moltenblast_impact_chest.m2
	scorch                 = { spell = 10207, cast = 38, hit = 166766 }, -- 불태우기 · scorch_low_chest.m2
	fire_blast             = { spell = 10199, cast = 38, hit = 166113 }, -- 화염 작열 · fire_impactdd_chest.m2
	flamestrike            = { spell = 10216, cast = 61, hit = 166403, low = true }, -- 불기둥 · immolate_state_base.m2
	combustion             = { spell = 11129, cast = 61, hit = 166162 }, -- 발화 · fireward_impact_chest.m2
	pyroblast              = { spell = 18809, cast = 38, missile = 166674, hit = 166583 }, -- 불덩이 작열 · moltenblast_impact_chest.m2
	frostbolt              = { spell = 25304, cast = 202, missile = 166214, hit = 166370 }, -- 얼음 화살 · ice_impactdd_med_chest.m2
	frost_nova             = { spell = 10230, self = 166210, selfLow = true, hit = 166385 }, -- 얼음 회오리 · ice_precast_uber_head.m2
	cone_of_cold           = { spell = 10161, cast = 1027, hit = 166370 }, -- 냉기 돌풍 · ice_impactdd_med_chest.m2
	ice_barrier            = { spell = 13033, cast = 207, hit = 166392, low = true }, -- 얼음 보호막 · iceshield_state.m2
	blizzard               = { spell = 10187, cast = 5390, hit = 165716, low = true }, -- 눈보라 · blizzard_impact_base.m2
	ice_armor              = { spell = 10220, cast = 203, hit = 166387 }, -- 얼음 갑옷 · icearmor_low_head.m2
	corruption             = { spell = 25311, cast = 118, hit = 166796 }, -- 부패 · shadow_impactdd_low_chest.m2
	curse_of_agony         = { spell = 11713, cast = 118, hit = 165852 }, -- 고통의 저주 · curseofagony_head.m2
	drain_life             = { spell = 11700, self = 166471, hit = 166471 }, -- 생명력 흡수 · lifetap_state_chest.m2
	curse_of_elements      = { spell = 11722, cast = 118, hit = 165851 }, -- 원소의 저주 · curseelements_impact_head.m2
	siphon_life            = { spell = 18881, cast = 118, hit = 166796 }, -- 생명력 착취 · shadow_impactdd_low_chest.m2
	hellfire               = { spell = 11684, self = 166304, selfLow = true, hit = 166304, low = true }, -- 지옥의 불길 · hellfire_impact_caster_base.m2
	shadow_bolt            = { spell = 25307, cast = 118, missile = 165891, hit = 165890 }, -- 어둠의 화살 · deathcoil_impact_chest.m2
	summon_felhunter       = { spell = 691, self = 166993, selfLow = true, hit = 166993, low = true }, -- 지옥사냥개 소환 · summonpet_cast_impact_base.m2
	soul_link              = { spell = 19028, cast = 267, hit = 165562, low = true }, -- 영혼의 고리 · amplifymagic_impact_base.m2
	death_coil             = { spell = 17926, cast = 118, missile = 165891, hit = 165890 }, -- 죽음의 고리 · deathcoil_impact_chest.m2
	demonic_sacrifice      = { spell = 18788, cast = 118, hit = 165648 }, -- 악의 제물 · banish_chest.m2
	inferno                = { spell = 1122, cast = 218, hit = 166796 }, -- 불지옥 · shadow_impactdd_low_chest.m2
	immolate               = { spell = 25309, cast = 61, hit = 166401 }, -- 제물 · immolate_impact_chest.m2
	searing_pain           = { spell = 17923, cast = 38, hit = 166766 }, -- 불타는 고통 · scorch_low_chest.m2
	rain_of_fire           = { spell = 11678, cast = 5391, hit = 166403, low = true }, -- 불의 비 · immolate_state_base.m2
	conflagrate            = { spell = 18932, cast = 38, hit = 166115 }, -- 점화 · fire_impactdd_high_chest.m2
	shadowburn             = { spell = 18871, cast = 218, hit = 166558 }, -- 어둠의 연소 · mindblast_head.m2
	soul_fire              = { spell = 17924, cast = 38, missile = 166674, hit = 166583 }, -- 영혼의 불꽃 · moltenblast_impact_chest.m2
	wrath                  = { spell = 9912, cast = 3291, missile = 167213, hit = 167212 }, -- 천벌 · wrath_impact_chest.m2
	moonfire               = { spell = 9835, cast = 730, hit = 166593, low = true }, -- 달빛 섬광 · moonfire_impact_base.m2
	starfire               = { spell = 25298, cast = 730, hit = 166973 }, -- 별빛 화살 · starfire_area.m2
	moonkin_form           = { spell = 24858, hit = 165970, low = true }, -- 달빛야수 변신 · druidmorph_impact_base.m2
	hurricane              = { spell = 17402, cast = 5669, hit = 165768, low = true }, -- 허리케인 · calllightning_impact.m2
	insect_swarm           = { spell = 24977, cast = 37, hit = 166602, low = true }, -- 곤충 떼 · nature_cast_hand.m2
	shred                  = { spell = 9830, self = 166550, selfLow = true, hit = 165737 }, -- 칼날 발톱 · bloodyexplosion.m2
	rake                   = { spell = 9904, self = 166679, selfLow = true, hit = 165737 }, -- 갈퀴 발톱 · bloodyexplosion.m2
	ferocious_bite         = { spell = 31018, cast = 5891, self = 166068, hit = 165737 }, -- 흉포한 이빨 · feint_impact_chest.m2 (the bite, at the cat's head) · bloodyexplosion.m2
	leader_of_pack         = { spell = 24932 }, -- 무리의 우두머리
	tigers_fury            = { spell = 9846, self = 165672, hit = 165673 }, -- 맹공격 · beastragestate.m2
	enrage                 = { spell = 5229, self = 165672, hit = 165672 }, -- 분노 · beastragecaster.m2
	maul                   = { spell = 9881, self = 166549, selfLow = true, hit = 165737 }, -- 후려치기 · bloodyexplosion.m2
	swipe                  = { spell = 9908, self = 167004, selfLow = true, hit = 165737 }, -- 휘둘러치기 · bloodyexplosion.m2
	demo_roar              = { spell = 9898, self = 165930, selfLow = true, hit = 165931 }, -- 위협의 포효 · demoralizingshout_impact_head.m2
	thorns                 = { spell = 9910, cast = 181, hit = 167114 }, -- 가시 · thorns_low_chest.m2
	frenzied_regen         = { spell = 22896, hit = 166694, low = true }, -- 광포한 재생력 · rejuvenation_impact_base.m2
	barkskin               = { spell = 22812, cast = 181, hit = 165655 }, -- 나무 껍질 · barkskin_state_base.m2
	rejuvenation           = { spell = 25299, cast = 181, hit = 166694, low = true }, -- 회복 · rejuvenation_impact_base.m2
	healing_touch          = { spell = 25297, cast = 183, hit = 166703, low = true }, -- 치유의 손길 · restoration_impact_base.m2
	regrowth               = { spell = 9858, cast = 183, hit = 166703, low = true }, -- 재생 · restoration_impact_base.m2
	mark_of_wild           = { spell = 9885, cast = 181, hit = 166546 }, -- 야생의 징표 · markofwild_impact_head.m2
	tranquility            = { spell = 9863, cast = 3375, hit = 167135, low = true }, -- 평온 · tranquility_impact_base.m2
	rebirth                = { spell = 20748, cast = 181, hit = 166704, low = true }, -- 환생 · resurrection_low_base.m2
}

-- A caster's basic attack (every ranged hero but the hunter): its school's
-- bolt, smaller than a skill's (size), flying to the target and bursting
-- there; a druid's nature is Wrath, the rest Lightning Bolt; holy has no
-- bolt, Smite's light bursts on the target.
ns.BASIC_FX_SIZE = 0.6
ns.BASIC_FX = {
	fire   = { missile = 166129, hit = 166583 }, -- 화염구 · moltenblast_impact_chest.m2
	frost  = { missile = 166214, hit = 166370 }, -- 얼음 화살 · ice_impactdd_med_chest.m2
	arcane = { missile = 165573, hit = 166525 }, -- 비전 화살 · magic_impact_chest.m2
	shadow = { missile = 165891, hit = 165890 }, -- 어둠의 화살 · deathcoil_impact_chest.m2
	nature = { missile = 166497, hit = 166496 }, -- 번개 화살 · lightningbolt_impact_chest.m2
	wrath  = { missile = 167213, hit = 167212 }, -- 천벌 · wrath_impact_chest.m2
	holy   = { hit = 166354 },                   -- 성스러운 일격 · holysmite_low_chest.m2
}
for _, fx in pairs(ns.BASIC_FX) do fx.size = ns.BASIC_FX_SIZE end
function ns.BasicFx(class, school)
	if class == "HUNTER" then return nil end
	if class == "DRUID" and school == "nature" then return ns.BASIC_FX.wrath end
	return ns.BASIC_FX[school]
end

-- Boss abilities by what they do and their school: the classic spell each
-- one is (its name shows when it is used) and its visual. A summon shows the
-- summoned monster's name.
ns.MOB_FX = {
	smash = {
		phys   = { spell = 12294, name = "죽음의 일격", cast = 324, hit = 166986 },
		fire   = { spell = 2136, name = "화염 작열", cast = 38, hit = 166113 },
		frost  = { spell = 116, name = "얼음 화살", cast = 202, missile = 166214, hit = 166370 },
		shadow = { spell = 686, name = "어둠의 화살", cast = 118, missile = 165891, hit = 165890 },
		nature = { spell = 403, name = "번개 화살", cast = 72, missile = 166497, hit = 166496 },
		arcane = { spell = 13748, name = "비전 화살", cast = 267, missile = 165573, hit = 166525 },
		holy   = { spell = 14914, name = "신성한 불꽃", cast = 61, hit = 166329 },
	},
	aoe = {
		phys   = { spell = 20549, name = "전투 발구르기", self = 167120, selfLow = true, hit = 166988 },
		fire   = { spell = 8349, name = "불꽃 회오리", self = 166144, selfLow = true, hit = 166147, low = true },
		frost  = { spell = 122, name = "얼음 회오리", self = 166210, selfLow = true, hit = 166385 },
		shadow = { spell = 9081, name = "연발 어둠의 화살", cast = 218, missile = 165891, hit = 165890 },
		nature = { spell = 421, name = "연쇄 번개", cast = 321, hit = 165780 },
		arcane = { spell = 1449, name = "신비한 폭발", self = 165576, selfLow = true, hit = 165578 },
		holy   = { spell = 15237, name = "신성한 폭발", self = 166350, selfLow = true, hit = 166325 },
	},
	shield = {
		phys   = { spell = 871, name = "방패의 벽", hit = 165914, low = true },
		fire   = { spell = 134, name = "화염 보호막", cast = 61, hit = 166157 },
		frost  = { spell = 168, name = "냉기 갑옷", cast = 203, hit = 166212 },
		shadow = { spell = 12040, name = "암흑 보호막", cast = 218, hit = 166823, low = true },
		nature = { spell = 324, name = "번개 보호막", cast = 224, hit = 166499, low = true },
		arcane = { spell = 1463, name = "마나 보호막", cast = 267, hit = 166540, low = true },
		holy   = { spell = 17, name = "신의 권능: 보호막", cast = 270, hit = 166342, low = true },
	},
	enrage = { spell = 3019, name = "격노", self = 165672, hit = 165672 },
	summon = { spell = 688, self = 166993, selfLow = true, hit = 166993, low = true },
}

-- The effect of a hero's skill in battle (nil: none).
function ns.SkillFx(classId, sk)
	return sk and ns.SKILL_FX[sk.id] or nil
end

-- The spell and effect of a boss ability (kind = smash, aoe, shield, enrage
-- or summon), by its school.
function ns.MobFx(kind, school)
	local t = ns.MOB_FX[kind]
	if not t then return nil end
	if t.spell then return t end
	return t[school or "phys"] or t.phys
end

-- The glow in a caster's hands for each cast kit above: the kit's hand
-- effect model (1.12 SpellVisualKit hand effect -> SpellVisualEffectName).
-- The battle window draws it as a model of its own, sized to the caster,
-- instead of the kit (a kit on a model is drawn at its own size whatever
-- the model's scale). Kits with no hand effect only animate.
ns.KIT_HAND = {
	[37] = 166602, -- nature_cast_hand.m2
	[38] = 166110, -- fire_cast_hand.m2
	[61] = 166110, -- fire_cast_hand.m2
	[72] = 166488, -- lightning_cast_hand.m2
	[118] = 166807, -- shadow_precast_low_hand.m2
	[119] = 166336, -- holy_precast_low_hand.m2
	[181] = 166602, -- nature_cast_hand.m2
	[183] = 166602, -- nature_cast_hand.m2
	[189] = 166337, -- holy_precast_med_hand.m2
	[191] = 166335, -- holy_precast_high_hand.m2
	[202] = 166381, -- ice_precast_low_hand.m2
	[203] = 166381, -- ice_precast_low_hand.m2
	[207] = 166379, -- ice_precast_high_hand.m2
	[218] = 166807, -- shadow_precast_low_hand.m2
	[224] = 166488, -- lightning_cast_hand.m2
	[267] = 166524, -- magic_cast_hand.m2
	[270] = 166336, -- holy_precast_low_hand.m2
	[321] = 166488, -- lightning_cast_hand.m2
	[379] = 166047, -- eviscerate_cast_hands.m2
	[394] = 165728, -- bloodlust_state_hand.m2
	[417] = 166336, -- holy_precast_low_hand.m2
	[425] = 166524, -- magic_cast_hand.m2
	[730] = 166524, -- magic_cast_hand.m2
	[733] = 166047, -- eviscerate_cast_hands.m2
	[1027] = 165811, -- coneofcold_hand.m2
	[2810] = 166602, -- nature_cast_hand.m2
	[3054] = 166602, -- nature_cast_hand.m2
	[3169] = 166336, -- holy_precast_low_hand.m2
	[3291] = 167214, -- wrath_precast_hand.m2
	[3375] = 166605, -- nature_precast_low_hand.m2
	[3770] = 166379, -- ice_precast_high_hand.m2
	[5390] = 166382, -- ice_precast_med_hand.m2
	[5391] = 166120, -- fire_precast_hand.m2
	[6383] = 166524, -- magic_cast_hand.m2
}
