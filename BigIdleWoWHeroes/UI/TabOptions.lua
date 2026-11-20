-- Settings (설정), opened from the gear button in the window header: display,
-- faction, game flow, statistics, help and save reset.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local function setMenuScale(delta)
	local s = U.clamp((ns.db.ui.scale or 1) + delta, 0.6, 1.6)
	ns.db.ui.scale = math.floor(s * 20 + 0.5) / 20
	Main.ApplyScale()
end

local function card(page, x, y, w, h, title)
	local c = UI.Panel(page, w, h, "card")
	c:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	c.title = UI.Title(c, title, 14)
	c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -12)
	return c
end

local function stepper(parent, x, y, label, onMinus, onPlus)
	local t = UI.Text(parent, 12, label)
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 6)
	local minus = UI.Button(parent, 32, 26, "-", onMinus, "dark")
	minus:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 150, y)
	local plus = UI.Button(parent, 32, 26, "+", onPlus, "dark")
	plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	return t, plus
end

local function build(page)
	-- display ---------------------------------------------------------------
	local disp = card(page, 0, 0, 416, 236, "화면")
	page.menuScale, page.menuPlus = stepper(disp, 14, -40, "", function() setMenuScale(-0.05) Main.Refresh() end,
		function() setMenuScale(0.05) Main.Refresh() end)
	page.barScale, page.barPlus = stepper(disp, 14, -72, "", function() ns.Bar.SetScale(ns.Bar.Scale() - 0.05) Main.Refresh() end,
		function() ns.Bar.SetScale(ns.Bar.Scale() + 0.05) Main.Refresh() end)
	local resetPos = UI.Button(disp, 150, 26, "전투 창 원래대로", function() ns.Bar.ResetPosition() Main.Refresh() end, "blue")
	resetPos:SetPoint("LEFT", page.barPlus, "RIGHT", 10, 0)
	UI.Tip(resetPos, function() return UI.SimpleTip("전투 창 원래대로", "전투 창의 위치와 크기를 처음 상태로 되돌립니다.") end)
	local hint = UI.Text(disp, 10, "전투 창은 오른쪽 아래 모서리를 끌어서도 크기를 바꿀 수 있습니다.")
	hint:SetPoint("TOPLEFT", disp, "TOPLEFT", 14, -104)
	UI.Color(hint, UI.C.dim)
	page.checks = {
		UI.Check(disp, "전투 창 보이기", function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(disp, "전투 창 아래 메뉴 줄 숨기기 (작게 보기)",
			function() return ns.db.ui.compact end, function(v) ns.db.ui.compact = v and true or nil ns.Bar.ApplyCompact() end),
		UI.Check(disp, "전투 창 위치·크기 잠금", function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
		UI.Check(disp, "효과음", function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", disp, "TOPLEFT", 14, -124 - (i - 1) * 26)
	end

	-- faction ---------------------------------------------------------------
	local fac = card(page, 432, 0, 416, 236, "진영")
	page.facIcon = fac:CreateTexture(nil, "ARTWORK")
	page.facIcon:SetSize(64, 64)
	page.facIcon:SetPoint("TOPLEFT", fac, "TOPLEFT", 14, -40)
	page.facName = UI.Text(fac, 18)
	page.facName:SetPoint("TOPLEFT", fac, "TOPLEFT", 90, -46)
	page.facDesc = UI.Text(fac, 11)
	page.facDesc:SetPoint("TOPLEFT", fac, "TOPLEFT", 90, -70)
	page.facDesc:SetWidth(310)
	UI.Color(page.facDesc, UI.C.sub)
	local facNote = UI.Text(fac, 11, "진영에 따라 영웅의 종족 모습이 바뀝니다. 이름, 레벨, 장비, 능력치는 그대로입니다.")
	facNote:SetPoint("TOPLEFT", fac, "TOPLEFT", 14, -120)
	facNote:SetWidth(388)
	page.facChange = UI.Button(fac, 180, 32, "진영 바꾸기", function()
		ns.PickFaction(function() Main.ShowTab("options") end)
	end, "blue")
	page.facChange:SetPoint("BOTTOMLEFT", fac, "BOTTOMLEFT", 14, 14)

	-- statistics ------------------------------------------------------------
	local stats = card(page, 0, -248, 416, 220, "통계")
	page.stats = UI.Text(stats, 12)
	page.stats:SetPoint("TOPLEFT", stats, "TOPLEFT", 14, -40)
	page.stats:SetWidth(388)
	page.stats:SetJustifyV("TOP")
	page.resetArmed = 0
	page.reset = UI.Button(stats, 220, 30, "", function()
		if page.resetArmed > 0 then
			page.resetArmed = 0
			ns.ResetDB()
			ns.Toast("모든 진행 상황을 초기화했습니다.")
			Main.SelectHero(nil)
			Main.ShowTab("party")
			ns.PickFaction(function() Main.ShowTab("party", { create = true }) end)
		else
			page.resetArmed = 5
			Main.Refresh()
		end
	end, "red")
	page.reset:SetPoint("BOTTOMLEFT", stats, "BOTTOMLEFT", 14, 14)
	page.version = UI.Text(stats, 10, "v" .. ns.VERSION)
	page.version:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", -14, 20)
	UI.Color(page.version, UI.C.dim)

	-- help ------------------------------------------------------------------
	local help = card(page, 432, -248, 416, 220, "도움말")
	page.help = UI.Text(help, 11)
	page.help:SetPoint("TOPLEFT", help, "TOPLEFT", 14, -40)
	page.help:SetWidth(388)
	page.help:SetJustifyV("TOP")
	page.help:SetSpacing(2)
	UI.Color(page.help, UI.C.text)
end

local function refresh(page)
	local db = ns.db
	page.menuScale:SetText(string.format("메뉴 창 크기  %d%%", math.floor((db.ui.scale or 1) * 100 + 0.5)))
	page.barScale:SetText(string.format("전투 창 크기  %d%%", math.floor(ns.Bar.Scale() * 100 + 0.5)))
	for _, c in ipairs(page.checks) do c:Refresh() end

	local fid = ns.Faction() or "ALLIANCE"
	local f = ns.FACTIONS[fid]
	UI.SetArtOrIcon(page.facIcon, "icon_" .. fid:lower(), f.icon)
	page.facName:SetText(U.col(f.hex, ns.N(f.name)))
	page.facDesc:SetText(ns.N(f.desc))

	local s = db.stat
	page.stats:SetText(string.format(
		"플레이 시간   %s\n처치한 몬스터   %s\n지역 공략   %s   ·   전멸   %s\n연 상자   %s%s\n누적 획득 골드   %s",
		U.time(s.time or 0), U.fmt(s.kills), U.fmt(s.clears), U.fmt(s.wipes), U.fmt(s.chests),
		(s.lost or 0) > 0 and string.format("   ·   못 받은 상자 %s", U.fmt(s.lost)) or "", U.fmt(s.gold)))
	if page.resetArmed > 0 then
		page.reset:SetLabel("정말 초기화하려면 한 번 더")
	else
		page.reset:SetLabel("모든 진행 상황 초기화")
	end

	page.help:SetText(string.format(
		"• /biwh : 메뉴 열기·닫기   • /biwh bar : 전투 창 보이기·숨기기\n" ..
		"• 전투 창: 왼쪽 드래그로 옮기기, 오른쪽 아래 모서리로 크기, 우클릭으로 메뉴\n" ..
		"• '다음 목표'를 누르면 지금 할 일을 바로 하거나 그 화면을 엽니다.\n" ..
		"• 빨간 점은 지금 할 수 있는 일이 있다는 표시입니다.\n" ..
		"• 레벨이 오르면 특성 점수(능력치)가, 4레벨마다 기술 점수(기술)가 생깁니다.\n" ..
		"• 가방에서 Alt+클릭은 장비 보호, 우클릭은 분해입니다.\n" ..
		"• 게임을 꺼 두어도 오프라인 보상이 쌓입니다 (지금 효율 %d%%, 최대 %s).",
		math.floor(ns.Offline.Efficiency() * 100 + 0.5), U.time(ns.Offline.Cap())))
end

local function tick(page)
	if page.resetArmed > 0 then
		page.resetArmed = page.resetArmed - 0.2
		if page.resetArmed <= 0 then
			page.resetArmed = 0
			refresh(page)
		end
	end
end

Main.RegisterTab({
	key = "options", title = "설정", sub = "화면, 진영, 통계, 도움말", nav = false,
	icon = "Trade_Engineering", art = "icon_settings", build = build, refresh = refresh, tick = tick,
	events = { "RESET", "FACTION" },
})
