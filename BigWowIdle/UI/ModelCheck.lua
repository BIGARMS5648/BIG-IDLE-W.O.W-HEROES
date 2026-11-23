-- 3D model check (/bwi model): a window that shows the game's own 3D models
-- the way the battle bar uses them - the selected hero (an NPC of its class,
-- race and gender), the player's own character, a monster, a boss and a
-- summon; or the tinker's mech, turrets and drone; or other mechs, drones
-- and robots to choose from - and plays animations on all of them. Every model function is called through pcall, and under each
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
-- (the first stage's first monster, the Molten Core's last boss)
local FIRST_MOB = ns.STAGES[1][1].mobs[1][1]
local SAMPLES = {
	{ key = "hero", title = "영웅 (전투 창 모델)", kind = "DressUpModel" },
	{ key = "player", title = "내 캐릭터", kind = "PlayerModel" },
	{ key = "mob", title = "몬스터: " .. ns.MONSTERS[FIRST_MOB].name, kind = "PlayerModel", creature = ns.MODEL.mob[FIRST_MOB] },
	{ key = "boss", title = "우두머리: " .. ns.STAGES[4][10].boss.name, kind = "PlayerModel", creature = ns.MODEL.boss["4-10"] },
	{ key = "pet", title = "소환물: 임프", kind = "PlayerModel", creature = 416 },
}
-- 땜장이 후보: what the tinker's mech, turret and drone could look like
local M, S = ns.MODEL.mech, ns.MODEL.summon
local TINKER = {
	{ key = "mech_horde", title = "기갑 (호드)", creature = M.HORDE[1], name = "스니드의 벌목기" },
	{ key = "mech_alliance", title = "기갑 (얼라이언스)", creature = M.ALLIANCE[1], name = "거대 전차 마크 II" },
	{ key = "turret", title = "포격: 포탑", creature = S.turret_gun, name = "기계화 보초병" },
	{ key = "drone", title = "정비: 치유 드론", creature = S.drone_heal, name = "꼬마 폴폴이" },
	{ key = "heal_turret", title = "정비: 치유 포탑", creature = S.turret_heal, name = "야전수리로봇 74A" },
}
-- 다른 후보: more mechs, drones and robots to choose from
local OTHER = {}
for i, c in ipairs(ns.MODEL.candidates) do
	OTHER[i] = { key = "other" .. i, title = c.name, creature = c.npc, name = c.name }
end
local SETS = { basic = SAMPLES, tinker = TINKER, other = OTHER }
-- pages drawn their own way (not the five cards)
local PAGES = {}

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
	local npc = id and ns.Figure3D.ForHero(id, false)
	p.name:SetText(string.format("%s · %s %s", h and ns.Heroes.ShortName(id) or "영웅 없음",
		ns.N(ns.RACES[race] and ns.RACES[race].name or race), ns.SEX[id and ns.Heroes.Sex(id) or "M"].short))
	if npc then
		p.def = { key = "hero", title = p.def.title, creature = npc }
		local disp = ns.MODEL.display and ns.MODEL.display[npc]
		if disp then
			setLine(p, 1, "모델 " .. disp .. " · 표시 " .. mark(call(m, "SetDisplayInfo", disp)))
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
		setLine(p, 1, "모델 표시 " .. mark(call(p.model, "SetDisplayInfo", disp)))
	else
		setLine(p, 1, "SetCreature " .. mark(call(p.model, "SetCreature", p.def.creature)))
	end
	if p.def.name then
		-- the name we know (the server may not know this NPC)
		setLine(p, 2, "이름 " .. U.col("ffffff", p.def.name))
	else
		p.nameTries = 0
		showName(p) -- the client's own name for the id, on the second line
	end
end

local SETUP = { hero = setupHero, player = setupPlayer }

-- 전투 방향: heroes turned to the right (where the monsters come from),
-- monsters to the left; the facing value used shows in the window
local function facingOf(p)
	if not state.battle then return state.facing end
	-- the tinker's mech, turret and drone stand with the heroes
	local hero = state.set == "tinker" or state.set == "other" or p.def.key == "hero" or p.def.key == "player"
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
	local page = PAGES[state.set]
	for name, pg in pairs(PAGES) do
		if pg.frame then pg.frame:SetShown(pg == page) end
	end
	for _, p in ipairs(panels) do p.card:SetShown(not page) end
	if page then
		page.setup()
		return
	end
	for i, p in ipairs(panels) do
		p.def = SETS[state.set][i]
		p.titleText:SetText(p.def.title)
		p.nameTries, p.file = nil, nil
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
	local page = PAGES[state.set]
	if page and page.anim then page.anim(state.anim) end
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
-- 전투 모습: the models as the battle bar draws them, side by side on one
-- ground line at the battle's sizes (twice as big)
------------------------------------------------------------------------
local BATTLE_K, GROUND = 2, 70
local battle = {}
PAGES.battle = battle

