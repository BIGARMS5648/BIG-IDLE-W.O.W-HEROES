-- Party screen (편성): the five slots in battle order (healer at the back
-- on the left, the tank in front on the right) as large cards with
-- [<] [빼기] [>], the party's power, and the heroes who wait below.
-- Also here: hero creation, renaming and the faction choice (the other
-- screens open them through ns.OpenCreate, ns.OpenRename, ns.PickFaction).
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

-- Why a waiting hero cannot go in at all (nil when it can).
local function fieldBlocked(id)
	if H.PartySlot(id) or fieldAction(id) then return nil end
	return string.format("파티 자리가 가득 찼습니다 (%d / %d). 룬 화면의 '지휘의 룬'을 배우면 자리가 늘어납니다.",
		H.PartyCount(), ns.PartyLimit())
end

local function swapIn(id, slot)
	local old = ns.db.party[slot]
	if H.Swap(id, slot) and old then
		ns.Toast(string.format("%s 출전, %s 대기", H.ShortName(id), H.ShortName(old)))
	end
end

local function field(id, slot)
	if slot then
		if ns.db.party[slot] then return swapIn(id, slot) end
		return UI.Try(H.Deploy(id, slot))
	end
	local act, s = fieldAction(id)
	if act == "deploy" then
		UI.Try(H.Deploy(id, s))
	elseif act == "swap" then
		swapIn(id, s)
	else
		UI.Try(false, fieldBlocked(id))
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
	if n > 0 then
		ns.Toast(string.format("%d명을 빈 자리에 넣었습니다.", n))
	elseif H.PartyCount() >= ns.PartyLimit() and H.PartyCount() < H.Count() then
		UI.Try(false, string.format("파티 자리가 가득 찼습니다 (%d / %d). 룬 화면의 '지휘의 룬'을 배우면 자리가 늘어납니다.",
			H.PartyCount(), ns.PartyLimit()))
	else
		ns.Toast("빈 자리에 넣을 수 있는 대기 영웅이 없습니다.")
	end
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
	return lines
end

-- A portrait that shows the hero as the game's 3D model when it can: only
-- the head and chest, inside the portrait's square (nothing reaches the
-- writing around it); no role ring or role mark behind the model.
local function heroFigure(parent, size)
	local p = UI.Portrait(parent, size)
	p.ringT:Hide()
	-- the model belongs to the portrait, so hiding the portrait hides it too
	p.fig = ns.Figure3D.New(p, size)
	if p.fig then
		p.fig:SetFacing("front")
		p.fig:SetBust(size)
		p.fig:ClearAllPoints()
		p.fig:SetAllPoints(p)
		-- the class circle stays until the model is in, so nothing blinks
		p.fig:SetScript("OnUpdate", function(self, dt)
			self:Step(dt)
			local inModel = self:IsLoaded()
			p.icon:SetShown(not inModel)
			p.disc:SetShown(not inModel)
		end)
		p.fig:EnableMouse(false)
	end
	function p:SetHeroFigure(id)
		self:SetHero(id)
		self.ringT:Hide()
		self.role:Hide()
		local F = ns.Figure3D
		local body = id and F.Enabled() and F.HeroBody(id, false)
		local mid = id and F.Enabled() and F.ForHero(id, false)
		if self.fig and ((body and self.fig:SetBody(body)) or (mid and self.fig:SetModelId(mid))) then
			self.fig:Show()
			local inModel = self.fig:IsLoaded()
			self.icon:SetShown(not inModel)
			self.disc:SetShown(not inModel)
		else
			if self.fig then self.fig:Hide() end
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
-- the create window's 3D preview (for the tests)
function UI.CreatePreview() return create.fig end

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
		b:SetSize(184, 36)
		b:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - (i - 1) * 39.4) -- 3px between rows
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
		-- "추천" goes under the name (beside it, a long name would run into it)
		b.rec = UI.Text(b, 10, "추천")
		b.rec:SetPoint("TOPLEFT", b, "TOPLEFT", 43, -21)
		b.rec:SetTextColor(0.35, 0.9, 0.45)
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
	create.fig = ns.Figure3D.New(mid, 190)
	if create.fig then
		create.fig:SetFacing("front")
		-- the class circle stays until the model is in
		create.fig:SetScript("OnUpdate", function(self, dt)
			self:Step(dt)
			create.portrait:SetShown(not self:IsLoaded())
		end)
	end
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
	-- both buttons under the right column only (clear of the middle panel)
	create.cancel = UI.Button(c, 153, 40, "취소", function() Main.CloseModal() end, "dark")
	create.go = UI.Button(c, 153, 40, "", function()
		if not create.spec then return end
		local ok, res = H.Create(create.spec, create.sex, create.name)
		if UI.Try(ok, res) then
			Main.CloseModal()
			Main.SelectHero(res)
			local slot = H.PartySlot(res)
			ns.Toast(slot and string.format("%s 합류! %d번 자리에 출전합니다.", H.Name(res), slot)
				or string.format("%s 합류! 파티 자리가 없어 대기합니다 (편성 화면).", H.Name(res)))
			Main.Refresh()
		end
	end, "primary")
	create.go:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	create.cancel:SetPoint("RIGHT", create.go, "LEFT", -8, 0)
