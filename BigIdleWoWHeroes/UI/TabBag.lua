-- Bags page: bag, bank and reagent views, chest opening and bulk smelting.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local COLS, ROWS, CELL = 14, 5, 52

local function smeltQ()
	return U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)
end

local function itemTip(self)
	local T = ns.T
	local page = self.page
	if page.view == "mats" then
		local id = self.data
		if not id then return nil end
		local lines = ns.Items.MatTooltip(id)
		lines[#lines + 1] = { T("클릭: 9개 융합 · 우클릭: 1개 용해 · Shift+우클릭: 전부 용해", "Click: fuse 9 - Right-click: smelt 1 - Shift+right-click: smelt all"), nil, 0.4, 0.8, 1 }
		return lines
	end
	local it = self.data
	if not it then return nil end
	local lines = ns.Items.Tooltip(it, Main.SelectedHero())
	if page.view == "bag" then
		lines[#lines + 1] = { T("클릭: 선택한 영웅에게 착용", "Click: equip on the selected hero"), nil, 0.4, 0.8, 1 }
		lines[#lines + 1] = { T("Shift+클릭: 은행으로 · Alt+클릭: 잠금", "Shift+click: to bank - Alt+click: lock"), nil, 0.4, 0.8, 1 }
		lines[#lines + 1] = { T("우클릭: 용해 (영웅 등급 이상은 Ctrl+우클릭)", "Right-click: smelt (Ctrl+right-click for Epic or better)"), nil, 0.4, 0.8, 1 }
	else
		lines[#lines + 1] = { T("클릭: 가방으로 · Alt+클릭: 잠금", "Click: to bags - Alt+click: lock"), nil, 0.4, 0.8, 1 }
	end
	return lines
end

local function onItemClick(self, button)
	local page = self.page
	local T = ns.T
	if page.view == "mats" then
		local id = self.data
		if not id then return end
		if button == "RightButton" then
			local n = IsShiftKeyDown() and ns.MatCount(id) or 1
			local ok, gold = ns.Forge.SmeltMat(id, n)
			if UI.Try(ok, gold) then
				ns.Fire("TOAST", string.format(T("재료 용해: +%s 골드", "Smelted: +%s gold"), U.fmt(gold)))
			end
		else
			local ok, res = ns.Forge.FuseMat(id)
			if UI.Try(ok, res) then
				ns.Fire("TOAST", string.format(T("융합 성공: %s", "Fused into %s"), ns.N(ns.MATS[res].name)))
			end
		end
		Main.Refresh()
		return
	end
	local it = self.data
	if not it then return end
	if page.view == "bank" then
		local idx
		for i, b in ipairs(ns.db.bank) do if b == it then idx = i end end
		if not idx then return end
		if IsAltKeyDown() then
			ns.Items.ToggleLock(it)
		else
			UI.Try(ns.Items.FromBank(idx))
		end
		Main.Refresh()
		return
	end
	local idx = ns.Items.IndexInBag(it)
	if not idx then return end
	if button == "RightButton" then
		if it.lock then
			UI.Try(false, T("잠긴 아이템은 용해할 수 없습니다.", "Locked items cannot be smelted."))
		elseif it.q >= 5 and not IsControlKeyDown() then
			UI.Try(false, T("영웅 등급 이상은 Ctrl+우클릭으로 용해합니다.", "Use Ctrl+right-click to smelt Epic or better items."))
		else
			local ok, gold = ns.Forge.Smelt({ it })
			if UI.Try(ok, gold) then
				ns.Fire("TOAST", string.format(T("용해: +%s 골드", "Smelted: +%s gold"), U.fmt(gold)))
			end
		end
	elseif IsAltKeyDown() then
		ns.Items.ToggleLock(it)
	elseif IsShiftKeyDown() then
		UI.Try(ns.Items.ToBank(idx))
	else
		local id = Main.SelectedHero()
		if id then
			UI.Try(ns.Items.Equip(id, idx))
		end
	end
	Main.Refresh()
end

local function build(page)
	local T = ns.T
	page.view = "bag"
	page.views = {}
	local function viewButton(key, x)
		local b = UI.Button(page, 112, 22, "", function()
			page.view = key
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", x, 0)
		page.views[key] = b
	end
	viewButton("bag", 0)
	viewButton("bank", 116)
	viewButton("mats", 232)

	page.open = UI.Button(page, 150, 22, "", function()
		ns.Loot.OpenAll()
		Main.Refresh()
	end)
	page.open:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	page.sort = UI.Button(page, 70, 22, T("정리", "Sort"), function()
		if page.view == "bank" then ns.Items.Sort(ns.db.bank) else ns.Items.Sort(ns.db.bag) end
		Main.Refresh()
	end)
	page.sort:SetPoint("RIGHT", page.open, "LEFT", -6, 0)

	-- bulk smelt row
	page.smeltLabel = UI.Text(page, 11, T("일괄 용해:", "Bulk smelt:"))
	page.smeltLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -32)
	page.smeltPick = UI.Button(page, 120, 20, "", function(_, button)
		local q = smeltQ() + (button == "RightButton" and -1 or 1)
		if q > ns.MAX_QUALITY then q = 1 elseif q < 1 then q = ns.MAX_QUALITY end
		ns.db.ui.smeltQ = q
		if (ns.db.opt.autoSmelt or 0) > 0 then ns.db.opt.autoSmelt = q end
		Main.Refresh()
	end)
	page.smeltPick:SetPoint("TOPLEFT", page, "TOPLEFT", 74, -28)
	UI.Tip(page.smeltPick, function()
		return UI.SimpleTip(T("용해 기준 등급", "Smelt threshold"),
			T("이 등급 이하이면서 잠기지 않았고 홈에 능력치가 없는 가방 아이템이 대상입니다. 클릭/우클릭으로 변경.",
				"Targets unlocked bag items of this quality or lower that have nothing socketed. Click / right-click to change."))
	end, "TOP")
	page.smeltGo = UI.Button(page, 220, 20, "", function()
		local list = ns.Forge.PickByQuality(smeltQ())
		local ok, gold, n = ns.Forge.Smelt(list)
		if UI.Try(ok, gold) then
			ns.Fire("TOAST", string.format(ns.T("%d개 용해: +%s 골드", "Smelted %d items: +%s gold"), n, U.fmt(gold)))
		end
		Main.Refresh()
	end)
	page.smeltGo:SetPoint("LEFT", page.smeltPick, "RIGHT", 6, 0)
	page.autoSmelt = UI.Check(page, T("가방이 가득 차면 자동 용해", "Auto-smelt when the bags are full"),
		function() return (ns.db.opt.autoSmelt or 0) > 0 end,
		function(v) ns.db.opt.autoSmelt = v and smeltQ() or 0 end)
	page.autoSmelt:SetPoint("LEFT", page.smeltGo, "RIGHT", 12, 0)

	-- grid
	page.cells = {}
	for i = 1, COLS * ROWS do
		local b = UI.IconButton(page, CELL - 6, onItemClick)
		b.page = page
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", col * CELL, -58 - row * CELL)
		UI.Tip(b, itemTip)
		page.cells[i] = b
	end

	page.target = UI.Text(page, 11)
	page.target:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -326)
	page.help = UI.Text(page, 10)
	page.help:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -346)
	page.help:SetWidth(Main.PAGE_W)
	page.help:SetTextColor(0.7, 0.7, 0.7)
	page.log = UI.Text(page, 10)
	page.log:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -386)
	page.log:SetWidth(Main.PAGE_W)
	page.log:SetJustifyV("TOP")
	page.log:SetTextColor(0.8, 0.8, 0.8)
end

local function refresh(page)
	local T = ns.T
	local db = ns.db
	page.views.bag:SetLabel(string.format(T("가방 %d/%d", "Bags %d/%d"), #db.bag, ns.BagSize()))
	page.views.bank:SetLabel(string.format(T("은행 %d/%d", "Bank %d/%d"), #db.bank, ns.BankSize()))
	page.views.mats:SetLabel(T("재료 가방", "Reagents"))
	for key, b in pairs(page.views) do b:SetOn(key == page.view) end
	local chests = ns.Loot.Count()
	page.open:SetLabel(string.format(T("상자 모두 열기 (%d)", "Open all chests (%d)"), chests))
	page.open:SetOff(chests == 0)
	page.sort:SetOff(page.view == "mats")

	local q = smeltQ()
	page.smeltPick:SetLabel(U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. T(" 이하", " or lower"))
	local list = ns.Forge.PickByQuality(q)
	local total = 0
	for _, it in ipairs(list) do total = total + ns.Items.Value(it) end
	total = math.floor(total * (1 + ns.Bonus("smeltGold") / 100))
	if ns.Forge.Unlocked("smelt") then
		page.smeltGo:SetLabel(string.format(T("%d개 용해 (+%s G)", "Smelt %d items (+%s G)"), #list, U.fmt(total)))
		page.smeltGo:SetOff(#list == 0)
	else
		page.smeltGo:SetLabel(T("'용광로' 탭에서 용해를 먼저 해금", "Unlock Smelt on the Forge tab first"))
		page.smeltGo:SetOff(true)
	end
	page.autoSmelt:Refresh()

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
					b.data = id
					b:SetIconName(m.icon)
					b:SetQuality(m.q)
					b:SetCount(U.fmt(count))
					b:SetMark(count >= ns.Forge.FUSE_COUNT and m.tier < ns.MAT_MAX_TIER[m.kind] and "+" or "", 0.3, 1, 0.3)
					b:SetDim(false)
				end
			end
		end
		for i = n + 1, #cells do cells[i]:Clear() end
		page.target:SetText(n == 0 and T("재료가 없습니다. 상자에서 얻을 수 있습니다.", "No materials yet. They come from chests.") or "")
		page.help:SetText(T("재료는 가방 칸을 차지하지 않습니다. 같은 재료 9개는 다음 단계 1개로 융합할 수 있습니다(+ 표시).",
			"Materials take no bag space. Nine of a kind can be fused into one of the next tier (marked +)."))
	else
		local src = page.view == "bank" and db.bank or db.bag
		local cap = page.view == "bank" and ns.BankSize() or ns.BagSize()
		for i = 1, #cells do
			local b = cells[i]
			local it = src[i]
			if it then
				b.data = it
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetCount(tostring(it.l))
				local usable = sel and ns.Items.CanEquip(sel, it)
				b:SetDim(sel ~= nil and not usable)
				if it.lock then
					b:SetMark("L", 1, 0.5, 0.2)
				elseif usable and page.view == "bag" then
					local r = ns.Items.Compare(sel, it)
					if r and r > 1.002 then b:SetMark("+", 0.3, 1, 0.3) else b:SetMark("") end
				else
					b:SetMark("")
				end
			else
				b:Clear()
				if i > cap then
					b:SetDim(true)
					b:SetBorderRGB(0.12, 0.12, 0.12)
				end
			end
		end
		if sel then
			local c = ns.CLASSES[sel]
			page.target:SetText(T("착용 대상: ", "Equip target: ") .. U.col(c.hex, ns.N(c.name)) .. "  " ..
				U.col("808080", T("(왼쪽 초상화로 변경 · + 표시는 이 영웅에게 더 좋은 장비)", "(change with the portraits on the left - + marks an upgrade)")))
		else
			page.target:SetText("")
		end
		page.help:SetText(T("상자는 전투 바의 상자 아이콘이나 위의 버튼으로 엽니다. 가방이 가득 차면 상자를 열 수 없으니, 필요 없는 장비는 용해하거나 융합하세요.",
			"Open chests with the bar icons or the button above. Chests stay closed while the bags are full, so smelt or fuse what you do not need."))
	end

	local lines = {}
	local log = ns.log
	for i = math.max(1, #log - 4), #log do lines[#lines + 1] = log[i] end
	page.log:SetText(table.concat(lines, "\n"))
end

Main.RegisterTab({
	key = "bag", title = { "가방", "Bags" }, build = build, refresh = refresh,
	events = { "BAG", "MATS", "CHESTS", "GEAR", "RUNES", "FORGE", "LEVEL", "RESET", "LOG" },
})
