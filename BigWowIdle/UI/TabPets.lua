-- Companions screen (동료): every companion as a card (owned or not, the
-- progress towards it, its effect); the chosen one on the right with
-- [데리고 다니기]. Every owned companion's effect always applies; the one
-- you take along also shows in the battle window.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local LEFT_W, RIGHT_X, RIGHT_W = 560, 570, 350
local CARD_W, CARD_H = 262, 116

local function bonusText(p)
	local parts = {}
	for k, v in pairs(p.bonus) do parts[#parts + 1] = ns.BonusText(k, v) end
	table.sort(parts)
	return parts
end

local function build(page)
	local lp = UI.Panel(page, LEFT_W, K.H, "inset")
	lp:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.head = UI.Section(lp, LEFT_W - 24)
	page.head:SetPoint("TOPLEFT", lp, "TOPLEFT", 12, -12)
	page.cards = {}
	for i, pet in ipairs(ns.PETS) do
		local col, row = (i - 1) % 2, floor((i - 1) / 2)
		local c = CreateFrame("Button", nil, lp)
		c:SetSize(CARD_W, CARD_H)
		c:SetPoint("TOPLEFT", lp, "TOPLEFT", 12 + col * (CARD_W + 12), -42 - row * (CARD_H + 6))
		c.isItem = true
		c.pet = pet
		c.bg = UI.Slice(c, "card", "BACKGROUND")
		c.sel = UI.SelFrame(c)
		c.icon = UI.IconButton(c, 52)
		c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -10)
		c.icon:EnableMouse(false)
		c.icon:SetIconName(pet.icon)
		c.name = UI.Text(c, 13)
		c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 72, -10)
		c.name:SetWidth(CARD_W - 82)
		c.name:SetWordWrap(false)
		c.state = UI.Text(c, 11)
		c.state:SetPoint("TOPLEFT", c, "TOPLEFT", 72, -30)
		c.state:SetWidth(CARD_W - 82)
		c.state:SetWordWrap(false)
		c.bonus = UI.Text(c, 11)
		c.bonus:SetPoint("TOPLEFT", c, "TOPLEFT", 72, -48)
		c.bonus:SetWidth(CARD_W - 82)
		c.bonus:SetHeight(30)
		c.bonus:SetJustifyV("TOP")
		c.bar = UI.Bar(c, CARD_W - 20, 14, 0.3, 0.6, 1)
		c.bar:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 10, 10)
		c:RegisterForClicks("LeftButtonUp")
		c:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.sel = self.pet.id
			Main.Refresh()
		end)
		UI.Tip(c, function(self)
			local lines = { { ns.N(self.pet.name), nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] } }
			for _, t in ipairs(bonusText(self.pet)) do lines[#lines + 1] = { t, nil, 0.4, 1, 0.45 } end
			lines[#lines + 1] = { ns.PetUnlockText(self.pet), nil, 0.8, 0.8, 0.8 }
			return lines
		end, "TOP")
		page.cards[i] = c
	end

	local rp = UI.Panel(page, RIGHT_W, K.H, "inset")
	rp:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X, 0)
	local d = UI.Panel(rp, RIGHT_W - 24, 104, "card")
	d:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -12)
	page.dIcon = UI.IconButton(d, 72)
	page.dIcon:SetPoint("LEFT", d, "LEFT", 14, 0)
	page.dIcon:EnableMouse(false)
	page.dName = UI.Text(d, 16)
	page.dName:SetPoint("TOPLEFT", d, "TOPLEFT", 98, -24)
	page.dName:SetWidth(RIGHT_W - 24 - 110)
	page.dName:SetWordWrap(false)
	page.dState = UI.Text(d, 12)
	page.dState:SetPoint("TOPLEFT", d, "TOPLEFT", 98, -50)
	page.dState:SetWidth(RIGHT_W - 24 - 110)
	page.bonusHead = UI.Section(rp, RIGHT_W - 24, "효과")
	page.bonusHead:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -132)
	page.dBonus = UI.Text(rp, 12)
	page.dBonus:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -160)
	page.dBonus:SetWidth(RIGHT_W - 24)
	page.dBonus:SetJustifyV("TOP")
	page.dBonus:SetSpacing(3)
	page.condHead = UI.Section(rp, RIGHT_W - 24, "얻는 조건")
	page.condHead:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -240)
	page.dCond = UI.Text(rp, 12)
	page.dCond:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -268)
	page.dCond:SetWidth(RIGHT_W - 24)
	page.dCond:SetJustifyV("TOP")
	page.dBar = UI.Bar(rp, RIGHT_W - 24, 16, 0.3, 0.6, 1)
	page.dBar:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -312)
	page.note = UI.Text(rp, 11, "얻은 동료의 효과는 모두 항상 적용됩니다. 데리고 다니는 동료는 전투 창에서 파티와 함께 보입니다.")
	page.note:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -344)
	page.note:SetWidth(RIGHT_W - 24)
	page.note:SetJustifyV("TOP")
	UI.Color(page.note, UI.C.dim)
	page.take = UI.Button(rp, RIGHT_W - 24, 38, "", function()
		local p = ns.PETS_BY_ID and ns.PETS_BY_ID[page.sel]
		for _, pet in ipairs(ns.PETS) do if pet.id == page.sel then p = pet end end
		if not (p and ns.db.pets[p.id]) then UI.Try(false, "아직 얻지 못한 동료입니다.") return end
		ns.db.pet = p.id
		ns.Fire("PETS")
		Main.Refresh()
	end, "primary")
	page.take:SetPoint("BOTTOMLEFT", rp, "BOTTOMLEFT", 12, 12)
	page.take.clickWhenOff = true
