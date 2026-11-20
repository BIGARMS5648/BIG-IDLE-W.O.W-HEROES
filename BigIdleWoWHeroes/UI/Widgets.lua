-- Small widget toolkit. Everything is built from plain frames, color
-- textures and font strings (no Blizzard templates), so the same code runs on
-- every client generation and Korean text always gets a font that can draw it.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local UI = {}
ns.UI = UI

UI.COLOR = {
	bg     = { 0.05, 0.05, 0.07, 0.94 },
	panel  = { 0.10, 0.10, 0.13, 0.92 },
	inset  = { 0.03, 0.03, 0.04, 0.90 },
	border = { 0.42, 0.36, 0.22, 1 },
	dim    = { 0.25, 0.25, 0.28, 1 },
	hover  = { 0.95, 0.80, 0.30, 1 },
	button = { 0.17, 0.16, 0.14, 1 },
	on     = { 0.32, 0.26, 0.10, 1 },
	gold   = { 1, 0.82, 0 },
}

------------------------------------------------------------------------
-- Textures and text
------------------------------------------------------------------------
function UI.Fill(tex, r, g, b, a)
	if tex.SetColorTexture then
		tex:SetColorTexture(r, g, b, a or 1)
	else
		tex:SetTexture(r, g, b, a or 1) -- clients older than 7.0
	end
end

local ICON_PATH = "Interface\\Icons\\"
local FALLBACK_ICON = ICON_PATH .. "INV_Misc_QuestionMark"

function UI.SetIcon(tex, name)
	local ok = tex:SetTexture(ICON_PATH .. (name or "INV_Misc_QuestionMark"))
	if ok == false then
		tex:SetTexture(FALLBACK_ICON)
	end
	tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

function UI.SetClassIcon(tex, classId)
	local c = ns.CLASS_ICON_COORD[classId]
	tex:SetTexture(ns.CLASS_ICON_FILE)
	if c then
		tex:SetTexCoord(c[1], c[2], c[3], c[4])
	end
end

function UI.Text(parent, size, text, flags, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	local ok = fs:SetFont(ns.FONT, size or 12, flags or "")
	if ok == false then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, flags or "")
	end
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH("LEFT")
	if text then fs:SetText(text) end
	return fs
end

-- Background plus a 1px border made of four color textures.
function UI.Box(frame, bg, border)
	bg = bg or UI.COLOR.panel
	border = border or UI.COLOR.border
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(frame)
	UI.Fill(t, bg[1], bg[2], bg[3], bg[4])
	frame.bgTex = t
	local edges = {}
	for i = 1, 4 do
		edges[i] = frame:CreateTexture(nil, "BORDER")
		UI.Fill(edges[i], border[1], border[2], border[3], border[4] or 1)
	end
	edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	edges[4]:SetWidth(1)
	frame.edges = edges
	return frame
end

function UI.BoxColor(frame, r, g, b, a)
	UI.Fill(frame.bgTex, r, g, b, a or 1)
end

function UI.BorderColor(frame, r, g, b, a)
	for i = 1, 4 do
		UI.Fill(frame.edges[i], r, g, b, a or 1)
	end
end

function UI.Panel(parent, w, h, bg, border)
	local f = CreateFrame("Frame", nil, parent)
	if w and h then f:SetSize(w, h) end
	UI.Box(f, bg, border)
	return f
end

------------------------------------------------------------------------
-- Tooltip (own frame: full control over fonts and layout)
------------------------------------------------------------------------
local tip
local TIP_WIDTH = 270

local function ensureTip()
	if tip then return tip end
	tip = CreateFrame("Frame", nil, UIParent)
	tip:SetFrameStrata("TOOLTIP")
	tip:SetClampedToScreen(true)
	UI.Box(tip, { 0.03, 0.03, 0.05, 0.97 }, { 0.6, 0.55, 0.4, 1 })
	tip.rows = {}
	tip:Hide()
	return tip
end

-- lines: array of { left, right, r, g, b }
function UI.ShowTip(owner, lines, anchor)
	if not lines or #lines == 0 then return end
	ensureTip()
	local y = -8
	for i = 1, #lines do
		local l = lines[i]
		local row = tip.rows[i]
		if not row then
			row = { left = UI.Text(tip, 11), right = UI.Text(tip, 11) }
			row.right:SetJustifyH("RIGHT")
			row.left:SetJustifyV("TOP")
			tip.rows[i] = row
		end
		local size = (i == 1) and 13 or 11
		row.left:SetFont(ns.FONT, size, "")
		row.left:SetWidth(l[2] and (TIP_WIDTH - 90) or TIP_WIDTH)
		row.left:SetText(l[1] or "")
		row.left:SetTextColor(l[3] or 1, l[4] or 1, l[5] or 1)
		row.left:ClearAllPoints()
		row.left:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, y)
		row.left:Show()
		if l[2] then
			row.right:SetText(l[2])
			row.right:SetTextColor(l[3] or 1, l[4] or 1, l[5] or 1)
			row.right:ClearAllPoints()
			row.right:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -8, y)
			row.right:Show()
		else
			row.right:Hide()
		end
		local h = row.left:GetStringHeight() or size
		if h < size then h = size end
		y = y - h - 3
	end
	for i = #lines + 1, #tip.rows do
		tip.rows[i].left:Hide()
		tip.rows[i].right:Hide()
	end
	tip:SetSize(TIP_WIDTH + 16, -y + 6)
	tip:ClearAllPoints()
	if anchor == "TOP" then
		tip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
	else
		tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
	end
	tip.owner = owner
	tip:Show()
