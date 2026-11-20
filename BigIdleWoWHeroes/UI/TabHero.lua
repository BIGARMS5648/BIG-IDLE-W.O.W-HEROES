-- Hero screen (영웅): a strip with every hero; on the left the selected hero
-- with the ten equipment slots around them; on the right three sub-pages:
-- 장비 (stats and the chosen slot), 기술 (skills, own points) and 특성
-- (passive talent tree, talent points).
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes

local LEFT_W, RIGHT_X, RIGHT_W = 392, 404, 444
local TOP = -54
local SLOT_SIZE = 48
local LEFT_SLOTS = { "mh", "head", "chest", "hands", "feet" }
local RIGHT_SLOTS = { "oh", "wrist", "neck", "ring", "trinket" }
local SUBS = {
	{ key = "gear", name = "장비" },
	{ key = "skills", name = "기술" },
	{ key = "tree", name = "특성" },
}

-- Which rune opens each skill slot (slot 1 is always open).
local SLOT_RUNE = { [2] = "c4", [3] = "c9" }

local function heroOf() return Main.SelectedHero() end

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
-- Two-click confirmation for buttons that cannot be undone.
local function armed(b, label, armedLabel, action)
	b.armT = 0
	b.baseLabel = label
	b.onClick = function(self)
		if self.armT > 0 then
			self.armT = 0
			self:SetLabel(self.baseLabel)
			action()
		else
			self.armT = 4
			self:SetLabel(armedLabel)
		end
	end
	function b:Disarm()
		if self.armT > 0 then
			self.armT = max(0, self.armT - 0.2)
			if self.armT == 0 then self:SetLabel(self.baseLabel) end
		end
	end
	function b:SetBase(t)
		self.baseLabel = t
		if self.armT == 0 then self:SetLabel(t) end
	end
end

