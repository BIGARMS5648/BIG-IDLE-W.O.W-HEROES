-- 3D figures for the battle bar: the game's own models (PlayerModel with an
-- NPC id from Data/Models.lua) driven like the drawn sprites (UI/Sprite.lua),
-- with the same calls: SetHeight2, SetFacing, Play, Playing, Step, PlaceFeet.
-- A model the client cannot load is remembered and the bar falls back to the
-- sprite or the icon for it. Settings: db.opt.models = false turns them off.
local _, ns = ...

local pi, min = math.pi, math.min
local Figure = {}
ns.Figure3D = Figure

-- animation ids of the game's models, and how long the one-shots last
local ANIM_ID = { idle = 0, walk = 4, attack = 17, cast = 53, hit = 9, death = 1, dead = 6 }
local ONESHOT = { attack = 0.7, cast = 0.9, hit = 0.35, death = 1.2 }
-- right = toward the monsters (checked in game with /bwi model: 90° faces right)
local FACE = { right = pi / 2, left = 3 * pi / 2 }
local LOAD_WAIT = 1.5 -- seconds before a model that shows nothing counts as missing

local failed = {} -- [npc id] = true when the client could not load it

function Figure.Enabled()
	return ns.db and ns.db.opt and ns.db.opt.models ~= false
end

local function usable(id) return id and not failed[id] and id or nil end

------------------------------------------------------------------------
-- Which model a thing uses
------------------------------------------------------------------------
local FORM = { DRUID_GUARDIAN = "bear", DRUID_FERAL = "cat", DRUID_BALANCE = "moonkin", DRUID_RESTO = "tree" }

-- A hero: druids fight in their form, the mech tinker in the mech
-- (inCombat=false gives the hero's own body).
function Figure.ForHero(heroId, inCombat)
	local h = ns.db and ns.db.heroes[heroId]
	if not h then return nil end
	local sp = ns.SPECS[h.spec]
	local faction = ns.Faction() or "ALLIANCE"
	if inCombat ~= false then
		local form = FORM[h.spec]
		if form and usable(ns.MODEL.form[form]) then return ns.MODEL.form[form] end
		if h.spec == "TINKER_MECH" then
			local mech = ns.MODEL.tinker[faction == "HORDE" and "mech_horde" or "mech_alliance"]
			if usable(mech) then return mech end
		end
	end
	local byClass = ns.MODEL.hero[sp.class]
	local byFaction = byClass and byClass[faction]
	if not byFaction then return nil end
	return usable(byFaction[h.sex == "F" and "F" or "M"]) or usable(byFaction[h.sex == "F" and "M" or "F"])
end

function Figure.ForMonster(monsterId, bossKey)
	return usable(bossKey and ns.MODEL.boss[bossKey]) or usable(monsterId and ns.MODEL.mob[monsterId])
end

-- a skill's summon (pets, turrets, the drone)
function Figure.ForSkill(skillId)
	local sk = ns.SKILLS[skillId]
	if not sk then return nil end
	return usable(sk.summon and ns.MODEL.summon[sk.summon]) or usable(ns.MODEL.summon[skillId])
end

-- a ground summon by its key (the turrets of a field skill)
function Figure.ForSummon(key)
	return usable(key and ns.MODEL.summon[key])
end

function Figure.ForPet(petId)
	return usable(ns.MODEL.pet[petId])
end

------------------------------------------------------------------------
-- The figure widget
------------------------------------------------------------------------
local proto = {}

-- nil when the client cannot make model frames
function Figure.New(parent, height)
	local ok, f = pcall(CreateFrame, "PlayerModel", nil, parent)
	if not ok or not f then return nil end
	-- the model's own turning, kept apart from the figure's SetFacing("left"|"right")
	f.ModelFacing = f.SetFacing
	for k, v in pairs(proto) do f[k] = v end
	f.isOverlay = true -- fighters overlap as they move
	f.height = height or 64
	f:SetSize(f.height, f.height)
	f.facing = "right"
	f.anim, f.left, f.done = "idle", 0, true
	f:Hide()
	return f
end

local function call(f, name, ...)
	local fn = f[name]
	if type(fn) == "function" then return pcall(fn, f, ...) end
	return false
end

-- Puts NPC model `id` up (once); false when there is none to show.
function proto:SetModelId(id)
	if not id or failed[id] then return false end
	if self.id ~= id then
		self.id = id
		call(self, "ClearModel")
		if not call(self, "SetCreature", id) then
			failed[id] = true
			self.id = nil
			return false
		end
		self.loadT = LOAD_WAIT
		self.anim, self.left, self.done = nil, 0, true
		call(self, "ModelFacing", FACE[self.facing] or FACE.right)
		self:Play("idle")
	end
	return true
end

function proto:SetHeight2(h)
	self.height = h
	self:SetSize(h, h)
end

function proto:SetFacing(dir)
	if self.facing == dir then return end
	self.facing = dir
	call(self, "ModelFacing", FACE[dir] or FACE.right)
end

-- restart=true replays a one-shot already playing
function proto:Play(anim, restart)
	if not ANIM_ID[anim] then anim = "idle" end
	if self.anim == anim and not restart and (not ONESHOT[anim] or not self.done) then return end
	self.anim = anim
	self.left = ONESHOT[anim] or 0
	self.done = not ONESHOT[anim]
	call(self, "SetAnimation", ANIM_ID[anim])
end

function proto:Playing()
	return self.anim, self.done
end

function proto:Step(dt)
	-- a model that never loaded is given up on (the bar falls back next frame)
	if self.loadT then
		self.loadT = self.loadT - dt
		if self.loadT <= 0 then
			self.loadT = nil
			local ok, file = call(self, "GetModelFileID")
			if ok and (not file or file == 0) and self.id then
				failed[self.id] = true
				self.id = nil
			end
		end
	end
	if ONESHOT[self.anim] and not self.done then
		self.left = self.left - dt
		if self.left <= 0 then
			self.done = true
			-- the dying stay down
			if self.anim == "death" then call(self, "SetAnimation", ANIM_ID.dead) end
		end
	end
end

-- Feet at (x, y) of the anchor's bottom-left corner (models stand a little
-- above their frame's bottom edge).
function proto:PlaceFeet(anchor, x, y)
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", anchor, "BOTTOMLEFT", x, y - self.height * 0.06)
end

-- for tests: forget the models that did not load
function Figure.ResetFailed() for k in pairs(failed) do failed[k] = nil end end
Figure.failed = failed
