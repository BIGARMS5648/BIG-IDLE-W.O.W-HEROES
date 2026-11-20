-- Screen kit. Every menu screen is built from the same parts, placed the same
-- way, so a player who learns one screen knows them all:
--
--   [ tabs: sub-pages or filters          ]  [ tools for the screen   ]
--   +---------------------------------------+ +-----------------------+
--   | LIST: what you choose from            | | CARD: what you chose  |
--   |  (heroes, items, stages, runes ...)   | |  icon  name           |
--   |                                       | |        kind · level   |
--   |                                       | |  ------------------   |
--   |                                       | |  details              |
--   |                                       | |                       |
--   | [blue: actions for the whole screen]  | |  [other]   [ GOLD ]   |
--   +---------------------------------------+ +-----------------------+
--
-- Colours mean the same on every screen:
--   gold  = the main action for what is chosen (always bottom right of the card)
--   blue  = an action for the whole screen (bottom of the list)
--   dark  = a secondary action      red = something you lose (break down, reset)
-- What is selected always has a gold frame. Text is never smaller than 10.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U

local K = {}
UI.K = K
K.W, K.H = 848, 468           -- the page (Main.PAGE_W/H)
K.TAB_H = 30                  -- tab row
K.TOP = 38                    -- list and card start below the tabs
K.CARD_W = 300                -- the card on the right
K.LIST_W = K.W - K.CARD_W - 12 -- 536
K.BODY_H = K.H - K.TOP        -- 430
K.PAD = 12                    -- inner margin of list and card
K.BTN_H = 34                  -- footer buttons
K.SMALL_H = 26                -- small buttons
K.FOOT = K.PAD + K.BTN_H + 8  -- footer zone height (54)
K.LIST_IN = K.LIST_W - 2 * K.PAD   -- 512: usable list width
K.CARD_IN = K.CARD_W - 2 * K.PAD   -- 276: usable card width
K.SEL = { 1.00, 0.82, 0.30 }  -- selection gold
-- font sizes
K.F_TITLE, K.F_HEAD, K.F_BODY, K.F_SMALL, K.F_MIN = 15, 12, 12, 11, 10

------------------------------------------------------------------------
-- Small building blocks
------------------------------------------------------------------------
-- Section heading inside the list or the card: gold title, optional
-- right-aligned note, a thin line underneath. Height 20.
function UI.Section(parent, w, text)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, 20)
	f.title = UI.Text(f, K.F_HEAD, text)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
	f.title:SetWordWrap(false)
	UI.Color(f.title, UI.C.gold)
	f.note = UI.Text(f, K.F_SMALL)
	f.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -3)
	f.note:SetJustifyH("RIGHT")
	f.note:SetWordWrap(false)
	UI.Color(f.note, UI.C.sub)
	f.line = UI.Line(f, w, 0.45, 0.50, 0.66, 0.35)
	f.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	function f:Set(t, note)
		self.title:SetText(t or "")
		self.note:SetText(note or "")
		-- the title gives way to the note
		local nw = (note and note ~= "") and min(w - 80, self.note:GetStringWidth() + 4) or 0
		self.note:SetWidth(max(1, nw))
		self.title:SetWidth(max(40, w - nw - 8))
	end
	return f
end

-- A label on the left and a value on the right. Height 22.
function UI.StatRow(parent, w, icon, art)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, 22)
	local x = 0
	if icon then
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetSize(16, 16)
		f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
		UI.SetArtOrIcon(f.icon, art, icon)
		x = 22
	end
	f.l = UI.Text(f, K.F_SMALL)
	f.l:SetPoint("LEFT", f, "LEFT", x, 0)
	f.l:SetWidth(floor(w * 0.5) - x)
	f.l:SetWordWrap(false)
	UI.Color(f.l, UI.C.sub)
	f.v = UI.Text(f, K.F_BODY)
	f.v:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.v:SetWidth(floor(w * 0.5))
	f.v:SetJustifyH("RIGHT")
	f.v:SetWordWrap(false)
	f.line = UI.Line(f, w, 0.45, 0.50, 0.66, 0.18)
	f.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	function f:Set(label, value)
		self.l:SetText(label or "")
		self.v:SetText(value or "")
		self.l:SetWidth((value == nil or value == "") and (w - x) or (floor(w * 0.5) - x))
	end
	return f
