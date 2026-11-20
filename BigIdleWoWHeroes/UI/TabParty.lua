-- Party screen (편성): the five role slots drawn in battle order (the tank
-- in front on the right), the roster, hero creation, companions and the
-- one-time faction choice.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes

local CARD_W, CARD_H = 160, 188
local R_W, R_H = 134, 88
local LANE_ORDER = { 5, 4, 3, 2, 1 } -- healer at the back ... tank in front
local ROLE_FILTER = { { nil, "전체" }, { "TANK", "탱커" }, { "DPS", "딜러" }, { "HEALER", "힐러" } }

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
-- The number a card shows: the stat that matters for the hero's role, so
-- heroes of different roles are never compared by one score.
local function roleStat(id)
	local s = ns.Stats.Get(id)
	local role = H.Role(id)
	if role == "TANK" then
		return "생명력 " .. U.col("ffd24a", U.fmt(s.hp))
	elseif role == "HEALER" then
		return "치유량 " .. U.col("ffd24a", "+" .. U.num(s.heal, 0) .. "%")
	end
	return "초당 피해 " .. U.col("ffd24a", U.fmt(ns.Stats.DPS(s)))
end

-- What the action button of a bench hero does: deploy into a free slot of its
-- role, swap with the weakest party member of that role, or nothing.
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

local function field(id, slot)
	if slot then
		if ns.db.party[slot] then return H.Swap(id, slot) end
		return UI.Try(H.Deploy(id, slot))
	end
	local act, s = fieldAction(id)
	if act == "deploy" then
		UI.Try(H.Deploy(id, s))
	elseif act == "swap" then
		H.Swap(id, s)
	end
end

-- Fills every open slot with the strongest bench hero of its role.
local function autoForm()
	local n = 0
	for _ = 1, ns.PARTY_SIZE do
		local done = false
		for i = 1, ns.PARTY_SIZE do
			if not ns.db.party[i] and H.PartyCount() < ns.PartyLimit() then
				local best, bp
				for _, id in ipairs(H.List()) do
					if not H.PartySlot(id) and H.Role(id) == ns.PARTY_ROLES[i] then
						local p = ns.Stats.Power(id)
						if not bp or p > bp then best, bp = id, p end
					end
				end
				if best and H.Deploy(best, i) then
					n = n + 1
					done = true
				end
			end
		end
		if not done then break end
	end
	ns.Toast(n > 0 and string.format("%d명을 빈 자리에 넣었습니다.", n) or "넣을 수 있는 대기 영웅이 없습니다.")
end

