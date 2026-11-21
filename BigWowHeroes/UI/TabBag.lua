-- The bag (가방), shown on the hero screen under the hero's equipment row
-- (UI/TabHero.lua builds it with BagView.Build):
--   two rows of tabs: 전체 · 무기 · 방어구 · 액세서리 · 은행 [정리], and the
--     materials: 제작 · 보석 세공 · 마법 부여 · 룬 각인 · 행운의 인장 재료;
--   the grid;
--   at the bottom: [상자 열기] [기준 ▾] [일괄 분해] [자동 분해];
--   on the card (BagView.Card): the chosen item or material and what to do
--     with it (equip on the chosen hero, break down, protect, bank, fuse).
-- Shortcuts on an item: Alt+click protects it, right-click breaks it down.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local BagView = {}
ns.BagView = BagView

-- six rows of twelve hold the largest bag (70 with every bag rune)
local COLS, ROWS, CELL = 12, 6, 36
local STEP_X = (K.LIST_IN - CELL) / (COLS - 1)
local STEP_Y = 41
local TABS_Y, MATS_Y, GRID_Y = -62, -90, -122
local CHIP_H = 24

local TABS = {
	{ "all", "전체" }, { "weapon", "무기" }, { "armor", "방어구" }, { "acc", "액세서리" }, { "bank", "은행" },
}
-- material tabs: the kinds each holds
local MAT_TABS = {
	{ "mat_craft", "제작 재료" }, { "mat_gem", "보석 세공 재료" }, { "mat_ench", "마법 부여 재료" },
	{ "mat_insc", "룬 각인 재료" }, { "mat_seal", "행운의 인장 재료" },
}
local MAT_KINDS_OF = {
	mat_craft = { bar = true, leather = true, cloth = true },
	mat_gem = { gem = true }, mat_ench = { dust = true }, mat_insc = { scroll = true }, mat_seal = { seal = true },
}
local MAT_USE = {
	mat_craft = "용광로 '제작'에 씁니다", mat_gem = "용광로 '보석'에 씁니다", mat_ench = "용광로 '마법부여'에 씁니다",
	mat_insc = "용광로 '각인'에 씁니다", mat_seal = "용광로 '보너스'에 씁니다",
}
local function isMats(tab) return MAT_KINDS_OF[tab] ~= nil end
BagView.IsMats = isMats
local function tabName(tab)
	for _, t in ipairs(MAT_TABS) do if t[1] == tab then return t[2] end end
	for _, t in ipairs(TABS) do if t[1] == tab then return t[2] end end
	return "가방"
end
local SLOTS_OF = {
	weapon = { mh = true, oh = true },
	armor = { head = true, chest = true, hands = true, feet = true },
	acc = { wrist = true, neck = true, ring = true, trinket = true },
}

local function smeltQ()
	return U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)
end
local function autoSmeltOn() return (ns.db.opt.autoSmelt or 0) > 0 end

