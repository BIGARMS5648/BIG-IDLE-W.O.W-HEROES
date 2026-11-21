-- The bag, the storage and the materials: tabs of the equipment screen
-- (UI/TabEquip.lua).
--   가방: "가방 43 / 70" [상자 열기] [보기 ▾] [정리], the grid (pages of 60),
--         and at the bottom: 분해 등급 [▾] [일괄 분해] [자동 분해].
--         On an item: click = 장착 (the hero on the left), right-click =
--         분해, Alt+click = 보호, Shift+click = 창고.
--   창고: the same grid over the storage (db.bank): "창고 3 / 20" [정리];
--         click = back to the bag.
--   재료: one tab per kind of material; a row per material with fusing
--         (9 → 1), breaking down for gold, and for the seals a bonus roll.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local K = UI.K

local BagView, MatsView = {}, {}
ns.BagView, ns.MatsView = BagView, MatsView

------------------------------------------------------------------------
-- Forge functions are unlocked where they are used: the button that needs
-- one says "… 해금 N G" (or the forge level it waits for) and unlocks it.
------------------------------------------------------------------------
local Unlock = {}
ns.ForgeUnlock = Unlock

-- label, off, style for a button whose function is still locked
function Unlock.Label(op, verb)
	local d = ns.Forge.OpDef(op)
	if ns.db.forge.level < d.level then
		return string.format("용광로 Lv %d 필요", d.level), true, "dark"
	end
	return string.format("%s 해금 %s G", verb, U.fmt(d.cost)), not ns.CanAfford(d.cost), "primary"
end

-- asks, then unlocks
function Unlock.Ask(op)
	local d = ns.Forge.OpDef(op)
	if ns.db.forge.level < d.level then
		UI.Try(false, string.format("'%s'은(는) 용광로 Lv %d에 열립니다. 장비를 융합·제작·분해하면 용광로 레벨이 오릅니다.", ns.N(d.name), d.level))
		return
	end
	if not ns.CanAfford(d.cost) then
		UI.Try(false, string.format("'%s' 해금에 %s 골드가 필요합니다.", ns.N(d.name), U.fmt(d.cost)))
		return
	end
	UI.Confirm({ title = ns.N(d.name) .. " 해금", ok = "해금", style = "primary",
		text = string.format("용광로의 '%s'을(를) 해금하시겠습니까?\n%s\n%s 골드가 듭니다.", ns.N(d.name), ns.N(d.desc), U.fmt(d.cost)),
		onOk = function()
			if UI.Try(ns.Forge.Unlock(op)) then ns.Toast(string.format("'%s'을(를) 해금했습니다.", ns.N(d.name))) end
		end })
end

-- the tooltip line for a locked function
function Unlock.Tip(op)
	local d = ns.Forge.OpDef(op)
	return string.format("아직 잠겨 있습니다: 용광로 Lv %d · 해금 %s G", d.level, U.fmt(d.cost))
end

local W = 526 -- body width
local COLS, ROWS, CELL, STEP = 10, 6, 46, 52
local PER_PAGE = COLS * ROWS
local GRID_Y = -38

local VIEWS = {
	{ "all", "전체" }, { "weapon", "무기" }, { "armor", "방어구" }, { "acc", "액세서리" },
}
local SLOTS_OF = {
	weapon = { mh = true, oh = true },
	armor = { head = true, chest = true, hands = true, feet = true },
	acc = { wrist = true, neck = true, ring = true, trinket = true },
}

local function smeltQ() return U.clamp(ns.db.ui.smeltQ or 2, 1, ns.MAX_QUALITY) end
local function autoSmeltOn() return (ns.db.opt.autoSmelt or 0) > 0 end
local function indexIn(list, it)
	for i = 1, #list do if list[i] == it then return i end end
end

-- the 창고 tab shows the storage in the bag's grid
local function isBank(page) return page.tab == "bank" end
local function pageKey(page) return isBank(page) and "bankPage" or "bagPage" end