end

function create.refresh()
	local cost = H.CreateCost()
	create.info:SetText(string.format("비용 %s   ·   시작 레벨 %d (파티 평균)   ·   보유 %d / %d",
		cost > 0 and UI.Gold(cost) or U.col("40ff40", "무료"), (H.StartLevel()), H.Count(), ns.ROSTER_MAX))
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
		local rec = create.role ~= nil and classRoles(b.cid)[create.role] == true
		b.rec:SetShown(rec)
		b.label:ClearAllPoints()
		if rec then
			b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 43, -5)
		else
			b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
		end
	end
	local cid = create.class
	-- preview
	local race = ns.RACES[ns.ClassRace(cid)]
	local fac = ns.FACTIONS[ns.Faction() or "ALLIANCE"]
	create.race:SetText(string.format("%s  ·  %s %s", ns.N(fac.name), race.name, ns.SEX[create.sex].name))
	local body = ns.Figure3D.Enabled() and ns.Figure3D.BodyFor(cid, ns.Faction(), create.spec, create.sex)
	local mid = ns.Figure3D.Enabled() and ns.Figure3D.ForClass(cid, ns.Faction(), create.spec, create.sex)
	UI.SetClassIcon(create.portrait.icon, cid)
	create.portrait.icon:Show()
	create.portrait.ringT:SetVertexColor(U.rgb(ns.CLASSES[cid].hex))
	create.portrait.role:Hide()
	if create.fig and ((body and create.fig:SetBody(body)) or (mid and create.fig:SetModelId(mid))) then
		create.fig:SetHeight2(190 * (ns.Figure3D.RACE_SCALE[race.id] or 1))
		create.fig:PlaceFeet(create.mid, 135, 210)
		create.fig:Show()
		create.portrait:SetShown(not create.fig:IsLoaded())
	else
		if create.fig then create.fig:Hide() end
		create.portrait:Show()
	end
	for _, b in ipairs(create.sexes) do
		b:SetStyle(b.sex == create.sex and "blue" or "dark")
		b:SetOn(b.sex == create.sex)
	end
	UI.FitText(create.nameText, create.name, 170, { 16, 14, 12 }) -- long names step down
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