function battle.build(win)
	local f = UI.Panel(win, W - 36, PANEL_H, "card")
	f:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -66)
	if f.SetClipsChildren then f:SetClipsChildren(true) end
	f:Hide()
	battle.frame = f
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetHeight(2)
	line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, GROUND)
	line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, GROUND)
	UI.Fill(line, 1, 0.82, 0.3, 0.6)
	local t = UI.Text(f, 11, "전투 창과 같은 방식으로 띄운 모델입니다. 노란 선이 땅이고, 모든 모델의 발이 선 위에 서야 합니다.")
	t:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	t:SetWidth(W - 56)
	t:SetWordWrap(false)
	UI.Color(t, UI.C.sub)
	-- the writing sits on a layer above the models
	local over = CreateFrame("Frame", nil, f)
	over:SetAllPoints(f)
	over:SetFrameLevel(f:GetFrameLevel() + 30)
	battle.over = over
	battle.cam = UI.Text(over, 11)
	battle.cam:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
	battle.cam:SetWidth(W - 56)
	battle.cam:SetWordWrap(false)
	battle.slots = {}
	for i = 1, 6 do
		local slot = {}
		slot.name = UI.Text(over, 11)
		slot.name:SetWidth(124)
		slot.name:SetJustifyH("CENTER")
		slot.name:SetWordWrap(false)
		slot.state = UI.Text(over, 10)
		slot.state:SetWidth(124)
		slot.state:SetJustifyH("CENTER")
		slot.state:SetWordWrap(false)
		UI.Color(slot.state, UI.C.sub)
		slot.size = UI.Text(over, 10)
		slot.size:SetWidth(124)
		slot.size:SetJustifyH("CENTER")
		slot.size:SetWordWrap(false)
		UI.Color(slot.size, UI.C.sub)
		slot.fix = UI.Text(over, 10)
		slot.fix:SetWidth(124)
		slot.fix:SetJustifyH("CENTER")
		slot.fix:SetWordWrap(false)
		UI.Color(slot.fix, UI.C.sub)
		battle.slots[i] = slot
	end
end

-- the camera factor the figures use and where it came from
local function camText()
	local F = ns.Figure3D
	local info = F.camInfo or {}
	local how
	if info.how == "measured" then
		how = U.col("60e070", "게임 투영으로 잼") .. " (" .. tostring(info.units) .. ", 회전 " .. (info.sense == -1 and "반대" or "기본") .. ")"
	else
		how = U.col("ffb84a", "기본값") .. (info.why and (" (" .. tostring(info.why) .. ")") or "")
		local r = F.lastRaw
		if r then how = how .. string.format(" · 투영 %.1f, %.1f, %.1f / 틀 %.0f", r[1], r[2], r[3], r[4]) end
	end
	return string.format("카메라 거리 보정 %.2f배 · %s", F.camFix or 1, how)
end

-- how a figure corrected itself after measuring where the game drew it
local function fixText(fig)
	local f = fig and fig.fixInfo
	if not f then return fig and fig.fixWhy and U.col("ffb84a", "보정 못 함") or "" end
	return string.format("보정 크기 ×%.2f · 발 %+.0f", f.scale, f.dy)
end

-- the model's measured box: height and length in its own units
local function sizeText(fig)
	local b = fig and fig.box
	if not b then return "" end
	local h = b[6] - b[3]
	local long = math.max(math.abs(b[4] - b[1]), math.abs(b[5] - b[2]))
	return string.format("키 %.2f · 길이 %.2f", h, long)
end

local function battleState(fig)
	if not fig then return U.col("ff6a5a", "모델 없음") end
	local how = fig.kind == "scene" and "장면" or "모델 틀"
	local load
	if fig:IsLoaded() then
		load = U.col("60e070", "불러옴")
	elseif fig.id then
		load = U.col("aab3c8", "불러오는 중")
	else
		load = U.col("ff6a5a", "안 불러짐")
	end
	local size = ""
	if fig.kind == "scene" and fig:IsLoaded() then
		size = " · " .. (fig.box and U.col("60e070", "크기 잼") or U.col("ff6a5a", "크기 못 잼"))
	end
	return how .. " · " .. load .. size
end