local function heroTip(id)
	local h = ns.db.heroes[id]
	if not h then return nil end
	local sp = ns.SPECS[h.spec]
	local c = ns.CLASSES[sp.class]
	local s = ns.Stats.Get(id)
	local r, g, b = U.rgb(c.hex)
	local race = ns.RACES[H.Race(id)]
	local lines = { { H.Name(id), "Lv " .. h.level, r, g, b } }
	lines[#lines + 1] = { ns.SpecLabel(h.spec), ns.N(ns.ROLE[sp.role].name), U.rgb(ns.ROLE[sp.role].hex) }
	lines[#lines + 1] = { (race and race.name or "") .. " " .. ns.SEX[H.Sex(id)].name, nil, 0.7, 0.75, 0.85 }
	lines[#lines + 1] = { "초당 피해", U.fmt(ns.Stats.DPS(s)), 1, 1, 1 }
	lines[#lines + 1] = { "생명력", U.fmt(s.hp), 1, 1, 1 }
	if H.PointsFree(id) > 0 then
		lines[#lines + 1] = { string.format("남은 특성 점수 %d", H.PointsFree(id)), nil, 0.4, 1, 0.4 }
	end
	if H.SkillPointsFree(id) > 0 then
		lines[#lines + 1] = { string.format("남은 기술 점수 %d", H.SkillPointsFree(id)), nil, 0.4, 1, 0.4 }
	end
	lines[#lines + 1] = { "클릭: 선택 · 두 번 클릭: 영웅 화면", nil, 0.45, 0.8, 1 }
	return lines
end

-- A portrait that becomes a small animated figure once hero art exists.
local function heroFigure(parent, size)
	local p = UI.Portrait(parent, size)
	p.fig = ns.Sprite.New(parent, size * 1.5)
	p.fig:SetScript("OnUpdate", function(self, dt) self:Step(dt) end)
	p.fig:EnableMouse(false)
	function p:SetHeroFigure(id)
		self:SetHero(id)
		local sid = id and ns.Sprite.ForHero(id, false)
		if sid and self.fig:SetSprite(sid) then
			self.fig:SetHeight2(size * 1.5 * ns.Sprite.HeroScale(id))
			self.fig:PlaceFeet(self, size / 2, 0)
			self.fig:Show()
			self.icon:Hide()
			self.disc:Hide()
		else
			self.fig:Hide()
			self.disc:Show()
			if id then UI.SetHeroIcon(self.icon, id) end
		end
	end
	return p
end
UI.HeroFigure = heroFigure

------------------------------------------------------------------------
-- Faction choice (first start; can be changed later in settings)
------------------------------------------------------------------------
local faction = {}

local function raceLines(fid)
	local parts = {}
	for _, cid in ipairs(ns.CLASS_ORDER) do
		local race = ns.RACES[ns.ClassRace(cid, fid)]
		parts[#parts + 1] = U.col(ns.CLASSES[cid].hex, ns.N(ns.CLASSES[cid].name)) .. " " .. race.name
	end
	local a, b = {}, {}
	for i, t in ipairs(parts) do
		if i <= 5 then a[#a + 1] = t else b[#b + 1] = t end
	end
	return table.concat(a, "  ·  ") .. "\n" .. table.concat(b, "  ·  ")
end

local function buildFaction()
	local c = Main.ModalContent(800, 440)
	faction.frame = c
	local title = UI.Title(c, "진영을 고르세요", 22)
	title:SetPoint("TOP", c, "TOP", 0, 0)
	local sub = UI.Text(c, 12, "영웅들의 종족 모습이 진영에 따라 정해집니다. 능력치 차이는 없고, 설정에서 언제든 바꿀 수 있습니다.")
	sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
	sub:SetJustifyH("CENTER")
	UI.Color(sub, UI.C.sub)
	for i, fid in ipairs(ns.FACTION_ORDER) do
		local f = ns.FACTIONS[fid]
		local r, g, b = U.rgb(f.hex)
		local half = UI.Panel(c, 392, 360, "card")
		half:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * 408, -64)
		half.bg:SetColor(r * 0.35 + 0.1, g * 0.35 + 0.1, b * 0.35 + 0.12, 1)
		local glow = UI.Art(half, "glow", "BORDER", r, g, b, 0.35)
		glow:SetSize(260, 200)
		glow:SetPoint("TOP", half, "TOP", 0, 10)
		local crest = half:CreateTexture(nil, "ARTWORK")
		crest:SetSize(96, 96)
		crest:SetPoint("TOP", half, "TOP", 0, -22)
		UI.SetArtOrIcon(crest, "icon_" .. fid:lower(), f.icon)
		local name = UI.Text(half, 24, ns.N(f.name))
		name:SetPoint("TOP", crest, "BOTTOM", 0, -10)
		name:SetJustifyH("CENTER")
		name:SetTextColor(r, g, b)
		local desc = UI.Text(half, 12, ns.N(f.desc))
		desc:SetPoint("TOP", name, "BOTTOM", 0, -8)
		desc:SetWidth(360)
		desc:SetJustifyH("CENTER")
		local races = UI.Text(half, 11, raceLines(fid))
		races:SetPoint("TOP", desc, "BOTTOM", 0, -14)
		races:SetWidth(370)
		races:SetJustifyH("CENTER")
		races:SetSpacing(4)
		local go = UI.Button(half, 220, 40, ns.N(f.name) .. "로 시작", function()
			local first = ns.db.faction == nil
			ns.db.faction = fid
			ns.Fire("FACTION")
			Main.CloseModal()
			ns.Toast(string.format("%s 진영을 골랐습니다.", ns.N(f.name)))
			if faction.done then
				local d = faction.done
				faction.done = nil
				d(first)
			end
		end, fid == "ALLIANCE" and "blue" or "red")
		go:SetPoint("BOTTOM", half, "BOTTOM", 0, 18)
		half.go = go
	end
end

-- done(first): called after a choice (first = true on the very first pick)
function ns.PickFaction(done)
	if not faction.frame then buildFaction() end
	faction.done = done
	Main.ShowModal(faction.frame)
end

------------------------------------------------------------------------
-- Hero creation (modal): class -> specialization -> gender -> name
------------------------------------------------------------------------
local create = {}

local function classRoles(cid)
	local roles = {}
	for _, sid in ipairs(ns.CLASSES[cid].specs) do roles[ns.SPECS[sid].role] = true end
	return roles
end

local function firstSpecFor(cid, role)
	for _, sid in ipairs(ns.CLASSES[cid].specs) do
		if not role or ns.SPECS[sid].role == role then return sid end
	end
end

local function rollName()
	create.name = H.RollName(create.spec, create.sex)
end

local function buildCreate()
	local c = Main.ModalContent(800, 470)
	create.frame = c
	local title = UI.Title(c, "영웅 만들기", 20)
	title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	create.info = UI.Text(c, 12)
	create.info:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -4)
	create.info:SetJustifyH("RIGHT")
	create.hint = UI.Text(c, 11)
	create.hint:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -28)
	UI.Color(create.hint, UI.C.sub)

	-- 1. class list ------------------------------------------------------
	local list = UI.Panel(c, 196, 404, "inset")
	list:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -50)
	create.classes = {}
	for i, cid in ipairs(ns.CLASS_ORDER) do
		local cls = ns.CLASSES[cid]
		local b = CreateFrame("Button", nil, list)
		b:SetSize(184, 38)
		b:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - (i - 1) * 39.5)
		b.bg = UI.Slice(b, "card", "BACKGROUND")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(30, 30)
		b.icon:SetPoint("LEFT", b, "LEFT", 5, 0)
		UI.SetClassIcon(b.icon, cid)
		b.label = UI.Text(b, 13, ns.N(cls.name))
		b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
		b.label:SetTextColor(U.rgb(cls.hex))
		b.roles = {}
		local roles = classRoles(cid)
		local x = -6
		for _, role in ipairs({ "HEALER", "DPS", "TANK" }) do
			if roles[role] then
				local g = UI.Glyph(b, ns.ROLE[role].art, 14, U.rgb(ns.ROLE[role].hex))
				g:SetPoint("RIGHT", b, "RIGHT", x, 0)
				x = x - 16
			end
		end
		b.rec = UI.Pill(b, 34, 15, 0.15, 0.55, 0.25, 1)
		b.rec:SetLabel("추천")
		b.rec:SetPoint("RIGHT", b, "RIGHT", x - 2, 0)
		b.cid = cid
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			create.class = self.cid
			create.spec = firstSpecFor(self.cid, create.role) or firstSpecFor(self.cid)
			rollName()
			create.refresh()
		end)
		b.onEnter = function(self) self.hover = true create.refresh() end
		b.onLeave = function(self) self.hover = false create.refresh() end
		b:SetScript("OnEnter", function(self) self.onEnter(self) end)
		b:SetScript("OnLeave", function(self) self.onLeave(self) end)
		create.classes[i] = b
	end

	-- 2. preview, gender, name --------------------------------------------
	local mid = UI.Panel(c, 270, 404, "card")
	mid:SetPoint("TOPLEFT", c, "TOPLEFT", 206, -50)
	create.mid = mid
	local stage = UI.Art(mid, "glow", "BORDER", 1, 0.85, 0.5, 0.25)
	stage:SetSize(240, 120)
	stage:SetPoint("CENTER", mid, "TOP", 0, -170)
	create.portrait = UI.Portrait(mid, 120)
	create.portrait:SetPoint("TOP", mid, "TOP", 0, -40)
	create.portrait.lvl:Hide()
	create.fig = ns.Sprite.New(mid, 190)
	create.fig:SetScript("OnUpdate", function(self, dt) self:Step(dt) end)
	create.race = UI.Text(mid, 12)
	create.race:SetPoint("TOP", mid, "TOP", 0, -196)
	create.race:SetJustifyH("CENTER")
	UI.Color(create.race, UI.C.sub)
	create.sexes = {}
	for i, sex in ipairs(ns.SEXES) do
		local b = UI.Button(mid, 108, 32, ns.SEX[sex].name, function()
			create.sex = sex
			rollName()
			create.refresh()
		end, "dark")
		b:SetPoint("TOP", mid, "TOP", (i - 1.5) * 116, -222)
		b.sex = sex
		local art = UI.ArtIcon(sex == "M" and "icon_male" or "icon_female")
		if art then
			b.sym = b:CreateTexture(nil, "OVERLAY")
			b.sym:SetSize(18, 18)
			b.sym:SetTexture(art)
			b.sym:SetPoint("RIGHT", b.label, "LEFT", -4, 0)
		end
		create.sexes[i] = b
	end
	local nameLabel = UI.Text(mid, 11, "이름")
	nameLabel:SetPoint("TOPLEFT", mid, "TOPLEFT", 16, -272)
	UI.Color(nameLabel, UI.C.sub)
	local nameBox = UI.Panel(mid, 238, 40, "inset")
	nameBox:SetPoint("TOPLEFT", mid, "TOPLEFT", 16, -290)
	create.nameText = UI.Text(nameBox, 16)
	create.nameText:SetPoint("LEFT", nameBox, "LEFT", 12, 0)
	create.nameText:SetWidth(170)
	create.nameText:SetWordWrap(false)
	create.reroll = UI.Button(nameBox, 50, 30, "다시", function()
		rollName()
		create.refresh()
	end, "blue")
	create.reroll:SetPoint("RIGHT", nameBox, "RIGHT", -5, 0)
	UI.Tip(create.reroll, function() return UI.SimpleTip("이름 다시 뽑기", "종족과 성별에 맞는 이름과 성을 새로 뽑습니다.") end)
	local nameHint = UI.Text(mid, 10, "이름은 영웅 화면에서도 바꿀 수 있습니다.")
	nameHint:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)
	UI.Color(nameHint, UI.C.dim)

	-- 3. specializations ----------------------------------------------------
	local right = CreateFrame("Frame", nil, c)
	right:SetSize(314, 380)
	right:SetPoint("TOPLEFT", c, "TOPLEFT", 486, -50)
	create.specs = {}
	for i = 1, 4 do
		local b = CreateFrame("Button", nil, right)
		b:SetSize(314, 72)
		b:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(i - 1) * 77)
		b.bg = UI.Slice(b, "card", "BACKGROUND")
		b.icon = UI.IconButton(b, 40)
		b.icon:EnableMouse(false)
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -8)
		b.name = UI.Text(b, 14)
		b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 56, -8)
		b.role = UI.Pill(b, 52, 18, 0.2, 0.3, 0.6, 1)
		b.role:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
		b.desc = UI.Text(b, 11)
		b.desc:SetPoint("TOPLEFT", b, "TOPLEFT", 56, -28)
		b.desc:SetWidth(250)
		b.desc:SetJustifyV("TOP")
		UI.Color(b.desc, UI.C.sub)
		b.check = UI.Glyph(b, "check", 18, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3])
		b.check:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -8)
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			create.spec = self.sid
			create.refresh()
		end)
		create.specs[i] = b
	end
	create.skillsTitle = UI.Text(right, 11, "이 전문화의 기술 (영웅 레벨에 따라 열림)")
	create.skillsTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -312)
	UI.Color(create.skillsTitle, UI.C.sub)
	create.skills = {}
	for i = 1, 6 do
		local s = UI.IconButton(right, 40)
		s:SetPoint("TOPLEFT", right, "TOPLEFT", (i - 1) * 50, -330)
		s.lv = UI.Text(s, 9, nil, "OUTLINE")
		s.lv:SetPoint("BOTTOM", s, "BOTTOM", 0, -11)
		s.lv:SetJustifyH("CENTER")
		UI.Color(s.lv, UI.C.sub)
		UI.Tip(s, function(self)
			if not self.sid then return nil end
			local sk = ns.SKILLS[self.sid]
			return {
				{ ns.N(sk.name), "영웅 Lv " .. self.unlock .. "부터", UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
				{ ns.SkillActText(self.sid, 1), ns.SkillTag(self.sid), 0.7, 0.8, 1 },
				{ ns.SkillDesc(self.sid, 1), nil, 1, 1, 1, true },
			}
		end)
		create.skills[i] = s
	end

	-- footer -------------------------------------------------------------
	create.cancel = UI.Button(c, 100, 40, "취소", function() Main.CloseModal() end, "dark")
	create.cancel:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -228, 0)
	create.go = UI.Button(c, 220, 40, "", function()
		if not create.spec then return end
		local ok, res = H.Create(create.spec, create.sex, create.name)
		if UI.Try(ok, res) then
			Main.CloseModal()
			Main.SelectHero(res)
			ns.Toast(string.format("%s 합류! (%s)", H.Name(res), ns.SpecLabel(create.spec)))
			Main.Refresh()
		end
	end, "primary")
	create.go:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
