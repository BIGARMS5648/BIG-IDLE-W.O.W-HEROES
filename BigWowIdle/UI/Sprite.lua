-- Animated sprites from the imported art (Data/Art.lua, Media/Art/).
-- Everything here is optional: when an asset has not been imported the
-- lookups return nil and callers keep their built-in look.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local UI = ns.UI

local Sprite = {}
ns.Sprite = Sprite

Sprite.PATH = UI.MEDIA .. "Art\\"

-- frames per second, and whether the animation repeats
local ANIM = {
	idle = { fps = 6, loop = true },
	walk = { fps = 10, loop = true },
	attack = { fps = 14, loop = false },
	cast = { fps = 10, loop = false },
	hit = { fps = 12, loop = false },
	death = { fps = 8, loop = false },
}
-- what to play when a sheet lacks an animation
local FALLBACK = { cast = "attack", attack = "idle", hit = "idle", walk = "idle", death = "idle" }

-- How tall each body is drawn relative to an ordinary hero.
Sprite.RACE_SCALE = { GNOME = 0.78, GOBLIN = 0.82, DWARF = 0.9, TAUREN = 1.12, DRAENEI = 1.05, NIGHTELF = 1.04, TROLL = 1.06 }

local function art() return ns.ART or {} end

function Sprite.Get(id)
	local s = art().sprites
	return id and s and s[id]
end

function Sprite.FX(id)
	local s = art().fx
	return id and s and s[id]
end

function Sprite.Background(theme)
	local s = art().bg
	return theme and s and s[theme]
end

function Sprite.Icon(id)
	local s = art().icons
	local e = id and s and s[id]
	return e and (Sprite.PATH .. e.file) or nil
end

------------------------------------------------------------------------
-- Which sprite a thing uses
------------------------------------------------------------------------
local FORM = { DRUID_GUARDIAN = "bear", DRUID_FERAL = "cat", DRUID_BALANCE = "moonkin", DRUID_RESTO = "treant" }

-- Hero sprite: druids fight in their form, mech tinkers in their mech.
-- inCombat=false gives the hero's own body (menus, portraits).
function Sprite.ForHero(heroId, inCombat)
	local h = ns.db and ns.db.heroes[heroId]
	if not h then return nil end
	local sp = ns.SPECS[h.spec]
	local faction = (ns.Faction() or "ALLIANCE"):lower()
	if inCombat ~= false then
		local form = FORM[h.spec]
		if form then
			local id = "form_" .. form .. "_" .. faction
			if Sprite.Get(id) then return id end
			id = "form_" .. form .. "_alliance"
			if Sprite.Get(id) then return id end
		end
		if h.spec == "TINKER_MECH" then
			local id = "mech_" .. faction
			if Sprite.Get(id) then return id end
		end
	end
	local base = "hero_" .. sp.class:lower() .. "_" .. faction .. "_"
	local id = base .. (h.sex == "F" and "f" or "m")
	if Sprite.Get(id) then return id end
	id = base .. (h.sex == "F" and "m" or "f") -- the other gender beats no picture
	if Sprite.Get(id) then return id end
	return nil
end

function Sprite.HeroScale(heroId)
	local race = ns.Heroes.Race(heroId)
	return Sprite.RACE_SCALE[race] or 1
end

-- monster id -> sprite id, built from the "game.monsters" lists of the art
local mobIndex, mobIndexFor
local function buildMobIndex()
	mobIndex = {}
	for id, s in pairs(art().sprites or {}) do
		local g = s.game
		if g and g.monsters then
			for _, m in ipairs(g.monsters) do mobIndex[m] = id end
		end
		if g and g.boss then mobIndex["boss:" .. g.boss] = id end
	end
	mobIndexFor = art().sprites
end

