-- Settings (설정), opened from the gear button in the window header.
--   tabs: 화면 · 게임 · 정보
--   one wide panel per tab: each setting on its own line with its control
--   beside it; a button that acts on a group (원래대로, 진영 바꾸기, 초기화)
--   sits in that group's header.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K
local W = K.W - 2 * K.PAD -- the panel's inner width

local function setMenuScale(delta)
	local s = U.clamp((ns.db.ui.scale or 1) + delta, 0.6, 1.6)
	ns.db.ui.scale = math.floor(s * 20 + 0.5) / 20
	Main.ApplyScale()
end

-- label on the left, [-] value [+] on the right
local function stepper(parent, y, onMinus, onPlus)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(W, 30)
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

-- a grey note under a setting
local function note(parent, x, y, text)
	local t = UI.Text(parent, K.F_SMALL, text)
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	t:SetWidth(W - (x - K.PAD))
	t:SetJustifyV("TOP")
	t:SetSpacing(2)
	UI.Color(t, UI.C.sub)
	return t
end

local function section(parent, y, title)
	local s = UI.Section(parent, W, title)
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", K.PAD, y)
	return s
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
	-- settings need no "chosen thing" card: the list takes the whole width
	S.card:Hide()
	local list = S.list
	list:SetWidth(K.W)

	-- 화면 -----------------------------------------------------------------
	local sc = CreateFrame("Frame", nil, list)
	sc:SetAllPoints(list)
	page.screen = sc
	sc.head = section(sc, -K.PAD, "크기")
	sc.menu = stepper(sc, -38, function() setMenuScale(-0.05) Main.Refresh() end, function() setMenuScale(0.05) Main.Refresh() end)
	sc.menu.label:SetText("메뉴 창 크기")
	sc.bar = stepper(sc, -72, function() ns.Bar.SetScale(ns.Bar.Scale() - 0.05) Main.Refresh() end,
		function() ns.Bar.SetScale(ns.Bar.Scale() + 0.05) Main.Refresh() end)
	sc.bar.label:SetText("전투 창 크기")
	sc.head2 = section(sc, -122, "전투 창")
	sc.resetPos = sc.head2:AddTool(UI.Button(sc, 130, 22, "위치·크기 원래대로", function()
		ns.Bar.ResetPosition()
		Main.Refresh()
	end, "dark"))
	UI.Tip(sc.resetPos, function() return UI.SimpleTip("원래대로", "전투 창의 위치와 크기를 처음 상태로 되돌립니다.") end, "TOP")
	sc.checks = {
		UI.Check(sc, "전투 창 보이기", function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(sc, "전투 창 아래 줄 숨기기: 다음 목표·자동 진행·상자·메뉴 (작게 보기)",
			function() return ns.db.ui.compact end, function(v) ns.db.ui.compact = v and true or nil ns.Bar.ApplyCompact() end),
		UI.Check(sc, "위치·크기 잠금", function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
		UI.Check(sc, "영웅·몬스터를 게임의 3D 모델로 보기", function() return ns.db.opt.models ~= false end,
			function(v) ns.db.opt.models = v and true or false end),
	}
	for i, c in ipairs(sc.checks) do c:SetPoint("TOPLEFT", sc, "TOPLEFT", K.PAD, -150 - (i - 1) * 26) end
	UI.Tip(sc.checks[4], function()
		return UI.SimpleTip("3D 모델", "전투 창의 영웅·몬스터·우두머리·소환물·동료를 게임에 들어 있는 3D 모델로 보여 줍니다. 끄면 그림(또는 아이콘)으로 보여 줍니다.")
	end, "TOP")
	sc.howto = note(sc, K.PAD, -262, "• 전투 창은 왼쪽 버튼으로 끌어 옮깁니다.\n" ..
		"• 오른쪽 아래 모서리를 끌면 크기가 바뀝니다 (모서리 우클릭: 원래 크기).\n" ..
		"• 전투 창을 우클릭하면 메뉴가 열립니다.")

	-- 게임 -----------------------------------------------------------------
	local gm = CreateFrame("Frame", nil, list)
	gm:SetAllPoints(list)
	page.game = gm
	gm.head = section(gm, -K.PAD, "가방")
	gm.autoSmelt = UI.Check(gm, "가방이 차면 자동 분해",
		function() return (ns.db.opt.autoSmelt or 0) > 0 end,
		function(v)
			if v and not ns.Forge.Unlocked("smelt") then
				UI.Try(false, "분해가 아직 잠겨 있습니다. 장비 > 가방 아래의 [분해 해금]을 먼저 누르세요.")
				return
			end
			ns.db.opt.autoSmelt = v and U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY) or 0
		end)
	gm.autoSmelt:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -40)
	gm.smeltNote = note(gm, K.PAD + 30, -66, "")
	gm.head2 = section(gm, -100, "소리")
	gm.sound = UI.Check(gm, "효과음", function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end)
	gm.sound:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -128)
	gm.head3 = section(gm, -166, "진영")
	gm.faction = gm.head3:AddTool(UI.Button(gm, 96, 22, "진영 바꾸기", function()
		ns.PickFaction(function() Main.ShowTab("options") end)
	end, "dark"))
	gm.factionIcon = UI.IconButton(gm, 40)
	gm.factionIcon:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -194)
	gm.factionIcon:EnableMouse(false)
	gm.factionName = UI.Text(gm, K.F_TITLE)
	gm.factionName:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD + 50, -196)
	gm.factionText = note(gm, K.PAD + 50, -216, "")
	gm.head4 = section(gm, -262, "진행 방식")
	gm.flow = note(gm, K.PAD, -290, "자동 진행, 전멸 시 물러나기, 다시 도전은 '스테이지' 화면 아래에서 바꿉니다.")

	-- 정보 -----------------------------------------------------------------
	local inf = CreateFrame("Frame", nil, list)
	inf:SetAllPoints(list)
	page.info = inf
	inf.head = section(inf, -K.PAD, "통계")
	inf.rows = {}
	local half = (W - 24) / 2
	for i = 1, 6 do
		local r = UI.StatRow(inf, half)
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		r:SetPoint("TOPLEFT", inf, "TOPLEFT", K.PAD + col * (half + 24), -38 - row * 24)
		inf.rows[i] = r
	end
	inf.head2 = section(inf, -124, "도움말")
	inf.help = note(inf, K.PAD, -150, "")
	inf.head3 = section(inf, -300, "저장 데이터")
	inf.reset = inf.head3:AddTool(UI.Button(inf, 150, 22, "모든 진행 상황 초기화", function()
		UI.Confirm({ title = "모든 진행 상황 초기화", ok = "초기화", style = "red",
			text = "모든 진행 상황을 초기화하시겠습니까?\n영웅, 장비, 골드, 룬, 진행도가 모두 사라지며 되돌릴 수 없습니다.",
			onOk = function()
				ns.ResetDB()
				ns.Toast("모든 진행 상황을 초기화했습니다.")
				Main.SelectHero(nil)
				Main.ShowTab("hero")
				ns.PickFaction(function() Main.ShowTab("hero", { create = true }) end)
			end })
	end, "red"))
	inf.resetNote = note(inf, K.PAD, -328, "처음부터 다시 시작하려면 모든 진행 상황을 지웁니다. " ..
		U.col("ff9a7a", "영웅, 장비, 골드, 룬, 진행도가 모두 사라지며 되돌릴 수 없습니다."))