local function slotTip(self)
	local id = heroOf()
	local h = id and ns.db.heroes[id]
	local it = h and h.gear[self.slot]
	if it then
		local lines = ns.Items.Tooltip(it, id)
		lines[#lines + 1] = { "클릭: 이 칸 보기 (오른쪽에 바꿀 장비 목록)", nil, 0.45, 0.8, 1 }
		return lines
	end
	return UI.SimpleTip(ns.N(ns.SLOT[self.slot].name), "비어 있음. 클릭하면 가방에서 이 칸에 맞는 장비를 보여 줍니다.")
end

-- Bag items for a slot the hero can wear, best gain first.
local function candidates(id, slot)
	local out = {}
	for i, it in ipairs(ns.db.bag) do
		if it.s == slot and ns.Items.CanEquip(id, it) then
			out[#out + 1] = { it = it, idx = i, r = ns.Items.Compare(id, it) or 0 }
		end
	end
	table.sort(out, function(a, b) return a.r > b.r end)
	return out
end

local function skillLines(id, sid)
	local sk = ns.SKILLS[sid]
	local pts = H.SkillPoints(id, sid)
	local eff = H.SkillLevel(id, sid)
	local lvl = max(1, eff)
	local lines = { { ns.N(sk.name), string.format("레벨 %d / %d", pts, ns.SKILL_MAX), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
	if eff > pts then lines[#lines + 1] = { string.format("장비 효과 포함 레벨 %d", eff), nil, 0.4, 1, 0.4 } end
	lines[#lines + 1] = { ns.SkillTag(sid) .. " · " .. ns.SkillActText(sid, lvl), nil, 0.6, 0.8, 1 }
	lines[#lines + 1] = { ns.SkillDesc(sid, lvl), nil, 1, 1, 1, true }
	return lines
end

------------------------------------------------------------------------
-- Rename (modal): preview a new name before keeping it
------------------------------------------------------------------------
local rename = {}

local function buildRename()
	local c = Main.ModalContent(420, 170)
	rename.frame = c
	local t = UI.Title(c, "이름 바꾸기", 18)
	t:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	rename.old = UI.Text(c, 12)
	rename.old:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -32)
	UI.Color(rename.old, UI.C.sub)
	local box = UI.Panel(c, 420, 44, "inset")
	box:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -56)
	rename.new = UI.Text(box, 18)
	rename.new:SetPoint("LEFT", box, "LEFT", 14, 0)
	local reroll = UI.Button(box, 70, 32, "다시", function()
		local h = ns.db.heroes[rename.id]
		rename.name = H.RollName(h.spec, h.sex)
		rename.refresh()
	end, "blue")
	reroll:SetPoint("RIGHT", box, "RIGHT", -6, 0)
	local cancel = UI.Button(c, 120, 34, "취소", function() Main.CloseModal() end, "dark")
	cancel:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	local ok = UI.Button(c, 180, 34, "이 이름으로", function()
		local h = ns.db.heroes[rename.id]
		if h and rename.name then
			h.name = rename.name
			ns.Fire("HEROES")
		end
		Main.CloseModal()
	end, "primary")
	ok:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
end

function rename.refresh()
	rename.old:SetText("지금 이름: " .. H.Name(rename.id))
	rename.new:SetText(rename.name or "")
end

local function openRename(id)
	if not rename.frame then buildRename() end
	local h = ns.db.heroes[id]
	rename.id = id
	rename.name = H.RollName(h.spec, h.sex)
	rename.refresh()
	Main.ShowModal(rename.frame)
end

------------------------------------------------------------------------
-- Detailed stats (modal)
------------------------------------------------------------------------
local sheet = {}

local function openSheet(id)
	if not sheet.frame then
		local c = Main.ModalContent(520, 360)
		sheet.frame = c
		sheet.title = UI.Title(c, "", 18)
		sheet.title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		sheet.rows = {}
		for i = 1, 24 do
			local col, row = (i <= 12) and 0 or 1, (i - 1) % 12
			local box = CreateFrame("Frame", nil, c)
			box:SetSize(250, 22)
			box:SetPoint("TOPLEFT", c, "TOPLEFT", col * 270, -34 - row * 23)
			box.bg = box:CreateTexture(nil, "BACKGROUND")
			box.bg:SetAllPoints(box)
			UI.Fill(box.bg, 1, 1, 1, (row % 2 == 0) and 0.05 or 0)
			box.l = UI.Text(box, 12)
			box.l:SetPoint("LEFT", box, "LEFT", 6, 0)
			UI.Color(box.l, UI.C.sub)
			box.v = UI.Text(box, 12)
			box.v:SetPoint("RIGHT", box, "RIGHT", -6, 0)
			box.v:SetJustifyH("RIGHT")
			sheet.rows[i] = box
		end
		local close = UI.Button(c, 120, 32, "닫기", function() Main.CloseModal() end, "dark")
		close:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, -6)
	end
	sheet.title:SetText(H.Name(id) .. " 상세 능력치")
	local rows = ns.Stats.Sheet(id)
	for i, box in ipairs(sheet.rows) do
		local r = rows[i]
		if r then
			box.l:SetText(r[1])
			box.v:SetText(r[2])
			box:Show()
		else
			box:Hide()
		end
	end
	Main.ShowModal(sheet.frame)
end

------------------------------------------------------------------------
-- Left: the hero with the equipment around them
------------------------------------------------------------------------
local function buildLeft(page)
	local L = UI.Panel(page, LEFT_W, 414, "card")
	L:SetPoint("TOPLEFT", page, "TOPLEFT", 0, TOP)
	page.L = L
	L.name = UI.Text(L, 18)
	L.name:SetPoint("TOP", L, "TOP", 0, -10)
	L.name:SetJustifyH("CENTER")
	L.spec = UI.Text(L, 11)
	L.spec:SetPoint("TOP", L.name, "BOTTOM", 0, -3)
	L.spec:SetJustifyH("CENTER")
	UI.Color(L.spec, UI.C.sub)
	L.level = UI.Text(L, 12)
	L.level:SetPoint("TOP", L.spec, "BOTTOM", 0, -6)
	L.level:SetJustifyH("CENTER")
	L.xp = UI.Bar(L, 200, 8, 0.55, 0.40, 1)
	L.xp:SetPoint("TOP", L.level, "BOTTOM", 0, -4)
	UI.Tip(L.xp, function()
		local id = heroOf()
		local h = id and ns.db.heroes[id]
		if not h then return nil end
		if h.level >= ns.HERO_MAX_LEVEL then return UI.SimpleTip("경험치", "최고 레벨입니다.") end
		return UI.SimpleTip("경험치", string.format("%s / %s\n출전해서 싸우면 경험치를 얻습니다. 지역 레벨이 영웅보다 너무 낮으면 적게 얻습니다.",
			U.fmt(h.xp), U.fmt(ns.XPForLevel(h.level))))
	end)

	L.stage = UI.Art(L, "glow", "BORDER", 1, 0.85, 0.5, 0.18)
	L.stage:SetSize(220, 120)
	L.stage:SetPoint("CENTER", L, "TOP", 0, -270)
	L.figure = UI.HeroFigure(L, 104)
	L.figure:SetPoint("TOP", L, "TOP", 0, -150)
	L.figure:EnableMouse(false)
	L.figure.lvl:Hide()

	L.slots = {}
	local function slotButton(slot, x, y)
		local b = UI.IconButton(L, SLOT_SIZE, function(self)
			page.slot = self.slot
			page.sub = "gear"
			Main.Refresh()
		end)
		b.slot = slot
		b:SetPoint("TOPLEFT", L, "TOPLEFT", x, y)
		b.label = UI.Text(b, 9, ns.N(ns.SLOT[slot].name))
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label:SetJustifyH("CENTER")
		UI.Color(b.label, UI.C.dim)
		b.up = UI.Text(b, 12, nil, "OUTLINE")
		b.up:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 2)
		b.up:SetTextColor(0.3, 1, 0.3)
		UI.Tip(b, slotTip)
		L.slots[slot] = b
	end
	for i, slot in ipairs(LEFT_SLOTS) do slotButton(slot, 12, -94 - (i - 1) * 56) end
	for i, slot in ipairs(RIGHT_SLOTS) do slotButton(slot, LEFT_W - 12 - SLOT_SIZE, -94 - (i - 1) * 56) end

	L.equip = UI.Button(L, 180, 32, "일괄 장착", function()
		local id = heroOf()
		if id then
			local n = ns.Items.AutoEquip(id)
			ns.Toast(n > 0 and string.format("%s: 장비 %d개를 바꿨습니다.", H.ShortName(id), n) or "가방에 더 좋은 장비가 없습니다.")
		end
	end, "blue")
	L.equip:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 12, 12)
	UI.Tip(L.equip, function() return UI.SimpleTip("일괄 장착", "가방에서 이 영웅에게 더 좋은 장비를 모든 칸에 장착합니다. 빼낸 장비는 가방으로 돌아갑니다.") end)
	L.equipAll = UI.Button(L, 180, 32, "파티 전원 일괄 장착", function()
		local n = 0
		for i = 1, ns.PARTY_SIZE do
			local pid = ns.db.party[i]
			if pid then n = n + ns.Items.AutoEquip(pid) end
		end
		ns.Toast(n > 0 and string.format("파티 전원: 장비 %d개를 바꿨습니다.", n) or "가방에 더 좋은 장비가 없습니다.")
	end, "dark")
	L.equipAll:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", -12, 12)
	L.statLine = UI.Text(L, 11)
	L.statLine:SetPoint("BOTTOM", L, "BOTTOM", 0, 52)
	L.statLine:SetJustifyH("CENTER")
end

local function refreshLeft(page, id)
	local L = page.L
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local cls = ns.CLASSES[sp.class]
	local race = ns.RACES[H.Race(id)]
	L.name:SetText(U.col(cls.hex, H.Name(id)))
	L.spec:SetText(string.format("%s  ·  %s  ·  %s %s", ns.SpecLabel(h.spec), ns.N(ns.ROLE[sp.role].name), race.name, ns.SEX[H.Sex(id)].name))
	L.level:SetText("레벨 " .. h.level)
	L.xp:SetValue(h.level >= ns.HERO_MAX_LEVEL and 1 or h.xp / ns.XPForLevel(h.level))
	L.figure:SetHeroFigure(id)
	L.figure:SetBadge(false)
	local s = ns.Stats.Get(id)
	L.statLine:SetText(string.format("공격력 %s   ·   생명력 %s   ·   초당 피해 %s",
		U.col("ffd24a", U.fmt(s.atk)), U.col("ffd24a", U.fmt(s.hp)), U.col("ffd24a", U.fmt(ns.Stats.DPS(s)))))
	local ups = ns.Guide.UpgradeHeroes()[id]
	for slot, b in pairs(L.slots) do
		local it = h.gear[slot]
		b:SetSelected(page.sub == "gear" and page.slot == slot)
		if it then
			b:SetIconName(ns.Items.Icon(it))
			b:SetQuality(it.q)
			b:SetLocked(it.lock)
			b.label:Hide()
		else
			b.icon:Hide()
			b:SetQuality(nil)
			b:SetLocked(false)
			b.label:Show()
		end
		local better = false
		if ups then
			for _, c in ipairs(candidates(id, slot)) do
				if c.r > 1.01 then better = true end
				break
			end
		end
		b.up:SetText(better and "+" or "")
	end
end

------------------------------------------------------------------------
-- Right: 장비 sub-page
------------------------------------------------------------------------
local KEY_STATS = {
	{ "공격력", function(s) return U.fmt(s.atk) end },
	{ "공격 속도", function(s) return U.num(s.aspd, 2) .. "/초" end },
	{ "치명타", function(s) return U.num(s.crit, 1) .. "% · " .. U.num(s.critdmg, 0) .. "%" end },
	{ "초당 피해", function(s) return U.fmt(ns.Stats.DPS(s)) end },
	{ "생명력", function(s) return U.fmt(s.hp) end },
	{ "방어도", function(s) return U.fmt(s.armor) .. " (" .. U.num(ns.Stats.ArmorDR(s.armor, s.level) * 100, 0) .. "%)" end },
	{ "회피 · 막기", function(s) return U.num(s.dodge, 1) .. "% · " .. U.num(s.block, 1) .. "%" end },
	{ "재사용 감소", function(s) return U.num(s.cdr, 1) .. "%" end },
}

local function buildGear(R)
	local p = CreateFrame("Frame", nil, R)
	p:SetAllPoints(R)
	R.gear = p
	p.rows = {}
	for i, st in ipairs(KEY_STATS) do
		local col, row = (i - 1) % 2, floor((i - 1) / 2)
		local box = CreateFrame("Frame", nil, p)
		box:SetSize(212, 22)
		box:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + col * 218, -44 - row * 24)
		box.bg = box:CreateTexture(nil, "BACKGROUND")
		box.bg:SetAllPoints(box)
		UI.Fill(box.bg, 1, 1, 1, 0.05)
		box.l = UI.Text(box, 11, st[1])
		box.l:SetPoint("LEFT", box, "LEFT", 6, 0)
		UI.Color(box.l, UI.C.sub)
		box.v = UI.Text(box, 12)
		box.v:SetPoint("RIGHT", box, "RIGHT", -6, 0)
		box.v:SetJustifyH("RIGHT")
		box.fn = st[2]
		p.rows[i] = box
	end
	p.more = UI.Button(p, 120, 24, "상세 능력치", function() if heroOf() then openSheet(heroOf()) end end, "dark")
	p.more:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -142)

	p.slotTitle = UI.Title(p, "", 13)
	p.slotTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -146)
	p.worn = UI.IconButton(p, 44)
	p.worn:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -172)
	UI.Tip(p.worn, function()
		local id = heroOf()
		local it = id and ns.db.heroes[id].gear[p.slot]
		return it and ns.Items.Tooltip(it, id) or nil
	end)
	p.wornName = UI.Text(p, 12)
	p.wornName:SetPoint("TOPLEFT", p, "TOPLEFT", 60, -174)
	p.wornName:SetWidth(240)
	p.wornName:SetWordWrap(false)
	p.wornSub = UI.Text(p, 10)
	p.wornSub:SetPoint("TOPLEFT", p, "TOPLEFT", 60, -192)
	UI.Color(p.wornSub, UI.C.sub)
	p.unequip = UI.Button(p, 70, 26, "해제", function()
		local id = heroOf()
		if id then UI.Try(ns.Items.Unequip(id, p.slot)) end
	end, "dark")
	p.unequip:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -178)

	p.listTitle = UI.Text(p, 11)
	p.listTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -226)
	UI.Color(p.listTitle, UI.C.sub)
	p.cands = {}
	for i = 1, 4 do
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(428, 38)
		row:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -244 - (i - 1) * 40)
		row.bg = UI.Slice(row, "inset", "BACKGROUND")
		row.icon = UI.IconButton(row, 32)
		row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		UI.Tip(row.icon, function(self)
			local id = heroOf()
			return self.data and ns.Items.Tooltip(self.data, id) or nil
		end)
		row.name = UI.Text(row, 12)
		row.name:SetPoint("LEFT", row, "LEFT", 44, 6)
		row.name:SetWidth(250)
		row.name:SetWordWrap(false)
		row.gain = UI.Text(row, 10)
		row.gain:SetPoint("LEFT", row, "LEFT", 44, -8)
		row.go = UI.Button(row, 72, 26, "장착", nil, "green")
		row.go:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		p.cands[i] = row
	end
	p.none = UI.Text(p, 11, "가방에 이 칸에 맞는 장비가 없습니다.")
	p.none:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -252)
	UI.Color(p.none, UI.C.dim)
	p.toBag = UI.Button(p, 140, 24, "가방에서 보기", function() Main.ShowTab("bag", { slot = p.slot }) end, "dark")
	p.toBag:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, 8)
