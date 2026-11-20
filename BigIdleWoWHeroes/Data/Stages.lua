-- Stages: 3 acts x 10 stages, each playable on 4 difficulties.
-- Every stage is a run of waves that ends with a boss; the 10th stage of an
-- act is a raid boss with its own abilities.
local _, ns = ...

ns.DIFFS = {
	{ name = { "일반", "Normal" },   hex = "ffffff", base = 1,  step = 1.00, mobs = 1, bossHP = 1.0, quality = 0 },
	{ name = { "영웅", "Heroic" },   hex = "1eff00", base = 32, step = 0.80, mobs = 3, bossHP = 1.5, quality = 1 },
	{ name = { "신화", "Mythic" },   hex = "a335ee", base = 57, step = 0.70, mobs = 4, bossHP = 2.0, quality = 2 },
	{ name = { "신화+", "Mythic+" }, hex = "ff8000", base = 79, step = 0.73, mobs = 5, bossHP = 2.6, quality = 3 },
}

ns.ACTS = {
	{ name = { "동부 왕국", "Eastern Kingdoms" } },
	{ name = { "칼림도어", "Kalimdor" } },
	{ name = { "북녘의 겨울", "The Northern Winter" } },
}

ns.STAGES_PER_ACT = 10
ns.STAGE_COUNT = 30
ns.WAVES = 10

-- Boss abilities:
--   smash  : heavy hit on the current target          { cd, mult }
--   aoe    : hits every hero                          { cd, mult, school, status }
--   summon : calls adds                               { cd, mob, n }
--   enrage : permanent damage bonus below a HP ratio  { hp, mult }
--   shield : temporary damage reduction               { cd, dur, dr }
local function B(ko, en, icon, mtype, hp, atk, aspd, o)
	o = o or {}
	o.name = { ko, en }
	o.icon = icon
	o.type = mtype
	o.hp = hp
	o.atk = atk
	o.aspd = aspd
	o.school = o.school or "phys"
	o.move = o.move or 150
	o.boss = true
	o.skills = o.skills or { { kind = "smash", cd = 9, mult = 2.2 } }
	return o
end

