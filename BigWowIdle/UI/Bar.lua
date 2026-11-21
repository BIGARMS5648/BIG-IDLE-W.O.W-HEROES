-- Battle HUD: the party fights over a scene tinted to the current zone, with a
-- dock underneath for the next goal, chests and menu shortcuts.
local _, ns = ...

local floor, max, min, sin = math.floor, math.max, math.min, math.sin
local UI, U = ns.UI, ns.U

local Bar = {}
ns.Bar = Bar

local W = 720
local SCENE_W, SCENE_H = 704, 112
local DOCK_H = 54
local UNIT, BOSS = 34, 44
local MOB = 30
local FEET = 16       -- unit bottom above the scene's bottom edge
local MAX_MOBS = 12
local MAX_FLOATS = 28
local MAX_PIPS = 10

local frame
local heroFrames, mobFrames, floats, pips = {}, {}, {}, {}
local infoT = 0
local dt = 0 -- seconds since the last drawn frame
local HERO_FIG, MOB_FIG = 74, 70 -- sprite cell heights on screen
local Sprite = ns.Sprite

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
	u.cast = u:CreateTexture(nil, "OVERLAY")
	u.cast:SetSize(16, 16)
	u.cast:SetPoint("BOTTOM", u, "TOP", 0, 3)
	u.cast:Hide()
	u.sprite = Sprite.New(parent, HERO_FIG)
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
	u.crown = UI.Glyph(u, "crown", 16, 1, 0.8, 0.25)
	u.crown:SetPoint("BOTTOM", u, "TOP", 0, 1)
	u.crown:Hide()
	u.hp = UI.Bar(u, MOB, 4, 0.9, 0.2, 0.15)
	u.hp:SetPoint("TOP", u, "BOTTOM", 0, -2)
	u.sprite = Sprite.New(parent, MOB_FIG)
	u.sprite:SetFacing("left")
	u:Hide()
	return u
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

