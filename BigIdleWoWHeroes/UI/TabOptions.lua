-- Options page: display settings, language, statistics and save reset.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local function setScale(delta)
	local s = U.clamp((ns.db.ui.scale or 1) + delta, 0.6, 1.6)
	ns.db.ui.scale = math.floor(s * 20 + 0.5) / 20
	ns.Bar.ApplyPosition()
	Main.ApplyScale()
end

local function build(page)
	local T = ns.T
	local y = 0
	local function header(text)
		local h = UI.Text(page, 12, text)
		h:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
		h:SetTextColor(1, 0.82, 0)
		y = y - 22
	end

	header(T("화면", "Display"))
	page.scaleText = UI.Text(page, 11)
	page.scaleText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 3)
	local minus = UI.Button(page, 26, 20, "-", function() setScale(-0.05) Main.Refresh() end)
	minus:SetPoint("TOPLEFT", page, "TOPLEFT", 130, y)
	local plus = UI.Button(page, 26, 20, "+", function() setScale(0.05) Main.Refresh() end)
	plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	local resetPos = UI.Button(page, 150, 20, T("전투 바 위치 초기화", "Reset bar position"), function() ns.Bar.ResetPosition() end)
	resetPos:SetPoint("LEFT", plus, "RIGHT", 12, 0)
	y = y - 28

	page.checks = {
		UI.Check(page, T("전투 바 표시", "Show the battle bar"),
			function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(page, T("전투 바 위치 잠금 (드래그 방지)", "Lock the battle bar in place"),
			function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
		UI.Check(page, T("효과음", "Sound effects"),
			function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end),
	}
	for _, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
		y = y - 22
	end
	y = y - 10

	header(T("언어", "Language"))
	page.langs = {}
	local langs = { { nil, T("자동 (클라이언트 언어)", "Automatic (client language)") }, { "ko", "한국어" }, { "en", "English" } }
	for i, l in ipairs(langs) do
		local b = UI.Button(page, i == 1 and 190 or 100, 22, l[2], function()
			ns.db.lang = l[1]
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", i == 1 and 0 or (194 + (i - 2) * 104), y)
		b.lang = l[1]
		page.langs[i] = b
	end
	page.reload = UI.Button(page, 170, 22, T("UI 다시 불러오기 (적용)", "Reload UI (apply)"), function()
		if ReloadUI then ReloadUI() end
	end)
	page.reload:SetPoint("TOPLEFT", page, "TOPLEFT", 420, y)
	y = y - 28
	page.langNote = UI.Text(page, 10, T("언어를 바꾼 뒤에는 UI를 다시 불러와야 적용됩니다.", "Reload the UI after changing the language."))
	page.langNote:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
	page.langNote:SetTextColor(0.7, 0.7, 0.7)
	y = y - 26

	header(T("통계", "Statistics"))
	page.stats = UI.Text(page, 11)
	page.stats:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
	page.stats:SetWidth(Main.PAGE_W)
	page.stats:SetJustifyV("TOP")
	y = y - 78

	header(T("도움말", "Help"))
	page.help = UI.Text(page, 10, T(
		"/biwh  메뉴 열기/닫기   ·   /biwh bar  전투 바 표시/숨김   ·   /biwh reset  전투 바 위치 초기화\n전투 바: 왼쪽 드래그로 이동, 우클릭으로 메뉴 열기. 게임을 끄고 있어도 최대 8시간까지 오프라인 보상이 쌓입니다.\n흐름: 상자를 열어 장비를 얻고 → 영웅에게 착용시키고 → 남는 장비는 용광로에서 용해/융합 → 골드로 룬을 배워 파티를 5명까지 늘리세요.",
		"/biwh  toggle the menu   -   /biwh bar  show / hide the battle bar   -   /biwh reset  reset the bar position\nBattle bar: drag with the left button to move it, right-click to open the menu. While logged out you earn offline rewards for up to 8 hours.\nLoop: open chests for gear -> equip your heroes -> smelt or fuse the rest in the forge -> spend gold on runes to grow the party to five."))
	page.help:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
	page.help:SetWidth(Main.PAGE_W)
	page.help:SetJustifyV("TOP")
	page.help:SetTextColor(0.8, 0.8, 0.8)
	y = y - 84

	header(T("저장 데이터", "Saved data"))
	page.resetArmed = 0
	page.reset = UI.Button(page, 240, 22, "", function()
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
	end)
	page.reset:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
	page.version = UI.Text(page, 10, "v" .. ns.VERSION)
	page.version:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	page.version:SetTextColor(0.5, 0.5, 0.5)
end

local function refresh(page)
	local T = ns.T
	local db = ns.db
	page.scaleText:SetText(string.format(T("UI 크기: %d%%", "UI scale: %d%%"), math.floor((db.ui.scale or 1) * 100 + 0.5)))
	for _, c in ipairs(page.checks) do c:Refresh() end
	for _, b in ipairs(page.langs) do b:SetOn(db.lang == b.lang) end
	local s = db.stat
	page.stats:SetText(string.format(
		T("플레이 시간  %s\n처치한 몬스터  %s   ·   스테이지 공략  %s   ·   전멸  %s\n연 상자  %s   ·   누적 획득 골드  %s\n오프라인 보상 효율  %d%% (최대 %s)",
			"Time played  %s\nMonsters defeated  %s   -   Stages cleared  %s   -   Wipes  %s\nChests opened  %s   -   Gold earned in total  %s\nOffline reward rate  %d%% (up to %s)"),
		U.time(s.time or 0), U.fmt(s.kills), U.fmt(s.clears), U.fmt(s.wipes), U.fmt(s.chests), U.fmt(s.gold),
		math.floor(ns.Offline.Efficiency() * 100 + 0.5), U.time(ns.Offline.Cap())))
	if page.resetArmed > 0 then
		page.reset:SetLabel(T("정말 초기화하려면 한 번 더 클릭", "Click again to really reset"))
		page.reset:SetTextRGB(1, 0.3, 0.3)
	else
		page.reset:SetLabel(T("모든 진행 상황 초기화", "Reset all progress"))
		page.reset:SetTextRGB(1, 0.9, 0.6)
	end
end

local function tick(page)
	if page.resetArmed > 0 then
		page.resetArmed = page.resetArmed - 0.15
		if page.resetArmed <= 0 then
			page.resetArmed = 0
			refresh(page)
		end
	end
end

Main.RegisterTab({
	key = "options", title = { "설정", "Options" }, build = build, refresh = refresh, tick = tick,
	events = { "RESET" },
})
