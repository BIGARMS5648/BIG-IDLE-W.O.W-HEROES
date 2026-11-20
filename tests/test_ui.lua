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
BigIdleWoWHeroesDB = nil

------------------------------------------------------------------------
-- start-up
------------------------------------------------------------------------
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "SomeOtherAddon")
try("ADDON_LOADED", Mock.FireEvent, "ADDON_LOADED", "BigIdleWoWHeroes")
try("PLAYER_LOGIN", Mock.FireEvent, "PLAYER_LOGIN")
if not ns.db then
	fail("saved variables were not initialised")
	return false
end
if not Main.IsShown() then fail("the menu should open by itself for a new player") end
if Main.Current() ~= "party" then fail("a new player should land on the party screen") end
if ns.db.faction then fail("a new player has no faction yet") end
click("choose Horde", labelIs("호드로 시작"))
if ns.db.faction ~= "HORDE" then fail("the faction choice was not saved") end
if not find(function(b) return b.cid == "WARRIOR" end) then fail("the hero creation dialog should open after the faction choice") end
if not SlashCmdList.BIGIDLEWOWHEROES then fail("slash command missing") end
if type(BigIdleWoWHeroes_OnAddonCompartmentClick) ~= "function" then fail("addon compartment function missing") end
local goal = ns.Guide.Current()
if not (goal.create and goal.tab == "party") then fail("the first goal should be to create a hero") end

local tabs = { "party", "hero", "bag", "forge", "runes", "map", "options" }
if #Main.Frame().nav ~= 6 then fail("the bottom bar should have six screens (settings is in the header)") end

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
try("show party", Main.ShowTab, "party")
local page = Main.Page("party")
if not page.S.card.wide:IsVisible() then fail("an empty roster should offer the first hero on the card") end
try("open create dialog", page.create.Click, page.create, "LeftButton")
click("class Tinker", function(b) return b.cid == "TINKER" end)
click("class Hunter", function(b) return b.cid == "HUNTER" end)
click("spec Marksmanship", function(b) return b.sid == "HUNTER_MM" end)
click("female", function(b) return b.sex == "F" end)
click("reroll name", labelIs("다시"))
click("create", function(b) return label(b) == "사격 사냥꾼 만들기" and b.__w == 220 end)
if H.Count() ~= 1 then fail("creating through the dialog did not make a hero") end
local first = H.List()[1]
if first and ns.db.heroes[first].spec ~= "HUNTER_MM" then fail("the hero has the wrong specialization") end
if first and ns.db.heroes[first].sex ~= "F" then fail("the chosen gender was not kept") end
if first and H.Race(first) ~= "TROLL" then fail("a Horde hunter should be a troll") end
if first and H.PartySlot(first) ~= 2 then fail("the first damage dealer should join slot 2") end
if first and not tostring(ns.db.heroes[first].name):find("^%S+ %S+$") then fail("hero name should be given + family name") end
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
for _, sid in ipairs({ "WARRIOR_PROT", "PRIEST_HOLY", "MAGE_FIRE", "ROGUE_ASSA", "DRUID_GUARDIAN", "SHAMAN_RESTO", "WARLOCK_DEMO" }) do H.Create(sid) end
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
-- walkthroughs (every screen: pick on the left, act on the card)
------------------------------------------------------------------------
local function card(key) return Main.Page(key).S.card end
local function press(what, b)
	if not b or not b:IsVisible() then fail("not shown: " .. what) return false end
	return try(what, b.Click, b, "LeftButton")
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