-- A soft colour per monster so monsters sharing one drawing look different.
local function tintFor(key)
	local h = 0
	for i = 1, #key do h = (h * 31 + key:byte(i)) % 997 end
	local k = h / 997
	return 0.78 + 0.22 * k, 0.78 + 0.22 * ((k * 7) % 1), 0.78 + 0.22 * ((k * 13) % 1)
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
				UI.SetClassIcon(f.icon, u.class)
				f.ring:SetVertexColor(U.rgb(ns.ROLE[u.role].hex))
			end
			local px = spread[i]
			local moving = f.prevX and math.abs(u.x - f.prevX) > 0.01
			f.prevX = u.x
			local sid = Sprite.ForHero(u.id, true)
			if sid and f.sprite:SetSprite(sid) then
				if f.spriteFor ~= u.id then
					f.spriteFor = u.id
					f.sprite:SetHeight2(HERO_FIG * Sprite.HeroScale(u.id))
				end
				local want = "idle"
				if u.dead then want = "death"
				elseif (u.castT or 0) > 0.6 then want = "cast"
				elseif u.anim > 0 then want = "attack"
				elseif u.flash > 0.05 then want = "hit"
				elseif ns.Combat.state.phase == "travel" or moving then want = "walk" end
				animate(f.sprite, want)
				f.sprite:PlaceFeet(frame.scene, px + UNIT / 2, FEET + 2)
				f.sprite:SetAlpha(u.dead and 0.6 or 1)
				f.sprite:Show()
				f.disc:Hide()
				f.icon:Hide()
				f.ring:Hide()
			else
				f.sprite:Hide()
				f.disc:Show()
				f.icon:Show()
				f.ring:Show()
				if u.anim > 0 then px = px + 4 end
			end
			local bob = (not u.dead and ns.Combat.state.phase == "travel" and not f.sprite:IsShown()) and (sin(now * 10 + i) * 1.5) or 0
			place(f, px, FEET + bob)
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
			if u.flash > 0 then f.flash:Show() else f.flash:Hide() end
			if (u.castT or 0) > 0 and u.castIcon then
				if f.castIcon ~= u.castIcon then
					f.castIcon = u.castIcon
					UI.SetIcon(f.cast, u.castIcon)
				end
				f.cast:SetAlpha(min(1, u.castT / 0.3))
				f.cast:Show()
			else
				f.cast:Hide()
			end
			f:Show()
		else
			f:Hide()
			f.sprite:Hide()
			f.shownId = nil
		end
	end
	-- the summoned companion trots behind the party
	local pet = ns.db.pet and ns.PET_BY_ID[ns.db.pet]
	if pet and backX and ns.db.pets[pet.id] then
		if frame.pet.shownId ~= pet.id then
			frame.pet.shownId = pet.id
			UI.SetIcon(frame.pet.icon, pet.icon)
		end
		local minX = laneX(backX) - UNIT / 2
		for i = 1, #list do if spread[i] and spread[i] < minX then minX = spread[i] end end
		local psid = Sprite.ForPet(pet.id)
		if psid and frame.petSprite:SetSprite(psid) then
			animate(frame.petSprite, ns.Combat.state.phase == "travel" and "walk" or "idle")
			frame.petSprite:PlaceFeet(frame.scene, max(14, minX - 14), FEET + 2)
			frame.petSprite:Show()
			frame.pet:Hide()
		else
			frame.petSprite:Hide()
			place(frame.pet, max(2, minX - 26), FEET + 2 + sin(now * 5) * 2)
			frame.pet:Show()
		end
	else
		frame.pet:Hide()
		frame.petSprite:Hide()
	end
	-- summoned creatures, turrets and drones (only drawn with art)
	local k = 0
	for i = 1, #list do
		local u = list[i]
		if not u.dead and spread[i] then
			for sid, pt in pairs(u.pets) do
				local art = Sprite.ForSkill(sid)
				if art and k < #frame.summons then
					k = k + 1
					local sp = frame.summons[k]
					if sp:SetSprite(art) then
						animate(sp, (pt.anim or 0) > 0 and "attack" or "idle")
						local fly = ns.SKILLS[sid].heal and 34 or 0
						sp:PlaceFeet(frame.scene, spread[i] + UNIT / 2 + 18, FEET + fly + (fly > 0 and sin(now * 3 + i) * 3 or 0))
						sp:Show()
					end
				end
			end
		end
	end
	for _, f in ipairs(ns.Combat.fields) do
		local art = f.sk.summon and Sprite.Get(f.sk.summon) and f.sk.summon
		if art and k < #frame.summons and not f.src.dead then
			k = k + 1
			local sp = frame.summons[k]
			sp:SetSprite(art)
			animate(sp, (f.tickT or 0) > f.sk.tick - 0.25 and "attack" or "idle")
			sp:PlaceFeet(frame.scene, laneX(f.src.x) + 34, FEET)
			sp:Show()
		end
	end
	for i = k + 1, #frame.summons do frame.summons[i]:Hide() end
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
					f.crown:Show()
				else
					f.edge:SetVertexColor(0.85, 0.2, 0.15)
					f.crown:Hide()
				end
			end
			local px = laneX(m.x) - size / 2
			local sid = Sprite.ForMonster(m.def and m.def.id, m.boss and Sprite.BossKey(m.name), m.boss and m.type)
			if sid and f.sprite:SetSprite(sid) then
				if f.spriteMob ~= m then
					f.spriteMob = m
					f.sprite:SetHeight2(MOB_FIG * (m.boss and 1.4 or 1))
					local tr, tg, tb = tintFor((m.def and m.def.id) or ns.N(m.name) or "?")
					f.sprite.tex:SetVertexColor(tr, tg, tb)
					f.sprite.prevX = nil
				end
				local moving = f.sprite.prevX and math.abs(m.x - f.sprite.prevX) > 0.01
				f.sprite.prevX = m.x
				local want = "idle"
				if m.dead then want = "death"
				elseif m.anim > 0 then want = "attack"
				elseif m.flash > 0.05 then want = "hit"
				elseif moving then want = "walk" end
				animate(f.sprite, want)
				f.sprite:PlaceFeet(frame.scene, px + size / 2, FEET + (m.boss and 0 or (m.off / 12) * 3))
				f.sprite:SetAlpha(m.dead and max(0, (m.fade or 0) / 0.4) or 1)
				f.sprite:Show()
				f.back:Hide()
				f.icon:Hide()
				f.edge:Hide()
			else
				f.sprite:Hide()
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
			if m.flash > 0 then f.flash:Show() else f.flash:Hide() end
			f:Show()
		else
			f:Hide()
			f.sprite:Hide()
			f.spriteMob = nil
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
	local n = max(1, min(MAX_PIPS, st.waves or 10))
	local wave = st.wave or 0
	local x0 = 418 - (n - 1) * 8 -- centred between the zone banner and the gold
	for i = 1, MAX_PIPS do
		local p = pips[i]
		if i <= n then
			p:ClearAllPoints()
			p:SetPoint("CENTER", frame.scene, "TOPLEFT", x0 + (i - 1) * 16, -17)
			local isBoss = i == n
			p.dot:SetTexture(UI.Tex(isBoss and "skull" or "circle"))
			local size = isBoss and 16 or 9
			if i < wave or (i == wave and st.phase ~= "fight") then
				p.dot:SetVertexColor(1, 0.80, 0.28) -- cleared
			elseif i == wave then
				local k = 0.75 + 0.25 * sin(now * 6)
				p.dot:SetVertexColor(k, k, k) -- in progress
				size = size + 2
			else
				p.dot:SetVertexColor(0.22, 0.25, 0.33) -- ahead
			end
			if isBoss and i >= wave then
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

	-- scenery
	if frame.themeKey ~= stg.theme then
		frame.themeKey = stg.theme
		local th = ns.THEMES[stg.theme] or ns.THEMES.forest
		frame.sky:SetTexture(UI.Tex(th.art))
		frame.sky:SetVertexColor(th.rgb[1] * 0.85, th.rgb[2] * 0.85, th.rgb[3] * 0.85)
	end

	-- zone banner
	local r, g, b = U.rgb(d.hex)
	frame.diffChip:SetColor(r * 0.55, g * 0.55, b * 0.55, 0.95)
	frame.diffChip:SetLabel(ns.N(d.name))
	local act, n = ns.StageAct(idx)
	local zone = string.format("%d-%d %s", act, n, ns.N(stg.name))
	if stg.raid then zone = zone .. "  " .. U.col("ff9326", "공격대") end
	frame.zone:SetText(zone)
	frame.zoneLv:SetText("Lv " .. ns.StageLevel(diff, idx))
	-- the banner never reaches the wave dots: long names are cut short
	local room = 250 - 70 - frame.zoneLv:GetStringWidth()
	frame.zone:SetWidth(min(room, frame.zone:GetStringWidth() + 2))
	frame.banner:SetWidth(min(250, frame.zone:GetWidth() + frame.zoneLv:GetStringWidth() + 80))

	-- scenery: imported two-layer background, else the tinted built-in one
	if frame.bgTheme ~= stg.theme then
		frame.bgTheme = stg.theme
		if frame.bg:SetTheme(stg.theme) then
			frame.sky:Hide()
		else
			frame.bg:Hide()
			frame.sky:Show()
		end
	end

	frame.gold:SetLabel(U.fmt(db.gold))

	-- retry note under the banner
	if (db.retry or 0) > 0 and db.opt.auto then
		frame.note:SetText(string.format("힘을 기르는 중 · 재도전까지 %d회", db.retry))
	elseif st.phase == "idle" then
		frame.note:SetText("영웅을 만들어 파티에 넣으세요")
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
		if count >= ns.ChestCap(t) then cb:SetBorderRGB(1, 0.25, 0.2) else cb:SetQuality(t == 1 and 3 or (t == 2 and 5 or 6)) end
	end
	local auto = db.opt.auto
	frame.auto.glyph:SetVertexColor(auto and 0.15 or 0.75, auto and 0.12 or 0.78, auto and 0.05 or 0.85)
	frame.auto.disc:SetVertexColor(auto and 1 or 0.14, auto and 0.78 or 0.17, auto and 0.25 or 0.26)
	frame.auto.caption:SetText(auto and "자동 진행" or "반복")

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

