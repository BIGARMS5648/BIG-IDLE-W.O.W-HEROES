-- Party screen (편성), built from the screen kit (UI/Layout.lua), no tab row:
--   list: the five party slots in battle order (healer at the back on the
--         left, the tank in front on the right) under a header with what
--         acts on the party (자동 편성, 동료); every hero you own under a
--         header with the role filter, and a "+" card to make a new hero;
--   card: the chosen hero or slot, and what to do with it.
-- Also here: hero creation, renaming, companions and the faction choice.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes

local K = UI.K
local LANE_ORDER = { 5, 4, 3, 2, 1 } -- healer at the back ... tank in front
local ROLE_TABS = { { "ALL", "전체" }, { "TANK", "탱커" }, { "DPS", "딜러" }, { "HEALER", "힐러" } }

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

-- Can auto-form put anyone in? (a bench hero whose role has a free slot)
local function canAutoForm()
	if H.PartyCount() >= ns.PartyLimit() then return false end
	for _, id in ipairs(H.List()) do
		if not H.PartySlot(id) and H.FreeSlot(H.Role(id)) then return true end
	end
	return false
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
	-- two per line
	local lines = {}
	for i = 1, #parts, 2 do
		lines[#lines + 1] = parts[i] .. (parts[i + 1] and ("   ·   " .. parts[i + 1]) or "")
	end
	return table.concat(lines, "\n")
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
		crest:SetSize(72, 72)
		crest:SetPoint("TOP", half, "TOP", 0, -18)
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
	right:SetSize(314, 362)
	right:SetPoint("TOPLEFT", c, "TOPLEFT", 486, -50)
	create.specs = {}
	for i = 1, 4 do
		local b = CreateFrame("Button", nil, right)
		b:SetSize(314, 66)
		b:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(i - 1) * 70)
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
	create.skillsTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -286)
	UI.Color(create.skillsTitle, UI.C.sub)
	create.skills = {}
	for i = 1, 6 do
		local s = UI.IconButton(right, 40)
		s:SetPoint("TOPLEFT", right, "TOPLEFT", (i - 1) * 52, -304)
		s.lv = UI.Text(right, K.F_MIN)
		s.lv:SetPoint("TOP", s, "BOTTOM", 0, -2)
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
	local c = Main.ModalContent(680, 400)
	pets.frame = c
	local title = UI.Title(c, "동료", 18)
	title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	local sub = UI.Text(c, K.F_SMALL, "조건을 채우면 얻습니다. 얻은 동료의 효과는 모두 항상 적용되고, 데리고 다니는 동료는 전투 창에 함께 보입니다.")
	sub:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -26)
	sub:SetWidth(680)
	UI.Color(sub, UI.C.sub)
	local list = UI.Panel(c, 368, 346, "inset")
	list:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	pets.rows = {}
	for i, pet in ipairs(ns.PETS) do
		local row = UI.Row(list, 344, 38, function(self)
			pets.sel = self.pet.id
			pets.refresh()
		end)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", 12, -12 - (i - 1) * 41)
		row:Layout(110)
		row.pet = pet
		row.icon:SetIconName(pet.icon)
		pets.rows[i] = row
	end
	pets.card = UI.Card(c, 300, 346)
	pets.card:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	local d = pets.card
	pets.bonusHead = UI.Section(d.content, d.IN, "효과")
	pets.bonusHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	pets.bonus = UI.Text(d.content, K.F_BODY)
	pets.bonus:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -28)
	pets.bonus:SetWidth(d.IN)
	pets.bonus:SetJustifyV("TOP")
	pets.condHead = UI.Section(d.content, d.IN, "얻는 조건")
	pets.condHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -92)
	pets.cond = UI.Text(d.content, K.F_SMALL)
	pets.cond:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -120)
	pets.cond:SetWidth(d.IN)
	pets.bar = UI.Bar(d.content, d.IN, 14, 0.3, 0.6, 1)
	pets.bar:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -158)
end

