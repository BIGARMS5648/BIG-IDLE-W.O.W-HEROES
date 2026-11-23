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
local function labelIs(ko, en) return function(b) return label(b) == (ko) end end

math.randomseed(777)
BigWowIdleDB = nil

------------------------------------------------------------------------
-- start-up
------------------------------------------------------------------------
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "SomeOtherAddon")
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "BigWowIdle")
try("PLAYER_LOGIN", Mock.FireEvent, "PLAYER_LOGIN")
if not ns.db then
	fail("saved variables were not initialised")
	return false
end
if not Main.IsShown() then fail("the menu should open by itself for a new player") end
if Main.Current() ~= "hero" then fail("a new player should land on the hero screen, got " .. tostring(Main.Current())) end
if ns.db.faction then fail("a new player has no faction yet") end
click("choose Horde", labelIs("호드로 시작"))
if ns.db.faction ~= "HORDE" then fail("the faction choice was not saved") end
if not find(function(b) return b.cid == "WARRIOR" end) then fail("the hero creation dialog should open after the faction choice") end
if not SlashCmdList.BIGWOWIDLE then fail("slash command missing") end
if type(BigWowIdle_OnAddonCompartmentClick) ~= "function" then fail("addon compartment function missing") end
local goal = ns.Guide.Current()
if not (goal.create and goal.tab == "hero") then fail("the first goal should be to create a hero on the hero screen") end

local tabs = { "hero", "equip", "party", "runes", "map", "pets", "options" }
do
	local nav = Main.Frame().nav
	local want = { "hero", "equip", "party", "runes", "map", "pets" }
	if #nav ~= #want then fail("the bottom bar should have six screens, got " .. #nav) end
	for i, k in ipairs(want) do
		if not (nav[i] and nav[i].key == k) then fail("bottom bar button " .. i .. " should open " .. k) end
	end
	-- old names still lead somewhere
	Main.ShowTab("forge")
	if Main.Current() ~= "equip" then fail("the old forge screen should open the equipment screen") end
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
if label(page.create) ~= "영웅 만들기" then fail("the hero list should end with '영웅 만들기'") end
try("open create dialog", page.create.Click, page.create, "LeftButton")
click("class Druid", function(b) return b.cid == "DRUID" end)
click("class Hunter", function(b) return b.cid == "HUNTER" end)
click("spec Marksmanship", function(b) return b.sid == "HUNTER_MM" end)
click("female", function(b) return b.sex == "F" end)
click("reroll name", labelIs("다시"))
do -- the preview: the player's body as the class's race (a hunter: night elf or troll), in its set
	local cf = ns.UI.CreatePreview()
	if not cf then fail("the create window should have a 3D preview") end
	if cf and (cf.actor.__display ~= "unit:player" or cf.actor.__race ~= ns.MODEL.raceId[ns.ClassRace("HUNTER")]) then
		fail("the create preview should be the player's body as the hunter's race: " .. tostring(cf.actor.__display) .. " " .. tostring(cf.actor.__race))
	end
end
click("create", function(b) return label(b) == "사격 사냥꾼 만들기" and b.__w == 153 end)
if H.Count() ~= 1 then fail("creating through the dialog did not make a hero") end
local first = H.List()[1]
if first and ns.db.heroes[first].spec ~= "HUNTER_MM" then fail("the hero has the wrong specialization") end
if first and ns.db.heroes[first].sex ~= "F" then fail("the chosen gender was not kept") end
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

