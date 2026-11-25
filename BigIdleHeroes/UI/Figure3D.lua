-- 3D figures: the game's own models (an NPC from Data/Models.lua, put up by
-- its display id) for the battle bar, the formation and the create window:
-- SetModelId, SetHeight2, SetFacing, Play, Playing, Step, PlaceFeet, IsLoaded.
--
-- A figure is a small ModelScene with one actor and a camera of its own, the
-- same for every figure: once a model is in, it is measured (its bounding
-- box), scaled to the figure's height and stood with its feet on the figure's
-- ground line. So every model stands on the same line at the size it is
-- given, whatever the model's own size, and grows and shrinks exactly with
-- the window around it. A client without ModelScene gets a PlayerModel
-- instead (the game fits the model in it by itself).
--
-- What this game showed is kept in the saved data (db.models): the display id
-- each NPC came up with, and display ids this game does not have, so the next
-- time a model comes up at once and no wait is spent on a missing one.
-- Settings: db.opt.models = false turns them off.
local _, ns = ...

local pi, min, max, abs = math.pi, math.min, math.max, math.abs
local sin, cos, tan, sqrt = math.sin, math.cos, math.tan, math.sqrt
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local Figure = {}
ns.Figure3D = Figure

-- animation ids of the game's models, and how long the one-shots last
local ANIM_ID = { idle = 0, walk = 4, attack = 17, cast = 53, hit = 9, death = 1, dead = 6 }
local ONESHOT = { attack = 0.7, cast = 0.9, hit = 0.35, death = 1.2 }

-- ModelScene figures: a square frame SIDE model heights across, the feet
-- FEET_AT above its bottom; a narrow camera straight from the front, far
-- enough back that the model is not seen from below or above
local SIDE, FEET_AT, FOV = 3.0, 0.32, 0.3
-- a bust (SetBust): the frame is the portrait and shows the top of the
-- model, from mid-chest to just over the head (in model heights)
local BUST_SIDE, BUST_TZ = 0.62, 0.74
local SCENE_WAIT = 1.5 -- seconds a display id is given to come up
local BODY_WAIT_MAX, BODY_TRIES = 6, 5 -- a hero's body: the longest wait between tries (seconds), and the tries
-- a long model (a dragon, a wolf) is fitted by this much of its length, so it
-- stays inside the frame
local WIDE = 0.6

-- PlayerModel figures (no ModelScene): right = toward the monsters (checked in
-- game with /bih model: 90° faces right); tries: 1 = the display id, then the
-- NPC id; the frame leaves room around the model
local FACE = { right = pi / 2, left = 3 * pi / 2, front = 0 }
local WAIT = { 1.0, 1.5, 2.5, 4.0 }
local FRAME_W, FRAME_H = 2.4, 1.6
local FEET_UP = 0.06

local failed = {} -- [npc id] = true when the client could not load it
-- [model id] = { box, norm }: a model's size, read in its standing pose.
-- A model's box follows the animation it plays (a running or pouncing cat is
-- much longer than a standing one). So when a model comes in it is held in
-- the standing pose, whatever it was asked to play meanwhile, until its box
-- reads the same twice in a row; only then does it play. The size is kept:
-- the same model never comes up at another size later.
local sizeOf = {}
local SIZE_WAIT = 5      -- seconds a model is held standing for its size at most (when its size is slow to come)
local SIZE_SETTLE = 0.3  -- seconds standing before the first read that counts
local SIZE_APART = 0.1   -- seconds between two reads that are compared
local SIZE_AGREE = 0.02  -- how far apart two reads may be and still agree
local SIZING_ALPHA = 0.01 -- a model standing for its size is all but out of sight

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
-- The druid specs that fight shapeshifted (restoration stays in caster form).
local FORM = { DRUID_GUARDIAN = "bear", DRUID_FERAL = "cat", DRUID_BALANCE = "moonkin" }

-- The form a druid hero fights in, as a model key ("disp:<display id>"), or
-- nil: no form for the spec, druids shown as themselves (settings), or a form
-- the game could not show.
local function formFor(specId, faction)
	if ns.db and ns.db.opt and ns.db.opt.druidForm == false then return nil end
	local form = FORM[specId] and ns.MODEL.form[FORM[specId]]
	local d = form and form[faction or ns.Faction() or "ALLIANCE"]
	return d and usable("disp:" .. d)
end
Figure.FormFor = formFor

-- The NPC a spec is drawn as for a faction and gender (Data/Models.lua
-- ns.MODEL.hero), else its famous NPC, else the class trainer.
function Figure.ForSpec(specId, faction, sex)
	local sp = ns.SPECS[specId]
	if not sp then return nil end
	faction = faction or ns.Faction() or "ALLIANCE"
	local look = ns.MODEL.hero and ns.MODEL.hero[specId] and ns.MODEL.hero[specId][faction]
	look = look and look[sex == "F" and "F" or "M"]
	local f = ns.MODEL.famous[specId] and ns.MODEL.famous[specId][faction]
	local t = ns.MODEL.trainer[sp.class] and ns.MODEL.trainer[sp.class][faction]
	return usable(look and look.npc, f and f.npc, t and t.npc)
end

-- A hero: druids fight in their form (inCombat=false gives the hero's own
-- body).
function Figure.ForHero(heroId, inCombat)
	local h = ns.db and ns.db.heroes[heroId]
	if not h then return nil end
	local faction = ns.Faction() or "ALLIANCE"
	if inCombat ~= false then
		local form = formFor(h.spec, faction)
		if form then return form end
	end
	return Figure.ForSpec(h.spec, faction, Figure.PlayerSex())
end

