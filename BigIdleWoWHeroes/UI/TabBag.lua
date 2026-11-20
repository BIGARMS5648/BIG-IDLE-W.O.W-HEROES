-- Bags screen: item grid with filters, a detail card with plain buttons for
-- every action, and an action bar for chests and bulk smelting.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main

local COLS, ROWS, CELL, GAP = 10, 7, 46, 4
local GRID_Y = -40
local DETAIL_X, DETAIL_W = 516, 332

local FILTERS = {
	{ key = "all",  name = "전체" },
	{ key = "weapon", name = "무기", slots = { mh = true, oh = true } },
	{ key = "armor", name = "방어구", slots = { head = true, chest = true, hands = true, feet = true } },
	{ key = "acc", name = "장신구", slots = { wrist = true, neck = true, ring = true, trinket = true } },
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
	d.targetLabel:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16, 112)
	UI.Color(d.targetLabel, UI.C.sub)
	d.targets = {}
	for i = 1, ns.PARTY_SIZE do
		local b = UI.Portrait(d, 32, function(self)
			if self.heroId then
				Main.SelectHero(self.heroId)
				Main.Refresh()
			end
		end)
		b:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16 + (i - 1) * 40, 70)
		b.lvl:Hide()
		d.targets[i] = b
	end
	d.compare = UI.Text(d, 12)
	d.compare:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 220, 82)
	d.compare:SetWidth(100)
	d.compare:SetJustifyH("RIGHT")

	d.b1 = UI.Button(d, 148, 32, "", nil, "primary")
	d.b1:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 30)
	d.b2 = UI.Button(d, 148, 32, "", nil, "red")
	d.b2:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 30)
	d.b3 = UI.Button(d, 148, 22, "", nil, "dark")
	d.b3:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 4)
	d.b4 = UI.Button(d, 148, 22, "", nil, "dark")
	d.b4:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 4)
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
		local gold = ns.MatValue(mat)
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
			{ "전부 분해", function()
				UI.Try(ns.Forge.SmeltMat(mat, ns.MatCount(mat)))
				Main.Refresh()
			end, not smelt },
		})
		return
	end

	-- an item
	local id = Main.SelectedHero()
	d.icon:SetIconName(ns.Items.Icon(it))
	d.icon:SetQuality(it.q)
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
		if not text:find("용해 가치", 1, true) and not text:find("잠김", 1, true) then
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
			{ it.lock and "잠금 해제" or "잠그기", function() ns.Items.ToggleLock(it) Main.Refresh() end },
		})
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
		local rr = ns.Items.Compare(id, it)
		if rr then
			local pct = (rr - 1) * 100
			if pct > 0.2 then
				d.compare:SetText(U.col("6af07a", "+" .. U.num(pct, 1) .. "%"))
			elseif pct < -0.2 then
				d.compare:SetText(U.col("ff6a5a", U.num(pct, 1) .. "%"))
			else
				d.compare:SetText(U.col("aab3c8", "±0%"))
			end
		else
			d.compare:SetText(U.col("ff6a5a", ns.Items.CanUse(id, it) and "레벨 부족" or "사용 불가"))
		end
	end
	local gold = floor(ns.Items.Value(it) * (1 + ns.Bonus("smeltGold") / 100))
	local canEquip = id and ns.Items.CanEquip(id, it)
	setButtons(d, {
		{ id and ("장착: " .. ns.Heroes.Name(id)) or "장착", function()
			local idx = indexIn(ns.db.bag, it)
			if idx and UI.Try(ns.Items.Equip(id, idx)) then page.selItem = nil end
			Main.Refresh()
		end, not canEquip },
		{ "분해 +" .. U.fmt(gold) .. " G", function()
			local ok, g = ns.Forge.Smelt({ it })
			if UI.Try(ok, g) then
				ns.Fire("TOAST", string.format("분해: +%s 골드", U.fmt(g)))
				page.selItem = nil
			end
			Main.Refresh()
		end, it.lock or not ns.Forge.Unlocked("smelt") },
		{ it.lock and "잠금 해제" or "잠그기 (보호)", function() ns.Items.ToggleLock(it) Main.Refresh() end },
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

	page.views = {}
	for i, v in ipairs({ "bag", "bank", "mats" }) do
		local c = UI.Chip(page, 112, 28, "", function()
			page.view = v
			page.selItem, page.selMat = nil, nil
			Main.Refresh()
		end)
		c.key = v
		c:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * 118, 0)
		page.views[i] = c
	end
	page.filters = {}
	for i, f in ipairs(FILTERS) do
		local c = UI.Chip(page, 66, 24, ns.N(f.name), function()
			page.filter = i
			Main.Refresh()
		end)
		c:SetPoint("TOPLEFT", page, "TOPLEFT", 362 + (i - 1) * 70, -2)
		page.filters[i] = c
	end
	page.sort = UI.Button(page, 80, 26, "정리", function()
		if page.view == "bank" then ns.Items.Sort(ns.db.bank) else ns.Items.Sort(ns.db.bag) end
		Main.Refresh()
	end, "dark")
	page.sort:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -1)

	page.cells = {}
	for i = 1, COLS * ROWS do
		local b = UI.IconButton(page, CELL, function(self)
			if page.view == "mats" then
				page.selMat, page.selItem = self.data, nil
			else
				page.selItem, page.selMat = self.data, nil
			end
			Main.Refresh()
		end)
		local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", col * (CELL + GAP), GRID_Y - row * (CELL + GAP))
		UI.Tip(b, function(self)
			if not self.data then return nil end
			if page.view == "mats" then return ns.Items.MatTooltip(self.data) end
			return ns.Items.Tooltip(self.data, Main.SelectedHero())
		end)
		page.cells[i] = b
	end
	page.empty = UI.Text(page, 12)
	page.empty:SetPoint("CENTER", page, "TOPLEFT", (COLS * (CELL + GAP)) / 2, GRID_Y - 160)
	page.empty:SetJustifyH("CENTER")
	page.empty:SetWidth(440)
	UI.Color(page.empty, UI.C.sub)

	-- action bar
	local barY = GRID_Y - ROWS * (CELL + GAP) - 8
	page.open = UI.Button(page, 170, 38, "", function()
		ns.Loot.OpenAll()
		Main.Refresh()
	end, "primary")
	page.open:SetPoint("TOPLEFT", page, "TOPLEFT", 0, barY)
	page.smeltGo = UI.Button(page, 170, 38, "", function()
		local ok, gold, n = ns.Forge.Smelt(ns.Forge.PickByQuality(smeltQ()))
		if UI.Try(ok, gold) then
			ns.Fire("TOAST", string.format("%d개 분해: +%s 골드", n, U.fmt(gold)))
		end
		page.selItem = nil
		Main.Refresh()
	end, "red")
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
			"이 등급 이하이면서 잠기지 않았고 홈에 능력치가 없는 장비가 분해됩니다. 클릭/우클릭으로 바꿉니다.")
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
		bag = string.format("가방 %d/%d", #db.bag, ns.BagSize()),
		bank = string.format("은행 %d/%d", #db.bank, ns.BankSize()),
		mats = "재료",
	}
	for _, c in ipairs(page.views) do
		c:SetLabel(labels[c.key])
		c:SetOn(c.key == page.view)
	end
	for i, c in ipairs(page.filters) do
		c:SetOn(i == page.filter)
		c:SetShown(page.view ~= "mats")
	end
	page.sort:SetShown(page.view ~= "mats")

	local chests = ns.Loot.Count()
	page.open:SetLabel(string.format("상자 모두 열기 (%d)", chests))
	page.open:SetOff(chests == 0)
	page.open:SetBadge(chests > 0 and chests or nil)
	local q = smeltQ()
	page.smeltPick:SetLabel(ns.N(ns.QUALITY[q].name) .. " 이하 분해")
	if ns.Forge.Unlocked("smelt") then
		local list = ns.Forge.PickByQuality(q)
		local total = 0
		for _, it in ipairs(list) do total = total + ns.Items.Value(it) end
		total = floor(total * (1 + ns.Bonus("smeltGold") / 100))
		page.smeltGo:SetLabel(string.format("일괄 분해 %d개", #list) .. "\n" .. U.col("ffd24a", "+" .. U.fmt(total) .. " G"))
		page.smeltGo:SetOff(#list == 0)
	else
		page.smeltGo:SetLabel("분해 잠김\n(용광로에서 해금)")
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
					b:SetBadge(count >= ns.Forge.FUSE_COUNT and m.tier < ns.MAT_MAX_TIER[m.kind])
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
				or "가방이 비어 있습니다. 상자를 열어 장비를 얻으세요.")
		else
			page.empty:SetText("")
		end
	end
	refreshDetail(page)
end

Main.RegisterTab({
	key = "bag", title = "가방", sub = "상자를 열고 장비를 장착하거나 분해합니다",
	icon = "INV_Misc_Bag_10", build = build, refresh = refresh,
	events = { "BAG", "MATS", "CHESTS", "GEAR", "RUNES", "FORGE", "LEVEL", "RESET", "PARTY" },
})
