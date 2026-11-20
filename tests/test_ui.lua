-- UI smoke test: start the addon the way the game does, open every page,
-- hover everything that has a tooltip and click buttons at random.
local ns = NS
local Mock = WoWMock
local failures = 0

local function fail(msg)
	failures = failures + 1
	print("  FAIL: " .. msg)
end

-- Lua 5.1's xpcall takes no extra arguments, so wrap the call.
local function try(what, fn, ...)
	local n = select("#", ...)
	local args = { ... }
	local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e) return debug.traceback(tostring(e), 2) end)
	if not ok then fail(what .. "\n" .. tostring(err)) end
	return ok
end

math.randomseed(777)
BigIdleWoWHeroesDB = nil

-- start-up sequence
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "SomeOtherAddon")
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "BigIdleWoWHeroes")
try("PLAYER_LOGIN", Mock.FireEvent, "PLAYER_LOGIN")
if not ns.db then
	fail("saved variables were not initialised")
	return false
end
if not ns.Main.IsShown() then fail("the menu should open by itself for a new player") end
if ns.Main.Current() ~= "party" then fail("a new player should land on the Party page") end
if not SlashCmdList.BIGIDLEWOWHEROES then fail("slash command missing") end
if type(BigIdleWoWHeroes_OnAddonCompartmentClick) ~= "function" then fail("addon compartment function missing") end

local function frames(n, dt)
	for _ = 1, n do
		if not try("OnUpdate", Mock.Update, dt or 0.1) then return false end
	end
	return true
end

