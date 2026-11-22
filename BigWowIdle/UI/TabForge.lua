-- The Titan Forge (용광로) as tabs of the equipment screen (UI/TabEquip.lua):
--   융합 (합성): grade chips, the bag's items of that grade (the next nine
--         to be used framed in gold), 1회 / 가능한 만큼, the last result;
--   제작: part chips, the tiers, what a tier needs, 제작하기;
--   보석 · 마법부여 · 각인: items with sockets; the chosen item's sockets
--         drawn with what is set in them ([추출] on each); the material to
--         set; 세공하기 / 부여하기 / 각인하기.
-- A function not unlocked yet shows what it needs and [해금하기].
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local ForgeView = {}
ns.ForgeView = ForgeView

local W, H = 526, 456
local CELL, STEP = 46, 52
local OP_ICON = {
	fuse = "Spell_Nature_WispSplode", smelt = "Spell_Fire_Fire", craft = "Trade_BlackSmithing", gem = "INV_Misc_Gem_Ruby_02",
	remove = "INV_Hammer_20", ench = "Trade_Engraving", seal = "INV_Misc_Coin_02", insc = "INV_Scroll_03",
}
ForgeView.OP_ICON = OP_ICON
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

local function itemExists(it)
	if not it then return false end
	if ns.Items.IndexInBag(it) then return true end
	for _, h in pairs(ns.db.heroes) do
		for _, g in pairs(h.gear) do if g == it then return true end end
	end
	return false
end

