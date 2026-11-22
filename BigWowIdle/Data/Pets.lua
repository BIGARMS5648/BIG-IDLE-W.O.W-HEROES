-- Companions. Their bonuses are always active once unlocked; the one you
-- "summon" only decides which icon walks with the party. The kill counts are
-- set so each one comes at about the same point of the game as it always has
-- (the balance run, tests/test_balance.lua).
local _, ns = ...

ns.PETS = {
	{ id = "cat", name = "얼룩 고양이", icon = "INV_Box_PetCarrier_01",
		unlock = { type = "beast", n = 13000 }, bonus = { exp = 15, chestChance = 1.5 } },
	{ id = "chicken", name = "기계 닭", icon = "INV_Gizmo_03",
		unlock = { type = "humanoid", n = 4300 }, bonus = { gold = 15 } },
	{ id = "skull", name = "떠도는 해골", icon = "INV_Misc_Bone_HumanSkull_01",
		unlock = { type = "undead", n = 16000 }, bonus = { bossChest = 10 } },
	{ id = "ember", name = "꼬마 불씨", icon = "Spell_Fire_Fire",
		unlock = { type = "elemental", n = 2500 }, bonus = { forgeExp = 15, smeltGold = 10 } },
	{ id = "imp", name = "말썽쟁이 임프", icon = "Spell_Shadow_SummonImp",
		unlock = { type = "demon", n = 870 }, bonus = { chestChance = 2 } },
	{ id = "whelp", name = "진홍 새끼용", icon = "INV_Misc_Head_Dragon_Red",
		unlock = { type = "dragonkin", n = 610 }, bonus = { gold = 15, exp = 20 } },
	{ id = "squirrel", name = "기계 다람쥐", icon = "INV_Gizmo_01",
		unlock = { type = "mechanical", n = 1100 }, bonus = { autoCd = 15, chestCap = 5 } },
	{ id = "bigglesworth", name = "비글스워스 씨", icon = "Ability_Hunter_Pet_Cat",
		unlock = { raid = 30 }, bonus = { offline = 20, exp = 10 } },
}

ns.PET_BY_ID = {}
for i = 1, #ns.PETS do
	ns.PET_BY_ID[ns.PETS[i].id] = ns.PETS[i]
end
