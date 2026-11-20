-- Map screen: four worlds (one per difficulty), three acts each, ten stages
-- per act, and a detail card for the chosen stage.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main

local NODE_W, NODE_H = 96, 98
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

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.diff = ns.db.stage.diff
	page.idx = ns.db.stage.idx
	page.act = ns.StageAct(page.idx)

	-- worlds
	page.worlds = {}
	for d = 1, #ns.DIFFS do
		local w = CreateFrame("Button", nil, page)
		w:SetSize(206, 66)
		w:SetPoint("TOPLEFT", page, "TOPLEFT", (d - 1) * 214, 0)
		w.scene = w:CreateTexture(nil, "BACKGROUND")
		w.scene:SetPoint("TOPLEFT", w, "TOPLEFT", 3, -3)
		w.scene:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -3, 3)
		local stg = ns.STAGES[d][15]
		local th, r, g, b = themeRGB(stg.theme)
		w.scene:SetTexture(UI.Tex(th.art))
		w.scene:SetTexCoord(0.2, 0.6, 0.15, 0.85)
		w.scene:SetVertexColor(r * 0.7, g * 0.7, b * 0.7)
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
		b:SetPoint("TOPLEFT", page, "TOPLEFT", col * (NODE_W + 8), PATH_Y - row * (NODE_H + 8))
		b.ringT = UI.Art(b, "ring", "ARTWORK")
		b.ringT:SetSize(52, 52)
		b.ringT:SetPoint("TOP", b, "TOP", 0, -2)
		b.disc = UI.Art(b, "circle", "BACKGROUND", 0.05, 0.06, 0.1)
		b.disc:SetSize(52, 52)
		b.disc:SetPoint("TOP", b, "TOP", 0, -2)
		b.icon = b:CreateTexture(nil, "ARTWORK", nil, -1)
		b.icon:SetSize(38, 38)
		b.icon:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow = UI.Art(b, "glow", "BACKGROUND", 1, 0.8, 0.3, 0.9)
		b.glow:SetSize(84, 84)
		b.glow:SetPoint("CENTER", b.disc, "CENTER", 0, 0)
		b.glow:Hide()
		b.state = UI.Glyph(b, "check", 18, 0.4, 1, 0.5)
		b.state:SetPoint("TOPRIGHT", b.disc, "TOPRIGHT", 4, 4)
		b.crown = UI.Glyph(b, "crown", 18, 1, 0.75, 0.25)
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
			local link = page:CreateTexture(nil, "BACKGROUND")
			if prevRow == row then
				local c1 = (row == 1) and (4 - prevCol) or prevCol
				local x1 = math.min(c1, col) * (NODE_W + 8) + NODE_W / 2 + 26
				link:SetSize(NODE_W + 8 - 52, 3)
				link:SetPoint("TOPLEFT", page, "TOPLEFT", x1, PATH_Y - row * (NODE_H + 8) - 27)
			else
				link:SetSize(3, NODE_H + 8 - 52)
				link:SetPoint("TOPLEFT", page, "TOPLEFT", 4 * (NODE_W + 8) + NODE_W / 2 - 1, PATH_Y - 54)
			end
			page.links[n] = link
		end
	end

	-- options under the path
	local optY = PATH_Y - 2 * (NODE_H + 8) - 6
	page.checks = {
		UI.Check(page, "자동 진행 - 깨면 다음 스테이지로",
			function() return ns.db.opt.auto end, function(v) ns.db.opt.auto = v if v then ns.db.retry = 0 end ns.Fire("OPTIONS") end),
		UI.Check(page, "전멸하면 한 스테이지 물러나기",
			function() return ns.db.opt.retreat end, function(v) ns.db.opt.retreat = v end),
		UI.Check(page, "물러난 뒤 8번 깨면 다시 도전",
			function() return ns.db.opt.retry end, function(v) ns.db.opt.retry = v end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", page, "TOPLEFT", 4, optY - (i - 1) * 24)
	end
	page.rate = UI.Text(page, 10)
	page.rate:SetPoint("TOPLEFT", page, "TOPLEFT", 4, optY - 78)
	page.rate:SetWidth(500)
	UI.Color(page.rate, UI.C.sub)

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
		UI.Try(ns.Combat.Travel(page.diff, page.idx))
		Main.Refresh()
	end, "primary")
	d.go:SetPoint("BOTTOM", d, "BOTTOM", 0, 12)
end

local function refresh(page)
	local db = ns.db
	for d, w in ipairs(page.worlds) do
		local open = worldOpen(d)
		local p = db.prog[d] or 0
		w.prog:SetText(open and string.format("진행 %d / 30", p) or "잠김")
		w.lockG:SetShown(not open)
		w.scene:SetDesaturated(not open)
		if d == page.diff then w.edge:SetColor(1, 0.82, 0.3, 1) else w.edge:SetColor(0.22, 0.27, 0.4, 1) end
		if d == db.stage.diff then
			w.name:SetText(ns.N(ns.DIFFS[d].world) .. "  " .. U.col("6af07a", "●"))
		else
			w.name:SetText(ns.N(ns.DIFFS[d].world))
		end
	end
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
		local here = db.stage.diff == page.diff and db.stage.idx == idx
		UI.SetIcon(b.icon, stg.boss.icon)
		b.icon:SetDesaturated(not reachable)
		b.icon:SetAlpha(reachable and 1 or 0.45)
		local _, r, g, bl = themeRGB(stg.theme)
		if here then
			b.ringT:SetVertexColor(0.4, 1, 0.5)
		elseif idx == page.idx then
			b.ringT:SetVertexColor(1, 0.82, 0.3)
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
		b.num:SetText(page.act .. "-" .. n .. "  Lv " .. ns.StageLevel(page.diff, idx))
		b.name:SetText(stg.raid and U.col("ff9326", ns.N(stg.name)) or ns.N(stg.name))
		b.name:SetTextColor(reachable and 0.92 or 0.5, reachable and 0.94 or 0.52, reachable and 0.98 or 0.58)
		local link = page.links[n]
		if link then
			if cleared then UI.Fill(link, 1, 0.8, 0.3, 0.9) else UI.Fill(link, 0.3, 0.33, 0.42, 0.8) end
		end
	end

	-- detail
	local d = page.detail
	local stg = ns.Stage(page.diff, page.idx)
	local th, r, g, bl = themeRGB(stg.theme)
	d.banner:SetTexture(UI.Tex(th.art))
	d.banner:SetTexCoord(0, 0.6, 0.1, 0.85)
	d.banner:SetVertexColor(r * 0.9, g * 0.9, bl * 0.9)
	d.name:SetText((stg.raid and U.col("ff9326", ns.N(stg.name))) or ns.N(stg.name))
	local level = ns.StageLevel(page.diff, page.idx)
	local waves = stg.raid and 4 or ns.WAVES
	d.info:SetText(U.col(ns.DIFFS[page.diff].hex, ns.N(ns.DIFFS[page.diff].name)) .. "  ·  Lv " .. level .. "  ·  " ..
		string.format("웨이브 %d · 웨이브당 %d마리", waves, ns.MobsPerWave(page.diff, page.idx)))
	local b = stg.boss
	d.boss:SetIconName(b.icon)
	d.boss:SetBorderRGB(stg.raid and 1 or 0.85, stg.raid and 0.6 or 0.25, stg.raid and 0.15 or 0.2)
	d.bossName:SetText((stg.raid and "공격대 우두머리  " or "우두머리  ") .. U.col("ff8a5a", ns.N(b.name)))
	local skills = {}
	for _, sk in ipairs(b.skills) do skills[#skills + 1] = "• " .. bossSkillText(sk) end
	d.bossSkills:SetText(table.concat(skills, "\n"))
	for i, m in ipairs(d.mobs) do
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
	d.loot:SetText("보상" .. "\n" .. U.col("ffffff", ns.N(ns.CHEST[1].name)) .. "\n" .. U.col("ffd24a", ns.N(chest.name)) ..
		"\n" .. string.format("장비 Lv %d~%d", max(1, level - 2), level))
	local can = ns.Combat.CanTravel(page.diff, page.idx)
	local here = db.stage.diff == page.diff and db.stage.idx == page.idx
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
		page.rate:SetText(string.format("최근 수입: 시간당 골드 %s · 경험치 %s. 영웅 레벨과 비슷한 레벨의 스테이지에서 경험치가 가장 잘 오릅니다.", U.fmt(rate.gold * 3600), U.fmt(rate.xp * 3600)))
	else
		page.rate:SetText("영웅 레벨과 비슷한 레벨의 스테이지에서 경험치가 가장 잘 오릅니다.")
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
	icon = "INV_Misc_Map_01", build = build, refresh = refresh, open = open,
	events = { "STAGE", "PROGRESS", "RESULT", "OPTIONS", "RESET" },
})
