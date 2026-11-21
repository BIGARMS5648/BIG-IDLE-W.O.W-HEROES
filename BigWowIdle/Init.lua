-- Start-up, the simulation driver, slash commands and the offline report.
local ADDON, ns = ...

local UI, U = ns.UI, ns.U
local ready = false
local stampT = 0

_G.BigWowIdle = ns -- handy for /run and for other addons

------------------------------------------------------------------------
-- Offline report (a small dialog shown once after logging in)
------------------------------------------------------------------------
local function showOffline(r)
	local lines
	if r.expired then
		lines = { "너무 오래 자리를 비워 오프라인 보상이 사라졌습니다 (30일 이상)." }
	else
		lines = {
			string.format("자리를 비운 시간: %s", U.time(r.away)),
			string.format("보상 인정 시간: %s (효율 %d%%)", U.time(r.counted), math.floor(r.eff * 100 + 0.5)),
			string.format("골드 +%s", U.fmt(r.gold)),
			string.format("경험치 +%s", U.fmt(r.xp)),
		}
		if r.levels > 0 then
			lines[#lines + 1] = string.format("영웅 레벨 +%d", r.levels)
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
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(40, 40)
	icon:SetPoint("TOP", f, "TOP", 0, -12)
	UI.SetIcon(icon, "INV_Misc_PocketWatch_01")
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
	local function afterFaction()
		if ns.Heroes.Count() == 0 then
			ns.Main.ShowTab("hero", { create = true })
		end
	end
	if not ns.Faction() then
		-- first start (or a save from before factions): choose a side first
		ns.Main.Toggle(true)
		ns.Main.ShowTab("hero")
		ns.PickFaction(afterFaction)
		ns.Print("환영합니다! 먼저 진영을 고르고, 첫 영웅을 무료로 만드세요. (/bwi 로 메뉴를 엽니다)")
	elseif ns.Heroes.Count() == 0 then
		ns.Main.Toggle(true)
		afterFaction()
		ns.Print("환영합니다! 첫 영웅은 무료입니다. 직업과 전문화를 골라 만들어 보세요. (/bwi 로 메뉴를 엽니다)")
	else
		ns.Print("불러왔습니다. /bwi 로 메뉴를 엽니다.")
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
	else
		ns.Print("/bwi (메뉴) · /bwi bar (전투 창 표시/숨김) · /bwi reset (전투 창 위치 초기화)")
	end
end

SLASH_BIGWOWIDLE1 = "/bwi"
SLASH_BIGWOWIDLE2 = "/bwh"  -- BIG W.O.W HEROES, the name before BIG W.O.W IDLE
SLASH_BIGWOWIDLE3 = "/biwh" -- Big Idle W.O.W Heroes, the first name
SLASH_BIGWOWIDLE4 = "/방치영웅"
SlashCmdList["BIGWOWIDLE"] = slash

function BigWowIdle_OnAddonCompartmentClick()
	if ready then ns.Main.Toggle() end
end