local function drawEffects(elapsed)
	local list = ns.Combat.vfx
	if not frame.fxOn then
		for i = #list, 1, -1 do list[i] = nil end
		return
	end
	for i = 1, #list do
		local e = list[i]
		list[i] = nil
		local w
		for _, cand in ipairs(frame.fxPool) do
			if not cand.active then w = cand break end
		end
		if w then
			if e.k == "shot" then
				local id = Sprite.Projectile(e.school, e.gun)
				if id and w:Start(id, 26, 26, 0.25, 16) then
					w.x1, w.x2, w.y = laneX(e.x1) + 10, laneX(e.x2), FEET + 30
				end
			elseif e.k == "hit" then
				local id = Sprite.Impact(e.school)
				if id and w:Start(id, 44, 44, nil, 18) then
					w.x1, w.x2, w.y = laneX(e.x) + math.random(-6, 6), nil, FEET + 22 + math.random(0, 10)
				end
			end
		end
	end
	for _, w in ipairs(frame.fxPool) do
		if w.active and w:Step(elapsed) then
			local x = w.x1
			if w.x2 then x = w.x1 + (w.x2 - w.x1) * math.min(1, w.t / w.life) end
			w:ClearAllPoints()
			w:SetPoint("CENTER", frame.scene, "BOTTOMLEFT", x, w.y)
		end
	end
	-- ground effects of area skills
	local n = 0
	for _, f in ipairs(ns.Combat.fields) do
		local id = not f.sk.summon and Sprite.Field(f.sk.id, f.sk.school)
		if id and n < #frame.fieldFx then
			n = n + 1
			local w = frame.fieldFx[n]
			if w.field ~= f then
				w.field = f
				w:Start(id, 150, 75, 999, 12)
			end
			w:Step(elapsed)
			local target = ns.Combat.mobs[1]
			local x = target and laneX(target.x) or SCENE_W * 0.75
			w:ClearAllPoints()
			w:SetPoint("BOTTOM", frame.scene, "BOTTOMLEFT", x, FEET - 8)
		end
	end
	for i = n + 1, #frame.fieldFx do
		frame.fieldFx[i].field = nil
		frame.fieldFx[i]:Stop()
	end