-- The twelve raid bosses (last zone of each act) have drawings of their own.
local RAID_ART = {
	{ "라그나로스", "ragnaros" }, { "크툰", "cthun" }, { "켈투자드", "kelthuzad" }, { "마그테리돈", "magtheridon" },
	{ "캘타스", "kaelthas" }, { "킬제덴", "kiljaeden" }, { "말리고스", "malygos" }, { "요그사론", "yoggsaron" },
	{ "리치 왕", "lichking" }, { "데스윙", "deathwing" }, { "가로쉬", "garrosh" }, { "아르거스", "argus" },
}
function Sprite.BossKey(name)
	name = ns.N(name) or ""
	for _, e in ipairs(RAID_ART) do
		if name:find(e[1], 1, true) then return e[2] end
	end
end

-- Other bosses borrow the drawing of their creature type.
local TYPE_ART = {
	beast = "mob_bigcat", humanoid = "mob_bandit", undead = "mob_dk", elemental = "mob_fire_elemental",
	demon = "mob_demon", dragonkin = "mob_drake", mechanical = "mob_golem", giant = "mob_giant", aberration = "mob_faceless",
}

function Sprite.ForMonster(monsterId, bossKey, bossType)
	if mobIndexFor ~= art().sprites then buildMobIndex() end
	local id = (bossKey and mobIndex["boss:" .. bossKey]) or (monsterId and mobIndex[monsterId])
	if not id and bossType and TYPE_ART[bossType] and Sprite.Get(TYPE_ART[bossType]) then id = TYPE_ART[bossType] end
	return id
end

function Sprite.ForSkill(skillId)
	local sk = ns.SKILLS[skillId]
	if not sk then return nil end
	if sk.summon and Sprite.Get(sk.summon) then return sk.summon end
	for id, s in pairs(art().sprites or {}) do
		if s.game and s.game.skill == skillId then return id end
	end
end

function Sprite.ForPet(petId)
	local id = "pet_" .. tostring(petId)
	return Sprite.Get(id) and id or nil
end

-- Effects by damage school.
local PROJ = { phys = "proj_arrow", fire = "proj_fire", frost = "proj_frost", shadow = "proj_shadow",
	arcane = "proj_arcane", holy = "proj_holy", nature = "proj_nature" }
local HIT = { phys = "hit_phys", fire = "hit_fire", frost = "hit_frost", shadow = "hit_shadow",
	arcane = "hit_arcane", holy = "hit_holy", nature = "hit_nature" }
local FIELD = { phys = "field_whirl", fire = "field_fire", frost = "field_frost", shadow = "field_shadow",
	arcane = "field_arcane", holy = "field_holy", nature = "field_nature" }
Sprite.FIELD_OVERRIDE = { volley = "field_arrows", explosive_trap = "field_fire", goblin_mortar = "field_fire" }

function Sprite.Projectile(school, gun)
	if gun and Sprite.FX("proj_bullet") then return "proj_bullet" end
	local id = PROJ[school or "phys"]
	return Sprite.FX(id) and id or nil
end

function Sprite.Impact(school)
	local id = HIT[school or "phys"]
	return Sprite.FX(id) and id or nil
end

function Sprite.Field(skillId, school)
	local id = Sprite.FIELD_OVERRIDE[skillId] or FIELD[school or "phys"]
	return Sprite.FX(id) and id or nil
end

------------------------------------------------------------------------
-- Texture coordinates
------------------------------------------------------------------------
local function cellCoords(e, k, flip)
	local col = k % e.cols
	local row = floor(k / e.cols)
	local l, r = col * e.cw / e.w, (col + 1) * e.cw / e.w
	local t, b = row * e.ch / e.h, (row + 1) * e.ch / e.h
	if flip then l, r = r, l end
	return l, r, t, b
end
Sprite.CellCoords = cellCoords

------------------------------------------------------------------------
-- Animated sprite widget
--   s = Sprite.New(parent, height)   height = on-screen height of one cell
--   s:SetSprite(id)  s:Play(anim)  s:SetFacing("right"|"left")  s:Step(dt)
--   s:PlaceFeet(anchorFrame, x, y)   puts the feet at (x, y) of anchorFrame
------------------------------------------------------------------------
local proto = {}

