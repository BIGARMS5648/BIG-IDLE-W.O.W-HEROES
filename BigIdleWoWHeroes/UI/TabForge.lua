-- Titan Forge (용광로): a list of functions on the left, the chosen function's
-- workbench on the right. Fusion, breaking down, crafting, sockets,
-- extraction and bonus rolls.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local PX = 248          -- left edge of the operation panel
local PW = 580
local GRID_COLS, GRID_ROWS = 11, 2

local OP_ICON = {
	fuse = "Spell_Nature_WispSplode", smelt = "Spell_Fire_Fire", craft = "Trade_BlackSmithing", gem = "INV_Misc_Gem_Ruby_02",
	remove = "INV_Hammer_20", ench = "Trade_Engraving", seal = "INV_Misc_Coin_02", insc = "INV_Scroll_03",
}

local function qualityOdds(weights)
	local total = 0
	for q = 1, ns.MAX_QUALITY do total = total + (weights[q] or 0) end
	local parts = {}
	for q = 1, ns.MAX_QUALITY do
		local w = weights[q] or 0
		if w > 0 then
			parts[#parts + 1] = U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name) .. " " .. U.num(w / total * 100, 2) .. "%")
		end
	end
	return table.concat(parts, "  ")
end

local function showResult(panel, it, text)
	panel.resultItem = it
	if it then
		panel.result:SetIconName(ns.Items.Icon(it))
		panel.result:SetQuality(it.q)
		panel.result:SetCount(tostring(it.l))
		panel.result:Show()
		panel.resultText:SetText((text and (text .. "\n") or "") .. ns.Items.ColorName(it))
	else
		panel.result:Hide()
		panel.resultText:SetText(text or "")
	end
end

local function addResult(panel, x, y)
	panel.result = UI.IconButton(panel, 44)
	panel.result:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
	UI.Tip(panel.result, function()
		if panel.resultItem then return ns.Items.Tooltip(panel.resultItem, Main.SelectedHero()) end
	end)
	panel.result:Hide()
	panel.resultText = UI.Text(panel, 12)
	panel.resultText:SetPoint("LEFT", panel.result, "RIGHT", 8, 0)
	panel.resultText:SetWidth(PW - x - 60)
end

-- Two-click confirmation: the first click arms the button for a few seconds.
local function armButton(b, label, armedLabel, action)
	b.armT, b.baseLabel, b.armedLabel = 0, label, armedLabel
	b.onClick = function(self)
		if self.off then return end
		if self.armT > 0 then
			self.armT = 0
			self:SetLabel(self.baseLabel)
			action()
		else
			self.armT = 4
			self:SetLabel(self.armedLabel)
		end
	end
end
local armed = {}
local function disarmAll()
	for _, b in ipairs(armed) do
		if b.armT > 0 then
			b.armT = math.max(0, b.armT - 0.2)
			if b.armT == 0 then b:SetLabel(b.baseLabel) end
		end
	end
end

-- An item shown as a result is gone once it was used up somewhere else.
local function itemExists(it)
	if not it then return false end
	if ns.Items.IndexInBag(it) then return true end
	for _, h in pairs(ns.db.heroes) do
		for _, g in pairs(h.gear) do if g == it then return true end end
	end
	return false
end

------------------------------------------------------------------------
-- Candidate item grid (equipped gear of the chosen hero + bag items)
------------------------------------------------------------------------
-- Party portraits: which hero's worn gear the grid lists.
local function addHeroPicker(panel, x, y)
	panel.heroes = {}
	for i = 1, ns.PARTY_SIZE do
		local b = UI.Portrait(panel, 30, function(self)
			if self.heroId then
				panel.hero = self.heroId
				panel.picked = nil
				Main.Refresh()
			end
		end)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", x + (i - 1) * 36, y)
		b.lvl:Hide()
		UI.Tip(b, function(self)
			return self.heroId and UI.SimpleTip(ns.Heroes.Name(self.heroId), "클릭: 이 영웅이 착용한 장비를 목록에 보여 줍니다.") or nil
		end)
		panel.heroes[i] = b
	end
end

local function refreshHeroPicker(panel)
	if not panel.hero or not ns.db.heroes[panel.hero] then panel.hero = Main.SelectedHero() end
	local k = 0
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id then
			k = k + 1
			local b = panel.heroes[k]
			b.heroId = id
			b:SetHero(id)
			UI.SetHeroIcon(b.icon, id)
			b.lvl:Hide()
			b:SetSelected(id == panel.hero)
			b:Show()
		end
	end
	for i = k + 1, ns.PARTY_SIZE do panel.heroes[i]:Hide() panel.heroes[i].heroId = nil end
end
local function addGrid(panel, y, onPick)
	panel.grid = {}
	for i = 1, GRID_COLS * GRID_ROWS do
		local b = UI.IconButton(panel, 44, function(self)
			if self.data then
				panel.picked = self.data
				panel.pickedHero = self.heroId
				onPick()
			end
		end)
		local col, row = (i - 1) % GRID_COLS, math.floor((i - 1) / GRID_COLS)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", col * 49, y - row * 49)
		UI.Tip(b, function(self)
			if self.data then return ns.Items.Tooltip(self.data, Main.SelectedHero()) end
		end)
		panel.grid[i] = b
	end
end

-- filter(item) -> bool
local function fillGrid(panel, filter)
	local list = {}
	local id = panel.hero or Main.SelectedHero()
	if id then
		for _, slot in ipairs(ns.SLOTS) do
			local it = ns.db.heroes[id].gear[slot]
			if it and filter(it) then list[#list + 1] = { it, id } end
		end
	end
	for _, it in ipairs(ns.db.bag) do
		if filter(it) then list[#list + 1] = { it } end
	end
	local found = false
	for i, b in ipairs(panel.grid) do
		local e = list[i]
		if e then
			b.data = e[1]
			b.heroId = e[2]
			b:SetIconName(ns.Items.Icon(e[1]))
			b:SetQuality(e[1].q)
			b:SetCount(tostring(e[1].l))
			b:SetMark(e[2] and "E" or "", 1, 0.82, 0)
			b:SetSelected(e[1] == panel.picked)
			if e[1] == panel.picked then found = true end
		else
			b:Clear()
			b.heroId = nil
		end
	end
	if not found then
		panel.picked = nil
		panel.pickedHero = nil
	end
	return #list
end

------------------------------------------------------------------------
-- Operation panels. Each returns its refresh function.
------------------------------------------------------------------------
local builders = {}

function builders.fuse(panel)
	panel.q = 2
	panel.cat = "gear"
	panel.pick = UI.Chip(panel, 170, 26, "", function(_, button)
		panel.q = panel.q + (button == "RightButton" and -1 or 1)
		if panel.q > ns.MAX_QUALITY - 1 then panel.q = 1 elseif panel.q < 1 then panel.q = ns.MAX_QUALITY - 1 end
		Main.Refresh()
	end)
	panel.pick:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	UI.Tip(panel.pick, function() return UI.SimpleTip("재료 등급", "클릭: 한 등급 올리기 · 우클릭: 내리기\n이 등급의 장비 9개를 융합합니다.") end)
	panel.catBtn = UI.Chip(panel, 170, 26, "", function()
		panel.cat = panel.cat == "gear" and "accessory" or "gear"
		Main.Refresh()
	end)
	panel.catBtn:SetPoint("LEFT", panel.pick, "RIGHT", 6, 0)
	UI.Tip(panel.catBtn, function() return UI.SimpleTip("재료 종류", "클릭: 무기·방어구 ↔ 액세서리\n결과도 같은 종류에서 무작위 부위로 나옵니다.") end)
	panel.have = UI.Text(panel, 12)
	panel.have:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -34)
	-- the nine items that the next fusion will use, an arrow, the result
	panel.inputs = {}
	for i = 1, ns.Forge.FUSE_COUNT do
		local b = UI.IconButton(panel, 42)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * 46, -58)
		UI.Tip(b, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
		panel.inputs[i] = b
	end
	panel.arrow = UI.Glyph(panel, "arrow", 22, 1, 0.82, 0.3)
	panel.arrow:SetPoint("TOPLEFT", panel, "TOPLEFT", 9 * 46 + 6, -68)
	panel.out = UI.IconButton(panel, 52)
	panel.out:SetPoint("TOPLEFT", panel, "TOPLEFT", 9 * 46 + 38, -53)
	panel.out.mark:SetText("?")
	panel.odds = UI.Text(panel, 11)
	panel.odds:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -116)
	panel.odds:SetWidth(PW)
	local function fuse(all)
		local last, n, great
		for _ = 1, all and 20 or 1 do
			local list = ns.Forge.PickForFusion(panel.q, panel.cat)
			if not list then break end
			local ok, it, outcome = ns.Forge.Fuse(list)
			if not ok then UI.Try(ok, it) break end
			last, n = it, (n or 0) + 1
			if outcome == "great" then great = true end
			panel.outcome = outcome
		end
		if last then
			local msg
			if n > 1 then
				msg = string.format("%d회 융합 완료. 마지막 결과:", n)
			elseif panel.outcome == "great" or great then
				msg = U.col("ffd100", "대성공! 두 등급 상승!")
			elseif panel.outcome == "same" then
				msg = U.col("ff8080", "등급 상승 실패 (같은 등급)")
			else
				msg = "융합 성공!"
			end
			showResult(panel, last, msg)
		else
			UI.Try(false, string.format("잠기지 않은 같은 등급 장비 %d개가 필요합니다.", ns.Forge.FUSE_COUNT))
		end
		Main.Refresh()
	end
	panel.go = UI.Button(panel, 170, 34, "융합", function() fuse(false) end, "primary")
	panel.go:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -306)
	panel.goAll = UI.Button(panel, 190, 34, "가능한 만큼 융합", nil, "blue")
	armButton(panel.goAll, "가능한 만큼 융합", "정말? 한 번 더 누르세요", function() fuse(true) end)
	armed[#armed + 1] = panel.goAll
	panel.goAll:SetPoint("RIGHT", panel.go, "LEFT", -8, 0)
	addResult(panel, 0, -144)
	panel.note = UI.Text(panel, 10, "가장 낮은 레벨의 장비부터 씁니다. 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비는 쓰지 않습니다(가방에서 Alt+클릭으로 보호).\n결과의 레벨은 재료 9개의 평균 레벨 부근이고, 부위는 같은 종류 안에서 무작위입니다. 영웅 등급부터는 등급이 오르지 않을 수도 있습니다. 재료(광석 등) 융합은 '가방 > 재료'에서 합니다.")
	panel.note:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -200)
	panel.note:SetWidth(PW)
	panel.note:SetTextColor(0.7, 0.7, 0.7)

	return function()
		local q = ns.QUALITY[panel.q]
		panel.pick:SetLabel("등급: " .. U.col(q.hex, ns.N(q.name)))
		panel.catBtn:SetLabel(panel.cat == "gear" and "종류: 무기·방어구" or "종류: 액세서리")
		local n, kept = 0, 0
		for _, it in ipairs(ns.db.bag) do
			if not it.lock and it.q == panel.q and ns.Items.FuseCat(it) == panel.cat and not ns.Items.HasSockets(it) then
				if ns.Items.PartyUpgrade(it) then kept = kept + 1 else n = n + 1 end
			end
		end
		panel.have:SetText(string.format("쓸 수 있는 장비: %d개 (9개 필요)", n) .. (kept > 0 and U.col("8a90a2", string.format("   파티에게 더 좋은 장비 %d개는 제외", kept)) or ""))
		if panel.resultItem and not itemExists(panel.resultItem) then showResult(panel, nil, "") end
		local weights = {}
		for _, e in ipairs(ns.Forge.FUSE_ODDS[panel.q]) do weights[e[1]] = e[2] end
		panel.odds:SetText("결과 확률: " .. qualityOdds(weights))
		panel.go:SetOff(n < ns.Forge.FUSE_COUNT)
		panel.goAll:SetOff(n < ns.Forge.FUSE_COUNT)
		local pick = ns.Forge.PickForFusion(panel.q, panel.cat)
		for i, b in ipairs(panel.inputs) do
			local it = pick and pick[i]
			if it then
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetCount(tostring(it.l))
				b.data = it
			else
				b:Clear()
				b:SetQuality(panel.q)
				b:SetDim(true)
			end
		end
		panel.out:SetQuality(math.min(ns.MAX_QUALITY, panel.q + 1))
		panel.out:SetDim(pick == nil)
	end
