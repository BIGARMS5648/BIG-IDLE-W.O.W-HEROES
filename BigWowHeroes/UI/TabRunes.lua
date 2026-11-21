-- Runes (룬): the whole rune tree on one page.
--   top: gold, runes learned, and the total of every learned rune;
--   tree: the root rune in the middle; three branches on each side, each a
--         hub rune that forks into two lines going outward. Lines turn gold
--         as runes are learned; "2/5" (or 완료) under every rune;
--   bottom: the chosen rune, and the gold button that learns it.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local R = ns.Runes
local K = UI.K

local TREE_Y, BAR_H = -36, 64
local TREE_H = K.H + TREE_Y - BAR_H - 8
local NODE = 38
local LINE_GAP = 32     -- the two lines sit this far above and below the hub
local STEP = 64         -- between runes on a line
local CX, CY = floor(K.W / 2), floor(TREE_H / 2) -- the root, in tree coordinates (y down)
local ROW = 134         -- hub rows above and below the middle one
local SIDE = {          -- branch -> side (-1 left, 1 right) and row (y of its hub)
	growth = { -1, CY - ROW }, war = { -1, CY }, wealth = { -1, CY + ROW },
	explore = { 1, CY - ROW }, guard = { 1, CY }, command = { 1, CY + ROW },
}
local HUB_DX = 96       -- root to hub
local BUS_DX = 52       -- root to the vertical line that feeds the top and bottom hubs
local LIT = { 1, 0.80, 0.30, 0.95 }
local DARK = { 0.30, 0.33, 0.42, 0.85 }

------------------------------------------------------------------------
-- Totals (modal)
------------------------------------------------------------------------
local totals = {}