function battle.setup()
	local list = {}
	local party = ns.db and ns.db.party or {}
	for i = 1, ns.PARTY_SIZE do
		local id = party[i]
		if id and ns.db.heroes[id] and #list < 3 then
			list[#list + 1] = { npc = ns.Figure3D.ForHero(id, true), body = ns.Figure3D.HeroBody(id, true), h = 74 * ns.Figure3D.HeroScale(id), face = "right", name = ns.Heroes.ShortName(id) }
		end
	end
	local st = ns.db and ns.db.stage or {}
	local stage = ns.Stage(st.diff or 1, st.idx or 1)
	if stage then
		local mob = stage.mobs[1] and stage.mobs[1][1]
		if mob then list[#list + 1] = { npc = ns.MODEL.mob[mob], h = 70, face = "left", name = ns.N(ns.MONSTERS[mob].name) } end
		list[#list + 1] = { npc = ns.MODEL.boss[(st.diff or 1) .. "-" .. (st.idx or 1)], h = 98, face = "left", name = ns.N(stage.boss.name) }
	end
	list[#list + 1] = { npc = ns.MODEL.boss["4-10"], h = 98, face = "left", name = ns.N(ns.STAGES[4][10].boss.name) }
	local f = battle.frame
	local step = (W - 36) / #list
	for i, slot in ipairs(battle.slots) do
		local e = list[i]
		if slot.fig then slot.fig:Hide() end
		slot.name:SetShown(e ~= nil)
		slot.state:SetShown(e ~= nil)
		if e then
			slot.fig = slot.fig or ns.Figure3D.New(f, 64)
			local x = step * (i - 0.5)
			if slot.fig then
				slot.fig.id = nil
				slot.fig:SetHeight2(e.h * BATTLE_K)
				slot.fig:SetFacing(e.face)
				ns.Figure3D.ResetFailed()
				if not (e.body and slot.fig:SetBody(e.body)) then slot.fig:SetModelId(e.npc) end
				slot.fig:PlaceFeet(f, x, GROUND)
				slot.fig:Show()
			end
			slot.name:ClearAllPoints()
			slot.name:SetPoint("TOP", f, "BOTTOMLEFT", x, GROUND - 6)
			slot.name:SetText(e.name or "")
			slot.state:ClearAllPoints()
			slot.state:SetPoint("TOP", slot.name, "BOTTOM", 0, -3)
			slot.state:SetText(battleState(slot.fig))
			slot.size:ClearAllPoints()
			slot.size:SetPoint("TOP", slot.state, "BOTTOM", 0, -2)
			slot.size:SetText(sizeText(slot.fig))
			slot.fix:ClearAllPoints()
			slot.fix:SetPoint("TOP", slot.size, "BOTTOM", 0, -2)
			slot.fix:SetText(fixText(slot.fig))
		end
		slot.size:SetShown(e ~= nil)
		slot.fix:SetShown(e ~= nil)
	end
	battle.cam:SetText(camText())
end

function battle.step(dt)
	for _, slot in ipairs(battle.slots) do
		if slot.fig and slot.fig:IsShown() then
			slot.fig:Step(dt)
			slot.state:SetText(battleState(slot.fig))
			slot.size:SetText(sizeText(slot.fig))
			slot.fix:SetText(fixText(slot.fig))
		end
	end
	battle.cam:SetText(camText())
end

function battle.anim(id)
	for _, slot in ipairs(battle.slots) do
		if slot.fig and slot.fig:IsShown() and slot.fig.SetAnim then slot.fig:SetAnim(id) end
	end
end

------------------------------------------------------------------------
-- 효과: a spell's effects on the game's models, three ways side by side -
-- the battle bar's scene models with the spell's visual kits, model frames
-- with the same kits, and the effects' own model files placed by hand. The
-- chosen spell plays over and over: casting, the release, the missile flying,
-- the hit. Under each way it says which calls this client has.
------------------------------------------------------------------------
local fx = {}
PAGES.fx = fx
local FX_TOP = 34
local FX_H = PANEL_H - FX_TOP
local FX_W = floor((W - 36 - 2 * GAP) / 3)
local FX_GROUND, FX_FIG = 84, 96 -- the ground line over a card's bottom; a figure's height
local FX_LOOP, FX_RELEASE, FX_FLIGHT = 4.4, 1.3, 1.0
local FX_LINES = 4
local FX_WAYS = {
	{ key = "scene", title = "장면 모델 · 효과 키트" },
	{ key = "model", title = "모델 틀 · 효과 키트" },
	{ key = "file", title = "효과 모델 파일" },
}
fx.i = 1

local function fxSpell() return ns.SPELL_FX[fx.i] end

-- the caster: the hero model of the spell's class (as in battle), else its
-- trainer; the target: the first stage's first monster
local function fxCaster()
	local cls = ns.CLASSES[fxSpell().class]
	local id = cls and cls.specs and ns.Figure3D.ForSpec(cls.specs[1], ns.Faction(), "M")
	if id then return id end
	local t = ns.MODEL.trainer[fxSpell().class]
	t = t and t[ns.Faction() or "ALLIANCE"]
	return t and t.npc
end
local function fxTarget() return ns.MODEL.mob[FIRST_MOB] end

function fx.build(win)
	local f = CreateFrame("Frame", nil, win)
	f:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -66)
	f:SetSize(W - 36, PANEL_H)
	f:Hide()
	fx.frame = f
	-- one button per spell
	fx.buttons = {}
	local n = #ns.SPELL_FX
	local bw = ((W - 36) - (n - 1) * 6) / n
	for i, sp in ipairs(ns.SPELL_FX) do
		local b = UI.Button(f, bw, 26, sp.name, function() fx.Pick(i) end, "dark")
		b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (bw + 6), 0)
		fx.buttons[i] = b
	end
	fx.cards = {}
	for i, way in ipairs(FX_WAYS) do
		local card = UI.Panel(f, FX_W, FX_H, "card")
		card:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (FX_W + GAP), -FX_TOP)
		if card.SetClipsChildren then card:SetClipsChildren(true) end
		local line = card:CreateTexture(nil, "ARTWORK")
		line:SetHeight(2)
		line:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 6, FX_GROUND)
		line:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -6, FX_GROUND)
		UI.Fill(line, 1, 0.82, 0.3, 0.45)
		-- the writing sits on a layer above the models
		local over = CreateFrame("Frame", nil, card)
		over:SetAllPoints(card)
		over:SetFrameLevel(card:GetFrameLevel() + 30)
		local t = UI.Text(over, 12, way.title)
		t:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
		t:SetWidth(FX_W - 24)
		t:SetWordWrap(false)
		UI.Color(t, UI.C.gold)
		local c = { way = way, card = card, lines = {} }
		for k = 1, FX_LINES do
			local l = UI.Text(over, 10)
			l:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 12, FX_GROUND - 8 - (k - 1) * 15)
			l:SetWidth(FX_W - 24)
			l:SetWordWrap(false)
			UI.Color(l, UI.C.sub)
			c.lines[k] = l
		end
		fx.cards[i] = c
	end