end

function builders.smelt(panel)
	panel.info = UI.Text(panel, 11, "분해는 '가방'에서 합니다: 아이템을 우클릭하면 하나씩, '일괄 분해'로 기준 등급 이하를 한꺼번에, '자동 분해'를 켜면 가방이 찰 때 저절로.\n용광로 레벨과 비슷한 레벨의 아이템일수록 경험치를 많이 줍니다. 아래는 지금 받는 골드(보너스 포함)입니다.")
	panel.info:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	panel.info:SetWidth(PW)
	panel.rows = {}
	for q = 1, ns.MAX_QUALITY do
		local fs = UI.Text(panel, 11)
		fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -70 - (q - 1) * 18)
		panel.rows[q] = fs
	end
	panel.toBag = UI.Button(panel, 170, 32, "가방에서 분해하기", function() Main.ShowTab("bag") end, "blue")
	panel.toBag:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -226)
	return function()
		local level = math.max(1, ns.db.forge.level)
		for q = 1, ns.MAX_QUALITY do
			local sample = { s = "chest", l = level, q = q }
			local gold = ns.Items.SmeltGold(sample)
			panel.rows[q]:SetText(string.format("%s  ·  %d레벨 가슴 방어구 기준  %s 골드",
				U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)), level, U.fmt(gold)))
		end
	end
