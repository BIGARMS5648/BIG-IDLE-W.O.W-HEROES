-- 3D model check (/bwi model): a window that shows the game's own 3D models
-- the way the battle bar uses them - the selected hero (an NPC of its class,
-- race and gender), the player's own character, a monster, a boss and a
-- summon; or the tinker's mech, turrets and drone; or 활력제 친구's drone
-- (its file, and a search for its model) and the turret candidates - and
-- plays animations on all of them. Every model function is called through pcall, and under each
-- model it says which ones this client has (됨 = worked, 없음 = the client
-- lacks it, 오류 = it failed) and the client's name for the NPC id.
local _, ns = ...

local UI, U = ns.UI, ns.U
local floor, pi, max, min = math.floor, math.pi, math.max, math.min

local Check = {}
ns.ModelCheck = Check

-- animation ids the battle would use (the number shows, and ◀ ▶ step
-- through every id, in case a name sits on another number in this client)
local ANIMS = {
	{ 0, "서기" }, { 4, "걷기" }, { 5, "달리기" }, { 17, "공격" }, { 53, "시전" }, { 9, "피격" }, { 1, "죽음" },
}
local ANIM_NAME = {}
for _, a in ipairs(ANIMS) do ANIM_NAME[a[1]] = a[2] end

-- the sample models: creature ids (NPC ids) for the monster, boss and summon
local SAMPLES = {
	{ key = "hero", title = "영웅 (전투 창 모델)", kind = "DressUpModel" },
	{ key = "player", title = "내 캐릭터", kind = "PlayerModel" },
	{ key = "mob", title = "몬스터: 호그", kind = "PlayerModel", creature = 448 },
	{ key = "boss", title = "우두머리: 라그나로스", kind = "PlayerModel", creature = 11502 },
	{ key = "pet", title = "소환물: 임프", kind = "PlayerModel", creature = 416 },
}
-- 땜장이 후보: what the tinker's mech, turret and drone could look like
local TINKER = {
	{ key = "mech_horde", title = "기갑 (호드)", creature = ns.MODEL.tinker.mech_horde },
	{ key = "mech_alliance", title = "기갑 (얼라이언스)", creature = ns.MODEL.tinker.mech_alliance },
	{ key = "turret", title = "포격: 포탑", creature = ns.MODEL.summon.turret_gun },
	{ key = "drone", title = "정비: 치유 드론", creature = ns.MODEL.summon.drone_heal },
	{ key = "heal_turret", title = "정비: 치유 포탑", creature = ns.MODEL.summon.turret_heal },
}
-- 드론·포탑: 활력제 친구's heal-ray drone (known only by its file: the
-- file itself, and a search for the model that wears it), the Hellfire cannons
-- and the turret used now
local DRONE = {
	{ key = "pickmeup", title = "활력제 친구 (파일)", file = ns.MODEL.file.drone_pickmeup },
	{ key = "pickmeup_find", title = "활력제 친구 (모델 찾기)", find = ns.MODEL.file.drone_pickmeup },
	{ key = "cannon1", title = ns.MODEL.cannon[1].name, creature = ns.MODEL.cannon[1].npc, display = ns.MODEL.cannon[1].display },
	{ key = "cannon2", title = ns.MODEL.cannon[2].name, creature = ns.MODEL.cannon[2].npc, display = ns.MODEL.cannon[2].display },
	{ key = "turret_now", title = "지금 포탑", creature = ns.MODEL.summon.turret_gun },
}
local SETS = { basic = SAMPLES, tinker = TINKER, drone = DRONE }
-- the model ids the drone search goes through
local FIND_FROM, FIND_TO, FIND_STEP = 100000, 140000, 400

local W, H = 830, 556
local PANEL_W, PANEL_H, MODEL_H, GAP = 154, 340, 210, 8
local LINES = 5

local frame
local panels = {}
local state = { anim = 0, facing = 0, dist = 1, cycle = false, cycleT = 0, cycleI = 1, loadT = 0, set = "basic" }

local OK, NO, ERR = U.col("60e070", "됨"), U.col("ff6a5a", "없음"), U.col("ff6a5a", "오류")

-- Calls m[name](m, ...) if the client has it: true (됨), nil (없음), false (오류)
local function call(m, name, ...)
	local fn = m and m[name]
	if type(fn) ~= "function" then return nil end
	local ok, res = pcall(fn, m, ...)
	if ok then return true, res end
	return false
