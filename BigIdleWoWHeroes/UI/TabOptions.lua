-- Settings screen: display, language, statistics, help and save reset.
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
	local T = ns.T
	-- display
	local disp = card(page, 0, 0, 416, 220, T("화면", "Display"))
	page.scaleText = UI.Text(disp, 12)
	page.scaleText:SetPoint("TOPLEFT", disp, "TOPLEFT", 14, -46)
	local minus = UI.Button(disp, 36, 28, "-", function() setScale(-0.05) Main.Refresh() end, "dark")
	minus:SetPoint("TOPLEFT", disp, "TOPLEFT", 150, -40)
	local plus = UI.Button(disp, 36, 28, "+", function() setScale(0.05) Main.Refresh() end, "dark")
	plus:SetPoint("LEFT", minus, "RIGHT", 6, 0)
	local resetPos = UI.Button(disp, 150, 28, T("전투 창 위치 초기화", "Reset HUD position"), function() ns.Bar.ResetPosition() end, "blue")
	resetPos:SetPoint("LEFT", plus, "RIGHT", 10, 0)
	page.checks = {
		UI.Check(disp, T("전투 창 표시", "Show the battle HUD"), function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(disp, T("전투 창 아래 메뉴 줄 숨기기 (작게 보기)", "Hide the HUD's lower dock (compact)"),
			function() return ns.db.ui.compact end, function(v) ns.db.ui.compact = v and true or nil ns.Bar.ApplyCompact() end),
		UI.Check(disp, T("전투 창 위치 잠금", "Lock the HUD in place"), function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
		UI.Check(disp, T("효과음", "Sound effects"), function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", disp, "TOPLEFT", 14, -84 - (i - 1) * 30)
	end

	-- language
	local lang = card(page, 432, 0, 416, 220, T("언어", "Language"))
	page.langs = {}
	local langs = { { nil, T("자동 (클라이언트 언어)", "Automatic (client language)") }, { "ko", "한국어" }, { "en", "English" } }
	for i, l in ipairs(langs) do
		local c = UI.Chip(lang, i == 1 and 200 or 90, 28, l[2], function()
			ns.db.lang = l[1]
			Main.Refresh()
		end)
		c:SetPoint("TOPLEFT", lang, "TOPLEFT", i == 1 and 14 or (220 + (i - 2) * 96), -44)
		c.lang = l[1]
		page.langs[i] = c
	end
	page.reload = UI.Button(lang, 200, 32, T("UI 다시 불러오기 (적용)", "Reload UI (apply)"), function()
		if ReloadUI then ReloadUI() end
	end, "primary")
	page.reload:SetPoint("TOPLEFT", lang, "TOPLEFT", 14, -86)
	local note = UI.Text(lang, 11, T("언어를 바꾼 뒤에는 UI를 다시 불러와야 적용됩니다. 영웅 이름은 언어에 맞는 표기로 바뀝니다.",
		"Reload the UI after changing the language. Hero names switch to that language's spelling."))
	note:SetPoint("TOPLEFT", lang, "TOPLEFT", 14, -130)
	note:SetWidth(388)
	UI.Color(note, UI.C.sub)

	-- statistics
	local stats = card(page, 0, -232, 416, 236, T("통계", "Statistics"))
	page.stats = UI.Text(stats, 12)
	page.stats:SetPoint("TOPLEFT", stats, "TOPLEFT", 14, -42)
	page.stats:SetWidth(388)
	page.stats:SetJustifyV("TOP")
	page.resetArmed = 0
	page.reset = UI.Button(stats, 220, 30, "", function()
		if page.resetArmed > 0 then
			page.resetArmed = 0
			ns.ResetDB()
			ns.Toast(ns.T("모든 진행 상황을 초기화했습니다.", "All progress has been reset."))
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
	local help = card(page, 432, -232, 416, 236, T("도움말", "Help"))
	local text = UI.Text(help, 11, T(
		"• /biwh : 메뉴 열기/닫기\n• /biwh bar : 전투 창 표시/숨김\n• /biwh reset : 전투 창 위치 초기화\n\n" ..
		"• 전투 창은 왼쪽 드래그로 옮기고, 우클릭하면 메뉴가 열립니다.\n" ..
		"• 전투 창의 '다음 목표'를 누르면 지금 할 일을 바로 하거나 해당 화면을 엽니다.\n" ..
		"• 빨간 점은 확인할 것이 있다는 표시입니다.\n" ..
		"• 게임을 끄고 있어도 최대 8시간까지 오프라인 보상이 쌓입니다.",
		"• /biwh : open / close the menu\n• /biwh bar : show / hide the battle HUD\n• /biwh reset : reset the HUD position\n\n" ..
		"• Drag the HUD with the left button; right-click opens the menu.\n" ..
		"• 'Next goal' on the HUD does the next useful thing or opens the right screen.\n" ..
		"• A red dot means something is waiting for you there.\n" ..
		"• While logged out you earn offline rewards for up to 8 hours."))
	text:SetPoint("TOPLEFT", help, "TOPLEFT", 14, -42)
	text:SetWidth(388)
	text:SetJustifyV("TOP")
	UI.Color(text, UI.C.text)
end

local function refresh(page)
	local T = ns.T
	local db = ns.db
	page.scaleText:SetText(string.format(T("UI 크기  %d%%", "UI scale  %d%%"), math.floor((db.ui.scale or 1) * 100 + 0.5)))
	for _, c in ipairs(page.checks) do c:Refresh() end
	for _, c in ipairs(page.langs) do c:SetOn(db.lang == c.lang) end
	local s = db.stat
	page.stats:SetText(string.format(
		T("플레이 시간   %s\n처치한 몬스터   %s\n스테이지 공략   %s   ·   전멸   %s\n연 상자   %s\n누적 획득 골드   %s\n오프라인 보상   효율 %d%% · 최대 %s",
			"Time played   %s\nMonsters defeated   %s\nStages cleared   %s   ·   Wipes   %s\nChests opened   %s\nGold earned   %s\nOffline rewards   %d%% rate · up to %s"),
		U.time(s.time or 0), U.fmt(s.kills), U.fmt(s.clears), U.fmt(s.wipes), U.fmt(s.chests), U.fmt(s.gold),
		math.floor(ns.Offline.Efficiency() * 100 + 0.5), U.time(ns.Offline.Cap())))
	if page.resetArmed > 0 then
		page.reset:SetLabel(T("정말 초기화하려면 한 번 더", "Click again to really reset"))
	else
		page.reset:SetLabel(T("모든 진행 상황 초기화", "Reset all progress"))
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
	key = "options", title = { "설정", "Settings" }, sub = { "화면, 언어, 통계", "Display, language, statistics" },
	icon = "Trade_Engineering", build = build, refresh = refresh, tick = tick,
	events = { "RESET" },
})
