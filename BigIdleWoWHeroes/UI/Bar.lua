-- The battle bar: a slim strip where the party fights on its own.
local _, ns = ...

local floor, max, min, sin = math.floor, math.max, math.min, math.sin
local UI, U = ns.UI, ns.U

local Bar = {}
ns.Bar = Bar

local W, H = 724, 92
local LANE_X, LANE_W, LANE_H = 176, 424, 80
local UNIT = 28
local BOSS = 38
local MAX_MOBS = 12
local MAX_FLOATS = 26

local frame
local heroFrames, mobFrames, floats = {}, {}, {}
local toastT, infoT = 0, 0

------------------------------------------------------------------------
-- Unit frames
------------------------------------------------------------------------
local function newUnit(parent)
	local u = CreateFrame("Frame", nil, parent)
	u:SetSize(UNIT, UNIT)
	u.border = u:CreateTexture(nil, "BACKGROUND")
	u.border:SetAllPoints(u)
	UI.Fill(u.border, 0, 0, 0, 1)
	u.icon = u:CreateTexture(nil, "ARTWORK")
	u.icon:SetPoint("TOPLEFT", u, "TOPLEFT", 1, -1)
	u.icon:SetPoint("BOTTOMRIGHT", u, "BOTTOMRIGHT", -1, 1)
	u.flash = u:CreateTexture(nil, "OVERLAY")
	u.flash:SetAllPoints(u.icon)
	UI.Fill(u.flash, 1, 1, 1, 0.55)
	u.flash:Hide()
	u.tint = u:CreateTexture(nil, "OVERLAY")
	u.tint:SetAllPoints(u.icon)
	u.tint:Hide()
	u.hp = UI.Bar(u, UNIT, 5, 0.2, 0.85, 0.2)
	u.hp:SetPoint("TOP", u, "BOTTOM", 0, -1)
	u.shield = u:CreateTexture(nil, "OVERLAY")
	u.shield:SetPoint("BOTTOMLEFT", u.hp, "TOPLEFT", 0, 0)
	u.shield:SetHeight(2)
	UI.Fill(u.shield, 0.5, 0.8, 1, 1)
	u.shield:Hide()
	u.cast = u:CreateTexture(nil, "OVERLAY")
	u.cast:SetSize(16, 16)
	u.cast:SetPoint("BOTTOM", u, "TOP", 0, 2)
	u.cast:Hide()
	u:Hide()
	return u
end

local STATUS_TINT = {
	freeze = { 0.4, 0.8, 1, 0.5 }, stun = { 1, 1, 0.4, 0.4 }, chill = { 0.4, 0.6, 1, 0.3 },
	ignite = { 1, 0.4, 0.1, 0.35 }, poison = { 0.3, 0.9, 0.3, 0.35 }, bleed = { 0.9, 0.1, 0.1, 0.35 },
	corrupt = { 0.6, 0.3, 0.9, 0.35 }, shock = { 1, 0.9, 0.3, 0.3 }, curse = { 0.5, 0.2, 0.7, 0.3 }, weaken = { 0.5, 0.4, 0.3, 0.3 },
}
local STATUS_ORDER = { "freeze", "stun", "ignite", "bleed", "poison", "corrupt", "shock", "curse", "chill", "weaken" }

local function paintStatus(f, unit)
	for i = 1, #STATUS_ORDER do
		local k = STATUS_ORDER[i]
		if unit.st[k] then
			local c = STATUS_TINT[k]
			UI.Fill(f.tint, c[1], c[2], c[3], c[4])
			f.tint:Show()
			return
		end
	end
	f.tint:Hide()
end

local function place(f, x, y)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", frame.lane, "BOTTOMLEFT", x, y)
end

local function laneX(x)
	return x / 1000 * LANE_W
end