end
local function mark(r) return r == true and OK or (r == nil and NO or ERR) end

local function newModel(parent, kind)
	local ok, m = pcall(CreateFrame, kind, nil, parent)
	if ok and m then return m, kind end
	ok, m = pcall(CreateFrame, "PlayerModel", nil, parent)
	if ok and m then return m, "PlayerModel" end
	return nil
end

local function setLine(p, i, text) p.lines[i]:SetText(text or "") end

-- The name the client gives an NPC id (from its creature cache; the first ask
-- may come back empty while the client fetches it).
local scanTip
local function npcName(id)
	local link = string.format("unit:Creature-0-0-0-0-%d-0000000000", id)
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
		local line = ok and data and data.lines and data.lines[1]
		if line and line.leftText and line.leftText ~= "" then return line.leftText end
	end
	if not scanTip then
		local ok, tip = pcall(CreateFrame, "GameTooltip", "BigWowIdleScanTip", nil, "GameTooltipTemplate")
		scanTip = ok and tip or false
	end
	if scanTip then
		scanTip:SetOwner(UIParent, "ANCHOR_NONE")
		local ok = pcall(scanTip.SetHyperlink, scanTip, link)
		local fs = _G.BigWowIdleScanTipTextLeft1
		local text = ok and fs and fs:GetText()
		scanTip:Hide()
		if text and text ~= "" then return text end
	end
end

------------------------------------------------------------------------
-- Putting the models up
------------------------------------------------------------------------
local applyLook, applyAnim -- (below)

local function showName(p)
	local name = npcName(p.def.creature)
	p.nameTries = (p.nameTries or 0) + 1
	if name then p.nameTries = nil end
	setLine(p, 2, "이름 " .. (name and U.col("ffffff", name) or U.col("aab3c8", "받는 중")))
end

-- the selected hero as the battle bar draws it: an NPC of its class, race
-- and gender (Data/Models.lua ns.MODEL.hero)
local function setupHero(p)
	local m = p.model
	local id = ns.Main.SelectedHero()
	local h = id and ns.db.heroes[id]
	local race = id and ns.Heroes.Race(id) or "HUMAN"
	local sex = h and h.sex or "M"
	local npc = id and ns.Figure3D.ForHero(id, false)
	p.name:SetText(string.format("%s · %s %s", h and ns.Heroes.ShortName(id) or "영웅 없음",
		ns.N(ns.RACES[race] and ns.RACES[race].name or race), ns.N(ns.SEX[sex].short)))
	if npc then
		p.def = { key = "hero", title = p.def.title, creature = npc }
		local disp = ns.MODEL.display and ns.MODEL.display[npc]
		if disp then
			setLine(p, 1, "모델 " .. disp .. " · SetDisplayInfo " .. mark(call(m, "SetDisplayInfo", disp)))
		else
			setLine(p, 1, "NPC " .. npc .. " · SetCreature " .. mark(call(m, "SetCreature", npc)))
		end
		p.nameTries = 0
		showName(p)
	else
		setLine(p, 1, "영웅 모델 없음")
	end
end

local function setupPlayer(p)
	p.name:SetText(UnitName and UnitName("player") or "player")
	setLine(p, 1, "SetUnit(\"player\") " .. mark(call(p.model, "SetUnit", "player")))
	setLine(p, 2, "")
end

-- An NPC by its model (display id: the game's own data, as the battle bar
-- does), or by the NPC id when there is no model id for it
local function setupCreature(p)
	local disp = p.def.display or (ns.MODEL.display and ns.MODEL.display[p.def.creature])
	p.name:SetText("NPC " .. p.def.creature .. (disp and (" · 모델 " .. disp) or ""))
	if disp then
		setLine(p, 1, "SetDisplayInfo " .. mark(call(p.model, "SetDisplayInfo", disp)))
	else
		setLine(p, 1, "SetCreature " .. mark(call(p.model, "SetCreature", p.def.creature)))
	end
	p.nameTries = 0
	showName(p) -- the client's own name for the id, on the second line
end

-- A model known only by its file
local function setupFile(p)
	p.name:SetText("파일 " .. p.def.file)
	setLine(p, 1, "SetModel " .. mark(call(p.model, "SetModel", p.def.file)))
	setLine(p, 2, "")
end

