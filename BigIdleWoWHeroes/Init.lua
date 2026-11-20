-- Start-up, the simulation driver, slash commands and the offline report.
local ADDON, ns = ...

local UI, U = ns.UI, ns.U
local ready = false
local stampT = 0

_G.BigIdleWoWHeroes = ns -- handy for /run and for other addons

------------------------------------------------------------------------
-- Offline report (a small dialog shown once after logging in)
------------------------------------------------------------------------
local function showOffline(r)
	local T = ns.T
	local lines
	if r.expired then
		lines = { T("너무 오래 자리를 비워 오프라인 보상이 사라졌습니다 (30일 이상).", "You were away too long - offline rewards have expired (30 days or more).") }
	else
		lines = {
			string.format(T("자리를 비운 시간: %s", "Time away: %s"), U.time(r.away)),
			string.format(T("보상 인정 시간: %s (효율 %d%%)", "Rewarded time: %s (at %d%% rate)"), U.time(r.counted), math.floor(r.eff * 100 + 0.5)),
			string.format(T("골드 +%s", "Gold +%s"), U.fmt(r.gold)),
			string.format(T("경험치 +%s", "Experience +%s"), U.fmt(r.xp)),
		}
		if r.levels > 0 then
			lines[#lines + 1] = string.format(T("영웅 레벨 +%d", "Hero levels +%d"), r.levels)
		end
	end
	local f = UI.Panel(UIParent, 360, 210, "panel", true)
	f:SetFrameStrata("DIALOG")
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	f:EnableMouse(true)
	local glow = UI.Art(f, "glow", "BORDER", 1, 0.8, 0.3, 0.5)
	glow:SetSize(120, 120)
	glow:SetPoint("TOP", f, "TOP", 0, 30)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(40, 40)
	icon:SetPoint("TOP", f, "TOP", 0, -12)
	UI.SetIcon(icon, "INV_Misc_PocketWatch_01")
	local title = UI.Title(f, T("오프라인 보상", "Offline Rewards"), 16)
	title:SetPoint("TOP", f, "TOP", 0, -58)
	title:SetJustifyH("CENTER")
	local body = UI.Text(f, 12, table.concat(lines, "\n"))
	body:SetPoint("TOP", f, "TOP", 0, -84)
	body:SetWidth(320)
	body:SetJustifyH("CENTER")
	body:SetJustifyV("TOP")
	local ok = UI.Button(f, 140, 32, T("받기", "Collect"), function() f:Hide() end, "primary")
	ok:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
	ns.Log(table.concat(lines, "  "))
end

------------------------------------------------------------------------
-- Driver: an unparented frame keeps ticking even when the UI is hidden
------------------------------------------------------------------------
local driver = CreateFrame("Frame")

local function onUpdate(_, elapsed)
	if not ready then return end
	if elapsed > 5 then elapsed = 5 end
	ns.Combat.Update(elapsed)
	ns.Loot.Tick(elapsed)
	local db = ns.db
	db.stat.time = (db.stat.time or 0) + elapsed
	stampT = stampT + elapsed
	if stampT >= 30 then
		stampT = 0
		ns.Offline.Stamp(time()) -- so a crash does not hand out a huge offline reward
	end
	-- nobody is drawing: drop queued visual events
	if not ns.Bar.IsShown() then
		local fx = ns.Combat.fx
		for i = #fx, 1, -1 do fx[i] = nil end
	end
end

local function onLogin()
	ns.Heroes.ValidateParty()
	ns.Runes.Invalidate()
	ns.Bar.Create()
	ns.Main.Create()
	local report = ns.Offline.Claim(time())
	ready = true
	if report then showOffline(report) end
	if ns.Heroes.Count() == 0 then
		ns.Main.Toggle(true)
		ns.Main.ShowTab("party", { create = true })
		ns.Print(ns.T("환영합니다! 첫 영웅은 무료입니다. 직업과 전문화를 골라 만들어 보세요. (/biwh 로 메뉴를 엽니다)",
			"Welcome! Your first hero is free - pick a class and specialization. (/biwh opens the menu)"))
	else
		ns.Print(ns.T("불러왔습니다. /biwh 로 메뉴를 엽니다.", "Loaded. Type /biwh to open the menu."))
	end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			local db = ns.InitDB()
			ns.DetectLang(db.lang)
		end
	elseif event == "PLAYER_LOGIN" then
		if not ns.db then
			local db = ns.InitDB()
			ns.DetectLang(db.lang)
		end
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
	ns.Log(string.format(ns.T("%s 레벨 %d 달성", "%s reached level %d"), ns.Heroes.ColorName(id), level))
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
	elseif msg == "lang ko" or msg == "lang en" or msg == "lang auto" then
		local l = msg:sub(6)
		ns.db.lang = (l ~= "auto") and l or nil
		ns.Print(ns.T("언어 설정을 바꿨습니다. /reload 후 적용됩니다.", "Language changed. It applies after /reload."))
	else
		ns.Print(ns.T("/biwh (메뉴) · /biwh bar (전투 바 표시/숨김) · /biwh reset (바 위치 초기화) · /biwh lang ko|en|auto",
			"/biwh (menu) - /biwh bar (show / hide the bar) - /biwh reset (reset bar position) - /biwh lang ko|en|auto"))
	end
end

SLASH_BIGIDLEWOWHEROES1 = "/biwh"
SLASH_BIGIDLEWOWHEROES2 = "/idleheroes"
SLASH_BIGIDLEWOWHEROES3 = "/방치영웅"
SlashCmdList["BIGIDLEWOWHEROES"] = slash

function BigIdleWoWHeroes_OnAddonCompartmentClick()
	if ready then ns.Main.Toggle() end
end
