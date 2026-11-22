-- Equipment screen (장비).
--   left: every hero (small portraits), the chosen hero's equipment around
--         a summary (전투력, 역할, 능력치, usable weapons), the two weapon
--         slots under it, and [자동 장착] [파티 자동 장착] [전체 해제] at the
--         bottom. A slot: click = the bag shows that slot's items,
--         right-click = 해제.
--   right: tabs 가방 · 융합 · 제작 · 보석 · 마법부여 · 각인 · 재료
--          (UI/TabBag.lua and UI/TabForge.lua); the forge level under all of
--          them. Forge functions used inside a tab (분해, 추출, 굴리기) are
--          unlocked on the button that uses them.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI, U = ns.UI, ns.U
local Main = ns.Main
local H = ns.Heroes
local K = UI.K

local LEFT_W, RIGHT_X, RIGHT_W = 360, 370, 550
local SLOT = 48
local LEFT_COL = { "head", "neck", "chest", "wrist" }
local RIGHT_COL = { "hands", "feet", "ring", "trinket" }
local WEAPONS = { "mh", "oh" }
local CX, CW = 70, 220 -- the summary between the slot columns
local PORTRAIT, PORTRAIT_GAP = 32, 5 -- the hero picker: two rows at the top
local SLOT_Y = -8 - 2 * PORTRAIT - PORTRAIT_GAP - 15 -- first slot row, under the picker
local DY = 18 -- the summary starts this far under its rows' base (the name sits beside the picker)

local TABS = {
	{ "bag", "가방" }, { "fuse", "융합" }, { "craft", "제작" }, { "gem", "보석" },
	{ "ench", "마법부여" }, { "insc", "각인" }, { "mats", "재료" }, { "bank", "창고" },
}
local FORGE_TAB = { fuse = true, craft = true, gem = true, ench = true, insc = true }

local function heroOf() return Main.SelectedHero() end

local function equipAllParty()
	local n = 0
	for i = 1, ns.PARTY_SIZE do
		local pid = ns.db.party[i]
		if pid then n = n + ns.Items.AutoEquip(pid) end
	end
	ns.Toast(n > 0 and string.format("파티 전원: 장비 %d개를 바꿨습니다.", n) or "가방에 더 좋은 장비가 없습니다.")
end

-- Bag items for a slot the hero can wear, best gain first.
local function bestFor(id, slot)
	local best
	for _, it in ipairs(ns.db.bag) do
		if it.s == slot and ns.Items.CanEquip(id, it) then
			local r = ns.Items.Compare(id, it) or 0
			if not best or r > best then best = r end
		end
	end
	return best
end