-- shared with the other screens
ns.HeroTip = heroTip
ns.HeroField = function(id) field(id) end
ns.HeroFieldBlocked = fieldBlocked
ns.OpenCreate = function(role) create.open(nil, role or ns.Guide.MissingRole()) end
ns.AutoForm = autoForm

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
	local cancel = UI.Button(c, 150, K.BTN_H, "취소", function() Main.CloseModal() end, "dark")
	cancel:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	local ok = UI.Button(c, 150, K.BTN_H, "이 이름으로", function()
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
-- Screen: the five slots in battle order, the heroes who wait
------------------------------------------------------------------------
local SLOT_W, SLOT_H, SLOT_Y = 170, 232, -52
local BENCH_W, BENCH_H, BENCH_Y = 214, 58, -352

local function nextCommandRune()
	for _, br in ipairs(ns.RUNE_BRANCHES) do
		for _, node in ipairs(br.nodes) do
			if node.stat == "party" and ns.Runes.Level(node.id) == 0 then return node.id end
		end
	end
end

-- the slot next to `slot` in battle order (dir -1 = left, 1 = right)
local function neighbour(slot, dir)
	for k, s in ipairs(LANE_ORDER) do
		if s == slot then return LANE_ORDER[k + dir] end
	end
end

local function swapSlots(a, b)
	local db = ns.db
	db.party[a], db.party[b] = db.party[b], db.party[a]
	ns.Fire("PARTY")
end

-- Put a waiting hero in: the chosen slot if it is of the hero's role,
-- else a free slot of the role, else in place of the weakest of the role.
local function place(page, id)
	local role = H.Role(id)
	local slot = page.selSlot
	if slot and ns.PARTY_ROLES[slot] ~= role then
		UI.Try(false, string.format("고른 칸은 %s 자리입니다. %s는 %s 자리에 들어갑니다.",
			ns.N(ns.ROLE[ns.PARTY_ROLES[slot]].name), H.ShortName(id), ns.N(ns.ROLE[role].name)))
		return
	end
	field(id, slot)
	page.selSlot = nil
end

local function buildSlot(page, slot, k)
	local p = page.panel
	local c = CreateFrame("Button", nil, p)
	c:SetSize(SLOT_W, SLOT_H)
	c:SetPoint("TOPLEFT", p, "TOPLEFT", 14 + (k - 1) * (SLOT_W + 10), SLOT_Y)
	c.isItem = true
	c.slot = slot
	c.bg = UI.Slice(c, "card", "BACKGROUND")
	c.sel = UI.SelFrame(c)
	local role = ns.PARTY_ROLES[slot]
	c.bar = c:CreateTexture(nil, "BORDER")
	c.bar:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)
	c.bar:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -6)
	c.bar:SetHeight(4)
	UI.Fill(c.bar, U.rgb(ns.ROLE[role].hex))
	c.label = UI.Text(c, 12, string.format("%d · %s%s", slot, ns.N(ns.ROLE[role].name), slot == 1 and " (맨 앞)" or (slot == 5 and " (맨 뒤)" or "")))
	c.label:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -16)
	UI.Color(c.label, UI.C.gold)
	c.fig = UI.HeroFigure(c, 72)
	c.fig:SetPoint("TOP", c, "TOP", 0, -38)
	c.fig:EnableMouse(false)
	c.fig.lvl:Hide()
	c.plus = UI.Glyph(c, "plus", 36, 0.55, 0.62, 0.8)
	c.plus:SetPoint("TOP", c, "TOP", 0, -56)
	c.lock = UI.Glyph(c, "lock", 34, 0.75, 0.65, 0.45)
	c.lock:SetPoint("TOP", c, "TOP", 0, -56)
	local function line(y, size)
		local t = UI.Text(c, size)
		t:SetPoint("TOP", c, "TOP", 0, y)
		t:SetWidth(SLOT_W - 12)
		t:SetJustifyH("CENTER")
		t:SetWordWrap(false)
		return t
	end
	c.name = line(-120, 13)
	c.spec = line(-140, 11)
	c.duty = line(-156, 11)
	UI.Color(c.duty, UI.C.sub)
	c.power = line(-172, 11)
	c.left = UI.Button(c, 28, 26, "<", function()
		local to = neighbour(c.slot, -1)
		if to and ns.PARTY_ROLES[to] == role then swapSlots(c.slot, to) end
	end, "dark")
	c.left:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 10, 10)
	c.right = UI.Button(c, 28, 26, ">", function()
		local to = neighbour(c.slot, 1)
		if to and ns.PARTY_ROLES[to] == role then swapSlots(c.slot, to) end
	end, "dark")
	c.right:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 10)
	c.out = UI.Button(c, 82, 26, "빼기", function()
		local id = ns.db.party[c.slot]
		if not id then return end
		if H.PartyCount() <= 1 then UI.Try(false, "마지막 출전 영웅은 뺄 수 없습니다.") return end
		UI.Try(H.Withdraw(id))
	end, "dark")
	c.out:SetPoint("BOTTOM", c, "BOTTOM", 0, 10)
	c.out.clickWhenOff = true
	c.rune = UI.Button(c, 100, 26, "룬 보기", function()
		Main.ShowTab("runes", { rune = nextCommandRune() })
	end, "dark")
	c.rune:SetPoint("BOTTOM", c, "BOTTOM", 0, 10)
	c:RegisterForClicks("LeftButtonUp")
	c:SetScript("OnClick", function(self)
		ns.Sound("click")
		local id = ns.db.party[self.slot]
		if id then
			Main.SelectHero(id)
			page.selSlot = nil
		else
			page.selSlot = (page.selSlot ~= self.slot) and self.slot or nil
		end
		Main.Refresh()
	end)
	UI.Tip(c, function(self)
		local id = ns.db.party[self.slot]
		if id then
			local lines = heroTip(id)
			lines[#lines + 1] = { "< > : 옆 칸과 자리 바꾸기 (같은 역할끼리) · 빼기: 대기로", nil, 0.45, 0.8, 1 }
			return lines
		end
		if self.locked then
			return UI.SimpleTip("잠긴 자리", "룬 화면의 '지휘의 룬'을 배우면 파티 자리가 하나씩 열립니다.")
		end
		local rn = ns.N(ns.ROLE[role].name)
		return UI.SimpleTip(rn .. " 자리", "비어 있습니다. 칸을 고른 뒤 아래에서 " .. rn .. " 영웅을 누르면 들어갑니다.")
	end, "TOP")
	return c
end

local function buildBench(page, i)
	local p = page.panel
	local col, row = (i - 1) % 4, floor((i - 1) / 4)
	local c = CreateFrame("Button", nil, p)
	c:SetSize(BENCH_W, BENCH_H)
	c:SetPoint("TOPLEFT", p, "TOPLEFT", 14 + col * (BENCH_W + 8), BENCH_Y - row * (BENCH_H + 6))
	c.isItem = true
	c.bg = UI.Slice(c, "card", "BACKGROUND")
	c.stripe = c:CreateTexture(nil, "BORDER")
	c.stripe:SetSize(4, BENCH_H - 12)
	c.stripe:SetPoint("LEFT", c, "LEFT", 5, 0)
	c.portrait = UI.Portrait(c, 40)
	c.portrait:SetPoint("LEFT", c, "LEFT", 14, 0)
	c.portrait:EnableMouse(false)
	c.portrait.lvl:Hide()
	c.name = UI.Text(c, 13)
	c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 62, -9)
	c.name:SetWidth(BENCH_W - 72 - 24)
	c.name:SetWordWrap(false)
	c.info = UI.Text(c, 11)
	c.info:SetPoint("TOPLEFT", c, "TOPLEFT", 62, -27)
	c.info:SetWidth(BENCH_W - 72)
	c.info:SetWordWrap(false)
	UI.Color(c.info, UI.C.sub)
	c.power = UI.Text(c, 11)
	c.power:SetPoint("TOPLEFT", c, "TOPLEFT", 62, -41)
	c.power:SetWidth(BENCH_W - 72)
	c.power:SetWordWrap(false)
	c.role = UI.Glyph(c, "role_tank", 16)
	c.role:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -8)
	c:RegisterForClicks("LeftButtonUp")
	c:SetScript("OnClick", function(self)
		if not self.heroId then return end
		ns.Sound("click")
		place(page, self.heroId)
		Main.Refresh()
	end)
	UI.Tip(c, function(self)
		if not self.heroId then return nil end
		local lines = heroTip(self.heroId)
		lines[#lines + 1] = { "클릭: 파티에 넣기 (고른 칸, 없으면 같은 역할의 빈 칸 또는 가장 약한 영웅 자리)", nil, 0.45, 0.8, 1 }
		return lines
	end, "TOP")
	return c
end

local function build(page)
	local p = UI.Panel(page, K.W, K.H, "inset")
	p:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.panel = p
	page.help = UI.Text(p, 11, "왼쪽이 맨 뒤(힐러), 오른쪽이 맨 앞(탱커)입니다. 적은 맨 앞 영웅부터 공격합니다.\n빈 칸을 고른 뒤 아래의 대기 영웅을 누르면 그 칸에 들어갑니다.")
	page.help:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
	page.help:SetWidth(640)
	page.help:SetJustifyV("TOP")
	UI.Color(page.help, UI.C.sub)
	page.auto = UI.Button(p, 110, 30, "자동 편성", autoForm, "blue")
	page.auto:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -12)
	page.auto.clickWhenOff = true
	UI.Tip(page.auto, function() return UI.SimpleTip("자동 편성", "빈 자리마다 그 역할의 대기 영웅 중 가장 강한 영웅을 넣습니다.") end, "TOP")
	page.slots = {}
	for k, slot in ipairs(LANE_ORDER) do page.slots[slot] = buildSlot(page, slot, k) end
	page.summary = UI.Text(p, 13)
	page.summary:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -298)
	page.summary:SetWidth(K.W - 28)
	page.benchHead = UI.Section(p, K.W - 28)
	page.benchHead:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -324)
	page.bench = {}
	for i = 1, 12 do page.bench[i] = buildBench(page, i) end
	page.benchEmpty = UI.Text(p, 12)
	page.benchEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -360)
	page.benchEmpty:SetWidth(K.W - 28)
	UI.Color(page.benchEmpty, UI.C.sub)
