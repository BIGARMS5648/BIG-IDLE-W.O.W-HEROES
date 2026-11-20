-- Hero page: gear, character sheet, talent tree and skill loadout.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local TREE_X = 262
local ROW_H = 43

local function gearTip(self)
	local id = Main.SelectedHero()
	local h = id and ns.db.heroes[id]
	local it = h and h.gear[self.slot]
	if it then
		local lines = ns.Items.Tooltip(it, id)
		lines[#lines + 1] = { ns.T("클릭: 장비 해제", "Click: unequip"), nil, 0.4, 0.8, 1 }
		return lines
	end
	return UI.SimpleTip(ns.N(ns.SLOT[self.slot].name), ns.T("비어 있음. '가방' 탭에서 장비를 클릭해 착용하세요.", "Empty. Click an item on the Bags tab to equip it."))
end

local function nodeTip(self)
	local T = ns.T
	local id = Main.SelectedHero()
	if not id then return nil end
	local node = ns.CLASSES[id].tree[self.tier][self.n]
	if not node then return nil end
	local lvl = ns.Heroes.NodeLevel(id, self.tier, self.n)
	local lines = {}
	if node.s then
		local sk = ns.SKILLS[node.s]
		local eff = ns.Heroes.SkillLevel(id, node.s)
		lines[1] = { ns.N(sk.name), string.format(T("레벨 %d/%d", "Level %d/%d"), lvl, node.max), 1, 0.82, 0 }
		if eff > lvl then
			lines[#lines + 1] = { string.format(T("장비 효과 포함 레벨 %d", "Level %d with gear bonuses"), eff), nil, 0.3, 1, 0.3 }
		end
		lines[#lines + 1] = { ns.SkillActText(node.s, math.max(1, eff)), nil, 0.6, 0.8, 1 }
		lines[#lines + 1] = { ns.SkillDesc(node.s, math.max(1, eff)), nil, 1, 1, 1 }
		if lvl > 0 and lvl < node.max then
			lines[#lines + 1] = { T("다음 레벨: ", "Next level: ") .. ns.SkillDesc(node.s, eff + 1), nil, 0.6, 0.6, 0.6 }
		end
		if lvl > 0 then
			if ns.Heroes.IsSkillEquipped(id, node.s) then
				lines[#lines + 1] = { T("장착 중 · 우클릭: 해제", "Equipped - right-click to remove"), nil, 0.3, 1, 0.3 }
			else
				lines[#lines + 1] = { T("우클릭: 기술 슬롯에 장착", "Right-click: put in a skill slot"), nil, 0.4, 0.8, 1 }
			end
		end
	else
		local a = ns.AFFIX[node.p]
		lines[1] = { ns.N(a.n) .. T(" 강화", " Mastery"), string.format(T("레벨 %d/%d", "Level %d/%d"), lvl, node.max), 1, 0.82, 0 }
		lines[#lines + 1] = { T("레벨당 ", "Per level: ") .. ns.Stats.ModText(node.p, node.v), nil, 1, 1, 1 }
		if lvl > 0 then
			lines[#lines + 1] = { T("현재 ", "Now: ") .. ns.Stats.ModText(node.p, node.v * lvl), nil, 0.3, 1, 0.3 }
		end
	end
	if not ns.Heroes.TierOpen(id, self.tier) then
		lines[#lines + 1] = { string.format(T("기술 점수를 %d점 사용하면 열립니다.", "Unlocks after spending %d skill points."), (self.tier - 1) * ns.TREE_TIER_POINTS), nil, 1, 0.3, 0.3 }
	elseif lvl < node.max then
		lines[#lines + 1] = { T("클릭: 기술 점수 1점 투자", "Click: spend 1 skill point"), nil, 0.4, 0.8, 1 }
	end
	return lines
end

local function build(page)
	local T = ns.T
	-- header
	page.icon = page:CreateTexture(nil, "ARTWORK")
	page.icon:SetSize(40, 40)
	page.icon:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.name = UI.Text(page, 14)
	page.name:SetPoint("TOPLEFT", page, "TOPLEFT", 48, -2)
	page.role = UI.Text(page, 10)
	page.role:SetPoint("TOPLEFT", page, "TOPLEFT", 48, -21)
	page.xp = UI.Bar(page, 250, 13, 0.55, 0.3, 0.85)
	page.xp:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -46)
	page.empty = UI.Text(page, 13, T("영입한 영웅이 없습니다. '파티' 탭에서 첫 영웅을 영입하세요.", "No hero yet. Recruit your first hero on the Party tab."))
	page.empty:SetPoint("CENTER", page, "CENTER", 0, 0)

	-- gear: two rows of five
	page.gear = {}
	for i, slot in ipairs(ns.SLOTS) do
		local b = UI.IconButton(page, 42, function(self)
			local id = Main.SelectedHero()
			if id and ns.db.heroes[id].gear[self.slot] then
				UI.Try(ns.Items.Unequip(id, self.slot))
			end
		end)
		b.slot = slot
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", col * 48, -66 - row * 48)
		UI.Tip(b, gearTip)
		b.label = UI.Text(b, 8, ns.N(ns.SLOT[slot].name))
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label:SetJustifyH("CENTER")
		b.label:SetTextColor(0.45, 0.45, 0.45)
		page.gear[i] = b
	end
	page.auto = UI.Button(page, 118, 20, T("최적 장비 자동 착용", "Equip best gear"), function()
		local id = Main.SelectedHero()
		if id then
			local n = ns.Items.AutoEquip(id)
			ns.Fire("TOAST", string.format(ns.T("장비 %d개를 교체했습니다.", "%d items changed."), n))
		end
	end)
	page.auto:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -166)
	page.power = UI.Text(page, 11)
	page.power:SetPoint("LEFT", page.auto, "RIGHT", 8, 0)

	-- character sheet
	page.rows = {}
	for i = 1, 20 do
		local l = UI.Text(page, 10)
		l:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -194 - (i - 1) * 14)
		l:SetTextColor(0.75, 0.75, 0.75)
		local v = UI.Text(page, 10)
		v:SetPoint("TOPRIGHT", page, "TOPLEFT", 250, -194 - (i - 1) * 14)
		v:SetJustifyH("RIGHT")
		page.rows[i] = { l, v }
	end

	-- skill loadout
	page.loadTitle = UI.Text(page, 12)
	page.loadTitle:SetPoint("TOPLEFT", page, "TOPLEFT", TREE_X, 0)
	page.loadTitle:SetTextColor(1, 0.82, 0)
	page.load = {}
	for i = 1, 3 do
		local b = UI.IconButton(page, 38, function(self)
			local id = Main.SelectedHero()
			if id and self.skill then ns.Heroes.UnequipSkill(id, self.skill) end
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", TREE_X + (i - 1) * 44, -18)
		UI.Tip(b, function(self)
			local id = Main.SelectedHero()
			if self.skill and id then
				local lvl = math.max(1, ns.Heroes.SkillLevel(id, self.skill))
				return {
					{ ns.N(ns.SKILLS[self.skill].name), string.format(ns.T("레벨 %d", "Level %d"), lvl), 1, 0.82, 0 },
					{ ns.SkillActText(self.skill, lvl), nil, 0.6, 0.8, 1 },
					{ ns.SkillDesc(self.skill, lvl), nil, 1, 1, 1 },
					{ ns.T("클릭: 해제", "Click: remove"), nil, 0.4, 0.8, 1 },
				}
			elseif self.locked then
				return UI.SimpleTip(ns.T("잠긴 기술 슬롯", "Locked skill slot"), ns.T("'각성의 룬'을 배우면 열립니다.", "Unlocked by a Rune of Awakening."))
			end
			return UI.SimpleTip(ns.T("빈 기술 슬롯", "Empty skill slot"), ns.T("배운 기술을 우클릭하면 여기에 장착됩니다.", "Right-click a learned skill to place it here."))
		end)
		page.load[i] = b
	end
	page.points = UI.Text(page, 12)
	page.points:SetPoint("TOPLEFT", page, "TOPLEFT", TREE_X + 146, -22)
	page.reset = UI.Button(page, 150, 20, "", function()
		local id = Main.SelectedHero()
		if id then UI.Try(ns.Heroes.ResetTree(id)) end
	end)
	page.reset:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -20)

	-- talent tree: 8 tiers
	page.tiers = {}
	for t = 1, 8 do
		local y = -66 - (t - 1) * ROW_H
		local row = { nodes = {} }
		row.label = UI.Text(page, 10)
		row.label:SetPoint("TOPLEFT", page, "TOPLEFT", TREE_X, y - 4)
		row.label:SetWidth(62)
		for n = 1, 4 do
			local b = UI.IconButton(page, 36, function(self, button)
				local id = Main.SelectedHero()
				if not id then return end
				local node = ns.CLASSES[id].tree[self.tier][self.n]
				if not node then return end
				if button == "RightButton" then
					if node.s then
						if ns.Heroes.IsSkillEquipped(id, node.s) then
							ns.Heroes.UnequipSkill(id, node.s)
						else
							UI.Try(ns.Heroes.EquipSkill(id, node.s))
						end
					end
				else
					UI.Try(ns.Heroes.SpendPoint(id, self.tier, self.n))
				end
				Main.Refresh()
			end)
			b.tier, b.n = t, n
			b:SetPoint("TOPLEFT", page, "TOPLEFT", TREE_X + 66 + (n - 1) * 100, y)
			UI.Tip(b, nodeTip)
			b.text = UI.Text(page, 10)
			b.text:SetPoint("LEFT", b, "RIGHT", 4, 0)
			b.text:SetWidth(58)
			row.nodes[n] = b
		end
		page.tiers[t] = row
	end
end

local function refresh(page)
	local T = ns.T
	local id = Main.SelectedHero()
	local has = id ~= nil
	page.empty:SetShown(not has)
	page.icon:SetShown(has)
	page.xp:SetShown(has)
	page.auto:SetShown(has)
	page.reset:SetShown(has)
	for _, b in ipairs(page.gear) do b:SetShown(has) end
	for _, b in ipairs(page.load) do b:SetShown(has) end
	for _, row in ipairs(page.tiers) do
		row.label:SetShown(has)
		for _, b in ipairs(row.nodes) do
			b:SetShown(has)
			b.text:SetShown(has)
		end
	end
	if not has then
		page.name:SetText("")
		page.role:SetText("")
		page.power:SetText("")
		page.points:SetText("")
		page.loadTitle:SetText("")
		for _, r in ipairs(page.rows) do r[1]:SetText("") r[2]:SetText("") end
		return
	end

	local c = ns.CLASSES[id]
	local h = ns.db.heroes[id]
	UI.SetClassIcon(page.icon, id)
	page.name:SetText(U.col(c.hex, ns.N(c.name)) .. "  " .. string.format(T("레벨 %d", "Level %d"), h.level))
	page.role:SetText(U.col(ns.ROLE[c.role].hex, ns.N(ns.ROLE[c.role].name)) .. "  " .. (ns.Heroes.PartySlot(id) and T("파티 참여 중", "In party") or T("대기 중", "Bench")))
	if h.level >= ns.HERO_MAX_LEVEL then
		page.xp:SetValue(1)
		page.xp:SetLabel(T("최대 레벨", "Max level"))
	else
		local need = ns.XPForLevel(h.level)
		page.xp:SetValue(h.xp / need)
		page.xp:SetLabel(U.fmt(h.xp) .. " / " .. U.fmt(need))
	end

	for _, b in ipairs(page.gear) do
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
	end
	page.power:SetText(T("전투력 ", "Power ") .. U.col("ffd100", U.fmt(ns.Stats.Power(id))))

	local sheet = ns.Stats.Sheet(id)
	for i, r in ipairs(page.rows) do
		local e = sheet[i]
		r[1]:SetText(e and e[1] or "")
		r[2]:SetText(e and e[2] or "")
	end

	-- loadout
	local slots = ns.SkillSlots()
	local active = ns.Heroes.ActiveSkills(id)
	page.loadTitle:SetText(string.format(T("장착 기술 (%d/%d)", "Equipped skills (%d/%d)"), #active, slots))
	for i, b in ipairs(page.load) do
		local sid = active[i]
		b.skill = sid
		b.locked = i > slots
		if sid then
			b:SetIconName(ns.SKILLS[sid].icon)
			b:SetBorderRGB(1, 0.82, 0)
			b:SetDim(false)
			b:SetMark("")
		else
			b:Clear()
			b:SetMark(b.locked and "X" or "", 0.6, 0.2, 0.2)
		end
	end
	local free = ns.Heroes.PointsFree(id)
	page.points:SetText(T("기술 점수 ", "Skill points ") .. U.col(free > 0 and "40ff40" or "b0b0b0", tostring(free)))
	local spent = ns.Heroes.PointsSpent(id)
	page.reset:SetLabel(T("초기화 ", "Reset ") .. "(" .. U.fmt(ns.Heroes.ResetCost(id)) .. " G)")
	page.reset:SetOff(spent == 0 or not ns.CanAfford(ns.Heroes.ResetCost(id)))

	-- tree
	for t, row in ipairs(page.tiers) do
		local open = ns.Heroes.TierOpen(id, t)
		if open then
			row.label:SetText(string.format(T("%d단계", "Tier %d"), t))
			row.label:SetTextColor(1, 0.82, 0)
		else
			row.label:SetText(string.format(T("%d단계\n%d점 필요", "Tier %d\nneeds %d"), t, (t - 1) * ns.TREE_TIER_POINTS))
			row.label:SetTextColor(0.5, 0.5, 0.5)
		end
		for n, b in ipairs(row.nodes) do
			local node = c.tree[t][n]
			if node then
				local lvl = ns.Heroes.NodeLevel(id, t, n)
				if node.s then
					b:SetIconName(ns.SKILLS[node.s].icon)
					local equipped = ns.Heroes.IsSkillEquipped(id, node.s)
					if equipped then b:SetBorderRGB(1, 0.82, 0) elseif lvl > 0 then b:SetBorderRGB(0.3, 0.7, 1) else b:SetQuality(nil) end
					b:SetMark(equipped and "E" or "", 1, 0.82, 0)
				else
					b:SetIconName(UI.STAT_ICON[node.p] or "INV_Misc_Book_09")
					if lvl >= node.max then b:SetBorderRGB(0.3, 1, 0.3) elseif lvl > 0 then b:SetBorderRGB(0.3, 0.7, 1) else b:SetQuality(nil) end
					b:SetMark("")
				end
				b:SetDim(not open or lvl == 0)
				local color = (lvl >= node.max) and "40ff40" or (lvl > 0 and "ffffff" or "808080")
				local label = node.s and ns.N(ns.SKILLS[node.s].name) or ns.N(ns.AFFIX[node.p].n)
				b.text:SetText(U.col(color, lvl .. "/" .. node.max) .. "\n" .. U.col("a0a0a0", label))
				b:Show()
				b.text:Show()
			else
				b:Hide()
				b.text:Hide()
			end
		end
	end
end

Main.RegisterTab({
	key = "hero", title = { "영웅", "Hero" }, build = build, refresh = refresh,
	events = { "HEROES", "LEVEL", "TREE", "SKILLS", "GEAR", "STATS", "RUNES", "RESET", "PARTY" },
})