-- party: pick a hero, act from the card
do
	Main.ShowTab("party")
	local pp = Main.Page("party")
	local d = card("party")
	local bench
	for _, id in ipairs(H.List()) do
		if not H.PartySlot(id) and H.Role(id) == "TANK" then bench = id end
	end
	local tankBefore = ns.db.party[1]
	for _, c in ipairs(pp.roster) do
		if c.heroId == bench then try("pick bench tank", c.Click, c, "LeftButton") end
	end
	Main.Refresh()
	if label(d.right) ~= "교체 출전" then fail("the card should offer to swap the bench tank in, got " .. tostring(label(d.right))) end
	press("swap", d.right)
	if ns.db.party[1] ~= bench or tankBefore == bench then fail("swapping a bench tank in did not work") end
	if pp.slots[1] and pp.slots[5] then
		local x1 = select(4, pp.slots[1]:GetPoint(1))
		local x5 = select(4, pp.slots[5]:GetPoint(1))
		if not (x1 and x5 and x1 > x5) then fail("the tank card should be drawn in front (right of the healer)") end
	end
	click("auto form", labelIs("자동 편성"))
	click("companions", labelIs("동료"))
	hoverAll()
	Main.CloseModal()
	local healer = ns.db.party[5]
	try("pick healer", pp.slots[5].Click, pp.slots[5], "LeftButton")
	Main.Refresh()
	if label(d.left) ~= "휴식" then fail("a fielded hero's card should offer rest") end
	press("rest healer", d.left)
	if ns.db.party[5] then fail("resting the healer did not free slot 5") end
	frames(2)
	try("pick empty slot", pp.slots[5].Click, pp.slots[5], "LeftButton")
	if not (pp.sel and pp.sel.slot == 5) then fail("picking an empty slot should select it") end
	if pp.filter ~= "HEALER" then fail("picking an empty slot should show its role in the roster") end
	Main.Refresh()
	local row
	for _, r in ipairs(pp.slotRows) do if r.heroId == healer then row = r end end
	if not row then fail("the empty slot's card should list the bench healer") else press("pick from card", row) end
	Main.Refresh()
	press("field healer", d.right)
	if not ns.db.party[5] then fail("the card should field the picked healer") end
	-- rename and dismiss live on the hero's card
	local id = ns.db.party[2]
	for _, c in ipairs(pp.roster) do if c.heroId == id then try("pick", c.Click, c, "LeftButton") end end
	Main.Refresh()
	press("rename", d.x1)
	click("rename reroll", labelIs("다시"))
	click("rename keep", labelIs("이 이름으로"))
	if not tostring(ns.db.heroes[id].name):find("^%S+ %S+$") then fail("renaming should keep the given + family name form") end
	local benchId
	for _, hid in ipairs(H.List()) do if not H.PartySlot(hid) then benchId = hid end end
	pp.sel = { hero = benchId }
	Main.Refresh()
	local n = H.Count()
	press("dismiss", d.x2)
	if H.Count() ~= n then fail("one click must not dismiss a hero") end
	confirmYes("dismiss")
	if H.Count() ~= n - 1 or ns.db.heroes[benchId] then fail("confirming should dismiss the hero") end
	hoverAll()
end

