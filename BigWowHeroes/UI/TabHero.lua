-- Hero screen (영웅), built from the screen kit (UI/Layout.lua):
--   tabs: 장비 · 기술 · 특성
--   list: the hero row on top, then the chosen tab (equipment slots around
--         the hero / the skill slots and skills / the talent tree);
--   card: what is chosen (the hero, a slot, a skill, a talent) and the gold
--         button that acts on it.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes
local K = UI.K

local TOP = -60                 -- sub-page content starts under the hero row
local SLOT = 44
local LEFT_SLOTS = { "mh", "head", "chest", "hands", "feet" }
local RIGHT_SLOTS = { "oh", "wrist", "neck", "ring", "trinket" }
-- Which rune opens each skill slot (slot 1 is always open).
local SLOT_RUNE = { [2] = "c4", [3] = "c9" }

local function heroOf() return Main.SelectedHero() end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
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

local function gainText(r)
	local pct = (r - 1) * 100
	if pct > 0.2 then return U.col("60e070", "+" .. U.num(pct, 1) .. "%") end
	if pct < -0.2 then return U.col("ff6a5a", U.num(pct, 1) .. "%") end
	return U.col("aab3c8", "비슷함")
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
-- 장비
------------------------------------------------------------------------
local function buildGear(page)
	local list = page.S.list
	local p = CreateFrame("Frame", nil, list)
	p:SetAllPoints(list)
	page.gear = p
	p.slots = {}
	local function slotButton(slot, x, y)
		local b = UI.IconButton(p, SLOT, function(self)
			page.slot = (page.slot ~= self.slot) and self.slot or nil
			page.cand = nil
			Main.Refresh()
		end)
		b.slot = slot
		b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
		b.empty = UI.Text(b, K.F_MIN, ns.N(ns.SLOT[slot].name))
		b.empty:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.empty:SetJustifyH("CENTER")
		UI.Color(b.empty, UI.C.dim)
		b.up = UI.Text(b, 14, nil, "OUTLINE")
		b.up:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 2)
		b.up:SetTextColor(0.3, 1, 0.3)
		UI.Tip(b, function(self)
			local id = heroOf()
			local it = id and ns.db.heroes[id].gear[self.slot]
			if it then
				local lines = ns.Items.Tooltip(it, id)
				lines[#lines + 1] = { "클릭: 오른쪽에서 이 칸 보기", nil, 0.45, 0.8, 1 }
				return lines
			end
			return UI.SimpleTip(ns.N(ns.SLOT[self.slot].name), "비어 있음. 클릭하면 오른쪽에 넣을 수 있는 장비가 나옵니다.")
		end)
		p.slots[slot] = b
	end
	for i, slot in ipairs(LEFT_SLOTS) do slotButton(slot, K.PAD, TOP - 4 - (i - 1) * 54) end
	for i, slot in ipairs(RIGHT_SLOTS) do slotButton(slot, K.LIST_W - K.PAD - SLOT, TOP - 4 - (i - 1) * 54) end
	local cx = K.LIST_W / 2
	p.stage = UI.Art(p, "glow", "BORDER", 1, 0.85, 0.5, 0.18)
	p.stage:SetSize(260, 140)
	p.stage:SetPoint("CENTER", p, "TOPLEFT", cx, TOP - 120)
	p.hero = UI.HeroFigure(p, 96)
	p.hero:SetPoint("TOP", p, "TOPLEFT", cx, TOP - 22)
	p.hero:EnableMouse(false)
	p.hero.lvl:Hide()
	p.name = UI.Text(p, K.F_TITLE)
	p.name:SetPoint("TOP", p, "TOPLEFT", cx, TOP - 150)
	p.name:SetWidth(300)
	p.name:SetJustifyH("CENTER")
	p.name:SetWordWrap(false)
	p.spec = UI.Text(p, K.F_SMALL)
	p.spec:SetPoint("TOP", p, "TOPLEFT", cx, TOP - 172)
	p.spec:SetWidth(300)
	p.spec:SetJustifyH("CENTER")
	p.spec:SetWordWrap(false)
	UI.Color(p.spec, UI.C.sub)
	p.xp = UI.Bar(p, 290, 16, 0.55, 0.40, 1)
	p.xp:SetPoint("TOP", p, "TOPLEFT", cx, TOP - 196)
	p.power = UI.Text(p, K.F_BODY)
	p.power:SetPoint("TOP", p, "TOPLEFT", cx, TOP - 222)
	p.power:SetWidth(300)
	p.power:SetJustifyH("CENTER")
	p.power:SetWordWrap(false)
	p.hint = UI.Text(p, K.F_MIN, "칸을 누르면 오른쪽에 그 칸의 장비와 바꿀 장비가 나옵니다.  + = 더 좋은 장비 있음")
	p.hint:SetPoint("TOP", p, "TOPLEFT", cx, TOP - 290)
	p.hint:SetWidth(K.LIST_IN)
	p.hint:SetJustifyH("CENTER")
	UI.Color(p.hint, UI.C.dim)

	-- the card: every stat of the hero (always shown), or the chosen slot
	local d = page.S.card
	p.statRows = {}
	for i = 1, 20 do
		local r = UI.StatRow(d.content, K.CARD_IN)
		r:SetHeight(14)
		r.v:SetFont(ns.FONT, K.F_SMALL, "")
		r:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -(i - 1) * 14.6)
		p.statRows[i] = r
	end
	p.ups = UI.Text(d.content, K.F_SMALL)
	p.ups:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 0, 0)
	p.ups:SetWidth(K.CARD_IN)
	p.ups:Hide()
	p.itemLines = UI.Lines(d.content, K.CARD_IN, 4, K.F_SMALL, 88)
	p.itemLines:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	p.candHead = UI.Section(d.content, K.CARD_IN)
	p.candHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -92)
	p.cands = {}
	for i = 1, 3 do
		local row = UI.Row(d.content, K.CARD_IN, 40, function(self)
			page.cand = self.it
			Main.Refresh()
		end)
		row:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -118 - (i - 1) * 44)
		row:Layout(64)
		UI.Tip(row, function(self) return self.it and ns.Items.Tooltip(self.it, heroOf()) or nil end)
		p.cands[i] = row
	end
	p.none = UI.Text(d.content, K.F_SMALL, "가방에 이 칸에 맞는 장비가 없습니다.")
	p.none:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -122)
	UI.Color(p.none, UI.C.dim)
