-- A strict stand-in for the parts of the WoW UI API this addon uses, so the
-- addon can be loaded and driven by a plain Lua 5.1 interpreter.
--
-- Only the widget methods listed below exist, exactly as in the game a method
-- missing from a widget type is nil, so calling it fails. On top of that the
-- mock rejects obviously invalid anchors, layers, strata and script names.
-- That turns typos into test failures instead of in-game Lua errors.

local Mock = { frames = {}, chat = {}, now = 1000, wall = 1700000000, named = {} }
_G.WoWMock = Mock

local POINTS = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 1, CENTER = 1, RIGHT = 1, BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }
local LAYERS = { BACKGROUND = 1, BORDER = 1, ARTWORK = 1, OVERLAY = 1, HIGHLIGHT = 1 }
local STRATA = { BACKGROUND = 1, LOW = 1, MEDIUM = 1, HIGH = 1, DIALOG = 1, FULLSCREEN = 1, FULLSCREEN_DIALOG = 1, TOOLTIP = 1 }
local FRAME_TYPES = { Frame = 1, Button = 1, ScrollFrame = 1, CheckButton = 1, StatusBar = 1, EditBox = 1 }
local SCRIPTS = {
	OnUpdate = 1, OnEvent = 1, OnShow = 1, OnHide = 1, OnEnter = 1, OnLeave = 1, OnMouseDown = 1, OnMouseUp = 1,
	OnMouseWheel = 1, OnDragStart = 1, OnDragStop = 1, OnSizeChanged = 1, OnClick = 1, OnDoubleClick = 1,
}
local BUTTON_ONLY = { OnClick = 1, OnDoubleClick = 1 }

local function check(cond, msg)
	if not cond then error(msg, 3) end
end

------------------------------------------------------------------------
-- Region (shared by frames, textures and font strings)
------------------------------------------------------------------------
local Region = {}

