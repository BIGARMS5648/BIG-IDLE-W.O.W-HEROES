-- Hero screen (영웅).
--   left: every hero as a card (party first; the mouse wheel scrolls), and
--         [영웅 모집하기] at the bottom;
--   right: the chosen hero: a header card (portrait, name, level and
--          experience, 전투력, 이름 바꾸기 · 출전/휴식 · 떠나보내기) and three
--          tabs: 능력치·전문화, 기술, 특성.
-- Skills and talents act on click: 기술 click = 장착/해제, right-click =
-- 배우기/강화; 특성 click = 1점, right-click = 최대까지.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes
local K = UI.K

local LEFT_W, RIGHT_X, RIGHT_W = 270, 280, 640
local CARD_W, CARD_H, CARD_STEP, LIST_Y, VISIBLE = 246, 56, 62, -36, 7
local NAME_W = CARD_W - 62 - 10 -- the name line of a hero card
local BODY_X, BODY_Y, BODY_W, BODY_H = 12, -172, 616, 366
-- which rune opens each skill slot (slot 1 is always open)
-- the rune that opens a locked skill slot
local function slotRune()
	for id, node in pairs(ns.Runes.byId) do if node.stat == "skillSlot" then return id end end
end

local function heroOf() return Main.SelectedHero() end
local function roleHex(id) return ns.ROLE[H.Role(id)].hex end

