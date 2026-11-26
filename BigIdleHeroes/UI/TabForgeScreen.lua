-- Forge screen (대장간).
--   left:   the forge level, then every function (융합 · 제작 · 보석 ·
--           마법부여 · 주문각인 · 강화 · 분해 · 재료; seals are rolled on
--           the materials' seal tab), a lock on
--           the ones not open yet.
--   middle: the chosen function (UI/TabForge.lua; the materials are
--           UI/TabBag.lua's), what it does on top; a locked one says what
--           opens it.
--   right:  what it works on - a hero, that hero's worn pieces and the bag's
--           (only the pieces the function can use) - and the latest results.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local GAP = 10
local MID_W = K.EQUIP_BODY_W + 24 -- the function views are EQUIP_BODY_W wide
local LIST_W = 140
local SIDE_W = K.W - LIST_W - MID_W - 2 * GAP
local MID_X = LIST_W + GAP
local SIDE_X = MID_X + MID_W + GAP
local FUNC_H, FUNC_STEP = 36, 41
local CELL = 38
local CELL_STEP = 42
local SIDE_COLS = 4
local BAG_ROWS = 3
local LOG_LINES = 6

-- op: the forge operation that unlocks it (none: always open, or 강화 with
-- the endless tower); target: works on a piece picked on the right
local FUNCS = {
	{ key = "smelt", name = "분해",       op = "smelt", desc = "장비를 골드와 대장간 경험치로 바꿉니다." },
	{ key = "fuse",  name = "융합",       op = "fuse",  desc = "같은 등급 장비 9개를 합쳐 장비 1개를 만듭니다." },
	{ key = "craft", name = "제작",       op = "craft", desc = "재료로 원하는 부위의 무작위 장비를 만듭니다." },
	{ key = "gem",   name = "보석",       op = "gem",   target = true, desc = "장비의 보석 홈에 무작위 능력치를 부여합니다." },
	{ key = "ench",  name = "마법부여",   op = "ench",  target = true, desc = "전설 등급 이상 장비의 마법 홈에 마법을 부여합니다." },
	{ key = "insc",  name = "주문각인",    op = "insc",  target = true, desc = "불멸 등급 이상 장비의 주문각인 홈에 주문서의 힘을 새깁니다." },
	{ key = "mats",  name = "재료",       desc = "재료를 모아 융합하거나 골드로 바꿉니다." },
	{ key = "up",    name = "강화",       target = true, desc = "골드로 장비의 기본 능력치를 +20까지 올립니다." },
}
local FUNC_BY = {}
for _, d in ipairs(FUNCS) do FUNC_BY[d.key] = d end
local ICON = { up = "INV_Hammer_09", smelt = "Spell_Fire_Fire", mats = "INV_Ingot_05" }

local function isOpen(key)
	if key == "up" then return ns.Upgrade.Open() end
	local d = FUNC_BY[key]
	return not d.op or ns.Forge.Unlocked(d.op)
end

------------------------------------------------------------------------
-- Left: the forge level and the functions
------------------------------------------------------------------------
local function buildLeft(page)
	local lp = UI.Panel(page, LIST_W, K.H, "inset")
	lp:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.left = lp
	page.level = UI.Text(lp, 14)
	page.level:SetPoint("TOPLEFT", lp, "TOPLEFT", 12, -12)
	UI.Color(page.level, UI.C.gold)
	page.forgeBar = UI.Bar(lp, LIST_W - 24, 14, 0.95, 0.55, 0.15)
	page.forgeBar:SetPoint("TOPLEFT", lp, "TOPLEFT", 12, -36)
	page.forgeBar.text:SetFont(ns.FONT, 10, "OUTLINE")
	page.forgeBar:EnableMouse(true)
	UI.Tip(page.forgeBar, function()
		local lines = { { "대장간 레벨", nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
			{ "장비를 분해·융합·제작하면 경험치가 오릅니다. 레벨이 오르면 새 기능과 제작 단계가 열립니다.", nil, 1, 1, 1, true } }
		for _, d in ipairs(ns.FORGE_OPS) do
			local open = ns.Forge.Unlocked(d.key)
			lines[#lines + 1] = { ns.N(d.name), open and "해금됨" or string.format("Lv %d · %s G", d.level, U.fmt(d.cost)),
				open and 0.4 or 0.75, open and 1 or 0.75, open and 0.45 or 0.8 }
		end
		lines[#lines + 1] = { "강화", ns.Upgrade.Open() and "해금됨" or string.format("%s 클리어", ns.N(ns.DIFFS[#ns.DIFFS - 1].name)),
			ns.Upgrade.Open() and 0.4 or 0.75, ns.Upgrade.Open() and 1 or 0.75, ns.Upgrade.Open() and 0.45 or 0.8 }
		return lines
	end, "TOP")
	-- the functions, one under the other (page.tabs: like a tab row)
	local tabs = { buttons = {} }
	page.tabs = tabs
	for i, d in ipairs(FUNCS) do
		local b = UI.Chip(lp, LIST_W - 20, FUNC_H, ns.N(d.name), function()
			page.func = d.key
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", lp, "TOPLEFT", 10, -62 - (i - 1) * FUNC_STEP)
		b.key = d.key
		b.isItem = true -- navigation, not an action
		b.dimOff = true -- the unchosen functions sit a little darker
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(22, 22)
		b.icon:SetPoint("LEFT", b, "LEFT", 8, 0)
		UI.SetArtOrIcon(b.icon, "forge_" .. d.key, ICON[d.key] or ns.ForgeView.OP_ICON[d.key])
		b.label:ClearAllPoints()
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label:SetJustifyH("CENTER")
		-- a locked function shows a lock where its icon is
		b.lock = UI.Glyph(b, "lock", 16, 0.95, 0.82, 0.5)
		b.lock:SetPoint("CENTER", b, "LEFT", 19, 0)
		b.lock:Hide()
		UI.Tip(b, function()
			local lines = { { ns.N(d.name), nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }, { d.desc, nil, 1, 1, 1, true } }
			if not isOpen(d.key) then
				if d.key == "up" then
					lines[#lines + 1] = { ns.Upgrade.LOCKED_TEXT, nil, 1, 0.5, 0.3 }
				else
					local op = ns.Forge.OpDef(d.op)
					lines[#lines + 1] = { string.format("대장간 %d레벨 · 해금 %s G", op.level, U.fmt(op.cost)), nil, 1, 0.5, 0.3 }
				end
			end
			return lines
		end, "RIGHT")
		tabs.buttons[i] = b
	end
	function tabs:Get(key) for _, b in ipairs(self.buttons) do if b.key == key then return b end end end
	function tabs:Select(key)
		for _, b in ipairs(self.buttons) do
			b:SetOn(b.key == key)
			-- the white icons: dark on the chosen (gold) one, light on the rest
			if b.icon.isArt then
				if b.key == key then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(0.74, 0.77, 0.85) end
			end
		end
	end
	function tabs:SetLocked(key, v)
		local b = self:Get(key)
		if b then
			b.lock:SetShown(v and true or false)
			b.icon:SetShown(not v)
			-- a locked function: its lock as faint as its name
			b.label:SetAlpha(v and 0.6 or 1)
			b.lock:SetAlpha(v and 0.6 or 1)
		end
	end
	function tabs:SetBadge(key, v) local b = self:Get(key) if b then b:SetBadge(v) end end
end

local function refreshLeft(page)
	local f = ns.db.forge
	page.level:SetText(string.format("대장간 Lv %d", f.level))
	if f.level >= ns.FORGE_MAX then
		page.forgeBar:SetValue(1)
		page.forgeBar:SetLabel("최고 레벨")
	else
		local need = ns.Forge.Need(f.level)
		page.forgeBar:SetValue(f.xp / need)
		page.forgeBar:SetLabel(string.format("%s / %s", U.fmt(f.xp), U.fmt(need)))
	end
	page.tabs:Select(page.func)
	for _, d in ipairs(FUNCS) do
		local open = isOpen(d.key)
		page.tabs:SetLocked(d.key, not open)
		-- a red dot: a function that can be unlocked now
		local op = d.op and ns.Forge.OpDef(d.op)
		page.tabs:SetBadge(d.key, not open and op and f.level >= op.level and ns.CanAfford(op.cost) and ns.Guide.UnlockUseful(d.op) or false)
	end
	-- 인장 굴리기 is on the materials' seal tab
	local sl = ns.Forge.OpDef("seal")
	if not ns.Forge.Unlocked("seal") and f.level >= sl.level and ns.CanAfford(sl.cost) and ns.Guide.UnlockUseful("seal") then
		page.tabs:SetBadge("mats", true)
	end
	-- 추출 sits on the gem sockets' lines
	local rm = ns.Forge.OpDef("remove")
	if ns.Forge.Unlocked("gem") and not ns.Forge.Unlocked("remove") and f.level >= rm.level and ns.CanAfford(rm.cost) and ns.Guide.UnlockUseful("remove") then
		page.tabs:SetBadge("gem", true)
	end
end

------------------------------------------------------------------------
-- Middle: the chosen function
------------------------------------------------------------------------
local function buildMiddle(page)
	local mp = UI.Panel(page, MID_W, K.H, "inset")
	mp:SetPoint("TOPLEFT", page, "TOPLEFT", MID_X, 0)
	page.mid = mp
	page.title = UI.Text(mp, 15)
	page.title:SetPoint("TOPLEFT", mp, "TOPLEFT", 12, -12)
	UI.Color(page.title, UI.C.gold)
	page.desc = UI.Text(mp, 11)
	page.desc:SetPoint("TOPLEFT", mp, "TOPLEFT", 12, -34)
	page.desc:SetWidth(MID_W - 24)
	page.desc:SetWordWrap(false)
	UI.Color(page.desc, UI.C.sub)
	page.bodies = {}
	local function body(key)
		local f = CreateFrame("Frame", nil, mp)
		f:SetSize(MID_W - 24, ns.ForgeView.H)
		f:SetPoint("TOPLEFT", mp, "TOPLEFT", 12, -60)
		page.bodies[key] = f
		return f
	end
	page.forge = {}
	for _, key in ipairs({ "fuse", "craft", "gem", "ench", "insc", "up", "smelt" }) do
		page.forge[key] = ns.ForgeView.Build[key](page, body(key))
	end
	ns.MatsView.Build(page, body("mats"))
	page.lockView = ns.ForgeView.Build.locked(page, body("locked"))
end

------------------------------------------------------------------------
-- Right: what the function works on, and the latest results
------------------------------------------------------------------------
local function buildSide(page)
	local sp = UI.Panel(page, SIDE_W, K.H, "inset")
	sp:SetPoint("TOPLEFT", page, "TOPLEFT", SIDE_X, 0)
	page.side = sp
	page.sideHead = UI.Section(sp, SIDE_W - 20, "대상")
	page.sideHead:SetPoint("TOPLEFT", sp, "TOPLEFT", 10, -10)
	-- every hero (small portraits); the chosen one's worn pieces under it
	page.strip = UI.HeroStrip(sp, ns.ROSTER_MAX, 24, 4, function(id)
		Main.SelectHero(id)
		Main.Refresh()
	end, nil, 6)
	page.strip:SetPoint("TOPLEFT", sp, "TOPLEFT", 10, -36)
	local function grid(n, y)
		local out = {}
		for i = 1, n do
			local b = UI.IconButton(sp, CELL, function(self, button)
				if not self.data then return end
				-- on 분해, right-click breaks a bag piece down (after asking)
				if button == "RightButton" and page.func == "smelt" and not self.heroId then
					ns.BagView.SmeltOne(self.data)
					return
				end
				ns.ForgeView.SetTarget(self.data, self.heroId)
				Main.Refresh()
			end)
			b:SetPoint("TOPLEFT", sp, "TOPLEFT", 10 + ((i - 1) % SIDE_COLS) * CELL_STEP, y - floor((i - 1) / SIDE_COLS) * CELL_STEP)
			UI.Tip(b, function(self)
				if not self.data then return nil end
				local lines = ns.Items.Tooltip(self.data, Main.SelectedHero())
				if page.func == "smelt" and not self.heroId then lines[#lines + 1] = { "우클릭: 분해", nil, 0.45, 0.8, 1 } end
				return lines
			end, "TOP")
			out[i] = b
		end
		return out
	end
	page.wornHead = UI.Text(sp, 11, "착용 중")
	page.wornHead:SetPoint("TOPLEFT", sp, "TOPLEFT", 10, -98)
	UI.Color(page.wornHead, UI.C.sub)
	page.worn = grid(#ns.SLOTS, -114)
	local bagY = -114 - 3 * CELL_STEP - 18
	page.bagHead = UI.Text(sp, 11, "가방")
	page.bagHead:SetPoint("TOPLEFT", sp, "TOPLEFT", 10, bagY + 20)
	UI.Color(page.bagHead, UI.C.sub)
	page.bagCells = grid(SIDE_COLS * BAG_ROWS, bagY)
	page.bagPrev = UI.PageButton(sp, 24, 20, "left", function() page.sidePage = (page.sidePage or 1) - 1 Main.Refresh() end)
	page.bagNext = UI.PageButton(sp, 24, 20, "right", function() page.sidePage = (page.sidePage or 1) + 1 Main.Refresh() end)
	page.bagNext:SetPoint("TOPRIGHT", sp, "TOPRIGHT", -10, bagY + 24)
	page.bagPrev:SetPoint("RIGHT", page.bagNext, "LEFT", -4, 0)
	page.bagPage = UI.Text(sp, 10)
	page.bagPage:SetPoint("RIGHT", page.bagPrev, "LEFT", -6, 0)
	UI.Color(page.bagPage, UI.C.dim)
	page.sideHint = UI.Text(sp, 11)
	page.sideHint:SetPoint("TOPLEFT", sp, "TOPLEFT", 10, -40)
	page.sideHint:SetWidth(SIDE_W - 20)
	page.sideHint:SetJustifyV("TOP")
	UI.Color(page.sideHint, UI.C.dim)
	-- the latest results
	page.logHead = UI.Section(sp, SIDE_W - 20, "최근 결과")
	page.logHead:SetPoint("BOTTOMLEFT", sp, "BOTTOMLEFT", 10, 10 + LOG_LINES * 17 + 6)
	page.logLines = {}
	for i = 1, LOG_LINES do
		local l = UI.Text(sp, 10)
		l:SetPoint("BOTTOMLEFT", sp, "BOTTOMLEFT", 10, 10 + (LOG_LINES - i) * 17)
		l:SetWidth(SIDE_W - 20)
		l:SetWordWrap(false)
		page.logLines[i] = l
	end
end

local function fill(b, it, heroId)
	b:Clear()
	b.data, b.heroId = it, heroId
	if it then
		b:SetIconName(ns.Items.Icon(it))
		b:SetQuality(it.q)
		b:SetItemMarks(it)
		b:SetLocked(it.lock)
		local t = ns.ForgeView.Target()
		b:SetSelected(t == it)
	end
end

local function refreshSide(page)
	local d = FUNC_BY[page.func]
	local view = page.forge[page.func]
	local targeted = d.target and isOpen(d.key) and view ~= nil
	for _, w in ipairs({ page.strip, page.wornHead, page.bagHead, page.bagPrev, page.bagNext, page.bagPage }) do w:SetShown(targeted) end
	for _, b in ipairs(page.worn) do b:SetShown(targeted) end
	for _, b in ipairs(page.bagCells) do b:SetShown(targeted) end
	page.sideHint:SetShown(not targeted)
	local log = ns.ForgeView.log
	for i, l in ipairs(page.logLines) do l:SetText(log[i] or (i == 1 and U.col("8a90a2", "아직 없습니다.") or "")) end
	if not targeted then
		page.sideHint:SetText(d.target and "기능이 열리면 여기서 장비를 고릅니다." or "이 기능은 가방의 장비와 재료를 씁니다.")
		return
	end
	local accepts = view.accepts
	local id = Main.SelectedHero()
	page.strip:Set(UI.HeroOrder(), id)
	-- the hero's pieces in slot order; the bag's that the function can use,
	-- the furthest along and best first
	local worn = {}
	if id then
		for _, slot in ipairs(ns.SLOTS) do
			local it = ns.db.heroes[id].gear[slot]
			if it and accepts(it) then worn[#worn + 1] = it end
		end
	end
	local bag = {}
	for _, it in ipairs(ns.db.bag) do if accepts(it) then bag[#bag + 1] = it end end
	table.sort(bag, function(a, b)
		local ua, ub = ns.Upgrade.Level(a), ns.Upgrade.Level(b)
		if ua ~= ub then return ua > ub end
		if a.q ~= b.q then return a.q > b.q end
		return a.l > b.l
	end)
	-- the target stays while it is one of the pieces shown (the selected
	-- hero's or the bag's) and can be used; else the first piece there is
	local t = ns.ForgeView.Target()
	local shown = false
	for _, it in ipairs(worn) do if it == t then shown = true end end
	for _, it in ipairs(bag) do if it == t then shown = true end end
	if not (t and shown and accepts(t)) then
		if worn[1] then ns.ForgeView.SetTarget(worn[1], id) elseif bag[1] then ns.ForgeView.SetTarget(bag[1], nil) else ns.ForgeView.SetTarget(nil, nil) end
	end
	for i, b in ipairs(page.worn) do
		fill(b, worn[i], id)
		b:SetShown(worn[i] ~= nil) -- only the pieces there are
	end
	local per = SIDE_COLS * BAG_ROWS
	local pages = max(1, math.ceil(#bag / per))
	page.sidePage = U.clamp(page.sidePage or 1, 1, pages)
	for i, b in ipairs(page.bagCells) do fill(b, bag[(page.sidePage - 1) * per + i], nil) end
	page.bagPage:SetText(string.format("%d/%d", page.sidePage, pages))
	page.bagPrev:SetOff(page.sidePage <= 1)
	page.bagNext:SetOff(page.sidePage >= pages)
	page.wornHead:SetText(#worn > 0 and "착용 중" or "착용 중 (쓸 수 있는 장비 없음)")
	page.bagHead:SetText(string.format("가방 %d개", #bag))
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.func = FUNCS[1].key -- the top of the list (분해)
	buildLeft(page)
	buildMiddle(page)
	buildSide(page)
end

local refresh
function refresh(page)
	local d = FUNC_BY[page.func] or FUNCS[1]
	page.func = d.key
	refreshLeft(page)
	-- the side first: it settles the piece the function works on
	refreshSide(page)
	page.title:SetText(ns.N(d.name))
	page.desc:SetText(d.desc)
	for _, b in pairs(page.bodies) do b:Hide() end
	if not isOpen(d.key) then
		page.bodies.locked:Show()
		page.lockView.refresh(d.key == "up" and "up" or d.op)
	elseif d.key == "mats" then
		page.bodies.mats:Show()
		ns.MatsView.Refresh(page)
	else
		page.bodies[d.key]:Show()
		page.forge[d.key].refresh()
	end
	page.lastFunc = d.key
	refreshSide(page)
end

-- opts.sub: a function ("fuse", "gem", "up", "mats" …; "remove" opens 보석,
-- "seal" the materials on the seals); opts.tab: a materials tab
local OLD_SUB = { remove = "gem", seal = "mats" }
local function open(page, opts)
	if not opts then return end
	if opts.sub == "seal" and not opts.tab then opts.tab = "mat_seal" end
	local sub = OLD_SUB[opts.sub] or opts.sub
	if opts.tab and ns.MatsView.KINDS_OF[opts.tab] then sub = "mats" end
	if sub and FUNC_BY[sub] then page.func = sub end
	ns.MatsView.Open(page, opts)
	if opts.hero then Main.SelectHero(opts.hero) end
end

Main.RegisterTab({
	key = "forge", title = "대장간", sub = "융합, 제작, 보석, 분해, 재료, 강화", art = "icon_forge",
	icon = "Trade_BlackSmithing", build = build, refresh = refresh, open = open,
	events = { "HEROES", "PARTY", "LEVEL", "GEAR", "BAG", "MATS", "STATS", "FORGE", "RESET", "PROGRESS" },
	gold = true,
})
