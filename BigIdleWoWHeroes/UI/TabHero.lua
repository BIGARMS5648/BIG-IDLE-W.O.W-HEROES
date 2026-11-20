-- Hero screen (영웅), laid out like the character screens of current mobile
-- RPGs (see docs/UI_RESEARCH.md): a column of hero portraits on the far left,
-- a vertical menu of the hero's pages next to it, then the page itself.
--   장비: the hero in the middle with the ten equipment slots around them;
--         on the right the stats, or the chosen slot and what could go there.
--   기술: the chosen skill in detail on the left, the skill list on the right.
--   특성: the passive talent tree.
-- The page's main action is the gold button at the bottom right.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes

local PAGE_H = 468
local STRIP_W = 44             -- hero portraits
local MENU_X, MENU_W = 52, 116 -- page menu
local CX = 176                 -- content starts here
local CW = 848 - CX            -- content width (672)
local FIG_W = 332              -- 장비: hero + slots
local SIDE_X = CX + FIG_W + 8  -- 장비: right panel
local SIDE_W = 848 - SIDE_X    -- 332
local SLOT_SIZE = 46
local LEFT_SLOTS = { "mh", "head", "chest", "hands", "feet" }
local RIGHT_SLOTS = { "oh", "wrist", "neck", "ring", "trinket" }
local SUBS = {
	{ key = "gear", name = "장비", hint = "장비 10칸과 능력치" },
	{ key = "skills", name = "기술", hint = "기술 점수로 배우고 강화" },
	{ key = "tree", name = "특성", hint = "특성 점수로 능력치 강화" },
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
-- 장비: the hero with the slots around them, stats or slot on the right
------------------------------------------------------------------------
local KEY_STATS = {
	{ "atk", "공격력", function(s) return U.fmt(s.atk) end },
	{ "aspd", "공격 속도", function(s) return U.num(s.aspd, 2) .. "/초" end },
	{ "crit", "치명타", function(s) return U.num(s.crit, 1) .. "% · " .. U.num(s.critdmg, 0) .. "%" end },
	{ "multi", "초당 피해", function(s) return U.fmt(ns.Stats.DPS(s)) end },
	{ "hp", "생명력", function(s) return U.fmt(s.hp) end },
	{ "armor", "방어도", function(s) return U.fmt(s.armor) .. " (" .. U.num(ns.Stats.ArmorDR(s.armor, s.level) * 100, 0) .. "%)" end },
	{ "dodge", "회피 · 막기", function(s) return U.num(s.dodge, 1) .. "% · " .. U.num(s.block, 1) .. "%" end },
	{ "cdr", "재사용 감소", function(s) return U.num(s.cdr, 1) .. "%" end },
}

local function buildGear(page)
	local p = CreateFrame("Frame", nil, page)
	p:SetAllPoints(page)
	page.gear = p

	-- the hero and the slots
	local fig = CreateFrame("Frame", nil, p)
	fig:SetSize(FIG_W, PAGE_H)
	fig:SetPoint("TOPLEFT", p, "TOPLEFT", CX, 0)
	p.fig = fig
	fig.name = UI.Text(fig, 18)
	fig.name:SetPoint("TOP", fig, "TOP", 0, -4)
	fig.name:SetJustifyH("CENTER")
	fig.spec = UI.Text(fig, 11)
	fig.spec:SetPoint("TOP", fig.name, "BOTTOM", 0, -3)
	fig.spec:SetJustifyH("CENTER")
	UI.Color(fig.spec, UI.C.sub)
	fig.stage = UI.Art(fig, "glow", "BORDER", 1, 0.85, 0.5, 0.20)
	fig.stage:SetSize(230, 120)
	fig.stage:SetPoint("CENTER", fig, "TOP", 0, -330)
	fig.hero = UI.HeroFigure(fig, 112)
	fig.hero:SetPoint("TOP", fig, "TOP", 0, -150)
	fig.hero:EnableMouse(false)
	fig.hero.lvl:Hide()
	p.slots = {}
	local function slotButton(slot, x, y)
		local b = UI.IconButton(fig, SLOT_SIZE, function(self)
			page.slot = (page.slot ~= self.slot) and self.slot or nil
			Main.Refresh()
		end)
		b.slot = slot
		b:SetPoint("TOPLEFT", fig, "TOPLEFT", x, y)
		b.label = UI.Text(b, 9, ns.N(ns.SLOT[slot].name))
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label:SetJustifyH("CENTER")
		UI.Color(b.label, UI.C.dim)
		b.up = UI.Text(b, 13, nil, "OUTLINE")
		b.up:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 2)
		b.up:SetTextColor(0.3, 1, 0.3)
		UI.Tip(b, slotTip)
		p.slots[slot] = b
	end
	for i, slot in ipairs(LEFT_SLOTS) do slotButton(slot, 4, -62 - (i - 1) * 56) end
	for i, slot in ipairs(RIGHT_SLOTS) do slotButton(slot, FIG_W - 4 - SLOT_SIZE, -62 - (i - 1) * 56) end
	fig.hint = UI.Text(fig, 10, "칸을 누르면 오른쪽에 그 칸의 장비와 바꿀 장비가 나옵니다.")
	fig.hint:SetPoint("BOTTOM", fig, "BOTTOM", 0, 52)
	fig.hint:SetWidth(FIG_W - 20)
	fig.hint:SetJustifyH("CENTER")
	UI.Color(fig.hint, UI.C.dim)
	fig.power = UI.Text(fig, 12)
	fig.power:SetPoint("BOTTOM", fig, "BOTTOM", 0, 24)
	fig.power:SetJustifyH("CENTER")

	-- right panel
	local side = UI.Panel(p, SIDE_W, PAGE_H - 50, "card")
	side:SetPoint("TOPLEFT", p, "TOPLEFT", SIDE_X, 0)
	p.side = side
	side.level = UI.Text(side, 20)
	side.level:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -12)
	side.xpText = UI.Text(side, 10)
	side.xpText:SetPoint("TOPRIGHT", side, "TOPRIGHT", -14, -20)
	side.xpText:SetJustifyH("RIGHT")
	UI.Color(side.xpText, UI.C.sub)
	side.xp = UI.Bar(side, SIDE_W - 28, 6, 0.55, 0.40, 1)
	side.xp:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -40)

	-- stats mode
	side.stats = CreateFrame("Frame", nil, side)
	side.stats:SetAllPoints(side)
	side.rows = {}
	for i, st in ipairs(KEY_STATS) do
		local row = CreateFrame("Frame", nil, side.stats)
		row:SetSize(SIDE_W - 28, 26)
		row:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -58 - (i - 1) * 28)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18)
		row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		UI.SetIcon(row.icon, UI.STAT_ICON[st[1]] or "INV_Misc_QuestionMark")
		row.l = UI.Text(row, 12, st[2])
		row.l:SetPoint("LEFT", row, "LEFT", 26, 0)
		UI.Color(row.l, UI.C.sub)
		row.v = UI.Text(row, 13)
		row.v:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.v:SetJustifyH("RIGHT")
		row.line = UI.Line(row, SIDE_W - 28, 0.4, 0.45, 0.6, 0.25)
		row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.fn = st[3]
		side.rows[i] = row
	end
	side.more = UI.Button(side.stats, 140, 24, "상세 능력치", function() if heroOf() then openSheet(heroOf()) end end, "dark")
	side.more:SetPoint("TOPRIGHT", side, "TOPRIGHT", -14, -290)
	side.ups = UI.Text(side.stats, 11)
	side.ups:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -326)
	side.ups:SetWidth(SIDE_W - 28)

	-- slot mode
	side.slotView = CreateFrame("Frame", nil, side)
	side.slotView:SetAllPoints(side)
	local sv = side.slotView
	sv.title = UI.Title(sv, "", 14)
	sv.title:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -56)
	sv.back = UI.Button(sv, 90, 22, "능력치 보기", function() page.slot = nil Main.Refresh() end, "dark")
	sv.back:SetPoint("TOPRIGHT", side, "TOPRIGHT", -14, -54)
	sv.worn = UI.IconButton(sv, 40)
	sv.worn:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -82)
	UI.Tip(sv.worn, function()
		local id = heroOf()
		local it = id and page.slot and ns.db.heroes[id].gear[page.slot]
		return it and ns.Items.Tooltip(it, id) or nil
	end)
	sv.wornName = UI.Text(sv, 12)
	sv.wornName:SetPoint("TOPLEFT", side, "TOPLEFT", 62, -84)
	sv.wornName:SetWidth(SIDE_W - 150)
	sv.wornName:SetWordWrap(false)
	sv.wornSub = UI.Text(sv, 10)
	sv.wornSub:SetPoint("TOPLEFT", side, "TOPLEFT", 62, -102)
	UI.Color(sv.wornSub, UI.C.sub)
	sv.unequip = UI.Button(sv, 60, 24, "해제", function()
		local id = heroOf()
		if id and page.slot then UI.Try(ns.Items.Unequip(id, page.slot)) end
	end, "dark")
	sv.unequip:SetPoint("TOPRIGHT", side, "TOPRIGHT", -14, -90)
	sv.listTitle = UI.Text(sv, 11)
	sv.listTitle:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -134)
	UI.Color(sv.listTitle, UI.C.sub)
	sv.cands = {}
	for i = 1, 6 do
		local row = CreateFrame("Frame", nil, sv)
		row:SetSize(SIDE_W - 28, 36)
		row:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -152 - (i - 1) * 38)
		row.bg = UI.Slice(row, "inset", "BACKGROUND")
		row.icon = UI.IconButton(row, 30)
		row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
		UI.Tip(row.icon, function(self) return self.data and ns.Items.Tooltip(self.data, heroOf()) or nil end)
		row.name = UI.Text(row, 11)
		row.name:SetPoint("LEFT", row, "LEFT", 40, 6)
		row.name:SetWidth(SIDE_W - 140)
		row.name:SetWordWrap(false)
		row.gain = UI.Text(row, 10)
		row.gain:SetPoint("LEFT", row, "LEFT", 40, -8)
		row.go = UI.Button(row, 60, 24, "장착", nil, "green")
		row.go:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		sv.cands[i] = row
	end
	sv.none = UI.Text(sv, 11, "가방에 이 칸에 맞는 장비가 없습니다.")
	sv.none:SetPoint("TOPLEFT", side, "TOPLEFT", 16, -158)
	UI.Color(sv.none, UI.C.dim)
	sv.toBag = UI.Button(sv, 120, 22, "가방에서 보기", function() Main.ShowTab("bag", { slot = page.slot }) end, "dark")
	sv.toBag:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -14, 12)

	-- main actions, bottom right
	p.equipAll = UI.Button(p, 140, 38, "파티 전원 장착", function()
		local n = 0
		for i = 1, ns.PARTY_SIZE do
			local pid = ns.db.party[i]
			if pid then n = n + ns.Items.AutoEquip(pid) end
		end
		ns.Toast(n > 0 and string.format("파티 전원: 장비 %d개를 바꿨습니다.", n) or "가방에 더 좋은 장비가 없습니다.")
	end, "blue")
	p.equipAll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -196, 0)
	UI.Tip(p.equipAll, function() return UI.SimpleTip("파티 전원 장착", "출전 중인 영웅 모두에게 가방 속 더 좋은 장비를 장착합니다.") end)
	p.equip = UI.Button(p, 188, 38, "일괄 장착", function()
		local id = heroOf()
		if id then
			local n = ns.Items.AutoEquip(id)
			ns.Toast(n > 0 and string.format("%s: 장비 %d개를 바꿨습니다.", H.ShortName(id), n) or "가방에 더 좋은 장비가 없습니다.")
		end
	end, "primary")
	p.equip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
	UI.Tip(p.equip, function() return UI.SimpleTip("일괄 장착", "가방에서 이 영웅에게 더 좋은 장비를 모든 칸에 장착합니다. 빼낸 장비는 가방으로 돌아갑니다.") end)
