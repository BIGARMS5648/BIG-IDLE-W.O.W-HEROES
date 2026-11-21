-- Runes (룬): the root rune on top, the six branches as columns underneath
-- (전쟁 · 수호 · 재물 · 성장 · 탐험 · 지휘), each rune with its level and the
-- cost of the next one. Click a rune to see it in the card on the right and
-- learn it there; the card also lists the total of every learned rune.
-- Inside a column every rune's requirement sits above it.
local _, ns = ...

local floor, max = math.floor, math.max
local UI, U = ns.UI, ns.U
local Main = ns.Main
local R = ns.Runes
local K = UI.K

local COL_W = 112             -- one branch
local NODE = 36               -- a rune
local ROW_H = 45              -- between runes in a column
local HEAD_Y = -50            -- the branch names
local TOP = -78               -- the first rune of each branch
local SIDE_X = 6 * COL_W + 8  -- the card on the right
local SIDE_W = K.W - SIDE_X
local TEXT_W = COL_W - NODE - 10

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
	b.text = UI.Text(page, 11)
	b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
	b.text:SetWidth(TEXT_W)
	b.text:SetJustifyH("LEFT")
	b.badge = UI.Badge(b, 14)
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
	page.nodes = {}
	-- the root, over the middle of the branches
	page.root = runeNode(page, ns.RUNE_ROOT, 3 * COL_W - NODE / 2 - 4, -4)
	page.nodes[1] = page.root

	for ci, br in ipairs(ns.RUNE_BRANCHES) do
		local x = (ci - 1) * COL_W
		local r, g, b = U.rgb(br.hex)
		local head = UI.Pill(page, COL_W - 10, 22, r * 0.45, g * 0.45, b * 0.45, 0.95)
		head:SetLabel(ns.N(br.name))
		head:SetPoint("TOPLEFT", page, "TOPLEFT", x, HEAD_Y)
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
		if step then page.sel = step end
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
	side.total = UI.Text(side, 11)
	side.total:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -306)
	side.total:SetWidth(IW)
	side.total:SetJustifyV("TOP")
	side.total:SetSpacing(2)
	if side.total.SetMaxLines then side.total:SetMaxLines(16) end
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
	side.total:SetText(#parts > 0 and table.concat(parts, "\n") or U.col("8a90a2", "아직 배운 룬이 없습니다."))
end

local function open(page, opts)
	if opts and opts.rune and R.byId[opts.rune] then page.sel = opts.rune end
end

Main.RegisterTab({
	key = "runes", title = "룬", sub = "골드로 배우는 계정 전체 강화입니다",
	icon = "INV_Misc_Rune_01", art = "icon_runes", build = build, refresh = refresh, open = open,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
