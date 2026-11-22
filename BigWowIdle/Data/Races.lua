-- Factions and races. The player picks Alliance or Horde once; every hero is
-- then drawn as its class's representative race of that faction, in the
-- gender chosen when the hero was created. Looks only: no stat differences.
local _, ns = ...

ns.FACTIONS = {
	ALLIANCE = { name = "얼라이언스", hex = "4a8cff", icon = "Achievement_PVP_A_A",
		desc = "인간, 드워프, 나이트 엘프, 노움의 동맹." },
	HORDE    = { name = "호드", hex = "e0402e", icon = "Achievement_PVP_H_H",
		desc = "오크, 언데드, 타우렌, 트롤, 고블린의 연합." },
}
ns.FACTION_ORDER = { "ALLIANCE", "HORDE" }
for id, f in pairs(ns.FACTIONS) do f.id = id end

ns.SEXES = { "M", "F" }
ns.SEX = {
	M = { name = "남성", short = "남" },
	F = { name = "여성", short = "여" },
}

-- names: which name pool the race draws from (Data/Names.lua)
-- icons: portrait icon per gender, used until drawn portraits are added
ns.RACES = {
	HUMAN    = { name = "인간",        faction = "ALLIANCE", names = "human",
		icons = { M = "Achievement_Character_Human_Male", F = "Achievement_Character_Human_Female" } },
	DWARF    = { name = "드워프",      faction = "ALLIANCE", names = "dwarf",
		icons = { M = "Achievement_Character_Dwarf_Male", F = "Achievement_Character_Dwarf_Female" } },
	NIGHTELF = { name = "나이트 엘프", faction = "ALLIANCE", names = "nightelf",
		icons = { M = "Achievement_Character_Nightelf_Male", F = "Achievement_Character_Nightelf_Female" } },
	GNOME    = { name = "노움",        faction = "ALLIANCE", names = "gnome",
		icons = { M = "Achievement_Character_Gnome_Male", F = "Achievement_Character_Gnome_Female" } },
	ORC      = { name = "오크",        faction = "HORDE", names = "orc",
		icons = { M = "Achievement_Character_Orc_Male", F = "Achievement_Character_Orc_Female" } },
	UNDEAD   = { name = "언데드",      faction = "HORDE", names = "undead",
		icons = { M = "Achievement_Character_Undead_Male", F = "Achievement_Character_Undead_Female" } },
	TAUREN   = { name = "타우렌",      faction = "HORDE", names = "tauren",
		icons = { M = "Achievement_Character_Tauren_Male", F = "Achievement_Character_Tauren_Female" } },
	TROLL    = { name = "트롤",        faction = "HORDE", names = "troll",
		icons = { M = "Achievement_Character_Troll_Male", F = "Achievement_Character_Troll_Female" } },
	GOBLIN   = { name = "고블린",      faction = "HORDE", names = "goblin",
		icons = { M = "Achievement_Goblinhead", F = "Achievement_Goblinhead" } },
}
for id, r in pairs(ns.RACES) do r.id = id end

-- The race each class is drawn as, per faction: the races of the original
-- game, and the goblin for the tinker.
ns.CLASS_RACE = {
	WARRIOR = { ALLIANCE = "DWARF",    HORDE = "ORC" },
	PALADIN = { ALLIANCE = "HUMAN",    HORDE = "TAUREN" },
	HUNTER  = { ALLIANCE = "NIGHTELF", HORDE = "TROLL" },
	ROGUE   = { ALLIANCE = "HUMAN",    HORDE = "UNDEAD" },
	PRIEST  = { ALLIANCE = "HUMAN",    HORDE = "TROLL" },
	SHAMAN  = { ALLIANCE = "DWARF",    HORDE = "TAUREN" },
	MAGE    = { ALLIANCE = "HUMAN",    HORDE = "UNDEAD" },
	WARLOCK = { ALLIANCE = "HUMAN",    HORDE = "ORC" },
	DRUID   = { ALLIANCE = "NIGHTELF", HORDE = "TAUREN" },
	TINKER  = { ALLIANCE = "GNOME",    HORDE = "GOBLIN" },
}

function ns.Faction()
	return ns.db and ns.db.faction
end

-- Race of a class for a faction (defaults to the player's faction, then Alliance).
function ns.ClassRace(classId, faction)
	local m = ns.CLASS_RACE[classId]
	if not m then return nil end
	return m[faction or ns.Faction() or "ALLIANCE"]
end
