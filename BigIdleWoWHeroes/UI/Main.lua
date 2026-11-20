-- Main window: a header with the screen title, gold, settings and close; the
-- screen itself; and a bottom navigation bar of six screens with red dots.
-- Settings is reached from the header's gear button, not from the bar.
local _, ns = ...

local UI, U = ns.UI, ns.U

local Main = {}
ns.Main = Main

Main.W, Main.H = 880, 604
Main.PAGE_X, Main.PAGE_Y = 16, -58
Main.PAGE_W, Main.PAGE_H = 848, 468
local NAV_H = 70

local frame
local tabs = {}
local tabByKey = {}
local current
local dirty = {}

------------------------------------------------------------------------
-- Screen registry (each UI/Tab*.lua file registers itself)
------------------------------------------------------------------------
-- def: { key, title, sub, icon, art (imported icon id), build(page), refresh(page),
--        open(page, opts) optional, tick(page) optional, events = { ... },
--        nav = false to keep it off the bottom bar }
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
-- Selected hero (shared by several screens)
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
	Main.sel = ns.Heroes.List()[1]
	return Main.sel
end

function Main.SelectHero(id)
	Main.sel = id
	Main.MarkDirty()
end

------------------------------------------------------------------------
-- Showing screens
------------------------------------------------------------------------
function Main.ShowTab(key, opts)
	local def = tabByKey[key]
	if not def or not frame then return end
	current = key
	if def.nav ~= false then Main.lastNav = key end
	Main.CloseModal()
	if UI.CloseList then UI.CloseList() end
	for _, t in ipairs(tabs) do
		if t.page then t.page:Hide() end
	end
	if not def.page then
		def.page = CreateFrame("Frame", nil, frame)
		def.page:SetSize(Main.PAGE_W, Main.PAGE_H)
		def.page:SetPoint("TOPLEFT", frame, "TOPLEFT", Main.PAGE_X, Main.PAGE_Y)
		def.build(def.page)
	end
	frame.title:SetText(ns.N(def.title))
	frame.sub:SetText(def.sub and ns.N(def.sub) or "")
	frame.titleIcon:SetShown(def.icon ~= nil)
	if def.icon then UI.SetArtOrIcon(frame.titleIcon, def.art, def.icon) end
	frame.gear:SetOn(key == "options")
	def.page:Show()
	if def.open then def.open(def.page, opts) end
	def.refresh(def.page)
	dirty[key] = nil
	ns.db.ui.tab = key
	Main.RefreshNav()
end

function Main.Current()
	return current
end

function Main.Refresh()
	if frame and frame:IsShown() and current then
		local def = tabByKey[current]
		if def.page then def.refresh(def.page) end
		dirty[current] = nil
		Main.RefreshNav()
		UI.RefreshTip()
	end
end

function Main.RefreshNav()
	if not frame then return end
	local badges = ns.Guide.Badges()
	for _, b in ipairs(frame.nav) do
		local on = b.key == current
		local over = UI.ArtUI(on and "ui_tab_on" or "ui_tab")
		if over and b.bg.art ~= over then b.bg:SetArt(over) end
		if on then
			b.bg:SetColor(1.0, 0.86, 0.45, 1)
			b.label:SetTextColor(1, 0.86, 0.35)
			b.glow:Show()
			b.icon:SetPoint("TOP", b, "TOP", 0, -3)
		else
			local k = b.hover and 0.75 or 0.55
			b.bg:SetColor(k, k * 1.05, k * 1.25, 1)
			b.label:SetTextColor(0.78, 0.82, 0.92)
			b.glow:Hide()
			b.icon:SetPoint("TOP", b, "TOP", 0, -6)
		end
		b.badge:Set(badges[b.key])
	end
end

