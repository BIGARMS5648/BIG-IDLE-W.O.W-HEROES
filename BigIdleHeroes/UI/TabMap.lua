-- Stages screen (스테이지): four worlds (one per difficulty) and the endless
-- tower (무한의 탑) as picture cards on top. A world: the three acts as tabs,
-- the act's ten stages as a path, and a card for the chosen stage on the
-- right. The tower: the floor to go to, the affixes (one more every fifth
-- floor) and a card for that floor.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main

local NODE_W, NODE_H = 96, 98
-- how experience goes by the stage's level (Heroes.XPFactor)
local XP_RULE = "스테이지 레벨이 영웅보다 10 넘게 높으면 1레벨마다 경험치가 5%씩 줄어듭니다."
local PATH_Y = -112
local DETAIL_X = 528

local function worldOpen(d)
	return d == 1 or (ns.db.prog[d - 1] or 0) >= ns.STAGE_COUNT
end

local function bossSkillText(sk)
	if sk.kind == "smash" then
		return string.format("강타 (피해 x%s)", U.num(sk.mult, 1))
	elseif sk.kind == "aoe" then
		return string.format("파티 전체 %s 공격", ns.N(ns.SCHOOL[sk.school or "phys"].name))
	elseif sk.kind == "summon" then
		return string.format("%s %d마리 소환", ns.N(ns.MONSTERS[sk.mob].name), sk.n)
	elseif sk.kind == "enrage" then
		return string.format("생명력 %d%% 이하에서 격노", sk.hp * 100)
	elseif sk.kind == "shield" then
		return string.format("%d초 동안 받는 피해 %d%% 감소", sk.dur, sk.dr)
	end
	return sk.kind
end

local function themeRGB(theme)
	local th = ns.THEMES[theme] or ns.THEMES.forest
	return th, th.rgb[1], th.rgb[2], th.rgb[3]
end

