-- Hero screen: a strip with every hero, then one hero's card with three
-- sub-pages - gear (paper doll + stats), talents and skills.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes

local CARD_Y = -62
local CONTENT_Y = -118 -- inside the card

------------------------------------------------------------------------
-- Tooltips
------------------------------------------------------------------------
local function gearTip(self)
	local id = Main.SelectedHero()
	local h = id and ns.db.heroes[id]
	local it = h and h.gear[self.slot]
	if it then
		local lines = ns.Items.Tooltip(it, id)
		lines[#lines + 1] = { "클릭: 장비 해제", nil, 0.45, 0.8, 1 }
		return lines
	end
	return UI.SimpleTip(ns.N(ns.SLOT[self.slot].name), "비어 있음. '가방'에서 장비를 골라 착용하거나 '일괄 장착'을 누르세요.")
end

local function skillLines(id, sid)
	local sk = ns.SKILLS[sid]
	local pts = H.SkillPoints(id, sid)
	local eff = H.SkillLevel(id, sid)
	local lvl = max(1, eff)
	local lines = { { ns.N(sk.name), string.format("레벨 %d/%d", pts, ns.SKILL_MAX), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
	if eff > pts then
		lines[#lines + 1] = { string.format("장비 효과 포함 레벨 %d", eff), nil, 0.4, 1, 0.4 }
	end
	lines[#lines + 1] = { ns.SkillTag(sid) .. " · " .. ns.SkillActText(sid, lvl), nil, 0.6, 0.8, 1 }
	lines[#lines + 1] = { ns.SkillDesc(sid, lvl), nil, 1, 1, 1 }
	if pts > 0 and pts < ns.SKILL_MAX then
		lines[#lines + 1] = { "다음 레벨: " .. ns.SkillDesc(sid, eff + 1), nil, 0.6, 0.62, 0.7 }
	end
	return lines
end

local function nodeTip(self)
	local id = Main.SelectedHero()
	if not id then return nil end
	local node = H.Tree(id)[self.tier][self.n]
	if not node then return nil end
	local lvl = H.NodeLevel(id, self.tier, self.n)
	local lines
	if node.s then
		lines = skillLines(id, node.s)
		if lvl > 0 then
			lines[#lines + 1] = { H.IsSkillEquipped(id, node.s) and "장착 중 · 우클릭: 해제"
				or "우클릭: 기술 슬롯에 장착", nil, 0.45, 0.8, 1 }
		end
	else
		local a = ns.AFFIX[node.p]
		lines = { { ns.N(a.n) .. " 강화", string.format("레벨 %d/%d", lvl, node.max), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
		lines[#lines + 1] = { "레벨당 " .. ns.Stats.ModText(node.p, node.v), nil, 1, 1, 1 }
		if lvl > 0 then lines[#lines + 1] = { "현재 " .. ns.Stats.ModText(node.p, node.v * lvl), nil, 0.4, 1, 0.4 } end
	end
	if not H.TierOpen(id, self.tier) then
		lines[#lines + 1] = { string.format("기술 점수를 %d점 쓰면 열립니다.", (self.tier - 1) * ns.TREE_TIER_POINTS), nil, 1, 0.35, 0.3 }
	elseif lvl < node.max then
		lines[#lines + 1] = { "클릭: 기술 점수 1점 투자", nil, 0.45, 0.8, 1 }
	end
	return lines
end

------------------------------------------------------------------------
-- Sub-pages
------------------------------------------------------------------------
local SUBS = {
	{ key = "gear", name = "장비" },
	{ key = "tree", name = "특성" },
	{ key = "skills", name = "기술" },
}

local function buildGear(p)
	p.slots = {}
	for i, slot in ipairs(ns.SLOTS) do
		local col, row = (i <= 5) and 0 or 1, (i - 1) % 5
		local b = UI.IconButton(p, 50, function(self)
			local id = Main.SelectedHero()
			if id and ns.db.heroes[id].gear[self.slot] then UI.Try(ns.Items.Unequip(id, self.slot)) end
		end)
		b.slot = slot
		b:SetPoint("TOPLEFT", p, "TOPLEFT", col * 58, -row * 56)
		b.label = UI.Text(b, 9, ns.N(ns.SLOT[slot].name))
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label:SetJustifyH("CENTER")
		UI.Color(b.label, UI.C.dim)
		UI.Tip(b, gearTip)
		p.slots[i] = b
	end
	p.statsTitle = UI.Title(p, "능력치", 13)
	p.statsTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 140, 0)
	p.rows = {}
	for i = 1, 22 do
		local col, row = (i <= 11) and 0 or 1, (i - 1) % 11
		local box = CreateFrame("Frame", nil, p)
		box:SetSize(214, 21)
		box:SetPoint("TOPLEFT", p, "TOPLEFT", 140 + col * 224, -22 - row * 23)
		box.bg = box:CreateTexture(nil, "BACKGROUND")
		box.bg:SetAllPoints(box)
		UI.Fill(box.bg, 1, 1, 1, (row % 2 == 0) and 0.04 or 0.0)
		box.l = UI.Text(box, 11)
		box.l:SetPoint("LEFT", box, "LEFT", 6, 0)
		UI.Color(box.l, UI.C.sub)
		box.v = UI.Text(box, 11)
		box.v:SetPoint("RIGHT", box, "RIGHT", -6, 0)
		box.v:SetJustifyH("RIGHT")
		p.rows[i] = box
	end
	p.equip = UI.Button(p, 190, 36, "일괄 장착", function()
		local id = Main.SelectedHero()
		if id then
			local n = ns.Items.AutoEquip(id)
			ns.Fire("TOAST", string.format("장비 %d개를 바꿨습니다.", n))
		end
	end, "primary")
	p.equip:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -4)
	p.equipAll = UI.Button(p, 190, 30, "파티 전원 일괄 장착", function()
		local n = 0
		for i = 1, ns.PARTY_SIZE do
			local id = ns.db.party[i]
			if id then n = n + ns.Items.AutoEquip(id) end
		end
		ns.Fire("TOAST", string.format("장비 %d개를 바꿨습니다.", n))
	end, "blue")
	p.equipAll:SetPoint("TOPRIGHT", p.equip, "BOTTOMRIGHT", 0, -8)
	p.toBag = UI.Button(p, 190, 30, "가방 열기", function() Main.ShowTab("bag") end, "dark")
	p.toBag:SetPoint("TOPRIGHT", p.equipAll, "BOTTOMRIGHT", 0, -8)
	p.upgrades = UI.Text(p, 11)
	p.upgrades:SetPoint("TOPRIGHT", p.toBag, "BOTTOMRIGHT", 0, -12)
	p.upgrades:SetWidth(190)
	p.upgrades:SetJustifyH("RIGHT")
	p.note = UI.Text(p, 10, "가방에서 + 표시가 붙은 장비는 이 영웅에게 더 좋은 장비입니다.")
	p.note:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 4)
	p.note:SetWidth(190)
	p.note:SetJustifyH("RIGHT")
	UI.Color(p.note, UI.C.dim)
end

local function refreshGear(p, id)
	local h = ns.db.heroes[id]
	-- compare every bag item once
	local better, ups = {}, 0
	for _, bi in ipairs(ns.db.bag) do
		if not bi.lock then
			local r = ns.Items.Compare(id, bi)
			if r and r > 1.01 then
				better[bi.s] = true
				ups = ups + 1
			end
		end
	end
	for _, b in ipairs(p.slots) do
		local it = h.gear[b.slot]
		if it then
			b:SetIconName(ns.Items.Icon(it))
			b:SetQuality(it.q)
			b:SetCount(tostring(it.l))
			b.label:Hide()
		else
			b:Clear()
			b.label:Show()
		end
		b:SetBadge(better[b.slot]) -- a better item for this slot is waiting in the bags
	end
	local sheet = ns.Stats.Sheet(id)
	for i, r in ipairs(p.rows) do
		local e = sheet[i]
		if e then
			r.l:SetText(e[1])
			r.v:SetText(e[2])
			r:Show()
		else
			r:Hide()
		end
	end
	p.upgrades:SetText(ups > 0 and U.col("6af07a", string.format("가방에 더 좋은 장비 %d개", ups)) or "")
	p.equip:SetBadge(ups > 0 and ups or nil)
end

local function buildTree(p)
	p.tiers = {}
	for t = 1, 8 do
		local y = -(t - 1) * 35
		local row = { nodes = {} }
		row.label = UI.Text(p, 11)
		row.label:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y - 9)
		row.label:SetWidth(56)
		for n = 1, 4 do
			local b = UI.IconButton(p, 31, function(self, button)
				local id = Main.SelectedHero()
				if not id then return end
				local node = H.Tree(id)[self.tier][self.n]
				if not node then return end
				if button == "RightButton" then
					if node.s then
						if H.IsSkillEquipped(id, node.s) then
							H.UnequipSkill(id, node.s)
						else
							UI.Try(H.EquipSkill(id, node.s))
						end
					end
				else
					UI.Try(H.SpendPoint(id, self.tier, self.n))
				end
				Main.Refresh()
			end)
			b.tier, b.n = t, n
			b:SetPoint("TOPLEFT", p, "TOPLEFT", 60 + (n - 1) * 138, y)
			UI.Tip(b, nodeTip)
			b.text = UI.Text(p, 10)
			b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
			b.text:SetWidth(98)
			row.nodes[n] = b
		end
		p.tiers[t] = row
	end
	p.side = UI.Panel(p, 200, 270, "inset")
	p.side:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
	p.ptsLabel = UI.Text(p.side, 11, "남은 기술 점수")
	p.ptsLabel:SetPoint("TOP", p.side, "TOP", 0, -14)
	p.ptsLabel:SetJustifyH("CENTER")
	UI.Color(p.ptsLabel, UI.C.sub)
	p.pts = UI.Text(p.side, 34)
	p.pts:SetPoint("TOP", p.ptsLabel, "BOTTOM", 0, -4)
	p.pts:SetJustifyH("CENTER")
	p.auto = UI.Button(p.side, 176, 32, "자동 배분", function()
		local id = Main.SelectedHero()
		if id then
			H.AutoSpend(id)
			Main.Refresh()
		end
	end, "primary")
	p.auto:SetPoint("TOP", p.pts, "BOTTOM", 0, -10)
	p.reset = UI.Button(p.side, 176, 28, "", function()
		local id = Main.SelectedHero()
		if id then UI.Try(H.ResetTree(id)) end
	end, "dark")
	p.reset:SetPoint("TOP", p.auto, "BOTTOM", 0, -8)
	p.help = UI.Text(p.side, 10, "레벨마다 1점을 얻습니다. 10점을 쓸 때마다 다음 단계가 열립니다. 기술 아이콘을 배우면 '기술' 탭에서 장착할 수 있습니다.")
	p.help:SetPoint("TOPLEFT", p.side, "TOPLEFT", 12, -192)
	p.help:SetWidth(176)
	p.help:SetJustifyV("TOP")
	UI.Color(p.help, UI.C.sub)
end

local function refreshTree(p, id)
	local tree = H.Tree(id)
	local free = H.PointsFree(id)
	p.pts:SetText(tostring(free))
	if free > 0 then p.pts:SetTextColor(0.4, 1, 0.45) else p.pts:SetTextColor(0.6, 0.64, 0.72) end
	p.auto:SetOff(free == 0)
	p.auto:SetBadge(free > 0 and free or nil)
	p.reset:SetLabel("초기화 " .. U.fmt(H.ResetCost(id)) .. " G")
	p.reset:SetOff(H.PointsSpent(id) == 0 or not ns.CanAfford(H.ResetCost(id)))
	for t, row in ipairs(p.tiers) do
		local open = H.TierOpen(id, t)
		if open then
			row.label:SetText(string.format("%d단계", t))
			UI.Color(row.label, UI.C.gold)
		else
			row.label:SetText(string.format("%d단계\n%d점", t, (t - 1) * ns.TREE_TIER_POINTS))
			UI.Color(row.label, UI.C.dim)
		end
		for n, b in ipairs(row.nodes) do
			local node = tree[t][n]
			if node then
				local lvl = H.NodeLevel(id, t, n)
				local label
				if node.s then
					b:SetIconName(ns.SKILLS[node.s].icon)
					label = ns.N(ns.SKILLS[node.s].name)
					local eq = H.IsSkillEquipped(id, node.s)
					if eq then b:SetBorderRGB(1, 0.82, 0.3) elseif lvl > 0 then b:SetBorderRGB(0.4, 0.7, 1) else b:SetQuality(nil) end
					b:SetMark(eq and "E" or "", 1, 0.85, 0.3)
				else
					b:SetIconName(UI.STAT_ICON[node.p] or "INV_Misc_Book_09")
					label = ns.N(ns.AFFIX[node.p].n)
					if lvl >= node.max then b:SetBorderRGB(0.35, 0.95, 0.45) elseif lvl > 0 then b:SetBorderRGB(0.4, 0.7, 1) else b:SetQuality(nil) end
					b:SetMark("")
				end
				b:SetDim(not open or lvl == 0)
				b:SetLocked(not open)
				b:SetBadge(open and free > 0 and lvl < node.max and node.s and lvl == 0)
				local color = (lvl >= node.max) and "6af07a" or (lvl > 0 and "ffffff" or "8a90a2")
				b.text:SetText(U.col(color, lvl .. "/" .. node.max) .. "  " .. U.col(node.s and "ffd24a" or "aab3c8", label))
				b:Show()
				b.text:Show()
			else
				b:Hide()
				b.text:Hide()
			end
		end
	end
end

local function buildSkills(p)
	p.slotTitle = UI.Title(p, "장착 슬롯", 13)
	p.slotTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
	p.load = {}
	for i = 1, 3 do
		local b = UI.IconButton(p, 56, function(self)
			local id = Main.SelectedHero()
			if id and self.skill then H.UnequipSkill(id, self.skill) end
		end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -22 - (i - 1) * 74)
		b.name = UI.Text(p, 11)
		b.name:SetPoint("LEFT", b, "RIGHT", 8, 6)
		b.name:SetWidth(100)
		b.sub = UI.Text(p, 9)
		b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
		b.sub:SetWidth(100)
		UI.Color(b.sub, UI.C.sub)
		UI.Tip(b, function(self)
			local id = Main.SelectedHero()
			if self.skill and id then
				local lines = skillLines(id, self.skill)
				lines[#lines + 1] = { "클릭: 해제", nil, 0.45, 0.8, 1 }
				return lines
			elseif self.locked then
				return UI.SimpleTip("잠긴 기술 슬롯", "'각성의 룬'을 배우면 열립니다.")
			end
			return UI.SimpleTip("빈 기술 슬롯", "오른쪽 목록에서 '장착'을 누르세요.")
		end)
		p.load[i] = b
	end
	p.cards = {}
	for i = 1, 6 do
		local col, row = (i - 1) % 2, floor((i - 1) / 2)
		local c = CreateFrame("Frame", nil, p)
		c:SetSize(318, 86)
		c:SetPoint("TOPLEFT", p, "TOPLEFT", 186 + col * 326, -row * 92)
		c.bg = UI.Slice(c, "card", "BACKGROUND")
		c.icon = UI.IconButton(c, 44)
		c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -8)
		UI.Tip(c.icon, function()
			local id = Main.SelectedHero()
			if id and c.skill then return skillLines(id, c.skill) end
		end)
		c.name = UI.Text(c, 13)
		c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 60, -8)
		c.name:SetWidth(170)
		c.name:SetWordWrap(false)
		c.tag = UI.Pill(c, 44, 16, 0.25, 0.3, 0.45, 1)
		c.tag:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -8)
		c.act = UI.Text(c, 10)
		c.act:SetPoint("TOPLEFT", c, "TOPLEFT", 60, -26)
		UI.Color(c.act, UI.C.blue)
		c.desc = UI.Text(c, 10)
		c.desc:SetPoint("TOPLEFT", c, "TOPLEFT", 60, -40)
		c.desc:SetWidth(170)
		c.desc:SetJustifyV("TOP")
		c.desc:SetMaxLines(3)
		UI.Color(c.desc, UI.C.text)
		c.btn = UI.Button(c, 72, 26, "", nil, "green")
		c.btn:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 8)
		p.cards[i] = c
	end
end

local function refreshSkills(p, id)
	local sp = H.Spec(id)
	local slots = ns.SkillSlots()
	local active = H.ActiveSkills(id)
	for i, b in ipairs(p.load) do
		local sid = active[i]
		b.skill = sid
		b.locked = i > slots
		if sid then
			b:SetIconName(ns.SKILLS[sid].icon)
			b:SetBorderRGB(1, 0.82, 0.3)
			b:SetLocked(false)
			b.name:SetText(ns.N(ns.SKILLS[sid].name))
			b.sub:SetText("Lv " .. H.SkillLevel(id, sid) .. " · " .. ns.SkillTag(sid))
		else
			b:Clear()
			b:SetLocked(b.locked)
			b.name:SetText(b.locked and U.col("8a8070", "잠김") or U.col("8a90a2", "비어 있음"))
			b.sub:SetText(b.locked and "각성의 룬 필요" or "")
		end
	end
	local full = #active >= slots
	for i, c in ipairs(p.cards) do
		local sid = sp.skills[i]
		c.skill = sid
		local sk = ns.SKILLS[sid]
		local pts = H.SkillPoints(id, sid)
		local lvl = max(1, H.SkillLevel(id, sid))
		c.icon:SetIconName(sk.icon)
		c.icon:SetDim(pts == 0)
		c.name:SetText(ns.N(sk.name) .. "  " .. U.col(pts > 0 and "ffd24a" or "8a90a2", "Lv " .. pts))
		c.tag:SetLabel(ns.SkillTag(sid))
		c.act:SetText(ns.SkillActText(sid, lvl))
		c.desc:SetText(ns.SkillDesc(sid, lvl))
		local eq = H.IsSkillEquipped(id, sid)
		if pts == 0 then
			c.icon:SetBorderRGB(0.3, 0.33, 0.42)
			c.btn:SetLabel("배우기")
			c.btn:SetStyle("blue")
			c.btn:SetOff(false)
			c.btn.onClick = function() Main.ShowTab("hero", { sub = "tree" }) end
			c.bg:SetColor(0.75, 0.75, 0.8, 1)
		elseif eq then
			c.icon:SetBorderRGB(1, 0.82, 0.3)
			c.btn:SetLabel("해제")
			c.btn:SetStyle("dark")
			c.btn:SetOff(false)
			c.btn.onClick = function() H.UnequipSkill(id, sid) end
			c.bg:SetColor(1.15, 1.1, 0.95, 1)
		else
			c.icon:SetBorderRGB(0.4, 0.7, 1)
			c.btn:SetLabel("장착")
			c.btn:SetStyle("green")
			c.btn:SetOff(full)
			c.btn.onClick = function() UI.Try(H.EquipSkill(id, sid)) end
			c.bg:SetColor(1, 1, 1, 1)
		end
	end
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.sub = "gear"

	page.strip = {}
	for i = 1, ns.ROSTER_MAX do
		local b = UI.Portrait(page, 44, function(self)
			if self.heroId then
				Main.SelectHero(self.heroId)
				Main.Refresh()
			end
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", 6 + (i - 1) * 58, -6)
		UI.Tip(b, function(self)
			if not self.heroId then return nil end
			local h = ns.db.heroes[self.heroId]
			return { { H.Name(self.heroId), "Lv " .. h.level, U.rgb(ns.CLASSES[H.Spec(self.heroId).class].hex) },
				{ ns.SpecLabel(h.spec), H.PartySlot(self.heroId) and "출전" or "대기", 0.75, 0.8, 0.9 } }
		end, "TOP")
		page.strip[i] = b
	end

	local card = UI.Panel(page, Main.PAGE_W, Main.PAGE_H + CARD_Y, "card")
	card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, CARD_Y)
	page.card = card
	card.portrait = UI.Portrait(card, 62)
	card.portrait:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
	card.name = UI.Text(card, 20)
	card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 90, -12)
	card.specIcon = card:CreateTexture(nil, "ARTWORK")
	card.specIcon:SetSize(16, 16)
	card.specIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 90, -38)
	card.spec = UI.Text(card, 12)
	card.spec:SetPoint("LEFT", card.specIcon, "RIGHT", 5, 0)
	card.role = UI.Pill(card, 64, 18, 0.3, 0.3, 0.3, 1)
	card.role:SetPoint("LEFT", card.spec, "RIGHT", 8, 0)
	card.xp = UI.Bar(card, 250, 12, 0.55, 0.35, 0.95)
	card.xp:SetPoint("TOPLEFT", card, "TOPLEFT", 90, -60)
	card.lv = UI.Text(card, 11)
	card.lv:SetPoint("LEFT", card.xp, "RIGHT", 8, 0)
	card.powerLabel = UI.Text(card, 11, "전투력")
	card.powerLabel:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -12)
	card.powerLabel:SetJustifyH("RIGHT")
	UI.Color(card.powerLabel, UI.C.sub)
	card.power = UI.Text(card, 26)
	card.power:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -26)
	card.power:SetJustifyH("RIGHT")
	UI.Color(card.power, UI.C.gold)
	card.field = UI.Button(card, 92, 26, "", nil, "green")
	card.field:SetPoint("TOPRIGHT", card, "TOPRIGHT", -200, -14)
	card.rename = UI.Button(card, 92, 26, "이름 변경", function()
		local id = Main.SelectedHero()
		if id then H.RerollName(id) end
	end, "dark")
	card.rename:SetGlyph("auto")
	card.rename:SetPoint("TOP", card.field, "BOTTOM", 0, -6)
	UI.Tip(card.rename, function() return UI.SimpleTip("이름 변경", "새 이름을 무작위로 뽑습니다 (무료).") end, "TOP")
	card.dismiss = UI.Button(card, 92, 26, "", function()
		local id = Main.SelectedHero()
		if not id then return end
		if (page.dismissArm or 0) > 0 and page.dismissId == id then
			page.dismissArm = 0
			if UI.Try(H.Dismiss(id)) then
				Main.SelectHero(nil)
				ns.Fire("TOAST", "영웅이 떠났습니다. 장비는 가방으로 돌아왔습니다.")
			end
		else
			page.dismissArm, page.dismissId = 4, id
		end
		Main.Refresh()
	end, "red")
	card.dismiss:SetPoint("RIGHT", card.field, "LEFT", -6, 0)
	UI.Tip(card.dismiss, function()
		return UI.SimpleTip("떠나보내기", "영웅을 명단에서 내보냅니다. 착용한 장비는 가방으로 돌아옵니다. 두 번 눌러야 합니다.")
	end, "TOP")

	card.chips = {}
	for i, s in ipairs(SUBS) do
		local c = UI.Chip(card, 110, 28, ns.N(s.name), function()
			page.sub = s.key
			Main.Refresh()
		end)
		c.key = s.key
		c:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (i - 1) * 118, -84)
		card.chips[i] = c
	end

	card.pages = {}
	local builders = { gear = buildGear, tree = buildTree, skills = buildSkills }
	for _, s in ipairs(SUBS) do
		local p = CreateFrame("Frame", nil, card)
		p:SetPoint("TOPLEFT", card, "TOPLEFT", 14, CONTENT_Y)
		p:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 10)
		p:SetSize(Main.PAGE_W - 28, Main.PAGE_H + CARD_Y + CONTENT_Y - 10)
		builders[s.key](p)
		card.pages[s.key] = p
	end

	page.empty = UI.Text(page, 14, "아직 영웅이 없습니다. '편성'에서 첫 영웅을 만드세요.")
	page.empty:SetPoint("CENTER", page, "CENTER", 0, 0)
	page.emptyBtn = UI.Button(page, 200, 34, "영웅 만들기", function()
		Main.ShowTab("party", { create = true })
	end, "primary")
	page.emptyBtn:SetPoint("TOP", page.empty, "BOTTOM", 0, -14)
