-- Titan Forge (용광로), built from the screen kit (UI/Layout.lua):
--   tabs: the eight forge functions; tools: the forge level;
--   list: what the function works on (equipment, materials, tiers);
--   card: the chosen thing, the result, and the gold button that does it.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local OP_ICON = {
	fuse = "Spell_Nature_WispSplode", smelt = "Spell_Fire_Fire", craft = "Trade_BlackSmithing", gem = "INV_Misc_Gem_Ruby_02",
	remove = "INV_Hammer_20", ench = "Trade_Engraving", seal = "INV_Misc_Coin_02", insc = "INV_Scroll_03",
}
local TAB_NAME = { fuse = "융합", smelt = "분해", craft = "제작", gem = "보석", remove = "추출", ench = "마법부여", seal = "보너스", insc = "각인" }
local CELL = 42
local STEP = 52
local SOCKET_VERB = { gem = "세공하기", ench = "부여하기", insc = "각인하기" }

local function qualityOdds(weights, sep)
	local total = 0
	for q = 1, ns.MAX_QUALITY do total = total + (weights[q] or 0) end
	local parts = {}
	for q = 1, ns.MAX_QUALITY do
		local w = weights[q] or 0
		if w > 0 then
			parts[#parts + 1] = U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name) .. " " .. U.num(w / total * 100, 2) .. "%")
		end
	end
	return table.concat(parts, sep or "  ")
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

-- "Last result" block in the card: a heading, the item, a line of text.
local function addResult(cp, y)
	local r = {}
	r.head = UI.Section(cp, K.CARD_IN, "마지막 결과")
	r.head:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, y)
	r.icon = UI.IconButton(cp, 40)
	r.icon:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, y - 28)
	UI.Tip(r.icon, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
	r.text = UI.Text(cp, K.F_SMALL)
	r.text:SetPoint("TOPLEFT", cp, "TOPLEFT", 48, y - 30)
	r.text:SetWidth(K.CARD_IN - 48)
	r.text:SetJustifyV("TOP")
	function r:Set(it, text)
		self.item = it
		if it and itemExists(it) then
			self.icon.data = it
			self.icon:SetIconName(ns.Items.Icon(it))
			self.icon:SetQuality(it.q)
			self.icon:SetCount(tostring(it.l))
			self.text:SetText((text and (text .. "\n") or "") .. ns.Items.ColorName(it))
			self.head:Show()
			self.icon:Show()
		else
			self.item = nil
			self.text:SetText(text or "")
			self.head:SetShown(text ~= nil and text ~= "")
			self.icon:Hide()
		end
	end
	function r:Refresh() if self.item and not itemExists(self.item) then self:Set(nil, nil) end end
	r:Set(nil, nil)
	return r
end

local function note(parent, y, text)
	local fs = UI.Text(parent, K.F_SMALL, text)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", K.PAD, y)
	fs:SetWidth(K.LIST_IN)
	fs:SetJustifyV("TOP")
	UI.Color(fs, UI.C.dim)
	return fs
end

------------------------------------------------------------------------
-- Equipment grid with a hero row: worn gear of the chosen hero + the bag
------------------------------------------------------------------------
local function addItemPicker(page, panel, title)
	panel.strip = UI.HeroStrip(panel, ns.ROSTER_MAX, 30, 8, function(id)
		panel.hero = id
		panel.picked = nil
		Main.Refresh()
	end)
	panel.strip:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -K.PAD + 2)
	panel.gridHead = UI.Section(panel, K.LIST_IN, title)
	panel.gridHead:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -52)
	panel.grid = {}
	for i = 1, 20 do
		local b = UI.IconButton(panel, CELL, function(self)
			if self.data then
				panel.picked = self.data
				panel.pickedHero = self.heroId
				panel.rm = nil
				Main.Refresh()
			end
		end)
		local col, row = (i - 1) % 10, floor((i - 1) / 10)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD + col * STEP, -78 - row * 48)
		UI.Tip(b, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
		panel.grid[i] = b
	end
end

-- filter(item) -> bool. Returns how many items match.
local function fillPicker(panel, filter)
	if not panel.hero or not ns.db.heroes[panel.hero] then panel.hero = Main.SelectedHero() end
	panel.strip:Set(UI.HeroOrder(), panel.hero)
	local list = {}
	local id = panel.hero
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
		b:Clear()
		b.heroId = nil
		if e then
			b.data = e[1]
			b.heroId = e[2]
			b:SetIconName(ns.Items.Icon(e[1]))
			b:SetQuality(e[1].q)
			b:SetCount(tostring(e[1].l))
			b:SetMark(e[2] and "E" or "", 1, 0.82, 0)
			b:SetSelected(e[1] == panel.picked)
			if e[1] == panel.picked then found = true end
		end
	end
	if not found then
		panel.picked = list[1] and list[1][1] or nil
		panel.pickedHero = list[1] and list[1][2] or nil
		if panel.picked then panel.grid[1]:SetSelected(true) end
	end
	panel.gridHead:Set(panel.gridHead.title:GetText(), #list > 0 and (#list .. "개 · E = 착용 중") or "")
	return #list
end

local function itemHead(d, it, sub)
	local q = ns.QUALITY[it.q]
	d:Head({ icon = ns.Items.Icon(it), quality = it.q, count = tostring(it.l), data = it, title = ns.Items.Name(it),
		titleRGB = { U.rgb(q.hex) }, sub = sub, band = { U.rgb(q.hex) } })
end

------------------------------------------------------------------------
-- Operations: build(page, panel, cp) -> refresh(page, panel, cp, d)
------------------------------------------------------------------------
local ops = {}

function ops.fuse(page, panel, cp)
	panel.q, panel.cat = 2, "gear"
	panel.head = UI.Section(panel, K.LIST_IN, "재료로 쓸 장비")
	panel.head:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -K.PAD)
	panel.pick = UI.Dropdown(panel, 170, 30, function()
		local out = {}
		for q = 1, ns.MAX_QUALITY - 1 do out[#out + 1] = { q, U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) } end
		return out
	end, function() return panel.q end, function(q) panel.q = q end, "등급: ")
	panel.pick:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -40)
	panel.pick.tipTitle = "재료 등급"
	panel.pick.tipText = "이 등급의 장비 9개를 융합합니다. 눌러서 목록에서 고르세요."
	panel.catBtn = UI.Dropdown(panel, 190, 30, function()
		return { { "gear", "무기·방어구" }, { "accessory", "액세서리" } }
	end, function() return panel.cat end, function(v) panel.cat = v end, "종류: ")
	panel.catBtn:SetPoint("LEFT", panel.pick, "RIGHT", 8, 0)
	panel.catBtn.tipTitle = "재료 종류"
	panel.catBtn.tipText = "결과도 같은 종류에서 무작위 부위로 나옵니다. 눌러서 목록에서 고르세요."
	panel.inputs = {}
	local step = (K.LIST_IN - CELL) / (ns.Forge.FUSE_COUNT - 1)
	for i = 1, ns.Forge.FUSE_COUNT do
		local b = UI.IconButton(panel, CELL)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", floor(K.PAD + (i - 1) * step), -84)
		UI.Tip(b, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
		panel.inputs[i] = b
	end
	panel.note = note(panel, -140, "가장 낮은 레벨의 장비부터 씁니다. 보호한 장비, 보석이 박힌 장비, 파티에게 더 좋은 장비는 쓰지 않습니다(가방에서 Alt+클릭으로 보호).\n결과의 레벨은 재료 9개의 평균 레벨 부근이고, 부위는 같은 종류 안에서 무작위입니다. 영웅 등급부터는 등급이 오르지 않을 수도 있습니다.\n재료(광석 등)의 융합은 '가방 > 재료'에서 합니다.")

	cp.head = UI.Section(cp, K.CARD_IN, "결과 등급 확률")
	cp.head:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, 0)
	cp.out = UI.IconButton(cp, 40)
	cp.out:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, -28)
	cp.out.mark:SetText("?")
	cp.odds = UI.Text(cp, K.F_SMALL)
	cp.odds:SetPoint("TOPLEFT", cp, "TOPLEFT", 48, -30)
	cp.odds:SetWidth(K.CARD_IN - 48)
	cp.odds:SetJustifyV("TOP")
	cp.result = addResult(cp, -96)

	local function fuse(all)
		local last, n, great, outcome
		for _ = 1, all and 20 or 1 do
			local list = ns.Forge.PickForFusion(panel.q, panel.cat)
			if not list then break end
			local ok, it, oc = ns.Forge.Fuse(list)
			if not ok then UI.Try(ok, it) break end
			last, n = it, (n or 0) + 1
			if oc == "great" then great = true end
			outcome = oc
		end
		if last then
			local msg
			if n > 1 then
				msg = string.format("%d번 융합했습니다. 마지막 결과:", n)
			elseif great then
				msg = U.col("ffd100", "대성공! 두 등급 상승")
			elseif outcome == "same" then
				msg = U.col("ff8080", "등급이 오르지 않았습니다")
			else
				msg = "융합 성공"
			end
			cp.result:Set(last, msg)
		else
			UI.Try(false, string.format("잠기지 않은 같은 등급 장비 %d개가 필요합니다.", ns.Forge.FUSE_COUNT))
		end
		Main.Refresh()
	end

	return function(_, _, _, d)
		local q = ns.QUALITY[panel.q]
		panel.pick:Refresh()
		panel.catBtn:Refresh()
		local n, kept = 0, 0
		for _, it in ipairs(ns.db.bag) do
			if not it.lock and it.q == panel.q and ns.Items.FuseCat(it) == panel.cat and not ns.Items.HasSockets(it) then
				if ns.Items.PartyUpgrade(it) then kept = kept + 1 else n = n + 1 end
			end
		end
		panel.head:Set("재료로 쓸 장비", string.format("쓸 수 있는 장비 %d개 / 9개 필요", n))
		local pick = ns.Forge.PickForFusion(panel.q, panel.cat)
		for i, b in ipairs(panel.inputs) do
			local it = pick and pick[i]
			b:Clear()
			if it then
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetCount(tostring(it.l))
				b.data = it
			else
				b:SetQuality(panel.q)
				b:SetDim(true)
			end
		end
		local weights = {}
		for _, e in ipairs(ns.Forge.FUSE_ODDS[panel.q]) do weights[e[1]] = e[2] end
		cp.odds:SetText(qualityOdds(weights, "\n"))
		cp.out:SetQuality(min(ns.MAX_QUALITY, panel.q + 1))
		cp.out:SetDim(pick == nil)
		cp.result:Refresh()
		d:Head({ icon = OP_ICON.fuse, art = "forge_fuse", title = "융합", sub = string.format("%s 장비 9개 → 장비 1개", ns.N(q.name)) })
		local can = n >= ns.Forge.FUSE_COUNT
		d:Actions({ "가능한 만큼", function()
			UI.Confirm({ title = "가능한 만큼 융합", ok = "융합", style = "primary",
				text = string.format("%s 장비로 가능한 만큼(최대 20번) 융합하시겠습니까?\n재료로 쓴 장비는 사라집니다.", ns.N(q.name)),
				onOk = function() fuse(true) end })
		end, "dark", not can, tip = { "가능한 만큼 융합", "재료가 떨어질 때까지(최대 20번) 계속 융합합니다." } },
			{ "융합하기", function() fuse(false) end, "primary", not can })
		if not can then d:Reason(string.format("%s 장비가 %d개 더 필요합니다.", ns.N(q.name), ns.Forge.FUSE_COUNT - n)) end
		if kept > 0 then
			panel.note:SetText(U.col("aab3c8", string.format("파티에게 더 좋은 장비 %d개는 재료에서 뺐습니다.\n", kept)) .. panel.note.base)
		else
			panel.note:SetText(panel.note.base)
		end
	end