local function itemList(page)
	local src = page.tab == "bank" and ns.db.bank or ns.db.bag
	local f = SLOTS_OF[page.tab]
	if not f then return src end
	local out = {}
	for _, it in ipairs(src) do
		if f[it.s] then out[#out + 1] = it end
	end
	return out
end

local function indexIn(list, it)
	for i = 1, #list do
		if list[i] == it then return i end
	end
end

-- Breaks one item down after asking (from the card button and right-click).
local function smeltOne(page, it)
	if it.lock then
		UI.Try(false, "보호된 장비는 분해할 수 없습니다. 먼저 보호를 푸세요.")
		return
	elseif not ns.Forge.Unlocked("smelt") then
		UI.Try(false, "용광로에서 '분해'를 먼저 해금하세요.")
		return
	end
	local text = string.format("%s을(를) 분해하시겠습니까?\n%s 골드를 받습니다.", ns.Items.ColorName(it), U.fmt(ns.Items.SmeltGold(it)))
	if ns.Items.PartyUpgrade(it) then
		text = text .. "\n" .. U.col("ff9a7a", "파티에게 지금 장비보다 더 좋은 장비입니다.")
	end
	UI.Confirm({ title = "분해", ok = "분해", style = "red", text = text, onOk = function()
		local ok, g = ns.Forge.Smelt({ it })
		if UI.Try(ok, g) then
			ns.Toast(string.format("분해: +%s 골드", U.fmt(g)))
			if page.selItem == it then page.selItem = nil end
		end
	end })
end

-- Materials in the order the player keeps them: new ones go to the end
-- until '정리' sorts them (sortMats). The order is kept for every
-- material; a tab shows its own kinds.
local function matList(tab)
	local db = ns.db
	local out, seen = {}, {}
	for _, id in ipairs(db.ui.matOrder or {}) do
		if ns.MATS[id] and ns.MatCount(id) > 0 and not seen[id] then out[#out + 1] = id seen[id] = true end
	end
	for _, id in ipairs(ns.MAT_ORDER) do
		if ns.MatCount(id) > 0 and not seen[id] then out[#out + 1] = id seen[id] = true end
	end
	db.ui.matOrder = out
	local kinds = MAT_KINDS_OF[tab]
	if not kinds then return out end
	local shown = {}
	for _, id in ipairs(out) do
		if kinds[ns.MATS[id].kind] then shown[#shown + 1] = id end
	end
	return shown
end

-- '정리' in a materials tab: like the item tabs, the highest grade first
-- (a material's grade follows its tier); the same tier in kind order.
local function sortMats()
	local idx = {}
	for i, id in ipairs(ns.MAT_ORDER) do idx[id] = i end
	local list = {}
	for _, id in ipairs(ns.MAT_ORDER) do
		if ns.MatCount(id) > 0 then list[#list + 1] = id end
	end
	table.sort(list, function(a, b)
		local ta, tb = ns.MATS[a].tier, ns.MATS[b].tier
		if ta ~= tb then return ta > tb end
		return idx[a] < idx[b]
	end)
	ns.db.ui.matOrder = list
end

------------------------------------------------------------------------
-- Build: host is the frame over the hero screen's list; the card is the
-- screen's card
------------------------------------------------------------------------
function BagView.Build(page, host)
	page.tab = page.tab or "all"
	local function pickTab(key)
		page.tab = key
		page.selItem, page.selMat, page.slot = nil, nil, nil
		Main.Refresh()
	end
	page.bagTabs = UI.Tabs(host, 300, TABS, pickTab, true, CHIP_H)
	page.bagTabs:SetPoint("TOPLEFT", host, "TOPLEFT", K.PAD, TABS_Y)
	page.matTabs = UI.Tabs(host, K.LIST_IN, MAT_TABS, pickTab, true, CHIP_H)
	page.matTabs:SetPoint("TOPLEFT", host, "TOPLEFT", K.PAD, MATS_Y)
	for _, t in ipairs(MAT_TABS) do
		UI.Tip(page.matTabs:Get(t[1]), function() return UI.SimpleTip(t[2], MAT_USE[t[1]]) end, "TOP")
	end
	-- 정리 sorts the grid, at the end of the tab row; the count beside it
	page.sort = UI.Button(host, 56, CHIP_H, "정리", function()
		if isMats(page.tab) then
			sortMats()
		elseif page.tab == "bank" then
			ns.Items.Sort(ns.db.bank)
		else
			ns.Items.Sort(ns.db.bag)
		end
		Main.Refresh()
	end, "dark")
	page.sort:SetPoint("TOPRIGHT", host, "TOPLEFT", K.PAD + K.LIST_IN, TABS_Y)
	UI.Tip(page.sort, function()
		return UI.SimpleTip("정리", isMats(page.tab) and "재료를 높은 등급(단계)부터 다시 놓습니다. 같은 단계는 종류 순입니다." or "등급과 레벨 순으로 다시 놓습니다.")
	end, "TOP")
	page.count = UI.Text(host, K.F_SMALL)
	page.count:SetPoint("RIGHT", page.sort, "LEFT", -8, 0)
	page.count:SetWidth(K.LIST_IN - 300 - 56 - 16)
	page.count:SetJustifyH("RIGHT")
	page.count:SetWordWrap(false)
	UI.Color(page.count, UI.C.sub)

	page.cells = {}
	for i = 1, COLS * ROWS do
		local b = UI.IconButton(host, CELL, function(self, button)
			if isMats(page.tab) then
				page.selMat, page.selItem = self.data, nil
			elseif self.data and IsAltKeyDown and IsAltKeyDown() then
				ns.Items.ToggleLock(self.data)
				page.selItem, page.selMat = self.data, nil
			elseif self.data and button == "RightButton" and page.tab ~= "bank" then
				page.selItem, page.selMat = self.data, nil
				smeltOne(page, self.data)
			elseif self.data then
				page.selItem, page.selMat = self.data, nil
			end
			page.slot = nil
			Main.Refresh()
		end)
		local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
		b:SetPoint("TOPLEFT", host, "TOPLEFT", floor(K.PAD + col * STEP_X), GRID_Y - row * STEP_Y)
		UI.Tip(b, function(self)
			if not self.data then return nil end
			if isMats(page.tab) then return ns.Items.MatTooltip(self.data) end
			local lines = ns.Items.Tooltip(self.data, Main.SelectedHero())
			if page.tab ~= "bank" then
				lines[#lines + 1] = { "클릭: 자세히 · Alt+클릭: 보호 · 우클릭: 분해", nil, 0.45, 0.8, 1 }
			end
			return lines
		end)
		page.cells[i] = b
	end
	page.bagHost = host
	page.empty = UI.Text(host, 13)
	page.empty:SetPoint("TOP", host, "TOPLEFT", K.PAD + K.LIST_IN / 2, GRID_Y - 90)
	page.empty:SetWidth(K.LIST_IN - 40)
	page.empty:SetJustifyH("CENTER")
	UI.Color(page.empty, UI.C.sub)

	-- the bottom row: open the chests | the grade, then break down up to it
	-- (now, or by itself whenever the bag is full)
	local function foot(w, label, onClick, style)
		local b = UI.Button(host, w, K.BTN_H, label, onClick, style)
		b.clickWhenOff = true
		return b
	end
	page.open = foot(118, "", function()
		ns.Loot.OpenAll()
		Main.Refresh()
	end, "blue")
	page.open:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", K.PAD, K.PAD)
	UI.Tip(page.open, function() return UI.SimpleTip("상자 모두 열기", "쌓인 상자를 모두 엽니다. 가방이 차면 남은 상자는 그대로 둡니다.") end, "TOP")
	page.smeltPick = UI.Dropdown(host, 130, K.BTN_H, function()
		local out = {}
		for q = 1, ns.MAX_QUALITY do out[#out + 1] = { q, U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하" } end
		return out
	end, smeltQ, function(q)
		ns.db.ui.smeltQ = q
		if autoSmeltOn() then ns.db.opt.autoSmelt = q end
	end, "기준: ")
	page.smeltPick:SetPoint("LEFT", page.open, "RIGHT", 6, 0)
	page.smeltPick.openUp = true -- it sits at the bottom
	page.smeltPick.tipTitle = "분해 기준 등급"
	page.smeltPick.tipText = "일괄 분해와 자동 분해가 이 등급 이하의 장비만 분해합니다. 눌러서 목록에서 고르세요."
	page.smeltGo = foot(150, "", function()
		if not ns.Forge.Unlocked("smelt") then
			Main.ShowTab("forge", { sub = "smelt" })
			return
		end
		local picked, kept = ns.Forge.PickByQuality(smeltQ())
		if #picked == 0 then
			UI.Try(false, "기준 등급 이하인 장비가 없습니다. 기준 등급을 올려 보세요.")
			return
		end
		local total = 0
		for _, it in ipairs(picked) do total = total + ns.Items.SmeltGold(it) end
		local q = ns.QUALITY[smeltQ()]
		UI.Confirm({ title = "일괄 분해", ok = "분해", style = "red",
			text = string.format("%s 이하의 장비 %d개를 분해하시겠습니까?\n%s 골드를 받습니다. 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비%s는 남깁니다.",
				U.col(q.hex, ns.N(q.name)), #picked, U.fmt(total), kept > 0 and string.format("(%d개)", kept) or ""),
			onOk = function()
				local ok, gold, n = ns.Forge.Smelt(picked)
				if UI.Try(ok, gold) then ns.Toast(string.format("%d개 분해: +%s 골드", n, U.fmt(gold))) end
				page.selItem = nil
			end })
	end, "red")
	page.smeltGo:SetPoint("LEFT", page.smeltPick, "RIGHT", 6, 0)
	UI.Tip(page.smeltGo, function()
		local picked, kept = ns.Forge.PickByQuality(smeltQ())
		local total = 0
		for _, it in ipairs(picked) do total = total + ns.Items.SmeltGold(it) end
		local body = string.format("기준 등급 이하의 장비 %d개를 골드로 바꿉니다 (+%s 골드). 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비는 남깁니다.", #picked, U.fmt(total))
		if kept > 0 then body = body .. string.format("\n(파티에게 더 좋은 장비 %d개는 남김)", kept) end
		return UI.SimpleTip("일괄 분해", body)
	end, "TOP")
	page.autoSmelt = foot(92, "", function()
		if not ns.Forge.Unlocked("smelt") then
			UI.Try(false, "용광로에서 '분해'를 먼저 해금하세요.")
			return
		end
		ns.db.opt.autoSmelt = autoSmeltOn() and 0 or smeltQ()
		ns.Toast(autoSmeltOn() and "자동 분해를 켰습니다." or "자동 분해를 껐습니다.")
		Main.Refresh()
	end, "dark")
	page.autoSmelt:SetPoint("LEFT", page.smeltGo, "RIGHT", 6, 0)
	UI.Tip(page.autoSmelt, function()
		local q = ns.QUALITY[smeltQ()]
		return UI.SimpleTip("자동 분해 " .. (autoSmeltOn() and "(켜짐)" or "(꺼짐)"),
			string.format("켜 두면 가방이 가득 찰 때 %s 이하의 장비를 저절로 분해해 자리를 만듭니다. 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비는 남깁니다.",
				U.col(q.hex, ns.N(q.name))))
	end, "TOP")

	-- card content
	local d = page.S.card
	page.lines = UI.Lines(d.content, K.CARD_IN, 14, K.F_SMALL, 174)
	page.lines:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	page.compare = UI.Text(d.content, K.F_SMALL)
	page.compare:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 0, 2)
	page.compare:SetWidth(K.CARD_IN)
	page.compare:SetWordWrap(false)
end

------------------------------------------------------------------------
-- Card
------------------------------------------------------------------------
function BagView.ClearCard(page)
	page.lines:Set(nil)
	page.compare:SetText("")
end

-- The tooltip lines (without the name and type) in the card, as many as fit
-- above the compare line or the card's footer. Call it after the card's
-- buttons are set: they decide the room left.
local function fillLines(page, tl, skip, compare)
	local list = {}
	for i = 3, #tl do
		local text = tl[i][1] or ""
		if not (skip and skip(text)) then
			list[#list + 1] = { text .. (tl[i][2] and ("  " .. tl[i][2]) or ""), tl[i][3], tl[i][4], tl[i][5], sockets = tl[i].sockets }
		end
	end
	local room = (page.S.card.contentH or 200) - (compare and 22 or 4)
	page.lines:Set(list, room)
end

-- materials: fuse everything of this tab that can be fused
local function autoFuseAction(tab)
	local kinds, name = MAT_KINDS_OF[tab], tabName(tab)
	return { "재료 자동 융합", function()
		local n = ns.Forge.MatFusionsReady(kinds)
		if n == 0 then return end
		UI.Confirm({ title = "재료 자동 융합", ok = "융합", style = "primary",
			text = string.format("%s를 자동으로 융합하시겠습니까?\n같은 재료가 %d개 이상이면 다음 단계 1개로 합칩니다(약 %d번). 낮은 단계부터 합쳐서, 새로 생긴 재료도 다시 합칩니다.",
				name, ns.Forge.FUSE_COUNT, n),
			onOk = function()
				local done = ns.Forge.FuseAllMats(kinds)
				ns.Toast(string.format("%s 융합 %d번", name, done))
			end })
	end, "primary", ns.Forge.MatFusionsReady(kinds) == 0,
	tip = { "재료 자동 융합", string.format("이 탭(%s)에서 같은 재료가 %d개 이상인 것을 모두 다음 단계로 합칩니다.", name, ns.Forge.FUSE_COUNT) } }
end
local function autoFuseReason(d, tab)
	if ns.Forge.MatFusionsReady(MAT_KINDS_OF[tab]) == 0 then
		d:Reason(string.format("같은 재료가 %d개 이상 모인 것이 없습니다.", ns.Forge.FUSE_COUNT))
	end
end

local function refreshMat(page, mat)
	local d = page.S.card
	local m = ns.MATS[mat]
	local q = ns.QUALITY[m.q]
	local count = ns.MatCount(mat)
	d:Head({ icon = m.icon, quality = m.q, count = U.fmt(count), title = ns.N(m.name), titleRGB = { U.rgb(q.hex) },
		sub = ns.N(ns.MAT_KIND_NAME[m.kind]) .. " · " .. string.format("%d단계 · %s개", m.tier, U.fmt(count)), band = { U.rgb(q.hex) } })
	local canFuse = count >= ns.Forge.FUSE_COUNT and m.tier < ns.MAT_MAX_TIER[m.kind]
	local smelt = ns.Forge.Unlocked("smelt")
	-- small row: break down one / all; footer: fuse nine / auto-fuse the tab
	d:Extras({ "1개 분해 +" .. U.fmt(ns.Forge.MatSmeltGold(mat, 1)), function()
		UI.Try(ns.Forge.SmeltMat(mat, 1))
		Main.Refresh()
	end, "red", not smelt },
	{ "전부 분해 +" .. U.fmt(ns.Forge.MatSmeltGold(mat, count)), function()
		UI.Confirm({ title = "재료 분해", ok = "분해", style = "red",
			text = string.format("%s %s개를 모두 분해하시겠습니까?\n%s 골드를 받습니다.", ns.N(m.name), U.fmt(count), U.fmt(ns.Forge.MatSmeltGold(mat, count))),
			onOk = function() UI.Try(ns.Forge.SmeltMat(mat, ns.MatCount(mat))) end })
	end, "red", not smelt })
	d:Actions({ ns.Forge.FUSE_COUNT .. "개 융합 → 1개", function()
		local ok, res = ns.Forge.FuseMat(mat)
		if UI.Try(ok, res) then ns.Fire("TOAST", string.format("융합 성공: %s", ns.N(ns.MATS[res].name))) end
		Main.Refresh()
	end, "blue", not canFuse, tip = { "재료 융합", string.format("같은 재료 %d개를 한 단계 높은 재료 1개로 만듭니다.", ns.Forge.FUSE_COUNT) } },
	autoFuseAction(page.tab))
	autoFuseReason(d, page.tab)
	fillLines(page, ns.Items.MatTooltip(mat))
end

local function refreshItem(page, it)
	local d = page.S.card
	local q = ns.QUALITY[it.q]
	d:Head({ icon = ns.Items.Icon(it), quality = it.q, count = tostring(it.l), locked = it.lock, data = it,
		title = ns.Items.Name(it), titleRGB = { U.rgb(q.hex) },
		sub = string.format("%s %s · 아이템 레벨 %d", ns.N(q.name), ns.N(ns.SLOT[it.s].name), it.l), band = { U.rgb(q.hex) },
		close = function() page.selItem = nil Main.Refresh() end })
	local function lines(compare)
		fillLines(page, ns.Items.Tooltip(it, nil), function(text)
			return text:find("분해 가치", 1, true) or text:find("보호됨", 1, true)
		end, compare)
	end
	local lock = { it.lock and "보호 풀기" or "보호하기", function() ns.Items.ToggleLock(it) Main.Refresh() end, "dark",
		tip = { "보호", "보호한 장비는 분해·융합되지 않습니다. 가방에서 Alt+클릭으로도 바꿀 수 있습니다." } }

	if page.tab == "bank" then
		d:Extras(lock, nil)
		d:Actions(nil, { "가방으로 꺼내기", function()
			local idx = indexIn(ns.db.bank, it)
			if idx and UI.Try(ns.Items.FromBank(idx)) then page.selItem = nil end
			Main.Refresh()
		end, "primary", ns.Items.BagFree() <= 0 })
		lines(false)
		return
	end

	-- the hero in the row above: compare with and equip on that hero
	local id = Main.SelectedHero()
	if id then
		local who = ns.Heroes.ShortName(id)
		local rr = ns.Items.Compare(id, it)
		if rr then
			local pct = (rr - 1) * 100
			if pct > 0.2 then
				page.compare:SetText(who .. ": " .. U.col("6af07a", "전투력 +" .. U.num(pct, 1) .. "%"))
			elseif pct < -0.2 then
				page.compare:SetText(who .. ": " .. U.col("ff6a5a", "전투력 " .. U.num(pct, 1) .. "%"))
			else
				page.compare:SetText(who .. ": " .. U.col("aab3c8", "비슷함"))
			end
		else
			page.compare:SetText(who .. ": " .. U.col("ff6a5a", ns.Items.CanUse(id, it) and "레벨이 부족합니다" or "착용할 수 없습니다"))
		end
	end
	d:Extras(lock, { "은행에 보관", function()
		local idx = indexIn(ns.db.bag, it)
		if idx and UI.Try(ns.Items.ToBank(idx)) then page.selItem = nil end
		Main.Refresh()
	end, "dark", #ns.db.bank >= ns.BankSize() })
	local canEquip = id and ns.Items.CanEquip(id, it)
	d:Actions({ "분해 +" .. U.fmt(ns.Items.SmeltGold(it)) .. " G", function() smeltOne(page, it) end, "red",
		it.lock or not ns.Forge.Unlocked("smelt"),
		tip = { "분해", "이 장비를 골드와 용광로 경험치로 바꿉니다." } },
	{ "장착", function()
		local idx = indexIn(ns.db.bag, it)
		if idx and UI.Try(ns.Items.Equip(id, idx)) then page.selItem = nil end
		Main.Refresh()
	end, "primary", not canEquip, tip = { "장착", "위 줄에서 고른 영웅에게 장착합니다. 영웅은 맨 위 초상화를 눌러 바꿉니다." } })
	if it.lock and ns.Forge.Unlocked("smelt") then d:Reason("보호한 장비는 분해할 수 없습니다.") end
	lines(id ~= nil)
end

-- Draws the card for what is chosen in the bag; false when nothing there
-- is chosen (the hero screen then shows the hero or the chosen slot).
function BagView.Card(page)
	local d = page.S.card
	if isMats(page.tab) then
		if page.selMat then
			refreshMat(page, page.selMat)
		else
			d:Head({ title = tabName(page.tab), sub = "비어 있음" })
			page.lines:Set({ { page.emptyText or "", 0.67, 0.70, 0.78 } })
			d:Actions(nil, autoFuseAction(page.tab))
			autoFuseReason(d, page.tab)
		end
		return true
	end
	if page.selItem then
		refreshItem(page, page.selItem)
		return true
	end
	return false
end

------------------------------------------------------------------------
-- Refresh (the list part)
------------------------------------------------------------------------
function BagView.Refresh(page)
	local db = ns.db
	page.bagTabs:Select(page.tab)
	page.matTabs:Select(page.tab)
	local chests = ns.Loot.Count()
	page.open:SetLabel(string.format("상자 열기 (%d)", chests))
	page.open:SetOff(chests == 0)
	page.open:SetBadge(chests > 0 and chests or nil)
	local q = smeltQ()
	page.smeltPick:SetLabel("기준: " .. U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하")
	local unlocked = ns.Forge.Unlocked("smelt")
	if unlocked then
		local picked = ns.Forge.PickByQuality(q)
		page.smeltGo:SetLabel(string.format("일괄 분해 %d개", #picked))
		page.smeltGo:SetOff(#picked == 0)
	else
		page.smeltGo:SetLabel("분해 해금하기")
		page.smeltGo:SetOff(false)
	end
	page.smeltPick:Refresh()
	page.smeltGo:SetStyle(unlocked and "red" or "blue")
	page.autoSmelt:SetLabel(autoSmeltOn() and "자동 분해 켬" or "자동 분해 끔")
	page.autoSmelt:SetStyle(autoSmeltOn() and "green" or "dark")
	page.autoSmelt:SetOff(not unlocked)
	local inBag = not isMats(page.tab) and page.tab ~= "bank"
	page.open:SetShown(page.tab ~= "bank")
	page.smeltGo:SetShown(inBag)
	page.smeltPick:SetShown(inBag)
	page.autoSmelt:SetShown(inBag)

	-- drop a selection that is gone
	if page.selItem and not indexIn(page.tab == "bank" and db.bank or db.bag, page.selItem) then page.selItem = nil end
	if page.selMat and ns.MatCount(page.selMat) <= 0 then page.selMat = nil end

	-- the "+" marks compare with the hero in the row above
	local sel = Main.SelectedHero()
	local cells = page.cells
	local empty
	if isMats(page.tab) then
		local list = matList(page.tab)
		page.count:SetText(string.format("%d종", #list))
		for i, b in ipairs(cells) do
			local id = list[i]
			b:Clear()
			b:SetShown(id ~= nil or i <= COLS * 2)
			if id then
				if not page.selMat then page.selMat = id end
				local m = ns.MATS[id]
				local count = ns.MatCount(id)
				b.data = id
				b:SetIconName(m.icon)
				b:SetQuality(m.q)
				b:SetCount(U.fmt(count))
				if count >= ns.Forge.FUSE_COUNT and m.tier < ns.MAT_MAX_TIER[m.kind] then b:SetMark("9+", 0.5, 0.85, 1) end
				b:SetSelected(page.selMat == id)
			end
		end
		if #list == 0 then empty = tabName(page.tab) .. "가 없습니다. 상자에서 얻을 수 있습니다." end
	else
		local list = itemList(page)
		local bank = page.tab == "bank"
		local cap = bank and ns.BankSize() or ns.BagSize()
		local filtered = SLOTS_OF[page.tab] ~= nil
		page.count:SetText(string.format("%s %d / %d", bank and "은행" or "가방", bank and #db.bank or #db.bag, cap))
		local shown = filtered and max(#list, COLS) or max(cap, #list)
		for i, b in ipairs(cells) do
			local it = list[i]
			b:Clear()
			b:SetShown(i <= shown)
			if it then
				b.data = it
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetCount(tostring(it.l))
				b:SetLocked(it.lock)
				b:SetSelected(page.selItem == it)
				if not bank and sel then
					local usable = ns.Items.CanEquip(sel, it)
					b:SetDim(not usable)
					if usable then
						local r = ns.Items.Compare(sel, it)
						if r and r > 1.01 then b:SetMark("+", 0.4, 1, 0.45) end
					end
				end
			end
		end
		if #list == 0 then
			empty = bank and "은행이 비어 있습니다. 아끼는 장비를 보관해 두세요."
				or (filtered and "이 종류의 장비가 없습니다." or "가방이 비어 있습니다. 상자를 열어 장비를 얻으세요.")
		end
	end
	page.emptyText = empty
	page.empty:SetText(empty or "")
	page.empty:SetShown(empty ~= nil)
	-- under the empty cells that are shown
	local shownCells = 0
	for _, b in ipairs(cells) do if b:IsShown() then shownCells = shownCells + 1 end end
	page.empty:ClearAllPoints()
	page.empty:SetPoint("TOP", page.bagHost, "TOPLEFT", K.PAD + K.LIST_IN / 2,
		GRID_Y - math.ceil(shownCells / COLS) * STEP_Y - 6)
end

-- opts.slot: the tab that holds this equipment slot; opts.tab: that tab
function BagView.Open(page, opts)
	if not opts then return end
	if opts.tab then page.tab = opts.tab end
	if opts.slot then
		for key, set in pairs(SLOTS_OF) do
			if set[opts.slot] then page.tab = key end
		end
		page.selItem = nil
	end
end
