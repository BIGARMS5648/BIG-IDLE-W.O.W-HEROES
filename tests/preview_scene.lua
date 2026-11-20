-- Builds a well-stocked save and returns a function that arranges one named
-- scene; tests/preview.py exports each scene and draws it.
local ns = NS
local Mock = WoWMock

math.randomseed(4242)
BigIdleWoWHeroesDB = nil
Mock.FireEvent("ADDON_LOADED", "BigIdleWoWHeroes")
Mock.FireEvent("PLAYER_LOGIN")
ns.Main.CloseModal()

local db = ns.db
ns.AddGold(123456789)
ns.Heroes.Create("WARRIOR_PROT")
for _, id in ipairs({ "root", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "w1", "w1", "w2", "g1", "m1", "x1", "e1", "e2", "e3" }) do ns.Runes.Buy(id) end
for _, sid in ipairs({ "MAGE_FIRE", "ROGUE_SUB", "HUNTER_BM", "PRIEST_DISC", "DRUID_RESTO", "SHAMAN_ENH" }) do ns.Heroes.Create(sid) end
for id in pairs(db.heroes) do ns.Heroes.AddXP(id, 2.5e6) end
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
		-- leave a few points so the badges show
		db.heroes[id].level = db.heroes[id].level + (slot == 2 and 3 or 0)
	end
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

return function(name)
	ns.UI.HideTip()
	ns.Main.CloseModal()
	if name == "bar" then
		ns.Main.Toggle(false)
		for _ = 1, 30 do Mock.Update(0.1) end
		ns.Toast(ns.T("첫 공략! 3-6 저주받은 땅 (+12,345 골드, 궤짝 1개)", "First clear! 3-6 Blasted Lands (+12,345 gold, 1 cache)"))
		Mock.Update(0.05)
		return
	end
	ns.Main.Toggle(true)
	local sel = db.party[2]
	ns.Main.SelectHero(sel)
	if name == "create" then
		ns.Main.ShowTab("party")
		ns.CreateHeroDialog("DRUID")
	elseif name == "created" then
		ns.Main.ShowTab("party")
		ns.CreateHeroDialog("SHAMAN")
		local go = find(function(f) return f.label and f.__w == 200 and f.__h == 38 end)
		local card = find(function(f) return f.sid == "SHAMAN_ELE" end)
		if card then card:Click() end
		if go then go:Click() end
	elseif name == "hero" or name == "hero_tree" or name == "hero_skills" then
		local sub = (name == "hero_tree" and "tree") or (name == "hero_skills" and "skills") or "gear"
		ns.Main.ShowTab("hero", { sub = sub })
	elseif name == "bag" or name == "bag_tooltip" then
		ns.Main.ShowTab("bag")
		local page = ns.Main.Page("bag")
		local best
		for _, it in ipairs(db.bag) do
			if not best or it.q > best.q then best = it end
		end
		page.selItem = best
		ns.Main.Refresh()
		if name == "bag_tooltip" then
			local cell = find(function(f) return f.data == db.bag[5] and f.tipFn end)
			if cell then cell.__scripts.OnEnter(cell) end
		end
	elseif name:sub(1, 6) == "forge_" then
		ns.Main.ShowTab("forge", { sub = name == "forge_locked" and "insc" or name:sub(7) })
		if name == "forge_gem" then
			local cell = find(function(f) return f.heroId and type(f.data) == "table" and f.data.q and f.data.q >= 3 end)
			if cell then cell:Click() end
			local mat = find(function(f) return f.data == "gem3" end)
			if mat then mat:Click() end
		end
	elseif name == "map_heroic" then
		ns.Main.ShowTab("map")
		local page = ns.Main.Page("map")
		page.diff, page.act, page.idx = 2, 2, 15
		ns.Main.Refresh()
	else
		ns.Main.ShowTab(name)
		if name == "runes" then
			local page = ns.Main.Page("runes")
			page.sel = "c5"
			ns.Main.Refresh()
		end
	end
	Mock.Update(0.25)
end
