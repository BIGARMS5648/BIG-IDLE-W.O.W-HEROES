-- Battle HUD: the party fights over a scene tinted to the current zone, with a
-- dock underneath for the next goal, chests and menu shortcuts.
local _, ns = ...

local floor, max, min, sin, abs = math.floor, math.max, math.min, math.sin, math.abs
local UI, U = ns.UI, ns.U

local Bar = {}
ns.Bar = Bar

local W = 720
local SCENE_W, SCENE_H = 704, 112
local DOCK_H = 54
-- the 추천 box: its width, where its text starts (after the star) and how
-- wide the text runs (clear of the » on its right); a longer one takes two
-- lines
local GOAL_W, GOAL_TEXT_X = 218, 40
local GOAL_TEXT_W = GOAL_W - GOAL_TEXT_X - 26
local UNIT, BOSS = 34, 44
local MOB = 30
local FEET = 9        -- unit bottom above the scene's bottom edge (the health bars just fit under it)
-- how tall the fighters stand on screen: every model height below times this
local FIG_SCALE = 0.85
local BACK_FIG, PET_FIG = 34 * FIG_SCALE, 24 * FIG_SCALE -- summons (by the front or their summoner) and the companion (at the back)
local PET_ROOM, PET_ROOM_FEET = 7, 0.22 -- the companion's frame: 7 of its heights across, its feet 0.22 up
-- summons drawn as a share of a druid's cat (Bar.CatScale): the hunter's pet
local SUMMON_SIZE = { call_pet = 0.8 }
local SUMMON_PACE = 140 -- how fast the companion walks to its place behind the party (pixels a second)
local MAX_MOBS = 12
local MAX_FLOATS = 28
local MAX_PIPS = 10
-- the zone banner's widest (it stays clear of the wave dots and boss bar)
local BANNER_MAX = 250

local frame
local held = false -- hidden until the first hero is made (Bar.Hold)
local heroFrames, mobFrames, floats, pips = {}, {}, {}, {}
local newScenery -- (Scenery, below)
local shade, drawBackdrop -- (moving layers, below)
local infoT = 0
local dt = 0 -- seconds since the last drawn frame
local HERO_FIG, MOB_FIG = 74 * FIG_SCALE, 70 * FIG_SCALE -- model heights on screen
local Figure = ns.Figure3D -- the game's 3D models

local function laneX(x)
	return x / 1000 * SCENE_W
end

local function place(f, x, y)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", frame.scene, "BOTTOMLEFT", x, y)
end

------------------------------------------------------------------------
-- Units
------------------------------------------------------------------------
local STATUS_TINT = {
	freeze = { 0.4, 0.8, 1, 0.5 }, stun = { 1, 1, 0.4, 0.4 }, chill = { 0.4, 0.6, 1, 0.3 },
	ignite = { 1, 0.4, 0.1, 0.35 }, bleed = { 0.9, 0.1, 0.1, 0.35 }, shock = { 1, 0.9, 0.3, 0.3 },
	curse = { 0.5, 0.2, 0.7, 0.3 }, weaken = { 0.5, 0.4, 0.3, 0.3 },
}
local STATUS_ORDER = { "freeze", "stun", "ignite", "bleed", "shock", "curse", "chill", "weaken" }

local function statusTint(unit)
	for i = 1, #STATUS_ORDER do
		if unit.st[STATUS_ORDER[i]] then return STATUS_TINT[STATUS_ORDER[i]] end
	end
	for _, e in pairs(unit.st) do
		if e.dps then return { 0.55, 0.3, 0.9, 0.3 } end -- any other damage over time
	end
end

local function newHero(parent)
	local u = CreateFrame("Frame", nil, parent)
	u.isOverlay = true -- fighters overlap as they move
	u:SetSize(UNIT, UNIT)
	u.shadow = UI.Art(u, "glow", "BACKGROUND", 0, 0, 0, 0.7)
	u.shadow:SetSize(UNIT + 8, 10)
	u.shadow:SetPoint("CENTER", u, "BOTTOM", 0, 0)
	u.disc = UI.Art(u, "circle", "BACKGROUND", 0.05, 0.06, 0.1)
	u.disc:SetAllPoints(u)
	u.icon = u:CreateTexture(nil, "ARTWORK")
	u.icon:SetPoint("TOPLEFT", u, "TOPLEFT", 3, -3)
	u.icon:SetPoint("BOTTOMRIGHT", u, "BOTTOMRIGHT", -3, 3)
	u.tint = UI.Art(u, "circle", "OVERLAY")
	u.tint:SetAllPoints(u.icon)
	u.tint:Hide()
	u.flash = UI.Art(u, "circle", "OVERLAY", 1, 1, 1, 0.55)
	u.flash:SetAllPoints(u.icon)
	u.flash:Hide()
	u.ring = UI.Art(u, "ring", "OVERLAY")
	u.ring:SetAllPoints(u)
	u.hp = UI.Bar(u, UNIT, 5, 0.25, 0.9, 0.3)
	u.hp:SetPoint("TOP", u, "BOTTOM", 0, -2)
	u.shield = UI.Art(u, "bar", "OVERLAY", 0.6, 0.85, 1)
	u.shield:SetHeight(2)
	u.shield:SetPoint("BOTTOMLEFT", u.hp, "TOPLEFT", 0, 0)
	u.shield:Hide()
	u.model = Figure.New(parent, HERO_FIG)
	u:Hide()
	return u
end

local function newMob(parent)
	local u = CreateFrame("Frame", nil, parent)
	u.isOverlay = true -- fighters overlap as they move
	u:SetSize(MOB, MOB)
	u.shadow = UI.Art(u, "glow", "BACKGROUND", 0, 0, 0, 0.7)
	u.shadow:SetSize(MOB + 8, 10)
	u.shadow:SetPoint("CENTER", u, "BOTTOM", 0, 0)
	u.back = UI.Art(u, "slot", "BACKGROUND")
	u.back:SetAllPoints(u)
	u.icon = u:CreateTexture(nil, "ARTWORK")
	u.icon:SetPoint("TOPLEFT", u, "TOPLEFT", 2, -2)
	u.icon:SetPoint("BOTTOMRIGHT", u, "BOTTOMRIGHT", -2, 2)
	u.tint = u:CreateTexture(nil, "OVERLAY")
	u.tint:SetAllPoints(u.icon)
	u.tint:Hide()
	u.flash = u:CreateTexture(nil, "OVERLAY")
	u.flash:SetAllPoints(u.icon)
	UI.Fill(u.flash, 1, 1, 1, 0.5)
	u.flash:Hide()
	u.edge = UI.Art(u, "frame", "OVERLAY", 0.85, 0.2, 0.15)
	u.edge:SetAllPoints(u)
	u.hp = UI.Bar(u, MOB, 4, 0.9, 0.2, 0.15)
	u.hp:SetPoint("TOP", u, "BOTTOM", 0, -2)
	u.model = Figure.New(parent, MOB_FIG)
	if u.model then u.model:SetFacing("left") end
	u:Hide()
	return u
end

-- The figure a unit is drawn as: the game's 3D model (modelId) when there is
-- one it can show, else nil (the round icon); the model is hidden then.
local function pickFigure(model, modelId)
	if model and modelId and Figure.Enabled() and model:SetModelId(modelId) then return model end
	if model then model:Hide() end
end