end

-- Lines of text under each other that may wrap (item stats and the like).
-- Each line starts below the one before; empty lines take no room. h is the
-- room they have (the layout check reports lines that run past it).
function UI.Lines(parent, w, n, size, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h or 100)
	f.lines = {}
	for i = 1, n do
		local fs = UI.Text(f, size or K.F_SMALL)
		if i == 1 then
			fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		else
			fs:SetPoint("TOPLEFT", f.lines[i - 1], "BOTTOMLEFT", 0, -3)
		end
		fs:SetWidth(w)
		fs:SetJustifyV("TOP")
		f.lines[i] = fs
	end
	-- list: { { text, r, g, b }, ... }
	function f:Set(list)
		for i, fs in ipairs(self.lines) do
			local v = list and list[i]
			if v then
				fs:SetText(v[1] or "")
				fs:SetTextColor(v[2] or 1, v[3] or 1, v[4] or 1)
				fs:Show()
			else
				fs:SetText("")
				fs:Hide()
			end
		end
	end
	return f
end

-- Gold frame around whatever is selected.
function UI.SelFrame(parent, out)
	out = out or 2
	local t = UI.Slice(parent, "frame", "OVERLAY", 11, out)
	t:SetColor(K.SEL[1], K.SEL[2], K.SEL[3], 1)
	if UI.ArtUI("ui_select") then t:SetArt(UI.ArtUI("ui_select")) end
	t:SetShown(false)
	return t
end

-- A row in a list: icon, title, a second line, a value on the right.
-- Clicking selects it (onClick). Height h (default 44).
function UI.Row(parent, w, h, onClick)
	h = h or 44
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.isItem = true -- a thing to pick, not an action
	b.bg = UI.Slice(b, "inset", "BACKGROUND")
	b.sel = UI.SelFrame(b, 1)
	local isz = h - 10
	b.icon = UI.IconButton(b, isz)
	b.icon:EnableMouse(false)
	b.icon:SetPoint("LEFT", b, "LEFT", 5, 0)
	b.title = UI.Text(b, K.F_BODY)
	b.title:SetPoint("TOPLEFT", b, "TOPLEFT", isz + 12, -(h / 2 - 13))
	b.title:SetWordWrap(false)
	b.sub = UI.Text(b, K.F_SMALL)
	b.sub:SetPoint("TOPLEFT", b, "TOPLEFT", isz + 12, -(h / 2 + 1))
	b.sub:SetWordWrap(false)
	UI.Color(b.sub, UI.C.sub)
	b.right = UI.Text(b, K.F_BODY)
	b.right:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	b.right:SetJustifyH("RIGHT")
	b.right:SetWordWrap(false)
	b.badge = UI.Badge(b, 16)
	b.badge:ClearAllPoints()
	b.badge:SetPoint("TOPLEFT", b, "TOPLEFT", isz - 4, -1)
	b.textW = w - isz - 20
	b.rightW = 0
	function b:Layout(rightW)
		self.rightW = rightW or 0
		self.right:SetWidth(max(1, self.rightW))
		local tw = self.textW - (self.rightW > 0 and (self.rightW + 8) or 0)
		self.title:SetWidth(tw)
		self.sub:SetWidth(tw)
	end
	b:Layout(0)
	function b:SetSelected(v)
		self.selected = v and true or false
		self.sel:SetShown(self.selected)
		if self.selected then self.bg:SetColor(1, 0.92, 0.70, 1) else self.bg:SetColor(1, 1, 1, 1) end
	end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		ns.Sound("click")
		if onClick then onClick(self, button) end
	end)
	return b
end