end

function UI.HideTip(owner)
	if tip and (owner == nil or tip.owner == owner) then
		tip:Hide()
		tip.owner = nil
	end
end

-- Attach a tooltip provider: fn(widget) returns the lines to show.
function UI.Tip(widget, fn, anchor)
	widget.tipFn = fn
	widget.tipAnchor = anchor
	widget:SetScript("OnEnter", function(self)
		if self.onEnter then self.onEnter(self) end
		if self.tipFn then
			UI.ShowTip(self, self.tipFn(self), self.tipAnchor)
		end
	end)
	widget:SetScript("OnLeave", function(self)
		if self.onLeave then self.onLeave(self) end
		UI.HideTip(self)
	end)
end

-- Redraw the tooltip of whatever is under the cursor (after a click changed it).
function UI.RefreshTip()
	if tip and tip:IsShown() and tip.owner and tip.owner.tipFn then
		UI.ShowTip(tip.owner, tip.owner.tipFn(tip.owner), tip.owner.tipAnchor)
	end
end

function UI.SimpleTip(title, body)
	local lines = { { title, nil, 1, 0.82, 0 } }
	if body then lines[2] = { body, nil, 1, 1, 1 } end
	return lines
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
local function buttonPaint(b)
	local c = UI.COLOR
	if b.off then
		UI.BoxColor(b, 0.10, 0.10, 0.11, 1)
		UI.BorderColor(b, c.dim[1], c.dim[2], c.dim[3], 1)
		b.label:SetTextColor(0.45, 0.45, 0.45)
	else
		local bg = b.on and c.on or c.button
		UI.BoxColor(b, bg[1], bg[2], bg[3], 1)
		local bd = (b.hover or b.on) and c.hover or c.border
		UI.BorderColor(b, bd[1], bd[2], bd[3], 1)
		if b.textColor then
			b.label:SetTextColor(b.textColor[1], b.textColor[2], b.textColor[3])
		else
			b.label:SetTextColor(1, 0.9, 0.6)
		end
	end
end

-- onClick(self, mouseButton)
function UI.Button(parent, w, h, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	UI.Box(b, UI.COLOR.button)
	b.label = UI.Text(b, 11, text)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetJustifyH("CENTER")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.onClick = onClick
	b:SetScript("OnClick", function(self, button)
		if self.off and not self.clickWhenOff then return end
		ns.Sound("click")
		if self.onClick then self.onClick(self, button) end
	end)
	b.onEnter = function(self) self.hover = true buttonPaint(self) end
	b.onLeave = function(self) self.hover = false buttonPaint(self) end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	function b:SetLabel(t) self.label:SetText(t) end
	function b:SetOn(v) self.on = v and true or false buttonPaint(self) end
	function b:SetOff(v) self.off = v and true or false buttonPaint(self) end
	function b:SetTextRGB(r, g, bl) self.textColor = { r, g, bl } buttonPaint(self) end
	buttonPaint(b)
	return b
end

-- A checkbox-like toggle: get() -> bool, set(bool)
function UI.Check(parent, text, get, set)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(200, 18)
	b.box = UI.Panel(b, 14, 14, UI.COLOR.inset)
	b.box:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.mark = b.box:CreateTexture(nil, "ARTWORK")
	b.mark:SetPoint("TOPLEFT", b.box, "TOPLEFT", 3, -3)
	b.mark:SetPoint("BOTTOMRIGHT", b.box, "BOTTOMRIGHT", -3, 3)
	UI.Fill(b.mark, 1, 0.82, 0, 1)
	b.label = UI.Text(b, 11, text)
	b.label:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
	b.get, b.set = get, set
	function b:Refresh()
		if self.get() then self.mark:Show() else self.mark:Hide() end
	end
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		ns.Sound("click")
		self.set(not self.get())
		self:Refresh()
	end)
	b:SetWidth(24 + b.label:GetStringWidth())
	return b
end

