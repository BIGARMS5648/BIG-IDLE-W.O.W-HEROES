-- Builds a well-stocked save and returns a function that arranges one named
-- scene; tests/preview.py exports each scene, draws it, and checks its layout
-- (tests/layout_check.js). Scenes run in the order of preview.py's list: the
-- "new_" scenes come last and start from an empty save.
local ns = NS
local Mock = WoWMock

math.randomseed(4242)
BigWowIdleDB = nil
Mock.FireEvent("ADDON_LOADED", "BigWowIdle")
Mock.FireEvent("PLAYER_LOGIN")
ns.Main.CloseModal()

local db = ns.db
db.faction = "ALLIANCE"
ns.AddGold(123456789)
ns.Heroes.Create("TINKER_MECH")
for _, id in ipairs({ "root", "c1", "c2", "c3", "c6", "c4", "c5", "c7", "w1", "w1", "w2", "g1", "m1", "x1", "e1", "e2", "e3" }) do ns.Runes.Buy(id) end
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

-- the battle window during a boss fight, then after a wipe
S.bar_boss = function()
	ns.Main.Toggle(false)
	local st = ns.Combat.state
	for _ = 1, 6000 do
		local up
		for _, m in ipairs(ns.Combat.mobs) do if m.boss and not m.dead then up = true end end
		if up then break end
		Mock.Update(0.1)
	end
	Mock.Update(0.05)
end
S.bar_wipe = function()
	ns.Main.Toggle(false)
	local st = ns.Combat.state
	-- a wipe in the middle of a boss fight
	S.bar_boss()
	st.phase, st.result, st.timer = "result", "lose", 2.5
	Mock.Update(0.05)
end

-- the battle window made small (no dock), and the offline report after logging in
S.bar_compact = function()
	ns.Main.Toggle(false)
	ns.db.ui.compact = true
	ns.Bar.ApplyCompact()
	Mock.Update(0.1)
	S.restore = function() ns.db.ui.compact = nil ns.Bar.ApplyCompact() end
end
S.offline = function()
	show("hero")
	local f = ns.ShowOffline({ away = 9 * 3600 + 1234, counted = 8 * 3600, eff = 0.75, gold = 1234567, xp = 98765, levels = 3 })
	S.restore = function() f:Hide() end
end

-- modals
S.faction = function() show("hero") ns.PickFaction() end
S.create = function() show("hero") ns.CreateHeroDialog("TINKER") end
S.create_druid = function() show("hero") ns.CreateHeroDialog("DRUID", "HEALER") end
S.rename = function() show("hero") ns.OpenRename(db.party[2]) end

-- 영웅
S.hero = function() local p = show("hero", { hero = db.party[2] }) p.sub = "stats" ns.Main.Refresh() end
-- hovering 원소 저항: each element's resistance
S.hero_res_tip = function()
	local p = show("hero", { hero = db.party[2] })
	p.sub = "stats"
	ns.Main.Refresh()
	for _, g in ipairs(p.groups) do
		for _, row in ipairs(g.rows) do
			if row.tip and row:IsShown() then row.hover = true row.__scripts.OnEnter(row) return end
		end
	end
end
S.hero_skills = function() local p = show("hero", { hero = db.party[2] }) p.sub = "skills" ns.Main.Refresh() end
S.hero_tree = function() local p = show("hero", { hero = db.party[2] }) p.sub = "tree" ns.Main.Refresh() end
S.hero_bench = function()
	local id
	for _, h in ipairs(ns.Heroes.List()) do if not ns.Heroes.PartySlot(h) then id = h end end
	local p = show("hero", { hero = id })
	p.sub = "stats"
	ns.Main.Refresh()
end
S.hero_tank = function() local p = show("hero", { hero = db.party[1] }) p.sub = "tree" ns.Main.Refresh() end
S.hero_reset = function()
	local p = show("hero", { hero = db.party[2] })
	p.sub = "skills"
	ns.Main.Refresh()
	p.resetSkills:Click()
end
S.hero_dismiss = function() local p = show("hero", { hero = db.party[3] }) p.sub = "stats" ns.Main.Refresh() p.head.dismiss:Click() end
S.hero_scroll = function()
	local p = show("hero", { hero = db.party[2] })
	p.list.__scripts.OnMouseWheel(p.list, -1)
	ns.Main.Refresh()
end

-- 장비
local function equip(tab, opts)
	local p = show("equip", opts)
	p.tab = tab or "bag"
	if p.tab == "bag" and not (opts and (opts.slot or opts.view)) then p.view = "all" end
	ns.Main.Refresh()
	return p
end
S.equip = function() ns.Main.SelectHero(db.party[2]) equip("bag") end
S.equip_tooltip = function()
	local p = equip("bag")
	local cell = p.cells[5]
	if cell and cell.data then cell.__scripts.OnEnter(cell) end