end

local function refreshGear(page, id)
	local p = page.R.gear
	local s = ns.Stats.Get(id)
	for _, box in ipairs(p.rows) do box.v:SetText(box.fn(s)) end
	local h = ns.db.heroes[id]
	-- default slot: first one with an upgrade, else the main hand
	if not page.slot then
		page.slot = "mh"
		for _, slot in ipairs(ns.SLOTS) do
			local c = candidates(id, slot)[1]
			if c and c.r > 1.01 then page.slot = slot break end
		end
	end
	p.slot = page.slot
	p.slotTitle:SetText(ns.N(ns.SLOT[page.slot].name) .. " 칸")
	local it = h.gear[page.slot]
	if it then
		p.worn:SetIconName(ns.Items.Icon(it))
		p.worn:SetQuality(it.q)
		p.wornName:SetText(U.col(ns.QUALITY[it.q].hex, ns.Items.Name(it)))
		p.wornSub:SetText(string.format("%s · 아이템 레벨 %d", ns.N(ns.QUALITY[it.q].name), it.l))
		p.unequip:Show()
	else
		p.worn:Clear()
		p.wornName:SetText(U.col("8a90a2", "비어 있음"))
		p.wornSub:SetText("")
		p.unequip:Hide()
	end
	local list = candidates(id, page.slot)
	p.listTitle:SetText(#list > 0 and string.format("가방에서 바꿀 수 있는 장비 %d개 (좋은 순)", #list) or "")
	p.none:SetShown(#list == 0)
	for i, row in ipairs(p.cands) do
		local c = list[i]
		if c then
			row.icon:SetIconName(ns.Items.Icon(c.it))
			row.icon:SetQuality(c.it.q)
			row.icon:SetLocked(c.it.lock)
			row.icon.data = c.it
			row.name:SetText(U.col(ns.QUALITY[c.it.q].hex, ns.Items.Name(c.it)) .. U.col("8a90a2", "  Lv " .. c.it.l))
			local pct = (c.r - 1) * 100
			if pct > 0.2 then
				row.gain:SetText(U.col("40ff40", string.format("전투력 +%s%%", U.num(pct, 1))))
			elseif pct < -0.2 then
				row.gain:SetText(U.col("ff6060", string.format("전투력 %s%%", U.num(pct, 1))))
			else
				row.gain:SetText(U.col("aab3c8", "비슷함"))
			end
			row.go:SetStyle(pct > 0.2 and "green" or "dark")
			local item = c.it
			row.go.onClick = function()
				local idx = ns.Items.IndexInBag(item)
				if idx then UI.Try(ns.Items.Equip(id, idx)) end
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

------------------------------------------------------------------------
-- Right: 기술 sub-page
------------------------------------------------------------------------
local function buildSkills(R, page)
	local p = CreateFrame("Frame", nil, R)
	p:SetAllPoints(R)
	R.skills = p
	p.points = UI.Pill(p, 120, 26, 0.10, 0.30, 0.15, 1)
	p.points:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -42)
	UI.Tip(p.points, function() return UI.SimpleTip("기술 점수", "레벨 1에 1점, 그 뒤 4레벨마다 1점씩 생깁니다. 기술을 배우거나(1점) 한 단계 올리는 데(1점) 씁니다. 특성 점수와는 따로입니다.") end)
	p.auto = UI.Button(p, 110, 26, "자동 배분", function()
		local id = heroOf()
		if id then
			local n = H.AutoSkills(id)
			ns.Toast(n > 0 and string.format("기술 점수 %d점을 썼습니다.", n) or "쓸 수 있는 기술 점수가 없습니다.")
		end
	end, "primary")
	p.auto:SetPoint("LEFT", p.points, "RIGHT", 8, 0)
	p.reset = UI.Button(p, 150, 26, "", nil, "red")
	p.reset:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -42)
	armed(p.reset, "", "정말 초기화? 한 번 더", function()
		local id = heroOf()
		if id then UI.Try(H.ResetSkills(id)) end
	end)
	UI.Tip(p.reset, function() return UI.SimpleTip("기술 초기화", "첫 기술을 뺀 모든 기술 점수를 돌려받습니다. 골드가 듭니다.") end)

	p.slotsTitle = UI.Text(p, 11, "장착 칸 (전투에서 쓰는 기술 3개)")
	p.slotsTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -76)
	UI.Color(p.slotsTitle, UI.C.sub)
	p.slots = {}
	for i = 1, 3 do
		local b = UI.IconButton(p, 38, function(self)
			local id = heroOf()
			if self.locked then
				Main.ShowTab("runes", { rune = SLOT_RUNE[i] })
			elseif self.sid then
				page.skill = self.sid
				Main.Refresh()
			end
		end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 214 + (i - 1) * 76, -66)
		b.num = UI.Text(b, 10, tostring(i), "OUTLINE")
		b.num:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -2)
		b.lockText = UI.Text(p, 9)
		b.lockText:SetPoint("LEFT", b, "RIGHT", 3, 0)
		b.lockText:SetWidth(34)
		UI.Color(b.lockText, UI.C.dim)
		UI.Tip(b, function(self)
			local id = heroOf()
			if self.locked then
				local rune = ns.Runes.byId[SLOT_RUNE[i]]
				local step = ns.Runes.NextStepTo(SLOT_RUNE[i])
				local body = string.format("'%s'을(를) 배우면 열립니다.", ns.N(rune.name))
				if step and step ~= SLOT_RUNE[i] then
					body = body .. string.format(" 먼저 '%s'이(가) 필요합니다.", ns.N(ns.Runes.byId[step].name))
				end
				return UI.SimpleTip("잠긴 기술 칸", body .. "\n클릭: 룬 화면에서 보기")
			end
			if self.sid then return skillLines(id, self.sid) end
			return UI.SimpleTip("빈 기술 칸", "아래 목록에서 배운 기술을 고르고 '장착'을 누르세요.")
		end)
		p.slots[i] = b
	end

	p.rows = {}
	for i = 1, 6 do
		local row = CreateFrame("Button", nil, p)
		row:SetSize(428, 33)
		row:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -110 - (i - 1) * 35)
		row.bg = UI.Slice(row, "inset", "BACKGROUND")
		row.icon = UI.IconButton(row, 30)
		row.icon:EnableMouse(false)
		row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
		row.name = UI.Text(row, 12)
		row.name:SetPoint("LEFT", row, "LEFT", 40, 0)
		row.tag = UI.Pill(row, 46, 16, 0.2, 0.25, 0.4, 1)
		row.tag:SetPoint("LEFT", row, "LEFT", 176, 0)
		row.state = UI.Text(row, 11)
		row.state:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		row.state:SetJustifyH("RIGHT")
		row.dot = UI.Badge(row, 12)
		row.dot:ClearAllPoints()
		row.dot:SetPoint("TOPLEFT", row, "TOPLEFT", 26, -2)
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.skill = self.sid
			Main.Refresh()
		end)
		UI.Tip(row, function(self) return self.sid and skillLines(heroOf(), self.sid) or nil end)
		p.rows[i] = row
	end

	local d = UI.Panel(p, 428, 92, "card")
	d:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -316)
	p.detail = d
	d.name = UI.Text(d, 12)
	d.name:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -7)
	d.act = UI.Text(d, 10)
	d.act:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -23)
	UI.Color(d.act, UI.C.sub)
	d.now = UI.Text(d, 10)
	d.now:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -37)
	d.now:SetWidth(278)
	d.now:SetJustifyV("TOP")
	if d.now.SetMaxLines then d.now:SetMaxLines(2) end
	d.next = UI.Text(d, 10)
	d.next:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -63)
	d.next:SetWidth(278)
	d.next:SetJustifyV("TOP")
	if d.next.SetMaxLines then d.next:SetMaxLines(2) end
	d.learn = UI.Button(d, 122, 32, "", nil, "green")
	d.learn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -8)
	d.learn.clickWhenOff = true
	d.equip = UI.Button(d, 122, 32, "", nil, "blue")
	d.equip:SetPoint("TOPRIGHT", d.learn, "BOTTOMRIGHT", 0, -6)
	d.equip.clickWhenOff = true
