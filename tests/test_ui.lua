-- UI test: start the addon the way the game does, walk through every screen
-- like a player would, hover everything that has a tooltip and click buttons
-- at random.
local ns = NS
local Mock = WoWMock
local Main, H = ns.Main, ns.Heroes
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

local function find(pred)
	for _, f in ipairs(Mock.frames) do
		if f:IsVisible() and (f.__type == "Button" or f.__type == "CheckButton") and pred(f) then return f end
	end
end

local function click(what, pred, mouse)
	local b = find(pred)
	if not b then
		fail("not found: " .. what)
		return false
	end
	return try("click " .. what, b.Click, b, mouse or "LeftButton")
end

local function label(b) return b.label and b.label.__text end
local function dotOn(b) return b.badge ~= nil and b.badge:IsShown() end
local function labelIs(ko, en) return function(b) return label(b) == (ko) end end

math.randomseed(777)
BigWowIdleDB = nil

------------------------------------------------------------------------
-- start-up
------------------------------------------------------------------------
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "SomeOtherAddon")
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "BigIdleHeroes")
try("PLAYER_LOGIN", Mock.FireEvent, "PLAYER_LOGIN")
if not ns.db then
	fail("saved variables were not initialised")
	return false
end
if not Main.IsShown() then fail("the menu should open by itself for a new player") end
if Main.Current() ~= "hero" then fail("a new player should land on the hero screen, got " .. tostring(Main.Current())) end
if ns.db.faction then fail("a new player has no faction yet") end
if ns.Bar.IsShown() then fail("a new player should see no battle window before the first hero, only the choice of side") end
if not find(function(b) return label(b) == "호드로 시작" end) then fail("a new player should be asked to choose a side straight away") end
-- closing and reopening the menu brings the choice back, and no hero can be
-- made without a side
SlashCmdList.BIGIDLEHEROES("")
SlashCmdList.BIGIDLEHEROES("")
if not Main.IsShown() then fail("/bih should open the menu again") end
if not find(function(b) return label(b) == "호드로 시작" end) then fail("reopening the menu before choosing a side should ask for the side again") end
if H.Create("MAGE_FIRE") or H.Count() ~= 0 then fail("no hero should be made before a side is chosen") end
click("choose Horde", labelIs("호드로 시작"))
if ns.Bar.IsShown() then fail("the battle window should still wait while the first hero is being made") end
if ns.db.faction ~= "HORDE" then fail("the faction choice was not saved") end
if not find(function(b) return b.cid == "WARRIOR" end) then fail("the hero creation dialog should open after the faction choice") end
if not SlashCmdList.BIGIDLEHEROES then fail("slash command missing") end
if type(BigIdleHeroes_OnAddonCompartmentClick) ~= "function" then fail("addon compartment function missing") end
local goal = ns.Guide.Current()
if not (goal.create and goal.tab == "hero") then fail("the first goal should be to create a hero on the hero screen") end

local tabs = { "hero", "equip", "forge", "party", "runes", "map", "pets", "options" }
do
	local nav = Main.Frame().nav
	local want = { "hero", "equip", "forge", "party", "runes", "map", "pets" }
	if #nav ~= #want then fail("the bottom bar should have seven screens, got " .. #nav) end
	for i, k in ipairs(want) do
		if not (nav[i] and nav[i].key == k) then fail("bottom bar button " .. i .. " should open " .. k) end
	end
	-- old names still lead somewhere
	Main.ShowTab("forge")
	if Main.Current() ~= "forge" then fail("the forge should be a screen of its own") end
	-- a forge function asked of the equipment screen opens on the forge screen
	Main.ShowTab("equip", { sub = "craft" })
	if Main.Current() ~= "forge" or Main.Page("forge").func ~= "craft" then fail("a forge function asked of the equipment screen should open the forge screen") end
	Main.ShowTab("bag")
	if Main.Current() ~= "equip" then fail("the old bag screen should open the equipment screen") end
end

-- every screen must render with no hero at all
Main.CloseModal()
for _, key in ipairs(tabs) do
	try("show " .. key .. " (empty save)", Main.ShowTab, key)
	hoverAll()
end
frames(20)

------------------------------------------------------------------------
-- create the first hero through the dialog: class -> specialization -> create
------------------------------------------------------------------------
try("show hero", Main.ShowTab, "hero")
local page = Main.Page("hero")
if not page.empty:IsVisible() then fail("an empty roster should say how to make the first hero") end
if label(page.create) ~= "영웅 모집하기" then fail("the hero list should end with '영웅 모집하기'") end
try("open create dialog", page.create.Click, page.create, "LeftButton")
click("class Druid", function(b) return b.cid == "DRUID" end)
click("class Hunter", function(b) return b.cid == "HUNTER" end)
click("spec Marksmanship", function(b) return b.sid == "HUNTER_MM" end)
if find(function(b) return b.sex ~= nil or label(b) == "여" or label(b) == "남" end) then fail("the create window should not offer a gender choice") end
click("reroll name", labelIs("다시"))
do -- the preview: the player's own body as the hunter's race (troll here),
	-- in the player's gender, in its set
	local cf = ns.UI.CreatePreview()
	if not cf then fail("the create window should have a 3D preview") end
	if cf and (cf.actor.__display ~= "unit:player" or cf.actor.__race ~= ns.MODEL.raceId[ns.ClassRace("HUNTER")]) then
		fail("the create preview should be the player's body as the hunter's race: " .. tostring(cf.actor.__display) .. " " .. tostring(cf.actor.__race))
	end
end
click("create", function(b) return label(b) == "사격 사냥꾼 모집하기" and b.__w == 153 end)
if H.Count() ~= 1 then fail("creating through the dialog did not make a hero") end
if not ns.Bar.IsShown() then fail("the battle window should show once the first hero is made") end
if ns.db.ui.shown == false then fail("waiting for the first hero should not change the battle window setting") end
local first = H.List()[1]
if first and ns.db.heroes[first].spec ~= "HUNTER_MM" then fail("the hero has the wrong specialization") end
if first and ns.db.heroes[first].sex ~= nil then fail("a hero should keep no gender of its own") end
if first and H.Race(first) ~= "TROLL" then fail("a Horde hunter should be a troll") end
if first and H.PartySlot(first) ~= 2 then fail("the first damage dealer should join slot 2") end
if first and not tostring(ns.db.heroes[first].name):find("^%S+ %S+$") then fail("hero name should be given + family name") end
if page.empty:IsVisible() then fail("the empty-roster text should go away once a hero exists") end
frames(300)
if ns.db.stat.kills == 0 then fail("the battle should run once a hero exists") end