end

local function equipAllParty()
	local n = 0
	for i = 1, ns.PARTY_SIZE do
		local pid = ns.db.party[i]
		if pid then n = n + ns.Items.AutoEquip(pid) end
	end
	ns.Toast(n > 0 and string.format("파티 전원: 장비 %d개를 바꿨습니다.", n) or "가방에 더 좋은 장비가 없습니다.")
end

local function refreshGear(page, id)
	local p = page.gear
	local d = page.S.card
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local s = ns.Stats.Get(id)
	local race = ns.RACES[H.Race(id)]
	p.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.Name(id)))
	p.spec:SetText(string.format("%s · %s · %s %s", ns.SpecLabel(h.spec), ns.N(ns.ROLE[sp.role].name), race.name, ns.SEX[H.Sex(id)].name))
	p.hero:SetHeroFigure(id)
	p.hero:SetBadge(false)
	if h.level >= ns.HERO_MAX_LEVEL then
		p.xp:SetValue(1)
		p.xp:SetLabel("Lv " .. h.level .. " · 최고 레벨")
	else
		p.xp:SetValue(h.xp / ns.XPForLevel(h.level))
		p.xp:SetLabel(string.format("Lv %d · 경험치 %s / %s", h.level, U.fmt(h.xp), U.fmt(ns.XPForLevel(h.level))))
	end
	p.power:SetText(string.format("초당 피해 %s  ·  생명력 %s", U.col("ffd24a", U.fmt(ns.Stats.DPS(s))), U.col("ffd24a", U.fmt(s.hp))))
	local ups = ns.Guide.UpgradeHeroes()[id]
	local upSlots = 0
	for slot, b in pairs(p.slots) do
		local it = h.gear[slot]
		b:SetSelected(page.slot == slot)
		if it then
			b:SetIconName(ns.Items.Icon(it))
			b:SetQuality(it.q)
			b:SetLocked(it.lock)
			b.empty:Hide()
		else
			b.icon:Hide()
			b:SetQuality(nil)
			b:SetLocked(false)
			b.empty:Show()
		end
		local c = ups and candidates(id, slot)[1]
		local better = c and c.r > 1.01
		if better then upSlots = upSlots + 1 end
		b.up:SetText(better and "+" or "")
	end

	for _, r in ipairs(p.statRows) do r:Hide() end
	p.itemLines:Set(nil)
	for _, r in ipairs(p.cands) do r:Hide() end
	p.ups:SetText("")
	p.candHead:Hide()
	p.none:Hide()
	d:Extras(nil, nil)
	if not page.slot then
		-- the hero
		d:Head({ hero = id, title = H.Name(id), titleRGB = { U.rgb(ns.CLASSES[sp.class].hex) },
			sub = string.format("Lv %d · %s", h.level, ns.SpecLabel(h.spec)) })
		local rows = ns.Stats.Sheet(id)
		for i, r in ipairs(p.statRows) do
			local v = rows[i]
			if v then r:Set(v[1], v[2]) r:Show() else r:Hide() end
		end
		d:Actions({ "파티 전원 장착", equipAllParty, "blue", tip = { "파티 전원 장착", "출전 중인 영웅 모두에게 가방 속 더 좋은 장비를 장착합니다." } },
			{ "일괄 장착", function()
				local n = ns.Items.AutoEquip(id)
				ns.Toast(n > 0 and string.format("%s: 장비 %d개를 바꿨습니다.", H.ShortName(id), n) or "가방에 더 좋은 장비가 없습니다.")
			end, "primary", upSlots == 0, tip = { "일괄 장착", "가방에서 이 영웅에게 더 좋은 장비를 모든 칸에 장착합니다. 빼낸 장비는 가방으로 돌아갑니다." } })
		d.right:SetBadge(upSlots > 0)
		return
	end
	d.right:SetBadge(false)
	-- the chosen slot
	local slotName = ns.N(ns.SLOT[page.slot].name)
	local it = h.gear[page.slot]
	local close = function() page.slot = nil Main.Refresh() end
	if it then
		local q = ns.QUALITY[it.q]
		d:Head({ icon = ns.Items.Icon(it), quality = it.q, count = tostring(it.l), locked = it.lock, data = it,
			title = ns.Items.Name(it), titleRGB = { U.rgb(q.hex) },
			sub = string.format("%s %s · 아이템 레벨 %d", ns.N(q.name), slotName, it.l), band = { U.rgb(q.hex) }, close = close })
		local tl = ns.Items.Tooltip(it, nil)
		local list = {}
		for i = 3, #tl do
			local text = tl[i][1] or ""
			if #list < 4 and not text:find("분해 가치", 1, true) and not text:find("보호됨", 1, true) and not text:find("사용 가능", 1, true) then
				list[#list + 1] = { text .. (tl[i][2] and ("  " .. tl[i][2]) or ""), tl[i][3], tl[i][4], tl[i][5] }
			end
		end
		p.itemLines:Set(list)
	else
		d:Head({ icon = "INV_Misc_QuestionMark", dim = true, title = slotName .. " 칸", sub = "비어 있음", close = close })
		p.itemLines:Set({ { "이 칸에 아무것도 장착하지 않았습니다.", 0.55, 0.58, 0.65 } })
	end
	local list = candidates(id, page.slot)
	local pick
	for _, c in ipairs(list) do if c.it == page.cand then pick = c end end
	pick = pick or list[1]
	page.cand = pick and pick.it or nil
	p.candHead:Set("가방에서 바꿀 장비", #list > 0 and (#list .. "개") or "")
	p.candHead:Show()
	p.none:SetShown(#list == 0)
	for i, row in ipairs(p.cands) do
		local c = list[i]
		row.it = c and c.it
		if c then
			row.icon:SetIconName(ns.Items.Icon(c.it))
			row.icon:SetQuality(c.it.q)
			row.icon:SetLocked(c.it.lock)
			row.title:SetText(U.col(ns.QUALITY[c.it.q].hex, ns.Items.Name(c.it)))
			row.sub:SetText(ns.N(ns.QUALITY[c.it.q].name) .. " · Lv " .. c.it.l)
			row.right:SetText(gainText(c.r))
			row:SetSelected(c.it == page.cand)
			row:Show()
		else
			row:Hide()
		end
	end
	d:Actions({ "해제", function() UI.Try(ns.Items.Unequip(id, page.slot)) end, "dark", it == nil },
		{ pick and ("장착  " .. gainText(pick.r)) or "바꿀 장비 없음", function()
			local idx = page.cand and ns.Items.IndexInBag(page.cand)
			if idx and UI.Try(ns.Items.Equip(id, idx)) then page.cand = nil end
		end, "primary", pick == nil })
end

------------------------------------------------------------------------
-- 기술
------------------------------------------------------------------------
local SK_W = (K.LIST_IN - 8) / 2

local function buildSkills(page)
	local list = page.S.list
	local p = CreateFrame("Frame", nil, list)
	p:SetAllPoints(list)
	page.skills = p
	p.slotHead = UI.Section(p, K.LIST_IN)
	p.slotHead:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD, TOP)
	p.slots = {}
	local sw = (K.LIST_IN - 16) / 3
	for i = 1, 3 do
		local b = UI.Row(p, sw, 44, function(self)
			if self.locked then
				Main.ShowTab("runes", { rune = SLOT_RUNE[i] })
			elseif self.sid then
				page.skill = self.sid
				Main.Refresh()
			end
		end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD + (i - 1) * (sw + 8), TOP - 26)
		b.num = UI.Text(b.icon, K.F_MIN, tostring(i), "OUTLINE")
		b.num:SetPoint("TOPLEFT", b.icon, "TOPLEFT", 2, -1)
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
			return UI.SimpleTip("빈 기술 칸", "아래에서 배운 기술을 고르고 오른쪽의 '장착'을 누르세요.")
		end, "TOP")
		p.slots[i] = b
	end
	p.listHead = UI.Section(p, K.LIST_IN)
	p.listHead:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD, TOP - 84)
	-- what acts on the skill points, next to them
	p.reset = p.listHead:AddTool(page.resetSkills)
	p.auto = p.listHead:AddTool(page.autoSkills)
	p.rows = {}
	for i = 1, 6 do
		local col, row = (i - 1) % 2, floor((i - 1) / 2)
		local b = UI.Row(p, SK_W, 44, function(self)
			page.skill = self.sid
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD + col * (SK_W + 8), TOP - 110 - row * 50)
		b:Layout(52)
		UI.Tip(b, function(self) return self.sid and skillLines(heroOf(), self.sid) or nil end, "TOP")
		p.rows[i] = b
	end
	-- card content
	local d = page.S.card
	p.nowHead = UI.Section(d.content, K.CARD_IN)
	p.nowHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	p.now = UI.Text(d.content, K.F_BODY)
	p.now:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -28)
	p.now:SetWidth(K.CARD_IN)
	p.now:SetJustifyV("TOP")
	p.nextHead = UI.Section(d.content, K.CARD_IN, "다음 단계")
	p.nextHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -104)
	p.next = UI.Text(d.content, K.F_BODY)
	p.next:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -132)
	p.next:SetWidth(K.CARD_IN)
	p.next:SetJustifyV("TOP")
	p.req = UI.Text(d.content, K.F_BODY)
	p.req:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 0, 0)
	p.req:SetWidth(K.CARD_IN)
	p.req:SetTextColor(1, 0.55, 0.45)