end

local function refreshSkills(page, id)
	local p = page.R.skills
	local h = ns.db.heroes[id]
	local list = H.SkillList(id)
	local free = H.SkillPointsFree(id)
	p.points:SetLabel(string.format("기술 점수 %d", free))
	p.points:SetColor(free > 0 and 0.12 or 0.12, free > 0 and 0.45 or 0.15, free > 0 and 0.2 or 0.22, 1)
	p.auto:SetOff(free == 0)
	p.reset:SetBase("초기화 " .. U.fmt(H.SkillResetCost(id)) .. " G")
	p.reset:SetOff(H.SkillPointsSpent(id) <= 1 or not ns.CanAfford(H.SkillResetCost(id)))
	local slots = ns.SkillSlots()
	for i, b in ipairs(p.slots) do
		b.locked = i > slots
		local sid = h.skills[i]
		b.sid = (not b.locked) and sid or nil
		if b.locked then
			b.icon:Hide()
			b:SetLocked(true)
			b:SetQuality(nil)
			b.lockText:SetText("룬으로\n열기")
		elseif sid then
			b:SetIconName(ns.SKILLS[sid].icon)
			b:SetLocked(false)
			b:SetQuality(5)
			b.lockText:SetText("")
		else
			b.icon:Hide()
			b:SetLocked(false)
			b:SetQuality(nil)
			b.lockText:SetText("비어\n있음")
		end
	end
	if not page.skill or not H.SkillUnlockLevel(id, page.skill) then page.skill = list[1] end
	for i, row in ipairs(p.rows) do
		local sid = list[i]
		row.sid = sid
		local sk = ns.SKILLS[sid]
		local pts = H.SkillPoints(id, sid)
		local open = H.SkillUnlocked(id, sid)
		row.icon:SetIconName(sk.icon)
		row.icon:SetDim(not open)
		row.name:SetText(open and ns.N(sk.name) or U.col("8a90a2", ns.N(sk.name)))
		row.tag:SetLabel(ns.SkillTag(sid))
		local eq = H.IsSkillEquipped(id, sid)
		if not open then
			row.state:SetText(U.col("8a8070", string.format("영웅 Lv %d에 열림", ns.SKILL_UNLOCK[i])))
		elseif pts == 0 then
			row.state:SetText(U.col("ffd24a", "배울 수 있음"))
		else
			row.state:SetText(string.format("%sLv %d/%d", eq and U.col("60e070", "장착 " .. eq .. "번  ") or "", pts, ns.SKILL_MAX))
		end
		row.dot:Set(open and free > 0 and pts < ns.SKILL_MAX and (pts == 0))
		if sid == page.skill then row.bg:SetColor(0.95, 0.8, 0.4, 1) else row.bg:SetColor(1, 1, 1, 1) end
	end
	-- detail
	local d = p.detail
	local sid = page.skill
	local sk = ns.SKILLS[sid]
	local pts = H.SkillPoints(id, sid)
	local lvl = max(1, H.SkillLevel(id, sid))
	d.name:SetText(U.col("ffd24a", ns.N(sk.name)) .. string.format("  Lv %d/%d", pts, ns.SKILL_MAX))
	d.act:SetText(ns.SkillTag(sid) .. " · " .. ns.SkillActText(sid, lvl))
	d.now:SetText((pts > 0 and "지금: " or "Lv 1: ") .. ns.SkillDesc(sid, lvl))
	if pts > 0 and pts < ns.SKILL_MAX then
		d.next:SetText(U.col("60e070", "다음: " .. ns.SkillDesc(sid, H.SkillLevel(id, sid) + 1)))
	else
		d.next:SetText("")
	end
	local ok, why = H.CanLearnSkill(id, sid)
	d.learn:SetLabel(pts == 0 and "배우기 (1점)" or (pts >= ns.SKILL_MAX and "최대 레벨" or "강화 (1점)"))
	d.learn:SetOff(not ok)
	d.learn.onClick = function()
		if UI.Try(H.LearnSkill(id, sid)) then return end
		if not ok then UI.Try(false, why) end
	end
	local eq = H.IsSkillEquipped(id, sid)
	if eq then
		d.equip:SetLabel("해제")
		d.equip:SetStyle("dark")
		d.equip:SetOff(false)
		d.equip.onClick = function() H.UnequipSkill(id, sid) end
	else
		local full = #h.skills >= ns.SkillSlots()
		d.equip:SetLabel(pts == 0 and "장착 (먼저 배우기)" or (full and "장착 (칸 가득)" or "장착"))
		d.equip:SetStyle("blue")
		d.equip:SetOff(pts == 0 or full)
		d.equip.onClick = function()
			if pts == 0 then
				UI.Try(false, "먼저 기술을 배우세요.")
			elseif full then
				UI.Try(false, "기술 칸이 가득 찼습니다. 위의 장착 칸에서 기술을 골라 해제하거나, 룬으로 칸을 늘리세요.")
			else
				UI.Try(H.EquipSkill(id, sid))
			end
		end
	end
