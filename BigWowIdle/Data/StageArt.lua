-- Pictures for the stage screen, in Media/Stages/:
--   w1 .. w4         a world's card (모험의 시작 .. 최후의 결전)
--   s1_01 .. s4_30   a stage's banner (difficulty, stage 01..30)
-- 1024x256 (or 512x128) TGA. Only the names listed in ns.ART_READY are used
-- (true: its own file; a name: that picture instead, for stages that share
-- one); the others keep the drawn scenery of their theme.
local _, ns = ...

ns.ART_READY = {
	-- w1 = true,
	-- s1_01 = true,
	-- s3_12 = "s3_11",
}

local DIR = "Interface\\AddOns\\BigWowIdle\\Media\\Stages\\"

local function file(name)
	local v = ns.ART_READY[name]
	if v == true then return DIR .. name .. ".tga" end
	if type(v) == "string" and ns.ART_READY[v] == true then return DIR .. v .. ".tga" end
end

function ns.WorldArtName(d) return "w" .. d end
function ns.StageArtName(d, idx) return string.format("s%d_%02d", d, idx) end

-- the picture's path, or nil when it has none
function ns.WorldArt(d) return file(ns.WorldArtName(d)) end
function ns.StageArt(d, idx) return file(ns.StageArtName(d, idx)) end