-- A hero: its own body (the player's model as its race, in its class's
-- dungeon set), else the NPC it is drawn as (a druid's form, the mech).
local function pickHero(model, heroId)
	if model and Figure.Enabled() then
		local body = Figure.HeroBody(heroId, true)
		if body and model:SetBody(body) then return model end
	end
	return pickFigure(model, Figure.ForHero(heroId, true))
end

-- Picks the animation for a unit, letting a started attack, skill or hit
-- finish before idling or walking again.
local ONESHOT = { attack = true, cast = true, hit = true }
local function animate(sp, want)
	local cur, done = sp:Playing()
	if ONESHOT[cur] and not done and (want == "idle" or want == "walk") then
		sp:Step(dt)
		return
	end
	sp:Play(want, ONESHOT[want] and cur ~= want)
	sp:Step(dt)
end


------------------------------------------------------------------------
-- Floating combat text
------------------------------------------------------------------------
local function spawnFloat(e)
	local slot
	for i = 1, MAX_FLOATS do
		if not floats[i].active then slot = floats[i] break end
	end
	if not slot then return end
	slot.active = true
	slot.t = 0
	slot.life = e.big and 1.2 or 0.9
	-- numbers that pop up close together climb in steps instead of piling up
	local now = GetTime()
	local lane = e.side == "hero" and 1 or 2
	floats.recent = floats.recent or { { t = 0, n = 0 }, { t = 0, n = 0 } }
	local r = floats.recent[lane]
	if now - r.t < 0.35 then r.n = (r.n + 1) % 4 else r.n = 0 end
	r.t = now
	slot.x = U.clamp(laneX(e.x) + math.random(-14, 14), 14, SCENE_W - 14)
	slot.y = FEET + (e.side == "hero" and 40 or 36) + r.n * 11
	slot.fs:SetFont(ns.FONT, e.big and 14 or 11, "OUTLINE")
	slot.fs:SetText(e.text)
	slot.fs:SetTextColor(e.r or 1, e.g or 1, e.b or 1)
	slot.fs:SetAlpha(1)
	slot.fs:Show()
end

local function updateFloats(elapsed)
	for i = 1, MAX_FLOATS do
		local s = floats[i]
		if s.active then
			s.t = s.t + elapsed
			local p = s.t / s.life
			if p >= 1 then
				s.active = false
				s.fs:Hide()
			else
				s.fs:ClearAllPoints()
				s.fs:SetPoint("BOTTOM", frame.scene, "BOTTOMLEFT", s.x, s.y + p * 22)
				s.fs:SetAlpha(1 - p * p)
			end
		end
	end
end

------------------------------------------------------------------------
-- Per-frame drawing
------------------------------------------------------------------------
-- Combat moves everyone in steps (Combat.STEP, 0.1 s). Drawn as they are, the
-- fighters would hop ten times a second; instead each one glides from where
-- it is drawn to where it is now, over one step, so it moves evenly at any
-- frame rate. A jump much longer than a step's walk (a new wave, a reset)
-- is taken at once.
local GLIDE_SNAP = 40 -- pixels
local function glide(f, target)
	local g = f.glide
	if not g or math.abs(target - g.cur) > GLIDE_SNAP then
		f.glide = { cur = target, from = target, to = target, t = 1 }
		return target, false
	end
	if g.to ~= target then g.from, g.to, g.t = g.cur, target, 0 end
	if g.t >= 1 then return g.cur, false end -- there: standing
	g.t = min(1, g.t + dt / (ns.Combat.STEP or 0.1))
	g.cur = g.from + (g.to - g.from) * g.t
	return g.cur, math.abs(g.to - g.from) > 0.05
end

-- Walking: from the last step that moved, for a little longer than a step,
-- so the walk is not broken off between two steps.
local WALK_HOLD = 0.25
local function walking(f, moved)
	if moved then f.walkT = WALK_HOLD else f.walkT = max(0, (f.walkT or 0) - dt) end
	return f.walkT > 0
end
-- Screen x of every hero, pushed apart so portraits never sit on each other
-- (two ranged heroes with similar reach would otherwise stand in one spot).
local spread = {}
local function heroPositions(list)
	local order = {}
	for i = 1, #list do
		local u = list[i]
		order[#order + 1] = { i = i, x = laneX(u.x) - UNIT / 2 }
	end
	table.sort(order, function(a, b) return a.x > b.x end)
	for k = 2, #order do
		local lim = order[k - 1].x - (UNIT - 4)
		if order[k].x > lim then order[k].x = lim end
	end
	for k = 1, #order do spread[order[k].i] = order[k].x end
end

local function drawHeroes(now)
	local list = ns.Combat.heroes
	local backX
	heroPositions(list)
	for i = 1, ns.PARTY_SIZE do
		local f = heroFrames[i]
		local u = list[i]
		if u then
			if f.shownId ~= u.id then
				f.shownId = u.id
				f.glide = nil
				UI.SetClassIcon(f.icon, u.class)
				f.ring:SetVertexColor(U.rgb(ns.ROLE[u.role].hex))
			end
			local px, moved = glide(f, spread[i])
			f.drawX = px
			local moving = walking(f, moved)
			local fig = pickHero(f.model, u.id)
			if fig then
				f.figFor, f.figIs = u.id, fig
				-- its size every frame (a druid's form can come up a moment later)
				local tall = HERO_FIG * Figure.HeroScale(u.id, true)
				if fig.height ~= tall then fig:SetHeight2(tall) end
				-- a cat or a bear: its effects at its front (spellFx)
				local form = Figure.HeroForm(u.id, true)
				fig.beast = Figure.BEAST[form or ""] and form or nil
				-- a hunter's attack is a shot of its bow or gun; other heroes that
				-- fight from afar (casters, healers) cast at the target instead of
				-- swinging their weapon
				local shot = Bar.ShotOf(u)
				fig:SetAnimFor("attack", shot and shot.anim or (u.ranged and Bar.CAST_ANIM) or nil)
				local want = "idle"
				if u.dead then want = "death"
				elseif (u.castT or 0) > 0.6 then want = "cast"
				elseif u.anim > 0 then want = "attack"
				elseif u.flash > 0.05 then want = "hit"
				elseif ns.Combat.state.phase == "travel" or moving then want = "walk" end
				animate(fig, want)
				fig:PlaceFeet(frame.scene, px + UNIT / 2, FEET + 2)
				fig:SetAlpha(u.dead and 0.6 or 1)
				fig:Show()
				-- the icon stays until the model is in, so nothing blinks
				local inModel = fig:IsLoaded()
				f.disc:SetShown(not inModel)
				f.icon:SetShown(not inModel)
				f.ring:SetShown(not inModel)
			else
				f.figFor, f.figIs = nil, nil
				f.disc:Show()
				f.icon:Show()
				f.ring:Show()
				if u.anim > 0 then px = px + 4 end
			end
			local bob = (not u.dead and ns.Combat.state.phase == "travel" and not fig) and (sin(now * 10 + i) * 1.5) or 0
			-- the bar under the body (a cat's middle is behind it, for its tail)
			local barX = (fig and fig:IsLoaded()) and Figure.HeroBarShift(u.id, true) * HERO_FIG * Figure.HeroScale(u.id, true) or 0
			place(f, px + barX, FEET + bob)
			if not backX or u.x < backX then backX = u.x end
			if u.dead then
				f:SetAlpha(0.35)
				f.icon:SetDesaturated(true)
				f.hp:SetValue(1 - u.reviveT / 20)
				f.hp:SetRGB(0.5, 0.5, 0.5)
				f.tint:Hide()
				f.shield:Hide()
			else
				f:SetAlpha(1)
				f.icon:SetDesaturated(false)
				local r = u.hp / u.maxhp
				f.hp:SetValue(r)
				if r > 0.5 then f.hp:SetRGB(0.25, 0.9, 0.3) elseif r > 0.25 then f.hp:SetRGB(0.95, 0.78, 0.15) else f.hp:SetRGB(0.95, 0.2, 0.15) end
				local c = statusTint(u)
				if c then
					f.tint:SetVertexColor(c[1], c[2], c[3], c[4])
					f.tint:Show()
				else
					f.tint:Hide()
				end
				if u.shield > 0 then
					f.shield:SetWidth(max(1, UNIT * min(1, u.shield / u.maxhp)))
					f.shield:Show()
				else
					f.shield:Hide()
				end
			end
			if u.flash > 0 and not fig then f.flash:Show() else f.flash:Hide() end
			if fig then f.tint:Hide() end -- no round overlay on a 3D model
			f:Show()
		else
			f:Hide()
			if f.model then f.model:Hide() end
			f.shownId = nil
		end
	end
	-- the party's front and back (where the heroes are drawn: their smooth
	-- positions, not the fight's steps)
	local minX, maxX
	for i = 1, #list do
		local x = heroFrames[i].drawX or spread[i]
		if x and (not minX or x < minX) then minX = x end
		if x and not list[i].dead and (not maxX or x > maxX) then maxX = x end
	end
	-- summoned creatures (3D models, else their skill's icon): one that shoots stands beside its
	-- summoner; one that fights up close walks beside its summoner too, and
	-- goes up to the front by the monsters (as the melee heroes do) while the
	-- party fights, walking there and back as fast as its summoner does (up at
	-- its speed, back into formation BACK_PACE faster)
	local k, front, beside = 0, 0, {}
	local phase = ns.Combat.state.phase
	local fighting = phase == "fight"
	for i = 1, #list do
		local u = list[i]
		if not u.dead and spread[i] then
			for sid, pt in pairs(u.pets) do
				if ns.SKILLS[sid] and k < #frame.summons then
					k = k + 1
					local mid = Figure.ForSkill(sid)
					local sp = pickFigure(frame.summons[k], mid)
					local icon = frame.summonIcons[k]
					-- the model, or its icon in its place (the walking state is kept on either)
					local holder = sp or icon
					do
						if sp then
							-- the hunter's pet a little smaller than a druid's cat; the rest small
							local tall = SUMMON_SIZE[sid] and HERO_FIG * Bar.CatScale() * SUMMON_SIZE[sid] or BACK_FIG
							if sp.height ~= tall then sp:SetHeight2(tall) end
						end
						local x
						local own = heroFrames[i].drawX or spread[i]
						if ns.SKILLS[sid].ranged then
							beside[i] = (beside[i] or 0) + 1
							x = own + UNIT / 2 - 18 - (beside[i] - 1) * 18
						else
							front = front + 1
							local target = fighting and (maxX or own) + UNIT / 2 + 22 + (front - 1) * 16
								or own + UNIT / 2 + 20 + (front - 1) * 14
							-- walks from where it is to its place (a new summon starts by its summoner)
							local h = holder
							if h.summonFor ~= u.id .. sid or not h.sx then
								h.summonFor, h.sx = u.id .. sid, own + UNIT / 2 + 20
							end
							local pace = laneX(ns.Combat.HeroSpeed(u)) * (target < h.sx and ns.Combat.BACK_PACE or 1)
							local step = pace * dt
							if math.abs(target - h.sx) <= step then h.sx = target
							else h.sx = h.sx + (target > h.sx and step or -step) end
							h.going = h.sx ~= target
							x = h.sx
						end
						if sp then
							local want = (pt.anim or 0) > 0 and "attack"
								or ((phase == "travel" or sp.going) and "walk" or "idle")
							animate(sp, want)
							sp:SetFacing("right")
							sp:PlaceFeet(frame.scene, x, FEET + 2)
							sp:Show()
						end
						if sp and sp:IsLoaded() then
							icon:Hide()
						else
							if icon.shownSkill ~= sid then
								icon.shownSkill = sid
								UI.SetIcon(icon.icon, ns.SKILLS[sid].icon)
							end
							place(icon, x - 10, FEET + 2)
							icon:Show()
						end
					end
				end
			end
		end
	end
	for i = k + 1, #frame.summons do
		if frame.summons[i] then frame.summons[i]:Hide() end
		if frame.summonIcons[i] then frame.summonIcons[i]:Hide() end
	end
	-- the companion: the very back, behind the whole party
	local function behind(w)
		return max(w / 2 + 2, (minX or 0) + UNIT / 2 - 44)
	end
	-- the companion, last
	local pet = ns.db.pet and ns.PET_BY_ID[ns.db.pet]
	if pet and backX and ns.db.pets[pet.id] then
		if frame.pet.shownId ~= pet.id then
			frame.pet.shownId = pet.id
			UI.SetIcon(frame.pet.icon, pet.icon)
		end
		-- walks to its place at a steady pace (no hops when the party moves)
		local want = behind(PET_FIG)
		local pm = frame.pet
		if not pm.cx or pm.forId ~= pet.id then pm.cx, pm.forId = want, pet.id end
		local step = SUMMON_PACE * dt
		if math.abs(want - pm.cx) <= step then pm.cx = want else pm.cx = pm.cx + (want > pm.cx and step or -step) end
		local px = pm.cx
		local pfig = pickFigure(frame.petModel, Figure.ForPet(pet.id))
		if pfig then
			animate(pfig, (ns.Combat.state.phase == "travel" or pm.cx ~= want) and "walk" or "idle")
			pfig:PlaceFeet(frame.scene, px, FEET + 2)
			pfig:Show()
			if pfig:IsLoaded() then
				frame.pet:Hide()
			else
				place(frame.pet, px - 10, FEET + 2)
				frame.pet:Show()
			end
		else
			place(frame.pet, px - 10, FEET + 2)
			frame.pet:Show()
		end
	else
		frame.pet:Hide()
		if frame.petModel then frame.petModel:Hide() end
	end
end

local function drawMobs()
	local list = ns.Combat.mobs
	local boss
	for i = 1, MAX_MOBS do
		local f = mobFrames[i]
		local m = list[i]
		if m and m.x < 1040 then
			local size = m.boss and BOSS or MOB
			if f.shownIcon ~= m.icon or f.size ~= size then
				f.shownIcon = m.icon
				f.size = size
				UI.SetIcon(f.icon, m.icon)
				f:SetSize(size, size)
				f.hp:SetBarWidth(size)
				if m.boss then
					f.edge:SetVertexColor(1, 0.78, 0.2)
				else
					f.edge:SetVertexColor(0.85, 0.2, 0.15)
				end
			end
			if f.mobRef ~= m then f.mobRef, f.glide = m, nil end
			local px, moved = glide(f, laneX(m.x) - size / 2)
			local st = ns.Combat.state
			local bd, bi = ns.Combat.SourceOf(true) -- (a tower floor's boss comes from its own stage)
			local bossKey = m.boss and not m.summoned and bd and (bd .. "-" .. bi) or nil
			local fig = pickFigure(f.model, Figure.ForMonster(m.def and m.def.id, bossKey))
			if fig then
				if f.figMob ~= m or f.figIs ~= fig then
					f.figMob, f.figIs = m, fig
					fig:SetHeight2(MOB_FIG * (m.boss and 1.4 or 1))
					f.walkT = 0
				end
				local moving = walking(f, moved)
				local want = "idle"
				if m.dead then want = "death"
				elseif m.anim > 0 then want = "attack"
				elseif m.flash > 0.05 then want = "hit"
				elseif moving then want = "walk" end
				animate(fig, want)
				fig:PlaceFeet(frame.scene, px + size / 2, FEET + (m.boss and 0 or (m.off / 12) * 3))
				fig:SetAlpha(m.dead and max(0, (m.fade or 0) / 0.4) or 1)
				fig:Show()
				local inModel = fig:IsLoaded()
				f.back:SetShown(not inModel)
				f.icon:SetShown(not inModel)
				f.edge:SetShown(not inModel)
			else
				f.figMob, f.figIs = nil, nil
				f.back:Show()
				f.icon:Show()
				f.edge:Show()
				if m.anim > 0 then px = px - 4 end
			end
			place(f, px, FEET + (m.boss and 0 or (m.off / 12) * 3))
			if m.dead then
				f:SetAlpha(max(0, (m.fade or 0) / 0.4))
				f.tint:Hide()
			else
				f:SetAlpha(1)
				local c = statusTint(m)
				if c then
					UI.Fill(f.tint, c[1], c[2], c[3], c[4])
					f.tint:Show()
				else
					f.tint:Hide()
				end
				if m.boss then boss = m end
			end
			f.hp:SetValue(m.hp / m.maxhp)
			if (m.drT or 0) > 0 then f.hp:SetRGB(0.5, 0.75, 1) else f.hp:SetRGB(0.9, 0.2, 0.15) end
			if m.flash > 0 and not fig then f.flash:Show() else f.flash:Hide() end
			if fig then f.tint:Hide() end -- no square overlay on a 3D model
			f:Show()
		else
			f:Hide()
			if f.model then f.model:Hide() end
			f.figMob, f.figIs = nil, nil
			f.shownIcon = nil
		end
	end
	-- big boss bar while a boss is up
	local bb = frame.bossBar
	if boss and ns.Combat.state.phase ~= "result" then
		bb:SetValue(boss.hp / boss.maxhp)
		bb:SetLabel(ns.N(boss.name) .. "  " .. floor(boss.hp / boss.maxhp * 100 + 0.5) .. "%")
		if (boss.drT or 0) > 0 then bb:SetRGB(0.5, 0.75, 1) elseif boss.enr > 1 then bb:SetRGB(1, 0.35, 0.1) else bb:SetRGB(0.85, 0.15, 0.12) end
		bb:Show()
	else
		bb:Hide()
	end
end

local function drawPips(now)
	local st = ns.Combat.state
	-- the boss bar takes the wave row's place while the boss is up
	if frame.bossBar:IsShown() then
		for i = 1, MAX_PIPS do pips[i]:Hide() end
		return
	end
	local waves = st.waves or 10
	local n = max(1, min(MAX_PIPS, waves))
	-- more waves than pips: each monster pip stands for a run of waves, the
	-- last pip is always the boss
	local function pipOf(w)
		if waves <= MAX_PIPS or w <= 0 then return w end
		if w >= waves then return n end
		return math.ceil(w * (n - 1) / (waves - 1))
	end
	local wave = pipOf(st.wave or 0)
	local runDone = (st.wave or 0) < waves and pipOf((st.wave or 0) + 1) > wave
	local x0 = 418 - (n - 1) * 8 -- centred between the zone banner and the gold
	for i = 1, MAX_PIPS do
		local p = pips[i]
		if i <= n then
			local isBoss = i == n
			-- the boss: the painted skull in its own colours (pulsing while reached),
			-- moved right so the gap before it is the dots' (7: the skull shows
			-- about 15 of its 18 wide, the dots 9 of 9)
			local skull = isBoss and UI.ArtPath("icon_skull")
			p:ClearAllPoints()
			p:SetPoint("CENTER", frame.scene, "TOPLEFT", x0 + (i - 1) * 16 + (skull and 3 or 0), -17)
			p.dot:SetTexture(skull or UI.Tex(isBoss and "skull" or "circle"))
			local size = isBoss and (skull and 18 or 16) or 9
			if i < wave or (i == wave and st.phase ~= "fight" and (runDone or waves <= MAX_PIPS or i == n)) then
				p.dot:SetVertexColor(1, 0.80, 0.28) -- cleared
			elseif i == wave then
				local k = 0.75 + 0.25 * sin(now * 6)
				p.dot:SetVertexColor(k, k, k) -- in progress
				size = size + 2
			else
				p.dot:SetVertexColor(0.22, 0.25, 0.33) -- ahead
			end
			if skull then
				local k = i == wave and (0.8 + 0.2 * sin(now * 6)) or 1
				p.dot:SetVertexColor(k, k, k)
			elseif isBoss and i >= wave then
				p.dot:SetVertexColor(i == wave and 1 or 0.75, i == wave and 0.35 or 0.30, i == wave and 0.25 or 0.30)
			end
			p.dot:SetSize(size, size)
			p:Show()
		else
			p:Hide()
		end
	end
end

local function updateInfo()
	local db = ns.db
	local st = ns.Combat.state
	local diff, idx = db.stage.diff, db.stage.idx
	if st.phase ~= "idle" and st.diff then diff, idx = st.diff, st.idx end
	local d = ns.DIFFS[diff]
	local stg = ns.Stage(diff, idx)

	-- the backdrop: a picture of the place (else the theme's drawn hills)
	local backdrop = ns.BackdropFile and ns.BackdropFile(diff, idx)
	local grounds, place = ns.GroundFiles(diff, idx)
	local ground = grounds and grounds[1]
	local key = tostring(backdrop or stg.theme) .. "|" .. tostring(ground)
	if frame.themeKey ~= key then
		frame.themeKey = key
		local art, r, g, b = backdrop, 0.8, 0.8, 0.8
		if not backdrop then
			local th = ns.THEMES[stg.theme] or ns.THEMES.forest
			art, r, g, b = UI.Tex(th.art), th.rgb[1] * 0.85, th.rgb[2] * 0.85, th.rgb[3] * 0.85
		end
		for _, t in ipairs({ frame.sky, frame.sky2 }) do
			t:SetTexture(art)
			t:SetVertexColor(r, g, b)
		end
		-- the ground of the place: the first of its textures the game has
		ground = grounds and Bar.PickGround(frame.ground, grounds, place)
		frame.groundFile = ground
		for _, t in ipairs({ frame.ground, frame.groundFade }) do
			if ground then
				t:SetTexture(ground, "REPEAT", "REPEAT")
				t:Show()
			else
				t:Hide()
			end
		end
		if ground then
			shade(frame.ground, 0.85, 1, 1)
			shade(frame.groundFade, 0.85, 1, 0)
		end
		drawBackdrop()
	end

	-- zone banner (a floor of the endless tower: 도전 and the tower's floor)
	local tf = st.phase ~= "idle" and st.tower
	local r, g, b = U.rgb(tf and "b48cff" or d.hex)
	frame.diffChip:SetColor(r * 0.55, g * 0.55, b * 0.55, 0.95)
	frame.diffChip:SetLabel(tf and "도전" or ns.N(d.name))
	local act, n = ns.StageAct(idx)
	local zone = tf and ns.Tower.Label(tf) or string.format("%d-%d %s", act, n, ns.N(stg.name))
	if stg.raid then zone = zone .. "  " .. U.col("ff9326", "공격대") end
	frame.zoneLv:SetText("Lv " .. (tf and ns.Tower.LEVEL or ns.StageLevel(diff, idx)))
	-- the banner never reaches the wave dots or the boss bar: a long name
	-- takes a smaller font first, and only then is cut short
	local chipW = frame.diffChip:GetWidth()
	local room = BANNER_MAX - (chipW + 18) - frame.zoneLv:GetStringWidth()
	for size = 12, 10, -1 do
		local font, _, flags = frame.zone:GetFont()
		frame.zone:SetFont(font or ns.FONT, size, flags)
		frame.zone:SetText(zone)
		if frame.zone:GetStringWidth() + 2 <= room then break end
	end
	frame.zone:SetWidth(min(room, frame.zone:GetStringWidth() + 2))
	frame.banner:SetWidth(min(BANNER_MAX, frame.zone:GetWidth() + frame.zoneLv:GetStringWidth() + chipW + 28))


	frame.gold:SetLabel(U.fmt(db.gold))

	-- retry note under the banner
	if (db.retry or 0) > 0 and db.opt.auto then
		frame.note:SetText(string.format("힘을 기르는 중 · 재도전까지 %d회", db.retry))
	elseif st.phase == "idle" then
		frame.note:SetText("영웅을 모집해 파티에 넣으세요")
	else
		frame.note:SetText("")
	end

	if st.phase == "result" then
		if st.result == "win" then
			frame.result:SetText("승리!")
			frame.result:SetTextColor(1, 0.85, 0.3)
		else
			frame.result:SetText("전멸...")
			frame.result:SetTextColor(1, 0.35, 0.3)
		end
		frame.result:Show()
	else
		frame.result:Hide()
	end

	-- dock
	for t = 1, #ns.CHEST do
		local cb = frame.chests[t]
		local count = ns.Loot.Count(t)
		cb:SetCount(count > 0 and tostring(count) or "")
		cb:SetDim(count == 0)
		if count >= ns.ChestCap(t) then cb:SetBorderRGB(1, 0.25, 0.2) else cb:SetQuality(t == 1 and 3 or (t == 2 and 6 or 4)) end
	end
	-- a chest's tooltip, while the mouse is on it, counts down to the auto-open
	local owner = UI.TipOwner()
	if owner and owner.chestType then UI.RefreshTip() end
	local auto = db.opt.auto and true or false
	local ab = frame.auto
	if ab.on ~= auto then
		ab.on = auto
		-- on: » (on to the next stage) on gold; off: a loop (this stage again) on dark
		UI.SetGlyph(ab.glyph, auto and "auto" or "repeat")
		if auto then ab.glyph:SetVertexColor(1, 1, 1) else ab.glyph:SetVertexColor(0.86, 0.89, 0.96) end
		ab.disc:SetVertexColor(auto and 0.22 or 0.16, auto and 0.55 or 0.2, auto and 1 or 0.3)
		ab.ringT:SetVertexColor(auto and 0.7 or 0.55, auto and 0.85 or 0.62, auto and 1 or 0.8)
		ab.caption:SetText(auto and "자동 진행" or "반복")
		UI.Color(ab.caption, auto and UI.C.gold or UI.C.sub)
	end

	local goal = ns.Guide.Current()
	frame.goal.text:SetText(ns.N(goal.text))
	frame.goal:Center()
	if goal.wait then
		frame.goal.text:SetTextColor(0.75, 0.78, 0.86)
	else
		frame.goal.text:SetTextColor(1, 1, 1)
	end
	local badges = ns.Guide.Badges()
	for _, mb in ipairs(frame.menu) do mb:SetBadge(badges[mb.key]) end
end

------------------------------------------------------------------------
-- Skill effects: the visuals of the classic spells the skills and boss
-- abilities are (Data/Effects.lua) - the glow in the caster's hands (the
-- cast kit's hand effect), what shows on the caster itself (a nova, a
-- shout), the missile flying to each target (spells that have one), the hit
-- on each one reached; heals and buffs land on whom they reach. Each is the
-- spell's own effect model in a figure of its own, put up as the model check
-- (/bih model, 효과) shows them: at a fixed share of the scale of the model
-- it flies from or lands on (a hit HIT_SIZE, the hand glow HAND_SIZE, a
-- missile MISSILE_SIZE; 1 = as big as next to a character in the game), so
-- they grow and shrink with the window as the fighters do. An effect on its
-- caster (a slash, a shout, the glow in its hands) faces the way the caster
-- does; a hit on another faces the way it flies, from the one who sent it.
-- Each effect's frame is wide all around its origin (FX_ROOM), so only the
-- battle scene's edge cuts it; a beast's (cat, bear) own blows come out at
-- its front. (An effect model's bounding box says little about what it
-- draws - most are far bigger than their glow - so it is not used to size
-- them.)
------------------------------------------------------------------------
local FX_FLIGHT, FX_HIT_DELAY, MAX_MISSILES, MAX_TARGETS = 0.35, 0.12, 12, 5
local MAX_HITS, HIT_SHOW, HIT_FADE, HIT_SIZE = 12, 0.8, 0.25, 1.0
local MISSILE_SIZE = 1.25
local HIT_WAIT = 1.5 -- an effect whose model is not in by then is dropped
-- the glow in a caster's hands: this share of the caster's scale, at the
-- front hand (HAND_X across, HAND_Y up)
local HAND_SIZE, HAND_X, HAND_Y = 0.8, 0.22, 0.5
-- each effect's frame: FX_ROOM figure heights across with the effect's
-- origin in its middle, so nothing of it is cut off (the battle scene's own
-- edge is the only one that cuts)
local FX_ROOM = 8
-- a beast (a druid's cat or bear) is long, its middle well behind its head:
-- what it does itself comes out at its front (FRONT_OWN of the way from its
-- middle to its nose: the cat's in front of its head, the bear's at its
-- head and paws), what reaches it lands on its chest (FRONT_HIT)
local FRONT_OWN, FRONT_HIT = { cat = 1.15, bear = 0.7 }, 0.4
-- how high a beast's own low blow (a claw: selfLow) comes out, as a share
-- of its figure's height (the cat is low and long: by its paws)
local LOW_OWN = { cat = 0.1 }
local missiles, hits, pendingHits = {}, {}, {}
-- what was launched and shown (the last missile's file), for the tests
local fxStats = { missiles = 0, hits = 0 }

local function figureOf(unit)
	local list = ns.Combat.heroes
	for i = 1, #list do
		if list[i] == unit then return heroFrames[i] and heroFrames[i].figIs end
	end
	list = ns.Combat.mobs
	for i = 1, #list do
		if list[i] == unit then return mobFrames[i] and mobFrames[i].figIs end
	end
end

-- a figure of the pool that is free (a new one while there are fewer than
-- most); nil when the client has no scene figures
local function freeFig(pool, most)
	for _, ms in ipairs(pool) do
		if not ms.active then return ms end
	end
	if #pool >= most then return nil end
	local fig = Figure.New(frame.scene, HERO_FIG)
	if not fig or fig.kind ~= "scene" then
		if fig then fig:Hide() end
		return nil
	end
	fig:SetFrameLevel(frame.scene:GetFrameLevel() + 21)
	fig:SetRoom(FX_ROOM, FX_ROOM / 2)
	fig:Hide()
	local ms = { fig = fig }
	pool[#pool + 1] = ms
	return ms
end

-- a figure's own scale (its model fitted to its height, or fixed)
local function scaleOf(fig) return fig.fixedScale or (fig.norm or 0.5) * (fig.corrScale or 1) end

-- how big a hit is: a share of the scale of the model it lands on
local function hitScale(hs)
	return (hs.hand and HAND_SIZE or HIT_SIZE) * scaleOf(hs.tfig)
end

-- how far in front of a figure's middle a beast's front is (k of the way
-- from its middle to its nose, the model's measured length); 0 for one that
-- stands upright
local function front(fig, k)
	local b = fig.beast and fig.box
	if not b then return 0 end
	return k * abs(b[4] - b[1]) / 2 * scaleOf(fig) * (fig.height or 0)
end

-- where a figure's hands and chest are, in the scene (a beast's paws and
-- chest are at its front)
local function hand(fig, dir)
	local x = fig.beast and front(fig, FRONT_OWN[fig.beast]) or fig.height * 0.2
	return fig.anchorX + x * dir, fig.anchorY + fig.height * 0.6
end
local function chest(fig)
	local dir = fig.facing == "left" and -1 or 1
	return fig.anchorX + front(fig, FRONT_HIT) * dir, fig.anchorY + fig.height * 0.55
end

-- the spell's hit on a figure: its impact model, put up afresh so it plays
-- from the start (nothing where the client has no scene figures)
local function playHit(tfig, fx)
	local hs = fx.hit and freeFig(hits, MAX_HITS)
	if not hs then return end
	local fig = hs.fig
	fig.id = nil
	if not fig:SetModelFile(fx.hit) then return end
	hs.tfig, hs.low, hs.hand, hs.own, hs.t, hs.wait, hs.active = tfig, fx.low, fx.hand, fx.own, 0, 0, true
	fig:SetHeight2(tfig.height)
	fig:SetFixedScale(hitScale(hs))
	-- on its caster: the way the caster faces; on another: the way it flies
	-- (away from the one who sent it, so toward the model it lands on)
	if fx.own then
		fig:SetFacing(tfig.facing or "right")
	else
		fig:SetFacing(tfig.facing == "left" and "right" or "left")
	end
	fig:SetAlpha(1)
	fxStats.hits = fxStats.hits + 1
end

-- a spell from caster u at the units in `to`: the cast on the caster, then a
-- missile to each target or straight its hit
local function spellFx(u, fx, to)
	local cfig = figureOf(u)
	if cfig and not cfig:IsLoaded() then cfig = nil end
	-- the glow in the hands (the cast kit's hand effect, sized to the caster),
	-- what shows on the caster
	local handFile = cfig and fx.cast and ns.KIT_HAND[fx.cast]
	if handFile and cfig.anchorX then playHit(cfig, { hit = handFile, hand = true, own = true }) end
	if cfig and cfig.anchorX and fx.self then playHit(cfig, { hit = fx.self, low = fx.selfLow, own = true }) end
	for k, t in ipairs(to or {}) do
		if k > MAX_TARGETS then break end
		local tfig = figureOf(t)
		if tfig and tfig:IsLoaded() and tfig.anchorX then
			local ms = fx.missile and cfig and cfig.anchorX and t ~= u and freeFig(missiles, MAX_MISSILES)
			if ms and ms.fig:SetModelFile(fx.missile) then
				local dir = tfig.anchorX >= cfig.anchorX and 1 or -1
				ms.fig:SetHeight2(cfig.height)
				ms.fig:SetFixedScale(MISSILE_SIZE * scaleOf(cfig))
				ms.fig:SetFacing(dir > 0 and "right" or "left")
				ms.x0, ms.y0 = hand(cfig, dir)
				ms.tfig, ms.fx, ms.t, ms.active = tfig, fx, 0, true
				fxStats.missiles, fxStats.lastMissile = fxStats.missiles + 1, fx.missile
				fxStats.seen = fxStats.seen or {}
				fxStats.seen[fx.missile] = fxStats.missiles
			else
				-- straight on the target (on the caster itself: its own way)
				pendingHits[#pendingHits + 1] = { t = FX_HIT_DELAY, fig = tfig, fx = t == u and { hit = fx.hit, low = fx.low, own = true } or fx }
			end
		end
	end
end

-- A hunter's shot (Data/Models.lua ns.MODEL.SHOT): the animation it fires
-- with and the arrow or bullet that flies, by the weapon in its hands; nil
-- for every other hero.
Bar.CAST_ANIM = 53 -- the game's SpellCastDirected
function Bar.ShotOf(u)
	if not u or u.class ~= "HUNTER" then return nil end
	local body = Figure.HeroBody(u.id, true)
	local mh = body and body.weapons and body.weapons.mh
	local kind = (mh and ns.MODEL.rangedKind[mh]) or (u.gun and "gun") or "bow"
	return ns.MODEL.SHOT[kind]
end
-- the arrow leaves the bow this long after the shot starts (the draw)
local SHOT_DELAY = 0.3
local pendingShots = {}

-- the combat's effect events: hero skills and boss abilities play their
-- spells; a hunter's basic attack flies its arrow or bullet to the target
-- (other basic attacks are not drawn)
local function drawEffects()
	local list = ns.Combat.vfx
	local on = Figure.Enabled()
	for i = 1, #list do
		local e = list[i]
		if on and e.u then
			local fx
			if e.k == "skill" then
				fx = ns.SkillFx(e.u.class, ns.SKILLS[e.sid])
			elseif e.k == "mob" then
				fx = ns.MobFx(e.kind, e.school)
			elseif e.k == "shot" then
				local shot = Bar.ShotOf(e.u)
				if shot and #pendingShots < MAX_MISSILES then
					pendingShots[#pendingShots + 1] = { t = SHOT_DELAY, u = e.u, to = e.to, fx = { missile = shot.missile } }
				end
			end
			if fx then spellFx(e.u, fx, e.to) end
		end
		list[i] = nil
	end
	for i = #pendingShots, 1, -1 do
		local p = pendingShots[i]
		p.t = p.t - dt
		if p.t <= 0 then
			table.remove(pendingShots, i)
			if not p.u.dead then spellFx(p.u, p.fx, p.to) end
		end
	end
	for _, ms in ipairs(missiles) do
		if ms.active then
			ms.t = ms.t + dt
			ms.fig:Step(dt)
			local p = ms.t / FX_FLIGHT
			if p >= 1 or not ms.tfig:IsShown() then
				ms.active = false
				ms.fig:Hide()
				if p >= 1 then playHit(ms.tfig, ms.fx) end
			else
				local tx, ty = chest(ms.tfig)
				ms.fig:PlaceFeet(frame.scene, ms.x0 + (tx - ms.x0) * p, ms.y0 + (ty - ms.y0) * p)
				-- the game brings a model in only while its frame is shown: shown
				-- see-through until it is in
				ms.fig:Show()
				ms.fig:SetAlpha(ms.fig:IsLoaded() and 1 or 0)
			end
		end
	end
	for i = #pendingHits, 1, -1 do
		local h = pendingHits[i]
		h.t = h.t - dt
		if h.t <= 0 then
			if h.fig:IsShown() then playHit(h.fig, h.fx) end
			table.remove(pendingHits, i)
		end
	end
	-- hits stay on their target (a heal low on the body, a blow at the chest)
	-- for a moment, then fade
	for _, hs in ipairs(hits) do
		if hs.active then
			hs.fig:Step(dt)
			-- its time runs once its model is in (given up if it never comes)
			if hs.fig:IsLoaded() then hs.t = hs.t + dt else hs.wait = (hs.wait or 0) + dt end
			local tf = hs.tfig
			if hs.t >= HIT_SHOW or (hs.wait or 0) > HIT_WAIT or not tf:IsShown() or not tf.anchorX then
				hs.active = false
				hs.fig:Hide()
			else
				if hs.fig.height ~= tf.height then hs.fig:SetHeight2(tf.height) end
				-- sized to its model (and as the window changes)
				hs.fig:SetFixedScale(hitScale(hs))
				local dir = tf.facing == "left" and -1 or 1
				if hs.hand then
					-- at the front hand (the way the caster faces; a beast's paws)
					local x = tf.beast and front(tf, FRONT_OWN[tf.beast]) or tf.height * HAND_X
					hs.fig:PlaceFeet(frame.scene, tf.anchorX + x * dir, tf.anchorY + tf.height * HAND_Y)
				else
					-- a beast's own blow at its front, a hit on it at its chest
					local x = tf.beast and front(tf, hs.own and FRONT_OWN[tf.beast] or FRONT_HIT) or 0
					local y = hs.low and ((hs.own and LOW_OWN[tf.beast or ""]) or 0.25) or 0.55
					hs.fig:PlaceFeet(frame.scene, tf.anchorX + x * dir, tf.anchorY + tf.height * y)
				end
				local left = HIT_SHOW - hs.t
				-- shown (see-through) while its model comes in: the game loads a
				-- model only into a frame that is shown
				hs.fig:Show()
				hs.fig:SetAlpha(hs.fig:IsLoaded() and (left < HIT_FADE and left / HIT_FADE or 1) or 0)
			end
		end
	end
end
Bar.missiles, Bar.hits, Bar.fxStats, Bar.FX_ROOM = missiles, hits, fxStats, FX_ROOM
function Bar.Scene() return frame and frame.scene end
Bar.FIG = { hero = HERO_FIG, mob = MOB_FIG, back = BACK_FIG, pet = PET_FIG, scale = FIG_SCALE }
Bar.GOAL = { w = GOAL_W, textX = GOAL_TEXT_X, textW = GOAL_TEXT_W }
function Bar.Summons() return frame and frame.summons, frame and frame.petModel, frame and frame.summonIcons end

------------------------------------------------------------------------
-- Scenery: the stage's own terrain models (Data/Scenery.lua) in three rows
-- behind the fight. Each model is drawn at a size that follows its real
-- height (a tree tall, a bush low) within its row's limits; ones too small
-- or too big for their row are swapped for another. While the party walks on
-- between waves the rows go by, the near one as fast as the walk and the far
-- one slowest; a model that leaves on the left comes back on the right as
-- another of the place's models.
------------------------------------------------------------------------
local SCENERY_ROWS = {
	-- y: ground of the row; k: pixels per yard of the model's height, within
	-- lo..hi; minH/maxH: the heights (yards) a model of the row may have;
	-- shade: its light; speed: share of the walk; phase: where its first
	-- model stands (in steps), so the rows' models do not stand in line
	{ key = "far",  n = 4, y = 42, k = 5, lo = 36, hi = 62, minH = 4,   maxH = 80, shade = 0.55, speed = 0.3, phase = 0.15, level = 1,
		inside = { k = 11, lo = 30, hi = 54, minH = 1.2, maxH = 30 } },
	{ key = "mid",  n = 3, y = 27, k = 6, lo = 20, hi = 40, minH = 1.2, maxH = 25, shade = 0.75, speed = 0.6, phase = 0.55, level = 2,
		inside = { k = 13, lo = 16, hi = 34, minH = 0.5, maxH = 10 } },
	{ key = "near", n = 4, y = 12, k = 9, lo = 8,  hi = 20, minH = 0.2, maxH = 5,  shade = 0.9,  speed = 1.0, phase = 0.85, level = 3,
		inside = { k = 16, lo = 7, hi = 18, minH = 0.1, maxH = 3 } },
}
-- the limits of a row for the set shown (an inside place's props are smaller,
-- man-sized things)
local function rowLimits(sc, def)
	return sc.set and sc.set.inside and def.inside or def
end
local SCENERY_WIDE = 2.4 -- a model this many times as long as it is tall (a wall, a cliff) does not stand in a row
Bar.SCENERY_ROWS = SCENERY_ROWS
-- Moving layers. The world goes by while the party walks on between waves:
-- its speed eases up and down; while the party fights everything stands
-- still.
local GROUND_H, GROUND_FADE = 30, 18 -- the ground band and its fading top edge (pixels)
local TILE_W, TILE_H = 128, 48       -- one tile of the ground texture on screen (flattened: seen from the side)
local BACKDROP_SHARE = 0.18          -- share of the walk the backdrop goes by
local world = { speed = 0, sky = 0, ground = 0 }
Bar.world = world

-- a texture's colour, from `a` at the bottom to `a2` at the top (the
-- ground's top edge fades out)
function shade(t, k, a, a2)
	local ok = CreateColor and pcall(t.SetGradient, t, "VERTICAL", CreateColor(k, k, k, a), CreateColor(k, k, k, a2))
	if not ok then
		ok = t.SetGradientAlpha and pcall(t.SetGradientAlpha, t, "VERTICAL", k, k, k, a, k, k, k, a2)
	end
	if not ok then
		t:SetVertexColor(k, k, k)
		t:SetAlpha(a2 > 0 and 1 or 0.6)
	end
end

local function piece(t, mirrored, ua, ub, x, w)
	if w < 0.5 then t:Hide() return end
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", frame.scene, "TOPLEFT", x, 0)
	t:SetPoint("BOTTOMLEFT", frame.scene, "BOTTOMLEFT", x, 0)
	t:SetWidth(w)
	if mirrored then t:SetTexCoord(1 - ua, 1 - ub, 0, 1) else t:SetTexCoord(ua, ub, 0, 1) end
	t:Show()
end

-- the backdrop seen from `world.sky` pixels along an endless row of the
-- picture and its mirror image (no seam where they meet)
function drawBackdrop()
	if not frame then return end
	local w = SCENE_W
	local p = (world.sky / w) % 2
	local tile = floor(p)
	local u = p - tile
	local w1 = (1 - u) * w
	piece(frame.sky, tile % 2 == 1, u, 1, 0, w1)
	piece(frame.sky2, tile % 2 == 0, 0, u, w1, w - w1)
end

local function drawGround()
	if not frame.groundFile then return end
	local u0 = (world.ground / TILE_W) % 1
	local u1 = u0 + SCENE_W / TILE_W
	local v1 = GROUND_H / TILE_H
	frame.ground:SetTexCoord(u0, u1, 0, v1)
	frame.groundFade:SetTexCoord(u0, u1, -GROUND_FADE / TILE_H, 0)
end

-- the scenery's own dice (math.random is the fights' own, left alone)
-- the scenery's own numbers (the fight's chances are not touched): the
-- minimal standard generator, exact in a double, its high part for a choice
local seed = 20240611
local function rnd(n)
	seed = (seed * 16807) % 2147483647
	local u = (seed - 1) / 2147483646
	if n then return math.min(n, floor(u * n) + 1) end
	return u
end
local WALK_PX = 90             -- how fast the ground goes by while the party walks (pixels a second)
local SPAN_PAD = 90            -- room past each side of the scene where a model turns round
local SPAN = SCENE_W + 2 * SPAN_PAD

function newScenery(scene)
	local sc = { rows = {}, bad = {} }
	local lv = scene:GetFrameLevel()
	for r, def in ipairs(SCENERY_ROWS) do
		local row = { def = def, off = 0, items = {} }
		for i = 1, def.n do
			local fig = Figure.New(scene, def.hi)
			if fig then
				fig:SetFrameLevel(lv + def.level)
				-- evenly spread, each row shifted by its phase, a little off the step
				local step = SPAN / def.n
				row.items[i] = { fig = fig, x = (i - 1 + def.phase) * step + step * 0.08 * (((i * 7 + r * 3) % 5) - 2) / 2, lap = nil }
			end
		end
		sc.rows[r] = row
	end
	frame.scenery = sc
end

-- the place's model for a spot: another than its neighbour's, none known
-- not to fit the row or not to load
local function sceneryFile(sc, row, it, prev)
	local list = sc.set and sc.set[row.def.key]
	if not list or #list == 0 then return nil end
	local bad = sc.bad[row.def.key]
	local start = rnd(#list)
	local fallback
	for k = 0, #list - 1 do
		local f = list[(start + k - 1) % #list + 1]
		if not (bad and bad[f]) and not Figure.failed["file:" .. f] then
			if f ~= prev and f ~= it.file then return f end
			fallback = fallback or f
		end
	end
	return fallback
end

local function setSceneryModel(sc, row, it, prev)
	local fig = it.fig
	it.sized = false
	fig:SetAlpha(0)
	for _ = 1, 4 do
		local f = sceneryFile(sc, row, it, prev)
		if not f then break end
		it.file = f
		if fig:SetModelFile(f) then
			fig:SetFacing(rnd(2) == 1 and "left" or "right")
			it.scale = 0.85 + rnd() * 0.3
			fig:Show()
			return
		end
	end
	it.file = nil
	fig:Hide()
end

-- the model is in: drawn as tall as its row makes it, or swapped when it
-- does not fit the row
local function sizeScenery(sc, row, it)
	local fig, def = it.fig, row.def
	local lim = rowLimits(sc, def)
	local b = fig.box
	local H = b and (b[6] - b[3]) or nil
	local long = b and max(math.abs(b[4] - b[1]), math.abs(b[5] - b[2])) or 0
	if H and (H < lim.minH or H > lim.maxH or long > H * SCENERY_WIDE) then
		sc.bad[def.key] = sc.bad[def.key] or {}
		sc.bad[def.key][it.file] = true
		setSceneryModel(sc, row, it, it.file)
		return
	end
	local px = H and max(lim.lo, min(lim.hi, H * lim.k)) or (lim.lo + lim.hi) / 2
	px = px * (it.scale or 1)
	-- drawn height = figure height x the model's height x its fitting
	local fit = (H and fig.norm) and H * fig.norm or 1
	fig:SetHeight2(px / max(0.05, fit))
	it.sized = true
	fig:SetAlpha(1)
end

local function drawScenery()
	local sc = frame.scenery
	if not sc then return end
	local st = ns.Combat.state
	local diff, idx = ns.db.stage.diff, ns.db.stage.idx
	if st.phase ~= "idle" and st.diff then diff, idx = st.diff, st.idx end
	local set = ns.db.opt.scenery ~= false and Figure.Enabled() and ns.SceneryFor and ns.SceneryFor(diff, idx) or nil
	local th = set and (ns.THEMES[ns.Stage(diff, idx).theme] or ns.THEMES.forest)
	if set ~= sc.set or th ~= sc.theme then
		sc.set, sc.theme = set, th
		for _, row in ipairs(sc.rows) do
			-- far rows take on the colour of the place's sky
			local k, rgb = row.def.shade, th and th.rgb or { 1, 1, 1 }
			local mix = 1 - k
			for _, it in ipairs(row.items) do
				it.lap = nil
				if set then
					it.fig:SetShade(k * (1 - mix + mix * rgb[1]), k * (1 - mix + mix * rgb[2]), k * (1 - mix + mix * rgb[3]))
					setSceneryModel(sc, row, it)
				else
					it.file = nil
					it.fig:Hide()
				end
			end
		end
	end
	-- how fast the world goes by: the walk's pace while the party walks on
	-- between waves; still while it fights (heroes stepping about included)
	local walk = st.phase == "travel"
	local want = walk and WALK_PX or 0
	world.speed = world.speed + (want - world.speed) * min(1, dt * 5)
	if world.speed < 0.5 and not walk then world.speed = 0 end
	world.sky = (world.sky + world.speed * BACKDROP_SHARE * dt) % (SCENE_W * 2000)
	world.ground = (world.ground + world.speed * dt) % (TILE_W * 1000)
	drawBackdrop()
	drawGround()
	if not set then return end
	for _, row in ipairs(sc.rows) do
		row.off = (row.off + world.speed * row.def.speed * dt) % (SPAN * 1000)
		local prev
		for _, it in ipairs(row.items) do
			local pos = it.x - row.off
			local lap = floor(pos / SPAN)
			if it.lap and lap ~= it.lap then setSceneryModel(sc, row, it, prev) end
			it.lap = lap
			if it.file then
				local fig = it.fig
				fig:Step(dt)
				if not fig.id then
					-- the game could not load it: another one
					setSceneryModel(sc, row, it, prev)
				elseif not it.sized and fig:IsLoaded() then
					sizeScenery(sc, row, it)
				end
				fig:PlaceFeet(frame.scene, pos - lap * SPAN - SPAN_PAD, row.def.y)
				prev = it.file
			end
		end
	end
end
Bar.DrawScenery = drawScenery
-- (for the checks: step = the seconds the frame took)
function Bar.DrawHeroes(step)
	if step then dt = step end
	drawHeroes(GetTime())
end
Bar.LaneX = laneX
function Bar.Ground() return frame and frame.ground, frame and frame.sky, frame and frame.sky2 end

-- How tall a druid's cat stands next to an ordinary hero (its race for the
-- player's faction, then the cat's own size).
function Bar.CatScale()
	local race = ns.ClassRace("DRUID")
	return (Figure.RACE_SCALE[race or ""] or 1) * (Figure.FORM_SCALE.cat or 1)
end
Bar.SUMMON_SIZE, Bar.LOW_OWN = SUMMON_SIZE, LOW_OWN

-- The first of a place's ground textures the game has (SetTexture says no
-- to a file it lacks); a place whose own first one was missing is noted
-- (Bar.groundMissing, /bih ground).
Bar.groundMissing = {}
function Bar.PickGround(tex, list, place)
	for i, id in ipairs(list) do
		if tex:SetTexture(id, "REPEAT", "REPEAT") ~= false then
			if place then Bar.groundMissing[place] = i > 1 and list[1] or nil end
			return id
		end
	end
	if place then Bar.groundMissing[place] = list[1] end
	return nil
end

-- /bih ground: every place's ground tried; the ones the game lacks listed.
function Bar.CheckGrounds()
	local t = (frame and frame.scene or UIParent):CreateTexture(nil, "BACKGROUND")
	t:Hide()
	local seen, missing, total = {}, {}, 0
	for d = 1, #ns.STAGE_SCENERY do
		for i = 1, #ns.STAGE_SCENERY[d] do
			local list, place = ns.GroundFiles(d, i)
			if list and not seen[place] then
				seen[place] = true
				total = total + 1
				local used = Bar.PickGround(t, list, place)
				if used ~= list[1] then
					missing[#missing + 1] = place .. (used and (" → " .. used) or " (없음)")
				end
			end
		end
	end
	return total, missing
end
function Bar.Scenery() return frame and frame.scenery, frame and frame.units end
function Bar.Sky() return frame and frame.sky end

local function onUpdate(self, elapsed)
	local now = GetTime()
	dt = elapsed
	drawScenery()
	drawHeroes(now)
	drawMobs()
	drawPips(now)
	local fx = ns.Combat.fx
	if #fx > 0 then
		for i = 1, #fx do
			spawnFloat(fx[i])
			fx[i] = nil
		end
	end
	updateFloats(elapsed)
	drawEffects()
	infoT = infoT - elapsed
	if infoT <= 0 then
		infoT = 0.25
		updateInfo()
	end
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
local function chestTip(self)
	local t = self.chestType
	local def = ns.CHEST[t]
	local lines = {
		{ ns.N(def.name), ns.Loot.Count(t) .. " / " .. ns.ChestCap(t), UI.C.gold[1], UI.C.gold[2], UI.C.gold[3] },
	}
	if t == 1 then
		lines[#lines + 1] = { "일반 몬스터가 떨어뜨립니다.", nil, 0.8, 0.8, 0.8 }
	elseif t == 2 then
		lines[#lines + 1] = { "스테이지 우두머리가 떨어뜨립니다.", nil, 0.8, 0.8, 0.8 }
	else
		lines[#lines + 1] = { "각 막의 마지막 공격대 우두머리가 떨어뜨립니다.", nil, 0.8, 0.8, 0.8 }
	end
	if ns.Loot.AutoOn(t) then
		local left = max(0, ns.Loot.AutoInterval(t) - (ns.db.autoT[t] or 0))
		lines[#lines + 1] = { "자동 열기까지", U.time(left), 0.5, 1, 0.5 }
	else
		lines[#lines + 1] = { "'태엽의 룬'을 배우면 자동으로 열립니다.", nil, 0.6, 0.6, 0.6 }
	end
	lines[#lines + 1] = { "클릭: 1개 열기", nil, 0.45, 0.8, 1 }
	if ns.Loot.CanOpen("kind") then
		lines[#lines + 1] = { "오른쪽 클릭: 이 상자 모두 열기", nil, 0.45, 0.8, 1 }
	end
	if ns.Loot.CanOpen("all") then
		lines[#lines + 1] = { "Shift+클릭: 모든 상자 열기", nil, 0.45, 0.8, 1 }
	end
	return lines
end

function Bar.SavePosition()
	local p, _, rp, x, y = frame:GetPoint(1)
	if p then ns.db.ui.barPos = { p, rp or p, x or 0, y or 0 } end
end

Bar.MIN_SCALE, Bar.MAX_SCALE = 0.5, 2.0

function Bar.Scale()
	return U.clamp(ns.db.ui.barScale or 1, Bar.MIN_SCALE, Bar.MAX_SCALE)
end

function Bar.ApplyPosition()
	frame:ClearAllPoints()
	frame:SetScale(Bar.Scale())
	local pos = ns.db.ui.barPos
	if pos and pos[1] then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
	end
end

-- Corner grip: dragging it scales the whole battle window, keeping its
-- proportions and its top-left corner where it is.
local function cursorUI()
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	return x / s, y / s
end

local function startResize()
	if ns.db.ui.locked then return end
	local scale = frame:GetScale()
	local left, top = frame:GetLeft() * scale, frame:GetTop() * scale -- in UIParent units
	frame.resizing = { left = left, top = top }
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
end

local function stepResize()
	local r = frame.resizing
	if not r then return end
	local cx = cursorUI()
	local scale = U.clamp((cx - r.left) / W, Bar.MIN_SCALE, Bar.MAX_SCALE)
	scale = floor(scale * 100 + 0.5) / 100
	if scale ~= frame:GetScale() then
		frame:SetScale(scale)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", r.left / scale, r.top / scale)
	end
end

local function stopResize()
	if not frame.resizing then return end
	frame.resizing = nil
	ns.db.ui.barScale = frame:GetScale()
	Bar.SavePosition()
end

function Bar.SetScale(scale)
	ns.db.ui.barScale = U.clamp(scale, Bar.MIN_SCALE, Bar.MAX_SCALE)
	if not frame then return end
	local old = frame:GetScale()
	local left, top = frame:GetLeft() * old, frame:GetTop() * old
	frame:SetScale(Bar.Scale())
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / Bar.Scale(), top / Bar.Scale())
	Bar.SavePosition()
end

local function newGrip()
	local g = CreateFrame("Button", nil, frame)
	g:SetSize(18, 18)
	g:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
	g:SetFrameLevel(frame:GetFrameLevel() + 30)
	g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	g:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	g:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then startResize() end
	end)
	g:SetScript("OnMouseUp", function(_, button)
		stopResize()
		if button == "RightButton" and not ns.db.ui.locked then Bar.SetScale(1) end
	end)
	g:SetScript("OnHide", stopResize)
	g:SetScript("OnUpdate", stepResize)
	UI.Tip(g, function()
		return UI.SimpleTip("크기 조절", ns.db.ui.locked and "전투 창이 잠겨 있습니다. 설정에서 잠금을 풀 수 있습니다."
			or string.format("끌어서 전투 창 크기를 바꿉니다 (지금 %d%%).\n우클릭: 원래 크기로", floor(frame:GetScale() * 100 + 0.5)))
	end)
	return g
end

function Bar.ApplyCompact()
	local compact = ns.db.ui.compact
	if compact then
		frame.dock:Hide()
		frame:SetHeight(8 + SCENE_H + 8)
	else
		frame.dock:Show()
		frame:SetHeight(8 + SCENE_H + 4 + DOCK_H + 6)
	end
end

local MENU = {
	{ "hero",  "INV_Helmet_06",          "영웅", "icon_hero" },
	{ "equip", "INV_Chest_Chain_05",     "장비", "icon_bag" },
	{ "forge", "Trade_BlackSmithing",    "용광로", "icon_forge" },
	{ "party", "INV_Misc_GroupNeedMore", "편성", "icon_party" },
	{ "runes", "INV_Misc_Rune_01",       "룬", "icon_runes" },
	{ "map",   "INV_Misc_Map_01",        "스테이지", "icon_map" },
	{ "pets",  "Ability_Hunter_BeastTaming", "동료", "icon_pets" },
}

function Bar.Create()
	if frame then return frame end
	frame = CreateFrame("Frame", "BigIdleHeroesBar", UIParent)
	frame:SetSize(W, 8 + SCENE_H + 4 + DOCK_H + 6)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	UI.Slice(frame, "shadow", "BACKGROUND", nil, 12)
	local body = UI.Slice(frame, "panel", "BACKGROUND")
	if UI.ArtUI("ui_battle_frame") then body:SetArt(UI.ArtUI("ui_battle_frame")) end
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not ns.db.ui.locked then self:StartMoving() end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Bar.SavePosition()
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then ns.Main.Toggle() end
	end)
	frame.grip = newGrip()

	-- scene -------------------------------------------------------------
	local scene = CreateFrame("Frame", nil, frame)
	scene:SetSize(SCENE_W, SCENE_H)
	scene:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	if scene.SetClipsChildren then scene:SetClipsChildren(true) end
	frame.scene = scene
	-- the backdrop: the place's picture and its mirror image side by side,
	-- scrolled (two pieces cover the scene at any time)
	frame.sky = scene:CreateTexture(nil, "BACKGROUND", nil, 0)
	frame.sky:SetAllPoints(scene)
	frame.sky:SetTexture(UI.Tex("scene_hills"))
	frame.sky2 = scene:CreateTexture(nil, "BACKGROUND", nil, 0)
	frame.sky2:SetTexture(UI.Tex("scene_hills"))
	frame.sky2:Hide()
	-- the ground: the place's terrain texture tiled along the bottom, its top
	-- edge fading into the backdrop
	frame.ground = scene:CreateTexture(nil, "BACKGROUND", nil, 2)
	frame.ground:SetPoint("BOTTOMLEFT", scene, "BOTTOMLEFT", 0, 0)
	frame.ground:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 0, 0)
	frame.ground:SetHeight(GROUND_H)
	-- drawn opaque: a terrain texture's alpha channel holds its shine, not
	-- how see-through it is (some places' ground would vanish)
	frame.ground:SetBlendMode("DISABLE")
	frame.ground:Hide()
	frame.groundFade = scene:CreateTexture(nil, "BACKGROUND", nil, 2)
	frame.groundFade:SetPoint("BOTTOMLEFT", frame.ground, "TOPLEFT", 0, 0)
	frame.groundFade:SetPoint("BOTTOMRIGHT", frame.ground, "TOPRIGHT", 0, 0)
	frame.groundFade:SetHeight(GROUND_FADE)
	frame.groundFade:Hide()
	-- (the scenery under everything, moving: the layout check leaves it out)
	for _, t in ipairs({ frame.sky, frame.sky2, frame.ground, frame.groundFade }) do t.isOverlay = true end
	local topShade = UI.Art(scene, "grad_v", "BORDER", 0, 0, 0, 0.6)
	topShade:SetPoint("TOPLEFT", scene, "TOPLEFT", 0, 0)
	topShade:SetPoint("TOPRIGHT", scene, "TOPRIGHT", 0, 0)
	topShade:SetHeight(40)
	-- the scene's rounded corners and its border line: on a layer above
	-- everything in it (the fighters and the scenery are frames of their own,
	-- drawn over the scene's own pictures), the corners outside the border's
	-- curve covered in the colour of the window around the scene
	local rim = CreateFrame("Frame", nil, scene)
	rim:SetAllPoints(scene)
	rim:SetFrameLevel(scene:GetFrameLevel() + 40)
	frame.rim = rim
	local corners = UI.Slice(rim, "corners", "BORDER", 10)
	corners:SetColor(0.10, 0.13, 0.21, 1)
	local edge = UI.Slice(rim, "frame", "OVERLAY", 10)
	edge:SetColor(0.14, 0.17, 0.27, 1)

	-- the place's own trees and rocks behind the fight, the fighters on a
	-- layer above them
	newScenery(scene)
	local units = CreateFrame("Frame", nil, scene)
	units:SetAllPoints(scene)
	units:SetFrameLevel(scene:GetFrameLevel() + 4)
	frame.units = units
	for i = 1, ns.PARTY_SIZE do heroFrames[i] = newHero(units) end
	for i = 1, MAX_MOBS do mobFrames[i] = newMob(units) end
	frame.pet = CreateFrame("Frame", nil, units)
	frame.pet:SetSize(20, 20)
	frame.pet.icon = frame.pet:CreateTexture(nil, "ARTWORK")
	frame.pet.icon:SetAllPoints(frame.pet)
	frame.pet:Hide()
	frame.petModel = Figure.New(units, PET_FIG)
	-- a companion's frame is far larger than the companion, so no part of a
	-- model (a long one, one fitted larger) is ever cut at its edges
	if frame.petModel and frame.petModel.SetRoom then frame.petModel:SetRoom(PET_ROOM, PET_ROOM_FEET) end
	frame.summons, frame.summonIcons = {}, {}
	for i = 1, 8 do
		frame.summons[i] = Figure.New(units, BACK_FIG)
		local ic = CreateFrame("Frame", nil, units)
		ic:SetSize(20, 20)
		ic.icon = ic:CreateTexture(nil, "ARTWORK")
		ic.icon:SetAllPoints(ic)
		ic:Hide()
		frame.summonIcons[i] = ic
	end

	-- everything drawn above the units lives on an overlay layer
	local over = CreateFrame("Frame", nil, scene)
	over:SetAllPoints(scene)
	over:SetFrameLevel(scene:GetFrameLevel() + 12)
	frame.over = over

	frame.banner = UI.Pill(over, 300, 24, 0.02, 0.03, 0.06, 0.5)
	frame.banner:SetPoint("TOPLEFT", scene, "TOPLEFT", 6, -5)
	frame.diffChip = UI.Pill(frame.banner, 52, 18, 0.3, 0.3, 0.3, 1)
	frame.diffChip:SetPoint("LEFT", frame.banner, "LEFT", 3, 0)
	frame.zone = UI.Text(frame.banner, 12)
	frame.zone:SetPoint("LEFT", frame.diffChip, "RIGHT", 6, 0)
	frame.zone:SetWordWrap(false)
	frame.zoneLv = UI.Text(frame.banner, 11)
	frame.zoneLv:SetPoint("LEFT", frame.zone, "RIGHT", 6, 0)
	UI.Color(frame.zoneLv, UI.C.gold)
	frame.note = UI.Text(over, 10)
	frame.note:SetPoint("TOPLEFT", frame.banner, "BOTTOMLEFT", 6, -2)
	UI.Color(frame.note, UI.C.sub)

	for i = 1, MAX_PIPS do
		local p = CreateFrame("Frame", nil, over)
		p:SetSize(16, 16)
		p.dot = UI.Art(p, "circle", "OVERLAY")
		p.dot:SetPoint("CENTER", p, "CENTER", 0, 0)
		pips[i] = p
	end

	frame.gold = UI.Pill(over, 118, 24, 0.02, 0.03, 0.06, 0.5)
	frame.gold:SetPoint("TOPRIGHT", scene, "TOPRIGHT", -6, -5)
	frame.gold.text:ClearAllPoints()
	frame.gold.text:SetPoint("RIGHT", frame.gold, "RIGHT", -10, 0)
	frame.gold.text:SetJustifyH("RIGHT")
	frame.gold.text:SetTextColor(1, 1, 1) -- the gold amount in white
	local coin = frame.gold:CreateTexture(nil, "OVERLAY")
	coin:SetSize(16, 16)
	coin:SetPoint("LEFT", frame.gold, "LEFT", 5, 0)
	UI.SetIcon(coin, "INV_Misc_Coin_01")

	-- the boss bar sits in the top row, where the wave dots are (the boss is
	-- always the last wave), so nothing in the fight below can cover it
	frame.bossBar = UI.Bar(over, 290, 16, 0.85, 0.15, 0.12)
	if UI.ArtUI("ui_boss_bar") then
		local deco = UI.Slice(frame.bossBar, "pill", "OVERLAY", 14, 10)
		deco:SetArt(UI.ArtUI("ui_boss_bar"))
	end
	frame.bossBar:SetPoint("CENTER", scene, "TOPLEFT", 418, -17)
	frame.bossBar:Hide()

	frame.result = UI.Text(over, 26, nil, "OUTLINE")

	frame.result.isOverlay = true -- "승리!" / "전멸..." over the fight
	frame.result:SetPoint("CENTER", scene, "CENTER", 0, -6)
	frame.result:SetJustifyH("CENTER")
	frame.result:Hide()


	for i = 1, MAX_FLOATS do
		local fs = UI.Text(over, 12, nil, "OUTLINE")
		fs:SetJustifyH("CENTER")
		fs.moving = true -- combat numbers fly over everything (the layout check skips them)
		fs:Hide()
		floats[i] = { fs = fs, active = false }
	end

	-- dock --------------------------------------------------------------
	local dock = CreateFrame("Frame", nil, frame)
	dock:SetSize(SCENE_W, DOCK_H)
	dock:SetPoint("TOPLEFT", scene, "BOTTOMLEFT", 0, -4)
	frame.dock = dock

	local goal = CreateFrame("Button", nil, dock)
	goal:SetSize(GOAL_W, 46)
	goal:SetPoint("LEFT", dock, "LEFT", 0, 0)
	goal.bg = UI.Slice(goal, "card", "BACKGROUND")
	goal.bg:SetColor(1, 1, 1, 1)
	goal.star = UI.Glyph(goal, "star", 22, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3])
	if UI.ArtPath("icon_goal") then
		goal.star:SetTexture(UI.ArtPath("icon_goal"))
		goal.star:SetVertexColor(1, 1, 1)
	end
	goal.star:SetPoint("LEFT", goal, "LEFT", 10, 0)
	goal.head = UI.Text(goal, 10, "추천")
	UI.Color(goal.head, UI.C.gold)
	goal.text = UI.Text(goal, 11)
	goal.text:SetPoint("TOPLEFT", goal.head, "BOTTOMLEFT", 0, -2)
	goal.text:SetWidth(GOAL_TEXT_W)
	goal.text:SetJustifyV("TOP")
	if goal.text.SetMaxLines then goal.text:SetMaxLines(2) end
	-- the heading and the goal (one or two lines) sit in the middle of the box
	function goal:Center()
		local lines = (self.text:GetStringWidth() > GOAL_TEXT_W - 2) and 2 or 1
		self.text:SetHeight(lines * 13 + 1)
		local h = 12 + 2 + lines * 13 + 1
		self.head:ClearAllPoints()
		self.head:SetPoint("TOPLEFT", self, "TOPLEFT", GOAL_TEXT_X, -math.floor((46 - h) / 2))
	end
	goal.arrow = goal:CreateTexture(nil, "OVERLAY")
	if UI.SetArrow(goal.arrow, "right", 0.7, 0.75, 0.9) then
		goal.arrow:SetSize(6, 11)
	else
		UI.SetGlyph(goal.arrow, "arrow", 0.7, 0.75, 0.9)
		goal.arrow:SetSize(14, 14)
	end
	goal.arrow:SetPoint("RIGHT", goal, "RIGHT", -8, 0)
	goal:RegisterForClicks("LeftButtonUp")
	goal:SetScript("OnClick", function()
		ns.Sound("click")
		Bar.FollowGoal()
	end)
	goal.onEnter = function(self) self.bg:SetColor(1.2, 1.2, 1.3, 1) end
	goal.onLeave = function(self) self.bg:SetColor(1, 1, 1, 1) end
	UI.Tip(goal, function()
		return UI.SimpleTip("추천", "지금 하면 좋은 일입니다. 클릭하면 바로 하거나 해당 화면을 엽니다.")
	end, "TOP")
	frame.goal = goal

	local auto = CreateFrame("Button", nil, dock)
	auto:SetSize(40, 49)
	auto:SetPoint("TOPLEFT", goal, "TOPRIGHT", 8, 1)
	auto.disc = UI.Art(auto, "circle", "BACKGROUND")
	auto.disc:SetSize(36, 36)
	auto.disc:SetPoint("TOP", auto, "TOP", 0, 0)
	auto.ringT = UI.Art(auto, "ring", "ARTWORK", 0.55, 0.62, 0.80)
	auto.ringT:SetSize(36, 36)
	auto.ringT:SetPoint("TOP", auto, "TOP", 0, 0)
	auto.glyph = UI.Glyph(auto, "auto", 24)
	auto.glyph:SetPoint("CENTER", auto.disc, "CENTER", 0, 0)
	auto.caption = UI.Text(auto, 10)
	auto.caption:SetPoint("TOP", auto.disc, "BOTTOM", 0, -1)
	auto.caption:SetJustifyH("CENTER")
	UI.Color(auto.caption, UI.C.sub)
	auto:RegisterForClicks("LeftButtonUp")
	auto:SetScript("OnClick", function()
		ns.Sound("click")
		ns.db.opt.auto = not ns.db.opt.auto
		ns.db.retry = 0
		updateInfo()
		ns.Fire("OPTIONS")
	end)
	UI.Tip(auto, function()
		return UI.SimpleTip("자동 진행",
			"켜면 스테이지를 깰 때마다 다음 스테이지로 넘어갑니다. 끄면 지금 스테이지를 반복해서 사냥합니다.")
	end, "TOP")
	frame.auto = auto

	frame.chests = {}
	for t = 1, #ns.CHEST do
		local cb = UI.IconButton(dock, 38, function(self, button)
			local how = (IsShiftKeyDown and IsShiftKeyDown()) and "all" or (button == "RightButton" and "kind" or "one")
			ns.Loot.OpenByHand(self.chestType, how)
			UI.RefreshTip()
		end)
		cb.chestType = t
		cb:SetArtIcon(({ "icon_chest_common", "icon_chest_boss", "icon_chest_raid" })[t], ns.CHEST[t].icon)
		-- the boxes have no caption: they sit on the dock's middle line
		cb:SetPoint("TOPLEFT", dock, "TOPLEFT", goal:GetWidth() + 8 + 40 + 8 + (t - 1) * 41, -(DOCK_H - 38) / 2)
		UI.Tip(cb, chestTip, "TOP")
		frame.chests[t] = cb
	end

	frame.menu = {}
	for i, m in ipairs(MENU) do
		local mb = UI.MenuButton(dock, 36, m[2], ns.N(m[3]), function(self) Bar.OpenMenu(self.key) end, m[4])
		mb.key = m[1]
		-- 44 apart: the captions (스테이지 is the widest) keep clear of each other
		mb:SetPoint("TOPLEFT", auto, "TOPRIGHT", 8 + #ns.CHEST * 41 + 2 + (i - 1) * 44, 0)
		frame.menu[i] = mb
	end

	frame:SetScript("OnUpdate", onUpdate)
	Bar.ApplyPosition()
	Bar.ApplyCompact()
	if ns.db.ui.shown == false then frame:Hide() end
	updateInfo()
	return frame
end

function Bar.OpenMenu(key)
	ns.Main.Toggle(true)
	ns.Main.ShowTab(key)
end

-- Carry out the guide's suggestion, or open the screen where it is done.
function Bar.FollowGoal()
	local goal = ns.Guide.Current()
	if goal.act then
		goal.act()
		ns.Guide.Invalidate()
		updateInfo()
		return
	end
	ns.Main.Toggle(true)
	if goal.hero then ns.Main.SelectHero(goal.hero) end
	ns.Main.ShowTab(goal.tab, goal)
end

function Bar.Toggle(show)
	if not frame then return end
	if show == nil then show = not frame:IsShown() end
	held = false
	ns.db.ui.shown = show and true or false
	if show then frame:Show() else frame:Hide() end
end

-- Before the first hero there is nothing to fight: the battle window waits
-- (the game starts with choosing a side and making a hero), then shows as
-- the settings say. The setting itself is left alone.
function Bar.Hold(on)
	if not frame then return end
	if on then
		held = true
		frame:Hide()
	elseif held then
		held = false
		if ns.db.ui.shown ~= false then frame:Show() end
	end
end
function Bar.IsHeld() return held end

function Bar.IsShown()
	return frame and frame:IsShown()
end

-- the unit frames (heroes, monsters), for the tests
function Bar.UnitFrames() return heroFrames, mobFrames end

function Bar.ResetPosition()
	ns.db.ui.barPos = nil
	ns.db.ui.barScale = nil
	if frame then Bar.ApplyPosition() end
end

------------------------------------------------------------------------
-- Toasts: short messages stacked above everything (dialog strata), next to
-- the menu window while it is open, otherwise above the battle window.
------------------------------------------------------------------------
local toast

local function placeToast()
	toast:ClearAllPoints()
	local main = ns.Main.Frame()
	if main and main:IsShown() then
		-- on the window's top edge, over the title: never over a button
		toast:SetScale(main:GetScale())
		toast:SetPoint("BOTTOM", main, "TOP", 0, -13)
	elseif frame and frame:IsShown() then
		toast:SetScale(frame:GetScale())
		toast:SetPoint("BOTTOM", frame, "TOP", 0, 6)
	else
		toast:SetScale(1)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
end

local function ensureToast()
	if toast then return toast end
	toast = CreateFrame("Frame", "BigIdleHeroesToast", UIParent)
	toast:SetSize(480, 90)
	toast:SetFrameStrata("DIALOG")
	toast:EnableMouse(false)
	toast.rows = {}
	for i = 1, 3 do
		local r = UI.Pill(toast, 480, 26, 0.02, 0.03, 0.06, 0.88)
		if UI.ArtUI("ui_toast") then r.bg:SetArt(UI.ArtUI("ui_toast")) end
		r:SetPoint("BOTTOM", toast, "BOTTOM", 0, (i - 1) * 29)
		r.text:SetWidth(460)
		r.text:SetWordWrap(false)
		r.t = 0
		r:Hide()
		toast.rows[i] = r
	end
	toast:SetScript("OnUpdate", function(self, elapsed)
		placeToast() -- follow the menu window as it opens and closes
		local any = false
		for _, r in ipairs(self.rows) do
			if r.t > 0 then
				r.t = r.t - elapsed
				if r.t <= 0 then r:Hide() else r:SetAlpha(min(1, r.t)) any = true end
			end
		end
		if not any then self:Hide() end
	end)
	return toast
end

ns.On("TOAST", function(msg)
	ensureToast()
	local rows = toast.rows
	-- newest on top: shift the others down
	for i = #rows, 2, -1 do
		local a, b = rows[i], rows[i - 1]
		a.text:SetText(b.text:GetText() or "")
		a.t = b.t
		if b.t > 0 then a:Show() a:SetAlpha(min(1, b.t)) else a:Hide() end
	end
	rows[1]:SetLabel(msg)
	rows[1].t = 5
	rows[1]:SetAlpha(1)
	rows[1]:Show()
	placeToast()
	toast:Show()
end)
