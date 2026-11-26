-- Runes (룬): the rune tree as a map. The first rune stands in the middle and
-- the tree spreads from it in every direction; each rune is joined by a line
-- to the rune before it (the one it needs). The map is larger than its box:
-- the mouse wheel zooms in and out around the cursor, dragging moves it.
--
-- A rune's border colour is its kind (전투 · 골드 · 경험치 · 상자 · 가방 · 해금
-- · 대장간, the key under the map; a kind's box there can be checked, and the
-- runes of the checked kinds then stand out, the others fade); a rune that cannot be learned yet is
-- grey; a rune at its top level has a green check in its lower right corner.
-- Click a rune to see it in the card on the right and learn it there; the
-- card also lists the total of every learned rune (a list that scrolls).
-- Another screen can send the player to a rune ("…을(를) 배우면 열립니다 ·
-- 클릭: 룬 화면에서 보기"): the map moves to it and red rings pulse around it
-- until another rune is picked.
local _, ns = ...

local floor, max, min, sqrt, atan2 = math.floor, math.max, math.min, math.sqrt, math.atan2
local UI, U = ns.UI, ns.U
local Main = ns.Main
local R = ns.Runes
local K = UI.K

local CELL = 50               -- one step of the tree's grid, at zoom 1
local NODE = 38               -- a rune
local LINK_W = 3              -- the line between two runes
local SIDE_W = 262            -- the card on the right
local MAP_W = K.W - SIDE_W - 10
local KEY_H = 26              -- the key under the map
local MAP_H = K.H - KEY_H - 6
local ZOOM_MAX, ZOOM_STEP = 1.6, 1.15
local LEVEL_TEXT_ZOOM = 0.6   -- below this the levels on the runes are hidden
local TOTAL_ROWS, TOTAL_STEP = 14, 15 -- the 보너스 합계 list
local BAR_W = 6
local GREY = { 0.34, 0.36, 0.42 }
-- the start rune's border is silver, not its kind's colour
local START_RGB = { 0.78, 0.82, 0.88 }
local function borderRGB(node) return node.id == ns.RUNE_FIRST and START_RGB or node.group.rgb end

-- the tree's extent in cells
local minX, maxX, minY, maxY = 0, 0, 0, 0
for _, n in pairs(R.byId) do
	minX, maxX = min(minX, n.x), max(maxX, n.x)
	minY, maxY = min(minY, n.y), max(maxY, n.y)
end

------------------------------------------------------------------------
-- The camera: the tree point at the middle of the map (cx, cy, in tree
-- pixels at zoom 1) and the zoom.
------------------------------------------------------------------------
local function zoomMin()
	local fit = min(MAP_W / ((maxX - minX + 2) * CELL), MAP_H / ((maxY - minY + 2) * CELL))
	return max(0.3, min(1, fit))
end

-- The middle of the view along one axis: the tree (lo..hi, a cell of room
-- around it) fills the view, or sits in its middle when it is smaller.
local function clampAxis(c, lo, hi, half)
	lo, hi = lo - CELL, hi + CELL
	if hi - lo <= 2 * half then return (lo + hi) / 2 end
	return U.clamp(c, lo + half, hi - half)
end

local function applyCamera(page)
	local cam = page.cam
	cam.z = U.clamp(cam.z, zoomMin(), ZOOM_MAX)
	cam.x = clampAxis(cam.x, minX * CELL, maxX * CELL, MAP_W / 2 / cam.z)
	cam.y = clampAxis(cam.y, minY * CELL, maxY * CELL, MAP_H / 2 / cam.z)
	local canvas = page.canvas
	canvas:SetScale(cam.z)
	canvas:ClearAllPoints()
	-- offsets are in the canvas's own (zoomed) units
	canvas:SetPoint("CENTER", page.map, "CENTER", -cam.x, -cam.y)
	local showLevels = cam.z >= LEVEL_TEXT_ZOOM
	if page.levelsShown ~= showLevels then
		page.levelsShown = showLevels
		for _, b in ipairs(page.nodes) do b.lvl:SetShown(showLevels) end
	end
end

-- The cursor, from the middle of the map, in the map's units.
local function cursorOffset(page)
	local map = page.map
	local mx, my = GetCursorPosition()
	local s = map:GetEffectiveScale()
	local x, y = map:GetCenter()
	return mx / s - (x or 0), my / s - (y or 0)
end

local function zoomAt(page, delta)
	local cam = page.cam
	local dx, dy = cursorOffset(page)
	-- the tree point under the cursor stays under it
	local tx, ty = cam.x + dx / cam.z, cam.y + dy / cam.z
	local z = U.clamp(cam.z * ZOOM_STEP ^ delta, zoomMin(), ZOOM_MAX)
	cam.z = z
	cam.x, cam.y = tx - dx / z, ty - dy / z
	applyCamera(page)
end

local function centerOn(page, id)
	local n = R.byId[id]
	if not n then return end
	page.cam.x, page.cam.y = n.x * CELL, n.y * CELL
	page.cam.z = max(page.cam.z, 1)
	applyCamera(page)
end

-- Dragging: from a press on the map or on a rune; a press that moves more
-- than a few pixels is a drag, not a click.
local function beginDrag(page)
	local dx, dy = cursorOffset(page)
	page.drag = { mx = dx, my = dy, x = page.cam.x, y = page.cam.y }
	page.dragged = false
end

local function followDrag(page)
	local d = page.drag
	if not d then return end
	if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then page.drag = nil return end
	local dx, dy = cursorOffset(page)
	local ox, oy = dx - d.mx, dy - d.my
	if not page.dragged and ox * ox + oy * oy < 16 then return end
	page.dragged = true
	page.cam.x, page.cam.y = d.x - ox / page.cam.z, d.y - oy / page.cam.z
	applyCamera(page)
end

------------------------------------------------------------------------
-- A rune on the map
------------------------------------------------------------------------
local function runeTip(self)
	local n = self.node
	local id = n.id
	local lvl, cost = R.Level(id), R.NextCost(id)
	local g = n.group
	local lines = { { ns.N(n.name), string.format("%d / %d", lvl, n.max), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
		{ ns.N(g.name), nil, g.rgb[1], g.rgb[2], g.rgb[3] } }
	if lvl > 0 then lines[#lines + 1] = { "현재  " .. R.Text(id, R.Amount(id, lvl)), nil, 0.4, 1, 0.45 } end
	if lvl < n.max then lines[#lines + 1] = { "다음 레벨  " .. R.Text(id, R.Amount(id, lvl + 1)), nil, 1, 1, 1 } end
	if not R.Available(id) then
		lines[#lines + 1] = { string.format("먼저 '%s'을(를) %d레벨까지 배워야 합니다", ns.N(R.byId[R.prev[id]].name), R.Need(id)), nil, 1, 0.55, 0.45 }
	elseif cost then
		lines[#lines + 1] = { "다음 레벨 비용", U.fmt(cost) .. " G", 0.8, 0.8, 0.85 }
	end
	lines[#lines + 1] = { "클릭: 오른쪽에서 보기", nil, 0.45, 0.8, 1 }
	return lines
end

local function runeNode(page, node)
	local canvas = page.canvas
	local b = CreateFrame("Button", nil, canvas)
	b:SetSize(NODE, NODE)
	b:SetPoint("CENTER", canvas, "CENTER", node.x * CELL, node.y * CELL)
	-- layers: lines (on the canvas) < runes (+2) < the marker's rings (+5)
	b:SetFrameLevel(canvas:GetFrameLevel() + 2)
	b.isItem = true
	b.glow = UI.Art(b, "glow", "BACKGROUND", 1, 0.82, 0.3, 0.85) -- can be learned now
	b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -9, 9)
	b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 9, -9)
	b.glow:Hide()
	-- a kind checked under the map: a halo in the kind's colour
	local g = node.group.rgb
	b.halo = UI.Art(b, "glow", "BACKGROUND", g[1], g[2], g[3], 1)
	b.halo:SetPoint("TOPLEFT", b, "TOPLEFT", -12, 12)
	b.halo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 12, -12)
	b.halo:Hide()
	-- the dark backing, inset like the icon: its corners stay under the
	-- border's rounded ones (a square one showed past them, over the end of
	-- a line coming in on the slant)
	b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	b.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	UI.Fill(b.bg, 0.04, 0.05, 0.08, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	UI.SetIcon(b.icon, node.icon)
	-- the border, in the rune's colour (twice, for a thicker line)
	b.border = UI.Art(b, "frame", "OVERLAY")
	b.border:SetAllPoints(b)
	b.border2 = UI.Art(b, "frame", "OVERLAY")
	b.border2:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.border2:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	-- the chosen rune: a gold frame around it
	b.sel = UI.Art(b, "frame", "OVERLAY", 0.55, 0.80, 1)
	b.sel:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
	b.sel:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
	b.sel:Hide()
	b.lvl = UI.Text(b, 10, nil, "OUTLINE")
	b.lvl:SetPoint("BOTTOM", b, "BOTTOM", 0, 4)
	b.lvl:SetJustifyH("CENTER")
	b.check = UI.Glyph(b, "check", 18, 0.3, 1, 0.38, "OVERLAY")
	b.check:SetDrawLayer("OVERLAY", 3)
	b.check:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, -5)
	b.check:Hide()
	b.node = node
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnMouseDown", function() beginDrag(page) end)
	b:EnableMouseWheel(true)
	b:SetScript("OnMouseWheel", function(_, delta) zoomAt(page, delta) end)
	b:SetScript("OnClick", function(self)
		if page.dragged then return end -- the end of a drag
		ns.Sound("click")
		page.sel = self.node.id
		if page.focus ~= self.node.id then page.focus = nil end
		Main.Refresh()
	end)
	b.onEnter = function(self) self.sel:Show() end
	b.onLeave = function(self) if page.sel ~= self.node.id then self.sel:Hide() end end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	UI.Tip(b, runeTip, "TOP")
	return b
end

-- The line from the rune before (a) to a rune (b), under the runes.
local function link(canvas, a, b)
	local dx, dy = (b.x - a.x) * CELL, (b.y - a.y) * CELL
	local t = canvas:CreateTexture(nil, "BORDER")
	t:SetPoint("CENTER", canvas, "CENTER", (a.x + b.x) / 2 * CELL, (a.y + b.y) / 2 * CELL)
	if dx == 0 then
		t:SetSize(LINK_W, math.abs(dy))
	elseif dy == 0 then
		t:SetSize(math.abs(dx), LINK_W)
	else
		t:SetSize(sqrt(dx * dx + dy * dy), LINK_W)
		t:SetRotation(atan2(dy, dx))
	end
	return t
end

------------------------------------------------------------------------
-- The page
------------------------------------------------------------------------
local function build(page)
	page.sel = ns.RUNE_FIRST
	page.cam = { x = 0, y = 0, z = 1 }

	-- the map: a box that shows part of the tree
	local map = CreateFrame("Frame", nil, page)
	map:SetSize(MAP_W, MAP_H)
	map:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	map:SetClipsChildren(true)
	map:EnableMouse(true)
	map:EnableMouseWheel(true)
	map.bg = UI.Slice(map, "inset", "BACKGROUND")
	map:SetScript("OnMouseDown", function() beginDrag(page) end)
	map:SetScript("OnMouseUp", function() page.drag = nil end)
	map:SetScript("OnMouseWheel", function(_, delta) zoomAt(page, delta) end)
	map:SetScript("OnUpdate", function() followDrag(page) end)
	page.map = map

	local canvas = CreateFrame("Frame", nil, map)
	canvas:SetSize(1, 1)
	canvas:SetFrameLevel(map:GetFrameLevel() + 1)
	page.canvas = canvas

	page.nodes, page.byId = {}, {}
	local ids = {}
	for id in pairs(R.byId) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local node = R.byId[id]
		local b = runeNode(page, node)
		local prev = R.prev[id]
		if prev then b.link = link(canvas, R.byId[prev], node) end
		page.nodes[#page.nodes + 1] = b
		page.byId[id] = b
	end

	-- the rune another screen sent us to: red rings that grow and shrink
	-- around it (the icon stays visible inside)
	local fx = CreateFrame("Frame", nil, canvas)
	fx:SetSize(NODE + 10, NODE + 10)
	fx:SetFrameLevel(canvas:GetFrameLevel() + 5)
	fx.isOverlay = true -- drawn over its rune on purpose
	fx.rings = {}
	for i, c in ipairs({ { 1, 0.12, 0.08 }, { 1, 0.3, 0.22 }, { 1, 0.55, 0.45 } }) do
		local t = UI.Art(fx, "frame", "OVERLAY", c[1], c[2], c[3])
		t:SetPoint("TOPLEFT", fx, "TOPLEFT", i - 1, -(i - 1))
		t:SetPoint("BOTTOMRIGHT", fx, "BOTTOMRIGHT", -(i - 1), i - 1)
		fx.rings[i] = t
	end
	fx:SetScript("OnUpdate", function(self)
		local s = 0.5 + 0.5 * math.sin((GetTime and GetTime() or 0) * 5)
		local size = NODE + 8 + 8 * s -- 4 to 8 pixels around the rune
		self:SetSize(size, size)
		for _, t in ipairs(self.rings) do t:SetAlpha(0.7 + 0.3 * s) end
	end)
	fx:Hide()
	page.focusFx = fx

	-- under the map: what the border colours mean (a box per kind: checked,
	-- that kind's runes stand out), and how to move the map
	local key = CreateFrame("Frame", nil, page)
	key:SetSize(MAP_W, KEY_H)
	key:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 0, -6)
	page.kinds = {}
	local saved = ns.db.ui.runeKinds
	if type(saved) == "table" then
		for _, g in ipairs(ns.RUNE_GROUPS) do if saved[g.key] then page.kinds[g.key] = true end end
	end
	page.kindBoxes = {}
	local x = 8
	for _, g in ipairs(ns.RUNE_GROUPS) do
		local bt = CreateFrame("Button", nil, key)
		bt.fill = bt:CreateTexture(nil, "BACKGROUND")
		bt.fill:SetSize(12, 12)
		bt.fill:SetPoint("LEFT", bt, "LEFT", 1, 0)
		UI.Fill(bt.fill, g.rgb[1], g.rgb[2], g.rgb[3], 0.35)
		bt.box = UI.Art(bt, "frame", "ARTWORK", g.rgb[1], g.rgb[2], g.rgb[3])
		bt.box:SetSize(14, 14)
		bt.box:SetPoint("LEFT", bt, "LEFT", 0, 0)
		bt.mark = UI.Glyph(bt, "check", 12, 1, 1, 1, "OVERLAY")
		bt.mark:SetPoint("CENTER", bt.box, "CENTER", 0, 0)
		local t = UI.Text(bt, 11, ns.N(g.name))
		t:SetPoint("LEFT", bt.box, "RIGHT", 8, 0)
		bt:SetSize(14 + 8 + t:GetStringWidth(), KEY_H)
		bt.isItem = true -- one of the key's boxes (its names are the kinds')
		bt:SetPoint("LEFT", key, "LEFT", x, 0)
		bt.key = g.key
		bt:RegisterForClicks("LeftButtonUp")
		bt:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.kinds[self.key] = not page.kinds[self.key] or nil
			local keep = {}
			for k in pairs(page.kinds) do keep[k] = true end
			ns.db.ui.runeKinds = keep
			Main.Refresh()
		end)
		UI.Tip(bt, function() return UI.SimpleTip(ns.N(g.name) .. " 룬", "체크하면 이 종류의 룬이 지도에서 강조됩니다. 여러 종류를 함께 체크할 수 있습니다.") end)
		page.kindBoxes[#page.kindBoxes + 1] = bt
		x = x + 14 + 8 + t:GetStringWidth() + 14
	end
	local hint = UI.Text(key, 10, "휠: 확대·축소  ·  끌기: 이동")
	hint:SetPoint("RIGHT", key, "RIGHT", -8, 0)
	UI.Color(hint, UI.C.dim)
	page.key = key

	-- the card on the right
	local side = UI.Panel(page, SIDE_W, K.H, "card")
	side:SetPoint("TOPLEFT", page, "TOPLEFT", MAP_W + 10, 0)
	page.side = side
	local IW = SIDE_W - 28
	side.icon = UI.IconButton(side, 48)
	side.icon:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -14)
	side.icon:EnableMouse(false)
	side.name = UI.Title(side, "", 15)
	side.name:SetPoint("TOPLEFT", side, "TOPLEFT", 72, -18)
	side.name:SetWidth(SIDE_W - 86)
	side.name:SetWordWrap(false)
	side.lvl = UI.Text(side, 11)
	side.lvl:SetPoint("TOPLEFT", side, "TOPLEFT", 72, -42)
	UI.Color(side.lvl, UI.C.sub)
	side.now = UI.Text(side, 12)
	side.now:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -78)
	side.now:SetWidth(IW)
	side.nxt = UI.Text(side, 12)
	side.nxt:SetPoint("TOPLEFT", side.now, "BOTTOMLEFT", 0, -6)
	side.nxt:SetWidth(IW)
	side.req = UI.Text(side, 11)
	side.req:SetPoint("TOPLEFT", side.nxt, "BOTTOMLEFT", 0, -8)
	side.req:SetWidth(IW)
	side.req:SetJustifyV("TOP")
	side.goPrev = UI.Button(side, IW, 26, "먼저 배울 룬 보기", function()
		local step = R.NextStepTo(page.sel)
		if step then
			page.sel = step
			if page.focus then page.focus = step end -- the marker follows the way there
			centerOn(page, step)
		end
		Main.Refresh()
	end, "blue")
	side.goPrev:SetPoint("TOP", side, "TOP", 0, -196)
	side.buy = UI.Button(side, IW, 40, "", function()
		UI.Try(R.Buy(page.sel))
		Main.Refresh()
	end, "primary")
	side.buy:SetPoint("TOP", side, "TOP", 0, -228)
	side.buy.clickWhenOff = true
	side.totalHead = UI.Section(side, IW, "보너스 합계")
	side.totalHead:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -284)
	-- the list: TOTAL_ROWS lines from page.totalOff, and a scroll bar
	local box = CreateFrame("Frame", nil, side)
	box:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -310)
	box:SetSize(IW, TOTAL_ROWS * TOTAL_STEP)
	box:EnableMouseWheel(true)
	side.totalBox = box
	local function scrollTo(off)
		local n = page.totalN or 0
		local was = page.totalOff or 0
		page.totalOff = U.clamp(floor(off + 0.5), 0, max(0, n - TOTAL_ROWS))
		if page.totalOff ~= was then Main.Refresh() end
	end
	page.scrollTotal = scrollTo
	box:SetScript("OnMouseWheel", function(_, delta) scrollTo((page.totalOff or 0) - delta * 2) end)
	side.totalLines = {}
	for i = 1, TOTAL_ROWS do
		local t = UI.Text(box, 11)
		t:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(i - 1) * TOTAL_STEP - 1)
		t:SetWidth(IW - BAR_W - 8)
		t:SetWordWrap(false)
		side.totalLines[i] = t
	end
	local trackH = TOTAL_ROWS * TOTAL_STEP
	local track = CreateFrame("Button", nil, box)
	track:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	track:SetSize(BAR_W, trackH)
	track.bg = UI.Line3(track, "BACKGROUND")
	track.bg:Place(track, "TOP", true, 0, 0, trackH, 6)
	track.bg:SetColor(UI.BAR_DARK[1], UI.BAR_DARK[2], UI.BAR_DARK[3])
	-- a click on the bar above or below the thumb turns a page
	track:SetScript("OnClick", function(self)
		local _, cy = GetCursorPosition()
		cy = cy / self:GetEffectiveScale()
		local thumb = side.thumb
		local up = cy > (thumb:GetTop() or 0)
		scrollTo((page.totalOff or 0) + (up and -TOTAL_ROWS or TOTAL_ROWS))
	end)
	side.track = track
	local thumb = CreateFrame("Button", nil, track)
	thumb:SetWidth(BAR_W)
	thumb:SetFrameLevel(track:GetFrameLevel() + 1)
	thumb.bg = thumb:CreateTexture(nil, "ARTWORK")
	thumb.bg:SetPoint("TOP", thumb, "TOP", 0, 0)
	thumb.bg:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
	thumb.bg:SetWidth(10)
	UI.SetGrip(thumb.bg)
	thumb:SetScript("OnEnter", function(self) UI.SetGrip(self.bg, true) end)
	thumb:SetScript("OnLeave", function(self) if not self.drag then UI.SetGrip(self.bg) end end)
	thumb:SetScript("OnMouseDown", function(self)
		local _, cy = GetCursorPosition()
		self.drag = { y = cy / self:GetEffectiveScale(), off = page.totalOff or 0 }
		UI.SetGrip(self.bg, true)
	end)
	thumb:SetScript("OnMouseUp", function(self)
		self.drag = nil
		if not self:IsMouseOver() then UI.SetGrip(self.bg) end
	end)
	thumb:SetScript("OnUpdate", function(self)
		local d = self.drag
		if not d then return end
		if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self.drag = nil return end
		local _, cy = GetCursorPosition()
		cy = cy / self:GetEffectiveScale()
		local room = trackH - self:GetHeight()
		local extra = max(0, (page.totalN or 0) - TOTAL_ROWS)
		if room > 0 and extra > 0 then scrollTo(d.off + (d.y - cy) / room * extra) end
	end)
	side.thumb = thumb
	side.note = UI.Text(side, 10, "동료 보너스는 '동료' 화면에서 봅니다.")
	side.note:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 14, 12)
	side.note:SetWidth(IW)
	UI.Color(side.note, UI.C.dim)

	page.zoomAt = function(delta) zoomAt(page, delta) end
	page.centerOn = function(id) centerOn(page, id) end
	applyCamera(page)
