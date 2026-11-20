-- Map (지도), built from the screen kit (UI/Layout.lua):
--   tabs: the four worlds (one per difficulty); tools: where the party is;
--   list: the three acts, the act's ten stages, and the game-flow options;
--   card: the chosen stage (boss, monsters, rewards) and the gold button that
--         travels there.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local NODE_W, NODE_H = 100, 100
local PATH_Y = -82

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

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function build(page)
	page.diff = ns.db.stage.diff
	page.idx = ns.db.stage.idx
	page.act = ns.StageAct(page.idx)
	local tabs = {}
	for d = 1, #ns.DIFFS do tabs[#tabs + 1] = { d, ns.N(ns.DIFFS[d].name) } end
	local S = UI.Screen(page, {
		tabs = tabs,
		onTab = function(d)
			if not worldOpen(d) then
				UI.Try(false, string.format("%s의 30개 스테이지를 모두 깨면 열립니다.", ns.N(ns.DIFFS[d - 1].world)))
			end
			page.diff = d
			page.act = 1
			page.idx = 1
			Main.Refresh()
		end,
	})
	page.S = S
	for _, b in ipairs(S.tabs.buttons) do
		UI.Tip(b, function(self)
			local dd = ns.DIFFS[self.key]
			local lines = { { ns.N(dd.world), ns.N(dd.name), U.rgb(dd.hex) } }
			lines[#lines + 1] = { string.format("스테이지 레벨 %d ~ %d", ns.StageLevel(self.key, 1), ns.StageLevel(self.key, ns.STAGE_COUNT)), nil, 1, 1, 1 }
			lines[#lines + 1] = { "높은 난이도일수록 몬스터가 많고 높은 등급 장비가 잘 나옵니다.", nil, 0.8, 0.8, 0.8 }
			if not worldOpen(self.key) then
				lines[#lines + 1] = { string.format("%s의 30개 스테이지를 모두 깨면 열립니다.", ns.N(ns.DIFFS[self.key - 1].world)), nil, 1, 0.35, 0.3 }
			end
			return lines
		end, "TOP")
	end
	page.here = UI.Pill(S.tools, K.CARD_W, K.TAB_H - 4, 0.05, 0.06, 0.10, 0.9)
	page.here:SetPoint("RIGHT", S.tools, "RIGHT", 0, 0)
	page.here.text:SetFont(ns.FONT, K.F_SMALL, "")

	local list = S.list
	-- acts
	page.acts = {}
	local aw = floor((K.LIST_IN - 16) / 3)
	for a = 1, 3 do
		local c = UI.Chip(list, aw, 30, "", function()
			page.act = a
			page.idx = (a - 1) * ns.STAGES_PER_ACT + 1
			Main.Refresh()
		end)
		c:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD + (a - 1) * (aw + 8), -K.PAD)
		c.isItem = true
		c.lock = UI.Glyph(c, "lock", 12, 0.9, 0.78, 0.5)
		c.lock:SetPoint("RIGHT", c.label, "LEFT", -3, 0)
		page.acts[a] = c
	end
	page.head = UI.Section(list, K.LIST_IN)
	page.head:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, -54)

	-- stages: two rows of five, the second row runs back (a snake)
	page.links = {}
	page.nodes = {}
	local stepX = (K.LIST_IN - NODE_W) / 4
	local function nodeX(col) return K.PAD + col * stepX end
	for n = 1, ns.STAGES_PER_ACT do
		local col, row = (n - 1) % 5, floor((n - 1) / 5)
		if row == 1 then col = 4 - col end
		local b = CreateFrame("Button", nil, list)
		b:SetSize(NODE_W, NODE_H)
		b:SetPoint("TOPLEFT", list, "TOPLEFT", nodeX(col), PATH_Y - row * (NODE_H + 8))
		b.isItem = true
		b.disc = UI.Art(b, "circle", "BACKGROUND", 0.05, 0.06, 0.1)
		b.disc:SetSize(48, 48)
		b.disc:SetPoint("TOP", b, "TOP", 0, -6)
		b.icon = b:CreateTexture(nil, "ARTWORK", nil, -1)
		b.icon:SetSize(34, 34)
		b.icon:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.ringT = UI.Art(b, "ring", "ARTWORK")
		b.ringT:SetSize(48, 48)
		b.ringT:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow = UI.Art(b, "glow", "BACKGROUND", 1, 0.8, 0.3, 0.9)
		b.glow:SetSize(78, 78)
		b.glow:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow:Hide()
		b.state = UI.Glyph(b, "check", 16, 0.4, 1, 0.5)
		b.state:SetPoint("TOPRIGHT", b.disc, "TOPRIGHT", 4, 4)
		b.crown = UI.Glyph(b, "crown", 16, 1, 0.75, 0.25)
		b.crown:SetPoint("TOPLEFT", b.disc, "TOPLEFT", -6, 4)
		b.num = UI.Text(b, K.F_MIN)
		b.num:SetPoint("TOP", b.disc, "BOTTOM", 0, -3)
		b.num:SetWidth(NODE_W)
		b.num:SetJustifyH("CENTER")
		b.num:SetWordWrap(false)
		UI.Color(b.num, UI.C.sub)
		b.name = UI.Text(b, K.F_SMALL)
		b.name:SetPoint("TOP", b.num, "BOTTOM", 0, -2)
		b.name:SetJustifyH("CENTER")
		b.name:SetJustifyV("TOP")
		b.name:SetWidth(NODE_W)
		b.n = n
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			ns.Sound("click")
			page.idx = (page.act - 1) * ns.STAGES_PER_ACT + self.n
			Main.Refresh()
		end)
		page.nodes[n] = b
		if n > 1 then
			local prevCol = (n - 2) % 5
			local prevRow = floor((n - 2) / 5)
			local cy = PATH_Y - 6 - 24
			local link = list:CreateTexture(nil, "BORDER")
			if prevRow == row then
				local c1 = (row == 1) and (4 - prevCol) or prevCol
				local x1 = nodeX(min(c1, col)) + NODE_W / 2 + 26
				link:SetSize(stepX - 52, 3)
				link:SetPoint("TOPLEFT", list, "TOPLEFT", x1, cy - row * (NODE_H + 8) + 1)
			else
				-- from stage 5 down to stage 6, along the right edge
				local bx = nodeX(4) + NODE_W / 2 + 34
				link:SetSize(3, NODE_H + 8)
				link:SetPoint("TOPLEFT", list, "TOPLEFT", bx, cy + 1)
				local top = list:CreateTexture(nil, "BORDER")
				top:SetSize(8 + 3, 3)
				top:SetPoint("TOPLEFT", list, "TOPLEFT", bx - 8, cy + 1)
				local bot = list:CreateTexture(nil, "BORDER")
				bot:SetSize(8 + 3, 3)
				bot:SetPoint("TOPLEFT", list, "TOPLEFT", bx - 8, cy - (NODE_H + 8) + 1)
				link.parts = { top, bot }
			end
			page.links[n] = link
		end
	end

	-- game flow
	local optY = PATH_Y - 2 * (NODE_H + 8) + 2
	page.optHead = UI.Section(list, K.LIST_IN, "진행 방식")
	page.optHead:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, optY)
	page.checks = {
		UI.Check(list, "자동 진행: 깨면 다음 스테이지로",
			function() return ns.db.opt.auto end, function(v) ns.db.opt.auto = v if v then ns.db.retry = 0 end ns.Fire("OPTIONS") end),
		UI.Check(list, "전멸하면 한 스테이지 물러나기",
			function() return ns.db.opt.retreat end, function(v) ns.db.opt.retreat = v end),
		UI.Check(list, "물러난 뒤 8번 깨면 다시 도전",
			function() return ns.db.opt.retry end, function(v) ns.db.opt.retry = v end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, optY - 26 - (i - 1) * 25)
	end
	page.rate = UI.Text(list, K.F_SMALL)
	page.rate:SetPoint("TOPLEFT", list, "TOPLEFT", K.PAD, optY - 104)
	page.rate:SetWidth(K.LIST_IN)
	page.rate:SetWordWrap(false)
	UI.Color(page.rate, UI.C.sub)

	-- card content
	local d = S.card
	page.bossHead = UI.Section(d.content, K.CARD_IN)
	page.bossHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, 0)
	page.bossSkills = UI.Text(d.content, K.F_SMALL)
	page.bossSkills:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -26)
	page.bossSkills:SetWidth(K.CARD_IN)
	page.bossSkills:SetJustifyV("TOP")
	page.mobHead = UI.Section(d.content, K.CARD_IN, "등장 몬스터")
	page.mobHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -100)
	page.mobs = {}
	for i = 1, 4 do
		local m = UI.IconButton(d.content, 36)
		m:SetPoint("TOPLEFT", d.content, "TOPLEFT", (i - 1) * 42, -126)
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
		page.mobs[i] = m
	end
	page.lootHead = UI.Section(d.content, K.CARD_IN, "보상")
	page.lootHead:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -174)
	page.loot = {}
	for i = 1, 3 do
		local r = UI.StatRow(d.content, K.CARD_IN)
		r:SetPoint("TOPLEFT", d.content, "TOPLEFT", 0, -200 - (i - 1) * 24)
		page.loot[i] = r
	end
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function refresh(page)
	local db = ns.db
	local S = page.S
	S.tabs:Select(page.diff)
	for d = 1, #ns.DIFFS do
		local open = worldOpen(d)
		S.tabs:SetLocked(d, not open)
		S.tabs:SetLabel(d, ns.N(ns.DIFFS[d].name) .. (open and string.format("  %d/30", db.prog[d] or 0) or ""))
	end
	page.here:SetLabel(string.format("지금 싸우는 곳: %s %d-%d", ns.N(ns.DIFFS[db.stage.diff].name),
		ns.StageAct(db.stage.idx), (db.stage.idx - 1) % ns.STAGES_PER_ACT + 1))

	local acts = ns.DIFFS[page.diff].acts
	for a, c in ipairs(page.acts) do
		local first = (a - 1) * ns.STAGES_PER_ACT
		local done = U.clamp((db.prog[page.diff] or 0) - first, 0, ns.STAGES_PER_ACT)
		local open = worldOpen(page.diff) and ns.Combat.CanTravel(page.diff, first + 1)
		c:SetLabel(open and string.format("%d막  %d/%d", a, done, ns.STAGES_PER_ACT) or string.format("%d막", a))
		c.lock:SetShown(not open)
		c:SetOn(a == page.act)
	end
	if ns.StageAct(page.idx) ~= page.act then page.idx = (page.act - 1) * ns.STAGES_PER_ACT + 1 end
	do
		local first = (page.act - 1) * ns.STAGES_PER_ACT
		local done = U.clamp((db.prog[page.diff] or 0) - first, 0, ns.STAGES_PER_ACT)
		page.head:Set(string.format("%s · %d막 %s", ns.N(ns.DIFFS[page.diff].world), page.act, ns.N(acts[page.act])),
			string.format("공략 %d / %d", done, ns.STAGES_PER_ACT))
	end

	for n, b in ipairs(page.nodes) do
		local idx = (page.act - 1) * ns.STAGES_PER_ACT + n
		local stg = ns.Stage(page.diff, idx)
		local cleared = (db.prog[page.diff] or 0) >= idx
		local reachable = ns.Combat.CanTravel(page.diff, idx)
		local here = db.stage.diff == page.diff and db.stage.idx == idx
		UI.SetIcon(b.icon, stg.boss.icon)
		b.icon:SetDesaturated(not reachable)
		b.icon:SetAlpha(reachable and 1 or 0.45)
		local _, r, g, bl = themeRGB(stg.theme)
		if idx == page.idx then
			b.ringT:SetVertexColor(K.SEL[1], K.SEL[2], K.SEL[3])
		elseif here then
			b.ringT:SetVertexColor(0.4, 1, 0.5)
		elseif reachable then
			b.ringT:SetVertexColor(r, g, bl)
		else
			b.ringT:SetVertexColor(0.25, 0.27, 0.34)
		end
		b.glow:SetShown(idx == page.idx)
		b.crown:SetShown(stg.raid == true)
		if cleared then
			b.state:SetTexture(UI.Tex("check"))
			b.state:SetVertexColor(0.4, 1, 0.5)
			b.state:Show()
		elseif not reachable then
			b.state:SetTexture(UI.Tex("lock"))
			b.state:SetVertexColor(0.8, 0.7, 0.5)
			b.state:Show()
		else
			b.state:Hide()
		end
		b.num:SetText(string.format("%d-%d · Lv %d", page.act, n, ns.StageLevel(page.diff, idx)) .. (here and U.col("60e070", " ●") or ""))
		b.name:SetText(stg.raid and U.col("ff9326", ns.N(stg.name)) or ns.N(stg.name))
		b.name:SetTextColor(reachable and 0.92 or 0.5, reachable and 0.94 or 0.52, reachable and 0.98 or 0.58)
		local link = page.links[n]
		if link then
			local parts = { link }
			for _, t in ipairs(link.parts or {}) do parts[#parts + 1] = t end
			for _, t in ipairs(parts) do
				if cleared then UI.Fill(t, 1, 0.8, 0.3, 0.9) else UI.Fill(t, 0.3, 0.33, 0.42, 0.8) end
			end
		end
	end
	for _, c in ipairs(page.checks) do c:Refresh() end
	local rate = db.rate
	if (rate.gold or 0) > 0 then
		page.rate:SetText(string.format("최근 수입: 시간당 골드 %s · 경험치 %s", U.fmt(rate.gold * 3600), U.fmt(rate.xp * 3600)))
	else
		page.rate:SetText("영웅 레벨과 비슷한 레벨의 스테이지에서 경험치가 가장 잘 오릅니다.")
	end

	-- the chosen stage
	local d = S.card
	local stg = ns.Stage(page.diff, page.idx)
	local _, r, g, bl = themeRGB(stg.theme)
	local level = ns.StageLevel(page.diff, page.idx)
	local waves = stg.raid and 4 or ns.WAVES
	d:Head({ icon = stg.boss.icon, title = ns.N(stg.name), titleRGB = stg.raid and { 1, 0.58, 0.15 } or nil,
		sub = string.format("%s · Lv %d · 웨이브 %d × %d마리", ns.N(ns.DIFFS[page.diff].name), level, waves, ns.MobsPerWave(page.diff, page.idx)),
		band = { r, g, bl } })
	local b = stg.boss
	page.bossHead:Set(stg.raid and "공격대 우두머리" or "우두머리", U.col("ff8a5a", ns.N(b.name)))
	local skills = {}
	for _, sk in ipairs(b.skills) do skills[#skills + 1] = "• " .. bossSkillText(sk) end
	page.bossSkills:SetText(table.concat(skills, "\n"))
	for i, m in ipairs(page.mobs) do
		local e = stg.mobs[i]
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
	local chest = stg.raid and ns.CHEST[3] or ns.CHEST[2]
	page.loot[1]:Set("웨이브마다", ns.N(ns.CHEST[1].name))
	page.loot[2]:Set("우두머리", U.col("ffd24a", ns.N(chest.name)))
	page.loot[3]:Set("장비 레벨", string.format("Lv %d ~ %d", max(1, level - 2), level))
	d:Extras(nil, nil)
	local can = ns.Combat.CanTravel(page.diff, page.idx)
	local here = db.stage.diff == page.diff and db.stage.idx == page.idx
	if here then
		d:Actions(nil, { "지금 여기서 싸우는 중", nil, "primary", true })
	elseif can then
		d:Actions(nil, { "이 스테이지로 이동", function()
			UI.Try(ns.Combat.Travel(page.diff, page.idx))
			Main.Refresh()
		end, "primary" })
	else
		d:Actions(nil, { "아직 잠겨 있습니다", nil, "primary", true })
	end
end

local function open(page)
	-- show where the party is
	page.diff = ns.db.stage.diff
	page.idx = ns.db.stage.idx
	page.act = ns.StageAct(page.idx)
end

Main.RegisterTab({
	key = "map", title = "지도", sub = "네 개의 세계, 120개 지역",
	icon = "INV_Misc_Map_01", art = "icon_map", build = build, refresh = refresh, open = open,
	events = { "STAGE", "PROGRESS", "RESULT", "OPTIONS", "RESET" },
})
