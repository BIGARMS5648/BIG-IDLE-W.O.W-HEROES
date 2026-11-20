-- Settings (설정), opened from the gear button in the window header. Built
-- from the screen kit (UI/Layout.lua):
--   tabs: 화면 · 게임 · 정보
--   list: the settings of the tab;
--   card: the battle window / the faction / the saved game.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local function setMenuScale(delta)
	local s = U.clamp((ns.db.ui.scale or 1) + delta, 0.6, 1.6)
	ns.db.ui.scale = math.floor(s * 20 + 0.5) / 20
	Main.ApplyScale()
end

-- label on the left, [-] value [+] on the right
local function stepper(parent, y, onMinus, onPlus)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(K.LIST_IN, 30)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", K.PAD, y)
	row.label = UI.Text(row, K.F_BODY)
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.plus = UI.Button(row, 34, 28, "+", onPlus, "dark")
	row.plus:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value = UI.Text(row, K.F_BODY)
	row.value:SetPoint("RIGHT", row.plus, "LEFT", -8, 0)
	row.value:SetWidth(50)
	row.value:SetJustifyH("CENTER")
	row.minus = UI.Button(row, 34, 28, "-", onMinus, "dark")
	row.minus:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
	return row
end

local function build(page)
	page.tab = "screen"
	local S = UI.Screen(page, {
		tabs = { { "screen", "화면" }, { "game", "게임" }, { "info", "정보" } },
		onTab = function(key)
			page.tab = key
			Main.Refresh()
		end,
	})
	page.S = S
	local list = S.list

	-- 화면
	local sc = CreateFrame("Frame", nil, list)
	sc:SetAllPoints(list)
	page.screen = sc
	sc.head = UI.Section(sc, K.LIST_IN, "크기")
	sc.head:SetPoint("TOPLEFT", sc, "TOPLEFT", K.PAD, -K.PAD)
	sc.menu = stepper(sc, -38, function() setMenuScale(-0.05) Main.Refresh() end, function() setMenuScale(0.05) Main.Refresh() end)
	sc.menu.label:SetText("메뉴 창 크기")
	sc.bar = stepper(sc, -72, function() ns.Bar.SetScale(ns.Bar.Scale() - 0.05) Main.Refresh() end,
		function() ns.Bar.SetScale(ns.Bar.Scale() + 0.05) Main.Refresh() end)
	sc.bar.label:SetText("전투 창 크기")
	sc.head2 = UI.Section(sc, K.LIST_IN, "전투 창")
	sc.head2:SetPoint("TOPLEFT", sc, "TOPLEFT", K.PAD, -118)
	sc.checks = {
		UI.Check(sc, "전투 창 보이기", function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(sc, "아래 메뉴 줄 숨기기 (작게 보기)",
			function() return ns.db.ui.compact end, function(v) ns.db.ui.compact = v and true or nil ns.Bar.ApplyCompact() end),
		UI.Check(sc, "위치·크기 잠금", function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
	}
	for i, c in ipairs(sc.checks) do c:SetPoint("TOPLEFT", sc, "TOPLEFT", K.PAD, -146 - (i - 1) * 26) end

	-- 게임
	local gm = CreateFrame("Frame", nil, list)
	gm:SetAllPoints(list)
	page.game = gm
	gm.head = UI.Section(gm, K.LIST_IN, "가방")
	gm.head:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -K.PAD)
	gm.autoSmelt = UI.Check(gm, "가방이 차면 자동 분해",
		function() return (ns.db.opt.autoSmelt or 0) > 0 end,
		function(v) ns.db.opt.autoSmelt = v and U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY) or 0 end)
	gm.autoSmelt:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -40)
	gm.smeltNote = UI.Text(gm, K.F_SMALL)
	gm.smeltNote:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD + 30, -64)
	gm.smeltNote:SetWidth(K.LIST_IN - 30)
	UI.Color(gm.smeltNote, UI.C.sub)
	gm.head2 = UI.Section(gm, K.LIST_IN, "소리")
	gm.head2:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -100)
	gm.sound = UI.Check(gm, "효과음", function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end)
	gm.sound:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -128)
	gm.head3 = UI.Section(gm, K.LIST_IN, "진행 방식")
	gm.head3:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -166)
	gm.flow = UI.Text(gm, K.F_SMALL, "자동 진행, 전멸 시 물러나기, 다시 도전은 '스테이지' 화면 아래에서 바꿉니다.")
	gm.flow:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -194)
	gm.flow:SetWidth(K.LIST_IN)
	UI.Color(gm.flow, UI.C.sub)

	-- 정보
	local inf = CreateFrame("Frame", nil, list)
	inf:SetAllPoints(list)
	page.info = inf
	inf.head = UI.Section(inf, K.LIST_IN, "통계")
	inf.head:SetPoint("TOPLEFT", inf, "TOPLEFT", K.PAD, -K.PAD)
	inf.rows = {}
	for i = 1, 6 do
		local r = UI.StatRow(inf, K.LIST_IN)
		r:SetPoint("TOPLEFT", inf, "TOPLEFT", K.PAD, -38 - (i - 1) * 24)
		inf.rows[i] = r
	end
	inf.head2 = UI.Section(inf, K.LIST_IN, "도움말")
	inf.head2:SetPoint("TOPLEFT", inf, "TOPLEFT", K.PAD, -190)
	inf.help = UI.Text(inf, K.F_SMALL)
	inf.help:SetPoint("TOPLEFT", inf, "TOPLEFT", K.PAD, -216)
	inf.help:SetWidth(K.LIST_IN)
	inf.help:SetJustifyV("TOP")
	inf.help:SetSpacing(3)

	-- card text
	page.cardText = UI.Text(S.card.content, K.F_BODY)
	page.cardText:SetPoint("TOPLEFT", S.card.content, "TOPLEFT", 0, 0)
	page.cardText:SetWidth(K.CARD_IN)
	page.cardText:SetJustifyV("TOP")
