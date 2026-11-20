-- Party screen: the five role slots, the roster, hero creation and companions.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes

local CARD_W, CARD_H = 160, 180
local R_W, R_H = 136, 88

------------------------------------------------------------------------
-- Field / bench decisions
------------------------------------------------------------------------
-- What the "field" button of a bench hero does: deploy, swap with the weakest
-- party member of the same role, or nothing (no room).
local function fieldAction(id)
	local role = H.Role(id)
	local slot = H.FreeSlot(role)
	if slot and H.PartyCount() < ns.PartyLimit() then
		return "deploy", slot
	end
	local weakest, wp
	for i = 1, ns.PARTY_SIZE do
		local pid = ns.db.party[i]
		if pid and ns.PARTY_ROLES[i] == role then
			local p = ns.Stats.Power(pid)
			if not wp or p < wp then weakest, wp = i, p end
		end
	end
	if weakest then return "swap", weakest end
	return nil
end

local function field(id)
	local act, slot = fieldAction(id)
	if act == "deploy" then
		UI.Try(H.Deploy(id, slot))
	elseif act == "swap" then
		H.Swap(id, slot)
	else
		UI.Try(false, "빈 자리가 없습니다. '지휘의 룬'으로 파티 인원을 늘리세요.")
	end
end

local function heroTip(id)
	local h = ns.db.heroes[id]
	if not h then return nil end
	local sp = ns.SPECS[h.spec]
	local c = ns.CLASSES[sp.class]
	local s = ns.Stats.Get(id)
	local r, g, b = U.rgb(c.hex)
	local lines = { { H.Name(id), "Lv " .. h.level, r, g, b } }
	lines[#lines + 1] = { ns.SpecLabel(h.spec), ns.N(ns.ROLE[sp.role].name), U.rgb(ns.ROLE[sp.role].hex) }
	lines[#lines + 1] = { "전투력", U.fmt(ns.Stats.Power(id)), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }
	lines[#lines + 1] = { "초당 피해", U.fmt(ns.Stats.DPS(s)), 1, 1, 1 }
	lines[#lines + 1] = { "생명력", U.fmt(s.hp), 1, 1, 1 }
	local free = H.PointsFree(id)
	if free > 0 then
		lines[#lines + 1] = { string.format("사용하지 않은 기술 점수 %d", free), nil, 0.4, 1, 0.4 }
	end
	lines[#lines + 1] = { ns.N(sp.desc), nil, 0.75, 0.8, 0.9 }
	return lines
end

------------------------------------------------------------------------
-- Hero creation (modal)
------------------------------------------------------------------------
local create = {}

local function buildCreate()
	local c = Main.ModalContent(680, 400)
	create.frame = c
	create.title = UI.Title(c, "영웅 만들기", 18)
	create.title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	create.cost = UI.Text(c, 12)
	create.cost:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -2)
	create.cost:SetJustifyH("RIGHT")
	create.step1 = UI.Text(c, 11, "1. 직업을 고르세요")
	create.step1:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -28)
	UI.Color(create.step1, UI.C.sub)

	create.classes = {}
	for i, cid in ipairs(ns.CLASS_ORDER) do
		local cls = ns.CLASSES[cid]
		local b = CreateFrame("Button", nil, c)
		b:SetSize(64, 78)
		b:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + (i - 1) * 75, -46)
		b.disc = UI.Art(b, "circle", "BACKGROUND", 0.05, 0.06, 0.1)
		b.disc:SetSize(58, 58)
		b.disc:SetPoint("TOP", b, "TOP", 0, 0)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(50, 50)
		b.icon:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		UI.SetClassIcon(b.icon, cid)
		b.ringT = UI.Art(b, "ring", "OVERLAY")
		b.ringT:SetSize(58, 58)
		b.ringT:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow = UI.Art(b, "glow", "BACKGROUND", 1, 0.85, 0.35, 0.9)
		b.glow:SetSize(84, 84)
		b.glow:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow:Hide()
		b.label = UI.Text(b, 11, ns.N(cls.name))
		b.label:SetPoint("TOP", b.disc, "BOTTOM", 0, -3)
		b.label:SetJustifyH("CENTER")
		b.label:SetTextColor(U.rgb(cls.hex))
		b.cid = cid
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			create.class = self.cid
			create.spec = nil
			create.refresh()
		end)
		create.classes[i] = b
	end

	create.step2 = UI.Text(c, 11, "2. 전문화를 고르세요 - 역할과 싸우는 방식이 정해집니다")
	create.step2:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -136)
	UI.Color(create.step2, UI.C.sub)

	create.specs = {}
	for i = 1, 4 do
		local b = CreateFrame("Button", nil, c)
		b:SetSize(161, 190)
		b:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * 173, -154)
		b.bg = UI.Slice(b, "card", "BACKGROUND")
		b.sel = UI.Slice(b, "frame", "OVERLAY", 12)
		b.sel:SetColor(1, 0.82, 0.3, 1)
		b.sel:SetShown(false)
		b.icon = UI.IconButton(b, 40)
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -10)
		b.icon:EnableMouse(false)
		b.name = UI.Text(b, 15)
		b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 58, -12)
		UI.Color(b.name, UI.C.gold)
		b.role = UI.Pill(b, 70, 18, 0.2, 0.2, 0.2, 1)
		b.role:SetPoint("TOPLEFT", b, "TOPLEFT", 58, -32)
		b.roleG = UI.Glyph(b.role, "role_tank", 12)
		b.roleG:SetPoint("LEFT", b.role, "LEFT", 6, 0)
		b.role.text:ClearAllPoints()
		b.role.text:SetPoint("LEFT", b.roleG, "RIGHT", 3, 0)
		b.desc = UI.Text(b, 11)
		b.desc:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -60)
		b.desc:SetWidth(141)
		b.desc:SetJustifyV("TOP")
		UI.Color(b.desc, UI.C.text)
		b.skillsLabel = UI.Text(b, 10, "대표 기술")
		b.skillsLabel:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 36)
		UI.Color(b.skillsLabel, UI.C.sub)
		b.skills = {}
		for k = 1, 4 do
			local sb = UI.IconButton(b, 26)
			sb:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10 + (k - 1) * 30, 8)
			UI.Tip(sb, function(self)
				if not self.data then return nil end
				local sk = ns.SKILLS[self.data]
				return {
					{ ns.N(sk.name), ns.SkillTag(self.data), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
					{ ns.SkillActText(self.data, 1), nil, 0.6, 0.8, 1 },
					{ ns.SkillDesc(self.data, 1), nil, 1, 1, 1 },
				}
			end, "TOP")
			b.skills[k] = sb
		end
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			create.spec = self.sid
			create.refresh()
		end)
		b.onEnter = function(self) self.bg:SetColor(1.2, 1.2, 1.3, 1) end
		b.onLeave = function(self) self.bg:SetColor(1, 1, 1, 1) end
		b:SetScript("OnEnter", function(self) self.onEnter(self) end)
		b:SetScript("OnLeave", function(self) self.onLeave(self) end)
		create.specs[i] = b
	end

	create.go = UI.Button(c, 200, 38, "영웅 만들기", function()
		if not create.spec then return end
		local ok, id = H.Create(create.spec)
		if UI.Try(ok, id) then
			create.showResult(id)
		end
	end, "primary")
	create.go:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	create.close = UI.Button(c, 100, 38, "닫기", function() Main.CloseModal() end, "dark")
	create.close:SetPoint("RIGHT", create.go, "LEFT", -10, 0)
	create.hint = UI.Text(c, 11)
	create.hint:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 12)
	create.hint:SetWidth(340)
	UI.Color(create.hint, UI.C.sub)

	-- the result page
	local r = Main.ModalContent(420, 300)
	create.result = r
	r.head = UI.Title(r, "새 영웅이 합류했습니다!", 18)
	r.head:SetPoint("TOP", r, "TOP", 0, 0)
	r.head:SetJustifyH("CENTER")
	r.glow = UI.Art(r, "glow", "BACKGROUND", 1, 0.8, 0.3, 0.8)
	r.glow:SetSize(170, 170)
	r.glow:SetPoint("TOP", r, "TOP", 0, -14)
	r.portrait = UI.Portrait(r, 96)
	r.portrait:SetPoint("TOP", r, "TOP", 0, -50)
	r.name = UI.Text(r, 22)
	r.name:SetPoint("TOP", r, "TOP", 0, -160)
	r.name:SetJustifyH("CENTER")
	r.spec = UI.Text(r, 13)
	r.spec:SetPoint("TOP", r.name, "BOTTOM", 0, -4)
	r.spec:SetJustifyH("CENTER")
	r.state = UI.Text(r, 11)
	r.state:SetPoint("TOP", r.spec, "BOTTOM", 0, -6)
	r.state:SetJustifyH("CENTER")
	UI.Color(r.state, UI.C.sub)
	r.reroll = UI.Button(r, 160, 34, "이름 다시 뽑기", function()
		H.RerollName(create.newId)
		create.showResult(create.newId)
	end, "blue")
	r.reroll:SetGlyph("auto")
	r.reroll:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 20, 0)
	r.ok = UI.Button(r, 160, 34, "확인", function() Main.CloseModal() end, "primary")
	r.ok:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -20, 0)

	function create.showResult(id)
		create.newId = id
		local h = ns.db.heroes[id]
		local sp = ns.SPECS[h.spec]
		r.portrait:SetHero(id)
		r.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.Name(id)))
		r.spec:SetText(ns.SpecLabel(h.spec) .. "  ·  " .. U.col(ns.ROLE[sp.role].hex, ns.N(ns.ROLE[sp.role].name)))
		r.state:SetText(H.PartySlot(id) and "파티에 바로 합류했습니다."
			or "대기 중입니다. 편성 화면에서 출전시킬 수 있습니다.")
		Main.ShowModal(r, function() Main.MarkDirty() end)
	end

	function create.refresh()
		local cost = H.CreateCost()
		create.cost:SetText("비용 " .. (cost > 0 and UI.Gold(cost) or U.col("45d16a", "무료")) ..
			"   " .. string.format("보유 %d/%d", H.Count(), ns.ROSTER_MAX))
		for _, b in ipairs(create.classes) do
			local on = b.cid == create.class
			b.glow:SetShown(on)
			if on then b.ringT:SetVertexColor(1, 0.82, 0.3) else b.ringT:SetVertexColor(0.45, 0.5, 0.65) end
		end
		local cls = ns.CLASSES[create.class]
		for i, b in ipairs(create.specs) do
			local sid = cls.specs[i]
			b.sid = sid
			if sid then
				local sp = ns.SPECS[sid]
				local role = ns.ROLE[sp.role]
				b.icon:SetIconName(sp.icon)
				b.icon:SetBorderRGB(U.rgb(cls.hex))
				b.name:SetText(ns.N(sp.name))
				b.role:SetColor(U.rgb(role.hex))
				b.role:SetLabel(ns.N(role.name))
				b.roleG:SetTexture(UI.Tex(role.art))
				b.desc:SetText(ns.N(sp.desc))
				for k, sb in ipairs(b.skills) do
					local skid = sp.skills[k]
					sb.data = skid
					sb:SetIconName(ns.SKILLS[skid].icon)
				end
				b.sel:SetShown(create.spec == sid)
				b:Show()
			else
				b:Hide()
			end
		end
		local can = create.spec and H.Count() < ns.ROSTER_MAX and ns.CanAfford(cost)
		create.go:SetOff(not can)
		if not create.spec then
			create.hint:SetText("전문화 카드를 누르세요.")
		else
			local sp = ns.SPECS[create.spec]
			local slot = H.FreeSlot(sp.role)
			if H.Count() >= ns.ROSTER_MAX then
				create.hint:SetText(U.col("ff6a5a", "영웅을 더 보유할 수 없습니다."))
			elseif not ns.CanAfford(cost) then
				create.hint:SetText(U.col("ff6a5a", "골드가 부족합니다."))
			elseif slot and H.PartyCount() < ns.PartyLimit() then
				create.hint:SetText("만들면 바로 파티에 들어갑니다. 이름은 무작위로 정해집니다.")
			else
				create.hint:SetText("파티에 자리가 없어 대기 영웅이 됩니다. 이름은 무작위로 정해집니다.")
			end
		end
	end