end

------------------------------------------------------------------------
-- Right: 특성 sub-page
------------------------------------------------------------------------
local function nodeTip(self)
	local id = heroOf()
	if not id then return nil end
	local node = H.Tree(id)[self.tier][self.n]
	local lvl = H.NodeLevel(id, self.tier, self.n)
	local a = ns.AFFIX[node.p]
	local lines = { { ns.N(a.n), string.format("%d / %d", lvl, node.max), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
	lines[#lines + 1] = { "1점마다 " .. ns.Stats.ModText(node.p, node.v), nil, 1, 1, 1 }
	if lvl > 0 then lines[#lines + 1] = { "지금 " .. ns.Stats.ModText(node.p, node.v * lvl), nil, 0.4, 1, 0.4 } end
	local ok, why = H.CanSpend(id, self.tier, self.n)
	if ok then
		lines[#lines + 1] = { "클릭: 특성 점수 1점 쓰기", nil, 0.45, 0.8, 1 }
	elseif why then
		lines[#lines + 1] = { why, nil, 1, 0.45, 0.35 }
	end
	return lines
end

local function buildTree(R)
	local p = CreateFrame("Frame", nil, R)
	p:SetAllPoints(R)
	R.tree = p
	p.points = UI.Pill(p, 120, 26, 0.10, 0.30, 0.15, 1)
	p.points:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -42)
	UI.Tip(p.points, function() return UI.SimpleTip("특성 점수", "레벨이 오를 때마다 1점씩 생깁니다. 능력치를 올리는 데만 쓰입니다(기술은 '기술' 탭).") end)
	p.auto = UI.Button(p, 110, 26, "자동 배분", function()
		local id = heroOf()
		if id then
			local n = H.AutoSpend(id)
			ns.Toast(n > 0 and string.format("특성 점수 %d점을 썼습니다.", n) or "쓸 수 있는 특성 점수가 없습니다.")
		end
	end, "primary")
	p.auto:SetPoint("LEFT", p.points, "RIGHT", 8, 0)
	p.reset = UI.Button(p, 150, 26, "", nil, "red")
	p.reset:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -42)
	armed(p.reset, "", "정말 초기화? 한 번 더", function()
		local id = heroOf()
		if id then UI.Try(H.ResetTree(id)) end
	end)
	UI.Tip(p.reset, function() return UI.SimpleTip("특성 초기화", "쓴 특성 점수를 모두 돌려받습니다. 골드가 듭니다.") end)
	p.help = UI.Text(p, 10, string.format("아래 단계는 특성 점수를 %d점씩 더 쓰면 열립니다.", ns.TREE_TIER_POINTS))
	p.help:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -74)
	UI.Color(p.help, UI.C.dim)
	p.tiers = {}
	for t = 1, 8 do
		local y = -88 - (t - 1) * 40
		local tier = {}
		tier.label = UI.Text(p, 10)
		tier.label:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y - 8)
		tier.label:SetWidth(44)
		tier.nodes = {}
		for n = 1, 2 do
			local b = CreateFrame("Button", nil, p)
			b:SetSize(188, 37)
			b:SetPoint("TOPLEFT", p, "TOPLEFT", 56 + (n - 1) * 192, y)
			b.bg = UI.Slice(b, "inset", "BACKGROUND")
			b.icon = UI.IconButton(b, 30)
			b.icon:EnableMouse(false)
			b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)
			b.name = UI.Text(b, 11)
			b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 40, -4)
			b.name:SetWidth(142)
			b.name:SetWordWrap(false)
			b.val = UI.Text(b, 10)
			b.val:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 40, 4)
			b.val:SetWidth(104)
			b.val:SetWordWrap(false)
			b.lv = UI.Text(b, 11)
			b.lv:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 4)
			b.lv:SetJustifyH("RIGHT")
			b.tier, b.n = t, n
			b:RegisterForClicks("LeftButtonUp")
			b:SetScript("OnClick", function(self)
				local id = heroOf()
				if id then
					ns.Sound("click")
					UI.Try(H.SpendPoint(id, self.tier, self.n))
				end
			end)
			UI.Tip(b, nodeTip)
			tier.nodes[n] = b
		end
		p.tiers[t] = tier
	end