end

local function onUpdate(self, elapsed)
	local now = GetTime()
	dt = elapsed
	if ns.Combat.state.phase == "travel" then frame.bg:Scroll(elapsed * 80) end
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
	drawEffects(elapsed)
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
	if ns.Bonus("autoOpen") > 0 then
		local left = max(0, ns.Loot.AutoInterval(t) - (ns.db.autoT[t] or 0))
		lines[#lines + 1] = { "자동 개봉까지", U.time(left), 0.5, 1, 0.5 }
	else
		lines[#lines + 1] = { "'개봉의 룬'을 배우면 자동으로 열립니다.", nil, 0.6, 0.6, 0.6 }
	end
	lines[#lines + 1] = { "클릭: 모두 열기", nil, 0.45, 0.8, 1 }
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
	{ "hero",  "INV_Helmet_06",          "영웅" },
	{ "equip", "INV_Chest_Chain_05",     "장비" },
	{ "party", "INV_Misc_GroupNeedMore", "편성" },
	{ "runes", "INV_Misc_Rune_01",       "룬" },
	{ "map",   "INV_Misc_Map_01",        "스테이지" },
	{ "pets",  "Ability_Hunter_BeastTaming", "동료" },
}

function Bar.Create()
	if frame then return frame end
	frame = CreateFrame("Frame", "BigWowIdleBar", UIParent)
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
	frame.sky = scene:CreateTexture(nil, "BACKGROUND")
	frame.sky:SetAllPoints(scene)
	frame.sky:SetTexture(UI.Tex("scene_hills"))
	frame.bg = Sprite.NewBackground(scene, SCENE_W, SCENE_H)
	local topShade = UI.Art(scene, "grad_v", "BORDER", 0, 0, 0, 0.6)
	topShade:SetPoint("TOPLEFT", scene, "TOPLEFT", 0, 0)
	topShade:SetPoint("TOPRIGHT", scene, "TOPRIGHT", 0, 0)
	topShade:SetHeight(40)
	local edge = UI.Slice(scene, "frame", "OVERLAY", 10)
	edge:SetColor(0.14, 0.17, 0.27, 1)

	for i = 1, ns.PARTY_SIZE do heroFrames[i] = newHero(scene) end
	for i = 1, MAX_MOBS do mobFrames[i] = newMob(scene) end
	frame.pet = CreateFrame("Frame", nil, scene)
	frame.pet:SetSize(20, 20)
	frame.pet.icon = frame.pet:CreateTexture(nil, "ARTWORK")
	frame.pet.icon:SetAllPoints(frame.pet)
	frame.pet:Hide()
	frame.petSprite = Sprite.New(scene, 40)
	frame.summons = {}
	for i = 1, 8 do frame.summons[i] = Sprite.New(scene, 52) end

	-- everything drawn above the units lives on an overlay layer
	local over = CreateFrame("Frame", nil, scene)
	over:SetAllPoints(scene)
	over:SetFrameLevel(scene:GetFrameLevel() + 12)
	frame.over = over

	frame.banner = UI.Pill(over, 300, 24, 0.02, 0.03, 0.06, 0.72)
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

	frame.gold = UI.Pill(over, 118, 24, 0.02, 0.03, 0.06, 0.72)
	frame.gold:SetPoint("TOPRIGHT", scene, "TOPRIGHT", -6, -5)
	frame.gold.text:ClearAllPoints()
	frame.gold.text:SetPoint("RIGHT", frame.gold, "RIGHT", -10, 0)
	frame.gold.text:SetJustifyH("RIGHT")
	UI.Color(frame.gold.text, UI.C.gold)
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

	frame.fxPool = {}
	for i = 1, 14 do frame.fxPool[i] = Sprite.NewFX(over) end
	frame.fieldFx = {}
	for i = 1, 3 do frame.fieldFx[i] = Sprite.NewFX(scene, "BORDER") end
	frame.fxOn = next((ns.ART and ns.ART.fx) or {}) ~= nil

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
	goal:SetSize(262, 46)
	goal:SetPoint("LEFT", dock, "LEFT", 0, 0)
	goal.bg = UI.Slice(goal, "card", "BACKGROUND")
	goal.bg:SetColor(1, 1, 1, 1)
	goal.star = UI.Glyph(goal, "star", 22, UI.C.gold[1], UI.C.gold[2], UI.C.gold[3])
	if UI.ArtPath("icon_goal") then
		goal.star:SetTexture(UI.ArtPath("icon_goal"))
		goal.star:SetVertexColor(1, 1, 1)
	end
	goal.star:SetPoint("LEFT", goal, "LEFT", 10, 0)
	goal.head = UI.Text(goal, 10, "다음 목표")
	UI.Color(goal.head, UI.C.gold)
	goal.text = UI.Text(goal, 11)
	goal.text:SetPoint("TOPLEFT", goal.head, "BOTTOMLEFT", 0, -2)
	goal.text:SetWidth(200)
	goal.text:SetJustifyV("TOP")
	if goal.text.SetMaxLines then goal.text:SetMaxLines(2) end
	-- the heading and the goal (one or two lines) sit in the middle of the box
	function goal:Center()
		local lines = (self.text:GetStringWidth() > 198) and 2 or 1
		self.text:SetHeight(lines * 13 + 1)
		local h = 12 + 2 + lines * 13 + 1
		self.head:ClearAllPoints()
		self.head:SetPoint("TOPLEFT", self, "TOPLEFT", 40, -math.floor((46 - h) / 2))
	end
	goal.arrow = UI.Glyph(goal, "arrow", 14, 0.7, 0.75, 0.9)
	goal.arrow:SetPoint("RIGHT", goal, "RIGHT", -8, 0)
	goal:RegisterForClicks("LeftButtonUp")
	goal:SetScript("OnClick", function()
		ns.Sound("click")
		Bar.FollowGoal()
	end)
	goal.onEnter = function(self) self.bg:SetColor(1.2, 1.2, 1.3, 1) end
	goal.onLeave = function(self) self.bg:SetColor(1, 1, 1, 1) end
	UI.Tip(goal, function()
		return UI.SimpleTip("다음 목표", "지금 하면 좋은 일입니다. 클릭하면 바로 하거나 해당 화면을 엽니다.")
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
	auto.glyph = UI.Glyph(auto, "auto", 22)
	auto.glyph:SetPoint("CENTER", auto.disc, "CENTER", 0, 0)
	auto.caption = UI.Text(auto, 10)
	auto.caption:SetPoint("TOP", auto.disc, "BOTTOM", 0, -1)
	auto.caption:SetJustifyH("CENTER")
	UI.Color(auto.caption, UI.C.sub)
	auto:RegisterForClicks("LeftButtonUp")
	auto:SetScript("OnClick", function()
		ns.Sound("click")
		ns.db.opt.auto = not ns.db.opt.auto
		if ns.db.opt.auto then ns.db.retry = 0 end
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
		local cb = UI.IconButton(dock, 38, function(self)
			ns.Loot.OpenAll(self.chestType)
			UI.RefreshTip()
		end)
		cb.chestType = t
		cb:SetArtIcon(({ "icon_chest_common", "icon_chest_boss", "icon_chest_raid" })[t], ns.CHEST[t].icon)
		cb:SetPoint("TOPLEFT", auto, "TOPRIGHT", 8 + (t - 1) * 41, 1)
		UI.Tip(cb, chestTip, "TOP")
		frame.chests[t] = cb
	end

	frame.menu = {}
	for i, m in ipairs(MENU) do
		local mb = UI.MenuButton(dock, 36, m[2], ns.N(m[3]), function(self) Bar.OpenMenu(self.key) end)
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
	ns.db.ui.shown = show and true or false
	if show then frame:Show() else frame:Hide() end
end

function Bar.IsShown()
	return frame and frame:IsShown()
end

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
	toast = CreateFrame("Frame", "BigWowIdleToast", UIParent)
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
