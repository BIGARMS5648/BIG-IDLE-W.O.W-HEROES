-- Bags screen (가방): item grid with filters, a detail card with plain buttons
-- for every action, and an action bar for chests and bulk breaking down.
-- Shortcuts on an item: Alt+click protects it, right-click breaks it down.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main

local COLS, ROWS, CELL, GAP = 10, 7, 46, 4
local GRID_Y = -34
local GRID_X = 54                     -- right of the category rail
local DETAIL_X, DETAIL_W = 564, 284

-- Category rail on the left: { view, filter index, label, icon }
local RAIL = {
	{ "bag", 1, "전체", "INV_Misc_Bag_10" },
	{ "bag", 2, "무기", "INV_Sword_04" },
	{ "bag", 3, "방어구", "INV_Chest_Plate03" },
	{ "bag", 4, "액세서리", "INV_Jewelry_Ring_03" },
	{ "mats", 1, "재료", "INV_Ore_Copper_01" },
	{ "bank", 1, "은행", "INV_Box_02" },
}

local FILTERS = {
	{ key = "all",  name = "전체" },
	{ key = "weapon", name = "무기", slots = { mh = true, oh = true } },
	{ key = "armor", name = "방어구", slots = { head = true, chest = true, hands = true, feet = true } },
	{ key = "acc", name = "액세서리", slots = { wrist = true, neck = true, ring = true, trinket = true } },
}

local function smeltQ()
	return U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)
end

local function itemList(page)
	local src = page.view == "bank" and ns.db.bank or ns.db.bag
	local f = FILTERS[page.filter]
	if not f.slots then return src end
	local out = {}
	for _, it in ipairs(src) do
		if f.slots[it.s] then out[#out + 1] = it end
	end
	return out
end

-- Two-click confirmation for buttons that cannot be undone.
local function confirmButton(b, action)
	b.armT = 0
	b.onClick = function(self)
		if self.armT > 0 then
			self.armT = 0
			action()
		else
			self.armT = 4
			Main.Refresh()
		end
	end
end

local function indexIn(list, it)
	for i = 1, #list do
		if list[i] == it then return i end
	end
end

------------------------------------------------------------------------
-- Detail card
------------------------------------------------------------------------
local function buildDetail(page)
	local d = UI.Panel(page, DETAIL_W, Main.PAGE_H + GRID_Y, "card")
	d:SetPoint("TOPLEFT", page, "TOPLEFT", DETAIL_X, GRID_Y)
	page.detail = d
	d.band = d:CreateTexture(nil, "BORDER")
	d.band:SetPoint("TOPLEFT", d, "TOPLEFT", 4, -4)
	d.band:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)
	d.band:SetHeight(76)
	d.band:Hide()
	d.icon = UI.IconButton(d, 56)
	d.icon:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -14)
	d.name = UI.Text(d, 15)
	d.name:SetPoint("TOPLEFT", d, "TOPLEFT", 80, -16)
	d.name:SetWidth(DETAIL_W - 94)
	d.kind = UI.Text(d, 11)
	d.kind:SetPoint("TOPLEFT", d, "TOPLEFT", 80, -38)
	UI.Color(d.kind, UI.C.sub)
	d.lines = {}
	for i = 1, 14 do
		local fs = UI.Text(d, 11)
		fs:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -82 - (i - 1) * 16)
		fs:SetWidth(DETAIL_W - 32)
		fs:SetWordWrap(false)
		d.lines[i] = fs
	end
	d.targetLabel = UI.Text(d, 11, "착용 대상")
	d.targetLabel:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16, 118)
	UI.Color(d.targetLabel, UI.C.sub)
	d.targets = {}
	for i = 1, ns.PARTY_SIZE do
		local b = UI.Portrait(d, 32, function(self)
			if self.heroId then
				Main.SelectHero(self.heroId)
				Main.Refresh()
			end
		end)
		b:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16 + (i - 1) * 40, 76)
		b.lvl:Hide()
		d.targets[i] = b
	end
	d.compare = UI.Text(d, 11)
	d.compare:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 118)
	d.compare:SetWidth(DETAIL_W - 100)
	d.compare:SetJustifyH("RIGHT")

	local half = floor((DETAIL_W - 34) / 2)
	d.b1 = UI.Button(d, half, 32, "", nil, "primary")
	d.b1:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 36)
	d.b2 = UI.Button(d, half, 32, "", nil, "red")
	d.b2.clickWhenOff = true
	d.b2:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 36)
	d.b3 = UI.Button(d, half, 24, "", nil, "dark")
	d.b3:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 8)
	d.b4 = UI.Button(d, half, 24, "", nil, "dark")
	d.b4:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 8)
	d.hint = UI.Text(d, 12, "아이템을 누르면 여기에서 자세히 보고 장착하거나 분해할 수 있습니다.")
	d.hint:SetPoint("CENTER", d, "CENTER", 0, 30)
	d.hint:SetWidth(DETAIL_W - 60)
	d.hint:SetJustifyH("CENTER")
	UI.Color(d.hint, UI.C.sub)