end

local function refresh(page)
	local db = ns.db
	local S = page.S
	local d = S.card
	S.tabs:Select(page.tab)
	page.screen:SetShown(page.tab == "screen")
	page.game:SetShown(page.tab == "game")
	page.info:SetShown(page.tab == "info")
	d:Extras(nil, nil)

	if page.tab == "screen" then
		local sc = page.screen
		sc.menu.value:SetText(math.floor((db.ui.scale or 1) * 100 + 0.5) .. "%")
		sc.bar.value:SetText(math.floor(ns.Bar.Scale() * 100 + 0.5) .. "%")
		for _, c in ipairs(sc.checks) do c:Refresh() end
		d:Head({ icon = "INV_Misc_Spyglass_02", title = "전투 창", sub = "끌어서 옮기고, 모서리로 크기 조절" })
		page.cardText:SetText("• 왼쪽 버튼으로 끌면 옮겨집니다.\n• 오른쪽 아래 모서리를 끌면 크기가 바뀝니다 (모서리 우클릭: 원래 크기).\n• 전투 창을 우클릭하면 메뉴가 열립니다.")
		d:Actions(nil, { "위치·크기 원래대로", function() ns.Bar.ResetPosition() Main.Refresh() end, "primary",
			tip = { "원래대로", "전투 창의 위치와 크기를 처음 상태로 되돌립니다." } })
	elseif page.tab == "game" then
		local gm = page.game
		gm.autoSmelt:Refresh()
		gm.sound:Refresh()
		local q = U.clamp(db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)
		gm.smeltNote:SetText("기준: " .. U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하 · 보호한 장비와 파티에게 더 좋은 장비는 남깁니다. 기준 등급은 가방 화면 아래에서 바꿉니다.")
		local fid = ns.Faction() or "ALLIANCE"
		local f = ns.FACTIONS[fid]
		d:Head({ icon = f.icon, title = ns.N(f.name), titleRGB = { U.rgb(f.hex) }, sub = "지금 진영" })
		page.cardText:SetText(ns.N(f.desc) .. "\n\n" .. U.col("aab3c8", "진영에 따라 영웅의 종족 모습이 바뀝니다. 이름, 레벨, 장비, 능력치는 그대로입니다."))
		d:Actions(nil, { "진영 바꾸기", function() ns.PickFaction(function() Main.ShowTab("options") end) end, "primary" })
	else
		local inf = page.info
		local s = db.stat
		local rows = {
			{ "플레이 시간", U.time(s.time or 0) },
			{ "처치한 몬스터", U.fmt(s.kills) },
			{ "지역 공략 · 전멸", U.fmt(s.clears) .. " · " .. U.fmt(s.wipes) },
			{ "연 상자", U.fmt(s.chests) .. ((s.lost or 0) > 0 and (" · 못 받은 상자 " .. U.fmt(s.lost)) or "") },
			{ "누적 획득 골드", U.fmt(s.gold) },
			{ "버전", "v" .. ns.VERSION },
		}
		for i, r in ipairs(inf.rows) do r:Set(rows[i][1], rows[i][2]) end
		inf.help:SetText(string.format(
			"• /biwh : 메뉴 열기·닫기   • /biwh bar : 전투 창 보이기·숨기기\n" ..
			"• '다음 목표'를 누르면 지금 할 일을 바로 하거나 그 화면을 엽니다.\n" ..
			"• 빨간 점은 지금 할 수 있는 일이 있다는 표시입니다.\n" ..
			"• 레벨마다 특성 점수(능력치), 4레벨마다 기술 점수(기술)가 생깁니다.\n" ..
			"• 가방에서 Alt+클릭은 장비 보호, 우클릭은 분해입니다.\n" ..
			"• 게임을 꺼 두어도 오프라인 보상이 쌓입니다 (지금 효율 %d%%, 최대 %s).",
			math.floor(ns.Offline.Efficiency() * 100 + 0.5), U.time(ns.Offline.Cap())))
		d:Head({ icon = "INV_Misc_Note_01", title = "저장 데이터", sub = "모든 진행 상황" })
		page.cardText:SetText("처음부터 다시 시작하려면 모든 진행 상황을 지울 수 있습니다.\n\n" .. U.col("ff9a7a", "영웅, 장비, 골드, 룬, 진행도가 모두 사라지며 되돌릴 수 없습니다."))
		d:Actions(nil, { "모든 진행 상황 초기화", function()
			UI.Confirm({ title = "모든 진행 상황 초기화", ok = "초기화", style = "red",
				text = "모든 진행 상황을 초기화하시겠습니까?\n영웅, 장비, 골드, 룬, 진행도가 모두 사라지며 되돌릴 수 없습니다.",
				onOk = function()
					ns.ResetDB()
					ns.Toast("모든 진행 상황을 초기화했습니다.")
					Main.SelectHero(nil)
					Main.ShowTab("party")
					ns.PickFaction(function() Main.ShowTab("party", { create = true }) end)
				end })
		end, "red" })
	end
end

local function tick(page) end

Main.RegisterTab({
	key = "options", title = "설정", sub = "화면, 게임, 정보", nav = false,
	icon = "Trade_Engineering", art = "icon_settings", build = build, refresh = refresh, tick = tick,
	events = { "RESET", "FACTION" },
})