ns.AddGold(5e9)
for _, id in ipairs({ "root", "c1", "c2", "c3", "c6", "c4", "c5", "c7", "e1", "e2", "e3" }) do ns.Runes.Buy(id) end
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
			if m and (m.actor.__display ~= "unit:player" or not m.actor.__race) then fail("a party card should show the hero's body (the player's model as its race)") end
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
	if ep.viewPick:IsVisible() or ep.open:IsVisible() or ep.smeltGo:IsVisible() then fail("the storage has no view list, chest opener or breaking down") end
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
	-- the forge level shows under the bag too; a locked 분해 unlocks right here
	if not ep.forgeBar:IsVisible() then fail("the forge level should show under the bag") end
	ns.db.forge.ops.smelt = nil
	Main.Refresh()
	if not (label(ep.smeltGo) or ""):find("분해 해금", 1, true) then fail("a locked 분해 should offer to unlock it, got " .. tostring(label(ep.smeltGo))) end
	press("unlock 분해", ep.smeltGo)
	if ns.Forge.Unlocked("smelt") then fail("unlocking must ask first") end
	confirmYes("unlock 분해")
	if not ns.Forge.Unlocked("smelt") then fail("[분해 해금] should unlock breaking down") end
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
	click("open chests", function(b) return label(b) and label(b):find("상자 열기", 1, true) end)
	press("sort", ep.sort)
	hoverAll()
end

-- equipment > 재료: one tab per kind; each row fuses or breaks down its material
do
	Main.ShowTab("equip", { sub = "mats" })
	local ep = Main.Page("equip")
	if ep.tab ~= "mats" then fail("the materials tab did not open") end
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
	if not (Main.Current() == "equip" and ep.tab == "mats" and ep.matTab == pill.def.tab) then fail("a currency in the title bar should open its materials tab") end
	-- auto-fuse in one tab leaves the other tabs' materials alone
	ns.AddMat("gem1", 20)
	ns.AddMat("bar1", 20)
	Main.ShowTab("equip", { sub = "mats", tab = "mat_gem" })
	local barsBefore = ns.MatCount("bar1")
	press("auto fuse gems", ep.autoFuse)
	confirmYes("auto fuse gems")
	if ns.MatCount("gem1") >= 9 then fail("auto-fuse in the gem tab should fuse the gems") end
	if ns.MatCount("bar1") ~= barsBefore then fail("auto-fuse in the gem tab must not touch crafting materials") end
	Main.ShowTab("equip", { sub = "mats", tab = "mat_craft" })
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
	Main.ShowTab("equip", { sub = "mats", tab = "mat_seal" })
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
		press("unlock the roll", s.roll)
		confirmYes("unlock the roll")
		if not ns.Forge.Unlocked("seal") then fail("the roll button should unlock 인장 굴리기") end
		local before = #ns.db.bag
		press("roll", s.roll)
		if #ns.db.bag ~= before + 1 then fail("rolling a seal should add one item") end
	end
	hoverAll()
end

-- equipment > forge tabs: fuse, craft, gem, enchant, inscribe; a locked one
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
	Main.ShowTab("equip", { sub = "fuse" })
	local ep = Main.Page("equip")
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
	press("tier 1", cp.tiers[1])
	for _, mid in ipairs(ns.MAT_ORDER) do ns.AddMat(mid, 30) end
	Main.Refresh()
	before = #ns.db.bag
	press("craft", cp.go)
	if #ns.db.bag ~= before + 1 then fail("crafting should add one item") end
	-- sockets: the item, then the material, then the button
	local epic = ns.Items.New("chest", 30, 6)
	ns.Items.AddToBag(epic)
	for _, step in ipairs({ { "gem", "gem2", "g" }, { "ench", "dust2", "e" }, { "insc", "scroll2", "i" } }) do
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
	press("unlock", ep.lockView.go)
	confirmYes("unlock")
	if not F.Unlocked("insc") then fail("해금하기 should unlock the function") end
	hoverAll()
end

