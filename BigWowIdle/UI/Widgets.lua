-- Widget toolkit. Everything on screen is the game's own interface art (the
-- client's atlases and interface files): the window of the character sheet,
-- the dialog border, the inset, the tooltip border, the red panel button,
-- item slots, role icons and marks. Game icons stand for things that exist in
-- the game (items, spells, classes).
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min
local unpack = unpack or table.unpack

local UI = {}
ns.UI = UI

-- Palette
UI.C = {
	gold  = { 1.00, 0.82, 0.29 },
	text  = { 0.92, 0.94, 0.98 },
	sub   = { 0.62, 0.68, 0.80 },
	dim   = { 0.42, 0.46, 0.56 },
	red   = { 1.00, 0.36, 0.32 },
	green = { 0.40, 0.92, 0.50 },
	blue  = { 0.48, 0.72, 1.00 },
}

function UI.RGB(hex)
	return ns.U.rgb(hex)
end

------------------------------------------------------------------------
-- The game's art
------------------------------------------------------------------------
local function atlasInfo(name)
	if not name or not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
	return C_Texture.GetAtlasInfo(name)
end
function UI.HasAtlas(name) return atlasInfo(name) ~= nil end

local FULL = { 0, 1, 0, 1 }
local FILE = {
	rock   = "Interface\\FrameGeneral\\UI-Background-Rock",
	marble = "Interface\\FrameGeneral\\UI-Background-Marble",
	dialog = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	mask   = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
}
UI.FILE = FILE

