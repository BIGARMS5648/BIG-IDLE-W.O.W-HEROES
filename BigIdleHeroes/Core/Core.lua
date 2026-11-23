-- BIG IDLE HEROES - core namespace, language, event bus and utilities.
local ADDON, ns = ...
ns = ns or {}
ns.ADDON = ADDON or "BigIdleHeroes"
ns.VERSION = "1.0.4"

local floor, max, min, random = math.floor, math.max, math.min, math.random
local format = string.format

------------------------------------------------------------------------
-- Text. The addon is Korean only. On a client of another language the
-- standard font may have no Hangul glyphs, so the Korean font is used.
------------------------------------------------------------------------
function ns.SetupFont()
	if GetLocale and GetLocale() == "koKR" then
		ns.FONT = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
	else
		ns.FONT = "Fonts\\2002.TTF"
	end
end
ns.SetupFont()

-- Names are plain strings; saves from older versions may still hold
-- { korean, english } pairs, of which the Korean half is used.
function ns.N(t)
	if type(t) == "table" then return t[1] end
	return t
end

------------------------------------------------------------------------
-- Tiny event bus so systems never have to know about the UI.
------------------------------------------------------------------------
local listeners = {}

function ns.On(ev, fn)
	local l = listeners[ev]
	if not l then
		l = {}
		listeners[ev] = l
	end
	l[#l + 1] = fn
end

function ns.Fire(ev, ...)
	local l = listeners[ev]
	if not l then return end
	for i = 1, #l do
		l[i](...)
	end
end

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------
local U = {}
ns.U = U

function U.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function U.round(v)
	return floor(v + 0.5)
end

local function commas(n)
	local s = format("%d", n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

-- 1234 -> "1,234"; 123456 -> "123.5K"; then M, B, T.
function U.fmt(n)
	n = n or 0
	local neg = n < 0
	if neg then n = -n end
	local s
	if n < 100000 then
		s = commas(floor(n + 0.5))
	elseif n < 1e6 then
		s = format("%.1fK", n / 1e3)
	elseif n < 1e9 then
		s = format("%.2fM", n / 1e6)
	elseif n < 1e12 then
		s = format("%.2fB", n / 1e9)
	else
		s = format("%.2fT", n / 1e12)
	end
	if neg then s = "-" .. s end
	return s
end

-- Trim trailing zeros: 12.50 -> "12.5", 3.00 -> "3".
function U.num(v, digits)
	local s = format("%." .. (digits or 1) .. "f", v)
	if s:find("%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s
end

function U.time(sec)
	sec = floor(sec or 0)
	local h = floor(sec / 3600)
	local m = floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return format("%d시간 %d분", h, m)
	elseif m > 0 then
		return format("%d분 %d초", m, s)
	end
	return format("%d초", s)
end

function U.col(hex, text)
	return "|cff" .. hex .. tostring(text) .. "|r"
end

function U.rgb(hex)
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function U.rnd(a, b)
	return a + (b - a) * random()
end

function U.pick(list)
	local n = #list
	if n == 0 then return nil end
	return list[random(1, n)]
end

-- list of entries with a numeric weight field (default "w"); returns one entry.
function U.weighted(list, key)
	key = key or "w"
	local total = 0
	for i = 1, #list do
		total = total + (list[i][key] or 0)
	end
	if total <= 0 then return list[1] end
	local r = random() * total
	for i = 1, #list do
		r = r - (list[i][key] or 0)
		if r <= 0 then return list[i] end
	end
	return list[#list]
end

-- weights given as a plain array of numbers; returns the chosen index.
function U.weightedIndex(weights)
	local total = 0
	for i = 1, #weights do
		total = total + weights[i]
	end
	if total <= 0 then return 1 end
	local r = random() * total
	for i = 1, #weights do
		r = r - weights[i]
		if r <= 0 then return i end
	end
	return #weights
end

function U.copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do
		out[k] = U.copy(v)
	end
	return out
end

function U.count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

function U.contains(list, v)
	for i = 1, #list do
		if list[i] == v then return true end
	end
	return false
end

------------------------------------------------------------------------
-- Messages: a short in-addon log plus a toast on the battle bar.
------------------------------------------------------------------------
ns.log = {}

function ns.Log(msg)
	local l = ns.log
	l[#l + 1] = msg
	if #l > 60 then
		table.remove(l, 1)
	end
	ns.Fire("LOG", msg)
end

function ns.Toast(msg)
	ns.Log(msg)
	ns.Fire("TOAST", msg)
end

function ns.Print(msg)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[B.I.H]|r " .. tostring(msg))
	end
end

function ns.Sound(kind)
	if not (ns.db and ns.db.ui and ns.db.ui.sound) then return end
	if not (PlaySound and SOUNDKIT) then return end
	local id
	if kind == "level" then
		id = SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_FIRSTTRAIT or SOUNDKIT.IG_QUEST_LIST_COMPLETE
	elseif kind == "loot" then
		id = SOUNDKIT.LOOT_WINDOW_COIN_SOUND or SOUNDKIT.IG_BACKPACK_COIN_OK
	elseif kind == "click" then
		id = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	elseif kind == "boss" then
		id = SOUNDKIT.RAID_WARNING
	end
	if id then
		pcall(PlaySound, id)
	end
end