end

local function fxX(c, k) return floor(FX_W * (k == "caster" and 0.24 or 0.76)) end

-- a model frame (PlayerModel) standing on the ground line
local function fxModel(c, x, w, h)
	local ok, m = pcall(CreateFrame, "PlayerModel", nil, c.card)
	if not ok or not m then return false end
	m:SetSize(w, h)
	m:SetPoint("BOTTOM", c.card, "BOTTOMLEFT", x, FX_GROUND - 6)
	return m
end

local function fxFig(c, h)
	local fig = ns.Figure3D.New(c.card, h)
	if fig and fig.kind ~= "scene" then fig:Hide() return false end
	return fig or false
end

local function loadedText(m)
	if not m then return NO end
	local inNow
	if m.IsLoaded and m.kind then
		inNow = m:IsLoaded()
	else
		local ok, file = call(m, "GetModelFileID")
		inNow = ok and file and file ~= 0
	end
	return inNow and U.col("60e070", "불러옴") or U.col("ff6a5a", "안 불러짐")
end

-- builds a card's models the first time
local function fxModels(c)
	if c.made then return end
	c.made = true
	local key = c.way.key
	if key == "model" then
		c.caster = fxModel(c, fxX(c, "caster"), 96, 130)
		c.target = fxModel(c, fxX(c, "target"), 96, 130)
		c.missile = fxModel(c, 0, 48, 48)
	else
		c.caster = fxFig(c, FX_FIG)
		c.target = fxFig(c, FX_FIG)
		c.missile = fxFig(c, FX_FIG)
		if key == "file" then
			c.hand = fxFig(c, 34)
			c.hit = fxFig(c, 60)
		end
	end
end

-- the kit call of a way: scene actors take SetSpellVisualKit, model frames
-- ApplySpellVisualKit (SetSpellVisualKit when the client has only that)
local function fxKit(c, m, kit, oneShot)
	if not m or not kit then return nil end
	if c.way.key == "scene" then
		if kit == 0 then return call(m.actor, "SetSpellVisualKit") end
		return call(m.actor, "SetSpellVisualKit", kit, oneShot)
	end
	if kit == 0 then return call(m, "SetSpellVisualKit") end
	local r = call(m, "ApplySpellVisualKit", kit, oneShot)
	if r == nil then r = call(m, "SetSpellVisualKit", kit, oneShot) end
	return r
end

local function fxAnim(c, m, id)
	if not m then return end
	if c.way.key == "model" then call(m, "SetAnimation", id) else m:SetAnim(id) end
end

-- where the missile is at a share of its flight
local function fxPath(c, share)
	local sp = fxSpell()
	local x0, y0 = fxX(c, "caster") + FX_FIG * 0.2, FX_GROUND + FX_FIG * 0.62
	local x1, y1 = fxX(c, "target") - FX_FIG * 0.12, FX_GROUND + FX_FIG * 0.55
	if sp.self then x1, y1 = x0, y0 end
	return x0 + (x1 - x0) * share, y0 + (y1 - y0) * share
end

