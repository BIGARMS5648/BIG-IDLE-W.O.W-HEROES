-- Playable classes. The party always has five role slots:
-- 1 tank, 3 damage dealers and 1 healer.
local _, ns = ...

ns.ROLE = {
	TANK   = { name = { "탱커", "Tank" },   hex = "4080ff" },
	DPS    = { name = { "딜러", "Damage" }, hex = "ff5040" },
	HEALER = { name = { "힐러", "Healer" }, hex = "40d060" },
}

-- Party slot index -> role it accepts.
ns.PARTY_ROLES = { "TANK", "DPS", "DPS", "DPS", "HEALER" }
ns.PARTY_SIZE = 5

ns.HERO_MAX_LEVEL = 100
ns.HERO_UNLOCK_COST = 500
ns.TREE_TIER_POINTS = 10 -- points that must be spent to open each further tier

-- Class portrait atlas (same sheet on every client).
ns.CLASS_ICON_FILE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
ns.CLASS_ICON_COORD = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE    = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE   = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID   = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER  = { 0, 0.25, 0.25, 0.5 },
	SHAMAN  = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST  = { 0.49609375, 0.7421875, 0.25, 0.5 },
	WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

ns.CLASS_ORDER = { "WARRIOR", "DRUID", "HUNTER", "MAGE", "ROGUE", "WARLOCK", "SHAMAN", "PRIEST", "PALADIN" }

-- Passive node: P(affix, perLevel, maxLevel). Skill node: K(skillId).
local function P(stat, per, maxLevel) return { p = stat, v = per, max = maxLevel } end
local function K(id) return { s = id, max = ns.SKILL_MAX } end