end
S.equip_slot = function() ns.Main.SelectHero(db.party[2]) equip("bag", { slot = "ring" }) end
S.equip_bank = function()
	while #db.bank < 6 and #db.bag > 0 do ns.Items.ToBank(#db.bag) end
	equip("bank")
end
S.equip_smelt_list = function() local p = equip("bag") p.smeltPick:Click() end
S.equip_view_list = function() local p = equip("bag") p.viewPick:Click() end
S.equip_smelt_all = function() local p = equip("bag") p.smeltGo:Click() end
-- the largest bag: every bag rune, every slot full
S.equip_max = function()
	local keep = { c2 = db.runes.c2, c8 = db.runes.c8 }
	db.runes.c2, db.runes.c8 = 5, 5
	ns.Runes.Invalidate()
	while #db.bag < ns.BagSize() do ns.Items.AddToBag(ns.Items.New("feet", 30, 2)) end
	local p = equip("bag")
	p.bagPage = 2
	ns.Main.Refresh()
	S.restore = function()
		db.runes.c2, db.runes.c8 = keep.c2, keep.c8
		ns.Runes.Invalidate()
		while #db.bag > ns.BagSize() do table.remove(db.bag) end
	end
end
-- a ring with every socket filled with the longest socket stat there is
local stress
local function stressRing()
	if stress then return stress end
	stress = ns.Items.New("ring", 60, ns.MAX_QUALITY)
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		local l = ns.Items.SocketList(stress, kind, true)
		for _ = 1, ns.Items.SocketCount(stress, kind) do
			local e = { "cdr", 0, #ns.SOCKET_TIER_MULT }
			local _, hi = ns.Items.SocketRange(stress, kind, e)
			e[2] = hi
			l[#l + 1] = e
		end
	end
	table.insert(db.bag, 1, stress)
	return stress
end
-- a top-grade chest piece: one gem and one inscription set, the rest empty
local mixed
local function mixedItem()
	if mixed then return mixed end
	mixed = ns.Items.New("chest", 58, ns.MAX_QUALITY)
	ns.Items.AddSocket(mixed, "gem", 4)
	ns.Items.AddSocket(mixed, "insc", 6)
	table.insert(db.bag, 2, mixed)
	return mixed
end
local function tipOf(p, it)
	for _, c in ipairs(p.cells) do
		if c.data == it then c.__scripts.OnEnter(c) return end
	end
end
S.equip_sockets_tip = function() stressRing() local p = equip("bag") tipOf(p, stress) end
S.equip_mixed_tip = function() mixedItem() local p = equip("bag") tipOf(p, mixed) end
S.equip_slot_tip = function()
	local p = equip("bag")
	local b = p.slots.chest
	b.__scripts.OnEnter(b)
end
S.fuse = function() equip("fuse") end
S.fuse_ready = function()
	for _ = 1, 10 do ns.Items.AddToBag(ns.Items.New("hands", 24, 2)) end
	local p = equip("fuse")
	p.forge.fuse.q = 2
	ns.Main.Refresh()
end
S.fuse_list = function() local p = equip("fuse") p.forge.fuse.q = 2 ns.Main.Refresh() p.forge.fuse.pick:Click() end
S.fuse_high = function() local p = equip("fuse") p.forge.fuse.q = 6 p.forge.fuse.cat = "accessory" ns.Main.Refresh() end
S.craft = function() local p = equip("craft") p.forge.craft.tier = 1 ns.Main.Refresh() end
S.craft_locked = function() local p = equip("craft") p.forge.craft.tier = 3 p.forge.craft.group = #ns.CRAFT_GROUPS ns.Main.Refresh() end
S.craft_far = function() local p = equip("craft") p.forge.craft.tier = 5 ns.Main.Refresh() end
S.gem = function() mixedItem() local p = equip("gem") p.forge.gem.picked = mixed ns.Main.Refresh() end
S.gem_stress = function() stressRing() local p = equip("gem") p.forge.gem.picked = stress ns.Main.Refresh() end
S.ench = function() mixedItem() local p = equip("ench") p.forge.ench.picked = mixed ns.Main.Refresh() end
S.insc_locked = function() equip("insc") end
S.mats = function() local p = equip("mats") p.matTab = "mat_craft" ns.Main.Refresh() end
S.mats_gem = function() local p = equip("mats") p.matTab = "mat_gem" ns.Main.Refresh() end
S.mats_seal = function() local p = equip("mats") p.matTab = "mat_seal" ns.Main.Refresh() end
-- functions used inside other tabs, still locked: their buttons unlock them
local function locked(op, fn)
	return function()
		local was = ns.db.forge.ops[op]
		ns.db.forge.ops[op] = nil
		fn()
		S.restore = function() ns.db.forge.ops[op] = was end
	end
end
-- only some seals in the bag: only those have a row
S.mats_seal_some = function()
	local had = {}
	for _, id in ipairs({ "seal2", "seal4" }) do had[id] = ns.MatCount(id) ns.AddMat(id, -had[id]) end
	local p = equip("mats")
	p.matTab = "mat_seal"
	ns.Main.Refresh()
	S.restore = function() for id, n in pairs(had) do ns.AddMat(id, n) end end
end
S.mats_seal_locked = locked("seal", function() local p = equip("mats") ns.MatsView.Open(p, { tab = "mat_seal" }) ns.Main.Refresh() end)
S.gem_remove_locked = locked("remove", function() equip("gem") end)
S.bag_smelt_locked = locked("smelt", function() ns.Main.SelectHero(db.party[2]) equip("bag") end)

S.mats_page2 = function() local p = equip("mats") p.matTab = "mat_craft" p.matPage = 2 ns.Main.Refresh() end

-- 편성
S.party = function() local p = show("party") p.selSlot = nil ns.Main.Refresh() end
S.party_open = function()
	local p = show("party")
	if db.party[5] then ns.Heroes.Withdraw(db.party[5]) end
	p.selSlot = 5
	ns.Main.Refresh()
	S.restore = function()
		for _, id in ipairs(ns.Heroes.List()) do
			if not ns.Heroes.PartySlot(id) and ns.Heroes.Role(id) == "HEALER" and not db.party[5] then ns.Heroes.Deploy(id, 5) end
		end
	end
end

-- 룬
S.runes = function() show("runes", { rune = "c5" }) end
S.runes_locked = function() show("runes", { rune = "w9" }) end

-- 스테이지
-- the 3D model check (/bwi model); the models themselves are empty boxes here
S.model_check = function()
	ns.ModelCheck.Toggle(true)
	S.restore = function() ns.ModelCheck.Toggle(false) end
end
-- the model check's battle look and dressing pages
S.model_check_battle = function()
	ns.ModelCheck.Toggle(true)
	ns.ModelCheck.ShowSet("battle")
	S.restore = function() ns.ModelCheck.ShowSet("basic") ns.ModelCheck.Toggle(false) end
end
S.model_check_dress = function()
	ns.ModelCheck.Toggle(true)
	ns.ModelCheck.ShowSet("dress")
	S.restore = function() ns.ModelCheck.ShowSet("basic") ns.ModelCheck.Toggle(false) end
end
-- every rune learned: the 보너스 합계 list is longer than its box and scrolls
S.runes_full = function()
	local saved = {}
	for id, lv in pairs(db.runes) do saved[id] = lv end
	for id, node in pairs(ns.Runes.byId) do db.runes[id] = node.max end
	ns.Runes.Invalidate()
	show("runes")
	local p = ns.Main.Page("runes")
	p.scrollTotal(4)
	S.restore = function()
		for id in pairs(db.runes) do db.runes[id] = nil end
		for id, lv in pairs(saved) do db.runes[id] = lv end
		p.totalOff = 0
		ns.Runes.Invalidate()
	end
end
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

-- 동료
S.pets = function() local p = show("pets") p.sel = nil ns.Main.Refresh() end
S.pets_locked = function() local p = show("pets") p.sel = ns.PETS[#ns.PETS].id ns.Main.Refresh() end

-- 설정
S.options = function() local p = show("options") p.tab = "screen" ns.Main.Refresh() end
S.options_game = function() local p = show("options") p.tab = "game" ns.Main.Refresh() end
S.options_info = function() local p = show("options") p.tab = "info" ns.Main.Refresh() end
S.options_reset = function()
	local p = show("options")
	p.tab = "info"
	ns.Main.Refresh()
	p.info.reset:Click()
end

-- a new player: no hero yet, then one hero
S.new_hero = function()
	freshSave()
	ns.Main.Toggle(true)
	show("hero")
end
S.new_equip = function() show("equip") end
S.new_mats = function() local p = show("equip") p.tab = "mats" ns.Main.Refresh() p.tab = "bag" end
S.new_party = function() show("party") end
-- the very first hero: the dialog opens by itself, a tank is recommended
S.new_create = function() show("hero", { create = true }) end
S.new_one = function()
	ns.Heroes.Create("WARRIOR_PROT")
	show("hero")
end
S.new_one_skills = function() local p = show("hero") p.sub = "skills" ns.Main.Refresh() p.sub = "stats" end
S.new_one_equip = function() show("equip") end
S.new_one_party = function() show("party") end
S.new_map = function() show("map") end
S.new_runes = function() show("runes") end
S.new_pets = function() show("pets") end

return function(name)
	ns.UI.HideTip()
	-- the mouse leaves whatever an earlier scene pointed at
	for _, f in ipairs(Mock.frames) do
		if f.hover and f.__scripts and f.__scripts.OnLeave then f.__scripts.OnLeave(f) end
	end
	ns.Main.CloseModal()
	if name ~= "bar" then ns.Main.Toggle(true) end
	if S.restore then S.restore() S.restore = nil end
	local fn = S[name]
	if not fn then error("unknown scene " .. tostring(name)) end
	fn()
	Mock.Update(0.25)
end
