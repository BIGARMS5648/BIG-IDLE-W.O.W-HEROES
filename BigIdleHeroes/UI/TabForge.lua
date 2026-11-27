-- The Titan Forge (대장간) as tabs of the equipment screen (UI/TabEquip.lua):
--   융합 (합성): grade chips, the bag's items of that grade (the next nine
--         to be used framed in gold), 1회 / 일괄 융합, the last result;
--   제작: part chips, the tiers, what a tier needs, 제작하기;
--   보석 · 마법부여 · 각인: items with sockets; the chosen item's sockets
--         drawn with what is set in them ([추출] on each); the material to
--         set; 세공하기 / 부여하기 / 각인하기.
-- A function not unlocked yet shows what it needs and [해금하기].
local _, ns = ...

local floor, min = math.floor, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main

local ForgeView = {}
ns.ForgeView = ForgeView

local W, H = UI.K.EQUIP_BODY_W, 456
local CELL, STEP = 46, 52
local MAT_COLS, MAT_SLOTS = 10, 20 -- the socket screens' material grid
local OP_ICON = {
	fuse = "Spell_Nature_WispSplode", smelt = "Spell_Fire_Fire", craft = "Trade_BlackSmithing", gem = "INV_Misc_Gem_Ruby_02",
	remove = "INV_Hammer_20", ench = "Trade_Engraving", seal = "INV_Misc_Coin_02", insc = "INV_Scroll_03",
	up = "INV_Hammer_09",
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
			parts[#parts + 1] = ns.QText(q, ns.N(ns.QUALITY[q].name) .. " " .. U.num(w / total * 100, 2) .. "%")
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
		if text and it then ForgeView.Log(text .. " · " .. ns.Items.Name(it)) end
		self:Refresh()
	end
	function r:Refresh()
		local it = self.item
		self.icon:Clear()
		if it and itemExists(it) then
			self.icon.data = it
			self.icon:SetIconName(ns.Items.Icon(it))
			self.icon:SetQuality(it.q)
			self.icon:SetItemMarks(it)
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
			if it.q == q and ns.Items.FuseCat(it) == p.cat and not ns.Forge.FuseBlock(it) then n = n + 1 end
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
			out[#out + 1] = { q, ns.QText(q, ns.N(a.name)) .. " → " .. ns.QText(q + 1, ns.N(b.name))
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
	p.all = UI.Button(f, 170, 36, "일괄 융합", function()
		local q = ns.QUALITY[p.q]
		if not ns.Forge.PickForFusion(p.q, p.cat) then
			UI.Try(false, string.format("쓸 수 있는 같은 등급 장비 %d개가 필요합니다.", ns.Forge.FUSE_COUNT))
			return
		end
		UI.Confirm({ title = "일괄 융합", ok = "융합", style = "primary",
			text = string.format("정말 %s 장비를 최대 20번까지 일괄 융합하시겠습니까?\n재료로 쓴 장비는 사라집니다.", ns.N(q.name)),
			onOk = function() fuse(true) end })
	end, "dark")
	p.all:SetPoint("LEFT", p.one, "RIGHT", 8, 0)
	p.all.clickWhenOff = true
	p.result = addResult(f, 372, -304)
	p.note = note(f, -384, "같은 등급 장비 9개 → 장비 1개. 가장 낮은 레벨부터 쓰고, 보호한 장비(가방에서 Alt+클릭), 보석·마법부여·주문각인이 붙은 장비, 영웅에게 더 좋은 장비는 쓰지 않습니다. 결과의 레벨은 재료의 평균 부근, 부위는 같은 종류 안에서 무작위입니다.")
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
				if not ns.Forge.FuseBlock(it) then usable = usable + 1 end
			end
		end
		local kindName = p.cat == "gear" and "무기·방어구" or "액세서리"
		p.head:Set(string.format("가방의 %s %s  %d개", ns.QText(p.q, ns.N(q.name)), kindName, #list),
			string.format("쓸 수 있는 것 %d개 · 파란 테두리 = 다음 융합에 쓰임", usable))
		for i, b in ipairs(p.cells) do
			local it = list[i]
			b:Clear()
			b.data, b.why = it, nil
			if it then
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
				b:SetItemMarks(it)
				b:SetLocked(it.lock)
				b:SetSelected(used[it] == true)
				b.why = ns.Forge.FuseBlock(it)
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
				UI.Try(false, string.format("대장간 Lv %d에 열립니다.", t.forge))
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
			row.title:SetText(string.format("%d단계  ·  장비 Lv %s", i, table.concat(t.levels, "·")))
			if open then
				row.sub:SetText(U.col("60e070", "열림"))
			elseif ns.db.forge.level >= t.forge then
				row.sub:SetText(U.col("ffd24a", "해금 " .. U.fmt(t.gold * 5) .. " G"))
			else
				row.sub:SetText(U.col("9a8f78", string.format("대장간 Lv %d 필요", t.forge)))
			end
			local best = 0
			for q = 1, ns.MAX_QUALITY do if (t.q[q] or 0) > 0 then best = q end end
			row.right:SetText("최고 " .. ns.QText(best, ns.N(ns.QUALITY[best].name)))
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
		p.go:SetBadge(not open and ns.db.forge.level >= t.forge and ns.CanAfford(t.gold * 5))
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
			p.go:SetLabel(string.format("대장간 Lv %d에 열림", t.forge))
			p.go:SetOff(true)
		end
	end
	return p
end

------------------------------------------------------------------------
-- 보석 · 마법부여 · 각인
------------------------------------------------------------------------
-- The piece a function works on: picked on the forge screen's right side
-- (UI/TabForgeScreen.lua) from the chosen hero's pieces and the bag.
ForgeView.target = { it = nil, hero = nil }
function ForgeView.SetTarget(it, heroId)
	ForgeView.target.it, ForgeView.target.hero = it, heroId
end
function ForgeView.Target()
	local t = ForgeView.target
	if t.it and itemExists(t.it) then return t.it, t.hero end
	return nil
end

-- The latest results of the forge, newest first (this session only).
ForgeView.log = {}
function ForgeView.Log(text)
	if not text or text == "" then return end
	table.insert(ForgeView.log, 1, text)
	while #ForgeView.log > 30 do table.remove(ForgeView.log) end
end

------------------------------------------------------------------------
-- 보석 · 마법부여 · 주문각인: the chosen piece and its sockets, the
-- material, the button
------------------------------------------------------------------------
local function buildSocket(kind)
	return function(page, f)
		local p = { kind = kind }
		local matKind = ns.SOCKET[kind].mat
		local c = UI.Panel(f, W, 196, "card")
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
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
			local y = -72 - (i - 1) * 36
			local r = {}
			r.socket = UI.Socket(c, 26)
			r.socket:SetPoint("TOPLEFT", c, "TOPLEFT", 12, y)
			r.text = UI.Text(c, 12)
			r.text:SetPoint("TOPLEFT", c, "TOPLEFT", 46, y - 6)
			r.text:SetWidth(W - 46 - 142)
			r.text:SetWordWrap(false)
			r.remove = UI.Button(c, 124, 26, "", function()
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
					onOk = function()
						local text = ns.Stats.ModText(e[1], e[2])
						if UI.Try(ns.Forge.RemoveSocket(it, kind, i, p.pickedHero)) then
							ForgeView.Log(string.format("추출: %s · %s", text, ns.Items.Name(it)))
						end
					end })
			end, "red")
			r.remove:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, y)
			r.remove.clickWhenOff = true
			c.rows[i] = r
		end
		c.pool = UI.Text(c, 11)
		c.pool:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 12, 12)
		c.pool:SetWidth(W - 24)
		c.pool:SetJustifyV("BOTTOM")
		UI.Color(c.pool, UI.C.sub)
		p.empty = UI.Text(c, 12)
		p.empty:SetPoint("CENTER", c, "CENTER", 0, 0)
		p.empty:SetWidth(W - 40)
		p.empty:SetJustifyH("CENTER")
		UI.Color(p.empty, UI.C.sub)
		-- the material to set: the ones you have, the best grades first,
		-- two rows of ten (more on further pages)
		p.matHead = UI.Section(f, W, "쓸 재료")
		p.matHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -214)
		p.matPage = 1
		-- (tools go right to left)
		p.next = p.matHead:AddTool(UI.PageButton(f, 30, 22, "right", function() p.matPage = p.matPage + 1 Main.Refresh() end))
		p.prev = p.matHead:AddTool(UI.PageButton(f, 30, 22, "left", function() p.matPage = p.matPage - 1 Main.Refresh() end))
		p.mats = {}
		for i = 1, MAT_SLOTS do
			local b = UI.IconButton(f, CELL, function(self) p.mat = self.matId Main.Refresh() end)
			b:SetPoint("TOPLEFT", f, "TOPLEFT", ((i - 1) % MAT_COLS) * STEP, -240 - math.floor((i - 1) / MAT_COLS) * STEP)
			UI.Tip(b, function(self) return self.matId and ns.Items.MatTooltip(self.matId) or nil end, "TOP")
			p.mats[i] = b
		end
		p.matText = UI.Text(f, 11)
		p.matText:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -348)
		p.matText:SetWidth(W)
		p.matText:SetWordWrap(false)
		UI.Color(p.matText, UI.C.sub)
		p.go = UI.Button(f, 180, 36, SOCKET_VERB[kind], function()
			if not p.picked then
				UI.Try(false, string.format("%s 홈이 있는 장비를 오른쪽에서 고르세요.", ns.N(ns.SOCKET[kind].short)))
				return
			elseif not p.mat then
				UI.Try(false, "쓸 재료가 없습니다. 상자에서 얻을 수 있습니다.")
				return
			end
			local ok, entry = ns.Forge.Socket(p.picked, kind, p.mat, p.pickedHero)
			if UI.Try(ok, entry) then
				local text = ns.Items.SocketText(p.picked, kind, entry)
				-- shown while this piece is the one picked
				p.last, p.lastFor = U.col("60e070", "부여됨: ") .. U.col("60e070", text), p.picked
				ForgeView.Log(string.format("%s: %s · %s", ns.N(ns.SOCKET[kind].short), text, ns.Items.Name(p.picked)))
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
		-- which pieces this function can work on
		p.accepts = function(it) return ns.Items.SocketCount(it, kind) > 0 end
		p.refresh = function()
			local t, th = ForgeView.Target()
			if t and p.accepts(t) then p.picked, p.pickedHero = t, th else p.picked, p.pickedHero = nil, nil end
			-- materials: the ones you have, best grade first; keep a usable
			-- one picked
			local owned = {}
			for i = ns.MAT_MAX_TIER[matKind], 1, -1 do
				for _, id in ipairs(ns.Forge.MatsAt(matKind, i)) do
					if ns.MatCount(id) > 0 then owned[#owned + 1] = id end
				end
			end
			if not p.mat or ns.MatCount(p.mat) <= 0 then p.mat = owned[1] end
			local pages = math.max(1, math.ceil(#owned / MAT_SLOTS))
			p.matPage = U.clamp(p.matPage, 1, pages)
			p.prev:SetShown(pages > 1)
			p.next:SetShown(pages > 1)
			p.prev:SetOff(p.matPage <= 1)
			p.next:SetOff(p.matPage >= pages)
			for i, b in ipairs(p.mats) do
				local id = owned[(p.matPage - 1) * MAT_SLOTS + i]
				b.matId = id
				b:Clear()
				if id then
					b:SetIconName(ns.MATS[id].icon)
					b:SetQuality(ns.MATS[id].q)
					b:SetCount(tostring(ns.MatCount(id)))
					b:SetSelected(p.mat == id)
					b:Show()
				else
					b:Hide()
				end
			end
			p.matText:SetText(p.mat and (ns.N(ns.MATS[p.mat].name) .. "  ·  " .. ns.MatCount(p.mat) .. "개") or "가진 재료가 없습니다.")
			local it = p.picked
			p.empty:SetShown(it == nil)
			for _, w in ipairs({ c.icon, c.name, c.sub, c.pool }) do w:SetShown(it ~= nil) end
			if not it then
				local need = (kind == "gem" and 3) or (kind == "ench" and 5) or 6
				p.empty:SetText(string.format("오른쪽에서 %s 홈이 있는 장비를 고르세요.\n%s 등급 이상의 장비에 %s 홈이 있습니다.",
					ns.N(ns.SOCKET[kind].short), ns.QText(need, ns.N(ns.QUALITY[need].name)), ns.N(ns.SOCKET[kind].short)))
				for _, r in ipairs(c.rows) do r.socket:Hide() r.text:Hide() r.remove:Hide() end
				p.go:SetOff(true)
				p.why:SetText("")
				p.lastText:SetText("")
				return
			end
			c.icon:Clear()
			c.icon.data = it
			c.icon:SetIconName(ns.Items.Icon(it))
			c.icon:SetQuality(it.q)
			c.icon:SetItemMarks(it)
			c.name:SetText(ns.QText(it.q, ns.Items.Name(it)))
			local wearer = ns.Items.Wearer(it)
			c.sub:SetText(string.format("%s 홈 %d개 중 %d개 비어 있음%s", ns.N(ns.SOCKET[kind].short), ns.Items.SocketCount(it, kind), ns.Items.FreeSockets(it, kind),
				wearer and ("  ·  " .. ns.Heroes.ShortName(wearer) .. " 착용 중") or "  ·  가방"))
			local l = ns.Items.SocketList(it, kind)
			for i, r in ipairs(c.rows) do
				local has = i <= ns.Items.SocketCount(it, kind)
				local e = has and l and l[i]
				r.socket:SetShown(has)
				r.text:SetShown(has)
				r.remove:SetShown(e ~= nil and e ~= false)
				if has then
					if e then
						r.socket:Set(kind, ns.Items.SocketIcon(kind, e[3], e[4]))
						r.text:SetText(U.col("66ccff", ns.Items.SocketText(it, kind, e)))
						r.remove:SetBadge(ns.Guide.CanUnlock("remove"))
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
			-- what the picked material gives this piece
			if p.mat then
				local pool = ns.Items.SocketPool(p.mat, it)
				local parts = {}
				for _, e in ipairs(pool) do
					parts[#parts + 1] = ns.N(ns.AFFIX[e[1]].n) .. " " .. ns.Items.RangeText(e[1], e[2], e[3])
				end
				if #parts > 3 then
					c.pool:SetText(string.format("%s: %d가지 능력치 중 하나 (재료에 마우스를 올리면 목록)", ns.N(ns.MATS[p.mat].name), #parts))
				else
					c.pool:SetText(ns.N(ns.MATS[p.mat].name) .. ": " .. table.concat(parts, #parts > 1 and " 또는 " or ""))
				end
			else
				c.pool:SetText("")
			end
			local can, why = false, "재료가 없습니다. 상자에서 얻을 수 있습니다."
			if p.mat then can, why = ns.Forge.CanSocket(it, kind, p.mat) end
			p.go:SetOff(not can)
			p.why:SetText(can and "" or (why or ""))
			p.lastText:SetText(p.lastFor == it and p.last or "")
		end
		return p
	end
end

------------------------------------------------------------------------
-- 강화: two cards. Left: the chosen piece, its step bar (+0 .. +20) and what
-- the next step gives (the bonus and up to four base stats now → after).
-- Right: the piece now » after the next step (icons), the chance large, the cost,
-- the average tries, [강화하기]. Under both, 계승 from a piece of the same
-- slot.
------------------------------------------------------------------------
local UP_GREEN, UP_YELLOW, UP_RED = "60e070", "ffd24a", "ff6a5a"
local function chanceHex(c)
	if c >= 0.6 then return UP_GREEN elseif c >= 0.3 then return UP_YELLOW end
	return UP_RED
end
------------------------------------------------------------------------
-- A try's result: the hammer comes down on the anvil three times (the
-- anvil still, the hammer swung about its handle's end; pictures cut from
-- the old forge icon by tools/cut_anvil.py), the game's strike sparks where
-- it lands, then a small window with how it went. A click during the
-- strikes shows the result at once.
------------------------------------------------------------------------
local UpFx = {}
ForgeView.UpFx = UpFx
UpFx.TIME = 2.0                    -- the strikes, then the result
UpFx.STRIKES = { 0.45, 1.05, 1.65 } -- when the hammer lands
UpFx.SPARK = 166986                -- strike_impact_chest.m2 (a warrior's strike)
-- (tools/cut_anvil.py) the handle's end in the anvil's square (from its top
-- left), the hammer's square, and how far it turns down onto the anvil
UpFx.HAMMER = { x = 0.861, y = 0.411, size = 1.042, down = 19.0 }
UpFx.LIFT = 25                     -- how far above its rest it is raised (degrees)
UpFx.HIT = { x = 0.47, y = 0.47 }  -- where the head meets the anvil
local ANVIL = 96                   -- the anvil's square on the window

-- turns a square picture about its middle, anticlockwise by deg (a
-- negative deg turns it clockwise)
local function turn(tex, deg)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	local function at(x, y)
		return 0.5 + x * c + y * s, 0.5 - (-x * s + y * c)
	end
	local ulx, uly = at(-0.5, 0.5)
	local llx, lly = at(-0.5, -0.5)
	local urx, ury = at(0.5, 0.5)
	local lrx, lry = at(0.5, -0.5)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function buildStrikes()
	local c = Main.ModalContent(340, 226)
	UpFx.anim = c
	-- a click anywhere on the window shows the result: the strikes are drawn
	-- on a button over all of it
	local b = CreateFrame("Button", nil, c)
	c.skip = b
	b:SetAllPoints(Main.Frame().modal)
	b:SetFrameLevel(c:GetFrameLevel() + 20)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function() UpFx.Finish() end)
	c.anvil = b:CreateTexture(nil, "ARTWORK")
	c.anvil:SetSize(ANVIL, ANVIL)
	c.anvil:SetPoint("CENTER", c, "CENTER", 0, 16)
	UI.SetArtOrIcon(c.anvil, "fx_anvil", "Trade_BlackSmithing")
	local H = UpFx.HAMMER
	c.hammer = b:CreateTexture(nil, "OVERLAY")
	c.hammer:SetSize(ANVIL * H.size, ANVIL * H.size)
	c.hammer:SetPoint("CENTER", c.anvil, "TOPLEFT", ANVIL * H.x, -ANVIL * H.y)
	c.hammer:SetTexture(UI.ArtIcon("fx_hammer"))
	c.text = UI.Text(b, 13, "강화하는 중...")
	c.text:SetPoint("TOP", c, "CENTER", 0, -44)
	UI.Color(c.text, UI.C.sub)
	-- the sparks where the hammer lands (the game's own effect)
	local Fig = ns.Figure3D
	if Fig and Fig.Enabled() then
		c.spark = Fig.New(b, ANVIL)
		c.spark:Hide()
	end
	c:SetScript("OnUpdate", function(_, dt) UpFx.Step(dt) end)
end

-- the hammer's turn at time t (degrees, anticlockwise from its rest): raised
-- slowly, brought down fast onto the anvil, held a moment, back to rest
function UpFx.Angle(t)
	local down, lift = UpFx.HAMMER.down, UpFx.LIFT
	local prev, nxt
	for _, s in ipairs(UpFx.STRIKES) do
		if t < s then nxt = s break end
		prev = s
	end
	if prev and t - prev < 0.05 then return down end
	if prev and t - prev < 0.15 then return down * (1 - (t - prev - 0.05) / 0.1) end
	if not nxt then return 0 end
	local from, slam = prev and prev + 0.15 or 0, nxt - 0.12
	if t < slam then return -lift * (t - from) / (slam - from) end
	return -lift + (down + lift) * (t - slam) / 0.12
end
function UpFx.Pose(t)
	turn(UpFx.anim.hammer, UpFx.Angle(t))
end

local function spark()
	local fig = UpFx.anim.spark
	if not fig then return end
	fig.id = nil
	if not fig:SetModelFile(UpFx.SPARK) then return end
	fig:SetHeight2(ANVIL)
	fig:SetFixedScale(0.6)
	fig:SetFacing("left")
	-- (from the window's bottom left: the anvil's square sits 16 above its middle)
	local x = 170 - ANVIL / 2 + ANVIL * UpFx.HIT.x
	local y = 113 + 16 + ANVIL / 2 - ANVIL * UpFx.HIT.y
	fig:PlaceFeet(UpFx.anim, x, y)
	fig:SetAlpha(1)
	fig:Show()
end

function UpFx.Step(dt)
	local r = UpFx.run
	if not r then return end
	local t0 = r.t
	r.t = r.t + dt
	for _, s in ipairs(UpFx.STRIKES) do
		if t0 < s and r.t >= s then spark() end
	end
	if UpFx.anim.spark then UpFx.anim.spark:Step(dt) end
	UpFx.Pose(r.t)
	if r.t >= UpFx.TIME then UpFx.Finish() end
end

local function buildResult()
	local c = Main.ModalContent(340, 226)
	UpFx.res = c
	c.title = UI.Title(c, "", 16)
	c.title:SetPoint("TOP", c, "TOP", 0, 0)
	c.a = UI.IconButton(c, 44)
	c.b = UI.IconButton(c, 44)
	c.arrow = c:CreateTexture(nil, "ARTWORK")
	c.arrow:SetSize(14, 14)
	UI.SetArrow(c.arrow, "right", 0.75, 0.8, 0.92)
	c.arrow:SetPoint("TOP", c, "TOP", 0, -45)
	c.name = UI.Text(c, 13)
	c.name:SetPoint("TOP", c, "TOP", 0, -82)
	c.name:SetWidth(300)
	c.name:SetJustifyH("CENTER")
	c.name:SetWordWrap(false)
	c.rows = {}
	for i = 1, 3 do
		local l = UI.Text(c, 12)
		l:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -106 - (i - 1) * 20)
		UI.Color(l, UI.C.sub)
		local r = UI.Text(c, 12)
		r:SetPoint("TOPRIGHT", c, "TOPRIGHT", -20, -106 - (i - 1) * 20)
		c.rows[i] = { l, r }
	end
	c.close = UI.Button(c, 164, 30, "확인", function() Main.CloseModal() end, "dark")
	c.close:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.again = UI.Button(c, 164, 30, "", function()
		local fn = UpFx.again
		Main.CloseModal()
		if fn then fn() end
	end, "primary")
	c.again:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	c.again.clickWhenOff = true
end

local function showPiece(b, it, step)
	b:Clear()
	b.data = it
	b:SetIconName(ns.Items.Icon(it))
	b:SetQuality(it.q)
	local was = it.up
	it.up = step > 0 and step or nil
	b:SetItemMarks(it)
	it.up = was
end

-- the result window: success shows the piece before » after and what rose;
-- a failure the next try's chance and cost
function UpFx.Finish()
	local r = UpFx.run
	if not r then return end
	UpFx.run = nil
	if UpFx.anim.spark then UpFx.anim.spark:Hide() end
	if not UpFx.res then buildResult() end
	local c, it, Up = UpFx.res, r.it, ns.Upgrade
	local G, R = "60e070", "ff6a5a"
	c.title:SetText(r.success and U.col(G, "성공!") or U.col(R, "실패..."))
	c.name:SetText(ns.QText(it.q, ns.Items.Name(it)))
	c.a:ClearAllPoints()
	if r.success then
		showPiece(c.a, it, r.from)
		showPiece(c.b, it, r.n)
		c.a:SetPoint("TOP", c, "TOP", -46, -30)
		c.b:SetPoint("TOP", c, "TOP", 46, -30)
		c.b:Show()
		c.arrow:Show()
	else
		showPiece(c.a, it, r.n)
		c.a:SetPoint("TOP", c, "TOP", 0, -30)
		c.b:Hide()
		c.arrow:Hide()
	end
	local rows = {}
	if r.success then
		local function pct(k) return floor((Up.Bonus(k) - 1) * 100 + 0.5) end
		rows[1] = { "기본 능력치", "+" .. pct(r.from) .. "%  →  " .. U.col(G, "+" .. pct(r.n) .. "%") }
		local was = it.up
		it.up = r.n > 0 and r.n or nil
		local now = ns.Items.BaseStats(it)
		it.up = r.from > 0 and r.from or nil
		local before = ns.Items.BaseStats(it)
		it.up = was
		for i = 1, min(2, #now) do
			local text = ns.Stats.ModText(before[i][1], before[i][2])
			local num, name = text:match("^%+?([%d,%.%%]+)%s+(.+)$")
			local num2 = ns.Stats.ModText(now[i][1], now[i][2]):match("^%+?([%d,%.%%]+)")
			rows[#rows + 1] = { name or "", (num or text) .. "  →  " .. U.col(G, num2 or "") }
		end
	elseif r.n < Up.MAX then
		local chance = Up.Chance(r.n)
		rows[1] = { "다음 성공 확률", U.col(chance >= 0.6 and G or (chance >= 0.3 and "ffd24a" or R), U.num(chance * 100, 0) .. "%") }
		rows[2] = { "비용", U.col(ns.CanAfford(Up.Cost(it, r.n)) and "ffd24a" or R, U.fmt(Up.Cost(it, r.n)) .. " G") }
	end
	for i, row in ipairs(c.rows) do
		row[1]:SetText(rows[i] and rows[i][1] or "")
		row[2]:SetText(rows[i] and rows[i][2] or "")
	end
	c.again:SetLabel(r.success and "계속 강화" or "다시 강화")
	c.again:SetOff(Up.Why(it) ~= nil)
	UpFx.again = r.again
	Main.ShowModal(c)
end

-- the strikes for a try that went `success` (from step `from` to `n`),
-- then its result; again() tries once more
function UpFx.Play(it, success, from, n, again)
	if not UpFx.anim then buildStrikes() end
	UpFx.run = { t = 0, it = it, success = success, from = from, n = n, again = again }
	UpFx.Pose(0)
	if UpFx.anim.spark then UpFx.anim.spark:Hide() end
	Main.ShowModal(UpFx.anim, function() UpFx.run = nil end)
end

local function buildUpgrade(page, f)
	local p = {}
	local Up = ns.Upgrade
	local CW = floor((W - 10) / 2)
	local function pct(k) return floor((Up.Bonus(k) - 1) * 100 + 0.5) end
	-- an item button showing the piece at step `step` (its tooltip too)
	local function pieceIcon(parent, size)
		local b = UI.IconButton(parent, size)
		UI.Tip(b, function(self)
			local it = self.data
			if not it then return nil end
			local was = it.up
			it.up = (self.step or 0) > 0 and self.step or nil
			local lines = ns.Items.Tooltip(it, Main.SelectedHero())
			it.up = was
			return lines
		end)
		function b:Show2(it, step)
			self:Clear()
			self.data, self.step = it, step
			self:SetIconName(ns.Items.Icon(it))
			self:SetQuality(it.q)
			local was = it.up
			it.up = step > 0 and step or nil
			self:SetItemMarks(it)
			it.up = was
		end
		return b
	end
	-- a name on the left, its value on the right
	local function row(parent, y, w)
		local l = UI.Text(parent, 12)
		l:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
		l:SetWidth(floor(w * 0.45))
		l:SetWordWrap(false)
		UI.Color(l, UI.C.sub)
		local r = UI.Text(parent, 12)
		r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
		r:SetWidth(floor(w * 0.55))
		r:SetJustifyH("RIGHT")
		r:SetWordWrap(false)
		return { l, r }
	end

	-- the piece
	local L = UI.Panel(f, CW, 322, "card")
	L:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	p.card = L
	L.icon = pieceIcon(L, 44)
	L.icon:SetPoint("TOPLEFT", L, "TOPLEFT", 12, -12)
	L.name = UI.Text(L, 13)
	L.name:SetPoint("LEFT", L.icon, "RIGHT", 8, 0)
	L.name:SetWidth(CW - 76)
	L.name:SetWordWrap(false)
	L.stepL = UI.Text(L, 11, "강화 단계")
	L.stepL:SetPoint("TOPLEFT", L, "TOPLEFT", 12, -72)
	UI.Color(L.stepL, UI.C.sub)
	L.step = UI.Bar(L, CW - 24, 10, 0.34, 0.6, 1.0)
	L.step:SetPoint("TOPLEFT", L, "TOPLEFT", 12, -90)
	L.ticks = {}
	for i, k in ipairs({ 0, Up.SAFE, Up.MAX }) do
		local t = UI.Text(L, 10, "+" .. k)
		UI.Color(t, UI.C.dim)
		if i == 1 then t:SetPoint("TOPLEFT", L.step, "BOTTOMLEFT", 0, -3)
		elseif i == 2 then t:SetPoint("TOP", L.step, "BOTTOMLEFT", (CW - 24) * k / Up.MAX, -3)
		else t:SetPoint("TOPRIGHT", L.step, "BOTTOMRIGHT", 0, -3) end
		L.ticks[i] = t
	end
	L.head = UI.Text(L, 11, "다음 단계에서")
	L.head:SetPoint("TOPLEFT", L, "TOPLEFT", 12, -124)
	UI.Color(L.head, UI.C.sub)
	L.rows = {}
	for i = 1, 5 do L.rows[i] = row(L, -144 - (i - 1) * 22, CW - 24) end
	p.empty = UI.Text(f, 12)
	p.empty:SetPoint("CENTER", L, "CENTER", 0, 0)
	p.empty:SetWidth(CW - 24)
	p.empty:SetJustifyH("CENTER")
	UI.Color(p.empty, UI.C.sub)

	-- the try
	local R = UI.Panel(f, CW, 322, "card")
	R:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	p.tryCard = R
	R.head = UI.Text(R, 11, "성공 확률")
	R.head:SetPoint("TOP", R, "TOP", 0, -14)
	UI.Color(R.head, UI.C.sub)
	R.cur = pieceIcon(R, 40)
	R.cur:SetPoint("TOP", R, "TOP", -50, -34)
	R.nxt = pieceIcon(R, 40)
	R.nxt:SetPoint("TOP", R, "TOP", 50, -34)
	R.arrow = R:CreateTexture(nil, "ARTWORK")
	R.arrow:SetSize(14, 14)
	R.arrow:SetPoint("TOP", R, "TOP", 0, -47)
	UI.SetArrow(R.arrow, "right", 0.75, 0.8, 0.92)
	R.ch = UI.Text(R, 30)
	R.ch:SetPoint("TOP", R, "TOP", 0, -96)
	R.rows = { row(R, -150, CW - 24), row(R, -172, CW - 24) }
	-- one try: the gold is spent and the step rolled now; the strikes and the
	-- result window follow
	function p.tryOnce()
		local it, hero = p.picked, p.pickedHero
		local from = Up.Level(it)
		local ok, success, n = Up.Try(it, hero)
		if UI.Try(ok, success) then
			if success then
				ForgeView.Log(U.col(UP_GREEN, string.format("강화 성공 +%d", n)) .. " · " .. ns.Items.Name(it))
			else
				ForgeView.Log(U.col(UP_RED, string.format("강화 실패 +%d", n)) .. " · " .. ns.Items.Name(it))
			end
			Main.Refresh()
			UpFx.Play(it, success, from, n, function()
				-- (the same piece, if it is still the one picked)
				if p.picked == it then p.tryOnce() end
			end)
			return
		end
		Main.Refresh()
	end
	p.go = UI.Button(R, CW - 24, 36, "강화하기", function() p.tryOnce() end, "primary")
	p.go:SetPoint("BOTTOM", R, "BOTTOM", 0, 12)
	p.go.clickWhenOff = true
	-- why it cannot be tried now, or how the last try went
	p.why = UI.Text(R, 11)
	p.why:SetPoint("BOTTOM", p.go, "TOP", 0, 8)
	p.why:SetWidth(CW - 24)
	p.why:SetJustifyH("CENTER")
	p.why:SetWordWrap(false)
	p.why:SetTextColor(1, 0.55, 0.45)
	p.lastText = UI.Text(R, 12)
	p.lastText:SetPoint("BOTTOM", p.go, "TOP", 0, 8)
	p.lastText:SetWidth(CW - 24)
	p.lastText:SetJustifyH("CENTER")
	p.lastText:SetWordWrap(false)

	-- 계승: from the piece of the same slot that takes this one the highest
	local m = UI.Panel(f, W, 40, "inset")
	m:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -330)
	m.isRow = true -- the 계승 button on its line
	p.move = m
	m.text = UI.Text(m, 11)
	m.text:SetPoint("LEFT", m, "LEFT", 12, 0)
	m.text:SetWidth(W - 24 - 130)
	m.text:SetWordWrap(false)
	UI.Color(m.text, UI.C.sub)
	m.btn = UI.Button(m, 120, 26, "계승하기", function()
		local to = p.picked
		local from = Up.SourceFor(to)
		local ok, why = Up.CanMove(from, to)
		if not ok then
			UI.Try(false, why)
			return
		end
		-- what is set in its sockets moves along (as much as there is room for)
		local moved, lost = {}, {}
		local plan = Up.SocketPlan(from, to)
		for _, kind in ipairs(ns.SOCKET_KINDS) do
			local q = plan[kind]
			local name = ns.N(ns.SOCKET[kind].short)
			if q and q.moved > 0 then moved[#moved + 1] = string.format("%s %d개", name, q.moved) end
			if q and q.lost > 0 then lost[#lost + 1] = string.format("%s %d개", name, q.lost) end
		end
		local what = string.format("+%d 강화", Up.Level(from))
		if #moved > 0 then what = what .. "와 " .. table.concat(moved, " · ") end
		local text = string.format("정말 %s의 %s를 이 장비에 계승하시겠습니까?\n%s  →  +%d\n원래 장비는 사라집니다.",
			ns.Items.ColorName(from), what, ns.Items.ColorName(to), Up.MoveResult(from, to))
		if #lost > 0 then
			text = text .. "\n" .. U.col("ff9a7a", string.format("빈 홈이 모자라 %s는 함께 사라집니다.", table.concat(lost, " · ")))
		end
		UI.Confirm({ title = "계승", ok = "계승",
			text = text,
			onOk = function()
				local done, n = Up.Move(from, to)
				if UI.Try(done, n) then
					p.last, p.lastFor = U.col(UP_GREEN, string.format("계승: +%d", n)), to
					ForgeView.Log(U.col(UP_GREEN, string.format("계승 +%d", n)) .. " · " .. ns.Items.Name(to))
				end
				Main.Refresh()
			end })
	end, "dark")
	m.btn:SetPoint("RIGHT", m, "RIGHT", -8, 0)
	m.btn.clickWhenOff = true

	local parts = { L.icon, L.name, L.stepL, L.step, L.head, R.head, R.cur, R.nxt, R.arrow, R.ch, m }
	for _, t in ipairs(L.ticks) do parts[#parts + 1] = t end
	for _, r in ipairs(L.rows) do parts[#parts + 1] = r[1] parts[#parts + 1] = r[2] end
	for _, r in ipairs(R.rows) do parts[#parts + 1] = r[1] parts[#parts + 1] = r[2] end
	p.accepts = function(it) return it ~= nil end
	p.refresh = function()
		local t, th = ForgeView.Target()
		p.picked, p.pickedHero = t, th
		local it = p.picked
		p.empty:SetShown(it == nil)
		for _, w in ipairs(parts) do w:SetShown(it ~= nil) end
		if not it then
			p.empty:SetText("오른쪽에서 강화할 장비를 고르세요.")
			p.go:SetLabel("강화하기")
			p.go:SetOff(true)
			p.why:SetText("")
			p.lastText:SetText("")
			return
		end
		local n = Up.Level(it)
		local top = n >= Up.MAX
		L.icon:Show2(it, n)
		L.name:SetText(ns.QText(it.q, (n > 0 and ("+" .. n .. " ") or "") .. ns.Items.Name(it)))
		L.step:SetValue(n / Up.MAX)
		-- the bonus and the base stats now → after the next step
		local now = ns.Items.BaseStats(it)
		local after = {}
		if not top then
			local was = it.up
			it.up = n + 1
			after = ns.Items.BaseStats(it)
			it.up = was
		end
		local lines = { { "기본 능력치", "+" .. pct(n) .. "%" .. (top and "" or ("  →  " .. U.col(UP_GREEN, "+" .. pct(n + 1) .. "%"))) } }
		for i = 1, min(4, #now) do
			local key = now[i][1]
			local text = ns.Stats.ModText(key, now[i][2])
			local num, name = text:match("^%+?([%d,%.%%]+)%s+(.+)$")
			local value = num or text
			if after[i] then
				local num2 = ns.Stats.ModText(key, after[i][2]):match("^%+?([%d,%.%%]+)")
				value = value .. "  →  " .. U.col(UP_GREEN, num2 or "")
			end
			lines[#lines + 1] = { name or "", value }
		end
		for i, r in ipairs(L.rows) do
			r[1]:SetText(lines[i] and lines[i][1] or "")
			r[2]:SetText(lines[i] and lines[i][2] or "")
		end
		L.head:SetText(top and "최고 단계" or "다음 단계에서")
		-- the try
		R.cur:Show2(it, n)
		R.nxt:SetShown(not top)
		R.arrow:SetShown(not top)
		if top then
			R.ch:SetText(U.col(UP_GREEN, "최고 단계"))
			R.rows[1][1]:SetText("")
			R.rows[1][2]:SetText("")
			R.rows[2][1]:SetText("")
			R.rows[2][2]:SetText("")
		else
			R.nxt:Show2(it, n + 1)
			local chance = Up.Chance(n)
			R.ch:SetText(U.col(chanceHex(chance), U.num(chance * 100, 0) .. "%"))
			R.rows[1][1]:SetText("비용")
			R.rows[1][2]:SetText(U.col(ns.CanAfford(Up.Cost(it, n)) and UP_YELLOW or UP_RED, U.fmt(Up.Cost(it, n)) .. " G"))
			R.rows[2][1]:SetText("성공까지 평균 시도")
			R.rows[2][2]:SetText(string.format("%.1f회", 1 / chance))
		end
		local why = Up.Why(it)
		p.go:SetLabel(top and "최고 단계" or ("강화하기  " .. U.fmt(Up.Cost(it, n)) .. " G"))
		p.go:SetOff(why ~= nil)
		-- the last result while its piece is the one picked, else why not
		local last = p.lastFor == it and p.last or nil
		p.lastText:SetText(last or "")
		p.why:SetText((not last and not top) and (why or "") or "")
		-- 계승
		local from = Up.SourceFor(it)
		if from then
			m.text:SetText(string.format("계승: %s +%d  →  이 장비 %s",
				ns.Items.Name(from), Up.Level(from), U.col(UP_GREEN, "+" .. Up.MoveResult(from, it))))
			m.btn:SetOff(not Up.CanMove(from, it))
		else
			m.text:SetText("계승: 같은 부위에 계승할 강화 장비가 없습니다.")
			m.btn:SetOff(true)
		end
	end
	return p
end

------------------------------------------------------------------------
-- 분해: the grade, the pieces it would break down, the gold, now or by
-- itself when the bag is full
------------------------------------------------------------------------
local SMELT_COLS, SMELT_ROWS = 10, 4
local function smeltQ() return U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY) end
local function autoSmeltOn() return (ns.db.opt.autoSmelt or 0) > 0 end
local function buildSmelt(page, f)
	local p = {}
	p.gradeLabel = UI.Text(f, 12, "분해 등급")
	p.gradeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -8)
	p.pick = UI.Dropdown(f, 160, 30, function()
		local out = {}
		for q = 1, ns.MAX_QUALITY do out[#out + 1] = { q, ns.QText(q, ns.N(ns.QUALITY[q].name)) .. " 이하" } end
		return out
	end, smeltQ, function(q)
		ns.db.ui.smeltQ = q
		if autoSmeltOn() then ns.db.opt.autoSmelt = q end
	end, "")
	p.pick:SetPoint("TOPLEFT", f, "TOPLEFT", 72, 0)
	p.pick.tipTitle = "분해 등급"
	p.pick.tipText = "일괄 분해와 자동 분해가 이 등급 이하의 장비만 분해합니다."
	p.auto = UI.Check(f, "자동 분해", autoSmeltOn, function(v)
		ns.db.opt.autoSmelt = v and smeltQ() or 0
		ns.Toast(v and "자동 분해를 켰습니다." or "자동 분해를 껐습니다.")
	end)
	p.auto:SetPoint("LEFT", p.pick, "RIGHT", 16, 0)
	UI.Tip(p.auto, function()
		local q = ns.QUALITY[smeltQ()]
		return UI.SimpleTip("자동 분해", string.format("켜 두면 가방이 가득 찰 때 %s 이하의 장비를 저절로 분해해 자리를 만듭니다.", ns.QText(smeltQ(), ns.N(q.name))))
	end, "TOP")
	p.head = UI.Section(f, W)
	p.head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -44)
	p.cells = {}
	for i = 1, SMELT_COLS * SMELT_ROWS do
		-- right-click: breaks that one down (after asking, as in the bag)
		local b = UI.IconButton(f, CELL, function(self, button)
			if button == "RightButton" and self.data then ns.BagView.SmeltOne(self.data) end
		end)
		local col, row = (i - 1) % SMELT_COLS, floor((i - 1) / SMELT_COLS)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * STEP, -70 - row * STEP)
		UI.Tip(b, function(self)
			if not self.data then return nil end
			local lines = ns.Items.Tooltip(self.data, Main.SelectedHero())
			lines[#lines + 1] = { "우클릭: 분해", nil, 0.45, 0.8, 1 }
			return lines
		end)
		p.cells[i] = b
	end
	p.note = note(f, -70 - SMELT_ROWS * STEP - 8, "보호한 장비, 강화한 장비, 보석·마법부여·주문각인이 붙은 장비, 영웅에게 지금 또는 레벨을 올린 뒤 더 좋은 장비는 남깁니다.")
	p.go = UI.Button(f, 220, 36, "일괄 분해", function()
		local picked = ns.Forge.PickByQuality(smeltQ())
		if #picked == 0 then
			UI.Try(false, "분해 등급 이하인 장비가 없습니다. 등급을 올려 보세요.")
			return
		end
		local total = ns.Items.SmeltGoldOf(picked)
		local q = ns.QUALITY[smeltQ()]
		UI.Confirm({ title = "일괄 분해", ok = "분해", style = "red",
			text = string.format("%s 이하의 장비 %d개를 분해하시겠습니까?\n%s 골드를 받습니다.", ns.QText(smeltQ(), ns.N(q.name)), #picked, U.fmt(total)),
			onOk = function()
				local ok, gold, n = ns.Forge.Smelt(picked)
				if UI.Try(ok, gold) then
					ns.Toast(string.format("%d개 분해: +%s 골드", n, U.fmt(gold)))
					ForgeView.Log(string.format("분해: %d개 · +%s G", n, U.fmt(gold)))
				end
			end })
	end, "red")
	p.go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	p.go.clickWhenOff = true
	p.total = UI.Text(f, 12)
	p.total:SetPoint("LEFT", p.go, "RIGHT", 12, 0)
	p.total:SetWidth(W - 240)
	p.total:SetWordWrap(false)
	p.refresh = function()
		p.pick:Refresh()
		p.auto:Refresh() -- (the bag's 자동 분해 sets the same option)
		local picked, kept = ns.Forge.PickByQuality(smeltQ())
		local total = ns.Items.SmeltGoldOf(picked)
		p.head:Set("분해할 장비", string.format("%d개%s", #picked, kept > 0 and string.format(" · 영웅에게 더 좋은 장비 %d개는 남김", kept) or ""))
		for i, b in ipairs(p.cells) do
			local it = picked[i]
			b:Clear()
			b.data = it
			if it then
				b:SetIconName(ns.Items.Icon(it))
				b:SetQuality(it.q)
			end
		end
		p.total:SetText(#picked > 0 and ("받을 골드  " .. U.col("ffd24a", U.fmt(total) .. " G")) or U.col("8a90a2", "분해할 장비가 없습니다."))
		p.go:SetOff(#picked == 0)
	end
	return p
end

------------------------------------------------------------------------
-- 행운의 인장: a row per seal (how many, the grades it rolls, [굴리기]),
-- the level of the piece it gives, and the last piece rolled
------------------------------------------------------------------------
local SEAL_ROW_H, SEAL_ROW_STEP = 62, 68
local function buildSeal(page, f)
	local p = { rows = {} }
	p.head = UI.Section(f, W, "인장")
	p.head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	for i, s in ipairs(ns.SEAL) do
		local r = UI.Panel(f, W, SEAL_ROW_H, "card")
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -28 - (i - 1) * SEAL_ROW_STEP)
		r.icon = UI.IconButton(r, 40)
		r.icon:SetPoint("LEFT", r, "LEFT", 10, 0)
		r.icon.data = s.mat
		UI.Tip(r.icon, function(self) return ns.Items.MatTooltip(self.data) end)
		r.name = UI.Text(r, 13)
		r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 60, -12)
		r.name:SetWidth(W - 60 - 180)
		r.name:SetWordWrap(false)
		r.odds = UI.Text(r, 10)
		r.odds:SetPoint("TOPLEFT", r, "TOPLEFT", 60, -36)
		r.odds:SetWidth(W - 60 - 180)
		r.odds:SetWordWrap(false)
		r.go = UI.Button(r, 160, 32, "", function()
			local ok, it = ns.Forge.BonusRoll(i)
			if UI.Try(ok, it) then
				ns.Toast("굴림 결과: " .. ns.Items.ColorName(it))
				p.result:Set(it, ns.N(ns.MATS[s.mat].name))
			end
			Main.Refresh()
		end, "primary")
		r.go:SetPoint("RIGHT", r, "RIGHT", -12, 0)
		r.go.clickWhenOff = true
		UI.Tip(r.go, function()
			local body = "인장 1개와 골드로 장비를 하나 얻습니다. 부위는 무작위이고, 영웅보다 레벨이 높은 장비는 영웅이 그 레벨이 될 때까지 가방에 남겨 둡니다."
			if ns.MatCount(s.mat) <= 0 then
				body = body .. "\n" .. U.col("ff9a7a", "이 인장이 없습니다. 상자에서 얻을 수 있습니다.")
			elseif ns.Items.BagFree() <= 0 then
				body = body .. "\n" .. U.col("ff9a7a", "가방이 가득 찼습니다. 장비를 분해하거나 정리하면 굴릴 수 있습니다.")
			elseif not ns.CanAfford(s.gold) then
				body = body .. "\n" .. U.col("ff9a7a", string.format("골드가 부족합니다. %s G가 필요합니다.", U.fmt(s.gold)))
			end
			return UI.SimpleTip("굴리기", body)
		end, "TOP")
		r.odds:SetText(qualityOdds(s.q))
		p.rows[i] = r
	end
	local y = -28 - #ns.SEAL * SEAL_ROW_STEP - 6
	p.result = addResult(f, 0, y)
	p.refresh = function()
		p.head:Set("인장", string.format("나오는 장비 Lv %d", ns.Forge.SealLevel()))
		local full = ns.Items.BagFree() <= 0
		for i, s in ipairs(ns.SEAL) do
			local r = p.rows[i]
			local m = ns.MATS[s.mat]
			local count = ns.MatCount(s.mat)
			r.icon:SetIconName(m.icon)
			r.icon:SetQuality(m.q)
			r.icon:SetDim(count <= 0)
			r.name:SetText(ns.QText(m.q, ns.N(m.name)) .. "  " .. U.col(count > 0 and "ffffff" or "8a90a2", U.fmt(count) .. "개"))
			r.go:SetLabel(full and "가방이 가득 참" or ("굴리기  " .. U.fmt(s.gold) .. " G"))
			r.go:SetOff(full or count <= 0 or not ns.CanAfford(s.gold))
		end
		p.result:Refresh()
	end
	return p
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
		if op == "up" then
			-- 강화 opens with the endless tower, not with the forge
			p.text:SetText(string.format("'강화'는 아직 잠겨 있습니다.\n장비의 기본 능력치를 +%d까지 올립니다.\n\n%s",
				ns.Upgrade.MAX, ns.Upgrade.LOCKED_TEXT))
			p.go:Hide()
			return
		end
		p.go:Show()
		p.go:SetBadge(ns.Guide.CanUnlock(op))
		local d = ns.Forge.OpDef(op)
		local lvl = ns.db.forge.level
		local okLevel = lvl >= d.level
		p.text:SetText(string.format("'%s'은(는) 아직 잠겨 있습니다.\n%s\n\n필요한 대장간 레벨: %s  ·  해금 비용: %s G\n(대장간 레벨은 장비를 분해·융합·제작하면 오릅니다)",
			ns.N(d.name), ns.N(d.desc), U.col(okLevel and "6af07a" or "ff6a5a", tostring(d.level)),
			U.col(ns.CanAfford(d.cost) and "ffd24a" or "ff6a5a", U.fmt(d.cost))))
		p.go:SetLabel(okLevel and ("해금하기  " .. U.fmt(d.cost) .. " G") or string.format("대장간 Lv %d에 열림", d.level))
		p.go:SetOff(not okLevel or not ns.CanAfford(d.cost))
	end
	return p
end

ForgeView.Build = {
	fuse = buildFuse, craft = buildCraft,
	gem = buildSocket("gem"), ench = buildSocket("ench"), insc = buildSocket("insc"),
	up = buildUpgrade, smelt = buildSmelt, seal = buildSeal, locked = buildLocked,
}
ForgeView.W, ForgeView.H = W, H