end

local function refresh(page)
	local db = ns.db
	if not page.sel then page.sel = db.pet or ns.PETS[1].id end
	local owned = 0
	local selPet
	for _, c in ipairs(page.cards) do
		local p = c.pet
		local has = db.pets[p.id]
		if has then owned = owned + 1 end
		c.icon:SetDim(not has)
		c.name:SetText(has and U.col("ffd27a", ns.N(p.name)) or U.col("8a90a2", ns.N(p.name)))
		if db.pet == p.id then
			c.state:SetText(U.col("60e070", "데리고 다니는 중"))
		elseif has then
			c.state:SetText(U.col("aab3c8", "얻음"))
		else
			c.state:SetText(U.col("8a90a2", "아직 얻지 못함"))
		end
		c.bonus:SetText(U.col(has and "66e070" or "7a8090", table.concat(bonusText(p), " · ")))
		local have, need = ns.PetProgress(p)
		c.bar:SetValue(have / need)
		c.bar:SetLabel(has and "완료" or (U.fmt(min(have, need)) .. " / " .. U.fmt(need)))
		c.bar:SetRGB(0.3, has and 0.9 or 0.6, has and 0.35 or 1)
		c.sel:SetShown(p.id == page.sel)
		if p.id == page.sel then selPet = p end
	end
	page.head:Set("동료", string.format("%d / %d 얻음", owned, #ns.PETS))
	local p = selPet or ns.PETS[1]
	local has = db.pets[p.id]
	page.dIcon:SetIconName(p.icon)
	page.dIcon:SetDim(not has)
	page.dName:SetText(U.col(has and "ffb84a" or "8a90a2", ns.N(p.name)))
	page.dState:SetText(has and (db.pet == p.id and U.col("60e070", "데리고 다니는 중") or U.col("aab3c8", "얻은 동료")) or U.col("8a90a2", "아직 얻지 못함"))
	page.dBonus:SetText(table.concat(bonusText(p), "\n"))
	page.dBonus:SetTextColor(has and 0.4 or 0.7, has and 1 or 0.72, has and 0.45 or 0.78)
	local have, need = ns.PetProgress(p)
	page.dCond:SetText(ns.PetUnlockText(p))
	page.dBar:SetValue(have / need)
	page.dBar:SetLabel(U.fmt(min(have, need)) .. " / " .. U.fmt(need))
	page.dBar:SetRGB(0.3, has and 0.9 or 0.6, has and 0.35 or 1)
	if not has then
		page.take:SetLabel("아직 얻지 못함")
		page.take:SetOff(true)
	elseif db.pet == p.id then
		page.take:SetLabel("데리고 다니는 중")
		page.take:SetOff(true)
	else
		page.take:SetLabel("데리고 다니기")
		page.take:SetOff(false)
	end
end

local function tick(page) end

Main.RegisterTab({
	key = "pets", title = "동료", sub = "조건을 채우면 얻는 동료",
	icon = "Ability_Hunter_BeastTaming", art = "icon_pets", build = build, refresh = refresh, tick = tick,
	events = { "PETS", "RESET", "PROGRESS" },
})