end

function create.refresh()
	local cost = H.CreateCost()
	create.info:SetText(string.format("비용 %s   ·   보유 %d / %d", cost > 0 and UI.Gold(cost) or U.col("40ff40", "무료"), H.Count(), ns.ROSTER_MAX))
	if create.role then
		create.hint:SetText(string.format("파티에 %s 자리가 비어 있습니다. %s 표시가 있는 직업에 %s 전문화가 있습니다.",
			ns.ROLE[create.role].name, U.col("40d060", "추천"), ns.ROLE[create.role].name))
	else
		create.hint:SetText("직업과 전문화를 고르고, 성별과 이름을 정하세요. 전문화가 역할(탱커·딜러·힐러)을 정합니다.")
	end
	for _, b in ipairs(create.classes) do
		local on = b.cid == create.class
		local k = on and 1 or (b.hover and 0.6 or 0.42)
		if on then b.bg:SetColor(0.95, 0.78, 0.35, 1) else b.bg:SetColor(k * 0.55, k * 0.6, k * 0.85, 1) end
		b.rec:SetShown(create.role ~= nil and classRoles(b.cid)[create.role] == true)
	end
	local cid = create.class
	-- preview
	local race = ns.RACES[ns.ClassRace(cid)]
	local fac = ns.FACTIONS[ns.Faction() or "ALLIANCE"]
	create.race:SetText(string.format("%s  ·  %s %s", ns.N(fac.name), race.name, ns.SEX[create.sex].name))
	local sid = "hero_" .. cid:lower() .. "_" .. (ns.Faction() or "ALLIANCE"):lower() .. "_" .. create.sex:lower()
	if create.fig:SetSprite(sid) then
		create.fig:SetHeight2(190 * (ns.Sprite.RACE_SCALE[race.id] or 1))
		create.fig:PlaceFeet(create.mid, 135, 210)
		create.fig:Show()
		create.portrait:Hide()
	else
		create.fig:Hide()
		create.portrait:Show()
		UI.SetClassIcon(create.portrait.icon, cid)
		create.portrait.icon:Show()
		create.portrait.ringT:SetVertexColor(U.rgb(ns.CLASSES[cid].hex))
		create.portrait.role:Hide()
	end
	for _, b in ipairs(create.sexes) do
		b:SetStyle(b.sex == create.sex and "blue" or "dark")
		b:SetOn(b.sex == create.sex)
	end
	create.nameText:SetText(create.name or "")
	create.nameText:SetTextColor(U.rgb(ns.CLASSES[cid].hex))
	-- specializations
	local specs = ns.CLASSES[cid].specs
	for i, b in ipairs(create.specs) do
		local spid = specs[i]
		b.sid = spid
		if spid then
			local sp = ns.SPECS[spid]
			local role = ns.ROLE[sp.role]
			b.icon:SetIconName(sp.icon)
			b.name:SetText(ns.N(sp.name))
			b.role:SetLabel(ns.N(role.name))
			local r, g, bl = U.rgb(role.hex)
			b.role:SetColor(r * 0.6, g * 0.6, bl * 0.6, 1)
			b.desc:SetText(ns.N(sp.desc))
			local on = spid == create.spec
			if on then b.bg:SetColor(0.95, 0.78, 0.35, 1) else b.bg:SetColor(0.30, 0.34, 0.48, 1) end
			b.check:SetShown(on)
			b:Show()
		else
			b:Hide()
		end
	end
	local sp = create.spec and ns.SPECS[create.spec]
	for i, s in ipairs(create.skills) do
		local skid = sp and sp.skills[i]
		s.sid = skid
		s.unlock = ns.SKILL_UNLOCK[i]
		if skid then
			s:SetIconName(ns.SKILLS[skid].icon)
			s.lv:SetText("Lv " .. ns.SKILL_UNLOCK[i])
			s:Show()
		else
			s:Hide()
		end
	end
	local full = H.Count() >= ns.ROSTER_MAX
	create.go:SetLabel(full and "보유 한도 가득 참" or (sp and (ns.SpecLabel(create.spec) .. " 만들기") or "전문화를 고르세요"))
	create.go:SetOff(full or not sp or not ns.CanAfford(cost))