-- runes: the tree; pick a rune, learn it from the bar
do
	Main.ShowTab("runes")
	local rp = Main.Page("runes")
	local lvl = ns.Runes.Level("w1")
	click("rune w1", function(b) return b.node and b.node.id == "w1" end)
	if rp.sel ~= "w1" then fail("clicking a rune should select it") end
	press("learn", rp.side.buy)
	if ns.Runes.Level("w1") ~= lvl + 1 then fail("learning a rune did not work") end
	if not ns.Runes.Available("w2") or not ns.Runes.Available("w3") then fail("a branch hub should open both of its lines") end
	if ns.Runes.Available("w4") and ns.Runes.Level("w2") == 0 then fail("a rune on a line needs the one before it") end
	click("rune w9", function(b) return b.node and b.node.id == "w9" end)
	if ns.Runes.Level("w9") == 0 and rp.side.goPrev:IsVisible() then
		press("first rune to learn", rp.side.goPrev)
		if not ns.Runes.Available(rp.sel) then fail("'먼저 배울 룬' should select a rune that can be learned") end
	end
	if not (rp.side.totalLines[1].__text or ""):find("%S") then fail("the rune card should list the total of the learned runes") end
	-- a long 보너스 합계 scrolls (wheel, the bar, its thumb)
	do
		local saved = {}
		for id, lv in pairs(ns.db.runes) do saved[id] = lv end
		for id, node in pairs(ns.Runes.byId) do ns.db.runes[id] = node.max end
		ns.Runes.Invalidate()
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
		ns.Runes.Invalidate()
		Main.Refresh()
		if rp.totalN <= #side.totalLines and side.track:IsVisible() then fail("a short total needs no scroll bar") end
	end
	-- sent from another screen: the rune gets a red ring until another one is picked
	Main.ShowTab("runes", { rune = "c4" })
	if rp.sel ~= "c4" or rp.focus ~= "c4" or not rp.focusFx:IsShown() then fail("a rune another screen points to should be marked") end
	click("another rune", function(b) return b.node and b.node.id == "w1" end)
	if rp.focus or rp.focusFx:IsShown() then fail("picking another rune should drop the mark") end
	Main.ShowTab("hero")
	Main.ShowTab("runes")
	if rp.focusFx:IsShown() then fail("opening the runes from the menu should not mark anything") end
	-- the locked skill slot on the hero screen leads to its rune, marked
	Main.ShowTab("runes", { rune = "c9" })
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