-- hero: talents, skills, gear
do
	local id = ns.db.party[2]
	Main.SelectHero(id)
	Main.ShowTab("hero", { sub = "tree" })
	local hp = Main.Page("hero")
	local d = card("hero")
	ns.db.heroes[id].tree = {}
	ns.db.heroes[id].skills = {}
	ns.Stats.Invalidate(id)
	hp.node = nil
	Main.Refresh()
	local free = H.PointsFree(id)
	local skillFree = H.SkillPointsFree(id)
	click("talent node", function(b) return b.tier == 1 and b.n == 1 end)
	if H.PointsFree(id) ~= free then fail("clicking a talent should only select it") end
	if label(d.right) ~= "1점 쓰기" then fail("the talent card should offer to spend a point") end
	press("spend", d.right)
	if H.PointsFree(id) ~= free - 1 then fail("the card button should spend a point") end
	if H.SkillPointsFree(id) ~= skillFree then fail("talents must not use skill points") end
	if find(function(b) return b.tier and b.n and b.n > 2 end) then fail("the talent tree must not show skills") end
	press("auto-assign", hp.autoTree)
	if H.PointsFree(id) ~= 0 then fail("auto-assign should spend every talent point") end
	tab("hero", "skills")
	if hp.sub ~= "skills" then fail("the skills tab did not switch the sub-page") end
	ns.db.heroes[id].sk = { [H.SkillList(id)[1]] = 1 }
	ns.db.heroes[id].skills = { H.SkillList(id)[1] }
	Main.Refresh()
	local second = H.SkillList(id)[2]
	click("select skill 2", function(b) return b.sid == second and b.title end)
	if hp.skill ~= second then fail("clicking a skill should select it") end
	if label(d.right) ~= "배우기 (1점)" then fail("the skill card should offer to learn, got " .. tostring(label(d.right))) end
	press("learn skill", d.right)
	if H.SkillPoints(id, second) ~= 1 then fail("learning a skill from the card did not work") end
	Main.Refresh()
	press("raise skill", d.right)
	if H.SkillPoints(id, second) ~= 2 then fail("raising a skill did not work") end
	Main.Refresh()
	local active = #H.ActiveSkills(id)
	if label(d.left) == "해제" then
		press("remove skill", d.left)
		if #H.ActiveSkills(id) ~= active - 1 then fail("removing a skill did not work") end
		Main.Refresh()
	end
	if label(d.left) ~= "장착" then fail("a learned, unequipped skill should offer to equip") end
	local before = #H.ActiveSkills(id)
	press("equip skill", d.left)
	if #H.ActiveSkills(id) ~= before + 1 then fail("equipping a skill did not work (" .. before .. " active, " .. #ns.db.heroes[id].skills .. "/" .. ns.SkillSlots() .. " slots, " .. tostring((H.IsSkillEquipped(id, second))) .. ")") end
	Main.Refresh()
	press("auto skills", hp.autoSkills)
	if H.SkillPointsFree(id) ~= 0 then fail("auto skills should spend every skill point") end
	tab("hero", "gear")
	click("slot ring", function(b) return b.slot == "ring" end)
	if hp.slot ~= "ring" then fail("clicking an equipment slot should show it on the card") end
	if not d.close:IsVisible() then fail("a chosen slot should have a close button on the card") end
	press("back to stats", d.close)
	if hp.slot ~= nil then fail("closing the slot should go back to the hero") end
	if label(d.right) ~= "일괄 장착" then fail("the hero card should offer to equip the best gear") end
	if label(d.left) ~= "파티 전원 장착" then fail("the hero card's other button should equip the whole party") end
	if find(function(b) return label(b) == "상세 능력치" end) then fail("there should be no detailed-stats button (the card shows every stat)") end
	try("equip best", d.right.Click, d.right, "LeftButton")
	press("equip party", d.left)
	hoverAll()
end