end

-- classId: optional class to start on; role: optional role the party misses
function create.open(classId, role)
	if not create.frame then buildCreate() end
	create.role = role
	if not create.sex then create.sex = math.random() < 0.5 and "M" or "F" end
	local cid = classId
	if not cid and role then
		for _, c in ipairs(ns.CLASS_ORDER) do
			if classRoles(c)[role] then cid = c break end
		end
	end
	cid = cid or create.class or ns.CLASS_ORDER[1]
	create.class = cid
	create.spec = firstSpecFor(cid, role) or firstSpecFor(cid)
	rollName()
	create.refresh()
	Main.ShowModal(create.frame)
end
ns.CreateHeroDialog = create.open

------------------------------------------------------------------------
-- Companions (modal)
------------------------------------------------------------------------
local pets = {}

local function buildPets()
	local c = Main.ModalContent(640, 330)
	pets.frame = c
	local title = UI.Title(c, "동료", 20)
	title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	local sub = UI.Text(c, 11, "동료는 조건을 채우면 얻고, 얻은 동료의 효과는 항상 모두 적용됩니다. 데리고 다닐 동료는 전투 창에 함께 보입니다.")
	sub:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -28)
	sub:SetWidth(640)
	UI.Color(sub, UI.C.sub)
	pets.cards = {}
	for i, pet in ipairs(ns.PETS) do
		local card = UI.Panel(c, 154, 128, "card")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", ((i - 1) % 4) * 162, -56 - floor((i - 1) / 4) * 136)
		card.icon = UI.IconButton(card, 40)
		card.icon:EnableMouse(false)
		card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
		card.icon:SetIconName(pet.icon)
		card.name = UI.Text(card, 12, ns.N(pet.name))
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -10)
		card.name:SetWidth(94)
		card.bonus = UI.Text(card, 10)
		card.bonus:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -28)
		card.bonus:SetWidth(94)
		card.bonus:SetJustifyV("TOP")
		card.cond = UI.Text(card, 10)
		card.cond:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -60)
		card.cond:SetWidth(138)
		UI.Color(card.cond, UI.C.sub)
		card.bar = UI.Bar(card, 138, 8, 0.3, 0.6, 1)
		card.bar:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -78)
		card.go = UI.Button(card, 138, 24, "", function()
			if ns.db.pets[pet.id] then
				ns.db.pet = pet.id
				pets.refresh()
				Main.MarkDirty("party")
			end
		end, "dark")
		card.go:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
		card.pet = pet
		pets.cards[i] = card
	end
	local close = UI.Button(c, 120, 32, "닫기", function() Main.CloseModal() end, "dark")
	close:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, -6)