local function fxPlace(c, m, x, y)
	if not m then return end
	m:ClearAllPoints()
	if c.way.key == "model" then
		m:SetPoint("CENTER", c.card, "BOTTOMLEFT", x, y)
	elseif m.fixedScale then
		m:PlaceFeet(c.card, x, y) -- its own origin on the path
	else
		m:PlaceFeet(c.card, x, y - (m.height or 0) / 2)
	end
end

function fx.Pick(i)
	fx.i = ((i - 1) % #ns.SPELL_FX) + 1
	fx.setup()
end

function fx.setup()
	local sp = fxSpell()
	for i, b in ipairs(fx.buttons) do b:SetStyle(i == fx.i and "primary" or "dark") end
	local caster, target = fxCaster(), fxTarget()
	local cDisp, tDisp = ns.Figure3D.DisplayFor(caster), ns.Figure3D.DisplayFor(target)
	ns.Figure3D.ResetFailed()
	for _, c in ipairs(fx.cards) do
		fxModels(c)
		c.res = {}
		for k = 1, FX_LINES do c.lines[k]:SetText("") end
		if c.way.key == "model" then
			for _, m in ipairs({ c.caster, c.target }) do
				if m then
					call(m, "ClearModel")
					m:Show()
				end
			end
			if c.caster then call(c.caster, "SetDisplayInfo", cDisp) call(c.caster, "SetFacing", pi / 2) end
			if c.target then call(c.target, "SetDisplayInfo", tDisp) call(c.target, "SetFacing", 3 * pi / 2) end
			if c.missile then
				call(c.missile, "ClearModel")
				if sp.missile then call(c.missile, "SetModel", sp.missile) end
				call(c.missile, "SetFacing", pi / 2)
				c.missile:Hide()
			end
		else
			-- a model the game lacks shows nothing (not the one before it)
			local function put(m, id, facing, x, body)
				m.id = nil
				m:SetHeight2(FX_FIG)
				m:SetFacing(facing)
				if (body and m:SetBody(body)) or m:SetModelId(id) then
					m:PlaceFeet(c.card, x, FX_GROUND)
					m:Show()
				else
					m.loaded = false
					m:Hide()
				end
			end
			-- the caster: the hero's own body (the player as the class's race, in its set)
			if c.caster then put(c.caster, caster, "right", fxX(c, "caster"), ns.Figure3D.BodyFor(sp.class)) end
			if c.target then put(c.target, target, "left", fxX(c, "target")) end
			for _, k in ipairs({ "missile", "hand", "hit" }) do
				local m = c[k]
				if m then
					m.id = nil
					m:SetHeight2(k == "missile" and FX_FIG or (k == "hand" and 34 or 60))
					m:SetFacing(k == "missile" and "right" or "front")
					if not (sp[k] and m:SetModelFile(sp[k])) then m.loaded = false end
					m:Hide()
				end
			end
		end
	end
	fx.t, fx.phase = 0, 0
	fx.lines()
end

-- what each way says under its models
function fx.lines()
	local sp = fxSpell()
	local kits = string.format("키트 %s · %s · %s", tostring(sp.precast or "-"), tostring(sp.cast or "-"), tostring(sp.impact or "-"))
	for _, c in ipairs(fx.cards) do
		local L = c.lines
		local models = "시전자 " .. loadedText(c.caster) .. " · 대상 " .. loadedText(c.target)
		local missile = sp.missile and ("투사체 파일 " .. loadedText(c.missile)) or "투사체 없음"
		if c.way.key == "scene" then
			L[1]:SetText("SetSpellVisualKit " .. (c.res.kit == nil and U.col("aab3c8", "…") or mark(c.res.kit)))
			L[2]:SetText(missile)
			L[3]:SetText(models)
			L[4]:SetText(kits)
		elseif c.way.key == "model" then
			L[1]:SetText("ApplySpellVisualKit " .. (c.res.kit == nil and U.col("aab3c8", "…") or mark(c.res.kit)))
			L[2]:SetText(missile)
			L[3]:SetText(models)
			L[4]:SetText(kits)
		else
			L[1]:SetText(sp.hand and ("손 효과 파일 " .. loadedText(c.hand)) or "손 효과 없음")
			L[2]:SetText(missile)
			L[3]:SetText(sp.hit and ("적중 효과 파일 " .. loadedText(c.hit)) or "적중 효과 없음")
			L[4]:SetText(models)
		end
	end
end

-- the steps of one cast, for every way at once
local function fxStart()
	local sp = fxSpell()
	for _, c in ipairs(fx.cards) do
		if sp.precast then fxAnim(c, c.caster, sp.omni and 52 or 51) end
		if c.way.key == "file" then
			if c.hand and sp.hand then
				fxPlace(c, c.hand, fxX(c, "caster") + FX_FIG * 0.18, FX_GROUND + FX_FIG * 0.58)
				c.hand:Show()
			end
		elseif sp.precast then
			c.res.kit = fxKit(c, c.caster, sp.precast, false)
		end
	end
