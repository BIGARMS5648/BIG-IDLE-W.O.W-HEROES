-- Combat audit: every combat formula measured in controlled fights.
--
--   python3 tests/run.py audit
--
-- Each test pins a hero's stats (tests/combat_lab.lua), runs the real combat
-- for a while against made-up monsters, and compares what the recorded
-- damage, healing and casts add up to with what the formula (and the stat
-- sheet, and the skill text) promises. Random rolls are checked with
-- tolerances of about three standard deviations.
local ns = NS
local here = debug.getinfo(1, "S").source:sub(2):gsub("combat_audit%.lua$", "")
local L = dofile(here .. "combat_lab.lua")
local check, section, near, f, mean, lab = L.check, L.section, L.near, L.f, L.mean, L.lab
local abs, max, min, floor, sqrt = math.abs, math.max, math.min, math.floor, math.sqrt
math.randomseed(20261121)

local function pctTol(p, n) return 3.5 * sqrt(p * (1 - p) / max(1, n)) + 0.005 end

------------------------------------------------------------------------
section("영웅 기본 공격")
------------------------------------------------------------------------
do -- attack speed and the base hit
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 2 } } }, hp = 1e12, n = 1, seconds = 60 })
	local hits = L.basics(log, u[1])
	local rate = (#hits - 1) / (hits[#hits].t - hits[1].t)
	check(near(rate, 2, 0.02), "공격 속도 2.0/초 → 초당 기본 공격 수", f(rate, 2) .. "회/초")
	local lo, hi = 1e9, 0
	local r = {}
	for _, e in ipairs(hits) do lo, hi = min(lo, e.a), max(hi, e.a) r[#r + 1] = e.a / 1000 end
	check(lo >= 950 - 1e-6 and hi <= 1050 + 1e-6, "기본 공격 피해 = 공격력 × 0.95~1.05", f(lo, 0) .. "~" .. f(hi, 0))
	check(near(mean(r), 1, 0.01), "기본 공격 평균 = 공격력", f(mean(r), 3) .. "배")
	L.endLab()
end

do -- critical hits
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 5, crit = 30, critdmg = 250 } } }, hp = 1e12, seconds = 150 })
	local hits = L.basics(log, u[1])
	local nc, cr, ncA, crA = 0, 0, {}, {}
	for _, e in ipairs(hits) do
		if e.crit then cr = cr + 1 crA[#crA + 1] = e.a else nc = nc + 1 ncA[#ncA + 1] = e.a end
	end
	local p = cr / #hits
	check(abs(p - 0.30) <= pctTol(0.3, #hits), "치명타 확률 30% → 치명타 비율", f(p * 100, 1) .. "% (" .. #hits .. "회)")
	local ratio = mean(crA) / mean(ncA)
	check(near(ratio, 2.5, 0.03), "치명타 피해 250% → 치명타 / 일반 피해", f(ratio, 3) .. "배")
	L.endLab()
end

do -- multistrike: an extra hit at half strength
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 5, multi = 40 } } }, hp = 1e12, seconds = 150 })
	local full, half = L.basics(log, u[1], 1), L.basics(log, u[1], 0.5)
	local p = #half / #full
	check(abs(p - 0.40) <= pctTol(0.4, #full), "연속 타격 40% → 추가 타격 비율", f(p * 100, 1) .. "%")
	check(near(mean((function() local t = {} for _, e in ipairs(half) do t[#t + 1] = e.a end return t end)()), 500, 0.02),
		"추가 타격 피해 = 공격력의 50%")
	L.endLab()
end

do -- damage of the hero's school and 모든 피해
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 3, dmg_fire = 50, dmg_all = 10, dmg_frost = 90 } } }, hp = 1e12, seconds = 60 })
	local r = {}
	for _, e in ipairs(L.basics(log, u[1])) do r[#r + 1] = e.a / 1000 end
	check(near(mean(r), 1.6, 0.01), "화염 피해 +50% · 모든 피해 +10% (냉기 +90%는 무관) → 화염 공격", f(mean(r), 3) .. "배")
	L.endLab()
end

do -- health on hit and life steal
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 2, hph = 37, leech = 10 } } }, hp = 1e12, seconds = 40,
		each = function(step, us) if us[1] then us[1].hp = us[1].maxhp * 0.5 end end })
	local hits = L.basics(log, u[1])
	local onHit, steal = 0, {}
	for _, e in ipairs(log.heal) do
		if e.src == nil and e.tgt == u[1] then
			if math.abs(e.a - 37) < 1e-9 then onHit = onHit + 1 else steal[#steal + 1] = e.a end
		end
	end
	check(onHit == #hits, "적중 시 생명력 37 → 기본 공격마다 37 회복", onHit .. " / " .. #hits .. "회")
	local outs = 0
	for _, e in ipairs(log.mob) do if e.src == u[1] and not e.dot then outs = outs + e.out end end
	check(near(mean(steal) * #steal, outs * 0.10, 0.01), "생명력 흡수 10% → 준 피해의 10% 회복", f(mean(steal) * #steal, 0) .. " / " .. f(outs * 0.1, 0))
	L.endLab()
end

do -- the stat sheet's "초당 피해(추정)" against a real fight (basic attacks only)
	local stats = { atk = 1000, aspd = 3, crit = 25, critdmg = 200, multi = 30, dmg_fire = 20 }
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = stats } }, hp = 1e12, seconds = 200 })
	local total, t0, t1 = 0, nil, nil
	for _, e in ipairs(log.mob) do
		if e.src == u[1] and not e.dot and e.cast == nil then total = total + e.out t0 = t0 or e.t t1 = e.t end
	end
	local measured = total / (t1 - t0 + 1 / 3)
	local shown = ns.Stats.DPS(u[1].s)
	check(near(measured, shown, 0.04), "영웅 탭 '초당 피해(추정)' = 실제 기본 공격 초당 피해", f(shown, 0) .. " / 실제 " .. f(measured, 0))
	L.endLab()
