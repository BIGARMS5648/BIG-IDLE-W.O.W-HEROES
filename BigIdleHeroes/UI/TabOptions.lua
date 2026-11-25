-- Settings (설정), opened from the gear button in the window header.
--   one page, two panels side by side:
--   left: 크기 (the menu window), 전투 창 (what it shows), 도움말
--   right: 소리, 진영, 진행 방식, 통계, 저장 데이터
--   each setting on its own line with its control beside it; a button that
--   acts on a group (원래대로, 진영 바꾸기, 초기화) sits in that group's header.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K
local GAP = 12
local COL_W = (K.W - GAP) / 2      -- each panel
local W = COL_W - 2 * K.PAD        -- a panel's inner width

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
	-- 왼쪽 ----------------------------------------------------------------
	local sc = UI.Panel(page, COL_W, K.H, "inset")
	sc:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.screen = sc
	sc.head = section(sc, -K.PAD, "크기")
	sc.menu = stepper(sc, -38, function() setMenuScale(-0.05) Main.Refresh() end, function() setMenuScale(0.05) Main.Refresh() end)
	sc.menu.label:SetText("메뉴 창 크기")
	sc.head2 = section(sc, -84, "전투 창")
	sc.resetPos = sc.head2:AddTool(UI.Button(sc, 130, 22, "위치·크기 원래대로", function()
		ns.Bar.ResetPosition()
		Main.Refresh()
	end, "dark"))
	UI.Tip(sc.resetPos, function() return UI.SimpleTip("원래대로", "전투 창의 위치와 크기를 처음 상태로 되돌립니다.") end, "TOP")
	sc.checks = {
		UI.Check(sc, "전투 창 보이기", function() return ns.db.ui.shown ~= false end, function(v) ns.Bar.Toggle(v) end),
		UI.Check(sc, "아래 줄 숨기기: 추천·자동 진행·상자·메뉴 (작게 보기)",
			function() return ns.db.ui.compact end, function(v) ns.db.ui.compact = v and true or nil ns.Bar.ApplyCompact() end),
		UI.Check(sc, "위치·크기 잠금", function() return ns.db.ui.locked end, function(v) ns.db.ui.locked = v end),
		UI.Check(sc, "영웅·몬스터를 게임의 3D 모델로 보기", function() return ns.db.opt.models ~= false end,
			function(v) ns.db.opt.models = v and true or false end),
		UI.Check(sc, "드루이드를 변신한 모습으로 보기 (끄면 사람 모습)", function() return ns.db.opt.druidForm ~= false end,
			function(v) ns.db.opt.druidForm = v and true or false end),
		UI.Check(sc, "전투 창 뒤에 지역의 나무·바위 모델 보기", function() return ns.db.opt.scenery ~= false end,
			function(v) ns.db.opt.scenery = v and true or false end),
	}
	for i, c in ipairs(sc.checks) do c:SetPoint("TOPLEFT", sc, "TOPLEFT", K.PAD, -112 - (i - 1) * 26) end
	UI.Tip(sc.checks[4], function()
		return UI.SimpleTip("3D 모델", "전투 창의 영웅·몬스터·우두머리·소환물·동료를 게임에 들어 있는 3D 모델로 보여 줍니다. 끄면 그림(또는 아이콘)으로 보여 줍니다.")
	end, "TOP")
	UI.Tip(sc.checks[5], function()
		return UI.SimpleTip("드루이드 변신", "켜면 수호 드루이드는 곰, 야성은 표범, 조화는 달빛야수 모습으로 싸웁니다(얼라이언스는 나이트 엘프, 호드는 타우렌의 변신 모습). 끄면 모두 사람 모습으로 무기를 들고 싸웁니다. 회복 드루이드는 늘 사람 모습입니다.")
	end, "TOP")
	UI.Tip(sc.checks[6], function()
		return UI.SimpleTip("지역 배경", "전투 창 뒤에 지금 스테이지 지역의 나무·바위·폐허·풀을 게임에 들어 있는 3D 모델로 세워 둡니다. 파티가 다음 무리로 걸어갈 때 앞쪽 줄일수록 빨리 지나갑니다. 3D 모델 보기를 끄면 함께 꺼집니다.")
	end, "TOP")
	sc.howto = note(sc, K.PAD, -274, "• 전투 창은 왼쪽 버튼으로 끌어 옮깁니다.\n" ..
		"• 오른쪽 아래 모서리를 끌면 크기가 바뀝니다 (모서리 우클릭: 원래 크기).\n" ..
		"• 전투 창을 우클릭하면 메뉴가 열립니다.")
	sc.head3 = section(sc, -338, "도움말")
	sc.help = note(sc, K.PAD, -364, "")

	-- 오른쪽 --------------------------------------------------------------
	local gm = UI.Panel(page, COL_W, K.H, "inset")
	gm:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	page.game = gm
	gm.head = section(gm, -K.PAD, "소리")
	gm.sound = UI.Check(gm, "효과음", function() return ns.db.ui.sound end, function(v) ns.db.ui.sound = v end)
	gm.sound:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -40)
	gm.head3 = section(gm, -78, "진영")
	gm.faction = gm.head3:AddTool(UI.Button(gm, 96, 22, "진영 바꾸기", function()
		ns.PickFaction(function() Main.ShowTab("options") end)
	end, "dark"))
	gm.factionIcon = UI.IconButton(gm, 40)
	gm.factionIcon:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -106)
	gm.factionIcon:EnableMouse(false)
	gm.factionName = UI.Text(gm, K.F_TITLE)
	gm.factionName:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD + 50, -108)
	gm.factionText = note(gm, K.PAD + 50, -128, "")
	gm.head4 = section(gm, -176, "진행 방식")
	gm.flow = note(gm, K.PAD, -204, "자동 진행, 전멸 시 물러나기, 다시 도전은 '스테이지' 화면 아래에서 바꿉니다.")
	gm.keepBench = UI.Check(gm, "대기 중인 영웅에게 좋은 장비도 분해·융합에서 지키기",
		function() return ns.db.opt.keepBench end, function(v) ns.db.opt.keepBench = v and true or false ns.Fire("BAG") end)
	gm.keepBench:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD, -222)
	UI.Tip(gm.keepBench, function()
		return UI.SimpleTip("대기 영웅의 장비 지키기", "켜면 파티 밖에서 기다리는 영웅에게 지금 또는 레벨을 올린 뒤 더 좋은 장비도 일괄 분해·자동 분해·융합에 쓰지 않습니다. 가방이 더 빨리 찰 수 있습니다.")
	end, "TOP")
	gm.head5 = section(gm, -258, "통계")
	gm.rows = {}
	local half = (W - 24) / 2
	for i = 1, 6 do
		local r = UI.StatRow(gm, half)
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		r:SetPoint("TOPLEFT", gm, "TOPLEFT", K.PAD + col * (half + 24), -284 - row * 24)
		gm.rows[i] = r
	end
	gm.head6 = section(gm, -366, "저장 데이터")
	gm.reset = gm.head6:AddTool(UI.Button(gm, 150, 22, "모든 진행 상황 초기화", function()
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
	gm.resetNote = note(gm, K.PAD, -394, "처음부터 다시 시작하려면 모든 진행 상황을 지웁니다. " ..
		U.col("ff9a7a", "영웅, 장비, 골드, 룬, 진행도가 모두 사라지며 되돌릴 수 없습니다."))
end

local stats -- below
local function refresh(page)
	local db = ns.db
	local sc, gm = page.screen, page.game
	sc.menu.value:SetText(math.floor((db.ui.scale or 1) * 100 + 0.5) .. "%")
	for _, c in ipairs(sc.checks) do c:Refresh() end
	sc.help:SetText(string.format(
		"• /bih : 메뉴 열기·닫기   • /bih bar : 전투 창 보이기·숨기기\n" ..
		"• '추천'을 누르면 지금 할 일을 바로 하거나 그 화면을 엽니다.\n" ..
		"• 빨간 점은 지금 할 수 있는 일이 있다는 표시입니다.\n" ..
		"• 레벨마다 특성 점수(능력치), 4레벨마다 기술 점수(기술)가 생깁니다.\n" ..
		"• 가방에서 클릭은 장착, 우클릭은 분해, Alt+클릭은 보호, Shift+클릭은 창고 보관입니다.\n" ..
		"%s",
		ns.OfflineOn() and string.format("• 게임을 꺼 두어도 오프라인 보상이 쌓입니다 (골드 %d%%, 경험치 %d%%, 최대 %s).",
			math.floor(ns.Offline.Efficiency() * 100 + 0.5), math.floor(ns.Offline.ExpEfficiency() * 100 + 0.5), U.time(ns.Offline.Cap()))
		or "• 룬 '안식의 룬'을 배우면 게임을 꺼 둔 동안에도 골드와 경험치가 쌓입니다."))

	gm.sound:Refresh()
	gm.keepBench:Refresh()
	local fid = ns.Faction() or "ALLIANCE"
	local f = ns.FACTIONS[fid]
	gm.factionIcon:SetIconName(f.icon)
	gm.factionName:SetText(U.col(f.hex, ns.N(f.name)))
	gm.factionText:SetText(ns.N(f.desc) .. " 진영에 따라 영웅의 종족 모습이 바뀝니다. 이름, 레벨, 장비, 능력치는 그대로입니다.")
	stats(page)
end

-- the play statistics, kept current while the screen is open
function stats(page)
	local gm = page.game
	local s = ns.db.stat
	local rows = {
		{ "플레이 시간", U.time(s.time or 0) },
		{ "처치한 몬스터", U.fmt(s.kills) },
		{ "지역 공략 · 전멸", U.fmt(s.clears) .. " · " .. U.fmt(s.wipes) },
		{ "연 상자", U.fmt(s.chests) .. ((s.lost or 0) > 0 and (" · 못 받은 상자 " .. U.fmt(s.lost)) or "") },
		{ "누적 획득 골드", U.fmt(s.gold) },
		{ "버전", "v" .. ns.VERSION },
	}
	for i, r in ipairs(gm.rows) do r:Set(rows[i][1], rows[i][2]) end
end

local function tick(page)
	page.statT = (page.statT or 0) + 1
	if page.statT >= 5 then -- the page ticks five times a second
		page.statT = 0
		stats(page)
	end
end

Main.RegisterTab({
	key = "options", title = "설정", sub = "화면, 소리, 진영, 정보", nav = false,
	icon = "Trade_Engineering", art = "icon_settings", build = build, refresh = refresh, tick = tick,
	events = { "RESET", "FACTION" },
})
