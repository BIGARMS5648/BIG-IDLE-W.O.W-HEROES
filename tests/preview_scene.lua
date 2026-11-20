-- Builds a well-stocked save and returns a function that arranges one named
-- scene; tests/preview.py exports each scene, draws it, and checks its layout
-- (tests/layout_check.js). Scenes run in the order of preview.py's list: the
-- "new_" scenes come last and start from an empty save.
local ns = NS
local Mock = WoWMock

math.randomseed(4242)
BigIdleWoWHeroesDB = nil
Mock.FireEvent("ADDON_LOADED", "BigIdleWoWHeroes")
Mock.FireEvent("PLAYER_LOGIN")
ns.Main.CloseModal()

local db = ns.db
db.faction = "ALLIANCE"
ns.AddGold(123456789)
ns.Heroes.Create("TINKER_MECH")
for _, id in ipairs({ "root", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "w1", "w1", "w2", "g1", "m1", "x1", "e1", "e2", "e3" }) do ns.Runes.Buy(id) end
for _, sid in ipairs({ "MAGE_FIRE", "ROGUE_SUB", "TINKER_TURRET", "PRIEST_DISC", "DRUID_RESTO", "SHAMAN_ENH", "WARRIOR_PROT", "TINKER_MEDIC" }) do ns.Heroes.Create(sid) end
for id in pairs(db.heroes) do ns.Heroes.AddXP(id, 2.5e6) end
-- the longest name the generator can make, to test every place a name is shown
db.heroes[db.party[2]].name = "로르티아스 브라이트스트라이더"
db.forge.level = 32
db.forge.xp = 21000
for _, op in ipairs(ns.FORGE_OPS) do
	if op.key ~= "insc" then ns.Forge.Unlock(op.key) end