end

local function refreshGear(page, id)
	local p = page.gear
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local cls = ns.CLASSES[sp.class]
	local race = ns.RACES[H.Race(id)]
	local s = ns.Stats.Get(id)
	local fig = p.fig
	fig.name:SetText(U.col(cls.hex, H.Name(id)))
	fig.spec:SetText(string.format("%s  ·  %s  ·  %s %s", ns.SpecLabel(h.spec), ns.N(ns.ROLE[sp.role].name), race.name, ns.SEX[H.Sex(id)].name))
	fig.hero:SetHeroFigure(id)
	fig.hero:SetBadge(false)
	fig.power:SetText(string.format("초당 피해 %s   ·   생명력 %s", U.col("ffd24a", U.fmt(ns.Stats.DPS(s))), U.col("ffd24a", U.fmt(s.hp))))
	local ups = ns.Guide.UpgradeHeroes()[id]
	local upSlots = 0
	for slot, b in pairs(p.slots) do
		local it = h.gear[slot]
		b:SetSelected(page.slot == slot)
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
			local c = candidates(id, slot)[1]
			better = c ~= nil and c.r > 1.01
		end
		if better then upSlots = upSlots + 1 end
		b.up:SetText(better and "+" or "")
	end

	local side = p.side
	if h.level >= ns.HERO_MAX_LEVEL then
		side.level:SetText(U.col("ffd24a", "레벨 " .. h.level) .. U.col("8a90a2", " / " .. ns.HERO_MAX_LEVEL))
		side.xp:SetValue(1)
		side.xpText:SetText("최고 레벨")
	else
		side.level:SetText(U.col("ffd24a", "레벨 " .. h.level) .. U.col("8a90a2", " / " .. ns.HERO_MAX_LEVEL))
		side.xp:SetValue(h.xp / ns.XPForLevel(h.level))
		side.xpText:SetText(string.format("경험치 %s / %s", U.fmt(h.xp), U.fmt(ns.XPForLevel(h.level))))
	end
	side.stats:SetShown(page.slot == nil)
	side.slotView:SetShown(page.slot ~= nil)
	if not page.slot then
		for _, row in ipairs(side.rows) do row.v:SetText(row.fn(s)) end
		side.ups:SetText(upSlots > 0 and U.col("60e070", string.format("가방에 더 좋은 장비가 있는 칸: %d개 (+ 표시)", upSlots))
			or U.col("8a90a2", "가방에 더 좋은 장비가 없습니다."))
	else
		local sv = side.slotView
		sv.title:SetText(ns.N(ns.SLOT[page.slot].name) .. " 칸")
		local it = h.gear[page.slot]
		if it then
			sv.worn:SetIconName(ns.Items.Icon(it))
			sv.worn:SetQuality(it.q)
			sv.wornName:SetText(U.col(ns.QUALITY[it.q].hex, ns.Items.Name(it)))
			sv.wornSub:SetText(string.format("%s · 아이템 레벨 %d · 착용 중", ns.N(ns.QUALITY[it.q].name), it.l))
			sv.unequip:Show()
		else
			sv.worn:Clear()
			sv.wornName:SetText(U.col("8a90a2", "비어 있음"))
			sv.wornSub:SetText("")
			sv.unequip:Hide()
		end
		local list = candidates(id, page.slot)
		sv.listTitle:SetText(#list > 0 and string.format("가방에서 바꿀 수 있는 장비 %d개 (좋은 순)", #list) or "")
		sv.none:SetShown(#list == 0)
		for i, row in ipairs(sv.cands) do
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
	p.equip:SetBadge(ups and true or nil)
end

------------------------------------------------------------------------
-- 기술: detail on the left, list and slots on the right
------------------------------------------------------------------------
local DETAIL_W = 380
local LIST_X = CX + DETAIL_W + 10
local LIST_W = 848 - LIST_X

local function buildSkills(page)
	local p = CreateFrame("Frame", nil, page)
	p:SetAllPoints(page)
	page.skills = p

	-- detail
	local d = UI.Panel(p, DETAIL_W, PAGE_H, "card")
	d:SetPoint("TOPLEFT", p, "TOPLEFT", CX, 0)
	p.detail = d
	d.icon = UI.IconButton(d, 64)
	d.icon:EnableMouse(false)
	d.icon:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -16)
	d.name = UI.Text(d, 18)
	d.name:SetPoint("TOPLEFT", d, "TOPLEFT", 92, -18)
	d.level = UI.Text(d, 13)
	d.level:SetPoint("TOPLEFT", d, "TOPLEFT", 92, -42)
	d.act = UI.Text(d, 11)
	d.act:SetPoint("TOPLEFT", d, "TOPLEFT", 92, -62)
	UI.Color(d.act, UI.C.sub)
	d.line = UI.Line(d, DETAIL_W - 32)
	d.line:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -94)
	d.nowTitle = UI.Text(d, 11, "지금")
	d.nowTitle:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -106)
	UI.Color(d.nowTitle, UI.C.gold)
	d.now = UI.Text(d, 13)
	d.now:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -124)
	d.now:SetWidth(DETAIL_W - 32)
	d.now:SetJustifyV("TOP")
	d.nextTitle = UI.Text(d, 11, "다음 단계")
	d.nextTitle:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -196)
	UI.Color(d.nextTitle, UI.C.gold)
	d.next = UI.Text(d, 13)
	d.next:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -214)
	d.next:SetWidth(DETAIL_W - 32)
	d.next:SetJustifyV("TOP")
	d.req = UI.Pill(d, DETAIL_W - 32, 30, 0.45, 0.22, 0.12, 0.95)
	d.req:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16, 64)
	d.equip = UI.Button(d, 140, 40, "", nil, "blue")
	d.equip:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16, 14)
	d.equip.clickWhenOff = true
	d.learn = UI.Button(d, 196, 40, "", nil, "primary")
	d.learn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -16, 14)
	d.learn.clickWhenOff = true

	-- list side
	p.points = UI.Pill(p, 130, 28, 0.10, 0.30, 0.15, 1)
	p.points:SetPoint("TOPLEFT", p, "TOPLEFT", LIST_X, -2)
	UI.Tip(p.points, function() return UI.SimpleTip("기술 점수", "레벨 1에 1점, 그 뒤 4레벨마다 1점씩 생깁니다. 기술을 배우거나(1점) 한 단계 올리는 데(1점) 씁니다. 특성 점수와는 따로입니다.") end)
	p.auto = UI.Button(p, 100, 28, "자동 배분", function()
		local id = heroOf()
		if id then
			local n = H.AutoSkills(id)
			ns.Toast(n > 0 and string.format("기술 점수 %d점을 썼습니다.", n) or "쓸 수 있는 기술 점수가 없습니다.")
		end
	end, "dark")
	p.auto:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -2)
	p.slotsTitle = UI.Text(p, 11, "전투에서 쓰는 기술 (장착 칸)")
	p.slotsTitle:SetPoint("TOPLEFT", p, "TOPLEFT", LIST_X, -40)
	UI.Color(p.slotsTitle, UI.C.sub)
	p.slots = {}
	for i = 1, 3 do
		local b = UI.IconButton(p, 44, function(self)
			if self.locked then
				Main.ShowTab("runes", { rune = SLOT_RUNE[i] })
			elseif self.sid then
				page.skill = self.sid
				Main.Refresh()
			end
		end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", LIST_X + (i - 1) * (LIST_W / 3), -58)
		b.num = UI.Text(b, 10, tostring(i), "OUTLINE")
		b.num:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -2)
		b.lockText = UI.Text(p, 9)
		b.lockText:SetPoint("LEFT", b, "RIGHT", 4, 0)
		b.lockText:SetWidth(LIST_W / 3 - 50)
		UI.Color(b.lockText, UI.C.dim)
		UI.Tip(b, function(self)
			if self.locked then
				local rune = ns.Runes.byId[SLOT_RUNE[i]]
				local step = ns.Runes.NextStepTo(SLOT_RUNE[i])
				local body = string.format("'%s'을(를) 배우면 열립니다.", ns.N(rune.name))
				if step and step ~= SLOT_RUNE[i] then
					body = body .. string.format(" 먼저 '%s'이(가) 필요합니다.", ns.N(ns.Runes.byId[step].name))
				end
				return UI.SimpleTip("잠긴 기술 칸", body .. "\n클릭: 룬 화면에서 보기")
			end
			if self.sid then return skillLines(heroOf(), self.sid) end
			return UI.SimpleTip("빈 기술 칸", "배운 기술을 고르고 '장착'을 누르세요.")
		end)
		p.slots[i] = b
	end
	p.listTitle = UI.Text(p, 11, "이 전문화의 기술")
	p.listTitle:SetPoint("TOPLEFT", p, "TOPLEFT", LIST_X, -112)
	UI.Color(p.listTitle, UI.C.sub)
	p.rows = {}
	for i = 1, 6 do
		local row = CreateFrame("Button", nil, p)
		row:SetSize(LIST_W, 40)
		row:SetPoint("TOPLEFT", p, "TOPLEFT", LIST_X, -130 - (i - 1) * 43)
		row.bg = UI.Slice(row, "inset", "BACKGROUND")
		row.icon = UI.IconButton(row, 32)
		row.icon:EnableMouse(false)
		row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.name = UI.Text(row, 12)
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -5)
		row.name:SetWidth(LIST_W - 50)
		row.name:SetWordWrap(false)
		row.state = UI.Text(row, 10)
		row.state:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 44, 5)
		row.eq = UI.Pill(row, 46, 16, 0.15, 0.5, 0.25, 1)
		row.eq:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		row.dot = UI.Badge(row, 12)
		row.dot:ClearAllPoints()
		row.dot:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -2)
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.skill = self.sid
			Main.Refresh()
		end)
		UI.Tip(row, function(self) return self.sid and skillLines(heroOf(), self.sid) or nil end)
		p.rows[i] = row
	end
	p.reset = UI.Button(p, LIST_W, 26, "", nil, "red")
	p.reset:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", LIST_X, 0)
	armed(p.reset, "", "정말 초기화? 한 번 더", function()
		local id = heroOf()
		if id then UI.Try(H.ResetSkills(id)) end
	end)
	UI.Tip(p.reset, function() return UI.SimpleTip("기술 초기화", "첫 기술을 뺀 모든 기술 점수를 돌려받습니다. 골드가 듭니다.") end)
