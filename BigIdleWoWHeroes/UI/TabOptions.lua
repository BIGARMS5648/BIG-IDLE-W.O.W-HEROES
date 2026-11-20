-- Settings screen: display, game flow, statistics, help and save reset.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local function setScale(delta)
	local s = U.clamp((ns.db.ui.scale or 1) + delta, 0.6, 1.6)
	ns.db.ui.scale = math.floor(s * 20 + 0.5) / 20
	ns.Bar.ApplyPosition()
	Main.ApplyScale()
end

local function card(page, x, y, w, h, title)
	local c = UI.Panel(page, w, h, "card")
	c:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	c.title = UI.Title(c, title, 14)
	c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -12)
	return c
end

local function build(page)
	-- display
	local disp = card(page, 0, 0, 416, 220, "화면")
	page.scaleText = UI.Text(disp, 12)
	page.scaleText:SetPoint("TOPLEFT", disp, "TOPLEFT", 14, -46)
	local minus = UI.Button(disp, 36, 28, "-", function() setScale(-0.05) Main.Refresh() end, "dark")
	minus:SetPoint("TOPLEFT", disp, "TOPLEFT", 150, -40)
	local plus = UI.Button(disp, 36, 28, "+", function() setScale(0.05) Main.Refresh() end, "dark")
	plus:SetPoint("LEFT", minus, "RIGHT", 6, 0)
	local resetPos = UI.Button(disp, 150, 28, "전투 창 위치 초기화", function() ns.Bar.ResetPosition() end, "blue")
	resetPos:SetPoint("LEFT", plus, "RIGHT", 10, 0)
	page.checks = {
		UI.Check(disp, "전투 창 표시", function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(disp, "전투 창 아래 메뉴 줄 숨기기 (작게 보기)",
			function() return ns.db.ui.compact end, function(v) ns.db.ui.compact = v and true or nil ns.Bar.ApplyCompact() end),
		UI.Check(disp, "전투 창 위치 잠금", function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
		UI.Check(disp, "효과음", function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", disp, "TOPLEFT", 14, -84 - (i - 1) * 30)
	end

	-- how the game flows
	local flow = card(page, 432, 0, 416, 220, "게임 흐름")
	local steps = UI.Text(flow, 12,
		"1. 상자를 열어 장비를 얻습니다.\n" ..
		"2. 영웅에게 더 좋은 장비를 장착합니다 (일괄 장착).\n" ..
		"3. 남는 장비는 용광로에서 분해하거나 융합합니다.\n" ..
		"4. 골드로 룬을 배워 파티를 5명까지 늘립니다.\n" ..
		"5. 레벨이 오르면 특성 점수를 쓰고 기술을 장착합니다.\n" ..
		"6. 막히면 이전 지역에서 힘을 기른 뒤 다시 도전합니다.")
	steps:SetPoint("TOPLEFT", flow, "TOPLEFT", 14, -44)
	steps:SetWidth(388)
	steps:SetJustifyV("TOP")
	UI.Color(steps, UI.C.text)

	-- statistics
	local stats = card(page, 0, -232, 416, 236, "통계")
	page.stats = UI.Text(stats, 12)
	page.stats:SetPoint("TOPLEFT", stats, "TOPLEFT", 14, -42)
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
		else
			page.resetArmed = 5
			Main.Refresh()
		end
	end, "red")
	page.reset:SetPoint("BOTTOMLEFT", stats, "BOTTOMLEFT", 14, 14)
	page.version = UI.Text(stats, 10, "v" .. ns.VERSION)
	page.version:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", -14, 20)
	UI.Color(page.version, UI.C.dim)

	-- help
	local help = card(page, 432, -232, 416, 236, "도움말")
	local text = UI.Text(help, 11, ("• /biwh : 메뉴 열기/닫기\n• /biwh bar : 전투 창 표시/숨김\n• /biwh reset : 전투 창 위치 초기화\n\n" ..
		"• 전투 창은 왼쪽 드래그로 옮기고, 우클릭하면 메뉴가 열립니다.\n" ..
		"• 전투 창의 '다음 목표'를 누르면 지금 할 일을 바로 하거나 해당 화면을 엽니다.\n" ..
		"• 빨간 점은 확인할 것이 있다는 표시입니다.\n" ..
		"• 게임을 끄고 있어도 최대 8시간까지 오프라인 보상이 쌓입니다."))
	text:SetPoint("TOPLEFT", help, "TOPLEFT", 14, -42)
	text:SetWidth(388)
	text:SetJustifyV("TOP")
	UI.Color(text, UI.C.text)
end

local function refresh(page)
	local db = ns.db
	page.scaleText:SetText(string.format("UI 크기  %d%%", math.floor((db.ui.scale or 1) * 100 + 0.5)))
	for _, c in ipairs(page.checks) do c:Refresh() end
	local s = db.stat
	page.stats:SetText(string.format(
		"플레이 시간   %s\n처치한 몬스터   %s\n스테이지 공략   %s   ·   전멸   %s\n연 상자   %s\n누적 획득 골드   %s\n오프라인 보상   효율 %d%% · 최대 %s",
		U.time(s.time or 0), U.fmt(s.kills), U.fmt(s.clears), U.fmt(s.wipes), U.fmt(s.chests), U.fmt(s.gold),
		math.floor(ns.Offline.Efficiency() * 100 + 0.5), U.time(ns.Offline.Cap())))
	if page.resetArmed > 0 then
		page.reset:SetLabel("정말 초기화하려면 한 번 더")
	else
		page.reset:SetLabel("모든 진행 상황 초기화")
	end
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
	key = "options", title = "설정", sub = "화면, 통계, 도움말",
	icon = "Trade_Engineering", build = build, refresh = refresh, tick = tick,
	events = { "RESET" },
})