end

local function refresh(page)
	local id = Main.SelectedHero()
	page.card:SetShown(id ~= nil)
	page.empty:SetShown(id == nil)
	page.emptyBtn:SetShown(id == nil)

	-- strip: party first, then the bench
	local order = {}
	for i = 1, ns.PARTY_SIZE do
		if ns.db.party[i] then order[#order + 1] = ns.db.party[i] end
	end
	for _, hid in ipairs(H.List()) do
		if not H.PartySlot(hid) then order[#order + 1] = hid end
	end
	for i, b in ipairs(page.strip) do
		local hid = order[i]
		if hid then
			b:SetHero(hid)
			b:SetSelected(hid == id)
			b:SetDim(not H.PartySlot(hid))
			b:SetBadge(H.PointsFree(hid) > 0 and H.PartySlot(hid) ~= nil)
			b:Show()
		else
			b:Hide()
		end
	end
	if not id then return end

	local card = page.card
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local cls = ns.CLASSES[sp.class]
	local role = ns.ROLE[sp.role]
	card.portrait:SetHero(id)
	card.name:SetText(U.col(cls.hex, H.Name(id)))
	UI.SetIcon(card.specIcon, sp.icon)
	card.spec:SetText(ns.SpecLabel(h.spec))
	card.role:SetColor(U.rgb(role.hex))
	card.role:SetLabel(ns.N(role.name))
	if h.level >= ns.HERO_MAX_LEVEL then
		card.xp:SetValue(1)
		card.xp:SetLabel("최대 레벨")
	else
		local need = ns.XPForLevel(h.level)
		card.xp:SetValue(h.xp / need)
		card.xp:SetLabel(U.fmt(h.xp) .. " / " .. U.fmt(need))
	end
	card.lv:SetText(string.format("레벨 %d", h.level))
	card.power:SetText(U.fmt(ns.Stats.Power(id)))
	if H.PartySlot(id) then
		card.field:SetLabel("휴식")
		card.field:SetStyle("dark")
		card.field:SetOff(H.PartyCount() <= 1)
		card.field.onClick = function() UI.Try(H.Withdraw(id)) end
	else
		card.field:SetLabel("출전")
		card.field:SetStyle("green")
		card.field:SetOff(false)
		card.field.onClick = function()
			if not H.FreeSlot(sp.role) then
				UI.Try(false, "같은 역할 자리가 차 있습니다. '편성'에서 교체하세요.")
			else
				UI.Try(H.Deploy(id))
			end
		end
	end

	if (page.dismissArm or 0) > 0 and page.dismissId == id then
		card.dismiss:SetLabel("정말요?")
	else
		card.dismiss:SetLabel("떠나보내기")
	end
	card.dismiss:SetOff(H.Count() <= 1)
	for _, c in ipairs(card.chips) do
		c:SetOn(c.key == page.sub)
		if c.key == "tree" then c:SetBadge(H.PointsFree(id) > 0 and H.PointsFree(id) or nil) end
	end
	for key, p in pairs(card.pages) do p:SetShown(key == page.sub) end
	if page.sub == "gear" then
		refreshGear(card.pages.gear, id)
	elseif page.sub == "tree" then
		refreshTree(card.pages.tree, id)
	else
		refreshSkills(card.pages.skills, id)
	end
end

local function tick(page)
	if (page.dismissArm or 0) > 0 then
		page.dismissArm = page.dismissArm - 0.2
		if page.dismissArm <= 0 then Main.Refresh() end
	end
end

local function open(page, opts)
	page.dismissArm = 0
	if opts and opts.sub then page.sub = opts.sub end
	if opts and opts.hero then Main.SelectHero(opts.hero) end
end

Main.RegisterTab({
	key = "hero", title = "영웅", sub = "장비와 특성, 기술을 관리합니다",
	icon = "INV_Helmet_06", build = build, refresh = refresh, open = open, tick = tick,
	events = { "HEROES", "LEVEL", "TREE", "SKILLS", "GEAR", "STATS", "RUNES", "RESET", "PARTY", "BAG" },
})