function pets.refresh()
	local db = ns.db
	if not pets.sel then pets.sel = db.pet or ns.PETS[1].id end
	local selPet
	for _, row in ipairs(pets.rows) do
		local p = row.pet
		local owned = db.pets[p.id]
		row.icon:SetDim(not owned)
		row.title:SetText(owned and ns.N(p.name) or U.col("8a90a2", ns.N(p.name)))
		local have, need = ns.PetProgress(p)
		row.sub:SetText(owned and "얻음" or string.format("%s / %s", U.fmt(min(have, need)), U.fmt(need)))
		if db.pet == p.id then
			row.right:SetText(U.col("60e070", "데리고 다님"))
		elseif owned then
			row.right:SetText(U.col("aab3c8", "얻음"))
		else
			row.right:SetText(U.col("8a90a2", "미획득"))
		end
		row:SetSelected(p.id == pets.sel)
		if p.id == pets.sel then selPet = p end
	end
	local p = selPet or ns.PETS[1]
	local owned = db.pets[p.id]
	local d = pets.card
	d:Head({ icon = p.icon, dim = not owned, title = ns.N(p.name), sub = owned and (db.pet == p.id and "데리고 다니는 중" or "얻은 동료") or "아직 얻지 못함" })
	local parts = {}
	for k, v in pairs(p.bonus) do parts[#parts + 1] = ns.BonusText(k, v) end
	table.sort(parts)
	pets.bonus:SetText(table.concat(parts, "\n"))
	pets.bonus:SetTextColor(owned and 0.4 or 0.7, owned and 1 or 0.72, owned and 0.45 or 0.78)
	local have, need = ns.PetProgress(p)
	pets.cond:SetText(ns.PetUnlockText(p))
	pets.bar:SetValue(have / need)
	pets.bar:SetLabel(U.fmt(min(have, need)) .. " / " .. U.fmt(need))
	pets.bar:SetRGB(0.3, owned and 0.9 or 0.6, owned and 0.35 or 1)
	local close = { "닫기", function() Main.CloseModal() end, "dark" }
	if not owned then
		d:Actions(close, { "아직 얻지 못함", nil, "primary", true })
	elseif db.pet == p.id then
		d:Actions(close, { "데리고 다니는 중", nil, "primary", true })
	else
		d:Actions(close, { "데리고 다니기", function()
			ns.db.pet = p.id
			pets.refresh()
			Main.MarkDirty("party")
		end, "primary" })
	end
end

local function openPets()
	if not pets.frame then buildPets() end
	pets.refresh()
	Main.ShowModal(pets.frame)
end

------------------------------------------------------------------------
-- Rename (modal): preview a new name before keeping it
------------------------------------------------------------------------
local rename = {}

local function buildRename()
	local c = Main.ModalContent(420, 180)
	rename.frame = c
	local t = UI.Title(c, "이름 바꾸기", 18)
	t:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	rename.old = UI.Text(c, 12)
	rename.old:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -32)
	rename.old:SetWidth(420)
	rename.old:SetWordWrap(false)
	UI.Color(rename.old, UI.C.sub)
	local box = UI.Panel(c, 420, 46, "inset")
	box:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -56)
	rename.new = UI.Text(box, 18)
	rename.new:SetPoint("LEFT", box, "LEFT", 14, 0)
	rename.new:SetWidth(310)
	rename.new:SetWordWrap(false)
	local reroll = UI.Button(box, 70, 32, "다시", function()
		local h = ns.db.heroes[rename.id]
		rename.name = H.RollName(h.spec, h.sex)
		rename.refresh()
	end, "blue")
	reroll:SetPoint("RIGHT", box, "RIGHT", -7, 0)
	local cancel = UI.Button(c, 120, K.BTN_H, "취소", function() Main.CloseModal() end, "dark")
	cancel:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	local ok = UI.Button(c, 180, K.BTN_H, "이 이름으로", function()
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

function ns.OpenRename(id)
	if not ns.db.heroes[id] then return end
	if not rename.frame then buildRename() end
	local h = ns.db.heroes[id]
	rename.id = id
	rename.name = H.RollName(h.spec, h.sex)
	rename.refresh()
	Main.ShowModal(rename.frame)
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local ROLE_ICON = { TANK = "Ability_Warrior_DefensiveStance", DPS = "Ability_DualWield", HEALER = "Spell_Holy_FlashHeal" }
local SLOT_W, SLOT_H = 96, 112        -- party slots (5 in a row)
local SLOT_Y = -38
local CARD_W, CARD_H = 78, 88         -- roster cards (6 in a row)
local ROSTER_Y = -188
local ROSTER_STEP_X = (K.LIST_IN - CARD_W) / 5

local function nextCommandRune()
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		for _, node in ipairs(br.nodes) do
			if node.stat == "party" and ns.Runes.Level(node.id) == 0 then return node.id end
		end
	end
end

-- the selection: { hero = id } or { slot = n }
local function pickHero(page, id)
	if page.sel and page.sel.hero == id and page.lastPick and GetTime() - page.lastPick < 0.4 then
		Main.SelectHero(id)
		Main.ShowTab("hero")
		return
	end
	page.lastPick = GetTime()
	page.sel = { hero = id }
	Main.SelectHero(id)
	Main.Refresh()
end

local function pickSlot(page, slot)
	local id = ns.db.party[slot]
	if id then return pickHero(page, id) end
	page.sel = { slot = slot }
	page.filter = ns.PARTY_ROLES[slot]
	Main.Refresh()
end

local function buildSlot(page, slot, k)
	local list = page.S.list
	local card = CreateFrame("Button", nil, list)
	card:SetSize(SLOT_W, SLOT_H)
	card:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD + (k - 1) * (SLOT_W + 8), SLOT_Y)
	card.isItem = true
	card.bg = UI.Slice(card, "card", "BACKGROUND")
	card.sel = UI.SelFrame(card)
	card.slot = slot
	local role = ns.PARTY_ROLES[slot]
	local r, g, b = U.rgb(ns.ROLE[role].hex)
	card.band = card:CreateTexture(nil, "BORDER")
	card.band:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
	card.band:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
	card.band:SetHeight(20)
	UI.Fill(card.band, r * 0.42, g * 0.42, b * 0.42, 0.95)
	card.roleIcon = UI.Glyph(card, ns.ROLE[role].art, 14, r, g, b)
	card.roleIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 9, -7)
	card.roleText = UI.Text(card, K.F_SMALL, ns.N(ns.ROLE[role].name))
	card.roleText:SetPoint("LEFT", card.roleIcon, "RIGHT", 4, 0)
	card.portrait = UI.Portrait(card, 44)
	card.portrait:SetPoint("TOP", card, "TOP", 0, -30)
	card.portrait:EnableMouse(false)
	card.portrait.lvl:Hide()
	card.plus = UI.Glyph(card, "plus", 30, 0.55, 0.62, 0.8)
	card.plus:SetPoint("TOP", card, "TOP", 0, -36)
	card.lock = UI.Glyph(card, "lock", 28, 0.75, 0.65, 0.45)
	card.lock:SetPoint("TOP", card, "TOP", 0, -38)
	card.name = UI.Text(card, K.F_BODY)
	card.name:SetPoint("TOP", card, "TOP", 0, -78)
	card.name:SetWidth(SLOT_W - 8)
	card.name:SetJustifyH("CENTER")
	card.name:SetWordWrap(false)
	card.spec = UI.Text(card, K.F_MIN)
	card.spec:SetPoint("TOP", card, "TOP", 0, -95)
	card.spec:SetWidth(SLOT_W - 8)
	card.spec:SetJustifyH("CENTER")
	card.spec:SetWordWrap(false)
	UI.Color(card.spec, UI.C.sub)
	card:RegisterForClicks("LeftButtonUp")
	card:SetScript("OnClick", function(self)
		ns.Sound("click")
		pickSlot(page, self.slot)
	end)
	UI.Tip(card, function(self)
		local id = ns.db.party[self.slot]
		if id then return heroTip(id) end
		local rn = ns.N(ns.ROLE[ns.PARTY_ROLES[self.slot]].name)
		if self.locked then
			return UI.SimpleTip("잠긴 자리", "룬 화면의 '지휘의 룬'을 배우면 파티 자리가 하나씩 열립니다.")
		end
		return UI.SimpleTip(rn .. " 자리", "비어 있습니다. 누르면 오른쪽에 넣을 수 있는 " .. rn .. "가 나옵니다.\n전투 창과 같은 순서입니다: 왼쪽이 뒤(힐러), 오른쪽이 맨 앞(탱커).")
	end, "TOP")
	return card
