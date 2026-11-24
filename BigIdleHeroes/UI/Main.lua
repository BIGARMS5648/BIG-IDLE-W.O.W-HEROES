-- Main window: a title bar (the game's name and faction, where the party
-- fights and its power, gold and materials, settings, close); the screen;
-- and a bottom bar of the screens with red dots. Settings is reached from
-- the title bar's gear button.
local _, ns = ...

local UI, U = ns.UI, ns.U

local Main = {}
ns.Main = Main

Main.W, Main.H = 940, 690
Main.PAGE_X, Main.PAGE_Y = 10, -64
Main.PAGE_W, Main.PAGE_H = 920, 550
local NAV_H = 66
-- old screen names that now live elsewhere
local ALIAS = { bag = "equip" }
-- the materials shown in the title bar, by group (Data/Items.lua kinds)
local CURRENCY = {
	{ key = "craft", kinds = { bar = true, leather = true, cloth = true }, name = "제작 재료", icon = "INV_Ingot_05", tab = "mat_craft" },
	{ key = "gem", kinds = { gem = true }, name = "보석 세공 재료", icon = "INV_Misc_Gem_Ruby_02", tab = "mat_gem" },
	{ key = "dust", kinds = { dust = true }, name = "마법부여 재료", icon = "INV_Enchant_DustSoul", tab = "mat_ench" },
	{ key = "scroll", kinds = { scroll = true }, name = "룬 각인 재료", icon = "INV_Scroll_03", tab = "mat_insc" },
	{ key = "seal", kinds = { seal = true }, name = "행운의 인장 재료", icon = "INV_Misc_Coin_03", tab = "mat_seal" },
}

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
	key = ALIAS[key] or key
	local def = tabByKey[key]
	if not def or not frame then return end
	-- a screen can hand a request on to another (the equipment screen sends
	-- forge functions to the forge screen)
	local to = def.redirect and def.redirect(opts)
	if to and to ~= key and tabByKey[to] then return Main.ShowTab(to, opts) end
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

-- The title bar: where the party is, its power, gold and the materials.
function Main.RefreshHeader()
	if not frame then return end
	local db = ns.db
	local fid = ns.Faction() or "ALLIANCE"
	local f = ns.FACTIONS[fid]
	frame.faction:SetText(U.col(f.hex, ns.N(f.name)))
	local st = db.stage
	local d = ns.DIFFS[st.diff]
	local power = 0
	for i = 1, ns.PARTY_SIZE do
		local id = db.party[i]
		if id and db.heroes[id] then power = power + ns.Heroes.PowerScore(id) end
	end
	frame.where:SetText(U.col(d.hex, ns.N(d.name)) .. " " .. ns.StageLabel(st.diff, st.idx)
		.. "     파티 전투력 " .. U.col("ffd24a", U.fmt(power)))
	frame.gold:SetLabel(U.fmt(db.gold))
	for _, c in ipairs(frame.currency) do
		local n = 0
		for _, id in ipairs(ns.MAT_ORDER) do
			if c.def.kinds[ns.MATS[id].kind] then n = n + ns.MatCount(id) end
		end
		c:SetLabel(U.fmt(n))
	end
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
			b.mark:Show()
			b.icon:SetPoint("TOP", b, "TOP", 0, -5)
		else
			local k = b.hover and 0.75 or 0.55
			b.bg:SetColor(k, k * 1.05, k * 1.25, 1)
			b.label:SetTextColor(0.78, 0.82, 0.92)
			b.glow:Hide()
			b.mark:Hide()
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

local LOGO_H = 50
local LOGO_W = math.floor(LOGO_H * 1.517 + 0.5)