ns.CLASSES = {
	WARRIOR = {
		role = "TANK", name = { "전사", "Warrior" }, hex = "c79c6e", school = "phys", range = 150,
		desc = { "방패로 최전선을 지키는 굳건한 수호자.", "A steadfast guardian who holds the front line behind a shield." },
		base = { atk = 8, aspd = 0.90, crit = 3, critdmg = 150, hp = 240, armor = 40, move = 0 },
		mh = { "sword", "axe", "mace" }, oh = { "shield" },
		tree = {
			{ P("hpPct", 3, 8), P("armorPct", 3, 5), K("shield_slam"), K("thunder_clap") },
			{ P("block", 1.5, 8), P("atkPct", 3, 5), K("revenge") },
			{ P("regenPct", 0.12, 8), P("dmg_phys", 3, 8), K("commanding_shout") },
			{ P("dr", 0.8, 10), P("hpPct", 2.5, 10), K("shield_wall") },
			{ P("cdr", 1.5, 8), P("allres", 2, 10), K("last_stand") },
			{ P("hpkPct", 0.4, 10), P("armorPct", 3, 10) },
			{ P("aspd", 2, 10), P("block", 1.5, 10) },
			{ P("dr", 1, 10), P("atkPct", 3, 10) },
		},
	},
	DRUID = {
		role = "TANK", name = { "드루이드", "Druid" }, hex = "ff7d0a", school = "phys", range = 150,
		desc = { "곰으로 변신해 두꺼운 가죽과 재생력으로 버티는 야생의 수호자.", "A guardian of the wild who shrugs off blows in bear form." },
		base = { atk = 9, aspd = 0.80, crit = 4, critdmg = 150, hp = 270, armor = 30, move = 0, dodge = 5 },
		mh = { "mace", "staff" }, oh = { "relic" },
		tree = {
			{ P("hpPct", 3.5, 8), P("dodge", 1, 5), K("maul"), K("swipe") },
			{ P("armorPct", 3, 8), P("atkPct", 3, 5), K("demo_roar") },
			{ P("regenPct", 0.15, 8), P("dmg_phys", 3, 8), K("thorns") },
			{ P("leech", 0.4, 10), P("hpPct", 2.5, 10), K("frenzied_regen") },
			{ P("dodge", 1, 10), P("cdr", 1.5, 8), K("barkskin") },
			{ P("crit", 1, 10), P("allres", 2, 10) },
			{ P("aspd", 2, 10), P("hpkPct", 0.4, 10) },
			{ P("dr", 1, 10), P("atkPct", 3, 10) },
		},
	},
	HUNTER = {
		role = "DPS", name = { "사냥꾼", "Hunter" }, hex = "abd473", school = "phys", range = 720, ranged = true,
		desc = { "먼 거리에서 화살을 퍼붓는 명사수. 공격 속도가 가장 빠릅니다.", "A marksman raining arrows from afar with the fastest attacks." },
		base = { atk = 9, aspd = 1.10, crit = 6, critdmg = 160, hp = 140, armor = 18, move = 0 },
		mh = { "bow" }, oh = { "quiver" },
		tree = {
			{ P("aspd", 2.5, 8), P("atkPct", 3, 5), K("multi_shot"), K("aimed_shot") },
			{ P("crit", 1.2, 8), P("dmg_phys", 3, 5), K("serpent_sting") },
			{ P("critdmg", 4, 10), P("dmg_nature", 4, 8), K("rapid_fire") },
			{ P("atkPct", 3, 10), P("multi", 2, 10), K("volley") },
			{ P("cdr", 1.5, 8), P("aspd", 2, 10), K("call_beast") },
			{ P("crit", 1, 10), P("hpPct", 3, 10) },
			{ P("dmg_phys", 3, 10), P("leech", 0.3, 10) },
			{ P("critdmg", 5, 10), P("atkPct", 3, 10) },
		},
	},
	MAGE = {
		role = "DPS", name = { "마법사", "Mage" }, hex = "69ccf0", school = "fire", range = 680, ranged = true,
		desc = { "화염과 냉기로 적 무리를 쓸어버리는 광역 마법의 대가.", "A master of fire and frost who wipes out whole packs." },
		base = { atk = 11, aspd = 0.60, crit = 6, critdmg = 170, hp = 110, armor = 8, move = -5 },
		mh = { "staff", "dagger", "sword" }, oh = { "orb" },
		tree = {
			{ P("atkPct", 3, 5), P("cdr", 1.5, 8), K("fireball"), K("frost_nova") },
			{ P("dmg_fire", 4, 8), P("cast", 3, 5), K("arcane_missiles") },
			{ P("dmg_frost", 4, 8), P("crit", 1.2, 10), K("blizzard") },
			{ P("critdmg", 5, 10), P("dmg_arcane", 4, 8), K("flamestrike") },
			{ P("cast", 2.5, 10), P("atkPct", 3, 10), K("pyroblast") },
			{ P("dmg_fire", 3, 10), P("hpPct", 3, 10) },
			{ P("cdr", 1.2, 10), P("dmg_frost", 3, 10) },
			{ P("crit", 1, 10), P("dmg_all", 2, 10) },
		},
	},
	ROGUE = {
		role = "DPS", name = { "도적", "Rogue" }, hex = "fff569", school = "phys", range = 150,
		desc = { "쌍수 칼날로 한 대상을 순식간에 베어 넘기는 근접 암살자.", "A dual-wielding assassin who shreds a single target in melee." },
		base = { atk = 10, aspd = 1.30, crit = 8, critdmg = 175, hp = 150, armor = 20, move = 10, dodge = 6 },
		mh = { "dagger", "sword", "mace" }, oh = { "offblade" },
		tree = {
			{ P("aspd", 2.5, 8), P("crit", 1.2, 5), K("sinister_strike"), K("blade_flurry") },
			{ P("dodge", 1.2, 8), P("atkPct", 3, 5), K("rupture") },
			{ P("critdmg", 5, 10), P("dmg_phys", 3, 8), K("evasion") },
			{ P("leech", 0.4, 10), P("aspd", 2, 10), K("eviscerate") },
			{ P("multi", 2, 10), P("cdr", 1.5, 8), K("adrenaline_rush") },
			{ P("crit", 1, 10), P("hpPct", 3, 10) },
			{ P("atkPct", 3, 10), P("dodge", 1, 10) },
			{ P("critdmg", 5, 10), P("dmg_phys", 3, 10) },
		},
	},
	WARLOCK = {
		role = "DPS", name = { "흑마법사", "Warlock" }, hex = "9482c9", school = "shadow", range = 680, ranged = true,
		desc = { "저주와 지속 피해, 소환수로 적을 서서히 무너뜨립니다.", "Wears enemies down with curses, lingering damage and demons." },
		base = { atk = 10, aspd = 0.65, crit = 5, critdmg = 160, hp = 130, armor = 8, move = -5 },
		mh = { "staff", "dagger" }, oh = { "orb" },
		tree = {
			{ P("dmg_shadow", 4, 8), P("atkPct", 3, 5), K("shadow_bolt"), K("corruption") },
			{ P("hpPct", 3, 8), P("cast", 3, 5), K("rain_of_fire") },
			{ P("dmg_fire", 4, 8), P("cdr", 1.5, 8), K("summon_imp") },
			{ P("leech", 0.4, 10), P("crit", 1.2, 10), K("drain_life") },
			{ P("atkPct", 3, 10), P("cast", 2.5, 10), K("curse_of_elements") },
			{ P("dmg_shadow", 3, 10), P("regenPct", 0.1, 10) },
			{ P("critdmg", 5, 10), P("cdr", 1.2, 10) },
			{ P("dmg_all", 2, 10), P("atkPct", 3, 10) },
		},
	},
	SHAMAN = {
		role = "DPS", name = { "주술사", "Shaman" }, hex = "0070de", school = "nature", range = 640, ranged = true,
		desc = { "번개와 토템으로 싸우며 파티 전체를 고양시키는 정령술사.", "Fights with lightning and totems that empower the whole party." },
		base = { atk = 10, aspd = 0.75, crit = 5, critdmg = 160, hp = 160, armor = 24, move = 0 },
		mh = { "mace", "axe", "staff" }, oh = { "shield", "relic" },
		tree = {
			{ P("dmg_nature", 4, 8), P("atkPct", 3, 5), K("lightning_bolt"), K("chain_lightning") },
			{ P("crit", 1.2, 8), P("armorPct", 4, 5), K("earth_shock") },
			{ P("cast", 3, 8), P("hpPct", 3, 8), K("windfury_totem") },
			{ P("critdmg", 5, 10), P("dmg_fire", 4, 10), K("searing_totem") },
			{ P("cdr", 1.5, 8), P("atkPct", 3, 10), K("bloodlust") },
			{ P("dmg_nature", 3, 10), P("block", 1.5, 10) },
			{ P("aspd", 2, 10), P("allres", 2, 10) },
			{ P("crit", 1, 10), P("dmg_all", 2, 10) },
		},
	},
	PRIEST = {
		role = "HEALER", name = { "사제", "Priest" }, hex = "ffffff", school = "holy", range = 700, ranged = true,
		desc = { "치유와 보호막, 부활로 파티를 살려내는 필수 지원가.", "Keeps the party alive with heals, shields and resurrection." },
		base = { atk = 6, aspd = 0.80, crit = 3, critdmg = 150, hp = 140, armor = 12, move = -10 },
		mh = { "mace", "staff", "dagger" }, oh = { "orb" },
		tree = {
			{ P("heal", 4, 8), P("hpPct", 3, 5), K("heal"), K("fortitude") },
			{ P("cdr", 1.5, 8), P("cast", 3, 5), K("holy_nova") },
			{ P("heal", 3, 10), P("allres", 2, 8), K("pw_shield") },
			{ P("dmg_holy", 4, 10), P("regenPct", 0.1, 10), K("prayer_of_healing") },
			{ P("cast", 2.5, 10), P("hpPct", 2.5, 10), K("resurrection") },
			{ P("cdr", 1.2, 10), P("dodge", 1, 10) },
			{ P("heal", 3, 10), P("armorPct", 4, 10) },
			{ P("dr", 1, 10), P("atkPct", 3, 10) },
		},
	},
	PALADIN = {
		role = "HEALER", name = { "성기사", "Paladin" }, hex = "f58cba", school = "holy", range = 520, ranged = true,
		desc = { "튼튼한 갑옷을 입은 치유사. 오라와 축복으로 파티를 강화합니다.", "An armored healer whose auras and blessings empower the party." },
		base = { atk = 7, aspd = 0.85, crit = 3, critdmg = 150, hp = 170, armor = 26, move = -10 },
		mh = { "sword", "mace" }, oh = { "shield", "relic" },
		tree = {
			{ P("heal", 3.5, 8), P("armorPct", 3, 5), K("holy_light"), K("devotion_aura") },
			{ P("hpPct", 3, 8), P("atkPct", 3, 5), K("judgement") },
			{ P("block", 1.5, 8), P("cdr", 1.5, 8), K("blessing_of_might") },
			{ P("dmg_holy", 4, 10), P("heal", 3, 10), K("lay_on_hands") },
			{ P("cast", 2.5, 10), P("hpPct", 2.5, 10), K("divine_protection") },
			{ P("crit", 1, 10), P("allres", 2, 10) },
			{ P("cdr", 1.2, 10), P("regenPct", 0.1, 10) },
			{ P("dr", 1, 10), P("heal", 3, 10) },
		},
	},
}

for id, c in pairs(ns.CLASSES) do
	c.id = id
end

-- Experience needed to go from level L to L+1.
function ns.XPForLevel(l)
	return math.floor(78 * l * l * 1.0812 ^ l + 20)
end

-- Level-based growth of the base stats.
function ns.BaseAtLevel(class, stat, level)
	local b = class.base[stat] or 0
	if stat == "atk" then
		return b * (1 + 0.08 * (level - 1))
	elseif stat == "hp" then
		return b * (1 + 0.12 * (level - 1))
	elseif stat == "armor" then
		return b * (1 + 0.10 * (level - 1))
	end
	return b
end
