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
click("class Tinker", function(b) return b.cid == "TINKER" end)
click("class Hunter", function(b) return b.cid == "HUNTER" end)
click("spec Marksmanship", function(b) return b.sid == "HUNTER_MM" end)
click("female", function(b) return b.sex == "F" end)
click("reroll name", labelIs("다시"))
click("create", function(b) return label(b) == "사격 사냥꾼 만들기" and b.__w == 210 end)
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
	local healer = ns.db.party[5]
	press("take the healer out", pp.slots[5].out)
	if ns.db.party[5] then fail("빼기 should free the healer's slot") end
	Main.Refresh()
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
		try("auto toggle", bar.auto.Click, bar.auto, "LeftButton")
		if ns.db.opt.auto == auto then fail("the HUD auto button should toggle auto-advance") end
		try("auto toggle back", bar.auto.Click, bar.auto, "LeftButton")
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
	local art = path:match("\\Media\\Art\\([%w_]+)$") or path:match("\\Media\\Art\\([%w_]+)%.tga$")
	if art then
		local A = ns.ART or {}
		local known = false
		for _, sec in ipairs({ "ui", "icons", "sprites", "fx", "bg" }) do
			for _, e in pairs(A[sec] or {}) do if e.file == art then known = true end end
		end
		if not known then fail("texture from imported art that is not in Data/Art.lua: " .. art) end
	elseif media then
		local f = io.open(debug.getinfo(1, "S").source:sub(2):gsub("tests/test_ui%.lua$", "BigWowIdle/Media/" .. media .. ".tga"), "rb")
		if f then f:close() else fail("missing texture file: Media/" .. media .. ".tga") end
	elseif path:find("AddOns") then
		fail("unexpected addon texture path: " .. path)
	end
end

if failures == 0 then print("  ui: all checks passed") end
return failures == 0
