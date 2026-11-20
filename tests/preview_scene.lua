-- Builds a well-stocked save and returns a function that arranges one named
-- scene; tests/preview.py exports each scene and draws it.
local ns = NS
local Mock = WoWMock

math.randomseed(4242)
BigIdleWoWHeroesDB = nil
Mock.FireEvent("ADDON_LOADED", "BigIdleWoWHeroes")
Mock.FireEvent("PLAYER_LOGIN")

local db = ns.db
ns.AddGold(123456789)
ns.Heroes.Unlock("WARRIOR")
for _, id in ipairs({ "root", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "w1", "w1", "w2", "g1", "m1", "x1", "e1", "e2", "e3" }) do ns.Runes.Buy(id) end
for _, id in ipairs({ "HUNTER", "MAGE", "ROGUE", "PRIEST", "DRUID", "SHAMAN" }) do ns.Heroes.Unlock(id) end
for id in pairs(db.heroes) do ns.Heroes.AddXP(id, 2.5e6) end
db.forge.level = 32
db.forge.xp = 21000
for _, op in ipairs(ns.FORGE_OPS) do ns.Forge.Unlock(op.key) end
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
		local c = ns.CLASSES[id]
		for t = 1, 4 do
			for n = 1, #c.tree[t] do
				for _ = 1, 3 do ns.Heroes.SpendPoint(id, t, n) end
			end
		end
	end
end
db.prog = { 30, 14, 0, 0 }
db.stage = { diff = 2, idx = 15 }
db.kills = { beast = 5200, undead = 1300, humanoid = 2400, elemental = 2500 }
ns.CheckPets()
for t = 1, 3 do for _ = 1, 3 + t do ns.Loot.AddChest(t, 40, 2) end end
ns.Combat.StartStage()
for _ = 1, 260 do Mock.Update(0.1) end

local function hoverFirst(pred)
	for _, f in ipairs(Mock.frames) do
		if f:IsVisible() and f.__scripts.OnEnter and pred(f) then
			f.__scripts.OnEnter(f)
			return true
		end
	end
end

return function(name)
	ns.UI.HideTip()
	if name == "bar" then
		ns.Main.Toggle(false)
		for _ = 1, 30 do Mock.Update(0.1) end
		ns.Toast(ns.T("첫 공략! 2-5 버섯구름 봉우리 (+12,345 골드, 궤짝 1개)", "First clear! 2-5 Thousand Needles (+12,345 gold, 1 cache)"))
		Mock.Update(0.05)
		return
	end
	ns.Main.Toggle(true)
	ns.Main.SelectHero("WARRIOR")
	if name == "bag_tooltip" then
		ns.Main.ShowTab("bag")
		hoverFirst(function(f) return f.data and type(f.data) == "table" and f.data.q and f.data.q >= 6 end)
	elseif name == "hero_tooltip" then
		ns.Main.ShowTab("hero")
		hoverFirst(function(f) return f.tier == 1 and f.n == 3 end)
	elseif name:sub(1, 6) == "forge_" then
		ns.Main.ShowTab("forge")
		local op = name:sub(7)
		for _, b in ipairs(Mock.VisibleButtons()) do
			if b.label and b.__w == 170 then
				for _, d in ipairs(ns.FORGE_OPS) do
					if d.key == op and b.label.__text == ns.N(d.name) then b:Click("LeftButton") end
				end
			end
		end
		if op == "gem" or op == "remove" then
			for _, b in ipairs(Mock.VisibleButtons()) do
				if b.icon and type(b.data) == "table" and b.heroId then b:Click("LeftButton") break end
			end
		end
	else
		ns.Main.ShowTab(name)
	end
	Mock.Update(0.2)
end
