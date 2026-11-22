-- 3D figures: the game's own models (PlayerModel with an NPC id from
-- Data/Models.lua) for the battle bar, the formation and the create window:
-- SetModelId, SetHeight2, SetFacing, Play, Playing, Step, PlaceFeet, IsLoaded.
-- A model is put up by its display id first (straight from the game's data),
-- then by the NPC id (the server is asked about the NPC) a few more times; one
-- that never loads is remembered and the caller keeps the icon for it.
-- What this game showed is kept in the saved data (db.models): the display id
-- each NPC came up with, and display ids this game does not have, so the next
-- time a model comes up at once and no wait is spent on a missing one.
-- Settings: db.opt.models = false turns them off.
local _, ns = ...

local pi, min = math.pi, math.min
local Figure = {}
ns.Figure3D = Figure

-- animation ids of the game's models, and how long the one-shots last
local ANIM_ID = { idle = 0, walk = 4, attack = 17, cast = 53, hit = 9, death = 1, dead = 6 }
local ONESHOT = { attack = 0.7, cast = 0.9, hit = 0.35, death = 1.2 }
-- right = toward the monsters (checked in game with /bwi model: 90° faces right)
local FACE = { right = pi / 2, left = 3 * pi / 2, front = 0 }
-- tries: 1 = the display id, then the NPC id; seconds to wait after each
local WAIT = { 1.0, 1.5, 2.5, 4.0 }
-- the frame around a model, in model heights: room on the sides and above so
-- wide and tall models (wings, tails, raised weapons) are not cut off; the
-- camera stands back by as much, so the model keeps its size
local FRAME_W, FRAME_H = 2.4, 1.6
-- feet: a little above the bottom of the model's own height
local FEET_UP = 0.06

local failed = {} -- [npc id] = true when the client could not load it

function Figure.Enabled()
	return ns.db and ns.db.opt and ns.db.opt.models ~= false
end

-- the first of the ids (one id or a list, best first) the game has not failed on
local function usable(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "table" then
			for _, id in ipairs(v) do if not failed[id] then return id end end
		elseif v and not failed[v] then
			return v
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Which model a thing uses
------------------------------------------------------------------------
local FORM = { DRUID_GUARDIAN = "bear", DRUID_FERAL = "cat", DRUID_BALANCE = "moonkin", DRUID_RESTO = "tree" }

-- The look of a spec for a faction: its famous NPC, or the class trainer
-- where it has none ({ npc, sex, name }).
function Figure.SpecLook(specId, faction)
	local sp = ns.SPECS[specId]
	if not sp then return nil end
	faction = faction or ns.Faction() or "ALLIANCE"
	local f = ns.MODEL.famous[specId] and ns.MODEL.famous[specId][faction]
	if f then return f end
	return ns.MODEL.trainer[sp.class] and ns.MODEL.trainer[sp.class][faction]
end

-- The body of a spec: its famous NPC, else (or when the game cannot show
-- that one) the class trainer.
function Figure.ForSpec(specId, faction)
	local sp = ns.SPECS[specId]
	if not sp then return nil end
	faction = faction or ns.Faction() or "ALLIANCE"
	local f = ns.MODEL.famous[specId] and ns.MODEL.famous[specId][faction]
	local t = ns.MODEL.trainer[sp.class] and ns.MODEL.trainer[sp.class][faction]
	return usable(f and f.npc, t and t.npc)
end

-- A hero: druids fight in their form, the mech tinker in the mech
-- (inCombat=false gives the hero's own body).
function Figure.ForHero(heroId, inCombat)
	local h = ns.db and ns.db.heroes[heroId]
	if not h then return nil end
	local faction = ns.Faction() or "ALLIANCE"
	if inCombat ~= false then
		local form = FORM[h.spec]
		if form and usable(ns.MODEL.form[form]) then return ns.MODEL.form[form] end
		if h.spec == "TINKER_MECH" then
			local mech = usable(ns.MODEL.mech[faction])
			if mech then return mech end
		end
	end
	return Figure.ForSpec(h.spec, faction)
end

-- The create window's preview: the spec picked there, else the class trainer.
function Figure.ForClass(classId, faction, specId)
	if specId and ns.SPECS[specId] and ns.SPECS[specId].class == classId then
		return Figure.ForSpec(specId, faction)
	end
	local t = ns.MODEL.trainer[classId] and ns.MODEL.trainer[classId][faction or ns.Faction() or "ALLIANCE"]
	return usable(t and t.npc)
end

-- How tall each body stands next to an ordinary hero.
Figure.RACE_SCALE = { GNOME = 0.78, GOBLIN = 0.82, DWARF = 0.9, TAUREN = 1.12, DRAENEI = 1.05, NIGHTELF = 1.04, TROLL = 1.06 }
function Figure.HeroScale(heroId)
	return Figure.RACE_SCALE[ns.Heroes.Race(heroId)] or 1
end

function Figure.ForMonster(monsterId, bossKey)
	return usable(bossKey and ns.MODEL.boss[bossKey]) or usable(monsterId and ns.MODEL.mob[monsterId])
end

-- a skill's summon (pets, turrets, the drone)
function Figure.ForSkill(skillId)
	local sk = ns.SKILLS[skillId]
	if not sk then return nil end
	return usable(sk.summon and ns.MODEL.summon[sk.summon], ns.MODEL.summon[skillId])
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
	f:SetSize(f.height * FRAME_W, f.height * FRAME_H)
	f.facing = "right"
	f.anim, f.left, f.done = "idle", 0, true
	if f.SetScript then
		pcall(f.SetScript, f, "OnModelLoaded", function(self) self:Loaded() end)
	end
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
		self.tries = 0
		self.loaded = false
		self.anim, self.left, self.done = nil, 0, true
		if not self:Load() then
			failed[id] = true
			self.id = nil
			return false
		end
		self:Play("idle")
	end
	return true
end

-- what this game showed before (saved): ok[npc] = display id it came up
-- with, bad[display id] = true for one the game does not have
local function memory()
	local db = ns.db
	if not db then return nil end
	db.models = db.models or {}
	db.models.ok = db.models.ok or {}
	db.models.bad = db.models.bad or {}
	return db.models
end

-- The display id to try first for an NPC: the one this game showed it with,
-- else the known one unless this game lacks it.
local function displayFor(id)
	local mem = memory()
	local seen = mem and mem.ok[id]
	if seen then return seen end
	local disp = ns.MODEL.display and ns.MODEL.display[id]
	if disp and not (mem and mem.bad[disp]) then return disp end
	return nil
end

-- One try: the display id the first time (the game's own data, no waiting
-- for the server), the NPC id after that.
function proto:Load()
	local id = self.id
	self.tries = (self.tries or 0) + 1
	call(self, "ClearModel")
	self.tryDisplay = nil
	local disp = self.tries == 1 and displayFor(id) or nil
	local ok = false
	if disp then
		ok = call(self, "SetDisplayInfo", disp)
		if ok then self.tryDisplay = disp end
	end
	if not ok then
		if self.tries == 1 then self.tries = 2 end
		ok = call(self, "SetCreature", id)
	end
	self.lastTry = self.tries >= #WAIT
	self.loadT = WAIT[self.tries] or WAIT[#WAIT]
	self:Look()
	return ok
end

-- A try that did not bring the model: a display id this game lacks is noted
-- (and forgotten as the NPC's), so it is not waited for again.
function proto:TryFailed()
	local mem = memory()
	if mem and self.tryDisplay then
		mem.bad[self.tryDisplay] = true
		if mem.ok[self.id] == self.tryDisplay then mem.ok[self.id] = nil end
	end
end

-- camera distance and facing (set again once a model is in)
function proto:Look()
	call(self, "SetCamDistanceScale", FRAME_H)
	call(self, "ModelFacing", FACE[self.facing] or FACE.right)
end

-- The model is in: look and animation again (a model takes them only once
-- it is there).
function proto:Loaded()
	if self.loaded or not self.id then return end
	self.loaded = true
	self.loadT = nil
	-- remember the display id it came up with (also when asked by NPC id)
	local mem = memory()
	if mem then
		local ok, d = call(self, "GetDisplayInfo")
		d = (ok and type(d) == "number" and d > 0) and d or self.tryDisplay
		if d then
			mem.ok[self.id] = d
			mem.bad[d] = nil
		end
	end
	self:Look()
	if self.anim then call(self, "SetAnimation", ANIM_ID[self.done and self.anim == "death" and "dead" or self.anim]) end
end

function proto:IsLoaded() return self.loaded and true or false end

function proto:SetHeight2(h)
	self.height = h
	self:SetSize(h * FRAME_W, h * FRAME_H)
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
	-- waiting for the model: in as soon as the game knows its file; tried
	-- again (by the NPC id) when it does not come, given up after the last try
	if self.loadT and self.id then
		local ok, file = call(self, "GetModelFileID")
		if ok and file and file ~= 0 then
			self:Loaded()
		else
			self.loadT = self.loadT - dt
			if self.loadT <= 0 then
				self:TryFailed()
				if not self.lastTry then
					self:Load()
				else
					self.loadT = nil
					failed[self.id] = true
					self.id = nil
				end
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

-- Feet at (x, y) of the anchor's bottom-left corner. The model stands in the
-- middle of its (taller) frame, so the frame reaches below the feet.
function proto:PlaceFeet(anchor, x, y)
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", anchor, "BOTTOMLEFT", x, y - self.height * (FRAME_H / 2 - 0.5 + FEET_UP))
end

-- for tests: forget the models that did not load
function Figure.ResetFailed() for k in pairs(failed) do failed[k] = nil end end
Figure.failed = failed