end

function pets.refresh()
	local db = ns.db
	for _, card in ipairs(pets.cards) do
		local p = card.pet
		local owned = db.pets[p.id]
		local have, need = ns.PetProgress(p)
		local parts = {}
		for k, v in pairs(p.bonus) do parts[#parts + 1] = ns.BonusText(k, v) end
		table.sort(parts)
		card.bonus:SetText(table.concat(parts, "\n"))
		card.bonus:SetTextColor(owned and 0.4 or 0.55, owned and 1 or 0.6, owned and 0.45 or 0.65)
		card.icon:SetDim(not owned)
		card.cond:SetText(ns.PetUnlockText(p) .. "  " .. U.fmt(min(have, need)) .. "/" .. U.fmt(need))
		card.bar:SetValue(have / need)
		card.bar:SetRGB(owned and 0.3 or 0.3, owned and 0.9 or 0.6, owned and 0.35 or 1)
		if not owned then
			card.go:SetLabel("미획득")
			card.go:SetStyle("dark")
			card.go:SetOff(true)
		elseif db.pet == p.id then
			card.go:SetLabel("데리고 다니는 중")
			card.go:SetStyle("green")
			card.go:SetOff(false)
		else
			card.go:SetLabel("데리고 다니기")
			card.go:SetStyle("blue")
			card.go:SetOff(false)
		end
	end
end

local function openPets()
	if not pets.frame then buildPets() end
	pets.refresh()
	Main.ShowModal(pets.frame)
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function selectSlot(page, slot)
	if page.slotSel == slot then slot = nil end
	page.slotSel = slot
	page.filter = slot and ns.PARTY_ROLES[slot] or nil
	Main.Refresh()
end

local function nextCommandRune()
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		for _, node in ipairs(br.nodes) do
			if node.stat == "party" and ns.Runes.Level(node.id) == 0 then return node.id end
		end
	end
end

local function buildSlotCard(page, slot, x)
	local card = CreateFrame("Button", nil, page)
	card:SetSize(CARD_W, CARD_H)
	card:SetPoint("TOPLEFT", page, "TOPLEFT", x, -46)
	card.bg = UI.Slice(card, "card", "BACKGROUND")
	card.slot = slot
	local role = ns.PARTY_ROLES[slot]
	local r, g, b = U.rgb(ns.ROLE[role].hex)
	card.roleBar = card:CreateTexture(nil, "BORDER")
	card.roleBar:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
	card.roleBar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
	card.roleBar:SetHeight(22)
	UI.Fill(card.roleBar, r * 0.45, g * 0.45, b * 0.45, 0.9)
	card.roleIcon = UI.Glyph(card, ns.ROLE[role].art, 16, r, g, b)
	card.roleIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 9, -7)
	card.roleText = UI.Text(card, 12, ns.N(ns.ROLE[role].name))
	card.roleText:SetPoint("LEFT", card.roleIcon, "RIGHT", 5, 0)
	card.sel = UI.Art(card, "frame", "OVERLAY", 1, 0.85, 0.35)
	card.sel:SetPoint("TOPLEFT", card, "TOPLEFT", -3, 3)
	card.sel:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 3, -3)
	card.sel:Hide()
	card.portrait = heroFigure(card, 68)
	card.portrait:SetPoint("TOP", card, "TOP", 0, -34)
	card.portrait:EnableMouse(false)
	card.plus = UI.Glyph(card, "plus", 40, 0.55, 0.62, 0.8)
	card.plus:SetPoint("TOP", card, "TOP", 0, -48)
	card.lock = UI.Glyph(card, "lock", 36, 0.75, 0.65, 0.45)
	card.lock:SetPoint("TOP", card, "TOP", 0, -50)
	card.name = UI.Text(card, 13)
	card.name:SetPoint("TOP", card, "TOP", 0, -110)
	card.name:SetWidth(CARD_W - 12)
	card.name:SetJustifyH("CENTER")
	card.name:SetWordWrap(false)
	card.spec = UI.Text(card, 10)
	card.spec:SetPoint("TOP", card.name, "BOTTOM", 0, -3)
	card.spec:SetWidth(CARD_W - 12)
	card.spec:SetJustifyH("CENTER")
	UI.Color(card.spec, UI.C.sub)
	card.stat = UI.Text(card, 10)
	card.stat:SetPoint("TOP", card.spec, "BOTTOM", 0, -3)
	card.stat:SetJustifyH("CENTER")
	card.action = UI.Button(card, CARD_W - 14, 24, "", nil, "dark")
	card.action:SetPoint("BOTTOM", card, "BOTTOM", 0, 7)
	card:RegisterForClicks("LeftButtonUp")
	card:SetScript("OnClick", function(self)
		ns.Sound("click")
		local id = ns.db.party[self.slot]
		if id then
			if Main.SelectedHero() == id and self.lastClick and GetTime() - self.lastClick < 0.4 then
				Main.ShowTab("hero")
				return
			end
			self.lastClick = GetTime()
			Main.SelectHero(id)
			page.slotSel, page.filter = nil, nil
			Main.Refresh()
		elseif H.PartyCount() < ns.PartyLimit() then
			selectSlot(page, self.slot)
		else
			Main.ShowTab("runes", { rune = nextCommandRune() })
		end
	end)
	UI.Tip(card, function(self)
		local id = ns.db.party[self.slot]
		if id then return heroTip(id) end
		if H.PartyCount() >= ns.PartyLimit() then
			return UI.SimpleTip("잠긴 자리", "룬 화면의 '지휘의 룬'을 배우면 파티 자리가 하나씩 열립니다. 클릭하면 룬 화면으로 갑니다.")
		end
		return UI.SimpleTip(ns.N(ns.ROLE[ns.PARTY_ROLES[self.slot]].name) .. " 자리",
			"클릭하면 아래 목록에서 이 역할의 영웅만 보여 줍니다. 대기 중인 영웅의 '출전'을 누르세요.")
	end)
	return card