end

local function refreshSkills(page, id)
	local p = page.skills
	local h = ns.db.heroes[id]
	local list = H.SkillList(id)
	local free = H.SkillPointsFree(id)
	p.points:SetLabel(string.format("기술 점수 %d", free))
	p.points:SetColor(0.12, free > 0 and 0.45 or 0.15, free > 0 and 0.2 or 0.22, 1)
	p.auto:SetOff(free == 0)
	p.reset:SetBase("기술 초기화  " .. U.fmt(H.SkillResetCost(id)) .. " G")
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
			b.lockText:SetText("룬 필요")
		elseif sid then
			b:SetIconName(ns.SKILLS[sid].icon)
			b:SetLocked(false)
			b:SetQuality(5)
			b.lockText:SetText(ns.N(ns.SKILLS[sid].name))
		else
			b.icon:Hide()
			b:SetLocked(false)
			b:SetQuality(nil)
			b.lockText:SetText("비어 있음")
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
		row.icon:SetLocked(not open)
		row.name:SetText(open and ns.N(sk.name) or U.col("8a90a2", ns.N(sk.name)))
		local eq = H.IsSkillEquipped(id, sid)
		if not open then
			row.state:SetText(U.col("9a8f78", string.format("영웅 Lv %d에 열림", ns.SKILL_UNLOCK[i])))
		elseif pts == 0 then
			row.state:SetText(U.col("ffd24a", "배울 수 있음"))
		else
			row.state:SetText(string.format("Lv %d / %d  ·  %s", pts, ns.SKILL_MAX, ns.SkillTag(sid)))
		end
		row.eq:SetShown(eq ~= nil)
		if eq then row.eq:SetLabel(eq .. "번 칸") end
		row.dot:Set(open and free > 0 and pts == 0)
		if sid == page.skill then row.bg:SetColor(0.95, 0.8, 0.4, 1) else row.bg:SetColor(1, 1, 1, 1) end
	end

	local d = p.detail
	local sid = page.skill
	local sk = ns.SKILLS[sid]
	local pts = H.SkillPoints(id, sid)
	local lvl = max(1, H.SkillLevel(id, sid))
	d.icon:SetIconName(sk.icon)
	d.icon:SetDim(not H.SkillUnlocked(id, sid))
	d.name:SetText(U.col("ffd24a", ns.N(sk.name)))
	d.level:SetText(pts > 0 and string.format("레벨 %d / %d", pts, ns.SKILL_MAX) or U.col("8a90a2", "아직 배우지 않음"))
	d.act:SetText(ns.SkillTag(sid) .. "  ·  " .. ns.SkillActText(sid, lvl))
	d.nowTitle:SetText(pts > 0 and "지금" or "레벨 1")
	d.now:SetText(ns.SkillDesc(sid, lvl))
	if pts > 0 and pts < ns.SKILL_MAX then
		d.nextTitle:Show()
		d.next:SetText(U.col("60e070", ns.SkillDesc(sid, H.SkillLevel(id, sid) + 1)))
	else
		d.nextTitle:Hide()
		d.next:SetText(pts >= ns.SKILL_MAX and U.col("ffd24a", "최대 레벨입니다.") or "")
	end
	local ok, why = H.CanLearnSkill(id, sid)
	if ok then
		d.req:Hide()
	else
		d.req:SetLabel(why or "")
		d.req:Show()
	end
	d.learn:SetLabel(pts == 0 and "배우기 (1점)" or (pts >= ns.SKILL_MAX and "최대 레벨" or "강화 (1점)"))
	d.learn:SetOff(not ok)
	d.learn.onClick = function()
		if not ok then UI.Try(false, why) return end
		UI.Try(H.LearnSkill(id, sid))
	end
	local eq = H.IsSkillEquipped(id, sid)
	if eq then
		d.equip:SetLabel("해제")
		d.equip:SetStyle("dark")
		d.equip:SetOff(false)
		d.equip.onClick = function() H.UnequipSkill(id, sid) end
	else
		local full = #h.skills >= ns.SkillSlots()
		d.equip:SetLabel("장착")
		d.equip:SetStyle("blue")
		d.equip:SetOff(pts == 0 or full)
		d.equip.onClick = function()
			if pts == 0 then
				UI.Try(false, "먼저 기술을 배우세요.")
			elseif full then
				UI.Try(false, "기술 칸이 가득 찼습니다. 장착 칸의 기술을 골라 해제하거나, 룬으로 칸을 늘리세요.")
			else
				UI.Try(H.EquipSkill(id, sid))
			end
		end
	end
