-- Start-up, the simulation driver, slash commands and the offline report.
local ADDON, ns = ...

local UI, U = ns.UI, ns.U
local ready = false
local stampT = 0

_G.BigIdleHeroes = ns -- handy for /run and for other addons

------------------------------------------------------------------------
-- Offline report (a small dialog shown once after logging in)
------------------------------------------------------------------------
local function showOffline(r)
	local lines
	if r.expired then
		lines = { "너무 오래 자리를 비워 오프라인 보상이 사라졌습니다 (30일 이상)." }
	else
		-- what was earned: the amounts in green, their names as they are
		local GAIN = "66ff73"
		lines = {
			string.format("자리를 비운 시간: %s", U.time(r.away)),
			string.format("보상 인정 시간: %s (효율 %d%%)", U.time(r.counted), math.floor(r.eff * 100 + 0.5)),
			"골드 " .. U.col(GAIN, "+" .. U.fmt(r.gold)),
		}
		if r.xp >= 1 then
			lines[#lines + 1] = "경험치 " .. U.col(GAIN, "+" .. U.fmt(r.xp))
		end
		if r.levels > 0 then
			lines[#lines + 1] = "영웅 레벨 " .. U.col(GAIN, "+" .. r.levels)
		end
	end
	local f = UI.Panel(UIParent, 360, 210, "panel", true)
	f:SetFrameStrata("DIALOG")
	f.isPopup = true -- shown once over everything until 받기
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	f:EnableMouse(true)
	local glow = UI.Art(f, "glow", "BORDER", 1, 0.8, 0.3, 0.5)
	glow:SetSize(120, 120)
	glow:SetPoint("TOP", f, "TOP", 0, 30)
	-- the clock in a slot with its border, like the companions' icons
	local icon = UI.IconButton(f, 44)
	icon:SetPoint("TOP", f, "TOP", 0, -10)
	icon:EnableMouse(false)
	icon:SetIconName("INV_Misc_PocketWatch_01")
	local title = UI.Title(f, "오프라인 보상", 16)
	title:SetPoint("TOP", f, "TOP", 0, -58)
	title:SetJustifyH("CENTER")
	local body = UI.Text(f, 12, table.concat(lines, "\n"))
	body:SetPoint("TOP", f, "TOP", 0, -84)
	body:SetWidth(320)
	body:SetJustifyH("CENTER")
	body:SetJustifyV("TOP")
	local ok = UI.Button(f, 140, 32, "받기", function() f:Hide() end, "primary")
	ok:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
	ns.Log(table.concat(lines, "  "))
	return f
end
ns.ShowOffline = showOffline

------------------------------------------------------------------------
-- Driver: an unparented frame keeps ticking even when the UI is hidden
------------------------------------------------------------------------
local driver = CreateFrame("Frame")

local function onUpdate(_, elapsed)
	if not ready then return end
	if elapsed > 120 then elapsed = 120 end -- (the fight catches up a few seconds a frame)
	ns.Combat.Update(elapsed)
	ns.Loot.Tick(elapsed)
	local db = ns.db
	db.stat.time = (db.stat.time or 0) + elapsed
	stampT = stampT + elapsed
	if stampT >= 30 then
		stampT = 0
		ns.Offline.Stamp(time()) -- so a crash does not hand out a huge offline reward
	end
	-- nobody is drawing: drop queued visual events (numbers and spells)
	if not ns.Bar.IsShown() then
		local fx, vfx = ns.Combat.fx, ns.Combat.vfx
		for i = #fx, 1, -1 do fx[i] = nil end
		for i = #vfx, 1, -1 do vfx[i] = nil end
	end
end

-- No hero yet: no battle window until the first one is made.
local awaiting = false
function ns.AwaitFirstHero()
	if ns.Heroes.Count() > 0 then return end
	ns.Bar.Hold(true)
	if not awaiting then
		awaiting = true
		ns.On("HEROES", function()
			if ns.Bar.IsHeld() and ns.Heroes.Count() > 0 then ns.Bar.Hold(false) end
		end)
	end
end
ns.On("RESET", function()
	if ready then ns.AwaitFirstHero() end
end)

local function onLogin()
	ns.Heroes.ValidateParty()
	ns.Runes.Invalidate()
	ns.Bar.Create()
	ns.Main.Create()
	local report = ns.Offline.Claim(time())
	ready = true
	if report then showOffline(report) end
	local function afterFaction()
		if ns.Heroes.Count() == 0 then
			ns.Main.ShowTab("hero", { create = true })
		end
	end
	ns.AwaitFirstHero()
	if not ns.Faction() then
		-- first start (or a save from before factions): choose a side first
		ns.Main.Toggle(true)
		ns.Main.ShowTab("hero")
		ns.PickFaction(afterFaction)
		ns.Print("환영합니다! 먼저 진영을 고르고, 첫 영웅을 무료로 만드세요. (/bih 로 메뉴를 엽니다)")
	elseif ns.Heroes.Count() == 0 then
		ns.Main.Toggle(true)
		afterFaction()
		ns.Print("환영합니다! 첫 영웅은 무료입니다. 직업과 전문화를 골라 모집해 보세요. (/bih 로 메뉴를 엽니다)")
	else
		ns.Print("불러왔습니다. /bih 로 메뉴를 엽니다.")
	end
	if ns.loadNote then
		ns.Print(ns.loadNote)
		ns.loadNote = nil
	end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			ns.InitDB()
			ns.db.lang = nil -- a setting of version 2.0 that no longer exists
		end
	elseif event == "PLAYER_LOGIN" then
		if not ns.db then ns.InitDB() end
		onLogin()
	elseif event == "PLAYER_LOGOUT" then
		if ns.db then ns.Offline.Stamp(time()) end
	end
end)
driver:SetScript("OnUpdate", onUpdate)

------------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------------
ns.On("LEVEL", function(id, level)
	ns.Log(string.format("%s 레벨 %d 달성", ns.Heroes.ColorName(id), level))
end)

------------------------------------------------------------------------
-- Slash commands and the addon compartment entry
------------------------------------------------------------------------
local function slash(msg)
	if not ready then return end
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then
		ns.Main.Toggle()
	elseif msg == "bar" then
		ns.Bar.Toggle()
	elseif msg == "reset" then
		ns.Bar.ResetPosition()
		ns.Bar.Toggle(true)
	elseif msg == "fx" or msg == "fx fail" then
		-- (for now) the 강화 strikes and result window, nothing spent
		ns.ForgeView.UpFx.Demo(msg == "fx")
	elseif msg == "ground" or msg == "땅" then
		local total, missing = ns.Bar.CheckGrounds()
		if #missing == 0 then
			ns.Log(string.format("땅 그림: %d곳 모두 있음", total))
		else
			ns.Log(string.format("땅 그림: %d곳 중 %d곳은 다른 그림으로 바꿔 씀", total, #missing))
			for _, m in ipairs(missing) do ns.Log("  " .. m) end
		end
	else
		ns.Print("/bih (메뉴) · /bih bar (전투 창 표시/숨김) · /bih reset (전투 창 위치 초기화) · /bih ground (땅 그림 확인) · /bih fx (강화 연출 보기, 실패는 /bih fx fail)")
	end
end

SLASH_BIGIDLEHEROES1 = "/bih"
SlashCmdList["BIGIDLEHEROES"] = slash

function BigIdleHeroes_OnAddonCompartmentClick()
	if ready then ns.Main.Toggle() end
end