end

-- where the i-th card of the roster grid goes
local function rosterAt(page, card, i)
	local col, row = (i - 1) % 6, floor((i - 1) / 6)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", page.S.list, "TOPLEFT", floor(K.PAD + col * ROSTER_STEP_X), ROSTER_Y - row * (CARD_H + 8))
end

local function buildRosterCard(page, i)
	local list = page.S.list
	local card = CreateFrame("Button", nil, list)
	card:SetSize(CARD_W, CARD_H)
	rosterAt(page, card, i)
	card.isItem = true
	card.bg = UI.Slice(card, "card", "BACKGROUND")
	card.sel = UI.SelFrame(card)
	card.state = UI.Pill(card, 34, 16, 0.2, 0.6, 0.3, 1)
	card.state:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
	card.role = UI.Glyph(card, "role_tank", 14)
	card.role:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -5)
	card.portrait = UI.Portrait(card, 32)
	card.portrait:SetPoint("TOP", card, "TOP", 0, -20)
	card.portrait:EnableMouse(false)
	card.portrait.lvl:Hide()
	card.portrait.role:SetAlpha(0)
	card.name = UI.Text(card, K.F_BODY)
	card.name:SetPoint("TOP", card, "TOP", 0, -55)
	card.name:SetWidth(CARD_W - 6)
	card.name:SetJustifyH("CENTER")
	card.name:SetWordWrap(false)
	card.spec = UI.Text(card, K.F_MIN)
	card.spec:SetPoint("TOP", card, "TOP", 0, -71)
	card.spec:SetWidth(CARD_W - 6)
	card.spec:SetJustifyH("CENTER")
	card.spec:SetWordWrap(false)
	UI.Color(card.spec, UI.C.sub)
	card:RegisterForClicks("LeftButtonUp")
	card:SetScript("OnClick", function(self)
		if not self.heroId then return end
		ns.Sound("click")
		pickHero(page, self.heroId)
	end)
	UI.Tip(card, function(self) return self.heroId and heroTip(self.heroId) or nil end, "TOP")
	return card