end

local function build(page)
	page.filter = nil
	page.title = UI.Title(page, "", 18)
	page.title:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
	page.quota = UI.Text(page, 12)
	page.quota:SetPoint("LEFT", page.title, "RIGHT", 14, -1)
	page.front = UI.Text(page, 10, "전투 창과 같은 순서: 왼쪽이 뒤(힐러), 오른쪽이 맨 앞(탱커)")
	page.front:SetPoint("TOP", page, "TOP", 0, -239)
	UI.Color(page.front, UI.C.dim)

	page.create = UI.Button(page, 190, 32, "", function()
		local role = ns.Guide.MissingRole()
		create.open(nil, role)
	end, "primary")
	page.create:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
	page.auto = UI.Button(page, 100, 32, "자동 편성", autoForm, "blue")
	page.auto:SetPoint("RIGHT", page.create, "LEFT", -8, 0)
	UI.Tip(page.auto, function() return UI.SimpleTip("자동 편성", "빈 자리마다 그 역할의 대기 영웅 중 가장 강한 영웅을 넣습니다. 이미 출전한 영웅은 바꾸지 않습니다.") end)
	page.petsBtn = UI.Button(page, 90, 32, "동료", openPets, "dark")
	page.petsBtn:SetPoint("RIGHT", page.auto, "LEFT", -8, 0)

	page.slots = {}
	for k, slot in ipairs(LANE_ORDER) do
		page.slots[slot] = buildSlotCard(page, slot, 2 + (k - 1) * (CARD_W + 10))
	end

	-- roster
	page.rosterTitle = UI.Title(page, "", 14)
	page.rosterTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -258)
	page.filters = {}
	for i, f in ipairs(ROLE_FILTER) do
		local chip = UI.Chip(page, 64, 24, f[2], function()
			page.filter = f[1]
			page.slotSel = nil
			Main.Refresh()
		end)
		chip:SetPoint("TOPRIGHT", page, "TOPRIGHT", -(#ROLE_FILTER - i) * 70, -252)
		chip.role = f[1]
		page.filters[i] = chip
	end
	page.roster = {}
	for i = 1, ns.ROSTER_MAX do
		local card = CreateFrame("Button", nil, page)
		card:SetSize(R_W, R_H)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", ((i - 1) % 6) * (R_W + 8), -284 - floor((i - 1) / 6) * (R_H + 8))
		card.bg = UI.Slice(card, "card", "BACKGROUND")
		card.sel = UI.Art(card, "frame", "OVERLAY", 1, 0.85, 0.35)
		card.sel:SetAllPoints(card)
		card.sel:Hide()
		card.portrait = heroFigure(card, 42)
		card.portrait:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -8)
		card.portrait:EnableMouse(false)
		card.name = UI.Text(card, 12)
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -8)
		card.name:SetWidth(R_W - 58)
		card.name:SetWordWrap(false)
		card.spec = UI.Text(card, 10)
		card.spec:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -24)
		card.spec:SetWidth(R_W - 58)
		card.spec:SetWordWrap(false)
		UI.Color(card.spec, UI.C.sub)
		card.state = UI.Pill(card, 40, 15, 0.2, 0.6, 0.3, 1)
		card.state:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -39)
		card.action = UI.Button(card, R_W - 12, 22, "", nil, "dark")
		card.action:SetPoint("BOTTOM", card, "BOTTOM", 0, 6)
		card.action.clickWhenOff = true
		card:RegisterForClicks("LeftButtonUp")
		card:SetScript("OnClick", function(self)
			if not self.heroId then return end
			ns.Sound("click")
			if Main.SelectedHero() == self.heroId and self.lastClick and GetTime() - self.lastClick < 0.4 then
				Main.ShowTab("hero")
				return
			end
			self.lastClick = GetTime()
			Main.SelectHero(self.heroId)
		end)
		UI.Tip(card, function(self) return self.heroId and heroTip(self.heroId) end)
		page.roster[i] = card
	end
	page.empty = UI.Text(page, 13, "아직 보유한 영웅이 없습니다.\n오른쪽 위 '영웅 만들기'로 첫 영웅을 무료로 만드세요!")
	page.empty:SetPoint("TOP", page, "TOP", 0, -330)
	page.empty:SetJustifyH("CENTER")