-- Marks and small pieces. atlas: the client's atlases, first one it has;
-- file (+ tc): the interface file used otherwise; alt: atlases tried when
-- the client has no such file either. tint: the piece is light and takes a
-- colour ("desat": greyed first, so a coloured ring keeps its shading);
-- without tint it keeps its own colours.
UI.GLYPH = {
	circle = { file = FILE.mask, tint = true },
	ring   = { file = "Interface\\Common\\GoldRing", alt = { "voicechat-portrait-ring" }, tint = "desat" },
	glow   = { atlas = { "ChallengeMode-SoftYellowGlow" }, file = "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64", blend = "ADD", tint = "desat" },
	hilite = { file = "Interface\\Buttons\\ButtonHilight-Square", blend = "ADD", tint = true },
	bar    = { file = "Interface\\TargetingFrame\\UI-StatusBar", tint = true },
	frame  = { file = "Interface\\Common\\WhiteIconFrame", tint = true },
	slot   = { atlas = { "bags-item-slot64" }, file = "Interface\\Buttons\\UI-EmptySlot-Disabled", tc = { 0.14, 0.86, 0.14, 0.86 } },
	shade  = { color = true, tint = true },
	check  = { file = "Interface\\Buttons\\UI-CheckBox-Check" },
	lock   = { atlas = { "bankslot-icon-lock-c60", "AdventureMapIcon-Lock" }, file = "Interface\\PetBattles\\PetBattle-LockIcon" },
	plus   = { file = "Interface\\PaperDollInfoFrame\\Character-Plus" },
	close  = { atlas = { "RedButton-Exit" }, file = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", tc = { 0.2, 0.8, 0.2, 0.8 } },
	arrow  = { file = "Interface\\ChatFrame\\ChatFrameExpandArrow" },
	star   = { atlas = { "PetJournal-FavoritesIcon" }, file = "Interface\\Common\\ReputationStar", tc = { 0, 0.5, 0, 0.5 } },
	crown  = { atlas = { "groupfinder-icon-leader" }, file = "Interface\\GroupFrame\\UI-Group-LeaderIcon" },
	skull  = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
	auto   = { atlas = { "UI-RefreshButton" }, file = "Interface\\Buttons\\UI-RefreshButton" },
	role_tank = { atlas = { "groupfinder-icon-role-large-tank" }, file = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", tc = { 0, 19 / 64, 22 / 64, 41 / 64 } },
	role_heal = { atlas = { "groupfinder-icon-role-large-heal" }, file = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", tc = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 } },
	role_dps  = { atlas = { "groupfinder-icon-role-large-dps" }, file = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", tc = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } },
}

-- Puts a piece of the game's art on a texture (spec: a UI.GLYPH entry).
local function firstAtlas(t, list)
	for _, a in ipairs(list or {}) do
		if atlasInfo(a) then
			t:SetAtlas(a)
			return true
		end
	end
	return false
end

local function putArt(t, spec)
	if spec.color then
		t:SetColorTexture(1, 1, 1, 1) -- a plain fill, coloured by the tint
	elseif not firstAtlas(t, spec.atlas) then
		-- a client says false for a file it does not have
		local ok = t:SetTexture(spec.file)
		t:SetTexCoord(unpack(spec.tc or FULL))
		if ok == false then firstAtlas(t, spec.alt) end
	end
	t:SetBlendMode(spec.blend or "BLEND")
	if t.SetDesaturated then t:SetDesaturated(spec.tint == "desat") end
end
UI.PutArt = putArt

-- Sets a mark (UI.GLYPH name) on a texture, optionally coloured.
function UI.SetGlyph(t, name, r, g, b, a)
	local spec = UI.GLYPH[name] or UI.GLYPH.circle
	putArt(t, spec)
	t.skinName = name
	t.painted = not spec.tint
	if r then UI.Tint(t, r, g, b, a) else t:SetVertexColor(1, 1, 1, 1) end
end

-- Colours a mark; marks with their own colours only take the alpha.
function UI.Tint(t, r, g, b, a)
	if t.painted then t:SetVertexColor(1, 1, 1, a or 1) else t:SetVertexColor(r, g, b, a or 1) end
end

function UI.Art(parent, name, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	UI.SetGlyph(t, name, r, g, b, a)
	return t
end

function UI.Glyph(parent, name, size, r, g, b, layer)
	local t = UI.Art(parent, name, layer or "OVERLAY", r or 1, g or 1, b or 1)
	t:SetSize(size, size)
	return t
end

-- A tiled background from an interface file (the rock of a window, the
-- marble of an inset).
function UI.TiledBg(parent, file, layer, sub)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	t:SetTexture(file, "REPEAT", "REPEAT")
	if t.SetHorizTile then t:SetHorizTile(true) end
	if t.SetVertTile then t:SetVertTile(true) end
	return t
end

-- A battle or stage scene: the rock of the game's windows, in the zone's
-- colour (theme: ns.THEMES entry).
function UI.SetScene(t, theme)
	t:SetTexture(FILE.rock, "REPEAT", "REPEAT")
	if t.SetHorizTile then t:SetHorizTile(true) end
	if t.SetVertTile then t:SetVertTile(true) end
	t:SetTexCoord(0, 1, 0, 1)
	local c = theme and theme.rgb or { 0.7, 0.7, 0.7 }
	t:SetVertexColor(0.35 + c[1] * 0.65, 0.35 + c[2] * 0.65, 0.35 + c[3] * 0.65)
	t.skinName = "scene"
end

-- A black fade (orientation as the game's SetGradient: HORIZONTAL from left
-- to right, VERTICAL from bottom to top); flat where a client has no gradients.
function UI.Shade(parent, layer, orientation, a1, a2)
	local t = parent:CreateTexture(nil, layer or "BORDER")
	t:SetColorTexture(1, 1, 1, 1)
	t.skinName = "shade"
	local ok = false
	if t.SetGradient and CreateColor then
		ok = pcall(t.SetGradient, t, orientation, CreateColor(0, 0, 0, a1), CreateColor(0, 0, 0, a2))
	end
	if not ok then t:SetVertexColor(0, 0, 0, (a1 + a2) / 2) end
	return t
end

-- Crops a texture to a circle (the game's portrait mask).
function UI.Round(t, owner)
	if not (owner and owner.CreateMaskTexture and t.AddMaskTexture) then return end
	local m = owner:CreateMaskTexture()
	m:SetTexture(FILE.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(t)
	t:AddMaskTexture(m)
	t.mask = m
end

-- Sets a one-line text in the largest of `sizes` (big to small) that fits
-- `width`; the smallest when none does.
function UI.FitText(fs, text, width, sizes, flags)
	fs:SetText(text or "")
	for i, size in ipairs(sizes) do
		fs:SetFont(ns.FONT, size, flags or "")
		if fs:GetStringWidth() <= width or i == #sizes then break end
	end
end

function UI.Text(parent, size, text, flags, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	local ok = fs:SetFont(ns.FONT, size or 12, flags or "")
	if ok == false then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, flags or "")
	end
	fs:SetShadowColor(0, 0, 0, 0.9)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(UI.C.text[1], UI.C.text[2], UI.C.text[3])
	if text then fs:SetText(text) end
	return fs
end

function UI.Color(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

function UI.Fill(tex, r, g, b, a)
	if tex.SetColorTexture then
		tex:SetColorTexture(r, g, b, a or 1)
	else
		tex:SetTexture(r, g, b, a or 1) -- clients older than 7.0
	end
end

local ICON_PATH = "Interface\\Icons\\"

function UI.SetIcon(tex, name)
	tex:SetTexture(ICON_PATH .. (name or "INV_Misc_QuestionMark"))
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function UI.SetClassIcon(tex, classId)
	local sq = ns.CLASS_ICON_SQUARE and ns.CLASS_ICON_SQUARE[classId]
	if sq then
		tex:SetTexture(sq)
		tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		return
	end
	local c = ns.CLASS_ICON_COORD[classId]
	tex:SetTexture(ns.CLASS_ICON_FILE)
	if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
end

-- Hero face: the class circle.
function UI.SetHeroIcon(tex, heroId)
	local h = ns.db and ns.db.heroes[heroId]
	UI.SetClassIcon(tex, h and ns.SPECS[h.spec].class)
	return false
end

------------------------------------------------------------------------
-- Borders: the client's nine-slice layouts
------------------------------------------------------------------------
-- The same tables the client builds its own windows from (NineSliceLayouts,
-- with Forever's offsets); these copies serve only a client without them.
local LAYOUT = {
	PortraitFrameTemplate = {
		TopLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-PortraitMetal-CornerTopLeft", x = -13, y = 16 },
		TopRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16 },
		BottomLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3 },
		BottomRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3 },
		TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop" },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom" },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft" },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight" },
	},
	Dialog = {
		TopLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopLeft" },
		TopRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopRight" },
		BottomLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomLeft" },
		BottomRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomRight" },
		TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop" },
		BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom" },
		LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft" },
		RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight" },
	},
	InsetFrameTemplate = {
		TopLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerTopLeft" },
		TopRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerTopRight" },
		BottomLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerBotLeftCorner", x = 0, y = -1 },
		BottomRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerBotRight", x = 0, y = -1 },
		TopEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-InnerTopTile" },
		BottomEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-InnerBotTile" },
		LeftEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-InnerLeftTile" },
		RightEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-InnerRightTile" },
	},
	TooltipDefaultLayout = {
		TopRightCorner = { atlas = "Tooltip-NineSlice-CornerTopRight" },
		TopLeftCorner = { atlas = "Tooltip-NineSlice-CornerTopLeft" },
		BottomLeftCorner = { atlas = "Tooltip-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "Tooltip-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_Tooltip-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_Tooltip-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!Tooltip-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!Tooltip-NineSlice-EdgeRight" },
		Center = { layer = "BACKGROUND", atlas = "Tooltip-NineSlice-Center", x = -4, y = 4, x1 = 4, y1 = -4 },
	},
}

-- How the client places the pieces (Blizzard_SharedXML/NineSlice.lua).
local SETUP = {
	{ "TopLeftCorner", "TOPLEFT" },
	{ "TopRightCorner", "TOPRIGHT", mh = true },
	{ "BottomLeftCorner", "BOTTOMLEFT", mv = true },
	{ "BottomRightCorner", "BOTTOMRIGHT", mh = true, mv = true },
	{ "TopEdge", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner", th = true },
	{ "BottomEdge", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner", mv = true, th = true },
	{ "LeftEdge", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner", tv = true },
	{ "RightEdge", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner", mh = true, tv = true },
	{ "Center" },
}

function UI.Layout(name)
	return (NineSliceLayouts and NineSliceLayouts[name]) or LAYOUT[name]
end

-- Builds border `name` on `frame` (out: pixels the border is pushed outwards;
-- noCenter: leave out the layout's centre piece). Returns the pieces, also by
-- name. layer/sub replace the layout's own draw layer.
function UI.NineSlice(frame, name, out, layer, sub, noCenter)
	local layout = UI.Layout(name)
	local pieces = {}
	if not layout then return pieces end
	out = out or 0
	local outX = { TOPLEFT = -out, TOPRIGHT = out, BOTTOMLEFT = -out, BOTTOMRIGHT = out }
	local outY = { TOPLEFT = out, TOPRIGHT = out, BOTTOMLEFT = -out, BOTTOMRIGHT = -out }
	for _, s in ipairs(SETUP) do
		local key = s[1]
		local p = layout[key]
		if p and p.atlas and not (noCenter and key == "Center") then
			local t = frame:CreateTexture(nil, layer or p.layer or "BORDER", nil, sub or p.subLevel)
			pieces[key] = t
			pieces[#pieces + 1] = t
			if key == "Center" then
				t:SetPoint("TOPLEFT", pieces.TopLeftCorner, "BOTTOMRIGHT", p.x or 0, p.y or 0)
				t:SetPoint("BOTTOMRIGHT", pieces.BottomRightCorner, "TOPLEFT", p.x1 or 0, p.y1 or 0)
			elseif s[3] then
				t:SetPoint(s[2], pieces[s[4]], s[3], p.x or 0, p.y or 0)
				t:SetPoint(s[3], pieces[s[5]], s[2], p.x1 or 0, p.y1 or 0)
			else
				local pt = p.point or s[2]
				t:SetPoint(pt, frame, p.relativePoint or pt, (p.x or 0) + outX[pt], (p.y or 0) + outY[pt])
			end
			local l, r, tp, b = 0, 1, 0, 1
			local mirror = p.mirrorLayout
			if mirror == nil then mirror = layout.mirrorLayout end
			if mirror then
				if s.mv then tp, b = b, tp end
				if s.mh then l, r = r, l end
			end
			t:SetTexCoord(l, r, tp, b)
			local info = atlasInfo(p.atlas)
			if t.SetHorizTile then t:SetHorizTile(info and info.tilesHorizontally or false) end
			if t.SetVertTile then t:SetVertTile(info and info.tilesVertically or false) end
			if info then t:SetAtlas(p.atlas, true) end
			if layout.disableSharpening then
				if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
				if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
			end
			t.skinName = (key == "Center") and "fill" or "border"
		end
	end
	return pieces
end

------------------------------------------------------------------------
-- Boxes
------------------------------------------------------------------------
-- What a box looks like (UI.Slice kinds):
--   panel  the dialog border with its dark background (popups, small windows)
--   card   the tooltip border over a dark fill (cards, raised boxes)
--   inset  the inner border over marble (sunken boxes, lists)
--   pill   the tooltip border over a fill in the given colour
--   frame  the tooltip border alone, coloured (selection, highlights)
--   shadow nothing (the game's windows cast none)
-- base: the fill a SetColor tint multiplies (card: the dark of the tooltip).
UI.BOX = {
	panel = { border = "Dialog", bg = FILE.dialog, inset = 7 },
	card  = { border = "TooltipDefaultLayout", fill = true, base = { 0.13, 0.15, 0.21 } },
	inset = { border = "InsetFrameTemplate", bg = FILE.marble, inset = 0 },
	pill  = { border = "TooltipDefaultLayout", fill = true, base = { 1, 1, 1 } },
	frame = { border = "TooltipDefaultLayout", tintBorder = true },
	tooltip = { border = "TooltipDefaultLayout", fill = true, base = { 0.06, 0.06, 0.08 } },
}

local Slice = {}
Slice.__index = Slice

-- Colours the box: its fill (cards, pills), or its border (frames).
function Slice:SetColor(r, g, b, a)
	local k = self.kind
	if k.tintBorder then
		for _, t in ipairs(self.pieces) do t:SetVertexColor(r, g, b, a or 1) end
	elseif self.fill then
		local base = k.base or FULL
		self.fill:SetVertexColor(min(1, r * base[1]), min(1, g * base[2]), min(1, b * base[3]), a or 1)
	elseif self.bg then
		self.bg:SetVertexColor(min(1, r), min(1, g), min(1, b), a or 1)
	end
end

function Slice:SetShown(v)
	for _, t in ipairs(self.pieces) do t:SetShown(v and true or false) end
	if self.bg then self.bg:SetShown(v and true or false) end
	if self.fill then self.fill:SetShown(v and true or false) end
end

-- Covers `frame` with a box of kind `art` (UI.BOX). out = pixels it grows by.
function UI.Slice(frame, art, layer, _, out)
	local k = UI.BOX[art]
	local s = setmetatable({ kind = k or {}, pieces = {} }, Slice)
	if not k then return s end
	out = out or 0
	local frameLayer = (layer == "OVERLAY") and "OVERLAY" or nil
	s.pieces = UI.NineSlice(frame, k.border, out, frameLayer, nil, true)
	if k.fill then
		-- a plain fill inside the border, in exactly the colour asked for
		s.fill = frame:CreateTexture(nil, "BACKGROUND")
		s.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 2 - out, out - 2)
		s.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out - 2, 2 - out)
		s.fill:SetColorTexture(1, 1, 1, 1)
		s.fill.skinName = art
		s:SetColor(1, 1, 1, 1)
	elseif k.bg then
		local i = (k.inset or 0) - out
		s.bg = UI.TiledBg(frame, k.bg, "BACKGROUND", -6)
		s.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", i, -i)
		s.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i, i)
		s.bg.skinName = art
	end
	return s
end

------------------------------------------------------------------------
-- Panels
------------------------------------------------------------------------
-- kind: panel (window), card (raised box), inset (sunken box)
function UI.Panel(parent, w, h, kind)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.bg = UI.Slice(f, kind or "card", "BACKGROUND")
	return f
end

-- A thin horizontal divider.
function UI.Line(parent, w, r, g, b, a)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(w, 1)
	UI.Fill(t, r or 0.35, g or 0.42, b or 0.62, a or 0.5)
	return t
end

------------------------------------------------------------------------
-- Pills and badges
------------------------------------------------------------------------
function UI.Pill(parent, w, h, r, g, b, a)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.bg = UI.Slice(f, "pill", "BACKGROUND")
	f.bg:SetColor(r or 0, g or 0, b or 0, a or 0.55)
	f.text = UI.Text(f, max(10, min(16, h - 9)))
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.text:SetJustifyH("CENTER")
	f.text:SetWordWrap(false)
	function f:SetLabel(t) self.text:SetText(t or "") end
	function f:SetColor(r2, g2, b2, a2) self.bg:SetColor(r2, g2, b2, a2 or 1) end
	return f
end

-- Red notification dot with an optional number.
function UI.Badge(parent, size)
	size = max(14, size or 16)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.isBadge = true -- sits on its owner's corner on purpose
	f:SetFrameLevel(parent:GetFrameLevel() + 6)
	f.dot = UI.Art(f, "circle", "OVERLAY", 0.92, 0.18, 0.16)
	f.dot:SetAllPoints(f)
	f.text = UI.Text(f, 10, nil, "OUTLINE")
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.text:SetJustifyH("CENTER")
	-- on the owner's corner, sticking out only a little so it never reaches
	-- the next button or cell
	f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 2, 2)
	f:Hide()
	-- v: false/nil hides, true shows a dot, a number shows the number
	function f:Set(v)
		if not v or v == 0 then
			self:Hide()
			return
		end
		if v == true then
			self.text:SetText("")
		else
			self.text:SetText(v > 99 and "99+" or tostring(v))
		end
		-- a longer number makes the dot wider rather than spilling out of it
		self:SetWidth(max(size, floor(self.text:GetStringWidth() + 5)))
		self:Show()
	end
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
	tip:SetSize(TIP_WIDTH + 20, 40)
	tip.bg = UI.Slice(tip, "tooltip", "BACKGROUND")
	tip.rows = {}
	tip:Hide()
	return tip
end

-- lines: array of { left, right, r, g, b } (a line may carry sockets: see
-- UI.Lines in UI/Layout.lua)
local TIP_SOCKET = 16
function UI.ShowTip(owner, lines, anchor)
	if not lines or #lines == 0 then return end
	ensureTip()
	local y = -10
	for i = 1, #lines do
		local l = lines[i]
		local row = tip.rows[i]
		if not row then
			row = { left = UI.Text(tip, 11), right = UI.Text(tip, 11), sockets = {} }
			row.right:SetJustifyH("RIGHT")
			row.left:SetJustifyV("TOP")
			tip.rows[i] = row
		end
		local size = (i == 1) and 13 or 11
		local socks = l.sockets
		local indent = UI.PlaceSockets(row.sockets, tip, socks, TIP_SOCKET, 10, y)
		row.left:SetFont(ns.FONT, size, "")
		row.left:SetWidth((l[2] and (TIP_WIDTH - 90) or TIP_WIDTH) - indent)
		row.left:SetText(l[1] or "")
		row.left:SetTextColor(l[3] or 1, l[4] or 1, l[5] or 1)
		row.left:ClearAllPoints()
		row.left:SetPoint("TOPLEFT", tip, "TOPLEFT", 10 + indent, y - (socks and 2 or 0))
		row.left:Show()
		if l[2] then
			row.right:SetText(l[2])
			row.right:SetTextColor(l[3] or 1, l[4] or 1, l[5] or 1)
			row.right:ClearAllPoints()
			row.right:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -10, y)
			row.right:Show()
		else
			row.right:Hide()
		end
		local h = row.left:GetStringHeight() or size
		if h < size then h = size end
		if socks and h < TIP_SOCKET then h = TIP_SOCKET end
		y = y - h - 3
	end
	for i = #lines + 1, #tip.rows do
		tip.rows[i].left:Hide()
		tip.rows[i].right:Hide()
		UI.PlaceSockets(tip.rows[i].sockets, tip, nil)
	end
	tip:SetSize(TIP_WIDTH + 20, -y + 8)
	tip:ClearAllPoints()
	if anchor == "TOP" then
		tip:SetPoint("BOTTOM", owner, "TOP", 0, 6)
	else
		tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 0)
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
		if self.tipFn then UI.ShowTip(self, self.tipFn(self), self.tipAnchor) end
	end)
	widget:SetScript("OnLeave", function(self)
		if self.onLeave then self.onLeave(self) end
		UI.HideTip(self)
	end)
end

function UI.RefreshTip()
	if tip and tip:IsShown() and tip.owner and tip.owner.tipFn then
		UI.ShowTip(tip.owner, tip.owner.tipFn(tip.owner), tip.owner.tipAnchor)
	end
end

function UI.SimpleTip(title, body)
	local lines = { { title, nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
	if body then lines[2] = { body, nil, 1, 1, 1 } end
	return lines
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- The red panel button of the game (UIPanelButtonTemplate): three pieces of
-- Interface\Buttons\UI-Panel-Button-Up / -Down / -Disabled and its highlight.
local PANEL_BTN = "Interface\\Buttons\\UI-Panel-Button-"
local BTN_TC = {
	{ 0, 0.09375, 0, 0.6875 },        -- left
	{ 0.09375, 0.53125, 0, 0.6875 },  -- middle
	{ 0.53125, 0.625, 0, 0.6875 },    -- right
}

local function btnFace(b, state)
	if b.face == state then return end
	b.face = state
	for i = 1, 3 do
		b.parts[i]:SetTexture(PANEL_BTN .. state)
		b.parts[i]:SetTexCoord(unpack(BTN_TC[i]))
	end
end

-- Builds the three pieces and the highlight of a panel button on `b`.
local function panelButtonArt(b)
	b.parts = {}
	local cap = 12
	local l = b:CreateTexture(nil, "BACKGROUND")
	l:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	l:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	l:SetWidth(cap)
	local r = b:CreateTexture(nil, "BACKGROUND")
	r:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	r:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	r:SetWidth(cap)
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT", 0, 0)
	b.parts = { l, m, r }
	for _, t in ipairs(b.parts) do t.skinName = "button" end
	b.hiT = b:CreateTexture(nil, "HIGHLIGHT")
	b.hiT:SetAllPoints(b)
	b.hiT:SetTexture(PANEL_BTN .. "Highlight")
	b.hiT:SetTexCoord(0, 0.625, 0, 0.6875)
	b.hiT:SetBlendMode("ADD")
	b.hiT.skinName = "glow"
	b.hiT:Hide()
	btnFace(b, "Up")
end
UI.PanelButtonArt = panelButtonArt

-- Up, pressed (held down or switched on), greyed out; the highlight while the
-- mouse is over it or it is on. Text: the game's gold, white when lit, grey
-- when off.
local function paint(b)
	if b.off then
		btnFace(b, "Disabled")
		b.hiT:Hide()
		b.label:SetTextColor(0.50, 0.50, 0.50)
	else
		btnFace(b, (b.on or b.down) and "Down" or "Up")
		b.hiT:SetShown((b.hover or b.on) and true or false)
		if b.on or b.hover then
			b.label:SetTextColor(1, 1, 1)
		else
			b.label:SetTextColor(1, 0.82, 0)
		end
	end
	if b.glyph then
		local a = b.off and 0.45 or 1
		b.glyph:SetVertexColor(a, a, a, 1)
	end
end

-- style: kept for the callers (primary | blue | green | red | dark | purple);
-- every button is the game's own panel button
function UI.Button(parent, w, h, text, onClick, style)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.style = style or "dark"
	panelButtonArt(b)
	b.label = UI.Text(b, h >= 30 and 13 or (h >= 22 and 12 or 10), text)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetJustifyH("CENTER")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.onClick = onClick
	b:SetScript("OnClick", function(self, button)
		if self.off and not self.clickWhenOff then return end
		ns.Sound("click")
		if self.onClick then self.onClick(self, button) end
	end)
	b:SetScript("OnMouseDown", function(self) self.down = true paint(self) end)
	b:SetScript("OnMouseUp", function(self) self.down = false paint(self) end)
	b.onEnter = function(self) self.hover = true paint(self) end
	b.onLeave = function(self) self.hover = false self.down = false paint(self) end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	function b:SetLabel(t) self.label:SetText(t or "") end
	function b:SetStyle(s) self.style = s paint(self) end
	function b:SetOn(v) self.on = v and true or false paint(self) end
	function b:SetOff(v) self.off = v and true or false paint(self) end
	-- small glyph to the left of the label
	function b:SetGlyph(name)
		if not self.glyph then
			self.glyph = UI.Glyph(self, name, h - 10)
			self.glyph:SetPoint("RIGHT", self.label, "LEFT", -4, 0)
		else
			UI.SetGlyph(self.glyph, name)
		end
		paint(self)
	end
	function b:SetBadge(v)
		if not self.badge then self.badge = UI.Badge(self, 14) end
		self.badge:Set(v)
	end
	paint(b)
	return b
end

-- The game's close button (the red X of its windows). size: the client's
-- (28 for Forever's art, 24 otherwise).
function UI.CloseButton(parent, onClick, size)
	local b = CreateFrame("Button", nil, parent)
	size = size or (UI.HasAtlas("bankslot-icon-lock-c60") and 28 or 24)
	b:SetSize(size, size)
	local function art(t, atlas, file)
		if UI.HasAtlas(atlas) then
			t:SetAtlas(atlas)
		else
			t:SetTexture(file)
		end
		t.skinName = "close"
	end
	b.n = b:CreateTexture(nil, "ARTWORK")
	b.n:SetAllPoints(b)
	art(b.n, "RedButton-Exit", "Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	b.p = b:CreateTexture(nil, "ARTWORK")
	b.p:SetAllPoints(b)
	art(b.p, "RedButton-exit-pressed", "Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	b.p:Hide()
	b.hiT = b:CreateTexture(nil, "HIGHLIGHT")
	b.hiT:SetAllPoints(b)
	art(b.hiT, "RedButton-Highlight", "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
	b.hiT:SetBlendMode("ADD")
	b.hiT.skinName = "glow"
	b.hiT:Hide()
	b.onClick = onClick
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		ns.Sound("click")
		if self.onClick then self.onClick(self) end
	end)
	b:SetScript("OnMouseDown", function(self) self.n:Hide() self.p:Show() end)
	b:SetScript("OnMouseUp", function(self) self.p:Hide() self.n:Show() end)
	b.onEnter = function(self) self.hiT:Show() end
	b.onLeave = function(self) self.hiT:Hide() self.p:Hide() self.n:Show() end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	return b
end

-- A round icon button with a caption underneath (menus, docks).
function UI.MenuButton(parent, size, icon, caption, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size + (caption and 13 or 0))
	b.disc = UI.Art(b, "circle", "BACKGROUND", 0.10, 0.13, 0.22, 1)
	b.disc:SetSize(size, size)
	b.disc:SetPoint("TOP", b, "TOP", 0, 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(size * 0.62, size * 0.62)
	b.icon:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
	UI.SetIcon(b.icon, icon)
	UI.Round(b.icon, b)
	b.ringT = UI.Art(b, "ring", "OVERLAY", 0.55, 0.62, 0.80)
	b.ringT:SetSize(size, size)
	b.ringT:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
	if caption then
		b.caption = UI.Text(b, 10, caption)
		b.caption:SetPoint("TOP", b.disc, "BOTTOM", 0, -1)
		b.caption:SetJustifyH("CENTER")
		UI.Color(b.caption, UI.C.sub)
	end
	b.badge = UI.Badge(b, 13)
	b.badge:ClearAllPoints()
	b.badge:SetPoint("TOPRIGHT", b.disc, "TOPRIGHT", 2, 2)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		ns.Sound("click")
		if onClick then onClick(self) end
	end)
	b.onEnter = function(self) UI.Tint(self.ringT, 1, 0.85, 0.35) end
	b.onLeave = function(self) UI.Tint(self.ringT, 0.55, 0.62, 0.80) end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	function b:SetBadge(v) self.badge:Set(v) end
	return b
end

-- Filter / segment chip: a small panel button that is either chosen (held
-- down and lit) or not.
function UI.Chip(parent, w, h, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	panelButtonArt(b)
	b.label = UI.Text(b, h >= 24 and 12 or 11, text)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetJustifyH("CENTER")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		ns.Sound("click")
		if onClick then onClick(self, button) end
	end)
	b:SetScript("OnMouseDown", function(self) self.down = true paint(self) end)
	b:SetScript("OnMouseUp", function(self) self.down = false paint(self) end)
	b.onEnter = function(self) self.hover = true paint(self) end
	b.onLeave = function(self) self.hover = false self.down = false paint(self) end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	function b:SetOn(v) self.on = v and true or false paint(self) end
	function b:SetLabel(t) self.label:SetText(t or "") end
	function b:SetBadge(v)
		if not self.badge then self.badge = UI.Badge(self, 13) end
		self.badge:Set(v)
	end
	paint(b)
	return b
end

-- A toggle: get() -> bool, set(bool). The game's check box.
function UI.Check(parent, text, get, set)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(220, 22)
	b.box = b:CreateTexture(nil, "ARTWORK")
	b.box:SetSize(24, 24)
	b.box:SetPoint("LEFT", b, "LEFT", -2, 0)
	b.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
	b.box.skinName = "checkbox"
	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetAllPoints(b.box)
	b.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	b.mark.skinName = "check"
	b.hiT = b:CreateTexture(nil, "HIGHLIGHT")
	b.hiT:SetAllPoints(b.box)
	b.hiT:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
	b.hiT:SetBlendMode("ADD")
	b.hiT.skinName = "glow"
	b.hiT:Hide()
	b.label = UI.Text(b, 12, text)
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
	b.onEnter = function(self) self.hiT:Show() end
	b.onLeave = function(self) self.hiT:Hide() end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	b:SetWidth(28 + b.label:GetStringWidth())
	return b
end

------------------------------------------------------------------------
-- Slot: items, skills, runes, materials ...
------------------------------------------------------------------------
-- The game's item button: the bag slot behind, the icon, the white icon
-- frame in the quality's colour, the square highlight.
function UI.IconButton(parent, size, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.isItem = true
	b.slotBg = UI.Art(b, "slot", "BACKGROUND")
	b.slotBg:SetAllPoints(b)
	local pad = max(2, floor(size * 0.07))
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", pad, -pad)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -pad, pad)
	b.icon:Hide()
	b.shade = b:CreateTexture(nil, "ARTWORK", nil, 2)
	b.shade:SetAllPoints(b.icon)
	UI.Fill(b.shade, 0.02, 0.03, 0.06, 0.70)
	b.shade:Hide()
	b.frame = UI.Art(b, "frame", "OVERLAY")
	b.frame:SetAllPoints(b)
	b.frame:Hide()
	b.hl = UI.Art(b, "hilite", "OVERLAY", 1, 0.92, 0.55, 0.9)
	b.hl:SetAllPoints(b)
	b.hl:Hide()
	b.count = UI.Text(b, max(10, floor(size * 0.24)), nil, "OUTLINE")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	b.count:SetJustifyH("RIGHT")
	b.mark = UI.Text(b, max(10, floor(size * 0.24)), nil, "OUTLINE")
	b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	b.lockG = UI.Glyph(b, "lock", max(10, floor(size * 0.3)), 0.95, 0.75, 0.35)
	b.lockG:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
	b.lockG:Hide()
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.onClick = onClick
	b:SetScript("OnClick", function(self, button)
		if self.onClick then self.onClick(self, button) end
	end)
	b.onEnter = function(self) self.hover = true self.hl:Show() end
	b.onLeave = function(self) self.hover = false if not self.selected then self.hl:Hide() end end
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
	-- the quality colours the frame around the icon
	function b:SetQuality(q)
		if q and ns.QUALITY[q] then
			local r, g, bl = ns.U.rgb(ns.QUALITY[q].hex)
			self.frame:SetVertexColor(r, g, bl)
			self.frame:Show()
		else
			self.frame:Hide()
		end
	end
	function b:SetBorderRGB(r, g, bl)
		self.frame:SetVertexColor(r, g, bl, 1)
		self.frame:Show()
	end
	function b:SetCount(t) self.count:SetText(t or "") end
	function b:SetMark(t, r, g, bl)
		self.mark:SetText(t or "")
		if r then self.mark:SetTextColor(r, g, bl) end
	end
	function b:SetDim(v) if v then self.shade:Show() else self.shade:Hide() end end
	function b:SetLocked(v) if v then self.lockG:Show() else self.lockG:Hide() end end
	function b:SetSelected(v)
		self.selected = v and true or false
		if self.selected or self.hover then self.hl:Show() else self.hl:Hide() end
	end
	function b:SetBadge(v)
		if not self.badge then self.badge = UI.Badge(self, 13) end
		self.badge:Set(v)
	end
	function b:Clear()
		self.icon:Hide()
		self:SetQuality(nil)
		self:SetCount(nil)
		self:SetMark(nil)
		self:SetDim(false)
		self:SetLocked(false)
		self:SetSelected(false)
		if self.badge then self.badge:Set(false) end
		self.data = nil
	end
	return b
end

------------------------------------------------------------------------
-- Round hero portrait: class circle, role-coloured ring, level pill.
------------------------------------------------------------------------
function UI.Portrait(parent, size, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.isItem = true
	b.disc = UI.Art(b, "circle", "BACKGROUND", 0.06, 0.08, 0.14)
	b.disc:SetAllPoints(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	local pad = floor(size * 0.09)
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", pad, -pad)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -pad, pad)
	b.ringT = UI.Art(b, "ring", "OVERLAY")
	b.ringT:SetAllPoints(b)
	b.hl = UI.Art(b, "glow", "BACKGROUND", 1, 0.85, 0.35, 0.8)
	b.hl:SetPoint("TOPLEFT", b, "TOPLEFT", -size * 0.22, size * 0.22)
	b.hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", size * 0.22, -size * 0.22)
	b.hl:Hide()
	b.lvl = UI.Pill(b, max(22, floor(size * 0.55)), max(13, floor(size * 0.28)), 0.05, 0.06, 0.10, 0.92)
	b.lvl:SetPoint("BOTTOM", b, "BOTTOM", 0, -floor(size * 0.10))
	b.lvl:SetFrameLevel(b:GetFrameLevel() + 3)
	b.role = UI.Glyph(b, "role_tank", max(10, floor(size * 0.30)))
	b.role:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
	b.badge = UI.Badge(b, max(12, floor(size * 0.28)))
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		ns.Sound("click")
		if onClick then onClick(self, button) end
	end)
	b.onEnter = function(self) self.hover = true self.hl:Show() end
	b.onLeave = function(self) self.hover = false if not self.selected then self.hl:Hide() end end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)

	-- heroId or nil (empty)
	function b:SetHero(id)
		self.heroId = id
		local h = id and ns.db.heroes[id]
		if not h then
			self.icon:Hide()
			self.lvl:Hide()
			self.role:Hide()
			UI.Tint(self.ringT, 0.30, 0.34, 0.45)
			return
		end
		local sp = ns.SPECS[h.spec]
		UI.SetClassIcon(self.icon, sp.class)
		self.icon:Show()
		local r, g, bl = ns.U.rgb(ns.ROLE[sp.role].hex)
		UI.Tint(self.ringT, r, g, bl)
		UI.SetGlyph(self.role, ns.ROLE[sp.role].art, r, g, bl)
		self.role:Show()
		self.lvl:SetLabel(tostring(h.level))
		self.lvl:Show()
	end
	function b:SetSelected(v)
		self.selected = v and true or false
		if self.selected or self.hover then self.hl:Show() else self.hl:Hide() end
	end
	function b:SetDim(v)
		self.icon:SetDesaturated(v and true or false)
		self.icon:SetAlpha(v and 0.5 or 1)
	end
	function b:SetBadge(v) self.badge:Set(v) end
	return b
end

------------------------------------------------------------------------
-- Progress bar: the game's status bar texture
------------------------------------------------------------------------
function UI.Bar(parent, w, h, r, g, b)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(f)
	UI.Fill(f.bg, 0.02, 0.03, 0.05, 0.85)
	f.fill = UI.Art(f, "bar", "ARTWORK", r or 0.2, g or 0.8, b or 0.2)
	f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	f.inner = w - 2
	f.text = UI.Text(f, max(10, min(11, h - 3)), nil, "OUTLINE")
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
	function f:SetRGB(r2, g2, b2) self.fill:SetVertexColor(r2, g2, b2, 1) end
	function f:SetLabel(t) self.text:SetText(t or "") end
	function f:SetBarWidth(w2)
		self:SetWidth(w2)
		self.inner = w2 - 2
	end
	f:SetValue(0)
	return f
end

------------------------------------------------------------------------
-- Misc helpers
------------------------------------------------------------------------
function UI.Gold(n)
	return "|cffffd24a" .. ns.U.fmt(n) .. "|r G"
end

-- Turns a (ok, reason) result into a toast when it failed.
function UI.Try(ok, why)
	if not ok and why then
		ns.Fire("TOAST", "|cffff6a5a" .. why .. "|r")
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

-- Section title: gold text with a short underline.
function UI.Title(parent, text, size)
	local fs = UI.Text(parent, size or 13, text)
	UI.Color(fs, UI.C.gold)
	return fs
end
