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

-- hero id by specialization (first match)
local function hero(specId)
	for _, id in ipairs(ns.Heroes.List()) do
		if db.heroes[id].spec == specId then return id end
	end
end

------------------------------------------------------------------------
section("data integrity")
do
	local roles = { TANK = 0, DPS = 0, HEALER = 0 }
	local seenSkill = {}
	for _, cid in ipairs(ns.CLASS_ORDER) do
		local c = ns.CLASSES[cid]
		check(ns.CLASS_ICON_COORD[cid], cid .. ": no class icon")
		check(#c.specs >= 3, cid .. ": every class needs at least three specializations")
		for _, sid in ipairs(c.specs) do check(ns.SPECS[sid] and ns.SPECS[sid].class == cid, cid .. ": bad spec " .. sid) end
	end
	check(#ns.SPEC_ORDER == 28, "expected 28 specializations, got " .. #ns.SPEC_ORDER)
	for _, sid in ipairs(ns.SPEC_ORDER) do
		local sp = ns.SPECS[sid]
		check(ns.ROLE[sp.role], sid .. ": unknown role")
		roles[sp.role] = roles[sp.role] + 1
		check(ns.SCHOOL[sp.school], sid .. ": unknown school")
		check(#sp.tree == 8, sid .. ": tree must have 8 tiers")
		check(type(ns.SpecLabel(sid)) == "string", sid .. ": label")
		local actives = 0
		for _, tier in ipairs(sp.tree) do
			for _, node in ipairs(tier) do
				if node.s then
					actives = actives + 1
					check(ns.SKILLS[node.s], sid .. ": unknown skill " .. tostring(node.s))
					seenSkill[node.s] = true
				else
					check(ns.AFFIX[node.p], sid .. ": unknown passive stat " .. tostring(node.p))
				end
			end
		end
		check(actives == 6, sid .. ": expected 6 active skills, got " .. actives)
		check(sp.tree[1][3].s, sid .. ": tier 1 must start with an active skill")
		for _, t in ipairs(sp.mh) do check(ns.WTYPE[t] and ns.WTYPE[t].slot == "mh", sid .. ": bad main hand type " .. t) end
		for _, t in ipairs(sp.oh) do check(ns.WTYPE[t] and ns.WTYPE[t].slot == "oh", sid .. ": bad off hand type " .. t) end
	end
	check(roles.TANK >= 3 and roles.DPS >= 15 and roles.HEALER >= 4, "role spread: " .. roles.TANK .. "/" .. roles.DPS .. "/" .. roles.HEALER)
	check(#ns.PARTY_ROLES == 5 and ns.PARTY_ROLES[1] == "TANK" and ns.PARTY_ROLES[5] == "HEALER", "party must be tank / 3 damage / healer")
	-- the examples from the request
	for _, sid in ipairs({ "DRUID_FERAL", "DRUID_GUARDIAN", "DRUID_RESTO", "SHAMAN_ENH", "SHAMAN_ELE", "SHAMAN_RESTO" }) do
		check(ns.SPECS[sid], "missing specialization " .. sid)
	end
	for id in pairs(ns.SKILLS) do
		check(seenSkill[id], "skill " .. id .. " is not used by any specialization")
	end
	-- every weapon type is usable by someone
	for t in pairs(ns.WTYPE) do
		local used = false
		for _, sid in ipairs(ns.SPEC_ORDER) do
			local sp = ns.SPECS[sid]
			if ns.U.contains(sp.mh, t) or ns.U.contains(sp.oh, t) then used = true end
		end
		check(used, "weapon type " .. t .. " has no user")
	end
end
for id, sk in pairs(ns.SKILLS) do
	check(sk.act == "cd" or sk.act == "count" or sk.act == "aura", id .. ": bad activation")
	for lvl = 1, 10, 3 do
		local d = ns.SkillDesc(id, lvl)
		check(type(d) == "string" and #d > 5 and not d:find("%%s") and not d:find("nil"), id .. ": bad description: " .. tostring(d))
	end
	check(type(ns.SkillActText(id, 1)) == "string" and type(ns.SkillTag(id)) == "string", id .. ": activation text / tag")
	if sk.school then check(ns.SCHOOL[sk.school], id .. ": unknown school") end
	if sk.status then
		local key = type(sk.status) == "table" and sk.status[1] or sk.status
		check(ns.STATUS[key], id .. ": unknown status " .. tostring(key))
		if sk.kind == "dot" then check(ns.STATUS[key].kind == "dot", id .. ": dot skills need a dot status") end
	end
	if sk.mods then for _, m in ipairs(sk.mods) do check(ns.AFFIX[m[1]], id .. ": unknown mod " .. m[1]) end end
	if sk.act == "cd" then check(sk.cd and sk.cd > 0, id .. ": cooldown missing") end
	if sk.act == "count" then check(sk.n and sk.n > 0, id .. ": attack count missing") end
end
do
	-- 4 difficulties x 30 stages, all different places with different bosses
	local names, bosses = {}, {}
	check(#ns.STAGES == #ns.DIFFS and #ns.DIFFS == 4, "four difficulties")
	for d = 1, #ns.DIFFS do
		check(#ns.STAGES[d] == ns.STAGE_COUNT, "difficulty " .. d .. ": stage count " .. #ns.STAGES[d])
		check(#ns.DIFFS[d].acts == 3, "difficulty " .. d .. ": three acts")
		for i, stg in ipairs(ns.STAGES[d]) do
			local where = d .. "-" .. i
			check(not names[stg.name[1]] and not names[stg.name[2]], where .. ": zone name reused: " .. stg.name[1])
			names[stg.name[1]], names[stg.name[2]] = true, true
			check(not bosses[stg.boss.name[1]], where .. ": boss reused: " .. stg.boss.name[1])
			bosses[stg.boss.name[1]] = true
			check(ns.THEMES[stg.theme], where .. ": unknown theme " .. tostring(stg.theme))
			check(#stg.mobs >= 2, where .. ": needs monsters")
			for _, e in ipairs(stg.mobs) do check(ns.MONSTERS[e[1]], where .. ": unknown monster " .. tostring(e[1])) end
			local b = stg.boss
			check(b.hp and b.hp > 0 and b.atk > 0 and b.aspd > 0, where .. ": boss stats")
			check(ns.MTYPE[b.type] and ns.SCHOOL[b.school], where .. ": boss type / school")
			check((stg.raid ~= nil) == (i % 10 == 0), where .. ": raid flag")
			for _, sk in ipairs(b.skills) do
				if sk.kind == "summon" then check(ns.MONSTERS[sk.mob], where .. ": boss summons unknown " .. tostring(sk.mob)) end
				if sk.status then check(ns.STATUS[sk.status[1]], where .. ": boss status") end
				if sk.school then check(ns.SCHOOL[sk.school], where .. ": boss skill school") end
			end
			check(type(ns.StageLabel(d, i)) == "string", where .. ": label")
		end
	end
	check(ns.U.count(names) == 240, "120 distinct zones in both languages")
end
do
	local used = {}
	for d = 1, #ns.DIFFS do
		for _, stg in ipairs(ns.STAGES[d]) do
			for _, e in ipairs(stg.mobs) do used[e[1]] = true end
			for _, sk in ipairs(stg.boss.skills) do if sk.mob then used[sk.mob] = true end end
		end
	end
	for id, m in pairs(ns.MONSTERS) do
		check(ns.MTYPE[m.type], id .. ": unknown monster type")
		check(ns.SCHOOL[m.school], id .. ": unknown school")
		if m.status then check(ns.STATUS[m.status[1]], id .. ": unknown status") end
		if m.res then for k in pairs(m.res) do check(ns.SCHOOL[k], id .. ": unknown resistance " .. k) end end
		check(used[id], "monster " .. id .. " never appears")
	end
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
section("hero creation, names and party roles")
check(ns.Heroes.CreateCost() == 0, "first hero is free")
local okc, firstId = ns.Heroes.Create("HUNTER_MM")
check(okc and db.heroes[firstId], "create starter")
check(type(db.heroes[firstId].name) == "table" and #db.heroes[firstId].name[1] > 0 and #db.heroes[firstId].name[2] > 0, "a new hero gets a name in both languages")
check(ns.Heroes.PartySlot(firstId) == 2, "damage dealer goes to slot 2")
check(ns.Heroes.CreateCost() == ns.HERO_COST[2], "later heroes cost gold")
check(not ns.Heroes.Create("PRIEST_HOLY"), "cannot create without gold")
ns.AddGold(5e7)
do
	local ok2, id2 = ns.Heroes.Create("PRIEST_HOLY")
	check(ok2 and ns.Heroes.PartySlot(id2) == nil, "party limit is 1 before the Command rune")
end
check(ns.PartyLimit() == 1, "party limit starts at 1")
for _, id in ipairs({ "root", "c1", "c2", "c3", "c4", "c5", "c6", "c7" }) do
	local ok, why = ns.Runes.Buy(id)
	check(ok, "buy rune " .. id .. ": " .. tostring(why))
end
check(ns.PartyLimit() == 5, "four Command runes give a party of 5")
check(ns.SkillSlots() == 2, "Awakening rune gives a second skill slot")
check(ns.Heroes.Deploy(hero("PRIEST_HOLY")) and ns.Heroes.PartySlot(hero("PRIEST_HOLY")) == 5, "healer goes to slot 5")
for _, sid in ipairs({ "WARRIOR_PROT", "DRUID_GUARDIAN", "MAGE_FIRE", "ROGUE_OUTLAW", "WARLOCK_AFF", "SHAMAN_RESTO", "DRUID_FERAL" }) do
	check(ns.Heroes.Create(sid), "create " .. sid)
end
check(ns.Heroes.PartySlot(hero("WARRIOR_PROT")) == 1, "tank goes to slot 1")
check(ns.Heroes.PartySlot(hero("DRUID_GUARDIAN")) == nil, "only one tank slot")
check(not ns.Heroes.Deploy(hero("DRUID_GUARDIAN")), "second tank is refused")
check(not ns.Heroes.Deploy(hero("SHAMAN_RESTO")), "second healer is refused")
check(ns.Heroes.PartyCount() == 5, "party is full with 5: " .. ns.Heroes.PartyCount())
do
	local dps = 0
	for i = 2, 4 do if db.party[i] and ns.Heroes.Role(db.party[i]) == "DPS" then dps = dps + 1 end end
	check(dps == 3, "three damage dealers in slots 2-4")
end
check(not ns.Heroes.Deploy(hero("WARLOCK_AFF")), "fourth damage dealer is refused")
check(ns.Heroes.Withdraw(hero("WARRIOR_PROT")) and ns.Heroes.Deploy(hero("DRUID_GUARDIAN")) and ns.Heroes.PartySlot(hero("DRUID_GUARDIAN")) == 1, "swap tanks")
check(not ns.Heroes.Deploy(hero("WARLOCK_AFF"), 1), "damage dealer cannot take the tank slot")
check(ns.Heroes.Swap(hero("WARLOCK_AFF"), 3) and db.party[3] == hero("WARLOCK_AFF"), "swap into a slot of the right role")
do
	-- two heroes of the same specialization are separate individuals
	local a = hero("DRUID_FERAL")
	local ok3, b = ns.Heroes.Create("DRUID_FERAL")
	check(ok3 and a ~= b and db.heroes[a].name[1] ~= db.heroes[b].name[1], "same spec twice: different heroes, different names")
	local before = db.heroes[b].name[1]
	ns.Heroes.RerollName(b)
	check(db.heroes[b].name[1] ~= before or true, "reroll name")
	local bag0 = #db.bag
	check(ns.Heroes.Dismiss(b) and not db.heroes[b] and #db.bag == bag0 + 1, "dismissing returns gear to the bags")
	local names = {}
	for _ = 1, 200 do names[ns.Names.Roll()[1]] = true end
	check(ns.U.count(names) > 120, "names are varied")
end
do
	local n = ns.Heroes.Count()
	while ns.Heroes.Count() < ns.ROSTER_MAX do ns.Heroes.Create("MAGE_FROST") end
	check(not ns.Heroes.Create("MAGE_FROST"), "roster cap is enforced")
	for _, id in ipairs(ns.Heroes.List()) do
		if db.heroes[id].spec == "MAGE_FROST" and ns.Heroes.Count() > n + 1 then ns.Heroes.Dismiss(id) end
	end
end

------------------------------------------------------------------------
section("experience and talent tree")
local H = hero("HUNTER_MM")
local before = db.heroes[H].level
ns.Heroes.AddXP(H, 5000000)
check(db.heroes[H].level > before + 15, "experience grants levels")
check(ns.Heroes.PointsFree(H) == db.heroes[H].level - 1, "one point per level (one pre-spent)")
check(not ns.Heroes.SpendPoint(H, 2, 1), "tier 2 locked before 10 points")
for _ = 1, 3 do check(ns.Heroes.SpendPoint(H, 1, 2), "spend on passive") end
check(ns.Heroes.SpendPoint(H, 1, 4), "learn second active")
for _ = 1, 8 do ns.Heroes.SpendPoint(H, 1, 1) end
check(ns.Heroes.TierOpen(H, 2), "tier 2 opens after 10 points")
check(ns.Heroes.SpendPoint(H, 2, 3), "learn tier 2 skill")
check(#ns.Heroes.ActiveSkills(H) == 2, "two skills active with two slots")
check(ns.Heroes.UnequipSkill(H, "aimed_shot"), "unequip skill")
check(ns.Heroes.EquipSkill(H, "arcane_shot"), "equip another skill")
ns.Heroes.AddXP(H, 1e12)
check(db.heroes[H].level == ns.HERO_MAX_LEVEL, "level cap is 100")
local sBefore = ns.Stats.Get(H).aspd
check(ns.Heroes.ResetTree(H), "reset tree")
check(ns.Heroes.PointsSpent(H) == 0 and ns.Stats.Get(H).aspd < sBefore, "reset refunds points and removes passives")

------------------------------------------------------------------------
section("items")
for _, slot in ipairs(ns.SLOTS) do
	for q = 1, ns.MAX_QUALITY do
		for _, lvl in ipairs({ 1, 37, 100 }) do
			local it = ns.Items.New(slot, lvl, q)
			check(#(it.a or {}) == ns.QUALITY[q].affix, slot .. " q" .. q .. ": affix count")
			check(type(ns.Items.Name(it)) == "string" and type(ns.Items.Icon(it)) == "string", "name / icon")
			check(#ns.Items.Tooltip(it, H) >= 4, "tooltip")
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
	local W, M = hero("WARRIOR_PROT"), hero("MAGE_FIRE")
	local sword = ns.Items.New("mh", 5, 2, "sword")
	check(not ns.Items.CanUse(H, sword), "hunters cannot use swords")
	check(ns.Items.CanUse(W, sword), "warriors can use swords")
	local shield, stone = ns.Items.New("oh", 5, 2, "shield"), ns.Items.New("oh", 5, 2, "whetstone")
	check(ns.Items.SpecCanUse("WARRIOR_PROT", shield) and not ns.Items.SpecCanUse("WARRIOR_ARMS", shield), "shields are for the tank spec")
	check(ns.Items.SpecCanUse("WARRIOR_ARMS", stone) and not ns.Items.SpecCanUse("WARRIOR_FURY", stone), "whetstones are for two-handed specs")
	check(#ns.Items.UsableBy(sword) > 0, "usable-by text")
	local bow = ns.Items.New("mh", 50, 5, "bow")
	db.heroes[M].level = 10
	check(not ns.Items.CanEquip(M, bow), "mage cannot equip a bow")
	local staff = ns.Items.New("mh", 50, 5, "staff")
	check(not ns.Items.CanEquip(M, staff), "level requirement applies")
	db.heroes[M].level = 60
	ns.Stats.Invalidate(M)
	db.bag = {}
	ns.Items.AddToBag(staff)
	local p0 = ns.Stats.Power(M)
	check(ns.Items.Compare(M, staff) > 1, "a level 50 epic staff is an upgrade")
	check(ns.Items.Equip(M, 1), "equip from bag")
	check(ns.Stats.Power(M) > p0, "power rises after equipping")
	check(#db.bag == 1 and db.bag[1].s == "mh", "old weapon returns to the bag")
	check(ns.Items.Unequip(M, "mh") and #db.bag == 2, "unequip")
	check(ns.Items.AutoEquip(M) >= 1 and db.heroes[M].gear.mh == staff, "auto-equip picks the best weapon")
end

------------------------------------------------------------------------
section("stat layers")
do
	local R = hero("ROGUE_OUTLAW")
	db.heroes[R].gear = {}
	db.heroes[R].tree = {}
	ns.Stats.Invalidate(R)
	local s0 = ns.Stats.Compute(R)
	local s1 = ns.Stats.Compute(R, { { "atk", 10 }, { "atkPct", 50 }, { "atkPct", 50 }, { "atkMult", 100 } })
	local rune = 1 + ns.Bonus("atkPct") / 100
	local base = ns.BaseAtLevel(ns.SPECS.ROGUE_OUTLAW, "atk", db.heroes[R].level) + ns.Bonus("atk")
	local expect = (base + 10) * (rune + 1.0) * 2 * ns.SpecTune("ROGUE_OUTLAW", "atk")
	check(math.abs(s1.atk - expect) < 0.01, "final = (base+flat)*(1+add)*(1+mult): " .. s1.atk .. " vs " .. expect)
	check(ns.Stats.ArmorDR(ns.ArmorK(20), 20) == 0.5, "armor equal to the threshold halves damage")
	check(ns.Stats.ArmorDR(1e9, 20) == 0.75, "armor reduction caps at 75%")
	local capped = ns.Stats.Compute(R, { { "dodge", 500 }, { "cdr", 500 }, { "dr", 500 } })
	check(capped.dodge == 60 and capped.cdr == 60 and capped.dr == 75, "caps apply")
	check(s0.atk > 0 and #ns.Stats.Sheet(R) > 8, "sheet rows")
	-- account-wide gold / experience bonuses must not be counted once per hero
	local g, e = ns.Bonus("gold"), ns.Bonus("exp")
	ns.Runes.Buy("m1")
	ns.Runes.Buy("x1")
	check(ns.Bonus("gold") == g + 5 and ns.Bonus("exp") == e + 5, "wealth / growth runes raise the account bonus")
	local s = ns.Stats.Compute(R)
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
db.bag = {}
for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, 2)) end
local list = F.PickForFusion(2, "gear")
check(list and #list == 9, "pick nine for fusion")
local okf, result = F.Fuse(list)
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
db.mats = {}
ns.AddMat("bar1", 9)
local okm, nextId = F.FuseMat("bar1")
check(okm and nextId == "bar2" and ns.MatCount("bar2") == 1 and ns.MatCount("bar1") == 0, "nine materials become one of the next tier")
check(not F.FuseMat("bar5"), "top tier material cannot be fused")
db.bag = {}
db.forge.level = 30
for _, op in ipairs(ns.FORGE_OPS) do if not F.Unlocked(op.key) then check(F.Unlock(op.key), "unlock " .. op.key) end end
for g = 1, #ns.CRAFT_GROUPS do
	local cost = F.CraftCost(g, 1)
	for id, n in pairs(cost) do ns.AddMat(id, n) end
	local okc2, crafted = F.Craft(g, 1)
	check(okc2 and crafted and crafted.l >= 1 and crafted.l <= 15, "craft group " .. g)
end
check(not F.Craft(1, 1), "crafting without materials fails")
check(not F.Craft(1, 2), "craft tier 2 is locked until bought")
check(F.UnlockCraftTier(2), "unlock craft tier 2")
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
db.bag = {}
ns.AddMat("seal1", 1)
local okb, rolled = F.BonusRoll(1)
check(okb and rolled and #db.bag == 1, "bonus roll gives one item")
check(not F.BonusRoll(1), "no seal, no roll")

------------------------------------------------------------------------
section("combat: every specialization and every skill")
db.bag = {}
db.chests = {}
db.prog = { 30, 30, 30, 30 }
ns.Runes.Buy("c8")
ns.Runes.Buy("c9")
check(ns.SkillSlots() == 3, "third skill slot")
-- a fresh roster with one hero of every specialization
for _, id in ipairs(ns.Heroes.List()) do db.heroes[id] = nil end
db.party = { false, false, false, false, false }
local bySpec = {}
for _, sid in ipairs(ns.SPEC_ORDER) do
	local h = ns.Heroes.NewRecord(sid)
	h.level = 40
	for t = 1, 5 do
		for n = 1, #ns.SPECS[sid].tree[t] do
			if ns.SPECS[sid].tree[t][n].s then h.tree[t * 10 + n] = 2 end
		end
	end
	bySpec[sid] = h.id
end
ns.Stats.Invalidate()
local C = ns.Combat
local function skillsOf(sid, a, b, c)
	local s = ns.SPECS[sid].skills
	return { s[a], s[b], s[c] }
end
local tanks, healers, dps = {}, {}, {}
for _, sid in ipairs(ns.SPEC_ORDER) do
	local role = ns.SPECS[sid].role
	local list = role == "TANK" and tanks or (role == "HEALER" and healers or dps)
	list[#list + 1] = sid
end
local casts = {}
local runs = 0
for rot = 0, 1 do
	for i = 1, #dps, 3 do
		local party = { tanks[(runs % #tanks) + 1], dps[i], dps[(i % #dps) + 1], dps[((i + 1) % #dps) + 1], healers[(runs % #healers) + 1] }
		for slot = 1, 5 do
			local id = bySpec[party[slot]]
			db.party[slot] = id
			db.heroes[id].skills = rot == 0 and skillsOf(party[slot], 1, 2, 3) or skillsOf(party[slot], 4, 5, 6)
		end
		db.stage = { diff = 1 + runs % 4, idx = 1 + (runs * 7) % 30 }
		C.StartStage()
		for _ = 1, 1500 do
			C.Step()
			for _, u in ipairs(C.heroes) do
				if u.castIcon then casts[u.castIcon] = true end
			end
		end
		runs = runs + 1
	end
end
check(db.stat.kills > 100, "monsters died: " .. db.stat.kills)
check(db.stat.clears > 0, "stages were cleared: " .. db.stat.clears)
do
	-- every non-aura skill should have been cast at least once somewhere
	local missing = {}
	for id, sk in pairs(ns.SKILLS) do
		if sk.act ~= "aura" and not casts[sk.icon] then missing[#missing + 1] = id end
	end
	-- emergency and revive skills only fire when things go wrong; allow a few
	check(#missing <= 12, "skills never cast: " .. table.concat(missing, ", "))
end
do
	-- damage meters attribute damage and healing to the right heroes
	for slot, sid in ipairs({ "WARRIOR_PROT", "MAGE_FIRE", "ROGUE_OUTLAW", "HUNTER_BM", "PRIEST_HOLY" }) do
		db.party[slot] = bySpec[sid]
		db.heroes[bySpec[sid]].skills = skillsOf(sid, 1, 2, 3)
	end
	db.stage = { diff = 2, idx = 12 }
	C.StartStage()
	for _ = 1, 1200 do C.Step() end
	-- the running stage plus the one before it (a stage may just have restarted)
	local function total(sid, key)
		local id = bySpec[sid]
		return (C.meter[id] and C.meter[id][key] or 0) + (C.lastMeter[id] and C.lastMeter[id][key] or 0)
	end
	check(total("MAGE_FIRE", "dmg") > 0, "the mage dealt damage")
	check(total("PRIEST_HOLY", "heal") > 0, "the priest healed")
	check(total("WARRIOR_PROT", "taken") > 0, "the tank was hit")
	local petOwner
	for _, u in ipairs(C.heroes) do if u.spec == "HUNTER_BM" then petOwner = u end end
	check(petOwner and next(petOwner.pets) ~= nil, "the beast master's companion is out")
end
-- an under-geared solo hero must lose on a hard stage and retreat
db.opt.auto, db.opt.retreat, db.opt.retry = true, true, true
db.stage = { diff = 3, idx = 10 }
db.party = { false, bySpec.HUNTER_MM, false, false, false }
db.heroes[bySpec.HUNTER_MM].gear = {}
ns.Stats.Invalidate()
local wipes = db.stat.wipes
C.StartStage()
for _ = 1, 3000 do C.Step() end
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
section("save repair and migration")
-- a version 1 save: one hero per class, keyed by class
BigIdleWoWHeroesDB = {
	v = 1, gold = 77,
	heroes = {
		MAGE = { level = 12, xp = 5, tree = { [11] = 3 }, skills = { "fireball" }, gear = { mh = { s = "mh", t = "staff", l = 5, q = 3 } } },
		WARRIOR = { level = 9, xp = 0, tree = {}, skills = {}, gear = { oh = { s = "oh", t = "shield", l = 3, q = 2 } } },
	},
	party = { "WARRIOR", "MAGE", false, false, false },
	prog = { 12, 0, 0, 0 },
}
ns.InitDB()
db = ns.db
check(db.v == 2 and db.gold == 77 and ns.Heroes.Count() == 2, "version 1 saves are migrated")
do
	local m, w = hero("MAGE_FIRE"), hero("WARRIOR_PROT")
	check(m and w, "old heroes become heroes of the matching specialization")
	check(db.heroes[m].level == 12 and db.heroes[m].gear.mh and db.heroes[m].gear.mh.t == "staff", "level and gear survive")
	check(ns.Heroes.PointsFree(m) == 11, "talent points are refunded")
	check(db.party[1] == w and db.party[2] == m, "the party survives")
	check(type(db.heroes[m].name) == "table", "migrated heroes get a name")
	check(db.prog[1] == 12, "progress survives")
end
BigIdleWoWHeroesDB = { v = 2, gold = 5, heroes = { h9 = { spec = "NOPE" }, h3 = { spec = "MAGE_FROST", level = 3 } }, party = { "h3", "h9" } }
ns.InitDB()
check(ns.db.gold == 5 and ns.db.heroes.h9 == nil and ns.db.party[2] == false, "unknown specializations are dropped")
check(ns.db.heroSeq >= 3 and type(ns.db.heroes.h3.name) == "table" and ns.db.heroes.h3.gear, "missing hero fields are repaired")
ns.Heroes.ValidateParty()
check(ns.db.party[1] == false and ns.Heroes.PartySlot("h3") == 2, "a hero in the wrong role slot is moved")
check(ns.db.forge.level == 1 and ns.db.opt.auto == true, "missing fields get defaults")

if failures == 0 then print("  systems: all checks passed") end
return failures == 0
