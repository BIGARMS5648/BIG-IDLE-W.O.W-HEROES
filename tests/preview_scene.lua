-- Builds a well-stocked save and returns a function that arranges one named
-- scene; tests/preview.py exports each scene, draws it, and checks its layout
-- (tests/layout_check.js). Scenes run in the order of preview.py's list: the
-- "new_" scenes come last and start from an empty save.
local ns = NS
local Mock = WoWMock

math.randomseed(4242)
BigWowIdleDB = nil
Mock.FireEvent("ADDON_LOADED", "BigIdleHeroes")
Mock.FireEvent("PLAYER_LOGIN")
ns.Main.CloseModal()

local db = ns.db
db.faction = "ALLIANCE"
ns.AddGold(123456789)
ns.Heroes.Create("PALADIN_PROT")
-- one step on the way to each (a rune named twice: two steps)
for _, id in ipairs({ 1, 10, 10, 10, 11, 11, 11, 1021, 101, 101, 20, 20, 20, 11001, 21, 11002, 25, 202, 302, 401 }) do
	local step = ns.Runes.NextStepTo(id)
	if step then ns.Runes.Buy(step) end
end
for _, sid in ipairs({ "MAGE_FIRE", "ROGUE_SUB", "HUNTER_MM", "PRIEST_DISC", "DRUID_RESTO", "SHAMAN_ENH", "WARRIOR_PROT", "PALADIN_HOLY" }) do ns.Heroes.Create(sid) end
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
	ns.Forge.Socket(it, "gem", ns.SocketMat("gem", 2))
	ns.Forge.Socket(it, "ench", ns.SocketMat("dust", 2))
end
db.prog = { 30, 14, 0, 0 }
db.stage = { diff = 1, idx = 26 }
db.kills = { beast = 5200, undead = 1300, humanoid = 2400, elemental = 2500 }
ns.CheckPets()
for t = 1, 3 do for _ = 1, 3 + t do ns.Loot.AddChest(t, 40, 2) end end
ns.Combat.StartStage()
for _ = 1, 260 do Mock.Update(0.1) end

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

-- the battle window on a Mythic stage
S.bar_mythic = function()
	local was = { db.stage.diff, db.stage.idx, db.prog[1], db.prog[2] }
	db.prog[1], db.prog[2] = 30, 30
	db.stage.diff, db.stage.idx = 3, 1
	ns.Combat.StartStage()
	S.bar()
	S.restore = function()
		db.stage.diff, db.stage.idx, db.prog[1], db.prog[2] = was[1], was[2], was[3], was[4]
		ns.Combat.StartStage()
	end
end

-- every chest opening by itself: a light runs round each box's border
S.bar_chest_auto = function()
	ns.Main.Toggle(false)
	local learnt = {}
	for _, rid in ipairs({ 13002, 15001, 1902001 }) do learnt[rid] = ns.db.runes[rid] ns.db.runes[rid] = 1 end
	ns.Runes.Invalidate()
	for _ = 1, 5 do Mock.Update(0.1) end
	S.restore = function()
		for rid, v in pairs(learnt) do ns.db.runes[rid] = v end
		ns.Runes.Invalidate()
		Mock.Update(0.05)
	end
end

-- the act boss chest's tooltip on the battle window
S.bar_chest_tip = function()
	ns.Main.Toggle(false)
	for _ = 1, 5 do Mock.Update(0.1) end
	local cb = BigIdleHeroesBar.chests[3]
	cb.__scripts.OnEnter(cb)
	S.restore = function() if cb.__scripts.OnLeave then cb.__scripts.OnLeave(cb) end end
end

-- the monster chest's tooltip: before its runes; with them, opening by
-- itself; with its auto-open stopped by a right-click
local function chestTipWith(runes, stop, t)
	ns.Main.Toggle(false)
	local learnt = {}
	for _, rid in ipairs({ 13002, 1021, 1055 }) do learnt[rid] = ns.db.runes[rid] ns.db.runes[rid] = runes and 1 or nil end
	ns.Runes.Invalidate()
	if ns.db.autoStop then ns.db.autoStop[1] = stop or nil end
	for _ = 1, 5 do Mock.Update(0.1) end
	local cb = BigIdleHeroesBar.chests[t or 1]
	cb.__scripts.OnEnter(cb)
	S.restore = function()
		if cb.__scripts.OnLeave then cb.__scripts.OnLeave(cb) end
		for rid, v in pairs(learnt) do ns.db.runes[rid] = v end
		if ns.db.autoStop then ns.db.autoStop[1] = nil end
		ns.Runes.Invalidate()
		Mock.Update(0.05)
	end