end

local function refresh(page)
	local focusB
	-- the kinds checked under the map: their runes stand out, the rest fade
	local filtering = next(page.kinds) ~= nil
	for _, bt in ipairs(page.kindBoxes) do
		local on = page.kinds[bt.key] == true
		bt.mark:SetShown(on)
		bt.fill:SetShown(on)
	end
	for _, b in ipairs(page.nodes) do
		local node = b.node
		local id = node.id
		local lit = not filtering or page.kinds[node.group.key] == true
		b.halo:SetShown(filtering and lit)
		if b.link then b.link:SetAlpha(lit and 1 or 0.15) end
		local lvl, cost, open = R.Level(id), R.NextCost(id), R.Available(id)
		local afford = open and cost ~= nil and ns.CanAfford(cost)
		-- (redrawn only when it changed: the page refreshes with every gold change)
		local state = lvl * 4 + (open and 2 or 0) + (afford and 1 or 0)
		if b.state ~= state then
			b.state = state
			local rgb = open and borderRGB(node) or GREY
			b.border:SetVertexColor(rgb[1], rgb[2], rgb[3])
			b.border2:SetVertexColor(rgb[1], rgb[2], rgb[3])
			b.icon:SetDesaturated(not open)
			local full = lvl >= node.max
			b.check:SetShown(full)
			b.lvl:SetText(full and "" or (lvl .. "/" .. node.max))
			b.lvl:SetTextColor(lvl > 0 and 1 or 0.62, lvl > 0 and 1 or 0.65, lvl > 0 and 1 or 0.72)
			b.glow:SetShown(afford)
			if b.link then
				if open then
					b.link:SetColorTexture(rgb[1] * 0.8, rgb[2] * 0.8, rgb[3] * 0.8, 0.95)
				else
					b.link:SetColorTexture(0.24, 0.26, 0.31, 0.9)
				end
			end
		end
		-- a faded rune: what it shows fades, its dark backing stays solid,
		-- so the lines behind it stay hidden
		local k = lit and 1 or 0.18
		b.icon:SetAlpha((open and 1 or 0.45) * k)
		b.border:SetAlpha(k)
		b.border2:SetAlpha(k)
		b.check:SetAlpha(k)
		b.lvl:SetAlpha(k)
		b.glow:SetAlpha(0.85 * k)
		if page.focus == id then focusB = b end
		if page.sel == id then b.sel:Show() elseif not b:IsMouseOver() then b.sel:Hide() end
	end
	local fx = page.focusFx
	if focusB then
		fx:ClearAllPoints()
		fx:SetPoint("CENTER", focusB, "CENTER", 0, 0)
		fx:Show()
	else
		fx:Hide()
	end

	local side = page.side
	local id = page.sel
	local node = R.byId[id]
	local lvl, cost, open = R.Level(id), R.NextCost(id), R.Available(id)
	local g = node.group
	side.icon:SetIconName(node.icon)
	local rgb = open and borderRGB(node) or GREY
	side.icon:SetBorderRGB(rgb[1], rgb[2], rgb[3])
	side.name:SetText(ns.N(node.name))
	side.lvl:SetText(U.col(U.hex(g.rgb[1], g.rgb[2], g.rgb[3]), ns.N(g.name)) .. "  ·  " .. string.format("레벨 %d / %d", lvl, node.max))
	side.now:SetText("현재  " .. (lvl > 0 and U.col("6af07a", R.Text(id, R.Amount(id, lvl))) or U.col("8a90a2", "배우지 않음")))
	side.nxt:SetText(lvl < node.max and ("다음 레벨  " .. U.col("ffffff", R.Text(id, R.Amount(id, lvl + 1)))) or U.col("6af07a", "최대 레벨입니다"))
	if not open then
		local step, total = R.NextStepTo(id)
		local first = R.byId[step]
		side.req:SetText(U.col("ff6a5a", string.format("먼저 '%s'을(를) %d레벨까지 배워야 합니다.", ns.N(R.byId[R.prev[id]].name), R.Need(id)))
			.. "\n" .. U.col("aab3c8", string.format("다음에 배울 룬: '%s' (%s G)", ns.N(first.name), U.fmt(R.NextCost(step) or 0)))
			.. "\n" .. U.col("aab3c8", string.format("여기까지 모두 %s G", U.fmt(total))))
		side.goPrev:Show()
	else
		side.req:SetText("")
		side.goPrev:Hide()
	end
	if cost then
		side.buy:SetLabel("배우기  " .. U.fmt(cost) .. " G")
		side.buy:SetOff(not open or not ns.CanAfford(cost))
	else
		side.buy:SetLabel("최대 레벨")
		side.buy:SetOff(true)
	end

	-- every learned rune added up, by what it gives (companions have their own screen)
	local sums, some = {}, {}
	for rid, lv in pairs(ns.db.runes) do
		local n = R.byId[rid]
		if n and lv > 0 then
			sums[n.kind] = (sums[n.kind] or 0) + R.Amount(rid, lv)
			some[n.kind] = some[n.kind] or rid
		end
	end
	local kinds = {}
	for k in pairs(sums) do kinds[#kinds + 1] = k end
	-- grouped like the key under the map, then by what they read
	local order = {}
	for i, gr in ipairs(ns.RUNE_GROUPS) do order[gr.key] = i end
	local texts = {}
	for _, k in ipairs(kinds) do texts[k] = R.Text(some[k], sums[k], true) end
	table.sort(kinds, function(a, b)
		local ga, gb = order[R.byId[some[a]].group.key], order[R.byId[some[b]].group.key]
		if ga ~= gb then return ga < gb end
		return texts[a] < texts[b]
	end)
	local parts = {}
	for _, k in ipairs(kinds) do
		local gr = R.byId[some[k]].group
		parts[#parts + 1] = U.col(U.hex(gr.rgb[1], gr.rgb[2], gr.rgb[3]), "■ ") .. texts[k]
	end
	if #parts == 0 then parts[1] = U.col("8a90a2", "아직 배운 룬이 없습니다.") end
	local n = #parts
	page.totalN = n
	page.totalOff = U.clamp(page.totalOff or 0, 0, max(0, n - TOTAL_ROWS))
	for i, t in ipairs(side.totalLines) do t:SetText(parts[page.totalOff + i] or "") end
	local over = n > TOTAL_ROWS
	side.track:SetShown(over)
	if over then
		local trackH = TOTAL_ROWS * TOTAL_STEP
		local th = U.clamp(floor(trackH * TOTAL_ROWS / n), UI.GRIP_MIN, UI.GRIP_MAX)
		side.thumb:SetHeight(th)
		side.thumb:ClearAllPoints()
		side.thumb:SetPoint("TOP", side.track, "TOP", 0, -floor((trackH - th) * page.totalOff / (n - TOTAL_ROWS) + 0.5))
	end
end

local function open(page, opts)
	if opts and opts.rune and R.byId[opts.rune] then
		page.sel = opts.rune
		page.focus = opts.rune
		centerOn(page, opts.rune)
	else
		page.focus = nil -- opened from the menu: nothing to point at
	end
end

Main.RegisterTab({
	key = "runes", title = "룬", sub = "골드로 배우는 계정 전체 강화입니다",
	icon = "INV_Misc_Rune_01", art = "icon_runes", build = build, refresh = refresh, open = open,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