end

function builders.craft(panel)
	panel.group, panel.tier = 1, 1
	panel.groups = {}
	for i, g in ipairs(ns.CRAFT_GROUPS) do
		local b = UI.Chip(panel, 78, 24, ns.N(g.name), function()
			panel.group = i
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * 82, 0)
		panel.groups[i] = b
	end
	panel.tiers = {}
	for i, d in ipairs(ns.CRAFT_TIERS) do
		local b = UI.Button(panel, 110, 36, "", nil)
		b.clickWhenOff = true
		b.armT = 0
		b.onClick = function(self)
			if ns.Forge.CraftTierUnlocked(i) then
				panel.tier = i
			elseif ns.db.forge.level < d.forge then
				UI.Try(false, string.format("용광로 %d레벨에 해금할 수 있습니다.", d.forge))
			elseif self.armT > 0 then
				self.armT = 0
				if UI.Try(ns.Forge.UnlockCraftTier(i)) then panel.tier = i end
			else
				self.armT = 4
			end
			Main.Refresh()
		end
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * 116, -32)
		UI.Tip(b, function()
			local lines = { { string.format("%d단계 제작 (레벨 %d~%d)", i, d.lo, d.hi), nil, 1, 0.82, 0 } }
			if not ns.Forge.CraftTierUnlocked(i) then
				lines[#lines + 1] = { string.format("용광로 %d레벨 필요", d.forge), nil, 1, 0.5, 0.3 }
				lines[#lines + 1] = { "해금 비용", U.fmt(d.gold * 5) .. " G", 1, 0.82, 0 }
				lines[#lines + 1] = { "클릭 두 번: 해금", nil, 0.4, 0.8, 1 }
			end
			lines[#lines + 1] = { qualityOdds(d.q), nil, 1, 1, 1 }
			return lines
		end, "TOP")
		panel.tiers[i] = b
	end
	panel.costTitle = UI.Text(panel, 12, "필요 재료")
	panel.costTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -76)
	panel.costTitle:SetTextColor(1, 0.82, 0)
	panel.cost = {}
	for i = 1, 3 do
		local b = UI.IconButton(panel, 40)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * 150, -96)
		UI.Tip(b, function(self)
			if self.data then return ns.Items.MatTooltip(self.data) end
		end)
		b.text = UI.Text(panel, 11)
		b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
		b.text:SetWidth(100)
		panel.cost[i] = b
	end
	panel.fee = UI.Text(panel, 12)
	panel.fee:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -146)
	panel.odds = UI.Text(panel, 11)
	panel.odds:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -168)
	panel.odds:SetWidth(PW)
	panel.go = UI.Button(panel, 170, 34, "제작", function()
		local ok, it = ns.Forge.Craft(panel.group, panel.tier)
		if UI.Try(ok, it) then
			showResult(panel, it, "제작 완료!")
		end
		Main.Refresh()
	end)
	panel.go:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -206)
	panel.go:SetStyle("primary")
	addResult(panel, 0, -244)

	return function()
		for i, b in ipairs(panel.groups) do b:SetOn(i == panel.group) end
		for i, b in ipairs(panel.tiers) do
			local d = ns.CRAFT_TIERS[i]
			local open = ns.Forge.CraftTierUnlocked(i)
			if b.armT > 0 then b.armT = math.max(0, b.armT - 0.05) end
			if open then
				b:SetLabel(string.format("%d단계%s\nLv %d~%d", i, i == panel.tier and " (선택)" or "", d.lo, d.hi))
				b:SetStyle(i == panel.tier and "primary" or "blue")
				b:SetOff(false)
				b:SetBadge(false)
			elseif ns.db.forge.level >= d.forge then
				b:SetLabel(b.armT > 0 and "정말 해금?\n한 번 더" or string.format("해금 %d단계\n%s G", i, U.fmt(d.gold * 5)))
				b:SetStyle("green")
				b:SetOff(not ns.CanAfford(d.gold * 5))
				b:SetBadge(ns.CanAfford(d.gold * 5))
			else
				b:SetLabel(string.format("%d단계 잠김\n용광로 Lv %d", i, d.forge))
				b:SetStyle("dark")
				b:SetOff(true)
				b:SetBadge(false)
			end
			b:SetOn(false)
		end
		if not ns.Forge.CraftTierUnlocked(panel.tier) then panel.tier = 1 end
		local cost, gold = ns.Forge.CraftCost(panel.group, panel.tier)
		local ids = {}
		for id in pairs(cost) do ids[#ids + 1] = id end
		table.sort(ids)
		for i, b in ipairs(panel.cost) do
			local id = ids[i]
			if id then
				local m = ns.MATS[id]
				local have, need = ns.MatCount(id), cost[id]
				b.data = id
				b:SetIconName(m.icon)
				b:SetQuality(m.q)
				b.text:SetText(ns.N(m.name) .. "\n" .. U.col(have >= need and "40ff40" or "ff5050", have .. " / " .. need))
				b:Show()
			else
				b:Hide()
				b.text:SetText("")
			end
		end
		panel.fee:SetText("제작 비용: " .. U.col(ns.CanAfford(gold) and "ffd100" or "ff5050", U.fmt(gold)) .. " G")
		panel.odds:SetText("결과 등급: " .. qualityOdds(ns.CRAFT_TIERS[panel.tier].q))
		panel.go:SetOff(not ns.Forge.CanCraft(panel.group, panel.tier))
	end
end

local function socketBuilder(kind)
	return function(panel)
		panel.title = UI.Text(panel, 11, "대상 장비 (E = 오른쪽에서 고른 영웅이 착용 중, 나머지는 가방)")
		panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
		panel.title:SetTextColor(1, 0.82, 0)
		addHeroPicker(panel, PW - 5 * 36, 6)
		addGrid(panel, -18, function() Main.Refresh() end)
		panel.info = UI.Text(panel, 11)
		panel.info:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -122)
		panel.info:SetWidth(PW)
		panel.info:SetJustifyV("TOP")
		panel.matTitle = UI.Text(panel, 11, "사용할 재료 (단계가 높을수록 수치가 높습니다)")
		panel.matTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -196)
		panel.matTitle:SetTextColor(1, 0.82, 0)
		panel.mats = {}
		local matKind = ns.SOCKET[kind].mat
		for i = 1, ns.MAT_MAX_TIER[matKind] do
			local id = matKind .. i
			local b = UI.IconButton(panel, 40, function(self)
				panel.mat = self.data
				Main.Refresh()
			end)
			b.data = id
			b:SetIconName(ns.MATS[id].icon)
			b:SetQuality(ns.MATS[id].q)
			b:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * 46, -214)
			UI.Tip(b, function(self) return ns.Items.MatTooltip(self.data) end, "TOP")
			panel.mats[i] = b
		end
		panel.go = UI.Button(panel, 170, 34, ns.N(ns.SOCKET[kind].name), function()
			if not panel.picked or not panel.mat then return end
			local ok, entry = ns.Forge.Socket(panel.picked, kind, panel.mat, panel.pickedHero)
			if UI.Try(ok, entry) then
				panel.last = U.col("40ff40", "부여됨: " .. ns.Stats.ModText(entry[1], entry[2]))
			end
			Main.Refresh()
		end)
		panel.go:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -266)
		panel.go:SetStyle("primary")
		panel.lastText = UI.Text(panel, 12)
		panel.lastText:SetPoint("LEFT", panel.go, "RIGHT", 10, 0)
		panel.note = UI.Text(panel, 10, "부여되는 능력치는 장비 종류(무기/방어구/장신구)에 따라 정해진 목록에서 무작위로 결정됩니다. 마음에 들지 않으면 '추출'로 비우고 다시 시도할 수 있습니다.")
		panel.note:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -302)
		panel.note:SetWidth(PW)
		panel.note:SetTextColor(0.7, 0.7, 0.7)

		return function()
			refreshHeroPicker(panel)
			local n = fillGrid(panel, function(it) return ns.Items.SocketCount(it, kind) > 0 end)
			if panel.picked == nil then panel.last = nil end
			if n == 0 then
				local need = (kind == "gem" and 3) or (kind == "ench" and 5) or 6
				panel.info:SetText(string.format("해당 홈이 있는 장비가 없습니다. %s 등급 이상 장비에 홈이 있습니다.",
					U.col(ns.QUALITY[need].hex, ns.N(ns.QUALITY[need].name))))
			elseif panel.picked then
				local it = panel.picked
				local l = ns.Items.SocketList(it, kind)
				local parts = { ns.Items.ColorName(it) .. "  " .. string.format("빈 홈 %d / %d", ns.Items.FreeSockets(it, kind), ns.Items.SocketCount(it, kind)) }
				if l then
					for _, e in ipairs(l) do parts[#parts + 1] = U.col("66ccff", ns.Stats.ModText(e[1], e[2])) end
				end
				local pool = {}
				for _, e in ipairs(ns.SOCKET[kind][ns.Items.Cat(it)]) do pool[#pool + 1] = ns.N(ns.AFFIX[e[1]].n) end
				parts[#parts + 1] = U.col("a0a0a0", "가능한 능력치: " .. table.concat(pool, ", "))
				panel.info:SetText(table.concat(parts, "\n"))
			else
				panel.info:SetText("위에서 장비를 선택하세요.")
			end
			for _, b in ipairs(panel.mats) do
				local count = ns.MatCount(b.data)
				b:SetCount(count > 0 and tostring(count) or "")
				b:SetDim(count == 0)
				b:SetSelected(panel.mat == b.data)
			end
			local can = panel.picked and panel.mat and ns.Forge.CanSocket(panel.picked, kind, panel.mat)
			panel.go:SetOff(not can)
			panel.lastText:SetText(panel.last or "")
		end
	end
end

builders.gem = socketBuilder("gem")
builders.ench = socketBuilder("ench")
builders.insc = socketBuilder("insc")

function builders.remove(panel)
	panel.title = UI.Text(panel, 11, "능력치가 부여된 장비 (E = 고른 영웅이 착용 중)")
	panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	panel.title:SetTextColor(1, 0.82, 0)
	addHeroPicker(panel, PW - 5 * 36, 6)
	addGrid(panel, -18, function() Main.Refresh() end)
	panel.info = UI.Text(panel, 11)
	panel.info:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -122)
	panel.rows = {}
	for i = 1, 6 do
		local b = UI.Button(panel, PW, 24, "", nil)
		b.armT = 0
		b.onClick = function(self)
			if not (panel.picked and self.kind) or self.off then return end
			if self.armT > 0 then
				self.armT = 0
				UI.Try(ns.Forge.RemoveSocket(panel.picked, self.kind, self.index, panel.pickedHero))
			else
				for _, o in ipairs(panel.rows) do o.armT = 0 end
				self.armT = 4
			end
			Main.Refresh()
		end
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -144 - (i - 1) * 28)
		b:SetStyle("red")
		panel.rows[i] = b
	end
	panel.note = UI.Text(panel, 10, "추출하면 홈이 비워지지만 사용했던 재료는 돌아오지 않습니다. 비용은 재료 단계가 높을수록 비쌉니다.")
	panel.note:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -308)
	panel.note:SetWidth(PW)
	panel.note:SetTextColor(0.7, 0.7, 0.7)
	return function()
		refreshHeroPicker(panel)
		local n = fillGrid(panel, function(it) return ns.Items.HasSockets(it) end)
		local rows = {}
		if panel.picked then
			for _, kind in ipairs(ns.SOCKET_KINDS) do
				local l = ns.Items.SocketList(panel.picked, kind)
				if l then
					for idx, e in ipairs(l) do rows[#rows + 1] = { kind, idx, e } end
				end
			end
			panel.info:SetText(ns.Items.ColorName(panel.picked))
		elseif n == 0 then
			panel.info:SetText("능력치가 부여된 장비가 없습니다.")
		else
			panel.info:SetText("위에서 장비를 선택하세요.")
		end
		for i, b in ipairs(panel.rows) do
			local r = rows[i]
			if r then
				local cost = ns.Forge.RemoveCost(r[1], r[3][3])
				b.kind, b.index = r[1], r[2]
				if b.armT > 0 then b.armT = math.max(0, b.armT - 0.05) end
				b:SetLabel(b.armT > 0 and "정말 추출할까요? (재료는 돌아오지 않음) 한 번 더 누르세요"
					or ("[" .. ns.N(ns.SOCKET[r[1]].short) .. "] " .. ns.Stats.ModText(r[3][1], r[3][2]) .. "   추출  " .. U.fmt(cost) .. " G"))
				b:SetOff(not ns.CanAfford(cost))
				b:Show()
			else
				b.kind = nil
				b:Hide()
			end
		end
	end
end

function builders.seal(panel)
	panel.rows = {}
	for i, d in ipairs(ns.SEAL) do
		local m = ns.MATS[d.mat]
		local y = -(i - 1) * 62
		local b = UI.IconButton(panel, 44)
		b.data = d.mat
		b:SetIconName(m.icon)
		b:SetQuality(m.q)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
		UI.Tip(b, function(self) return ns.Items.MatTooltip(self.data) end)
		b.name = UI.Text(panel, 12)
		b.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 52, y - 2)
		b.odds = UI.Text(panel, 10)
		b.odds:SetPoint("TOPLEFT", panel, "TOPLEFT", 52, y - 20)
		b.odds:SetWidth(PW - 150)
		b.odds:SetText(qualityOdds(d.q))
		b.go = UI.Button(panel, 96, 30, "굴림", function()
			local ok, it = ns.Forge.BonusRoll(i)
			if UI.Try(ok, it) then
				showResult(panel, it, "보너스 굴림 결과:")
			end
			Main.Refresh()
		end)
		b.go:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y - 8)
		b.go:SetStyle("primary")
		panel.rows[i] = b
	end
	addResult(panel, 0, -256)
	panel.note = UI.Text(panel, 10, "행운의 인장은 상자에서 드물게 나옵니다. 결과 장비의 레벨은 지금까지 도달한 가장 높은 스테이지를 따릅니다.")
	panel.note:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -316)
	panel.note:SetWidth(PW)
	panel.note:SetTextColor(0.7, 0.7, 0.7)
	return function()
		for i, b in ipairs(panel.rows) do
			local d = ns.SEAL[i]
			local count = ns.MatCount(d.mat)
			b:SetCount(tostring(count))
			b:SetDim(count == 0)
			b.name:SetText(ns.N(ns.MATS[d.mat].name) .. "   " .. "비용 " .. U.col(ns.CanAfford(d.gold) and "ffd100" or "ff5050", U.fmt(d.gold)) .. " G")
			b.go:SetOff(count == 0 or not ns.CanAfford(d.gold) or ns.Items.BagFree() <= 0)
		end
	end
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.op = "fuse"
	-- forge level card
	page.lvCard = UI.Panel(page, 236, 68, "card")
	page.lvCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.anvil = page.lvCard:CreateTexture(nil, "ARTWORK")
	page.anvil:SetSize(40, 40)
	page.anvil:SetPoint("TOPLEFT", page.lvCard, "TOPLEFT", 12, -12)
	UI.SetIcon(page.anvil, "Trade_BlackSmithing")
	page.title = UI.Title(page.lvCard, "", 14)
	page.title:SetPoint("TOPLEFT", page.lvCard, "TOPLEFT", 60, -12)
	page.xp = UI.Bar(page.lvCard, 162, 14, 0.95, 0.55, 0.15)
	page.xp:SetPoint("TOPLEFT", page.lvCard, "TOPLEFT", 60, -36)
	UI.Tip(page.lvCard, function()
		return UI.SimpleTip("용광로 레벨", "아이템을 분해·융합·제작해 소모하면 경험치가 오릅니다. 레벨이 오르면 새 기능과 제작 단계가 열립니다.")
	end)

	-- operation tiles
	page.ops = {}
	page.panels = {}
	page.refreshers = {}
	for i, d in ipairs(ns.FORGE_OPS) do
		local b = CreateFrame("Button", nil, page)
		b:SetSize(236, 46)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -76 - (i - 1) * 49)
		b.bg = UI.Slice(b, "card", "BACKGROUND")
		b.sel = UI.Slice(b, "frame", "OVERLAY", 11)
		b.sel:SetColor(1, 0.82, 0.3, 1)
		b.icon = UI.IconButton(b, 36)
		b.icon:SetPoint("LEFT", b, "LEFT", 5, 0)
		b.icon:EnableMouse(false)
		b.icon:SetIconName(OP_ICON[d.key])
		b.name = UI.Text(b, 13, ns.N(d.name))
		b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 48, -7)
		b.lv = UI.Text(b, 10)
		b.lv:SetPoint("TOPLEFT", b, "TOPLEFT", 48, -26)
		b.lv:SetWidth(170)
		b.badge = UI.Badge(b, 15)
		b.badge:ClearAllPoints()
		b.badge:SetPoint("RIGHT", b, "RIGHT", -8, 0)
		b.key = d.key
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.op = self.key
			Main.Refresh()
		end)
		UI.Tip(b, function()
			local lines = { { ns.N(d.name), nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }, { ns.N(d.desc), nil, 1, 1, 1 } }
			if not ns.Forge.Unlocked(d.key) then
				lines[#lines + 1] = { string.format("용광로 %d레벨 필요", d.level), nil, 1, 0.5, 0.3 }
				lines[#lines + 1] = { "해금 비용", U.fmt(d.cost) .. " G", UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }
			end
			return lines
		end)
		page.ops[i] = b
	end

	-- the operation card
	page.card = UI.Panel(page, Main.PAGE_W - PX + 12, Main.PAGE_H, "card")
	page.card:SetPoint("TOPLEFT", page, "TOPLEFT", PX - 12, 0)
	page.opIcon = UI.IconButton(page.card, 40)
	page.opIcon:SetPoint("TOPLEFT", page.card, "TOPLEFT", 14, -12)
	page.opIcon:EnableMouse(false)
	page.opName = UI.Title(page.card, "", 17)
	page.opName:SetPoint("TOPLEFT", page.card, "TOPLEFT", 62, -12)
	page.opDesc = UI.Text(page.card, 11)
	page.opDesc:SetPoint("TOPLEFT", page.card, "TOPLEFT", 62, -34)
	page.opDesc:SetWidth(PW - 50)
	UI.Color(page.opDesc, UI.C.sub)
	for _, d in ipairs(ns.FORGE_OPS) do
		local panel = CreateFrame("Frame", nil, page)
		panel:SetSize(PW, 380)
		panel:SetPoint("TOPLEFT", page, "TOPLEFT", PX, -70)
		panel:SetFrameLevel(page.card:GetFrameLevel() + 2)
		panel:Hide()
		page.panels[d.key] = panel
		page.refreshers[d.key] = builders[d.key](panel)
	end

	page.locked = CreateFrame("Frame", nil, page)
	page.locked:SetSize(PW, 200)
	page.locked:SetPoint("TOPLEFT", page, "TOPLEFT", PX, -90)
	page.locked:SetFrameLevel(page.card:GetFrameLevel() + 2)
	page.lockG = UI.Glyph(page.locked, "lock", 56, 0.6, 0.55, 0.45)
	page.lockG:SetPoint("TOP", page.locked, "TOP", 0, -10)
	page.lockText = UI.Text(page.locked, 13)
	page.lockText:SetPoint("TOP", page.locked, "TOP", 0, -80)
	page.lockText:SetWidth(PW - 40)
	page.lockText:SetJustifyH("CENTER")
	page.unlock = UI.Button(page.locked, 220, 38, "", function()
		UI.Try(ns.Forge.Unlock(page.op))
		Main.Refresh()
	end, "primary")
	page.unlock:SetPoint("TOP", page.lockText, "BOTTOM", 0, -18)
end

local function refresh(page)
	local f = ns.db.forge
	page.title:SetText(string.format("티탄 용광로 Lv %d", f.level))
	if f.level >= ns.FORGE_MAX then
		page.xp:SetValue(1)
		page.xp:SetLabel("최대 레벨")
	else
		local need = ns.Forge.Need(f.level)
		page.xp:SetValue(f.xp / need)
		page.xp:SetLabel(U.fmt(f.xp) .. " / " .. U.fmt(need))
	end
	for i, d in ipairs(ns.FORGE_OPS) do
		local b = page.ops[i]
		local open = ns.Forge.Unlocked(d.key)
		b.sel:SetShown(page.op == d.key)
		b.icon:SetDim(not open)
		b.icon:SetLocked(not open)
		if open then
			b.lv:SetText(U.col("8a90a2", ns.N(d.short or "")))
			UI.Color(b.name, UI.C.text)
		elseif f.level >= d.level then
			b.lv:SetText(U.col(ns.CanAfford(d.cost) and "60e070" or "ffd24a", "해금 가능 · " .. U.fmt(d.cost) .. " G"))
			UI.Color(b.name, UI.C.text)
		else
			b.lv:SetText(U.col("9a8f78", string.format("용광로 Lv %d 필요", d.level)))
			UI.Color(b.name, UI.C.dim)
		end
		b.badge:Set(not open and f.level >= d.level and ns.CanAfford(d.cost))
		page.panels[d.key]:Hide()
	end
	local d = ns.Forge.OpDef(page.op)
	page.opIcon:SetIconName(OP_ICON[d.key])
	page.opName:SetText(ns.N(d.name))
	page.opDesc:SetText(ns.N(d.desc))
	if ns.Forge.Unlocked(page.op) then
		page.locked:Hide()
		page.panels[page.op]:Show()
		page.refreshers[page.op]()
	else
		page.locked:Show()
		local okLevel = f.level >= d.level
		page.lockText:SetText(string.format("용광로 %s레벨에 열리며, 해금 비용은 %s 골드입니다.\n용광로 레벨은 아이템을 분해·융합·제작하면 오릅니다.",
			U.col(okLevel and "6af07a" or "ff6a5a", tostring(d.level)), U.col(ns.CanAfford(d.cost) and "ffd24a" or "ff6a5a", U.fmt(d.cost))))
		page.unlock:SetLabel("해금하기" .. "  " .. U.fmt(d.cost) .. " G")
		page.unlock:SetOff(not okLevel or not ns.CanAfford(d.cost))
	end
end

local function open(page, opts)
	if opts and opts.sub and ns.Forge.OpDef(opts.sub) then page.op = opts.sub end
end

local function tick(page)
	disarmAll()
	local craft = page.panels and page.panels.craft
	if page.op == "craft" or page.op == "remove" then Main.MarkDirty("forge") end
end

Main.RegisterTab({
	key = "forge", title = "용광로", sub = "장비를 융합하고, 분해하고, 만들고, 강화합니다",
	icon = "Trade_BlackSmithing", art = "icon_forge", build = build, refresh = refresh, open = open, tick = tick,
	events = { "FORGE", "BAG", "MATS", "GEAR", "RESET", "GOLD" },
})