------------------------------------------------------------------------
-- Left: the hero's equipment
------------------------------------------------------------------------
local function buildLeft(page)
	local lp = UI.Panel(page, LEFT_W, K.H, "inset")
	lp:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	page.left = lp
	-- every hero in two rows; the chosen one wears a gold ring and its name
	-- stands to the right
	page.strip = UI.HeroStrip(lp, ns.ROSTER_MAX, PORTRAIT, PORTRAIT_GAP, function(id)
		Main.SelectHero(id)
		Main.Refresh()
	end, function(id) return ns.Guide.UpgradeHeroes()[id] end, ns.ROSTER_MAX / 2) -- red dot: better gear in the bag
	page.strip:SetPoint("TOPLEFT", lp, "TOPLEFT", 12, -8)
	page.slots = {}
	local function slotButton(slot, x, y)
		local b = UI.IconButton(lp, SLOT, function(self, button)
			local id = heroOf()
			if not id then return end
			if button == "RightButton" then
				if ns.db.heroes[id].gear[self.slot] then UI.Try(ns.Items.Unequip(id, self.slot)) end
			else
				page.tab = "bag"
				ns.BagView.Open(page, { slot = self.slot })
			end
			Main.Refresh()
		end)
		b.slot = slot
		b:SetPoint("TOPLEFT", lp, "TOPLEFT", x, y)
		b.empty = UI.Text(b, 10, ns.N(ns.SLOT[slot].name))
		b.empty:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.empty:SetWidth(SLOT - 4)
		b.empty:SetJustifyH("CENTER")
		UI.Color(b.empty, UI.C.dim)
		b.up = UI.Text(b, 14, nil, "OUTLINE")
		b.up:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 1)
		b.up:SetTextColor(0.3, 1, 0.3)
		UI.Tip(b, function(self)
			local id = heroOf()
			local it = id and ns.db.heroes[id].gear[self.slot]
			local lines
			if it then
				lines = ns.Items.Tooltip(it, id)
			else
				lines = { { ns.N(ns.SLOT[self.slot].name), nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }, { "비어 있음", nil, 0.7, 0.7, 0.7 } }
			end
			lines[#lines + 1] = { "클릭: 가방에서 이 부위 보기" .. (it and " · 오른쪽 클릭: 해제" or ""), nil, 0.45, 0.8, 1 }
			return lines
		end)
		page.slots[slot] = b
	end
	for i, slot in ipairs(LEFT_COL) do slotButton(slot, 12, SLOT_Y - (i - 1) * 60) end
	for i, slot in ipairs(RIGHT_COL) do slotButton(slot, LEFT_W - 12 - SLOT, SLOT_Y - (i - 1) * 60) end
	-- the weapons right under "착용 가능 무기"
	for i, slot in ipairs(WEAPONS) do slotButton(slot, LEFT_W / 2 - SLOT - 6 + (i - 1) * (SLOT + 12), -340 - DY) end

	-- the summary
	local nameX = 12 + page.strip:GetWidth() + 12
	local nameW = LEFT_W - 12 - nameX
	page.name = UI.Text(lp, 15)
	page.name:SetPoint("TOPLEFT", lp, "TOPLEFT", nameX, -18)
	page.name:SetWidth(nameW)
	page.name:SetWordWrap(false)
	page.spec = UI.Text(lp, 11)
	page.spec:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -4)
	page.spec:SetWidth(nameW)
	page.spec:SetWordWrap(false)
	UI.Color(page.spec, UI.C.sub)
	local function rows(n, y)
		local out = {}
		for i = 1, n do
			local r = UI.StatRow(lp, CW)
			r:SetHeight(19)
			r.l:SetFont(ns.FONT, 11, "")
			r.v:SetFont(ns.FONT, 11, "")
			r:SetPoint("TOPLEFT", lp, "TOPLEFT", CX, y - (i - 1) * 19)
			out[i] = r
		end
		return out
	end
	page.top = rows(3, -72 - DY)
	page.statHead = UI.Section(lp, CW, "능력치")
	page.statHead:SetPoint("TOPLEFT", lp, "TOPLEFT", CX, -136 - DY)
	page.stats = rows(6, -160 - DY)
	page.weaponHead = UI.Text(lp, 11, "착용 가능 무기")
	page.weaponHead:SetPoint("TOPLEFT", lp, "TOPLEFT", CX, -282 - DY)
	UI.Color(page.weaponHead, UI.C.gold)
	page.weapons = UI.Text(lp, 11)
	page.weapons:SetPoint("TOPLEFT", lp, "TOPLEFT", CX, -298 - DY)
	page.weapons:SetWidth(CW)
	page.weapons:SetJustifyV("TOP")
	UI.Color(page.weapons, UI.C.sub)
	page.auto = UI.Button(lp, CW, 34, "자동 장착", function()
		local id = heroOf()
		if not id then return end
		local n = ns.Items.AutoEquip(id)
		ns.Toast(n > 0 and string.format("%s: 장비 %d개를 바꿨습니다.", H.ShortName(id), n) or "가방에 더 좋은 장비가 없습니다.")
		Main.Refresh()
	end, "primary")
	page.auto:SetPoint("BOTTOMLEFT", lp, "BOTTOMLEFT", CX, 50) -- the buttons at the bottom
	UI.Tip(page.auto, function() return UI.SimpleTip("자동 장착", "가방에서 이 영웅에게 더 좋은 장비를 모든 칸에 장착합니다. 빼낸 장비는 가방으로 돌아갑니다.") end, "TOP")
	page.party = UI.Button(lp, floor((CW - 6) / 2), 28, "파티 자동 장착", function()
		equipAllParty()
		Main.Refresh()
	end, "dark")
	page.party:SetPoint("BOTTOMLEFT", lp, "BOTTOMLEFT", CX, 14)
	UI.Tip(page.party, function() return UI.SimpleTip("파티 자동 장착", "출전 중인 영웅 모두에게 가방 속 더 좋은 장비를 장착합니다.") end, "TOP")
	page.unequip = UI.Button(lp, floor((CW - 6) / 2), 28, "전체 해제", function()
		local id = heroOf()
		if not id then return end
		if not next(ns.db.heroes[id].gear) then UI.Try(false, "착용한 장비가 없습니다.") return end
		if ns.Items.BagFree() <= 0 then UI.Try(false, "가방이 가득 찼습니다. 벗긴 장비를 넣을 자리가 없습니다.") return end
		UI.Confirm({ title = "전체 해제", ok = "해제", style = "red",
			text = string.format("%s의 장비를 모두 벗기시겠습니까?\n벗긴 장비는 가방으로 갑니다 (가방 빈칸 %d개).", H.Name(id), ns.Items.BagFree()),
			onOk = function()
				local n = 0
				for _, slot in ipairs(ns.SLOTS) do
					if ns.db.heroes[id].gear[slot] and ns.Items.BagFree() > 0 then
						if ns.Items.Unequip(id, slot) then n = n + 1 end
					end
				end
				ns.Toast(string.format("장비 %d개를 가방으로 옮겼습니다.", n))
			end })
	end, "red")
	page.unequip:SetPoint("BOTTOMRIGHT", lp, "BOTTOMLEFT", CX + CW, 14)
	page.unequip.clickWhenOff = true
	page.slotHint = UI.Text(lp, 11, "칸 클릭: 가방에서 그 부위 보기\n오른쪽 클릭: 해제")
	page.slotHint:SetPoint("TOP", lp, "TOPLEFT", CX + CW / 2, -400 - DY)
	page.slotHint:SetWidth(CW)
	page.slotHint:SetJustifyH("CENTER")
	UI.Color(page.slotHint, UI.C.dim)
	page.noHero = UI.Text(lp, 13, "영웅이 없습니다.\n'영웅' 화면에서 첫 영웅을 만드세요.")
	page.noHero:SetPoint("CENTER", lp, "CENTER", 0, 40)
	page.noHero:SetWidth(LEFT_W - 40)
	page.noHero:SetJustifyH("CENTER")
	UI.Color(page.noHero, UI.C.sub)
