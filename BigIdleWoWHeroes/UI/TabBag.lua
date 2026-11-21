-- Bags screen (가방), built from the screen kit (UI/Layout.lua):
--   tabs: 전체 · 무기 · 방어구 · 액세서리 · 재료 · 은행
--   list: the item grid; at the bottom, chests and breaking down in bulk;
--   card: the chosen item and what to do with it (equip, break down,
--         protect, bank).
-- Shortcuts on an item: Alt+click protects it, right-click breaks it down.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local COLS, ROWS, CELL = 10, 7, 42
local STEP_X = (K.LIST_IN - CELL) / (COLS - 1)
local STEP_Y = 48
local GRID_Y = -38

local TABS = {
	{ "all", "전체" }, { "weapon", "무기" }, { "armor", "방어구" }, { "acc", "액세서리" }, { "mats", "재료" }, { "bank", "은행" },
}
local SLOTS_OF = {
	weapon = { mh = true, oh = true },
	armor = { head = true, chest = true, hands = true, feet = true },
	acc = { wrist = true, neck = true, ring = true, trinket = true },
}

local function smeltQ()
	return U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)
end

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
-- until '정리' sorts them (sortMats).
local function matList()
	local db = ns.db
	local out, seen = {}, {}
	for _, id in ipairs(db.ui.matOrder or {}) do
		if ns.MATS[id] and ns.MatCount(id) > 0 and not seen[id] then out[#out + 1] = id seen[id] = true end
	end
	for _, id in ipairs(ns.MAT_ORDER) do
		if ns.MatCount(id) > 0 and not seen[id] then out[#out + 1] = id seen[id] = true end
	end
	db.ui.matOrder = out
	return out
end

-- '정리' in the materials tab: like the item tabs, the highest grade first
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
-- Build
------------------------------------------------------------------------
local function build(page)
	page.tab = "all"
	local S = UI.Screen(page, {
		tabs = TABS,
		onTab = function(key)
			page.tab = key
			page.selItem, page.selMat = nil, nil
			Main.Refresh()
		end,
	})
	page.S = S
	page.sort = S.Tool(90, "정리", function()
		if page.tab == "mats" then
			sortMats()
		elseif page.tab == "bank" then
			ns.Items.Sort(ns.db.bank)
		else
			ns.Items.Sort(ns.db.bag)
		end
		Main.Refresh()
	end, "dark")
	UI.Tip(page.sort, function()
		return UI.SimpleTip("정리", page.tab == "mats" and "재료를 높은 등급(단계)부터 다시 놓습니다. 같은 단계는 종류 순입니다." or "등급과 레벨 순으로 다시 놓습니다.")
	end, "TOP")

	local list = S.list
	page.head = UI.Section(list, K.LIST_IN)
	page.head:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, -K.PAD)
	page.cells = {}
	for i = 1, COLS * ROWS do
		local b = UI.IconButton(list, CELL, function(self, button)
			if page.tab == "mats" then
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
			Main.Refresh()
		end)
		local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
		b:SetPoint("TOPLEFT", list, "TOPLEFT", floor(K.PAD + col * STEP_X), GRID_Y - row * STEP_Y)
		UI.Tip(b, function(self)
			if not self.data then return nil end
			if page.tab == "mats" then return ns.Items.MatTooltip(self.data) end
			local lines = ns.Items.Tooltip(self.data, Main.SelectedHero())
			if page.tab ~= "bank" then
				lines[#lines + 1] = { "클릭: 자세히 · Alt+클릭: 보호 · 우클릭: 분해", nil, 0.45, 0.8, 1 }
			end
			return lines
		end)
		page.cells[i] = b
	end

	-- list footer: chests and bulk breaking down
	page.open = S.FootButton(1, 160, "", function()
		ns.Loot.OpenAll()
		Main.Refresh()
	end, "blue")
	UI.Tip(page.open, function() return UI.SimpleTip("상자 모두 열기", "쌓인 상자를 모두 엽니다. 가방이 차면 남은 상자는 그대로 둡니다.") end, "TOP")
	page.smeltGo = S.FootButton(2, 190, "", function(self)
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
	UI.Tip(page.smeltGo, function()
		local picked, kept = ns.Forge.PickByQuality(smeltQ())
		local body = string.format("기준 등급 이하의 장비 %d개를 골드로 바꿉니다. 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비는 남깁니다.", #picked)
		if kept > 0 then body = body .. string.format("\n(파티에게 더 좋은 장비 %d개는 남김)", kept) end
		return UI.SimpleTip("일괄 분해", body)
	end, "TOP")
	page.smeltPick = UI.Dropdown(list, 150, K.BTN_H, function()
		local out = {}
		for q = 1, ns.MAX_QUALITY do out[#out + 1] = { q, U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하" } end
		return out
	end, smeltQ, function(q)
		ns.db.ui.smeltQ = q
		if (ns.db.opt.autoSmelt or 0) > 0 then ns.db.opt.autoSmelt = q end
	end, "기준: ")
	page.smeltPick:SetPoint("LEFT", page.smeltGo, "RIGHT", 8, 0)
	page.smeltPick.openUp = true -- it sits in the footer
	page.smeltPick.tipTitle = "분해 기준 등급"
	page.smeltPick.tipText = "일괄 분해와 자동 분해(설정)가 이 등급 이하의 장비만 분해합니다. 눌러서 목록에서 고르세요."

	-- card content
	local d = S.card
	page.lines = UI.Lines(d.content, K.CARD_IN, 14, K.F_SMALL, 174)
	page.lines:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	page.targetHead = UI.Section(d.content, K.CARD_IN, "착용 대상 (출전 중인 영웅)")
	page.targetHead:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 0, 62)
	page.targets = {}
	for i = 1, ns.PARTY_SIZE do
		local b = UI.Portrait(d.content, 30, function(self)
			if self.heroId then
				Main.SelectHero(self.heroId)
				Main.Refresh()
			end
		end)
		b:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 2 + (i - 1) * 38, 24)
		b.lvl:Hide()
		UI.Tip(b, function(self)
			return self.heroId and UI.SimpleTip(ns.Heroes.Name(self.heroId), "클릭: 이 영웅에게 장착할지 비교합니다.") or nil
		end, "TOP")
		page.targets[i] = b
	end
	page.compare = UI.Text(d.content, K.F_SMALL)
	page.compare:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 0, 2)
	page.compare:SetWidth(K.CARD_IN)
	page.compare:SetWordWrap(false)
end

------------------------------------------------------------------------
-- Card
------------------------------------------------------------------------
local function clearCard(page)
	page.lines:Set(nil)
	for _, b in ipairs(page.targets) do b:Hide() end
	page.targetHead:Hide()
	page.compare:SetText("")
end

-- The tooltip lines (without the name and type) in the card, as many as fit
-- above the "who can wear it" block (targets) or the card's footer. Call
-- it after the card's buttons are set: they decide the room left.
local function fillLines(page, tl, skip, targets)
	local list = {}
	for i = 3, #tl do
		local text = tl[i][1] or ""
		if not (skip and skip(text)) then
			list[#list + 1] = { text .. (tl[i][2] and ("  " .. tl[i][2]) or ""), tl[i][3], tl[i][4], tl[i][5] }
		end
	end
	local room = (page.S.card.contentH or 200) - (targets and 90 or 4)
	page.lines:Set(list, room)
end

-- materials: fuse everything that can be fused (the card's gold button in
-- the materials tab)
local function autoFuseAction()
	return { "재료 자동 융합", function()
		local n = ns.Forge.MatFusionsReady()
		if n == 0 then return end
		UI.Confirm({ title = "재료 자동 융합", ok = "융합", style = "primary",
			text = string.format("재료를 자동으로 융합하시겠습니까?\n같은 재료가 %d개 이상이면 다음 단계 1개로 합칩니다(약 %d번). 낮은 단계부터 합쳐서, 새로 생긴 재료도 다시 합칩니다.",
				ns.Forge.FUSE_COUNT, n),
			onOk = function()
				local done = ns.Forge.FuseAllMats()
				ns.Toast(string.format("재료 융합 %d번", done))
			end })
	end, "primary", ns.Forge.MatFusionsReady() == 0,
	tip = { "재료 자동 융합", string.format("같은 재료가 %d개 이상인 것을 모두 다음 단계로 합칩니다.", ns.Forge.FUSE_COUNT) } }
end
local function autoFuseReason(d)
	if ns.Forge.MatFusionsReady() == 0 then
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
	-- small row: break down one / all; footer: fuse nine / auto-fuse everything
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
	autoFuseAction())
	autoFuseReason(d)
	fillLines(page, ns.Items.MatTooltip(mat))
end

local function refreshItem(page, it)
	local d = page.S.card
	local q = ns.QUALITY[it.q]
	d:Head({ icon = ns.Items.Icon(it), quality = it.q, count = tostring(it.l), locked = it.lock, data = it,
		title = ns.Items.Name(it), titleRGB = { U.rgb(q.hex) },
		sub = string.format("%s %s · 아이템 레벨 %d", ns.N(q.name), ns.N(ns.SLOT[it.s].name), it.l), band = { U.rgb(q.hex) } })
	local function lines()
		fillLines(page, ns.Items.Tooltip(it, nil), function(text)
			return text:find("분해 가치", 1, true) or text:find("보호됨", 1, true)
		end, page.tab ~= "bank")
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
		lines()
		return
	end

	-- who could wear it: the party (the chosen hero if fielded, else the one it helps most)
	local id = Main.SelectedHero()
	if not (id and ns.Heroes.PartySlot(id)) then
		local best, br
		for i = 1, ns.PARTY_SIZE do
			local pid = ns.db.party[i]
			local rr = pid and ns.Items.Compare(pid, it)
			if pid and (not best or (rr or 0) > (br or 0)) then best, br = pid, rr end
		end
		id = best
	end
	page.targetHead:Show()
	local k = 0
	for i = 1, ns.PARTY_SIZE do
		local pid = ns.db.party[i]
		if pid then
			k = k + 1
			local pb = page.targets[k]
			pb:SetHero(pid)
			UI.SetHeroIcon(pb.icon, pid)
			pb.lvl:Hide()
			pb:SetSelected(pid == id)
			local rr = ns.Items.Compare(pid, it)
			pb:SetDim(not ns.Items.CanUse(pid, it))
			pb:SetBadge(rr and rr > 1.01)
			pb:Show()
		end
	end
	if id then
		local who = ns.Heroes.Name(id)
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
	end, "primary", not canEquip, tip = { "장착", "위에서 고른 영웅에게 장착합니다. 영웅은 초상화를 눌러 바꿉니다." } })
	if it.lock and ns.Forge.Unlocked("smelt") then d:Reason("보호한 장비는 분해할 수 없습니다.") end
	lines()
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function refresh(page)
	local db = ns.db
	local S = page.S
	S.tabs:Select(page.tab)
	page.sort:Show()
	local chests = ns.Loot.Count()
	page.open:SetLabel(string.format("상자 열기 (%d)", chests))
	page.open:SetOff(chests == 0)
	page.open:SetBadge(chests > 0 and chests or nil)
	local q = smeltQ()
	page.smeltPick:SetLabel("기준: " .. U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하")
	if ns.Forge.Unlocked("smelt") then
		local picked = ns.Forge.PickByQuality(q)
		local total = 0
		for _, it in ipairs(picked) do total = total + ns.Items.SmeltGold(it) end
		page.smeltGo:SetLabel(string.format("일괄 분해 %d개 +%s", #picked, U.fmt(total)))
		page.smeltGo:SetOff(#picked == 0)
	else
		page.smeltGo:SetLabel("분해 해금하러 가기")
		page.smeltGo:SetOff(false)
	end
	page.smeltPick:Refresh()
	page.smeltGo:SetStyle(ns.Forge.Unlocked("smelt") and "red" or "blue")
	local inBag = page.tab ~= "mats" and page.tab ~= "bank"
	page.open:SetShown(page.tab ~= "bank")
	page.smeltGo:SetShown(inBag)
	page.smeltPick:SetShown(inBag)

	-- drop a selection that is gone
	if page.selItem and not indexIn(page.tab == "bank" and db.bank or db.bag, page.selItem) then page.selItem = nil end
	if page.selMat and ns.MatCount(page.selMat) <= 0 then page.selMat = nil end

	-- the hero the grid's "+" marks compare with: the chosen hero if fielded
	local sel = Main.SelectedHero()
	if not (sel and ns.Heroes.PartySlot(sel)) then sel = db.party[1] or db.party[2] or db.party[3] or db.party[4] or db.party[5] end
	local cells = page.cells
	local empty
	if page.tab == "mats" then
		page.head:Set("재료", "상자에서 얻고, 용광로에서 씁니다")
		local n = 0
		for _, id in ipairs(matList()) do
			local count = ns.MatCount(id)
			if count > 0 then
				n = n + 1
				if not page.selMat then page.selMat = id end
				local b = cells[n]
				if b then
					local m = ns.MATS[id]
					b:Clear()
					b.data = id
					b:SetIconName(m.icon)
					b:SetQuality(m.q)
					b:SetCount(U.fmt(count))
					if count >= ns.Forge.FUSE_COUNT and m.tier < ns.MAT_MAX_TIER[m.kind] then b:SetMark("9+", 0.5, 0.85, 1) end
					b:SetSelected(page.selMat == id)
					b:Show()
				end
			end
		end
		for i = n + 1, #cells do cells[i]:Clear() cells[i]:SetShown(i <= COLS * 2) end
		if n == 0 then empty = "재료가 없습니다. 상자에서 얻을 수 있습니다." end
	else
		local list = itemList(page)
		local bank = page.tab == "bank"
		local cap = bank and ns.BankSize() or ns.BagSize()
		local filtered = SLOTS_OF[page.tab] ~= nil
		if bank then
			page.head:Set(string.format("은행  %d / %d", #db.bank, cap), "아끼는 장비를 보관합니다")
		else
			page.head:Set(string.format("가방  %d / %d", #db.bag, cap), "Alt+클릭: 보호 · 우클릭: 분해")
		end
		if not page.selItem then page.selItem = list[1] end
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
	S.Empty(nil)

	local d = S.card
	clearCard(page)
	d:Extras(nil, nil)
	if page.tab == "mats" and page.selMat then
		refreshMat(page, page.selMat)
	elseif page.tab ~= "mats" and page.selItem then
		refreshItem(page, page.selItem)
	else
		d:Head({ title = page.tab == "mats" and "재료" or (page.tab == "bank" and "은행" or "가방"), sub = empty and "비어 있음" or "고른 것이 없습니다" })
		page.lines:Set({ { empty or "왼쪽에서 아이템을 누르면 여기에서 자세히 보고 장착하거나 분해할 수 있습니다.", 0.67, 0.70, 0.78 } })
		if page.tab == "mats" then
			-- nothing picked: auto-fuse still fills the footer
			d:Actions(nil, autoFuseAction())
			autoFuseReason(d)
		else
			d:Actions(nil, nil)
			d.wide:Hide()
		end
	end
end

local function tick(page) end

-- opts.slot: show the tab that holds this equipment slot
local function open(page, opts)
	if opts and opts.slot then
		for key, set in pairs(SLOTS_OF) do
			if set[opts.slot] then page.tab = key end
		end
		page.selItem = nil
	end
end

Main.RegisterTab({
	key = "bag", title = "가방", sub = "상자를 열고 장비를 장착하거나 분해합니다",
	icon = "INV_Misc_Bag_10", art = "icon_bag", build = build, refresh = refresh, tick = tick, open = open,
	events = { "BAG", "MATS", "CHESTS", "GEAR", "RUNES", "FORGE", "LEVEL", "RESET", "PARTY" },
})