-- The create window's preview: the spec picked there, else the class trainer.
function Figure.ForClass(classId, faction, specId, sex)
	if specId and ns.SPECS[specId] and ns.SPECS[specId].class == classId then
		return Figure.ForSpec(specId, faction, sex)
	end
	local t = ns.MODEL.trainer[classId] and ns.MODEL.trainer[classId][faction or ns.Faction() or "ALLIANCE"]
	return usable(t and t.npc)
end

-- The player's gender ("M" or "F"): every hero's.
function Figure.PlayerSex()
	return UnitSex and UnitSex("player") == 3 and "F" or "M"
end

-- A hero's own look: the player's model made the class's race (SetModelByUnit
-- with the game's race id), with nothing on, in the class's armor and the
-- spec's weapons for how far the account has come (Data/Models.lua
-- ns.MODEL.armorTier / weaponTier by ns.GearTier; no weapons without a spec).
-- The body has the player's gender: a man logged in gives men, a woman women.
local bodies = {}
function Figure.BodyFor(classId, faction, specId, tier)
	faction = faction or ns.Faction() or "ALLIANCE"
	tier = tier or (ns.GearTier and ns.GearTier()) or 2
	local sex = Figure.PlayerSex()
	local key = tostring(classId) .. ":" .. faction .. ":" .. tostring(specId) .. ":" .. sex .. ":" .. tier
	if bodies[key] ~= nil then return bodies[key] or nil end
	local race = ns.ClassRace(classId, faction)
	local rid = race and ns.MODEL.raceId and ns.MODEL.raceId[race]
	if not rid then
		bodies[key] = false
		return nil
	end
	local M = ns.MODEL
	local armor = M.armorTier and M.armorTier[tier] or {}
	local items = armor[classId] or (M.dungeonSet and M.dungeonSet[classId] and M.dungeonSet[classId].items) or {}
	local wt = M.weaponTier and M.weaponTier[tier] or M.weapons
	local w = specId and wt and wt[specId]
	local weapons = w and { mh = w.mh, oh = w.oh } or {}
	local body = {
		race = race, rid = rid, sex = sex, tier = tier, items = items, weapons = weapons,
		key = "body:" .. rid .. ":" .. table.concat(items, ",") .. ":" .. tostring(weapons.mh) .. ":" .. tostring(weapons.oh),
	}
	bodies[key] = body
	return body
end

