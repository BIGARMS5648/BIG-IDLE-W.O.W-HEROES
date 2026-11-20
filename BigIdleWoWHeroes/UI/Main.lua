-- Main window: a hero strip on the left, tabs on top, one content page per tab.
local _, ns = ...

local UI, U = ns.UI, ns.U

local Main = {}
ns.Main = Main

Main.W, Main.H = 800, 540
Main.PAGE_X, Main.PAGE_Y = 64, -58
Main.PAGE_W, Main.PAGE_H = 728, 474

local frame
local tabs = {}        -- ordered
local tabByKey = {}
local current
local dirty = {}       -- [tabKey] = true when its page needs a refresh

------------------------------------------------------------------------
-- Tab registry (each UI/Tab*.lua file registers itself)
------------------------------------------------------------------------
-- def: { key, title = { ko, en }, build = function(page), refresh = function(page), events = { ... } }
function Main.RegisterTab(def)
	tabs[#tabs + 1] = def
	tabByKey[def.key] = def
	for _, ev in ipairs(def.events or {}) do
		ns.On(ev, function() Main.MarkDirty(def.key) end)
	end
end

function Main.MarkDirty(key)
	if key then
		dirty[key] = true
	else
		for _, t in ipairs(tabs) do dirty[t.key] = true end
	end
end

------------------------------------------------------------------------
-- Selected hero (shared by the Hero, Bag and Forge pages)
------------------------------------------------------------------------
function Main.SelectedHero()
	local db = ns.db
	if Main.sel and db.heroes[Main.sel] then return Main.sel end
	for i = 1, ns.PARTY_SIZE do
		if db.party[i] and db.heroes[db.party[i]] then
			Main.sel = db.party[i]
			return Main.sel
		end
	end
	for _, id in ipairs(ns.CLASS_ORDER) do
		if db.heroes[id] then
			Main.sel = id
			return id
		end
	end
	Main.sel = nil
	return nil
end

function Main.SelectHero(id)
	Main.sel = id
	Main.MarkDirty()
	Main.RefreshStrip()
end

local function heroTip(self)
	local id = self.classId
	local c = ns.CLASSES[id]
	local h = ns.db.heroes[id]
	local r, g, b = U.rgb(c.hex)
	local lines = { { ns.N(c.name), ns.N(ns.ROLE[c.role].name), r, g, b } }
	if h then
		lines[#lines + 1] = { string.format(ns.T("레벨 %d", "Level %d"), h.level), nil, 1, 1, 1 }
		if h.level < ns.HERO_MAX_LEVEL then
			lines[#lines + 1] = { ns.T("경험치", "Experience"), U.fmt(h.xp) .. " / " .. U.fmt(ns.XPForLevel(h.level)), 0.8, 0.8, 0.8 }
		end
		local free = ns.Heroes.PointsFree(id)
		if free > 0 then
			lines[#lines + 1] = { string.format(ns.T("사용하지 않은 기술 점수 %d", "%d unspent skill points"), free), nil, 0.3, 1, 0.3 }
		end
		lines[#lines + 1] = { ns.Heroes.PartySlot(id) and ns.T("파티에 참여 중", "In the party") or ns.T("대기 중", "On the bench"), nil, 0.7, 0.7, 0.7 }
	else
		lines[#lines + 1] = { ns.T("아직 영입하지 않았습니다. '파티' 탭에서 영입하세요.", "Not recruited yet. Recruit on the Party tab."), nil, 0.7, 0.7, 0.7 }
	end
	lines[#lines + 1] = { ns.N(c.desc), nil, 1, 0.82, 0 }
	return lines
end

function Main.RefreshStrip()
	if not frame then return end
	local sel = Main.SelectedHero()
	for i, id in ipairs(ns.CLASS_ORDER) do
		local b = frame.strip[i]
		local h = ns.db.heroes[id]
		b:SetDim(not h)
		b:SetSelected(id == sel)
		if h then
			b:SetCount(tostring(h.level))
			local r, g, bl = U.rgb(ns.ROLE[ns.CLASSES[id].role].hex)
			if ns.Heroes.PartySlot(id) then b:SetBorderRGB(r, g, bl) else b:SetQuality(nil) end
			local free = ns.Heroes.PointsFree(id)
			b:SetMark(free > 0 and "+" or "", 0.3, 1, 0.3)
		else
			b:SetCount("")
			b:SetMark("")
			b:SetQuality(nil)
		end
	end
end

------------------------------------------------------------------------
-- Showing pages
------------------------------------------------------------------------
function Main.ShowTab(key)
	local def = tabByKey[key]
	if not def or not frame then return end
	current = key
	for _, t in ipairs(tabs) do
		if t.page then t.page:Hide() end
		if t.button then t.button:SetOn(t.key == key) end
	end
	if not def.page then
		def.page = CreateFrame("Frame", nil, frame)
		def.page:SetSize(Main.PAGE_W, Main.PAGE_H)
		def.page:SetPoint("TOPLEFT", frame, "TOPLEFT", Main.PAGE_X, Main.PAGE_Y)
		def.build(def.page)
	end
	def.page:Show()
	def.refresh(def.page)
	dirty[key] = nil
	ns.db.ui.tab = key
end

function Main.Current()
	return current
end

function Main.Refresh()
	if frame and frame:IsShown() and current then
		local def = tabByKey[current]
		if def.page then def.refresh(def.page) end
		dirty[current] = nil
		Main.RefreshStrip()
		UI.RefreshTip()
	end
end

local refreshT = 0
local function onUpdate(_, elapsed)
	refreshT = refreshT - elapsed
	if refreshT > 0 then return end
	refreshT = 0.15
	if current and dirty[current] then
		Main.Refresh()
	end
	local def = current and tabByKey[current]
	if def and def.tick and def.page then def.tick(def.page) end
	frame.gold:SetText(UI.Gold(ns.db.gold))
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
function Main.Create()
	if frame then return frame end
	frame = CreateFrame("Frame", "BigIdleWoWHeroesMain", UIParent)
	frame:SetSize(Main.W, Main.H)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	UI.Box(frame, UI.COLOR.bg)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint(1)
		if p then ns.db.ui.mainPos = { p, rp or p, x or 0, y or 0 } end
	end)
	local pos = ns.db.ui.mainPos
	if pos and pos[1] then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
	frame:SetScale(ns.db.ui.scale or 1)

	frame.title = UI.Text(frame, 14, "Big Idle W.O.W Heroes")
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -9)
	frame.title:SetTextColor(1, 0.82, 0)
	frame.gold = UI.Text(frame, 13)
	frame.gold:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -10)
	frame.gold:SetJustifyH("RIGHT")
	frame.close = UI.Button(frame, 24, 20, "X", function() Main.Toggle(false) end)
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -6)

	-- tabs
	local x = 64
	for _, def in ipairs(tabs) do
		local b = UI.Button(frame, 98, 22, ns.N(def.title), function() Main.ShowTab(def.key) end)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -32)
		def.button = b
		x = x + 102
	end

	-- hero strip
	frame.strip = {}
	for i, id in ipairs(ns.CLASS_ORDER) do
		local b = UI.IconButton(frame, 44, function(self) Main.SelectHero(self.classId) end)
		b.classId = id
		b:SetClass(id)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -58 - (i - 1) * 48)
		UI.Tip(b, heroTip)
		frame.strip[i] = b
	end

	frame:SetScript("OnUpdate", onUpdate)
	frame:SetScript("OnShow", function()
		Main.RefreshStrip()
		if current then Main.ShowTab(current) end
	end)
	frame:SetScript("OnHide", function() UI.HideTip() end)
	if UISpecialFrames then
		UISpecialFrames[#UISpecialFrames + 1] = "BigIdleWoWHeroesMain" -- close with Escape
	end
	frame:Hide()
	return frame
end

function Main.Toggle(show)
	if not frame then return end
	if show == nil then show = not frame:IsShown() end
	if show then
		if not current then
			local key = ns.db.ui.tab
			if not tabByKey[key] then key = tabs[1].key end
			if ns.Heroes.Count() == 0 then key = "party" end
			current = key
		end
		frame:Show()
	else
		frame:Hide()
	end
end

function Main.IsShown()
	return frame and frame:IsShown()
end

function Main.ApplyScale()
	if frame then frame:SetScale(ns.db.ui.scale or 1) end
end

-- hero strip follows anything that changes levels or the party
for _, ev in ipairs({ "HEROES", "PARTY", "LEVEL", "TREE", "RESET" }) do
	ns.On(ev, function()
		if frame and frame:IsShown() then Main.RefreshStrip() end
	end)
end