-- "최근 결과": a small label, the item and its name
local function addResult(f, x, y)
	local r = {}
	r.head = UI.Text(f, 11, "최근 결과")
	r.head:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
	UI.Color(r.head, UI.C.sub)
	r.icon = UI.IconButton(f, 40)
	r.icon:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 18)
	UI.Tip(r.icon, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
	r.text = UI.Text(f, 11)
	r.text:SetPoint("TOPLEFT", f, "TOPLEFT", x + 46, y - 20)
	r.text:SetWidth(W - x - 46)
	r.text:SetJustifyV("TOP")
	function r:Set(it, text)
		self.item, self.msg = it, text
		self:Refresh()
	end
	function r:Refresh()
		local it = self.item
		self.icon:Clear()
		if it and itemExists(it) then
			self.icon.data = it
			self.icon:SetIconName(ns.Items.Icon(it))
			self.icon:SetQuality(it.q)
			self.icon:SetCount(tostring(it.l))
			self.text:SetText((self.msg and (self.msg .. "\n") or "") .. ns.Items.ColorName(it))
		else
			self.icon.data = nil
			self.text:SetText(U.col("8a90a2", self.msg or "없음"))
		end
	end
	r:Set(nil, nil)
	return r
end

local function note(f, y, text)
	local fs = UI.Text(f, 11, text)
	fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	fs:SetWidth(W)
	fs:SetJustifyV("TOP")
	fs:SetSpacing(2)
	UI.Color(fs, UI.C.dim)
	return fs
end

------------------------------------------------------------------------
-- 융합
------------------------------------------------------------------------
local FUSE_COLS, FUSE_ROWS = 10, 4

local function buildFuse(page, f)
	local p = { q = 2, cat = "gear" }
	local function grades(a, b)
		local out = {}
		for q = a, b do
			out[#out + 1] = { q, ns.N(ns.QUALITY[q].name) .. " → " .. ns.N(ns.QUALITY[q + 1].name) }
		end
		return out
	end
	-- how many items of a grade (in the chosen kind) a fusion could use
	local function usableCount(q)
		local n = 0
		for _, it in ipairs(ns.db.bag) do
			if it.q == q and ns.Items.FuseCat(it) == p.cat and not it.lock and not ns.Items.HasSockets(it)
				and not ns.Items.PartyUpgrade(it) then n = n + 1 end
		end
		return n
	end
	-- the grade: picked from a list, like the bag's 분해 등급
	p.gradeLabel = UI.Text(f, 12, "융합 등급")
	p.gradeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -8)
	p.pick = UI.Dropdown(f, 220, 28, function()
		local out = {}
		for _, g in ipairs(grades(1, ns.MAX_QUALITY - 1)) do
			local q, n = g[1], usableCount(g[1])
			local a, b = ns.QUALITY[q], ns.QUALITY[q + 1]
			out[#out + 1] = { q, U.col(a.hex, ns.N(a.name)) .. " → " .. U.col(b.hex, ns.N(b.name))
				.. U.col(n >= ns.Forge.FUSE_COUNT and "60e070" or "8a90a2", string.format("  (%d개)", n)) }
		end
		return out
	end, function() return p.q end, function(q) p.q = q end, "")
	p.pick:SetPoint("TOPLEFT", f, "TOPLEFT", 66, 0)
	p.pick.tipTitle = "융합 등급"
	p.pick.tipText = "융합할 장비의 등급을 고릅니다. 괄호 안은 지금 쓸 수 있는 장비 수(9개면 융합할 수 있음)."
	p.kinds = UI.Tabs(f, 218, { { "gear", "무기·방어구" }, { "accessory", "액세서리" } }, function(k) p.cat = k Main.Refresh() end, false, 28)
	p.kinds:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	p.head = UI.Section(f, W)
	p.head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
	p.cells = {}
	for i = 1, FUSE_COLS * FUSE_ROWS do
		local b = UI.IconButton(f, CELL)
		local col, row = (i - 1) % FUSE_COLS, floor((i - 1) / FUSE_COLS)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * STEP, -68 - row * STEP)
		UI.Tip(b, function(self)
			if not self.data then return nil end
			local lines = ns.Items.Tooltip(self.data, Main.SelectedHero())
			if self.why then lines[#lines + 1] = { self.why, nil, 1, 0.6, 0.4 } end
			return lines
		end)
		p.cells[i] = b
	end
	p.info = UI.Text(f, 13)
	p.info:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -282)
	p.info:SetWidth(W)
	p.odds = UI.Text(f, 11)
	p.odds:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -304)
	p.odds:SetWidth(W)
	p.odds:SetWordWrap(false)
	local function fuse(all)
		local last, n, great, outcome
		for _ = 1, all and 20 or 1 do
			local list = ns.Forge.PickForFusion(p.q, p.cat)
			if not list then break end
			local ok, it, oc = ns.Forge.Fuse(list)
			if not ok then UI.Try(ok, it) break end
			last, n = it, (n or 0) + 1
			if oc == "great" then great = true end
			outcome = oc
		end
		if last then
			local msg = n > 1 and string.format("%d번 융합", n) or (great and U.col("ffd100", "대성공! 두 등급 상승") or (outcome == "same" and U.col("ff8080", "등급이 오르지 않음") or "융합 성공"))
			p.result:Set(last, msg)
		else
			UI.Try(false, string.format("쓸 수 있는 같은 등급 장비 %d개가 필요합니다.", ns.Forge.FUSE_COUNT))
		end
		Main.Refresh()
	end
	p.one = UI.Button(f, 170, 36, "1회 융합", function() fuse(false) end, "primary")
	p.one:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -332)
	p.one.clickWhenOff = true
	p.all = UI.Button(f, 170, 36, "가능한 만큼 융합", function()
		local q = ns.QUALITY[p.q]
		if not ns.Forge.PickForFusion(p.q, p.cat) then
			UI.Try(false, string.format("쓸 수 있는 같은 등급 장비 %d개가 필요합니다.", ns.Forge.FUSE_COUNT))
			return
		end
		UI.Confirm({ title = "가능한 만큼 융합", ok = "융합", style = "primary",
			text = string.format("%s 장비로 가능한 만큼(최대 20번) 융합하시겠습니까?\n재료로 쓴 장비는 사라집니다.", ns.N(q.name)),
			onOk = function() fuse(true) end })
	end, "dark")
	p.all:SetPoint("LEFT", p.one, "RIGHT", 8, 0)
	p.all.clickWhenOff = true
	p.result = addResult(f, 372, -326)
	p.note = note(f, -384, "같은 등급 장비 9개 → 장비 1개. 가장 낮은 레벨부터 쓰고, 보호한 장비(가방에서 Alt+클릭), 보석·마법부여·각인이 붙은 장비, 파티에게 더 좋은 장비는 쓰지 않습니다. 결과의 레벨은 재료의 평균 부근, 부위는 같은 종류 안에서 무작위입니다.")
	p.refresh = function()
		p.pick:Refresh()
		p.kinds:Select(p.cat)
		local q = ns.QUALITY[p.q]
		local pick = ns.Forge.PickForFusion(p.q, p.cat)
		local used = {}
		for _, it in ipairs(pick or {}) do used[it] = true end
		local list, usable = {}, 0
		for _, it in ipairs(ns.db.bag) do
			if it.q == p.q and ns.Items.FuseCat(it) == p.cat then
				list[#list + 1] = it
				if not it.lock and not ns.Items.HasSockets(it) and not ns.Items.PartyUpgrade(it) then usable = usable + 1 end
			end
		end
		local kindName = p.cat == "gear" and "무기·방어구" or "액세서리"
		p.head:Set(string.format("가방의 %s %s  %d개", U.col(q.hex, ns.N(q.name)), kindName, #list),
			string.format("쓸 수 있는 것 %d개 · 금색 테두리 = 다음 융합에 쓰임", usable))
		for i, b in ipairs(p.cells) do
			local it = list[i]
			b:Clear()
			b.data, b.why = it, nil
			if it then
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetCount(tostring(it.l))
				b:SetLocked(it.lock)
				b:SetSelected(used[it] == true)
				if it.lock then b.why = "보호한 장비는 쓰지 않습니다."
				elseif ns.Items.HasSockets(it) then b.why = "보석·마법부여·각인이 붙은 장비는 쓰지 않습니다."
				elseif ns.Items.PartyUpgrade(it) then b.why = "파티에게 더 좋은 장비라 쓰지 않습니다." end
				b:SetDim(b.why ~= nil)
			end
		end
		local have = pick and ns.Forge.FUSE_COUNT or min(usable, ns.Forge.FUSE_COUNT)
		p.info:SetText(string.format("재료 %s / %d개  ·  비용 없음", U.col(pick and "60e070" or "ff9a7a", tostring(have)), ns.Forge.FUSE_COUNT))
		local weights = {}
		for _, e in ipairs(ns.Forge.FUSE_ODDS[p.q]) do weights[e[1]] = e[2] end
		p.odds:SetText("결과: " .. qualityOdds(weights, " · "))
		p.one:SetOff(pick == nil)
		p.all:SetOff(pick == nil)
		p.result:Refresh()
	end
	return p
end

------------------------------------------------------------------------
-- 제작
------------------------------------------------------------------------
local function buildCraft(page, f)
	local p = { group = 1, tier = 1 }
	local groups = {}
	for i, g in ipairs(ns.CRAFT_GROUPS) do groups[i] = { i, ns.N(g.name) } end
	p.groups = UI.Tabs(f, W, groups, function(i) p.group = i Main.Refresh() end, true, 28)
	p.groups:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	p.head = UI.Section(f, W, "제작 단계")
	p.head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
	p.tiers = {}
	for i = 1, #ns.CRAFT_TIERS do
		local row = UI.Row(f, W, 36, function() p.tier = i Main.Refresh() end)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -66 - (i - 1) * 40)
		row:Layout(220)
		row.icon:SetArtIcon("forge_craft", OP_ICON.craft)
		p.tiers[i] = row
	end
	local y = -66 - #ns.CRAFT_TIERS * 40 - 6
	p.matHead = UI.Section(f, 300, "필요 재료")
	p.matHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	p.mats = {}
	for i = 1, 3 do
		local b = UI.IconButton(f, 32)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 26 - (i - 1) * 36)
		UI.Tip(b, function(self) return self.data and ns.Items.MatTooltip(self.data) or nil end)
		b.text = UI.Text(f, 12)
		b.text:SetPoint("LEFT", b, "RIGHT", 8, 0)
		b.text:SetWidth(250)
		b.text:SetWordWrap(false)
		p.mats[i] = b
	end
	p.fee = UI.Text(f, 12)
	p.fee:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 134)
	p.fee:SetWidth(W - 212)
	p.fee:SetWordWrap(false)
	p.odds = UI.Text(f, 11)
	p.odds:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 154)
	p.odds:SetWidth(W - 212)
	p.odds:SetWordWrap(false)
	p.result = addResult(f, 320, y)
	p.go = UI.Button(f, 200, 36, "", function()
		local t = ns.CRAFT_TIERS[p.tier]
		if not ns.Forge.CraftTierUnlocked(p.tier) then
			if ns.db.forge.level < t.forge then
				UI.Try(false, string.format("용광로 Lv %d에 열립니다.", t.forge))
				return
			end
			UI.Confirm({ title = "제작 단계 해금", ok = "해금", style = "primary",
				text = string.format("%d단계 제작을 해금하시겠습니까?\n%s 골드가 듭니다.", p.tier, U.fmt(t.gold * 5)),
				onOk = function() UI.Try(ns.Forge.UnlockCraftTier(p.tier)) end })
			return
		end
		local ok, it = ns.Forge.Craft(p.group, p.tier)
		if UI.Try(ok, it) then p.result:Set(it, "제작 완료") end
		Main.Refresh()
	end, "primary")
	p.go:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	p.go.clickWhenOff = true
	p.why = UI.Text(f, 11)
	p.why:SetPoint("BOTTOMRIGHT", p.go, "TOPRIGHT", 0, 6)
	p.why:SetWidth(200)
	p.why:SetJustifyH("RIGHT")
	p.why:SetTextColor(1, 0.55, 0.45)
	p.refresh = function()
		p.groups:Select(p.group)
		for i, row in ipairs(p.tiers) do
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
			row:SetSelected(i == p.tier)
		end
		local t = ns.CRAFT_TIERS[p.tier]
		local open = ns.Forge.CraftTierUnlocked(p.tier)
		local cost, gold = ns.Forge.CraftCost(p.group, p.tier)
		local ids = {}
		for id in pairs(cost) do ids[#ids + 1] = id end
		table.sort(ids)
		for i, b in ipairs(p.mats) do
			local id = ids[i]
			b:Clear()
			b.data = id
			if id then
				local m = ns.MATS[id]
				local have, need = ns.MatCount(id), cost[id]
				b:SetIconName(m.icon)
				b:SetQuality(m.q)
				b.text:SetText(ns.N(m.name) .. "  " .. U.col(have >= need and "60e070" or "ff6a5a", U.fmt(have) .. " / " .. need))
				b:Show()
				b.text:Show()
			else
				b:Hide()
				b.text:Hide()
			end
		end
		p.fee:SetText("제작 비용  " .. U.col(ns.CanAfford(gold) and "ffd24a" or "ff6a5a", U.fmt(gold) .. " G"))
		p.odds:SetText("결과: " .. qualityOdds(t.q, " · "))
		p.result:Refresh()
		p.why:SetText("")
		if open then
			local okc, whyc = ns.Forge.CanCraft(p.group, p.tier)
			p.go:SetLabel("제작하기")
			p.go:SetOff(not okc)
			if not okc then p.why:SetText(whyc or "") end
		elseif ns.db.forge.level >= t.forge then
			p.go:SetLabel(string.format("%d단계 해금  %s G", p.tier, U.fmt(t.gold * 5)))
			p.go:SetOff(not ns.CanAfford(t.gold * 5))
			if not ns.CanAfford(t.gold * 5) then p.why:SetText("골드가 부족합니다.") end
		else
			p.go:SetLabel(string.format("용광로 Lv %d에 열림", t.forge))
			p.go:SetOff(true)
		end
	end
	return p
end

------------------------------------------------------------------------
-- 보석 · 마법부여 · 각인
------------------------------------------------------------------------
local SOCK_COLS, SOCK_ROWS = 10, 2

local function buildSocket(kind)
	return function(page, f)
		local p = { kind = kind }
		local matKind = ns.SOCKET[kind].mat
		p.head = UI.Section(f, W)
		p.head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		p.cells = {}
		for i = 1, SOCK_COLS * SOCK_ROWS do
			local b = UI.IconButton(f, CELL, function(self)
				if self.data then p.picked, p.pickedHero = self.data, self.heroId Main.Refresh() end
			end)
			local col, row = (i - 1) % SOCK_COLS, floor((i - 1) / SOCK_COLS)
			b:SetPoint("TOPLEFT", f, "TOPLEFT", col * STEP, -26 - row * STEP)
			UI.Tip(b, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
			p.cells[i] = b
		end
		-- the chosen item and its sockets
		local c = UI.Panel(f, W, 176, "card")
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -136)
		p.card = c
		c.isRow = true -- an [추출] button on every socket line
		c.icon = UI.IconButton(c, 44)
		c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -12)
		UI.Tip(c.icon, function(self) return self.data and ns.Items.Tooltip(self.data, Main.SelectedHero()) or nil end)
		c.name = UI.Text(c, 14)
		c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -14)
		c.name:SetWidth(W - 80)
		c.name:SetWordWrap(false)
		c.sub = UI.Text(c, 11)
		c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -36)
		c.sub:SetWidth(W - 80)
		c.sub:SetWordWrap(false)
		UI.Color(c.sub, UI.C.sub)
		c.rows = {}
		for i = 1, 2 do
			local y = -68 - (i - 1) * 34
			local r = {}
			r.socket = UI.Socket(c, 26)
			r.socket:SetPoint("TOPLEFT", c, "TOPLEFT", 12, y)
			r.text = UI.Text(c, 12)
			r.text:SetPoint("TOPLEFT", c, "TOPLEFT", 46, y - 6)
			r.text:SetWidth(W - 46 - 130)
			r.text:SetWordWrap(false)
			r.remove = UI.Button(c, 112, 26, "", function()
				local it = p.picked
				local l = it and ns.Items.SocketList(it, kind)
				local e = l and l[i]
				if not e then return end
				if not ns.Forge.Unlocked("remove") then
					ns.ForgeUnlock.Ask("remove")
					return
				end
				local cost = ns.Forge.RemoveCost(kind, e[3])
				UI.Confirm({ title = "추출", ok = "추출", style = "red",
					text = string.format("'%s'을(를) 추출하시겠습니까?\n홈이 비워지고 사용했던 재료는 돌아오지 않습니다. %s 골드가 듭니다.",
						ns.Stats.ModText(e[1], e[2]), U.fmt(cost)),
					onOk = function() UI.Try(ns.Forge.RemoveSocket(it, kind, i, p.pickedHero)) end })
			end, "red")
			r.remove:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, y)
			r.remove.clickWhenOff = true
			c.rows[i] = r
		end
		c.pool = UI.Text(c, 11)
		c.pool:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 12, 10)
		c.pool:SetWidth(W - 24)
		UI.Color(c.pool, UI.C.sub)
		p.empty = UI.Text(c, 12)
		p.empty:SetPoint("CENTER", c, "CENTER", 0, 0)
		p.empty:SetWidth(W - 40)
		p.empty:SetJustifyH("CENTER")
		UI.Color(p.empty, UI.C.sub)
		-- the material to set
		p.matHead = UI.Section(f, W, "쓸 재료")
		p.matHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -320)
		p.mats = {}
		for i = 1, ns.MAT_MAX_TIER[matKind] do
			local b = UI.IconButton(f, CELL, function(self) p.mat = self.matId Main.Refresh() end)
			b.matId = matKind .. i
			b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * STEP, -346)
			UI.Tip(b, function(self) return ns.Items.MatTooltip(self.matId) end, "TOP")
			p.mats[i] = b
		end
		p.go = UI.Button(f, 180, 36, SOCKET_VERB[kind], function()
			if not p.picked then
				UI.Try(false, string.format("%s 홈이 있는 장비가 없습니다.", ns.N(ns.SOCKET[kind].short)))
				return
			elseif not p.mat then
				UI.Try(false, "쓸 재료가 없습니다. 상자에서 얻을 수 있습니다.")
				return
			end
			local ok, entry = ns.Forge.Socket(p.picked, kind, p.mat, p.pickedHero)
			if UI.Try(ok, entry) then
				p.last = U.col("60e070", "부여됨: ") .. U.col("60e070", ns.Items.SocketText(p.picked, kind, entry))
			end
			Main.Refresh()
		end, "primary")
		p.go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
		p.go.clickWhenOff = true
		p.why = UI.Text(f, 11)
		p.why:SetPoint("LEFT", p.go, "RIGHT", 12, 6)
		p.why:SetWidth(W - 200)
		p.why:SetWordWrap(false)
		p.why:SetTextColor(1, 0.55, 0.45)
		p.lastText = UI.Text(f, 11)
		p.lastText:SetPoint("LEFT", p.go, "RIGHT", 12, -9)
		p.lastText:SetWidth(W - 200)
		p.lastText:SetWordWrap(false)
		p.refresh = function()
			-- the items: the hero on the left first, then the bag
			local id = Main.SelectedHero()
			local list = {}
			if id then
				for _, slot in ipairs(ns.SLOTS) do
					local it = ns.db.heroes[id].gear[slot]
					if it and ns.Items.SocketCount(it, kind) > 0 then list[#list + 1] = { it, id } end
				end
			end
			for _, it in ipairs(ns.db.bag) do
				if ns.Items.SocketCount(it, kind) > 0 then list[#list + 1] = { it } end
			end
			local found = false
			for _, e in ipairs(list) do if e[1] == p.picked then found = true end end
			if not found then p.picked, p.pickedHero = list[1] and list[1][1], list[1] and list[1][2] end
			p.head:Set("홈이 있는 장비", string.format("%d개 · E = 왼쪽 영웅이 착용 중", #list))
			for i, b in ipairs(p.cells) do
				local e = list[i]
				b:Clear()
				b.data, b.heroId = e and e[1], e and e[2]
				if e then
					b:SetIconName(ns.Items.Icon(e[1]))
					b:SetQuality(e[1].q)
					b:SetCount(tostring(e[1].l))
					b:SetMark(e[2] and "E" or "", 1, 0.82, 0)
					b:SetSelected(e[1] == p.picked)
					local free = ns.Items.FreeSockets(e[1], kind)
					if free > 0 then b:SetBadge(free) end
				end
			end
			-- materials: keep a usable one picked
			if not p.mat or ns.MatCount(p.mat) <= 0 then
				p.mat = nil
				for i = ns.MAT_MAX_TIER[matKind], 1, -1 do
					if not p.mat and ns.MatCount(matKind .. i) > 0 then p.mat = matKind .. i end
				end
			end
			for _, b in ipairs(p.mats) do
				local count = ns.MatCount(b.matId)
				b:Clear()
				b:SetIconName(ns.MATS[b.matId].icon)
				b:SetQuality(ns.MATS[b.matId].q)
				b:SetCount(count > 0 and tostring(count) or "")
				b:SetDim(count == 0)
				b:SetSelected(p.mat == b.matId)
			end
			local it = p.picked
			local c = p.card
			p.empty:SetShown(it == nil)
			for _, w in ipairs({ c.icon, c.name, c.sub, c.pool }) do w:SetShown(it ~= nil) end
			if not it then
				local need = (kind == "gem" and 3) or (kind == "ench" and 5) or 6
				p.empty:SetText(string.format("%s 등급 이상의 장비에 %s 홈이 있습니다.",
					U.col(ns.QUALITY[need].hex, ns.N(ns.QUALITY[need].name)), ns.N(ns.SOCKET[kind].short)))
				for _, r in ipairs(c.rows) do r.socket:Hide() r.text:Hide() r.remove:Hide() end
				p.go:SetOff(true)
				p.why:SetText("")
				p.lastText:SetText(p.last or "")
				return
			end
			local q = ns.QUALITY[it.q]
			c.icon:Clear()
			c.icon.data = it
			c.icon:SetIconName(ns.Items.Icon(it))
			c.icon:SetQuality(it.q)
			c.icon:SetCount(tostring(it.l))
			c.name:SetText(U.col(q.hex, ns.Items.Name(it)))
			c.sub:SetText(string.format("%s 홈 %d개 중 %d개 비어 있음", ns.N(ns.SOCKET[kind].short), ns.Items.SocketCount(it, kind), ns.Items.FreeSockets(it, kind)))
			local l = ns.Items.SocketList(it, kind)
			for i, r in ipairs(c.rows) do
				local has = i <= ns.Items.SocketCount(it, kind)
				local e = has and l and l[i]
				r.socket:SetShown(has)
				r.text:SetShown(has)
				r.remove:SetShown(e ~= nil and e ~= false)
				if has then
					if e then
						r.socket:Set(kind, ns.Items.SocketIcon(kind, e[3]))
						r.text:SetText(U.col("66ccff", ns.Items.SocketText(it, kind, e)))
						if ns.Forge.Unlocked("remove") then
							r.remove:SetStyle("red")
							r.remove:SetLabel("추출 " .. U.fmt(ns.Forge.RemoveCost(kind, e[3])) .. " G")
							r.remove:SetOff(not ns.CanAfford(ns.Forge.RemoveCost(kind, e[3])))
						else
							local label, off, style = ns.ForgeUnlock.Label("remove", "추출")
							r.remove:SetStyle(style)
							r.remove:SetLabel(label)
							r.remove:SetOff(off)
						end
					else
						r.socket:Set(kind, nil)
						r.text:SetText(U.col("8a90a2", "빈 " .. ns.N(ns.SOCKET[kind].short) .. " 홈"))
					end
				end
			end
			local pool = {}
			for _, e in ipairs(ns.SOCKET[kind][ns.Items.Cat(it)]) do pool[#pool + 1] = ns.N(ns.AFFIX[e[1]].n) end
			c.pool:SetText("나올 수 있는 능력치(무작위): " .. table.concat(pool, ", "))
			local can, why = false, "재료가 없습니다. 상자에서 얻을 수 있습니다."
			if p.mat then can, why = ns.Forge.CanSocket(it, kind, p.mat) end
			p.go:SetOff(not can)
			p.why:SetText(can and "" or (why or ""))
			p.lastText:SetText(p.last or "")
		end
		return p
	end
end

------------------------------------------------------------------------
-- A function not unlocked yet
------------------------------------------------------------------------
local function buildLocked(page, f)
	local p = {}
	p.glyph = UI.Glyph(f, "lock", 56, 0.6, 0.55, 0.45)
	p.glyph:SetPoint("TOP", f, "TOP", 0, -90)
	p.text = UI.Text(f, 13)
	p.text:SetPoint("TOP", f, "TOP", 0, -160)
	p.text:SetWidth(W - 60)
	p.text:SetJustifyH("CENTER")
	p.go = UI.Button(f, 200, 36, "", function() ns.ForgeUnlock.Ask(p.op) end, "primary")
	p.go:SetPoint("TOP", f, "TOP", 0, -250)
	p.go.clickWhenOff = true
	p.refresh = function(op)
		p.op = op
		local d = ns.Forge.OpDef(op)
		local lvl = ns.db.forge.level
		local okLevel = lvl >= d.level
		p.text:SetText(string.format("'%s'은(는) 아직 잠겨 있습니다.\n%s\n\n필요한 용광로 레벨: %s  ·  해금 비용: %s G\n(용광로 레벨은 장비를 분해·융합·제작하면 오릅니다)",
			ns.N(d.name), ns.N(d.desc), U.col(okLevel and "6af07a" or "ff6a5a", tostring(d.level)),
			U.col(ns.CanAfford(d.cost) and "ffd24a" or "ff6a5a", U.fmt(d.cost))))
		p.go:SetLabel(okLevel and ("해금하기  " .. U.fmt(d.cost) .. " G") or string.format("용광로 Lv %d에 열림", d.level))
		p.go:SetOff(not okLevel or not ns.CanAfford(d.cost))
	end
	return p
end

ForgeView.Build = {
	fuse = buildFuse, craft = buildCraft,
	gem = buildSocket("gem"), ench = buildSocket("ench"), insc = buildSocket("insc"),
	locked = buildLocked,
}
ForgeView.W, ForgeView.H = W, H