------------------------------------------------------------------------
-- Modal layer (used for hero creation and confirmations)
------------------------------------------------------------------------
-- Creates (once) a content frame for the modal box; show it with ShowModal.
function Main.ModalContent(w, h)
	local box = frame.modal.box
	local c = CreateFrame("Frame", nil, box)
	c:SetSize(w, h)
	c:SetPoint("CENTER", box, "CENTER", 0, 0)
	c:Hide()
	box.contents[#box.contents + 1] = c
	return c
end

function Main.ShowModal(content, onClose)
	local m = frame.modal
	for _, c in ipairs(m.box.contents) do c:Hide() end
	m.box:SetSize(content:GetWidth() + 32, content:GetHeight() + 32)
	content:Show()
	m.onClose = onClose
	m:Show()
end

function Main.CloseModal()
	if frame and frame.modal then
		frame.modal:Hide()
		if frame.modal.onClose then
			local f = frame.modal.onClose
			frame.modal.onClose = nil
			f()
		end
	end
end

local refreshT = 0
local function onUpdate(_, elapsed)
	refreshT = refreshT - elapsed
	if refreshT > 0 then return end
	refreshT = 0.2
	if current and dirty[current] then Main.Refresh() end
	local def = current and tabByKey[current]
	if def and def.tick and def.page then def.tick(def.page) end
	frame.gold:SetLabel(U.fmt(ns.db.gold))
	Main.RefreshNav()
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
	UI.Slice(frame, "shadow", "BACKGROUND", nil, 14)
	UI.Slice(frame, "panel", "BACKGROUND")
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
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	end
	frame:SetScale(ns.db.ui.scale or 1)

	-- header
	local head = UI.Art(frame, "grad_v", "BORDER", 0.30, 0.42, 0.75, 0.35)
	head:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
	head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
	head:SetHeight(46)
	if UI.ArtUI("ui_header") then
		-- a painted title strip instead of the plain gradient
		local strip = CreateFrame("Frame", nil, frame)
		strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
		strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
		strip:SetHeight(50)
		UI.Slice(strip, "card", "BACKGROUND"):SetArt(UI.ArtUI("ui_header"))
		head:Hide()
	end
	frame.titleIcon = frame:CreateTexture(nil, "ARTWORK")
	frame.titleIcon:SetSize(28, 28)
	frame.titleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
	frame.title = UI.Title(frame, "", 18)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -11)
	frame.sub = UI.Text(frame, 11)
	frame.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -32)
	UI.Color(frame.sub, UI.C.sub)
	local brand = UI.Text(frame, 10, "Big Idle W.O.W Heroes")
	brand:SetPoint("TOP", frame, "TOP", 0, -8)
	UI.Color(brand, UI.C.dim)

	frame.gold = UI.Pill(frame, 160, 30, 0.02, 0.03, 0.07, 0.85)
	frame.gold:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -100, -11)
	frame.gold.text:ClearAllPoints()
	frame.gold.text:SetPoint("RIGHT", frame.gold, "RIGHT", -12, 0)
	frame.gold.text:SetJustifyH("RIGHT")
	frame.gold.text:SetFont(ns.FONT, 14, "")
	UI.Color(frame.gold.text, UI.C.gold)
	local coin = frame.gold:CreateTexture(nil, "OVERLAY")
	coin:SetSize(20, 20)
	coin:SetPoint("LEFT", frame.gold, "LEFT", 5, 0)
	UI.SetArtOrIcon(coin, "icon_gold", "INV_Misc_Coin_01")
	UI.Tip(frame.gold, function() return UI.SimpleTip("골드", "몬스터를 잡고 지역을 공략하면 얻습니다. 영웅 만들기, 룬, 용광로에 씁니다.") end)

	frame.close = UI.Button(frame, 36, 32, "", function() Main.Toggle(false) end, "red")
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
	local x = UI.Glyph(frame.close, "close", 16)
	x:SetPoint("CENTER", frame.close, "CENTER", 0, 0)
	UI.Tip(frame.close, function() return UI.SimpleTip("닫기", "Esc 키로도 닫힙니다. 전투는 계속됩니다.") end)

	frame.gear = UI.Button(frame, 36, 32, "", function()
		if current == "options" then
			Main.ShowTab(Main.lastNav or "party")
		else
			Main.ShowTab("options")
		end
	end, "dark")
	frame.gear:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
	frame.gear.icon = frame.gear:CreateTexture(nil, "ARTWORK")
	frame.gear.icon:SetSize(20, 20)
	frame.gear.icon:SetPoint("CENTER", frame.gear, "CENTER", 0, 0)
	UI.SetArtOrIcon(frame.gear.icon, "icon_settings", "Trade_Engineering")
	UI.Tip(frame.gear, function() return UI.SimpleTip("설정", "화면 크기, 진영, 통계, 도움말, 초기화") end)

	-- bottom navigation
	local navBg = UI.Art(frame, "grad_v", "BORDER", 0, 0, 0, 0.45)
	navBg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 3)
	navBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
	navBg:SetHeight(NAV_H)
	navBg:SetTexCoord(0, 1, 1, 0) -- dark at the bottom
	frame.nav = {}
	local navTabs = {}
	for _, def in ipairs(tabs) do
		if def.nav ~= false then navTabs[#navTabs + 1] = def end
	end
	local n = #navTabs
	local bw = math.floor((Main.W - 32 - (n - 1) * 6) / n)
	for i, def in ipairs(navTabs) do
		local b = CreateFrame("Button", nil, frame)
		b:SetSize(bw, NAV_H - 14)
		b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16 + (i - 1) * (bw + 6), 8)
		b.key = def.key
		b.glow = UI.Art(b, "glow", "BACKGROUND", 1, 0.75, 0.25, 0.35)
		b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 10)
		b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -6)
		b.bg = UI.Slice(b, "card", "BACKGROUND")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(28, 28)
		b.icon:SetPoint("TOP", b, "TOP", 0, -6)
		UI.SetArtOrIcon(b.icon, def.art, def.icon)
		b.label = UI.Text(b, 13, ns.N(def.title))
		b.label:SetPoint("BOTTOM", b, "BOTTOM", 0, 6)
		b.label:SetJustifyH("CENTER")
		b.badge = UI.Badge(b, 16)
		b.badge:ClearAllPoints()
		b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, 6)
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			Main.ShowTab(self.key)
		end)
		b.onEnter = function(self) self.hover = true Main.RefreshNav() end
		b.onLeave = function(self) self.hover = false Main.RefreshNav() end
		b:SetScript("OnEnter", function(self) self.onEnter(self) end)
		b:SetScript("OnLeave", function(self) self.onLeave(self) end)
		frame.nav[i] = b
	end

	-- modal layer over the page area
	local modal = CreateFrame("Frame", nil, frame)
	modal:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
	modal:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
	modal:SetFrameLevel(frame:GetFrameLevel() + 40)
	modal:EnableMouse(true)
	local dim = modal:CreateTexture(nil, "BACKGROUND")
	dim:SetAllPoints(modal)
	UI.Fill(dim, 0, 0, 0, 0.65)
	modal.box = UI.Panel(modal, 600, 400, "panel", true)
	modal.box:SetPoint("CENTER", modal, "CENTER", 0, 10)
	modal.box.contents = {}
	modal:Hide()
	frame.modal = modal

	frame:SetScript("OnUpdate", onUpdate)
	frame:SetScript("OnShow", function()
		if current then Main.ShowTab(current) end
	end)
	frame:SetScript("OnHide", function()
		UI.HideTip()
		Main.CloseModal()
	end)
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

function Main.Frame()
	return frame
end

-- The built frame of a screen (nil until it was first shown).
function Main.Page(key)
	return tabByKey[key] and tabByKey[key].page
end