------------------------------------------------------------------------
-- Icon button (items, skills, runes, materials ...)
------------------------------------------------------------------------
function UI.IconButton(parent, size, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	UI.Box(b, UI.COLOR.inset, UI.COLOR.dim)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.icon:Hide()
	b.shade = b:CreateTexture(nil, "OVERLAY")
	b.shade:SetAllPoints(b.icon)
	UI.Fill(b.shade, 0, 0, 0, 0.65)
	b.shade:Hide()
	b.glow = b:CreateTexture(nil, "OVERLAY")
	b.glow:SetAllPoints(b.icon)
	UI.Fill(b.glow, 1, 0.9, 0.3, 0.28)
	b.glow:Hide()
	b.count = UI.Text(b, 10, nil, "OUTLINE")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.count:SetJustifyH("RIGHT")
	b.mark = UI.Text(b, 10, nil, "OUTLINE")
	b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.onClick = onClick
	b:SetScript("OnClick", function(self, button)
		if self.onClick then self.onClick(self, button) end
	end)
	b.onEnter = function(self) self.glowHover = true self.glow:Show() end
	b.onLeave = function(self) self.glowHover = false if not self.selected then self.glow:Hide() end end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)

	function b:SetIconName(name)
		if name then
			UI.SetIcon(self.icon, name)
			self.icon:Show()
		else
			self.icon:Hide()
		end
	end
	function b:SetClass(classId)
		UI.SetClassIcon(self.icon, classId)
		self.icon:Show()
	end
	function b:SetQuality(q)
		if q and ns.QUALITY[q] then
			local r, g, bl = ns.U.rgb(ns.QUALITY[q].hex)
			UI.BorderColor(self, r, g, bl, 1)
		else
			local c = UI.COLOR.dim
			UI.BorderColor(self, c[1], c[2], c[3], 1)
		end
	end
	function b:SetBorderRGB(r, g, bl) UI.BorderColor(self, r, g, bl, 1) end
	function b:SetCount(t) self.count:SetText(t or "") end
	function b:SetMark(t, r, g, bl)
		self.mark:SetText(t or "")
		if r then self.mark:SetTextColor(r, g, bl) end
	end
	function b:SetDim(v) if v then self.shade:Show() else self.shade:Hide() end end
	function b:SetSelected(v)
		self.selected = v and true or false
		if self.selected or self.glowHover then self.glow:Show() else self.glow:Hide() end
	end
	function b:Clear()
		self.icon:Hide()
		self:SetQuality(nil)
		self:SetCount(nil)
		self:SetMark(nil)
		self:SetDim(false)
		self:SetSelected(false)
		self.data = nil
	end
	return b
end

------------------------------------------------------------------------
-- Progress bar
------------------------------------------------------------------------
function UI.Bar(parent, w, h, r, g, b)
	local f = UI.Panel(parent, w, h, UI.COLOR.inset, { 0, 0, 0, 1 })
	f.fill = f:CreateTexture(nil, "ARTWORK")
	f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	UI.Fill(f.fill, r or 0.2, g or 0.8, b or 0.2, 1)
	f.inner = w - 2
	f.text = UI.Text(f, max(8, min(11, h - 3)), nil, "OUTLINE")
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.text:SetJustifyH("CENTER")
	function f:SetValue(v)
		if v ~= v then v = 0 end -- NaN guard
		v = ns.U.clamp(v or 0, 0, 1)
		if v <= 0 then
			self.fill:Hide()
		else
			self.fill:Show()
			self.fill:SetWidth(max(1, self.inner * v))
		end
	end
	function f:SetRGB(r2, g2, b2) UI.Fill(self.fill, r2, g2, b2, 1) end
	function f:SetLabel(t) self.text:SetText(t or "") end
	f:SetValue(0)
	return f
end

------------------------------------------------------------------------
-- Misc helpers
------------------------------------------------------------------------
function UI.Gold(n)
	return "|cffffd100" .. ns.U.fmt(n) .. "|r G"
end

-- Short feedback line: turns a (ok, reason) result into a toast when it failed.
function UI.Try(ok, why)
	if not ok and why then
		ns.Fire("TOAST", "|cffff6060" .. why .. "|r")
	end
	return ok
end

-- Icons for passive talent nodes and other stat displays.
UI.STAT_ICON = {
	atk = "Ability_Warrior_OffensiveStance", atkPct = "Ability_Warrior_OffensiveStance",
	hp = "Spell_Nature_Rejuvenation", hpPct = "Spell_Nature_Rejuvenation",
	armor = "INV_Shield_06", armorPct = "INV_Shield_06", block = "Ability_Defend",
	regenPct = "Spell_Nature_ResistNature", regen = "Spell_Nature_ResistNature",
	dr = "Ability_Warrior_DefensiveStance", cdr = "Spell_Nature_TimeStop", allres = "Spell_Frost_WizardMark",
	hpkPct = "Spell_Shadow_LifeDrain", aspd = "Ability_Rogue_Sprint", dodge = "Ability_Rogue_Feint",
	leech = "Spell_Shadow_LifeDrain02", crit = "Ability_CriticalStrike", critdmg = "Ability_BackStab",
	multi = "Ability_Warrior_Cleave", cast = "Spell_Holy_MindVision", heal = "Spell_Holy_FlashHeal",
	dmg_phys = "Ability_MeleeDamage", dmg_fire = "Spell_Fire_FireBolt02", dmg_frost = "Spell_Frost_FrostBolt02",
	dmg_nature = "Spell_Nature_Lightning", dmg_shadow = "Spell_Shadow_ShadowWordPain", dmg_holy = "Spell_Holy_HolySmite",
	dmg_arcane = "Spell_Holy_MagicalSentry", dmg_all = "Spell_Nature_WispSplode",
}