------------------------------------------------------------------------
-- a rich save so that every screen has something to show
------------------------------------------------------------------------
local function enrich(round)
	local db = ns.db
	if db.gold < 1e9 then ns.AddGold(5e9) end
	if H.Count() == 0 then H.Create("MAGE_FROST") end
	if #db.bag < 12 then
		for i = 1, 20 do ns.Items.AddToBag(ns.Items.New(ns.SLOTS[(i % #ns.SLOTS) + 1], 10 + i, 1 + (i + round) % ns.MAX_QUALITY)) end
	end
	if ns.MatCount(ns.SocketMat("gem", 1)) < 5 then
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

-- learns a rune to a level (its top level by default), the runes before it first
local function learnRune(id, lvl)
	local R = ns.Runes
	lvl = lvl or R.byId[id].max
	for _ = 1, 1000 do
		if R.Level(id) >= lvl then return true end
		if not R.Buy(R.NextStepTo(id)) then return false end
	end
	return false
end
ns.AddGold(5e9)
-- party seats, automatic chest opening, offline rewards, opening a kind at once
for _, id in ipairs({ 21, 24, 13002, 11001, 1021 }) do learnRune(id) end
for _, sid in ipairs({ "WARRIOR_PROT", "PRIEST_HOLY", "MAGE_FIRE", "ROGUE_ASSA", "DRUID_GUARDIAN", "SHAMAN_RESTO", "WARLOCK_DEMO", "PALADIN_HOLY" }) do H.Create(sid) end
for _, id in ipairs(H.List()) do H.AddXP(id, 3e6) end
enrich(1)
ns.db.prog = { 30, 12, 0, 0 }
ns.db.kills = { beast = 6000, undead = 100 }
ns.CheckPets()
frames(50)
if H.PartyCount() ~= 5 then fail("the party should be full: " .. H.PartyCount()) end

for _, key in ipairs(tabs) do
	try("show " .. key, Main.ShowTab, key)
	frames(3)
	hoverAll()
end

------------------------------------------------------------------------
-- walkthroughs
------------------------------------------------------------------------
local function press(what, b, mouse)
	if not b or not b:IsVisible() then fail("not shown: " .. what) return false end
	return try(what, b.Click, b, mouse or "LeftButton")
end
local function tab(key, k)
	local b = Main.Page(key).S.tabs:Get(k)
	return press("tab " .. tostring(k), b)
end
-- answer the confirmation window
local function confirmYes(what)
	local yes = ns.UI.ConfirmButtons()
	if not (yes and yes:IsVisible()) then fail("a confirmation window should ask first: " .. what) return false end
	return press("confirm " .. what, yes)
end

-- formation: five slot cards (healer on the left, tank on the right), the
-- waiting heroes underneath
do
	Main.ShowTab("party")
	local pp = Main.Page("party")
	local x1 = select(4, pp.slots[1]:GetPoint(1))
	local x5 = select(4, pp.slots[5]:GetPoint(1))
	if not (x1 and x5 and x1 > x5) then fail("the tank's slot should be drawn in front (right of the healer)") end
	-- a party card's model: head and chest inside the portrait's square, no
	-- red dot, no role ring or role mark behind it
	for i = 1, ns.PARTY_SIZE do
		local p = pp.slots[i].fig
		if p and p:IsVisible() then
			local m = p.fig
			if m and (not m.bust or math.abs(m:GetWidth() - p:GetWidth()) > 1e-6 or math.abs(m:GetHeight() - p:GetHeight()) > 1e-6) then
				fail("a party card's model should be a bust the size of its portrait")
			end
			if p.badge:IsShown() then fail("a party card should show no red dot") end
			-- the hero's body: the player's model as its race, or for the other
			-- gender the NPC body of the race and gender
			local hid = ns.db.party[i]
			local hb = hid and ns.Figure3D.HeroBody(hid, false)
			if m and hb and m.actor.__display ~= (hb.npc and hb.npc[1] or "unit:player") then fail("a party card should show the hero's body: " .. tostring(m.actor.__display)) end
			if p.ringT:IsShown() or p.role:IsShown() then fail("a party card should show no role ring or role mark behind the model") end
		end
	end
	local healer = ns.db.party[5]
	press("take the healer out", pp.slots[5].out)
	if ns.db.party[5] then fail("빼기 should free the healer's slot") end
	Main.Refresh()
	-- the empty slot shows no leftover 3D model of the hero who left
	local leftover = pp.slots[5].fig.fig
	if leftover and leftover:IsVisible() then fail("an empty slot should not keep the old hero's 3D model") end
	try("pick the empty slot", pp.slots[5].Click, pp.slots[5], "LeftButton")
	if pp.selSlot ~= 5 then fail("clicking an empty slot should choose it") end
	Main.Refresh()
	local tank
	for _, id in ipairs(H.List()) do
		if not H.PartySlot(id) and H.Role(id) == "TANK" then tank = id end
	end
	local function benchCard(id)
		for _, c in ipairs(pp.bench) do
			if c.heroId == id and c:IsVisible() then return c end
		end
	end
	if not tank then
		fail("the test save should have a waiting tank")
	elseif not benchCard(tank) then
		fail("the waiting tank should be listed under the slots")
	else
		press("waiting tank into the healer's slot", benchCard(tank))
		if ns.db.party[5] == tank then fail("a tank must not go into the healer's slot") end
	end
	if not benchCard(healer) then
		fail("the healer who was taken out should wait under the slots")
	else
		press("waiting healer", benchCard(healer))
		if ns.db.party[5] ~= healer then fail("clicking a waiting healer should put them into the chosen slot") end
	end
	-- the arrows swap two damage dealers
	local a, b = ns.db.party[2], ns.db.party[3]
	press("move the damage dealer in slot 2 back", pp.slots[2].left)
	if not (ns.db.party[2] == b and ns.db.party[3] == a) then fail("'<' should swap slot 2 with slot 3") end
	press("and forward again", pp.slots[3].right)
	if not (ns.db.party[2] == a and ns.db.party[3] == b) then fail("'>' should swap them back") end
	if pp.slots[1].left:IsVisible() then fail("the only tank slot has no neighbour of its role to swap with") end
	-- auto formation fills a free slot
	H.Withdraw(ns.db.party[4])
	Main.Refresh()
	press("auto formation", pp.auto)
	if not ns.db.party[4] then fail("자동 편성 should fill the free slot") end
	hoverAll()
end

-- hero: the list, the header card, 능력치 · 기술 · 특성
do
	Main.ShowTab("hero")
	local hp = Main.Page("hero")
	local hc = hp.head
	local id = ns.db.party[2]
	local picked
	for _, c in ipairs(hp.cards) do
		if c.heroId == id and c:IsVisible() then picked = c end
	end
	if not picked then fail("the hero list should show the party's heroes") else press("pick hero", picked) end
	if Main.SelectedHero() ~= id then fail("clicking a hero card should choose that hero") end
	if H.Count() > #hp.cards then
		if not hp.thumb:IsVisible() then fail("a long hero list should show a scroll bar") end
		try("scroll down", hp.list.__scripts.OnMouseWheel, hp.list, -1)
		if (hp.offset or 0) ~= 1 then fail("the mouse wheel should scroll the hero list") end
		try("scroll up", hp.list.__scripts.OnMouseWheel, hp.list, 1)
		if (hp.offset or 0) ~= 0 then fail("scrolling back up should return to the top") end
	end
	-- 능력치 · 전문화
	press("stats tab", hp.subTabs:Get("stats"))
	if hp.sub ~= "stats" or not hp.bodies.stats:IsVisible() then fail("the stats tab did not open") end
	if not hp.groups[4].head:IsVisible() then fail("the stats tab should show four groups of stats") end
	-- 특성: click spends one point, right-click fills the talent
	ns.db.heroes[id].tree = {}
	ns.db.heroes[id].skills = {}
	ns.Stats.Invalidate(id)
	press("talents tab", hp.subTabs:Get("tree"))
	if hp.sub ~= "tree" then fail("the talents tab did not open") end
	local free = H.PointsFree(id)
	local skillFree = H.SkillPointsFree(id)
	press("talent 1-1", hp.tiers[1].nodes[1])
	if H.PointsFree(id) ~= free - 1 then fail("clicking a talent should spend one point") end
	if H.SkillPointsFree(id) ~= skillFree then fail("talents must not use skill points") end
	press("talent 1-2 to the top", hp.tiers[1].nodes[2], "RightButton")
	if H.NodeLevel(id, 1, 2) < 2 then fail("right-clicking a talent should spend as many points as it takes") end
	press("auto talents", hp.autoTree)
	if H.PointsFree(id) ~= 0 then fail("자동 배분 should spend every talent point") end
	press("reset talents", hp.resetTree)
	if H.PointsFree(id) ~= 0 then fail("resetting talents must ask first") end
	confirmYes("reset talents")
	if H.PointsFree(id) == 0 then fail("confirming should give the talent points back") end
	press("auto talents again", hp.autoTree)
	-- 기술: right-click learns, click equips; the slots above take it off
	press("skills tab", hp.subTabs:Get("skills"))
	if hp.sub ~= "skills" then fail("the skills tab did not open") end
	ns.db.heroes[id].sk = { [H.SkillList(id)[1]] = 1 }
	ns.db.heroes[id].skills = { H.SkillList(id)[1] }
	ns.Stats.Invalidate(id)
	Main.Refresh()
	local second = H.SkillList(id)[2]
	local row
	for _, r in ipairs(hp.skRows) do
		if r.sid == second and r:IsVisible() then row = r end
	end
	if not row then
		fail("the skills tab should list the specialization's second skill")
	else
		press("equip an unlearned skill", row)
		if H.IsSkillEquipped(id, second) then fail("a skill that is not learned must not be equipped") end
		press("learn", row, "RightButton")
		if H.SkillPoints(id, second) ~= 1 then fail("right-clicking a skill should learn it") end
		if not H.IsSkillEquipped(id, second) then fail("a newly learned skill should go into a free slot") end
		press("raise", row, "RightButton")
		if H.SkillPoints(id, second) ~= 2 then fail("right-clicking again should raise it") end
		press("take off", row)
		if H.IsSkillEquipped(id, second) then fail("clicking an equipped skill in the list should take it off") end
		press("equip", row)
		if not H.IsSkillEquipped(id, second) then fail("clicking a learned skill should equip it") end
		local slotB
		for _, b in ipairs(hp.eqSlots) do
			if b.sid == second then slotB = b end
		end
		if not slotB then
			fail("an equipped skill should show in the slots above the list")
		else
			press("take off from the slot", slotB)
			if H.IsSkillEquipped(id, second) then fail("clicking a skill slot should take the skill off") end
		end
	end
	press("auto skills", hp.autoSkills)
	if H.SkillPointsFree(id) ~= 0 then fail("자동 배분 should spend every skill point") end
	press("reset skills", hp.resetSkills)
	confirmYes("reset skills")
	if H.SkillPointsFree(id) == 0 then fail("resetting skills should give the points back") end
	press("auto skills again", hp.autoSkills)
	-- the header card: rename, rest / field, dismiss
	press("rename", hc.rename)
	click("rename reroll", labelIs("다시"))
	click("rename keep", labelIs("이 이름으로"))
	if not tostring(ns.db.heroes[id].name):find("^%S+ %S+$") then fail("renaming should keep the given + family name form") end
	if label(hc.field) ~= "휴식" then fail("a fielded hero's card should offer rest, got " .. tostring(label(hc.field))) end
	press("rest", hc.field)
	if H.PartySlot(id) then fail("휴식 should take the hero out of the party") end
	Main.Refresh()
	if label(hc.field) ~= "출전" then fail("a resting hero's card should offer to field them, got " .. tostring(label(hc.field))) end
	press("field", hc.field)
	if not H.PartySlot(id) then fail("출전 should put the hero back into the party") end
	local benchId
	for _, hid in ipairs(H.List()) do
		if not H.PartySlot(hid) then benchId = hid end
	end
	Main.SelectHero(benchId)
	Main.Refresh()
	local n = H.Count()
	press("dismiss", hc.dismiss)
	if H.Count() ~= n then fail("one click must not dismiss a hero") end
	confirmYes("dismiss")
	if H.Count() ~= n - 1 or ns.db.heroes[benchId] then fail("confirming should dismiss the hero") end
	hoverAll()
end

-- equipment: paper doll on the left, bag on the right
do
	Main.ShowTab("equip", { sub = "bag" })
	local ep = Main.Page("equip")
	local id = ns.db.party[1]
	click("hero in the strip", function(b) return b.heroId == id end)
	if Main.SelectedHero() ~= id then fail("the strip on top should choose the hero") end
	if ep.tab ~= "bag" or not ep.bodies.bag:IsVisible() then fail("the equipment screen should open on the bag") end
	-- chests waiting put no red dot on the 가방 tab nor on the 장비 menu
	do
		local savedChests, savedBag = ns.db.chests, ns.db.bag
		ns.db.chests = { { t = 1, l = 5, d = 1 }, { t = 2, l = 5, d = 1 } }
		ns.db.bag = {}
		ns.Fire("BAG")
		ns.Fire("CHESTS")
		Main.Refresh()
		local bagTab = ep.tabs:Get("bag")
		if ns.Forge.Unlocked("smelt") and bagTab.badge and bagTab.badge:IsShown() then fail("chests should not mark the 가방 tab") end
		if ns.Forge.Unlocked("smelt") and ns.Guide.Badges().equip then fail("chests should not put a red dot on the 장비 menu") end
		ns.db.bag = savedBag
		ns.Fire("BAG")
		ns.db.chests = savedChests
		Main.Refresh()
	end
	local sword = ns.Items.New("mh", 5, 4, H.Spec(id).mh[1])
	ns.db.bag = {}
	ns.Items.AddToBag(sword)
	for i = 1, 6 do ns.Items.AddToBag(ns.Items.New("head", 5 + i, 2)) end
	ns.Items.AddToBag(ns.Items.New("ring", 9, 2))
	Main.Refresh()
	click("equip from the bag", function(b) return b.data == sword end)
	if ns.db.heroes[id].gear.mh ~= sword then fail("clicking an item in the bag should equip it on the chosen hero") end
	press("take off from the slot", ep.slots.mh, "RightButton")
	if ns.db.heroes[id].gear.mh == sword or not ns.Items.IndexInBag(sword) then fail("right-clicking a slot should put the item back in the bag") end
	-- a slot shows the bag's items for that slot
	press("head slot", ep.slots.head)
	if ep.view ~= "head" then fail("clicking an equipment slot should show that slot's items") end
	local shown = 0
	for _, c in ipairs(ep.cells) do
		if c.data and c:IsShown() then
			shown = shown + 1
			if c.data.s ~= "head" then fail("the head view shows a " .. tostring(c.data.s)) break end
		end
	end
	if shown ~= 6 then fail("the head view should show the six heads, got " .. shown) end
	press("view list", ep.viewPick)
	click("view all", function(b) return b.value == "all" and b.label end)
	if ep.view ~= "all" then fail("picking '전체' from the list should show every item") end
	-- protect, bank, break down
	local junk = ns.db.bag[#ns.db.bag]
	Mock.alt = true
	click("alt-click", function(b) return b.data == junk end)
	Mock.alt = false
	if not junk.lock then fail("Alt+click should protect an item") end
	Mock.shift = true
	click("shift-click", function(b) return b.data == junk end)
	Mock.shift = false
	if ns.db.bank[#ns.db.bank] ~= junk then fail("Shift+click should move the item to the storage") end
	-- the storage is its own tab (창고), at the end; the bag's view list has no storage
	press("view list", ep.viewPick)
	if find(function(b) return b.value == "bank" and b.label end) then fail("보기 should not list the storage") end
	press("close the view list", ep.viewPick)
	press("창고 tab", ep.tabs:Get("bank"))
	if ep.tab ~= "bank" then fail("the 창고 tab should open the storage") end
	if not (ep.bagCount:GetText() or ""):find("창고", 1, true) then fail("the 창고 tab should count the storage, got " .. tostring(ep.bagCount:GetText())) end
	if ep.viewPick:IsVisible() or ep.smeltGo:IsVisible() then fail("the storage has no view list or breaking down") end
	click("take out of the storage", function(b) return b.data == junk end)
	if not ns.Items.IndexInBag(junk) then fail("clicking an item in the storage should take it out") end
	-- 가방 always opens on 보기: 전체, whatever was picked before and from any tab
	ep.view = "weapon"
	press("가방 tab", ep.tabs:Get("bag"))
	if ep.tab ~= "bag" or ep.view ~= "all" then fail("the 가방 tab should open on 보기: 전체, got " .. tostring(ep.view)) end
	ep.view = "armor"
	press("가방 tab again", ep.tabs:Get("bag"))
	if ep.view ~= "all" then fail("pressing 가방 on the bag should go back to 보기: 전체") end
	ep.view = "acc"
	Main.ShowTab("equip", { sub = "mats" })
	Main.ShowTab("equip", { sub = "bag" })
	if ep.view ~= "all" then fail("opening the bag from elsewhere should show 보기: 전체") end
	ns.Items.ToggleLock(junk)
	Main.Refresh()
	local n1 = #ns.db.bag
	click("right-click break down", function(b) return b.data == junk end, "RightButton")
	if #ns.db.bag ~= n1 then fail("right-click must ask before breaking down") end
	confirmYes("break down")
	if #ns.db.bag ~= n1 - 1 then fail("confirming should break the item down") end
	-- a locked 분해 unlocks right here, under the bag
	ns.db.forge.ops.smelt = nil
	Main.Refresh()
	if not (label(ep.smeltGo) or ""):find("분해 해금", 1, true) then fail("a locked 분해 should offer to unlock it, got " .. tostring(label(ep.smeltGo))) end
	-- an unlock button that can unlock now has the red dot
	if not ns.Guide.CanUnlock("smelt") or not dotOn(ep.smeltGo) then fail("[분해 해금] should have the red dot when it can unlock now") end
	press("unlock 분해", ep.smeltGo)
	if ns.Forge.Unlocked("smelt") then fail("unlocking must ask first") end
	confirmYes("unlock 분해")
	if not ns.Forge.Unlocked("smelt") then fail("[분해 해금] should unlock breaking down") end
	Main.Refresh()
	if dotOn(ep.smeltGo) then fail("the 분해 button has no red dot once unlocked") end
	-- break down by grade, or by itself
	press("grade list", ep.smeltPick)
	click("grade 3", function(b) return b.value == 3 and b.label end)
	if ns.db.ui.smeltQ ~= 3 then fail("picking from the grade list did not set it") end
	local n0 = #ns.db.bag
	press("break down by grade", ep.smeltGo)
	if #ns.db.bag ~= n0 then fail("breaking down by grade must ask first") end
	if #ns.Forge.PickByQuality(3) > 0 then
		confirmYes("break down by grade")
		if #ns.db.bag == n0 then fail("confirming should break the items down") end
	end
	ns.db.opt.autoSmelt = 0
	Main.Refresh()
	press("auto break-down on", ep.autoSmelt)
	if ns.db.opt.autoSmelt ~= 3 then fail("turning auto break-down on should use the chosen grade, got " .. tostring(ns.db.opt.autoSmelt)) end
	press("auto break-down off", ep.autoSmelt)
	if ns.db.opt.autoSmelt ~= 0 then fail("clicking again should turn auto break-down off") end
	-- equip the best, the party, take everything off
	enrich(2)
	Main.Refresh()
	press("auto equip", ep.auto)
	press("party auto equip", ep.party)
	local worn = 0
	for _ in pairs(ns.db.heroes[id].gear) do worn = worn + 1 end
	press("take everything off", ep.unequip)
	confirmYes("take everything off")
	if next(ns.db.heroes[id].gear) and ns.Items.BagFree() > 0 then fail("전체 해제 should take the gear off") end
	press("auto equip again", ep.auto)
	-- (chests are opened from the battle window, not from the bag)
	if ep.open then fail("the bag should have no chest opener") end
	press("sort", ep.sort)
	hoverAll()
end

-- forge > 재료: one tab per kind; each row fuses or breaks down its material
do
	Main.ShowTab("forge", { sub = "mats" })
	local ep = Main.Page("forge")
	if Main.Current() ~= "forge" or ep.func ~= "mats" then fail("the materials did not open on the forge screen") end
	local KINDS = {
		mat_craft = { bar = true, leather = true, cloth = true }, mat_gem = { gem = true },
		mat_ench = { dust = true }, mat_insc = { scroll = true }, mat_seal = { seal = true },
	}
	local function rowOf(mid)
		for _, r in ipairs(ep.matRows) do
			if r.id == mid and r:IsVisible() then return r end
		end
	end
	for _, k in ipairs({ "mat_craft", "mat_gem", "mat_ench", "mat_insc", "mat_seal" }) do
		press("materials tab " .. k, ep.matTabs:Get(k))
		if ep.matTab ~= k then fail("the materials tab " .. k .. " did not open") end
		local n = 0
		for _, r in ipairs(ep.matRows) do
			if r:IsVisible() and r.id then
				n = n + 1
				if not KINDS[k][ns.MATS[r.id].kind] then fail(k .. " shows " .. r.id) break end
			end
		end
		if n == 0 then fail(k .. " should list its materials") end
		hoverAll()
	end
	-- a click on a coin in the title bar opens its tab
	local pill = Main.Frame().currency[1]
	try("currency pill", pill.__scripts.OnMouseUp, pill, "LeftButton")
	if not (Main.Current() == "forge" and ep.func == "mats" and ep.matTab == pill.def.tab) then fail("a currency in the title bar should open its materials tab") end
	-- auto-fuse in one tab leaves the other tabs' materials alone
	local GEM1 = ns.SocketMat("gem", 1)
	ns.AddMat(GEM1, 20)
	ns.AddMat("bar1", 20)
	Main.ShowTab("forge", { sub = "mats", tab = "mat_gem" })
	local barsBefore = ns.MatCount("bar1")
	press("auto fuse gems", ep.autoFuse)
	confirmYes("auto fuse gems")
	if ns.MatCount(GEM1) >= 9 then fail("auto-fuse in the gem tab should fuse the gems") end
	if ns.MatCount("bar1") ~= barsBefore then fail("auto-fuse in the gem tab must not touch crafting materials") end
	Main.ShowTab("forge", { sub = "mats", tab = "mat_craft" })
	local r = rowOf("bar1")
	if not r then
		fail("the crafting tab should list copper bars")
	else
		local bars = ns.MatCount("bar1")
		press("fuse once", r.one)
		if ns.MatCount("bar1") ~= bars - 9 then fail("1회 should fuse nine materials into one") end
		ns.AddMat("bar1", 30)
		Main.Refresh()
		press("fuse all", r.all)
		if ns.MatCount("bar1") >= 9 then fail("모두 should fuse while nine or more are left") end
		ns.AddMat("bar1", 5)
		Main.Refresh()
		press("break all down", r.smelt)
		if ns.MatCount("bar1") == 0 then fail("breaking materials down must ask first") end
		confirmYes("break all down")
		if ns.MatCount("bar1") ~= 0 then fail("confirming should break every bar down") end
	end
	-- the lucky seals roll an item (unlocked from the row itself)
	Main.ShowTab("forge", { sub = "mats", tab = "mat_seal" })
	-- only the seals in the bag have a row
	for _, d in ipairs(ns.SEAL) do ns.AddMat(d.mat, -ns.MatCount(d.mat)) end
	ns.AddMat("seal1", 3)
	Main.Refresh()
	for _, d in ipairs(ns.SEAL) do
		if (rowOf(d.mat) ~= nil) ~= (d.mat == "seal1") then fail("only seals in the bag should have a row: " .. d.mat) end
	end
	ns.db.forge.ops.seal = nil
	Main.Refresh()
	local s = rowOf("seal1")
	if not (s and s.roll:IsVisible()) then
		fail("a seal row should have a roll button")
	else
		if not (label(s.roll) or ""):find("해금", 1, true) then fail("a locked roll should offer to unlock it, got " .. tostring(label(s.roll))) end
		if dotOn(s.roll) ~= ns.Guide.CanUnlock("seal") then fail("[굴리기 해금] should have the red dot exactly when it can unlock now") end
		press("unlock the roll", s.roll)
		confirmYes("unlock the roll")
		if not ns.Forge.Unlocked("seal") then fail("the roll button should unlock 인장 굴리기") end
		Main.Refresh()
		if dotOn(s.roll) then fail("the roll button has no red dot once unlocked") end
		local before = #ns.db.bag
		press("roll", s.roll)
		if #ns.db.bag ~= before + 1 then fail("rolling a seal should add one item") end
	end
	-- seals are rolled on the materials' seal tab: the forge has no list
	-- entry of its own for it (an old link to it opens that tab)
	Main.ShowTab("forge", { sub = "seal" })
	local fp = Main.Page("forge")
	if fp.matTab ~= "mat_seal" or fp.func ~= "mats" then fail("a link to 인장 굴리기 should open the materials on the seals: " .. tostring(fp.matTab) .. " " .. tostring(fp.func)) end
	if fp.tabs:Get("seal") then fail("the forge list should have no 인장 굴리기 entry") end
	click("craft materials tab", labelIs("제작 재료"))
	if fp.matTab ~= "mat_craft" or fp.func ~= "mats" then fail("picking another tab should show those materials: " .. tostring(fp.matTab) .. " " .. tostring(fp.func)) end
	hoverAll()
end

-- the forge screen: fuse, craft, gem, enchant, inscribe, enhance; a locked one
do
	local F = ns.Forge
	for _, op in ipairs(ns.FORGE_OPS) do if not F.Unlocked(op.key) then F.Unlock(op.key) end end
	-- give the party better heads so that the test items are not upgrades
	for i = 1, ns.PARTY_SIZE do
		local pid = ns.db.party[i]
		if pid then
			ns.db.heroes[pid].gear.head = ns.Items.New("head", 100, 8)
			ns.Stats.Invalidate(pid)
		end
	end
	ns.db.bag = {}
	for _ = 1, 27 do ns.Items.AddToBag(ns.Items.New("head", 20, 2)) end
	Main.ShowTab("forge", { sub = "fuse" })
	local ep = Main.Page("forge")
	if not ep.forgeBar:IsVisible() or not (ep.level.__text or ""):find("대장간 Lv", 1, true) then fail("the forge screen should show the forge level") end
	local fp = ep.forge.fuse
	if not ep.bodies.fuse:IsVisible() then fail("the fuse tab did not open") end
	local before = #ns.db.bag
	press("fuse once", fp.one)
	if #ns.db.bag ~= before - 8 then fail("1회 융합 should turn 9 items into 1") end
	press("fuse all", fp.all)
	confirmYes("fuse all")
	if #ns.db.bag ~= 3 then fail("가능한 만큼 융합 should leave 3 items, got " .. #ns.db.bag) end
	-- the grade is picked from one list (like the bag's 분해 등급)
	press("grade list", fp.pick)
	click("grade 3", function(b) return b.value == 3 and b.label end)
	if fp.q ~= 3 then fail("picking from the grade list should set the grade") end
	press("grade list", fp.pick)
	click("grade 6", function(b) return b.value == 6 and b.label end)
	if fp.q ~= 6 then fail("picking grade 6 from the list should set it") end
	if not (label(fp.pick) or ""):find("→", 1, true) then fail("the grade button should show the chosen grade") end
	press("accessories", fp.kinds:Get("accessory"))
	if fp.cat ~= "accessory" then fail("the kind chips should pick the kind") end
	-- craft
	press("craft tab", ep.tabs:Get("craft"))
	local cp = ep.forge.craft
	press("tier 2", cp.tiers[2])
	if cp.tier ~= 2 then fail("clicking a crafting tier should choose it") end
	-- each tier's unlock button has the red dot when it can unlock now (tier
	-- 2 locked again, with the forge level and the gold for it)
	local had2, hadLvl, hadGold = ns.db.forge.craft[2], ns.db.forge.level, ns.db.gold
	ns.db.forge.craft[2] = nil
	ns.db.forge.level = math.max(hadLvl, ns.CRAFT_TIERS[2].forge)
	ns.db.gold = math.max(hadGold, ns.CRAFT_TIERS[2].gold * 5)
	Main.Refresh()
	for i = 1, #cp.tiers do
		press("tier " .. i, cp.tiers[i])
		local t = ns.CRAFT_TIERS[i]
		local can = not ns.Forge.CraftTierUnlocked(i) and ns.db.forge.level >= t.forge and ns.CanAfford(t.gold * 5)
		if dotOn(cp.go) ~= (can and true or false) then fail("tier " .. i .. "'s button: the red dot should show exactly when it can unlock now") end
		if i == 2 and not can then fail("the test should have tier 2 ready to unlock") end
	end
	ns.db.forge.craft[2], ns.db.forge.level, ns.db.gold = had2, hadLvl, hadGold
	press("tier 1", cp.tiers[1])
	for _, mid in ipairs(ns.MAT_ORDER) do ns.AddMat(mid, 30) end
	Main.Refresh()
	before = #ns.db.bag
	press("craft", cp.go)
	if #ns.db.bag ~= before + 1 then fail("crafting should add one item") end
	-- sockets: the item, then the material, then the button
	local epic = ns.Items.New("chest", 30, 6)
	ns.Items.AddToBag(epic)
	-- (the best grades come first: a top one is on the first page)
	for _, step in ipairs({ { "gem", ns.SocketMat("gem", 10), "g" }, { "ench", ns.SocketMat("dust", 10), "e" }, { "insc", ns.SocketMat("scroll", 10), "i" } }) do
		press(step[1] .. " tab", ep.tabs:Get(step[1]))
		local sp = ep.forge[step[1]]
		click("target", function(b) return b.data == epic end)
		if sp.picked ~= epic then fail("clicking an item in the " .. step[1] .. " tab should choose it") end
		click("material", function(b) return b.matId == step[2] end)
		if sp.mat ~= step[2] then fail("clicking a material should choose it") end
		press("apply " .. step[1], sp.go)
		if not epic[step[3]] or #epic[step[3]] ~= 1 then fail(step[1] .. " did not add a stat") end
		hoverAll()
	end
	-- more materials than fit: the best grades on the first page, the rest
	-- one page on
	do
		press("gem tab", ep.tabs:Get("gem"))
		local sp = ep.forge.gem
		local function shown(id)
			for _, b in ipairs(sp.mats) do if b.__shown ~= false and b.matId == id then return true end end
			return false
		end
		local low = ns.SocketMat("gem", 1)
		if not sp.next.__shown then fail("with every gem at hand the gem tab should page its materials") end
		if shown(low) then fail("a common gem should not be on the first page when better ones are at hand") end
		press("next materials", sp.next)
		if not shown(low) then fail("the next page should show the common gems") end
		press("previous materials", sp.prev)
	end
	-- the "부여됨" line belongs to the piece it was set in: another piece
	-- picked, it goes; back on that piece, it is there again
	do
		press("gem tab", ep.tabs:Get("gem"))
		local sp = ep.forge.gem
		local other = ns.Items.New("chest", 30, 6)
		ns.Items.AddToBag(other)
		Main.Refresh()
		click("gem target", function(b) return b.data == epic end)
		if not (sp.lastText.__text or ""):find("부여됨", 1, true) then fail("the gem tab should say what was just set") end
		click("another target", function(b) return b.data == other end)
		if sp.picked ~= other then fail("clicking another item should choose it") end
		if (sp.lastText.__text or "") ~= "" then fail("'부여됨' should go when another item is picked: " .. tostring(sp.lastText.__text)) end
		click("gem target again", function(b) return b.data == epic end)
		if not (sp.lastText.__text or ""):find("부여됨", 1, true) then fail("'부여됨' should show again on the piece it was set in") end
		ns.Items.RemoveFromBag(ns.Items.IndexInBag(other))
	end
	-- nothing picked (no item with that socket yet): the button explains, no error
	press("inscribe tab", ep.tabs:Get("insc"))
	local ip = ep.forge.insc
	ip.picked, ip.mat = nil, nil
	try("inscribe with nothing picked", ip.go.Click, ip.go, "LeftButton")
	-- extraction sits on the socket's line (and unlocks there)
	press("gem tab", ep.tabs:Get("gem"))
	local gp = ep.forge.gem
	gp.picked = epic
	ns.db.forge.ops.remove = nil
	Main.Refresh()
	if not (label(gp.card.rows[1].remove) or ""):find("추출 해금", 1, true) then fail("a locked 추출 should offer to unlock it") end
	if dotOn(gp.card.rows[1].remove) ~= ns.Guide.CanUnlock("remove") then fail("[추출 해금] should have the red dot exactly when it can unlock now") end
	press("unlock 추출", gp.card.rows[1].remove)
	confirmYes("unlock 추출")
	if not F.Unlocked("remove") then fail("the socket line should unlock 추출") end
	press("extract", gp.card.rows[1].remove)
	confirmYes("extract")
	if #(epic.g or {}) ~= 0 then fail("추출 should clear the gem") end
	-- a locked tab explains itself and unlocks
	ns.db.forge.ops.insc = nil
	press("locked tab", ep.tabs:Get("insc"))
	if not ep.bodies.locked:IsVisible() then fail("a locked forge tab should show how to unlock it") end
	if dotOn(ep.lockView.go) ~= ns.Guide.CanUnlock("insc") then fail("[해금하기] should have the red dot exactly when it can unlock now") end
	press("unlock", ep.lockView.go)
	confirmYes("unlock")
	if not F.Unlocked("insc") then fail("해금하기 should unlock the function") end
	hoverAll()
	-- 강화: locked until 신화+ opens (신화 cleared), then +0 .. +20
	local prog = ns.db.prog
	local savedProg = { prog[1], prog[2], prog[3], prog[4] }
	prog[3], prog[4] = 0, 0
	press("enhance tab (locked)", ep.tabs:Get("up"))
	if not ep.bodies.locked:IsVisible() or ep.bodies.up:IsVisible() then fail("a locked 강화 tab should say what opens it") end
	if not (ep.lockView.text.__text or ""):find("신화+ 난이도", 1, true) then fail("the locked 강화 tab should say 신화+ opens it") end
	if ep.lockView.go:IsVisible() then fail("강화 opens by itself, not with a button") end
	for d = 1, #ns.DIFFS do prog[d] = ns.STAGE_COUNT end
	ns.db.gold = 1e15
	Main.Refresh()
	if not ep.bodies.up:IsVisible() then fail("the 강화 tab should open once 신화+ opens") end
	local up = ep.forge.up
	click("enhance target", function(b) return b.data == epic end)
	if up.picked ~= epic then fail("clicking an item in the 강화 tab should choose it") end
	-- each try: the strikes, then a click shows the result window (성공! or
	-- 실패...); a try can fail, so pressed until the piece is at +3
	local fx = ns.ForgeView.UpFx
	local sawWin, sawFail = false, false
	for _ = 1, 200 do
		if (epic.up or 0) >= 3 then break end
		local before = epic.up or 0
		press("enhance", up.go)
		if not (fx.anim and fx.anim:IsShown() and fx.run) then fail("a try should show the strikes") break end
		if not (fx.Angle(fx.STRIKES[1]) > 0 and fx.Angle(fx.STRIKES[1] - 0.2) < 0) then fail("the hammer should be raised before it lands and down on the anvil as it lands") end
		fx.anim.skip:Click()
		if fx.run or not (fx.res and fx.res:IsShown()) then fail("a click on the strikes should show the result window") break end
		local title = fx.res.title.__text or ""
		local won = (epic.up or 0) > before
		if won and not title:find("성공!", 1, true) then fail("a success should say 성공!: " .. title) end
		if not won and not title:find("실패...", 1, true) then fail("a failure should say 실패...: " .. title) end
		sawWin, sawFail = sawWin or won, sawFail or not won
		Main.CloseModal()
	end
	if (epic.up or 0) ~= 3 then fail("강화하기 should raise the piece to +3: " .. tostring(epic.up)) end
	-- 계속 강화 / 다시 강화 tries the same piece once more
	if sawWin or sawFail then
		local before = epic.up or 0
		press("enhance", up.go)
		fx.anim.skip:Click()
		local tries = ns.db.stat.upTries
		fx.res.again:Click()
		if ns.db.stat.upTries ~= tries + 1 or not fx.run then fail("계속/다시 강화 should try once more with the strikes") end
		fx.Finish()
		Main.CloseModal()
		epic.up = before > 0 and before or nil
	end
	-- the icons show the item level; the step goes before the name in the
	-- tooltip ("+3 <name>")
	Main.ShowTab("equip", { sub = "bag" })
	local eq = Main.Page("equip")
	local cell, plain
	for _, b in ipairs(eq.cells) do
		if b.data == epic then cell = b elseif b.data and not b.data.up and b:IsShown() then plain = b end
	end
	-- marks: "lv.N" top left, the enhancement step's number badge bottom right
	if not cell or cell.ilvl.__text ~= "lv." .. epic.l then fail("an enhanced item's icon should show its item level: " .. tostring(cell and cell.ilvl.__text)) end
	if cell and cell.enh.__text ~= "+" .. epic.up then fail("an enhanced item's icon should show its step: " .. tostring(cell.enh.__text)) end
	if plain and (plain.ilvl.__text ~= "lv." .. plain.data.l or (plain.enh.__text or "") ~= "") then fail("an item's icon should show its level and no step: " .. tostring(plain.ilvl.__text)) end
	local title = ns.Items.Tooltip(epic)[1][1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	if title ~= "+3 " .. ns.Items.Name(epic) then fail("the tooltip should name the step before the item: " .. title) end
	local plainTitle = ns.Items.Tooltip(plain and plain.data or ns.Items.New("chest", 30, 2))[1][1]
	if plainTitle:find("^%+") then fail("a piece at +0 has no step before its name: " .. plainTitle) end
	-- a bag item's tooltip has, beside it, what the chosen hero wears in
	-- that slot; none when the hero wears nothing there, none in the bank
	do
		local hid = Main.SelectedHero()
		local h = hid and ns.db.heroes[hid]
		local wornCell, bareCell
		for _, b in ipairs(eq.cells) do
			if b.data and b:IsShown() and h then
				if h.gear[b.data.s] and not wornCell then wornCell = b end
				if not h.gear[b.data.s] and not bareCell then bareCell = b end
			end
		end
		if not wornCell then fail("the test needs a bag item of a slot the chosen hero wears") else
			try("bag hover", wornCell.__scripts.OnEnter, wornCell)
			local side = ns.UI.TipText(true)
			local worn = h.gear[wornCell.data.s]
			if side[1] ~= "착용 중" or not (side[2] or ""):find(ns.Items.Name(worn), 1, true) then
				fail("a bag item's tooltip should show the worn " .. wornCell.data.s .. " beside it: " .. tostring(side[1]) .. " / " .. tostring(side[2]))
			end
			if not (ns.UI.TipText()[1] or ""):find(ns.Items.Name(wornCell.data), 1, true) then fail("the bag item's own tooltip should stay first") end
			try("bag leave", wornCell.__scripts.OnLeave, wornCell)
			if #ns.UI.TipText(true) > 0 then fail("leaving the item should hide the worn item's tooltip too") end
		end
		if bareCell then
			try("bag hover", bareCell.__scripts.OnEnter, bareCell)
			if #ns.UI.TipText(true) > 0 then fail("no worn tooltip when the hero wears nothing in that slot") end
			try("bag leave", bareCell.__scripts.OnLeave, bareCell)
		end
	end
	-- 계승: a new piece of the same slot takes the steps' worth, the old one
	-- is used up
	local other = ns.Items.New(epic.s, epic.l, epic.q, epic.t)
	ns.Items.AddToBag(other)
	Main.ShowTab("forge", { sub = "up" })
	click("inherit target", function(b) return b.data == other end)
	if up.picked ~= other then fail("the second piece should be chosen") end
	local want = ns.Upgrade.MoveResult(epic, other)
	if not (up.move.text.__text or ""):find("+" .. want, 1, true) then fail("the 계승 line should say the step it gives: " .. tostring(up.move.text.__text)) end
	press("inherit", up.move.btn)
	confirmYes("inherit")
	if (other.up or 0) ~= want or want < 1 or ns.Items.IndexInBag(epic) or ns.Items.Wearer(epic) then
		fail("계승 should give the new piece +" .. want .. " and use up the old one: " .. tostring(other.up))
	end
	prog[1], prog[2], prog[3], prog[4] = savedProg[1], savedProg[2], savedProg[3], savedProg[4]
	hoverAll()
end

-- runes: the tree map; pick a rune, learn it from the card, move the map
do
	Main.ShowTab("runes")
	local rp = Main.Page("runes")
	local R = ns.Runes
	local function node(id) return rp.byId[id] end
	learnRune(1)
	ns.db.runes[10] = nil
	R.Invalidate()
	Main.Refresh()
	click("rune 10", function(b) return b.node and b.node.id == 10 end)
	if rp.sel ~= 10 then fail("clicking a rune should select it") end
	press("learn", rp.side.buy)
	if R.Level(10) ~= 1 then fail("learning a rune did not work") end
	if R.Available(11) then fail("a rune needs the one before it at the level it names (here its top level)") end
	press("learn", rp.side.buy)
	press("learn", rp.side.buy)
	if not (R.Available(11) and R.Available(101) and R.Available(201)) then fail("a rune at its top level should open the runes after it") end
	-- a kind checked under the map: the other runes fade, but their dark
	-- backing stays solid so the lines behind them stay hidden
	do
		local box
		for _, bt in ipairs(rp.kindBoxes) do if bt.key == "fight" then box = bt end end
		press("check fight", box)
		local faded, kept
		for _, b in ipairs(rp.nodes) do
			if b.node.group.key == "fight" then kept = kept or b else faded = faded or b end
		end
		if not (faded and kept) then fail("the rune map should have runes of the checked kind and of others")
		else
			if faded:GetAlpha() < 1 or faded.icon:GetAlpha() > 0.2 or faded.border:GetAlpha() > 0.2 then
				fail("a faded rune should fade its picture and border, not its solid backing")
			end
			if kept.border:GetAlpha() < 1 then fail("a rune of the checked kind should stay bright") end
		end
		press("uncheck fight", box)
		if faded and faded.border:GetAlpha() < 1 then fail("with no kind checked every rune should be bright again") end
	end
	-- the border is the rune's kind; grey while closed; a green check at the top level
	do
		local b = node(10)
		local rgb = R.byId[10].group.rgb
		local v = b.border.__vertex or {}
		if math.abs((v[1] or 0) - rgb[1]) > 0.01 or math.abs((v[2] or 0) - rgb[2]) > 0.01 then fail("an open rune's border should be its kind's colour") end
		if not b.check:IsShown() then fail("a rune at its top level should show the green check") end
		if R.Level(202) >= R.byId[202].max or node(202).check:IsShown() then fail("a rune below its top level shows no check") end
		local c = node(12821)
		local cv = c.border.__vertex or {}
		if math.abs((cv[1] or 0) - (cv[2] or 0)) > 0.05 or not c.icon.__desat then fail("a closed rune should be grey") end
	end
	click("rune 12821", function(b) return b.node and b.node.id == 12821 end)
	if rp.side.goPrev:IsVisible() then
		press("first rune to learn", rp.side.goPrev)
		if not R.Available(rp.sel) then fail("'먼저 배울 룬' should select a rune that can be learned") end
	else
		fail("a closed rune's card should offer the rune to learn first")
	end
	if not (rp.side.totalLines[1].__text or ""):find("%S") then fail("the rune card should list the total of the learned runes") end
	-- the map: the wheel zooms (within limits), dragging moves it, a drag is no click
	do
		local map, cam = rp.map, rp.cam
		local z0 = cam.z
		try("map wheel in", map.__scripts.OnMouseWheel, map, 1)
		if not (cam.z > z0) then fail("the wheel should zoom in") end
		for _ = 1, 40 do map.__scripts.OnMouseWheel(map, 1) end
		local zMax = cam.z
		for _ = 1, 80 do map.__scripts.OnMouseWheel(map, -1) end
		local zMin = cam.z
		if not (zMax <= 1.6 + 1e-9 and zMin >= 0.3 - 1e-9 and zMin < 1) then fail("zoom should stay within its limits: " .. zMin .. " .. " .. zMax) end
		if node(10).lvl:IsShown() then fail("zoomed far out, the levels on the runes should hide") end
		try("wheel on a rune", node(10).__scripts.OnMouseWheel, node(10), 1)
		if not (cam.z > zMin) then fail("the wheel over a rune should zoom the map too") end
		for _ = 1, 10 do map.__scripts.OnMouseWheel(map, 1) end
		if not node(10).lvl:IsShown() then fail("zoomed in, the levels on the runes show") end
		rp.centerOn(1)
		local real = GetCursorPosition
		local cx, cy = 400, 300
		_G.GetCursorPosition = function() return cx, cy end
		local x0, y0 = cam.x, cam.y
		try("press on the map", map.__scripts.OnMouseDown, map, "LeftButton")
		cx, cy = 520, 240
		try("drag", map.__scripts.OnUpdate, map, 0.02)
		if not (cam.x < x0 and cam.y > y0) then fail("dragging right and down should show what is left and up: " .. x0 .. "," .. y0 .. " -> " .. cam.x .. "," .. cam.y) end
		map.__scripts.OnMouseUp(map, "LeftButton")
		-- a press on a rune that drags is no click
		local sel = rp.sel
		node(11).__scripts.OnMouseDown(node(11), "LeftButton")
		cx, cy = 300, 300
		map.__scripts.OnUpdate(map, 0.02)
		node(11):Click()
		if rp.sel ~= sel then fail("the end of a drag that started on a rune should not pick it") end
		map.__scripts.OnMouseUp(map, "LeftButton")
		node(11).__scripts.OnMouseDown(node(11), "LeftButton")
		map.__scripts.OnUpdate(map, 0.02)
		node(11):Click()
		if rp.sel ~= 11 then fail("a press without moving should pick the rune") end
		_G.GetCursorPosition = real
	end
	-- a long 보너스 합계 scrolls (wheel, the bar, its thumb)
	do
		local saved = {}
		for id, lv in pairs(ns.db.runes) do saved[id] = lv end
		for id, n in pairs(R.byId) do ns.db.runes[id] = n.max end
		R.Invalidate()
		Main.Refresh()
		local side = rp.side
		if not (rp.totalN > #side.totalLines) then fail("every rune learned should make the total longer than the list (" .. tostring(rp.totalN) .. ")") end
		if not side.track:IsVisible() then fail("a long total should show its scroll bar") end
		local first = side.totalLines[1].__text
		try("wheel down", side.totalBox.__scripts.OnMouseWheel, side.totalBox, -1)
		if rp.totalOff == 0 or side.totalLines[1].__text == first then fail("the mouse wheel should scroll the total") end
		for _ = 1, 30 do side.totalBox.__scripts.OnMouseWheel(side.totalBox, -1) end
		if rp.totalOff ~= rp.totalN - #side.totalLines then fail("scrolling should stop at the last line") end
		local last = side.totalLines[#side.totalLines].__text
		if not (last or ""):find("%S") then fail("the last line should show at the bottom") end
		try("wheel up", side.totalBox.__scripts.OnMouseWheel, side.totalBox, 30)
		if rp.totalOff ~= 0 then fail("scrolling up should stop at the first line") end
		for id in pairs(ns.db.runes) do ns.db.runes[id] = nil end
		for id, lv in pairs(saved) do ns.db.runes[id] = lv end
		R.Invalidate()
		Main.Refresh()
		if rp.totalN <= #side.totalLines and side.track:IsVisible() then fail("a short total needs no scroll bar") end
	end
	-- sent from another screen: the map moves to the rune and red rings mark
	-- it until another one is picked
	local far = 1902001
	Main.ShowTab("runes", { rune = far })
	if rp.sel ~= far or rp.focus ~= far or not rp.focusFx:IsShown() then fail("a rune another screen points to should be marked") end
	do
		local n = R.byId[far]
		local half = (rp.map:GetWidth() / 2) / rp.cam.z
		if math.abs(rp.cam.x - n.x * 50) > half or rp.cam.z < 1 then fail("the map should move to the rune another screen points to") end
	end
	click("another rune", function(b) return b.node and b.node.id == 11 end)
	if rp.focus or rp.focusFx:IsShown() then fail("picking another rune should drop the mark") end
	Main.ShowTab("hero")
	Main.ShowTab("runes")
	if rp.focusFx:IsShown() then fail("opening the runes from the menu should not mark anything") end
	-- the locked skill slot on the hero screen leads to its rune, marked
	Main.ShowTab("runes", { rune = R.FirstFor("skillSlot") })
	if not rp.focusFx:IsShown() then fail("the skill-slot rune should be marked") end
	if rp.side.goPrev:IsVisible() then
		press("first rune to learn (marked)", rp.side.goPrev)
		if rp.focus ~= rp.sel then fail("the mark should follow '먼저 배울 룬 보기'") end
	end
	hoverAll()
end

-- stages: world, act, stage, travel
do
	Main.ShowTab("map")
	ns.db.prog[1] = 30
	click("world Azeroth", function(b) return b.d == 1 end)
	click("stage 3", function(b) return b.n == 3 and b.disc end)
	click("travel", labelIs("이 스테이지로 이동"))
	if ns.db.stage.idx ~= 3 or ns.db.stage.diff ~= 1 then fail("travelling from the stage screen did not work") end
	click("world Outland", function(b) return b.d == 2 end)
	hoverAll()
	-- the endless tower: closed, then open; pick a floor, go, come back
	do
		local pg = Main.Page("map")
		local was = { ns.db.prog[1], ns.db.prog[2], ns.db.prog[3], ns.db.prog[4] }
		local wasT = { on = ns.db.tower.on, floor = ns.db.tower.floor, best = ns.db.tower.best }
		ns.db.prog = { 30, 30, 30, 29 }
		click("tower card", function(b) return b == pg.towerCard end)
		if not pg.tower or not pg.towerView:IsShown() or pg.nodes[1]:IsShown() then fail("the tower card should show the tower instead of a world's stages") end
		-- the tower's own loading screens, which no stage uses: Dalaran on its
		-- card, Zephra's Isle behind the floor
		do
			local card = tostring(pg.towerCard.scene:GetTexture() or ""):lower()
			local floor = tostring(pg.detail.banner:GetTexture() or ""):lower()
			if not card:find("dalaran", 1, true) then fail("the tower card should show Dalaran's loading screen: " .. card) end
			if not floor:find("zephrasisle", 1, true) then fail("the tower's floor should show Zephra's Isle's loading screen: " .. floor) end
			for d = 1, #ns.DIFFS do
				for i = 1, ns.STAGE_COUNT do
					local k = ns.StageLoadingKey(d, i)
					if k == "dalaran" or k == "zephrasisle" then fail("no stage should use the tower's loading screens") end
				end
			end
		end
		if not pg.detail.go.off then fail("a closed tower cannot be entered") end
		ns.db.prog = { 30, 30, 30, 30 }
		ns.db.tower.best = 7
		click("tower card (open)", function(b) return b == pg.towerCard end)
		if pg.floor ~= 8 then fail("the tower should show the floor after the best: " .. tostring(pg.floor)) end
		press("floor down", pg.towerView.prev)
		if pg.floor ~= 7 then fail("the left button should go down a floor") end
		press("floor up", pg.towerView.next)
		press("floor up (top)", pg.towerView.next)
		if pg.floor ~= 8 then fail("floors past the one after the best cannot be picked") end
		local on = 0
		for i, r in ipairs(pg.towerView.rows) do if not r.icon.__desat then on = i end end
		if on ~= 1 then fail("floor 8 should show one affix lit: " .. on) end
		click("climb", labelIs("8층 도전"))
		if not ns.db.tower.on or ns.db.tower.floor ~= 8 or ns.Combat.state.tower ~= 8 then fail("the button should send the party to the floor") end
		if not (pg.detail.go.off and pg.detail.go.label:GetText() == "지금 싸우는 곳") then fail("the floor being fought should say so") end
		hoverAll()
		Main.ShowTab("hero")
		Main.ShowTab("map")
		if not pg.tower then fail("the stage screen should open on the tower while the party is there") end
		click("world Azeroth (from the tower)", function(b) return b.d == 1 end)
		click("travel back", labelIs("이 스테이지로 이동"))
		if ns.db.tower.on then fail("travelling to a stage should leave the tower") end
		ns.db.prog = { was[1], was[2], was[3], was[4] }
		ns.db.tower.on, ns.db.tower.floor, ns.db.tower.best = wasT.on, wasT.floor, wasT.best
		ns.Combat.StartStage()
		Main.ShowTab("map")
	end
	-- the banner shows the loading screen of the stage's place: Forever's for
	-- the outdoor places (the original one when the client lacks it), the
	-- original game's for dungeons and raids
	local pg = Main.Page("map")
	local function bannerFor(diff, idx)
		pg.diff, pg.idx, pg.act = diff, idx, ns.StageAct(idx)
		Main.Refresh()
		return tostring(pg.detail.banner:GetTexture() or "")
	end
	local tex = bannerFor(1, 15)
	if not tex:find("^Interface\\Glues\\LoadingScreens\\LoadScreenDeadmines$") then fail("the Deadmines stage should show its loading screen: " .. tex) end
	tex = bannerFor(1, 1)
	if not tex:find("camelot160\\main\\loadscreen_camelot_easternkingdom$") then fail("Elwynn Forest should show Forever's Eastern Kingdoms loading screen: " .. tex) end
	tex = bannerFor(1, 2)
	if not tex:find("loadscreen_camelot_oldironforge$") then fail("Dun Morogh should show Forever's Old Ironforge loading screen: " .. tex) end
	tex = bannerFor(1, 4)
	if not tex:find("loadscreen_camelot_kalimdor$") then fail("Durotar should show Forever's Kalimdor loading screen: " .. tex) end
	tex = bannerFor(4, 11)
	if not tex:find("LoadScreenRaid$") then fail("Onyxia's Lair should show the original raid loading screen: " .. tex) end
	local _, t, _, b = pg.detail.banner:GetTexCoord()
	if not (t and b and b - t > 0.1 and b - t < 0.4 and t > 0.2) then fail("a loading screen should show a band of its picture, clear of the logo: " .. tostring(t) .. "-" .. tostring(b)) end
	-- a client without Forever's file: the original screen
	GetFileIDFromPath = function(path) return not path:find("camelot") and 1 or nil end
	tex = bannerFor(1, 1)
	if not tex:find("LoadScreenEasternKingdom$") then fail("without Forever's screen the original one should show: " .. tex) end
	GetFileIDFromPath = nil
	-- every stage and world has a loading screen
	for d = 1, #ns.DIFFS do
		if not ns.WorldLoadingScreen(d) then fail("every world should have a loading screen") end
		for i = 1, ns.STAGE_COUNT do
			if not ns.StageLoadingScreen(d, i) then fail("stage " .. d .. "-" .. i .. " should have a loading screen") end
		end
	end
	Main.Refresh()
end

-- companions: pick one, take it along
do
	Main.ShowTab("pets")
	local pg = Main.Page("pets")
	local mine, notMine
	for _, c in ipairs(pg.cards) do
		if c.pet.id ~= ns.db.pet then
			if ns.db.pets[c.pet.id] then mine = mine or c else notMine = notMine or c end
		end
	end
	if not mine then
		for _, c in ipairs(pg.cards) do
			if c.pet.id ~= ns.db.pet and c ~= notMine then ns.db.pets[c.pet.id] = true mine = c break end
		end
		Main.Refresh()
	end
	if notMine then
		press("a companion not yet won", notMine)
		local was = ns.db.pet
		press("take it along", pg.take)
		if ns.db.pet ~= was then fail("a companion that is not won yet must not come along") end
	end
	press("a won companion", mine)
	if pg.sel ~= mine.pet.id then fail("clicking a companion should choose it") end
	press("take it along", pg.take)
	if ns.db.pet ~= mine.pet.id then fail("데리고 다니기 should take the companion along") end
	hoverAll()
end

-- settings: one page, no tabs; no battle-window size (its corner sets it)
-- and no bag auto break-down (the bag's own switch)
do
	Main.ShowTab("options")
	hoverAll()
	local op = Main.Page("options")
	if op.S then fail("settings should be one page without tabs") end
	if not (op.screen:IsVisible() and op.game:IsVisible()) then fail("every setting should show on the one page") end
	if op.screen.bar or op.game.autoSmelt then fail("settings should not have the battle window size or the bag auto break-down") end
	press("battle window back to default", op.screen.resetPos)
	press("reset everything", op.game.reset)
	local yes, no = ns.UI.ConfirmButtons()
	if not (no and no:IsVisible()) then fail("resetting everything must ask first") else press("cancel the reset", no) end
	if H.Count() == 0 then fail("cancelling the reset must keep the heroes") end
	-- the gear in the title bar opens the settings
	Main.ShowTab("hero")
	press("settings gear", Main.Frame().gear)
	if Main.Current() ~= "options" then fail("the gear in the title bar should open the settings") end
end

-- HUD: goal, auto toggle, chests, menu shortcuts
do
	local bar = BigIdleHeroesBar
	if not bar then
		fail("HUD frame missing")
	else
		Main.Toggle(false)
		local auto = ns.db.opt.auto
		local function glyphOf() return tostring(bar.auto.glyph:GetTexture()):match("([%w_]+)%.tga$") end
		local before = glyphOf()
		if before ~= (auto and "auto" or "repeat") then fail("the auto button should show » when on and the loop when off, got " .. tostring(before)) end
		try("auto toggle", bar.auto.Click, bar.auto, "LeftButton")
		if ns.db.opt.auto == auto then fail("the HUD auto button should toggle auto-advance") end
		if glyphOf() ~= (ns.db.opt.auto and "auto" or "repeat") then fail("the auto button picture should follow the setting") end
		if bar.auto.caption:GetText() ~= (ns.db.opt.auto and "자동 진행" or "반복") then fail("the auto button caption should follow the setting") end
		try("auto toggle back", bar.auto.Click, bar.auto, "LeftButton")
		if glyphOf() ~= before then fail("toggling back should bring the first picture back") end
		-- the chest boxes sit on the dock's middle line
		for t, cb in ipairs(bar.chests) do
			local p, rel, rp, x, y = cb:GetPoint(1)
			if rel ~= bar.dock or p ~= "TOPLEFT" or math.abs(-y * 2 + cb:GetHeight() - bar.dock:GetHeight()) > 0.01 then
				fail("chest box " .. t .. " should be centered in the dock (y " .. tostring(y) .. ")")
			end
		end
		ns.Loot.AddChest(1, 10, 1)
		try("chest", bar.chests[1].Click, bar.chests[1], "LeftButton")
		-- with auto-open learned, a chest's tooltip counts down while the mouse
		-- is on it
		do
			local wasRune = ns.db.runes[13002]
			ns.db.runes[13002] = 1
			ns.Runes.Invalidate()
			local cb = bar.chests[1]
			local function left()
				for _, l in ipairs(ns.UI.TipText()) do
					local v = l:match("^자동 열기까지  (.+)$")
					if v then return v end
				end
			end
			ns.db.autoT[1] = 0
			try("chest hover", cb.__scripts.OnEnter, cb)
			local before = left()
			frames(20, 0.25) -- five seconds with the mouse on it
			local after = left()
			local want = ns.U.time(math.max(0, ns.Loot.AutoInterval(1) - (ns.db.autoT[1] or 0)))
			if not before then fail("a chest's tooltip should show the time to its auto-open") end
			if not after or after == before or after ~= want then
				fail("a chest's tooltip should count down while the mouse is on it: " .. tostring(before) .. " -> " .. tostring(after) .. ", want " .. want)
			end
			if cb.__scripts.OnLeave then cb.__scripts.OnLeave(cb) end
			ns.db.runes[13002] = wasRune
			ns.Runes.Invalidate()
		end
		-- before its own 태엽의 룬: the act boss chest names that rune, and
		-- Alt+click shows it on the rune screen
		do
			local rid = 1902001
			local was = ns.db.runes[rid]
			ns.db.runes[rid] = nil
			ns.Runes.Invalidate()
			local cb = bar.chests[3]
			try("act chest hover", cb.__scripts.OnEnter, cb)
			local named = false
			for _, l in ipairs(ns.UI.TipText()) do
				if l:find("태엽의 룬: 막 우두머리 상자", 1, true) then named = true end
			end
			if not named then fail("the act boss chest should name the rune that opens it by itself") end
			if cb.__scripts.OnLeave then cb.__scripts.OnLeave(cb) end
			Mock.alt = true
			try("act chest alt-click", cb.Click, cb, "LeftButton")
			Mock.alt = nil
			local rp = Main.Page("runes")
			if Main.Current() ~= "runes" or not rp or rp.focus ~= rid then fail("Alt+click on a chest should show its 태엽의 룬 on the rune screen") end
			ns.db.runes[rid] = was
			ns.Runes.Invalidate()
		end
		-- the boxes' borders are bronze, silver and gold; a light runs round
		-- a box's border only while its 태엽의 룬 opens it by itself
		do
			local rid = 13002
			local was = ns.db.runes[rid]
			local cb = bar.chests[1]
			local c = ns.CHEST[1].rgb
			if not (c and c[1] > c[3] and ns.CHEST[3].rgb[1] == 1) then fail("the chest borders should run bronze, silver, gold") end
			local function lit()
				for _, sp in ipairs(cb.sparks or {}) do if sp:IsShown() then return true end end
				return false
			end
			ns.db.runes[rid] = nil
			ns.Runes.Invalidate()
			Mock.Update(0.1)
			if lit() then fail("a chest that does not open by itself should have no light on its border") end
			ns.db.runes[rid] = 1
			ns.Runes.Invalidate()
			Mock.Update(0.1)
			if not lit() then fail("a chest that opens by itself should have a light running round its border") end
			local p1 = { cb.sparks[1]:GetPoint(1) }
			Mock.Update(0.3)
			local p2 = { cb.sparks[1]:GetPoint(1) }
			if p1[4] == p2[4] and p1[5] == p2[5] then fail("the light on a chest's border should move round it") end
			ns.db.runes[rid] = was
			ns.Runes.Invalidate()
			Mock.Update(0.1)
		end
		-- a right-click on a chest stops its auto-open (no light), another
		-- starts it again
		do
			local rid = 13002
			local was = ns.db.runes[rid]
			ns.db.runes[rid] = 1
			ns.Runes.Invalidate()
			local cb = bar.chests[1]
			local function lit()
				for _, sp in ipairs(cb.sparks) do if sp:IsShown() then return true end end
				return false
			end
			try("chest right-click", cb.Click, cb, "RightButton")
			Mock.Update(0.1)
			if not ns.Loot.AutoStopped(1) or lit() then fail("a right-click on a chest should stop its auto-open and its light") end
			try("chest hover", cb.__scripts.OnEnter, cb)
			local said = false
			for _, l in ipairs(ns.UI.TipText()) do if l:find("자동 열기 멈춤", 1, true) then said = true end end
			if not said then fail("a stopped chest's tooltip should say its auto-open is stopped") end
			if cb.__scripts.OnLeave then cb.__scripts.OnLeave(cb) end
			try("chest right-click again", cb.Click, cb, "RightButton")
			Mock.Update(0.1)
			if ns.Loot.AutoStopped(1) or not lit() then fail("another right-click should start the auto-open and its light again") end
			ns.db.runes[rid] = was
			ns.Runes.Invalidate()
			Mock.Update(0.1)
		end
		if #bar.menu ~= 7 then fail("the HUD menu should have the seven screens") end
		for _, mb in ipairs(bar.menu) do
			try("menu " .. mb.key, mb.Click, mb, "LeftButton")
			if Main.Current() ~= mb.key then fail("HUD menu button " .. mb.key .. " should open its screen") end
		end
		-- the goal button either acts or opens a screen; give it something to do
		local hid = ns.db.party[2]
		ns.Heroes.AddXP(hid, ns.XPForLevel(ns.db.heroes[hid].level) + 1)
		ns.Guide.Invalidate()
		Main.Toggle(false)
		try("goal", bar.goal.Click, bar.goal, "LeftButton")
		if not (Main.IsShown() and Main.Current() == "hero") then fail("the goal button should open the hero screen for talent points") end
		-- recruiting from the recommendation without the gold: the warning
		-- only, neither the menu nor the recruit window opens
		do
			local realCurrent, gold = ns.Guide.Current, ns.db.gold
			ns.Guide.Current = function()
				return { text = "탱커 영웅 모집하기 (300 G)", tab = "hero", create = "TANK", wait = true }
			end
			ns.db.gold = 0
			local said
			ns.On("TOAST", function(m) said = said or m end)
			Main.CloseModal()
			Main.Toggle(false)
			try("goal without gold", bar.goal.Click, bar.goal, "LeftButton")
			local modal = Main.Frame().modal
			if Main.IsShown() or modal:IsShown() then fail("recruiting without the gold should not open the menu or the recruit window") end
			if not (said and said:find("골드가 부족합니다", 1, true)) then fail("recruiting without the gold should say so: " .. tostring(said)) end
			-- the same from the hero screen's own paths
			Main.Toggle(true)
			ns.OpenCreate("TANK")
			if modal:IsShown() then fail("the recruit window should not open without the gold") end
			ns.Guide.Current = realCurrent
			ns.db.gold = gold
			ns.Guide.Invalidate()
		end
		-- every goal fits its box: the text stops clear of the » on the right
		-- and runs to two lines at most (no gold amount after a rune's name)
		do
			local G = ns.Bar.GOAL
			local gt = bar.goal.text
			if G.textX + G.textW > G.w - 8 - 14 then fail("the goal's text should stop before the » on the right of its box") end
			if math.abs((gt.__w or 0) - G.textW) > 1e-6 then fail("the goal's text should be as wide as the box leaves it: " .. tostring(gt.__w)) end
			local texts = {}
			for _, g in ipairs(ns.Guide.Candidates()) do texts[#texts + 1] = g.text end
			-- each forge unlock (as the guide words it), with the others done
			local unlocked, useful, lv = ns.Forge.Unlocked, ns.Guide.UnlockUseful, ns.db.forge.level
			ns.db.forge.level = 99
			ns.Guide.UnlockUseful = function() return true end
			for _, op in ipairs(ns.FORGE_OPS) do
				ns.Forge.Unlocked = function(k) return k ~= op.key end
				for _, g in ipairs(ns.Guide.Candidates()) do texts[#texts + 1] = g.text end
			end
			ns.Forge.Unlocked, ns.Guide.UnlockUseful, ns.db.forge.level = unlocked, useful, lv
			-- the rune goals, with every rune's name; the place goals, with every
			-- stage's and raid boss's
			for id, r in pairs(ns.Runes.byId) do texts[#texts + 1] = "룬 배우기: " .. ns.N(r.name) end
			for d = 1, #ns.STAGE_SCENERY do
				for i = 1, 30 do
					local stg = ns.Stage(d, i)
					if stg then
						texts[#texts + 1] = "지금 지역 공략 중: " .. ns.N(stg.name)
						if stg.boss then texts[#texts + 1] = "공격대 우두머리 처치: " .. ns.N(stg.boss.name) end
					end
				end
			end
			local was = gt:GetText()
			local worst, worstW = nil, 0
			for _, t in ipairs(texts) do
				if t:find("룬 배우기") and t:find(" G") then fail("a rune goal should name the rune only: " .. t) end
				gt:SetText(t)
				local w = gt:GetStringWidth()
				if w > worstW then worst, worstW = t, w end
			end
			if worstW > 2 * G.textW then fail(string.format("every goal should fit two lines of its box: '%s' (%.0f > %.0f)", worst, worstW, 2 * G.textW)) end
			gt:SetText(was)
		end
		ns.db.ui.locked = false
		try("grip down", bar.grip.__scripts.OnMouseDown, bar.grip, "LeftButton")
		try("grip move", bar.grip.__scripts.OnUpdate, bar.grip, 0.1)
		try("grip up", bar.grip.__scripts.OnMouseUp, bar.grip, "LeftButton")
		if not ns.db.ui.barScale then fail("resizing with the corner grip should save the size") end
		try("grip reset", bar.grip.__scripts.OnMouseUp, bar.grip, "RightButton")
		if ns.db.ui.barScale ~= 1 then fail("right-clicking the grip should restore the size") end
		try("drag start", bar.__scripts.OnDragStart, bar)
		try("drag stop", bar.__scripts.OnDragStop, bar)
		try("bar right-click", bar.__scripts.OnMouseUp, bar, "RightButton")
		if not (ns.db.ui.barPos and ns.db.ui.barPos[1]) then fail("HUD position was not saved") end
		ns.db.ui.compact = true
		try("compact", ns.Bar.ApplyCompact)
		ns.db.ui.compact = nil
		try("full", ns.Bar.ApplyCompact)
	end
end

------------------------------------------------------------------------
-- click everything, several rounds, with random mouse buttons
------------------------------------------------------------------------
local clickTabs = { "party", "hero", "equip", "equip", "equip", "runes", "map", "pets", "options", "hero", "hero" }
local clicks = 0
for round = 1, 50 do
	for _, key in ipairs(clickTabs) do
		if not Main.IsShown() then try("reopen", Main.Toggle, true) end
		try("show " .. key, Main.ShowTab, key)
		for _ = 1, 14 do
			if not Main.IsShown() then
				try("reopen", Main.Toggle, true)
				try("show " .. key, Main.ShowTab, key)
			end
			local buttons = Mock.VisibleButtons()
			local b = #buttons > 0 and buttons[math.random(1, #buttons)] or nil
			if b and b:IsVisible() and not b.__disabled then
				local mouse = math.random() < 0.3 and "RightButton" or "LeftButton"
				clicks = clicks + 1
				if not try("click [" .. key .. "] " .. tostring(label(b) or (b.data and "icon") or "?") .. " " .. mouse, b.Click, b, mouse) then break end
				Mock.Hover(b)
			end
		end
		frames(4)
		enrich(round)
	end
end
print("  clicked " .. clicks .. " buttons")

-- slash commands, compartment
try("slash", SlashCmdList.BIGIDLEHEROES, "")
try("slash bar", SlashCmdList.BIGIDLEHEROES, "bar")
frames(20)
try("slash bar", SlashCmdList.BIGIDLEHEROES, "bar")
try("slash reset", SlashCmdList.BIGIDLEHEROES, "reset")
try("slash help", SlashCmdList.BIGIDLEHEROES, "help")

-- the battle bar draws heroes and monsters as the game's 3D models: each one
-- a small ModelScene with one actor, put up by its display id, measured and
-- stood on the ground line at its given height
local function animOf(fig) return fig.actor and fig.actor.__anim or fig.__anim end
do
	local Fig = ns.Figure3D
	Fig.ResetFailed()
	ns.db.opt.models = true
	-- a known party at the first stage (the random clicks leave any party
	-- and roster): a tank, casters with missiles, a hunter and a healer, fresh
	ns.db.heroes = {}
	for i, sid in ipairs({ "WARRIOR_PROT", "MAGE_FIRE", "SHAMAN_ELE", "HUNTER_MM", "PRIEST_HOLY" }) do
		ns.db.party[i] = ns.Heroes.NewRecord(sid).id
	end
	ns.db.stage.diff, ns.db.stage.idx = 1, 1
	ns.Stats.Invalidate()
	-- all five party slots open (they come from runes, which may be reset)
	local partyLimit = ns.PartyLimit
	ns.PartyLimit = function() return ns.PARTY_SIZE end
	ns.Combat.StartStage()
	frames(40)
	local heroes, mobs = ns.Bar.UnitFrames()
	local hShown, mShown = 0, 0
	for _, f in ipairs(heroes) do
		local m = f.model
		if f:IsShown() and m and m:IsShown() then
			hShown = hShown + 1
			if m.kind ~= "scene" then fail("a battle figure should be a ModelScene") end
			-- the player's body as the hero's race, undressed, in the class's
			-- dungeon set; a druid in its form or the mech stays an NPC
			local u
			for _, x in ipairs(ns.Combat.heroes) do if x.id == f.shownId then u = x end end
			local body = u and Fig.HeroBody(u.id, true)
			if body then
				local cls = ns.SPECS[ns.db.heroes[u.id].spec].class
				local race = ns.ClassRace(cls)
				-- the player's own body as the race, in the player's gender
				if m.actor.__display ~= "unit:player" or m.actor.__race ~= ns.MODEL.raceId[race] or m.actor.__dressed then
					fail("a hero should be the player's body as its race (" .. race .. "), undressed: " .. tostring(m.actor.__display) .. " " .. tostring(m.actor.__race))
				end
				local worn = m.actor.__worn or {}
				local w = ns.MODEL.weaponTier[ns.GearTier()][ns.db.heroes[u.id].spec]
				local nW = (w.mh and 1 or 0) + (w.oh and 1 or 0)
				if #worn ~= #body.items + nW or #body.items == 0 then fail("a hero should wear its class's dungeon set and its weapons: " .. #worn .. " pieces") end
				-- the spec's dungeon weapons in its hands, drawn
				local hands = m.actor.__hands or {}
				if hands.MAINHANDSLOT ~= "item:" .. w.mh or (w.oh and hands.SECONDARYHANDSLOT ~= "item:" .. w.oh) then
					fail("a hero should hold its spec's weapons: " .. tostring(hands.MAINHANDSLOT) .. " " .. tostring(hands.SECONDARYHANDSLOT))
				end
				if m.actor.__noWeapons then fail("a hero's body should not hide its weapons") end
			else
				local want = Fig.DisplayFor(m.id)
				if m.actor.__display ~= want then fail("a hero in another shape should be put up by its display id: " .. tostring(m.actor.__display) .. " / " .. tostring(want)) end
			end
			if not m:IsLoaded() or f.icon:IsShown() then fail("a hero whose model is in should not show the icon too") end
			-- a square frame with room around the model
			if math.abs(m:GetWidth() - m:GetHeight()) > 1e-6 or m:GetHeight() < 2.5 * m.height then fail("a figure's frame should be square with room around the model") end
			-- right: away from the camera's "right" (seen in game), 270° in the mock
			if math.abs((m.actor.__yaw or 0) - 3 * math.pi / 2) > 1e-6 then fail("hero models should face the monsters (right): " .. tostring(m.actor.__yaw)) end
		end
	end
	for _, f in ipairs(mobs) do
		local m = f.model
		if f:IsShown() and m and m:IsShown() then
			mShown = mShown + 1
			if m:IsLoaded() and math.abs((m.actor.__yaw or 0) - math.pi / 2) > 1e-6 then fail("monster models should face the heroes (left)") end
		end
	end
	if hShown == 0 then fail("the heroes in battle should be 3D models") end
	if mShown == 0 then fail("the monsters in battle should be 3D models") end
	if #Mock.misuse > 0 then fail("ModelScene calls with bad arguments: " .. table.concat(Mock.misuse, "; ")) end
	-- skills play the game's spell effects: kits on the fighters' models and
	-- missiles (model files) flying from caster to target
	do
		Mock.kits = {}
		local flown = ns.Bar.fxStats.missiles
		local sawMissile, hit = false, nil
		local hitFiles, handFiles = {}, {}
		for _, e in pairs(ns.SKILL_FX) do if e.hit then hitFiles["file:" .. e.hit] = true end end
		for _, f in pairs(ns.KIT_HAND) do handFiles["file:" .. f] = true end
		local hand
		for _ = 1, 600 do
			frames(1)
			for _, ms in ipairs(ns.Bar.missiles) do
				if ms.active and type(ms.fig.actor.__display) == "string" and ms.fig.actor.__display:find("^file:") then sawMissile = true end
			end
			-- a missile is in the air for a moment only: counted when it leaves
			if ns.Bar.fxStats.missiles > flown then sawMissile = true end
			for _, hs in ipairs(ns.Bar.hits) do
				-- (a skill's hit, not a caster's smaller basic bolt: hs.size)
				if not hit and hs.active and not hs.size and hs.fig:IsShown() and hs.fig:IsLoaded() and hitFiles[hs.fig.actor.__display] then
					local t = hs.tfig
					hit = { scale = hs.fig.actor.__scale or 0, height = hs.fig.height, want = (t.fixedScale or (t.norm or 0.5) * (t.corrScale or 1)), tall = t.height,
						parent = hs.fig:GetParent() }
				end
			end
			-- the glow in a caster's hands: the kit's hand model, sized to the caster
			for _, hs in ipairs(ns.Bar.hits) do
				if not hand and hs.active and hs.hand and hs.fig:IsShown() and hs.fig:IsLoaded() and handFiles[hs.fig.actor.__display] then
					local t = hs.tfig
					local ts = t.fixedScale or (t.norm or 0.5) * (t.corrScale or 1)
					hand = { scale = hs.fig.actor.__scale or 0, want = 0.8 * ts, x = hs.fig.anchorX, cx = t.anchorX, facing = t.facing, figFacing = hs.fig.facing }
				end
			end
			if sawMissile and hit and hand then break end
		end
		-- a kit on a model is drawn at its own size whatever the model's scale:
		-- none in battle
		if #Mock.kits > 0 then fail("battle figures should not play spell kits (" .. #Mock.kits .. ")") end
		if not hand then
			fail("a cast should show the glow in the caster's hands")
		else
			if math.abs(hand.scale - hand.want) > 1e-6 then fail(string.format("the glow in the hands should be 0.8 of the caster's scale: %.3f, want %.3f", hand.scale, hand.want)) end
			if (hand.facing == "left" and hand.x >= hand.cx) or (hand.facing ~= "left" and hand.x <= hand.cx) then fail("the glow should be at the caster's front hand") end
			if hand.figFacing ~= hand.facing then fail("the glow in the hands should face the way its caster does") end
		end
		if not sawMissile then fail("a skill with a missile should fly it from the caster to the target") end
		local known = false
		for _, e in pairs(ns.SKILL_FX) do if e.missile and e.missile == ns.Bar.fxStats.lastMissile then known = true end end
		-- or a hunter's arrow or bullet
		for _, e in pairs(ns.MODEL.SHOT) do if e.missile and e.missile == ns.Bar.fxStats.lastMissile then known = true end end
		if sawMissile and not known then fail("a flying missile should be its spell's missile model") end
		-- a hunter shoots: its bow or crossbow animation for an attack, and an
		-- arrow (a bullet from a gun) flies to the target a moment later
		do
			local hu, hf
			for i, x in ipairs(ns.Combat.heroes) do if x.class == "HUNTER" then hu, hf = x, heroes[i] end end
			local mob
			for _ = 1, 300 do -- (between waves: until the next one is in)
				for _, m in ipairs(ns.Combat.mobs) do if not m.dead then mob = m break end end
				if mob then break end
				frames(1)
			end
			if hu and hf and hf.figIs and mob then
				local shot = ns.Bar.ShotOf(hu)
				local body = Fig.HeroBody(hu.id, true)
				local kind = ns.MODEL.rangedKind[body.weapons.mh]
				if not (kind and shot == ns.MODEL.SHOT[kind]) then fail("a hunter's shot should follow the weapon in its hands: " .. tostring(kind)) end
				if hf.figIs:AnimId("attack") ~= shot.anim then fail("a hunter should attack with its bow or rifle animation: " .. tostring(hf.figIs:AnimId("attack"))) end
				local before = ns.Bar.fxStats.missiles
				ns.Combat.vfx[#ns.Combat.vfx + 1] = { k = "shot", u = hu, to = { mob } }
				frames(5)
				-- (a skill's missile may fly in the same frames)
				local seen = ns.Bar.fxStats.seen or {}
				if ns.Bar.fxStats.missiles <= before or (seen[shot.missile] or 0) <= before then
					fail("a hunter's basic attack should fly its arrow to the target: " .. tostring(ns.Bar.fxStats.lastMissile))
				end
			else
				fail("the battle check should have a hunter and a monster on screen")
			end
			-- a caster's basic attack: its school's small bolt (holy: Smite's
			-- light on the target), smaller than a skill's
			do
				local caster, cfx
				for _, x in ipairs(ns.Combat.heroes) do
					local b = x.ranged and ns.BasicFx(x.class, x.school)
					if b and b.missile and not caster then caster, cfx = x, b end
				end
				if caster and mob then
					local before = ns.Bar.fxStats.missiles
					ns.Combat.vfx[#ns.Combat.vfx + 1] = { k = "shot", u = caster, to = { mob } }
					frames(5)
					local seen = ns.Bar.fxStats.seen or {}
					if (seen[cfx.missile] or 0) <= before then
						fail("a " .. caster.spec .. "'s basic attack should fly its school's bolt: " .. tostring(ns.Bar.fxStats.lastMissile))
					end
					local small
					for _, ms in ipairs(ns.Bar.missiles) do
						if ms.active and ms.fx == cfx then small = ms end
					end
					if small and not (small.fig.fixedScale and small.fx.size == ns.BASIC_FX_SIZE) then
						fail("a caster's basic bolt should be drawn smaller than a skill's")
					end
				else
					fail("the battle check should have a caster with a bolt and a monster on screen")
				end
				if ns.BasicFx("HUNTER", "phys") ~= nil or ns.BasicFx("DRUID", "nature") ~= ns.BASIC_FX.wrath
					or ns.BasicFx("SHAMAN", "nature") ~= ns.BASIC_FX.nature or ns.BASIC_FX.holy.missile ~= nil then
					fail("basic bolts: none for hunters, Wrath for druids, Lightning Bolt for shamans, no bolt for holy")
				end
			end
			-- the others: casters and healers cast at the target, the rest swing
			for i, x in ipairs(ns.Combat.heroes) do
				local want = x.class == "HUNTER" and ns.Bar.ShotOf(x).anim or (x.ranged and 53 or 17)
				if heroes[i].figIs and heroes[i].figIs:AnimId("attack") ~= want then
					fail("a " .. x.spec .. "'s attack should be animation " .. want .. ": " .. tostring(heroes[i].figIs:AnimId("attack")))
				end
			end
		end
		-- effects are drawn straight into the scene (the game shows nothing of
		-- an effect drawn on its own); the fighters on their own, over the scenery
		for _, pool in ipairs({ ns.Bar.missiles, ns.Bar.hits }) do
			for _, ms in ipairs(pool) do
				if ms.fig.__overlap ~= true then fail("a spell effect should be drawn as the fighters are (as the model check shows it)") break end
			end
		end
		for _, f in ipairs(heroes) do
			if f.model and f.model.kind == "scene" and f.model.__overlap ~= true then fail("a fighter should be drawn on its own, over the scenery") break end
		end
		-- a hit is the spell's impact model next to its target, half as big
		-- as the target's own scale, in a figure as tall as the target
		if not hit then
			fail("a skill's hit should show the spell's impact model on the target")
		else
			if math.abs(hit.scale - hit.want) > 1e-6 then
				fail(string.format("a hit should be as big as next to a character in the game (the target's scale) (%.3f, want %.3f)", hit.scale, hit.want))
			end
			if math.abs(hit.height - hit.tall) > 1e-6 then fail("a hit's figure should be as tall as its target's") end
			-- straight in the battle scene, as the model check shows it (no clipping box)
			if hit.parent ~= ns.Bar.Scene() then fail("a hit should be drawn straight in the battle scene") end
		end
		if #Mock.misuse > 0 then fail("effect calls with bad arguments: " .. table.concat(Mock.misuse, "; ")) end
		-- an effect model's bounding box (most are far bigger than their glow)
		-- does not shrink it: a fire nova with a huge box is as big as any hit
		do
			local wide = ns.MobFx("aoe", "fire")
			Mock.boxes["file:" .. wide.hit] = { -6, -6, 0, 6, 6, 1 }
			local target = ns.Combat.heroes[1]
			local boss0
			for _, m in ipairs(ns.Combat.mobs) do if not m.dead then boss0 = m break end end
			if boss0 and target then
				ns.Combat.VFX({ k = "mob", u = boss0, kind = "aoe", school = "fire", to = { target } })
				local big
				for _ = 1, 30 do
					frames(1)
					for _, hs in ipairs(ns.Bar.hits) do
						if hs.active and hs.fig:IsLoaded() and hs.fig.actor.__display == "file:" .. wide.hit and hs.tfig ~= nil then big = big or hs end
					end
				end
				if big then
					local tf = big.tfig
					local ts = tf.fixedScale or (tf.norm or 0.5) * (tf.corrScale or 1)
					if math.abs((big.fig.actor.__scale or 0) - ts) > 1e-6 then fail("an effect's own bounding box should not shrink it") end
				else
					fail("a boss's fire nova should show its ring")
				end
			end
			Mock.boxes["file:" .. wide.hit] = nil
		end
		-- an effect on its caster (a slash, a shout) faces the way the caster
		-- does; its hit on a monster faces the way it flies (toward the monster)
		do
			local war, wf
			for i, x in ipairs(ns.Combat.heroes) do if x.class == "WARRIOR" then war, wf = x, heroes[i] end end
			-- a monster that is alive and drawn (its model in)
			local _, mobFr = ns.Bar.UnitFrames()
			local function liveMob()
				for _ = 1, 300 do
					for i, m in ipairs(ns.Combat.mobs) do
						local mf = mobFr[i] and mobFr[i].figIs
						if not m.dead and mf and mf:IsShown() and mf:IsLoaded() then return m end
					end
					frames(1)
				end
			end
			local mob = liveMob()
			local fx = ns.SKILL_FX.cleave
			if war and wf and wf.figIs and mob and fx then
				local own, onMob
				for _ = 1, 3 do -- (again with another monster if this one fell meanwhile)
					ns.Combat.VFX({ k = "skill", u = war, sid = "cleave", to = { mob } })
					for _ = 1, 4 do
						frames(1)
						for _, hs in ipairs(ns.Bar.hits) do
							if hs.active and hs.fig.actor.__display == "file:" .. fx.self then own = hs.fig.facing end
							if hs.active and hs.fig.actor.__display == "file:" .. fx.hit and hs.tfig ~= wf.figIs then onMob = hs.fig.facing end
						end
					end
					if onMob then break end
					mob = liveMob() or mob
				end
				if own ~= wf.figIs.facing then fail("an effect on its caster should face the way the caster does: " .. tostring(own) .. " / " .. tostring(wf.figIs.facing)) end
				if onMob ~= "right" then fail("a hit on a monster should face the way it flies (toward the monster): " .. tostring(onMob)) end
			else
				fail("the battle check should have a warrior and a monster for the effect facing")
			end
			-- every effect's frame leaves room all around its origin (nothing
			-- of it is cut off where the frame ends): FX_ROOM figure heights
			-- across, the origin in its middle
			local room = ns.Bar.FX_ROOM
			for _, pool in ipairs({ ns.Bar.missiles, ns.Bar.hits }) do
				for _, ms in ipairs(pool) do
					local f = ms.fig
					if f.side ~= room or f.feetAt ~= room / 2 then fail("an effect's frame should be " .. tostring(room) .. " heights across with its origin in the middle") break end
					if f.height and math.abs(f:GetWidth() - f.height * room) > 1e-6 then fail("an effect's frame should be as wide as its room") break end
				end
			end
			-- a beast (a druid's cat or bear) does its blows at its front, not
			-- at the middle of its long body: the cat in front of its head, the
			-- bear at its head and paws; a hit on a beast lands on its chest
			local bh, bf
			for i, x in ipairs(ns.Combat.heroes) do
				if x ~= war and heroes[i].figIs and heroes[i].figIs:IsLoaded() and not bh then bh, bf = x, heroes[i] end
			end
			local bite = ns.SKILL_FX.ferocious_bite
			if war and wf and wf.figIs and mob and fx and bh and bite then
				local cfig, bfig = wf.figIs, bf.figIs
				local was = Fig.HeroForm
				Fig.HeroForm = function(id, c)
					if id == war.id then return "cat" end
					if id == bh.id then return "bear" end
					return was(id, c)
				end
				frames(1)
				local smash = ns.MobFx("smash", "fire")
				ns.Combat.VFX({ k = "skill", u = war, sid = "ferocious_bite", to = { mob } })
				ns.Combat.VFX({ k = "skill", u = war, sid = "rake", to = { mob } })
				ns.Combat.VFX({ k = "skill", u = bh, sid = "cleave", to = { mob } })
				ns.Combat.VFX({ k = "mob", u = mob, kind = "smash", school = "fire", to = { war } })
				local catX, catY, bearX, onX, clawY
				for _ = 1, 6 do
					frames(1)
					for _, hs in ipairs(ns.Bar.hits) do
						if hs.active and not hs.hand and hs.fig:IsShown() then
							-- (offsets from the body, read in the frame they were placed)
							local d = hs.fig.actor.__display
							if hs.tfig == cfig and d == "file:" .. bite.self then catX, catY = hs.fig.anchorX - cfig.anchorX, hs.fig.anchorY - cfig.anchorY end
							if hs.tfig == cfig and d == "file:" .. ns.SKILL_FX.rake.self then clawY = hs.fig.anchorY - cfig.anchorY end
							if hs.tfig == cfig and d == "file:" .. smash.hit then onX = hs.fig.anchorX - cfig.anchorX end
							if hs.tfig == bfig and d == "file:" .. fx.self then bearX = hs.fig.anchorX - bfig.anchorX end
						end
					end
				end
				local function half(f)
					local b = f.box
					return b and math.abs(b[4] - b[1]) / 2 * (f.fixedScale or (f.norm or 0.5) * (f.corrScale or 1)) * f.height or 0
				end
				local function dirOf(f) return f.facing == "left" and -1 or 1 end
				local ch, bhalf = half(cfig) * dirOf(cfig), half(bfig) * dirOf(bfig)
				Fig.HeroForm = was
				frames(1)
				if ch == 0 or bhalf == 0 then fail("the beast check needs measured bodies") end
				if not catX or math.abs(catX - 1.15 * ch) > 1e-6 then
					fail(string.format("a cat's own blow should come out in front of its head: %s, want %.2f", tostring(catX), 1.15 * ch))
				end
				if catY and math.abs(catY - cfig.height * 0.55) > 1e-6 then fail("a cat's bite should be at its head's height") end
				if not clawY or math.abs(clawY - cfig.height * ns.Bar.LOW_OWN.cat) > 1e-6 then
					fail(string.format("a cat's claw should come out low by its paws: %s, want %.2f", tostring(clawY), cfig.height * ns.Bar.LOW_OWN.cat))
				end
				if not bearX or math.abs(bearX - 0.7 * bhalf) > 1e-6 then
					fail(string.format("a bear's own blow should come out at its front: %s, want %.2f", tostring(bearX), 0.7 * bhalf))
				end
				if not onX or math.abs(onX - 0.4 * ch) > 1e-6 then
					fail(string.format("a hit on a beast should land on its chest: %s, want %.2f", tostring(onX), 0.4 * ch))
				end
				if cfig.beast or bfig.beast then fail("a hero out of its form should not be a beast") end
			else
				fail("the beast check should have a warrior, another hero and a monster")
			end
			-- every attack the cat makes shows on the cat itself (in front of
			-- its head): its claws (shred, rake) low by its paws, the rest at
			-- its head's height
			local CLAW = { shred = true, rake = true }
			for _, sid in ipairs({ "shred", "rake", "ferocious_bite", "tigers_fury" }) do
				local e = ns.SKILL_FX[sid]
				if not (e and e.self) then fail("the cat's " .. sid .. " should show on the cat") end
				if e and (e.selfLow and true or false) ~= (CLAW[sid] or false) then fail("the cat's " .. sid .. " is at the wrong height") end
			end
		end
		-- a boss ability is a classic spell: its name shows, its cast plays
		-- on the boss and its hit on whom it reaches
		local boss
		for _, m in ipairs(ns.Combat.mobs) do if not m.dead then boss = m break end end
		if boss then
			local sp = ns.MobFx("aoe", "shadow")
			Mock.kits = {}
			ns.Combat.VFX({ k = "mob", u = boss, kind = "aoe", school = "shadow", to = { ns.Combat.heroes[1] } })
			local sawHit
			for _ = 1, 30 do
				frames(1)
				for _, hs in ipairs(ns.Bar.hits) do
					if hs.active and hs.fig.actor.__display == "file:" .. sp.hit then sawHit = true end
				end
			end
			local castOk = ns.KIT_HAND[sp.cast] == nil
			for _ = 1, 3 do
				for _, hs in ipairs(ns.Bar.hits) do
					if hs.hand and hs.fig.actor.__display == "file:" .. tostring(ns.KIT_HAND[sp.cast]) then castOk = true end
				end
			end
			if not castOk then fail("a boss ability should show its spell's cast in the boss's hands") end
			if #Mock.kits > 0 then fail("a boss's cast should not be a kit on its model") end
			if not sawHit then fail("a boss ability should show its spell's hit on the heroes") end
		end
		for kind, t in pairs(ns.MOB_FX) do
			local list = t.spell and { t } or t
			for _, sp in pairs(list) do
				if not (sp.spell and (sp.hit or sp.cast)) then fail("every boss ability should be a spell with an effect: " .. kind) end
				if kind ~= "summon" and not sp.name then fail("a boss ability should have its spell's name: " .. kind) end
			end
		end
	end
	-- a melee summon (the hunter's pet) fights at the front, by the monsters;
	-- the companion stands behind the whole party
	do
		local u = ns.Combat.heroes[4]
		local petId = ns.PETS[1] and ns.PETS[1].id
		ns.db.pets[petId] = ns.db.pets[petId] or true
		local wasPet = ns.db.pet
		ns.db.pet = petId
		u.pets = { call_pet = { sk = ns.SKILLS.call_pet, mult = 0.5, t = 1, anim = 0 } }
		frames(3)
		local summons, petFig = ns.Bar.Summons()
		local front, back
		for i, f in ipairs(heroes) do
			if f:IsShown() and f.drawX then
				front = front and math.max(front, f.drawX) or f.drawX
				back = back and math.min(back, f.drawX) or f.drawX
			end
		end
		-- walking: by its summoner; fighting: up front by the monsters, walked there
		local st = ns.Combat.state
		local was = st.phase
		local s1 = summons[1]
		local own = heroes[4].drawX
		st.phase = "travel"
		for _ = 1, 40 do ns.Bar.DrawHeroes() end
		if not (s1 and s1:IsShown() and s1.anchorX and own and math.abs(s1.anchorX - (own + 17 + 20)) < 3) then
			fail("a melee summon should walk beside its summoner: " .. tostring(s1 and s1.anchorX) .. " / " .. tostring(own))
		end
		st.phase = "fight"
		ns.Bar.DrawHeroes()
		local x1 = s1 and s1.anchorX
		if s1 and s1.sx and front and s1.anchorX > front + 17 + 10 then fail("a melee summon should walk to the front, not jump there") end
		for _ = 1, 40 do ns.Bar.DrawHeroes() end
		if not (s1 and s1:IsShown() and s1.anchorX and front and s1.anchorX > front + 17 + 10) then
			fail("a melee summon should stand at the front, by the monsters, while the party fights: " .. tostring(s1 and s1.anchorX) .. " / " .. tostring(front))
		end
		if x1 and s1.anchorX and s1.anchorX <= x1 then fail("a melee summon should go forward when the fight starts") end
		-- the hunter's pet a little smaller than a druid's cat
		local catTall = ns.Bar.FIG.hero * ns.Bar.CatScale()
		if not (s1 and s1.height and math.abs(s1.height - catTall * 0.8) < 0.01) then
			fail(string.format("the hunter's pet should be a little smaller than a druid's cat: %s / %.1f", tostring(s1 and s1.height), catTall))
		end
		-- it goes back into formation as fast as its summoner falls back (as
		-- the melee heroes do), not slower
		if s1 and s1.sx then
			st.phase = "travel"
			local x0 = s1.sx
			ns.Bar.DrawHeroes(0.1)
			local want = ns.Bar.LaneX(ns.Combat.HeroSpeed(u) * ns.Combat.BACK_PACE) * 0.1
			if math.abs((x0 - s1.sx) - want) > 1e-6 then
				fail(string.format("a melee summon should fall back as fast as its summoner: %.2f px in 0.1 s, want %.2f", x0 - s1.sx, want))
			end
		end
		st.phase = was
		if petFig and petFig:IsShown() and back and not (petFig.anchorX < back) then
			fail("the companion should stand behind the whole party: " .. tostring(petFig.anchorX) .. " / " .. tostring(back))
		end
		-- the party jumps to a new place (as after a fight): the companion
		-- walks after it at a steady pace, never in hops
		if petFig and petFig:IsShown() then
			local xs = {}
			for i, h in ipairs(ns.Combat.heroes) do xs[i] = h.x; h.x = h.x + 30 end
			local last, biggest, moved = petFig.anchorX, 0, 0
			for _ = 1, 40 do
				ns.Bar.DrawHeroes()
				local d = math.abs(petFig.anchorX - last)
				biggest = math.max(biggest, d)
				moved = moved + d
				last = petFig.anchorX
			end
			if moved < 20 then fail("the companion should follow the party to its new place: " .. moved) end
			if biggest > 140 * 0.1 + 0.5 then fail("the companion should walk, not hop: " .. biggest .. " in one frame") end
			for i, h in ipairs(ns.Combat.heroes) do h.x = xs[i] end
			for _ = 1, 40 do ns.Bar.DrawHeroes() end
		end
		u.pets = {}
		ns.db.pet = wasPet
	end
	-- the place's own trees and rocks stand behind the fight in three rows,
	-- each as tall as its row makes it, and go by while the party walks on
	do
		local sc, units = ns.Bar.Scenery()
		local st = ns.Combat.state
		-- (the stage the run is on may be seen from inside: an outdoor one)
		local sceneryFor = ns.SceneryFor
		ns.SceneryFor = function() return ns.SCENERY.elwynn end
		ns.db.opt.scenery = true -- (the settings check may have been clicked off)
		local set = ns.SCENERY.elwynn
		if not (sc and set and units) then fail("the battle should have the stage's scenery") else
			for _, f in ipairs(set.far) do Mock.boxes["file:" .. f] = { -3, -3, 0, 3, 3, 10 } end
			-- every near model made too big for the near row: none of them stands there
			for _, f in ipairs(set.near) do Mock.boxes["file:" .. f] = { -1, -1, 0, 1, 1, 20 } end
			sc.set, sc.bad = nil, {} -- put up again with the boxes above (loaded again, measured again)
			for _, row in ipairs(sc.rows) do for _, it in ipairs(row.items) do it.fig.id = nil end end
			frames(4)
			if heroes[1]:GetParent() ~= units then fail("the fighters should be on the layer above the scenery") end
			local shown = 0
			for r, row in ipairs(sc.rows) do
				local def = row.def
				for _, it in ipairs(row.items) do
					local fig = it.fig
					if fig:GetFrameLevel() >= units:GetFrameLevel() then fail("scenery should be drawn behind the fighters") end
					if it.file and fig:IsShown() then
						shown = shown + 1
						local ok = false
						for _, f in ipairs(set[def.key]) do if f == it.file then ok = true end end
						if not ok then fail("a scenery model should be one of its place's: " .. tostring(it.file)) end
						if def.key == "near" and it.sized then fail("a model too big for its row should be swapped") end
						if it.sized then
							local b = fig.box
							local drawn = fig.height * (b[6] - b[3]) * fig.norm
							if drawn < def.lo * 0.84 or drawn > def.hi * 1.16 then
								fail(string.format("a %s scenery model should be %d..%d tall: %.1f", def.key, def.lo, def.hi, drawn))
							end
						end
					end
				end
			end
			-- every row solid: no model see-through or greyed
			for _, row in ipairs(sc.rows) do
				for _, it in ipairs(row.items) do
					if it.sized and it.fig.alpha ~= 1 then fail("scenery models should be solid, not see-through") end
					if it.file and (it.fig.desat or 0) ~= 0 then fail("scenery models should keep their own colours") end
				end
			end
			if shown < 6 then
				fail("most scenery spots should hold a model: " .. shown)
			end
			if not (sc.bad.near and next(sc.bad.near)) then fail("a model too big for its row should be noted") end
			-- walking on: the near row goes by fastest, the far one slowest
			local was = st.phase
			local x0 = {}
			for r, row in ipairs(sc.rows) do x0[r] = row.off end
			st.phase = "travel"
			for _ = 1, 5 do ns.Bar.DrawScenery() end
			st.phase = was
			local moved = {}
			for r, row in ipairs(sc.rows) do moved[r] = row.off - x0[r] end
			if not (moved[1] > 0 and moved[2] > moved[1] and moved[3] > moved[2]) then
				fail(string.format("scenery rows should go by faster the nearer they are: %.1f %.1f %.1f", moved[1], moved[2], moved[3]))
			end
			-- the ground is the place's own texture and goes by with the walk;
			-- the backdrop drifts slowly all the time, faster while walking
			local ground, sky, sky2 = ns.Bar.Ground()
			local gfile = ns.GroundFile(1, 1)
			if not (ground and gfile) then fail("the battle should have the place's ground") end
			local cd, ci = ns.db.stage.diff, ns.db.stage.idx
			if st.phase ~= "idle" and st.diff then cd, ci = st.diff, st.idx end
			if ground and ground:GetTexture() ~= ns.GroundFile(cd, ci) then fail("the ground should be the stage's own: " .. tostring(ground:GetTexture())) end
			-- fighting: everything stands still, the backdrop too
			st.phase = "fight"
			for _ = 1, 30 do ns.Bar.DrawScenery() end -- (the walk slows to a stop)
			local off, g0, s0 = sc.rows[3].off, ns.Bar.world.ground, ns.Bar.world.sky
			ns.Bar.DrawScenery()
			if sc.rows[3].off ~= off or ns.Bar.world.ground ~= g0 then fail("scenery and ground should stand still while the party fights") end
			if ns.Bar.world.sky ~= s0 then fail("the backdrop should stand still while the party fights") end
			st.phase = "travel"
			for _ = 1, 10 do ns.Bar.DrawScenery() end
			if not (ns.Bar.world.ground > g0 + 20) then fail("the ground should go by while the party walks: " .. (ns.Bar.world.ground - g0)) end
			if not (ns.Bar.world.sky > s0) then fail("the backdrop should go by while the party walks") end
			-- the backdrop is two pieces covering the scene: the picture and its mirror image
			local w1 = sky:IsShown() and sky:GetWidth() or 0
			local w2 = sky2:IsShown() and sky2:GetWidth() or 0
			if math.abs(w1 + w2 - 704) > 1 then fail("the backdrop's two pieces should cover the scene: " .. w1 .. " + " .. w2) end
			st.phase = was
			-- a model that leaves on the left comes back on the right
			local it = sc.rows[3].items[1]
			local lap = it.lap
			sc.rows[3].off = sc.rows[3].off + ns.Bar.SCENERY_ROWS[3].n * 1000
			ns.Bar.DrawScenery()
			if it.lap == lap then fail("a scenery model should come round again") end
			-- off in the settings: gone
			ns.db.opt.scenery = false
			frames(1)
			for _, row in ipairs(sc.rows) do
				for _, i2 in ipairs(row.items) do if i2.fig:IsShown() then fail("scenery should hide when turned off") break end end
			end
			ns.db.opt.scenery = true
			frames(1)
			-- a wall or a cliff (much longer than tall) does not stand in a row
			for _, f in ipairs(set.mid) do Mock.boxes["file:" .. f] = { -6, -1, 0, 6, 1, 2 } end
			sc.set = nil
			for _, row in ipairs(sc.rows) do for _, it in ipairs(row.items) do it.fig.id = nil end end
			frames(6)
			local wideUp = false
			for _, it in ipairs(sc.rows[2].items) do if it.fig:IsShown() and it.sized then wideUp = true end end
			if wideUp or not (sc.bad.mid and next(sc.bad.mid)) then fail("a model much longer than tall should not stand in the scenery") end
			-- an inside place: its own props, in man-sized rows
			ns.SceneryFor = function() return ns.SCENERY.scholomance end
			for _, f in ipairs(ns.SCENERY.scholomance.far) do Mock.boxes["file:" .. f] = { -0.5, -0.5, 0, 0.5, 0.5, 3 } end
			sc.set, sc.bad = nil, {}
			for _, row in ipairs(sc.rows) do for _, it in ipairs(row.items) do it.fig.id = nil end end
			frames(4)
			local props = 0
			for _, row in ipairs(sc.rows) do
				for _, i2 in ipairs(row.items) do
					if i2.fig:IsShown() and i2.sized then
						props = props + 1
						local ok = false
						for _, f in ipairs(ns.SCENERY.scholomance[row.def.key]) do if f == i2.file then ok = true end end
						if not ok then fail("an inside place should show its own props") end
					end
				end
			end
			if props < 6 then fail("an inside place should be filled with its props (a 3 yd bookshelf far off, cauldrons, jars): " .. props) end
			for _, f in ipairs(ns.SCENERY.scholomance.far) do Mock.boxes["file:" .. f] = nil end
			-- no scenery at all (nothing known for the place): nothing shown
			ns.SceneryFor = function() return nil end
			frames(2)
			for _, row in ipairs(sc.rows) do
				for _, i2 in ipairs(row.items) do if i2.fig:IsShown() then fail("a place without scenery should show none") break end end
			end
			for _, f in ipairs(set.far) do Mock.boxes["file:" .. f] = nil end
			for _, f in ipairs(set.near) do Mock.boxes["file:" .. f] = nil end
			for _, f in ipairs(set.mid) do Mock.boxes["file:" .. f] = nil end
			sc.bad = {}
		end
		ns.SceneryFor = sceneryFor
		frames(1)
	end
	-- the battle's backdrop is a picture of the stage's place
	do
		local st = ns.Combat.state
		local diff, idx = ns.db.stage.diff, ns.db.stage.idx
		if st.phase ~= "idle" and st.diff then diff, idx = st.diff, st.idx end
		local want = ns.BackdropFile(diff, idx)
		frames(3)
		local sky = ns.Bar.Sky and ns.Bar.Sky()
		if not want then fail("every stage should have a backdrop picture") end
		if sky and want and sky:GetTexture() ~= want then fail("the battle backdrop should be the place's picture: " .. tostring(sky:GetTexture())) end
		for d = 1, #ns.DIFFS do
			for i = 1, ns.STAGE_COUNT do
				if not ns.BackdropFile(d, i) then fail("stage " .. d .. "-" .. i .. " should have a backdrop picture") end
			end
		end
	end
	-- every model scene clears its own depth, so the fighters (on the layer
	-- above) are always drawn over the scenery
	do
		local sc = ns.Bar.Scenery()
		local fig = sc and sc.rows[1].items[1].fig
		if fig and fig.GetAllowOverlappedModels and not fig:GetAllowOverlappedModels() then fail("scenery scenes should clear their own depth") end
		local hf = heroes[1].model
		if hf and hf.GetAllowOverlappedModels and not hf:GetAllowOverlappedModels() then fail("hero scenes should clear their own depth") end
	end
	-- an attack plays the hero's attack animation (a swing, a cast, a shot)
	local attacked = false
	for _ = 1, 400 do -- until the party has met the monsters and fought a while
		frames(1)
		for _, f in ipairs(heroes) do
			local m = f.model
			if m and m:IsShown() and m.AnimId and animOf(m) == m:AnimId("attack") and m:Playing() == "attack" then attacked = true end
		end
		if attacked then break end
	end
	if not attacked then fail("heroes should play their attack animation in battle") end
	ns.PartyLimit = partyLimit
	-- off in the settings: icons again
	ns.db.opt.models = false
	frames(2)
	for _, f in ipairs(heroes) do if f.model and f.model:IsShown() then fail("models should hide when turned off") break end end
	-- a summon with the models off: its skill's icon in its place
	do
		local u
		for _, h in ipairs(ns.Combat.heroes) do if not h.dead then u = h break end end
		if u then
			local keep = u.pets
			u.pets = { call_pet = { sk = ns.SKILLS.call_pet, mult = 0.5, t = 1, anim = 0 } }
			ns.Bar.DrawHeroes()
			local summons, _, icons = ns.Bar.Summons()
			local shown = 0
			for _, ic in ipairs(icons or {}) do if ic:IsShown() then shown = shown + 1 end end
			if shown ~= 1 then fail("with 3D off a summon should show as its icon: " .. shown) end
			for _, m in ipairs(summons) do if m:IsShown() then fail("with 3D off no summon model should show") break end end
			u.pets = keep
			ns.Bar.DrawHeroes()
		end
	end
	ns.db.opt.models = true
	-- a model whose size comes a moment after the model itself (a druid's
	-- cat drawn as tall as a man) is measured again: its own size
	do
		local f
		for _, x in ipairs(heroes) do if x:IsShown() and x.model and x.model:IsLoaded() and x.model.box then f = x break end end
		if f then
			-- a long, low body (a cat): as tall as a man it would be drawn too small
			local disp = f.model.actor.__display
			local wasBox = Mock.boxes[disp]
			Mock.boxes[disp] = { -1.0, -0.3, 0, 1.2, 0.3, 1.0 }
			local want = 1 / (2.2 * 0.6)
			Fig.ResetFailed()
			f.model.id = nil
			Mock.noBoxUntil = Mock.now + 0.25
			frames(2)
			local early = f.model:IsLoaded() and f.model.box == nil
			frames(12)
			Mock.boxes[disp] = wasBox
			if not early then fail("the late-size check needs a model that came before its size") end
			if not (f.model.box and math.abs((f.model.norm or 0) - want) < 1e-6) then
				fail(string.format("a model whose size came late should get its own size: %s, want %s", tostring(f.model.norm), tostring(want)))
			end
		end
	end
	-- a hero's body that comes slowly (seconds, as when every model comes
	-- back at once) is waited for: the hero is not drawn as an NPC meanwhile
	do
		local f
		for _, x in ipairs(heroes) do if x:IsShown() and x.model and x.model.body then f = x break end end
		if f then
			Mock.loadDelay["unit:player"] = 4
			Fig.ResetFailed()
			f.model.id = nil
			local npc = false
			for _ = 1, 120 do
				frames(1)
				if f.model.id and not f.model.body then npc = true end
			end
			Mock.loadDelay["unit:player"] = nil
			if npc then fail("a hero whose body comes slowly should not be drawn as an NPC meanwhile") end
			if not (f.model.body and f.model:IsLoaded()) then fail("a hero's body that comes slowly should come in: " .. tostring(f.model.id)) end
		else
			fail("the battle check should have a hero drawn as its own body")
		end
	end
	-- models this game does not have: the icon stays meanwhile, and in the
	-- end every one of them is given up on
	Mock.missingDisplays = setmetatable({}, { __index = function() return true end })
	Fig.ResetFailed()
	ns.db.models = nil
	for _, f in ipairs(heroes) do if f.model then f.model.id = nil end end
	frames(3)
	local waiting = 0
	for _, f in ipairs(heroes) do
		if f:IsShown() and f.model and f.model:IsShown() then
			waiting = waiting + 1
			if not f.icon:IsShown() then fail("the icon should stay while the model is not in yet") break end
		end
	end
	if waiting == 0 then fail("a model that is still loading should be up (waiting)") end
	frames(900) -- every try of every model (famous NPC, then the trainer)
	Mock.missingDisplays = {}
	local back = 0
	for _, f in ipairs(heroes) do
		if f:IsShown() then
			if f.model and f.model:IsShown() then fail("a model that did not load should not stay up") break end
			if f.icon:IsShown() then back = back + 1 end
		end
	end
	if back == 0 then fail("a hero whose model did not load should fall back to the icon") end
	if not next(Fig.bad) then fail("display ids the game does not have should be noted for the session") end
	if ns.db.models.bad then fail("display ids that did not come up must not be saved: a slow model is not a missing one") end
	ns.db.models = nil
	Fig.ResetFailed()
	frames(2)
end

-- every spec looks like one NPC per faction: its famous NPC, else the class
-- trainer; the trainer stands in when the game cannot show the famous one
do
	local Fig = ns.Figure3D
	Fig.ResetFailed()
	for specId, sp in pairs(ns.SPECS) do
		for _, fac in ipairs({ "ALLIANCE", "HORDE" }) do
			local f = ns.MODEL.famous[specId] and ns.MODEL.famous[specId][fac]
			local t = ns.MODEL.trainer[sp.class][fac]
			local want = f and f.npc or t.npc
			if not ns.MODEL.display[want] then fail("no model id for the look of " .. specId .. " " .. fac) end
			for _, sex in ipairs({ "M", "F" }) do
				if Fig.ForSpec(specId, fac, sex) ~= want then fail("the " .. specId .. " " .. fac .. " body should be its look") end
			end
		end
	end
	local f = ns.MODEL.famous.PALADIN_HOLY.ALLIANCE.npc
	Fig.failed[f] = true
	if Fig.ForSpec("PALADIN_HOLY", "ALLIANCE", "M") ~= ns.MODEL.trainer.PALADIN.ALLIANCE.npc then fail("when the famous model cannot be shown, the class trainer should stand in") end
	Fig.ResetFailed()
	-- every hero is the player's own body as its race, in the player's gender:
	-- a male character gives men, a female character women
	do
		local was = Mock.playerSex
		for _, ps in ipairs({ 2, 3 }) do
			Mock.playerSex = ps
			local me = ps == 3 and "F" or "M"
			local b = Fig.BodyFor("WARRIOR", "ALLIANCE", "WARRIOR_ARMS", 2)
			if b.npc or b.rid ~= ns.MODEL.raceId.DWARF or b.sex ~= me then fail("a hero should be the player's body as a dwarf, " .. me) end
			if #b.items ~= 8 or b.weapons.mh ~= ns.MODEL.weapons.WARRIOR_ARMS.mh then fail("every body wears the set and holds the weapons") end
		end
		Mock.playerSex = was
		-- the clothes go with how far the account has come: the starting
		-- clothes, then one look for every difficulty cleared to its end
		local prog = ns.db.prog
		local saved = { prog[1], prog[2], prog[3], prog[4] }
		local seen = {}
		for tier = 0, 4 do
			for d = 1, 4 do prog[d] = d <= tier and ns.STAGE_COUNT or (d == tier + 1 and ns.STAGE_COUNT - 1 or 0) end
			if ns.GearTier() ~= tier then fail("clearing " .. tier .. " difficulties should give look " .. tier .. ": " .. ns.GearTier()) end
			local b = Fig.BodyFor("WARRIOR", "ALLIANCE", "WARRIOR_ARMS")
			if b.tier ~= tier or b.items ~= ns.MODEL.armorTier[tier].WARRIOR or b.weapons.mh ~= ns.MODEL.weaponTier[tier].WARRIOR_ARMS.mh then
				fail("look " .. tier .. " should wear its own armor and weapons")
			end
			if seen[b.key] then fail("every look should differ from the others") end
			seen[b.key] = true
		end
		-- a later difficulty cleared with an earlier one not: no skipping
		prog[1], prog[2], prog[3], prog[4] = ns.STAGE_COUNT, 0, ns.STAGE_COUNT, 0
		if ns.GearTier() ~= 1 then fail("the look should count difficulties cleared in order") end
		prog[1], prog[2], prog[3], prog[4] = saved[1], saved[2], saved[3], saved[4]
		if ns.MODEL.npcBody or ns.MODEL.raceBody then fail("no stand-in bodies for the other gender") end
	end
	-- druids fight in the night elf's (Alliance) or the tauren's (Horde)
	-- forms; restoration in caster form; the setting shows them all as
	-- themselves, weapons in hand
	local was = ns.db.faction
	local FORM_OF = { DRUID_GUARDIAN = "bear", DRUID_FERAL = "cat", DRUID_BALANCE = "moonkin" }
	for _, fac in ipairs({ "ALLIANCE", "HORDE" }) do
		ns.db.faction = fac
		for _, sid in ipairs({ "DRUID_GUARDIAN", "DRUID_FERAL", "DRUID_BALANCE", "DRUID_RESTO" }) do
			local h = H.NewRecord(sid)
			ns.db.opt.druidForm = nil
			local want = FORM_OF[sid] and ("disp:" .. ns.MODEL.form[FORM_OF[sid]][fac])
			if want then
				if Fig.ForHero(h.id, true) ~= want or Fig.HeroBody(h.id, true) then fail(sid .. " (" .. fac .. ") should fight in its form " .. want .. ": " .. tostring(Fig.ForHero(h.id, true))) end
				if Fig.DisplayFor(want) ~= ns.MODEL.form[FORM_OF[sid]][fac] then fail("a form should load by its own display id") end
			elseif not Fig.HeroBody(h.id, true) then
				fail("a restoration druid should fight in caster form")
			end
			-- the cat a little smaller than the others in battle
			local raceScale = Fig.RACE_SCALE[ns.Heroes.Race(h.id)] or 1
			local inForm = Fig.HeroScale(h.id, true)
			if sid == "DRUID_FERAL" and math.abs(inForm - raceScale * 0.92 / 0.85) > 1e-9 then fail("the cat should stand as tall as before the fighters were made smaller: " .. inForm) end
			if sid == "DRUID_BALANCE" and math.abs(inForm - Fig.RACE_SCALE.TAUREN * 1.25) > 1e-9 then fail("the moonkin of both factions should be a good deal taller than the tauren: " .. inForm) end
			if (sid == "DRUID_GUARDIAN" or sid == "DRUID_RESTO") and math.abs(inForm - raceScale) > 1e-9 then fail(sid .. " should keep its size") end
			-- the cat's health bar under its body, forward of its middle (its tail is long)
			local shift = Fig.HeroBarShift(h.id, true)
			if sid == "DRUID_FERAL" and not (shift > 0.05 and shift < 0.3) then fail("the cat's health bar should sit under its body, a little forward of its middle: " .. shift) end
			if sid ~= "DRUID_FERAL" and shift ~= 0 then fail(sid .. "'s health bar should sit under its middle") end
			ns.db.opt.druidForm = false
			if Fig.HeroBarShift(h.id, true) ~= 0 then fail("a druid as itself has its health bar under its middle") end
			-- a worgen's health bar under its body, forward of its middle (its tail)
			if not (Fig.MobBarShift(ns.MODEL.boss["1-9"]) > 0) then fail("Son of Arugal's health bar should sit under its body, forward of its middle") end
			if Fig.MobBarShift(ns.MODEL.boss["1-1"]) ~= 0 then fail("Hogger's health bar should sit under its middle") end
			if math.abs(Fig.HeroScale(h.id, true) - raceScale) > 1e-9 then fail("a druid as itself keeps its race's size") end
			local body = Fig.HeroBody(h.id, true)
			if not body or body.weapons.mh ~= ns.MODEL.weaponTier[ns.GearTier()][sid].mh or Fig.ForHero(h.id, true) == want then
				fail(sid .. " should fight as itself, weapon in hand, when druid forms are off")
			end
			ns.db.heroes[h.id] = nil
		end
	end
	ns.db.opt.druidForm = nil
	ns.db.faction = was
end

-- a figure measures its model: whatever the model's own size, it stands as
-- tall as it is given, its feet on the ground line, its middle on the middle
do
	local Fig = ns.Figure3D
	Fig.ResetFailed()
	ns.db.models = nil
	local D = ns.MODEL.display
	local MOB = ns.MODEL.mob[ns.STAGES[1][1].mobs[1][1]]
	Mock.boxes[D[MOB]] = { -1, -1, 0, 1, 1, 2 }        -- 2 tall, 2 long
	Mock.boxes[D[11502]] = { -3, -2, -1.5, 5, 2, 14.5 } -- huge, standing in lava below its origin
	Mock.boxes[D[416]] = { -0.2, -0.2, 0, 0.4, 0.2, 0.6 } -- small and off its middle
	local function stand(npc, h)
		local m = Fig.New(UIParent, h)
		m:SetModelId(npc)
		m:PlaceFeet(UIParent, 300, 100)
		m:Show() -- (the game brings a model into a shown frame only)
		m:Step(0.05)
		return m
	end
	-- a model's box follows its animation (a running cat is longer than a
	-- standing one): its size is taken standing and kept, so the same model
	-- never comes up smaller, whatever it was doing when its size was read
	do
		Fig.ResetFailed()
		local catBox = Mock.boxes[D[416]]
		Mock.boxes[D[416]] = { -1.0, -0.3, 0, 1.2, 0.3, 1.0 } -- long and low
		Mock.animBox = { [4] = 1.6, [5] = 1.6, [16] = 1.5, [17] = 1.5 } -- walking, running, attacking: longer
		local m = stand(416, 70)
		local standing = m.norm
		m:Play("walk")
		for _ = 1, 20 do m:Step(0.05) end -- past the second look, still walking
		if math.abs(m.norm - standing) > 1e-9 then fail(string.format("a walking model should keep its standing size: %.3f, was %.3f", m.norm, standing)) end
		m:Play("idle")
		for _ = 1, 20 do m:Step(0.05) end
		if math.abs(m.norm - standing) > 1e-9 then fail("standing again it should be the same size") end
		-- the same model put up again while it walks: the size it had standing
		local m2 = Fig.New(UIParent, 70)
		m2:Play("walk")
		m2:SetModelId(416)
		m2:Show()
		for _ = 1, 30 do m2:Step(0.05) end
		if not (m2.norm and math.abs(m2.norm - standing) < 1e-9) then fail(string.format("a model put up again while walking should come up its standing size: %s, want %.3f", tostring(m2.norm), standing)) end
		-- after a reload nothing is known yet, and the cat is already fighting
		-- when its model comes in: it swings without a pause and never stands
		-- idle. Its size is still read standing, and only then does it swing.
		for _, slow in ipairs({ 0, 0.4 }) do
			Fig.ResetFailed()
			Mock.loadDelay[D[416]] = slow > 0 and slow or nil
			local m3 = Fig.New(UIParent, 70)
			-- (as the battle does: the model put up, then the swing it is in)
			m3:SetModelId(416)
			m3:Play("attack")
			m3:Show()
			local t, swing, sawStand = 0, 0, false
			while t < 3 do
				swing = swing + 0.05
				if swing >= 0.5 then m3:Play("attack", true) swing = 0 end
				m3:Step(0.05)
				t = t + 0.05
				Mock.now = Mock.now + 0.05
				if m3.loaded and m3.actor.__anim == 0 then
					sawStand = true
					if (m3.actor.__alpha or 1) > 0.05 then fail("a model should be out of sight while it stands for its size") end
				end
			end
			if not (m3.norm and math.abs(m3.norm - standing) < 1e-9) then
				fail(string.format("a cat that comes in while it fights (load %.1fs) should get its standing size: %s, want %.3f", slow, tostring(m3.norm), standing))
			end
			if not sawStand then fail("a model should stand while its size is read") end
			if m3.actor.__anim ~= 17 then fail("once its size is read the model should play what it was asked to (the swing): " .. tostring(m3.actor.__anim)) end
			if (m3.actor.__alpha or 1) < 1 then fail("once its size is read the model should be in sight") end
			m3:Hide()
		end
		Mock.loadDelay[D[416]] = nil
		Mock.animBox = nil
		Mock.boxes[D[416]] = catBox
		m:Hide() m2:Hide()
		Fig.ResetFailed()
	end
	for _, c in ipairs({ { MOB, 70 }, { 11502, 98 }, { 416, 70 } }) do
		local m = stand(c[1], c[2])
		local a = m.actor
		local b = Mock.boxes[D[c[1]]]
		local s = a.__scale or 1
		local tall = (b[6] - b[3]) * s
		local long = math.max(b[4] - b[1], b[5] - b[2]) * s
		if math.max(tall, long * 0.6) < 0.999 or math.max(tall, long * 0.6) > 1.001 then fail("NPC " .. c[1] .. " should be fitted to its figure's height") end
		-- the bottom of the model on the ground line (z = 0)
		if math.abs(a.__pos[3] + b[3] * s) > 1e-6 then fail("NPC " .. c[1] .. " should stand on the ground line") end
		-- its middle on the figure's middle, as it faces (right)
		local cx, cy = (b[1] + b[4]) / 2, (b[2] + b[5]) / 2
		local yaw = (Fig.yawSense or 1) * a.__yaw -- as the game turns it
		local mx = a.__pos[1] + (math.cos(yaw) * cx - math.sin(yaw) * cy) * s
		local my = a.__pos[2] + (math.sin(yaw) * cx + math.cos(yaw) * cy) * s
		if math.abs(mx) > 1e-6 or math.abs(my) > 1e-6 then fail("NPC " .. c[1] .. " should stand in the middle of its figure") end
		-- feet: the frame reaches FEET_AT heights below them
		local _, _, _, x, y = m:GetPoint(1)
		if math.abs(y - (100 - Fig.FEET_AT * c[2])) > 1e-6 or x ~= 300 then fail("the feet should be where they are placed") end
		if math.abs(m:GetHeight() - Fig.SIDE * c[2]) > 1e-6 then fail("a figure's frame should follow its height") end
		-- the dying stay down: death once, then lying dead
		m:Play("death")
		for _ = 1, 20 do m:Step(0.1) m:Play("death") end
		if a.__anim ~= 6 then fail("a dead figure should stay down (animation 6), not die again: " .. tostring(a.__anim)) end
		-- grown with the window: the camera is set again
		a.__scene.__camPos = nil
		m:SetScale(1.5)
		m:Step(0.05)
		if not a.__scene.__camPos then fail("the camera should be set again when the window grows") end
		m:Hide()
	end
	-- the camera follows the game's own projection: whatever it magnifies by,
	-- a model's feet land on the ground line and its top one height above
	for _, mag in ipairs({ 1.4, 0.9 }) do
		Mock.projMag = mag
		Fig.ResetCalibration()
		local h = 64
		local m = stand(MOB, h)
		for _ = 1, 3 do Mock.now = Mock.now + 1 m:Step(0.05) end
		local info = Fig.camInfo
		if info.how ~= "measured" or math.abs(Fig.camFix - mag) > 1e-6 then
			fail(string.format("the camera factor should be measured from the projection: %s %.3f (want %.2f, %s)", tostring(info.how), Fig.camFix, mag, tostring(info.why)))
		end
		if Fig.yawSense ~= -1 then fail("the mock draws the camera's right on the screen's right: the turn sense should be -1") end
		local a = m.actor
		local s = a.__scale
		local b = Mock.boxes[D[MOB]]
		local _, footY = m:Project3DPointTo2D(0, 0, 0)
		local _, topY = m:Project3DPointTo2D(0, 0, (b[6] - b[3]) * s)
		if math.abs(footY - Fig.FEET_AT * h) > 1e-6 then fail(string.format("feet should project onto the ground line: %.2f / %.2f", footY, Fig.FEET_AT * h)) end
		if math.abs((topY - footY) - h) > 1e-6 then fail(string.format("a model should project at its figure's height: %.2f / %d", topY - footY, h)) end
		m:Hide()
	end
	-- a game that answers in screen pixels (1440 high: 1.875 per frame unit),
	-- counts y from the top and draws the picture 14 lower and 3 to the
	-- right: the units are read off the frame's middle, and each figure moves
	-- and sizes its model until the feet are on the line and the head one
	-- height above
	local K = 1440 / 768
	Mock.projMag, Mock.projK, Mock.projDown, Mock.projShift = 1.1, K, true, { 3, -14 }
	Fig.ResetCalibration()
	do
		local h = 64
		local m = stand(MOB, h)
		for _ = 1, 12 do Mock.now = Mock.now + 0.5 m:Step(0.05) end
		if Fig.camInfo.how ~= "measured" or not Fig.conv or Fig.conv.kind ~= "frame" or math.abs(Fig.conv.k - K) > 1e-9 or Fig.conv.up then
			fail("the projection's units should be read off the frame's middle: " .. tostring(Fig.conv and Fig.conv.kind) .. " " .. tostring(Fig.conv and Fig.conv.k) .. " (" .. tostring(Fig.camInfo.why) .. ")")
		end
		local a, b = m.actor, Mock.boxes[D[MOB]]
		local s = a.__scale
		-- where the mock draws the feet and the head, in frame units from the bottom
		local _, fy = m:Project3DPointTo2D(0, 0, 0)
		local _, ty = m:Project3DPointTo2D(0, 0, (b[6] - b[3]) * s)
		fy, ty = h * Fig.SIDE - fy / K, h * Fig.SIDE - ty / K
		local _, _, _, x, y = m:GetPoint(1)
		local feetOnScreen = y + fy
		if math.abs(feetOnScreen - 100) > 0.5 then fail(string.format("feet should be put back on the line: %.2f / 100 (shift %.3f)", feetOnScreen, m.corrYf or 0)) end
		if math.abs((ty - fy) - h * (b[6] - b[3]) * m.norm) > 0.5 then fail(string.format("the model should be its figure's height: %.2f / %.2f", ty - fy, h * (b[6] - b[3]) * m.norm)) end
		if math.abs((x - 300) + 3) > 0.5 then fail(string.format("the model should be moved back over its place: %.2f", x - 300)) end
		m:Hide()
	end
	Mock.projK, Mock.projDown, Mock.projShift = 1, false, nil
	-- no projection: the factor seen in game stays
	local proj = Mock.ModelScene.Project3DPointTo2D
	Mock.ModelScene.Project3DPointTo2D = nil
	Fig.ResetCalibration()
	local m0 = stand(MOB, 60)
	for _ = 1, 3 do Mock.now = Mock.now + 1 m0:Step(0.05) end
	if Fig.camInfo.how ~= "default" or Fig.camFix ~= 1.25 or Fig.camInfo.why ~= "no projection" then fail("without a projection the camera factor should stay 1.25") end
	m0:Hide()
	Mock.ModelScene.Project3DPointTo2D = proj
	Mock.projMag = 1.25
	Fig.ResetCalibration()
	Mock.boxes = {}
	-- the game's own answer is kept: the display id a model came up with is
	-- used first next time; one the game lacks is not waited for again
	local npc = MOB
	local m = stand(npc, 60)
	if ns.db.models.ok[npc] ~= D[npc] then fail("the display id a model came up with should be kept") end
	ns.db.models.ok[npc] = 777
	local m2 = stand(npc, 60)
	if m2.actor.__display ~= 777 then fail("a kept display id should be used first: " .. tostring(m2.actor.__display)) end
	ns.db.models.ok[npc] = nil
	Mock.missingDisplays[D[npc]] = true
	local m3 = Fig.New(UIParent, 60)
	m3:Show()
	m3:SetModelId(npc)
	for _ = 1, 30 do m3:Step(0.1) end
	if Fig.failed[npc] or Fig.bad[D[npc]] then fail("a model should get more than one try before it is given up on") end
	for _ = 1, 100 do m3:Step(0.1) end
	if not Fig.bad[D[npc]] then fail("a display id the game does not have should be noted for the session") end
	if ns.db.models.bad then fail("a display id that did not come up must not be saved") end
	if m3:IsLoaded() or not Fig.failed[npc] then fail("a model the game does not have should be given up on") end
	Mock.missingDisplays = {}
	m3:Hide()
	Fig.ResetFailed()
	-- a model slow to come up (not there at the first try) still comes up
	Mock.missingDisplays[D[npc]] = true
	local m4 = Fig.New(UIParent, 60)
	m4:Show()
	m4:SetModelId(npc)
	for _ = 1, 20 do m4:Step(0.1) end
	Mock.missingDisplays = {}
	for _ = 1, 60 do m4:Step(0.1) end
	if not m4:IsLoaded() then fail("a model slow to come up should still come up at a later try") end
	m4:Hide()
	-- an older save's list of "missing" display ids is dropped
	ns.db.models = { ok = {}, bad = { [D[npc]] = true } }
	if Fig.DisplayFor(npc) ~= D[npc] or ns.db.models.bad then fail("an older save's missing display ids should be forgotten") end
	for _, x in ipairs({ m, m2, m3 }) do x:Hide() end
	ns.db.models = nil
	Fig.ResetFailed()
	-- a client without ModelScene: a PlayerModel, by display id then NPC id
	Mock.noModelScene = true
	local p = Fig.New(UIParent, 60)
	if not p or p.kind ~= "model" then fail("without ModelScene a figure should be a PlayerModel") end
	p:Show()
	p:SetModelId(npc)
	if p.__model ~= "display:" .. D[npc] then fail("a PlayerModel figure should be put up by its display id") end
	local getFile = Mock.Model.GetModelFileID
	Mock.Model.GetModelFileID = function(self)
		if (self.__model or ""):find("^display:") then return nil end -- this game lacks the display id
		return 123456
	end
	local p2 = Fig.New(UIParent, 60)
	p2:Show()
	ns.db.models = nil
	p2:SetModelId(npc)
	for _ = 1, 30 do p2:Step(0.1) end
	if not p2:IsLoaded() or not tostring(p2.__model):find("^creature:") then fail("after a missing display id the NPC id should bring the model") end
	Mock.Model.GetModelFileID = getFile
	-- a loading screen the client cannot load: the original it stands in for
	do
		local t = UIParent:CreateTexture()
		local set = t.SetTexture
		t.SetTexture = function(self, f) if f == "missing" then return false end return set(self, f) end
		local ok = ns.UI.SetLoadingScreen(t, { file = "missing", kind = "forever", fallback = { file = "kept", kind = "classic" } }, 4)
		if not ok or t.__tex ~= "kept" then fail("a loading screen that fails should fall back to the original: " .. tostring(t.__tex)) end
		ok = ns.UI.SetLoadingScreen(t, { file = "missing", kind = "forever" }, 4)
		if ok then fail("a loading screen that fails with nothing to fall back on should say so") end
	end
	-- greying a PlayerModel reaches the model's own call, once
	do
		local calls = 0
		Mock.Model.SetDesaturation = function(self, v) calls = calls + 1 end
		local q = Fig.New(UIParent, 60)
		calls = 0
		q:SetDesaturation(true)
		if calls ~= 1 then fail("greying a PlayerModel figure should call the model once, got " .. calls) end
		Mock.Model.SetDesaturation = nil
		q:Hide()
	end
	-- a display id the game answers false to: the NPC id is tried at once
	do
		local setDisp = Mock.Model.SetDisplayInfo
		Mock.Model.SetDisplayInfo = function(self, id) return false end
		local q = Fig.New(UIParent, 60)
		q:Show()
		q:SetModelId(npc)
		if not tostring(q.__model):find("^creature:") then fail("a display id answered false should fall to the NPC id on the first try: " .. tostring(q.__model)) end
		Mock.Model.SetDisplayInfo = setDisp
		q:Hide()
	end
	-- the older spell effect call when the newer one is missing
	do
		local apply = Mock.Model.ApplySpellVisualKit
		local used = 0
		Mock.Model.ApplySpellVisualKit = nil
		Mock.Model.SetSpellVisualKit = function() used = used + 1 end
		local q = Fig.New(UIParent, 60)
		q:Show()
		q:SetModelId(npc)
		for _ = 1, 30 do q:Step(0.1) end
		q.loaded = true
		q:PlayKit(1234)
		if used ~= 1 then fail("a PlayerModel without the newer effect call should use the older one") end
		Mock.Model.ApplySpellVisualKit, Mock.Model.SetSpellVisualKit = apply, nil
		q:Hide()
	end
	Mock.noModelScene = false
	p:Hide() p2:Hide()
	ns.db.models = nil
	Fig.ResetFailed()
end

-- fighters move evenly: drawn a little further every frame, not hopping on
-- each combat step (0.1 s); the walk is not broken off between steps
do
	ns.Combat.StartStage()
	frames(2)
	local _, mobs = ns.Bar.UnitFrames()
	local f = mobs[1]
	local xs, anims = {}, {}
	for n = 1, 60 do
		frames(1, 0.02) -- 50 frames a second
		xs[n] = f:IsShown() and select(4, f:GetPoint(1)) or nil
		-- (a model whose size is being read stands out of sight: not counted)
		anims[n] = f.model and f.model:IsShown() and not f.model.sizing and animOf(f.model) or false
	end
	-- while it walks: from its first step to its last (it stops to fight)
	local first, last
	for n = 2, 60 do
		if xs[n] and xs[n - 1] and math.abs(xs[n] - xs[n - 1]) > 0.01 then first = first or n last = n end
	end
	local moved, still, biggest, total = 0, 0, 0, 0
	for n = (first or 2), (last or 1) do
		if xs[n] and xs[n - 1] then
			local d = math.abs(xs[n] - xs[n - 1])
			if d > 0.01 then moved = moved + 1 total = total + d biggest = math.max(biggest, d) else still = still + 1 end
		end
	end
	if moved < 10 then fail("a monster walking in should move (moved on " .. moved .. " frames)") end
	if still > moved / 4 then fail(string.format("a walking monster should move on nearly every frame, not in steps (%d moved, %d still)", moved, still)) end
	if moved > 0 and biggest > 3 * total / moved then fail("a walking monster should move by even amounts") end
	-- the animation while it walks (from its first step to its last walking
	-- frame: one that reaches its place may swing while it slides the last bit)
	local lastWalk
	for n = (first or 2), (last or 1) do if anims[n] == 4 then lastWalk = n end end
	local walk, other = 0, 0
	for n = (first or 2), (lastWalk or 1) do
		local a = anims[n]
		if a == 4 then walk = walk + 1 elseif a then other = other + 1 end
	end
	if walk + other > 10 and other > walk / 4 then fail(string.format("the walk should not be broken off between steps (%d walking, %d not)", walk, other)) end
end

try("compartment", BigIdleHeroes_OnAddonCompartmentClick)

-- a long stretch with a full party fighting, then lag spikes
enrich(1)
-- the random clicks may have reset everything: learn the party-slot runes again
ns.AddGold(5e9)
for _, id in ipairs({ 21, 24, 11001 }) do learnRune(id) end
for _, sid in ipairs({ "WARRIOR_PROT", "PRIEST_HOLY", "MAGE_FIRE", "ROGUE_ASSA", "HUNTER_MM" }) do
	if H.PartyCount() < ns.PartyLimit() and H.Count() < ns.ROSTER_MAX then H.Create(sid) end
end
if H.PartyCount() < 3 then fail("the long run should have a party, got " .. H.PartyCount()) end
frames(2500, 0.05)
frames(40, 2.0)

-- log out, stay away two hours, log back in: offline report
enrich(1)
ns.db.rate.gold = math.max(ns.db.rate.gold or 0, 5)
try("PLAYER_LOGOUT", Mock.FireEvent, "PLAYER_LOGOUT")
Mock.wall = Mock.wall + 7200
local goldBefore = ns.db.gold
try("PLAYER_LOGIN again", Mock.FireEvent, "PLAYER_LOGIN")
if ns.db.gold <= goldBefore then fail("offline rewards were not paid on login") end
-- the report: the amounts earned in green, their names as they are
do
	local f = ns.ShowOffline({ away = 7200, counted = 7200, eff = 1, gold = 1234567, xp = 98765, levels = 2 })
	local text = ns.log[#ns.log] or ""
	if not text:find("골드 |cff66ff73+1.23M|r", 1, true) or not text:find("경험치 |cff66ff73+98,765|r", 1, true)
		or not text:find("영웅 레벨 |cff66ff73+2|r", 1, true) then
		fail("the offline report should show the amounts in green: " .. text)
	end
	f:Hide()
end
frames(10)
local st = ns.db.stat
print(string.format("  after the run: %d kills, %d clears, %d chests opened, forge level %d, %d heroes",
	st.kills, st.clears, st.chests, ns.db.forge.level, H.Count()))

-- open screens keep their numbers current: the settings' play time, the
-- companions' kill counts
do
	Main.Toggle(true)
	Main.ShowTab("options")
	local op = Main.Page("options")
	ns.db.stat.time = 7200
	frames(8, 0.2)
	if op.game.rows[1].v.__text ~= ns.U.time(ns.db.stat.time) then fail("the play time in the settings should count on while open: " .. tostring(op.game.rows[1].v.__text)) end
	Main.ShowTab("pets")
	local pp = Main.Page("pets")
	local pet = ns.PET_BY_ID.chicken
	local had = ns.db.pets.chicken
	ns.db.pets.chicken = nil
	ns.db.kills.humanoid = pet.unlock.n - 7
	frames(8, 0.2)
	local card
	for _, c in ipairs(pp.cards) do if c.pet == pet then card = c end end
	-- (the fight goes on meanwhile: the count shown is the count now)
	local want = ns.U.fmt(math.min(pet.unlock.n, ns.db.kills.humanoid)) .. " / " .. ns.U.fmt(pet.unlock.n)
	if not (card and card.bar.text.__text == want) then
		fail("the companion screen should show the kill count as it moves: " .. tostring(card and card.bar.text.__text) .. " / " .. want)
	end
	ns.db.pets.chicken = had
end

-- a reset: the runes' room goes, no battle window until the first hero, and
-- the side is chosen again
Main.Toggle(true)
Main.ShowTab("options")
click("reset", labelIs("모든 진행 상황 초기화"))
click("confirm reset", labelIs("초기화"))
if H.Count() ~= 0 then fail("a reset should leave no hero") end
if ns.BagSize() ~= 30 or ns.PartyLimit() ~= ns.PARTY_BASE then fail("a reset should take the rune bonuses: bag " .. ns.BagSize() .. ", party " .. ns.PartyLimit()) end
if ns.Bar.IsShown() then fail("after a reset the battle window should wait for the first hero") end
if not find(function(b) return label(b) == "얼라이언스로 시작" end) then fail("after a reset the side should be chosen again") end
click("choose Alliance", labelIs("얼라이언스로 시작"))
if not H.Create("MAGE_FIRE") then fail("the first hero after a reset could not be made") end
if not ns.Bar.IsShown() then fail("the battle window should come back with the first hero after a reset") end

-- every texture path must be well-formed; addon textures must exist on disk
for path in pairs(Mock.textures) do
	if path:find("Interface\\Icons\\") and (path:find("%s") or path:sub(-1) == "\\") then
		fail("malformed icon path: " .. path)
	end
	local media, ext = path:match("\\Media\\([%w_\\]+)%.(%a+)$")
	if media and (ext == "tga" or ext == "blp") then
		media = media:gsub("\\", "/") .. "." .. ext
		local f = io.open(debug.getinfo(1, "S").source:sub(2):gsub("tests/test_ui%.lua$", "BigIdleHeroes/Media/" .. media), "rb")
		if f then f:close() else fail("missing texture file: Media/" .. media) end
	elseif path:find("AddOns") then
		fail("unexpected addon texture path: " .. path)
	end
end

if failures == 0 then print("  ui: all checks passed") end
return failures == 0