end

local function fxRelease()
	local sp = fxSpell()
	for _, c in ipairs(fx.cards) do
		fxAnim(c, c.caster, sp.omni and 54 or 53)
		if c.way.key == "file" then
			if c.hand then c.hand:Hide() end
		else
			if sp.precast then fxKit(c, c.caster, 0) end
			local r = fxKit(c, c.caster, sp.cast, true)
			if c.res.kit == nil then c.res.kit = r end
		end
		if sp.missile and c.missile then
			-- as big as it really is next to the caster
			if c.way.key ~= "model" and c.caster and c.caster.loaded then
				c.missile:SetFixedScale((c.caster.norm or 0.5) * (c.caster.corrScale or 1))
			end
			local x, y = fxPath(c, 0)
			fxPlace(c, c.missile, x, y)
			c.missile:Show()
		end
	end
end

local function fxHit()
	local sp = fxSpell()
	for _, c in ipairs(fx.cards) do
		if c.missile then c.missile:Hide() end
		local who = sp.self and c.caster or c.target
		if not sp.self then fxAnim(c, c.target, 9) end
		if c.way.key == "file" then
			if c.hit and sp.hit then
				local x = sp.self and fxX(c, "caster") or fxX(c, "target")
				fxPlace(c, c.hit, x, FX_GROUND + FX_FIG * (sp.self and 0.25 or 0.55))
				c.hit:Show()
			end
		else
			local r = fxKit(c, who, sp.impact, true)
			if c.res.kit == nil then c.res.kit = r end
		end
	end
end

local function fxRest()
	for _, c in ipairs(fx.cards) do
		fxAnim(c, c.caster, 0)
		fxAnim(c, c.target, 0)
		if c.hit then c.hit:Hide() end
	end
end

function fx.step(dt)
	local sp = fxSpell()
	fx.t = (fx.t or 0) + dt
	local flight = sp.missile and FX_FLIGHT or 0.25
	if fx.phase == 0 then fxStart() fx.phase = 1 end
	if fx.phase == 1 and fx.t >= (sp.precast and FX_RELEASE or 0.3) then fxRelease() fx.phase, fx.released = 2, fx.t end
	if fx.phase == 2 then
		local share = (fx.t - fx.released) / flight
		if share >= 1 then
			fxHit()
			fx.phase = 3
		elseif sp.missile then
			for _, c in ipairs(fx.cards) do
				if c.missile then fxPlace(c, c.missile, fxPath(c, share)) end
			end
		end
	end
	if fx.phase == 3 and fx.t >= fx.released + flight + 1.0 then fxRest() fx.phase = 4 end
	if fx.t >= FX_LOOP then fx.t, fx.phase = 0, 0 end
	for _, c in ipairs(fx.cards) do
		if c.way.key ~= "model" then
			for _, k in ipairs({ "caster", "target", "missile", "hand", "hit" }) do
				local m = c[k]
				if m then m:Step(dt) end
			end
		end
	end
	fx.lines()
end

------------------------------------------------------------------------
-- 옷 입히기: a class's dungeon set on its race's own body (the race's base
-- model with nothing on), next to the bare body and the player's own
-- character; ◀ ▶ go through every class and faction, 남 · 여 the gender
------------------------------------------------------------------------
local dress = {}
PAGES.dress = dress
local DRESS_TOP, DRESS_MODEL_H = 32, 180
local DRESS_H = PANEL_H - DRESS_TOP