end

-- the "+" card after the heroes: make a new one
local function buildCreateCard(page)
	local card = CreateFrame("Button", nil, page.S.list)
	card:SetSize(CARD_W, CARD_H)
	card.bg = UI.Slice(card, "card", "BACKGROUND")
	card.bg:SetColor(0.22, 0.25, 0.34, 1)
	card.plus = UI.Glyph(card, "plus", 30, 0.70, 0.80, 1)
	card.plus:SetPoint("TOP", card, "TOP", 0, -14)
	card.name = UI.Text(card, K.F_BODY, "영웅 만들기")
	card.name:SetPoint("TOP", card, "TOP", 0, -55)
	card.name:SetWidth(CARD_W - 6)
	card.name:SetJustifyH("CENTER")
	card.name:SetWordWrap(false)
	card.cost = UI.Text(card, K.F_MIN)
	card.cost:SetPoint("TOP", card, "TOP", 0, -71)
	card.cost:SetWidth(CARD_W - 6)
	card.cost:SetJustifyH("CENTER")
	card.cost:SetWordWrap(false)
	card.badge = UI.Badge(card, 14)
	card.badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", 3, 3)
	card:RegisterForClicks("LeftButtonUp")
	card:SetScript("OnClick", function(self)
		ns.Sound("click")
		if self.why then UI.Try(false, self.why) return end
		create.open(nil, ns.Guide.MissingRole())
	end)
	UI.Tip(card, function() return UI.SimpleTip("영웅 만들기", "직업과 전문화, 성별과 이름을 정해 새 영웅을 만듭니다. 영웅이 많을수록 비용이 오릅니다.") end, "TOP")
	return card