-- A row of hero portraits (party first). onPick(heroId).
function UI.HeroStrip(parent, count, size, gap, onPick)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(count * (size + gap) - gap, size + 4)
	f.items = {}
	for i = 1, count do
		local b = UI.Portrait(f, size, function(self)
			if self.heroId and onPick then onPick(self.heroId) end
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (size + gap), -2)
		b.lvl:Hide()
		UI.Tip(b, function(self)
			local id = self.heroId
			local h = id and ns.db.heroes[id]
			if not h then return nil end
			local lines = { { ns.Heroes.Name(id), "Lv " .. h.level, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
				{ ns.SpecLabel(h.spec), ns.Heroes.PartySlot(id) and "출전 중" or "대기", 0.75, 0.8, 0.9 } }
			if ns.Guide.HeroNeeds(id) then lines[#lines + 1] = { "할 일이 있습니다 (점수나 더 좋은 장비)", nil, 0.4, 1, 0.4 } end
			return lines
		end, "TOP")
		f.items[i] = b
	end
	-- order: hero ids; sel: selected id
	function f:Set(order, sel)
		for i, b in ipairs(self.items) do
			local id = order[i]
			b.heroId = id
			if id and ns.db.heroes[id] then
				b:SetHero(id)
				UI.SetHeroIcon(b.icon, id)
				b.lvl:Hide()
				b:SetSelected(id == sel)
				b:SetDim(ns.Heroes.PartySlot(id) == nil)
				b:SetBadge(ns.Heroes.PartySlot(id) ~= nil and ns.Guide.HeroNeeds(id))
				b:Show()
			else
				b:Hide()
			end
		end
	end
	return f
end

-- Party first, then the bench.
function UI.HeroOrder()
	local out, seen = {}, {}
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id and ns.db.heroes[id] then out[#out + 1] = id seen[id] = true end
	end
	for _, id in ipairs(ns.Heroes.List()) do
		if not seen[id] then out[#out + 1] = id end
	end
	return out
end

-- Two-click confirmation for things that cannot be undone. The button shows
-- armedLabel for a few seconds after the first click.
function UI.Arm(b, armedLabel, action)
	b.armT = 0
	b.armedLabel = armedLabel
	b.armAction = action
	b.onClick = function(self)
		if self.off then return end
		if self.armT > 0 then
			self.armT = 0
			self:SetLabel(self.baseLabel or "")
			self.armAction()
		else
			self.armT = 4
			self:SetLabel(self.armedLabel)
		end
	end
	function b:SetBase(t)
		self.baseLabel = t
		if self.armT == 0 then self:SetLabel(t) end
	end
	function b:Disarm()
		if self.armT > 0 then
			self.armT = max(0, self.armT - 0.2)
			if self.armT == 0 then self:SetLabel(self.baseLabel or "") end
		end
	end
	return b
end

------------------------------------------------------------------------
-- Tabs: equal-width segments in one row
------------------------------------------------------------------------
-- items: { { key, label }, ... }; onSelect(key)
function UI.Tabs(parent, w, items, onSelect)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(w, K.TAB_H)
	row.buttons = {}
	local n = #items
	local gap = 4
	local bw = min(110, floor((w - (n - 1) * gap) / n))
	for i, it in ipairs(items) do
		local b = UI.Chip(row, bw, K.TAB_H, it[2], function(self)
			if onSelect then onSelect(self.key) end
		end)
		b:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (bw + gap), 0)
		b.key = it[1]
		b.isItem = true -- navigation, not an action
		b.lock = UI.Glyph(b, "lock", 12, 0.9, 0.78, 0.5)
		b.lock:SetPoint("RIGHT", b.label, "LEFT", -3, 0)
		b.lock:Hide()
		row.buttons[i] = b
	end
	function row:Select(key)
		for _, b in ipairs(self.buttons) do b:SetOn(b.key == key) end
	end
	function row:Get(key)
		for _, b in ipairs(self.buttons) do if b.key == key then return b end end
	end
	function row:SetLabel(key, text) local b = self:Get(key) if b then b:SetLabel(text) end end
	function row:SetBadge(key, v) local b = self:Get(key) if b then b:SetBadge(v) end end
	function row:SetLocked(key, v)
		local b = self:Get(key)
		if b then
			b.lock:SetShown(v and true or false)
			b.label:SetAlpha(v and 0.6 or 1)
		end
	end
	return row
end

------------------------------------------------------------------------
-- The card on the right: header, content, footer buttons
------------------------------------------------------------------------
function UI.Card(parent, w, h)
	local d = UI.Panel(parent, w, h, "card")
	d.W, d.H = w, h
	d.IN = w - 2 * K.PAD
	-- coloured band behind the header (rarity, class, region ...)
	d.band = d:CreateTexture(nil, "BORDER")
	d.band:SetPoint("TOPLEFT", d, "TOPLEFT", 4, -4)
	d.band:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)
	d.band:SetHeight(68)
	d.band:Hide()
	d.icon = UI.IconButton(d, 48)
	d.icon:SetPoint("TOPLEFT", d, "TOPLEFT", K.PAD, -K.PAD)
	d.portrait = UI.Portrait(d, 48)
	d.portrait:SetPoint("TOPLEFT", d, "TOPLEFT", K.PAD, -K.PAD)
	d.portrait.lvl:Hide()
	d.portrait:EnableMouse(false)
	d.portrait:Hide()
	d.title = UI.Text(d, K.F_TITLE)
	d.title:SetPoint("TOPLEFT", d, "TOPLEFT", K.PAD + 58, -15)
	d.title:SetWidth(w - K.PAD * 2 - 58)
	d.title:SetWordWrap(false)
	d.sub = UI.Text(d, K.F_SMALL)
	d.sub:SetPoint("TOPLEFT", d, "TOPLEFT", K.PAD + 58, -37)
	d.sub:SetWidth(w - K.PAD * 2 - 58)
	d.sub:SetWordWrap(false)
	UI.Color(d.sub, UI.C.sub)
	d.close = UI.Button(d, 24, 24, "", nil, "dark")
	d.close:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -8)
	d.close.x = UI.Glyph(d.close, "close", 12)
	d.close.x:SetPoint("CENTER", d.close, "CENTER", 0, 0)
	d.close:Hide()
	d.div = UI.Line(d, w - 2 * K.PAD, 0.5, 0.55, 0.72, 0.35)
	d.div:SetPoint("TOPLEFT", d, "TOPLEFT", K.PAD, -72)
	-- content: everything between the header and the footer
	d.content = CreateFrame("Frame", nil, d)
	d.content:SetPoint("TOPLEFT", d, "TOPLEFT", K.PAD, -80)
	d.content:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -K.PAD, K.FOOT)
	-- footer: [left] [RIGHT], and above it an optional row of two small buttons
	local half = floor((w - 2 * K.PAD - 8) / 2)
	d.half = half
	d.left = UI.Button(d, half, K.BTN_H, "", nil, "dark")
	d.left:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", K.PAD, K.PAD)
	d.left.clickWhenOff = true
	d.right = UI.Button(d, half, K.BTN_H, "", nil, "primary")
	d.right:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -K.PAD, K.PAD)
	d.right.clickWhenOff = true
	d.wide = UI.Button(d, w - 2 * K.PAD, K.BTN_H, "", nil, "primary")
	d.wide:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", K.PAD, K.PAD)
	d.wide.clickWhenOff = true
	d.x1 = UI.Button(d, half, K.SMALL_H, "", nil, "dark")
	d.x1:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", K.PAD, K.PAD + K.BTN_H + 8)
	d.x1.clickWhenOff = true
	d.x2 = UI.Button(d, half, K.SMALL_H, "", nil, "dark")
	d.x2:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -K.PAD, K.PAD + K.BTN_H + 8)
	d.x2.clickWhenOff = true
	for _, b in ipairs({ d.left, d.right, d.wide, d.x1, d.x2 }) do
		UI.Tip(b, function(self) return self.tipText and UI.SimpleTip(self.tipText[1], self.tipText[2]) or nil end, "TOP")
		b:Hide()
	end
	-- why the main button cannot be used (shown right above the footer)
	d.why = UI.Text(d, K.F_SMALL)
	d.why:SetWidth(w - 2 * K.PAD)
	d.why:SetWordWrap(false)
	d.why:SetTextColor(1, 0.55, 0.45)

	-- opts: { icon, quality, count, hero, title, titleRGB, sub, band = {r,g,b}, close = fn }
	function d:Head(o)
		o = o or {}
		self.whyText = nil
		self.why:SetText("")
		self.icon:Clear()
		self.icon:SetShown(o.hero == nil and (o.icon ~= nil or o.class ~= nil))
		self.portrait:SetShown(o.hero ~= nil)
		if o.hero then
			self.portrait:SetHero(o.hero)
			UI.SetHeroIcon(self.portrait.icon, o.hero)
			self.portrait.lvl:Hide()
		elseif o.class then
			self.icon:SetClass(o.class)
		elseif o.icon then
			if o.art then self.icon:SetArtIcon(o.art, o.icon) else self.icon:SetIconName(o.icon) end
			self.icon:SetQuality(o.quality)
			self.icon:SetCount(o.count)
			self.icon:SetLocked(o.locked)
			self.icon:SetDim(o.dim)
		end
		self.icon.data = o.data
		local hasIcon = o.hero ~= nil or o.icon ~= nil or o.class ~= nil
		local x = K.PAD + (hasIcon and 58 or 0)
		local tw = self.W - x - K.PAD - (o.close and 30 or 0)
		self.title:ClearAllPoints()
		self.title:SetPoint("TOPLEFT", self, "TOPLEFT", x, (o.sub and o.sub ~= "") and -15 or -26)
		self.title:SetWidth(tw)
		self.sub:ClearAllPoints()
		self.sub:SetPoint("TOPLEFT", self, "TOPLEFT", x, -37)
		self.sub:SetWidth(self.W - x - K.PAD)
		self.title:SetText(o.title or "")
		if o.titleRGB then self.title:SetTextColor(o.titleRGB[1], o.titleRGB[2], o.titleRGB[3]) else UI.Color(self.title, UI.C.gold) end
		self.sub:SetText(o.sub or "")
		if o.band then
			local art = UI.ArtPath("ui_band")
			if art then
				self.band:SetTexture(art)
				self.band:SetVertexColor(o.band[1] * 0.8 + 0.2, o.band[2] * 0.8 + 0.2, o.band[3] * 0.8 + 0.2, 1)
			else
				UI.Fill(self.band, o.band[1] * 0.38, o.band[2] * 0.38, o.band[3] * 0.38, 0.9)
			end
			self.band:Show()
		else
			self.band:Hide()
		end
		self.close:SetShown(o.close ~= nil)
		self.close.onClick = o.close
	end

	-- a = { label, onClick, style, off, tip = { title, body } } (or the same as named fields), or nil
	local function setButton(b, a, defaultStyle)
		if not a then b:Hide() return end
		b:SetStyle(a.style or a[3] or defaultStyle)
		b:SetLabel(a[1] or a.label or "")
		b.baseLabel = a[1] or a.label or ""
		b.onClick = a[2] or a.onClick
		b:SetOff((a.off or a[4]) and true or false)
		b.tipText = a.tip
		b:Show()
	end
	-- left = secondary, right = the main action (gold). Only one given: it
	-- fills the footer.
	function d:Actions(left, right)
		if left and right then
			setButton(self.left, left, "dark")
			setButton(self.right, right, "primary")
			self.wide:Hide()
		else
			self.left:Hide()
			self.right:Hide()
			setButton(self.wide, left or right, left and "dark" or "primary")
		end
		self:SetFooter(self.x1:IsShown() or self.x2:IsShown())
	end
	-- the small buttons above the footer
	function d:Extras(a, b)
		setButton(self.x1, a, "dark")
		setButton(self.x2, b, "dark")
		self:SetFooter(a ~= nil or b ~= nil)
	end
	-- text: why the main action is not available (nil hides it)
	function d:Reason(text)
		self.whyText = (text and text ~= "") and text or nil
		self.why:SetText(self.whyText or "")
		self:SetFooter(self.x1:IsShown() or self.x2:IsShown())
	end
	function d:SetFooter(extras)
		local any = self.left:IsShown() or self.right:IsShown() or self.wide:IsShown()
		local bottom = K.PAD + (any and (K.BTN_H + 8) or 0) + (extras and (K.SMALL_H + 8) or 0)
		self.why:ClearAllPoints()
		self.why:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", K.PAD, bottom)
		self.why:SetShown(self.whyText ~= nil)
		if self.whyText then bottom = bottom + 20 end
		self.content:ClearAllPoints()
		self.content:SetPoint("TOPLEFT", self, "TOPLEFT", K.PAD, -80)
		self.content:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -K.PAD, bottom)
		self.contentH = self.H - 80 - bottom
	end
	d:SetFooter(false)
	-- for screens that tick: two-click buttons fall back
	function d:Disarm()
		for _, b in ipairs({ self.left, self.right, self.wide, self.x1, self.x2 }) do
			if b.Disarm then b:Disarm() end
		end
	end
	return d