function Sprite.New(parent, height, layer)
	local f = CreateFrame("Frame", nil, parent)
	for k, v in pairs(proto) do f[k] = v end
	f.tex = f:CreateTexture(nil, layer or "ARTWORK")
	f.tex:SetAllPoints(f)
	f.height = height or 64
	f.facing = "right"
	f.anim, f.k, f.t = "idle", 0, 0
	f:SetSize(f.height, f.height)
	f:Hide()
	return f
end

function proto:SetSprite(id)
	if self.id == id then return self.entry ~= nil end
	self.id = id
	self.entry = Sprite.Get(id)
	if not self.entry then return false end
	local e = self.entry
	self.tex:SetTexture(Sprite.PATH .. e.file)
	local w = self.height * e.cw / e.ch
	self:SetSize(w, self.height)
	self.anim, self.k, self.t = nil, 0, 0
	self:Play("idle")
	return true
end

function proto:SetHeight2(h)
	self.height = h
	if self.entry then
		self:SetSize(h * self.entry.cw / self.entry.ch, h)
	else
		self:SetSize(h, h)
	end
end

function proto:SetFacing(dir)
	self.facing = dir
	self:Draw()
end

local function resolve(e, anim)
	local guard = 0
	while anim and not e.anims[anim] and guard < 4 do
		anim = FALLBACK[anim]
		guard = guard + 1
	end
	return anim and e.anims[anim] and anim or nil
end

-- restart=true replays a one-shot animation already playing
function proto:Play(anim, restart)
	local e = self.entry
	if not e then return end
	local real = resolve(e, anim)
	if not real then return end
	if self.anim == real and not restart and (ANIM[real] or {}).loop then return end
	if self.anim == real and not restart and not self.done then return end
	self.anim, self.want, self.k, self.t, self.done = real, anim, 0, 0, false
	self:Draw()
end

function proto:Playing()
	return self.anim, self.done
end

function proto:Step(dt)
	local e = self.entry
	if not e or not self.anim then return end
	local a = e.anims[self.anim]
	local spec = ANIM[self.anim] or ANIM.idle
	self.t = self.t + dt
	local step = 1 / spec.fps
	if self.t >= step then
		local n = floor(self.t / step)
		self.t = self.t - n * step
		local k = self.k + n
		if k >= a[2] then
			if spec.loop then
				k = k % a[2]
			else
				k = a[2] - 1
				self.done = true
			end
		end
		if k ~= self.k then
			self.k = k
			self:Draw()
		end
	end
end

function proto:Draw()
	local e = self.entry
	if not e or not self.anim then return end
	local a = e.anims[self.anim]
	local flip = (e.facing or "right") ~= self.facing
	self.tex:SetTexCoord(cellCoords(e, a[1] + min(self.k, a[2] - 1), flip))
end

-- Feet at (x, y) relative to the anchor frame's bottom-left corner.
function proto:PlaceFeet(anchor, x, y)
	local e = self.entry
	local foot = e and e.foot or 0
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", anchor, "BOTTOMLEFT", x, y - foot * self.height)
end

------------------------------------------------------------------------
-- One-shot effect widget (projectile, impact, field): plays its frames once
-- (or loops for `life` seconds) and hides itself.
------------------------------------------------------------------------
local fxProto = {}

function Sprite.NewFX(parent, layer)
	local f = CreateFrame("Frame", nil, parent)
	for k, v in pairs(fxProto) do f[k] = v end
	f.tex = f:CreateTexture(nil, layer or "OVERLAY")
	f.tex:SetAllPoints(f)
	f:Hide()
	return f
end

-- id: fx id; w, h: size on screen; life: seconds (nil = one pass); fps
function fxProto:Start(id, w, h, life, fps)
	local e = Sprite.FX(id)
	if not e then return false end
	self.entry = e
	self.tex:SetTexture(Sprite.PATH .. e.file)
	self:SetSize(w, h)
	self.fps = fps or 14
	self.life = life or (e.n / self.fps)
	self.t = 0
	self.active = true
	self:Frame(0)
	self:Show()
	return true
