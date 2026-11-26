-- Layout kit: the sizes every menu screen shares (UI.K), section headings,
-- rows, hero strips, tabs and the confirmation window.
--
-- Colours mean the same on every screen:
--   blue  = the main action for what is chosen (always bottom right of the card;
--           the logo's blue)
--   steel = an action for the whole screen (bottom of the list)
--   dark  = a secondary action      red = something you lose (break down,
--   reset); those ask first in a confirmation window (UI.Confirm)
-- What is selected always has a blue frame (the logo's). Text is never smaller than 10.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI = ns.UI

local K = {}
UI.K = K
K.W, K.H = 920, 550           -- the page (Main.PAGE_W/H)
K.TAB_H = 30                  -- tab row
K.PAD = 12                    -- inner margin of a panel
K.EQUIP_BODY_W = 546          -- the equipment screen's right side (bag, forge tabs)
K.BTN_H = 34                  -- dialog buttons
K.SEL = { 0.42, 0.70, 1.00 }  -- selection blue (the logo's)
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
		-- the title gives way to the note (and the note to the header's buttons)
		local avail = w - (self.toolW or 0)
		local nw = (note and note ~= "") and min(avail - 80, self.note:GetStringWidth() + 4) or 0
		self.note:SetWidth(max(1, nw))
		self.title:SetWidth(max(40, avail - nw - 8))
	end
	-- a small button (or a row of chips) at the right end of the header, for
	-- what acts on the things under this header; added right to left
	function f:AddTool(b)
		self.tools = self.tools or {}
		local x = 0
		for _, o in ipairs(self.tools) do x = x + o:GetWidth() + 6 end
		b:ClearAllPoints()
		b:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -x, 3)
		self.tools[#self.tools + 1] = b
		self.toolW = x + b:GetWidth() + 10
		self.note:ClearAllPoints()
		self.note:SetPoint("TOPRIGHT", self, "TOPRIGHT", -self.toolW, -3)
		return b
	end
	return f
end

-- A label on the left and a value on the right. Height 22.
function UI.StatRow(parent, w, icon, art, split)
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
	local lw = floor(w * (split or 0.5)) -- the label's share of the row
	f.l = UI.Text(f, K.F_SMALL)
	f.l:SetPoint("LEFT", f, "LEFT", x, 0)
	f.l:SetWidth(lw - x)
	f.l:SetWordWrap(false)
	UI.Color(f.l, UI.C.sub)
	f.v = UI.Text(f, K.F_BODY)
	f.v:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.v:SetWidth(w - lw)
	f.v:SetJustifyH("RIGHT")
	f.v:SetWordWrap(false)
	f.line = UI.Line(f, w, 0.45, 0.50, 0.66, 0.18)
	f.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	function f:Set(label, value)
		self.l:SetText(label or "")
		self.v:SetText(value or "")
		self.l:SetWidth((value == nil or value == "") and (w - x) or (lw - x))
	end
	return f
end

-- A socket on an item: a dark round hole with a ring in the colour of its
-- kind (보석 sky blue, 마법부여 purple, 주문각인 gold) and, when filled, the
-- icon of the material set in it.
UI.SOCKET_RGB = { gem = { 0.40, 0.85, 1.00 }, ench = { 0.80, 0.52, 1.00 }, insc = { 1.00, 0.80, 0.32 } }
function UI.Socket(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.hole = UI.Art(f, "circle", "BACKGROUND", 0.03, 0.04, 0.07)
	f.hole:SetAllPoints(f)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.icon:SetSize(floor(size * 0.64), floor(size * 0.64))
	f.ring = UI.Art(f, "ring", "OVERLAY", 1, 1, 1)
	f.ring:SetAllPoints(f)
	-- kind: "gem" | "ench" | "insc"; icon: the material's icon, nil = empty
	function f:Set(kind, icon)
		local c = UI.SOCKET_RGB[kind] or { 0.7, 0.7, 0.7 }
		self.ring:SetVertexColor(c[1], c[2], c[3], 1)
		if icon then
			UI.SetIcon(self.icon, icon)
			self.icon:Show()
		else
			self.icon:Hide()
		end
	end
	return f
end

-- Sockets drawn in front of a line of text (item text: line.sockets is a
-- list of { kind, icon }). pool: the line's sockets, made as needed.
-- Returns how far the text moves right.
function UI.PlaceSockets(pool, parent, list, size, x, y)
	local n = list and #list or 0
	for i = 1, max(n, #pool) do
		local s = list and list[i]
		if s then
			pool[i] = pool[i] or UI.Socket(parent, size)
			pool[i]:ClearAllPoints()
			pool[i]:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * (size + 3), y)
			pool[i]:Set(s[1], s[2])
			pool[i]:Show()
		elseif pool[i] then
			pool[i]:Hide()
		end
	end
	return n > 0 and (n * (size + 3) + 3) or 0
end

-- Blue frame around whatever is selected.
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
	b.badge = UI.Badge(b, 14)
	b.badge:ClearAllPoints()
	b.badge:SetPoint("TOPRIGHT", b.icon, "TOPRIGHT", 3, 3)
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
		if self.selected then self.bg:SetColor(0.78, 0.88, 1, 1) else self.bg:SetColor(1, 1, 1, 1) end
	end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		ns.Sound("click")
		if onClick then onClick(self, button) end
	end)
	return b
end

-- A row of hero portraits (party first). onPick(heroId); badge(heroId):
-- whether that hero gets a red dot here (each screen says what it is about).
-- cols: portraits per row (all in one row when nil). The chosen hero wears a
-- thick gold ring.
function UI.HeroStrip(parent, count, size, gap, onPick, badge, cols)
	cols = cols or count
	local rows = math.ceil(count / cols)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(cols * (size + gap) - gap, rows * (size + gap) - gap + 4)
	f.items = {}
	for i = 1, count do
		local b = UI.Portrait(f, size, function(self)
			if self.heroId and onPick then onPick(self.heroId) end
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", ((i - 1) % cols) * (size + gap), -2 - floor((i - 1) / cols) * (size + gap))
		b.lvl:Hide()
		b.badge:ClearAllPoints()
		b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, 1) -- inside: the next portrait is close
		b.selRing = UI.Art(b, "ring", "OVERLAY", UI.C.gold[1], UI.C.gold[2], UI.C.gold[3])
		b.selRing:SetDrawLayer("OVERLAY", 2)
		b.selRing:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
		b.selRing:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
		b.selRing:Hide()
		UI.Tip(b, function(self)
			local id = self.heroId
			local h = id and ns.db.heroes[id]
			if not h then return nil end
			local lines = { { ns.Heroes.Name(id), "Lv " .. h.level, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
				{ ns.SpecLabel(h.spec), ns.Heroes.PartySlot(id) and "출전 중" or "대기", 0.75, 0.8, 0.9 } }
			if badge and badge(id) then lines[#lines + 1] = { "가방에 더 좋은 장비가 있습니다", nil, 0.4, 1, 0.4 } end
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
				b.selRing:SetShown(id == sel)
				b:SetDim(ns.Heroes.PartySlot(id) == nil)
				b:SetBadge(badge and badge(id) and true or false)
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

------------------------------------------------------------------------
-- Tabs: equal-width segments in one row
------------------------------------------------------------------------
-- items: { { key, label }, ... }; onSelect(key); h: the row's height (the
-- fifth argument is not used)
function UI.Tabs(parent, w, items, onSelect, _, h)
	h = h or K.TAB_H
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(w, h)
	row.buttons = {}
	local n = #items
	local gap = 4
	-- equal widths that fill the row (up to 110 each)
	local bw = min(110, (w - (n - 1) * gap) / n)
	for i, it in ipairs(items) do
		local b = UI.Chip(row, bw, h, it[2], function(self)
			if onSelect then onSelect(self.key) end
		end)
		b:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (bw + gap), 0)
		b.key = it[1]
		b.isItem = true -- navigation, not an action
		-- a locked tab: a lock on the middle of its top edge
		b.lock = CreateFrame("Frame", nil, b)
		b.lock:SetSize(16, 16)
		b.lock.isBadge = true -- sits on its owner's edge on purpose
		b.lock:SetFrameLevel(b:GetFrameLevel() + 6)
		b.lock:SetPoint("CENTER", b, "TOP", 0, 0)
		b.lock.glyph = UI.Glyph(b.lock, "lock", 14, 0.95, 0.82, 0.5)
		b.lock.glyph:SetPoint("CENTER", b.lock, "CENTER", 0, 0)
		b.lock:Hide()
		row.buttons[i] = b
	end
	-- every tab the same width, its name in the middle; when a name is too
	-- long for its tab, the whole row's names get a little smaller
	local base = h >= 24 and 12 or 11
	function row:Fit()
		for size = base, base - 2, -1 do
			local fits = true
			for _, b in ipairs(self.buttons) do
				b.label:SetFont(ns.FONT, size, "")
				if b.label:GetStringWidth() > bw - 10 then fits = false end
			end
			if fits then break end
		end
	end
	row:Fit()
	function row:Select(key)
		for _, b in ipairs(self.buttons) do b:SetOn(b.key == key) end
	end
	function row:Get(key)
		for _, b in ipairs(self.buttons) do if b.key == key then return b end end
	end
	function row:SetLabel(key, text) local b = self:Get(key) if b then b:SetLabel(text) self:Fit() end end
	function row:SetBadge(key, v)
		local b = self:Get(key)
		if not b then return end
		b:SetBadge(v)
		-- on the tab's top edge, inside its right corner: tabs stand close
		-- together, so the dot never reaches the next one or its name
		if b.badge and not b.badge.onTab then
			b.badge.onTab = true
			b.badge:ClearAllPoints()
			b.badge:SetPoint("CENTER", b, "TOPRIGHT", -8, 1)
		end
	end
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
-- Confirmation window for anything that cannot be undone:
--   UI.Confirm({ title = "분해", text = "정말 분해하시겠습니까?", ok = "분해",
--                style = "red", onOk = function() ... end })
------------------------------------------------------------------------
local confirm = {}

local function buildConfirm()
	local c = ns.Main.ModalContent(400, 170)
	confirm.frame = c
	confirm.title = UI.Title(c, "", 16)
	confirm.title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	confirm.title:SetWidth(400)
	confirm.title:SetWordWrap(false)
	confirm.text = UI.Text(c, K.F_BODY)
	confirm.text:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -30)
	confirm.text:SetWidth(400)
	confirm.text:SetJustifyV("TOP")
	confirm.text:SetSpacing(3)
	confirm.no = UI.Button(c, 175, K.BTN_H, "취소", function() ns.Main.CloseModal() end, "dark")
	confirm.no:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	confirm.yes = UI.Button(c, 175, K.BTN_H, "", nil, "red")
	confirm.yes:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	confirm.yes.onClick = function()
		local fn = confirm.onOk
		confirm.onOk = nil
		ns.Main.CloseModal()
		if fn then fn() end
		ns.Main.Refresh()
	end
end

-- (for tests) the confirmation window's buttons
function UI.ConfirmButtons() return confirm.yes, confirm.no end

function UI.Confirm(o)
	if not confirm.frame then buildConfirm() end
	confirm.title:SetText(o.title or "확인")
	confirm.text:SetText(o.text or "")
	confirm.yes:SetLabel(o.ok or "확인")
	confirm.yes:SetStyle(o.style or "red")
	confirm.onOk = o.onOk
	ns.Main.ShowModal(confirm.frame)
end

------------------------------------------------------------------------
-- A button that opens a list to choose from (instead of a button that
-- changes its value on every click).
--   items() -> { { value, label }, ... }; get() -> value; set(value)
------------------------------------------------------------------------
local list

local function closeList()
	if list then
		list.catcher:Hide()
		list.owner = nil
	end
end
UI.CloseList = closeList

local function ensureList()
	if list then return list end
	local host = ns.Main.Frame()
	list = {}
	-- clicking anywhere else closes the list
	local catcher = CreateFrame("Button", nil, host)
	catcher:SetAllPoints(host)
	catcher:SetFrameLevel(host:GetFrameLevel() + 70)
	catcher.isPopup = true
	catcher.isCatcher = true
	catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	catcher:SetScript("OnClick", closeList)
	catcher:Hide()
	list.catcher = catcher
	local box = UI.Panel(catcher, 180, 40, "card", true)
	box:SetFrameLevel(catcher:GetFrameLevel() + 2)
	box.isPopup = true
	list.box = box
	list.rows = {}
	return list
end

local function openList(b)
	local l = ensureList()
	if l.owner == b and l.catcher:IsShown() then closeList() return end
	local items = b.items()
	local w = max(b:GetWidth(), 170)
	local rowH = 26
	for i, it in ipairs(items) do
		local r = l.rows[i]
		if not r then
			r = CreateFrame("Button", nil, l.box)
			r:SetHeight(rowH)
			r.isItem = true
			r.hl = r:CreateTexture(nil, "BACKGROUND")
			r.hl:SetAllPoints(r)
			UI.Fill(r.hl, 0.35, 0.62, 1, 0.18)
			r.mark = UI.Glyph(r, "check", 14, K.SEL[1], K.SEL[2], K.SEL[3])
			r.mark:SetPoint("LEFT", r, "LEFT", 6, 0)
			r.label = UI.Text(r, K.F_BODY)
			r.label:SetPoint("LEFT", r, "LEFT", 26, 0)
			r.label:SetWordWrap(false)
			r:RegisterForClicks("LeftButtonUp")
			r:SetScript("OnClick", function(self)
				ns.Sound("click")
				local owner = l.owner
				closeList()
				if owner then owner.set(self.value) owner:Refresh() end
				ns.Main.Refresh()
			end)
			r:SetScript("OnEnter", function(self) self.hl:Show() end)
			r:SetScript("OnLeave", function(self) if not self.current then self.hl:Hide() end end)
			l.rows[i] = r
		end
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", l.box, "TOPLEFT", 6, -6 - (i - 1) * rowH)
		r:SetWidth(w - 12)
		r.label:SetWidth(w - 40)
		r.value = it[1]
		r.label:SetText(it[2])
		r.current = it[1] == b.get()
		r.mark:SetShown(r.current)
		r.hl:SetShown(r.current)
		r:Show()
	end
	for i = #items + 1, #l.rows do l.rows[i]:Hide() end
	local boxH = #items * rowH + 12
	l.box:SetSize(w, boxH)
	l.box:ClearAllPoints()
	-- open upward when there is no room below (a button in a footer)
	local up = b.openUp
	if not up then
		local bb, hb = b:GetBottom(), ns.Main.Frame():GetBottom()
		up = bb and hb and (bb - boxH - 2 < hb) or false
	end
	if up then
		l.box:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 2)
	else
		l.box:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
	end
	l.owner = b
	l.catcher:Show()
end

function UI.Dropdown(parent, w, h, items, get, set, prefix)
	local b = UI.Chip(parent, w, h, "", function(self) openList(self) end)
	b.items, b.get, b.set, b.prefix = items, get, set, prefix or ""
	b.caret = b:CreateTexture(nil, "OVERLAY")
	if UI.SetArrow(b.caret, "down", 0.85, 0.88, 0.95) then
		b.caret:SetSize(11, 6)
	else
		UI.SetGlyph(b.caret, "arrow", 0.85, 0.88, 0.95)
		b.caret:SetSize(12, 12)
		b.caret:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0) -- the arrow turned to point down
	end
	b.caret:SetPoint("RIGHT", b, "RIGHT", -10, 0)
	b.label:ClearAllPoints()
	b.label:SetPoint("CENTER", b, "CENTER", -8, 0)
	function b:Refresh()
		local cur = self.get()
		for _, it in ipairs(self.items()) do
			if it[1] == cur then self:SetLabel(self.prefix .. it[2]) end
		end
	end
	UI.Tip(b, function() return UI.SimpleTip(b.tipTitle or "고르기", b.tipText or "눌러서 목록에서 고르세요.") end, "TOP")
	return b
end