end
ns.Forge.UnlockCraftTier(2)
for i = 1, 26 do
	ns.Items.AddToBag(ns.Items.New(ns.SLOTS[(i % #ns.SLOTS) + 1], 24 + i % 12, 1 + i % ns.MAX_QUALITY))
end
db.bag[3].lock = true
for _, id in ipairs(ns.MAT_ORDER) do ns.AddMat(id, 7 + #id) end
for slot = 1, ns.PARTY_SIZE do
	local id = db.party[slot]
	if id then
		ns.Items.AutoEquip(id)
		ns.Heroes.AutoSpend(id)
		ns.Heroes.AutoSkills(id)
		-- leave a few points so the badges show
		db.heroes[id].level = db.heroes[id].level + (slot == 2 and 3 or 0)
	end
end
-- one socketed item for the extraction scene
do
	local it = ns.Items.New("chest", 30, 6)
	ns.Items.AddToBag(it)
	ns.Forge.Socket(it, "gem", "gem2")
	ns.Forge.Socket(it, "ench", "dust2")
end
db.prog = { 30, 14, 0, 0 }
db.stage = { diff = 1, idx = 26 }
db.kills = { beast = 5200, undead = 1300, humanoid = 2400, elemental = 2500 }
ns.CheckPets()
for t = 1, 3 do for _ = 1, 3 + t do ns.Loot.AddChest(t, 40, 2) end end
ns.Combat.StartStage()
for _ = 1, 260 do Mock.Update(0.1) end

local function find(pred)
	for _, f in ipairs(Mock.frames) do
		if f:IsVisible() and pred(f) then return f end
	end
end
local function clickWhere(pred)
	local b = find(function(f) return f.Click and pred(f) end)
	if b then b:Click() end
	return b
end
local function page(key) return ns.Main.Page(key) end
local function show(key, opts)
	ns.Main.ShowTab(key, opts)
	return page(key)
end

local fresh = false
local function freshSave()
	if fresh then return end
	fresh = true
	ns.ResetDB()
	ns.Main.CloseModal()
	ns.db.faction = "HORDE"
	ns.Main.SelectHero(nil)
	db = ns.db
end

local S = {}

S.bar = function()
	ns.Main.Toggle(false)
	for _ = 1, 30 do Mock.Update(0.1) end
	ns.Toast("첫 공략! 3-6 저주받은 땅 (+12,345 골드, 궤짝 1개)")
	Mock.Update(0.05)
end

-- modals
S.faction = function() show("party") ns.PickFaction() end
S.create = function() show("party") ns.CreateHeroDialog("TINKER") end
S.create_druid = function() show("party") ns.CreateHeroDialog("DRUID", "HEALER") end
S.pets = function() show("party") clickWhere(function(f) return f.label and f.label.__text == "동료" end) end
S.pets_locked = function()
	show("party")
	clickWhere(function(f) return f.label and f.label.__text == "동료" end)
	clickWhere(function(f) return f.pet and not db.pets[f.pet.id] end)
end
S.rename = function() show("party") ns.OpenRename(db.party[2]) end

-- party
S.party = function() local p = show("party") p.sel = { hero = db.party[2] } p.filter = nil ns.Main.Refresh() end
S.party_bench = function()
	local p = show("party")
	for _, id in ipairs(ns.Heroes.List()) do
		if not ns.Heroes.PartySlot(id) and ns.Heroes.Role(id) == "DPS" then p.sel = { hero = id } end
	end
	p.filter = "DPS"
	ns.Main.Refresh()
end
S.party_slot = function()
	local p = show("party")
	p.saved = db.party[5]
	ns.Heroes.Withdraw(db.party[5])
	p.sel = { slot = 5 }
	ns.Main.Refresh()
end
S.party_dismiss = function()
	local p = show("party")
	if p.saved then ns.Heroes.Deploy(p.saved, 5) p.saved = nil end
	p.sel = { hero = db.party[3] }
	p.filter = nil
	ns.Main.Refresh()
	clickWhere(function(f) return f.label and f.label.__text == "떠나보내기" end)
end

-- hero
S.hero = function() local p = show("hero", { sub = "gear", hero = db.party[2] }) p.slot = nil ns.Main.Refresh() end
S.hero_slot = function()
	local p = show("hero", { sub = "gear", hero = db.party[2] })
	local id = db.party[2]
	ns.Items.AddToBag(ns.Items.New("ring", 34, 5))
	p.slot = "ring"
	ns.Main.Refresh()
end
S.hero_slot_empty = function()
	local p = show("hero", { sub = "gear", hero = db.party[2] })
	local h = db.heroes[db.party[2]]
	local empty
	for _, slot in ipairs(ns.SLOTS) do if not h.gear[slot] then empty = slot end end
	p.slot = empty or "oh"
	ns.Main.Refresh()
end
S.hero_sheet = function()
	show("hero", { sub = "gear", hero = db.party[2] })
	page("hero").slot = nil
	ns.Main.Refresh()
	page("hero").S.card.left:Click()
end
S.hero_skills = function() local p = show("hero", { sub = "skills", hero = db.party[2] }) p.skill = nil ns.Main.Refresh() end
S.hero_skill_locked = function()
	local p = show("hero", { sub = "skills", hero = db.party[2] })
	local list = ns.Heroes.SkillList(db.party[2])
	p.skill = list[#list]
	ns.Main.Refresh()
end
S.hero_tree = function() local p = show("hero", { sub = "tree", hero = db.party[2] }) p.node = nil ns.Main.Refresh() end
S.hero_tree_locked = function()
	local p = show("hero", { sub = "tree", hero = db.party[2] })
	p.node = { 8, 2 }
	ns.Main.Refresh()
end
S.hero_bench = function()
	local bench
	for _, id in ipairs(ns.Heroes.List()) do if not ns.Heroes.PartySlot(id) then bench = id end end
	show("hero", { sub = "gear", hero = bench })
end

-- bag
local function bestItem()
	local best
	for _, it in ipairs(db.bag) do
		if not best or it.q > best.q then best = it end
	end
	return best
end
S.bag = function() local p = show("bag") p.tab = "all" p.selItem = bestItem() ns.Main.Refresh() end
S.bag_tooltip = function()
	local p = show("bag")
	p.tab = "all"
	p.selItem = bestItem()
	ns.Main.Refresh()
	local cell = find(function(f) return f.data == db.bag[5] and f.tipFn end)
	if cell then cell.__scripts.OnEnter(cell) end
end
S.bag_locked = function() local p = show("bag") p.tab = "all" p.selItem = db.bag[3] ns.Main.Refresh() end
S.bag_weapon = function() local p = show("bag") p.tab = "weapon" p.selItem = nil ns.Main.Refresh() end
S.bag_mats = function() local p = show("bag") p.tab = "mats" p.selMat = "bar1" ns.Main.Refresh() end
S.bag_bank_empty = function() local p = show("bag") p.tab = "bank" p.selItem = nil ns.Main.Refresh() end
S.bag_bank = function()
	ns.Items.ToBank(1)
	ns.Items.ToBank(1)
	local p = show("bag")
	p.tab = "bank"
	p.selItem = nil
	ns.Main.Refresh()
end
S.bag_full = function()
	while #db.bag < ns.BagSize() do ns.Items.AddToBag(ns.Items.New("hands", 30, 3)) end
	local p = show("bag")
	p.tab = "all"
	p.selItem = db.bag[#db.bag]
	ns.Main.Refresh()
end

-- forge
S.forge_fuse = function() show("forge", { sub = "fuse" }) end
S.forge_fuse_ready = function()
	local p = show("forge", { sub = "fuse" })
	p.panels.fuse.q = 3
	ns.Main.Refresh()
end
S.forge_smelt = function() show("forge", { sub = "smelt" }) end
S.forge_craft = function() local p = show("forge", { sub = "craft" }) p.panels.craft.tier = 1 ns.Main.Refresh() end
S.forge_craft_locked = function() local p = show("forge", { sub = "craft" }) p.panels.craft.tier = 3 p.panels.craft.group = 7 ns.Main.Refresh() end
S.forge_craft_far = function() local p = show("forge", { sub = "craft" }) p.panels.craft.tier = 5 ns.Main.Refresh() end
S.forge_gem = function()
	show("forge", { sub = "gem" })
	clickWhere(function(f) return f.heroId and type(f.data) == "table" and f.data.q and f.data.q >= 3 end)
	clickWhere(function(f) return f.data == "gem3" end)
end
S.forge_ench = function() show("forge", { sub = "ench" }) end
S.forge_remove = function() show("forge", { sub = "remove" }) end
S.forge_seal = function() show("forge", { sub = "seal" }) end
S.forge_locked = function() show("forge", { sub = "insc" }) end

-- runes
S.runes = function() show("runes", { rune = "c5" }) end
S.runes_locked = function() show("runes", { rune = "w9" }) end
S.runes_total = function() show("runes") page("runes").totalBtn:Click() end

-- map
S.map = function() show("map") end
S.map_heroic = function()
	local p = show("map")
	p.diff, p.act, p.idx = 2, 2, 15
	ns.Main.Refresh()
end
S.map_raid = function()
	local p = show("map")
	p.diff, p.act, p.idx = 1, 3, 30
	ns.Main.Refresh()
end
S.map_locked = function()
	local p = show("map")
	p.diff, p.act, p.idx = 3, 1, 1
	ns.Main.Refresh()
end

-- settings
S.options = function() local p = show("options") p.tab = "screen" ns.Main.Refresh() end
S.options_game = function() local p = show("options") p.tab = "game" ns.Main.Refresh() end
S.options_info = function() local p = show("options") p.tab = "info" ns.Main.Refresh() end
S.options_reset = function()
	local p = show("options")
	p.tab = "info"
	ns.Main.Refresh()
	p.S.card.wide:Click()
end

-- a new player: no hero yet, then one hero
S.new_party = function()
	freshSave()
	ns.Main.Toggle(true)
	show("party")
end
S.new_hero = function() show("hero") end
S.new_bag = function() show("bag") end
S.new_forge = function() show("forge", { sub = "craft" }) end
S.new_one = function()
	ns.Heroes.Create("WARRIOR_PROT")
	show("party")
end
S.new_one_slot = function()
	local p = show("party")
	p.sel = { slot = 3 }
	ns.Main.Refresh()
end
S.new_one_hero = function() show("hero", { sub = "skills" }) end
S.new_map = function() show("map") end
S.new_runes = function() show("runes") end

return function(name)
	ns.UI.HideTip()
	ns.Main.CloseModal()
	if name ~= "bar" then ns.Main.Toggle(true) end
	local fn = S[name]
	if not fn then error("unknown scene " .. tostring(name)) end
	fn()
	Mock.Update(0.25)
end