end

------------------------------------------------------------------------
-- 특성: the passive talent tree
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

local NODE_W = floor((CW - 56 - 8) / 2)

local function buildTree(page)
	local p = CreateFrame("Frame", nil, page)
	p:SetAllPoints(page)
	page.tree = p
	p.points = UI.Pill(p, 130, 28, 0.10, 0.30, 0.15, 1)
	p.points:SetPoint("TOPLEFT", p, "TOPLEFT", CX, -2)
	UI.Tip(p.points, function() return UI.SimpleTip("특성 점수", "레벨이 오를 때마다 1점씩 생깁니다. 능력치를 올리는 데만 쓰입니다(기술은 '기술' 메뉴).") end)
	p.help = UI.Text(p, 11, string.format("한 단계에 특성 점수를 %d점 쓸 때마다 다음 단계가 열립니다. 칸을 누르면 1점을 씁니다.", ns.TREE_TIER_POINTS))
	p.help:SetPoint("LEFT", p.points, "RIGHT", 12, 0)
	UI.Color(p.help, UI.C.sub)
	p.tiers = {}
	for t = 1, 8 do
		local y = -40 - (t - 1) * 46
		local tier = {}
		tier.label = UI.Text(p, 11)
		tier.label:SetPoint("TOPLEFT", p, "TOPLEFT", CX, y - 8)
		tier.label:SetWidth(52)
		tier.nodes = {}
		for n = 1, 2 do
			local b = CreateFrame("Button", nil, p)
			b:SetSize(NODE_W, 42)
			b:SetPoint("TOPLEFT", p, "TOPLEFT", CX + 56 + (n - 1) * (NODE_W + 8), y)
			b.bg = UI.Slice(b, "inset", "BACKGROUND")
			b.icon = UI.IconButton(b, 34)
			b.icon:EnableMouse(false)
			b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)
			b.name = UI.Text(b, 12)
			b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 46, -5)
			b.name:SetWidth(NODE_W - 110)
			b.name:SetWordWrap(false)
			b.val = UI.Text(b, 11)
			b.val:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 46, 5)
			b.val:SetWidth(NODE_W - 110)
			b.val:SetWordWrap(false)
			b.lv = UI.Text(b, 14)
			b.lv:SetPoint("RIGHT", b, "RIGHT", -10, 0)
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
	p.reset = UI.Button(p, 160, 38, "", nil, "red")
	p.reset:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -196, 0)
	armed(p.reset, "", "정말? 한 번 더", function()
		local id = heroOf()
		if id then UI.Try(H.ResetTree(id)) end
	end)
	UI.Tip(p.reset, function() return UI.SimpleTip("특성 초기화", "쓴 특성 점수를 모두 돌려받습니다. 골드가 듭니다.") end)
	p.auto = UI.Button(p, 188, 38, "자동 배분", function()
		local id = heroOf()
		if id then
			local n = H.AutoSpend(id)
			ns.Toast(n > 0 and string.format("특성 점수 %d점을 썼습니다.", n) or "쓸 수 있는 특성 점수가 없습니다.")
		end
	end, "primary")
	p.auto:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
