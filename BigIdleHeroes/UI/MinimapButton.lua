-- The minimap button: the game's round minimap button (its gold ring) with
-- the add-on's logo (Media/Art/icon_minimap). Click: the menu window;
-- right click: the battle window; drag: moves it around the minimap's edge
-- (ns.db.ui.minimapAngle). Shown unless turned off in the settings
-- (ns.db.ui.minimap == false).
local _, ns = ...

local UI = ns.UI
local cos, sin, rad, deg, atan2 = math.cos, math.sin, math.rad, math.deg, math.atan2

local MB = {}
ns.MinimapButton = MB

local DEFAULT_ANGLE = 225 -- lower left of the minimap

local btn

local function place()
	local angle = rad(ns.db.ui.minimapAngle or DEFAULT_ANGLE)
	local r = (Minimap:GetWidth() or 140) / 2 + 10
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", cos(angle) * r, sin(angle) * r)
end

-- the angle of the cursor around the minimap's middle
local function cursorAngle()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale() or 1
	return deg(atan2(py / scale - my, px / scale - mx)) % 360
end

function MB.Create()
	if btn or not Minimap then return btn end
	btn = CreateFrame("Button", nil, Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	btn.bg:SetSize(20, 20)
	btn.bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetSize(20, 20)
	btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -5)
	UI.SetArtOrIcon(btn.icon, "icon_minimap", "INV_Misc_Book_09")
	btn.border = btn:CreateTexture(nil, "OVERLAY")
	btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	btn.border:SetSize(53, 53)
	btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
	btn.hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	btn.hl:SetBlendMode("ADD")
	btn.hl:SetAllPoints(btn)
	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then ns.Bar.Toggle() else ns.Main.Toggle() end
	end)
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			ns.db.ui.minimapAngle = cursorAngle()
			place()
		end)
	end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	UI.Tip(btn, function()
		return {
			{ "BIG IDLE HEROES", nil, 1, 0.82, 0.29 },
			{ "클릭: 메뉴 창 열기·닫기", nil, 0.45, 0.8, 1 },
			{ "오른쪽 클릭: 전투 창 보이기·숨기기", nil, 0.45, 0.8, 1 },
			{ "끌기: 미니맵 둘레로 옮기기", nil, 0.45, 0.8, 1 },
		}
	end, "LEFT")
	place()
	MB.Refresh()
	return btn
end

-- shown or hidden as the setting says
function MB.Refresh()
	if btn then btn:SetShown(ns.db.ui.minimap ~= false) end
end

function MB.Button() return btn end