end

local function refreshSkills(page, id)
	local p = page.skills
	local d = page.S.card
	local h = ns.db.heroes[id]
	local list = H.SkillList(id)
	local free = H.SkillPointsFree(id)
	p.slotHead:Set("전투에서 쓰는 기술", string.format("장착 칸 %d / 3", ns.SkillSlots()))
	local slots = ns.SkillSlots()
	for i, b in ipairs(p.slots) do
		b.locked = i > slots
		local sid = h.skills[i]
		b.sid = (not b.locked) and sid or nil
		b.icon:Clear()
		b:SetSelected(b.sid ~= nil and b.sid == page.skill)
		if b.locked then
			b.icon:SetLocked(true)
			b.title:SetText(U.col("9a8f78", i .. "번 칸 잠김"))
			b.sub:SetText("룬으로 열기")
		elseif sid then
			b.icon:SetIconName(ns.SKILLS[sid].icon)
			b.title:SetText(ns.N(ns.SKILLS[sid].name))
			b.sub:SetText(i .. "번 칸 · Lv " .. H.SkillPoints(id, sid))
		else
			b.title:SetText(U.col("aab3c8", i .. "번 칸"))
			b.sub:SetText("비어 있음")
		end
	end
	p.listHead:Set("이 전문화의 기술", free > 0 and U.col("60e070", "남은 점수 " .. free) or "남은 점수 0")
	if not page.skill or not H.SkillUnlockLevel(id, page.skill) then page.skill = h.skills[1] or list[1] end
	for i, row in ipairs(p.rows) do
		local sid = list[i]
		row.sid = sid
		local sk = ns.SKILLS[sid]
		local pts = H.SkillPoints(id, sid)
		local open = H.SkillUnlocked(id, sid)
		row.icon:Clear()
		row.icon:SetIconName(sk.icon)
		row.icon:SetDim(not open)
		row.icon:SetLocked(not open)
		row.title:SetText(open and ns.N(sk.name) or U.col("8a90a2", ns.N(sk.name)))
		local eq = H.IsSkillEquipped(id, sid)
		if not open then
			row.sub:SetText(U.col("9a8f78", string.format("영웅 Lv %d에 열림", ns.SKILL_UNLOCK[i])))
		elseif pts == 0 then
			row.sub:SetText(U.col("ffd24a", "배울 수 있음"))
		else
			row.sub:SetText(string.format("Lv %d / %d · %s", pts, ns.SKILL_MAX, ns.SkillTag(sid)))
		end
		row.right:SetText(eq and U.col("60e070", eq .. "번 칸") or "")
		row.badge:Set(open and free > 0 and pts == 0)
		row:SetSelected(sid == page.skill)
	end

	local sid = page.skill
	local sk = ns.SKILLS[sid]
	local pts = H.SkillPoints(id, sid)
	local lvl = max(1, H.SkillLevel(id, sid))
	d:Head({ icon = sk.icon, dim = not H.SkillUnlocked(id, sid), title = ns.N(sk.name),
		sub = (pts > 0 and string.format("Lv %d / %d", pts, ns.SKILL_MAX) or "아직 배우지 않음") .. " · " .. ns.SkillTag(sid) })
	p.nowHead:Set(pts > 0 and "지금" or "배우면 (레벨 1)", ns.SkillActText(sid, lvl))
	p.now:SetText(ns.SkillDesc(sid, lvl))
	if pts > 0 and pts < ns.SKILL_MAX then
		p.nextHead:Show()
		p.next:SetText(U.col("60e070", ns.SkillDesc(sid, H.SkillLevel(id, sid) + 1)))
	else
		p.nextHead:Hide()
		p.next:SetText(pts >= ns.SKILL_MAX and U.col("ffd24a", "최대 레벨입니다.") or "")
	end
	local ok, why = H.CanLearnSkill(id, sid)
	p.req:SetShown(not ok and why ~= nil and pts < ns.SKILL_MAX)
	p.req:SetText(why or "")
	local learn = { pts == 0 and "배우기 (1점)" or (pts >= ns.SKILL_MAX and "최대 레벨" or "강화 (1점)"), function()
		if not ok then UI.Try(false, why) return end
		UI.Try(H.LearnSkill(id, sid))
	end, "primary", not ok }
	local eq = H.IsSkillEquipped(id, sid)
	if eq then
		d:Actions({ "해제", function() H.UnequipSkill(id, sid) end, "dark" }, learn)
	else
		local full = #h.skills >= ns.SkillSlots()
		d:Actions({ "장착", function()
			if pts == 0 then
				UI.Try(false, "먼저 기술을 배우세요.")
			elseif full then
				UI.Try(false, "기술 칸이 가득 찼습니다. 장착 칸의 기술을 골라 해제하거나, 룬으로 칸을 늘리세요.")
			else
				UI.Try(H.EquipSkill(id, sid))
			end
		end, "blue", pts == 0 or full }, learn)
	end
	page.autoSkills:SetOff(free == 0)
	page.resetSkills:SetLabel("초기화 " .. U.fmt(H.SkillResetCost(id)) .. " G")
	page.resetSkills:SetOff(H.SkillPointsSpent(id) <= 1 or not ns.CanAfford(H.SkillResetCost(id)))