end

local function refreshTree(page, id)
	local p = page.tree
	local tree = H.Tree(id)
	local free = H.PointsFree(id)
	p.points:SetLabel(string.format("특성 점수 %d", free))
	p.points:SetColor(0.12, free > 0 and 0.45 or 0.15, free > 0 and 0.2 or 0.22, 1)
	p.auto:SetOff(free == 0)
	p.reset:SetBase("초기화  " .. U.fmt(H.ResetCost(id)) .. " G")
	p.reset:SetOff(H.PointsSpent(id) == 0 or not ns.CanAfford(H.ResetCost(id)))
	local spent = H.PointsSpent(id)
	for t, tier in ipairs(p.tiers) do
		local open = H.TierOpen(id, t)
		local need = (t - 1) * ns.TREE_TIER_POINTS - spent
		tier.label:SetText(open and U.col("ffd24a", t .. "단계") or U.col("9a8f78", need .. "점 더"))
		for n, b in ipairs(tier.nodes) do
			local node = tree[t][n]
			local a = ns.AFFIX[node.p]
			local lvl = H.NodeLevel(id, t, n)
			b.icon:SetIconName(UI.STAT_ICON[node.p] or "INV_Misc_QuestionMark")
			b.icon:SetDim(not open)
			b.icon:SetLocked(not open)
			b.name:SetText(open and ns.N(a.n) or U.col("8a90a2", ns.N(a.n)))
			local num = "+" .. ns.Stats.FormatValue(node.p, node.v * max(1, lvl))
			b.val:SetText(lvl > 0 and U.col("60e070", num) or U.col("8a90a2", "점당 +" .. ns.Stats.FormatValue(node.p, node.v)))
			local col = lvl >= node.max and "ffd24a" or (lvl > 0 and "ffffff" or "8a90a2")
			b.lv:SetText(U.col(col, lvl .. "/" .. node.max))
			if lvl >= node.max then
				b.bg:SetColor(1, 0.85, 0.45, 1)
			elseif open and free > 0 then
				b.bg:SetColor(0.6, 1, 0.65, 1)
			else
				b.bg:SetColor(1, 1, 1, 1)
			end
		end
	end
