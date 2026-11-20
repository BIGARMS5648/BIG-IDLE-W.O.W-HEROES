-- Checks of the game systems (no UI involved).
local ns = NS
local failures = 0

local function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("  FAIL: " .. msg)
	end
end

local function section(name) print("  - " .. name) end

math.randomseed(12345)
BigIdleWoWHeroesDB = nil
ns.DetectLang()
ns.InitDB()
local db = ns.db

------------------------------------------------------------------------
section("data integrity")
for id, c in pairs(ns.CLASSES) do
	check(ns.ROLE[c.role], id .. ": unknown role")
	check(ns.CLASS_ICON_COORD[id], id .. ": no class icon")
	check(#c.tree == 8, id .. ": tree must have 8 tiers")
	local actives = 0
	for t, tier in ipairs(c.tree) do
		for n, node in ipairs(tier) do
			if node.s then
				actives = actives + 1
				check(ns.SKILLS[node.s], id .. ": unknown skill " .. tostring(node.s))
			else
				check(ns.AFFIX[node.p], id .. ": unknown passive stat " .. tostring(node.p))
			end
		end
	end
	check(actives == 6, id .. ": expected 6 active skills, got " .. actives)
	for _, t in ipairs(c.mh) do check(ns.WTYPE[t] and ns.WTYPE[t].slot == "mh", id .. ": bad main hand type " .. t) end
	for _, t in ipairs(c.oh) do check(ns.WTYPE[t] and ns.WTYPE[t].slot == "oh", id .. ": bad off hand type " .. t) end
end
do
	local roles = { TANK = 0, DPS = 0, HEALER = 0 }
	for _, id in ipairs(ns.CLASS_ORDER) do roles[ns.CLASSES[id].role] = roles[ns.CLASSES[id].role] + 1 end
	check(roles.TANK >= 1 and roles.DPS >= 3 and roles.HEALER >= 1, "need at least 1 tank, 3 damage and 1 healer class")
	check(#ns.PARTY_ROLES == 5 and ns.PARTY_ROLES[1] == "TANK" and ns.PARTY_ROLES[5] == "HEALER", "party must be tank / 3 damage / healer")
end
for id, sk in pairs(ns.SKILLS) do
	check(sk.act == "cd" or sk.act == "count" or sk.act == "aura", id .. ": bad activation")
	check(type(ns.SkillDesc(id, 1)) == "string", id .. ": description failed")
	check(type(ns.SkillActText(id, 1)) == "string", id .. ": activation text failed")
	if sk.school then check(ns.SCHOOL[sk.school], id .. ": unknown school") end
	if sk.status then
		local key = type(sk.status) == "table" and sk.status[1] or sk.status
		check(ns.STATUS[key], id .. ": unknown status " .. tostring(key))
	end
	if sk.mods then for _, m in ipairs(sk.mods) do check(ns.AFFIX[m[1]], id .. ": unknown mod " .. m[1]) end end
end
check(#ns.STAGES == ns.STAGE_COUNT, "stage count mismatch")
for i, stg in ipairs(ns.STAGES) do
	for _, e in ipairs(stg.mobs) do check(ns.MONSTERS[e[1]], "stage " .. i .. ": unknown monster " .. e[1]) end
	check(stg.boss and stg.boss.hp > 0, "stage " .. i .. ": no boss")
	for _, sk in ipairs(stg.boss.skills) do
		if sk.kind == "summon" then check(ns.MONSTERS[sk.mob], "stage " .. i .. ": boss summons unknown " .. tostring(sk.mob)) end
		if sk.status then check(ns.STATUS[sk.status[1]], "stage " .. i .. ": boss status") end
	end
end
for id, m in pairs(ns.MONSTERS) do
	check(ns.MTYPE[m.type], id .. ": unknown monster type")
	check(ns.SCHOOL[m.school], id .. ": unknown school")
	if m.status then check(ns.STATUS[m.status[1]], id .. ": unknown status") end
end
for cat, pool in pairs(ns.AFFIX_POOL) do
	for _, e in ipairs(pool) do check(ns.AFFIX[e[1]], cat .. " pool: unknown affix " .. e[1]) end
end
for kind, def in pairs(ns.SOCKET) do
	for _, cat in ipairs({ "weapon", "armor", "accessory" }) do
		for _, e in ipairs(def[cat]) do check(ns.AFFIX[e[1]], kind .. "/" .. cat .. ": unknown affix " .. e[1]) end
	end
end
for _, br in ipairs(ns.RUNE_BRANCHES) do
	for _, node in ipairs(br.nodes) do
		check(ns.BONUS_TEXT[node.stat] or ns.AFFIX[node.stat], "rune " .. node.id .. ": unknown bonus " .. node.stat)
		check(type(ns.BonusText(node.stat, node.per)) == "string", "rune text " .. node.id)
	end
end
for _, pet in ipairs(ns.PETS) do
	for k in pairs(pet.bonus) do check(ns.BONUS_TEXT[k] or ns.AFFIX[k], "pet " .. pet.id .. ": unknown bonus " .. k) end
	check(type(ns.PetUnlockText(pet)) == "string", "pet unlock text")
end
check(ns.StageLevel(1, 1) == 1 and ns.StageLevel(4, 30) == 100, "stage levels should span 1..100")

------------------------------------------------------------------------
section("heroes and party roles")
check(ns.Heroes.UnlockCost() == 0, "first hero is free")
check(ns.Heroes.Unlock("HUNTER"), "unlock starter")
check(ns.Heroes.PartySlot("HUNTER") == 2, "damage dealer goes to slot 2")
check(ns.Heroes.UnlockCost() == ns.HERO_UNLOCK_COST, "later heroes cost gold")
check(not ns.Heroes.Unlock("PRIEST"), "cannot unlock without gold")
ns.AddGold(1000000)
check(ns.Heroes.Unlock("PRIEST"), "unlock priest")
check(ns.Heroes.PartySlot("PRIEST") == nil, "party limit is 1 before the Command rune")
check(ns.PartyLimit() == 1, "party limit starts at 1")
for _, id in ipairs({ "root", "c1", "c2", "c3", "c4", "c5", "c6", "c7" }) do
	local ok, why = ns.Runes.Buy(id)
	check(ok, "buy rune " .. id .. ": " .. tostring(why))
end
check(ns.PartyLimit() == 5, "four Command runes give a party of 5")
check(ns.SkillSlots() == 2, "Awakening rune gives a second skill slot")
check(ns.Heroes.Deploy("PRIEST") and ns.Heroes.PartySlot("PRIEST") == 5, "healer goes to slot 5")
for _, id in ipairs({ "WARRIOR", "DRUID", "MAGE", "ROGUE", "WARLOCK", "SHAMAN", "PALADIN" }) do
	check(ns.Heroes.Unlock(id), "unlock " .. id)
end
check(ns.Heroes.PartySlot("WARRIOR") == 1, "tank goes to slot 1")
check(ns.Heroes.PartySlot("DRUID") == nil, "only one tank slot")
check(not ns.Heroes.Deploy("DRUID"), "second tank is refused")
check(not ns.Heroes.Deploy("PALADIN"), "second healer is refused")
check(ns.Heroes.PartyCount() == 5, "party is full with 5: " .. ns.Heroes.PartyCount())
do
	local dps = 0
	for i = 2, 4 do if db.party[i] and ns.CLASSES[db.party[i]].role == "DPS" then dps = dps + 1 end end
	check(dps == 3, "three damage dealers in slots 2-4")
end
check(not ns.Heroes.Deploy("WARLOCK"), "fourth damage dealer is refused")
check(ns.Heroes.Withdraw("WARRIOR") and ns.Heroes.Deploy("DRUID") and ns.Heroes.PartySlot("DRUID") == 1, "swap tanks")
check(not ns.Heroes.Deploy("WARLOCK", 1), "damage dealer cannot take the tank slot")

------------------------------------------------------------------------
section("experience and talent tree")
local before = db.heroes.HUNTER.level
ns.Heroes.AddXP("HUNTER", 5000000)
check(db.heroes.HUNTER.level > before + 20, "experience grants levels")
check(ns.Heroes.PointsFree("HUNTER") == db.heroes.HUNTER.level - 1, "one point per level (one pre-spent)")
check(not ns.Heroes.SpendPoint("HUNTER", 2, 1), "tier 2 locked before 10 points")
for _ = 1, 3 do check(ns.Heroes.SpendPoint("HUNTER", 1, 2), "spend on passive") end
check(ns.Heroes.SpendPoint("HUNTER", 1, 4), "learn second active")
for _ = 1, 8 do ns.Heroes.SpendPoint("HUNTER", 1, 1) end
check(ns.Heroes.TierOpen("HUNTER", 2), "tier 2 opens after 10 points")
check(ns.Heroes.SpendPoint("HUNTER", 2, 3), "learn tier 2 skill")
check(#ns.Heroes.ActiveSkills("HUNTER") == 2, "two skills active with two slots")
check(ns.Heroes.UnequipSkill("HUNTER", "multi_shot"), "unequip skill")
check(ns.Heroes.EquipSkill("HUNTER", "serpent_sting"), "equip another skill")
ns.Heroes.AddXP("HUNTER", 1e12)
check(db.heroes.HUNTER.level == ns.HERO_MAX_LEVEL, "level cap is 100")
local sBefore = ns.Stats.Get("HUNTER").aspd
check(ns.Heroes.ResetTree("HUNTER"), "reset tree")
check(ns.Heroes.PointsSpent("HUNTER") == 0 and ns.Stats.Get("HUNTER").aspd < sBefore, "reset refunds points and removes passives")

------------------------------------------------------------------------
section("items")
for _, slot in ipairs(ns.SLOTS) do
	for q = 1, ns.MAX_QUALITY do
		for _, lvl in ipairs({ 1, 37, 100 }) do
			local it = ns.Items.New(slot, lvl, q)
			check(#(it.a or {}) == ns.QUALITY[q].affix, slot .. " q" .. q .. ": affix count")
			check(type(ns.Items.Name(it)) == "string" and type(ns.Items.Icon(it)) == "string", "name / icon")
			check(#ns.Items.Tooltip(it, "HUNTER") >= 4, "tooltip")
			local gold, fxp = ns.Items.Value(it)
			check(gold > 0 and fxp > 0, "value")
			local seen = {}
			for _, a in ipairs(it.a or {}) do
				check(not seen[a[1]], "duplicate affix " .. a[1])
				seen[a[1]] = true
				check(a[2] > 0, "affix value must be positive")
			end
		end
	end
end
do
	local sword = ns.Items.New("mh", 5, 2, "sword")
	check(not ns.Items.CanUse("HUNTER", sword), "hunters cannot use swords")
	check(ns.Items.CanUse("WARRIOR", sword), "warriors can use swords")
	local bow = ns.Items.New("mh", 50, 5, "bow")
	db.heroes.MAGE.level = 10
	check(not ns.Items.CanEquip("MAGE", bow), "mage cannot equip a bow")
	local staff = ns.Items.New("mh", 50, 5, "staff")
	check(not ns.Items.CanEquip("MAGE", staff), "level requirement applies")
	db.heroes.MAGE.level = 60
	ns.Stats.Invalidate("MAGE")
	db.bag = {}
	ns.Items.AddToBag(staff)
	local p0 = ns.Stats.Power("MAGE")
	check(ns.Items.Compare("MAGE", staff) > 1, "a level 50 epic staff is an upgrade")
	check(ns.Items.Equip("MAGE", 1), "equip from bag")
	check(ns.Stats.Power("MAGE") > p0, "power rises after equipping")
	check(#db.bag == 1 and db.bag[1].s == "mh", "old weapon returns to the bag")
	check(ns.Items.Unequip("MAGE", "mh") and #db.bag == 2, "unequip")
	check(ns.Items.AutoEquip("MAGE") >= 1 and db.heroes.MAGE.gear.mh == staff, "auto-equip picks the best weapon")
end

------------------------------------------------------------------------
section("stat layers")
do
	db.heroes.ROGUE.gear = {}
	db.heroes.ROGUE.tree = {}
	ns.Stats.Invalidate("ROGUE")
	local s0 = ns.Stats.Compute("ROGUE")
	local s1 = ns.Stats.Compute("ROGUE", { { "atk", 10 }, { "atkPct", 50 }, { "atkPct", 50 }, { "atkMult", 100 } })
	local rune = 1 + ns.Bonus("atkPct") / 100
	local base = ns.BaseAtLevel(ns.CLASSES.ROGUE, "atk", db.heroes.ROGUE.level) + ns.Bonus("atk")
	local expect = (base + 10) * (rune + 1.0) * 2
	check(math.abs(s1.atk - expect) < 0.01, "final = (base+flat)*(1+add)*(1+mult): " .. s1.atk .. " vs " .. expect)
	check(ns.Stats.ArmorDR(ns.ArmorK(20), 20) == 0.5, "armor equal to the threshold halves damage")
	check(ns.Stats.ArmorDR(1e9, 20) == 0.75, "armor reduction caps at 75%")
	local capped = ns.Stats.Compute("ROGUE", { { "dodge", 500 }, { "cdr", 500 }, { "dr", 500 } })
	check(capped.dodge == 60 and capped.cdr == 60 and capped.dr == 75, "caps apply")
	check(s0.atk > 0 and #ns.Stats.Sheet("ROGUE") > 8, "sheet rows")
end

do
	-- account-wide gold / experience bonuses must not be counted once per hero
	local g, e = ns.Bonus("gold"), ns.Bonus("exp")
	ns.Runes.Buy("m1")
	ns.Runes.Buy("x1")
	check(ns.Bonus("gold") == g + 5 and ns.Bonus("exp") == e + 5, "wealth / growth runes raise the account bonus")
	local s = ns.Stats.Compute("ROGUE")
	check(s.gold == 0 and s.exp == 0, "account gold / exp bonuses are not folded into hero stats")
end

------------------------------------------------------------------------
section("chests and loot")
db.bag = {}
db.chests = {}
for _ = 1, 100 do ns.Loot.AddChest(1, 20, 1) end
check(ns.Loot.Count(1) == ns.ChestCap(1), "chest capacity is enforced: " .. ns.Loot.Count(1))
local sum = ns.Loot.OpenAll()
check(sum.opened == ns.ChestCap(1), "open all")
check(ns.Loot.Count() == 0, "no chests left")
db.bag = {}
for _ = 1, ns.BagSize() do ns.Items.AddToBag(ns.Items.New("head", 3, 2)) end
ns.Loot.AddChest(2, 20, 1)
db.opt.autoSmelt = 0
sum = ns.Loot.OpenAll()
check(sum.opened == 0 and sum.full, "a full bag keeps chests closed")
do
	local counts = {}
	for _ = 1, 4000 do
		local q = ns.Loot.RollQuality(ns.CHEST[1].q, 1)
		counts[q] = (counts[q] or 0) + 1
	end
	check((counts[2] or 0) > (counts[4] or 0), "common is likelier than rare from a battered chest")
	local hi1, hi4 = 0, 0
	for _ = 1, 4000 do
		if ns.Loot.RollQuality(ns.CHEST[1].q, 1) >= 4 then hi1 = hi1 + 1 end
		if ns.Loot.RollQuality(ns.CHEST[1].q, 4) >= 4 then hi4 = hi4 + 1 end
	end
	check(hi4 > hi1 * 2, "higher difficulty improves quality")
end

------------------------------------------------------------------------
section("titan forge")
local F = ns.Forge
db.bag = {}
db.forge = { level = 1, xp = 0, ops = { fuse = true }, craft = { true } }
check(not F.Smelt({}), "smelt is locked at first")
check(F.Unlock("smelt"), "unlock smelt")
check(not F.Unlock("craft"), "craft needs forge level 5")
local it = ns.Items.New("chest", 10, 3)
ns.Items.AddToBag(it)
local g0 = db.gold
local ok, gold = F.Smelt({ it })
check(ok and gold > 0 and db.gold == g0 + gold and #db.bag == 0, "smelting pays gold and removes the item")
check(db.forge.xp > 0 or db.forge.level > 1, "smelting grants forge experience")
-- fusion
db.bag = {}
for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, 2)) end
local list = F.PickForFusion(2, "gear")
check(list and #list == 9, "pick nine for fusion")
local okf, result, outcome = F.Fuse(list)
check(okf and #db.bag == 1 and result.q >= 3, "nine commons fuse into one better item")
db.bag = {}
for _ = 1, 8 do ns.Items.AddToBag(ns.Items.New("head", 12, 2)) end
ns.Items.AddToBag(ns.Items.New("ring", 12, 2))
check(not F.Fuse(db.bag), "armor and accessories do not mix")
db.bag = {}
for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, 8)) end
check(not F.Fuse(db.bag), "the top quality cannot be fused")
do
	local same, up = 0, 0
	for _ = 1, 300 do
		db.bag = {}
		for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, 5)) end
		local _, r = F.Fuse(F.PickForFusion(5, "gear"))
		if r.q == 5 then same = same + 1 else up = up + 1 end
	end
	check(same > 100 and up > 80, "epic fusion can fail or succeed (" .. same .. "/" .. up .. ")")
end
-- materials
db.mats = {}
ns.AddMat("bar1", 9)
local okm, nextId = F.FuseMat("bar1")
check(okm and nextId == "bar2" and ns.MatCount("bar2") == 1 and ns.MatCount("bar1") == 0, "nine materials become one of the next tier")
check(not F.FuseMat("bar5"), "top tier material cannot be fused")
-- crafting
db.bag = {}
db.forge.level = 30
for _, op in ipairs(ns.FORGE_OPS) do if not F.Unlocked(op.key) then check(F.Unlock(op.key), "unlock " .. op.key) end end
for g = 1, #ns.CRAFT_GROUPS do
	local cost = F.CraftCost(g, 1)
	for id, n in pairs(cost) do ns.AddMat(id, n) end
	local okc, crafted = F.Craft(g, 1)
	check(okc and crafted and crafted.l >= 1 and crafted.l <= 15, "craft group " .. g)
end
check(not F.Craft(1, 1), "crafting without materials fails")
check(not F.Craft(1, 2), "craft tier 2 is locked until bought")
check(F.UnlockCraftTier(2), "unlock craft tier 2")
-- sockets
local epic = ns.Items.New("chest", 40, 5)
check(ns.Items.FreeSockets(epic, "gem") == 2 and ns.Items.FreeSockets(epic, "ench") == 1 and ns.Items.FreeSockets(epic, "insc") == 0, "epic sockets")
ns.AddMat("gem3", 3)
ns.AddMat("dust2", 1)
check(F.Socket(epic, "gem", "gem3") and F.Socket(epic, "gem", "gem3"), "socket two gems")
check(not F.Socket(epic, "gem", "gem3"), "no third gem socket")
check(F.Socket(epic, "ench", "dust2"), "enchant")
check(not F.Socket(epic, "insc", "scroll1"), "epic has no inscription slot")
check(not F.Socket(epic, "gem", "dust2"), "wrong material kind is refused")
check(#epic.g == 2 and #epic.e == 1, "socket entries stored")
local goldBefore = db.gold
check(F.RemoveSocket(epic, "gem", 1) and #epic.g == 1 and db.gold < goldBefore, "extraction costs gold and frees the slot")
check(ns.MatCount("gem3") == 1, "extraction does not refund the material")
-- bonus roll
db.bag = {}
ns.AddMat("seal1", 1)
local okb, rolled = F.BonusRoll(1)
check(okb and rolled and #db.bag == 1, "bonus roll gives one item")
check(not F.BonusRoll(1), "no seal, no roll")

------------------------------------------------------------------------
section("combat")
db.bag = {}
db.chests = {}
db.stage = { diff = 1, idx = 1 }
db.prog = { 0, 0, 0, 0 }
for _, id in ipairs(ns.CLASS_ORDER) do
	local h = db.heroes[id]
	h.level = 30
	h.tree = {}
	h.skills = {}
	ns.Stats.Invalidate(id)
	-- learn everything in the first tiers so every skill kind runs
	local c = ns.CLASSES[id]
	for t = 1, 5 do
		for n = 1, #c.tree[t] do
			if c.tree[t][n].s then
				h.tree[t * 10 + n] = 1
			end
		end
	end
end
ns.Runes.Buy("c8")
ns.Runes.Buy("c9")
check(ns.SkillSlots() == 3, "third skill slot")
local C = ns.Combat
local function runParty(party, skillSets, steps)
	for i = 1, 5 do db.party[i] = party[i] or false end
	for i = 1, 5 do
		local id = party[i]
		if id then db.heroes[id].skills = skillSets[id] or {} end
	end
	C.StartStage()
	for _ = 1, steps do C.Step() end
end
local c = ns.CLASSES
local function skillsOf(id, a, b, d)
	local list = {}
	for t = 1, 5 do
		for n = 1, #c[id].tree[t] do
			local s = c[id].tree[t][n].s
			if s then list[#list + 1] = s end
		end
	end
	return { list[a], list[b], list[d] }
end
-- every class, every skill, in a few rotations
for rot = 0, 3 do
	local sets = {}
	for _, id in ipairs(ns.CLASS_ORDER) do
		sets[id] = skillsOf(id, 1 + rot % 6, 1 + (rot + 2) % 6, 1 + (rot + 4) % 6)
	end
	db.stage = { diff = 1, idx = 3 + rot * 7 }
	db.prog = { 30, 30, 30, 30 }
	runParty({ "WARRIOR", "HUNTER", "MAGE", "ROGUE", "PRIEST" }, sets, 2500)
	runParty({ "DRUID", "WARLOCK", "SHAMAN", "ROGUE", "PALADIN" }, sets, 2500)
end
check(db.stat.kills > 50, "monsters died: " .. db.stat.kills)
check(db.stat.clears > 0, "stages were cleared: " .. db.stat.clears)
-- an under-geared solo hero must lose on a hard stage and retreat
db.opt.auto, db.opt.retreat, db.opt.retry = true, true, true
db.stage = { diff = 3, idx = 10 }
db.heroes.HUNTER.gear = {}
ns.Stats.Invalidate("HUNTER")
local wipes = db.stat.wipes
runParty({ false, "HUNTER", false, false, false }, { HUNTER = { "multi_shot" } }, 3000)
check(db.stat.wipes > wipes, "a hopeless fight ends in defeat")
check(db.stage.idx < 10 or db.stage.diff < 3, "defeat retreats to an earlier stage")
check(not C.CanTravel(1, 31) and C.CanTravel(4, 30), "travel limits")
db.prog = { 3, 0, 0, 0 }
check(C.CanTravel(1, 4) and not C.CanTravel(1, 5) and not C.CanTravel(2, 1), "only unlocked stages are reachable")
check(#C.fx <= 40, "visual event list stays bounded")

------------------------------------------------------------------------
section("offline rewards")
db.rate = { gold = 10, xp = 5, level = 5 }
db.lastSeen = 1000
local g1 = db.gold
local r = ns.Offline.Claim(1000 + 3600)
check(r and r.gold == math.floor(10 * 3600 * ns.Offline.Efficiency()) and db.gold == g1 + r.gold, "one hour away pays the measured rate")
db.lastSeen = 1000
r = ns.Offline.Claim(1000 + 20 * 3600)
check(r and r.counted == ns.Offline.Cap(), "rewards are capped")
db.lastSeen = 1000
r = ns.Offline.Claim(1000 + 31 * 86400)
check(r and r.expired and r.gold == 0, "a month away pays nothing")
db.lastSeen = 1000
check(ns.Offline.Claim(1030) == nil, "less than a minute pays nothing")

------------------------------------------------------------------------
section("companions")
db.pets = {}
db.kills = { beast = 5000 }
ns.Runes.Invalidate()
local e0 = ns.Bonus("exp")
ns.CheckPets()
check(db.pets.cat and ns.Bonus("exp") == e0 + 15, "5000 beast kills unlock the cat and its bonus")

------------------------------------------------------------------------
section("save repair")
BigIdleWoWHeroesDB = { gold = 5, heroes = { NOPE = {}, MAGE = { level = 3, xp = 0, tree = {}, skills = {}, gear = {} } }, party = { "MAGE", "NOPE" } }
ns.InitDB()
check(ns.db.gold == 5 and ns.db.heroes.NOPE == nil and ns.db.party[2] == false, "unknown classes are dropped")
ns.Heroes.ValidateParty()
check(ns.db.party[1] == false and ns.Heroes.PartySlot("MAGE") == 2, "a hero in the wrong role slot is moved")
check(ns.db.forge.level == 1 and ns.db.opt.auto == true, "missing fields get defaults")

if failures == 0 then print("  systems: all checks passed") end
return failures == 0