local TOWER_HEX = "b48cff"
local K_SEL = UI.K.SEL -- what is chosen
local AFFIX_ROW = 34

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	-- the stage path and its options on a dark inset, like the other screens'
	-- lists, level with the detail card on the right: drawn on the page
	-- itself (its background), over a box that only gives it its place
	local pathBox = CreateFrame("Frame", nil, page)
	pathBox:SetSize(DETAIL_X - 8, Main.PAGE_H - 76 - 30)
	pathBox:SetPoint("TOPLEFT", page, "TOPLEFT", 0, PATH_Y + 6)
	pathBox:EnableMouse(false)
	page.pathBg = UI.Slice(pathBox, "inset", "BACKGROUND", nil, nil, page)

	page.diff = ns.db.stage.diff
	page.idx = ns.db.stage.idx
	page.act = ns.StageAct(page.idx)

	-- worlds, and the tower after them
	page.worlds = {}
	local cards = #ns.DIFFS + 1
	local ww = floor((Main.PAGE_W - 8 * (cards - 1)) / cards)
	for d = 1, #ns.DIFFS do
		local w = CreateFrame("Button", nil, page)
		w:SetSize(ww, 66)
		w:SetPoint("TOPLEFT", page, "TOPLEFT", (d - 1) * (ww + 8), 0)
		w.scene = w:CreateTexture(nil, "BACKGROUND")
		w.scene:SetPoint("TOPLEFT", w, "TOPLEFT", 3, -3)
		w.scene:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -3, 3)
		-- the loading screen of the world's place (a band of it, in the card's shape)
		if not UI.SetLoadingScreen(w.scene, ns.WorldLoadingScreen(d), (ww - 6) / 60) then
			local stg = ns.STAGES[d][15]
			local th, r, g, b = themeRGB(stg.theme)
			w.scene:SetTexture(UI.Tex(th.art))
			w.scene:SetTexCoord(0.2, 0.6, 0.15, 0.85)
			w.scene:SetVertexColor(r * 0.7, g * 0.7, b * 0.7)
		end
		w.shade = UI.Art(w, "grad_h", "BORDER", 0, 0, 0, 0.75)
		w.shade:SetPoint("TOPLEFT", w, "TOPLEFT", 3, -3)
		w.shade:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 3, 3)
		w.shade:SetWidth(150)
		w.edge = UI.Slice(w, "frame", "OVERLAY", 11)
		w.diffChip = UI.Pill(w, 56, 18)
		local dr, dg, db2 = U.rgb(ns.DIFFS[d].hex)
		w.diffChip:SetColor(dr, dg, db2, 1)
		w.diffChip:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -8)
		w.diffChip:SetLabel(ns.N(ns.DIFFS[d].name))
		w.diffChip.text:SetTextColor(0.08, 0.08, 0.1)
		w.diffChip.text:SetShadowOffset(0, 0)
		w.name = UI.Text(w, 14, ns.N(ns.DIFFS[d].world))
		w.name:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -30)
		w.prog = UI.Text(w, 10)
		w.prog:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 10, 8)
		w.lockG = UI.Glyph(w, "lock", 22, 0.85, 0.75, 0.55)
		w.lockG:SetPoint("RIGHT", w, "RIGHT", -12, 0)
		w.d = d
		w:RegisterForClicks("LeftButtonUp")
		w:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.tower = false
			page.diff = self.d
			page.act = 1
			page.idx = 1
			Main.Refresh()
		end)
		UI.Tip(w, function(self)
			local dd = ns.DIFFS[self.d]
			local lines = { { ns.N(dd.world), ns.N(dd.name), U.rgb(dd.hex) } }
			lines[#lines + 1] = { string.format("스테이지 레벨 %d ~ %d", ns.StageLevel(self.d, 1), ns.StageLevel(self.d, ns.STAGE_COUNT)), nil, 1, 1, 1 }
			lines[#lines + 1] = { "높은 난이도일수록 몬스터가 많고 높은 등급 장비가 잘 나옵니다.", nil, 0.8, 0.8, 0.8 }
			if not worldOpen(self.d) then
				lines[#lines + 1] = { string.format("%s의 30개 스테이지를 모두 깨면 열립니다.", ns.N(ns.DIFFS[self.d - 1].world)), nil, 1, 0.35, 0.3 }
			end
			return lines
		end, "TOP")
		page.worlds[d] = w
	end
	page.towerCard = (function()
		local w = CreateFrame("Button", nil, page)
		w:SetSize(ww, 66)
		w:SetPoint("TOPLEFT", page, "TOPLEFT", #ns.DIFFS * (ww + 8), 0)
		w.scene = w:CreateTexture(nil, "BACKGROUND")
		w.scene:SetPoint("TOPLEFT", w, "TOPLEFT", 3, -3)
		w.scene:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -3, 3)
		if not UI.SetLoadingScreen(w.scene, ns.TowerLoadingScreen("card"), (ww - 6) / 60) then
			local th, r, g, b = themeRGB(ns.STAGES[#ns.DIFFS][ns.STAGE_COUNT].theme)
			w.scene:SetTexture(UI.Tex(th.art))
			w.scene:SetTexCoord(0.2, 0.6, 0.15, 0.85)
			w.scene:SetVertexColor(r * 0.7, g * 0.7, b * 0.7)
		end
		w.shade = UI.Art(w, "grad_h", "BORDER", 0, 0, 0, 0.75)
		w.shade:SetPoint("TOPLEFT", w, "TOPLEFT", 3, -3)
		w.shade:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 3, 3)
		w.shade:SetWidth(150)
		w.edge = UI.Slice(w, "frame", "OVERLAY", 11)
		w.diffChip = UI.Pill(w, 56, 18)
		local r, g, b = U.rgb(TOWER_HEX)
		w.diffChip:SetColor(r, g, b, 1)
		w.diffChip:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -8)
		w.diffChip:SetLabel("도전")
		w.diffChip.text:SetTextColor(0.08, 0.08, 0.1)
		w.diffChip.text:SetShadowOffset(0, 0)
		w.name = UI.Text(w, 14, "무한의 탑")
		w.name:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -30)
		w.prog = UI.Text(w, 10)
		w.prog:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 10, 8)
		w.lockG = UI.Glyph(w, "lock", 22, 0.85, 0.75, 0.55)
		w.lockG:SetPoint("RIGHT", w, "RIGHT", -12, 0)
		w:RegisterForClicks("LeftButtonUp")
		w:SetScript("OnClick", function()
			ns.Sound("click")
			page.tower = true
			page.floor = ns.db.tower.on and ns.db.tower.floor or ns.Tower.Top()
			Main.Refresh()
		end)
		UI.Tip(w, function()
			local lines = { { "무한의 탑", nil, U.rgb(TOWER_HEX) } }
			lines[#lines + 1] = { "층마다 다른 장소의 몬스터와 우두머리가 나오고, 10층마다 공격대 우두머리가 기다립니다.", nil, 1, 1, 1, true }
			lines[#lines + 1] = { "5층마다 신화+ 속성이 하나씩 더해집니다. 탑의 상자에서는 아이템 레벨 100 장비가 나옵니다.", nil, 0.8, 0.8, 0.8, true }
			if not ns.Tower.Open() then
				lines[#lines + 1] = { string.format("%s의 30개 스테이지를 모두 깨면 열립니다.", ns.N(ns.DIFFS[#ns.DIFFS].world)), nil, 1, 0.35, 0.3 }
			end
			return lines
		end, "TOP")
		return w
	end)()

	page.acts = {}
	for a = 1, 3 do
		local c = UI.Chip(page, 170, 26, "", function()
			page.act = a
			page.idx = (a - 1) * ns.STAGES_PER_ACT + 1
			Main.Refresh()
		end)
		c:SetPoint("TOPLEFT", page, "TOPLEFT", (a - 1) * 176, -76)
		page.acts[a] = c
	end

	-- stage path: two rows of five
	page.links = {}
	page.nodes = {}
	for n = 1, ns.STAGES_PER_ACT do
		local col, row = (n - 1) % 5, floor((n - 1) / 5)
		if row == 1 then col = 4 - col end -- snake back on the second row
		local b = CreateFrame("Button", nil, page)
		b:SetSize(NODE_W, NODE_H)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", 4 + col * (NODE_W + 8), PATH_Y - row * (NODE_H + 8))
		b.ringT = UI.Art(b, "ring", "ARTWORK")
		b.ringT:SetSize(52, 52)
		b.ringT:SetPoint("TOP", b, "TOP", 0, -2)
		b.disc = UI.Art(b, "circle", "BACKGROUND", 0.05, 0.06, 0.1)
		b.disc:SetSize(52, 52)
		b.disc:SetPoint("TOP", b, "TOP", 0, -2)
		b.icon = b:CreateTexture(nil, "ARTWORK", nil, -1)
		b.icon:SetSize(38, 38)
		b.icon:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow = UI.Art(b, "glow", "BACKGROUND", 0.35, 0.62, 1, 0.9)
		b.glow:SetSize(84, 84)
		b.glow:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow:Hide()
		b.state = UI.Glyph(b, "check", 18, 0.4, 1, 0.5)
		b.state:SetPoint("TOPRIGHT", b.disc, "TOPRIGHT", 4, 4)
		b.crown = UI.Glyph(b, "crown", 22, 1, 0.75, 0.25)
		b.crown:SetPoint("BOTTOM", b.disc, "TOP", 0, -6)
		b.num = UI.Text(b, 10)
		b.num:SetPoint("TOP", b.disc, "BOTTOM", 0, -2)
		b.num:SetJustifyH("CENTER")
		UI.Color(b.num, UI.C.sub)
		b.name = UI.Text(b, 11)
		b.name:SetPoint("TOP", b.num, "BOTTOM", 0, -1)
		b.name:SetJustifyH("CENTER")
		b.name:SetWidth(NODE_W + 6)
		b.name:SetWordWrap(false)
		b.n = n
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.idx = (page.act - 1) * ns.STAGES_PER_ACT + self.n
			Main.Refresh()
		end)
		page.nodes[n] = b
		if n > 1 then
			local prevCol = ((n - 2) % 5)
			local prevRow = floor((n - 2) / 5)
			-- (a rounded line from just clear of one stage's ring to the next;
			-- the disc's middle: its column's middle, 28 below its row's top)
			local link = { lines = {} }
			local cy = PATH_Y - row * (NODE_H + 8) - 28
			local T = 6
			local GAP = 28 -- from a ring's middle: just clear of the ring and its shadow
			local function line(vertical, x, y, len, squareA, squareB)
				local l = UI.Line3(page, "BACKGROUND")
				l:Place(page, "TOPLEFT", vertical, x, y, len, T, squareA, squareB)
				link.lines[#link.lines + 1] = l
			end
			local function bend(x, y, up)
				local l = UI.Bend(page, "BACKGROUND")
				l:Place(page, "TOPLEFT", x, y, T, up)
				link.lines[#link.lines + 1] = l
			end
			if prevRow == row then
				local c1 = (row == 1) and (4 - prevCol) or prevCol
				local cx1 = math.min(c1, col) * (NODE_W + 8) + NODE_W / 2
				line(false, cx1 + GAP, cy, NODE_W + 8 - 2 * GAP)
			else
				-- from stage 5 down to stage 6: a bracket to the right of the column,
				-- clear of stage 5's name; square ends meet a bend at each corner
				local cx = 4 * (NODE_W + 8) + NODE_W / 2
				local y1, y2 = PATH_Y - 28, PATH_Y - (NODE_H + 8) - 28
				local bx = 4 * (NODE_W + 8) + NODE_W + 6
				line(false, cx + GAP, y1, bx - T / 2 - (cx + GAP), false, true)
				bend(bx, y1)
				line(true, bx, y1 - T / 2, y1 - y2 - T, true, true)
				bend(bx, y2, true)
				line(false, cx + GAP, y2, bx - T / 2 - (cx + GAP), false, true)
			end
			page.links[n] = link
		end
	end

	-- options under the path
	local optY = PATH_Y - 2 * (NODE_H + 8) - 6
	page.checks = {
		UI.Check(page, "자동 진행 - 깨면 다음 스테이지로",
			function() return ns.db.opt.auto end, function(v) ns.db.opt.auto = v ns.db.retry = 0 ns.Fire("OPTIONS") end),
		UI.Check(page, "전멸하면 한 스테이지 물러나기",
			function() return ns.db.opt.retreat end, function(v) ns.db.opt.retreat = v end),
		UI.Check(page, "물러난 뒤 8번 깨면 다시 도전",
			function() return ns.db.opt.retry end, function(v)
				ns.db.opt.retry = v
				if not v and (ns.db.retry or 0) > 0 then
					-- stop the countdown and stay on the stage being farmed
					ns.db.retry = 0
					ns.db.opt.auto = false
				end
				ns.Fire("OPTIONS")
			end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", page, "TOPLEFT", 12, optY - (i - 1) * 24)
	end
	page.rate = UI.Text(page, 10)
	page.rate:SetPoint("TOPLEFT", page, "TOPLEFT", 12, optY - 78)
	page.rate:SetWidth(500)
	UI.Color(page.rate, UI.C.sub)
	-- what belongs to a world (hidden while the tower is shown)
	page.stageParts = { page.rate }
	for _, c in ipairs(page.acts) do page.stageParts[#page.stageParts + 1] = c end
	for _, b in ipairs(page.nodes) do page.stageParts[#page.stageParts + 1] = b end
	for _, l in pairs(page.links) do
		for _, ln in ipairs(l.lines) do page.stageParts[#page.stageParts + 1] = ln end
	end
	for _, c in ipairs(page.checks) do page.stageParts[#page.stageParts + 1] = c end

	-- the tower: the floor to go to, its affixes, the options
	local tv = CreateFrame("Frame", nil, page)
	tv:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -76)
	tv:SetSize(DETAIL_X - 12, Main.PAGE_H - 76)
	page.towerView = tv
	tv.prev = UI.PageButton(tv, 34, 30, "left", function()
		page.floor = math.max(1, (page.floor or 1) - 1)
		Main.Refresh()
	end)
	tv.prev:SetPoint("TOPLEFT", tv, "TOPLEFT", 0, 0)
	tv.floorPill = UI.Pill(tv, 104, 30, 0.2, 0.14, 0.32, 0.95)
	tv.floorPill:SetPoint("LEFT", tv.prev, "RIGHT", 6, 0)
	tv.next = UI.PageButton(tv, 34, 30, "right", function()
		page.floor = math.min(ns.Tower.Top(), (page.floor or 1) + 1)
		Main.Refresh()
	end)
	tv.next:SetPoint("LEFT", tv.floorPill, "RIGHT", 6, 0)
	tv.top = UI.Button(tv, 96, 30, "최고 층으로", function()
		page.floor = ns.Tower.Top()
		Main.Refresh()
	end, "dark")
	tv.top:SetPoint("LEFT", tv.next, "RIGHT", 6, 0)
	tv.record = UI.Text(tv, 11)
	tv.record:SetPoint("LEFT", tv.top, "RIGHT", 12, 0)
	tv.record:SetWidth(DETAIL_X - 12 - (34 + 6 + 104 + 6 + 34 + 6 + 96 + 12))
	tv.record:SetWordWrap(false)
	tv.head = UI.Section(tv, DETAIL_X - 16, "속성")
	tv.head:SetPoint("TOPLEFT", tv, "TOPLEFT", 0, -40)
	tv.rows = {}
	for i, a in ipairs(ns.TOWER_AFFIXES) do
		local r = CreateFrame("Frame", nil, tv)
		r:SetSize(DETAIL_X - 16, AFFIX_ROW - 2)
		r:SetPoint("TOPLEFT", tv, "TOPLEFT", 0, -64 - (i - 1) * AFFIX_ROW)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(24, 24)
		r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
		UI.SetIcon(r.icon, a.icon)
		r.name = UI.Text(r, 12, ns.N(a.name))
		r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -1)
		r.name:SetWidth(64)
		r.name:SetWordWrap(false)
		r.from = UI.Text(r, 10, string.format("%d층부터", ns.Tower.AffixFloor(i)))
		r.from:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -1)
		r.from:SetWidth(64)
		r.text = UI.Text(r, 10, ns.N(a.text))
		r.text:SetPoint("LEFT", r, "LEFT", 104, 0)
		r.text:SetWidth(DETAIL_X - 16 - 108)
		tv.rows[i] = r
	end
	local ty = -64 - #ns.TOWER_AFFIXES * AFFIX_ROW - 6
	tv.checks = {
		UI.Check(tv, "자동 진행 - 깨면 다음 층으로",
			function() return ns.db.opt.auto end, function(v) ns.db.opt.auto = v ns.db.retry = 0 ns.Fire("OPTIONS") end),
		UI.Check(tv, "전멸해 한 층 내려간 뒤 8번 깨면 다시 도전",
			function() return ns.db.opt.retry end, function(v)
				ns.db.opt.retry = v
				if not v and (ns.db.retry or 0) > 0 then
					ns.db.retry = 0
					ns.db.opt.auto = false
				end
				ns.Fire("OPTIONS")
			end),
	}
	for i, c in ipairs(tv.checks) do
		c:SetPoint("TOPLEFT", tv, "TOPLEFT", 4, ty - (i - 1) * 24)
	end

	-- detail card
	local d = UI.Panel(page, Main.PAGE_W - DETAIL_X, Main.PAGE_H - 76 - 30, "card")
	d:SetPoint("TOPLEFT", page, "TOPLEFT", DETAIL_X, PATH_Y + 6)
	page.detail = d
	d.banner = d:CreateTexture(nil, "BORDER")
	d.banner:SetPoint("TOPLEFT", d, "TOPLEFT", 4, -4)
	d.banner:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)
	d.banner:SetHeight(76)
	d.bannerShade = UI.Art(d, "grad_v", "ARTWORK", 0, 0, 0, 0.7)
	d.bannerShade:SetPoint("BOTTOMLEFT", d.banner, "BOTTOMLEFT", 0, 0)
	d.bannerShade:SetPoint("BOTTOMRIGHT", d.banner, "BOTTOMRIGHT", 0, 0)
	d.bannerShade:SetHeight(40)
	d.bannerShade:SetTexCoord(0, 1, 1, 0)
	d.name = UI.Text(d, 17)
	d.name:SetPoint("BOTTOMLEFT", d.banner, "BOTTOMLEFT", 10, 22)
	d.info = UI.Text(d, 11)
	d.info:SetPoint("BOTTOMLEFT", d.banner, "BOTTOMLEFT", 10, 6)
	d.boss = UI.IconButton(d, 46)
	d.boss:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -90)
	d.boss:EnableMouse(false)
	d.bossName = UI.Text(d, 13)
	d.bossName:SetPoint("TOPLEFT", d, "TOPLEFT", 66, -92)
	d.bossName:SetWidth(240)
	d.bossSkills = UI.Text(d, 10)
	d.bossSkills:SetPoint("TOPLEFT", d, "TOPLEFT", 66, -110)
	d.bossSkills:SetWidth(240)
	d.bossSkills:SetJustifyV("TOP")
	UI.Color(d.bossSkills, UI.C.sub)
	d.towerNote = UI.Text(d, 11)
	d.towerNote:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -92)
	d.towerNote:SetWidth(Main.PAGE_W - DETAIL_X - 24)
	d.towerNote:SetJustifyV("TOP")
	d.towerNote:Hide()
	d.mobTitle = UI.Text(d, 10, "등장 몬스터")
	d.mobTitle:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -176)
	UI.Color(d.mobTitle, UI.C.sub)
	d.mobs = {}
	for i = 1, 4 do
		local m = UI.IconButton(d, 34)
		m:SetPoint("TOPLEFT", d, "TOPLEFT", 12 + (i - 1) * 40, -192)
		UI.Tip(m, function(self)
			local mon = self.data and ns.MONSTERS[self.data]
			if not mon then return nil end
			local lines = { { ns.N(mon.name), ns.N(ns.MTYPE[mon.type]), 1, 0.6, 0.5 } }
			local traits = {}
			if mon.range then traits[#traits + 1] = "원거리" end
			if mon.school ~= "phys" then traits[#traits + 1] = ns.N(ns.SCHOOL[mon.school].name) .. " 공격" end
			if mon.res then
				for k, v in pairs(mon.res) do
					traits[#traits + 1] = ns.N(ns.SCHOOL[k].name) .. (v > 0 and " 저항 " or " 약점 ") .. math.abs(v) .. "%"
				end
			end
			if #traits > 0 then lines[#lines + 1] = { table.concat(traits, ", "), nil, 0.8, 0.8, 0.8 } end
			return lines
		end, "TOP")
		d.mobs[i] = m
	end
	d.loot = UI.Text(d, 10)
	d.loot:SetPoint("TOPLEFT", d, "TOPLEFT", 190, -178)
	d.loot:SetWidth(120)
	d.loot:SetJustifyV("TOP")
	UI.Color(d.loot, UI.C.sub)
	d.go = UI.Button(d, Main.PAGE_W - DETAIL_X - 24, 40, "", function()
		if page.tower then
			UI.Try(ns.Combat.EnterTower(page.floor))
		else
			UI.Try(ns.Combat.Travel(page.diff, page.idx))
		end
		Main.Refresh()
	end, "primary")
	d.go:SetPoint("BOTTOM", d, "BOTTOM", 0, 12)
end

local refreshTower

local function refresh(page)
	local db = ns.db
	local inTower = db.tower.on
	for d, w in ipairs(page.worlds) do
		local open = worldOpen(d)
		local p = db.prog[d] or 0
		w.prog:SetText(open and string.format("진행 %d / 30", p) or "잠김")
		w.lockG:SetShown(not open)
		w.scene:SetDesaturated(not open)
		if d == page.diff and not page.tower then w.edge:SetColor(K_SEL[1], K_SEL[2], K_SEL[3], 1) else w.edge:SetColor(0.22, 0.27, 0.4, 1) end
		if d == db.stage.diff and not inTower then
			w.name:SetText(ns.N(ns.DIFFS[d].world) .. "  " .. U.col("6af07a", "●"))
		else
			w.name:SetText(ns.N(ns.DIFFS[d].world))
		end
	end
	do
		local w = page.towerCard
		local open = ns.Tower.Open()
		w.prog:SetText(open and string.format("최고 %d층", db.tower.best or 0) or "잠김")
		w.lockG:SetShown(not open)
		w.scene:SetDesaturated(not open)
		if page.tower then w.edge:SetColor(K_SEL[1], K_SEL[2], K_SEL[3], 1) else w.edge:SetColor(0.22, 0.27, 0.4, 1) end
		w.name:SetText(inTower and ("무한의 탑  " .. U.col("6af07a", "●")) or "무한의 탑")
	end
	for _, part in ipairs(page.stageParts) do part:SetShown(not page.tower) end
	page.towerView:SetShown(page.tower and true or false)
	if page.tower then return refreshTower(page) end

	local acts = ns.DIFFS[page.diff].acts
	for a, c in ipairs(page.acts) do
		c:SetLabel(string.format("%d막  %s", a, ns.N(acts[a])))
		c:SetOn(a == page.act)
	end
	if ns.StageAct(page.idx) ~= page.act then page.idx = (page.act - 1) * ns.STAGES_PER_ACT + 1 end

	for n, b in ipairs(page.nodes) do
		local idx = (page.act - 1) * ns.STAGES_PER_ACT + n
		local stg = ns.Stage(page.diff, idx)
		local cleared = (db.prog[page.diff] or 0) >= idx
		local reachable = ns.Combat.CanTravel(page.diff, idx)
		local here = not inTower and db.stage.diff == page.diff and db.stage.idx == idx
		UI.SetIcon(b.icon, stg.boss.icon)
		b.icon:SetDesaturated(not reachable)
		b.icon:SetAlpha(reachable and 1 or 0.45)
		local _, r, g, bl = themeRGB(stg.theme)
		if here then
			b.ringT:SetVertexColor(0.4, 1, 0.5)
		elseif idx == page.idx then
			b.ringT:SetVertexColor(K_SEL[1], K_SEL[2], K_SEL[3])
		elseif reachable then
			b.ringT:SetVertexColor(r, g, bl)
		else
			b.ringT:SetVertexColor(0.25, 0.27, 0.34)
		end
		b.glow:SetShown(idx == page.idx)
		b.crown:SetShown(stg.raid == true)
		if cleared then
			UI.SetGlyph(b.state, "check", 0.4, 1, 0.5)
			b.state:Show()
		elseif not reachable then
			UI.SetGlyph(b.state, "lock", 0.8, 0.7, 0.5)
			b.state:Show()
		else
			b.state:Hide()
		end
		b.num:SetText(page.act .. "-" .. n .. "  Lv " .. ns.StageLevel(page.diff, idx))
		b.name:SetText(stg.raid and U.col("ff9326", ns.N(stg.name)) or ns.N(stg.name))
		b.name:SetTextColor(reachable and 0.92 or 0.5, reachable and 0.94 or 0.52, reachable and 0.98 or 0.58)
		local link = page.links[n]
		if link then
			-- (the scroll bar sheet's bar: blue once cleared)
			for _, ln in ipairs(link.lines) do
				local c = cleared and UI.BAR_BLUE or UI.BAR_DARK
				ln:SetColor(c[1], c[2], c[3], 1)
			end
		end
	end

	-- detail
	local d = page.detail
	local stg = ns.Stage(page.diff, page.idx)
	local th, r, g, bl = themeRGB(stg.theme)
	-- the loading screen of the stage's place (a band of it, in the banner's shape)
	if not UI.SetLoadingScreen(d.banner, ns.StageLoadingScreen(page.diff, page.idx), (Main.PAGE_W - DETAIL_X - 8) / 76) then
		d.banner:SetTexture(UI.Tex(th.art))
		d.banner:SetTexCoord(0, 0.6, 0.1, 0.85)
		d.banner:SetVertexColor(r * 0.9, g * 0.9, bl * 0.9)
	end
	local title = (stg.place and stg.place ~= stg.name and (ns.N(stg.place) .. "  ·  ") or "") .. ns.N(stg.name)
	d.name:SetText(stg.raid and U.col("ff9326", title) or title)
	local level = ns.StageLevel(page.diff, page.idx)
	local kills = ns.StageKills(page.diff, page.idx)
	d.info:SetText(U.col(ns.DIFFS[page.diff].hex, ns.N(ns.DIFFS[page.diff].name)) .. "  ·  Lv " .. level .. "  ·  " ..
		(kills > 0 and string.format("몬스터 %d마리 · 한 번에 %d마리", kills, ns.MobsPerWave(page.diff, page.idx)) or "우두머리만"))
	local b = stg.boss
	d.towerNote:Hide()
	d.loot:ClearAllPoints()
	d.loot:SetPoint("TOPLEFT", d, "TOPLEFT", 190, -178)
	d.loot:SetWidth(120)
	d.boss:Show()
	d.bossName:Show()
	d.bossSkills:Show()
	d.boss:SetIconName(b.icon)
	d.boss:SetBorderRGB(stg.raid and 1 or 0.85, stg.raid and 0.6 or 0.25, stg.raid and 0.15 or 0.2)
	d.bossName:SetText((stg.raid and "공격대 우두머리  " or "우두머리  ") .. U.col("ff8a5a", ns.N(b.name)))
	local skills = {}
	for _, sk in ipairs(b.skills) do skills[#skills + 1] = "• " .. bossSkillText(sk) end
	d.bossSkills:SetText(table.concat(skills, "\n"))
	-- a stage of the boss alone has no monster waves
	d.mobTitle:SetShown(kills > 0)
	for i, m in ipairs(d.mobs) do
		local e = kills > 0 and stg.mobs[i]
		if e then
			m.data = e[1]
			m:SetIconName(ns.MONSTERS[e[1]].icon)
			m:SetBorderRGB(0.7, 0.25, 0.2)
			m:Show()
		else
			m.data = nil
			m:Hide()
		end
	end
	-- its boxes (TBH's): the monster box at its chance each kill (with the
	-- chest bonus), the boss's box at its chance and a second one by the
	-- bonus, and the gear levels they hold (worn from that level)
	local tb = ns.TBH.STAGES[page.diff][page.idx]
	local lines = { "보상" }
	local function pct(v) v = math.min(100, v) return (v >= 100 and "%d%%" or (v >= 10 and "%.0f%%" or "%.1f%%")):format(v) end
	if tb.mbox then
		local chance = tb.mrate / 10 * (1 + ns.Bonus("chestChance") / 100)
		lines[#lines + 1] = U.col("ffffff", string.format("Lv %d %s %s", ns.TBH.BOXES[tb.mbox].lv, ns.N(ns.CHEST[1].name), pct(chance)))
	end
	lines[#lines + 1] = U.col("ffd24a", string.format("Lv %d %s %s", ns.TBH.BOXES[tb.bbox].lv, ns.N((stg.raid and ns.CHEST[3] or ns.CHEST[2]).name),
		pct(tb.brate / 10 * (1 + ns.Bonus("bossRate") / 100))))
	local extra = ns.Bonus("bossChest")
	if extra > 0 then
		lines[#lines + 1] = U.col("ffd24a", string.format("한 개 더 %s (동료 효과)", pct(extra)))
	end
	local lo, hi = ns.Loot.BoxLevels(tb.bbox)
	if tb.mbox then
		local mlo, mhi = ns.Loot.BoxLevels(tb.mbox)
		lo, hi = math.min(lo, mlo), math.max(hi, mhi)
	end
	lines[#lines + 1] = U.col("aab3c8", lo == hi and string.format("장비 Lv %d", hi) or string.format("장비 Lv %d~%d", lo, hi))
	d.loot:SetText(table.concat(lines, "\n"))
	local can = ns.Combat.CanTravel(page.diff, page.idx)
	local here = not inTower and db.stage.diff == page.diff and db.stage.idx == page.idx
	if here then
		d.go:SetLabel("지금 싸우는 곳")
		d.go:SetOff(true)
	elseif can then
		d.go:SetLabel("이 스테이지로 이동")
		d.go:SetOff(false)
	else
		d.go:SetLabel("아직 잠겨 있습니다")
		d.go:SetOff(true)
	end

	for _, c in ipairs(page.checks) do c:Refresh() end
	local rate = db.rate
	if (rate.gold or 0) > 0 then
		page.rate:SetText(string.format("최근 수입: 시간당 골드 %s · 경험치 %s. %s", U.fmt(rate.gold * 3600), U.fmt(rate.xp * 3600), XP_RULE))
	else
		page.rate:SetText(XP_RULE)
	end
end

-- The tower shown: the floor picked, its affixes, and its card (the place,
-- monsters and boss it borrows, its chests and first-clear reward).
refreshTower = function(page)
	local db = ns.db
	local T = ns.Tower
	local top = T.Top()
	page.floor = U.clamp(page.floor or top, 1, top)
	local f = page.floor
	local tv = page.towerView
	tv.floorPill:SetLabel(string.format("%d층", f))
	tv.prev:SetOff(f <= 1)
	tv.next:SetOff(f >= top)
	tv.top:SetOff(f >= top)
	tv.record:SetText(string.format("최고 기록 %s", U.col("ffd24a", (db.tower.best or 0) .. "층")) ..
		(db.tower.on and ("  ·  지금 " .. U.col("6af07a", db.tower.floor .. "층")) or ""))
	local active = T.Affixes(f)
	tv.head:Set("속성", string.format("%d층: %d개", f, #active))
	for i, r in ipairs(tv.rows) do
		local on = i <= #active
		r.icon:SetDesaturated(not on)
		r.icon:SetAlpha(on and 1 or 0.45)
		r.name:SetTextColor(on and 1 or 0.55, on and 0.82 or 0.57, on and 0.3 or 0.62)
		UI.Color(r.from, on and UI.C.sub or UI.C.dim)
		r.text:SetTextColor(on and 0.92 or 0.5, on and 0.94 or 0.52, on and 0.98 or 0.58)
	end
	for _, c in ipairs(tv.checks) do c:Refresh() end

	-- the floor's card: what is known before it starts (its place, monsters
	-- and boss are rolled when it does)
	local d = page.detail
	local raid = T.IsRaid(f)
	local last = ns.STAGES[#ns.DIFFS][ns.STAGE_COUNT]
	if not UI.SetLoadingScreen(d.banner, ns.TowerLoadingScreen("floor"), (Main.PAGE_W - DETAIL_X - 8) / 76) then
		local th, r, g, bl = themeRGB(last.theme)
		d.banner:SetTexture(UI.Tex(th.art))
		d.banner:SetTexCoord(0, 0.6, 0.1, 0.85)
		d.banner:SetVertexColor(r * 0.9, g * 0.9, bl * 0.9)
	end
	local title = T.Label(f) .. (raid and "  ·  공격대" or "")
	d.name:SetText(raid and U.col("ff9326", title) or title)
	local kills = T.Kills(f)
	d.info:SetText(U.col(TOWER_HEX, "도전") .. "  ·  Lv " .. T.LEVEL .. "  ·  " ..
		(kills > 0 and string.format("몬스터 %d마리 · 한 번에 %d마리", kills, T.MobsPerWave()) or "공격대 우두머리만"))
	d.boss:Hide()
	d.bossName:Hide()
	d.bossSkills:Hide()
	d.mobTitle:Hide()
	for _, m in ipairs(d.mobs) do m.data = nil m:Hide() end
	local notes = { "도전할 때마다 장소, 몬스터, 우두머리가 무작위로 정해집니다." }
	notes[#notes + 1] = raid and "이 층에는 공격대 우두머리가 홀로 기다립니다." or
		string.format("%d층마다 공격대 우두머리가 기다립니다.", T.RAID_EVERY)
	notes[#notes + 1] = string.format("몬스터 강함: 생명력 x%s · 공격력 x%s", U.num(T.HPMult(f), 2), U.num(T.AtkMult(f), 2))
	d.towerNote:SetText(table.concat(notes, "\n"))
	d.towerNote:Show()
	d.loot:ClearAllPoints()
	d.loot:SetPoint("TOPLEFT", d.towerNote, "BOTTOMLEFT", 0, -14)
	d.loot:SetWidth(Main.PAGE_W - DETAIL_X - 24)
	local function pct(v) v = math.min(100, v) return (v >= 100 and "%d%%" or (v >= 10 and "%.0f%%" or "%.1f%%")):format(v) end
	local lines = { "보상" }
	if kills > 0 then
		lines[#lines + 1] = U.col("ffffff", string.format("%s %s", ns.N(ns.CHEST[1].name), pct(T.MRATE / 10 * (1 + ns.Bonus("chestChance") / 100))))
	end
	lines[#lines + 1] = U.col("ffd24a", string.format("%s %s", ns.N((raid and ns.CHEST[3] or ns.CHEST[2]).name), pct(T.BRATE / 10 * (1 + ns.Bonus("bossRate") / 100))))
	local extra = ns.Bonus("bossChest")
	if extra > 0 then
		lines[#lines + 1] = U.col("ffd24a", string.format("한 개 더 %s (동료 효과)", pct(extra)))
	end
	lines[#lines + 1] = U.col("aab3c8", string.format("장비 Lv %d", T.ITEM_LEVEL))
	if f > (db.tower.best or 0) then
		lines[#lines + 1] = U.col("6af07a", string.format("첫 공략: %s G", U.fmt(T.FirstGold(f))))
		lines[#lines + 1] = U.col("6af07a", "+ 상자 1개")
	end
	d.loot:SetText(table.concat(lines, "\n"))
	local here = db.tower.on and db.tower.floor == f
	if not T.Open() then
		d.go:SetLabel("아직 잠겨 있습니다")
		d.go:SetOff(true)
	elseif here then
		d.go:SetLabel("지금 싸우는 곳")
		d.go:SetOff(true)
	else
		d.go:SetLabel(string.format("%d층 도전", f))
		d.go:SetOff(false)
	end
end

local function open(page, opts)
	-- show where the party is (the tower when sent there)
	page.diff = ns.db.stage.diff
	page.idx = ns.db.stage.idx
	page.act = ns.StageAct(page.idx)
	page.tower = (ns.db.tower.on or (opts and opts.tower)) and true or false
	page.floor = ns.db.tower.on and ns.db.tower.floor or ns.Tower.Top()
end

Main.RegisterTab({
	key = "map", title = "스테이지", sub = "네 개의 세계, 120개 지역, 무한의 탑",
	icon = "INV_Misc_Map_01", art = "icon_map", build = build, refresh = refresh, open = open,
	events = { "STAGE", "PROGRESS", "RESULT", "OPTIONS", "RESET" },
})
