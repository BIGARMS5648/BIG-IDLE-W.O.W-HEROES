-- Rune tree: a root rune and six branches, bought with gold. Tap a rune to
-- see it in the side card and learn it there.
local _, ns = ...

local floor = math.floor
local UI, U = ns.UI, ns.U
local Main = ns.Main
local R = ns.Runes

local COL_W = 104
local NODE = 34
local ROW_H = 38
local TOP = -60
local SIDE_X = 6 * COL_W + 8

local function runeNode(page, node, x, y)
	local b = CreateFrame("Button", nil, page)
	b:SetSize(NODE, NODE)
	b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
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
	b.text = UI.Text(page, 10)
	b.text:SetPoint("LEFT", b, "RIGHT", 4, 0)
	b.text:SetWidth(COL_W - NODE - 6)
	b.badge = UI.Badge(b, 12)
	b.node = node
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		ns.Sound("click")
		page.sel = self.node.id
		Main.Refresh()
	end)
	b.onEnter = function(self) self.hl:Show() end
	b.onLeave = function(self) if page.sel ~= self.node.id then self.hl:Hide() end end
	b:SetScript("OnEnter", function(self) self.onEnter(self) end)
	b:SetScript("OnLeave", function(self) self.onLeave(self) end)
	return b
end

local function build(page)
	page.sel = "root"
	page.nodes = {}
	-- root, centered over the branches
	page.root = runeNode(page, ns.RUNE_ROOT, 3 * COL_W - NODE / 2 - 4, 0)
	page.nodes[1] = page.root
	page.root.text:ClearAllPoints()
	page.root.text:SetPoint("LEFT", page.root, "RIGHT", 6, 0)
	page.root.text:SetWidth(120)

	for ci, br in ipairs(ns.RUNE_BRANCHES) do
		local x = (ci - 1) * COL_W
		local r, g, b = U.rgb(br.hex)
		local head = UI.Pill(page, COL_W - 8, 20, r * 0.45, g * 0.45, b * 0.45, 0.95)
		head:SetLabel(ns.N(br.name))
		head:SetPoint("TOPLEFT", page, "TOPLEFT", x, TOP + 24)
		for ri, node in ipairs(br.nodes) do
			local y = TOP - (ri - 1) * ROW_H
			local link
			if ri > 1 then
				link = page:CreateTexture(nil, "BORDER")
				link:SetSize(3, ROW_H - NODE + 2)
				link:SetPoint("TOPLEFT", page, "TOPLEFT", x + NODE / 2 - 1, y + ROW_H - NODE + 1)
				UI.Fill(link, r * 0.5, g * 0.5, b * 0.5, 0.9)
			end
			local nb = runeNode(page, node, x, y)
			nb.link = link
			page.nodes[#page.nodes + 1] = nb
		end
	end

	-- side card
	local side = UI.Panel(page, Main.PAGE_W - SIDE_X, Main.PAGE_H, "card")
	side:SetPoint("TOPLEFT", page, "TOPLEFT", SIDE_X, 0)
	page.side = side
	side.icon = UI.IconButton(side, 48)
	side.icon:SetPoint("TOPLEFT", side, "TOPLEFT", 12, -12)
	side.icon:EnableMouse(false)
	side.name = UI.Title(side, "", 14)
	side.name:SetPoint("TOPLEFT", side, "TOPLEFT", 68, -14)
	side.name:SetWidth(150)
	side.lvl = UI.Text(side, 11)
	side.lvl:SetPoint("TOPLEFT", side, "TOPLEFT", 68, -36)
	UI.Color(side.lvl, UI.C.sub)
	side.per = UI.Text(side, 11)
	side.per:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -74)
	side.per:SetWidth(200)
	side.now = UI.Text(side, 11)
	side.now:SetPoint("TOPLEFT", side.per, "BOTTOMLEFT", 0, -6)
	side.now:SetWidth(200)
	side.req = UI.Text(side, 11)
	side.req:SetPoint("TOPLEFT", side.now, "BOTTOMLEFT", 0, -8)
	side.req:SetWidth(200)
	side.buy = UI.Button(side, 200, 40, "", function()
		UI.Try(R.Buy(page.sel))
		Main.Refresh()
	end, "primary")
	side.buy:SetPoint("TOP", side, "TOP", 0, -172)
	side.totalTitle = UI.Title(side, "보너스 합계", 12)
	side.totalTitle:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -228)
	side.total = UI.Text(side, 10)
	side.total:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -248)
	side.total:SetWidth(200)
	side.total:SetJustifyV("TOP")
	side.total:SetMaxLines(14)
end

local function nodeState(id)
	local node = R.byId[id]
	local lvl = R.Level(id)
	local cost = R.NextCost(id)
	return node, lvl, cost, R.Available(id)
end

local function refresh(page)
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
		if b.link then b.link:SetAlpha(lvl > 0 and 1 or 0.35) end
		local line = U.col(lvl >= node.max and "6af07a" or (lvl > 0 and "ffffff" or "8a90a2"), lvl .. "/" .. node.max)
		if cost then
			line = line .. "\n" .. U.col(affordable and "ffd24a" or "7a6a40", U.fmt(cost))
		end
		b.text:SetText(line)
		b.badge:Set(affordable and lvl == 0)
		if page.sel == b.node.id then b.hl:Show() elseif not b:IsMouseOver() then b.hl:Hide() end
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
		local prev = R.byId[R.prev[page.sel]]
		side.req:SetText(U.col("ff6a5a", string.format("먼저 '%s'을(를) 배워야 합니다.", ns.N(prev.name))))
	else
		side.req:SetText("")
	end
	if cost then
		side.buy:SetLabel("배우기  " .. U.fmt(cost) .. " G")
		side.buy:SetOff(not available or not ns.CanAfford(cost))
	else
		side.buy:SetLabel("최대 레벨")
		side.buy:SetOff(true)
	end

	local keys = {}
	for k in pairs(R.All()) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local v = ns.Bonus(k)
		if v ~= 0 then parts[#parts + 1] = ns.BonusText(k, v) end
	end
	side.total:SetText(#parts > 0 and table.concat(parts, "\n") or "아직 배운 룬이 없습니다.")
end

local function open(page, opts)
	if opts and opts.rune and R.byId[opts.rune] then page.sel = opts.rune end
end

Main.RegisterTab({
	key = "runes", title = "룬", sub = "골드로 배우는 계정 전체 강화입니다",
	icon = "INV_Misc_Rune_01", build = build, refresh = refresh, open = open,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