end

------------------------------------------------------------------------
-- 특성
------------------------------------------------------------------------
local TIER_W = 46
local NODE_W = (K.LIST_IN - TIER_W - 8) / 2
local NODE_H, NODE_STEP = 32, 36

local function buildTree(page)
	local list = page.S.list
	local p = CreateFrame("Frame", nil, list)
	p:SetAllPoints(list)
	page.tree = p
	p.head = UI.Section(p, K.LIST_IN)
	p.head:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD, TOP)
	p.head:AddTool(page.resetTree)
	p.head:AddTool(page.autoTree)
	p.tiers = {}
	for t = 1, 8 do
		local y = TOP - 26 - (t - 1) * NODE_STEP
		local tier = {}
		tier.label = UI.Text(p, K.F_SMALL)
		tier.label:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD, y - 9)
		tier.label:SetWidth(TIER_W)
		tier.label:SetWordWrap(false)
		tier.nodes = {}
		for n = 1, 2 do
			local b = UI.Row(p, NODE_W, NODE_H, function(self)
				page.node = { self.tier, self.n }
				Main.Refresh()
			end)
			b:SetPoint("TOPLEFT", p, "TOPLEFT", K.PAD + TIER_W + 8 + (n - 1) * (NODE_W + 8), y)
			b:Layout(66)
			b.title:ClearAllPoints()
			b.title:SetPoint("LEFT", b, "LEFT", NODE_H + 2, 0)
			b.title:SetFont(ns.FONT, K.F_SMALL, "")
			b.right:SetFont(ns.FONT, K.F_SMALL, "")
			b.sub:Hide()
			b.tier, b.n = t, n
			tier.nodes[n] = b
		end
		p.tiers[t] = tier
	end
	-- card content
	local d = page.S.card
	p.rowsCard = {}
	for i = 1, 4 do
		local r = UI.StatRow(d.content, K.CARD_IN)
		r:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -(i - 1) * 24)
		p.rowsCard[i] = r
	end
	p.state = UI.Text(d.content, K.F_SMALL)
	p.state:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -108)
	p.state:SetWidth(K.CARD_IN)
	p.help = UI.Text(d.content, K.F_SMALL, string.format("특성 점수는 레벨이 오를 때마다 1점씩 생깁니다. 한 단계에 %d점을 쓸 때마다 다음 단계가 열립니다.", ns.TREE_TIER_POINTS))
	p.help:SetPoint("BOTTOMLEFT", d.content, "BOTTOMLEFT", 0, 0)
	p.help:SetWidth(K.CARD_IN)
	UI.Color(p.help, UI.C.dim)