-- the items a view shows: a group or one slot (a key of ns.SLOT); the storage
-- shows everything
local function itemList(view, bank)
	if bank then return ns.db.bank end
	local src = ns.db.bag
	local f = SLOTS_OF[view] or (ns.SLOT[view] and { [view] = true })
	if not f then return src end
	local out = {}
	for _, it in ipairs(src) do
		if f[it.s] then out[#out + 1] = it end
	end
	return out
end

-- Breaks one item down after asking.
local function smeltOne(it)
	if it.lock then
		UI.Try(false, "보호된 장비는 분해할 수 없습니다. 먼저 보호를 푸세요 (Alt+클릭).")
		return
	elseif not ns.Forge.Unlocked("smelt") then
		UI.Try(false, "분해가 아직 잠겨 있습니다. 가방 아래의 [분해 해금]을 누르세요.")
		return
	end
	local text = string.format("%s을(를) 분해하시겠습니까?\n%s 골드를 받습니다.", ns.Items.ColorName(it), U.fmt(ns.Items.SmeltGold(it)))
	if ns.Items.PartyUpgrade(it) then
		text = text .. "\n" .. U.col("ff9a7a", "파티에게 지금 장비보다 더 좋은 장비입니다.")
	end
	UI.Confirm({ title = "분해", ok = "분해", style = "red", text = text, onOk = function()
		local ok, g = ns.Forge.Smelt({ it })
		if UI.Try(ok, g) then ns.Toast(string.format("분해: +%s 골드", U.fmt(g))) end
	end })
end
BagView.SmeltOne = smeltOne

------------------------------------------------------------------------
-- 가방
------------------------------------------------------------------------
function BagView.Build(page, f)
	page.view = page.view or "all"
	page.bagPage, page.bankPage = 1, 1
	page.bagCount = UI.Text(f, 13)
	page.bagCount:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -7)
	page.bagCount:SetWidth(120)
	page.bagCount:SetWordWrap(false)
	page.open = UI.Button(f, 120, 28, "", function()
		ns.Loot.OpenAll()
		Main.Refresh()
	end, "blue")
	page.open:SetPoint("TOPLEFT", f, "TOPLEFT", 126, 0)
	page.open.clickWhenOff = true
	UI.Tip(page.open, function() return UI.SimpleTip("상자 모두 열기", "쌓인 상자를 모두 엽니다. 가방이 차면 남은 상자는 그대로 둡니다.") end, "TOP")
	page.viewPick = UI.Dropdown(f, 136, 28, function()
		local out = {}
		for _, v in ipairs(VIEWS) do out[#out + 1] = { v[1], v[2] } end
		if ns.SLOT[page.view] then out[#out + 1] = { page.view, ns.N(ns.SLOT[page.view].name) .. " 장비" } end
		return out
	end, function() return page.view end, function(v)
		page.view = v
		page.bagPage = 1
	end, "보기: ")
	page.viewPick:SetPoint("TOPLEFT", f, "TOPLEFT", 254, 0)
	page.viewPick.tipTitle = "보기"
	page.viewPick.tipText = "가방의 장비를 종류별로 봅니다. 왼쪽의 장비 칸을 누르면 그 부위만 봅니다."
	page.sort = UI.Button(f, 64, 28, "정리", function()
		ns.Items.Sort(isBank(page) and ns.db.bank or ns.db.bag)
		Main.Refresh()
	end, "dark")
	page.sort:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	UI.Tip(page.sort, function() return UI.SimpleTip("정리", "등급과 레벨 순으로 다시 놓습니다.") end, "TOP")

	page.cells = {}
	for i = 1, PER_PAGE do
		local b = UI.IconButton(f, CELL, function(self, button)
			local it = self.data
			if not it then return end
			local id = Main.SelectedHero()
			if isBank(page) then
				local idx = indexIn(ns.db.bank, it)
				if idx then UI.Try(ns.Items.FromBank(idx)) end
			elseif IsAltKeyDown and IsAltKeyDown() then
				ns.Items.ToggleLock(it)
			elseif IsShiftKeyDown and IsShiftKeyDown() then
				local idx = indexIn(ns.db.bag, it)
				if idx then UI.Try(ns.Items.ToBank(idx)) end
			elseif button == "RightButton" then
				smeltOne(it)
			elseif id then
				local idx = indexIn(ns.db.bag, it)
				if idx then UI.Try(ns.Items.Equip(id, idx)) end
			else
				UI.Try(false, "장착할 영웅이 없습니다.")
			end
			Main.Refresh()
		end)
		local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * STEP, GRID_Y - row * STEP)
		UI.Tip(b, function(self)
			local it = self.data
			if not it then return nil end
			local id = Main.SelectedHero()
			local lines = ns.Items.Tooltip(it, id)
			if isBank(page) then
				lines[#lines + 1] = { "클릭: 가방으로 꺼내기", nil, 0.45, 0.8, 1 }
			else
				lines[#lines + 1] = { "클릭: 장착 · 오른쪽 클릭: 분해", nil, 0.45, 0.8, 1 }
				lines[#lines + 1] = { "Alt+클릭: 보호 · Shift+클릭: 창고에 보관", nil, 0.45, 0.8, 1 }
			end
			return lines
		end)
		page.cells[i] = b
	end
	page.empty = UI.Text(f, 13)
	page.empty:SetPoint("TOP", f, "TOP", 0, GRID_Y - 140)
	page.empty:SetWidth(W - 40)
	page.empty:SetJustifyH("CENTER")
	UI.Color(page.empty, UI.C.sub)
	-- pages
	page.prev = UI.Button(f, 30, 24, "<", function() local k = pageKey(page) page[k] = page[k] - 1 Main.Refresh() end, "dark")
	page.next = UI.Button(f, 30, 24, ">", function() local k = pageKey(page) page[k] = page[k] + 1 Main.Refresh() end, "dark")
	page.pageText = UI.Text(f, 12)
	page.pageText:SetPoint("TOP", f, "TOP", 0, GRID_Y - ROWS * STEP - 8)
	page.pageText:SetJustifyH("CENTER")
	page.prev:SetPoint("RIGHT", page.pageText, "LEFT", -12, 0)
	page.next:SetPoint("LEFT", page.pageText, "RIGHT", 12, 0)
	page.hint = UI.Text(f, 11, "")
	page.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 0, GRID_Y - ROWS * STEP - 42)
	page.hint:SetWidth(W)
	UI.Color(page.hint, UI.C.dim)

	-- breaking down: the grade, now, or by itself when the bag is full
	page.smeltLabel = UI.Text(f, 12, "분해 등급")
	page.smeltLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 10)
	page.smeltPick = UI.Dropdown(f, 136, 32, function()
		local out = {}
		for q = 1, ns.MAX_QUALITY do out[#out + 1] = { q, U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name)) .. " 이하" } end
		return out
	end, smeltQ, function(q)
		ns.db.ui.smeltQ = q
		if autoSmeltOn() then ns.db.opt.autoSmelt = q end
	end, "")
	page.smeltPick:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 72, 0)
	page.smeltPick.openUp = true
	page.smeltPick.tipTitle = "분해 등급"
	page.smeltPick.tipText = "일괄 분해와 자동 분해가 이 등급 이하의 장비만 분해합니다."
	page.smeltGo = UI.Button(f, 150, 32, "", function()
		if not ns.Forge.Unlocked("smelt") then
			Unlock.Ask("smelt")
			return
		end
		local picked, kept = ns.Forge.PickByQuality(smeltQ())
		if #picked == 0 then
			UI.Try(false, "분해 등급 이하인 장비가 없습니다. 등급을 올려 보세요.")
			return
		end
		local total = 0
		for _, it in ipairs(picked) do total = total + ns.Items.SmeltGold(it) end
		local q = ns.QUALITY[smeltQ()]
		UI.Confirm({ title = "일괄 분해", ok = "분해", style = "red",
			text = string.format("%s 이하의 장비 %d개를 분해하시겠습니까?\n%s 골드를 받습니다. 보호한 장비, 보석·마법부여·각인이 붙은 장비, 파티에게 더 좋은 장비%s는 남깁니다.",
				U.col(q.hex, ns.N(q.name)), #picked, U.fmt(total), kept > 0 and string.format("(%d개)", kept) or ""),
			onOk = function()
				local ok, gold, n = ns.Forge.Smelt(picked)
				if UI.Try(ok, gold) then ns.Toast(string.format("%d개 분해: +%s 골드", n, U.fmt(gold))) end
			end })
	end, "red")
	page.smeltGo:SetPoint("LEFT", page.smeltPick, "RIGHT", 8, 0)
	page.smeltGo.clickWhenOff = true
	UI.Tip(page.smeltGo, function()
		local picked, kept = ns.Forge.PickByQuality(smeltQ())
		local total = 0
		for _, it in ipairs(picked) do total = total + ns.Items.SmeltGold(it) end
		local body = string.format("분해 등급 이하의 장비 %d개를 골드로 바꿉니다 (+%s 골드). 보호한 장비, 보석·마법부여·각인이 붙은 장비, 파티에게 더 좋은 장비는 남깁니다.", #picked, U.fmt(total))
		if kept > 0 then body = body .. string.format("\n(파티에게 더 좋은 장비 %d개는 남김)", kept) end
		return UI.SimpleTip("일괄 분해", body)
	end, "TOP")
	page.autoSmelt = UI.Check(f, "자동 분해", autoSmeltOn, function(v)
		if v and not ns.Forge.Unlocked("smelt") then
			UI.Try(false, "분해가 아직 잠겨 있습니다. 왼쪽의 [분해 해금]을 먼저 누르세요.")
			return
		end
		ns.db.opt.autoSmelt = v and smeltQ() or 0
		ns.Toast(v and "자동 분해를 켰습니다." or "자동 분해를 껐습니다.")
	end)
	page.autoSmelt:SetPoint("LEFT", page.smeltGo, "RIGHT", 16, 0)
	UI.Tip(page.autoSmelt, function()
		local q = ns.QUALITY[smeltQ()]
		return UI.SimpleTip("자동 분해", string.format("켜 두면 가방이 가득 찰 때 %s 이하의 장비를 저절로 분해해 자리를 만듭니다. 보호한 장비, 보석·마법부여·각인이 붙은 장비, 파티에게 더 좋은 장비는 남깁니다.", U.col(q.hex, ns.N(q.name))))
	end, "TOP")
end

function BagView.Refresh(page)
	local db = ns.db
	local bank = isBank(page)
	local list = itemList(page.view, bank)
	local cap = bank and ns.BankSize() or ns.BagSize()
	page.bagCount:SetText(string.format("%s  %s", bank and "창고" or "가방",
		U.col("aab3c8", string.format("%d / %d", bank and #db.bank or #db.bag, cap))))
	local chests = ns.Loot.Count()
	page.open:SetLabel(string.format("상자 열기 (%d)", chests))
	page.open:SetOff(chests == 0)
	page.open:SetBadge(chests > 0 and chests or nil)
	page.open:SetShown(not bank)
	page.viewPick:Refresh()
	page.viewPick:SetShown(not bank)
	local filtered = page.view ~= "all" and not bank
	local shown = filtered and #list or max(cap, #list)
	local pages = max(1, math.ceil(shown / PER_PAGE))
	local key = pageKey(page)
	page[key] = U.clamp(page[key] or 1, 1, pages)
	local cur = page[key]
	local first = (cur - 1) * PER_PAGE
	local sel = Main.SelectedHero()
	for i, b in ipairs(page.cells) do
		local n = first + i
		local it = list[n]
		b:Clear()
		b:SetShown(n <= shown or (filtered and i <= COLS))
		if it then
			b.data = it
			b:SetIconName(ns.Items.Icon(it))
			b:SetQuality(it.q)
			b:SetCount(tostring(it.l))
			b:SetLocked(it.lock)
			if not bank and sel then
				local usable = ns.Items.CanEquip(sel, it)
				b:SetDim(not usable)
				if usable then
					local r = ns.Items.Compare(sel, it)
					if r and r > 1.01 then b:SetMark("+", 0.4, 1, 0.45) end
				end
			end
		end
	end
	local empty
	if #list == 0 then
		empty = bank and "창고가 비어 있습니다. 가방에서 Shift+클릭으로 보관합니다."
			or (filtered and "이 종류의 장비가 없습니다." or "가방이 비어 있습니다. 상자를 열어 장비를 얻으세요.")
	end
	page.empty:SetText(empty or "")
	page.empty:SetShown(empty ~= nil)
	-- under the last row of slots on this page
	local rows = min(ROWS, max(1, math.ceil(max(shown - first, filtered and COLS or 0) / COLS)))
	page.empty:ClearAllPoints()
	page.empty:SetPoint("TOP", page.empty:GetParent(), "TOP", 0, GRID_Y - rows * STEP - 14)
	page.pageText:SetText(string.format("%d / %d", cur, pages))
	page.pageText:SetShown(pages > 1)
	page.prev:SetShown(pages > 1)
	page.next:SetShown(pages > 1)
	page.prev:SetOff(cur <= 1)
	page.next:SetOff(cur >= pages)
	page.hint:SetText(bank and "클릭: 가방으로 꺼내기" or "클릭: 장착 · 오른쪽 클릭: 분해 · Alt+클릭: 보호 · Shift+클릭: 창고에 보관")
	-- breaking down
	local unlocked = ns.Forge.Unlocked("smelt")
	page.smeltPick:Refresh()
	if unlocked then
		local picked = ns.Forge.PickByQuality(smeltQ())
		page.smeltGo:SetStyle("red")
		page.smeltGo:SetLabel(string.format("일괄 분해 %d개", #picked))
		page.smeltGo:SetOff(#picked == 0)
	else
		local label, off, style = Unlock.Label("smelt", "분해")
		page.smeltGo:SetStyle(style)
		page.smeltGo:SetLabel(label)
		page.smeltGo:SetOff(off)
	end
	page.autoSmelt:Refresh()
	for _, w in ipairs({ page.smeltLabel, page.smeltPick, page.smeltGo, page.autoSmelt }) do w:SetShown(not bank) end
end

-- opts.slot: show that slot's items; opts.view: a view of the bag
function BagView.Open(page, opts)
	if not opts then return end
	if opts.view then page.view = opts.view page.bagPage = 1 end
	if opts.slot and ns.SLOT[opts.slot] then page.view = opts.slot page.bagPage = 1 end
end

------------------------------------------------------------------------
-- 재료
------------------------------------------------------------------------
local MAT_TABS = {
	{ "mat_craft", "제작 재료" }, { "mat_gem", "보석 세공 재료" }, { "mat_ench", "마법부여 재료" },
	{ "mat_insc", "룬 각인 재료" }, { "mat_seal", "행운의 인장 재료" },
}
local MAT_KINDS_OF = {
	mat_craft = { bar = true, leather = true, cloth = true },
	mat_gem = { gem = true }, mat_ench = { dust = true }, mat_insc = { scroll = true }, mat_seal = { seal = true },
}
local MAT_USE = {
	mat_craft = "장비 '제작'에 씁니다", mat_gem = "장비 '보석'에 씁니다", mat_ench = "장비 '마법부여'에 씁니다",
	mat_insc = "장비 '각인'에 씁니다", mat_seal = "[굴리기]로 장비 1개",
}
MatsView.KINDS_OF = MAT_KINDS_OF
local ROW_H, ROW_STEP, LIST_Y, MAT_ROWS = 54, 58, -70, 6

local function sealIndex(id)
	for i, s in ipairs(ns.SEAL) do if s.mat == id then return i end end
end

function MatsView.Build(page, f)
	page.matTab = page.matTab or "mat_craft"
	page.matPage = 1
	page.matTabs = UI.Tabs(f, W, MAT_TABS, function(key)
		page.matTab = key
		page.matPage = 1
		Main.Refresh()
	end, true, 28)
	page.matTabs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	page.matNote = UI.Text(f, 11)
	page.matNote:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
	page.matNote:SetWidth(W - 130)
	page.matNote:SetWordWrap(false)
	UI.Color(page.matNote, UI.C.sub)
	page.autoFuse = UI.Button(f, 120, 26, "재료 자동 융합", function()
		local kinds = MAT_KINDS_OF[page.matTab]
		local n = ns.Forge.MatFusionsReady(kinds)
		if n == 0 then UI.Try(false, string.format("같은 재료가 %d개 이상 모인 것이 없습니다.", ns.Forge.FUSE_COUNT)) return end
		local name = ""
		for _, t in ipairs(MAT_TABS) do if t[1] == page.matTab then name = t[2] end end
		UI.Confirm({ title = "재료 자동 융합", ok = "융합", style = "primary",
			text = string.format("%s를 자동으로 융합하시겠습니까?\n같은 재료가 %d개 이상이면 다음 단계 1개로 합칩니다(약 %d번).", name, ns.Forge.FUSE_COUNT, n),
			onOk = function() ns.Toast(string.format("%s 융합 %d번", name, ns.Forge.FuseAllMats(kinds))) end })
	end, "primary")
	page.autoFuse:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -34)
	page.autoFuse.clickWhenOff = true
	page.matRows = {}
	for i = 1, MAT_ROWS do
		local r = UI.Panel(f, W, ROW_H, "card")
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, LIST_Y - (i - 1) * ROW_STEP)
		r.icon = UI.IconButton(r, 40)
		r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
		UI.Tip(r.icon, function(self) return self.data and ns.Items.MatTooltip(self.data) or nil end)
		r.name = UI.Text(r, 13)
		r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 58, -9)
		r.name:SetWidth(190)
		r.name:SetWordWrap(false)
		r.sub = UI.Text(r, 11)
		r.sub:SetPoint("TOPLEFT", r, "TOPLEFT", 58, -30)
		r.sub:SetWidth(190)
		r.sub:SetWordWrap(false)
		UI.Color(r.sub, UI.C.sub)
		r.smelt = UI.Button(r, 92, 26, "모두 분해", function()
			if not ns.Forge.Unlocked("smelt") then Unlock.Ask("smelt") return end
			local id = r.id
			local count = ns.MatCount(id)
			if count <= 0 then UI.Try(false, "분해할 재료가 없습니다.") return end
			UI.Confirm({ title = "재료 분해", ok = "분해", style = "red",
				text = string.format("%s %s개를 모두 분해하시겠습니까?\n%s 골드를 받습니다.", ns.N(ns.MATS[id].name), U.fmt(count), U.fmt(ns.Forge.MatSmeltGold(id, count))),
				onOk = function() UI.Try(ns.Forge.SmeltMat(id, ns.MatCount(id))) end })
		end, "red")
		r.smelt:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -7)
		r.smelt.clickWhenOff = true
		r.price = UI.Text(r, 11)
		r.price:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -37)
		r.price:SetJustifyH("RIGHT")
		UI.Color(r.price, UI.C.sub)
		r.all = UI.Button(r, 56, 26, "모두", function()
			local k = 0
			while ns.MatCount(r.id) >= ns.Forge.FUSE_COUNT do
				if not ns.Forge.FuseMat(r.id) then break end
				k = k + 1
			end
			if k > 0 then ns.Toast(string.format("%s 융합 %d번", ns.N(ns.MATS[r.id].name), k)) end
			Main.Refresh()
		end, "dark")
		r.all:SetPoint("RIGHT", r.smelt, "LEFT", -10, 0)
		r.all.clickWhenOff = true
		r.one = UI.Button(r, 56, 26, "1회", function()
			local ok, res = ns.Forge.FuseMat(r.id)
			if UI.Try(ok, res) then ns.Toast(string.format("융합 성공: %s", ns.N(ns.MATS[res].name))) end
			Main.Refresh()
		end, "blue")
		r.one:SetPoint("RIGHT", r.all, "LEFT", -6, 0)
		r.one.clickWhenOff = true
		-- seals: a bonus roll instead of fusing
		r.roll = UI.Button(r, 118, 26, "", function()
			if not ns.Forge.Unlocked("seal") then Unlock.Ask("seal") return end
			local si = sealIndex(r.id)
			local ok, it = ns.Forge.BonusRoll(si)
			if UI.Try(ok, it) then ns.Toast("굴림 결과: " .. ns.Items.ColorName(it)) end
			Main.Refresh()
		end, "primary")
		r.roll:SetPoint("RIGHT", r.smelt, "LEFT", -10, 0)
		r.roll.clickWhenOff = true
		UI.Tip(r.roll, function()
			local s = ns.SEAL[sealIndex(r.id) or 1]
			local parts = {}
			for q = 1, ns.MAX_QUALITY do
				if (s.q[q] or 0) > 0 then parts[#parts + 1] = U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name) .. " " .. s.q[q] .. "%") end
			end
			local body = "인장 1개와 골드로 장비를 하나 얻습니다. 레벨은 지금까지 간 가장 높은 스테이지를 따릅니다.\n" .. table.concat(parts, "  ")
			if not ns.Forge.Unlocked("seal") then
				body = body .. "\n" .. U.col("ff9a7a", Unlock.Tip("seal"))
			elseif ns.MatCount(s.mat) <= 0 then
				body = body .. "\n" .. U.col("ff9a7a", "이 인장이 없습니다. 상자에서 얻을 수 있습니다.")
			elseif ns.Items.BagFree() <= 0 then
				body = body .. "\n" .. U.col("ff9a7a", "가방이 가득 찼습니다. 장비를 분해하거나 정리하면 굴릴 수 있습니다.")
			elseif not ns.CanAfford(s.gold) then
				body = body .. "\n" .. U.col("ff9a7a", string.format("골드가 부족합니다 (%s G 필요).", U.fmt(s.gold)))
			end
			return UI.SimpleTip("굴리기", body)
		end, "TOP")
		r.isRow = true -- the same buttons on every row
		page.matRows[i] = r
	end
	page.matEmpty = UI.Text(f, 13)
	page.matEmpty:SetPoint("TOP", f, "TOP", 0, LIST_Y - 120)
	page.matEmpty:SetWidth(W - 40)
	page.matEmpty:SetJustifyH("CENTER")
	UI.Color(page.matEmpty, UI.C.sub)
	page.matPrev = UI.Button(f, 30, 24, "<", function() page.matPage = page.matPage - 1 Main.Refresh() end, "dark")
	page.matNext = UI.Button(f, 30, 24, ">", function() page.matPage = page.matPage + 1 Main.Refresh() end, "dark")
	page.matPageText = UI.Text(f, 12)
	page.matPageText:SetPoint("TOP", f, "TOP", 0, LIST_Y - MAT_ROWS * ROW_STEP - 6)
	page.matPrev:SetPoint("RIGHT", page.matPageText, "LEFT", -12, 0)
	page.matNext:SetPoint("LEFT", page.matPageText, "RIGHT", 12, 0)
end

function MatsView.Refresh(page)
	local kinds = MAT_KINDS_OF[page.matTab]
	page.matTabs:Select(page.matTab)
	page.matNote:SetText(MAT_USE[page.matTab] .. " · 같은 재료 9개 → 다음 단계 1개 · 남는 재료는 골드로 분해")
	page.autoFuse:SetOff(ns.Forge.MatFusionsReady(kinds) == 0)
	local list = {}
	for _, id in ipairs(ns.MAT_ORDER) do
		if kinds[ns.MATS[id].kind] and ns.MatCount(id) > 0 then list[#list + 1] = id end
	end
	local pages = max(1, math.ceil(#list / MAT_ROWS))
	page.matPage = U.clamp(page.matPage or 1, 1, pages)
	local smelt = ns.Forge.Unlocked("smelt")
	for i, r in ipairs(page.matRows) do
		local id = list[(page.matPage - 1) * MAT_ROWS + i]
		r.id = id
		if id then
			local m = ns.MATS[id]
			local count = ns.MatCount(id)
			local top = m.tier >= ns.MAT_MAX_TIER[m.kind]
			r.icon.data = id
			r.icon:SetIconName(m.icon)
			r.icon:SetQuality(m.q)
			r.name:SetText(U.col(ns.QUALITY[m.q].hex, ns.N(m.name)) .. "  " .. U.fmt(count))
			r.price:SetText("개당 " .. U.fmt(ns.Forge.MatSmeltGold(id, 1)) .. " G")
			if smelt then
				r.smelt:SetLabel("모두 분해")
				r.smelt:SetStyle("red")
				r.smelt:SetOff(count <= 0)
			else
				local label, off, style = Unlock.Label("smelt", "분해")
				r.smelt:SetLabel(label)
				r.smelt:SetStyle(style)
				r.smelt:SetOff(off)
			end
			local seal = sealIndex(id)
			r.roll:SetShown(seal ~= nil)
			r.one:SetShown(seal == nil and not top)
			r.all:SetShown(seal == nil and not top)
			if seal then
				local s = ns.SEAL[seal]
				r.sub:SetText("굴리면 장비 1개 · 비용 " .. U.fmt(s.gold) .. " G")
				if ns.Forge.Unlocked("seal") then
					local full = ns.Items.BagFree() <= 0
					r.roll:SetStyle("primary")
					r.roll:SetLabel(full and "가방이 가득 참" or ("굴리기 " .. U.fmt(s.gold) .. " G"))
					r.roll:SetOff(full or not ns.CanAfford(s.gold))
				else
					local label, off, style = Unlock.Label("seal", "굴리기")
					r.roll:SetStyle(style)
					r.roll:SetLabel(label)
					r.roll:SetOff(off)
				end
			elseif top then
				r.sub:SetText("가장 높은 단계 (융합 없음)")
			else
				local nextM = ns.MATS[m.kind .. (m.tier + 1)]
				r.sub:SetText(string.format("%d개 → %s 1개", ns.Forge.FUSE_COUNT, nextM and ns.N(nextM.name) or "다음 단계"))
				r.one:SetOff(count < ns.Forge.FUSE_COUNT)
				r.all:SetOff(count < ns.Forge.FUSE_COUNT)
			end
			r:Show()
		else
			r:Hide()
		end
	end
	page.matEmpty:SetText(#list == 0 and "이 종류의 재료가 없습니다. 상자에서 얻을 수 있습니다." or "")
	page.matEmpty:SetShown(#list == 0)
	page.matPageText:SetText(string.format("%d / %d", page.matPage, pages))
	page.matPageText:SetShown(pages > 1)
	page.matPrev:SetShown(pages > 1)
	page.matNext:SetShown(pages > 1)
	page.matPrev:SetOff(page.matPage <= 1)
	page.matNext:SetOff(page.matPage >= pages)
end

function MatsView.Open(page, opts)
	if opts and opts.tab and MAT_KINDS_OF[opts.tab] then page.matTab = opts.tab page.matPage = 1 end
end