local function hoverAll()
	local list = {}
	for _, f in ipairs(Mock.frames) do list[#list + 1] = f end
	for _, f in ipairs(list) do
		if f:IsVisible() and f.__scripts.OnEnter then
			if not try("hover", Mock.Hover, f) then return false end
		end
	end
	return true
end

local tabs = { "party", "hero", "bag", "forge", "runes", "map", "options" }
-- the forge has by far the most controls, so the random clicking visits it more often
local clickTabs = { "party", "hero", "bag", "forge", "forge", "forge", "runes", "map", "options", "bag" }

-- an empty save: every page must render without a hero
for _, key in ipairs(tabs) do
	try("show tab " .. key .. " (empty save)", ns.Main.ShowTab, key)
	hoverAll()
end
frames(20)

-- recruit the first hero through the UI and let the fight run
try("show party", ns.Main.ShowTab, "party")
do
	local clicked = false
	for _, b in ipairs(Mock.VisibleButtons()) do
		if b.classId == "HUNTER" and b.label then
			try("recruit", b.Click, b, "LeftButton")
			clicked = true
			break
		end
	end
	if not clicked then fail("recruit button not found") end
end
if not ns.db.heroes.HUNTER then fail("recruiting through the UI did not work") end
frames(300)
if ns.db.stat.kills == 0 then fail("the battle should run once a hero is recruited") end

-- a rich save so that every page has something to show.
-- (The reset button replaces the saved table, so always go through ns.db.)
local function enrich(round)
	local db = ns.db
	if db.gold < 1e9 then ns.AddGold(5e9) end
	if ns.Heroes.Count() == 0 then ns.Heroes.Unlock("MAGE") end
	if #db.bag < 12 then
		for i = 1, 20 do ns.Items.AddToBag(ns.Items.New(ns.SLOTS[(i % #ns.SLOTS) + 1], 10 + i, 1 + (i + round) % ns.MAX_QUALITY)) end
	end
	if ns.MatCount("gem1") < 5 then
		for _, id in ipairs(ns.MAT_ORDER) do ns.AddMat(id, 30) end
	end
	if db.forge.level < 70 then db.forge.level = 70 end
	for _, op in ipairs(ns.FORGE_OPS) do
		if not ns.Forge.Unlocked(op.key) and round % 3 ~= 0 then ns.Forge.Unlock(op.key) end
	end
	for t = 2, #ns.CRAFT_TIERS do
		if not ns.Forge.CraftTierUnlocked(t) and round % 4 == 1 then ns.Forge.UnlockCraftTier(t) end
	end
	if ns.Loot.Count() == 0 then
		for t = 1, 3 do ns.Loot.AddChest(t, 30, 2) end
	end
end
local db = ns.db
ns.AddGold(5e9)
for _, id in ipairs({ "root", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "e1", "e2", "e3" }) do ns.Runes.Buy(id) end
for _, id in ipairs(ns.CLASS_ORDER) do
	if not db.heroes[id] then ns.Heroes.Unlock(id) end
	ns.Heroes.AddXP(id, 3e6)
end
db.forge.level = 40
for i = 1, 40 do
	ns.Items.AddToBag(ns.Items.New(ns.SLOTS[(i % #ns.SLOTS) + 1], 20 + i % 15, 1 + i % ns.MAX_QUALITY))
end
for _, id in ipairs(ns.MAT_ORDER) do ns.AddMat(id, 30) end
for t = 1, 3 do for _ = 1, 4 do ns.Loot.AddChest(t, 25, 1) end end
db.prog = { 30, 12, 0, 0 }
db.kills = { beast = 6000, undead = 100 }
ns.CheckPets()
frames(50)

for _, key in ipairs(tabs) do
	try("show tab " .. key, ns.Main.ShowTab, key)
	frames(3)
	hoverAll()
end

-- walk through each forge operation the way a player would
local function clickLabel(ko, en, mouse)
	local text = ns.T(ko, en)
	for _, b in ipairs(Mock.VisibleButtons()) do
		local t = b.label and b.label.__text
		if t and t:find(text, 1, true) then
			try("click " .. text, b.Click, b, mouse or "LeftButton")
			return true
		end
	end
	fail("button not found: " .. text)
	return false
end
-- exact label, optionally a specific button width (operation buttons are 170 wide, actions 150)
local function clickExact(ko, en, width)
	local text = ns.T(ko, en)
	for _, b in ipairs(Mock.VisibleButtons()) do
		if b.label and b.label.__text == text and (not width or b.__w == width) then
			try("click " .. text, b.Click, b, "LeftButton")
			return true
		end
	end
	fail("button not found: " .. text)
	return false
end
local function clickIcon(pred, what)
	for _, b in ipairs(Mock.VisibleButtons()) do
		if b.icon and b.data ~= nil and pred(b) then
			try("click icon " .. what, b.Click, b, "LeftButton")
			return true
		end
	end
	fail("icon not found: " .. what)
	return false
end
do
	local F = ns.Forge
	for _, op in ipairs(ns.FORGE_OPS) do if not F.Unlocked(op.key) then F.Unlock(op.key) end end
	ns.db.bag = {}
	for _ = 1, 27 do ns.Items.AddToBag(ns.Items.New("head", 20, 2)) end
	try("forge tab", ns.Main.ShowTab, "forge")
	clickExact("융합", "Fusion", 170)
	local before = #ns.db.bag
	clickExact("융합", "Fuse", 150)
	if #ns.db.bag ~= before - 8 then fail("fusing through the UI should turn 9 items into 1") end
	clickLabel("가능한 만큼 융합", "Fuse as many as possible")
	if #ns.db.bag ~= 3 then fail("fuse-all should leave 3 items, got " .. #ns.db.bag) end

	clickExact("제작", "Craft", 170)
	before = #ns.db.bag
	local crafted = clickExact("제작", "Craft", 150)
	if not crafted or #ns.db.bag ~= before + 1 then fail("crafting through the UI should add one item") end

	-- sockets: an epic chest piece in the bag, a gem, an enchant
	local epic = ns.Items.New("chest", 30, 6)
	ns.Items.AddToBag(epic)
	for _, step in ipairs({ { "보석 세공", "Gem Socket", "gem2", "g" }, { "마법부여", "Enchant", "dust2", "e" }, { "룬 각인", "Inscription", "scroll2", "i" } }) do
		clickExact(step[1], step[2], 170)
		clickIcon(function(b) return b.data == epic end, "target item")
		clickIcon(function(b) return b.data == step[3] end, "material " .. step[3])
		local applied = clickExact(step[1], step[2], 150)
		if not applied or not epic[step[4]] or #epic[step[4]] ~= 1 then fail(step[2] .. " through the UI did not add a stat") end
	end
	clickExact("추출", "Extraction", 170)
	clickIcon(function(b) return b.data == epic end, "item to clear")
	local removed = false
	for _, b in ipairs(Mock.VisibleButtons()) do
		if b.kind and b.index and not removed then
			try("extract", b.Click, b, "LeftButton")
			removed = true
		end
	end
	if not removed or (#(epic.g or {}) + #(epic.e or {}) + #(epic.i or {})) ~= 2 then fail("extraction through the UI should clear one stat") end

	clickExact("보너스 굴림", "Bonus Roll", 170)
	before = #ns.db.bag
	clickExact("굴림", "Roll")
	if #ns.db.bag ~= before + 1 then fail("a bonus roll through the UI should add one item") end
	clickExact("용해", "Smelt", 170)
	hoverAll()

	-- bags: equip by clicking, lock with Alt, bank with Shift, bulk smelt
	try("bag tab", ns.Main.ShowTab, "bag")
	ns.Main.SelectHero("WARRIOR")
	local sword = ns.Items.New("mh", 5, 4, "sword")
	ns.Items.AddToBag(sword)
	try("refresh", ns.Main.Refresh)
	clickIcon(function(b) return b.data == sword end, "sword")
	if ns.db.heroes.WARRIOR.gear.mh ~= sword then fail("clicking a bag item should equip it on the selected hero") end
	local junk = ns.db.bag[1]
	Mock.alt = true
	clickIcon(function(b) return b.data == junk end, "lock")
	Mock.alt = false
	if not junk.lock then fail("Alt+click should lock an item") end
	Mock.shift = true
	clickIcon(function(b) return b.data == junk end, "to bank")
	Mock.shift = false
	if ns.db.bank[1] ~= junk then fail("Shift+click should move an item to the bank") end
	clickLabel("은행", "Bank")
	clickIcon(function(b) return b.data == junk end, "from bank")
	if ns.Items.IndexInBag(junk) == nil then fail("clicking a bank item should return it to the bags") end
	clickLabel("재료 가방", "Reagents")
	hoverAll()
	local bars = ns.MatCount("bar1")
	clickIcon(function(b) return b.data == "bar1" end, "fuse bars")
	if ns.MatCount("bar1") ~= bars - 9 then fail("clicking a material should fuse nine of them") end
	clickLabel("가방 ", "Bags ")

	-- hero page: spend a point, equip a skill with a right-click, auto-equip
	try("hero tab", ns.Main.ShowTab, "hero")
	local free = ns.Heroes.PointsFree("WARRIOR")
	for _, b in ipairs(Mock.VisibleButtons()) do
		if b.tier == 1 and b.n == 1 then try("spend point", b.Click, b, "LeftButton") end
	end
	if ns.Heroes.PointsFree("WARRIOR") ~= free - 1 then fail("clicking a talent should spend a point") end
	clickLabel("최적 장비 자동 착용", "Equip best gear")

	-- map: travel
	try("map tab", ns.Main.ShowTab, "map")
	ns.db.prog[1] = 30
	try("refresh", ns.Main.Refresh)
	clickLabel("1-3 ", "1-3 ")
	clickLabel("이 스테이지로 이동", "Travel to this stage")
	if ns.db.stage.idx ~= 3 or ns.db.stage.diff ~= 1 then fail("travelling through the map did not work") end

	-- runes: buy by clicking
	try("runes tab", ns.Main.ShowTab, "runes")
	local lvl = ns.Runes.Level("w1")
	for _, b in ipairs(Mock.VisibleButtons()) do
		if b.node and b.node.id == "w1" then try("buy rune", b.Click, b, "LeftButton") end
	end
	if ns.Runes.Level("w1") ~= lvl + 1 then fail("clicking a rune should buy a level") end
end

-- click everything, several rounds, with random mouse buttons and modifiers
local clicks = 0
for round = 1, 60 do
	for _, key in ipairs(clickTabs) do
		if not ns.Main.IsShown() then try("reopen", ns.Main.Toggle, true) end
		try("show tab " .. key, ns.Main.ShowTab, key)
		local buttons = Mock.VisibleButtons()
		for _ = 1, 14 do
			if not ns.Main.IsShown() then
				-- the close button (or Escape) was hit: open the window again
				try("reopen", ns.Main.Toggle, true)
				try("show tab " .. key, ns.Main.ShowTab, key)
			end
			buttons = Mock.VisibleButtons()
			local b = #buttons > 0 and buttons[math.random(1, #buttons)] or nil
			if b and b:IsVisible() and not b.__disabled then
				Mock.shift = math.random() < 0.15
				Mock.ctrl = math.random() < 0.15
				Mock.alt = math.random() < 0.1
				local mouse = math.random() < 0.3 and "RightButton" or "LeftButton"
				local label = b.label and b.label.__text or (b.data and "icon") or "?"
				clicks = clicks + 1
				if not try("click [" .. key .. "] " .. tostring(label) .. " " .. mouse, b.Click, b, mouse) then break end
				Mock.Hover(b)
			end
		end
		Mock.shift, Mock.ctrl, Mock.alt = false, false, false
		frames(4)
		-- keep the save rich so later rounds still have things to click
		enrich(round)
	end
end
print("  clicked " .. clicks .. " buttons")

-- battle bar: drag, right-click, hide / show
local bar = BigIdleWoWHeroesBar
if not bar then
	fail("battle bar frame missing")
else
	try("drag start", bar.__scripts.OnDragStart, bar)
	try("drag stop", bar.__scripts.OnDragStop, bar)
	try("bar right-click", bar.__scripts.OnMouseUp, bar, "RightButton")
	if not (ns.db.ui.barPos and ns.db.ui.barPos[1]) then fail("bar position was not saved") end
end
try("slash", SlashCmdList.BIGIDLEWOWHEROES, "")
try("slash bar", SlashCmdList.BIGIDLEWOWHEROES, "bar")
frames(20)
try("slash bar", SlashCmdList.BIGIDLEWOWHEROES, "bar")
try("slash reset", SlashCmdList.BIGIDLEWOWHEROES, "reset")
try("slash help", SlashCmdList.BIGIDLEWOWHEROES, "help")
try("slash lang", SlashCmdList.BIGIDLEWOWHEROES, "lang en")
try("compartment", BigIdleWoWHeroes_OnAddonCompartmentClick)
ns.db.lang = nil

-- a long stretch of frames with a full party fighting (floating text, statuses ...)
if ns.Heroes.Count() == 0 then ns.Heroes.Unlock("MAGE") end
frames(2500, 0.05)
frames(40, 2.0) -- lag spikes

-- log out, stay away two hours, log back in: offline report
enrich(1)
ns.db.rate.gold = math.max(ns.db.rate.gold or 0, 5)
try("PLAYER_LOGOUT", Mock.FireEvent, "PLAYER_LOGOUT")
Mock.wall = Mock.wall + 7200
local goldBefore = ns.db.gold
try("PLAYER_LOGIN again", Mock.FireEvent, "PLAYER_LOGIN")
if ns.db.gold <= goldBefore then fail("offline rewards were not paid on login") end
local st = ns.db.stat
print(string.format("  after the run: %d kills, %d clears, %d chests opened, forge level %d, %d heroes",
	st.kills, st.clears, st.chests, ns.db.forge.level, ns.Heroes.Count()))
frames(10)

-- no icon may be requested with an empty or malformed path
for path in pairs(Mock.textures) do
	if path:find("Interface\\Icons\\") and (path:find("%s") or path:sub(-1) == "\\") then
		fail("malformed icon path: " .. path)
	end
end

if failures == 0 then print("  ui: all checks passed") end
return failures == 0