end

function create.open(classId)
	if not create.frame then buildCreate() end
	create.class = classId or create.class or "WARRIOR"
	create.spec = nil
	-- preselect a specialization for the role the party is missing
	for i = 1, ns.PARTY_SIZE do
		if not ns.db.party[i] then
			local want = ns.PARTY_ROLES[i]
			for _, sid in ipairs(ns.CLASSES[create.class].specs) do
				if ns.SPECS[sid].role == want then create.spec = sid break end
			end
			break
		end
	end
	create.refresh()
	Main.ShowModal(create.frame, function() Main.MarkDirty() end)
end

ns.CreateHeroDialog = create.open

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.title = UI.Title(page, "", 14)
	page.title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.hint = UI.Text(page, 11, "탱커 1 · 딜러 3 · 힐러 1 자리. 파티 인원은 '지휘의 룬'으로 늘어납니다.")
	page.hint:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
	page.hint:SetJustifyH("RIGHT")
	UI.Color(page.hint, UI.C.sub)

	page.slots = {}
	for i = 1, ns.PARTY_SIZE do
		local role = ns.ROLE[ns.PARTY_ROLES[i]]
		local card = CreateFrame("Button", nil, page)
		card:SetSize(CARD_W, CARD_H)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (CARD_W + 12), -22)
		card.bg = UI.Slice(card, "card", "BACKGROUND")
		card.edge = UI.Slice(card, "frame", "BORDER", 11)
		local r, g, b = U.rgb(role.hex)
		card.edge:SetColor(r, g, b, 0.75)
		card.head = UI.Art(card, "grad_v", "BORDER", r, g, b, 0.35)
		card.head:SetPoint("TOPLEFT", card, "TOPLEFT", 3, -3)
		card.head:SetPoint("TOPRIGHT", card, "TOPRIGHT", -3, -3)
		card.head:SetHeight(28)
		card.roleG = UI.Glyph(card, role.art, 16, r, g, b)
		card.roleG:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -7)
		card.roleT = UI.Text(card, 12, ns.N(role.name))
		card.roleT:SetPoint("LEFT", card.roleG, "RIGHT", 4, 0)
		card.roleT:SetTextColor(r, g, b)
		card.slotN = UI.Text(card, 10, "#" .. i)
		card.slotN:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -9)
		UI.Color(card.slotN, UI.C.dim)
		card.portrait = UI.Portrait(card, 56, function(self)
			if self.heroId then
				Main.SelectHero(self.heroId)
				Main.ShowTab("hero")
			end
		end)
		card.portrait:SetPoint("TOP", card, "TOP", 0, -34)
		UI.Tip(card.portrait, function(self) return heroTip(self.heroId) end)
		card.plus = UI.Glyph(card, "plus", 34, 0.5, 0.56, 0.72)
		card.plus:SetPoint("TOP", card, "TOP", 0, -46)
		card.lock = UI.Glyph(card, "lock", 34, 0.55, 0.5, 0.42)
		card.lock:SetPoint("TOP", card, "TOP", 0, -46)
		card.name = UI.Text(card, 13)
		card.name:SetPoint("TOP", card, "TOP", 0, -98)
		card.name:SetJustifyH("CENTER")
		card.name:SetWidth(CARD_W - 12)
		card.name:SetWordWrap(false)
		card.spec = UI.Text(card, 10)
		card.spec:SetPoint("TOP", card.name, "BOTTOM", 0, -2)
		card.spec:SetJustifyH("CENTER")
		card.spec:SetWidth(CARD_W - 12)
		card.power = UI.Text(card, 11)
		card.power:SetPoint("TOP", card.spec, "BOTTOM", 0, -2)
		card.power:SetJustifyH("CENTER")
		card.action = UI.Button(card, CARD_W - 16, 24, "", nil, "dark")
		card.action:SetPoint("BOTTOM", card, "BOTTOM", 0, 6)
		card.idx = i
		card:RegisterForClicks("LeftButtonUp")
		card:SetScript("OnClick", function(self)
			local id = ns.db.party[self.idx]
			if id then Main.SelectHero(id) end
		end)
		page.slots[i] = card
	end

	page.rosterTitle = UI.Title(page, "", 14)
	page.rosterTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -216)
	page.create = UI.Button(page, 200, 28, "", function() create.open() end, "primary")
	page.create:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -210)
	page.create:SetGlyph("plus")

	page.roster = {}
	for i = 1, ns.ROSTER_MAX do
		local col, row = (i - 1) % 6, floor((i - 1) / 6)
		local card = CreateFrame("Button", nil, page)
		card:SetSize(R_W, R_H)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", col * (R_W + 6.4), -244 - row * (R_H + 6))
		card.bg = UI.Slice(card, "card", "BACKGROUND")
		card.sel = UI.Slice(card, "frame", "OVERLAY", 10)
		card.sel:SetColor(1, 0.82, 0.3, 1)
		card.sel:SetShown(false)
		card.portrait = UI.Portrait(card, 42, function(self)
			if self.heroId then Main.SelectHero(self.heroId) end
		end)
		card.portrait:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -7)
		UI.Tip(card.portrait, function(self) return heroTip(self.heroId) end)
		card.name = UI.Text(card, 12)
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -9)
		card.name:SetWidth(R_W - 58)
		card.name:SetWordWrap(false)
		card.spec = UI.Text(card, 10)
		card.spec:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -26)
		card.spec:SetWidth(R_W - 58)
		card.spec:SetWordWrap(false)
		UI.Color(card.spec, UI.C.sub)
		card.state = UI.Pill(card, 46, 16, 0.2, 0.6, 0.3, 1)
		card.state:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -40)
		card.action = UI.Button(card, R_W - 12, 22, "", nil, "dark")
		card.action:SetPoint("BOTTOM", card, "BOTTOM", 0, 6)
		card:RegisterForClicks("LeftButtonUp")
		card:SetScript("OnClick", function(self)
			if self.heroId then Main.SelectHero(self.heroId) end
		end)
		page.roster[i] = card
	end
	page.empty = UI.Text(page, 13, "아직 영웅이 없습니다. 오른쪽 위의 '영웅 만들기'로 첫 영웅을 무료로 만드세요!")
	page.empty:SetPoint("TOP", page, "TOP", 0, -300)
	page.empty:SetJustifyH("CENTER")

	page.petTitle = UI.Text(page, 11, "동료 (효과는 획득만 하면 항상 적용)")
	page.petTitle:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 30)
	UI.Color(page.petTitle, UI.C.sub)
	page.pets = {}
	for i, pet in ipairs(ns.PETS) do
		local b = UI.IconButton(page, 30, function(self)
			if ns.db.pets[self.pet.id] then
				ns.db.pet = self.pet.id
				Main.MarkDirty("party")
			end
		end)
		b.pet = pet
		b:SetIconName(pet.icon)
		b:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 300 + (i - 1) * 68, 26)
		UI.Tip(b, function(self)
			local p = self.pet
			local have, need = ns.PetProgress(p)
			local owned = ns.db.pets[p.id]
			local lines = { { ns.N(p.name), owned and "획득 · 클릭: 데리고 다니기" or "미획득",
				UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
			for k, v in pairs(p.bonus) do lines[#lines + 1] = { ns.BonusText(k, v), nil, 0.4, 1, 0.4 } end
			lines[#lines + 1] = { ns.PetUnlockText(p), U.fmt(have) .. " / " .. U.fmt(need), 0.8, 0.8, 0.8 }
			return lines
		end, "TOP")
		b.progress = UI.Bar(page, 30, 5, 0.3, 0.7, 1)
		b.progress:SetPoint("LEFT", b, "RIGHT", 3, -10)
		b.progress:SetBarWidth(30)
		page.pets[i] = b
	end
end

local function refresh(page)
	local db = ns.db
	local count, limit = H.PartyCount(), ns.PartyLimit()
	page.title:SetText(string.format("출전 파티  %d / %d", count, limit))
	local sel = Main.SelectedHero()

	for i, card in ipairs(page.slots) do
		local id = db.party[i]
		card.portrait:Hide()
		card.plus:Hide()
		card.lock:Hide()
		if id and db.heroes[id] then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			card.portrait:SetHero(id)
			card.portrait:SetSelected(id == sel)
			card.portrait:SetBadge(H.PointsFree(id) > 0)
			card.portrait:Show()
			card.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.Name(id)))
			card.spec:SetText(ns.SpecLabel(h.spec))
			UI.Color(card.spec, UI.C.sub)
			card.power:SetText("전투력 " .. U.col("ffd24a", U.fmt(ns.Stats.Power(id))))
			card.action:SetLabel("휴식")
			card.action:SetStyle("dark")
			card.action:SetOff(count <= 1)
			card.action.onClick = function() UI.Try(H.Withdraw(id)) end
		elseif count >= limit then
			card.lock:Show()
			card.name:SetText(U.col("9a8f78", "잠긴 자리"))
			card.spec:SetText("지휘의 룬으로 열립니다")
			UI.Color(card.spec, UI.C.dim)
			card.power:SetText("")
			card.action:SetLabel("룬 보러 가기")
			card.action:SetStyle("blue")
			card.action:SetOff(false)
			card.action.onClick = function() Main.ShowTab("runes") end
		else
			card.plus:Show()
			card.name:SetText(U.col("b8c0d8", "빈 자리"))
			card.spec:SetText(string.format("%s 영웅을 넣으세요", ns.N(ns.ROLE[ns.PARTY_ROLES[i]].name)))
			UI.Color(card.spec, UI.C.dim)
			card.power:SetText("")
			-- a bench hero of this role, or create one
			local bench
			for _, hid in ipairs(H.List()) do
				if not H.PartySlot(hid) and H.Role(hid) == ns.PARTY_ROLES[i] then bench = hid break end
			end
			if bench then
				card.action:SetLabel("출전: " .. H.Name(bench))
				card.action:SetStyle("green")
				card.action:SetOff(false)
				card.action.onClick = function() UI.Try(H.Deploy(bench, i)) end
			else
				card.action:SetLabel("영웅 만들기")
				card.action:SetStyle("primary")
				card.action:SetOff(H.Count() >= ns.ROSTER_MAX)
				card.action.onClick = function() create.open() end
			end
		end
	end

	local list = H.List()
	page.rosterTitle:SetText(string.format("보유 영웅  %d / %d", #list, ns.ROSTER_MAX))
	local cost = H.CreateCost()
	page.create:SetLabel("영웅 만들기  " .. (cost > 0 and U.fmt(cost) .. " G" or "무료"))
	page.create:SetOff(#list >= ns.ROSTER_MAX)
	page.create:SetBadge(ns.Guide.Badges().party and H.Count() < ns.ROSTER_MAX and ns.CanAfford(cost) and H.PartyCount() < ns.PartyLimit())
	page.empty:SetShown(#list == 0)

	for i, card in ipairs(page.roster) do
		local id = list[i]
		card.heroId = id
		if id then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			card.portrait:SetHero(id)
			card.portrait:SetSelected(false)
			card.portrait:SetBadge(H.PointsFree(id) > 0 and H.PartySlot(id) ~= nil)
			card.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.Name(id)))
			card.spec:SetText(ns.SpecLabel(h.spec))
			card.sel:SetShown(id == sel)
			if H.PartySlot(id) then
				card.state:SetColor(0.2, 0.55, 0.3, 1)
				card.state:SetLabel("출전")
				card.action:SetLabel("휴식")
				card.action:SetStyle("dark")
				card.action:SetOff(H.PartyCount() <= 1)
				card.action.onClick = function() UI.Try(H.Withdraw(id)) end
			else
				card.state:SetColor(0.3, 0.33, 0.42, 1)
				card.state:SetLabel("대기")
				local act = fieldAction(id)
				card.action:SetLabel(act == "swap" and "교체 출전" or "출전")
				card.action:SetStyle(act and "green" or "dark")
				card.action:SetOff(act == nil)
				card.action.onClick = function() field(id) end
			end
			card:Show()
		else
			card:Hide()
		end
	end

	for _, b in ipairs(page.pets) do
		local owned = db.pets[b.pet.id]
		local have, need = ns.PetProgress(b.pet)
		b:SetDim(not owned)
		b:SetSelected(owned and db.pet == b.pet.id)
		b.progress:SetValue(have / need)
		if owned then b.progress:SetRGB(0.3, 0.9, 0.35) else b.progress:SetRGB(0.3, 0.6, 1) end
	end
end

local function open(page, opts)
	if opts and opts.create then
		refresh(page)
		create.open()
	end
end

Main.RegisterTab({
	key = "party", title = "편성", sub = "출전할 영웅을 정하고 새 영웅을 만듭니다",
	icon = "INV_Misc_GroupNeedMore", build = build, refresh = refresh, open = open,
	events = { "PARTY", "HEROES", "LEVEL", "RUNES", "PETS", "RESET", "GEAR", "TREE" },
})