end

local function refreshLeft(page)
	local id = heroOf()
	page.strip:Set(UI.HeroOrder(), id)
	local has = id ~= nil
	for _, w in ipairs({ page.name, page.spec, page.statHead, page.weaponHead, page.weapons, page.auto, page.party, page.unequip, page.slotHint }) do
		w:SetShown(has)
	end
	for _, r in ipairs(page.top) do r:SetShown(has) end
	for _, r in ipairs(page.stats) do r:SetShown(has) end
	for _, b in pairs(page.slots) do b:SetShown(has) end
	page.noHero:SetShown(not has)
	if not has then return end
	local h = ns.db.heroes[id]
	local sp = ns.SPECS[h.spec]
	local s = ns.Stats.Get(id)
	page.name:SetText(U.col("ffb84a", H.ShortName(id)))
	page.spec:SetText(string.format("Lv %d %s", h.level, ns.N(sp.name)))
	local worn, ups = 0, 0
	for slot, b in pairs(page.slots) do
		local it = h.gear[slot]
		b:Clear()
		b:SetSelected(page.tab == "bag" and page.view == slot)
		if it then
			worn = worn + 1
			b:SetIconName(ns.Items.Icon(it))
			b:SetQuality(it.q)
			b:SetLocked(it.lock)
			b.empty:Hide()
		else
			b.empty:Show()
		end
		local r = bestFor(id, slot)
		local better = r and r > 1.01
		if better then ups = ups + 1 end
		b.up:SetText(better and "+" or "")
	end
	local rh = ns.ROLE[sp.role]
	page.top[1]:Set("전투력", U.col("ffd24a", U.fmt(H.PowerScore(id))))
	page.top[2]:Set("역할", U.col(rh.hex, ns.N(rh.name)))
	page.top[3]:Set("장착", string.format("%d / %d칸", worn, #ns.SLOTS))
	page.stats[1]:Set("공격력", U.col("ffd24a", U.fmt(s.atk)))
	page.stats[2]:Set("생명력", U.col("60e070", U.fmt(s.hp)))
	page.stats[3]:Set("방어도", U.fmt(s.armor))
	page.stats[4]:Set("치명타", U.num(s.crit, 1) .. "% / " .. U.num(s.critdmg, 0) .. "%")
	page.stats[5]:Set("공격 속도", U.num(s.aspd, 2) .. "/초")
	page.stats[6]:Set("회피 · 막기", U.num(s.dodge, 1) .. "% · " .. U.num(s.block, 1) .. "%")
	local names = {}
	for _, t in ipairs(sp.mh or {}) do names[#names + 1] = ns.N(ns.WTYPE[t].name) end
	for _, t in ipairs(sp.oh or {}) do names[#names + 1] = ns.N(ns.WTYPE[t].name) end
	page.weapons:SetText(table.concat(names, ", "))
	page.auto:SetOff(ups == 0)
	page.auto:SetBadge(ups > 0 and ups or nil)
	page.unequip:SetOff(worn == 0)
end

------------------------------------------------------------------------
-- Right: the tabs
------------------------------------------------------------------------
local function buildRight(page)
	local rp = UI.Panel(page, RIGHT_W, K.H, "inset")
	rp:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT_X, 0)
	page.right = rp
	page.tabs = UI.Tabs(rp, RIGHT_W - 24, TABS, function(key)
		page.tab = key
		-- the bag always opens on everything (보기: 전체)
		if key == "bag" then page.view = "all" page.bagPage = 1 end
		Main.Refresh()
	end, true, 32)
	page.tabs:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -12)
	for _, t in ipairs(TABS) do
		if FORGE_TAB[t[1]] then
			UI.Tip(page.tabs:Get(t[1]), function()
				local d = ns.Forge.OpDef(t[1])
				local lines = { { ns.N(d.name), nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] }, { ns.N(d.desc), nil, 1, 1, 1 } }
				if not ns.Forge.Unlocked(t[1]) then
					lines[#lines + 1] = { string.format("용광로 %d레벨 · 해금 %s G", d.level, U.fmt(d.cost)), nil, 1, 0.5, 0.3 }
				end
				return lines
			end, "TOP")
		end
	end
	page.bodies = {}
	local function body(key, h)
		local f = CreateFrame("Frame", nil, rp)
		f:SetSize(RIGHT_W - 24, h)
		f:SetPoint("TOPLEFT", rp, "TOPLEFT", 12, -56)
		page.bodies[key] = f
		return f
	end
	-- every tab leaves room for the forge level at the bottom
	ns.BagView.Build(page, body("bag", ns.ForgeView.H))
	ns.MatsView.Build(page, body("mats", ns.ForgeView.H))
	page.forge = {}
	for key in pairs(FORGE_TAB) do
		page.forge[key] = ns.ForgeView.Build[key](page, body(key, ns.ForgeView.H))
	end
	page.lockView = ns.ForgeView.Build.locked(page, body("locked", ns.ForgeView.H))
	-- the forge level, under every tab (breaking down and fusing raise it)
	page.forgeBar = UI.Bar(rp, RIGHT_W - 24, 18, 0.95, 0.55, 0.15)
	page.forgeBar:SetPoint("BOTTOMLEFT", rp, "BOTTOMLEFT", 12, 12)
	page.forgeBar.text:SetFont(ns.FONT, 11, "OUTLINE")
	page.forgeBar:EnableMouse(true)
	UI.Tip(page.forgeBar, function()
		local lines = { { "용광로 레벨", nil, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
			{ "장비를 분해·융합·제작하면 경험치가 오릅니다. 레벨이 오르면 새 기능과 제작 단계가 열립니다.", nil, 1, 1, 1, true } }
		for _, d in ipairs(ns.FORGE_OPS) do
			local open = ns.Forge.Unlocked(d.key)
			lines[#lines + 1] = { ns.N(d.name), open and "해금됨" or string.format("Lv %d · %s G", d.level, U.fmt(d.cost)),
				open and 0.4 or 0.75, open and 1 or 0.75, open and 0.45 or 0.8 }
		end
		return lines
	end, "TOP")
end

local function refreshRight(page)
	local tab = page.tab
	page.tabs:Select(tab)
	local f = ns.db.forge
	for key in pairs(FORGE_TAB) do
		local d = ns.Forge.OpDef(key)
		local open = ns.Forge.Unlocked(key)
		page.tabs:SetLocked(key, not open)
		page.tabs:SetBadge(key, not open and f.level >= d.level and ns.CanAfford(d.cost))
	end
	-- a function used inside the bag, the gem tab or the materials that can be
	-- unlocked now shows on that tab
	local function ready(op)
		local d = ns.Forge.OpDef(op)
		return not ns.Forge.Unlocked(op) and f.level >= d.level and ns.CanAfford(d.cost) and ns.Guide.UnlockUseful(op)
	end
	page.tabs:SetBadge("bag", ns.Loot.Count() > 0 and ns.Loot.Count() or ready("smelt"))
	if ns.Forge.Unlocked("gem") and ready("remove") then page.tabs:SetBadge("gem", true) end
	page.tabs:SetBadge("mats", ready("seal"))
	for _, b in pairs(page.bodies) do b:Hide() end
	if f.level >= ns.FORGE_MAX then
		page.forgeBar:SetValue(1)
		page.forgeBar:SetLabel(string.format("용광로 Lv %d · 최고 레벨", f.level))
	else
		local need = ns.Forge.Need(f.level)
		page.forgeBar:SetValue(f.xp / need)
		page.forgeBar:SetLabel(string.format("용광로 Lv %d · %s / %s", f.level, U.fmt(f.xp), U.fmt(need)))
	end
	if tab == "bag" or tab == "bank" then
		page.bodies.bag:Show()
		ns.BagView.Refresh(page)
	elseif tab == "mats" then
		page.bodies.mats:Show()
		ns.MatsView.Refresh(page)
	elseif ns.Forge.Unlocked(tab) then
		page.bodies[tab]:Show()
		page.forge[tab].refresh()
	else
		page.bodies.locked:Show()
		page.lockView.refresh(tab)
	end
end

------------------------------------------------------------------------
-- Screen
------------------------------------------------------------------------
local function build(page)
	page.tab = "bag"
	buildLeft(page)
	buildRight(page)
end

local function refresh(page)
	refreshRight(page)
	refreshLeft(page)
end

local function tick(page) end

-- opts.sub: a tab ("bag", "fuse", "mats", "bank" …; old forge names work too);
-- opts.slot / opts.view: what the bag shows; opts.tab: a materials tab
local OLD_SUB = { smelt = "bag", remove = "gem", seal = "mats" }
local OLD_MATS = { seal = "mat_seal" }
local function open(page, opts)
	if not opts then return end
	local sub = OLD_SUB[opts.sub] or opts.sub
	if opts.tab and ns.MatsView.KINDS_OF[opts.tab] then sub = "mats" end
	for _, t in ipairs(TABS) do if t[1] == sub then page.tab = sub end end
	-- the bag opens on everything unless a slot or view is asked for
	if sub == "bag" and not opts.view and not opts.slot then page.view = "all" page.bagPage = 1 end
	if opts.slot or opts.view then
		page.tab = "bag"
		ns.BagView.Open(page, opts)
	end
	ns.MatsView.Open(page, opts)
	if OLD_MATS[opts.sub] then ns.MatsView.Open(page, { tab = OLD_MATS[opts.sub] }) end
	if opts.hero then Main.SelectHero(opts.hero) end
end

Main.RegisterTab({
	key = "equip", title = "장비", sub = "장비, 가방, 용광로, 재료",
	icon = "INV_Chest_Chain_05", art = "icon_bag", build = build, refresh = refresh, open = open, tick = tick,
	events = { "HEROES", "PARTY", "LEVEL", "GEAR", "BAG", "MATS", "CHESTS", "STATS", "RUNES", "FORGE", "RESET" },
})