end

local function build(page)
	page.filter = nil
	local S = UI.Screen(page, { noTop = true })
	page.S = S

	local list = S.list
	-- the party, and what acts on it
	page.partyHead = UI.Section(list, K.LIST_IN)
	page.partyHead:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, -K.PAD)
	page.auto = page.partyHead:AddTool(UI.Button(list, 84, 22, "자동 편성", autoForm, "blue"))
	page.auto.clickWhenOff = true
	UI.Tip(page.auto, function() return UI.SimpleTip("자동 편성", "빈 자리마다 그 역할의 대기 영웅 중 가장 강한 영웅을 넣습니다. 이미 출전한 영웅은 바꾸지 않습니다.") end, "TOP")
	page.petsBtn = page.partyHead:AddTool(UI.Button(list, 60, 22, "동료", openPets, "dark"))
	UI.Tip(page.petsBtn, function() return UI.SimpleTip("동료", "조건을 채우면 얻는 동료와 그 효과를 봅니다. 동료는 파티와 함께 싸웁니다.") end, "TOP")
	page.slots = {}
	for k, slot in ipairs(LANE_ORDER) do page.slots[slot] = buildSlot(page, slot, k) end
	-- the heroes you own, the role filter, and a new hero
	page.rosterHead = UI.Section(list, K.LIST_IN)
	page.rosterHead:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, -162)
	page.filterTabs = UI.Tabs(list, 236, ROLE_TABS, function(key)
		page.filter = key ~= "ALL" and key or nil
		Main.Refresh()
	end, true, 22)
	page.rosterHead:AddTool(page.filterTabs)
	page.roster = {}
	for i = 1, ns.ROSTER_MAX do page.roster[i] = buildRosterCard(page, i) end
	page.create = buildCreateCard(page)

	-- the card's list of heroes for an empty slot
	local d = S.card
	page.slotRows = {}
	for i = 1, 4 do
		local row = UI.Row(d.content, K.CARD_IN, 44, function(self) if self.heroId then pickHero(page, self.heroId) end end)
		row:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -26 - (i - 1) * 50)
		row:Layout(80)
		page.slotRows[i] = row
	end
	page.cardHead = UI.Section(d.content, K.CARD_IN)
	page.cardHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	page.cardText = UI.Text(d.content, K.F_SMALL)
	page.cardText:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -28)
	page.cardText:SetWidth(K.CARD_IN)
	page.cardText:SetJustifyV("TOP")
	UI.Color(page.cardText, UI.C.sub)
	page.stats = {}
	for i = 1, 8 do
		local r = UI.StatRow(d.content, K.CARD_IN)
		r:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -(i - 1) * 24)
		page.stats[i] = r
	end
end