------------------------------------------------------------------------
-- Floating combat text
------------------------------------------------------------------------
local function spawnFloat(e)
	local slot
	for i = 1, MAX_FLOATS do
		if not floats[i].active then slot = floats[i] break end
	end
	if not slot then return end
	slot.active = true
	slot.t = 0
	slot.life = e.big and 1.2 or 0.9
	slot.x = U.clamp(laneX(e.x) + math.random(-8, 8), 10, LANE_W - 10)
	slot.y = (e.side == "hero") and 38 or 44
	slot.fs:SetFont(ns.FONT, e.big and 13 or 10, "OUTLINE")
	slot.fs:SetText(e.text)
	slot.fs:SetTextColor(e.r or 1, e.g or 1, e.b or 1)
	slot.fs:SetAlpha(1)
	slot.fs:Show()
end

local function updateFloats(elapsed)
	for i = 1, MAX_FLOATS do
		local s = floats[i]
		if s.active then
			s.t = s.t + elapsed
			local p = s.t / s.life
			if p >= 1 then
				s.active = false
				s.fs:Hide()
			else
				s.fs:ClearAllPoints()
				s.fs:SetPoint("BOTTOM", frame.lane, "BOTTOMLEFT", s.x, s.y + p * 20)
				s.fs:SetAlpha(1 - p * p)
			end
		end
	end
end

------------------------------------------------------------------------
-- Per-frame drawing
------------------------------------------------------------------------
local function drawHeroes(now)
	local list = ns.Combat.heroes
	local backX
	for i = 1, ns.PARTY_SIZE do
		local f = heroFrames[i]
		local u = list[i]
		if u then
			if f.shownId ~= u.id then
				f.shownId = u.id
				UI.SetClassIcon(f.icon, u.id)
				local r, g, b = U.rgb(ns.ROLE[u.role].hex)
				UI.Fill(f.border, r, g, b, 1)
			end
			local px = laneX(u.x) - UNIT / 2
			if u.anim > 0 then px = px + 4 end
			local bob = (not u.dead and ns.Combat.state.phase == "travel") and (sin(now * 10 + i) * 1.5) or 0
			place(f, px, 12 + bob)
			if not backX or u.x < backX then backX = u.x end
			if u.dead then
				f:SetAlpha(0.3)
				f.icon:SetDesaturated(true)
				f.hp:SetValue(1 - u.reviveT / 20)
				f.hp:SetRGB(0.5, 0.5, 0.5)
				f.tint:Hide()
				f.shield:Hide()
			else
				f:SetAlpha(1)
				f.icon:SetDesaturated(false)
				local r = u.hp / u.maxhp
				f.hp:SetValue(r)
				if r > 0.5 then f.hp:SetRGB(0.2, 0.85, 0.2) elseif r > 0.25 then f.hp:SetRGB(0.9, 0.75, 0.1) else f.hp:SetRGB(0.9, 0.15, 0.1) end
				paintStatus(f, u)
				if u.shield > 0 then
					f.shield:SetWidth(max(1, UNIT * min(1, u.shield / u.maxhp)))
					f.shield:Show()
				else
					f.shield:Hide()
				end
			end
			if u.flash > 0 then f.flash:Show() else f.flash:Hide() end
			if (u.castT or 0) > 0 and u.castIcon then
				if f.castIcon ~= u.castIcon then
					f.castIcon = u.castIcon
					UI.SetIcon(f.cast, u.castIcon)
				end
				f.cast:SetAlpha(min(1, u.castT / 0.3))
				f.cast:Show()
			else
				f.cast:Hide()
			end
			f:Show()
		else
			f:Hide()
			f.shownId = nil
		end
	end
	-- companion trots behind the party
	local pet = ns.db.pet and ns.PET_BY_ID[ns.db.pet]
	if pet and backX and ns.db.pets[pet.id] then
		if frame.pet.shownId ~= pet.id then
			frame.pet.shownId = pet.id
			UI.SetIcon(frame.pet.icon, pet.icon)
		end
		place(frame.pet, max(2, laneX(backX) - UNIT / 2 - 22), 12 + sin(now * 5) * 2)
		frame.pet:Show()
	else
		frame.pet:Hide()
	end
end