end

------------------------------------------------------------------------
-- Screen: hero column, page menu, page
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
	-- hero portraits, party first
	page.strip = {}
	for i = 1, ns.ROSTER_MAX do
		local b = UI.Portrait(page, 36, function(self)
			if self.heroId then Main.SelectHero(self.heroId) end
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -(i - 1) * 39)
		b.lvl:Hide()
		UI.Tip(b, function(self)
			if not self.heroId or not ns.db.heroes[self.heroId] then return nil end
			local hh = ns.db.heroes[self.heroId]
			local lines = { { H.Name(self.heroId), "Lv " .. hh.level, 1, 0.82, 0.3 },
				{ ns.SpecLabel(hh.spec), H.PartySlot(self.heroId) and "출전" or "대기", 0.75, 0.8, 0.9 } }
			if ns.Guide.HeroNeeds(self.heroId) then lines[#lines + 1] = { "할 일이 있습니다 (점수 또는 더 좋은 장비)", nil, 0.4, 1, 0.4 } end
			return lines
		end, "RIGHT")
		page.strip[i] = b
	end
	local div = UI.Line(page, 1, 0.4, 0.45, 0.6, 0.3)
	div:SetSize(1, PAGE_H)
	div:SetPoint("TOPLEFT", page, "TOPLEFT", STRIP_W + 2, 0)

	-- page menu
	page.menu = {}
	for i, s in ipairs(SUBS) do
		local b = CreateFrame("Button", nil, page)
		b:SetSize(MENU_W, 46)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", MENU_X, -4 - (i - 1) * 50)
		b.mark = b:CreateTexture(nil, "ARTWORK")
		b.mark:SetSize(3, 30)
		b.mark:SetPoint("LEFT", b, "LEFT", 0, 0)
		UI.Fill(b.mark, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3], 1)
		b.glow = UI.Art(b, "grad_h", "BACKGROUND", 1, 0.8, 0.3, 0.18)
		b.glow:SetAllPoints(b)
		b.label = UI.Text(b, 16, s.name)
		b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -6)
		b.hint = UI.Text(b, 9, s.hint)
		b.hint:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -28)
		b.hint:SetWidth(MENU_W - 14)
		b.hint:SetWordWrap(false)
		UI.Color(b.hint, UI.C.dim)
		b.badge = UI.Badge(b, 14)
		b.badge:ClearAllPoints()
		b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -6)
		b.key = s.key
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.sub = self.key
			Main.Refresh()
		end)
		b.onEnter = function(self) self.hover = true Main.Refresh() end
		b.onLeave = function(self) self.hover = false Main.Refresh() end
		b:SetScript("OnEnter", function(self) self.onEnter(self) end)
		b:SetScript("OnLeave", function(self) self.onLeave(self) end)
		page.menu[i] = b
	end
	page.renameB = UI.Button(page, MENU_W, 28, "이름 바꾸기", function()
		local id = heroOf()
		if id then openRename(id) end
	end, "dark")
	page.renameB:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", MENU_X, 34)
	page.dismiss = UI.Button(page, MENU_W, 28, "떠나보내기", nil, "red")
	page.dismiss:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", MENU_X, 0)
	armed(page.dismiss, "떠나보내기", "정말요? 한 번 더", function()
		local id = heroOf()
		if id and UI.Try(H.Dismiss(id)) then
			Main.SelectHero(nil)
		end
	end)
	UI.Tip(page.dismiss, function() return UI.SimpleTip("떠나보내기", "영웅이 영영 떠납니다. 장착한 장비는 가방으로 돌아옵니다. 되돌릴 수 없습니다.") end)

	buildGear(page)
	buildSkills(page)
	buildTree(page)

	page.empty = UI.Text(page, 14, "영웅이 없습니다. '편성'에서 첫 영웅을 만드세요.")
	page.empty:SetPoint("CENTER", page, "CENTER", 0, 0)