end

local function refreshTree(page, id)
	local p = page.tree
	local d = page.S.card
	local tree = H.Tree(id)
	local free = H.PointsFree(id)
	local spent = H.PointsSpent(id)
	p.head:Set("특성 트리", free > 0 and U.col("60e070", "남은 점수 " .. free) or "남은 점수 0")
	-- default selection: the first node that can take a point
	if not page.node then
		for t = 1, 8 do
			for n = 1, 2 do
				if not page.node and H.CanSpend(id, t, n) then page.node = { t, n } end
			end
		end
		page.node = page.node or { 1, 1 }
	end
	for t, tier in ipairs(p.tiers) do
		local open = H.TierOpen(id, t)
		local need = (t - 1) * ns.TREE_TIER_POINTS - spent
		tier.label:SetText(open and U.col("ffd24a", t .. "단계") or U.col("9a8f78", need .. "점 더"))
		for n, b in ipairs(tier.nodes) do
			local node = tree[t][n]
			local a = ns.AFFIX[node.p]
			local lvl = H.NodeLevel(id, t, n)
			b.icon:Clear()
			b.icon:SetArtIcon(UI.STAT_ART[node.p], UI.STAT_ICON[node.p] or "INV_Misc_QuestionMark")
			b.icon:SetDim(not open)
			b.icon:SetLocked(not open)
			b.title:SetText(open and ns.N(a.n) or U.col("8a90a2", ns.N(a.n)))
			local num = lvl > 0 and U.col("60e070", "+" .. ns.Stats.FormatValue(node.p, node.v * lvl)) or ""
			local col = lvl >= node.max and "ffd24a" or (lvl > 0 and "ffffff" or "8a90a2")
			b.right:SetText(num .. "  " .. U.col(col, lvl .. "/" .. node.max))
			b.badge:Set(false)
			b:SetSelected(page.node[1] == t and page.node[2] == n)
		end
	end
	local t, n = page.node[1], page.node[2]
	local node = tree[t][n]
	local a = ns.AFFIX[node.p]
	local lvl = H.NodeLevel(id, t, n)
	d:Head({ icon = UI.STAT_ICON[node.p] or "INV_Misc_QuestionMark", art = UI.STAT_ART[node.p], dim = not H.TierOpen(id, t), title = ns.N(a.n),
		sub = string.format("%d단계 · %d / %d", t, lvl, node.max) })
	local rows = {
		{ "1점마다", ns.Stats.ModText(node.p, node.v) },
		{ "지금", lvl > 0 and U.col("60e070", ns.Stats.ModText(node.p, node.v * lvl)) or "없음" },
		{ "최대", ns.Stats.ModText(node.p, node.v * node.max) },
	}
	for i, r in ipairs(p.rowsCard) do
		local v = rows[i]
		if v then r:Set(v[1], v[2]) r:Show() else r:Hide() end
	end
	local ok, why = H.CanSpend(id, t, n)
	if lvl >= node.max then
		p.state:SetText(U.col("ffd24a", "최대로 올렸습니다."))
	elseif not H.TierOpen(id, t) then
		p.state:SetText(U.col("ff9a7a", string.format("특성 점수를 %d점 더 쓰면 열립니다.", (t - 1) * ns.TREE_TIER_POINTS - spent)))
	elseif not ok then
		p.state:SetText(U.col("ff9a7a", why or ""))
	else
		p.state:SetText(U.col("60e070", "점수를 쓸 수 있습니다."))
	end
	local function spend(all)
		local k = 0
		for _ = 1, all and node.max or 1 do
			if not H.CanSpend(id, t, n) then break end
			if H.SpendPoint(id, t, n) then k = k + 1 end
		end
		if k == 0 then UI.Try(H.CanSpend(id, t, n)) end
	end
	d:Actions({ "최대까지", function() spend(true) end, "dark", not ok },
		{ "1점 쓰기", function() spend(false) end, "primary", not ok })
	page.autoTree:SetOff(free == 0)
	page.resetTree:SetLabel("초기화 " .. U.fmt(H.ResetCost(id)) .. " G")
	page.resetTree:SetOff(spent == 0 or not ns.CanAfford(H.ResetCost(id)))
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.sub = "gear"
	local S = UI.Screen(page, {
		tabs = { { "gear", "장비" }, { "skills", "기술" }, { "tree", "특성" } },
		onTab = function(key)
			page.sub = key
			Main.Refresh()
		end,
	})
	page.S = S
	page.strip = UI.HeroStrip(S.list, ns.ROSTER_MAX, 34, 8, function(id)
		Main.SelectHero(id)
		Main.Refresh()
	end)
	page.strip:SetPoint("TOPLEFT", S.list, "TOPLEFT", K.PAD, -K.PAD + 2)

	-- the skill and talent points' buttons: they sit in the header that
	-- shows the points (buildSkills, buildTree)
	page.autoSkills = UI.Button(S.list, 76, 22, "자동 배분", function()
		local id = heroOf()
		if id then
			local n = H.AutoSkills(id)
			ns.Toast(n > 0 and string.format("기술 점수 %d점을 썼습니다.", n) or "쓸 수 있는 기술 점수가 없습니다.")
		end
	end, "blue")
	page.resetSkills = UI.Button(S.list, 116, 22, "", function()
		local id = heroOf()
		if not id then return end
		UI.Confirm({ title = "기술 초기화", ok = "초기화", style = "red",
			text = string.format("%s의 기술을 초기화하시겠습니까?\n첫 기술을 뺀 모든 기술 점수를 돌려받고, %s 골드가 듭니다.",
				H.Name(id), U.fmt(H.SkillResetCost(id))),
			onOk = function() UI.Try(H.ResetSkills(id)) end })
	end, "red")
	UI.Tip(page.resetSkills, function() return UI.SimpleTip("기술 초기화", "첫 기술을 뺀 모든 기술 점수를 돌려받습니다. 골드가 듭니다.") end, "TOP")
	page.autoTree = UI.Button(S.list, 76, 22, "자동 배분", function()
		local id = heroOf()
		if id then
			local n = H.AutoSpend(id)
			ns.Toast(n > 0 and string.format("특성 점수 %d점을 썼습니다.", n) or "쓸 수 있는 특성 점수가 없습니다.")
		end
	end, "blue")
	page.resetTree = UI.Button(S.list, 116, 22, "", function()
		local id = heroOf()
		if not id then return end
		UI.Confirm({ title = "특성 초기화", ok = "초기화", style = "red",
			text = string.format("%s의 특성을 초기화하시겠습니까?\n쓴 특성 점수를 모두 돌려받고, %s 골드가 듭니다.",
				H.Name(id), U.fmt(H.ResetCost(id))),
			onOk = function() UI.Try(H.ResetTree(id)) end })
	end, "red")
	UI.Tip(page.resetTree, function() return UI.SimpleTip("특성 초기화", "쓴 특성 점수를 모두 돌려받습니다. 골드가 듭니다.") end, "TOP")

	buildGear(page)
	buildSkills(page)
	buildTree(page)