-- asRace: the player's own body made that race (SetModelByUnit's
-- customRaceID), nothing worn; mine: the race's body with the player's own
-- looks (SetModelByCreatureDisplayID's useActivePlayerCustomizations)
local DRESS = {
	{ title = "종족으로 바꾼 내 몸", kind = "scene", asRace = true, bare = true },
	{ title = "바꾼 몸에 입히기", kind = "scene", asRace = true },
	{ title = "종족 몸 + 내 꾸미기", kind = "scene", body = true, mine = true, bare = true },
	{ title = "꾸민 종족 몸에 입히기", kind = "scene", body = true, mine = true },
	{ title = "내 캐릭터에 입히기", kind = "DressUpModel", unit = true },
}

-- every class that has a dungeon set, for both factions: { class, faction, race }
local COMBOS = {}
for _, cls in ipairs(ns.CLASS_ORDER) do
	if ns.MODEL.dungeonSet[cls] then
		for _, fac in ipairs({ "ALLIANCE", "HORDE" }) do
			COMBOS[#COMBOS + 1] = { class = cls, faction = fac, race = ns.CLASS_RACE[cls][fac] }
		end
	end
end
dress.COMBOS = COMBOS
dress.i, dress.sex = 1, "M"

function dress.build(win)
	local f = CreateFrame("Frame", nil, win)
	f:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -66)
	f:SetSize(W - 36, PANEL_H)
	f:Hide()
	dress.frame = f
	-- which class, race and gender: ◀ [label] ▶  [남] [여]
	dress.prev = UI.Button(f, 30, 24, "<", function() dress.Pick(dress.i - 1) end, "dark")
	dress.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	dress.label = UI.Text(f, 12)
	dress.label:SetPoint("LEFT", dress.prev, "RIGHT", 10, 0)
	dress.label:SetWidth(440)
	dress.label:SetWordWrap(false)
	dress.next = UI.Button(f, 30, 24, ">", function() dress.Pick(dress.i + 1) end, "dark")
	dress.next:SetPoint("LEFT", dress.prev, "RIGHT", 460, 0)
	dress.sexBtn = {}
	for k, sx in ipairs(ns.SEXES) do
		local b = UI.Button(f, 44, 24, ns.SEX[sx].short, function() dress.Pick(dress.i, sx) end, "dark")
		b:SetPoint("LEFT", dress.next, "RIGHT", 16 + (k - 1) * 50, 0)
		dress.sexBtn[sx] = b
	end
	dress.cards = {}
	for i, def in ipairs(DRESS) do
		local card = UI.Panel(f, PANEL_W, DRESS_H, "card")
		card:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (PANEL_W + GAP), -DRESS_TOP)
		local t = UI.Text(card, 12, def.title)
		t:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
		t:SetWidth(PANEL_W - 16)
		t:SetWordWrap(false)
		UI.Color(t, UI.C.gold)
		local c = { def = def, card = card, lines = {} }
		c.name = UI.Text(card, 11)
		c.name:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -26 - DRESS_MODEL_H - 4)
		c.name:SetWidth(PANEL_W - 16)
		c.name:SetWordWrap(false)
		for k = 1, LINES do
			local l = UI.Text(card, 10)
			l:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -26 - DRESS_MODEL_H - 22 - (k - 1) * 15)
			l:SetWidth(PANEL_W - 16)
			l:SetWordWrap(false)
			UI.Color(l, UI.C.sub)
			c.lines[k] = l
		end
		dress.cards[i] = c
	end
end

local function combo() return COMBOS[dress.i] end

local function dressItems()
	local set = ns.MODEL.dungeonSet[combo().class]
	return set and set.items or {}
end

-- the race's own body for the gender picked
local function bodyDisplay()
	local b = ns.MODEL.raceBody[combo().race]
	return b and b[dress.sex]
end

-- the widget a card's model is shown in, made the first time
local function dressModel(c)
	if c.model ~= nil then return c.model end
	local def = c.def
	if def.kind == "scene" then
		local fig = ns.Figure3D.New(c.card, DRESS_MODEL_H / 1.5)
		if fig and fig.kind ~= "scene" then fig:Hide() fig = nil end
		c.model = fig or false
		if fig then fig:PlaceFeet(c.card, PANEL_W / 2, DRESS_H - 26 - DRESS_MODEL_H + 18) end
	else
		local ok, m = pcall(CreateFrame, def.kind, nil, c.card)
		if not ok or not m then ok, m = pcall(CreateFrame, "PlayerModel", nil, c.card) end
		c.model = (ok and m) or false
		if c.model then
			m:SetPoint("TOPLEFT", c.card, "TOPLEFT", 4, -26)
			m:SetSize(PANEL_W - 8, DRESS_MODEL_H)
		end
	end
	return c.model
end