end

local function setButtons(d, specs)
	for i, key in ipairs({ "b1", "b2", "b3", "b4" }) do
		local b, s = d[key], specs[i]
		if s then
			b:SetLabel(s[1])
			b.onClick = s[2]
			b:SetOff(s[3] or false)
			b:Show()
		else
			b:Hide()
		end
	end
end

local function refreshDetail(page)
	local d = page.detail
	local it, mat = page.selItem, page.selMat
	local showItem = it ~= nil
	d.icon:SetShown(showItem or mat ~= nil)
	d.hint:SetShown(not showItem and mat == nil)
	d.targetLabel:SetShown(showItem and page.view == "bag")
	d.compare:SetShown(showItem and page.view == "bag")
	for _, b in ipairs(d.targets) do b:Hide() end
	for _, fs in ipairs(d.lines) do fs:SetText("") end
	d.band:Hide()
	if not showItem and not mat then
		d.name:SetText("")
		d.kind:SetText("")
		setButtons(d, {})
		return
	end

	if mat then
		local m = ns.MATS[mat]
		d.icon:SetIconName(m.icon)
		d.icon:SetQuality(m.q)
		do
			local br, bg, bb = U.rgb(ns.QUALITY[m.q].hex)
			UI.Fill(d.band, br * 0.38, bg * 0.38, bb * 0.38, 0.9)
			d.band:Show()
		end
		d.icon:SetCount(U.fmt(ns.MatCount(mat)))
		local r, g, b = U.rgb(ns.QUALITY[m.q].hex)
		d.name:SetText(ns.N(m.name))
		d.name:SetTextColor(r, g, b)
		d.kind:SetText(ns.N(ns.MAT_KIND_NAME[m.kind]) .. " · " .. string.format("%d단계", m.tier))
		local tl = ns.Items.MatTooltip(mat)
		for i = 3, #tl do
			if d.lines[i - 2] then
				d.lines[i - 2]:SetText((tl[i][1] or "") .. (tl[i][2] and ("  " .. tl[i][2]) or ""))
				d.lines[i - 2]:SetTextColor(tl[i][3] or 1, tl[i][4] or 1, tl[i][5] or 1)
			end
		end
		local count = ns.MatCount(mat)
		local gold = ns.Forge.MatSmeltGold(mat, 1)
		local canFuse = count >= ns.Forge.FUSE_COUNT and m.tier < ns.MAT_MAX_TIER[m.kind]
		local smelt = ns.Forge.Unlocked("smelt")
		setButtons(d, {
			{ "9개 융합", function()
				local ok, res = ns.Forge.FuseMat(mat)
				if UI.Try(ok, res) then ns.Fire("TOAST", string.format("융합 성공: %s", ns.N(ns.MATS[res].name))) end
				Main.Refresh()
			end, not canFuse },
			{ "1개 분해 +" .. U.fmt(gold), function()
				UI.Try(ns.Forge.SmeltMat(mat, 1))
				Main.Refresh()
			end, not smelt },
			{ d.allArmed and d.allArmed > 0 and "정말 전부? 한 번 더" or ("전부 분해 +" .. U.fmt(ns.Forge.MatSmeltGold(mat, count))), function()
				if (d.allArmed or 0) > 0 then
					d.allArmed = 0
					UI.Try(ns.Forge.SmeltMat(mat, ns.MatCount(mat)))
				else
					d.allArmed = 4
				end
				Main.Refresh()
			end, not smelt },
		})
		d.b3:SetStyle("red")
		return
	end

	-- an item
	local id = Main.SelectedHero()
	d.icon:SetIconName(ns.Items.Icon(it))
	d.icon:SetQuality(it.q)
	do
		local br, bg, bb = U.rgb(ns.QUALITY[it.q].hex)
		UI.Fill(d.band, br * 0.38, bg * 0.38, bb * 0.38, 0.9)
		d.band:Show()
	end
	d.icon:SetCount(tostring(it.l))
	d.icon:SetLocked(it.lock)
	local r, g, b = U.rgb(ns.QUALITY[it.q].hex)
	d.name:SetText(ns.Items.Name(it))
	d.name:SetTextColor(r, g, b)
	d.kind:SetText(ns.N(ns.QUALITY[it.q].name) .. " " .. ns.N(ns.SLOT[it.s].name) .. " · " .. "아이템 레벨 " .. it.l)
	local tl = ns.Items.Tooltip(it, nil)
	local n = 0
	for i = 3, #tl do
		local line = tl[i]
		local text = line[1] or ""
		if not text:find("분해 가치", 1, true) and not text:find("보호됨", 1, true) then
			n = n + 1
			if d.lines[n] then
				d.lines[n]:SetText(text .. (line[2] and ("  " .. line[2]) or ""))
				d.lines[n]:SetTextColor(line[3] or 1, line[4] or 1, line[5] or 1)
			end
		end
	end

	if page.view == "bank" then
		setButtons(d, {
			{ "가방으로", function()
				local idx = indexIn(ns.db.bank, it)
				if idx and UI.Try(ns.Items.FromBank(idx)) then page.view = "bag" end
				Main.Refresh()
			end },
			nil,
			{ it.lock and "보호 풀기" or "보호하기", function() ns.Items.ToggleLock(it) Main.Refresh() end },
		})
		d.b3:SetStyle("dark")
		return
	end

	-- equip targets: the party
	local k = 0
	for i = 1, ns.PARTY_SIZE do
		local pid = ns.db.party[i]
		if pid then
			k = k + 1
			local pb = d.targets[k]
			pb:SetHero(pid)
			pb.lvl:Hide()
			pb:SetSelected(pid == id)
			local rr = ns.Items.Compare(pid, it)
			pb:SetDim(not ns.Items.CanUse(pid, it))
			pb:SetBadge(rr and rr > 1.01)
			pb:Show()
		end
	end
	if id then
		local who = ns.Heroes.ShortName(id)
		local rr = ns.Items.Compare(id, it)
		if rr then
			local pct = (rr - 1) * 100
			if pct > 0.2 then
				d.compare:SetText(who .. " " .. U.col("6af07a", "전투력 +" .. U.num(pct, 1) .. "%"))
			elseif pct < -0.2 then
				d.compare:SetText(who .. " " .. U.col("ff6a5a", "전투력 " .. U.num(pct, 1) .. "%"))
			else
				d.compare:SetText(who .. " " .. U.col("aab3c8", "비슷함"))
			end
		else
			d.compare:SetText(who .. " " .. U.col("ff6a5a", ns.Items.CanUse(id, it) and "레벨 부족" or "착용 불가"))
		end
	end
	local gold = ns.Items.SmeltGold(it)
	local canEquip = id and ns.Items.CanEquip(id, it)
	setButtons(d, {
		{ id and ("장착: " .. ns.Heroes.ShortName(id)) or "장착", function()
			local idx = indexIn(ns.db.bag, it)
			if idx and UI.Try(ns.Items.Equip(id, idx)) then page.selItem = nil end
			Main.Refresh()
		end, not canEquip },
		{ "분해 +" .. U.fmt(gold) .. " G", function()
			if it.lock then
				UI.Try(false, "보호된 장비입니다. 먼저 '보호 풀기'를 누르세요.")
			elseif not ns.Forge.Unlocked("smelt") then
				UI.Try(false, "용광로에서 '분해'를 먼저 해금하세요.")
			else
				local ok, g = ns.Forge.Smelt({ it })
				if UI.Try(ok, g) then
					ns.Toast(string.format("분해: +%s 골드", U.fmt(g)))
					page.selItem = nil
				end
			end
			Main.Refresh()
		end, it.lock or not ns.Forge.Unlocked("smelt") },
		{ it.lock and "보호 풀기" or "보호하기", function() ns.Items.ToggleLock(it) Main.Refresh() end },
		{ "은행에 보관", function()
			local idx = indexIn(ns.db.bag, it)
			if idx and UI.Try(ns.Items.ToBank(idx)) then page.selItem = nil end
			Main.Refresh()
		end },
	})
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.view, page.filter = "bag", 1

	page.rail = {}
	for i, r in ipairs(RAIL) do
		local b = CreateFrame("Button", nil, page)
		b:SetSize(46, 58)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(i - 1) * 62)
		b.bg = UI.Slice(b, "card", "BACKGROUND")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(28, 28)
		b.icon:SetPoint("TOP", b, "TOP", 0, -6)
		UI.SetIcon(b.icon, r[4])
		b.label = UI.Text(b, 10, r[3])
		b.label:SetPoint("BOTTOM", b, "BOTTOM", 0, 5)
		b.label:SetJustifyH("CENTER")
		b.mark = b:CreateTexture(nil, "OVERLAY")
		b.mark:SetSize(3, 40)
		b.mark:SetPoint("RIGHT", b, "RIGHT", 1, 0)
		UI.Fill(b.mark, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3], 1)
		b.badge = UI.Badge(b, 13)
		b.view, b.filter = r[1], r[2]
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.view, page.filter = self.view, self.filter
			page.selItem, page.selMat = nil, nil
			Main.Refresh()
		end)
		page.rail[i] = b
	end
	page.cap = UI.Title(page, "", 14)
	page.cap:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X, -6)
	page.capHint = UI.Text(page, 10, "Alt+클릭: 보호  ·  우클릭: 분해")
	page.capHint:SetPoint("LEFT", page.cap, "RIGHT", 12, -1)
	UI.Color(page.capHint, UI.C.dim)
	page.sort = UI.Button(page, 80, 26, "정리", function()
		if page.view == "bank" then ns.Items.Sort(ns.db.bank) else ns.Items.Sort(ns.db.bag) end
		Main.Refresh()
	end, "dark")
	page.sort:SetPoint("TOPRIGHT", page, "TOPLEFT", DETAIL_X - 14, -2)

	page.cells = {}
	for i = 1, COLS * ROWS do
		local b = UI.IconButton(page, CELL, function(self, button)
			if page.view == "mats" then
				page.selMat, page.selItem = self.data, nil
			elseif self.data and IsAltKeyDown and IsAltKeyDown() then
				ns.Items.ToggleLock(self.data)
				page.selItem, page.selMat = self.data, nil
			elseif self.data and button == "RightButton" and page.view == "bag" then
				local it = self.data
				if it.lock then
					UI.Try(false, "보호된 장비는 분해되지 않습니다 (Alt+클릭으로 보호 풀기).")
				elseif not ns.Forge.Unlocked("smelt") then
					UI.Try(false, "용광로에서 '분해'를 먼저 해금하세요.")
				elseif ns.Items.PartyUpgrade(it) then
					UI.Try(false, "파티에게 더 좋은 장비라서 우클릭으로는 분해하지 않습니다. 오른쪽 '분해' 버튼을 쓰세요.")
				else
					local ok, g = ns.Forge.Smelt({ it })
					if UI.Try(ok, g) then ns.Toast(string.format("분해: +%s 골드", U.fmt(g))) end
				end
			else
				page.selItem, page.selMat = self.data, nil
			end
			Main.Refresh()
		end)
		local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X + col * (CELL + GAP), GRID_Y - row * (CELL + GAP))
		UI.Tip(b, function(self)
			if not self.data then return nil end
			if page.view == "mats" then return ns.Items.MatTooltip(self.data) end
			local lines = ns.Items.Tooltip(self.data, Main.SelectedHero())
			if page.view == "bag" then
				lines[#lines + 1] = { "클릭: 자세히 · Alt+클릭: 보호 · 우클릭: 분해", nil, 0.45, 0.8, 1 }
			end
			return lines
		end)
		page.cells[i] = b
	end
	page.emptyLayer = CreateFrame("Frame", nil, page)
	page.emptyLayer:SetAllPoints(page)
	page.emptyLayer:SetFrameLevel(page:GetFrameLevel() + 20)
	page.emptyBox = UI.Panel(page.emptyLayer, 440, 60, "card")
	page.emptyBox:SetPoint("CENTER", page, "TOPLEFT", GRID_X + (COLS * (CELL + GAP)) / 2, GRID_Y - 160)
	page.empty = UI.Text(page.emptyLayer, 12)
	page.empty:SetPoint("CENTER", page, "TOPLEFT", GRID_X + (COLS * (CELL + GAP)) / 2, GRID_Y - 160)
	page.empty:SetJustifyH("CENTER")
	page.empty:SetWidth(440)
	UI.Color(page.empty, UI.C.sub)

	-- action bar
	local barY = GRID_Y - ROWS * (CELL + GAP) - 8
	page.open = UI.Button(page, 170, 38, "", function()
		ns.Loot.OpenAll()
		Main.Refresh()
	end, "primary")
	page.open:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X, barY)
	page.smeltGo = UI.Button(page, 170, 38, "", nil, "red")
	page.smeltGo.clickWhenOff = true
	confirmButton(page.smeltGo, function()
		local ok, gold, n = ns.Forge.Smelt((ns.Forge.PickByQuality(smeltQ())))
		if UI.Try(ok, gold) then
			ns.Toast(string.format("%d개 분해: +%s 골드", n, U.fmt(gold)))
		end
		page.selItem = nil
		Main.Refresh()
	end)
	local armedClick = page.smeltGo.onClick
	page.smeltGo.onClick = function(self)
		if not ns.Forge.Unlocked("smelt") then
			Main.ShowTab("forge", { sub = "smelt" })
		elseif self.off then
			UI.Try(false, "기준 등급 이하인 장비가 없습니다. 기준 등급을 올려 보세요.")
		else
			armedClick(self)
		end
	end
	UI.Tip(page.smeltGo, function()
		local list, kept = ns.Forge.PickByQuality(smeltQ())
		local body = string.format("기준 등급 이하의 장비 %d개를 골드로 바꿉니다. 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비는 남깁니다.", #list)
		if kept > 0 then body = body .. string.format("\n(파티에게 더 좋은 장비 %d개는 남김)", kept) end
		return UI.SimpleTip("일괄 분해", body .. "\n누른 뒤 한 번 더 눌러야 실행됩니다.")
	end, "TOP")
	page.smeltGo:SetPoint("LEFT", page.open, "RIGHT", 8, 0)
	page.smeltPick = UI.Chip(page, 140, 24, "", function(_, button)
		local q = smeltQ() + (button == "RightButton" and -1 or 1)
		if q > ns.MAX_QUALITY then q = 1 elseif q < 1 then q = ns.MAX_QUALITY end
		ns.db.ui.smeltQ = q
		if (ns.db.opt.autoSmelt or 0) > 0 then ns.db.opt.autoSmelt = q end
		Main.Refresh()
	end)
	page.smeltPick:SetPoint("TOPLEFT", page.smeltGo, "TOPRIGHT", 8, 0)
	UI.Tip(page.smeltPick, function()
		return UI.SimpleTip("분해 기준 등급",
			"일괄 분해와 자동 분해가 이 등급 이하의 장비만 분해합니다. 클릭하면 한 등급 올리고, 우클릭하면 내립니다.")
	end, "TOP")
	page.autoSmelt = UI.Check(page, "가방이 차면 자동 분해",
		function() return (ns.db.opt.autoSmelt or 0) > 0 end,
		function(v) ns.db.opt.autoSmelt = v and smeltQ() or 0 end)
	page.autoSmelt:SetPoint("TOPLEFT", page.smeltPick, "BOTTOMLEFT", 0, -2)

	buildDetail(page)
end

local function refresh(page)
	local db = ns.db
	local labels = {
		bag = string.format("가방  %d / %d", #db.bag, ns.BagSize()),
		bank = string.format("은행  %d / %d", #db.bank, ns.BankSize()),
		mats = "재료",
	}
	page.cap:SetText(labels[page.view])
	page.capHint:SetShown(page.view == "bag")
	for _, b in ipairs(page.rail) do
		local on = b.view == page.view and (b.view ~= "bag" or b.filter == page.filter)
		b.mark:SetShown(on)
		if on then
			b.bg:SetColor(0.95, 0.78, 0.35, 1)
			UI.Color(b.label, UI.C.gold)
		else
			b.bg:SetColor(0.40, 0.44, 0.58, 1)
			UI.Color(b.label, UI.C.sub)
		end
	end
	page.sort:SetShown(page.view ~= "mats")

	local chests = ns.Loot.Count()
	page.open:SetLabel(string.format("상자 모두 열기 (%d)", chests))
	page.open:SetOff(chests == 0)
	page.open:SetBadge(chests > 0 and chests or nil)
	local q = smeltQ()
	page.smeltPick:SetLabel("기준: " .. U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하")
	if ns.Forge.Unlocked("smelt") then
		local list = ns.Forge.PickByQuality(q)
		local total = 0
		for _, it in ipairs(list) do total = total + ns.Items.SmeltGold(it) end
		if page.smeltGo.armT > 0 then
			page.smeltGo:SetLabel(string.format("정말 %d개 분해?\n한 번 더 누르세요", #list))
		else
			page.smeltGo:SetLabel(string.format("일괄 분해 %d개", #list) .. "\n" .. U.col("ffd24a", "+" .. U.fmt(total) .. " G"))
		end
		page.smeltGo:SetOff(#list == 0)
	else
		page.smeltGo:SetLabel("분해 해금하러 가기\n(용광로)")
		page.smeltGo:SetOff(true)
	end
	page.autoSmelt:Refresh()

	-- drop a selection that is gone
	if page.selItem and not indexIn(page.view == "bank" and db.bank or db.bag, page.selItem) then page.selItem = nil end
	if page.selMat and ns.MatCount(page.selMat) <= 0 then page.selMat = nil end

	local sel = Main.SelectedHero()
	local cells = page.cells
	if page.view == "mats" then
		local n = 0
		for _, id in ipairs(ns.MAT_ORDER) do
			local count = ns.MatCount(id)
			if count > 0 then
				n = n + 1
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
				end
			end
		end
		for i = n + 1, #cells do cells[i]:Clear() end
		page.empty:SetText(n == 0 and "재료가 없습니다. 상자에서 얻을 수 있습니다." or "")
	else
		local list = itemList(page)
		local cap = page.view == "bank" and ns.BankSize() or ns.BagSize()
		local filtered = FILTERS[page.filter].slots ~= nil
		for i, b in ipairs(cells) do
			local it = list[i]
			b:Clear()
			if it then
				b.data = it
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetCount(tostring(it.l))
				b:SetLocked(it.lock)
				b:SetSelected(page.selItem == it)
				if page.view == "bag" and sel then
					local usable = ns.Items.CanEquip(sel, it)
					b:SetDim(not usable)
					if usable then
						local r = ns.Items.Compare(sel, it)
						if r and r > 1.01 then b:SetMark("+", 0.4, 1, 0.45) end
					end
				end
			elseif not filtered and i > cap then
				b:SetDim(true)
				b:SetLocked(true)
			end
		end
		if #list == 0 then
			page.empty:SetText(page.view == "bank" and "은행이 비어 있습니다. 아끼는 장비를 보관해 두세요."
				or (filtered and "이 종류의 장비가 없습니다." or "가방이 비어 있습니다. 상자를 열어 장비를 얻으세요."))
		else
			page.empty:SetText("")
		end
	end
	page.emptyBox:SetShown(page.empty:GetText() ~= nil and page.empty:GetText() ~= "")
	refreshDetail(page)
end

local function tick(page)
	local b = page.smeltGo
	if b and b.armT > 0 then
		b.armT = max(0, b.armT - 0.2)
		if b.armT == 0 then Main.Refresh() end
	end
	local d = page.detail
	if d and (d.allArmed or 0) > 0 then
		d.allArmed = max(0, d.allArmed - 0.2)
		if d.allArmed == 0 then Main.Refresh() end
	end
end

-- opts.slot: show the filter that holds this equipment slot
local function open(page, opts)
	if opts and opts.slot then
		page.view = "bag"
		for i, f in ipairs(FILTERS) do
			if f.slots and f.slots[opts.slot] then page.filter = i end
		end
	end
end

Main.RegisterTab({
	key = "bag", title = "가방", sub = "상자를 열고 장비를 장착하거나 분해합니다",
	icon = "INV_Misc_Bag_10", art = "icon_bag", build = build, refresh = refresh, tick = tick, open = open,
	events = { "BAG", "MATS", "CHESTS", "GEAR", "RUNES", "FORGE", "LEVEL", "RESET", "PARTY" },
})