ns.STAGES = {
	---------------------------------------------------------------- Act 1
	{ name = { "엘윈 숲", "Elwynn Forest" }, mobs = { { "kobold", 50 }, { "wolf", 50 } },
		boss = B("들창코", "Hogger", "INV_Misc_Head_Gnoll_01", "humanoid", 150, 7, 0.7) },
	{ name = { "서부 몰락지대", "Westfall" }, mobs = { { "gnoll", 35 }, { "defias", 35 }, { "golem", 30 } },
		boss = B("미치광이 수확기", "Rogue Harvester", "INV_Gizmo_02", "mechanical", 240, 8, 0.6) },
	{ name = { "죽음의 폐광", "The Deadmines" }, mobs = { { "defias", 40 }, { "defias_mage", 30 }, { "goblin", 30 } },
		boss = B("에드윈 밴클리프", "Edwin VanCleef", "INV_Misc_Head_Human_02", "humanoid", 300, 10, 0.9,
			{ skills = { { kind = "smash", cd = 8, mult = 2.0 }, { kind = "summon", cd = 18, mob = "defias", n = 2 } } }) },
	{ name = { "붉은마루 산맥", "Redridge Mountains" }, mobs = { { "orc", 45 }, { "gnoll", 30 }, { "murloc", 25 } },
		boss = B("검은바위 대장", "Blackrock Warlord", "INV_Misc_Head_Orc_01", "humanoid", 360, 11, 0.7) },
	{ name = { "그늘숲", "Duskwood" }, mobs = { { "skeleton", 35 }, { "worgen", 35 }, { "spider", 30 } },
		boss = B("스티치스", "Stitches", "Spell_Shadow_AbominationExplosion", "undead", 460, 11, 0.6,
			{ skills = { { kind = "smash", cd = 9, mult = 2.2 }, { kind = "aoe", cd = 13, mult = 0.8, school = "nature", status = { "poison", 0.5 } } } }) },
	{ name = { "가시덤불 골짜기", "Stranglethorn Vale" }, mobs = { { "raptor", 35 }, { "troll", 30 }, { "tiger", 35 } },
		boss = B("왕 방갈라쉬", "King Bangalash", "INV_Misc_Head_Tiger_01", "beast", 440, 13, 1.0,
			{ skills = { { kind = "smash", cd = 8, mult = 2.0 }, { kind = "summon", cd = 20, mob = "tiger", n = 2 } } }) },
	{ name = { "저습지", "Wetlands" }, mobs = { { "croc", 35 }, { "darkiron", 30 }, { "murloc", 35 } },
		boss = B("늪지대의 거대 악어", "Giant Marsh Crocolisk", "Ability_Hunter_Pet_Crocolisk", "beast", 560, 12, 0.6) },
	{ name = { "동부 역병지대", "Eastern Plaguelands" }, mobs = { { "ghoul", 40 }, { "acolyte", 25 }, { "plaguebat", 35 } },
		boss = B("역병의 군주", "Plague Lord", "INV_Misc_Head_Scourge_01", "undead", 520, 13, 0.7,
			{ school = "shadow", skills = { { kind = "aoe", cd = 11, mult = 0.9, school = "shadow" }, { kind = "summon", cd = 20, mob = "ghoul", n = 2 } } }) },
	{ name = { "검은바위 나락", "Blackrock Depths" }, mobs = { { "darkiron_guard", 40 }, { "fire_elemental", 30 }, { "darkiron", 30 } },
		boss = B("제왕 다그란 타우릿산", "Emperor Dagran Thaurissan", "INV_Misc_Head_Dwarf_02", "humanoid", 600, 14, 0.8,
			{ skills = { { kind = "smash", cd = 9, mult = 2.2 }, { kind = "aoe", cd = 12, mult = 0.9, school = "fire", status = { "ignite", 0.4 } } } }) },
	{ name = { "화산 심장부", "Molten Core" }, raid = true, mobs = { { "core_hound", 50 }, { "fire_elemental", 50 } },
		boss = B("라그나로스", "Ragnaros", "Spell_Fire_LavaSpawn", "elemental", 1500, 16, 0.6,
			{ school = "fire", res = { fire = 75, frost = -25 }, skills = {
				{ kind = "aoe", cd = 9, mult = 1.0, school = "fire", status = { "ignite", 0.5 } },
				{ kind = "smash", cd = 12, mult = 2.6 },
				{ kind = "summon", cd = 24, mob = "son_of_flame", n = 3 },
				{ kind = "enrage", hp = 0.25, mult = 1.4 },
			} }) },
	---------------------------------------------------------------- Act 2
	{ name = { "듀로타", "Durotar" }, mobs = { { "scorpid", 35 }, { "boar", 35 }, { "quilboar", 30 } },
		boss = B("가시멧돼지 족장", "Razormane Chieftain", "INV_Misc_Head_Quillboar_01", "humanoid", 420, 10, 0.7) },
	{ name = { "불모의 땅", "The Barrens" }, mobs = { { "centaur", 35 }, { "thunder_lizard", 30 }, { "hyena", 35 } },
		boss = B("켄타우로스 칸", "Kolkar Khan", "INV_Misc_Head_Centaur_01", "humanoid", 480, 12, 0.9,
			{ skills = { { kind = "smash", cd = 8, mult = 2.0 }, { kind = "summon", cd = 18, mob = "centaur", n = 2 } } }) },
	{ name = { "통곡의 동굴", "Wailing Caverns" }, mobs = { { "deviate_raptor", 35 }, { "serpent", 30 }, { "ooze", 35 } },
		boss = B("걸신들린 무타누스", "Mutanus the Devourer", "INV_Misc_Head_Murloc_01", "humanoid", 560, 12, 0.7,
			{ skills = { { kind = "smash", cd = 9, mult = 2.3 }, { kind = "aoe", cd = 14, mult = 0.8, school = "nature", status = { "stun", 0.25 } } } }) },
	{ name = { "잿빛 골짜기", "Ashenvale" }, mobs = { { "furbolg", 40 }, { "satyr", 30 }, { "spider", 30 } },
		boss = B("타락한 고대정령", "Corrupted Ancient", "Spell_Nature_StoneClawTotem", "elemental", 680, 12, 0.5,
			{ res = { nature = 50, fire = -30 }, skills = { { kind = "smash", cd = 8, mult = 2.6 }, { kind = "shield", cd = 22, dur = 6, dr = 60 } } }) },
	{ name = { "버섯구름 봉우리", "Thousand Needles" }, mobs = { { "harpy", 40 }, { "centaur", 35 }, { "hyena", 25 } },
		boss = B("하피 여군주", "Harpy Matriarch", "Ability_Hunter_Pet_Vulture", "humanoid", 540, 14, 0.8,
			{ range = 420, school = "nature", skills = { { kind = "aoe", cd = 10, mult = 1.0, school = "nature", status = { "shock", 0.5 } } } }) },
	{ name = { "타나리스", "Tanaris" }, mobs = { { "basilisk", 30 }, { "pirate", 35 }, { "sand_troll", 35 } },
		boss = B("남쪽바다 선장", "Southsea Captain", "INV_Misc_Head_Human_01", "humanoid", 620, 14, 0.9,
			{ skills = { { kind = "smash", cd = 8, mult = 2.2 }, { kind = "summon", cd = 18, mob = "pirate", n = 2 } } }) },
	{ name = { "운고로 분화구", "Un'Goro Crater" }, mobs = { { "devilsaur", 25 }, { "deviate_raptor", 40 }, { "lava_elemental", 35 } },
		boss = B("폭군 데빌사우루스", "Tyrant Devilsaur", "INV_Misc_MonsterFang_02", "beast", 820, 15, 0.5,
			{ skills = { { kind = "smash", cd = 7, mult = 2.8 }, { kind = "enrage", hp = 0.3, mult = 1.4 } } }) },
	{ name = { "실리더스", "Silithus" }, mobs = { { "silithid", 40 }, { "cultist", 30 }, { "sandworm", 30 } },
		boss = B("둥지의 여왕", "Hive Queen", "Spell_Nature_InsectSwarm", "beast", 760, 14, 0.8,
			{ skills = { { kind = "aoe", cd = 12, mult = 0.9, school = "nature", status = { "poison", 0.6 } }, { kind = "summon", cd = 16, mob = "silithid", n = 3 } } }) },
	{ name = { "안퀴라즈 폐허", "Ruins of Ahn'Qiraj" }, mobs = { { "anubisath", 30 }, { "qiraji", 40 }, { "silithid", 30 } },
		boss = B("무적의 오시리안", "Ossirian the Unscarred", "INV_Misc_AhnQirajTrinket_04", "giant", 900, 16, 0.6,
			{ skills = { { kind = "smash", cd = 8, mult = 2.6 }, { kind = "shield", cd = 20, dur = 6, dr = 70 }, { kind = "enrage", hp = 0.3, mult = 1.3 } } }) },
	{ name = { "안퀴라즈 사원", "Temple of Ahn'Qiraj" }, raid = true, mobs = { { "anubisath", 40 }, { "qiraji", 60 } },
		boss = B("쑨", "C'Thun", "INV_Misc_Eye_01", "beast", 1900, 15, 0.7,
			{ school = "shadow", res = { shadow = 50 }, skills = {
				{ kind = "aoe", cd = 9, mult = 1.0, school = "shadow" },
				{ kind = "summon", cd = 18, mob = "eye_tentacle", n = 2 },
				{ kind = "shield", cd = 30, dur = 7, dr = 75 },
				{ kind = "enrage", hp = 0.2, mult = 1.5 },
			} }) },
	---------------------------------------------------------------- Act 3
	{ name = { "여명의 설원", "Winterspring" }, mobs = { { "yeti", 35 }, { "frostsaber", 35 }, { "frost_elemental", 30 } },
		boss = B("설인 왕", "Yeti King", "Ability_Hunter_Pet_Gorilla", "humanoid", 700, 13, 0.6,
			{ res = { frost = 50 }, skills = { { kind = "smash", cd = 8, mult = 2.5, status = { "stun", 0.5 } } } }) },
	{ name = { "알터랙 계곡", "Alterac Valley" }, mobs = { { "frostwolf", 40 }, { "ice_troll", 30 }, { "frost_elemental", 30 } },
		boss = B("서리 군주", "Frost Lord", "Spell_Frost_Glacier", "elemental", 760, 14, 0.6,
			{ school = "frost", res = { frost = 75, fire = -30 }, skills = { { kind = "aoe", cd = 10, mult = 1.0, school = "frost", status = { "chill", 1 } } } }) },
	{ name = { "서부 역병지대", "Western Plaguelands" }, mobs = { { "ghoul", 35 }, { "skeleton_mage", 30 }, { "abomination", 35 } },
		boss = B("누더기 감독관", "Abomination Overseer", "Spell_Shadow_AbominationExplosion", "undead", 980, 14, 0.5,
			{ skills = { { kind = "smash", cd = 7, mult = 2.6 }, { kind = "aoe", cd = 14, mult = 0.8, school = "nature", status = { "poison", 0.6 } } } }) },
	{ name = { "스칼로맨스", "Scholomance" }, mobs = { { "necromancer", 30 }, { "skeleton", 40 }, { "ghost", 30 } },
		boss = B("암흑스승 간들링", "Darkmaster Gandling", "Spell_Shadow_AnimateDead", "humanoid", 800, 16, 0.6,
			{ range = 430, school = "shadow", skills = { { kind = "aoe", cd = 9, mult = 1.0, school = "shadow" }, { kind = "summon", cd = 14, mob = "skeleton", n = 3 } } }) },
	{ name = { "스트라솔름", "Stratholme" }, mobs = { { "crusader", 35 }, { "gargoyle", 35 }, { "banshee", 30 } },
		boss = B("남작 리븐데어", "Baron Rivendare", "Spell_Shadow_DeathCoil", "undead", 940, 16, 0.8,
			{ school = "shadow", skills = { { kind = "smash", cd = 8, mult = 2.3 }, { kind = "summon", cd = 16, mob = "skeleton", n = 3 }, { kind = "enrage", hp = 0.3, mult = 1.3 } } }) },
	{ name = { "저주받은 땅", "Blasted Lands" }, mobs = { { "voidwalker", 30 }, { "imp", 35 }, { "felhound", 35 } },
		boss = B("군주 카자크", "Lord Kazzak", "Spell_Shadow_SummonInfernal", "demon", 1100, 16, 0.7,
			{ school = "shadow", res = { shadow = 50 }, skills = { { kind = "aoe", cd = 8, mult = 1.1, school = "shadow" }, { kind = "enrage", hp = 0.35, mult = 1.5 } } }) },
	{ name = { "검은바위 첨탑", "Blackrock Spire" }, mobs = { { "blackhand", 40 }, { "whelp", 30 }, { "ogre", 30 } },
		boss = B("사령관 드라키사스", "General Drakkisath", "INV_Misc_Head_Dragon_01", "dragonkin", 1150, 17, 0.7,
			{ res = { fire = 50 }, skills = { { kind = "smash", cd = 8, mult = 2.4 }, { kind = "aoe", cd = 11, mult = 1.0, school = "fire", status = { "ignite", 0.6 } } } }) },
	{ name = { "검은날개 둥지", "Blackwing Lair" }, mobs = { { "dragonkin", 40 }, { "drake", 30 }, { "technician", 30 } },
		boss = B("네파리안", "Nefarian", "INV_Misc_Head_Dragon_Black", "dragonkin", 1400, 18, 0.7,
			{ school = "fire", res = { fire = 60 }, skills = {
				{ kind = "aoe", cd = 9, mult = 1.1, school = "fire", status = { "ignite", 0.6 } },
				{ kind = "smash", cd = 11, mult = 2.6 },
				{ kind = "summon", cd = 20, mob = "dragonkin", n = 2 },
			} }) },
	{ name = { "낙스라마스", "Naxxramas" }, mobs = { { "crypt_fiend", 35 }, { "death_knight", 30 }, { "abomination", 35 } },
		boss = B("패치워크", "Patchwerk", "Spell_Shadow_AbominationExplosion", "undead", 1700, 17, 1.0,
			{ skills = { { kind = "smash", cd = 5, mult = 2.6 }, { kind = "enrage", hp = 0.2, mult = 1.6 } } }) },
	{ name = { "켈투자드의 방", "Kel'Thuzad's Chamber" }, raid = true, mobs = { { "death_knight", 50 }, { "crypt_fiend", 50 } },
		boss = B("켈투자드", "Kel'Thuzad", "Spell_Frost_FrostArmor02", "undead", 2400, 17, 0.7,
			{ range = 600, school = "frost", res = { frost = 60, shadow = 40 }, skills = {
				{ kind = "aoe", cd = 8, mult = 1.1, school = "frost", status = { "chill", 1 } },
				{ kind = "smash", cd = 10, mult = 2.4, school = "shadow", status = { "freeze", 1 } },
				{ kind = "summon", cd = 16, mob = "frozen_wraith", n = 3 },
				{ kind = "shield", cd = 32, dur = 6, dr = 70 },
				{ kind = "enrage", hp = 0.2, mult = 1.5 },
			} }) },
}

------------------------------------------------------------------------
-- Derived values
------------------------------------------------------------------------
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
	return string.format("%d-%d %s", act, n, ns.N(ns.STAGES[idx].name))
end

function ns.MobsPerWave(diff, idx)
	return ns.DIFFS[diff].mobs + math.floor((idx - 1) / (ns.STAGE_COUNT - 1) * 2.5)
end

function ns.MobHP(base, l)   return base * (1 + 0.25 * (l - 1)) * 1.07 ^ (l - 1) end
function ns.MobAtk(base, l)  return base * (1 + 0.12 * (l - 1)) * 1.05 ^ (l - 1) end
function ns.MobGold(base, l) return base * (1 + 0.15 * (l - 1)) * 1.04 ^ (l - 1) end
function ns.MobExp(base, l)  return base * (1 + 0.20 * (l - 1)) * 1.045 ^ (l - 1) end

-- Physical mitigation threshold: armor equal to this halves physical damage.
function ns.ArmorK(l)
	return 30 + 20 * l
end