-- ◀ ▶ and 남 · 여
function dress.Pick(i, sex)
	dress.i = ((i - 1) % #COMBOS) + 1
	if sex then dress.sex = sex end
	dress.setup()
end

function dress.setup()
	local cb = combo()
	local set = ns.MODEL.dungeonSet[cb.class]
	local raceName = ns.RACES[cb.race].name .. " " .. ns.SEX[dress.sex].short
	dress.label:SetText(string.format("%s (%s) · %s · %s   %d/%d", ns.N(ns.CLASSES[cb.class].name), ns.FACTIONS[cb.faction].name,
		raceName, set and set.name or "", dress.i, #COMBOS))
	for sx, b in pairs(dress.sexBtn) do b:SetStyle(sx == dress.sex and "primary" or "dark") end
	local disp = bodyDisplay()
	for _, c in ipairs(dress.cards) do
		local def, m = c.def, dressModel(c)
		c.name:SetText(def.unit and "내 캐릭터" or (def.asRace and (ns.RACES[cb.race].name .. " · 내 성별") or raceName))
		for k = 1, LINES do c.lines[k]:SetText("") end
		c.dressed, c.t = false, 0
		if not m then
			c.lines[1]:SetText((def.kind == "scene" and "ModelScene" or def.kind) .. " 만들기 " .. NO)
		elseif def.kind == "scene" then
			local a = m.actor
			m.loaded, m.id = false, nil
			m:SetFacing("front")
			m:Show()
			call(a, "ClearModel")
			call(a, "SetScale", 1)
			call(a, "SetYaw", 0)
			call(a, "SetPosition", 0, 0, 0)
			if def.asRace then
				-- the player, unarmed and undressed, as the race (game race id)
				local rid = ns.MODEL.raceId[combo().race]
				c.lines[1]:SetText("종족 " .. tostring(rid) .. " · SetModelByUnit " .. mark(call(a, "SetModelByUnit", "player", false, false, true, true, false, rid)))
			elseif def.unit then
				c.lines[1]:SetText("SetModelByUnit " .. mark(call(a, "SetModelByUnit", "player", false, true)))
			else
				c.lines[1]:SetText("몸 " .. tostring(disp) .. " · 표시 " .. mark(disp and call(a, "SetModelByCreatureDisplayID", disp, def.mine and true or nil) or nil))
			end
		else
			call(m, "ClearModel")
			call(m, "SetFacing", 0)
			if def.unit then
				c.lines[1]:SetText("SetUnit " .. mark(call(m, "SetUnit", "player")))
			else
				c.lines[1]:SetText("몸 " .. tostring(disp) .. " · 표시 " .. mark(disp and call(m, "SetDisplayInfo", disp) or nil))
			end
		end
	end
end

-- once the body is in (or after a moment): clothes off, the set on (the bare
-- body card keeps nothing on)
local function putOn(c)
	c.dressed = true
	local def, m = c.def, c.model
	local target = def.kind == "scene" and m.actor or m
	c.lines[2]:SetText("Undress " .. mark(call(target, "Undress")))
	if def.bare then
		c.lines[3]:SetText("입히지 않음 (몸만)")
	else
		local worn, tried = 0, 0
		for _, item in ipairs(dressItems()) do
			tried = tried + 1
			if call(target, "TryOn", "item:" .. item) == true then worn = worn + 1 end
		end
		c.lines[3]:SetText(string.format("TryOn %d/%d %s", worn, tried, worn == tried and tried > 0 and OK or (worn > 0 and ERR or NO)))
	end
	if def.kind == "scene" then
		m.loaded = true
		m:Measure()
		m:Look()
	end
end

function dress.step(dt)
	for _, c in ipairs(dress.cards) do
		local m = c.model
		if m and not c.dressed then
			c.t = c.t + dt
			local inNow
			if c.def.kind == "scene" then
				local ok, l = call(m.actor, "IsLoaded")
				inNow = ok and l
			else
				local ok, file = call(m, "GetModelFileID")
				inNow = ok and file and file ~= 0
			end
			if inNow or c.t > 1.5 then
				c.lines[4]:SetText(inNow and U.col("60e070", "모델 불러옴") or U.col("ff6a5a", "모델 안 불러짐"))
				putOn(c)
			end
		end
	end
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
	for i, s in ipairs({ { "fx", "효과" }, { "dress", "옷 입히기" }, { "battle", "전투 모습" }, { "other", "다른 후보" }, { "tinker", "땜장이 후보" }, { "basic", "기본 확인" } }) do
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
	btn("< 돌리기", 66, 62, function() setLook(state.facing - pi / 4, state.dist) end)
	btn("정면", 66, 134, function() setLook(0, state.dist) end)
	btn("돌리기 >", 66, 206, function() setLook(state.facing + pi / 4, state.dist) end)
	frame.battleDir = btn("전투 방향", 66, 278, function() setLook(state.facing, state.dist, true) end)
	UI.Tip(frame.battleDir, function()
		return UI.SimpleTip("전투 방향", "전투 창에서 쓸 방향으로 돌립니다. 영웅 둘은 오른쪽, 몬스터·우두머리·소환물은 왼쪽을 보면 맞습니다.")
	end, "TOP")
	btn("가까이", 66, 350, function() setLook(state.facing, state.dist - 0.25, state.battle) end)
	btn("멀리", 66, 422, function() setLook(state.facing, state.dist + 0.25, state.battle) end)
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
	local again = UI.Button(frame, 120, 28, "다시 불러오기", function()
		ns.Figure3D.ResetCalibration()
		setupAll()
		refresh()
	end, "blue")
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

	for _, pg in pairs(PAGES) do if pg.build then pg.build(frame) end end

	frame:SetScript("OnUpdate", function(_, dt)
		local page = PAGES[state.set]
		if page and page.step and page.frame and page.frame:IsShown() then page.step(dt) end
		for _, p in ipairs(panels) do
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

-- shows one set of models (basic, tinker, other, battle, dress)
function Check.ShowSet(name)
	if not frame then build() end
	state.set = name
	setupAll()
	refresh()
end
Check.panels = panels
Check.state = state
Check.pages = PAGES