local function skillLines(id, sid)
	local sk = ns.SKILLS[sid]
	local pts = H.SkillPoints(id, sid)
	local lvl = max(1, H.SkillLevel(id, sid))
	local lines = { { ns.N(sk.name), string.format("레벨 %d / %d", pts, ns.SKILL_MAX), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
	lines[#lines + 1] = { ns.SkillTag(sid) .. " · " .. ns.SkillActText(sid, lvl), nil, 0.6, 0.8, 1 }
	lines[#lines + 1] = { (pts > 0 and "지금: " or "배우면: ") .. ns.SkillDesc(sid, lvl), nil, 1, 1, 1 }
	if pts > 0 and pts < ns.SKILL_MAX then
		lines[#lines + 1] = { "다음 단계: " .. ns.SkillDesc(sid, H.SkillLevel(id, sid) + 1), nil, 0.4, 1, 0.4 }
	end
	local ok, why = H.CanLearnSkill(id, sid)
	if not ok and why and pts < ns.SKILL_MAX then lines[#lines + 1] = { why, nil, 1, 0.55, 0.45 } end
	lines[#lines + 1] = { "클릭: 장착·해제 · 오른쪽 클릭: " .. (pts == 0 and "배우기" or "강화") .. " (기술 점수 1점)", nil, 0.45, 0.8, 1 }
	return lines
end

------------------------------------------------------------------------
-- Left: the heroes
------------------------------------------------------------------------
local function buildList(page)
	local list = UI.Panel(page, LEFT_W, K.H, "inset")
	list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.list = list
	page.listHead = UI.Text(list, 13)
	page.listHead:SetPoint("TOPLEFT", list, "TOPLEFT", 14, -12)
	page.cards = {}
	for i = 1, VISIBLE do
		local c = CreateFrame("Button", nil, list)
		c:SetSize(CARD_W, CARD_H)
		c:SetPoint("TOPLEFT", list, "TOPLEFT", 12, LIST_Y - (i - 1) * CARD_STEP)
		c.isItem = true
		c.bg = UI.Slice(c, "card", "BACKGROUND")
		c.sel = UI.SelFrame(c)
		c.stripe = c:CreateTexture(nil, "BORDER")
		c.stripe:SetSize(4, CARD_H - 12)
		c.stripe:SetPoint("LEFT", c, "LEFT", 5, 0)
		c.portrait = UI.Portrait(c, 40)
		c.portrait:SetPoint("LEFT", c, "LEFT", 14, 0)
		c.portrait:EnableMouse(false)
		c.portrait.lvl:Hide()
		-- the full name gets the whole first line; 출전 n / 대기 sits on the second
		c.name = UI.Text(c, 13)
		c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 62, -8)
		c.name:SetWidth(NAME_W)
		c.name:SetWordWrap(false)
		-- second line: level · specialization ... role icon, 출전 n / 대기
		c.slot = UI.Text(c, 11)
		c.slot:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -27)
		c.slot:SetWidth(36)
		c.slot:SetJustifyH("RIGHT")
		c.info = UI.Text(c, 11)
		c.info:SetPoint("TOPLEFT", c, "TOPLEFT", 62, -27)
		c.info:SetWidth(NAME_W - 60)
		c.info:SetWordWrap(false)
		UI.Color(c.info, UI.C.sub)
		c.xp = UI.Bar(c, 150, 4, 0.55, 0.40, 1)
		c.xp:SetPoint("TOPLEFT", c, "TOPLEFT", 62, -44)
		c.xp.text:Hide()
		c.badge = UI.Badge(c, 14)
		c.badge:ClearAllPoints()
		c.badge:SetPoint("TOPRIGHT", c.portrait, "TOPRIGHT", 3, 3) -- clear of "출전 n"
		c:RegisterForClicks("LeftButtonUp")
		c:SetScript("OnClick", function(self)
			if not self.heroId then return end
			ns.Sound("click")
			Main.SelectHero(self.heroId)
			Main.Refresh()
		end)
		UI.Tip(c, function(self) return self.heroId and ns.HeroTip and ns.HeroTip(self.heroId) or nil end)
		page.cards[i] = c
	end
	-- the scroll bar (when there are more heroes than cards)
	page.track = list:CreateTexture(nil, "BORDER")
	page.track:SetPoint("TOPLEFT", list, "TOPLEFT", LEFT_W - 8, LIST_Y)
	page.track:SetSize(3, VISIBLE * CARD_STEP - 6)
	UI.Fill(page.track, 1, 1, 1, 0.08)
	page.thumb = list:CreateTexture(nil, "ARTWORK")
	page.thumb:SetWidth(3)
	UI.Fill(page.thumb, 0.42, 0.70, 1, 0.7)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		local n = #UI.HeroOrder()
		page.offset = U.clamp((page.offset or 0) - delta, 0, max(0, n - VISIBLE))
		Main.Refresh()
	end)
	-- a new hero
	page.create = UI.Button(list, CARD_W, 56, "영웅 모집하기", function()
		if page.createWhy then UI.Try(false, page.createWhy) return end
		if ns.OpenCreate then ns.OpenCreate() end
	end, "primary")
	page.create:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 12, 12)
	page.create.clickWhenOff = true
	page.create.label:ClearAllPoints()
	page.create.label:SetPoint("CENTER", page.create, "CENTER", 0, 8)
	page.create.cost = UI.Text(page.create, 11)
	page.create.cost:SetPoint("CENTER", page.create, "CENTER", 0, -11)
	UI.Tip(page.create, function() return UI.SimpleTip("영웅 모집하기", "직업과 전문화, 이름을 정해 새 영웅을 모집합니다. 영웅이 많을수록 비용이 오릅니다.") end, "TOP")
end

local function refreshList(page)
	local db = ns.db
	local order = UI.HeroOrder()
	local sel = heroOf()
	page.listHead:SetText(U.col("ffd24a", "영웅") .. "  " .. U.col("8a90a2", string.format("%d / %d", #order, ns.ROSTER_MAX)))
	-- keep the chosen hero in view
	local n = #order
	page.offset = U.clamp(page.offset or 0, 0, max(0, n - VISIBLE))
	if page.followSel ~= sel then
		page.followSel = sel
		for i, id in ipairs(order) do
			if id == sel then
				if i <= page.offset then page.offset = i - 1 end
				if i > page.offset + VISIBLE then page.offset = i - VISIBLE end
			end
		end
	end
	for i, c in ipairs(page.cards) do
		local id = order[i + page.offset]
		c.heroId = id
		if id and db.heroes[id] then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			UI.Fill(c.stripe, U.rgb(roleHex(id)))
			c.portrait:SetHero(id)
			UI.SetHeroIcon(c.portrait.icon, id)
			c.portrait.lvl:Hide()
			-- the full name; a very long one steps down a size rather than being cut
			c.name:SetFont(ns.FONT, 13, "")
			c.name:SetText(U.col(id == sel and "ffb84a" or "ffd27a", H.Name(id)))
			if c.name:GetStringWidth() > NAME_W then c.name:SetFont(ns.FONT, 12, "") end
			local slot = H.PartySlot(id)
			c.slot:SetText(slot and U.col("ffd24a", "출전 " .. slot) or U.col("8a90a2", "대기"))
			c.info:SetText(string.format("Lv %d · %s", h.level, ns.SpecLabel(h.spec)))
			if h.level >= ns.HERO_MAX_LEVEL then c.xp:SetValue(1) else c.xp:SetValue(h.xp / ns.XPForLevel(h.level)) end
			c.sel:SetShown(id == sel)
			c.badge:Set(slot ~= nil and ns.Guide.HeroNeeds(id))
			c:Show()
		else
			c:Hide()
		end
	end
	local scroll = n > VISIBLE
	page.track:SetShown(scroll)
	page.thumb:SetShown(scroll)
	if scroll then
		local th = (VISIBLE * CARD_STEP - 6) * VISIBLE / n
		page.thumb:SetHeight(th)
		page.thumb:ClearAllPoints()
		page.thumb:SetPoint("TOPLEFT", page.track, "TOPLEFT", 0, -((VISIBLE * CARD_STEP - 6 - th) * page.offset / (n - VISIBLE)))
	end
	local cost = H.CreateCost()
	local full = n >= ns.ROSTER_MAX
	page.createWhy = full and string.format("영웅은 %d명까지 둘 수 있습니다.", ns.ROSTER_MAX)
		or (not ns.CanAfford(cost) and "골드가 부족합니다." or nil)
	page.create:SetOff(page.createWhy ~= nil)
	page.create.cost:SetText(full and "가득 참" or (cost > 0 and (U.fmt(cost) .. " 골드") or "무료"))
	page.create:SetBadge(page.createWhy == nil and ns.Guide.MissingRole() ~= nil)
end

------------------------------------------------------------------------
-- Right: the header card
------------------------------------------------------------------------
local function buildHeader(page, rp)
	local hc = UI.Panel(rp, RIGHT_W - 24, 104, "card")
	hc:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -12)
	page.head = hc
	hc.portrait = UI.Portrait(hc, 76)
	hc.portrait:SetPoint("TOPLEFT", hc, "TOPLEFT", 14, -14)
	hc.portrait:EnableMouse(false)
	hc.portrait.lvl:Hide()
	hc.name = UI.Text(hc, 18)
	hc.name:SetPoint("TOPLEFT", hc, "TOPLEFT", 104, -14)
	hc.name:SetWidth(330)
	hc.name:SetWordWrap(false)
	hc.info = UI.Text(hc, 11)
	hc.info:SetPoint("TOPLEFT", hc, "TOPLEFT", 104, -42)
	hc.info:SetWidth(310)
	hc.info:SetWordWrap(false)
	UI.Color(hc.info, UI.C.sub)
	hc.xp = UI.Bar(hc, 200, 16, 0.55, 0.40, 1)
	hc.xp:SetPoint("TOPLEFT", hc, "TOPLEFT", 104, -66)
	hc.power = UI.Title(hc, "", 24)
	hc.power:SetPoint("TOPRIGHT", hc, "TOPRIGHT", -16, -12)
	hc.power:SetJustifyH("RIGHT")
	UI.Color(hc.power, UI.C.gold)
	hc.powerLabel = UI.Text(hc, 11, "전투력")
	hc.powerLabel:SetPoint("BOTTOMRIGHT", hc.power, "BOTTOMLEFT", -8, 4)
	UI.Color(hc.powerLabel, UI.C.sub)
	hc.dismiss = UI.Button(hc, 86, 28, "떠나보내기", function()
		local id = heroOf()
		if not id then return end
		if H.Count() <= 1 then UI.Try(false, "마지막 영웅은 떠나보낼 수 없습니다.") return end
		UI.Confirm({ title = "영웅 떠나보내기", ok = "떠나보내기", style = "red",
			text = string.format("%s을(를) 떠나보내시겠습니까?\n장착한 장비는 가방으로 돌아오지만, 영웅은 되돌릴 수 없습니다.", H.Name(id)),
			onOk = function()
				if UI.Try(H.Dismiss(id)) then Main.SelectHero(nil) end
			end })
	end, "red")
	hc.dismiss:SetPoint("BOTTOMRIGHT", hc, "BOTTOMRIGHT", -14, 14)
	hc.dismiss.clickWhenOff = true
	hc.field = UI.Button(hc, 86, 28, "", function()
		local id = heroOf()
		if not id then return end
		if H.PartySlot(id) then
			if H.PartyCount() <= 1 then UI.Try(false, "마지막 출전 영웅은 쉬게 할 수 없습니다.") return end
			UI.Try(H.Withdraw(id))
		elseif ns.HeroField then
			ns.HeroField(id)
		end
	end, "dark")
	hc.field:SetPoint("RIGHT", hc.dismiss, "LEFT", -6, 0)
	UI.Tip(hc.field, function()
		local id = heroOf()
		if not id then return nil end
		if H.PartySlot(id) then
			return UI.SimpleTip("휴식", "파티에서 빼서 대기시킵니다. 경험치는 출전 중인 영웅만 얻습니다.")
		end
		local why = ns.HeroFieldBlocked and ns.HeroFieldBlocked(id)
		return UI.SimpleTip("출전", why or "같은 역할의 빈 자리에 들어갑니다. 빈 자리가 없으면 그 역할에서 가장 약한 영웅과 바꿉니다.")
	end, "TOP")
	hc.field.clickWhenOff = true
	hc.rename = UI.Button(hc, 86, 28, "이름 바꾸기", function()
		local id = heroOf()
		if id and ns.OpenRename then ns.OpenRename(id) end
	end, "dark")
	hc.rename:SetPoint("RIGHT", hc.field, "LEFT", -6, 0)
end

local function refreshHeader(page, id)
	local hc = page.head
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local race = ns.RACES[H.Race(id)]
	hc.portrait:SetHero(id)
	UI.SetHeroIcon(hc.portrait.icon, id)
	hc.portrait.lvl:Hide()
	hc.name:SetText(U.col("ffb84a", H.Name(id)))
	hc.info:SetText(string.format("Lv %d · %s · %s · %s", h.level, race.name,
		U.col(ns.CLASSES[sp.class].hex, ns.SpecLabel(h.spec)), ns.N(ns.ROLE[sp.role].name)))
	if h.level >= ns.HERO_MAX_LEVEL then
		hc.xp:SetValue(1)
		hc.xp:SetLabel("최고 레벨")
	else
		hc.xp:SetValue(h.xp / ns.XPForLevel(h.level))
		hc.xp:SetLabel(string.format("%s / %s", U.fmt(h.xp), U.fmt(ns.XPForLevel(h.level))))
	end
	hc.power:SetText(U.fmt(H.PowerScore(id)))
	local slot = H.PartySlot(id)
	if slot then
		hc.field:SetLabel("휴식")
		hc.field:SetStyle("dark")
		hc.field:SetOff(H.PartyCount() <= 1)
	else
		hc.field:SetLabel("출전")
		hc.field:SetStyle("blue")
		-- the party limit can leave no place at all (the click says why)
		hc.field:SetOff(ns.HeroFieldBlocked and ns.HeroFieldBlocked(id) ~= nil)
	end
	hc.dismiss:SetOff(H.Count() <= 1)
end

------------------------------------------------------------------------
-- 능력치 · 전문화
------------------------------------------------------------------------
local function buildStats(page, f)
	page.specHead = UI.Section(f, 220, "전문화")
	page.specHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	local sc = UI.Panel(f, 220, 58, "card")
	sc:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -28)
	page.specCard = sc
	sc.icon = UI.IconButton(sc, 40)
	sc.icon:SetPoint("LEFT", sc, "LEFT", 9, 0)
	sc.icon:EnableMouse(false)
	sc.name = UI.Text(sc, 13)
	sc.name:SetPoint("TOPLEFT", sc, "TOPLEFT", 58, -12)
	sc.name:SetWidth(154)
	sc.name:SetWordWrap(false)
	sc.sub = UI.Text(sc, 11)
	sc.sub:SetPoint("TOPLEFT", sc, "TOPLEFT", 58, -32)
	sc.sub:SetWidth(154)
	sc.sub:SetWordWrap(false)
	UI.Color(sc.sub, UI.C.sub)
	page.descHead = UI.Section(f, 220, "특징")
	page.descHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -100)
	page.desc = UI.Text(f, 11)
	page.desc:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -126)
	page.desc:SetWidth(220)
	page.desc:SetJustifyV("TOP")
	page.desc:SetSpacing(3)
	-- the stats in four groups, two columns
	page.groups = {}
	local cols = { { x = 236, w = 182 }, { x = 434, w = 182 } }
	for gi = 1, 4 do
		local col = cols[gi <= 2 and 1 or 2]
		local g = { head = UI.Section(f, col.w), rows = {}, col = col, f = f }
		for r = 1, 7 do
			local row = UI.StatRow(f, col.w, nil, nil, 0.6)
			row:SetHeight(19)
			-- some rows explain themselves on hover (원소 저항: each element)
			row:EnableMouse(true)
			UI.Tip(row, function(self) return self.tip end, "TOP")
			row.l:SetFont(ns.FONT, 11, "")
			row.v:SetFont(ns.FONT, 11, "")
			g.rows[r] = row
		end
		page.groups[gi] = g
	end
end

local function refreshStats(page, id)
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local sc = page.specCard
	sc.icon:SetIconName(sp.icon or "INV_Misc_QuestionMark")
	sc.name:SetText(U.col(ns.CLASSES[sp.class].hex, ns.SpecLabel(h.spec)))
	sc.sub:SetText(ns.N(ns.ROLE[sp.role].name) .. " · " .. ns.N(ns.SCHOOL[ns.Stats.Get(id).school].name) .. " 공격")
	page.desc:SetText(ns.N(sp.desc or ""))
	local groups = ns.Stats.Groups(id)
	local y = { 0, 0 }
	for gi, g in ipairs(page.groups) do
		local data = groups[gi]
		local ci = gi <= 2 and 1 or 2
		g.head:ClearAllPoints()
		g.head:SetPoint("TOPLEFT", g.f, "TOPLEFT", g.col.x, -y[ci])
		g.head:Set(data[1])
		y[ci] = y[ci] + 24
		for r, row in ipairs(g.rows) do
			local v = data[2][r]
			if v then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", g.f, "TOPLEFT", g.col.x, -y[ci])
				row:Set(v[1], v[2])
				row.tip = v[4]
				if v[3] == "up" then row.v:SetTextColor(0.4, 1, 0.45)
				elseif v[3] == "zero" then row.v:SetTextColor(0.55, 0.58, 0.65)
				else row.v:SetTextColor(1, 1, 1) end
				row:Show()
				y[ci] = y[ci] + 19
			else
				row:Hide()
			end
		end
		y[ci] = y[ci] + 10
	end
end

------------------------------------------------------------------------
-- 기술
------------------------------------------------------------------------
local SK_COL_W = (BODY_W - 8) / 2

local function buildSkills(page, f)
	page.eqHead = UI.Section(f, BODY_W)
	page.eqHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	page.eqSlots = {}
	for i = 1, 3 do
		local b = UI.IconButton(f, 48, function(self)
			local id = heroOf()
			if self.locked then
				Main.ShowTab("runes", { rune = slotRune() })
			elseif self.sid and id then
				H.UnequipSkill(id, self.sid)
				Main.Refresh()
			end
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 26 + (i - 1) * 104, -30)
		b.name = UI.Text(f, 11)
		b.name:SetPoint("TOP", b, "BOTTOM", 0, -4)
		b.name:SetWidth(96)
		b.name:SetJustifyH("CENTER")
		b.name:SetWordWrap(false)
		UI.Tip(b, function(self)
			if self.locked then
				local rune = ns.Runes.byId[slotRune()]
				return UI.SimpleTip("잠긴 기술 칸", string.format("'%s'을(를) 배우면 열립니다.\n클릭: 룬 화면에서 보기", ns.N(rune.name)))
			end
			if self.sid then
				local lines = skillLines(heroOf(), self.sid)
				lines[#lines] = { "클릭: 해제", nil, 0.45, 0.8, 1 }
				return lines
			end
			return UI.SimpleTip("빈 기술 칸", "아래에서 배운 기술을 클릭하면 여기에 장착됩니다.")
		end, "TOP")
		page.eqSlots[i] = b
	end
	page.autoSkills = UI.Button(f, 140, 32, "자동 배분", function()
		local id = heroOf()
		if not id then return end
		local n = H.AutoSkills(id)
		ns.Toast(n > 0 and string.format("기술 점수 %d점을 썼습니다.", n) or "쓸 수 있는 기술 점수가 없습니다.")
	end, "primary")
	page.autoSkills:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -30)
	page.autoSkills.clickWhenOff = true
	UI.Tip(page.autoSkills, function() return UI.SimpleTip("자동 배분", "남은 기술 점수를 장착한 기술부터 올립니다. 빈 칸이 있으면 새 기술을 배워 넣고, 장착한 기술이 모두 최고 레벨이면 나머지 기술에 씁니다.") end, "TOP")
	page.resetSkills = UI.Button(f, 140, 24, "", function()
		local id = heroOf()
		if not id then return end
		UI.Confirm({ title = "기술 초기화", ok = "초기화", style = "red",
			text = string.format("%s의 기술을 초기화하시겠습니까?\n첫 기술을 뺀 모든 기술 점수를 돌려받고, %s 골드가 듭니다.",
				H.Name(id), U.fmt(H.SkillResetCost(id))),
			onOk = function() UI.Try(H.ResetSkills(id)) end })
	end, "red")
	page.resetSkills:SetPoint("TOPRIGHT", page.autoSkills, "BOTTOMRIGHT", 0, -6)
	UI.Tip(page.resetSkills, function() return UI.SimpleTip("기술 초기화", "첫 기술을 뺀 모든 기술 점수를 돌려받습니다. 골드가 듭니다.") end, "TOP")

	page.skHead = UI.Section(f, BODY_W)
	page.skHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -112)
	page.skRows = {}
	for i = 1, 6 do
		local col, row = (i - 1) % 2, floor((i - 1) / 2)
		local b = UI.Row(f, SK_COL_W, 50, function(self, button)
			local id = heroOf()
			if not (id and self.sid) then return end
			if button == "RightButton" then
				UI.Try(H.LearnSkill(id, self.sid))
			elseif H.IsSkillEquipped(id, self.sid) then
				H.UnequipSkill(id, self.sid)
			elseif H.SkillPoints(id, self.sid) == 0 then
				UI.Try(false, "먼저 배우세요 (오른쪽 클릭, 기술 점수 1점).")
			elseif #ns.db.heroes[id].skills >= ns.SkillSlots() then
				UI.Try(false, "기술 칸이 가득 찼습니다. 위의 칸을 눌러 하나를 빼세요.")
			else
				UI.Try(H.EquipSkill(id, self.sid))
			end
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * (SK_COL_W + 8), -140 - row * 56)
		b:Layout(56)
		UI.Tip(b, function(self) return self.sid and skillLines(heroOf(), self.sid) or nil end, "TOP")
		page.skRows[i] = b
	end
end

local function refreshSkills(page, id)
	local h = ns.db.heroes[id]
	local list = H.SkillList(id)
	local free = H.SkillPointsFree(id)
	local slots = ns.SkillSlots()
	page.eqHead:Set(string.format("장착 기술  %d / %d", #h.skills, slots), "장착하면 전투에서 알아서 씁니다 · 칸 클릭: 해제")
	for i, b in ipairs(page.eqSlots) do
		b.locked = i > slots
		local sid = (not b.locked) and h.skills[i] or nil
		b.sid = sid
		b:Clear()
		if b.locked then
			b:SetLocked(true)
			b.name:SetText(U.col("9a8f78", "잠김 · 룬"))
		elseif sid then
			b:SetIconName(ns.SKILLS[sid].icon)
			b:SetCount(tostring(H.SkillLevel(id, sid)))
			b.name:SetText(ns.N(ns.SKILLS[sid].name))
		else
			b.name:SetText(U.col("8a90a2", "빈 칸"))
		end
	end
	page.autoSkills:SetOff(free == 0)
	page.autoSkills:SetBadge(free > 0 and free or nil)
	page.resetSkills:SetLabel("초기화 " .. U.fmt(H.SkillResetCost(id)) .. " G")
	page.resetSkills:SetOff(H.SkillPointsSpent(id) <= 1 or not ns.CanAfford(H.SkillResetCost(id)))
	page.skHead:Set("이 전문화의 기술", (free > 0 and U.col("60e070", "남은 점수 " .. free) or "남은 점수 0")
		.. " · 클릭: 장착·해제 · 오른쪽 클릭: 배우기·강화")
	for i, row in ipairs(page.skRows) do
		local sid = list[i]
		row.sid = sid
		if sid then
			local sk = ns.SKILLS[sid]
			local pts = H.SkillPoints(id, sid)
			local open = H.SkillUnlocked(id, sid)
			local eq = H.IsSkillEquipped(id, sid)
			row.icon:Clear()
			row.icon:SetIconName(sk.icon)
			row.icon:SetDim(not open)
			row.icon:SetLocked(not open)
			if pts > 0 then row.icon:SetCount(tostring(pts)) end
			row.title:SetText(eq and U.col("ffd24a", ns.N(sk.name) .. " · 장착") or (open and ns.N(sk.name) or U.col("8a90a2", ns.N(sk.name))))
			if not open then
				row.sub:SetText(U.col("9a8f78", string.format("영웅 Lv %d에 열림", ns.SKILL_UNLOCK[i])))
			elseif pts == 0 then
				row.sub:SetText(U.col("ffd24a", "배울 수 있음 (오른쪽 클릭)"))
			else
				row.sub:SetText(ns.SkillTag(sid) .. " · " .. ns.SkillActText(sid, max(1, H.SkillLevel(id, sid))))
			end
			row.right:SetText(pts > 0 and U.col(eq and "60e070" or "c8cdd8", string.format("Lv %d/%d", pts, ns.SKILL_MAX)) or "")
			row.badge:Set(open and free > 0 and pts < ns.SKILL_MAX and (H.CanLearnSkill(id, sid)) and true or false)
			row:SetSelected(eq and true or false)
			row:Show()
		else
			row:Hide()
		end
	end
end

------------------------------------------------------------------------
-- 특성
------------------------------------------------------------------------
local TIER_W = 64
local NODE_W = (BODY_W - TIER_W - 8) / 2
local NODE_H, NODE_STEP = 36, 40

local function buildTree(page, f)
	page.treeHead = UI.Section(f, BODY_W)
	page.treeHead:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	page.resetTree = page.treeHead:AddTool(UI.Button(f, 120, 22, "", function()
		local id = heroOf()
		if not id then return end
		UI.Confirm({ title = "특성 초기화", ok = "초기화", style = "red",
			text = string.format("%s의 특성을 초기화하시겠습니까?\n쓴 특성 점수를 모두 돌려받고, %s 골드가 듭니다.",
				H.Name(id), U.fmt(H.ResetCost(id))),
			onOk = function() UI.Try(H.ResetTree(id)) end })
	end, "red"))
	page.autoTree = page.treeHead:AddTool(UI.Button(f, 120, 22, "자동 배분", function()
		local id = heroOf()
		if not id then return end
		local n = H.AutoSpend(id)
		ns.Toast(n > 0 and string.format("특성 점수 %d점을 썼습니다.", n) or "쓸 수 있는 특성 점수가 없습니다.")
	end, "primary"))
	page.autoTree.clickWhenOff = true
	page.tiers = {}
	for t = 1, 8 do
		local y = -28 - (t - 1) * NODE_STEP
		local tier = { label = UI.Text(f, 12), nodes = {} }
		tier.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 11)
		tier.label:SetWidth(TIER_W)
		tier.label:SetWordWrap(false)
		for n = 1, 2 do
			local b = UI.Row(f, NODE_W, NODE_H, function(self, button)
				local id = heroOf()
				if not id then return end
				local node = H.Tree(id)[self.tier][self.n]
				local k = 0
				for _ = 1, button == "RightButton" and node.max or 1 do
					if not H.CanSpend(id, self.tier, self.n) then break end
					if H.SpendPoint(id, self.tier, self.n) then k = k + 1 end
				end
				if k == 0 then UI.Try(H.CanSpend(id, self.tier, self.n)) end
				Main.Refresh()
			end)
			b:SetPoint("TOPLEFT", f, "TOPLEFT", TIER_W + (n - 1) * (NODE_W + 8), y)
			b:Layout(64)
			-- points on the name line, so the effect can use the whole width
			b.right:ClearAllPoints()
			b.right:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -(NODE_H / 2 - 13))
			b.sub:SetWidth(b.textW)
			b.tier, b.n = t, n
			UI.Tip(b, function(self)
				local id = heroOf()
				if not id then return nil end
				local node = H.Tree(id)[self.tier][self.n]
				local lvl = H.NodeLevel(id, self.tier, self.n)
				local lines = { { ns.N(ns.AFFIX[node.p].n), string.format("%d / %d", lvl, node.max), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
					{ "1점마다 " .. ns.Stats.ModText(node.p, node.v), nil, 1, 1, 1 },
					{ "최대 " .. ns.Stats.ModText(node.p, node.v * node.max), nil, 0.7, 0.7, 0.7 } }
				local ok, why = H.CanSpend(id, self.tier, self.n)
				if not ok and why then lines[#lines + 1] = { why, nil, 1, 0.55, 0.45 } end
				lines[#lines + 1] = { "클릭: 1점 · 오른쪽 클릭: 최대까지", nil, 0.45, 0.8, 1 }
				return lines
			end, "TOP")
			tier.nodes[n] = b
		end
		page.tiers[t] = tier
	end
end

local function refreshTree(page, id)
	local tree = H.Tree(id)
	local free = H.PointsFree(id)
	local spent = H.PointsSpent(id)
	page.treeHead:Set("특성", (free > 0 and U.col("60e070", "남은 점수 " .. free) or "남은 점수 0") .. " · 클릭: 1점 · 오른쪽 클릭: 최대")
	page.autoTree:SetOff(free == 0)
	page.autoTree:SetBadge(free > 0 and free or nil)
	page.resetTree:SetLabel("초기화 " .. U.fmt(H.ResetCost(id)) .. " G")
	page.resetTree:SetOff(spent == 0 or not ns.CanAfford(H.ResetCost(id)))
	for t, tier in ipairs(page.tiers) do
		local open = H.TierOpen(id, t)
		local need = (t - 1) * ns.TREE_TIER_POINTS - spent
		tier.label:SetText(open and U.col("ffd24a", t .. "단계") or U.col("8a90a2", need .. "점 더"))
		for n, b in ipairs(tier.nodes) do
			local node = tree[t][n]
			local a = ns.AFFIX[node.p]
			local lvl = H.NodeLevel(id, t, n)
			b.icon:Clear()
			b.icon:SetArtIcon(UI.STAT_ART[node.p], UI.STAT_ICON[node.p] or "INV_Misc_QuestionMark")
			b.icon:SetDim(not open)
			b.icon:SetLocked(not open)
			b.title:SetText(open and ns.N(a.n) or U.col("8a90a2", ns.N(a.n)))
			b.sub:SetText(lvl > 0 and U.col("60e070", ns.Stats.ModText(node.p, node.v * lvl)) or U.col("8a90a2", "점당 " .. ns.Stats.ModText(node.p, node.v)))
			local col = lvl >= node.max and "ffd24a" or (lvl > 0 and "ffffff" or "8a90a2")
			b.right:SetText(U.col(col, lvl .. " / " .. node.max))
			b.badge:Set(false)
			b:SetSelected(lvl > 0)
		end
	end
end

------------------------------------------------------------------------
-- Build and refresh
------------------------------------------------------------------------
local SUBS = { { "stats", "능력치 · 전문화" }, { "skills", "기술" }, { "tree", "특성" } }

local function build(page)
	page.sub = "stats"
	buildList(page)
	local rp = UI.Panel(page, RIGHT_W, K.H, "inset")
	rp:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X, 0)
	page.right = rp
	buildHeader(page, rp)
	page.subTabs = UI.Tabs(rp, 450, SUBS, function(key)
		page.sub = key
		Main.Refresh()
	end, false, 32)
	page.subTabs:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -128)
	page.bodies = {}
	for _, s in ipairs(SUBS) do
		local f = CreateFrame("Frame", nil, rp)
		f:SetSize(BODY_W, BODY_H)
		f:SetPoint("TOPLEFT", rp, "TOPLEFT", BODY_X, BODY_Y)
		page.bodies[s[1]] = f
	end
	buildStats(page, page.bodies.stats)
	buildSkills(page, page.bodies.skills)
	buildTree(page, page.bodies.tree)
	page.empty = UI.Text(rp, 13, "영웅이 없습니다.\n왼쪽 아래 '영웅 모집하기'로 첫 영웅을 모집하세요 (무료).")
	page.empty:SetPoint("CENTER", rp, "CENTER", 0, 20)
	page.empty:SetWidth(RIGHT_W - 60)
	page.empty:SetJustifyH("CENTER")
	UI.Color(page.empty, UI.C.sub)
end

local function refresh(page)
	refreshList(page)
	local id = heroOf()
	local has = id ~= nil
	page.head:SetShown(has)
	page.subTabs:SetShown(has)
	page.empty:SetShown(not has)
	for key, f in pairs(page.bodies) do f:SetShown(has and key == page.sub) end
	if not has then return end
	refreshHeader(page, id)
	page.subTabs:Select(page.sub)
	page.subTabs:SetBadge("skills", H.SkillPointsFree(id) > 0 and H.SkillPointsFree(id) or nil)
	page.subTabs:SetBadge("tree", H.PointsFree(id) > 0 and H.PointsFree(id) or nil)
	if page.sub == "stats" then
		refreshStats(page, id)
	elseif page.sub == "skills" then
		refreshSkills(page, id)
	else
		refreshTree(page, id)
	end
end

-- the experience bars follow the fight live (five times a second): the
-- chosen hero's and each card's
local function xpBar(bar, h, label)
	if h.level >= ns.HERO_MAX_LEVEL then
		bar:SetValue(1)
		if label then bar:SetLabel("최고 레벨") end
	else
		local need = ns.XPForLevel(h.level)
		bar:SetValue(h.xp / need)
		if label then bar:SetLabel(string.format("%s / %s", U.fmt(h.xp), U.fmt(need))) end
	end
end
local function tick(page)
	local id = heroOf()
	local h = id and ns.db.heroes[id]
	if h and page.head:IsShown() then xpBar(page.head.xp, h, true) end
	for _, c in ipairs(page.cards or {}) do
		local ch = c.heroId and ns.db.heroes[c.heroId]
		if ch and c:IsShown() then xpBar(c.xp, ch) end
	end
end

-- opts: sub ("stats" | "skills" | "tree"), hero
local function open(page, opts)
	if not opts then return end
	if opts.hero then Main.SelectHero(opts.hero) end
	if opts.create then ns.OpenCreate(opts.create ~= true and opts.create or nil) end
	local sub = opts.sub or opts.mode
	if sub == "skills" or sub == "tree" or sub == "stats" then page.sub = sub end
end

Main.RegisterTab({
	key = "hero", title = "영웅", sub = "영웅, 능력치, 기술, 특성",
	icon = "INV_Helmet_06", art = "icon_hero", build = build, refresh = refresh, open = open, tick = tick,
	events = { "HEROES", "PARTY", "LEVEL", "TREE", "SKILLS", "GEAR", "STATS", "RUNES", "RESET", "FACTION" },
	gold = true,
})