-- settings: every tab
do
	Main.ShowTab("options")
	for _, t in ipairs({ "screen", "game", "info" }) do
		tab("options", t)
		hoverAll()
	end
	local op = Main.Page("options")
	if op.S.card:IsVisible() then fail("settings should have no side card") end
	tab("options", "screen")
	press("battle window back to default", op.screen.resetPos)
	tab("options", "info")
	press("reset everything", op.info.reset)
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
	local bar = BigWowIdleBar
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
		if #bar.menu ~= 6 then fail("the HUD menu should have the six screens") end
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
try("slash", SlashCmdList.BIGWOWIDLE, "")
try("slash bar", SlashCmdList.BIGWOWIDLE, "bar")
frames(20)
try("slash bar", SlashCmdList.BIGWOWIDLE, "bar")
try("slash reset", SlashCmdList.BIGWOWIDLE, "reset")
try("slash help", SlashCmdList.BIGWOWIDLE, "help")

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
				if m.actor.__display ~= "unit:player" or m.actor.__race ~= ns.MODEL.raceId[race] or m.actor.__dressed then
					fail("a hero should be the player's body as its race (" .. race .. "), undressed: " .. tostring(m.actor.__display) .. " " .. tostring(m.actor.__race))
				end
				local worn = m.actor.__worn or {}
				local w = ns.MODEL.weapons[ns.db.heroes[u.id].spec]
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
			if math.abs((m.actor.__yaw or 0) - math.pi / 2) > 1e-6 then fail("monster models should face the heroes (left)") end
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
		local hitFiles = {}
		for _, e in pairs(ns.SKILL_FX) do if e.hit then hitFiles["file:" .. e.hit] = true end end
		for _ = 1, 600 do
			frames(1)
			for _, ms in ipairs(ns.Bar.missiles) do
				if ms.active and type(ms.fig.actor.__display) == "string" and ms.fig.actor.__display:find("^file:") then sawMissile = true end
			end
			-- a missile is in the air for a moment only: counted when it leaves
			if ns.Bar.fxStats.missiles > flown then sawMissile = true end
			for _, hs in ipairs(ns.Bar.hits) do
				if not hit and hs.active and hs.fig:IsShown() and hitFiles[hs.fig.actor.__display] then
					local t = hs.tfig
					hit = { scale = hs.fig.actor.__scale or 0, height = hs.fig.height, want = 0.5 * (t.norm or 0.5) * (t.corrScale or 1), tall = t.height,
						clip = hs.clip, clipW = hs.clip and hs.clip:GetWidth() }
				end
			end
			if sawMissile and hit and #Mock.kits >= 4 then break end
		end
		local known = {}
		for _, e in pairs(ns.SKILL_FX) do if e.cast then known[e.cast] = true end end
		local good = 0
		for _, k in ipairs(Mock.kits) do if known[k] then good = good + 1 end end
		if good == 0 then fail("skills in battle should play spell kits on the models (" .. #Mock.kits .. " kits)") end
		if not sawMissile then fail("a skill with a missile should fly it from the caster to the target") end
		local known = false
		for _, e in pairs(ns.SKILL_FX) do if e.missile and e.missile == ns.Bar.fxStats.lastMissile then known = true end end
		if sawMissile and not known then fail("a flying missile should be its spell's missile model") end
		-- a hit is the spell's impact model next to its target, half as big
		-- as the target's own scale, in a figure as tall as the target
		if not hit then
			fail("a skill's hit should show the spell's impact model on the target")
		else
			if hit.scale > hit.want + 1e-6 or hit.scale <= 0 then
				fail(string.format("a hit should be at most half the target's scale (%.3f, at most %.3f)", hit.scale, hit.want))
			end
			if math.abs(hit.height - hit.tall) > 1e-6 then fail("a hit's figure should be as tall as its target's") end
			-- drawn only inside a box about the target's size
			if not (hit.clip and hit.clip.__clips) or math.abs(hit.clipW - 1.3 * hit.tall) > 1e-6 then
				fail("a hit should be clipped to a box around its target: " .. tostring(hit.clipW))
			end
		end
		if #Mock.misuse > 0 then fail("effect calls with bad arguments: " .. table.concat(Mock.misuse, "; ")) end
		-- a wide effect (a ring many times the target's size) is made no
		-- wider than the target is tall
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
						if hs.active and hs.fig:IsShown() and hs.fig.actor.__display == "file:" .. wide.hit and hs.tfig ~= nil then big = big or hs end
					end
				end
				if big then
					local tf = big.tfig
					local ts = tf.fixedScale or (tf.norm or 0.5) * (tf.corrScale or 1)
					local across = 12 * (big.fig.actor.__scale or 0)
					local tall = (tf.box[6] - tf.box[3]) * ts
					if across > tall * 1.0 + 1e-6 then fail(string.format("a wide effect should be no wider than its model is tall (%.2f > %.2f)", across, tall)) end
				else
					fail("a boss's fire nova should show its ring")
				end
			end
			Mock.boxes["file:" .. wide.hit] = nil
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
			local castOk
			for _, k in ipairs(Mock.kits) do if k == sp.cast then castOk = true end end
			if not castOk then fail("a boss ability should play its spell's cast on the boss") end
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
	-- an attack plays the attack animation
	local anims = {}
	for _ = 1, 400 do -- until the party has met the monsters and fought a while
		frames(1)
		for _, f in ipairs(heroes) do if f.model and f.model:IsShown() then anims[animOf(f.model) or -1] = true end end
		if anims[17] then break end
	end
	if not anims[17] then fail("heroes should play the attack animation (17) in battle") end
	ns.PartyLimit = partyLimit
	-- off in the settings: icons again
	ns.db.opt.models = false
	frames(2)
	for _, f in ipairs(heroes) do if f.model and f.model:IsShown() then fail("models should hide when turned off") break end end
	ns.db.opt.models = true
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
	frames(400) -- every try of every model (famous NPC, then the trainer)
	Mock.missingDisplays = {}
	local back = 0
	for _, f in ipairs(heroes) do
		if f:IsShown() then
			if f.model and f.model:IsShown() then fail("a model that did not load should not stay up") break end
			if f.icon:IsShown() then back = back + 1 end
		end
	end
	if back == 0 then fail("a hero whose model did not load should fall back to the icon") end
	if not next(ns.db.models.bad) then fail("display ids the game does not have should be noted") end
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
			ns.db.opt.druidForm = false
			local body = Fig.HeroBody(h.id, true)
			if not body or body.weapons.mh ~= ns.MODEL.weapons[sid].mh or Fig.ForHero(h.id, true) == want then
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
		m:Step(0.05)
		m:PlaceFeet(UIParent, 300, 100)
		m:Show()
		return m
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
	if not ns.db.models.bad[D[npc]] then fail("a display id the game does not have should be noted") end
	if m3:IsLoaded() or not Fig.failed[npc] then fail("a model the game does not have should be given up on") end
	Mock.missingDisplays = {}
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
		anims[n] = f.model and f.model:IsShown() and animOf(f.model) or false
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
	-- the animation while it walks (from its first step to its last)
	local walk, other = 0, 0
	for n = (first or 2), (last or 1) do
		local a = anims[n]
		if a == 4 then walk = walk + 1 elseif a then other = other + 1 end
	end
	if walk + other > 10 and other > walk / 4 then fail(string.format("the walk should not be broken off between steps (%d walking, %d not)", walk, other)) end
end

-- the 3D model check (/bwi model): five models, animations, facing, distance
do
	local MC = ns.ModelCheck
	try("slash model", SlashCmdList.BIGWOWIDLE, "model")
	local mf = MC.Frame()
	if not (mf and mf:IsShown()) then fail("/bwi model should open the model check") end
	-- the hero as the battle bar draws it: the NPC of its class, race and gender
	local heroNpc = ns.Figure3D.ForHero(ns.Main.SelectedHero(), false)
	-- every NPC by its model (display id), as the battle bar puts it up
	local D = ns.MODEL.display
	local MOB = ns.MODEL.mob[ns.STAGES[1][1].mobs[1][1]]
	local want = { hero = "display:" .. tostring(D[heroNpc]), player = "unit:player", mob = "display:" .. D[MOB], boss = "display:" .. D[11502], pet = "display:" .. D[416] }
	for _, p in ipairs(MC.panels) do
		if not p.model then fail("no model frame for " .. p.def.key)
		elseif p.model.__model ~= want[p.def.key] then fail(p.def.key .. " shows " .. tostring(p.model.__model)) end
	end
	frames(20) -- the models report what loaded
	if not (MC.panels[3].name.__text or ""):find("NPC " .. MOB, 1, true) or not (MC.panels[3].lines[2].__text or ""):find("이름", 1, true) then fail("a creature card should show its NPC id and the client name") end
	if not (MC.panels[3].lines[3].__text or ""):find("모델 불러옴", 1, true) then fail("a loaded model should say so: " .. tostring(MC.panels[3].lines[3].__text)) end
	click("model: attack", function(b) return b.anim == 17 and b:IsVisible() end)
	for _, p in ipairs(MC.panels) do if p.model.__anim ~= 17 then fail("the attack button should play animation 17 on " .. p.def.key) end end
	click("model: next animation", function(b) return label(b) == ">" and b:GetParent() == mf end)
	if MC.state.anim ~= 18 or MC.panels[2].model.__anim ~= 18 then fail("> should step to the next animation number") end
	click("model: turn", function(b) return label(b) == "돌리기 >" end)
	if math.abs((MC.panels[1].model.__facing or 0) - math.pi / 4) > 1e-6 then fail("turning should face the models 45 degrees round") end
	click("model: battle facing", function(b) return label(b) == "전투 방향" end)
	if math.abs((MC.panels[1].model.__facing or 0) - math.pi / 2) > 1e-6 or math.abs((MC.panels[3].model.__facing or 0) - 3 * math.pi / 2) > 1e-6 then
		fail("전투 방향 should turn the heroes one way and the monsters the other")
	end
	click("model: farther", function(b) return label(b) == "멀리" end)
	if MC.panels[4].model.__dist ~= 1.25 then fail("멀리 should move the camera back") end
	MC.state.cycle = true
	MC.state.cycleT = 0
	frames(3)
	if MC.state.anim == 18 then fail("the automatic cycle should move on to another animation") end
	-- a client without a model function: the card says 없음
	local setAnim = Mock.Model.SetAnimation
	Mock.Model.SetAnimation = nil
	click("model: load again", function(b) return label(b) == "다시 불러오기" end)
	frames(10)
	Mock.Model.SetAnimation = setAnim
	if not (MC.panels[2].lines[5].__text or ""):find("없음", 1, true) then fail("a missing model function should read 없음: " .. tostring(MC.panels[2].lines[5].__text)) end
	-- only the pages the window has
	for _, b in ipairs(MC.Frame().setButtons) do
		if label(b) == "땜장이 후보" or label(b) == "다른 후보" then fail("the model check should have no page " .. label(b)) end
	end
	-- 전투 모습: the models as the battle draws them, on one ground line
	click("model: battle look", function(b) return label(b) == "전투 모습" end)
	local bp = MC.pages.battle
	if not bp.frame:IsShown() or MC.panels[1].card:IsShown() then fail("전투 모습 should show its own page instead of the cards") end
	frames(5)
	local figs = 0
	for _, slot in ipairs(bp.slots) do
		if slot.fig and slot.fig:IsShown() then
			figs = figs + 1
			if not slot.fig:IsLoaded() then fail("a 전투 모습 model should load") end
			if not (slot.state.__text or ""):find("불러옴", 1, true) then fail("a 전투 모습 model should say it loaded: " .. tostring(slot.state.__text)) end
		end
	end
	if figs < 3 then fail("전투 모습 should stand heroes and monsters side by side (" .. figs .. ")") end
	click("model: attack on the battle look", function(b) return b.anim == 17 and b:IsVisible() end)
	for _, slot in ipairs(bp.slots) do
		if slot.fig and slot.fig:IsShown() and slot.fig.actor and slot.fig.actor.__anim ~= 17 then fail("the animation buttons should play on 전투 모습 too") break end
	end
	-- 옷 입히기: a class's set on its race's own body (the race's base display)
	click("model: dressing", function(b) return label(b) == "옷 입히기" end)
	local dp = MC.pages.dress
	if not dp.frame:IsShown() or bp.frame:IsShown() then fail("옷 입히기 should show its own page") end
	frames(20)
	if dp.COMBOS[1].class ~= "WARRIOR" or dp.COMBOS[1].race ~= "DWARF" or #dp.COMBOS ~= 18 then fail("옷 입히기 should start with the dwarf warrior and go through 18 class/faction pairs") end
	local c1, c2, c3, c4 = dp.cards[1], dp.cards[2], dp.cards[3], dp.cards[4]
	local a1, a2, a3, a4 = c1.model.actor, c2.model.actor, c3.model, c4.model
	-- the player's own body as the race (customRaceID), nothing worn
	if a1.__display ~= "unit:player" or a1.__race ~= ns.MODEL.raceId.DWARF or a1.__dressed then
		fail("the first card should be the player's body as a dwarf, undressed: " .. tostring(a1.__display) .. " " .. tostring(a1.__race))
	end
	if a1.__worn and #a1.__worn > 0 then fail("the bare card should put nothing on") end
	if not (a2.__worn and #a2.__worn == 8) or not (c2.lines[3].__text or ""):find("TryOn 8/8", 1, true) then
		fail("the second card should try the eight pieces on the changed body: " .. tostring(c2.lines[3].__text))
	end
	-- a model frame with the player made the race and the gender picked
	if a3.__race ~= ns.MODEL.raceId.DWARF or a3.__sex ~= 0 or (a3.__worn and #a3.__worn > 0) then
		fail("the third card should be the player made a male dwarf, undressed: " .. tostring(a3.__race) .. " " .. tostring(a3.__sex))
	end
	if not (a4.__worn and #a4.__worn == 8) then fail("the fourth card should try the set on that body") end
	click("model: dressing next", function(b) return b == dp.next end)
	click("model: dressing female", function(b) return b == dp.sexBtn.F end)
	frames(20)
	if dp.i ~= 2 or dp.sex ~= "F" or a3.__race ~= ns.MODEL.raceId.ORC or a3.__sex ~= 1 or a1.__race ~= ns.MODEL.raceId.ORC then
		fail("▶ and 여 should show the orc woman: " .. tostring(a3.__race) .. " " .. tostring(a3.__sex) .. " " .. tostring(a1.__race))
	end
	if not (dp.label.__text or ""):find("오크 여", 1, true) then fail("the dressing label should name the race and gender: " .. tostring(dp.label.__text)) end
	-- 변신: the six druid forms by their display ids, with the model file
	-- loaded and whether it is the HD one
	do
		local HD = { [2281] = 1302532, [2289] = 1336653, [892] = 1273658, [8571] = 1363012, [15374] = 1139162, [15375] = 1139164 }
		Mock.displayFile = HD
		click("model: forms", function(b) return label(b) == "변신" end)
		local fpg = MC.pages.forms
		if not fpg.frame:IsShown() or dp.frame:IsShown() then fail("변신 should show its own page") end
		frames(10)
		if #fpg.cards ~= 6 then fail("변신 should show bear, cat and moonkin for both factions") end
		for _, c in ipairs(fpg.cards) do
			local want = ns.MODEL.form[c.e.form][c.e.faction]
			if not c.fig or c.fig.actor.__display ~= want then fail("a form card should load the battle's display id " .. want .. ": " .. tostring(c.fig and c.fig.actor.__display)) end
			if c.hd ~= true or not (c.lines[2].__text or ""):find("HD 모델", 1, true) then fail("a form card should say its HD model file loaded: " .. tostring(c.lines[2].__text)) end
		end
		-- a client where a display brings up another file: said so
		Mock.displayFile = {}
		fpg.setup()
		frames(10)
		if fpg.cards[1].hd ~= false or not (fpg.cards[1].lines[2].__text or ""):find("HD 아님", 1, true) then fail("a form card should say when the file is not the HD one") end
		for id, path in pairs(ns.MODEL.formHD) do
			if not path:find("2%.m2$") then fail("the HD form files should be the remade (…2.m2) models: " .. path) end
		end
		-- every form's display id is listed with its HD file
		for disp, file in pairs(HD) do if not ns.MODEL.formHD[file] then fail("missing HD file for form " .. disp) end end
		click("model: dressing again", function(b) return label(b) == "옷 입히기" end)
	end
	click("model: dressing back", function(b) return b == dp.prev end)
	click("model: dressing back again", function(b) return b == dp.prev end)
	if dp.i ~= #dp.COMBOS then fail("◀ from the first pair should go round to the last") end
	dp.Pick(1, "M")
	-- 효과: a spell's kits on the scene models and model frames, its effect
	-- files by file id, playing over and over
	Mock.kits = {}
	click("model: effects", function(b) return label(b) == "효과" end)
	local fp = MC.pages.fx
	if not fp.frame:IsShown() or dp.frame:IsShown() then fail("효과 should show its own page") end
	if #fp.buttons ~= #ns.SPELL_FX then fail("효과 should have a button per spell") end
	frames(40)
	local LB = ns.SPELL_FX[1]
	local seen = {}
	for _, k in ipairs(Mock.kits) do seen[k] = (seen[k] or 0) + 1 end
	for _, k in ipairs({ LB.precast, LB.cast, LB.impact }) do
		if (seen[k] or 0) < 2 then fail("번개 화살 should play its kit " .. k .. " on the scene models and the model frames (" .. tostring(seen[k]) .. ")") end
	end
	local sc, fc = fp.cards[1], fp.cards[3]
	if sc.missile.actor.__display ~= "file:" .. LB.missile then fail("the missile should be the spell's model file: " .. tostring(sc.missile.actor.__display)) end
	if fc.hand.actor.__display ~= "file:" .. LB.hand or fc.hit.actor.__display ~= "file:" .. LB.hit then fail("the effect files should be put up by their file ids") end
	if fp.cards[2].missile.__model ~= "file:" .. LB.missile then fail("the model frame's missile should be the spell's file: " .. tostring(fp.cards[2].missile.__model)) end
	if not (sc.lines[1].__text or ""):find("SetSpellVisualKit", 1, true) or not (fp.cards[2].lines[1].__text or ""):find("ApplySpellVisualKit", 1, true) then
		fail("each way should say which call it used")
	end
	if #Mock.misuse > 0 then fail("효과 calls with bad arguments: " .. table.concat(Mock.misuse, "; ")) end
	Mock.kits = {}
	click("model: effects fireball", function(b) return b == fp.buttons[2] end)
	frames(40)
	local hit30 = false
	for _, k in ipairs(Mock.kits) do if k == ns.SPELL_FX[2].precast then hit30 = true end end
	if fp.i ~= 2 or not hit30 then fail("picking 화염구 should play its kits") end
	click("model: basic check", function(b) return label(b) == "기본 확인" end)
	if dp.frame:IsShown() or not MC.panels[1].card:IsShown() then fail("기본 확인 should bring the cards back") end
	if MC.panels[3].model.__model ~= "display:" .. D[MOB] then fail("기본 확인 should bring the basic models back") end
	hoverAll()
	try("slash model again", SlashCmdList.BIGWOWIDLE, "모델")
	if mf:IsShown() then fail("/bwi model again should close the model check") end
end
try("compartment", BigWowIdle_OnAddonCompartmentClick)

-- a long stretch with a full party fighting, then lag spikes
enrich(1)
-- the random clicks may have reset everything: learn the party-slot runes again
ns.AddGold(5e9)
for _ = 1, 3 do
	for _, id in ipairs({ "root", "c1", "c2", "c3", "c6", "c4", "c5", "c7" }) do ns.Runes.Buy(id) end
end
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
frames(10)
local st = ns.db.stat
print(string.format("  after the run: %d kills, %d clears, %d chests opened, forge level %d, %d heroes",
	st.kills, st.clears, st.chests, ns.db.forge.level, H.Count()))

-- every texture path must be well-formed; addon textures must exist on disk
for path in pairs(Mock.textures) do
	if path:find("Interface\\Icons\\") and (path:find("%s") or path:sub(-1) == "\\") then
		fail("malformed icon path: " .. path)
	end
	local media = path:match("\\Media\\([%w_]+)%.tga$")
	if media then
		local f = io.open(debug.getinfo(1, "S").source:sub(2):gsub("tests/test_ui%.lua$", "BigWowIdle/Media/" .. media .. ".tga"), "rb")
		if f then f:close() else fail("missing texture file: Media/" .. media .. ".tga") end
	elseif path:find("AddOns") then
		fail("unexpected addon texture path: " .. path)
	end
end

if failures == 0 then print("  ui: all checks passed") end
return failures == 0