local function drawMobs()
	local list = ns.Combat.mobs
	for i = 1, MAX_MOBS do
		local f = mobFrames[i]
		local m = list[i]
		if m and m.x < 1030 then
			local size = m.boss and BOSS or UNIT
			if f.shownIcon ~= m.icon or f.size ~= size then
				f.shownIcon = m.icon
				f.size = size
				UI.SetIcon(f.icon, m.icon)
				f:SetSize(size, size)
				f.hp:SetWidth(size)
				f.hp.inner = size - 2
				if m.boss then UI.Fill(f.border, 1, 0.75, 0.1, 1) else UI.Fill(f.border, 0.45, 0.08, 0.08, 1) end
			end
			local px = laneX(m.x) - size / 2
			if m.anim > 0 then px = px - 4 end
			place(f, px, 12 + (m.boss and 0 or (m.off / 12) * 3))
			if m.dead then
				f:SetAlpha(max(0, (m.fade or 0) / 0.4))
				f.tint:Hide()
			else
				f:SetAlpha(1)
				paintStatus(f, m)
			end
			f.hp:SetValue(m.hp / m.maxhp)
			if (m.drT or 0) > 0 then f.hp:SetRGB(0.5, 0.7, 1) else f.hp:SetRGB(0.85, 0.15, 0.1) end
			if m.flash > 0 then f.flash:Show() else f.flash:Hide() end
			f:Show()
		else
			f:Hide()
			f.shownIcon = nil
		end
	end
end

local function updateInfo()
	local db = ns.db
	local st = ns.Combat.state
	local diff, idx = db.stage.diff, db.stage.idx
	if st.phase ~= "idle" and st.diff then
		diff, idx = st.diff, st.idx
	end
	local d = ns.DIFFS[diff]
	frame.stage:SetText(U.col(d.hex, ns.StageLabel(diff, idx)))
	local sub = ns.N(d.name) .. " · Lv " .. ns.StageLevel(diff, idx)
	if ns.STAGES[idx].raid then sub = sub .. " · " .. U.col("ff8000", ns.T("공격대", "Raid")) end
	if (db.retry or 0) > 0 and db.opt.auto then
		sub = sub .. " · " .. string.format(ns.T("재도전까지 %d회", "retry in %d"), db.retry)
	end
	frame.sub:SetText(sub)

	if st.phase == "idle" then
		frame.wave:SetValue(0)
		frame.wave:SetLabel(ns.T("영웅을 선택하세요", "Choose a hero"))
	else
		local waves = max(1, st.waves or 1)
		frame.wave:SetValue(min(1, (st.wave or 0) / waves))
		if st.wave == st.waves and st.phase == "fight" then
			frame.wave:SetLabel(U.col("ff6040", ns.T("우두머리!", "Boss!")))
		else
			frame.wave:SetLabel(string.format(ns.T("웨이브 %d/%d", "Wave %d/%d"), min(st.wave or 0, waves), waves))
		end
	end
	frame.gold:SetText(UI.Gold(db.gold))

	if st.phase == "result" then
		if st.result == "win" then
			frame.result:SetText(U.col("ffd100", ns.T("승리!", "Victory!")))
		else
			frame.result:SetText(U.col("ff4040", ns.T("전멸...", "Defeat...")))
		end
	else
		frame.result:SetText("")
	end

	for t = 1, #ns.CHEST do
		local n = ns.Loot.Count(t)
		local b = frame.chests[t]
		b:SetCount(n > 0 and tostring(n) or "")
		b:SetDim(n == 0)
		if n >= ns.ChestCap(t) then b:SetBorderRGB(1, 0.2, 0.2) else b:SetQuality(nil) end
	end
	frame.auto:SetLabel(db.opt.auto and ns.T("자동 진행: 켬", "Auto-advance: On") or ns.T("자동 진행: 끔", "Auto-advance: Off"))
	frame.auto:SetOn(db.opt.auto)
end