end

-- Turns a card button into a two-click one; Actions() keeps it armed.
function UI.CardArm(b, armedLabel, action)
	return UI.Arm(b, armedLabel, action)
end

------------------------------------------------------------------------
-- A screen: tabs + tools on top, list on the left, card on the right
------------------------------------------------------------------------
-- opts: { tabs = { {key, label}... }, onTab = fn(key) }
function UI.Screen(page, opts)
	opts = opts or {}
	local S = {}
	if opts.tabs then
		S.tabs = UI.Tabs(page, K.LIST_W, opts.tabs, opts.onTab)
		S.tabs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	else
		S.heading = UI.Text(page, 16)
		S.heading:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -6)
		S.heading:SetWidth(K.LIST_W - 8)
		S.heading:SetWordWrap(false)
		UI.Color(S.heading, UI.C.gold)
	end
	-- tools: right-aligned above the card
	S.tools = CreateFrame("Frame", nil, page)
	S.tools:SetSize(K.CARD_W, K.TAB_H)
	S.tools:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	S.list = UI.Panel(page, K.LIST_W, K.BODY_H, "inset")
	S.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -K.TOP)
	S.card = UI.Card(page, K.CARD_W, K.BODY_H)
	S.card:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -K.TOP)
	-- list footer: page-wide buttons, left to right
	S.foot = {}
	function S.FootButton(i, w, label, onClick, style)
		local b = UI.Button(S.list, w, K.BTN_H, label, onClick, style or "blue")
		local x = K.PAD
		for j = 1, i - 1 do x = x + S.foot[j]:GetWidth() + 8 end
		b:SetPoint("BOTTOMLEFT", S.list, "BOTTOMLEFT", x, K.PAD)
		b.clickWhenOff = true
		S.foot[i] = b
		return b
	end
	-- a tool button, laid out from the right
	S.toolButtons = {}
	function S.Tool(w, label, onClick, style)
		local b = UI.Button(S.tools, w, K.TAB_H, label, onClick, style or "dark")
		local x = 0
		for _, o in ipairs(S.toolButtons) do x = x + o:GetWidth() + 6 end
		b:SetPoint("TOPRIGHT", S.tools, "TOPRIGHT", -x, 0)
		S.toolButtons[#S.toolButtons + 1] = b
		return b
	end
	-- an empty-state message in the middle of the list
	S.empty = UI.Text(S.list, 13)
	S.empty:SetPoint("CENTER", S.list, "CENTER", 0, 20)
	S.empty:SetWidth(K.LIST_IN - 40)
	S.empty:SetJustifyH("CENTER")
	UI.Color(S.empty, UI.C.sub)
	S.empty:Hide()
	function S.Empty(text)
		S.empty:SetText(text or "")
		S.empty:SetShown(text ~= nil and text ~= "")
	end
	return S
end

------------------------------------------------------------------------
-- Two-click actions for card buttons (they are re-labelled on every
-- refresh, so the armed state lives in a table of the screen).
------------------------------------------------------------------------
-- state: a table kept by the screen; key: which action
function UI.ArmSpec(state, key, label, armedLabel, action, style, off, tip)
	state.arm = state.arm or {}
	local armed = (state.arm[key] or 0) > 0
	return { armed and armedLabel or label, function()
		if (state.arm[key] or 0) > 0 then
			state.arm[key] = 0
			action()
		else
			state.arm[key] = 4
		end
		ns.Main.Refresh()
	end, style or "red", off, tip = tip }
end

-- Call from the screen's tick (5 times a second); true when one ran out.
function UI.ArmTick(state)
	local out = false
	for k, v in pairs(state.arm or {}) do
		if v > 0 then
			state.arm[k] = max(0, v - 0.2)
			if state.arm[k] == 0 then out = true end
		end
	end
	return out
end