end

------------------------------------------------------------------------
section("영웅 방어")
------------------------------------------------------------------------
-- a tank that cannot die, one monster that hits for 100 twice a second
local function defense(stats, mob, seconds, each)
	stats.hp = stats.hp or 1e9
	stats.atk = stats.atk or 1
	return lab({ heroes = { { spec = "WARRIOR_PROT", stats = stats } }, hp = 1e12, atk = 100,
		mob = mob or { aspd = 2 }, seconds = seconds or 120, each = each })
end
local function hits(log, u)
	local t = {}
	for _, e in ipairs(log.hero) do if e.h == u and not e.dot then t[#t + 1] = e end end
	return t
end

do
	local u, log = defense({ dodge = 25 })
	local hs = hits(log, u[1])
	local z = 0
	for _, e in ipairs(hs) do if e.out == 0 then z = z + 1 end end
	check(abs(z / #hs - 0.25) <= pctTol(0.25, #hs), "회피 25% → 피한 공격 비율", f(z / #hs * 100, 1) .. "% (" .. #hs .. "회)")
	L.endLab()
end
do
	local u, log = defense({ block = 40 })
	local hs = hits(log, u[1])
	local b = 0
	for _, e in ipairs(hs) do if near(e.out, e.a * 0.5, 1e-6) then b = b + 1 end end
	check(abs(b / #hs - 0.40) <= pctTol(0.4, #hs), "막기 40% → 절반만 받은 공격 비율", f(b / #hs * 100, 1) .. "%")
	L.endLab()
end
do
	local u, log = defense({ armor = 500 })
	local want = 1 - ns.Stats.ArmorDR(500, L.st.level)
	local r = {}
	for _, e in ipairs(hits(log, u[1])) do r[#r + 1] = e.out / e.a end
	check(near(mean(r), want, 1e-6), "방어도 500 → 물리 피해 × (1 - 방어도/(방어도+K))", f(mean(r), 4) .. " / " .. f(want, 4))
	local shown
	for _, g in ipairs(ns.Stats.Groups(u[1].id)) do
		for _, r in ipairs(g[2]) do if r[1] == "물리 피해 감소" then shown = tonumber((r[2]:gsub("%%", ""))) end end
	end
	check(shown and abs(shown - (1 - want) * 100) < 0.06, "영웅 탭 '물리 피해 감소' = 전투에서 실제로 줄어드는 비율",
		"탭 " .. tostring(shown) .. "% / 전투 " .. f((1 - want) * 100, 1) .. "% (영웅 Lv " .. ns.db.heroes[u[1].id].level .. ", 지역 Lv " .. L.st.level .. ")")
	L.endLab()
end
do
	local u, log = defense({ res_fire = 30, allres = 10 }, { aspd = 2, school = "fire" })
	local r = {}
	for _, e in ipairs(hits(log, u[1])) do r[#r + 1] = e.out / e.a end
	check(near(mean(r), 0.6, 1e-6), "화염 저항 30% + 모든 원소 저항 10% → 화염 피해 × 0.6", f(mean(r), 4))
	L.endLab()
	u, log = defense({ res_fire = 70, allres = 30 }, { aspd = 2, school = "fire" })
	r = {}
	for _, e in ipairs(hits(log, u[1])) do r[#r + 1] = e.out / e.a end
	check(near(mean(r), 0.25, 1e-6), "저항 합 100% → 최대 75%까지만 (× 0.25)", f(mean(r), 4))
	L.endLab()
	u, log = defense({ res_fire = 60 }, { aspd = 2, school = "frost" })
	r = {}
	for _, e in ipairs(hits(log, u[1])) do r[#r + 1] = e.out / e.a end
	check(near(mean(r), 1, 1e-6), "화염 저항은 냉기 피해를 줄이지 않음", f(mean(r), 4))
	L.endLab()
end
do
	local u, log = defense({ dr = 20 })
	local r = {}
	for _, e in ipairs(hits(log, u[1])) do r[#r + 1] = e.out / e.a end
	check(near(mean(r), 0.8, 1e-6), "받는 피해 감소 20% → × 0.8", f(mean(r), 4))
	L.endLab()
end
do
	local u, log = defense({ absorb = 30 })
	local okAll = true
	for _, e in ipairs(hits(log, u[1])) do if not near(e.out, max(1, e.a - 30), 1e-6) then okAll = false end end
	check(okAll, "피해 흡수 30 → 맞을 때마다 30 덜 받음 (최소 1)")
	L.endLab()
end
do -- thorns: what a melee attacker gets back
	local u, log = defense({ atk = 200, thorns = 50, dodge = 50 })
	local attacks, dodged, thorns = 0, 0, {}
	for _, e in ipairs(hits(log, u[1])) do
		attacks = attacks + 1
		if e.out == 0 then dodged = dodged + 1 end
	end
	for _, e in ipairs(log.mob) do if e.src == u[1] and e.school == "nature" and e.mult == nil and not e.dot then thorns[#thorns + 1] = e.a end end
	check(near(mean(thorns), 100, 1e-6), "가시 반사 50% → 공격력 200의 50% = 100 자연 피해", f(mean(thorns), 1))
	check(#thorns == attacks - dodged, "가시 반사는 실제로 맞은 공격에만 (회피한 공격 제외)",
		"반사 " .. #thorns .. "회 / 공격 " .. attacks .. "회 (회피 " .. dodged .. "회)")
	L.endLab()
	u, log = defense({ atk = 200, thorns = 50 }, { aspd = 2, range = 400 })
	thorns = 0
	for _, e in ipairs(log.mob) do if e.src == u[1] and e.school == "nature" and e.mult == nil then thorns = thorns + 1 end end
	check(thorns == 0, "원거리 공격자에게는 가시 반사 없음", thorns .. "회")
	L.endLab()
end
do -- regeneration
	local u, log = defense({ regen = 50, regenPct = 1, hp = 1e6 }, { aspd = 0.001 }, 20,
		function(step, us) if step == 50 then us[1].hp = us[1].maxhp * 0.5 L.mark = us[1].hp end if step == 150 then L.mark2 = us[1].hp end end)
	local gained = (L.mark2 - L.mark) / 10
	check(near(gained, 50 + 1e6 * 0.01, 0.02), "초당 생명력 회복 50 + 최대의 1% → 초당 10,050", f(gained, 0) .. "/초")
	L.endLab()
end
do -- on a kill
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1e6, aspd = 2, hpk = 100, hpkPct = 2, hp = 1e6 } } },
		hp = 50, n = 4, seconds = 60, each = function(step, us) if us[1] then us[1].hp = us[1].maxhp * 0.5 end end })
	local onKill = {}
	for _, e in ipairs(log.heal) do if e.src == nil and e.tgt == u[1] then onKill[#onKill + 1] = e.a end end
	local kills = 0
	for _, k in ipairs(log.kill) do if k.killer == u[1] then kills = kills + 1 end end
	check(kills > 10 and #onKill == kills and near(mean(onKill), 100 + 1e6 * 0.02, 1e-6),
		"처치 시 생명력 100 + 최대의 2% → 처치마다 20,100 회복", #onKill .. "회 / 처치 " .. kills .. "회, 평균 " .. f(mean(onKill), 0))
	L.endLab()
end

------------------------------------------------------------------------
section("기술 발동 · 재사용 대기시간 · 시전 속도")
------------------------------------------------------------------------
local function castTimes(log, sid)
	local t = {}
	for _, e in ipairs(log.cast) do if e.sid == sid then t[#t + 1] = e.t end end
	return t
end
local function gaps(t)
	local g = {}
	for i = 2, #t do g[#g + 1] = t[i] - t[i - 1] end
	return g
end
for _, case in ipairs({ { 0, 0 }, { 50, 0 }, { 0, 30 }, { 50, 30 } }) do
	local cast, cdr = case[1], case[2]
	local u, log = lab({ heroes = { { spec = "WARRIOR_FURY", skills = { "whirlwind" }, stats = { atk = 100, aspd = 1, cast = cast, cdr = cdr } } },
		hp = 1e12, n = 3, seconds = 120 })
	local want = ns.SkillCooldown("whirlwind", 1) * (1 - cdr / 100) / (1 + cast / 100)
	local g = gaps(castTimes(log, "whirlwind"))
	check(#g > 5 and abs(mean(g) - want) <= 0.1 + 1e-6,
		string.format("소용돌이(재사용 %d초) 시전 속도 +%d%% · 재사용 감소 %d%% → 간격", ns.SkillCooldown("whirlwind", 1), cast, cdr),
		f(mean(g), 2) .. "초 / 기대 " .. f(want, 2) .. "초")
	L.endLab()
end
do -- count skills: every n-th basic attack
	local u, log = lab({ heroes = { { spec = "WARRIOR_ARMS", skills = { "mortal_strike" }, stats = { atk = 100, aspd = 2 } } }, hp = 1e12, seconds = 60 })
	local n = #castTimes(log, "mortal_strike")
	local b = #L.basics(log, u[1])
	check(abs(n - floor(b / 3)) <= 1, "죽음의 일격: 기본 공격 3회마다 발동", n .. "회 / 기본 공격 " .. b .. "회")
	L.endLab()
end
do -- skill levels: from points, plus 모든 기술 레벨
	local u, log = lab({ heroes = { { spec = "WARRIOR_ARMS", skills = { "mortal_strike" }, slv = 3, stats = { atk = 1000, aspd = 2, skills = 2 } } }, hp = 1e12, seconds = 30 })
	local lvl = u[1].slv.mortal_strike
	check(lvl == 5, "기술 점수 3 + 모든 기술 레벨 +2 → 기술 레벨 5", "Lv " .. tostring(lvl))
	local r = {}
	for _, e in ipairs(log.mob) do if e.cast == "mortal_strike" then r[#r + 1] = e.a / 1000 end end
	check(near(mean(r), ns.SkillValue("mortal_strike", 5) / 100, 0.02), "기술 피해가 레벨 5의 수치로", f(mean(r) * 100, 1) .. "% / " .. f(ns.SkillValue("mortal_strike", 5), 1) .. "%")
	L.endLab()
end

------------------------------------------------------------------------
section("모든 기술: 설명문의 수치 = 실제 전투")
------------------------------------------------------------------------
local function specOf(sid)
	for _, spid in ipairs(ns.SPEC_ORDER) do
		for _, x in ipairs(ns.SPECS[spid].skills) do if x == sid then return spid end end
	end
end
local function numText(v) return ns.U.num(v, 1) end
local function medianGap(list)
	local g = {}
	for i = 2, #list do g[#g + 1] = list[i].t - list[i - 1].t end
	table.sort(g)
	return g[floor((#g + 1) / 2)] or 0
end
local skillIds = {}
for id in pairs(ns.SKILLS) do skillIds[#skillIds + 1] = id end
table.sort(skillIds)
local skillFails = {}
local function sfail(sid, msg) skillFails[#skillFails + 1] = sid .. " (" .. ns.N(ns.SKILLS[sid].name) .. "): " .. msg end
local tested = 0
for _, sid in ipairs(skillIds) do
	local sk = ns.SKILLS[sid]
	local spec = specOf(sid)
	if spec then
		tested = tested + 1
		local role = ns.SPECS[spec].role
		local partner = role == "TANK" and "MAGE_FIRE" or "WARRIOR_PROT"
		local free = {}
		if sk.kind == "aura" or sk.kind == "buff" then
			for _, m in ipairs(sk.mods or {}) do
				local a = ns.AFFIX[m[1]]
				if a then free[a.t] = true end
			end
		end
		local shields, buffsSeen, revived = {}, {}, {}
		local lastCasts = 0
		local u, log = lab({
			heroes = {
				{ spec = spec, skills = { sid }, slv = 3, stats = { atk = 1000, hp = 1e6, aspd = sk.kind == "pet" and 0.01 or 1 }, free = free },
				{ spec = partner, stats = { atk = 1, hp = 1e6 }, free = free },
			},
			hp = 1e12, n = 6, atk = 0, mob = { aspd = 1 }, seconds = 60, -- monsters scratch (1 a hit): nobody dies by accident
			each = function(step, us)
				local me, other = us[1], us[2]
				if not me then return end
				if sk.when and sk.when.self and not me.dead then me.hp = min(me.hp, me.maxhp * (sk.when.self - 0.05)) end
				if sk.when and sk.when.ally and other and not other.dead then other.hp = min(other.hp, other.maxhp * (sk.when.ally - 0.05)) end
				-- healing with no condition still needs someone hurt
				if sk.heal and not sk.when and other and not other.dead then other.hp = min(other.hp, other.maxhp * 0.5) end
				if sk.kind == "revive" and step % 150 == 0 and other and not other.dead then L.kill(other) end
				-- what a cast in the previous step left behind
				local L2 = L.LOGF()
				if #L2.cast > lastCasts then
					lastCasts = #L2.cast
					for _, h in ipairs(us) do
						if h.shield and h.shield > 0 then shields[#shields + 1] = h.shield / h.maxhp end
						for _, b in ipairs(h.buffs) do buffsSeen[#buffsSeen + 1] = { mods = b.mods, t = b.t } end
						if sk.kind == "revive" and not h.dead and h.reviveT == 0 and h ~= me then revived[#revived + 1] = h.hp / h.maxhp end
					end
				end
			end,
		})
		local me = u[1]
		local lvl = me.slv[sid] or 1
		local v = ns.SkillValue(sid, lvl)
		local casts = {}
		for _, e in ipairs(log.cast) do if e.sid == sid and e.u == me then casts[#casts + 1] = e end end
		local desc = ns.SkillDesc(sid, lvl)
		local kind = sk.kind
		if kind ~= "aura" and kind ~= "pet" and #casts == 0 then
			sfail(sid, "60초 동안 한 번도 쓰이지 않음")
		end
		-- the text shows the number the fight uses
		if (sk.v and kind ~= "aura" and kind ~= "buff") and not desc:find(numText(v), 1, true) then
			sfail(sid, "설명문에 수치 " .. numText(v) .. "% 가 없음: " .. desc)
		end
		if kind == "dmg" and #casts > 0 then
			local byT = {}
			for _, e in ipairs(log.mob) do
				if e.cast == sid and e.src == me then
					byT[e.t] = byT[e.t] or { n = 0, mobs = {}, r = {} }
					local g = byT[e.t]
					g.n = g.n + 1
					g.mobs[e.m] = (g.mobs[e.m] or 0) + 1
					g.r[#g.r + 1] = e.a / (1000 * v / 100) / (e.crit and 1.5 or 1)
				end
			end
			local want = min(sk.targets or 1, 6)
			for _, g in pairs(byT) do
				local nm = 0
				for _, k in pairs(g.mobs) do nm = nm + 1 if k ~= (sk.hits or 1) then sfail(sid, "대상마다 " .. k .. "번 (설명 " .. (sk.hits or 1) .. "번)") break end end
				if nm ~= want then sfail(sid, "대상 " .. nm .. "명 (설명 " .. want .. "명)") end
				for _, r in ipairs(g.r) do if r < 0.95 - 1e-6 or r > 1.05 + 1e-6 then sfail(sid, "피해 배율 " .. f(r, 3) .. " (설명 " .. numText(v) .. "%)") break end end
				break -- one cast is enough for the shape; the loop below checks all amounts
			end
			local all = {}
			for _, g in pairs(byT) do for _, r in ipairs(g.r) do all[#all + 1] = r end end
			-- each hit rolls ±5%: the average of a few hits may drift more
			-- than of many (three standard deviations of the mean, at least 3%)
			local tol = #all > 0 and math.max(0.03, 3 * 0.05 / math.sqrt(3 * #all)) or 0.03
			if #all > 0 and not near(mean(all), 1, tol) then sfail(sid, "평균 피해 " .. f(mean(all) * v, 1) .. "% (설명 " .. numText(v) .. "%)") end
			if sk.status then
				local n = 0
				for _, e in ipairs(log.status) do if e.cast == sid and e.kind == sk.status[1] then n = n + 1 end end
				if sk.status[2] >= 1 and n == 0 then sfail(sid, "상태 이상 " .. sk.status[1] .. " 이 걸리지 않음") end
			end
			local function healsOf(pred)
				local t = {}
				for _, e in ipairs(log.heal) do if e.cast == sid and pred(e) then t[#t + 1] = e end end
				return t
			end
			if sk.selfHeal then
				local hs = healsOf(function(e) return e.tgt == me and e.src == me end)
				local want2 = me.maxhp * (sk.selfHeal[1] + sk.selfHeal[2] * (lvl - 1)) / 100
				if #hs == 0 or not near(hs[1].a, want2, 1e-6) then sfail(sid, "자신 회복이 설명과 다름") end
			end
			if sk.healAll then
				local hs = healsOf(function(e) return e.src == me end)
				local pct = sk.healAll[1] + sk.healAll[2] * (lvl - 1)
				if #hs == 0 or not near(hs[1].a / hs[1].tgt.maxhp * 100, pct, 1e-6) then sfail(sid, "파티 회복이 설명과 다름") end
			end
			if sk.drain then
				local hs = healsOf(function(e) return e.tgt == me end)
				if #hs == 0 then sfail(sid, "흡수 회복이 없음") end
			end
		elseif kind == "dot" and #casts > 0 then
			local applied = {}
			for _, e in ipairs(log.status) do if e.cast == sid then applied[#applied + 1] = e end end
			local want = 1000 * v / 100
			if #applied == 0 then sfail(sid, "지속 피해가 걸리지 않음")
			else
				if not near(applied[1].power, want, 1e-6) then sfail(sid, "초당 피해 " .. f(applied[1].power, 1) .. " (설명 " .. f(want, 1) .. ")") end
				if applied[1].dur ~= sk.dur then sfail(sid, "지속 " .. tostring(applied[1].dur) .. "초 (설명 " .. sk.dur .. "초)") end
				local perCast = 0
				for _, e in ipairs(applied) do if e.t == applied[1].t then perCast = perCast + 1 end end
				if perCast ~= min(sk.targets or 1, 6) then sfail(sid, "대상 " .. perCast .. "명 (설명 " .. min(sk.targets or 1, 6) .. "명)") end
				local ticks = {}
				for _, e in ipairs(log.mob) do if e.dot and e.src == me and e.school == sk.school then ticks[#ticks + 1] = e.a end end
				if #ticks == 0 or not near(mean(ticks), want * 0.1, 0.01) then sfail(sid, "틱 피해 " .. f(mean(ticks) * 10, 1) .. "/초 (설명 " .. f(want, 1) .. "/초)") end
			end
		elseif kind == "field" and #casts > 0 then
			if sk.heal then
				local hs = {}
				for _, e in ipairs(log.heal) do if e.src == me and e.cast == nil then hs[#hs + 1] = e.a / e.tgt.maxhp * 100 end end
				if #hs == 0 or not near(mean(hs), v, 1e-6) then sfail(sid, "장판 회복 " .. f(mean(hs), 2) .. "% (설명 " .. numText(v) .. "%)") end
			else
				local r = {}
				for _, e in ipairs(log.mob) do if e.src == me and e.cast == nil and e.mult and near(e.mult, v / 100, 1e-9) then r[#r + 1] = e.a / (1000 * v / 100) / (e.crit and 1.5 or 1) end end
				local ticks = floor(sk.dur / sk.tick + 0.5)
				local per = #r / #casts / min(sk.targets or 1, 6)
				if #r == 0 or not near(mean(r), 1, 0.03) then sfail(sid, "장판 피해 배율 " .. f(mean(r), 3)) end
				if #r > 0 and abs(per - ticks) > 1.01 then sfail(sid, "장판이 대상마다 " .. f(per, 1) .. "번 (설명 " .. ticks .. "번 = " .. sk.dur .. "초/" .. sk.tick .. "초)") end
			end
		elseif kind == "heal" and #casts > 0 then
			local hs = {}
			for _, e in ipairs(log.heal) do if e.cast == sid and e.src == me then hs[#hs + 1] = e end end
			if sk.hot then
				local ticks = {}
				for _, e in ipairs(log.heal) do if e.src == me and e.cast == nil then ticks[#ticks + 1] = e.a / e.tgt.maxhp * 1000 end end
				if #ticks == 0 or not near(mean(ticks), v, 1e-6) then sfail(sid, "지속 회복 " .. f(mean(ticks), 2) .. "%/초 (설명 " .. numText(v) .. "%)") end
			elseif #hs == 0 or not near(hs[1].a / hs[1].tgt.maxhp * 100, v, 1e-6) then
				sfail(sid, "회복량이 설명과 다름")
			end
		elseif kind == "shield" and #casts > 0 then
			local best = 0
			for _, x in ipairs(shields) do best = max(best, x) end
			if not near(best, v / 100, 1e-3) then sfail(sid, "보호막 " .. f(best * 100, 2) .. "% (설명 " .. numText(v) .. "%)") end
		elseif kind == "buff" and #casts > 0 then
			local b = buffsSeen[1]
			if not b then sfail(sid, "강화 효과가 걸리지 않음")
			else
				for i, m in ipairs(sk.mods) do
					local want = m[2] + m[3] * (lvl - 1)
					if not (b.mods[i] and b.mods[i][1] == m[1] and near(b.mods[i][2], want, 1e-9)) then sfail(sid, "강화 수치가 설명과 다름") end
				end
				if abs(b.t - sk.dur) > 0.21 then sfail(sid, "강화 지속 " .. f(b.t, 1) .. "초 (설명 " .. sk.dur .. "초)") end
			end
		elseif kind == "aura" then
			-- in combat the stat equals the stat sheet's numbers plus the aura
			local who = sk.self and me or u[2]
			local mods = {}
			for _, m in ipairs(sk.mods) do mods[#mods + 1] = { m[1], m[2] + m[3] * (lvl - 1) } end
			local want = L.real.Compute(who.id, mods)
			for _, m in ipairs(sk.mods) do
				local key = ns.AFFIX[m[1]].t
				if not near(who.s[key], want[key], 1e-6) then sfail(sid, "오라가 " .. key .. " 에 적용되지 않음 (" .. f(who.s[key], 2) .. " / " .. f(want[key], 2) .. ")") end
			end
		elseif kind == "pet" then
			local mult = ns.SkillValue(sid, lvl) / 100
			if sk.heal then
				local hs = {}
				for _, e in ipairs(log.heal) do if e.src == me and e.cast == nil then hs[#hs + 1] = e end end
				if #hs == 0 then sfail(sid, "치유 소환수가 치유하지 않음")
				else
					local gap = medianGap(hs)
					if not near(gap, sk.tick, 0.05) then sfail(sid, "치유 간격 " .. f(gap, 2) .. "초 (설명 " .. sk.tick .. "초)") end
				end
			else
				local hits = {}
				for _, e in ipairs(log.mob) do if e.src == me and e.cast == nil and e.mult and near(e.mult, mult, 1e-9) then hits[#hits + 1] = e end end
				if #hits < 3 then sfail(sid, "소환수가 공격하지 않음")
				else
					local gap = medianGap(hits)
					if not near(gap, sk.tick, 0.05) then sfail(sid, "공격 간격 " .. f(gap, 2) .. "초 (설명 " .. sk.tick .. "초)") end
				end
			end
		elseif kind == "debuff" and #casts > 0 then
			local a
			for _, e in ipairs(log.status) do if e.cast == sid then a = e break end end
			if not a or not near(a.power, v, 1e-9) or a.dur ~= sk.dur then sfail(sid, "약화 수치/지속이 설명과 다름") end
		elseif kind == "revive" and #casts > 0 then
			local rv
			for _, e in ipairs(log.revive) do if e.cast == sid then rv = e break end end
			if not rv or not near(rv.ratio, v / 100, 1e-9) then sfail(sid, "되살린 생명력 " .. f((rv and rv.ratio or 0) * 100, 1) .. "% (설명 " .. numText(v) .. "%)") end
		end
		L.endLab()
	end
end
check(#skillFails == 0, "기술 " .. tested .. "개 전부 설명문대로 작동", #skillFails > 0 and (#skillFails .. "건") or nil)
for _, m in ipairs(skillFails) do print("        · " .. m) end

------------------------------------------------------------------------
section("몬스터 쪽")
------------------------------------------------------------------------
local C = ns.Combat
local function mobHits(log, u, from)
	local t = {}
	for _, e in ipairs(log.hero) do if e.h == u and not e.dot and (not from or e.src == from) then t[#t + 1] = e end end
	return t
end
do -- monsters ramp up after 75 s in one wave
	local u, log = lab({ heroes = { { spec = "WARRIOR_PROT", stats = { hp = 1e12, atk = 1 } } }, hp = 1e12, atk = 100, mob = { aspd = 2 }, seconds = 110 })
	local r, late = {}, 0
	for _, e in ipairs(mobHits(log, u[1])) do
		local rage = 1 + max(0, (e.wt - 75) / 5) * 0.1
		r[#r + 1] = e.a / (100 * rage)
		if e.wt > 76 then late = late + 1 end
	end
	check(late > 20 and near(mean(r), 1, 0.02), "한 웨이브 75초 뒤부터 5초마다 몬스터 피해 +10%", f(mean(r), 3) .. "배 (75초 뒤 " .. late .. "회)")
	L.endLab()
end
do -- ailments on monsters: weakened, chilled, stunned, shocked
	local apply = L.ORIG.applyStatus
	local restun, again = {}, nil
	local u, log = lab({ heroes = { { spec = "WARRIOR_PROT", stats = { hp = 1e12, atk = 1 } } }, hp = 1e12, atk = 100, mob = { aspd = 2 }, seconds = 70,
		each = function(step)
			local m = C.mobs[1]
			if not m then return end
			if step == 100 then apply(m, "weaken", nil, 40, 8) end -- 10.0 .. 18.0 s
			if step == 300 then apply(m, "stun", nil, nil, nil) end -- 30.0 .. 32.0 s, immune until 36 s
			if step == 310 then -- ignored: just stunned (the stun keeps its time left)
				restun[1] = m.st.stun and m.st.stun.t
				apply(m, "stun", nil, nil, nil)
				restun[2] = m.st.stun and m.st.stun.t
			end
			if step == 345 then apply(m, "stun", nil, nil, nil) again = m.st.stun ~= nil end -- still immune
			if step == 370 then apply(m, "stun", nil, nil, nil) again = again == false and m.st.stun ~= nil end -- free again
			if step >= 400 and step < 600 and step % 30 == 0 then apply(m, "chill") end -- 40 .. 60 s
		end })
	local weak, normal, stunned, chilledT = {}, {}, 0, {}
	for _, e in ipairs(mobHits(log, u[1])) do
		if e.t > 10.15 and e.t < 17.9 then weak[#weak + 1] = e.a / 100
		elseif e.t > 2 and e.t < 9.9 then normal[#normal + 1] = e.a / 100 end
		if e.t > 30.05 and e.t < 31.95 then stunned = stunned + 1 end
		if e.t > 40.5 and e.t < 60 then chilledT[#chilledT + 1] = e.t end
	end
	check(near(mean(weak) / mean(normal), 0.6, 0.04), "약화 40% → 몬스터 피해 × 0.6", f(mean(weak) / mean(normal), 3))
	check(stunned == 0, "기절한 몬스터는 2초 동안 공격하지 않음", stunned .. "회")
	local gap = (chilledT[#chilledT] - chilledT[1]) / (#chilledT - 1)
	check(near(gap, 0.5 / 0.7, 0.05), "냉기 둔화 30% → 공격 간격 0.5초 → 0.71초", f(gap, 3) .. "초")
	check(restun[1] and restun[1] == restun[2] and near(restun[1], 1, 0.15) and again == true,
		"기절 뒤 4초 동안은 다시 기절하지 않음, 그 뒤엔 다시 걸림", "남은 기절 " .. f(restun[1] or 0, 1) .. "초 → " .. f(restun[2] or 0, 1) .. "초")
	L.endLab()
end
do -- shocked / cursed monsters and resistances
	local apply = L.ORIG.applyStatus
	local u, log = lab({ heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 2 } } }, hp = 1e12, n = 1, mob = { res = { fire = 50 } }, seconds = 40,
		each = function(step) local m = C.mobs[1] if m and step == 200 then apply(m, "shock") end end })
	local base, shocked = {}, {}
	for _, e in ipairs(L.basics(log, u[1])) do
		if e.t < 19.9 then base[#base + 1] = e.out / e.a elseif e.t > 20.05 and e.t < 25.9 then shocked[#shocked + 1] = e.out / e.a end
	end
	check(near(mean(base), 0.5, 1e-6), "몬스터 화염 저항 50% → 화염 피해 × 0.5", f(mean(base), 3))
	check(near(mean(shocked), 0.5 * 1.2, 1e-6), "감전(받는 피해 +20%) → × 1.2 (저항 뒤에)", f(mean(shocked), 3))
	L.endLab()
end
do -- boss abilities
	local function bossLab(skills, o)
		o = o or {}
		return lab({ heroes = o.heroes or { { spec = "WARRIOR_PROT", stats = { hp = 1e12, atk = o.heroAtk or 1, aspd = 2 } } },
			boss = { boss = true, aspd = o.aspd or 0.001, skills = skills }, hp = o.hp or 1e12, atk = 100, n = 0, seconds = o.seconds or 40, each = o.each })
	end
	-- (the boss's one basic attack as the fight opens is 100: only the skill's hits count)
	local u, log = bossLab({ { kind = "smash", cd = 4, mult = 3 } })
	local sm = {}
	for _, e in ipairs(mobHits(log, u[1])) do if near(e.a, 300, 1e-6) then sm[#sm + 1] = e end end
	local gap = #sm > 1 and (sm[#sm].t - sm[1].t) / (#sm - 1) or 0
	check(#sm > 5 and near(sm[2].a, 300, 1e-6) and near(gap, 4, 0.03), "우두머리 강타(4초마다 ×3) → 300 피해, 4초 간격", #sm .. "회, " .. f(sm[2] and sm[2].a or 0, 0) .. ", " .. f(gap, 2) .. "초")
	L.endLab()
	u, log = bossLab({ { kind = "aoe", cd = 5, mult = 2 } }, { heroes = {
		{ spec = "WARRIOR_PROT", stats = { hp = 1e12, atk = 1 } }, { spec = "MAGE_FIRE", stats = { hp = 1e12, atk = 1 } }, { spec = "PRIEST_HOLY", stats = { hp = 1e12, atk = 1 } } } })
	local per = {}
	for _, e in ipairs(log.hero) do if near(e.a, 200, 1e-6) then per[e.h] = (per[e.h] or 0) + 1 end end
	local n, same = 0, true
	local first
	for h, c in pairs(per) do n = n + 1 first = first or c if c ~= first then same = false end end
	check(n == 3 and same and first >= 7, "우두머리 광역 공격(5초마다 ×2) → 파티 전원이 똑같이 맞음", n .. "명 × " .. (first or 0) .. "회")
	L.endLab()
	u, log = bossLab({ { kind = "shield", cd = 10, dur = 5, dr = 50 } }, { heroes = { { spec = "MAGE_FIRE", stats = { atk = 1000, aspd = 2 } } } })
	local half, full = 0, 0
	for _, e in ipairs(L.basics(log, u[1])) do if near(e.out, e.a * 0.5, 1e-6) then half = half + 1 elseif near(e.out, e.a, 1e-6) then full = full + 1 end end
	check(half > 0 and abs(half / (half + full) - 0.5) < 0.12, "우두머리 보호막(10초마다 5초, 피해 50% 감소)", f(half / (half + full) * 100, 0) .. "%의 공격이 절반")
	L.endLab()
	u, log = bossLab({ { kind = "enrage", hp = 0.5, mult = 2 } }, { heroes = {
		{ spec = "WARRIOR_PROT", stats = { hp = 1e12, atk = 1 } }, { spec = "MAGE_FIRE", stats = { hp = 1e12, atk = 3000, aspd = 3 } } },
		hp = 300000, aspd = 1, seconds = 45 })
	-- the first boss (it dies at about 33 s and the stage starts over with a new one)
	local boss
	for _, e in ipairs(log.mob) do if e.m.boss then boss = e.m break end end
	local below
	local hp = boss and boss.maxhp or 0
	for _, e in ipairs(log.mob) do
		if e.m == boss then hp = hp - e.out if not below and hp <= boss.maxhp * 0.5 then below = e.t end end
	end
	local before, after = {}, {}
	for _, e in ipairs(log.hero) do
		if e.src == boss and not e.dot and below then
			if e.t > below + 0.15 then after[#after + 1] = e.a elseif e.t < below then before[#before + 1] = e.a end
		end
	end
	check(below and #after > 5 and #before > 5 and near(mean(after) / mean(before), 2, 0.06), "우두머리 격노(생명력 50% 이하에서 ×2)",
		below and (f(mean(after) / mean(before), 2) .. "배 (" .. #before .. "회 → " .. #after .. "회)") or "격노까지 못 감")
	L.endLab()
	local maxAdds = 0
	u, log = bossLab({ { kind = "summon", cd = 3, mob = "__dummy", n = 3 } }, { seconds = 40, each = function()
		local n = 0
		for _, m in ipairs(C.mobs) do if m.summoned and not m.dead then n = n + 1 end end
		maxAdds = max(maxAdds, n)
	end })
	check(maxAdds > 0 and maxAdds <= 4, "우두머리 소환: 쫄은 한 번에 최대 4마리", maxAdds .. "마리")
	L.endLab()
end

------------------------------------------------------------------------
section("처치 보상")
------------------------------------------------------------------------
do
	local u, log = lab({ heroes = {
		{ spec = "MAGE_FIRE", stats = { atk = 1e6, aspd = 2, gold = 20, exp = 30 } },
		{ spec = "WARRIOR_PROT", stats = { atk = 1, gold = 10, exp = 0 } } }, hp = 50, n = 4, seconds = 40 })
	local goldPct = ns.Bonus("gold") + 20 + 10
	local okGold, okXP, nk = true, true, 0
	for _, k in ipairs(log.kill) do
		nk = nk + 1
		local want = max(1, floor(k.m.gold * (1 + goldPct / 100) + 0.5))
		if k.gold ~= want then okGold = false end
	end
	check(nk > 10 and okGold, "처치 골드 = 몬스터 골드 × (1 + 룬 + 파티 전원의 골드 획득%)", nk .. "마리, 골드 획득 +" .. goldPct .. "%")
	local mage = u[1]
	local per = {}
	for _, x in ipairs(log.xp) do if x.id == mage.id then per[#per + 1] = x.a end end
	local m = log.kill[1].m
	local want = m.exp * (1 + (ns.Bonus("exp") + 30) / 100) * ns.Heroes.XPFactor(ns.db.heroes[mage.id].level, L.st.level)
	check(#per == nk and near(per[1], want, 1e-9), "처치 경험치 = 몬스터 경험치 × (1 + 룬 + 자신의 경험치 획득%) × 레벨 차 보정", f(per[1] or 0, 2) .. " / " .. f(want, 2))
	L.endLab()
end

------------------------------------------------------------------------
section("실전: 모든 전문화, 실제 지역, 실제 장비 (불변식)")
------------------------------------------------------------------------
do
	local tanks, heals, dps = {}, {}, {}
	for _, sid in ipairs(ns.SPEC_ORDER) do
		local r = ns.SPECS[sid].role
		local t = r == "TANK" and tanks or (r == "HEALER" and heals or dps)
		t[#t + 1] = sid
	end
	local problems, kills, clears, wipes, runs, steps = {}, 0, 0, 0, 0, 0
	local function note(msg) if #problems < 30 then problems[#problems + 1] = msg end end
	for i = 1, #dps, 3 do
		for loadout = 0, 1 do
			local party = { tanks[(runs % #tanks) + 1], dps[i], dps[(i % #dps) + 1], dps[((i + 1) % #dps) + 1], heals[(runs % #heals) + 1] }
			local heroes = {}
			for k, sid in ipairs(party) do
				local sk = ns.SPECS[sid].skills
				local a = loadout * 3
				heroes[k] = { spec = sid, level = 35, gear = 4, slv = 3, skills = { sk[a + 1], sk[a + 2], sk[a + 3] } }
			end
			runs = runs + 1
			local u, log = lab({ heroes = heroes, realStage = true, diff = 1 + runs % 3, idx = 8 + (runs * 7) % 20, seconds = 240,
				each = function()
					steps = steps + 1
					for _, h in ipairs(C.heroes) do
						if not (h.hp == h.hp and h.hp >= 0 and h.hp <= h.maxhp + 1e-6) then note("영웅 생명력 범위 밖: " .. tostring(h.hp) .. "/" .. tostring(h.maxhp)) end
						if h.dead and h.hp ~= 0 then note("쓰러진 영웅의 생명력이 0이 아님") end
						if not (h.shield >= 0 and h.shield == h.shield) then note("보호막 음수/NaN") end
						for sid, cd in pairs(h.cd or {}) do if cd ~= cd or cd > 1e6 then note("재사용 대기시간 이상: " .. sid) end end
					end
					for _, m in ipairs(C.mobs) do
						if not (m.hp == m.hp and m.hp >= 0 and m.hp <= m.maxhp + 1e-6) then note("몬스터 생명력 범위 밖") end
						if m.dead and m.hp ~= 0 then note("죽은 몬스터의 생명력이 0이 아님") end
					end
				end })
			for _, b in ipairs(log.bad) do note(b) end
			for _, e in ipairs(log.mob) do if e.srcDead and not e.dot then note("쓰러진 영웅이 공격함") break end end
			for _, e in ipairs(log.heal) do if e.dead0 and e.out > 0 then note("쓰러진 영웅이 치유됨") break end end
			kills = kills + #log.kill
			clears = ns.db.stat.clears + clears
			wipes = ns.db.stat.wipes + wipes
			L.endLab()
		end
	end
	check(#problems == 0, string.format("파티 %d번 × 240초 (%d스텝): 생명력·보호막·재사용 대기시간 범위, 죽은 유닛 행동, 기절 중 공격, NaN", runs, steps),
		#problems > 0 and (#problems .. "건") or nil)
	for _, p in ipairs(problems) do print("        · " .. p) end
	check(kills > 500 and clears > 0, "실전이 진행됨", string.format("처치 %d · 공략 %d · 전멸 %d", kills, clears, wipes))
end

print(string.format("\n  결과: %d개 통과, %d개 실패", L.R.pass, L.R.fail))
return L.R.fail == 0