end

local function refresh(page)
	local db = ns.db
	local count, limit = H.PartyCount(), ns.PartyLimit()
	if page.selSlot and db.party[page.selSlot] then page.selSlot = nil end
	local power, n = 0, { TANK = 0, DPS = 0, HEALER = 0 }
	for slot, c in pairs(page.slots) do
		local id = db.party[slot]
		local role = ns.PARTY_ROLES[slot]
		c.plus:Hide()
		c.lock:Hide()
		c.fig:Hide()
		c.locked = false
		c.sel:SetShown(page.selSlot == slot)
		for _, w in ipairs({ c.left, c.right, c.out, c.rune }) do w:Hide() end
		if id and db.heroes[id] then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			c.bg:SetColor(0.42, 0.46, 0.62, 1)
			c.fig:SetHeroFigure(id)
			c.fig.lvl:Hide()
			c.fig:SetBadge(false)
			c.fig:Show()
			c.name:SetText(U.col("ffb84a", H.ShortName(id)))
			c.spec:SetText(string.format("Lv %d %s", h.level, ns.SpecLabel(h.spec)))
			c.duty:SetText(ns.N(ns.ROLE[sp.role].name) .. " 전담")
			local ps = H.PowerScore(id)
			power = power + ps
			n[role] = n[role] + 1
			c.power:SetText("전투력 " .. U.col("ffd24a", U.fmt(ps)))
			c.out:Show()
			c.out:SetOff(count <= 1)
			local l, r = neighbour(slot, -1), neighbour(slot, 1)
			c.left:SetShown(l ~= nil and ns.PARTY_ROLES[l] == role)
			c.right:SetShown(r ~= nil and ns.PARTY_ROLES[r] == role)
		elseif count >= limit then
			c.locked = true
			c.bg:SetColor(0.26, 0.27, 0.32, 1)
			c.lock:Show()
			c.name:SetText(U.col("9a8f78", "잠긴 자리"))
			c.spec:SetText("지휘의 룬으로 열기")
			c.duty:SetText("")
			c.power:SetText("")
			c.rune:Show()
		else
			c.bg:SetColor(0.30, 0.33, 0.44, 1)
			c.plus:Show()
			c.name:SetText(U.col("b8c0d8", "빈 자리"))
			c.spec:SetText(page.selSlot == slot and U.col("ffd24a", "아래에서 영웅을 고르세요") or "눌러서 고르기")
			c.duty:SetText("")
			c.power:SetText("")
		end
	end
	page.summary:SetText(string.format("파티 전투력 %s   ·   탱커 %d / 딜러 %d / 힐러 %d   ·   %d / %d명",
		U.col("ffd24a", U.fmt(power)), n.TANK, n.DPS, n.HEALER, count, limit))
	page.auto:SetOff(not canAutoForm())
	-- who waits
	local bench = {}
	for _, id in ipairs(UI.HeroOrder()) do
		if not H.PartySlot(id) then bench[#bench + 1] = id end
	end
	page.benchHead:Set("대기 중인 영웅", string.format("%d명 · 누르면 파티에 넣습니다", #bench))
	for i, c in ipairs(page.bench) do
		local id = bench[i]
		c.heroId = id
		if id then
			local h = db.heroes[id]
			local sp = ns.SPECS[h.spec]
			UI.Fill(c.stripe, U.rgb(ns.ROLE[sp.role].hex))
			c.portrait:SetHero(id)
			UI.SetHeroIcon(c.portrait.icon, id)
			c.portrait.lvl:Hide()
			c.name:SetText(U.col("ffd27a", H.ShortName(id)))
			c.info:SetText(string.format("Lv %d %s", h.level, ns.SpecLabel(h.spec)))
			c.power:SetText("전투력 " .. U.col("ffd24a", U.fmt(H.PowerScore(id))))
			UI.SetGlyph(c.role, ns.ROLE[sp.role].art, U.rgb(ns.ROLE[sp.role].hex))
			c:Show()
		else
			c:Hide()
		end
	end
	page.benchEmpty:SetText(#bench == 0 and "대기 중인 영웅이 없습니다. '영웅' 화면 왼쪽 아래의 '영웅 만들기'로 새 영웅을 만들 수 있습니다." or "")
end

local function open(page, opts)
	if opts and opts.create then
		create.open(nil, opts.create ~= true and opts.create or ns.Guide.MissingRole())
	end
end

local function tick(page) end

Main.RegisterTab({
	key = "party", title = "편성", sub = "출전할 영웅과 자리",
	icon = "INV_Misc_GroupNeedMore", art = "icon_party", build = build, refresh = refresh, open = open, tick = tick,
	events = { "PARTY", "HEROES", "LEVEL", "RUNES", "PETS", "RESET", "GEAR", "TREE", "SKILLS", "FACTION" },
})