end

local function refresh(page)
	local S = page.S
	local id = heroOf()
	page.strip:Set(UI.HeroOrder(), id)
	S.tabs:Select(page.sub)
	local d = S.card
	if not id then
		page.gear:Hide()
		page.skills:Hide()
		page.tree:Hide()
		for _, r in ipairs(page.gear.statRows) do r:Hide() end
		page.gear.itemLines:Set(nil)
		for _, r in ipairs(page.gear.cands) do r:Hide() end
		page.gear.ups:SetText("")
		page.gear.candHead:Hide()
		page.gear.none:Hide()
		for _, w in ipairs({ page.skills.nowHead, page.skills.nextHead }) do w:Hide() end
		page.skills.now:SetText("")
		page.skills.next:SetText("")
		page.skills.req:SetText("")
		for _, r in ipairs(page.tree.rowsCard) do r:Hide() end
		page.tree.state:SetText("")
		page.tree.help:Hide()
		for _, k in ipairs({ "gear", "skills", "tree" }) do S.tabs:SetBadge(k, nil) end
		for _, b in ipairs({ page.autoSkills, page.resetSkills, page.autoTree, page.resetTree }) do b:Hide() end
		S.Empty("영웅이 없습니다.\n'편성'에서 첫 영웅을 만드세요.")
		d:Head({ title = "영웅이 없습니다" })
		d:Extras(nil, nil)
		d:Actions(nil, { "편성으로 가기", function() Main.ShowTab("party", { create = true }) end })
		return
	end
	S.Empty(nil)
	if page.heroShown ~= id then
		page.heroShown = id
		page.slot, page.cand, page.skill, page.node = nil, nil, nil, nil
	end
	S.tabs:SetBadge("gear", ns.Guide.UpgradeHeroes()[id] and true or nil)
	S.tabs:SetBadge("skills", H.SkillPointsFree(id) > 0 and H.SkillPointsFree(id) or nil)
	S.tabs:SetBadge("tree", H.PointsFree(id) > 0 and H.PointsFree(id) or nil)
	local sub = page.sub
	page.gear:SetShown(sub == "gear")
	page.skills:SetShown(sub == "skills")
	page.tree:SetShown(sub == "tree")
	page.autoSkills:SetShown(sub == "skills")
	page.resetSkills:SetShown(sub == "skills")
	page.autoTree:SetShown(sub == "tree")
	page.resetTree:SetShown(sub == "tree")
	-- card parts of the other tabs
	for _, r in ipairs(page.gear.statRows) do r:SetShown(false) end
	page.gear.itemLines:Set(nil)
	for _, r in ipairs(page.gear.cands) do r:Hide() end
	page.gear.ups:SetText("")
	page.gear.candHead:Hide()
	page.gear.none:Hide()
	for _, w in ipairs({ page.skills.nowHead, page.skills.nextHead, page.skills.req }) do w:Hide() end
	page.skills.now:SetText("")
	page.skills.next:SetText("")
	page.skills.req:SetText("")
	for _, r in ipairs(page.tree.rowsCard) do r:Hide() end
	page.tree.state:SetText("")
	page.tree.help:Hide()
	d.right:SetBadge(false)
	d:Extras(nil, nil)
	if sub == "gear" then
		refreshGear(page, id)
	elseif sub == "skills" then
		page.skills.nowHead:Show()
		refreshSkills(page, id)
	else
		page.tree.help:Show()
		refreshTree(page, id)
	end
end

local function tick(page) end

local function open(page, opts)
	if opts and opts.sub then page.sub = opts.sub end
	if opts and opts.hero then Main.SelectHero(opts.hero) end
end

Main.RegisterTab({
	key = "hero", title = "영웅", sub = "장비, 기술, 특성",
	icon = "INV_Helmet_06", art = "icon_hero", build = build, refresh = refresh, open = open, tick = tick,
	events = { "HEROES", "PARTY", "LEVEL", "TREE", "SKILLS", "GEAR", "BAG", "STATS", "RUNES", "RESET", "FACTION" },
})