-- The body a hero is drawn with, or nil when it fights in another shape (a
-- druid's form) or the body cannot be had.
function Figure.HeroBody(heroId, inCombat)
	local h = ns.db and ns.db.heroes[heroId]
	if not h then return nil end
	local faction = ns.Faction() or "ALLIANCE"
	if inCombat ~= false and formFor(h.spec, faction) then return nil end
	local sp = ns.SPECS[h.spec]
	return sp and Figure.BodyFor(sp.class, faction, h.spec)
end

-- How tall each body stands next to an ordinary hero.
Figure.RACE_SCALE = { GNOME = 0.78, DWARF = 0.9, TAUREN = 1.12, NIGHTELF = 1.04, TROLL = 1.06 }
-- In battle a form has its own size: the cat a little taller than the
-- others (as tall as it stood before every fighter was drawn 15% smaller),
-- the moonkin of both factions a good deal taller than the tauren.
Figure.FORM_SCALE = { cat = 0.92 / 0.85, moonkin = 1.25 }
Figure.FORM_SIZE_OF = { moonkin = "TAUREN" }
function Figure.HeroScale(heroId, inCombat)
	local s = Figure.RACE_SCALE[ns.Heroes.Race(heroId)] or 1
	local h = inCombat and ns.db and ns.db.heroes[heroId]
	local form = h and FORM[h.spec]
	if form and formFor(h.spec) then
		local race = Figure.FORM_SIZE_OF[form]
		if race then s = Figure.RACE_SCALE[race] or 1 end
		s = s * (Figure.FORM_SCALE[form] or 1)
	end
	return s
end

-- Where the health bar sits under a form, as a share of the figure's height
-- forward of the model's middle: the cat's long tail puts its middle behind
-- its body.
Figure.FORM_BAR_X = { cat = 0.15 }
-- the forms that go on four legs, long and low
Figure.BEAST = { cat = true, bear = true }
-- the form a hero fights in (cat, bear, moonkin ...), nil when it stands as
-- itself
function Figure.HeroForm(heroId, inCombat)
	local h = inCombat and ns.db and ns.db.heroes[heroId]
	local form = h and FORM[h.spec]
	if form and formFor(h.spec) then return form end
	return nil
end
function Figure.HeroBarShift(heroId, inCombat)
	local h = inCombat and ns.db and ns.db.heroes[heroId]
	local form = h and FORM[h.spec]
	if form and formFor(h.spec) then return Figure.FORM_BAR_X[form] or 0 end
	return 0
end

function Figure.ForMonster(monsterId, bossKey)
	return usable(bossKey and ns.MODEL.boss[bossKey]) or usable(monsterId and ns.MODEL.mob[monsterId])
end

-- a skill's summon (the hunter's pet, the warlock's demons)
function Figure.ForSkill(skillId)
	if not ns.SKILLS[skillId] then return nil end
	return usable(ns.MODEL.summon[skillId])
end

function Figure.ForPet(petId)
	return usable(ns.MODEL.pet[petId])
end

------------------------------------------------------------------------
-- What this game showed (saved)
------------------------------------------------------------------------
-- ok[npc] = display id it came up with, bad[display id] = true for one the
-- game does not have
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
	-- a model by its display id itself (a druid's form)
	local own = type(id) == "string" and tonumber(id:match("^disp:(%d+)$"))
	if own then return not (mem and mem.bad[own]) and own or nil end
	if type(id) ~= "number" then return nil end
	local seen = mem and mem.ok[id]
	if seen then return seen end
	local disp = ns.MODEL.display and ns.MODEL.display[id]
	if disp and not (mem and mem.bad[disp]) then return disp end
	return nil
end
Figure.DisplayFor = displayFor

local function call(f, name, ...)
	local fn = f and f[name]
	if type(fn) == "function" then return pcall(fn, f, ...) end
	return false
end

-- a call that worked: it ran, and did not answer false
local function worked(f, name, ...)
	local ok, res = call(f, name, ...)
	return ok and res ~= false
end

------------------------------------------------------------------------
-- The figure widget: what both kinds share
------------------------------------------------------------------------
local base = {}

-- gives frame f the methods of a figure kind (and those they share)
local function dress(f, kind)
	for k, v in pairs(base) do f[k] = v end
	for k, v in pairs(kind) do f[k] = v end
end

-- Puts NPC model `id` up (once); false when there is none to show.
function base:SetModelId(id)
	if not id or failed[id] then return false end
	if self.id ~= id then
		self.file, self.body = nil, nil
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

-- Puts a hero's body up (Figure.BodyFor); false when the client cannot.
function base:SetBody(body)
	if self.kind ~= "scene" or not body or failed[body.key] then return false end
	if self.id ~= body.key then
		self.file, self.body = nil, body
		self.id = body.key
		self.tries = 0
		self.loaded = false
		self.anim, self.left, self.done = nil, 0, true
		if not self:Load() then
			failed[body.key] = true
			self.id, self.body = nil, nil
			return false
		end
		self:Play("idle")
	end
	return true
end

-- Puts a model file up by its file id (a spell's effect or missile) instead
-- of an NPC; false when the client cannot.
function base:SetModelFile(file)
	local id = "file:" .. tostring(file)
	if not file or failed[id] then return false end
	if self.id ~= id then
		self.file, self.body = file, nil
		self.id = id
		self.tries = 0
		self.loaded = false
		self.anim, self.left, self.done = nil, 0, true
		if not self:Load() then
			failed[id] = true
			self.id, self.file = nil, nil
			return false
		end
		self:Play("idle")
	end
	return true
end

-- The model at a given scale instead of fitted to the figure's height, its
-- origin on the figure's ground point: a missile as big as it is next to a
-- model of scale s in a figure of the same height. nil fits again.
function base:SetFixedScale(s)
	if self.fixedScale == s then return end
	self.fixedScale = s
	if self.loaded then self:Look() end
end

-- A try that did not bring the model: a display id this game lacks is noted
-- (and forgotten as the NPC's), so it is not waited for again.
function base:TryFailed()
	local mem = memory()
	if mem and self.tryDisplay then
		mem.bad[self.tryDisplay] = true
		if mem.ok[self.id] == self.tryDisplay then mem.ok[self.id] = nil end
	end
end

-- The model is in: remember the display id it came up with, then size it
-- and play its animation (a model takes them only once it is there).
function base:Loaded()
	if self.loaded or not self.id then return end
	self.loaded = true
	self.loadT = nil
	local mem = memory()
	if mem then
		local d = self:ShownDisplay()
		if d then
			mem.ok[self.id] = d
			mem.bad[d] = nil
		end
	end
	self.corrScale, self.corrXf, self.corrYf, self.fixTries, self.fixInfo = nil, nil, nil, 0, nil
	self.sinceLoad = 0
	if self.body and self.Dress then self:Dress() end
	local known = self.id and sizeOf[self.id]
	if known and self.kind == "scene" then
		self.box, self.norm = known.box, known.norm
	elseif self.kind == "scene" and not self.file then
		-- its size is read standing (Step): until then it stands, out of sight
		-- (all but: a model not drawn at all may not take its pose), and
		-- comes into view at its size, doing what it was asked to
		self.sizing = { t = 0 }
		call(self.actor, "SetAlpha", SIZING_ALPHA)
		call(self.actor, "SetAnimation", ANIM_ID.idle)
		self:Measure()
	else
		self:Measure()
	end
	self:Look()
	self:ShowAnim()
	if self.kind == "scene" then Figure.Calibrate(self) end
end

-- The animation the figure was last asked to play, on the model.
function base:ShowAnim()
	if self.anim then self:SetAnim(self:AnimId(self.done and self.anim == "death" and "dead" or self.anim)) end
end

function base:IsLoaded() return self.loaded and true or false end

-- restart=true replays a one-shot already playing; the dying stay down
-- The game's animation for a name, or the figure's own one for it (a hunter
-- shoots its bow for "attack": SetAnimFor).
function base:AnimId(anim)
	return self.ownAnim and self.ownAnim[anim] or ANIM_ID[anim]
end

function base:SetAnimFor(anim, id)
	if (self.ownAnim and self.ownAnim[anim]) == id then return end
	self.ownAnim = self.ownAnim or {}
	self.ownAnim[anim] = id
end

function base:Play(anim, restart)
	if not ANIM_ID[anim] then anim = "idle" end
	if self.anim == anim and not restart and (anim == "death" or not ONESHOT[anim] or not self.done) then return end
	if self.anim ~= anim then self.animAge = 0 end
	self.anim = anim
	self.left = ONESHOT[anim] or 0
	self.done = not ONESHOT[anim]
	self:SetAnim(self:AnimId(anim))
end

function base:Playing()
	return self.anim, self.done
end

function base:Step(dt)
	-- the window around it grew or shrank: the camera is set again
	local okS, eff = call(self, "GetEffectiveScale")
	if okS and eff and eff ~= self.effScale then
		self.effScale = eff
		self:Rescaled()
	end
	-- waiting for the model: in as soon as the game has it; tried again when
	-- it does not come, given up after the last try
	if self.loadT and self.id then
		if self:ModelIn() then
			self:Loaded()
		else
			self.loadT = self.loadT - dt
			if self.loadT <= 0 then
				self:TryFailed()
				if not self.lastTry and self:Load() then
					-- next try under way
				else
					self.loadT = nil
					failed[self.id] = true
					self.id = nil
				end
			end
		end
	end
	self.animAge = (self.animAge or 0) + dt
	-- the model's size: an NPC or a body is held standing until its box reads
	-- the same twice (see sizeOf); a model file (scenery, an effect: they do
	-- not move) is read until the game has its size (a model can come in
	-- before it)
	if self.loaded and self.kind == "scene" then
		self.sinceLoad = (self.sinceLoad or 0) + dt
		local z = self.sizing
		local again = z or (self.file and not self.box and not self.fixedScale and self.sinceLoad < SIZE_WAIT)
		if again then
			local old = self.box and self.norm
			self:Measure()
			if z then
				-- read once it has stood a moment (the pose it had before has
				-- given way), and taken when two reads a little apart agree;
				-- a model that keeps moving while it stands (a tail) is taken
				-- after a while all the same, standing
				z.t = z.t + dt
				local done = z.t >= SIZE_WAIT
				if self.box and z.t >= SIZE_SETTLE then
					if z.ref and z.t - z.refT >= SIZE_APART then
						done = done or abs(self.norm - z.ref) <= SIZE_AGREE * z.ref or z.t >= SIZE_SETTLE * 4
						z.ref, z.refT = self.norm, z.t
					elseif not z.ref then
						z.ref, z.refT = self.norm, z.t
					end
				end
				if done then
					self.sizing = nil
					if self.box and self.id then sizeOf[self.id] = { box = self.box, norm = self.norm } end
					call(self.actor, "SetAlpha", self.alpha or 1)
					self:ShowAnim()
				end
			end
			if self.box and (not old or abs(self.norm - old) > 0.01 * old) then
				self.corrScale, self.corrXf, self.corrYf, self.fixTries, self.fixInfo = nil, nil, nil, 0, nil
				self:Look()
				if self.anchorTo then self:PlaceFeet(self.anchorTo, self.anchorX, self.anchorY) end
			end
		end
	end
	if self.loaded and self.kind == "scene" then
		Figure.Calibrate(self)
		-- each figure checks where its feet and head really are, a few times
		if self.Correct and (self.fixTries or 0) < 3 then
			local now = GetTime and GetTime() or 0
			if not self.nextFix or now >= self.nextFix then
				self.nextFix = now + 0.25
				self:Correct()
			end
		end
	end
	if ONESHOT[self.anim] and not self.done then
		self.left = self.left - dt
		if self.left <= 0 then
			self.done = true
			-- the dying stay down
			if self.anim == "death" then self:SetAnim(ANIM_ID.dead) end
		end
	end
end

function base:SetFacing(dir)
	if self.facing == dir then return end
	self.facing = dir
	self:Look()
end

------------------------------------------------------------------------
-- ModelScene figures
------------------------------------------------------------------------
local scene = {}

-- How much farther back the camera stands than a plain pinhole camera with
-- FOV would: the game draws a scene's models larger than that (seen in game:
-- about 1.25 times, feet below the line). It is measured once with the
-- game's own projection (measureProjection); CAM_FIX is used until then and
-- when the client cannot project.
local CAM_FIX = 1.25
Figure.camFix = CAM_FIX
Figure.camInfo = { how = "default", fix = CAM_FIX }
local scenes = setmetatable({}, { __mode = "k" }) -- every scene figure, to set their cameras again
local projectTries = 0

-- The camera every scene figure shares: straight from the front at the
-- figure's middle; which way is right is read back from the game, so the
-- models face where they should whatever the client's axes are.
local function setCamera(f)
	call(f, "SetCameraOrientationByYawPitchRoll", pi, 0, 0)
	local fx, fy, fz = -1, 0, 0
	local ok, a, b, c = call(f, "GetCameraForward")
	if ok and type(a) == "number" and type(b) == "number" and type(c) == "number" then fx, fy, fz = a, b, c end
	local rx, ry, rz = fy, -fx, 0 -- forward x up
	ok, a, b, c = call(f, "GetCameraRight")
	if ok and type(a) == "number" and type(b) == "number" and type(c) == "number" then rx, ry, rz = a, b, c end
	local side = f.side or SIDE
	local tz = side / 2 - (f.feetAt or FEET_AT)
	if f.bust then side, tz = BUST_SIDE, BUST_TZ end
	f.viewSide, f.viewTz = side, tz
	local d = side / (2 * tan(FOV / 2)) * Figure.camFix
	call(f, "SetCameraFieldOfView", FOV)
	call(f, "SetCameraNearClip", 0.05)
	call(f, "SetCameraFarClip", d * 2 + 20)
	call(f, "SetCameraPosition", -fx * d, -fy * d, tz - fz * d)
	-- a model faces +x at yaw 0. Seen in game: turned toward the camera's
	-- "right" it looks to the screen's left, so right is the other way.
	local side = atan2(ry, rx)
	f.yaws = { right = side + pi, left = side, front = atan2(-fy, -fx) }
	f.camRight = { rx, ry, rz }
	-- light from in front, above and a little to the left
	local lx, ly, lz = fx * 0.6 + rx * 0.35, fy * 0.6 + ry * 0.35, fz * 0.6 + rz * 0.35 - 0.7
	local n = sqrt(lx * lx + ly * ly + lz * lz)
	call(f, "SetLightVisible", true)
	if LE_MODEL_LIGHT_TYPE_DIRECTIONAL then call(f, "SetLightType", LE_MODEL_LIGHT_TYPE_DIRECTIONAL) end
	call(f, "SetLightDirection", lx / n, ly / n, lz / n)
	-- a shaded figure (SetShade: scenery in the distance) gets less light
	local sr, sg, sb = 1, 1, 1
	if f.shade then sr, sg, sb = f.shade[1], f.shade[2], f.shade[3] end
	call(f, "SetLightAmbientColor", 0.75 * sr, 0.75 * sg, 0.75 * sb)
	call(f, "SetLightDiffuseColor", 0.7 * sr, 0.7 * sg, 0.7 * sb)
end

-- The game's projection (Project3DPointTo2D) answers in units and from an
-- origin of its own. They are read off the camera's target, which is the
-- frame's middle: the units are the ones in which the target's x and y both
-- come out where the frame's middle is (the frame is square, so in the
-- frame's own units both are half its side; on the screen they are its
-- centre); a point one unit higher tells which way y runs. Returns
-- { kind = "frame" | "screen", k = units per frame unit, up = y runs up },
-- or nil and why.
local function decode(f)
	if type(f.Project3DPointTo2D) ~= "function" then return false, "no projection" end
	local okV, vis = call(f, "IsVisible")
	if okV and not vis then return nil, "hidden" end
	local okW, w = call(f, "GetWidth")
	local okH, h = call(f, "GetHeight")
	if not (okW and okH and type(w) == "number" and type(h) == "number" and w > 8 and h > 8) then return nil, "no size" end
	local tz = f.viewTz or (SIDE / 2 - FEET_AT)
	local ok0, x0, y0 = call(f, "Project3DPointTo2D", 0, 0, tz)
	local ok1, _, y1 = call(f, "Project3DPointTo2D", 0, 0, tz + 1)
	if not (ok0 and ok1 and type(x0) == "number" and type(y0) == "number" and type(y1) == "number") then
		return nil, "projection gave nothing"
	end
	f.rawProj = { x0, y0, y1, w, h }
	Figure.lastRaw = f.rawProj
	if y1 == y0 then return nil, "projection flat" end
	local up = y1 > y0
	local cands = { { kind = "frame", ex = w / 2, ey = h / 2 } }
	local okC, cx, cy = call(f, "GetCenter")
	local okE, eff = call(f, "GetEffectiveScale")
	local sh
	if UIParent and okE and type(eff) == "number" and eff > 0 then
		local okU, uh = call(UIParent, "GetHeight")
		local okUE, ueff = call(UIParent, "GetEffectiveScale")
		if okU and okUE and type(uh) == "number" and type(ueff) == "number" then sh = uh * ueff / eff end
	end
	if okC and type(cx) == "number" and type(cy) == "number" then
		cands[#cands + 1] = { kind = "screen", ex = cx, ey = up and cy or (sh and sh - cy) }
	end
	-- the units come from x; y only tells the kinds apart (the game may draw
	-- the picture a little higher or lower, which each figure corrects)
	local best, bestErr, second
	for _, c in ipairs(cands) do
		if c.ex and c.ex > 0 and c.ey then
			local k = x0 / c.ex
			if k > 0 then
				c.k = k
				local err = abs(y0 - k * c.ey) / (k * h)
				if not bestErr or err < bestErr then
					second = bestErr
					best, bestErr = c, err
				elseif not second or err < second then
					second = err
				end
			end
		end
	end
	if not best or bestErr > 0.35 or (second and second < bestErr * 2) then
		return nil, string.format("units unknown (x %.1f y %.1f, frame %.0f)", x0, y0, w)
	end
	-- a picture drawn a little to the side would skew the units read from x:
	-- the game's units are one of these, so the nearest one is taken
	local k = best.k
	local nice = { 1, 1 / w }
	if okE and type(eff) == "number" and eff > 0 then
		nice[#nice + 1] = eff
		if type(GetPhysicalScreenSize) == "function" then
			local okP, _, ph = pcall(GetPhysicalScreenSize)
			if okP and type(ph) == "number" and ph > 0 then
				nice[#nice + 1] = eff * ph / 768
				nice[#nice + 1] = ph / 768
			end
		end
	end
	local near, nearErr
	for _, n in ipairs(nice) do
		local e = abs(k - n) / n
		if not nearErr or e < nearErr then near, nearErr = n, e end
	end
	if nearErr and nearErr < 0.08 then k = near end
	return { kind = best.kind, k = k, up = up, sh = sh }
end

-- A projected point in the frame's own units from its bottom-left corner.
local function toLocal(f, conv, px, py)
	local x, y = px / conv.k, py / conv.k
	local w, h = f:GetWidth(), f:GetHeight()
	if conv.kind == "screen" then
		local _, cx, cy = call(f, "GetCenter")
		x = x - (cx - w / 2)
		if not conv.up then y = (conv.sh or 0) - y end
		y = y - (cy - h / 2)
		return x, y
	end
	if not conv.up then y = h - y end
	return x, y
end

-- The camera factor (how much farther the camera has to stand for one unit
-- to come out at its size) and which way the game turns a model, from the
-- projection; nil and why when it cannot tell yet, false when the client has
-- no projection.
local function measureProjection(f)
	local conv, why = decode(f)
	if not conv then return conv, why end
	local side, tz = f.viewSide or SIDE, f.viewTz or (SIDE / 2 - FEET_AT)
	local h = f:GetHeight()
	local _, x0, y0 = call(f, "Project3DPointTo2D", 0, 0, tz)
	local _, _, y1 = call(f, "Project3DPointTo2D", 0, 0, tz + 1)
	local r = f.camRight or { 0, 1, 0 }
	local okR, xr = call(f, "Project3DPointTo2D", r[1], r[2], tz + r[3])
	local shown = abs(y1 - y0) / conv.k -- one unit, in frame units
	local fix = shown * Figure.camFix * side / h
	if fix < 0.3 or fix > 4 then return nil, string.format("factor out of range (%.2f)", fix) end
	-- the camera's "right" drawn on the screen's right: then the right yaw
	-- (side + pi) faces right only because the game turns the other way round
	local sense = 1
	if okR and type(xr) == "number" and xr > x0 then sense = -1 end
	Figure.conv = conv
	return fix, conv.kind .. string.format(" x%.2f", conv.k), sense
end

-- Measures once and sets every scene's camera again with the factor found.
-- Asked at most twice a second; a frame not shown yet does not count as a
-- try, ten answers that make no sense end it (CAM_FIX stays).
local function calibrate(f)
	if Figure.camInfo.how ~= "default" or projectTries >= 10 then return end
	local now = GetTime and GetTime() or 0
	if Figure.nextProbe and now < Figure.nextProbe then return end
	Figure.nextProbe = now + 0.5
	local fix, how, sense = measureProjection(f)
	if not fix then
		Figure.camInfo.why = how
		if fix == false then
			projectTries = 10
		elseif how ~= "hidden" and how ~= "no size" then
			projectTries = projectTries + 1
		end
		return
	end
	Figure.camInfo = { how = "measured", fix = fix, units = how, before = Figure.camFix, sense = sense }
	Figure.camFix = fix
	Figure.yawSense = sense
	-- every figure checks itself again with the new camera
	for s in pairs(scenes) do
		s.corrScale, s.corrXf, s.corrYf, s.fixTries, s.fixInfo, s.nextFix = nil, nil, nil, 0, nil, nil
		setCamera(s)
		if s.loaded then s:Look() end
		if s.anchorTo then s:PlaceFeet(s.anchorTo, s.anchorX, s.anchorY) end
	end
end
Figure.Calibrate = calibrate

-- Forgets the measurement (the model check's reload measures again).
function Figure.ResetCalibration()
	Figure.camFix = CAM_FIX
	Figure.camInfo = { how = "default", fix = CAM_FIX }
	Figure.yawSense = nil
	Figure.nextProbe = nil
	Figure.conv = nil
	projectTries = 0
	for s in pairs(scenes) do
		s.corrScale, s.corrXf, s.corrYf, s.fixTries, s.fixInfo, s.nextFix = nil, nil, nil, 0, nil, nil
		setCamera(s)
		if s.loaded then s:Look() end
		if s.anchorTo then s:PlaceFeet(s.anchorTo, s.anchorX, s.anchorY) end
	end
end

local function newScene(parent, height)
	local ok, f = pcall(CreateFrame, "ModelScene", nil, parent)
	if not ok or not f or type(f.CreateActor) ~= "function" then
		if ok and f and f.Hide then f:Hide() end
		return nil
	end
	local okA, actor = pcall(f.CreateActor, f)
	if not okA or not actor or type(actor.SetModelByCreatureDisplayID) ~= "function" then
		f:Hide()
		return nil
	end
	f.actor = actor
	f.kind = "scene"
	f.FrameAlpha = f.SetAlpha
	-- the game shares one depth buffer between all model scenes, so a model
	-- that is nearer its own camera would show through another scene drawn
	-- above it; each scene clears its own area instead, and the frame level
	-- alone says what is in front (fighters over the scenery behind them).
	-- Spell effects turn this off (scene:SetOverlapped): drawn that way the
	-- game shows nothing of them.
	call(f, "SetAllowOverlappedModels", true)
	dress(f, scene)
	setCamera(f)
	scenes[f] = true
	return f
end

-- One try: the display id (a scene actor takes no NPC id).
function scene:Load()
	local a = self.actor
	self.tries = (self.tries or 0) + 1
	self.tryDisplay = nil
	self.box = nil
	if self.sizing then call(a, "SetAlpha", self.alpha or 1) end
	self.sizing = nil
	call(a, "ClearModel")
	-- measured as it is: no size, turn or offset yet
	call(a, "SetScale", 1)
	call(a, "SetYaw", 0)
	call(a, "SetPosition", 0, 0, 0)
	if self.file then
		local okF, resF = call(a, "SetModelByFileID", self.file)
		if not okF or resF == false then return false end
		self.lastTry = true
		self.loadT = SCENE_WAIT
		return true
	end
	if self.body then
		-- the player, weapons drawn and nothing worn, as the body's race. It
		-- comes slower than an NPC (the player's model and every piece of its
		-- set; all heroes at once when the models are turned back on): it is
		-- asked for again, waiting longer each time (about 20 seconds in all)
		-- before the hero is drawn as an NPC instead
		local okB, resB = call(a, "SetModelByUnit", "player", false, false, false, true, false, self.body.rid)
		if not okB or resB == false then return false end
		self.lastTry = self.tries >= BODY_TRIES
		self.loadT = min(BODY_WAIT_MAX, SCENE_WAIT * self.tries)
		return true
	end
	local disp = displayFor(self.id)
	if not disp then return false end
	local ok, res = call(a, "SetModelByCreatureDisplayID", disp)
	if not ok or res == false then return false end
	self.tryDisplay = disp
	self.lastTry = true
	self.loadT = SCENE_WAIT
	return true
end

function scene:ModelIn()
	local a = self.actor
	local ok, l = call(a, "IsLoaded")
	if ok and not l then return false end
	local okF, file = call(a, "GetModelFileID")
	if okF then return file ~= nil and file ~= 0 end
	return ok and l and true or false
end

function scene:ShownDisplay() return self.tryDisplay end

-- Plays one of the game's spell visual kits on the model once (a spell's
-- cast in the hands, its hit on the target); nothing before the model is in.
function scene:PlayKit(kit)
	if kit and self.loaded then return call(self.actor, "SetSpellVisualKit", kit, true) end
end

-- The body's clothes off, the set on and the weapons in its hands (once the
-- body is in).
function scene:Dress()
	local a = self.actor
	local body = self.body
	call(a, "Undress")
	for _, item in ipairs(body.items or {}) do call(a, "TryOn", "item:" .. item) end
	local w = body.weapons or {}
	if w.mh then call(a, "TryOn", "item:" .. w.mh, "MAINHANDSLOT") end
	if w.oh then call(a, "TryOn", "item:" .. w.oh, "SECONDARYHANDSLOT") end
end

-- The model's own size (its bounding box, standing): its height becomes the
-- figure's height, a long one is fitted by part of its length.
function scene:Measure()
	local ok, x1, y1, z1, x2, y2, z2 = call(self.actor, "GetActiveBoundingBox")
	if ok and type(z2) == "number" and type(z1) == "number" and z2 - z1 > 0.01 then
		local h = z2 - z1
		local long = max(abs((x2 or 0) - (x1 or 0)), abs((y2 or 0) - (y1 or 0)))
		self.box = { x1 or 0, y1 or 0, z1, x2 or 0, y2 or 0, z2 }
		self.norm = 1 / max(h, long * WIDE)
	else
		self.box = nil
		self.norm = 0.5 -- about a man's height, when the game cannot tell
	end
end

-- Size, turn and place: the feet on the ground line, the middle of the model
-- on the figure's middle.
function scene:Look()
	local a = self.actor
	local yaw = (self.yaws and self.yaws[self.facing or "right"]) or 0
	call(a, "SetYaw", yaw)
	if not self.loaded then return end
	-- a fixed scale (SetFixedScale) keeps the model's own size and origin
	local s = self.fixedScale or (self.norm or 0.5) * (self.corrScale or 1)
	call(a, "SetScale", s)
	local b = not self.fixedScale and self.box
	local cx, cy, z1 = 0, 0, 0
	if b then cx, cy, z1 = (b[1] + b[4]) / 2, (b[2] + b[5]) / 2, b[3] end
	-- the box's middle turned as the game turns the model (yawSense)
	local th = (Figure.yawSense or 1) * yaw
	local c, sn = cos(th), sin(th)
	call(a, "SetPosition", -(c * cx - sn * cy) * s, -(sn * cx + c * cy) * s, -z1 * s)
end

function scene:Rescaled() setCamera(self) end

-- Whether the scene is drawn on its own over what is under it (see newScene);
-- off for spell effects.
function scene:SetOverlapped(v)
	call(self, "SetAllowOverlappedModels", v and true or false)
end

-- How grey the model is (0 = its own colours, 1 = grey): scenery far off.
function scene:SetDesaturation(v)
	if self.desat == v then return end
	self.desat = v
	call(self.actor, "SetDesaturation", v)
end

-- The light on the model times (r, g, b): darker and tinted for scenery far
-- off; nil for the usual light.
function scene:SetShade(r, g, b)
	self.shade = r and { r, g, b } or nil
	setCamera(self)
end

-- (a model not in yet, or held standing for its size, plays it once it can:
-- base:ShowAnim)
function scene:SetAnim(id)
	if not self.loaded or self.sizing then return end
	call(self.actor, "SetAnimation", id)
end

function scene:SetAlpha(v)
	if self.alpha == v then return end
	self.alpha = v
	self:FrameAlpha(v)
	if not self.sizing then call(self.actor, "SetAlpha", v) end
end

function scene:SetHeight2(h)
	self.height = h
	local side = self.side or SIDE
	self:SetSize(h * side, h * side)
end

-- The frame side figure heights across with the ground point feetAt above
-- its bottom, instead of SIDE and FEET_AT: room around a spell effect, which
-- reaches out every way from its origin and is cut where its frame ends.
function scene:SetRoom(side, feetAt)
	self.side, self.feetAt = side, feetAt
	setCamera(self)
	if self.height then self:SetHeight2(self.height) end
	if self.loaded then self:Look() end
end

-- Only the head and chest, in a square of px (the caller places the frame,
-- e.g. over a portrait): nothing is drawn outside it.
function scene:SetBust(px)
	self.bust = true
	self.height = px
	self:SetSize(px, px)
	setCamera(self)
	if self.loaded then self:Look() end
end

-- Feet at (x, y) of the anchor's bottom-left corner.
function scene:PlaceFeet(anchor, x, y)
	self.anchorTo, self.anchorX, self.anchorY = anchor, x, y
	local h = self.height or 0
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", anchor, "BOTTOMLEFT", x + (self.corrXf or 0) * h, y - h * (self.feetAt or FEET_AT) + (self.corrYf or 0) * h)
end

-- Where the game really draws the model: its feet (the world's origin) and
-- its head (its height above), read with the projection. The model is made
-- as tall as the figure and moved so the feet land where they were placed.
-- Shifts are kept as shares of the figure's height (the window can grow).
function scene:Correct()
	if self.bust or self.fixedScale or not self.box or not self.height or self.height <= 0 then
		self.fixTries = 3
		return
	end
	local conv, why = decode(self)
	if not conv then
		if conv == false then
			self.fixTries = 3
		elseif why ~= "hidden" and why ~= "no size" then
			self.fixTries = (self.fixTries or 0) + 1
		end
		self.fixWhy = why
		return
	end
	local b = self.box
	local norm = self.norm or 0.5
	local s = norm * (self.corrScale or 1)
	local H = (b[6] - b[3]) * s
	local okF, fx, fy = call(self, "Project3DPointTo2D", 0, 0, 0)
	local okT, tx, ty = call(self, "Project3DPointTo2D", 0, 0, H)
	if not (okF and okT and type(fx) == "number" and type(fy) == "number" and type(ty) == "number") then return end
	local lx, ly = toLocal(self, conv, fx, fy)
	local _, ly2 = toLocal(self, conv, tx, ty)
	local h = self.height
	local want = h * (b[6] - b[3]) * norm
	local got = ly2 - ly
	self.fixTries = (self.fixTries or 0) + 1
	if got > 1 then self.corrScale = max(0.4, min(2.5, (self.corrScale or 1) * want / got)) end
	-- feet: from the frame's bottom-left they should be at (middle, FEET_AT)
	local w = self:GetWidth()
	local feet = self.feetAt or FEET_AT
	self.corrXf = (w / 2 - lx) / h
	self.corrYf = (h * feet - ly) / h
	self.fixInfo = { scale = self.corrScale or 1, dx = w / 2 - lx, dy = h * feet - ly, size = got / want }
	self:Look()
	if self.anchorTo then self:PlaceFeet(self.anchorTo, self.anchorX, self.anchorY) end
end

------------------------------------------------------------------------
-- PlayerModel figures (clients without ModelScene)
------------------------------------------------------------------------
local model = {}

local function newModel(parent, height)
	local ok, f = pcall(CreateFrame, "PlayerModel", nil, parent)
	if not ok or not f then return nil end
	-- the model's own turning and greying, kept apart from the figure's
	-- SetFacing("left"|"right") and SetDesaturation
	f.ModelFacing = f.SetFacing
	f.ModelDesaturation = f.SetDesaturation
	f.kind = "model"
	dress(f, model)
	return f
end

-- One try: the display id the first time (the game's own data, no waiting
-- for the server), the NPC id after that.
function model:Load()
	local id = self.id
	self.tries = (self.tries or 0) + 1
	call(self, "ClearModel")
	self.tryDisplay = nil
	if self.file then
		local okF = worked(self, "SetModel", self.file)
		self.lastTry = true
		self.loadT = WAIT[1]
		self:Look()
		return okF
	end
	local disp = self.tries == 1 and displayFor(id) or nil
	local ok = false
	if disp then
		ok = worked(self, "SetDisplayInfo", disp)
		if ok then self.tryDisplay = disp end
	end
	if not ok and type(id) == "number" then
		if self.tries == 1 then self.tries = 2 end
		ok = worked(self, "SetCreature", id)
	end
	self.lastTry = self.tries >= #WAIT
	self.loadT = WAIT[self.tries] or WAIT[#WAIT]
	self:Look()
	return ok
end

function model:ModelIn()
	local ok, file = call(self, "GetModelFileID")
	return ok and file and file ~= 0 and true or false
end

-- the display id it came up with (also when asked by NPC id)
function model:ShownDisplay()
	local ok, d = call(self, "GetDisplayInfo")
	return (ok and type(d) == "number" and d > 0) and d or self.tryDisplay
end

function model:Measure() end

-- camera distance and facing
function model:Look()
	call(self, "SetCamDistanceScale", FRAME_H)
	call(self, "ModelFacing", FACE[self.facing or "right"] or FACE.right)
end

-- the game fits the model to the frame when it is put up: done again for
-- the new size
function model:Rescaled()
	call(self, "RefreshCamera")
	self:Look()
end

function model:SetAnim(id) call(self, "SetAnimation", id) end

function model:SetDesaturation(v)
	self.desat = v
	call(self, "ModelDesaturation", v)
end

function model:SetShade(r, g, b)
	self.shade = r and { r, g, b } or nil
	call(self, "SetLight", true, false, 0, 0, -1, 1, r or 1, g or 1, b or 1, 1, r or 1, g or 1, b or 1)
end

function model:SetHeight2(h)
	if self.height == h then return end
	self.height = h
	self:SetSize(h * FRAME_W, h * FRAME_H)
	self:Rescaled()
end

function model:PlayKit(kit)
	if not kit or not self.loaded then return end
	-- the older call when the newer one is missing or fails
	return worked(self, "ApplySpellVisualKit", kit, true) or worked(self, "SetSpellVisualKit", kit, true)
end

-- Only the head and chest, in a square of px (the game's portrait framing).
function model:SetBust(px)
	self.bust = true
	self.height = px
	self:SetSize(px, px)
	call(self, "SetPortraitZoom", 1)
end

-- Feet at (x, y) of the anchor's bottom-left corner. The model stands in the
-- middle of its (taller) frame, so the frame reaches below the feet.
function model:PlaceFeet(anchor, x, y)
	self:ClearAllPoints()
	self:SetPoint("BOTTOM", anchor, "BOTTOMLEFT", x, y - self.height * (FRAME_H / 2 - 0.5 + FEET_UP))
end

------------------------------------------------------------------------
-- nil when the client cannot make model frames
function Figure.New(parent, height)
	local f = Figure.useScene ~= false and newScene(parent, height) or nil
	f = f or newModel(parent, height)
	if not f then return nil end
	f.isOverlay = true -- fighters overlap as they move
	if f.EnableMouse then f:EnableMouse(false) end -- clicks go through to what is under it
	f.facing = "right"
	f.anim, f.left, f.done = "idle", 0, true
	f:SetHeight2(height or 64)
	if f.kind == "model" and f.SetScript then
		pcall(f.SetScript, f, "OnModelLoaded", function(self) self:Loaded() end)
	end
	f:Hide()
	return f
end

-- for tests: forget the models that did not load
function Figure.ResetFailed()
	for k in pairs(failed) do failed[k] = nil end
	for k in pairs(sizeOf) do sizeOf[k] = nil end
end
Figure.SizeOf = sizeOf
Figure.failed = failed
Figure.SIDE, Figure.FEET_AT = SIDE, FEET_AT