function Region:SetPoint(point, a, b, c, d)
	check(type(point) == "string" and POINTS[point], "SetPoint: bad point " .. tostring(point))
	if type(a) == "string" then
		check(POINTS[a], "SetPoint: bad relative point " .. tostring(a))
	elseif type(a) == "table" then
		check(a.__widget, "SetPoint: relativeTo is not a widget")
		check(a ~= self, "SetPoint: anchored to itself")
		if b ~= nil and type(b) ~= "number" then
			check(type(b) == "string" and POINTS[b], "SetPoint: bad relative point " .. tostring(b))
			check(c == nil or type(c) == "number", "SetPoint: x offset must be a number")
			check(d == nil or type(d) == "number", "SetPoint: y offset must be a number")
		end
	elseif a ~= nil then
		check(type(a) == "number", "SetPoint: bad argument #2 " .. tostring(a))
		check(b == nil or type(b) == "number", "SetPoint: y offset must be a number")
	end
	self.__points[#self.__points + 1] = { point, a, b, c, d }
end
function Region:ClearAllPoints() self.__points = {} end
function Region:SetAllPoints(other)
	check(other == nil or (type(other) == "table" and other.__widget), "SetAllPoints: bad target")
	self.__points = { { "ALL" } }
end
function Region:GetPoint(i)
	local p = self.__points[i or 1]
	if not p then return nil end
	return p[1], p[2], p[3], p[4], p[5]
end
function Region:GetNumPoints() return #self.__points end
function Region:SetSize(w, h)
	check(type(w) == "number" and type(h) == "number", "SetSize: numbers expected")
	self.__w, self.__h = w, h
end
function Region:SetWidth(w) check(type(w) == "number", "SetWidth: number expected") self.__w = w end
function Region:SetHeight(h) check(type(h) == "number", "SetHeight: number expected") self.__h = h end
function Region:GetWidth() return self.__w or 0 end
function Region:GetHeight() return self.__h or 0 end
function Region:GetSize() return self.__w or 0, self.__h or 0 end
function Region:GetLeft() return 100 end
function Region:GetRight() return 100 + (self.__w or 0) end
function Region:GetTop() return 500 end
function Region:GetBottom() return 500 - (self.__h or 0) end
function Region:GetCenter() return 100 + (self.__w or 0) / 2, 500 - (self.__h or 0) / 2 end
function Region:SetAlpha(a) check(type(a) == "number", "SetAlpha: number expected") self.__alpha = a end
function Region:GetAlpha() return self.__alpha or 1 end
function Region:SetScale(s) check(type(s) == "number" and s > 0, "SetScale: positive number expected") self.__scale = s end
function Region:GetScale() return self.__scale or 1 end
function Region:GetEffectiveScale() return self.__scale or 1 end
function Region:GetName() return self.__name end
function Region:GetParent() return self.__parent end
function Region:SetParent(p) self.__parent = p end
function Region:GetObjectType() return self.__type end
function Region:IsShown() return self.__shown end
function Region:IsVisible()
	local f = self
	while f do
		if not f.__shown then return false end
		f = f.__parent
	end
	return true
end

local function fireVisibility(f, script)
	local fn = f.__scripts and f.__scripts[script]
	if fn then fn(f) end
	if f.__children then
		for _, c in ipairs(f.__children) do
			if c.__shown then fireVisibility(c, script) end
		end
	end
end

function Region:Show()
	if not self.__shown then
		self.__shown = true
		if self.__scripts and (not self.__parent or self.__parent:IsVisible()) then fireVisibility(self, "OnShow") end
	end
end
function Region:Hide()
	if self.__shown then
		local was = self:IsVisible()
		self.__shown = false
		if self.__scripts and was then fireVisibility(self, "OnHide") end
	end
end
function Region:SetShown(v) if v then self:Show() else self:Hide() end end

------------------------------------------------------------------------
-- Texture
------------------------------------------------------------------------
local Texture = setmetatable({}, { __index = Region })

function Texture:SetTexture(t, a, b, c)
	check(t == nil or type(t) == "string" or type(t) == "number", "SetTexture: path or file id expected")
	check(a == nil or type(a) ~= "number", "SetTexture(r, g, b, a) is gone on modern clients; use SetColorTexture")
	self.__tex = t
	Mock.textures[tostring(t)] = true
	return true
end
function Texture:GetTexture() return self.__tex end
function Texture:SetColorTexture(r, g, b, a)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetColorTexture: numbers expected")
	self.__tex = "color"
end
function Texture:SetTexCoord(...)
	local n = select("#", ...)
	check(n == 4 or n == 8, "SetTexCoord: 4 or 8 numbers expected")
	for i = 1, n do check(type((select(i, ...))) == "number", "SetTexCoord: numbers expected") end
end
function Texture:SetVertexColor(r, g, b, a)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetVertexColor: numbers expected")
end
function Texture:SetBlendMode(m) check(m == "ADD" or m == "BLEND" or m == "DISABLE" or m == "MOD" or m == "ALPHAKEY", "SetBlendMode: bad mode") end
function Texture:SetDrawLayer(l, sub) check(LAYERS[l], "SetDrawLayer: bad layer") end
function Texture:SetDesaturated(v) end
function Texture:SetRotation(r) check(type(r) == "number", "SetRotation: number expected") end

------------------------------------------------------------------------
-- FontString
------------------------------------------------------------------------
local FontString = setmetatable({}, { __index = Region })

function FontString:SetText(t)
	check(t == nil or type(t) == "string" or type(t) == "number", "SetText: string expected, got " .. type(t))
	self.__text = t and tostring(t) or ""
end
function FontString:GetText() return self.__text end
function FontString:SetFormattedText(fmt, ...) self.__text = string.format(fmt, ...) end
function FontString:SetFont(path, size, flags)
	check(type(path) == "string", "SetFont: font path expected")
	check(type(size) == "number" and size > 0, "SetFont: size expected")
	check(flags == nil or type(flags) == "string", "SetFont: flags must be a string")
	self.__font = { path, size, flags }
	return true
end
function FontString:GetFont() if self.__font then return self.__font[1], self.__font[2], self.__font[3] end end
function FontString:SetFontObject(o) end
function FontString:SetTextColor(r, g, b, a)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetTextColor: numbers expected")
end
function FontString:SetJustifyH(j) check(j == "LEFT" or j == "CENTER" or j == "RIGHT", "SetJustifyH: bad value " .. tostring(j)) end
function FontString:SetJustifyV(j) check(j == "TOP" or j == "MIDDLE" or j == "BOTTOM", "SetJustifyV: bad value " .. tostring(j)) end
function FontString:SetWordWrap(v) end
function FontString:SetNonSpaceWrap(v) end
function FontString:SetMaxLines(n) end
function FontString:SetShadowOffset(x, y) end
function FontString:SetShadowColor(r, g, b, a) end
function FontString:SetDrawLayer(l) check(LAYERS[l], "SetDrawLayer: bad layer") end
function FontString:GetStringWidth()
	check(self.__font, "GetStringWidth before SetFont")
	return #(self.__text or "") * self.__font[2] * 0.45
end
function FontString:GetStringHeight()
	check(self.__font, "GetStringHeight before SetFont")
	local lines = 1
	if self.__w and self.__w > 0 then
		lines = math.max(1, math.ceil(self:GetStringWidth() / self.__w))
	end
	return lines * self.__font[2] * 1.2
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------
local Frame = setmetatable({}, { __index = Region })

function Frame:SetScript(name, fn)
	check(SCRIPTS[name], "SetScript: unknown script " .. tostring(name))
	check(not BUTTON_ONLY[name] or self.__type == "Button" or self.__type == "CheckButton",
		"SetScript: " .. tostring(name) .. " only exists on buttons")
	check(fn == nil or type(fn) == "function", "SetScript: function expected")
	self.__scripts[name] = fn
end
function Frame:GetScript(name) return self.__scripts[name] end
function Frame:HookScript(name, fn)
	check(SCRIPTS[name], "HookScript: unknown script " .. tostring(name))
	local old = self.__scripts[name]
	self.__scripts[name] = function(...)
		if old then old(...) end
		fn(...)
	end
end
function Frame:RegisterEvent(ev) check(type(ev) == "string", "RegisterEvent: string expected") self.__events[ev] = true end
function Frame:UnregisterEvent(ev) self.__events[ev] = nil end
function Frame:UnregisterAllEvents() self.__events = {} end
function Frame:CreateTexture(name, layer, template, sub)
	check(layer == nil or LAYERS[layer], "CreateTexture: bad layer " .. tostring(layer))
	local t = setmetatable({ __widget = true, __type = "Texture", __points = {}, __shown = true, __parent = self, __name = name }, { __index = Texture })
	return t
end
function Frame:CreateFontString(name, layer, template)
	check(layer == nil or LAYERS[layer], "CreateFontString: bad layer " .. tostring(layer))
	local t = setmetatable({ __widget = true, __type = "FontString", __points = {}, __shown = true, __parent = self, __name = name, __text = "" }, { __index = FontString })
	if template then t.__font = { "template", 12 } end
	return t
end
function Frame:EnableMouse(v) self.__mouse = v and true or false end
function Frame:IsMouseEnabled() return self.__mouse end
function Frame:EnableMouseWheel(v) end
function Frame:SetMovable(v) self.__movable = v end
function Frame:RegisterForDrag(...) end
function Frame:StartMoving() check(self.__movable, "StartMoving on a frame that is not movable") end
function Frame:StopMovingOrSizing() end
function Frame:SetClampedToScreen(v) end
function Frame:SetUserPlaced(v) end
function Frame:SetFrameStrata(s) check(STRATA[s], "SetFrameStrata: bad strata " .. tostring(s)) end
function Frame:SetFrameLevel(l) check(type(l) == "number" and l >= 0, "SetFrameLevel: non-negative number expected") self.__level = l end
function Frame:GetFrameLevel() return self.__level or 1 end
function Frame:SetToplevel(v) end
function Frame:Raise() end
function Frame:Lower() end
function Frame:SetID(id) self.__id = id end
function Frame:GetID() return self.__id or 0 end
function Frame:IsMouseOver() return false end
function Frame:SetClipsChildren(v) end
function Frame:SetHitRectInsets(a, b, c, d) end

local Button = setmetatable({}, { __index = Frame })
function Button:RegisterForClicks(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		check(v == "AnyUp" or v == "AnyDown" or v == "LeftButtonUp" or v == "RightButtonUp" or v == "LeftButtonDown"
			or v == "RightButtonDown" or v == "MiddleButtonUp", "RegisterForClicks: bad click type " .. tostring(v))
	end
end
function Button:Click(button)
	if self.__disabled then return end
	local fn = self.__scripts.OnClick
	if fn then fn(self, button or "LeftButton", false) end
end
function Button:Enable() self.__disabled = false end
function Button:Disable() self.__disabled = true end
function Button:SetEnabled(v) self.__disabled = not v end
function Button:IsEnabled() return not self.__disabled end
function Button:SetMotionScriptsWhileDisabled(v) end
function Button:LockHighlight() end
function Button:UnlockHighlight() end

local ScrollFrame = setmetatable({}, { __index = Frame })
function ScrollFrame:SetScrollChild(c) check(type(c) == "table" and c.__widget, "SetScrollChild: frame expected") self.__child = c end
function ScrollFrame:GetScrollChild() return self.__child end
function ScrollFrame:SetVerticalScroll(v) check(type(v) == "number", "SetVerticalScroll: number expected") self.__scroll = v end
function ScrollFrame:GetVerticalScroll() return self.__scroll or 0 end
function ScrollFrame:GetVerticalScrollRange()
	local c = self.__child
	return math.max(0, (c and c.__h or 0) - (self.__h or 0))
end
function ScrollFrame:UpdateScrollChildRect() end

local CLASSES = { Frame = Frame, Button = Button, CheckButton = Button, ScrollFrame = ScrollFrame, StatusBar = Frame, EditBox = Frame }

function _G.CreateFrame(ftype, name, parent, template)
	check(FRAME_TYPES[ftype], "CreateFrame: unknown frame type " .. tostring(ftype))
	check(name == nil or type(name) == "string", "CreateFrame: name must be a string or nil")
	check(parent == nil or (type(parent) == "table" and parent.__widget), "CreateFrame: parent must be a frame or nil")
	check(template == nil or template == "BackdropTemplate", "CreateFrame: unexpected template " .. tostring(template))
	local class = CLASSES[ftype]
	local f = setmetatable({
		__widget = true, __type = ftype, __points = {}, __shown = true, __parent = parent, __name = name,
		__scripts = {}, __events = {}, __children = {},
	}, { __index = class })
	if parent then parent.__children[#parent.__children + 1] = f end
	Mock.frames[#Mock.frames + 1] = f
	if name then
		_G[name] = f
		Mock.named[name] = f
	end
	return f
end

------------------------------------------------------------------------
-- Globals the addon reads
------------------------------------------------------------------------
Mock.textures = {}
Mock.locale = "koKR"
Mock.shift, Mock.ctrl, Mock.alt = false, false, false

_G.UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
_G.GetLocale = function() return Mock.locale end
_G.GetTime = function() return Mock.now end
_G.time = function() return Mock.wall end
_G.date = os.date
_G.STANDARD_TEXT_FONT = "Fonts\\2002.TTF"
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) Mock.chat[#Mock.chat + 1] = msg end }
_G.SlashCmdList = {}
_G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, RAID_WARNING = 8959, IG_QUEST_LIST_COMPLETE = 878, IG_BACKPACK_COIN_OK = 120 }
_G.PlaySound = function(id) check(type(id) == "number", "PlaySound: sound kit id expected") end
_G.IsShiftKeyDown = function() return Mock.shift end
_G.IsControlKeyDown = function() return Mock.ctrl end
_G.IsAltKeyDown = function() return Mock.alt end
_G.GetCursorPosition = function() return 400, 300 end
_G.ReloadUI = function() Mock.reloaded = true end
_G.GetScreenWidth = function() return 1920 end
_G.GetScreenHeight = function() return 1080 end
_G.UISpecialFrames = {}
_G.strsplit = function(sep, s)
	local out = {}
	for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
	return unpack(out)
end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.tinsert, _G.tremove = table.insert, table.remove
_G.format = string.format

------------------------------------------------------------------------
-- Test drivers
------------------------------------------------------------------------
function Mock.FireEvent(ev, ...)
	for _, f in ipairs(Mock.frames) do
		if f.__events[ev] and f.__scripts.OnEvent then
			f.__scripts.OnEvent(f, ev, ...)
		end
	end
end

-- Advance time and run OnUpdate on every visible frame.
function Mock.Update(dt)
	Mock.now = Mock.now + dt
	Mock.wall = Mock.wall + dt
	local n = #Mock.frames
	for i = 1, n do
		local f = Mock.frames[i]
		local fn = f.__scripts.OnUpdate
		if fn and f:IsVisible() then fn(f, dt) end
	end
end

function Mock.Hover(f)
	local fn = f.__scripts.OnEnter
	if fn then fn(f) end
	fn = f.__scripts.OnLeave
	if fn then fn(f) end
end

-- Every visible, enabled button (used by the UI smoke test).
function Mock.VisibleButtons()
	local out = {}
	for _, f in ipairs(Mock.frames) do
		if (f.__type == "Button" or f.__type == "CheckButton") and f:IsVisible() and not f.__disabled and f.__scripts.OnClick then
			out[#out + 1] = f
		end
	end
	return out
end

return Mock
