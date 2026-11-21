-- Runes (룬): the root rune on top, the six branches as columns underneath
-- (전쟁 · 수호 · 재물 · 성장 · 탐험 · 지휘), each rune with its level and the
-- cost of the next one. Click a rune to see it in the card on the right and
-- learn it there; the card also lists the total of every learned rune
-- (a list that scrolls: mouse wheel, the bar on its right, or dragging the
-- bar's thumb).
-- A branch is its first rune and two lines that fork from it: the first
-- line runs straight down under it, the second follows, joined to the
-- first rune by a line along the column's left edge. So every rune's
-- requirement is the rune it is drawn joined to, above it.
-- Another screen can send the player to a rune ("…을(를) 배우면 열립니다 ·
-- 클릭: 룬 화면에서 보기"): that rune gets a red band behind its row, a red
-- glow and thick red rings, all pulsing, until another rune is picked.
local _, ns = ...

local floor, max = math.floor, math.max
local UI, U = ns.UI, ns.U
local Main = ns.Main
local R = ns.Runes
local K = UI.K

local COL_W = 112             -- one branch
local COL_X = 10              -- room for the second line's joint on the left
local NODE = 36               -- a rune
local ROW_H = 45              -- between runes in a column
local HEAD_Y = -50            -- the branch names
local TOP = -78               -- the first rune of each branch
local SIDE_X = COL_X + 6 * COL_W + 6 -- the card on the right
local SIDE_W = K.W - SIDE_X
local TEXT_W = COL_W - NODE - 10
local TOTAL_ROWS, TOTAL_STEP = 14, 15 -- the 보너스 합계 list
local BAR_W = 6

local function runeNode(page, node, x, y)
	local b = CreateFrame("Button", nil, page)
	b:SetSize(NODE, NODE)
	b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	-- layers: the marker's band (+1) < runes (+2) < their texts (+3) < the marker's rings (+5)
	b:SetFrameLevel(page:GetFrameLevel() + 2)
	b.disc = UI.Art(b, "circle", "BACKGROUND", 0.05, 0.06, 0.1)
	b.disc:SetAllPoints(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
	UI.SetIcon(b.icon, node.icon)
	b.ringT = UI.Art(b, "ring", "OVERLAY")
	b.ringT:SetAllPoints(b)
	b.hl = UI.Art(b, "glow", "BACKGROUND", 1, 0.85, 0.35, 0.9)
	b.hl:SetPoint("TOPLEFT", b, "TOPLEFT", -10, 10)
	b.hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 10, -10)
	b.hl:Hide()
	b.text = UI.Text(page.textLayer, 11)
	b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
	b.text:SetWidth(TEXT_W)
	b.text:SetJustifyH("LEFT")
	b.badge = UI.Badge(b, 14)
	b.node = node
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		ns.Sound("click")
		page.sel = self.node.id
		if page.focus ~= self.node.id then page.focus = nil end
		Main.Refresh()
	end)
	b.onEnter = function(self) self.hl:Show() end
	b.onLeave = function(self) if page.sel ~= self.node.id or page.focus == self.node.id then self.hl:Hide() end end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	UI.Tip(b, function(self)
		local n = self.node
		local lvl, cost = R.Level(n.id), R.NextCost(n.id)
		local lines = { { ns.N(n.name), string.format("%d / %d", lvl, n.max), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
			{ "레벨당 " .. ns.BonusText(n.stat, n.per), nil, 1, 1, 1 } }
		if lvl > 0 then lines[#lines + 1] = { "지금 " .. ns.BonusText(n.stat, n.per * lvl), nil, 0.4, 1, 0.45 } end
		if not R.Available(n.id) then
			local step = R.NextStepTo(n.id)
			local first = step and R.byId[step]
			lines[#lines + 1] = { first and string.format("먼저 '%s'을(를) 배워야 합니다", ns.N(first.name)) or "먼저 위의 룬을 배워야 합니다", nil, 1, 0.55, 0.45 }
		elseif cost then
			lines[#lines + 1] = { "다음 레벨", U.fmt(cost) .. " G", 0.8, 0.8, 0.85 }
		end
		lines[#lines + 1] = { "클릭: 오른쪽에서 보기", nil, 0.45, 0.8, 1 }
		return lines
	end, "TOP")
	return b
end

local function build(page)
	page.sel = "root"
	page.textLayer = CreateFrame("Frame", nil, page)
	page.textLayer:SetAllPoints(page)
	page.textLayer:SetFrameLevel(page:GetFrameLevel() + 3)
	page.nodes = {}
	-- the root, over the middle of the branches
	page.root = runeNode(page, ns.RUNE_ROOT, COL_X + 3 * COL_W - NODE / 2 - 4, -4)
	page.nodes[1] = page.root

	local function bar(x, y, w, h, r, g, b)
		local t = page:CreateTexture(nil, "BORDER")
		t:SetSize(w, h)
		t:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
		UI.Fill(t, r * 0.5, g * 0.5, b * 0.5, 0.9)
		return t
	end
	for ci, br in ipairs(ns.RUNE_BRANCHES) do
		local x = COL_X + (ci - 1) * COL_W
		local r, g, b = U.rgb(br.hex)
		local head = UI.Pill(page, COL_W - 10, 22, r * 0.45, g * 0.45, b * 0.45, 0.95)
		head:SetLabel(ns.N(br.name))
		head:SetPoint("TOPLEFT", page, "TOPLEFT", x, HEAD_Y)
		-- the column: the first rune, its first line, then its second line
		local hub = br.nodes[1]
		local lines = ns.RUNE_TREE[br.key]
		local order = { { node = hub } }
		for li, line in ipairs(lines) do
			for k, id in ipairs(line) do order[#order + 1] = { node = R.byId[id], line = li, first = (k == 1) } end
		end
		local hubY = TOP
		for ri, e in ipairs(order) do
			local y = TOP - (ri - 1) * ROW_H
			local links
			if ri > 1 then
				if e.line == 2 and e.first then
					-- joined to the first rune along the left edge, past the first line
					local gx = x - 7
					links = {
						bar(gx, hubY - NODE / 2 + 1, 7, 3, r, g, b),
						bar(gx, hubY - NODE / 2 + 1, 3, (hubY - y) + 3, r, g, b),
						bar(gx, y - NODE / 2 + 1, 7, 3, r, g, b),
					}
				else
					links = { bar(x + NODE / 2 - 1, y + ROW_H - NODE + 1, 3, ROW_H - NODE + 2, r, g, b) }
				end
			end
			local nb = runeNode(page, e.node, x, y)
			nb.links = links
			page.nodes[#page.nodes + 1] = nb
		end
	end

	-- the rune another screen sent us to:
	--   behind the row (under the rune and its text): a red band and a red
	--   glow, both breathing; over the rune: thick red rings that grow and
	--   shrink. The icon and the text stay readable.
	local back = CreateFrame("Frame", nil, page)
	back:SetSize(COL_W - 4, NODE + 10)
	back:SetFrameLevel(page:GetFrameLevel() + 1)
	back.isOverlay = true
	back.band = UI.Slice(back, "pill", "BACKGROUND", 0)
	back.band:SetColor(0.85, 0.08, 0.06, 0.5)
	back.glow = UI.Art(back, "glow", "BORDER", 1, 0.15, 0.1, 1)
	back.glow:SetSize(NODE + 44, NODE + 44)
	back.glow:SetPoint("CENTER", back, "LEFT", 4 + NODE / 2, 0)
	back:Hide()
	page.focusBack = back

	local fx = CreateFrame("Frame", nil, page)
	fx:SetSize(NODE + 10, NODE + 10)
	fx:SetFrameLevel(page:GetFrameLevel() + 5)
	fx.isOverlay = true -- drawn over its rune on purpose
	-- rings only: the rune's icon stays visible inside
	fx.rings = {}
	for i, c in ipairs({ { 1, 0.12, 0.08 }, { 1, 0.3, 0.22 }, { 1, 0.55, 0.45 } }) do
		local t = UI.Art(fx, "ring", "OVERLAY", c[1], c[2], c[3])
		t:SetPoint("TOPLEFT", fx, "TOPLEFT", i - 1, -(i - 1))
		t:SetPoint("BOTTOMRIGHT", fx, "BOTTOMRIGHT", -(i - 1), i - 1)
		fx.rings[i] = t
	end
	fx:SetScript("OnUpdate", function(self)
		local s = 0.5 + 0.5 * math.sin((GetTime and GetTime() or 0) * 5)
		local size = NODE + 8 + 8 * s -- 4 to 8 pixels around the rune
		self:SetSize(size, size)
		for _, t in ipairs(self.rings) do t:SetAlpha(0.7 + 0.3 * s) end
		back:SetAlpha(0.45 + 0.55 * s) -- the band and the glow breathe together
	end)
	fx:Hide()
	page.focusFx = fx

	-- the card on the right
	local side = UI.Panel(page, SIDE_W, K.H, "card")
	side:SetPoint("TOPLEFT", page, "TOPLEFT", SIDE_X, 0)
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
	side.per = UI.Text(side, 12)
	side.per:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -80)
	side.per:SetWidth(IW)
	side.now = UI.Text(side, 12)
	side.now:SetPoint("TOPLEFT", side.per, "BOTTOMLEFT", 0, -6)
	side.now:SetWidth(IW)
	side.req = UI.Text(side, 11)
	side.req:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -124)
	side.req:SetWidth(IW)
	side.req:SetJustifyV("TOP")
	side.goPrev = UI.Button(side, IW, 26, "먼저 배울 룬 보기", function()
		local step = R.NextStepTo(page.sel)
		if step then
			page.sel = step
			if page.focus then page.focus = step end -- the marker follows the way there
		end
		Main.Refresh()
	end, "blue")
	side.goPrev:SetPoint("TOP", side, "TOP", 0, -186)
	side.buy = UI.Button(side, IW, 40, "", function()
		UI.Try(R.Buy(page.sel))
		Main.Refresh()
	end, "primary")
	side.buy:SetPoint("TOP", side, "TOP", 0, -220)
	side.buy.clickWhenOff = true
	side.totalHead = UI.Section(side, IW, "보너스 합계")
	side.totalHead:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -278)
	-- the list: TOTAL_ROWS lines from page.totalOff, and a scroll bar
	local box = CreateFrame("Frame", nil, side)
	box:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -304)
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
	track.bg = track:CreateTexture(nil, "BACKGROUND")
	track.bg:SetAllPoints(track)
	UI.Fill(track.bg, 1, 1, 1, 0.10)
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
	thumb.bg:SetAllPoints(thumb)
	UI.Fill(thumb.bg, 1, 0.82, 0.3, 0.8)
	thumb:SetScript("OnMouseDown", function(self)
		local _, cy = GetCursorPosition()
		self.drag = { y = cy / self:GetEffectiveScale(), off = page.totalOff or 0 }
	end)
	thumb:SetScript("OnMouseUp", function(self) self.drag = nil end)
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
end

local function nodeState(id)
	local node = R.byId[id]
	local lvl = R.Level(id)
	local cost = R.NextCost(id)
	return node, lvl, cost, R.Available(id)
end

local function refresh(page)
	local focusB
	for _, b in ipairs(page.nodes) do
		local node, lvl, cost, available = nodeState(b.node.id)
		local affordable = cost and available and ns.CanAfford(cost)
		if lvl >= node.max then
			b.ringT:SetVertexColor(0.4, 0.95, 0.5)
		elseif affordable then
			b.ringT:SetVertexColor(1, 0.82, 0.3)
		elseif lvl > 0 then
			b.ringT:SetVertexColor(0.45, 0.7, 1)
		else
			b.ringT:SetVertexColor(0.3, 0.33, 0.42)
		end
		b.icon:SetDesaturated(not available)
		b.icon:SetAlpha(available and 1 or 0.45)
		for _, l in ipairs(b.links or {}) do l:SetAlpha(lvl > 0 and 1 or 0.35) end
		local line = U.col(lvl >= node.max and "6af07a" or (lvl > 0 and "ffffff" or "8a90a2"), lvl .. "/" .. node.max)
		if cost then
			line = line .. "\n" .. U.col(affordable and "ffd24a" or "7a6a40", U.fmt(cost))
		end
		b.text:SetText(line)
		b.badge:Set(affordable and lvl == 0)
		if page.focus == b.node.id then
			b.hl:Hide()
			b.ringT:SetVertexColor(1, 0.25, 0.2) -- its own border turns red too
			focusB = b
		elseif page.sel == b.node.id then b.hl:Show() elseif not b:IsMouseOver() then b.hl:Hide() end
	end
	local fx, back = page.focusFx, page.focusBack
	if focusB then
		fx:ClearAllPoints()
		fx:SetPoint("CENTER", focusB, "CENTER", 0, 0)
		fx:Show()
		back:ClearAllPoints()
		back:SetPoint("LEFT", focusB, "LEFT", -5, 0)
		back:Show()
	else
		fx:Hide()
		back:Hide()
	end

	local side = page.side
	local node, lvl, cost, available = nodeState(page.sel)
	side.icon:SetIconName(node.icon)
	side.icon:SetBorderRGB(lvl > 0 and 0.45 or 0.3, lvl > 0 and 0.7 or 0.33, lvl > 0 and 1 or 0.42)
	side.name:SetText(ns.N(node.name))
	side.lvl:SetText(string.format("레벨 %d / %d", lvl, node.max))
	side.per:SetText("레벨당  " .. U.col("ffffff", ns.BonusText(node.stat, node.per)))
	side.now:SetText(lvl > 0 and ("현재  " .. U.col("6af07a", ns.BonusText(node.stat, node.per * lvl))) or "")
	if not available then
		local step, total = R.NextStepTo(page.sel)
		local first = R.byId[step]
		side.req:SetText(U.col("ff6a5a", string.format("먼저 '%s'(%s G)을(를) 배워야 합니다.", ns.N(first.name), U.fmt(R.NextCost(step) or 0)))
			.. "\n" .. U.col("aab3c8", string.format("여기까지 모두 %s G", U.fmt(total))))
		side.goPrev:Show()
	else
		side.req:SetText("")
		side.goPrev:Hide()
	end
	if cost then
		side.buy:SetLabel("배우기  " .. U.fmt(cost) .. " G")
		side.buy:SetOff(not available or not ns.CanAfford(cost))
	else
		side.buy:SetLabel("최대 레벨")
		side.buy:SetOff(true)
	end

	-- every learned rune added up (companions have their own screen)
	local sums = {}
	for id, lv in pairs(ns.db.runes) do
		local n = R.byId[id]
		if n and lv > 0 then sums[n.stat] = (sums[n.stat] or 0) + n.per * lv end
	end
	local keys = {}
	for k in pairs(sums) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = ns.BonusText(k, sums[k]) end
	if #parts == 0 then parts[1] = U.col("8a90a2", "아직 배운 룬이 없습니다.") end
	local n = #parts
	page.totalN = n
	page.totalOff = U.clamp(page.totalOff or 0, 0, max(0, n - TOTAL_ROWS))
	for i, t in ipairs(side.totalLines) do t:SetText(parts[page.totalOff + i] or "") end
	local over = n > TOTAL_ROWS
	side.track:SetShown(over)
	if over then
		local trackH = TOTAL_ROWS * TOTAL_STEP
		local th = max(18, floor(trackH * TOTAL_ROWS / n))
		side.thumb:SetHeight(th)
		side.thumb:ClearAllPoints()
		side.thumb:SetPoint("TOP", side.track, "TOP", 0, -floor((trackH - th) * page.totalOff / (n - TOTAL_ROWS) + 0.5))
	end
end

local function open(page, opts)
	if opts and opts.rune and R.byId[opts.rune] then
		page.sel = opts.rune
		page.focus = opts.rune
	else
		page.focus = nil -- opened from the menu: nothing to point at
	end
end

Main.RegisterTab({
	key = "runes", title = "룬", sub = "골드로 배우는 계정 전체 강화입니다",
	icon = "INV_Misc_Rune_01", art = "icon_runes", build = build, refresh = refresh, open = open,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