local function benchOf(role)
	local out = {}
	for _, id in ipairs(H.List()) do
		if not H.PartySlot(id) and H.Role(id) == role then out[#out + 1] = id end
	end
	table.sort(out, function(a, b) return ns.Stats.Power(a) > ns.Stats.Power(b) end)
	return out
end

local function hideCardParts(page)
	for _, r in ipairs(page.slotRows) do r:Hide() end
	for _, r in ipairs(page.stats) do r:Hide() end
	page.cardHead:Hide()
	page.cardText:SetText("")
end

local function refreshCard(page)
	local db = ns.db
	local d = page.S.card
	hideCardParts(page)
	d:Extras(nil, nil)
	local sel = page.sel or {}
	local id = sel.hero and db.heroes[sel.hero] and sel.hero

	if H.Count() == 0 then
		d:Head({ title = "영웅이 없습니다", sub = "첫 영웅은 무료입니다" })
		page.cardText:ClearAllPoints()
		page.cardText:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
		page.cardText:SetText("직업과 전문화를 골라 첫 영웅을 만드세요. 만든 영웅은 비어 있는 자리에 바로 들어가 싸웁니다.")
		d:Actions(nil, { "첫 영웅 만들기", function() create.open(nil, ns.Guide.MissingRole()) end })
		return
	end

	if id then
		local h = db.heroes[id]
		local sp = ns.SPECS[h.spec]
		local s = ns.Stats.Get(id)
		local race = ns.RACES[H.Race(id)]
		d:Head({ hero = id, title = H.Name(id), titleRGB = { U.rgb(ns.CLASSES[sp.class].hex) },
			sub = string.format("Lv %d · %s · %s", h.level, ns.SpecLabel(h.spec), ns.N(ns.ROLE[sp.role].name)) })
		local slot = H.PartySlot(id)
		local rows = {
			{ "상태", slot and U.col("60e070", "출전 중") or U.col("aab3c8", "대기 중") },
			{ "초당 피해", U.fmt(ns.Stats.DPS(s)) },
			{ "생명력", U.fmt(s.hp) },
		}
		if sp.role == "HEALER" then rows[#rows + 1] = { "치유량", "+" .. U.num(s.heal, 0) .. "%" }
		else rows[#rows + 1] = { "방어도", U.fmt(s.armor) } end
		rows[#rows + 1] = { "남은 특성 점수", H.PointsFree(id) > 0 and U.col("60e070", tostring(H.PointsFree(id))) or "0" }
		rows[#rows + 1] = { "남은 기술 점수", H.SkillPointsFree(id) > 0 and U.col("60e070", tostring(H.SkillPointsFree(id))) or "0" }
		rows[#rows + 1] = { "종족", (race and race.name or "") .. " " .. ns.SEX[H.Sex(id)].name }
		for i, r in ipairs(page.stats) do
			local v = rows[i]
			if v then r:Set(v[1], v[2]) r:Show() else r:Hide() end
		end
		d:Extras({ "이름 바꾸기", function() ns.OpenRename(id) end, "dark" },
			{ "떠나보내기", function()
				UI.Confirm({ title = "영웅 떠나보내기", ok = "떠나보내기", style = "red",
					text = string.format("%s을(를) 떠나보내시겠습니까?\n장착한 장비는 가방으로 돌아오지만, 영웅은 되돌릴 수 없습니다.", H.Name(id)),
					onOk = function()
						if UI.Try(H.Dismiss(id)) then
							page.sel = nil
							Main.SelectHero(nil)
						end
					end })
			end, "red", H.Count() <= 1, tip = { "떠나보내기", "영웅이 영영 떠납니다. 장착한 장비는 가방으로 돌아옵니다." } })
		local view = { "영웅 화면", function() Main.SelectHero(id) Main.ShowTab("hero") end, "dark" }
		if slot then
			d:Actions({ "휴식", function()
				if H.PartyCount() <= 1 then UI.Try(false, "마지막 출전 영웅은 쉬게 할 수 없습니다.") return end
				UI.Try(H.Withdraw(id))
			end, "dark", H.PartyCount() <= 1, tip = { "휴식", "파티에서 빼고 대기시킵니다. 자리는 비게 됩니다." } },
				{ "영웅 화면", view[2], "primary" })
		else
			local act, s2 = fieldAction(id)
			if act == "swap" then
				d:Actions(view, { "교체 출전", function() field(id) end, "primary",
					tip = { "교체 출전", string.format("%s 자리가 가득 차 있어 가장 약한 %s와 바꿉니다.", ns.N(ns.ROLE[sp.role].name), H.Name(db.party[s2])) } })
			elseif act == "deploy" then
				d:Actions(view, { "출전", function() field(id) end, "primary" })
			else
				d:Actions(view, { "자리 없음", function() UI.Try(false, "자리가 없습니다. '지휘의 룬'으로 파티 인원을 늘리세요.") end, "primary", true })
				d:Reason("파티가 가득 찼습니다. '지휘의 룬'으로 자리를 늘리세요.")
			end
		end
		return
	end

	-- an empty or locked slot
	local slot = sel.slot or 1
	local role = ns.PARTY_ROLES[slot]
	local rn = ns.N(ns.ROLE[role].name)
	local locked = H.PartyCount() >= ns.PartyLimit() and not db.party[slot]
	if locked then
		d:Head({ icon = "INV_Misc_Key_03", title = "잠긴 자리", sub = "지휘의 룬으로 열립니다" })
		page.cardText:ClearAllPoints()
		page.cardText:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
		page.cardText:SetText("파티 인원은 룬 화면의 '지휘의 룬'을 배울 때마다 한 명씩 늘어납니다.")
		d:Actions(nil, { "룬 화면에서 열기", function() Main.ShowTab("runes", { rune = nextCommandRune() }) end })
		return
	end
	d:Head({ icon = ROLE_ICON[role], title = rn .. " 자리", sub = "비어 있음" })
	local bench = benchOf(role)
	page.cardHead:Set("넣을 수 있는 " .. rn, #bench > 0 and (#bench .. "명") or "")
	page.cardHead:Show()
	if #bench == 0 then
		page.cardText:ClearAllPoints()
		page.cardText:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -28)
		page.cardText:SetText("대기 중인 " .. rn .. "가 없습니다. 새로 만드세요.")
	end
	for i, row in ipairs(page.slotRows) do
		local hid = bench[i]
		row.heroId = hid
		if hid then
			local h = db.heroes[hid]
			UI.SetHeroIcon(row.icon.icon, hid)
			row.icon.icon:Show()
			row.icon:SetQuality(nil)
			row.title:SetText(U.col(ns.CLASSES[ns.SPECS[h.spec].class].hex, H.Name(hid)))
			row.sub:SetText("Lv " .. h.level .. " · " .. ns.SpecLabel(h.spec))
			row.right:SetText(U.col("ffd24a", U.fmt(ns.Stats.Power(hid))))
			row:SetSelected(false)
			row:Show()
		else
			row:Hide()
		end
	end
	local cost = H.CreateCost()
	d:Actions(nil, { rn .. " 만들기  " .. (cost > 0 and U.fmt(cost) .. " G" or "무료"), function() create.open(nil, role) end, "primary",
		H.Count() >= ns.ROSTER_MAX or not ns.CanAfford(cost) })
	if H.Count() >= ns.ROSTER_MAX then
		d:Reason("보유 영웅이 가득 찼습니다 (" .. ns.ROSTER_MAX .. "명).")
	elseif not ns.CanAfford(cost) then
		d:Reason("골드가 부족합니다 (" .. U.fmt(cost) .. " G 필요).")
	end
end

local function refresh(page)
	local db = ns.db
	local S = page.S
	local count, limit = H.PartyCount(), ns.PartyLimit()
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
	page.partyHead:Set(string.format("출전 파티  %d / %d", count, limit), table.concat(parts, " "))

	-- the selection: keep it valid; default to the first party hero
	local sel = page.sel
	if sel and sel.hero and not db.heroes[sel.hero] then sel = nil end
	if sel and sel.slot and db.party[sel.slot] then sel = { hero = db.party[sel.slot] } end
	if not sel then
		local first = UI.HeroOrder()[1]
		sel = first and { hero = first } or nil
	end
	page.sel = sel

	for slot, card in pairs(page.slots) do
		local id = db.party[slot]
		card.portrait:Hide()
		card.plus:Hide()
		card.lock:Hide()
		card.locked = false
		card.sel:SetShown(sel ~= nil and ((id and sel.hero == id) or sel.slot == slot))
		if id and db.heroes[id] then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			card.bg:SetColor(0.42, 0.46, 0.62, 1)
			card.portrait:SetHero(id)
			UI.SetHeroIcon(card.portrait.icon, id)
			card.portrait.lvl:Hide()
			card.portrait:SetBadge(ns.Guide.HeroNeeds(id))
			card.portrait:Show()
			card.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.ShortName(id)))
			card.spec:SetText("Lv " .. h.level .. " " .. ns.SpecLabel(h.spec))
		elseif count >= limit then
			card.locked = true
			card.bg:SetColor(0.26, 0.27, 0.32, 1)
			card.lock:Show()
			card.name:SetText(U.col("9a8f78", "잠긴 자리"))
			card.spec:SetText("지휘의 룬")
		else
			card.bg:SetColor(0.30, 0.33, 0.44, 1)
			card.plus:Show()
			card.name:SetText(U.col("b8c0d8", "빈 자리"))
			card.spec:SetText("눌러서 채우기")
		end
	end

	-- the role filter in the roster's header
	local all = H.List()
	local n = { TANK = 0, DPS = 0, HEALER = 0 }
	for _, id in ipairs(all) do n[H.Role(id)] = n[H.Role(id)] + 1 end
	local ft = page.filterTabs
	ft:Select(page.filter or "ALL")
	ft:SetLabel("ALL", "전체 " .. #all)
	ft:SetLabel("TANK", "탱커 " .. n.TANK)
	ft:SetLabel("DPS", "딜러 " .. n.DPS)
	ft:SetLabel("HEALER", "힐러 " .. n.HEALER)
	local list = {}
	for _, id in ipairs(all) do
		if not page.filter or H.Role(id) == page.filter then list[#list + 1] = id end
	end
	page.rosterHead:Set("보유 영웅", string.format("%d / %d", #all, ns.ROSTER_MAX))
	for i, card in ipairs(page.roster) do
		local id = list[i]
		card.heroId = id
		if id then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			card.portrait:SetHero(id)
			UI.SetHeroIcon(card.portrait.icon, id)
			card.portrait.lvl:Hide()
			card.portrait:SetBadge(H.PartySlot(id) ~= nil and ns.Guide.HeroNeeds(id))
			card.name:SetText(U.col(ns.CLASSES[sp.class].hex, H.ShortName(id)))
			card.spec:SetText("Lv " .. h.level .. " " .. ns.N(ns.CLASSES[sp.class].name))
			UI.SetGlyph(card.role, ns.ROLE[sp.role].art, U.rgb(ns.ROLE[sp.role].hex))
			card.sel:SetShown(sel ~= nil and sel.hero == id)
			if H.PartySlot(id) then
				card.bg:SetColor(0.38, 0.50, 0.46, 1)
				card.state:SetColor(0.18, 0.55, 0.28, 1)
				card.state:SetLabel("출전")
			else
				card.bg:SetColor(0.34, 0.37, 0.50, 1)
				card.state:SetColor(0.28, 0.31, 0.40, 1)
				card.state:SetLabel("대기")
			end
			card:Show()
		else
			card:Hide()
		end
	end
	S.Empty(#all == 0 and "" or nil)
	-- the "+" card right after the last hero shown
	local cost = H.CreateCost()
	local cc = page.create
	if #all >= ns.ROSTER_MAX then
		cc:Hide()
	else
		rosterAt(page, cc, #list + 1)
		local afford = ns.CanAfford(cost)
		cc.cost:SetText(U.col(afford and "ffd24a" or "ff6a5a", cost > 0 and (U.fmt(cost) .. " G") or "무료"))
		cc.why = not afford and "골드가 부족합니다." or nil
		cc.plus:SetAlpha(afford and 1 or 0.45)
		cc.name:SetAlpha(afford and 1 or 0.6)
		cc.badge:Set(ns.Guide.MissingRole() ~= nil and afford)
		cc:Show()
	end
	page.auto:SetOff(not canAutoForm())
	refreshCard(page)
end

local function open(page, opts)
	if opts and opts.create then
		refresh(page)
		create.open(nil, opts.create ~= true and opts.create or ns.Guide.MissingRole())
	end
end

local function tick(page) end

Main.RegisterTab({
	key = "party", title = "편성", sub = "출전할 영웅을 정하고 새 영웅을 만듭니다",
	icon = "INV_Misc_GroupNeedMore", art = "icon_party", build = build, refresh = refresh, open = open, tick = tick,
	events = { "PARTY", "HEROES", "LEVEL", "RUNES", "PETS", "RESET", "GEAR", "TREE", "SKILLS", "FACTION" },
})