end

function fxProto:Frame(k)
	local e = self.entry
	self.tex:SetTexCoord(cellCoords(e, k % e.n, self.flip))
end

-- returns false once finished
function fxProto:Step(dt)
	if not self.active then return false end
	self.t = self.t + dt
	if self.t >= self.life then
		self.active = false
		self:Hide()
		return false
	end
	self:Frame(floor(self.t * self.fps))
	return true
end

function fxProto:Stop()
	self.active = false
	self:Hide()
end

------------------------------------------------------------------------
-- Scrolling two-layer background for the battle scene. Each layer is drawn
-- as two textures whose texture coordinates wrap around, so no clipping is
-- needed. Returns nil when the theme has no imported background.
------------------------------------------------------------------------
local bgProto = {}

function Sprite.NewBackground(scene, w, h)
	local b = { scene = scene, w = w, h = h, off = { 0, 0 } }
	for k, v in pairs(bgProto) do b[k] = v end
	b.layers = {}
	for i, lay in ipairs({ "BACKGROUND", "BORDER" }) do
		local L = { scene:CreateTexture(nil, lay, nil, i), scene:CreateTexture(nil, lay, nil, i) }
		L[1]:Hide()
		L[2]:Hide()
		b.layers[i] = L
	end
	return b
end

-- true if the theme has art
function bgProto:SetTheme(theme)
	if self.theme == theme then return self.ok end
	self.theme = theme
	local e = Sprite.Background(theme)
	self.ok = e ~= nil and (e.far ~= nil or e.near ~= nil)
	self.entry = e
	for i, key in ipairs({ "far", "near" }) do
		local L = self.layers[i]
		local part = e and e[key]
		if part then
			L[1]:SetTexture(Sprite.PATH .. part.file)
			L[2]:SetTexture(Sprite.PATH .. part.file)
			L.part = part
		else
			L.part = nil
			L[1]:Hide()
			L[2]:Hide()
		end
	end
	self:Draw()
	return self.ok
end

-- dx: how far the party walked (scene pixels); the far layer moves slower
function bgProto:Scroll(dx)
	self.off[1] = (self.off[1] + dx * 0.25) % self.w
	self.off[2] = (self.off[2] + dx) % self.w
	self:Draw()
end

function bgProto:Draw()
	for i = 1, 2 do
		local L = self.layers[i]
		local part = L.part
		if part then
			-- one copy of the texture spans `span` scene pixels; when the texture is
			-- too short for the scene it is cropped vertically instead of stretched
			local span = self.h * part.w / part.h
			local v0, v1 = 0, 1
			if span < self.w then
				span = self.w
				local frac = (part.w * self.h / self.w) / part.h
				if i == 1 then v0 = (1 - frac) * 0.6 else v0 = 1 - frac end
				v1 = v0 + frac
			end
			local o = (self.off[i] % span) / span -- 0..1 into the texture
			local w1 = (1 - o) * span
			L[1]:ClearAllPoints()
			L[1]:SetPoint("BOTTOMLEFT", self.scene, "BOTTOMLEFT", 0, 0)
			L[1]:SetSize(max(1, min(self.w, w1)), self.h)
			L[1]:SetTexCoord(o, min(1, o + self.w / span), v0, v1)
			L[1]:Show()
			if w1 < self.w then
				local rest = self.w - w1
				L[2]:ClearAllPoints()
				L[2]:SetPoint("BOTTOMLEFT", self.scene, "BOTTOMLEFT", w1, 0)
				L[2]:SetSize(rest, self.h)
				L[2]:SetTexCoord(0, rest / span, v0, v1)
				L[2]:Show()
			else
				L[2]:Hide()
			end
		end
	end
end

function bgProto:Hide()
	for i = 1, 2 do
		self.layers[i][1]:Hide()
		self.layers[i][2]:Hide()
	end
end