end

local function refresh(page)
	local id = heroOf()
	local order = heroOrder()
	page.empty:SetShown(id == nil)
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
	for _, b in ipairs(page.menu) do b:SetShown(id ~= nil) end
	page.renameB:SetShown(id ~= nil)
	page.dismiss:SetShown(id ~= nil)
	if not id then
		page.gear:Hide()
		page.skills:Hide()
		page.tree:Hide()
		return
	end
	if page.heroShown ~= id then
		page.heroShown = id
		page.slot = nil
		page.skill = nil
	end
	page.dismiss:SetOff(H.Count() <= 1)
	local badges = {
		gear = ns.Guide.UpgradeHeroes()[id] and true or nil,
		skills = H.SkillPointsFree(id) > 0 and H.SkillPointsFree(id) or nil,
		tree = H.PointsFree(id) > 0 and H.PointsFree(id) or nil,
	}
	for _, b in ipairs(page.menu) do
		local on = b.key == page.sub
		b.mark:SetShown(on)
		b.glow:SetShown(on or b.hover)
		b.glow:SetAlpha(on and 1 or 0.5)
		if on then UI.Color(b.label, UI.C.gold) else UI.Color(b.label, UI.C.text) end
		b.badge:Set(badges[b.key])
	end
	page.gear:SetShown(page.sub == "gear")
	page.skills:SetShown(page.sub == "skills")
	page.tree:SetShown(page.sub == "tree")
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
	if page.skills then page.skills.reset:Disarm() end
	if page.tree then page.tree.reset:Disarm() end
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