end

local function refresh(page)
	local db = ns.db
	local count, limit = H.PartyCount(), ns.PartyLimit()
	page.title:SetText(string.format("출전 파티  %d / %d", count, limit))
	-- role quota: filled / open within the limit
	local have = { TANK = 0, DPS = 0, HEALER = 0 }
	local want = { TANK = 0, DPS = 0, HEALER = 0 }
	for i = 1, ns.PARTY_SIZE do
		local role = ns.PARTY_ROLES[i]
		want[role] = want[role] + 1
		if db.party[i] then have[role] = have[role] + 1 end
	end
	local parts = {}
	for _, role in ipairs({ "TANK", "DPS", "HEALER" }) do
		local col = have[role] >= want[role] and "60e070" or (have[role] > 0 and "ffd24a" or "ff6a5a")
		parts[#parts + 1] = U.col(col, string.format("%s %d/%d", ns.N(ns.ROLE[role].name), have[role], want[role]))
	end
	page.quota:SetText(table.concat(parts, "   "))
	local sel = Main.SelectedHero()

	for slot, card in pairs(page.slots) do
		local id = db.party[slot]
		card.portrait:Hide()
		card.portrait.fig:Hide()
		card.plus:Hide()
		card.lock:Hide()
		card.stat:SetText("")
		card.sel:SetShown((id and id == sel) or page.slotSel == slot)
		if id and db.heroes[id] then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			card.bg:SetColor(0.42, 0.46, 0.62, 1)
			card.portrait:SetHeroFigure(id)
			card.portrait:SetBadge(ns.Guide.HeroNeeds(id))
			card.portrait:Show()
			card.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.Name(id)))
			card.spec:SetText(string.format("Lv %d  ·  %s", h.level, ns.SpecLabel(h.spec)))
			card.stat:SetText(roleStat(id))
			card.action:SetLabel("휴식")
			card.action:SetStyle("dark")
			card.action:SetOff(count <= 1)
			card.action.onClick = function() UI.Try(H.Withdraw(id)) end
		elseif count >= limit then
			card.bg:SetColor(0.26, 0.27, 0.32, 1)
			card.lock:Show()
			card.name:SetText(U.col("9a8f78", "잠긴 자리"))
			card.spec:SetText("지휘의 룬으로 열립니다")
			card.action:SetLabel("룬 보러 가기")
			card.action:SetStyle("blue")
			card.action:SetOff(false)
			card.action.onClick = function() Main.ShowTab("runes", { rune = nextCommandRune() }) end
		else
			card.bg:SetColor(0.30, 0.33, 0.44, 1)
			card.plus:Show()
			local role = ns.PARTY_ROLES[slot]
			card.name:SetText(U.col("b8c0d8", "빈 자리"))
			card.spec:SetText(string.format("%s 영웅을 넣으세요", ns.N(ns.ROLE[role].name)))
			local bench, bp
			for _, hid in ipairs(H.List()) do
				if not H.PartySlot(hid) and H.Role(hid) == role then
					local p = ns.Stats.Power(hid)
					if not bp or p > bp then bench, bp = hid, p end
				end
			end
			if bench then
				card.action:SetLabel("출전: " .. H.ShortName(bench))
				card.action:SetStyle("green")
				card.action:SetOff(false)
				card.action.onClick = function() UI.Try(H.Deploy(bench, slot)) end
			else
				card.action:SetLabel(ns.N(ns.ROLE[role].name) .. " 만들기")
				card.action:SetStyle("green")
				card.action:SetOff(H.Count() >= ns.ROSTER_MAX)
				card.action.onClick = function() create.open(nil, role) end
			end
		end
	end

	-- roster
	local all = H.List()
	local list = {}
	for _, id in ipairs(all) do
		if not page.filter or H.Role(id) == page.filter then list[#list + 1] = id end
	end
	page.rosterTitle:SetText(string.format("보유 영웅  %d / %d", #all, ns.ROSTER_MAX))
	for _, chip in ipairs(page.filters) do chip:SetOn(chip.role == page.filter) end
	local cost = H.CreateCost()
	page.create:SetLabel("영웅 만들기  " .. (cost > 0 and U.fmt(cost) .. " G" or "무료"))
	page.create:SetOff(#all >= ns.ROSTER_MAX or not ns.CanAfford(cost))
	page.create:SetBadge(ns.Guide.MissingRole() ~= nil and #all < ns.ROSTER_MAX and ns.CanAfford(cost))
	page.empty:SetShown(#all == 0)
	page.auto:SetOff(count >= limit)

	for i, card in ipairs(page.roster) do
		local id = list[i]
		card.heroId = id
		if id then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			card.portrait:SetHeroFigure(id)
			card.portrait:SetBadge(H.PartySlot(id) ~= nil and ns.Guide.HeroNeeds(id))
			card.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.Name(id)))
			card.spec:SetText(ns.SpecLabel(h.spec))
			card.sel:SetShown(id == sel)
			if H.PartySlot(id) then
				card.bg:SetColor(0.40, 0.50, 0.48, 1)
				card.state:SetColor(0.2, 0.55, 0.3, 1)
				card.state:SetLabel("출전")
				card.action:SetLabel("휴식")
				card.action:SetStyle("dark")
				card.action:SetOff(H.PartyCount() <= 1)
				card.action.onClick = function()
					if H.PartyCount() <= 1 then
						UI.Try(false, "마지막 출전 영웅은 쉬게 할 수 없습니다.")
					else
						UI.Try(H.Withdraw(id))
					end
				end
			else
				card.bg:SetColor(0.34, 0.37, 0.50, 1)
				card.state:SetColor(0.3, 0.33, 0.42, 1)
				card.state:SetLabel("대기")
				local target = page.slotSel and ns.PARTY_ROLES[page.slotSel] == H.Role(id) and page.slotSel
				local act, s = fieldAction(id)
				if target then
					local who = db.party[target]
					card.action:SetLabel(who and ("교체: " .. H.ShortName(who)) or "여기에 출전")
					card.action:SetStyle("green")
					card.action:SetOff(false)
					card.action.onClick = function() field(id, target) page.slotSel = nil Main.Refresh() end
				elseif act == "swap" then
					card.action:SetLabel("교체: " .. H.ShortName(db.party[s]))
					card.action:SetStyle("green")
					card.action:SetOff(false)
					card.action.onClick = function() field(id) end
				elseif act == "deploy" then
					card.action:SetLabel("출전")
					card.action:SetStyle("green")
					card.action:SetOff(false)
					card.action.onClick = function() field(id) end
				else
					card.action:SetLabel("출전 (자리 없음)")
					card.action:SetStyle("dark")
					card.action:SetOff(true)
					card.action.onClick = function()
						UI.Try(false, string.format("%s 자리가 없습니다. '지휘의 룬'으로 파티 인원을 늘리세요.", ns.N(ns.ROLE[H.Role(id)].name)))
					end
				end
			end
			card:Show()
		else
			card:Hide()
		end
	end
end

local function open(page, opts)
	if opts and opts.create then
		refresh(page)
		create.open(nil, opts.create ~= true and opts.create or ns.Guide.MissingRole())
	end
end

Main.RegisterTab({
	key = "party", title = "편성", sub = "출전할 영웅을 정하고 새 영웅을 만듭니다",
	icon = "INV_Misc_GroupNeedMore", art = "icon_party", build = build, refresh = refresh, open = open,
	events = { "PARTY", "HEROES", "LEVEL", "RUNES", "PETS", "RESET", "GEAR", "TREE", "SKILLS", "FACTION" },
})