local function openTotals()
	if not totals.frame then
		local c = Main.ModalContent(540, 380)
		totals.frame = c
		local t = UI.Title(c, "배운 룬 보너스 합계", 18)
		t:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		totals.rows = {}
		for i = 1, 24 do
			local col, row = (i <= 12) and 0 or 1, (i - 1) % 12
			local r = UI.StatRow(c, 260)
			r:SetPoint("TOPLEFT", c, "TOPLEFT", col * 280, -34 - row * 24)
			totals.rows[i] = r
		end
		totals.none = UI.Text(c, K.F_BODY, "아직 배운 룬이 없습니다.")
		totals.none:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -40)
		UI.Color(totals.none, UI.C.sub)
		local note = UI.Text(c, K.F_SMALL, "동료 보너스는 '편성 > 동료'에서 봅니다.")
		note:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 10)
		UI.Color(note, UI.C.dim)
		local close = UI.Button(c, 120, K.BTN_H, "닫기", function() Main.CloseModal() end, "dark")
		close:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	end
	local sums = {}
	for id, lv in pairs(ns.db.runes) do
		local n = R.byId[id]
		if n and lv > 0 then sums[n.stat] = (sums[n.stat] or 0) + n.per * lv end
	end
	local keys = {}
	for k in pairs(sums) do keys[#keys + 1] = k end
	table.sort(keys)
	for i, r in ipairs(totals.rows) do
		local k = keys[i]
		if k then r:Set(ns.BonusText(k, sums[k]), "") r:Show() else r:Hide() end
	end
	totals.none:SetShown(#keys == 0)
	Main.ShowModal(totals.frame)
end

------------------------------------------------------------------------
-- Tree geometry
------------------------------------------------------------------------
-- Where every rune sits (tree coordinates, y down), and the links.
local function layout()
	local pos = { root = { CX, CY } }
	-- { ids (lit when any of them is learned), points... } drawn as straight segments
	local links = {}
	local sideHubs = { [-1] = {}, [1] = {} }
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		local side = SIDE[br.key][1]
		table.insert(sideHubs[side], br.nodes[1].id)
	end
	-- root to the bus on each side (shared by that side's three branches)
	for _, side in ipairs({ -1, 1 }) do
		links[#links + 1] = { sideHubs[side], { CX + side * NODE / 2, CY }, { CX + side * BUS_DX, CY } }
	end
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		local side, hy = SIDE[br.key][1], SIDE[br.key][2]
		local hub = br.nodes[1].id
		local hx = CX + side * HUB_DX
		local bx = CX + side * BUS_DX
		pos[hub] = { hx, hy }
		-- from the bus (up or down it if needed) into the hub
		if hy == CY then
			links[#links + 1] = { { hub }, { bx, CY }, { hx - side * NODE / 2, CY } }
		else
			links[#links + 1] = { { hub }, { bx, CY }, { bx, hy }, { hx - side * NODE / 2, hy } }
		end
		local elbow = hx + side * (NODE / 2 + (STEP - NODE) / 2)
		for li, line in ipairs(ns.RUNE_TREE[br.key]) do
			local y = hy + (li == 1 and -LINE_GAP or LINE_GAP)
			for k, id in ipairs(line) do
				local x = hx + side * k * STEP
				pos[id] = { x, y }
				if k == 1 then
					links[#links + 1] = { { id }, { hx + side * NODE / 2, hy }, { elbow, hy }, { elbow, y }, { x - side * NODE / 2, y } }
				else
					links[#links + 1] = { { id }, { x - side * (STEP - NODE / 2), y }, { x - side * NODE / 2, y } }
				end
			end
		end
	end
	return pos, links
end

-- An axis-aligned segment as a thin texture.
local function segment(parent, a, b)
	local t = parent:CreateTexture(nil, "BORDER")
	local x1, x2 = min(a[1], b[1]), max(a[1], b[1])
	local y1, y2 = min(a[2], b[2]), max(a[2], b[2])
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x1 - 1.5, -(y1 - 1.5))
	t:SetSize(max(3, x2 - x1 + 3), max(3, y2 - y1 + 3))
	return t
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function build(page)
	page.sel = "root"
	page.heading = UI.Text(page, 13)
	page.heading:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -8)
	page.heading:SetWidth(600)
	page.heading:SetWordWrap(false)
	UI.Color(page.heading, UI.C.gold)
	page.totalBtn = UI.Button(page, 150, K.TAB_H, "보너스 합계", openTotals, "dark")
	page.totalBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	UI.Tip(page.totalBtn, function() return UI.SimpleTip("보너스 합계", "지금까지 배운 모든 룬의 효과를 모아 봅니다.") end, "TOP")

	local tree = UI.Panel(page, K.W, TREE_H, "inset")
	tree:SetPoint("TOPLEFT", page, "TOPLEFT", 0, TREE_Y)
	page.tree = tree
	local pos, links = layout()
	page.links = {}
	for _, l in ipairs(links) do
		local parts = {}
		for i = 2, #l - 1 do parts[#parts + 1] = segment(tree, l[i], l[i + 1]) end
		page.links[#page.links + 1] = { ids = l[1], parts = parts }
	end
	-- branch names above the hubs
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		local p = pos[br.nodes[1].id]
		local t = UI.Text(tree, K.F_SMALL, ns.N(br.name))
		t:SetPoint("BOTTOM", tree, "TOPLEFT", p[1], -(p[2] - NODE / 2 - 2))
		t:SetJustifyH("CENTER")
		t:SetTextColor(U.rgb(br.hex))
	end
	page.nodes = {}
	for id, p in pairs(pos) do
		local node = R.byId[id]
		local b = UI.IconButton(tree, NODE, function(self)
			page.sel = self.node.id
			Main.Refresh()
		end)
		b:SetPoint("CENTER", tree, "TOPLEFT", p[1], -p[2])
		b:SetIconName(node.icon)
		b.node = node
		b.lv = UI.Text(tree, K.F_MIN)
		b.lv:SetPoint("TOP", b, "BOTTOM", 0, -1)
		b.lv:SetJustifyH("CENTER")
		UI.Tip(b, function(self)
			local n = self.node
			local lvl, cost = R.Level(n.id), R.NextCost(n.id)
			local lines = { { ns.N(n.name), string.format("%d / %d", lvl, n.max), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
				{ "레벨당 " .. ns.BonusText(n.stat, n.per), nil, 1, 1, 1 } }
			if lvl > 0 then lines[#lines + 1] = { "지금 " .. ns.BonusText(n.stat, n.per * lvl), nil, 0.4, 1, 0.45 } end
			if not R.Available(n.id) then
				lines[#lines + 1] = { "앞의 룬을 먼저 배워야 합니다", nil, 1, 0.55, 0.45 }
			elseif cost then
				lines[#lines + 1] = { "다음 레벨", U.fmt(cost) .. " G", 0.8, 0.8, 0.85 }
			end
			lines[#lines + 1] = { "클릭: 아래에서 보기", nil, 0.45, 0.8, 1 }
			return lines
		end, "TOP")
		page.nodes[#page.nodes + 1] = b
	end

	-- the chosen rune
	local bar = UI.Panel(page, K.W, BAR_H, "card")
	bar:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	page.bar = bar
	bar.icon = UI.IconButton(bar, 40)
	bar.icon:SetPoint("LEFT", bar, "LEFT", 12, 0)
	bar.icon:EnableMouse(false)
	bar.name = UI.Text(bar, 14)
	bar.name:SetPoint("TOPLEFT", bar, "TOPLEFT", 62, -11)
	bar.name:SetWidth(150)
	bar.name:SetWordWrap(false)
	UI.Color(bar.name, UI.C.gold)
	bar.sub = UI.Text(bar, K.F_SMALL)
	bar.sub:SetPoint("TOPLEFT", bar, "TOPLEFT", 62, -32)
	bar.sub:SetWidth(150)
	bar.sub:SetWordWrap(false)
	UI.Color(bar.sub, UI.C.sub)
	bar.eff = UI.Text(bar, K.F_SMALL)
	bar.eff:SetPoint("TOPLEFT", bar, "TOPLEFT", 222, -11)
	bar.eff:SetWidth(K.W - 222 - 322)
	bar.eff:SetWordWrap(false)
	bar.why = UI.Text(bar, K.F_SMALL)
	bar.why:SetPoint("TOPLEFT", bar, "TOPLEFT", 222, -32)
	bar.why:SetWidth(K.W - 222 - 322)
	bar.why:SetWordWrap(false)
	page.learn = UI.Button(bar, 170, K.BTN_H, "", nil, "primary")
	page.learn:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	page.learn.clickWhenOff = true
	page.prevBtn = UI.Button(bar, 120, K.BTN_H, "먼저 배울 룬", function()
		local step = R.NextStepTo(page.sel)
		if step then page.sel = step end
		Main.Refresh()
	end, "dark")
	page.prevBtn:SetPoint("RIGHT", page.learn, "LEFT", -8, 0)
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function refresh(page)
	local learned, steps, maxSteps = 0, 0, 0
	for id, node in pairs(R.byId) do
		local lvl = R.Level(id)
		if lvl > 0 then learned = learned + 1 end
		steps = steps + lvl
		maxSteps = maxSteps + node.max
	end
	page.heading:SetText(string.format("보유 골드 %s   ·   배운 룬 %d단계 / %d단계", U.fmt(ns.db.gold), steps, maxSteps))

	for _, l in ipairs(page.links) do
		local lit = false
		for _, id in ipairs(l.ids) do if R.Level(id) > 0 then lit = true end end
		local c = lit and LIT or DARK
		for _, t in ipairs(l.parts) do UI.Fill(t, c[1], c[2], c[3], c[4]) end
	end
	for _, b in ipairs(page.nodes) do
		local n = b.node
		local lvl, cost, avail = R.Level(n.id), R.NextCost(n.id), R.Available(n.id)
		b:SetDim(not avail)
		b:SetLocked(not avail)
		if lvl >= n.max then
			b:SetBorderRGB(0.4, 0.95, 0.5)
			b.lv:SetText(U.col("6af07a", "완료"))
		elseif lvl > 0 then
			b:SetBorderRGB(1, 0.80, 0.30)
			b.lv:SetText(lvl .. "/" .. n.max)
		else
			if avail then b:SetBorderRGB(0.55, 0.62, 0.80) else b:SetBorderRGB(0.28, 0.30, 0.38) end
			b.lv:SetText(U.col("8a90a2", lvl .. "/" .. n.max))
		end
		b:SetSelected(n.id == page.sel)
		b:SetBadge(avail and lvl == 0 and cost ~= nil and ns.CanAfford(cost))
	end

	local bar = page.bar
	local node = R.byId[page.sel]
	local lvl, cost, avail = R.Level(page.sel), R.NextCost(page.sel), R.Available(page.sel)
	bar.icon:SetIconName(node.icon)
	bar.icon:SetDim(not avail)
	bar.name:SetText(ns.N(node.name))
	local brName = node.branch and ns.N((function()
		for _, br in ipairs(ns.RUNE_BRANCHES) do if br.key == node.branch then return br.name end end
	end)()) or "모든 룬의 시작"
	bar.sub:SetText(string.format("%s · 레벨 %d / %d", brName, lvl, node.max))
	bar.eff:SetText("레벨당 " .. ns.BonusText(node.stat, node.per) ..
		(lvl > 0 and ("  ·  지금 " .. U.col("6af07a", ns.BonusText(node.stat, node.per * lvl))) or ""))
	page.prevBtn:SetShown(not avail)
	page.learn.onClick = function()
		UI.Try(R.Buy(page.sel))
		Main.Refresh()
	end
	if not avail then
		local step, total = R.NextStepTo(page.sel)
		bar.why:SetText(U.col("ff9a7a", string.format("'%s'부터 배워야 합니다 (모두 %s G)", ns.N(R.byId[step].name), U.fmt(total))))
		page.learn:SetLabel("배우기  " .. U.fmt(cost or 0) .. " G")
		page.learn:SetOff(true)
	elseif cost then
		bar.why:SetText(ns.CanAfford(cost) and U.col("aab3c8", "최대 " .. ns.BonusText(node.stat, node.per * node.max))
			or U.col("ff9a7a", "골드가 부족합니다."))
		page.learn:SetLabel("배우기  " .. U.fmt(cost) .. " G")
		page.learn:SetOff(not ns.CanAfford(cost))
	else
		bar.why:SetText(U.col("6af07a", "최대 레벨입니다."))
		page.learn:SetLabel("최대 레벨")
		page.learn:SetOff(true)
	end
end

local function open(page, opts)
	if opts and opts.rune and R.byId[opts.rune] then page.sel = opts.rune end
end

Main.RegisterTab({
	key = "runes", title = "룬", sub = "골드로 배우는 계정 전체 강화입니다",
	icon = "INV_Misc_Rune_01", art = "icon_runes", build = build, refresh = refresh, open = open,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