local function onUpdate(self, elapsed)
	local now = GetTime()
	drawHeroes(now)
	drawMobs()
	local fx = ns.Combat.fx
	if #fx > 0 then
		for i = 1, #fx do
			spawnFloat(fx[i])
			fx[i] = nil
		end
	end
	updateFloats(elapsed)
	if toastT > 0 then
		toastT = toastT - elapsed
		if toastT <= 0 then
			frame.toast:SetText("")
		else
			frame.toast:SetAlpha(min(1, toastT))
		end
	end
	infoT = infoT - elapsed
	if infoT <= 0 then
		infoT = 0.2
		updateInfo()
	end
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
local function chestTip(self)
	local t = self.chestType
	local def = ns.CHEST[t]
	local lines = {
		{ ns.N(def.name), nil, 1, 0.82, 0 },
		{ ns.T("보관 중", "Stored"), ns.Loot.Count(t) .. " / " .. ns.ChestCap(t), 1, 1, 1 },
	}
	if t == 1 then
		lines[#lines + 1] = { ns.T("일반 몬스터가 떨어뜨립니다.", "Dropped by regular monsters."), nil, 0.8, 0.8, 0.8 }
	elseif t == 2 then
		lines[#lines + 1] = { ns.T("스테이지 우두머리가 떨어뜨립니다.", "Dropped by stage bosses."), nil, 0.8, 0.8, 0.8 }
	else
		lines[#lines + 1] = { ns.T("각 막의 마지막 공격대 우두머리가 떨어뜨립니다.", "Dropped by the raid boss at the end of each act."), nil, 0.8, 0.8, 0.8 }
	end
	lines[#lines + 1] = { ns.T("한도를 넘으면 더 이상 쌓이지 않습니다.", "Nothing more is stored once it is full."), nil, 0.8, 0.8, 0.8 }
	if ns.Bonus("autoOpen") > 0 then
		local left = max(0, ns.Loot.AutoInterval(t) - (ns.db.autoT[t] or 0))
		lines[#lines + 1] = { ns.T("자동 개봉까지", "Auto-open in"), U.time(left), 0.5, 1, 0.5 }
	else
		lines[#lines + 1] = { ns.T("'개봉의 룬'을 배우면 자동으로 열립니다.", "Learn the Rune of Opening to open these automatically."), nil, 0.6, 0.6, 0.6 }
	end
	lines[#lines + 1] = { ns.T("클릭: 모두 열기", "Click: open all"), nil, 0.4, 0.8, 1 }
	return lines
end

function Bar.SavePosition()
	local p, _, rp, x, y = frame:GetPoint(1)
	if p then
		ns.db.ui.barPos = { p, rp or p, x or 0, y or 0 }
	end
end

function Bar.ApplyPosition()
	frame:ClearAllPoints()
	local pos = ns.db.ui.barPos
	if pos and pos[1] then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
	end
	frame:SetScale(ns.db.ui.scale or 1)
end

function Bar.Create()
	if frame then return frame end
	frame = CreateFrame("Frame", "BigIdleWoWHeroesBar", UIParent)
	frame:SetSize(W, H)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	UI.Box(frame, UI.COLOR.bg)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not ns.db.ui.locked then self:StartMoving() end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Bar.SavePosition()
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then ns.Main.Toggle() end
	end)

	-- left: stage info
	frame.stage = UI.Text(frame, 12)
	frame.stage:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	frame.stage:SetWidth(164)
	frame.stage:SetWordWrap(false)
	frame.sub = UI.Text(frame, 10)
	frame.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -25)
	frame.sub:SetWidth(164)
	frame.sub:SetWordWrap(false)
	frame.sub:SetTextColor(0.8, 0.8, 0.8)
	frame.wave = UI.Bar(frame, 160, 14, 0.75, 0.55, 0.15)
	frame.wave:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -42)
	frame.gold = UI.Text(frame, 12)
	frame.gold:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -64)

	-- middle: the lane
	local lane = UI.Panel(frame, LANE_W, LANE_H, UI.COLOR.inset, { 0, 0, 0, 1 })
	lane:SetPoint("LEFT", frame, "LEFT", LANE_X, 0)
	if lane.SetClipsChildren then lane:SetClipsChildren(true) end
	frame.lane = lane
	local ground = lane:CreateTexture(nil, "BORDER")
	ground:SetPoint("BOTTOMLEFT", lane, "BOTTOMLEFT", 1, 1)
	ground:SetPoint("BOTTOMRIGHT", lane, "BOTTOMRIGHT", -1, 1)
	ground:SetHeight(12)
	UI.Fill(ground, 0.20, 0.15, 0.09, 1)
	for i = 1, ns.PARTY_SIZE do heroFrames[i] = newUnit(lane) end
	for i = 1, MAX_MOBS do mobFrames[i] = newUnit(lane) end
	-- text lives on its own layer above the unit icons
	local overlay = CreateFrame("Frame", nil, lane)
	overlay:SetAllPoints(lane)
	overlay:SetFrameLevel(lane:GetFrameLevel() + 10)
	frame.overlay = overlay
	frame.result = UI.Text(overlay, 20, nil, "OUTLINE")
	frame.result:SetPoint("CENTER", lane, "CENTER", 0, 6)
	frame.result:SetJustifyH("CENTER")
	frame.pet = CreateFrame("Frame", nil, lane)
	frame.pet:SetSize(16, 16)
	frame.pet.icon = frame.pet:CreateTexture(nil, "ARTWORK")
	frame.pet.icon:SetAllPoints(frame.pet)
	frame.pet:Hide()
	for i = 1, MAX_FLOATS do
		local fs = UI.Text(overlay, 10, nil, "OUTLINE")
		fs:SetJustifyH("CENTER")
		fs:Hide()
		floats[i] = { fs = fs, active = false }
	end

	-- right: chests and buttons
	frame.chests = {}
	for t = 1, #ns.CHEST do
		local b = UI.IconButton(frame, 30, function(self)
			ns.Loot.OpenAll(self.chestType)
			UI.RefreshTip()
		end)
		b.chestType = t
		b:SetIconName(ns.CHEST[t].icon)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", LANE_X + LANE_W + 8 + (t - 1) * 34, -8)
		UI.Tip(b, chestTip, "TOP")
		frame.chests[t] = b
	end
	frame.menu = UI.Button(frame, 98, 20, ns.T("메뉴 열기", "Open Menu"), function() ns.Main.Toggle() end)
	frame.menu:SetPoint("TOPLEFT", frame, "TOPLEFT", LANE_X + LANE_W + 8, -43)
	frame.auto = UI.Button(frame, 98, 18, "", function()
		ns.db.opt.auto = not ns.db.opt.auto
		if ns.db.opt.auto then ns.db.retry = 0 end
		updateInfo()
		ns.Fire("OPTIONS")
	end)
	frame.auto:SetPoint("TOPLEFT", frame, "TOPLEFT", LANE_X + LANE_W + 8, -67)
	UI.Tip(frame.auto, function()
		return UI.SimpleTip(ns.T("자동 진행", "Auto-advance"),
			ns.T("켜면 스테이지를 깰 때마다 다음 스테이지로 넘어갑니다. 끄면 현재 스테이지를 반복합니다.",
				"On: move to the next stage after every clear. Off: repeat the current stage."))
	end, "TOP")

	-- toast line floating above the bar
	frame.toast = UI.Text(frame, 11, nil, "OUTLINE")
	frame.toast:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	frame.toast:SetJustifyH("CENTER")
	frame.toast:SetWidth(W)

	frame:SetScript("OnUpdate", onUpdate)
	Bar.ApplyPosition()
	if ns.db.ui.shown == false then frame:Hide() end
	updateInfo()
	return frame
end

function Bar.Toggle(show)
	if not frame then return end
	if show == nil then show = not frame:IsShown() end
	ns.db.ui.shown = show and true or false
	if show then frame:Show() else frame:Hide() end
end

function Bar.IsShown()
	return frame and frame:IsShown()
end

function Bar.ResetPosition()
	ns.db.ui.barPos = nil
	if frame then Bar.ApplyPosition() end
end

ns.On("TOAST", function(msg)
	if not frame then return end
	frame.toast:SetText(msg)
	frame.toast:SetAlpha(1)
	toastT = 5
end)