-- bags: select, equip, lock, bank, materials
do
	Main.ShowTab("bag")
	local bp = Main.Page("bag")
	local d = card("bag")
	local id = ns.db.party[1]
	Main.SelectHero(id)
	local sword = ns.Items.New("mh", 5, 4, H.Spec(id).mh[1])
	ns.db.bag = {}
	ns.Items.AddToBag(sword)
	for i = 1, 6 do ns.Items.AddToBag(ns.Items.New("head", 5 + i, 2)) end
	Main.Refresh()
	click("select sword", function(b) return b.data == sword end)
	if bp.selItem ~= sword then fail("clicking an item should select it") end
	if label(d.right) ~= "장착" then fail("the item card should offer to equip") end
	press("equip", d.right)
	if ns.db.heroes[id].gear.mh ~= sword then fail("the card's equip button should equip the item") end
	local junk = ns.db.bag[1]
	bp.selItem = junk
	Main.Refresh()
	press("lock", d.x1)
	if not junk.lock then fail("the lock button should lock the item") end
	press("to bank", d.x2)
	if ns.db.bank[1] ~= junk then fail("the bank button should move the item to the bank") end
	tab("bag", "bank")
	click("select banked", function(b) return b.data == junk end)
	press("from bank", d.wide)
	if not ns.Items.IndexInBag(junk) then fail("taking an item out of the bank did not work") end
	tab("bag", "all")
	local before = #ns.db.bag
	local victim
	for _, it in ipairs(ns.db.bag) do
		if not it.lock then victim = it end
	end
	bp.selItem = victim
	Main.Refresh()
	press("smelt one", d.left)
	if #ns.db.bag ~= before then fail("breaking down must ask first") end
	confirmYes("smelt one")
	if #ns.db.bag ~= before - 1 then fail("the card's break-down button should break the item down") end
	-- right-click asks too
	local rc = ns.db.bag[#ns.db.bag]
	if rc.lock then ns.Items.ToggleLock(rc) end
	Main.Refresh()
	local n1 = #ns.db.bag
	click("right-click smelt", function(b) return b.data == rc end, "RightButton")
	if #ns.db.bag ~= n1 then fail("right-click must ask before breaking down") end
	confirmYes("right-click smelt")
	if #ns.db.bag ~= n1 - 1 then fail("confirming a right-click should break the item down") end
	local alt = ns.db.bag[#ns.db.bag]
	local wasLocked = alt.lock
	Mock.alt = true
	click("alt-click", function(b) return b.data == alt end)
	Mock.alt = false
	if (alt.lock and true or false) == (wasLocked and true or false) then fail("Alt+click should protect / unprotect an item") end
	ns.Items.ToggleLock(alt)
	ns.db.ui.smeltQ = ns.MAX_QUALITY
	Main.Refresh()
	local n0 = #ns.db.bag
	try("bulk smelt", bp.smeltGo.Click, bp.smeltGo, "LeftButton")
	if #ns.db.bag ~= n0 then fail("bulk smelt must ask first") end
	if #ns.Forge.PickByQuality(ns.MAX_QUALITY) > 0 then
		confirmYes("bulk smelt")
		if #ns.db.bag == n0 then fail("confirming should smelt") end
	end
	-- the threshold is picked from a list
	press("threshold list", bp.smeltPick)
	click("threshold 3", function(b) return b.value == 3 and b.label end)
	if ns.db.ui.smeltQ ~= 3 then fail("picking from the threshold list did not set it") end
	enrich(3)
	Main.Refresh()
	for _, t in ipairs({ "weapon", "armor", "acc", "mats", "bank", "all" }) do tab("bag", t) end
	tab("bag", "mats")
	local bars = ns.MatCount("bar1")
	click("select bars", function(b) return b.data == "bar1" end)
	press("fuse 9", d.right)
	if ns.MatCount("bar1") ~= bars - 9 then fail("fusing nine materials from the card did not work") end
	ns.AddMat("cloth1", 20)
	Main.Refresh()
	press("auto fuse", bp.autoFuse)
	confirmYes("auto fuse")
	if ns.MatCount("cloth1") >= 9 then fail("auto-fuse should leave fewer than nine of each material") end
	press("sort materials", bp.sort)
	tab("bag", "all")
	enrich(2)
	Main.Refresh()
	click("open chests", function(b) return label(b) and label(b):find("상자 열기", 1, true) end)
	hoverAll()
end

-- forge: every operation
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
	local d = card("forge")
	local before = #ns.db.bag
	if label(d.right) ~= "융합하기" then fail("the fusion card should offer to fuse") end
	press("fuse", d.right)
	if #ns.db.bag ~= before - 8 then fail("fusing through the forge should turn 9 items into 1") end
	press("fuse all", d.left)
	confirmYes("fuse all")
	if #ns.db.bag ~= 3 then fail("fuse-all should leave 3 items, got " .. #ns.db.bag) end
	local fp = Main.Page("forge").panels.fuse
	press("fusion grade list", fp.pick)
	click("grade 3", function(b) return b.value == 3 and b.label end)
	if fp.q ~= 3 then fail("picking the fusion grade from the list did not work") end
	press("fusion kind list", fp.catBtn)
	click("accessories", function(b) return b.value == "accessory" end)
	if fp.cat ~= "accessory" then fail("picking the fusion kind from the list did not work") end
	tab("forge", "craft")
	before = #ns.db.bag
	press("craft", d.wide)
	if #ns.db.bag ~= before + 1 then fail("crafting should add one item") end
	local epic = ns.Items.New("chest", 30, 6)
	ns.Items.AddToBag(epic)
	for _, step in ipairs({ { "gem", "gem2", "g" }, { "ench", "dust2", "e" }, { "insc", "scroll2", "i" } }) do
		tab("forge", step[1])
		click("target", function(b) return b.data == epic end)
		click("material", function(b) return b.data == step[2] end)
		press("apply " .. step[1], d.wide)
		if not epic[step[3]] or #epic[step[3]] ~= 1 then fail(step[1] .. " did not add a stat") end
	end
	tab("forge", "remove")
	click("item to clear", function(b) return b.data == epic end)
	press("extract", d.wide)
	confirmYes("extract")
	if (#(epic.g or {}) + #(epic.e or {}) + #(epic.i or {})) ~= 2 then fail("extraction should clear one stat") end
	tab("forge", "seal")
	before = #ns.db.bag
	press("roll", d.wide)
	if #ns.db.bag ~= before + 1 then fail("a bonus roll should add one item") end
	tab("forge", "smelt")
	hoverAll()
end

-- runes: the tree; pick a rune, learn it from the bar
do
	Main.ShowTab("runes")
	local rp = Main.Page("runes")
	local lvl = ns.Runes.Level("w1")
	click("rune w1", function(b) return b.node and b.node.id == "w1" end)
	if rp.sel ~= "w1" then fail("clicking a rune should select it") end
	press("learn", rp.learn)
	if ns.Runes.Level("w1") ~= lvl + 1 then fail("learning a rune did not work") end
	if not ns.Runes.Available("w2") or not ns.Runes.Available("w3") then fail("a branch hub should open both of its lines") end
	if ns.Runes.Available("w4") and ns.Runes.Level("w2") == 0 then fail("a rune on a line needs the one before it") end
	click("rune w9", function(b) return b.node and b.node.id == "w9" end)
	if ns.Runes.Level("w9") == 0 and rp.prevBtn:IsVisible() then
		press("first rune to learn", rp.prevBtn)
		if not ns.Runes.Available(rp.sel) then fail("'먼저 배울 룬' should select a rune that can be learned") end
	end
	press("totals", rp.totalBtn)
	hoverAll()
	Main.CloseModal()
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

-- settings: every tab
do
	Main.ShowTab("options")
	for _, t in ipairs({ "screen", "game", "info" }) do
		tab("options", t)
		hoverAll()
	end
end

-- HUD: goal, auto toggle, chests, menu shortcuts
do
	local bar = BigIdleWoWHeroesBar
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
local clickTabs = { "party", "hero", "bag", "forge", "forge", "runes", "map", "options", "bag", "hero" }
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
try("slash", SlashCmdList.BIGIDLEWOWHEROES, "")
try("slash bar", SlashCmdList.BIGIDLEWOWHEROES, "bar")
frames(20)
try("slash bar", SlashCmdList.BIGIDLEWOWHEROES, "bar")
try("slash reset", SlashCmdList.BIGIDLEWOWHEROES, "reset")
try("slash help", SlashCmdList.BIGIDLEWOWHEROES, "help")
try("compartment", BigIdleWoWHeroes_OnAddonCompartmentClick)

-- a long stretch with a full party fighting, then lag spikes
enrich(1)
if H.PartyCount() == 0 then H.Create("MAGE_FROST") end
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
		local f = io.open(debug.getinfo(1, "S").source:sub(2):gsub("tests/test_ui%.lua$", "BigIdleWoWHeroes/Media/" .. media .. ".tga"), "rb")
		if f then f:close() else fail("missing texture file: Media/" .. media .. ".tga") end
	elseif path:find("AddOns") then
		fail("unexpected addon texture path: " .. path)
	end
end

if failures == 0 then print("  ui: all checks passed") end
return failures == 0
