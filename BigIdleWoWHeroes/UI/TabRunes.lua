-- Rune tree page: one root rune and six branches bought with gold.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local COL_W = 121
local ROW_H = 38
local TOP = -70

local function runeTip(self)
	local T = ns.T
	local node = self.node
	local lvl = ns.Runes.Level(node.id)
	local lines = { { ns.N(node.name), string.format(T("레벨 %d/%d", "Level %d/%d"), lvl, node.max), 1, 0.82, 0 } }
	lines[#lines + 1] = { T("레벨당: ", "Per level: ") .. ns.BonusText(node.stat, node.per), nil, 1, 1, 1 }
	if lvl > 0 then
		lines[#lines + 1] = { T("현재: ", "Now: ") .. ns.BonusText(node.stat, node.per * lvl), nil, 0.3, 1, 0.3 }
	end
	local cost = ns.Runes.NextCost(node.id)
	if not ns.Runes.Available(node.id) then
		local prev = ns.Runes.byId[ns.Runes.prev[node.id]]
		lines[#lines + 1] = { string.format(T("먼저 '%s'을(를) 배워야 합니다.", "Requires %s first."), ns.N(prev.name)), nil, 1, 0.3, 0.3 }
	end
	if cost then
		local ok = ns.CanAfford(cost)
		lines[#lines + 1] = { T("다음 레벨 비용", "Next level"), U.fmt(cost) .. " G", ok and 1 or 1, ok and 0.82 or 0.3, ok and 0 or 0.3 }
		lines[#lines + 1] = { T("클릭: 배우기", "Click: learn"), nil, 0.4, 0.8, 1 }
	else
		lines[#lines + 1] = { T("최대 레벨", "Maximum level"), nil, 0.3, 1, 0.3 }
	end
	return lines
end

local function summaryTip()
	local T = ns.T
	local lines = { { T("룬과 동료의 보너스 합계", "Total bonuses from runes and companions"), nil, 1, 0.82, 0 } }
	local keys = {}
	for k in pairs(ns.Runes.All()) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = ns.Bonus(k)
		if v ~= 0 then lines[#lines + 1] = { ns.BonusText(k, v), nil, 1, 1, 1 } end
	end
	if #lines == 1 then
		lines[2] = { T("아직 배운 룬이 없습니다.", "No runes learned yet."), nil, 0.7, 0.7, 0.7 }
	end
	return lines
end

local function makeNode(page, node, x, y)
	local b = UI.IconButton(page, 30, function(self)
		UI.Try(ns.Runes.Buy(self.node.id))
		Main.Refresh()
	end)
	b.node = node
	b:SetIconName(node.icon)
	b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	UI.Tip(b, runeTip)
	b.text = UI.Text(page, 10)
	b.text:SetPoint("LEFT", b, "RIGHT", 4, 0)
	b.text:SetWidth(COL_W - 40)
	return b
end

local function build(page)
	local T = ns.T
	page.nodes = {}
	page.root = makeNode(page, ns.RUNE_ROOT, 0, 0)
	page.nodes[1] = page.root
	page.rootHint = UI.Text(page, 10, T("모든 룬의 시작점입니다. 룬은 골드로 배우며 계정 전체(모든 영웅)에 적용됩니다. 각 갈래는 위에서 아래로 차례대로 열립니다.",
		"Every rune starts here. Runes cost gold and apply to the whole account (all heroes). Each branch opens from top to bottom."))
	page.rootHint:SetPoint("TOPLEFT", page, "TOPLEFT", 130, -2)
	page.rootHint:SetWidth(430)
	page.rootHint:SetTextColor(0.7, 0.7, 0.7)
	page.summary = UI.Button(page, 150, 22, T("보너스 합계 보기", "Show total bonuses"))
	page.summary:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	UI.Tip(page.summary, summaryTip)

	for ci, br in ipairs(ns.RUNE_BRANCHES) do
		local x = (ci - 1) * COL_W
		local head = UI.Text(page, 12, ns.N(br.name))
		head:SetPoint("TOPLEFT", page, "TOPLEFT", x, TOP + 22)
		head:SetTextColor(U.rgb(br.hex))
		for ri, node in ipairs(br.nodes) do
			local y = TOP - (ri - 1) * ROW_H
			if ri > 1 then
				local link = page:CreateTexture(nil, "ARTWORK")
				link:SetSize(2, ROW_H - 30)
				link:SetPoint("TOPLEFT", page, "TOPLEFT", x + 14, y + (ROW_H - 30))
				UI.Fill(link, 0.3, 0.3, 0.3, 1)
			end
			page.nodes[#page.nodes + 1] = makeNode(page, node, x, y)
		end
	end
end

local function refresh(page)
	for _, b in ipairs(page.nodes) do
		local node = b.node
		local lvl = ns.Runes.Level(node.id)
		local available = ns.Runes.Available(node.id)
		local cost = ns.Runes.NextCost(node.id)
		b:SetDim(not available)
		if lvl >= node.max then
			b:SetBorderRGB(0.3, 1, 0.3)
		elseif cost and available and ns.CanAfford(cost) then
			b:SetBorderRGB(1, 0.82, 0)
		elseif lvl > 0 then
			b:SetBorderRGB(0.3, 0.7, 1)
		else
			b:SetQuality(nil)
		end
		local line = U.col(lvl >= node.max and "40ff40" or (lvl > 0 and "ffffff" or "808080"), lvl .. "/" .. node.max)
		if cost then
			line = line .. "\n" .. U.col((available and ns.CanAfford(cost)) and "ffd100" or "806a30", U.fmt(cost))
		end
		b.text:SetText(line)
	end
end

Main.RegisterTab({
	key = "runes", title = { "룬", "Runes" }, build = build, refresh = refresh,
	events = { "RUNES", "RESET", "PETS", "GOLD" },
})
