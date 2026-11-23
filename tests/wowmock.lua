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
local FRAME_TYPES = { Frame = 1, Button = 1, ScrollFrame = 1, CheckButton = 1, StatusBar = 1, EditBox = 1, PlayerModel = 1, DressUpModel = 1, ModelScene = 1 }
local SCRIPTS = {
	OnUpdate = 1, OnEvent = 1, OnShow = 1, OnHide = 1, OnEnter = 1, OnLeave = 1, OnMouseDown = 1, OnMouseUp = 1,
	OnMouseWheel = 1, OnDragStart = 1, OnDragStop = 1, OnSizeChanged = 1, OnClick = 1, OnDoubleClick = 1, OnModelLoaded = 1,
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
	-- the same anchor in one canonical shape, for the layout preview
	local relTo, relPoint, x, y = self.__parent, point, 0, 0
	if type(a) == "table" then
		relTo = a
		if type(b) == "string" then relPoint, x, y = b, c or 0, d or 0 else x, y = b or 0, c or 0 end
	elseif type(a) == "string" then
		relPoint, x, y = a, b or 0, c or 0
	elseif type(a) == "number" then
		x, y = a, b or 0
	end
	self.__anchors[#self.__anchors + 1] = { point, relTo, relPoint, x, y }
end
function Region:ClearAllPoints() self.__points = {} self.__anchors = {} end
function Region:SetAllPoints(other)
	check(other == nil or (type(other) == "table" and other.__widget), "SetAllPoints: bad target")
	self.__points = { { "ALL" } }
	self.__anchors = { { "ALL", other or self.__parent } }
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
	self.__color = nil -- (texture coordinates survive SetTexture, as in the game)
	Mock.textures[tostring(t)] = true
	return true
end
function Texture:GetTexture() return self.__tex end
function Texture:SetColorTexture(r, g, b, a)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetColorTexture: numbers expected")
	self.__tex = "color"
	self.__color = { r, g, b, a or 1 }
end
function Texture:SetTexCoord(...)
	local n = select("#", ...)
	check(n == 4 or n == 8, "SetTexCoord: 4 or 8 numbers expected")
	for i = 1, n do check(type((select(i, ...))) == "number", "SetTexCoord: numbers expected") end
	if n == 4 then self.__tc, self.__tc8 = { ... }, nil else self.__tc, self.__tc8 = nil, { ... } end
end
-- as the game: the corners, ULx, ULy, LLx, LLy, URx, URy, LRx, LRy
function Texture:GetTexCoord()
	if self.__tc8 then return unpack(self.__tc8) end
	local c = self.__tc or { 0, 1, 0, 1 }
	return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
end
function Texture:SetVertexColor(r, g, b, a)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetVertexColor: numbers expected")
	self.__vertex = { r, g, b, a or 1 }
end
function Texture:SetBlendMode(m) check(m == "ADD" or m == "BLEND" or m == "DISABLE" or m == "MOD" or m == "ALPHAKEY", "SetBlendMode: bad mode") end
function Texture:SetDrawLayer(l, sub) check(LAYERS[l], "SetDrawLayer: bad layer") self.__layer = l end
function Texture:SetDesaturated(v) self.__desat = v and true or nil end
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
	self.__color = { r, g, b, a or 1 }
end
function FontString:SetJustifyH(j) check(j == "LEFT" or j == "CENTER" or j == "RIGHT", "SetJustifyH: bad value " .. tostring(j)) self.__jh = j end
function FontString:SetJustifyV(j) check(j == "TOP" or j == "MIDDLE" or j == "BOTTOM", "SetJustifyV: bad value " .. tostring(j)) self.__jv = j end
function FontString:SetWordWrap(v) self.__nowrap = not v end
function FontString:SetNonSpaceWrap(v) end
function FontString:SetSpacing(n) check(type(n) == "number", "SetSpacing: number expected") self.__spacing = n end
function FontString:SetMaxLines(n) end
function FontString:SetShadowOffset(x, y) end
function FontString:SetShadowColor(r, g, b, a) end
function FontString:SetDrawLayer(l) check(LAYERS[l], "SetDrawLayer: bad layer") end
function FontString:GetStringWidth()
	check(self.__font, "GetStringWidth before SetFont")
	-- roughly what the game measures: a Hangul syllable about one em, Latin
	-- letters and digits a little over half
	local text = (self.__text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local w = 0
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		w = w + ((#ch > 1) and 1.0 or 0.55)
	end
	return w * self.__font[2]
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
	local t = setmetatable({ __widget = true, __type = "Texture", __points = {}, __anchors = {}, __shown = true, __parent = self, __name = name,
		__layer = layer or "ARTWORK" }, { __index = Texture })
	self.__regions[#self.__regions + 1] = t
	return t
end
function Frame:CreateFontString(name, layer, template)
	check(layer == nil or LAYERS[layer], "CreateFontString: bad layer " .. tostring(layer))
	local t = setmetatable({ __widget = true, __type = "FontString", __points = {}, __anchors = {}, __shown = true, __parent = self, __name = name, __text = "",
		__layer = layer or "ARTWORK" }, { __index = FontString })
	self.__regions[#self.__regions + 1] = t
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
function Frame:SetFrameStrata(s) check(STRATA[s], "SetFrameStrata: bad strata " .. tostring(s)) self.__strata = s end
function Frame:SetFrameLevel(l) check(type(l) == "number" and l >= 0, "SetFrameLevel: non-negative number expected") self.__level = l end
function Frame:GetFrameLevel() return self.__level or 1 end
function Frame:SetToplevel(v) end
function Frame:Raise() end
function Frame:Lower() end
function Frame:SetID(id) self.__id = id end
function Frame:GetID() return self.__id or 0 end
function Frame:IsMouseOver() return false end
function Frame:SetClipsChildren(v) self.__clips = v and true or nil end
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
for _, key in ipairs({ "Normal", "Pushed", "Highlight", "Disabled" }) do
	Button["Set" .. key .. "Texture"] = function(self, path, blend)
		check(type(path) == "string" or (type(path) == "table" and path.__widget), "Set" .. key .. "Texture: path or texture expected")
		check(blend == nil or blend == "ADD" or blend == "BLEND" or blend == "MOD", "Set" .. key .. "Texture: bad blend mode")
		self["__" .. key:lower() .. "Tex"] = path
	end
end

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

-- 3D model frames: they record what was put up and how it is shown
local Model = setmetatable({}, { __index = Frame })
function Model:SetCreature(id) check(type(id) == "number", "SetCreature: id must be a number") self.__model = "creature:" .. id end
function Model:SetDisplayInfo(id) check(type(id) == "number", "SetDisplayInfo: id must be a number") self.__model = "display:" .. id end
function Model:SetModel(f) check(type(f) == "number" or type(f) == "string", "SetModel: file id or path expected") self.__model = "file:" .. f end
function Model:SetUnit(unit) check(type(unit) == "string", "SetUnit: unit must be a string") self.__model = "unit:" .. unit end
function Model:ClearModel() self.__model = nil end
function Model:GetModelFileID() return self.__model and 123456 or nil end
-- the display id the model shows: the one put up, or one for the NPC
function Model:GetDisplayInfo()
	local m = self.__model or ""
	local d = m:match("^display:(%d+)$")
	if d then return tonumber(d) end
	local c = m:match("^creature:(%d+)$")
	if c then return 500000 + tonumber(c) end
	return 0
end
function Model:SetAnimation(id) check(type(id) == "number", "SetAnimation: id must be a number") self.__anim = id end
function Model:SetFacing(r) check(type(r) == "number", "SetFacing: radians must be a number") self.__facing = r end
function Model:SetCamDistanceScale(v) check(type(v) == "number" and v > 0, "SetCamDistanceScale: bad scale") self.__dist = v end
function Model:SetPortraitZoom(v) end
function Model:SetPosition(x, y, z) end
function Model:SetModelScale(v) end
function Model:ApplySpellVisualKit(kit, oneShot)
	check(type(kit) == "number" and kit > 0, "ApplySpellVisualKit: kit id expected")
	check(oneShot == nil or type(oneShot) == "boolean", "ApplySpellVisualKit: oneShot must be a boolean")
	self.__kit = kit
	Mock.kits[#Mock.kits + 1] = kit
end
local DressUpModel = setmetatable({}, { __index = Model })
function DressUpModel:SetCustomRace(race, sex)
	check(self.__model ~= nil, "SetCustomRace before a unit is set")
	check(type(race) == "number", "SetCustomRace: race must be a number")
	self.__race, self.__sex = race, sex
end
function DressUpModel:Undress() self.__worn = {} end
function DressUpModel:TryOn(link)
	check(type(link) == "string" or type(link) == "number", "TryOn: bad item")
	self.__worn = self.__worn or {}
	self.__worn[#self.__worn + 1] = link
	return true
end
Mock.Model, Mock.DressUpModel = Model, DressUpModel

-- ModelScene frames and their actors. Calls with bad arguments are noted in
-- Mock.misuse as well as raised (the addon calls these through pcall).
Mock.misuse = {}
local function strict(cond, msg)
	if not cond then
		Mock.misuse[#Mock.misuse + 1] = msg
		error(msg, 3)
	end
end
local function nums(n, ...)
	for i = 1, n do if type(select(i, ...)) ~= "number" then return false end end
	return true
end
-- display ids this mock game lacks, and the bounding box a display stands in
Mock.missingDisplays = {}
Mock.boxes = {}
-- the player's gender (2 = male, 3 = female)
Mock.playerSex = 2
function UnitSex(unit) return unit == "player" and Mock.playerSex or 2 end
local Actor = {}
function Actor:SetModelByCreatureDisplayID(id, useActivePlayerCustomizations)
	strict(type(id) == "number" and id > 0, "SetModelByCreatureDisplayID: display id expected")
	strict(useActivePlayerCustomizations == nil or type(useActivePlayerCustomizations) == "boolean", "SetModelByCreatureDisplayID: a boolean expected")
	self.__display = id
	self.__mine = useActivePlayerCustomizations or nil
	return true
end
-- a model file (a spell's effect or missile) by its file id
function Actor:SetModelByFileID(id)
	strict(type(id) == "number" and id > 0, "SetModelByFileID: file id expected")
	self.__display = "file:" .. id
	return true
end
-- the unit's model (the race given by customRaceID, the 7th argument)
function Actor:SetModelByUnit(unit, sheathe, autoDress, hideWeapons, native, holdBow, raceId)
	strict(type(unit) == "string", "SetModelByUnit: unit expected")
	strict(raceId == nil or type(raceId) == "number", "SetModelByUnit: customRaceID must be a number")
	self.__display = "unit:" .. unit
	self.__race, self.__dressed, self.__noWeapons = raceId, autoDress ~= false, hideWeapons and true or false
	return true
end
function Actor:SetDesaturation(v) strict(type(v) == "number" and v >= 0 and v <= 1, "actor SetDesaturation: 0..1 expected") self.__desat = v end
function Actor:GetDesaturation() return self.__desat or 0 end
function Actor:Undress() self.__worn, self.__hands = {}, {} end
-- an item on (a hand slot name puts a weapon in that hand)
local HAND = { MAINHANDSLOT = true, SECONDARYHANDSLOT = true }
function Actor:TryOn(link, hand)
	strict(type(link) == "string" or type(link) == "number", "TryOn: item link or id expected")
	strict(hand == nil or HAND[hand], "TryOn: hand slot must be MAINHANDSLOT or SECONDARYHANDSLOT")
	self.__worn = self.__worn or {}
	self.__worn[#self.__worn + 1] = link
	if hand then
		self.__hands = self.__hands or {}
		self.__hands[hand] = link
	end
	return true
end
-- spell visual kits played on an actor: none clears; Mock.kits notes them
Mock.kits = {}
function Actor:SetSpellVisualKit(kit, oneShot)
	strict(kit == nil or (type(kit) == "number" and kit > 0), "SetSpellVisualKit: kit id expected")
	strict(oneShot == nil or type(oneShot) == "boolean", "SetSpellVisualKit: oneShot must be a boolean")
	self.__kit = kit
	if kit then Mock.kits[#Mock.kits + 1] = kit end
end
function Actor:ClearModel() self.__display = nil self.__in = nil end
-- the game brings a model in only while its scene is shown: a model put up
-- in a hidden scene stays out until the scene is shown
function Actor:IsLoaded()
	if self.__display == nil or Mock.missingDisplays[self.__display] then return false end
	if self.__in ~= self.__display then
		if self.__scene and self.__scene.IsVisible and not self.__scene:IsVisible() then return false end
		self.__in = self.__display
	end
	return true
end
-- the model file a display id brings up (Mock.displayFile; any other: 123456)
Mock.displayFile = {}
function Actor:GetModelFileID()
	if not self:IsLoaded() then return 0 end
	return Mock.displayFile[self.__display] or 123456
end
function Actor:GetActiveBoundingBox()
	if not self:IsLoaded() then return 0, 0, 0, 0, 0, 0 end
	local b = Mock.boxes[self.__display] or { -0.4, -0.3, 0, 0.5, 0.3, 2.0 }
	return b[1], b[2], b[3], b[4], b[5], b[6]
end
function Actor:SetScale(v) strict(type(v) == "number" and v > 0, "actor SetScale: positive number expected") self.__scale = v end
function Actor:GetScale() return self.__scale or 1 end
function Actor:SetYaw(v) strict(type(v) == "number", "actor SetYaw: radians expected") self.__yaw = v end
function Actor:GetYaw() return self.__yaw or 0 end
function Actor:SetPosition(x, y, z) strict(nums(3, x, y, z), "actor SetPosition: x, y, z expected") self.__pos = { x, y, z } end
function Actor:GetPosition() local p = self.__pos or { 0, 0, 0 } return p[1], p[2], p[3] end
function Actor:SetAnimation(id) strict(type(id) == "number", "actor SetAnimation: id expected") self.__anim = id end
function Actor:SetAlpha(v) strict(type(v) == "number", "actor SetAlpha: number expected") self.__alpha = v end
function Actor:Show() self.__shown = true end
function Actor:Hide() self.__shown = false end
local ModelScene = setmetatable({}, { __index = Frame })
function ModelScene:CreateActor()
	local a = setmetatable({ __scene = self, __shown = true }, { __index = Actor })
	self.__actors = self.__actors or {}
	self.__actors[#self.__actors + 1] = a
	return a
end
function ModelScene:SetCameraOrientationByYawPitchRoll(y, p, r)
	strict(nums(3, y, p, r), "SetCameraOrientationByYawPitchRoll: three numbers expected")
	self.__camYaw = y
end
function ModelScene:GetCameraForward() local y = self.__camYaw or 0 return math.cos(y), math.sin(y), 0 end
function ModelScene:GetCameraRight() local y = self.__camYaw or 0 return math.sin(y), -math.cos(y), 0 end
function ModelScene:SetCameraPosition(x, y, z) strict(nums(3, x, y, z), "SetCameraPosition: x, y, z expected") self.__camPos = { x, y, z } end
function ModelScene:SetCameraFieldOfView(v) strict(type(v) == "number" and v > 0 and v < math.pi, "SetCameraFieldOfView: radians expected") self.__fov = v end
function ModelScene:SetCameraNearClip(v) strict(type(v) == "number" and v > 0, "SetCameraNearClip: number expected") end
function ModelScene:SetCameraFarClip(v) strict(type(v) == "number" and v > 0, "SetCameraFarClip: number expected") end
function ModelScene:SetLightVisible(v) strict(type(v) == "boolean", "SetLightVisible: boolean expected") end
function ModelScene:SetLightType(v) strict(type(v) == "number", "SetLightType: number expected") end
function ModelScene:SetLightDirection(x, y, z) strict(nums(3, x, y, z), "SetLightDirection: x, y, z expected") end
function ModelScene:SetAllowOverlappedModels(v) strict(type(v) == "boolean", "SetAllowOverlappedModels: boolean expected") self.__overlap = v end
function ModelScene:GetAllowOverlappedModels() return self.__overlap or false end
function ModelScene:SetLightAmbientColor(r, g, b) strict(nums(3, r, g, b), "SetLightAmbientColor: r, g, b expected") end
function ModelScene:SetLightDiffuseColor(r, g, b) strict(nums(3, r, g, b), "SetLightDiffuseColor: r, g, b expected") end
-- The game's projection: a camera with the field of view it was given that
-- draws the scene Mock.projMag times larger than a plain pinhole camera
-- would (what the game was seen to do); answers in frame units from the
-- frame's bottom-left corner, screen right along GetCameraRight.
Mock.projMag = 1.25
-- how the mock game answers: units per frame unit (projK), y from the top
-- (projDown), and a shift of the drawn picture in frame units (projShift)
Mock.projK, Mock.projDown, Mock.projShift = 1, false, nil
function ModelScene:Project3DPointTo2D(x, y, z)
	strict(nums(3, x, y, z), "Project3DPointTo2D: x, y, z expected")
	local c = self.__camPos
	if not c or not self.__fov then return nil end
	local fx, fy, fz = self:GetCameraForward()
	local rx, ry, rz = self:GetCameraRight()
	local vx, vy, vz = x - c[1], y - c[2], z - c[3]
	local depth = vx * fx + vy * fy + vz * fz
	if depth <= 0 then return nil end
	local t = math.tan(self.__fov / 2) * depth / Mock.projMag
	local u, v = (vx * rx + vy * ry + vz * rz) / t, vz / t
	local w, h = self:GetWidth(), self:GetHeight()
	local px, py = w / 2 + u * w / 2, h / 2 + v * h / 2
	if Mock.projShift then px, py = px + Mock.projShift[1], py + Mock.projShift[2] end
	if Mock.projDown then py = h - py end
	return px * Mock.projK, py * Mock.projK, depth
end
Mock.ModelScene, Mock.Actor = ModelScene, Actor
-- a client without ModelScene: creating one fails
Mock.noModelScene = false

local CLASSES = { Frame = Frame, Button = Button, CheckButton = Button, ScrollFrame = ScrollFrame, StatusBar = Frame, EditBox = Frame,
	PlayerModel = Model, DressUpModel = DressUpModel, ModelScene = ModelScene }

function _G.CreateFrame(ftype, name, parent, template)
	check(FRAME_TYPES[ftype], "CreateFrame: unknown frame type " .. tostring(ftype))
	check(not (ftype == "ModelScene" and Mock.noModelScene), "CreateFrame: unknown frame type ModelScene")
	check(name == nil or type(name) == "string", "CreateFrame: name must be a string or nil")
	check(parent == nil or (type(parent) == "table" and parent.__widget), "CreateFrame: parent must be a frame or nil")
	check(template == nil or template == "BackdropTemplate", "CreateFrame: unexpected template " .. tostring(template))
	local class = CLASSES[ftype]
	local f = setmetatable({
		__widget = true, __type = ftype, __points = {}, __anchors = {}, __shown = true, __parent = parent, __name = name,
		__scripts = {}, __events = {}, __children = {}, __regions = {},
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
_G.GetPhysicalScreenSize = function() return 2560, 1440 end
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

------------------------------------------------------------------------
-- Layout preview: everything currently visible, as a flat JSON-ready list
-- (tests/preview.py turns it into a picture).
------------------------------------------------------------------------
function Mock.Export()
	local ids, n = {}, 0
	local function id(w)
		if not w then return 0 end
		if not ids[w] then
			n = n + 1
			ids[w] = n
		end
		return ids[w]
	end
	local out = {}
	local function anchors(w)
		local list = {}
		for _, a in ipairs(w.__anchors) do
			if a[1] == "ALL" then
				list[#list + 1] = { "ALL", id(a[2]) }
			else
				list[#list + 1] = { a[1], id(a[2]), a[3], a[4], a[5] }
			end
		end
		return list
	end
	local function add(w, kind, order)
		local e = {
			id = id(w), kind = kind, parent = id(w.__parent), w = w.__w or 0, h = w.__h or 0,
			alpha = w.__alpha or 1, anchors = anchors(w), order = order, scale = w.__scale or 1,
		}
		if kind == "texture" then
			e.layer = w.__layer
			e.color = w.__color
			e.tex = (w.__tex ~= "color") and w.__tex or nil
			e.vertex = w.__vertex
			e.tc = w.__tc
			e.tc8 = w.__tc8
			e.desat = w.__desat
			e.overlay = w.isOverlay or false -- moving scenery under everything
		elseif kind == "text" then
			e.layer = w.__layer
			e.text = w.__text
			e.size = w.__font and w.__font[2] or 12
			e.color = w.__color
			e.jh = w.__jh or "CENTER"
			e.jv = w.__jv or "MIDDLE"
			e.nowrap = w.__nowrap or false
			e.moving = w.moving or false
			e.overlay = w.isOverlay or false -- a message drawn over the scene on purpose
		else
			e.badge = w.isBadge or false
			e.overlay = w.isOverlay or false
			e.popup = w.isPopup or false
			e.strata = w.__strata
			e.level = w.__level
			e.ftype = w.__type
			e.nomouse = (w.__mouse == false)
			-- a thing to pick, or a button repeated on every row of a list
			local inRow = false
			local a = w.__parent
			while a do
				if a.isItem or a.isRow then inRow = true break end
				a = a.__parent
			end
			e.item = w.isItem or inRow
			e.catcher = w.isCatcher or false
			e.clips = w.__clips or false
			e.click = (w.__scripts and w.__scripts.OnClick) and true or false
			e.off = w.__disabled or false
		end
		out[#out + 1] = e
	end
	local order = 0
	local function walk(f)
		if not f.__shown then return end
		order = order + 1
		add(f, "frame", order)
		for _, r in ipairs(f.__regions) do
			if r.__shown then
				order = order + 1
				add(r, r.__type == "Texture" and "texture" or "text", order)
			end
		end
		for _, c in ipairs(f.__children) do walk(c) end
	end
	for _, f in ipairs(Mock.frames) do
		if not f.__parent then walk(f) end
	end
	return out, id(UIParent)
end

local function json(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for i = 1, #v do parts[i] = json(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do parts[#parts + 1] = string.format("%q", tostring(k)) .. ":" .. json(x) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			if c == "\n" then return "\\n" end
			if c == '"' then return '\\"' end
			if c == "\\" then return "\\\\" end
			return string.format("\\u%04x", c:byte())
		end) .. '"'
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		return string.format("%.4f", v)
	elseif t == "boolean" then
		return v and "true" or "false"
	end
	return "null"
end

function Mock.ExportJSON()
	local list, root = Mock.Export()
	return '{"root":' .. root .. ',"items":' .. json(list) .. "}"
end

return Mock