local refreshT = 0
local function onUpdate(_, elapsed)
	refreshT = refreshT - elapsed
	if refreshT > 0 then return end
	refreshT = 0.2
	if current and dirty[current] then Main.Refresh() end
	local def = current and tabByKey[current]
	if def and def.tick and def.page then def.tick(def.page) end
	Main.RefreshHeader()
	Main.RefreshNav()
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
function Main.Create()
	if frame then return frame end
	frame = CreateFrame("Frame", "BigIdleHeroesMain", UIParent)
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

	-- title bar: the game's logo, name and faction; where the party fights and its
	-- power; gold and materials; settings; close
	local head = CreateFrame("Frame", nil, frame)
	head:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
	head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
	head:SetHeight(56)
	-- (the shading belongs to the window itself, under the title and logo:
	-- on the header frame it would be drawn over them and dim them)
	local hbg = UI.Art(frame, "grad_v", "BORDER", 0.10, 0.13, 0.22, 0.9)
	hbg:SetAllPoints(head)
	if UI.ArtUI("ui_header") then UI.Slice(head, "card", "BACKGROUND"):SetArt(UI.ArtUI("ui_header")) end
	local line = UI.Line(frame, Main.W - 24, 0.55, 0.60, 0.75, 0.35)
	line:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -59)
	-- the logo (Media/logo.tga: the sign in the middle of a square picture)
	frame.logo = frame:CreateTexture(nil, "ARTWORK")
	frame.logo:SetSize(LOGO_W, LOGO_H)
	frame.logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -5)
	frame.logo:SetTexture(UI.Tex("logo"))
	frame.logo:SetTexCoord(0, 1, 0.168, 0.828)
	local textX = 8 + LOGO_W + 8
	frame.brand = UI.Title(frame, "BIG IDLE HEROES", 16)
	frame.brand:SetPoint("TOPLEFT", frame, "TOPLEFT", textX, -12)
	UI.Color(frame.brand, { 0.92, 0.94, 1 })
	frame.faction = UI.Text(frame, 14)
	frame.faction:SetPoint("LEFT", frame.brand, "RIGHT", 8, 0)
	frame.where = UI.Text(frame, 11)
	frame.where:SetPoint("TOPLEFT", frame, "TOPLEFT", textX, -34)
	frame.where:SetWidth(388 - textX)
	frame.where:SetWordWrap(false)
	UI.Color(frame.where, UI.C.sub)

	frame.close = UI.Button(frame, 30, 30, "", function() Main.Toggle(false) end, "dark")
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -14)
	local x = UI.Glyph(frame.close, "close", 14)
	x:SetPoint("CENTER", frame.close, "CENTER", 0, 0)
	UI.Tip(frame.close, function() return UI.SimpleTip("닫기", "Esc 키로도 닫힙니다. 전투는 계속됩니다.") end)
	frame.gear = UI.Button(frame, 34, 30, "", function()
		if current == "options" then
			Main.ShowTab(Main.lastNav or "hero")
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

	-- gold and the materials, right to left
	local function pill(w, icon, art)
		local p = UI.Pill(frame, w, 28, 0.02, 0.03, 0.07, 0.85)
		p.text:ClearAllPoints()
		p.text:SetPoint("RIGHT", p, "RIGHT", -10, 0)
		p.text:SetJustifyH("RIGHT")
		p.text:SetFont(ns.FONT, 13, "")
		p.coin = p:CreateTexture(nil, "OVERLAY")
		p.coin:SetSize(18, 18)
		p.coin:SetPoint("LEFT", p, "LEFT", 6, 0)
		UI.SetArtOrIcon(p.coin, art, icon)
		return p
	end
	frame.currency = {}
	local right = frame.gear
	for i = #CURRENCY, 1, -1 do
		local c = CURRENCY[i]
		local p = pill(76, c.icon)
		p.def = c
		p:SetPoint("RIGHT", right, "LEFT", -6, 0)
		UI.Color(p.text, { 0.92, 0.94, 1 })
		p:EnableMouse(true)
		p:SetScript("OnMouseUp", function() Main.ShowTab("forge", { sub = "mats", tab = c.tab }) end)
		UI.Tip(p, function()
			local lines = { { c.name, nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
			for _, id in ipairs(ns.MAT_ORDER) do
				local m = ns.MATS[id]
				if c.kinds[m.kind] and ns.MatCount(id) > 0 then
					lines[#lines + 1] = { U.col(ns.QUALITY[m.q].hex, ns.N(m.name)), U.fmt(ns.MatCount(id)), 1, 1, 1 }
				end
			end
			if #lines == 1 then lines[2] = { "아직 없습니다. 상자에서 얻습니다.", nil, 0.7, 0.7, 0.7 } end
			lines[#lines + 1] = { "클릭: 장비 > 재료에서 보기", nil, 0.45, 0.8, 1 }
			return lines
		end)
		frame.currency[i] = p
		right = p
	end
	frame.gold = pill(100, "INV_Misc_Coin_01", "icon_gold")
	frame.gold:SetPoint("RIGHT", right, "LEFT", -6, 0)
	UI.Color(frame.gold.text, UI.C.gold)
	UI.Tip(frame.gold, function() return UI.SimpleTip("골드", "몬스터를 잡고 지역을 공략하면 얻습니다. 영웅 모집하기, 룬, 장비 제작·강화와 기능 해금에 씁니다.") end)

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
		b:SetSize(bw, NAV_H - 12)
		b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16 + (i - 1) * (bw + 6), 8)
		b.mark = b:CreateTexture(nil, "OVERLAY")
		b.mark:SetSize(26, 4)
		b.mark:SetPoint("BOTTOM", b, "TOP", 0, -2)
		UI.Fill(b.mark, 1, 0.80, 0.30, 1)
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
		UISpecialFrames[#UISpecialFrames + 1] = "BigIdleHeroesMain" -- close with Escape
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
			key = ALIAS[key] or key
			if not tabByKey[key] then key = tabs[1].key end
			if ns.Heroes.Count() == 0 then key = "hero" end
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
