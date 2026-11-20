-- Party page: the five role slots, the roster, and companions.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local function build(page)
	local T = ns.T
	page.title = UI.Text(page, 13)
	page.title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.hint = UI.Text(page, 10, T("탱커 1 · 딜러 3 · 힐러 1. 파티 인원은 '지휘의 룬'으로 늘립니다.",
		"1 tank, 3 damage dealers, 1 healer. Party size grows with Runes of Command."))
	page.hint:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
	page.hint:SetJustifyH("RIGHT")
	page.hint:SetTextColor(0.7, 0.7, 0.7)

	-- five slot cards
	page.slots = {}
	for i = 1, ns.PARTY_SIZE do
		local role = ns.ROLE[ns.PARTY_ROLES[i]]
		local card = UI.Panel(page, 140, 128)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * 147, -22)
		card.role = UI.Text(card, 11, ns.N(role.name))
		card.role:SetPoint("TOP", card, "TOP", 0, -6)
		card.role:SetJustifyH("CENTER")
		card.role:SetTextColor(U.rgb(role.hex))
		card.icon = UI.IconButton(card, 46, function(self)
			if self.classId then Main.SelectHero(self.classId) end
		end)
		card.icon:SetPoint("TOP", card, "TOP", 0, -22)
		card.name = UI.Text(card, 11)
		card.name:SetPoint("TOP", card, "TOP", 0, -72)
		card.name:SetJustifyH("CENTER")
		card.name:SetWidth(134)
		card.info = UI.Text(card, 10)
		card.info:SetPoint("TOP", card, "TOP", 0, -87)
		card.info:SetJustifyH("CENTER")
		card.info:SetWidth(134)
		card.info:SetTextColor(0.75, 0.75, 0.75)
		card.remove = UI.Button(card, 70, 18, T("내보내기", "Remove"), function(self)
			if self.classId then
				UI.Try(ns.Heroes.Withdraw(self.classId))
			end
		end)
		card.remove:SetPoint("BOTTOM", card, "BOTTOM", 0, 5)
		page.slots[i] = card
	end

	-- roster
	page.rosterTitle = UI.Text(page, 12, T("영웅 명단", "Roster"))
	page.rosterTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -160)
	page.rosterTitle:SetTextColor(1, 0.82, 0)
	page.banner = UI.Text(page, 12)
	page.banner:SetPoint("TOPLEFT", page, "TOPLEFT", 110, -160)
	page.banner:SetTextColor(0.3, 1, 0.3)

	page.cards = {}
	for i, id in ipairs(ns.CLASS_ORDER) do
		local c = ns.CLASSES[id]
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local card = CreateFrame("Button", nil, page)
		card:SetSize(238, 56)
		UI.Box(card)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", col * 245, -180 - row * 61)
		card.classId = id
		card:RegisterForClicks("LeftButtonUp")
		card:SetScript("OnClick", function(self)
			if ns.db.heroes[self.classId] then Main.SelectHero(self.classId) end
		end)
		card.icon = card:CreateTexture(nil, "ARTWORK")
		card.icon:SetSize(42, 42)
		card.icon:SetPoint("LEFT", card, "LEFT", 7, 0)
		UI.SetClassIcon(card.icon, id)
		card.name = UI.Text(card, 12, ns.N(c.name))
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 56, -8)
		card.name:SetTextColor(U.rgb(c.hex))
		card.role = UI.Text(card, 10, ns.N(ns.ROLE[c.role].name))
		card.role:SetPoint("TOPLEFT", card, "TOPLEFT", 56, -24)
		card.role:SetTextColor(U.rgb(ns.ROLE[c.role].hex))
		card.status = UI.Text(card, 10)
		card.status:SetPoint("TOPLEFT", card, "TOPLEFT", 56, -38)
		card.status:SetTextColor(0.75, 0.75, 0.75)
		card.action = UI.Button(card, 66, 20, "", function(self)
			local cid = self.classId
			if not ns.db.heroes[cid] then
				if UI.Try(ns.Heroes.Unlock(cid)) then
					Main.SelectHero(cid)
					ns.Toast(string.format(ns.T("%s 영입 완료!", "%s has joined you!"), ns.N(ns.CLASSES[cid].name)))
				end
			elseif ns.Heroes.PartySlot(cid) then
				UI.Try(ns.Heroes.Withdraw(cid))
			else
				UI.Try(ns.Heroes.Deploy(cid))
			end
		end)
		card.action.classId = id
		card.action:SetPoint("RIGHT", card, "RIGHT", -7, 0)
		UI.Tip(card, function(self)
			local cls = ns.CLASSES[self.classId]
			local lines = { { ns.N(cls.name), ns.N(ns.ROLE[cls.role].name), U.rgb(cls.hex) } }
			lines[#lines + 1] = { ns.N(cls.desc), nil, 1, 0.82, 0 }
			local wl = {}
			for _, t in ipairs(cls.mh) do wl[#wl + 1] = ns.N(ns.WTYPE[t].name) end
			for _, t in ipairs(cls.oh) do wl[#wl + 1] = ns.N(ns.WTYPE[t].name) end
			lines[#lines + 1] = { ns.T("장비: ", "Gear: ") .. table.concat(wl, ", "), nil, 0.8, 0.8, 0.8 }
			local names = {}
			for t = 1, #cls.tree do
				for n = 1, #cls.tree[t] do
					local s = cls.tree[t][n].s
					if s then names[#names + 1] = ns.N(ns.SKILLS[s].name) end
				end
			end
			lines[#lines + 1] = { ns.T("기술: ", "Skills: ") .. table.concat(names, ", "), nil, 0.6, 0.8, 1 }
			return lines
		end)
		page.cards[i] = card
	end

	-- companions
	page.petTitle = UI.Text(page, 12, T("동료", "Companions"))
	page.petTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -372)
	page.petTitle:SetTextColor(1, 0.82, 0)
	page.petHint = UI.Text(page, 10, T("획득한 동료의 효과는 항상 적용됩니다. 클릭하면 함께 다닐 동료를 고릅니다.",
		"Bonuses of unlocked companions always apply. Click to choose which one follows the party."))
	page.petHint:SetPoint("TOPLEFT", page, "TOPLEFT", 60, -374)
	page.petHint:SetTextColor(0.7, 0.7, 0.7)
	page.pets = {}
	for i, pet in ipairs(ns.PETS) do
		local b = UI.IconButton(page, 40, function(self)
			if ns.db.pets[self.pet.id] then
				ns.db.pet = self.pet.id
				Main.MarkDirty("party")
			end
		end)
		b.pet = pet
		b:SetIconName(pet.icon)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * 46, -392)
		UI.Tip(b, function(self)
			local p = self.pet
			local have, need = ns.PetProgress(p)
			local owned = ns.db.pets[p.id]
			local lines = { { ns.N(p.name), owned and ns.T("획득", "Unlocked") or ns.T("미획득", "Locked"), 1, 0.82, 0 } }
			for k, v in pairs(p.bonus) do
				lines[#lines + 1] = { ns.BonusText(k, v), nil, 0.3, 1, 0.3 }
			end
			lines[#lines + 1] = { ns.PetUnlockText(p), U.fmt(have) .. " / " .. U.fmt(need), 0.8, 0.8, 0.8 }
			return lines
		end, "TOP")
		b.progress = UI.Bar(page, 40, 6, 0.3, 0.7, 1)
		b.progress:SetPoint("TOP", b, "BOTTOM", 0, -2)
		page.pets[i] = b
	end
end

local function refresh(page)
	local T = ns.T
	local db = ns.db
	local count, limit = ns.Heroes.PartyCount(), ns.PartyLimit()
	page.title:SetText(string.format(T("파티 편성 (%d/%d)", "Party (%d/%d)"), count, limit))
	if ns.Heroes.Count() == 0 then
		page.banner:SetText(T("첫 영웅을 골라 영입하세요. 첫 영웅은 무료입니다!", "Pick and recruit your first hero - the first one is free!"))
	else
		page.banner:SetText("")
	end

	for i = 1, ns.PARTY_SIZE do
		local card = page.slots[i]
		local id = db.party[i]
		if id and db.heroes[id] then
			local c = ns.CLASSES[id]
			local s = ns.Stats.Get(id)
			card.icon:SetClass(id)
			card.icon.classId = id
			card.icon:SetDim(false)
			card.icon:SetSelected(id == Main.SelectedHero())
			card.name:SetText(U.col(c.hex, ns.N(c.name)) .. "  Lv " .. db.heroes[id].level)
			card.info:SetText(T("피해 ", "DPS ") .. U.fmt(ns.Stats.DPS(s)) .. "   " .. T("생명력 ", "HP ") .. U.fmt(s.hp))
			card.remove.classId = id
			card.remove:Show()
			UI.BorderColor(card, U.rgb(ns.ROLE[c.role].hex))
		else
			card.icon:Clear()
			card.icon.classId = nil
			card.remove:Hide()
			local c = UI.COLOR.border
			UI.BorderColor(card, c[1], c[2], c[3], 1)
			if count >= limit then
				card.name:SetText(U.col("808080", T("잠김", "Locked")))
				card.info:SetText(T("지휘의 룬 필요", "Needs a Rune of Command"))
			else
				card.name:SetText(U.col("b0b0b0", T("비어 있음", "Empty")))
				card.info:SetText(T("아래 명단에서 배치", "Deploy from the roster"))
			end
		end
	end

	local cost = ns.Heroes.UnlockCost()
	for i, id in ipairs(ns.CLASS_ORDER) do
		local card = page.cards[i]
		local h = db.heroes[id]
		local c = UI.COLOR
		if h then
			if ns.Heroes.PartySlot(id) then
				card.status:SetText("Lv " .. h.level .. " · " .. T("파티 참여 중", "in party"))
				card.action:SetLabel(T("내보내기", "Remove"))
			else
				card.status:SetText("Lv " .. h.level .. " · " .. T("대기 중", "bench"))
				card.action:SetLabel(T("배치", "Deploy"))
			end
			card.action:SetOff(false)
			if id == Main.SelectedHero() then
				UI.BorderColor(card, c.hover[1], c.hover[2], c.hover[3], 1)
			else
				UI.BorderColor(card, c.border[1], c.border[2], c.border[3], 1)
			end
		else
			if cost > 0 then
				card.status:SetText(T("영입 비용 ", "Recruit: ") .. UI.Gold(cost))
			else
				card.status:SetText(U.col("40ff40", T("무료 영입", "Free")))
			end
			card.action:SetLabel(T("영입", "Recruit"))
			card.action:SetOff(not ns.CanAfford(cost))
			UI.BorderColor(card, c.dim[1], c.dim[2], c.dim[3], 1)
		end
	end

	for _, b in ipairs(page.pets) do
		local owned = db.pets[b.pet.id]
		local have, need = ns.PetProgress(b.pet)
		b:SetDim(not owned)
		b:SetSelected(owned and db.pet == b.pet.id)
		b.progress:SetValue(have / need)
		if owned then b.progress:SetRGB(0.3, 0.9, 0.3) else b.progress:SetRGB(0.3, 0.7, 1) end
	end
end

Main.RegisterTab({
	key = "party", title = { "파티", "Party" }, build = build, refresh = refresh,
	events = { "PARTY", "HEROES", "LEVEL", "RUNES", "PETS", "RESET", "GEAR", "GOLD" },
})