-- Looks for the model that wears the file: tries model ids one after another
-- and keeps those whose file is the drone's
local function setupFind(p)
	p.name:SetText("파일 " .. p.def.find .. "을 쓰는 모델")
	p.scan = { id = FIND_FROM, found = {} }
	setLine(p, 1, "찾는 중…")
	setLine(p, 2, "")
end

local function stepFind(p)
	local sc = p.scan
	local target = p.def.find
	for _ = 1, FIND_STEP do
		if sc.id > FIND_TO then break end
		if call(p.model, "SetDisplayInfo", sc.id) then
			local ok, file = call(p.model, "GetModelFileID")
			if ok and file == target then sc.found[#sc.found + 1] = sc.id end
		end
		sc.id = sc.id + 1
	end
	if sc.id <= FIND_TO then
		setLine(p, 1, string.format("찾는 중… %d / %d", sc.id - FIND_FROM, FIND_TO - FIND_FROM + 1))
		return
	end
	p.scan = nil
	if #sc.found > 0 then
		call(p.model, "SetDisplayInfo", sc.found[1])
		setLine(p, 1, U.col("60e070", "찾음") .. " · 모델 " .. table.concat(sc.found, ", ", 1, math.min(#sc.found, 4)))
	else
		call(p.model, "ClearModel")
		setLine(p, 1, U.col("ff6a5a", "못 찾음") .. string.format(" (모델 %d~%d)", FIND_FROM, FIND_TO))
	end
	applyLook(p)
	applyAnim(p)
	state.loadT = 1.6
end

local SETUP = { hero = setupHero, player = setupPlayer, pickmeup = setupFile, pickmeup_find = setupFind }

-- 전투 방향: heroes turned to the right (where the monsters come from),
-- monsters to the left; the facing value used shows in the window
local function facingOf(p)
	if not state.battle then return state.facing end
	-- the tinker's mech, turret and drone stand with the heroes
	local hero = state.set == "tinker" or state.set == "drone" or p.def.key == "hero" or p.def.key == "player"
	return hero and (pi / 2) or (3 * pi / 2)
end

function applyLook(p)
	local m = p.model
	local f = call(m, "SetFacing", facingOf(p))
	local d = call(m, "SetCamDistanceScale", state.dist)
	setLine(p, 4, "SetFacing " .. mark(f) .. " · 거리 " .. mark(d))
end

function applyAnim(p)
	local how, r = "SetAnimation", call(p.model, "SetAnimation", state.anim)
	if r == nil then how, r = "SetSequence", call(p.model, "SetSequence", state.anim) end
	setLine(p, 5, "동작 " .. how .. " " .. mark(r))
end

-- Models load a moment after they are set: what was loaded shows then.
local function reportLoad(p)
	local fileOk, file = call(p.model, "GetModelFileID")
	local text
	if fileOk == nil then
		text = "모델 파일 확인 " .. NO
	elseif file and file ~= 0 then
		text = U.col("60e070", "모델 불러옴") .. " · 파일 " .. tostring(file)
	else
		text = U.col("ff6a5a", "모델 안 불러짐")
	end
	local dOk, display = call(p.model, "GetDisplayInfo")
	if dOk and display and display ~= 0 then text = text .. " · 모델 " .. tostring(display) end
	p.file = file
	setLine(p, 3, text)
end

local function setupAll()
	for i, p in ipairs(panels) do
		p.def = SETS[state.set][i]
		p.titleText:SetText(p.def.title)
		p.nameTries, p.file, p.scan = nil, nil, nil
		setLine(p, 2, "")
		if p.model then
			call(p.model, "ClearModel")
			local fn = SETUP[p.def.key] or setupCreature
			fn(p)
			setLine(p, 3, U.col("aab3c8", "불러오는 중…"))
			applyLook(p)
			applyAnim(p)
		else
			p.name:SetText(p.def.title)
			setLine(p, 1, p.def.kind .. " 만들기 " .. NO)
		end
	end
	state.loadT = 1.6
end

local function animLabel()
	local name = ANIM_NAME[state.anim]
	return string.format("동작 번호 %d%s", state.anim, name and (" (" .. name .. ")") or "")
end

local function refresh()
	if not frame then return end
	frame.animText:SetText(animLabel())
	if state.battle then
		frame.lookText:SetText("영웅 90° · 몬스터 270°")
	else
		frame.lookText:SetText(string.format("방향 %d° · 거리 %s", floor(state.facing * 180 / pi + 0.5) % 360, U.num(state.dist, 2)))
	end
	frame.battleDir:SetStyle(state.battle and "primary" or "dark")
	for _, b in ipairs(frame.setButtons) do b:SetStyle(b.set == state.set and "primary" or "dark") end
	for _, b in ipairs(frame.animButtons) do b:SetStyle(b.anim == state.anim and "primary" or "dark") end
	frame.cycle:Refresh()
end

local function setAnim(id)
	state.anim = max(0, min(999, id))
	for _, p in ipairs(panels) do if p.model then applyAnim(p) end end
	refresh()
end

local function setLook(facing, dist, battle)
	state.battle = battle or false
	state.facing = facing % (2 * pi)
	state.dist = max(0.25, min(4, dist))
	for _, p in ipairs(panels) do if p.model then applyLook(p) end end
	refresh()
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local function build()
	frame = CreateFrame("Frame", "BigWowIdleModelCheck", UIParent)
	frame:SetSize(W, H)
	frame.isPopup = true -- sits over the menu on purpose
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	UI.Slice(frame, "shadow", "BACKGROUND", nil, 14)
	UI.Slice(frame, "panel", "BACKGROUND")
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	if UISpecialFrames then table.insert(UISpecialFrames, "BigWowIdleModelCheck") end

	local title = UI.Title(frame, "3D 모델 확인", 16)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
	local desc = UI.Text(frame, 11, "게임에 들어 있는 3D 모델을 띄워 보는 창입니다. 모델 아래 글자는 각 기능이 이 클라이언트에서 되는지(됨 · 없음 · 오류)입니다.")
	desc:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -40)
	desc:SetWidth(W - 90)
	desc:SetWordWrap(false)
	UI.Color(desc, UI.C.sub)
	local close = UI.Button(frame, 30, 30, "", function() Check.Toggle(false) end, "dark")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -14)
	-- which models: the basic check, or the tinker's candidates
	frame.setButtons = {}
	for i, s in ipairs({ { "drone", "드론·포탑" }, { "tinker", "땜장이 후보" }, { "basic", "기본 확인" } }) do
		local b = UI.Button(frame, 96, 24, s[2], function()
			state.set = s[1]
			setupAll()
			refresh()
		end, "dark")
		b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -54 - (i - 1) * 104, -12)
		b.set = s[1]
		frame.setButtons[i] = b
	end
	local x = UI.Glyph(close, "close", 14)
	x:SetPoint("CENTER", close, "CENTER", 0, 0)

	-- one card per sample: title, the model, its name, five lines of results
	for i, def in ipairs(SAMPLES) do
		local card = UI.Panel(frame, PANEL_W, PANEL_H, "card")
		card:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + (i - 1) * (PANEL_W + GAP), -66)
		local t = UI.Text(card, 12, def.title)
		t:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
		t:SetWidth(PANEL_W - 16)
		t:SetWordWrap(false)
		UI.Color(t, UI.C.gold)
		local p = { def = def, card = card, lines = {}, titleText = t }
		local m, kind = newModel(card, def.kind)
		p.model, p.kind = m, kind
		if m then
			m:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -26)
			m:SetSize(PANEL_W - 8, MODEL_H)
		end
		p.name = UI.Text(card, 11)
		p.name:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -26 - MODEL_H - 4)
		p.name:SetWidth(PANEL_W - 16)
		p.name:SetWordWrap(false)
		for k = 1, LINES do
			local l = UI.Text(card, 10)
			l:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -26 - MODEL_H - 22 - (k - 1) * 15)
			l:SetWidth(PANEL_W - 16)
			l:SetWordWrap(false)
			UI.Color(l, UI.C.sub)
			p.lines[k] = l
		end
		panels[i] = p
	end

	-- animations: the usual ones, then any number
	local y = -66 - PANEL_H - 14
	local label = UI.Text(frame, 12, "동작")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, y - 8)
	frame.animButtons = {}
	local bx = 62
	for i, a in ipairs(ANIMS) do
		local b = UI.Button(frame, 66, 28, a[2], function() state.cycle = false setAnim(a[1]) end, "dark")
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", bx + (i - 1) * 72, y)
		b.anim = a[1]
		frame.animButtons[i] = b
	end
	local prev = UI.Button(frame, 30, 28, "<", function() state.cycle = false setAnim(state.anim - 1) end, "dark")
	prev:SetPoint("TOPLEFT", frame, "TOPLEFT", bx + #ANIMS * 72 + 8, y)
	frame.animText = UI.Text(frame, 12)
	frame.animText:SetPoint("LEFT", prev, "RIGHT", 8, 0)
	frame.animText:SetWidth(128)
	frame.animText:SetJustifyH("CENTER")
	frame.animText:SetWordWrap(false)
	local nxt = UI.Button(frame, 30, 28, ">", function() state.cycle = false setAnim(state.anim + 1) end, "dark")
	nxt:SetPoint("LEFT", frame.animText, "RIGHT", 8, 0)

	-- facing and camera distance; the automatic cycle
	local y2 = y - 40
	local look = UI.Text(frame, 12, "보기")
	look:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, y2 - 8)
	local function btn(text, w, x, fn)
		local b = UI.Button(frame, w, 28, text, fn, "dark")
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y2)
		return b
	end
	btn("< 돌리기", 76, 62, function() setLook(state.facing - pi / 4, state.dist) end)
	btn("정면", 52, 144, function() setLook(0, state.dist) end)
	btn("돌리기 >", 76, 202, function() setLook(state.facing + pi / 4, state.dist) end)
	frame.battleDir = btn("전투 방향", 80, 284, function() setLook(state.facing, state.dist, true) end)
	UI.Tip(frame.battleDir, function()
		return UI.SimpleTip("전투 방향", "전투 창에서 쓸 방향으로 돌립니다. 영웅 둘은 오른쪽, 몬스터·우두머리·소환물은 왼쪽을 보면 맞습니다.")
	end, "TOP")
	btn("가까이", 60, 370, function() setLook(state.facing, state.dist - 0.25, state.battle) end)
	btn("멀리", 52, 436, function() setLook(state.facing, state.dist + 0.25, state.battle) end)
	frame.lookText = UI.Text(frame, 12)
	frame.lookText:SetPoint("TOPLEFT", frame, "TOPLEFT", 498, y2 - 8)
	frame.lookText:SetWidth(120)
	frame.lookText:SetWordWrap(false)
	frame.cycle = UI.Check(frame, "동작 자동 순환", function() return state.cycle end, function(v)
		state.cycle = v
		state.cycleT = 0
		refresh()
	end)
	frame.cycle:SetPoint("TOPLEFT", frame, "TOPLEFT", 626, y2 - 2)
	local again = UI.Button(frame, 120, 28, "다시 불러오기", function() setupAll() refresh() end, "blue")
	again:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 16)
	frame.again = again

	-- client facts that decide how the battle bar can be built
	frame.info = UI.Text(frame, 11)
	frame.info:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 24)
	frame.info:SetWidth(W - 180)
	frame.info:SetWordWrap(false)
	UI.Color(frame.info, UI.C.sub)
	local scene, sceneFrame = pcall(CreateFrame, "ModelScene", nil, frame)
	if scene and sceneFrame then sceneFrame:Hide() end
	local buildNo = GetBuildInfo and select(4, GetBuildInfo())
	frame.info:SetText(string.format("ModelScene %s · 클라이언트 빌드 %s", scene and OK or NO, tostring(buildNo or "?")))

	frame:SetScript("OnUpdate", function(_, dt)
		for _, p in ipairs(panels) do
			if p.scan and p.model then stepFind(p) end
			-- NPC names the client did not have yet
			if p.nameTries and p.nameTries < 8 then
				p.nameT = (p.nameT or 0) - dt
				if p.nameT <= 0 then p.nameT = 1 showName(p) end
			end
		end
		if state.loadT > 0 then
			state.loadT = state.loadT - dt
			if state.loadT <= 0 then
				for _, p in ipairs(panels) do if p.model then reportLoad(p) end end
			end
		end
		if state.cycle then
			state.cycleT = state.cycleT - dt
			if state.cycleT <= 0 then
				state.cycleT = 2.5
				state.cycleI = state.cycleI % #ANIMS + 1
				setAnim(ANIMS[state.cycleI][1])
			end
		end
	end)
	frame:Hide()
end

function Check.Toggle(show)
	if not frame then build() end
	if show == nil then show = not frame:IsShown() end
	if show then
		frame:Show()
		setupAll()
		refresh()
	else
		frame:Hide()
	end
end

function Check.Frame() return frame end
Check.panels = panels
Check.state = state