end

function ops.smelt(page, panel, cp)
	panel.head = UI.Section(panel, K.LIST_IN, "등급별 분해 골드")
	panel.head:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -K.PAD)
	panel.rows = {}
	for q = 1, ns.MAX_QUALITY do
		local r = UI.StatRow(panel, K.LIST_IN)
		r:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -38 - (q - 1) * 24)
		panel.rows[q] = r
	end
	panel.note = note(panel, -38 - ns.MAX_QUALITY * 24 - 10, "용광로 레벨과 비슷한 레벨의 아이템일수록 용광로 경험치를 많이 줍니다. 위는 지금 받는 골드(보너스 포함)입니다.")
	cp.text = UI.Text(cp, K.F_BODY, "분해는 가방에서 합니다.\n\n• 아이템을 우클릭하면 하나씩\n• '일괄 분해'로 기준 등급 이하를 한꺼번에\n• 설정에서 '자동 분해'를 켜면 가방이 찰 때 저절로")
	cp.text:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, 0)
	cp.text:SetWidth(K.CARD_IN)
	cp.text:SetJustifyV("TOP")
	return function(_, _, _, d)
		local level = max(1, ns.db.forge.level)
		panel.head:Set("등급별 분해 골드", string.format("%d레벨 가슴 방어구 기준", level))
		for q, r in ipairs(panel.rows) do
			local gold = ns.Items.SmeltGold({ s = "chest", l = level, q = q })
			r:Set(U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)), U.col("ffd24a", U.fmt(gold)) .. " G")
		end
		d:Head({ icon = OP_ICON.smelt, art = "forge_smelt", title = "분해", sub = "장비 → 골드, 용광로 경험치" })
		d:Actions(nil, { "가방에서 분해하기", function() Main.ShowTab("bag") end, "primary" })
	end