end

local function refreshTree(page, id)
	local p = page.R.tree
	local tree = H.Tree(id)
	local free = H.PointsFree(id)
	p.points:SetLabel(string.format("특성 점수 %d", free))
	p.auto:SetOff(free == 0)
	p.reset:SetBase("초기화 " .. U.fmt(H.ResetCost(id)) .. " G")
	p.reset:SetOff(H.PointsSpent(id) == 0 or not ns.CanAfford(H.ResetCost(id)))
	local spent = H.PointsSpent(id)
	for t, tier in ipairs(p.tiers) do
		local open = H.TierOpen(id, t)
		local need = (t - 1) * ns.TREE_TIER_POINTS - spent
		tier.label:SetText(open and (t .. "단계") or U.col("8a8070", need .. "점\n더"))
		for n, b in ipairs(tier.nodes) do
			local node = tree[t][n]
			local a = ns.AFFIX[node.p]
			local lvl = H.NodeLevel(id, t, n)
			b.icon:SetIconName(UI.STAT_ICON[node.p] or "INV_Misc_QuestionMark")
			b.icon:SetDim(not open)
			b.name:SetText(open and ns.N(a.n) or U.col("8a90a2", ns.N(a.n)))
			-- the stat name is on the line above: show just the number here
			local num = "+" .. ns.Stats.FormatValue(node.p, node.v * max(1, lvl))
			b.val:SetText(lvl > 0 and U.col("60e070", num) or U.col("8a90a2", "점당 +" .. ns.Stats.FormatValue(node.p, node.v)))
			local col = lvl >= node.max and "ffd24a" or (lvl > 0 and "ffffff" or "8a90a2")
			b.lv:SetText(U.col(col, lvl .. "/" .. node.max))
			local can = open and free > 0 and lvl < node.max
			if lvl >= node.max then
				b.bg:SetColor(1, 0.85, 0.45, 1)
			elseif can then
				b.bg:SetColor(0.6, 1, 0.65, 1)
			else
				b.bg:SetColor(1, 1, 1, 1)
			end
		end
	end
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function heroOrder()
	local out, seen = {}, {}
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id and ns.db.heroes[id] then out[#out + 1] = id seen[id] = true end
	end
	for _, id in ipairs(H.List()) do
		if not seen[id] then out[#out + 1] = id end
	end
	return out
end

local function build(page)
	page.sub = "gear"
	-- hero strip
	page.strip = {}
	for i = 1, ns.ROSTER_MAX do
		local b = UI.Portrait(page, 40, function(self)
			if self.heroId then
				Main.SelectHero(self.heroId)
			end
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * 46, -4)
		b.lvl:Hide()
		b.out = UI.Text(b, 9, nil, "OUTLINE")
		b.out:SetPoint("BOTTOM", b, "BOTTOM", 0, -2)
		UI.Tip(b, function(self)
			if not self.heroId or not ns.db.heroes[self.heroId] then return nil end
			local lines = { { H.Name(self.heroId), "Lv " .. ns.db.heroes[self.heroId].level, 1, 0.82, 0.3 },
				{ ns.SpecLabel(ns.db.heroes[self.heroId].spec), H.PartySlot(self.heroId) and "출전" or "대기", 0.75, 0.8, 0.9 } }
			if ns.Guide.HeroNeeds(self.heroId) then lines[#lines + 1] = { "할 일이 있습니다 (점수 또는 더 좋은 장비)", nil, 0.4, 1, 0.4 } end
			return lines
		end)
		page.strip[i] = b
	end
	page.renameB = UI.Button(page, 96, 28, "이름 바꾸기", function()
		local id = heroOf()
		if id then openRename(id) end
	end, "dark")
	page.renameB:SetPoint("TOPRIGHT", page, "TOPRIGHT", -112, -8)
	page.dismiss = UI.Button(page, 104, 28, "떠나보내기", nil, "red")
	page.dismiss:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -8)
	armed(page.dismiss, "떠나보내기", "정말요? 한 번 더", function()
		local id = heroOf()
		if id and UI.Try(H.Dismiss(id)) then
			Main.SelectHero(nil)
		end
	end)
	UI.Tip(page.dismiss, function() return UI.SimpleTip("떠나보내기", "영웅이 영영 떠납니다. 장착한 장비는 가방으로 돌아옵니다. 되돌릴 수 없습니다.") end)

	buildLeft(page)

	local R = UI.Panel(page, RIGHT_W, 414, "card")
	R:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X, TOP)
	page.R = R
	R.tabs = {}
	for i, s in ipairs(SUBS) do
		local chip = UI.Chip(R, 140, 28, s.name, function()
			page.sub = s.key
			Main.Refresh()
		end)
		chip:SetPoint("TOPLEFT", R, "TOPLEFT", 8 + (i - 1) * 146, -8)
		chip.key = s.key
		R.tabs[i] = chip
	end
	buildGear(R)
	buildSkills(R, page)
	buildTree(R)

	page.empty = UI.Text(page, 14, "영웅이 없습니다. '편성'에서 첫 영웅을 만드세요.")
	page.empty:SetPoint("CENTER", page, "CENTER", 0, 0)
end

local function refresh(page)
	local id = heroOf()
	local order = heroOrder()
	page.empty:SetShown(id == nil)
	page.L:SetShown(id ~= nil)
	page.R:SetShown(id ~= nil)
	page.renameB:SetShown(id ~= nil)
	page.dismiss:SetShown(id ~= nil)
	for i, b in ipairs(page.strip) do
		local hid = order[i]
		b.heroId = hid
		if hid then
			b:SetHero(hid)
			UI.SetHeroIcon(b.icon, hid)
			b.lvl:Hide()
			b:SetSelected(hid == id)
			b:SetBadge(ns.Guide.HeroNeeds(hid) and H.PartySlot(hid) ~= nil)
			b:SetDim(H.PartySlot(hid) == nil)
			b:Show()
		else
			b:Hide()
		end
	end
	if not id then return end
	if page.heroShown ~= id then
		page.heroShown = id
		page.slot = nil
		page.skill = nil
	end
	page.dismiss:SetOff(H.Count() <= 1)
	refreshLeft(page, id)
	local R = page.R
	local badges = {
		gear = ns.Guide.UpgradeHeroes()[id] and true or nil,
		skills = H.SkillPointsFree(id) > 0 and H.SkillPointsFree(id) or nil,
		tree = H.PointsFree(id) > 0 and H.PointsFree(id) or nil,
	}
	for _, chip in ipairs(R.tabs) do
		chip:SetOn(chip.key == page.sub)
		chip:SetBadge(badges[chip.key])
	end
	R.gear:SetShown(page.sub == "gear")
	R.skills:SetShown(page.sub == "skills")
	R.tree:SetShown(page.sub == "tree")
	if page.sub == "gear" then
		refreshGear(page, id)
	elseif page.sub == "skills" then
		refreshSkills(page, id)
	else
		refreshTree(page, id)
	end
end

local function tick(page)
	if page.dismiss then page.dismiss:Disarm() end
	if page.R then
		page.R.skills.reset:Disarm()
		page.R.tree.reset:Disarm()
	end
end

local function open(page, opts)
	if opts and opts.sub then page.sub = opts.sub end
	if opts and opts.hero then Main.SelectHero(opts.hero) end
end

Main.RegisterTab({
	key = "hero", title = "영웅", sub = "장비, 기술, 특성",
	icon = "INV_Helmet_06", art = "icon_hero", build = build, refresh = refresh, open = open, tick = tick,
	events = { "HEROES", "PARTY", "LEVEL", "TREE", "SKILLS", "GEAR", "BAG", "STATS", "RUNES", "RESET", "FACTION" },
})
