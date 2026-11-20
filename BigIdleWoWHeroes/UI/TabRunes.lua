-- Runes (룬), built from the screen kit (UI/Layout.lua):
--   tabs: the six branches; tools: the total of every learned rune;
--   list: the root rune and the branch's runes in the order they are learned;
--   card: the chosen rune and the gold button that learns it.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local R = ns.Runes
local K = UI.K

local ROW_H, ROW_STEP = 30, 33

local function branchOf(id)
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		for _, n in ipairs(br.nodes) do
			if n.id == id then return br.key end
		end
	end
end

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
		if k then
			local text = ns.BonusText(k, sums[k])
			r:Set(text, "")
			r:Show()
		else
			r:Hide()
		end
	end
	totals.none:SetShown(#keys == 0)
	Main.ShowModal(totals.frame)
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.branch = ns.RUNE_BRANCHES[1].key
	page.sel = "root"
	local tabs = {}
	for _, br in ipairs(ns.RUNE_BRANCHES) do tabs[#tabs + 1] = { br.key, ns.N(br.name) } end
	local S = UI.Screen(page, {
		tabs = tabs,
		onTab = function(key)
			page.branch = key
			page.sel = nil
			Main.Refresh()
		end,
	})
	page.S = S
	page.totalBtn = S.Tool(150, "보너스 합계", openTotals, "dark")
	UI.Tip(page.totalBtn, function() return UI.SimpleTip("보너스 합계", "지금까지 배운 모든 룬의 효과를 모아 봅니다.") end, "TOP")

	local list = S.list
	page.head = UI.Section(list, K.LIST_IN)
	page.head:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, -K.PAD)
	page.rows = {}
	for i = 1, 10 do
		local row = UI.Row(list, K.LIST_IN, ROW_H, function(self)
			page.sel = self.node.id
			Main.Refresh()
		end)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, -38 - (i - 1) * ROW_STEP)
		row:Layout(200)
		row.sub:Hide()
		row.title:ClearAllPoints()
		row.title:SetPoint("LEFT", row, "LEFT", ROW_H + 4, 0)
		page.rows[i] = row
	end

	local d = S.card
	page.cardRows = {}
	for i = 1, 3 do
		local r = UI.StatRow(d.content, K.CARD_IN)
		r:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -(i - 1) * 24)
		page.cardRows[i] = r
	end
	page.req = UI.Text(d.content, K.F_SMALL)
	page.req:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -84)
	page.req:SetWidth(K.CARD_IN)
	page.req:SetJustifyV("TOP")
end

local function refresh(page)
	local S = page.S
	local d = S.card
	S.tabs:Select(page.branch)
	local br
	for _, b in ipairs(ns.RUNE_BRANCHES) do
		local can = false
		for _, n in ipairs(b.nodes) do
			local cost = R.NextCost(n.id)
			if cost and R.Available(n.id) and R.Level(n.id) == 0 and ns.CanAfford(cost) then can = true end
		end
		S.tabs:SetBadge(b.key, can)
		if b.key == page.branch then br = b end
	end
	local nodes = { ns.RUNE_ROOT }
	for _, n in ipairs(br.nodes) do nodes[#nodes + 1] = n end
	local learned = 0
	for _, n in ipairs(br.nodes) do if R.Level(n.id) > 0 then learned = learned + 1 end end
	page.head:Set(ns.N(br.name) .. "의 룬", string.format("배운 룬 %d / %d · 위에서부터 차례로 배웁니다", learned, #br.nodes))
	if not page.sel or (page.sel ~= "root" and branchOf(page.sel) ~= page.branch) then
		page.sel = nil
		for _, n in ipairs(nodes) do
			if not page.sel and R.Level(n.id) < n.max and R.Available(n.id) then page.sel = n.id end
		end
		page.sel = page.sel or nodes[1].id
	end
	for i, row in ipairs(page.rows) do
		local n = nodes[i]
		row.node = n
		if n then
			local lvl, cost, avail = R.Level(n.id), R.NextCost(n.id), R.Available(n.id)
			local affordable = cost and avail and ns.CanAfford(cost)
			row.icon:Clear()
			row.icon:SetIconName(n.icon)
			row.icon:SetDim(not avail)
			row.icon:SetLocked(not avail)
			row.title:SetText((avail and ns.N(n.name) or U.col("8a90a2", ns.N(n.name))) .. U.col("aab3c8", "   " .. ns.BonusText(n.stat, n.per)))
			local lv = U.col(lvl >= n.max and "6af07a" or (lvl > 0 and "ffffff" or "8a90a2"), lvl .. "/" .. n.max)
			local price = cost and U.col(affordable and "ffd24a" or "8a7a50", U.fmt(cost) .. " G") or U.col("6af07a", "최대")
			row.right:SetText(price .. "   " .. lv)
			row.badge:Set(affordable and lvl == 0)
			row:SetSelected(n.id == page.sel)
			row:Show()
		else
			row:Hide()
		end
	end

	local node = R.byId[page.sel]
	local lvl, cost, avail = R.Level(page.sel), R.NextCost(page.sel), R.Available(page.sel)
	d:Head({ icon = node.icon, dim = not avail, title = ns.N(node.name),
		sub = string.format("레벨 %d / %d · %s", lvl, node.max, page.sel == "root" and "모든 룬의 시작" or ns.N(br.name)) })
	local rows = {
		{ "레벨당", ns.BonusText(node.stat, node.per) },
		{ "지금", lvl > 0 and U.col("6af07a", ns.BonusText(node.stat, node.per * lvl)) or "없음" },
		{ "최대", ns.BonusText(node.stat, node.per * node.max) },
	}
	for i, r in ipairs(page.cardRows) do r:Set(rows[i][1], rows[i][2]) end
	d:Extras(nil, nil)
	if not avail then
		local step, total = R.NextStepTo(page.sel)
		local first = R.byId[step]
		page.req:SetText(U.col("ff9a7a", string.format("먼저 '%s'(%s G)을(를) 배워야 합니다.", ns.N(first.name), U.fmt(R.NextCost(step) or 0)))
			.. "\n" .. U.col("aab3c8", string.format("여기까지 모두 %s G", U.fmt(total))))
		d:Actions({ "먼저 배울 룬", function()
			page.sel = step
			Main.Refresh()
		end, "dark" }, { "배우기  " .. U.fmt(cost or 0) .. " G", nil, "primary", true })
		return
	end
	page.req:SetText("")
	if cost then
		d:Actions(nil, { "배우기  " .. U.fmt(cost) .. " G", function()
			UI.Try(R.Buy(page.sel))
			Main.Refresh()
		end, "primary", not ns.CanAfford(cost) })
		if not ns.CanAfford(cost) then d:Reason("골드가 부족합니다.") end
	else
		d:Actions(nil, { "최대 레벨", nil, "primary", true })
	end
end

local function open(page, opts)
	if opts and opts.rune and R.byId[opts.rune] then
		page.sel = opts.rune
		page.branch = branchOf(opts.rune) or page.branch
	end
end

Main.RegisterTab({
	key = "runes", title = "룬", sub = "골드로 배우는 계정 전체 강화입니다",
	icon = "INV_Misc_Rune_01", art = "icon_runes", build = build, refresh = refresh, open = open,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