end
S.chest_tip_norune = function() chestTipWith(false) end
S.chest_tip_auto = function() chestTipWith(true) end
S.chest_tip_stop = function() chestTipWith(true, true) end
S.chest_tip_boss = function() chestTipWith(true, false, 2) end

-- the battle window during a boss fight, then after a wipe
S.bar_boss = function()
	ns.Main.Toggle(false)
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
S.create = function() show("hero") ns.CreateHeroDialog("PALADIN") end
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
-- the forge screen on one of its functions
local function forge(func, opts)
	local p = show("forge", opts)
	p.func = func or "fuse"
	ns.Main.Refresh()
	return p
end
S.equip = function() ns.Main.SelectHero(db.party[2]) equip("bag") end
S.equip_fuse = function() ns.db.opt.autoFuse, ns.db.ui.autoFuseQ = 5, 5 ns.Main.SelectHero(db.party[2]) equip("bag") end
S.equip_fuse_ready = function()
	db.bag = {}
	for _ = 1, 20 do local it = ns.Items.New("head", 20, 5) it.lock = nil ns.Items.AddToBag(it) end
	ns.db.ui.autoFuseQ = 5
	ns.Main.SelectHero(db.party[2]) equip("bag")
end
-- the item marks: level top left, the better-gear arrow top right, the
-- enhancement step bottom right (a protected one's lock bottom left)
S.equip_marks = function()
	local was = {}
	for i = 1, 6 do local it = db.bag[i] if it then was[i] = { it.up, it.lock } end end
	local steps = { 3, 10, 15, 20, nil, 7 }
	for i = 1, 6 do local it = db.bag[i] if it then it.up = steps[i] end end
	if db.bag[5] then db.bag[5].lock = true end
	local hero = db.heroes[db.party[2]]
	local lvl = hero.level
	hero.level = 40 -- (old enough for the bag's gear: some of it is better)
	ns.Stats.Invalidate(db.party[2])
	ns.Main.SelectHero(db.party[2])
	equip("bag")
	S.restore = function()
		hero.level = lvl
		ns.Stats.Invalidate(db.party[2])
		for i, w in pairs(was) do db.bag[i].up, db.bag[i].lock = w[1], w[2] end
		ns.Main.Refresh()
	end
end
S.equip_tooltip = function()
	local p = equip("bag")
	local cell = p.cells[5]
	if cell and cell.data then cell.__scripts.OnEnter(cell) end
end
-- a bag item's tooltip next to the item the chosen hero wears there
S.equip_compare = function()
	local id = db.party[2]
	ns.Main.SelectHero(id)
	local p = equip("bag")
	local h = db.heroes[id]
	-- an armour piece in a middle column, so both tooltips fit beside it
	for i, cell in ipairs(p.cells) do
		local it = cell.data
		if it and (i - 1) % 10 < 5 and it.s ~= "mh" and it.s ~= "oh" then
			if not h.gear[it.s] then
				h.gear[it.s] = ns.Items.New(it.s, 10, 2)
				ns.Main.Refresh()
			end
			cell.__scripts.OnEnter(cell)
			return
		end
	end
end
-- the top grade's tooltip: its name in the grade's running colours
S.equip_top_tip = function()
	local p = equip("bag")
	for _, cell in ipairs(p.cells) do
		if cell.data and cell.data.q == ns.MAX_QUALITY then cell.__scripts.OnEnter(cell) return end
	end
end
S.equip_slot = function() ns.Main.SelectHero(db.party[2]) equip("bag", { slot = "ring" }) end
S.equip_bank = function()
	while #db.bank < 6 and #db.bag > 0 do ns.Items.ToBank(#db.bag) end
	equip("bank")
end
-- an empty bag, an empty bank
S.equip_empty = function()
	local saved = db.bag
	db.bag = {}
	ns.Main.SelectHero(db.party[2])
	equip("bag")
	S.restore = function() db.bag = saved end
end
S.equip_bank_empty = function()
	local saved = db.bank
	db.bank = {}
	equip("bank")
	S.restore = function() db.bank = saved end
end
S.equip_smelt_list = function() local p = equip("bag") p.smeltPick:Click() end
S.equip_view_list = function() local p = equip("bag") p.viewPick:Click() end
S.equip_smelt_all = function() local p = equip("bag") p.smeltGo:Click() end
-- the largest bag: every bag rune, every slot full
S.equip_max = function()
	local keep = {}
	for id, node in pairs(ns.Runes.byId) do
		if node.stat == "bag" then keep[id] = db.runes[id] or false db.runes[id] = node.max end
	end
	ns.Runes.Invalidate()
	while #db.bag < ns.BagSize() do ns.Items.AddToBag(ns.Items.New("feet", 30, 2)) end
	local p = equip("bag")
	p.bagPage = 2
	ns.Main.Refresh()
	S.restore = function()
		for id, lv in pairs(keep) do db.runes[id] = lv or nil end
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
			-- 재사용 대기시간 감소 at TBH's top tier
			local _, hi = ns.SocketStat(100701, 10, ns.TBH.STAT_MODS[100701][10][2])
			local e = { "cdr", hi, 10, nil, 100701 }
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
	ns.Items.AddSocket(mixed, "gem", ns.SocketMat("gem", 4))
	ns.Items.AddSocket(mixed, "insc", ns.SocketMat("scroll", 6))
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
S.fuse = function() forge("fuse") end
S.fuse_ready = function()
	for _ = 1, 10 do ns.Items.AddToBag(ns.Items.New("hands", 24, 2)) end
	local p = forge("fuse")
	p.forge.fuse.q = 2
	ns.Main.Refresh()
end
S.fuse_list = function() local p = forge("fuse") p.forge.fuse.q = 2 ns.Main.Refresh() p.forge.fuse.pick:Click() end
S.fuse_high = function() local p = forge("fuse") p.forge.fuse.q = 6 p.forge.fuse.cat = "accessory" ns.Main.Refresh() end
S.craft = function() local p = forge("craft") p.forge.craft.tier = 1 ns.Main.Refresh() end
S.craft_locked = function() local p = forge("craft") p.forge.craft.tier = 3 p.forge.craft.group = #ns.CRAFT_GROUPS ns.Main.Refresh() end
S.craft_far = function() local p = forge("craft") p.forge.craft.tier = 5 ns.Main.Refresh() end
S.gem = function() mixedItem() ns.ForgeView.SetTarget(mixed) forge("gem") end
S.gem_stress = function() stressRing() ns.ForgeView.SetTarget(stress) forge("gem") end
S.ench = function() mixedItem() ns.ForgeView.SetTarget(mixed) forge("ench") end
S.smelt = function() forge("smelt") end
S.seal = function() forge("seal") end
-- a seal just rolled: the piece it gave under the seals
S.seal_rolled = function()
	local p = forge("seal")
	local it = ns.Items.New("chest", ns.Forge.SealLevel(), 5)
	ns.Items.AddToBag(it)
	p.forge.seal.result:Set(it, "낡은 행운의 인장")
	ns.Main.Refresh()
end
S.insc_locked = function() forge("insc") end
-- 강화: locked before the last difficulty is cleared; open with a piece at +12
local function setProg(n)
	local prog = ns.db.prog
	local was = { prog[1], prog[2], prog[3], prog[4] }
	for d = 1, #ns.DIFFS do prog[d] = n end
	S.restore = function() prog[1], prog[2], prog[3], prog[4] = was[1], was[2], was[3], was[4] end
end
S.up_locked = function() setProg(0) forge("up") end
S.up = function()
	setProg(ns.STAGE_COUNT)
	mixedItem()
	mixed.up = 12
	ns.ForgeView.SetTarget(mixed)
	ns.ForgeView.Log(ns.U.col("60e070", "강화 성공 +12") .. " · " .. ns.Items.Name(mixed))
	ns.ForgeView.Log(ns.U.col("ff6a5a", "강화 실패 +11") .. " · " .. ns.Items.Name(mixed))
	local p = forge("up")
	p.forge.up.last = ns.U.col("60e070", "성공! +12")
	ns.Main.Refresh()
end
-- 계승: a new chest at +0 picked, the enhanced one in the bag to move from
local function upMove()
	setProg(ns.STAGE_COUNT)
	local undo = S.restore
	mixedItem()
	local was = mixed.up
	mixed.up = 15
	local fresh = ns.Items.New("chest", 65, ns.MAX_QUALITY)
	table.insert(db.bag, 1, fresh)
	ns.ForgeView.SetTarget(fresh)
	local p = forge("up")
	ns.Main.Refresh()
	S.restore = function()
		undo()
		mixed.up = was
		local i = ns.Items.IndexInBag(fresh)
		if i then table.remove(db.bag, i) end
	end
	return p
end
S.up_move = function() upMove() end
S.up_move_confirm = function() local p = upMove() p.forge.up.move.btn:Click() end
-- 계승 onto a 전설 chest: no inscription socket there
S.up_move_lost = function()
	local p = upMove()
	local i = ns.Items.IndexInBag(p.forge.up.picked)
	local low = ns.Items.New("chest", 65, 5)
	db.bag[i] = low
	ns.ForgeView.SetTarget(low)
	ns.Main.Refresh()
	p.forge.up.move.btn:Click()
end
-- the strikes at a moment, and the result window after a try
local function upFx(ok, at)
	setProg(ns.STAGE_COUNT)
	local undo = S.restore
	mixedItem()
	local was = mixed.up
	mixed.up = ok and 13 or 12
	ns.ForgeView.SetTarget(mixed)
	forge("up")
	ns.Main.Refresh()
	local tf = _G.BigIdleHeroesToast
	if tf then for _, r in ipairs(tf.rows) do r:Hide() r.t = 0 end tf:Hide() end
	local fx = ns.ForgeView.UpFx
	fx.Play(mixed, ok, 12, ok and 13 or 12, function() end)
	if at then fx.Pose(at) else fx.Finish() end
	S.restore = function() fx.run = nil ns.Main.CloseModal() undo() mixed.up = was end
end
S.upfx = function() upFx(true, 0.46) end
S.upfx_ok = function() upFx(true) end
S.upfx_fail = function() upFx(false) end
S.mats = function() local p = forge("mats") p.matTab = "mat_craft" ns.Main.Refresh() end
S.mats_gem = function() local p = forge("mats") p.matTab = "mat_gem" ns.Main.Refresh() end
S.mats_seal = function() local p = forge("mats") p.matTab = "mat_seal" ns.Main.Refresh() end
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
	local p = forge("mats")
	p.matTab = "mat_seal"
	ns.Main.Refresh()
	S.restore = function() for id, n in pairs(had) do ns.AddMat(id, n) end end
end
S.mats_seal_locked = locked("seal", function() local p = forge("mats") ns.MatsView.Open(p, { tab = "mat_seal" }) ns.Main.Refresh() end)
S.seal_locked = locked("seal", function() forge("seal") end)
S.gem_remove_locked = locked("remove", function() forge("gem") end)
S.bag_smelt_locked = locked("smelt", function() ns.Main.SelectHero(db.party[2]) equip("bag") end)

S.mats_page2 = function() local p = forge("mats") p.matTab = "mat_craft" p.matPage = 2 ns.Main.Refresh() end

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
S.runes = function() show("runes", { rune = 11 }) end
S.runes_locked = function() show("runes", { rune = 12821 }) end
S.runes_start = function() db.runes = { [1] = 1 } ns.Runes.Invalidate() show("runes", { rune = 1 }) end
-- zoomed all the way out: the whole tree in the box
S.runes_far = function()
	show("runes")
	local p = ns.Main.Page("runes")
	for _ = 1, 30 do p.zoomAt(-1) end
	S.restore = function() p.cam.z = 1 p.centerOn(ns.RUNE_FIRST) end
end
-- the whole tree zoomed out with every rune learned: each kind in its colour
S.runes_far_full = function()
	local saved = {}
	for id, lv in pairs(db.runes) do saved[id] = lv end
	for id, node in pairs(ns.Runes.byId) do db.runes[id] = node.max end
	ns.Runes.Invalidate()
	show("runes", { rune = ns.RUNE_FIRST })
	local p = ns.Main.Page("runes")
	for _ = 1, (S.runesZoomOut or 30) do p.zoomAt(-1) end
	S.restore = function()
		for id in pairs(db.runes) do db.runes[id] = nil end
		for id, lv in pairs(saved) do db.runes[id] = lv end
		ns.Runes.Invalidate()
		p.cam.z = 1 p.centerOn(ns.RUNE_FIRST)
	end
end
-- the same at the map's usual zoom, round the first rune
S.runes_near_full = function() S.runesZoomOut = 0 S.runes_far_full() S.runesZoomOut = nil end

-- 스테이지
-- the 전투 kind checked under the map: its runes stand out
S.runes_kind = function()
	show("runes", { rune = 11 })
	local page = ns.Main.Page("runes")
	for _, bt in ipairs(page.kindBoxes) do if bt.key == "fight" then bt:Click() end end
	S.restore = function() for _, bt in ipairs(page.kindBoxes) do if bt.key == "fight" then bt:Click() end end end
end
-- every rune learned: the 보너스 합계 list is longer than its box and scrolls
S.runes_full = function()
	local saved = {}
	for id, lv in pairs(db.runes) do saved[id] = lv end
	for id, node in pairs(ns.Runes.byId) do db.runes[id] = node.max end
	ns.Runes.Invalidate()
	show("runes")
	local p = ns.Main.Page("runes")
	p.scrollTotal(S.runesOff or 14)
	S.restore = function()
		for id in pairs(db.runes) do db.runes[id] = nil end
		for id, lv in pairs(saved) do db.runes[id] = lv end
		p.totalOff = 0
		ns.Runes.Invalidate()
	end
end
S.runes_full_end = function() S.runesOff = 999 S.runes_full() S.runesOff = nil end
S.map = function() show("map") end
-- hovering the Mythic world card
S.map_mythic_tip = function()
	local p = show("map")
	p.worlds[3].__scripts.OnEnter(p.worlds[3])
end
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
-- the endless tower, still closed: its card and the first floor
S.map_tower_locked = function()
	local p = show("map")
	p.tower, p.floor = true, 1
	ns.Main.Refresh()
end
-- the tower open: the best floor 12, fighting on floor 13 (two affixes)
local function towerOn(best, f)
	local was = { db.prog[1], db.prog[2], db.prog[3], db.prog[4] }
	local wasT = { on = db.tower.on, floor = db.tower.floor, best = db.tower.best }
	db.prog = { 30, 30, 30, 30 }
	db.tower.best = best
	ns.Combat.EnterTower(f)
	return function()
		db.prog = { was[1], was[2], was[3], was[4] }
		db.tower.on, db.tower.floor, db.tower.best = wasT.on, wasT.floor, wasT.best
		ns.Combat.StartStage()
	end
end
S.map_tower = function()
	local undo = towerOn(12, 13)
	show("map")
	S.restore = undo
end
-- a raid floor, every affix
S.map_tower_raid = function()
	local undo = towerOn(59, 60)
	show("map")
	S.restore = undo
end
-- runes and a companion that raise the boss chests
local function bossBonus()
	local wasPet = db.pets.skull
	db.pets.skull = true
	local set = {}
	for _, id in ipairs({ 102, 106 }) do
		set[id] = db.runes[id] or false
		db.runes[id] = ns.Runes.byId[id].max
	end
	ns.Runes.Invalidate()
	local wasRate = { db.rate.gold, db.rate.xp }
	db.rate.gold, db.rate.xp = 41.7, 12.5
	return function()
		db.rate.gold, db.rate.xp = wasRate[1], wasRate[2]
		db.pets.skull = wasPet
		for id, v in pairs(set) do db.runes[id] = v or nil end
		ns.Runes.Invalidate()
	end
end
S.map_bonus = function()
	local undo = bossBonus()
	local p = show("map")
	p.diff, p.act, p.idx = 1, 3, 22
	ns.Main.Refresh()
	S.restore = undo
end
S.map_tower_bonus = function()
	local undo = towerOn(12, 13)
	local undo2 = bossBonus()
	show("map")
	S.restore = function() undo2() undo() end
end
-- the battle window on a floor of the tower
S.bar_tower = function()
	local undo = towerOn(12, 13)
	ns.Main.Toggle(false)
	for _ = 1, 30 do Mock.Update(0.1) end
	S.restore = function() undo() ns.Main.Toggle(true) end
end

-- 동료
S.pets = function() local p = show("pets") p.sel = nil ns.Main.Refresh() end
S.pets_locked = function() local p = show("pets") p.sel = ns.PETS[#ns.PETS].id ns.Main.Refresh() end

-- 설정
S.options = function() show("options") ns.Main.Refresh() end
S.options_reset = function()
	local p = show("options")
	ns.Main.Refresh()
	p.game.reset:Click()
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