end

local function refresh(page)
	local db = ns.db
	local S = page.S
	S.tabs:Select(page.tab)
	page.screen:SetShown(page.tab == "screen")
	page.game:SetShown(page.tab == "game")
	page.info:SetShown(page.tab == "info")

	if page.tab == "screen" then
		local sc = page.screen
		sc.menu.value:SetText(math.floor((db.ui.scale or 1) * 100 + 0.5) .. "%")
		sc.bar.value:SetText(math.floor(ns.Bar.Scale() * 100 + 0.5) .. "%")
		for _, c in ipairs(sc.checks) do c:Refresh() end
	elseif page.tab == "game" then
		local gm = page.game
		gm.autoSmelt:Refresh()
		gm.sound:Refresh()
		local q = U.clamp(db.ui.smeltQ or 2, 1, ns.MAX_QUALITY)
		gm.smeltNote:SetText("기준: " .. U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하 · 보호한 장비, 보석·마법부여·각인이 붙은 장비, 파티에게 더 좋은 장비는 남깁니다. 기준 등급은 장비 > 가방 아래 '분해 등급'에서 바꿉니다.")
		local fid = ns.Faction() or "ALLIANCE"
		local f = ns.FACTIONS[fid]
		gm.factionIcon:SetIconName(f.icon)
		gm.factionName:SetText(U.col(f.hex, ns.N(f.name)))
		gm.factionText:SetText(ns.N(f.desc) .. " 진영에 따라 영웅의 종족 모습이 바뀝니다. 이름, 레벨, 장비, 능력치는 그대로입니다.")
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
			"• /bwi : 메뉴 열기·닫기   • /bwi bar : 전투 창 보이기·숨기기\n" ..
			"• '다음 목표'를 누르면 지금 할 일을 바로 하거나 그 화면을 엽니다.\n" ..
			"• 빨간 점은 지금 할 수 있는 일이 있다는 표시입니다.\n" ..
			"• 레벨마다 특성 점수(능력치), 4레벨마다 기술 점수(기술)가 생깁니다.\n" ..
			"• 가방에서 클릭은 장착, 우클릭은 분해, Alt+클릭은 보호, Shift+클릭은 창고 보관입니다.\n" ..
			"• 게임을 꺼 두어도 오프라인 보상이 쌓입니다 (지금 효율 %d%%, 최대 %s).",
			math.floor(ns.Offline.Efficiency() * 100 + 0.5), U.time(ns.Offline.Cap())))
	end
end

local function tick(page) end

Main.RegisterTab({
	key = "options", title = "설정", sub = "화면, 게임, 정보", nav = false,
	icon = "Trade_Engineering", art = "icon_settings", build = build, refresh = refresh, tick = tick,
	events = { "RESET", "FACTION" },
})