end

function ops.craft(page, panel, cp)
	panel.group, panel.tier = 1, 1
	panel.head = UI.Section(panel, K.LIST_IN, "만들 부위")
	panel.head:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -K.PAD)
	panel.groups = {}
	local n = #ns.CRAFT_GROUPS
	local gw = floor((K.LIST_IN - (n - 1) * 6) / n)
	for i, g in ipairs(ns.CRAFT_GROUPS) do
		local b = UI.Chip(panel, gw, 30, ns.N(g.name), function()
			panel.group = i
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD + (i - 1) * (gw + 6), -38)
		panel.groups[i] = b
	end
	panel.tierHead = UI.Section(panel, K.LIST_IN, "제작 단계")
	panel.tierHead:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -82)
	panel.tiers = {}
	for i = 1, #ns.CRAFT_TIERS do
		local row = UI.Row(panel, K.LIST_IN, 40, function()
			panel.tier = i
			Main.Refresh()
		end)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -108 - (i - 1) * 44)
		row:Layout(240)
		row.icon:SetArtIcon("forge_craft", OP_ICON.craft)
		panel.tiers[i] = row
	end
	cp.head = UI.Section(cp, K.CARD_IN, "필요 재료")
	cp.head:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, 0)
	cp.mats = {}
	for i = 1, 3 do
		local r = UI.Row(cp, K.CARD_IN, 34)
		r:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, -26 - (i - 1) * 38)
		r:Layout(70)
		r:EnableMouse(false)
		r.sub:Hide()
		r.title:ClearAllPoints()
		r.title:SetPoint("LEFT", r, "LEFT", 36, 0)
		cp.mats[i] = r
	end
	cp.fee = UI.StatRow(cp, K.CARD_IN)
	cp.fee:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, -142)
	cp.odds = UI.Text(cp, K.F_SMALL)
	cp.odds:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, -170)
	cp.odds:SetWidth(K.CARD_IN)
	cp.result = addResult(cp, -206)
	return function(_, _, _, d)
		for i, b in ipairs(panel.groups) do b:SetOn(i == panel.group) end
		for i, row in ipairs(panel.tiers) do
			local t = ns.CRAFT_TIERS[i]
			local open = ns.Forge.CraftTierUnlocked(i)
			row.title:SetText(string.format("%d단계  ·  장비 Lv %d~%d", i, t.lo, t.hi))
			if open then
				row.sub:SetText(U.col("60e070", "열림"))
			elseif ns.db.forge.level >= t.forge then
				row.sub:SetText(U.col("ffd24a", "해금 " .. U.fmt(t.gold * 5) .. " G"))
			else
				row.sub:SetText(U.col("9a8f78", string.format("용광로 Lv %d 필요", t.forge)))
			end
			local best = 0
			for q = 1, ns.MAX_QUALITY do if (t.q[q] or 0) > 0 then best = q end end
			row.right:SetText("최고 " .. U.col(ns.QUALITY[best].hex, ns.N(ns.QUALITY[best].name)))
			row.icon:SetDim(not open)
			row.icon:SetLocked(not open)
			row.badge:Set(not open and ns.db.forge.level >= t.forge and ns.CanAfford(t.gold * 5))
			row:SetSelected(i == panel.tier)
		end
		local g = ns.CRAFT_GROUPS[panel.group]
		local t = ns.CRAFT_TIERS[panel.tier]
		local open = ns.Forge.CraftTierUnlocked(panel.tier)
		local cost, gold = ns.Forge.CraftCost(panel.group, panel.tier)
		local ids = {}
		for id in pairs(cost) do ids[#ids + 1] = id end
		table.sort(ids)
		for i, r in ipairs(cp.mats) do
			local id = ids[i]
			if id then
				local m = ns.MATS[id]
				local have, need = ns.MatCount(id), cost[id]
				r.icon:SetIconName(m.icon)
				r.icon:SetQuality(m.q)
				r.title:SetText(ns.N(m.name))
				r.right:SetText(U.col(have >= need and "60e070" or "ff6a5a", U.fmt(have) .. " / " .. need))
				r:Show()
			else
				r:Hide()
			end
		end
		cp.fee:Set("제작 비용", U.col(ns.CanAfford(gold) and "ffd24a" or "ff6a5a", U.fmt(gold)) .. " G")
		cp.odds:SetText("결과 등급: " .. qualityOdds(t.q))
		cp.result:Refresh()
		d:Head({ icon = OP_ICON.craft, art = "forge_craft", title = "제작: " .. ns.N(g.name),
			sub = string.format("%d단계 · 장비 Lv %d~%d", panel.tier, t.lo, t.hi) })
		if open then
			local okc, whyc = ns.Forge.CanCraft(panel.group, panel.tier)
			d:Actions(nil, { "제작하기", function()
				local ok, it = ns.Forge.Craft(panel.group, panel.tier)
				if UI.Try(ok, it) then cp.result:Set(it, "제작 완료") end
				Main.Refresh()
			end, "primary", not okc })
			if not okc then d:Reason(whyc) end
		elseif ns.db.forge.level >= t.forge then
			d:Actions(nil, { string.format("%d단계 해금  %s G", panel.tier, U.fmt(t.gold * 5)), function()
				UI.Confirm({ title = "제작 단계 해금", ok = "해금", style = "primary",
					text = string.format("%d단계 제작을 해금하시겠습니까?\n%s 골드가 듭니다.", panel.tier, U.fmt(t.gold * 5)),
					onOk = function() UI.Try(ns.Forge.UnlockCraftTier(panel.tier)) end })
			end, "primary", not ns.CanAfford(t.gold * 5) })
			if not ns.CanAfford(t.gold * 5) then d:Reason("골드가 부족합니다.") end
		else
			d:Actions(nil, { string.format("용광로 Lv %d에 열림", t.forge), nil, "primary", true })
		end
	end
end

local function socketOp(kind)
	return function(page, panel, cp)
		local matKind = ns.SOCKET[kind].mat
		addItemPicker(page, panel, "홈이 있는 장비")
		panel.matHead = UI.Section(panel, K.LIST_IN, "쓸 재료")
		panel.matHead:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -184)
		panel.mats = {}
		for i = 1, ns.MAT_MAX_TIER[matKind] do
			local id = matKind .. i
			local b = UI.IconButton(panel, CELL, function(self)
				panel.mat = self.data
				Main.Refresh()
			end)
			b.data = id
			b:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD + (i - 1) * STEP, -210)
			UI.Tip(b, function(self) return ns.Items.MatTooltip(self.data) end, "TOP")
			panel.mats[i] = b
		end
		panel.note = note(panel, -266, "부여되는 능력치는 장비 종류(무기·방어구·액세서리)에 따라 정해진 목록에서 무작위로 정해집니다. 마음에 들지 않으면 '추출'로 비우고 다시 할 수 있습니다.")
		cp.lines = UI.Text(cp, K.F_SMALL)
		cp.lines:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, 0)
		cp.lines:SetWidth(K.CARD_IN)
		cp.lines:SetJustifyV("TOP")
		cp.last = UI.Text(cp, K.F_BODY)
		cp.last:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", 0, 0)
		cp.last:SetWidth(K.CARD_IN)
		return function(_, _, _, d)
			local n = fillPicker(panel, function(it) return ns.Items.SocketCount(it, kind) > 0 end)
			local it = panel.picked
			if not panel.mat then
				for i = 1, ns.MAT_MAX_TIER[matKind] do
					if ns.MatCount(matKind .. i) > 0 then panel.mat = matKind .. i end
				end
			end
			for _, b in ipairs(panel.mats) do
				local count = ns.MatCount(b.data)
				b:SetIconName(ns.MATS[b.data].icon)
				b:SetQuality(ns.MATS[b.data].q)
				b:SetCount(count > 0 and tostring(count) or "")
				b:SetDim(count == 0)
				b:SetSelected(panel.mat == b.data)
			end
			local name = ns.N(ns.SOCKET[kind].name)
			if not it then
				local need = (kind == "gem" and 3) or (kind == "ench" and 5) or 6
				d:Head({ icon = OP_ICON[kind], art = "forge_" .. kind, title = name, sub = "홈이 있는 장비가 없습니다" })
				cp.lines:SetText(string.format("%s 등급 이상의 장비에 홈이 있습니다.", U.col(ns.QUALITY[need].hex, ns.N(ns.QUALITY[need].name))))
				cp.last:SetText("")
				d:Actions(nil, { SOCKET_VERB[kind], nil, "primary", true })
				return
			end
			itemHead(d, it, string.format("%s 홈 %d / %d 비어 있음", ns.N(ns.SOCKET[kind].short), ns.Items.FreeSockets(it, kind), ns.Items.SocketCount(it, kind)))
			local parts = {}
			local l = ns.Items.SocketList(it, kind)
			if l then
				for _, e in ipairs(l) do parts[#parts + 1] = U.col("66ccff", "• ") .. U.col("66ccff", ns.Items.SocketText(it, kind, e)) end
			end
			if #parts == 0 then parts[1] = U.col("8a90a2", "아직 부여한 능력치가 없습니다.") end
			local pool = {}
			for _, e in ipairs(ns.SOCKET[kind][ns.Items.Cat(it)]) do pool[#pool + 1] = ns.N(ns.AFFIX[e[1]].n) end
			parts[#parts + 1] = ""
			parts[#parts + 1] = U.col("aab3c8", "나올 수 있는 능력치: " .. table.concat(pool, ", "))
			if panel.mat then parts[#parts + 1] = U.col("aab3c8", "재료: ") .. ns.N(ns.MATS[panel.mat].name) end
			cp.lines:SetText(table.concat(parts, "\n"))
			cp.last:SetText(panel.last or "")
			local can, why = false, "재료가 없습니다. 상자에서 얻을 수 있습니다."
			if panel.mat then can, why = ns.Forge.CanSocket(it, kind, panel.mat) end
			d:Actions(nil, { SOCKET_VERB[kind], function()
				local ok, entry = ns.Forge.Socket(it, kind, panel.mat, panel.pickedHero)
				if UI.Try(ok, entry) then panel.last = U.col("60e070", "부여됨: ") .. U.col("60e070", ns.Items.SocketText(it, kind, entry)) end
				Main.Refresh()
			end, "primary", not can })
			if not can then d:Reason(why) end
		end
	end
end

ops.gem = socketOp("gem")
ops.ench = socketOp("ench")
ops.insc = socketOp("insc")

function ops.remove(page, panel, cp)
	addItemPicker(page, panel, "능력치가 부여된 장비")
	panel.note = note(panel, -186, "추출하면 홈이 비워지지만 사용했던 재료는 돌아오지 않습니다. 비용은 재료 단계가 높을수록 비쌉니다.")
	cp.head = UI.Section(cp, K.CARD_IN, "지울 능력치를 고르세요")
	cp.head:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, 0)
	cp.rows = {}
	for i = 1, 6 do
		local r = UI.Row(cp, K.CARD_IN, 32, function(self)
			panel.rm = self.idx
			Main.Refresh()
		end)
		r:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, -26 - (i - 1) * 36)
		r:Layout(60) -- the stat on top, the range it could roll in below; cost at most "12,800 G"
		cp.rows[i] = r
	end
	return function(_, _, _, d)
		fillPicker(panel, function(it) return ns.Items.HasSockets(it) end)
		local it = panel.picked
		local rows = {}
		if it then
			for _, kind in ipairs(ns.SOCKET_KINDS) do
				local l = ns.Items.SocketList(it, kind)
				if l then
					for idx, e in ipairs(l) do rows[#rows + 1] = { kind, idx, e } end
				end
			end
		end
		if panel.rm and not rows[panel.rm] then panel.rm = nil end
		panel.rm = panel.rm or (rows[1] and 1)
		for i, r in ipairs(cp.rows) do
			local e = rows[i]
			r.idx = i
			if e then
				r.icon:SetArtIcon("forge_" .. e[1], OP_ICON[e[1]])
				r.title:SetText(ns.Stats.ModText(e[3][1], e[3][2]))
				r.sub:SetText(ns.Items.SocketRangeText(it, e[1], e[3]) or "고정 값")
				r.right:SetText(U.fmt(ns.Forge.RemoveCost(e[1], e[3][3])) .. " G")
				r:SetSelected(i == panel.rm)
				r:Show()
			else
				r:Hide()
			end
		end
		cp.head:SetShown(it ~= nil)
		if not it then
			d:Head({ icon = OP_ICON.remove, art = "forge_remove", title = "추출", sub = "능력치가 부여된 장비가 없습니다" })
			d:Actions(nil, { "추출하기", nil, "red", true })
			return
		end
		itemHead(d, it, string.format("부여된 능력치 %d개", #rows))
		local e = panel.rm and rows[panel.rm]
		if e then
			local cost = ns.Forge.RemoveCost(e[1], e[3][3])
			d:Actions(nil, { "추출  " .. U.fmt(cost) .. " G", function()
				UI.Confirm({ title = "추출", ok = "추출", style = "red",
					text = string.format("'%s'을(를) 추출하시겠습니까?\n홈이 비워지고 사용했던 재료는 돌아오지 않습니다. %s 골드가 듭니다.",
						ns.Stats.ModText(e[3][1], e[3][2]), U.fmt(cost)),
					onOk = function()
						UI.Try(ns.Forge.RemoveSocket(it, e[1], e[2], panel.pickedHero))
						panel.rm = nil
					end })
			end, "red", not ns.CanAfford(cost) })
			if not ns.CanAfford(cost) then d:Reason("골드가 부족합니다.") end
		else
			d:Actions(nil, { "추출하기", nil, "red", true })
		end
	end
end

function ops.seal(page, panel, cp)
	panel.sel = 1
	panel.head = UI.Section(panel, K.LIST_IN, "행운의 인장")
	panel.head:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -K.PAD)
	panel.rows = {}
	for i, s in ipairs(ns.SEAL) do
		local r = UI.Row(panel, K.LIST_IN, 44, function()
			panel.sel = i
			Main.Refresh()
		end)
		r:SetPoint("TOPLEFT", panel, "TOPLEFT", K.PAD, -38 - (i - 1) * 50)
		r:Layout(110)
		r.icon:SetIconName(ns.MATS[s.mat].icon)
		r.icon:SetQuality(ns.MATS[s.mat].q)
		UI.Tip(r, function() return ns.Items.MatTooltip(s.mat) end, "TOP")
		panel.rows[i] = r
	end
	panel.note = note(panel, -38 - #ns.SEAL * 50 - 6, "행운의 인장은 상자에서 드물게 나옵니다. 결과 장비의 레벨은 지금까지 도달한 가장 높은 스테이지를 따릅니다.")
	cp.head = UI.Section(cp, K.CARD_IN, "결과 등급 확률")
	cp.head:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, 0)
	cp.odds = UI.Text(cp, K.F_SMALL)
	cp.odds:SetPoint("TOPLEFT", cp, "TOPLEFT", 0, -28)
	cp.odds:SetWidth(K.CARD_IN)
	cp.odds:SetJustifyV("TOP")
	cp.result = addResult(cp, -150)
	return function(_, _, _, d)
		for i, r in ipairs(panel.rows) do
			local s = ns.SEAL[i]
			local count = ns.MatCount(s.mat)
			r.title:SetText(ns.N(ns.MATS[s.mat].name))
			r.sub:SetText("가진 개수 " .. count)
			r.right:SetText(U.col(ns.CanAfford(s.gold) and "ffd24a" or "ff6a5a", U.fmt(s.gold)) .. " G")
			r.icon:SetCount(count > 0 and tostring(count) or "")
			r.icon:SetDim(count == 0)
			r:SetSelected(i == panel.sel)
		end
		local s = ns.SEAL[panel.sel]
		local m = ns.MATS[s.mat]
		local count = ns.MatCount(s.mat)
		cp.odds:SetText(qualityOdds(s.q, "\n"))
		cp.result:Refresh()
		d:Head({ icon = m.icon, quality = m.q, count = tostring(count), title = ns.N(m.name), titleRGB = { U.rgb(ns.QUALITY[m.q].hex) },
			sub = string.format("가진 개수 %d · 비용 %s G", count, U.fmt(s.gold)) })
		d:Actions(nil, { "굴리기", function()
			local ok, it = ns.Forge.BonusRoll(panel.sel)
			if UI.Try(ok, it) then cp.result:Set(it, "굴림 결과") end
			Main.Refresh()
		end, "primary", count == 0 or not ns.CanAfford(s.gold) or ns.Items.BagFree() <= 0 })
		if count == 0 then
			d:Reason("이 인장이 없습니다. 상자에서 드물게 나옵니다.")
		elseif not ns.CanAfford(s.gold) then
			d:Reason("골드가 부족합니다.")
		elseif ns.Items.BagFree() <= 0 then
			d:Reason("가방이 가득 찼습니다.")
		end
	end
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.op = "fuse"
	local tabs = {}
	for _, d in ipairs(ns.FORGE_OPS) do tabs[#tabs + 1] = { d.key, TAB_NAME[d.key] or ns.N(d.name) } end
	local S = UI.Screen(page, {
		tabs = tabs,
		onTab = function(key)
			page.op = key
			Main.Refresh()
		end,
	})
	page.S = S
	page.xp = UI.Bar(S.tools, K.CARD_W, K.TAB_H - 4, 0.95, 0.55, 0.15)
	page.xp:SetPoint("RIGHT", S.tools, "RIGHT", 0, 0)
	page.xp.text:SetFont(ns.FONT, K.F_SMALL, "OUTLINE")
	page.xp:EnableMouse(true)
	UI.Tip(page.xp, function()
		return UI.SimpleTip("용광로 레벨", "아이템을 분해·융합·제작해 소모하면 경험치가 오릅니다. 레벨이 오르면 새 기능과 제작 단계가 열립니다.")
	end, "TOP")
	for _, b in ipairs(S.tabs.buttons) do
		UI.Tip(b, function(self)
			local d = ns.Forge.OpDef(self.key)
			local lines = { { ns.N(d.name), nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }, { ns.N(d.desc), nil, 1, 1, 1 } }
			if not ns.Forge.Unlocked(d.key) then
				lines[#lines + 1] = { string.format("용광로 %d레벨 필요", d.level), nil, 1, 0.5, 0.3 }
				lines[#lines + 1] = { "해금 비용", U.fmt(d.cost) .. " G", UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }
			end
			return lines
		end, "TOP")
	end

	page.panels, page.cps, page.refreshers = {}, {}, {}
	for _, d in ipairs(ns.FORGE_OPS) do
		local panel = CreateFrame("Frame", nil, S.list)
		panel:SetAllPoints(S.list)
		panel:Hide()
		local cp = CreateFrame("Frame", nil, S.card.content)
		cp:SetAllPoints(S.card.content)
		cp:Hide()
		page.panels[d.key], page.cps[d.key] = panel, cp
		page.refreshers[d.key] = ops[d.key](page, panel, cp)
		if panel.note then panel.note.base = panel.note:GetText() end
	end

	-- a function that is not unlocked yet
	page.locked = CreateFrame("Frame", nil, S.list)
	page.locked:SetAllPoints(S.list)
	page.lockG = UI.Glyph(page.locked, "lock", 56, 0.6, 0.55, 0.45)
	page.lockG:SetPoint("TOP", page.locked, "TOP", 0, -90)
	page.lockText = UI.Text(page.locked, 13)
	page.lockText:SetPoint("TOP", page.locked, "TOP", 0, -160)
	page.lockText:SetWidth(K.LIST_IN - 40)
	page.lockText:SetJustifyH("CENTER")
	page.lockCard = UI.Text(S.card.content, K.F_BODY)
	page.lockCard:SetPoint("TOPLEFT", S.card.content, "TOPLEFT", 0, 0)
	page.lockCard:SetWidth(K.CARD_IN)
	page.lockCard:SetJustifyV("TOP")
end

local function refresh(page)
	local S = page.S
	local d = S.card
	local f = ns.db.forge
	if f.level >= ns.FORGE_MAX then
		page.xp:SetValue(1)
		page.xp:SetLabel(string.format("용광로 Lv %d · 최고 레벨", f.level))
	else
		local need = ns.Forge.Need(f.level)
		page.xp:SetValue(f.xp / need)
		page.xp:SetLabel(string.format("용광로 Lv %d · %s / %s", f.level, U.fmt(f.xp), U.fmt(need)))
	end
	S.tabs:Select(page.op)
	for _, od in ipairs(ns.FORGE_OPS) do
		local open = ns.Forge.Unlocked(od.key)
		S.tabs:SetLocked(od.key, not open)
		S.tabs:SetBadge(od.key, not open and f.level >= od.level and ns.CanAfford(od.cost))
		page.panels[od.key]:Hide()
		page.cps[od.key]:Hide()
	end
	d:Extras(nil, nil)
	local od = ns.Forge.OpDef(page.op)
	if ns.Forge.Unlocked(page.op) then
		page.locked:Hide()
		page.lockCard:Hide()
		page.panels[page.op]:Show()
		page.cps[page.op]:Show()
		page.refreshers[page.op](page, page.panels[page.op], page.cps[page.op], d)
		return
	end
	page.locked:Show()
	page.lockCard:Show()
	local okLevel = f.level >= od.level
	page.lockText:SetText(string.format("'%s'은(는) 아직 잠겨 있습니다.\n용광로 레벨은 아이템을 분해·융합·제작하면 오릅니다.", ns.N(od.name)))
	d:Head({ icon = OP_ICON[od.key], art = "forge_" .. od.key, dim = true, locked = true, title = ns.N(od.name), sub = ns.N(od.short or "") })
	page.lockCard:SetText(ns.N(od.desc) .. "\n\n" ..
		string.format("필요한 용광로 레벨: %s", U.col(okLevel and "6af07a" or "ff6a5a", tostring(od.level))) .. "\n" ..
		string.format("해금 비용: %s G", U.col(ns.CanAfford(od.cost) and "ffd24a" or "ff6a5a", U.fmt(od.cost))))
	d:Actions(nil, { okLevel and ("해금하기  " .. U.fmt(od.cost) .. " G") or string.format("용광로 Lv %d에 열림", od.level), function()
		UI.Try(ns.Forge.Unlock(page.op))
		Main.Refresh()
	end, "primary", not okLevel or not ns.CanAfford(od.cost) })
	if okLevel and not ns.CanAfford(od.cost) then d:Reason("골드가 부족합니다.") end
end

local function open(page, opts)
	if opts and opts.sub and ns.Forge.OpDef(opts.sub) then page.op = opts.sub end
end

local function tick(page) end

Main.RegisterTab({
	key = "forge", title = "용광로", sub = "장비를 융합하고, 분해하고, 만들고, 강화합니다",
	icon = "Trade_BlackSmithing", art = "icon_forge", build = build, refresh = refresh, open = open, tick = tick,
	events = { "FORGE", "BAG", "MATS", "GEAR", "RESET", "GOLD" },
})
