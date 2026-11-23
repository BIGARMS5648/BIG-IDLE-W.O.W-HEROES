-- Stat audit: every source of a hero's stats followed into the stat sheet
-- and into the hero fighting in combat.
--
--   python3 tests/run.py stats
--
-- Each source is put on a clean hero (no gear, talents, runes or companions)
-- and the hero's stats are compared with what the source says it gives:
-- the numbers in an item's tooltip (base stats with their enhancement,
-- random stats, gems, enchants, rune inscriptions), a talent's value, a
-- rune's and a companion's bonus. Each stat's own math (flat, % added, %
-- multiplied, the limits) is worked out by hand once. Then the same in a
-- running fight: whatever is done to a hero (gear, sockets, enhancement,
-- talents, runes, a level) shows in its combat stats on the next step.
-- (How combat uses the stats - damage, crits, armor, skills, auras, buffs -
-- is tests/combat_audit.lua.)
local ns = NS
local abs, max, min, floor = math.abs, math.max, math.min, math.floor
math.randomseed(20261123)
BigWowIdleDB = nil
ns.InitDB()
local db = ns.db
db.faction = db.faction or "HORDE"
db.gold = 1e15

local R = { pass = 0, fail = 0, fails = {} }
local function check(ok, name, detail)
	if ok then R.pass = R.pass + 1 else
		R.fail = R.fail + 1
		R.fails[#R.fails + 1] = name .. (detail and ("  — " .. detail) or "")
	end
	print(string.format("  %s %s%s", ok and "ok  " or "FAIL", name, detail and ("  — " .. detail) or ""))
end
local function section(name) print("\n== " .. name) end
local function f(x, d) return string.format("%." .. (d or 2) .. "f", x) end
local function list(t, n)
	local out = {}
	for i = 1, min(#t, n or 6) do out[i] = t[i] end
	return table.concat(out, "; ") .. (#t > (n or 6) and (" … 외 " .. (#t - (n or 6)) .. "건") or "")
end

-- the add-on's source files (for what the code reads)
local here = debug.getinfo(1, "S").source:sub(2):gsub("stat_audit%.lua$", "")
local root = here .. "../BigIdleHeroes/"
local SRC = {}
do
	local toc = io.open(root .. "BigIdleHeroes.toc"):read("*a")
	for line in toc:gmatch("[^\r\n]+") do
		if line:match("%.lua%s*$") then
			local p = line:gsub("\\", "/"):gsub("%s+$", "")
			local fh = io.open(root .. p)
			if fh then SRC[p] = fh:read("*a") fh:close() end
		end
	end
end
local function src(pattern)
	for _, text in pairs(SRC) do if text:find(pattern) then return true end end
	return false
end

------------------------------------------------------------------------
-- A clean hero
------------------------------------------------------------------------
local function newHero(spec)
	local ok, id = ns.Heroes.Create(spec)
	assert(ok, "could not make a " .. spec)
	return id
end
local function clean(id)
	local h = db.heroes[id]
	h.gear, h.tree = {}, {}
	db.runes, db.pets = {}, {}
	ns.Runes.Invalidate()
	ns.Stats.Invalidate()
end
-- every number of two stat tables that differs ("key a/b")
local function diff(a, b, tol)
	local bad = {}
	for k, v in pairs(b) do
		if type(v) == "number" then
			local w = a[k]
			if type(w) ~= "number" or abs(w - v) > (tol or 1e-9) * max(1, abs(v)) then
				bad[#bad + 1] = k .. " " .. tostring(w) .. "/" .. f(v, 3)
			end
		end
	end
	table.sort(bad)
	return bad
end
-- the stats an item says it gives (its tooltip): base stats (with the
-- enhancement), random stats, then each socket
local function claimed(it)
	local mods = {}
	for _, b in ipairs(ns.Items.BaseStats(it)) do mods[#mods + 1] = { b[1], b[2] } end
	for _, l in ipairs({ it.a or {}, it.g or {}, it.e or {}, it.i or {} }) do
		for _, e in ipairs(l) do mods[#mods + 1] = { e[1], e[2] } end
	end
	return mods
end
-- worn by the hero: its stats equal a bare hero's plus exactly what the item claims
local function wearCheck(id, it)
	local h = db.heroes[id]
	h.gear = { [it.s] = it }
	ns.Stats.Invalidate(id)
	local got = ns.Stats.Get(id)
	h.gear = {}
	local want = ns.Stats.Compute(id, claimed(it))
	h.gear = { [it.s] = it }
	return diff(got, want)
end
-- every claimed stat shows in the tooltip with its number
local function tipCheck(it)
	local lines = {}
	for _, l in ipairs(ns.Items.Tooltip(it)) do lines[#lines + 1] = l[1] or "" end
	local text = table.concat(lines, "\n")
	local missing = {}
	for _, m in ipairs(claimed(it)) do
		if not text:find(ns.Stats.ModText(m[1], m[2]), 1, true) then missing[#missing + 1] = ns.Stats.ModText(m[1], m[2]) end
	end
	return missing
end

local H = newHero("WARRIOR_ARMS")
local SPEC = db.heroes[H].spec
clean(H)

------------------------------------------------------------------------
section("1. 능력치 이름: 무엇이 주든 계산과 전투에 들어가는 이름")
------------------------------------------------------------------------
local READ = {}
for k, v in pairs(ns.Stats.Compute(H)) do if type(v) == "number" then READ[k] = true end end
do
	local bad = {}
	for key, a in pairs(ns.AFFIX) do if not READ[a.t] then bad[#bad + 1] = key .. "→" .. a.t end end
	check(#bad == 0, "능력치 종류마다 능력치 표에 계산되는 칸이 있음", #bad > 0 and list(bad) or nil)
end
-- what the code asks the account for (ns.Bonus("..."))
local ACCOUNT = {}
for _, text in pairs(SRC) do for k in text:gmatch('ns%.Bonus%("([%w_]+)"%)') do ACCOUNT[k] = true end end
local function known(key, account)
	return ns.AFFIX[key] ~= nil or (account and ACCOUNT[key])
end
do
	local bad = {}
	local function need(where, key, account)
		if not known(key, account) then bad[#bad + 1] = where .. ": " .. tostring(key) end
	end
	for cat, pool in pairs(ns.AFFIX_POOL) do for _, e in ipairs(pool) do need("옵션 " .. cat, e[1]) end end
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		for _, cat in ipairs({ "weapon", "armor", "accessory" }) do
			for _, e in ipairs(ns.SOCKET[kind][cat]) do need(kind .. " " .. cat, e[1]) end
		end
	end
	for s, def in pairs(ns.SLOT) do for k in pairs(def.base or {}) do need("부위 " .. s, k) end end
	for t, def in pairs(ns.WTYPE) do for k in pairs(def.base or {}) do need("무기 " .. t, k) end end
	for sid, sp in pairs(ns.SPECS) do
		for _, tier in ipairs(sp.tree) do for _, node in ipairs(tier) do if node.p then need("특성 " .. sid, node.p) end end end
	end
	for id, node in pairs(ns.Runes.byId) do if node.stat then need("룬 " .. id, node.stat, true) end end
	for _, pet in ipairs(ns.PETS) do for k in pairs(pet.bonus) do need("동료 " .. pet.id, k, true) end end
	for sid, sk in pairs(ns.SKILLS) do for _, m in ipairs(sk.mods or {}) do need("기술 " .. sid, m[1]) end end
	check(#bad == 0, "장비·옵션·보석·마법부여·룬 각인·특성·룬·동료·기술이 주는 능력치 이름이 모두 있는 이름", #bad > 0 and list(bad, 10) or nil)
	-- an account bonus nobody gives is a typo somewhere
	local given = {}
	for _, node in pairs(ns.Runes.byId) do if node.stat then given[node.stat] = true end end
	for _, pet in ipairs(ns.PETS) do for k in pairs(pet.bonus) do given[k] = true end end
	local unused = {}
	for k in pairs(given) do if not ns.AFFIX[k] and not ACCOUNT[k] then unused[#unused + 1] = k end end
	check(#unused == 0, "룬·동료 보너스는 모두 코드가 읽음", #unused > 0 and list(unused) or nil)
end
do
	-- every stat of the sheet is used by combat (or by skills: 모든 기술 레벨)
	local skip = { level = true }
	local unused = {}
	for k in pairs(READ) do
		local used = skip[k] or src("s%." .. k .. "%f[^%w_]") or src("stats%." .. k .. "%f[^%w_]")
			or (k:match("^dmg_") and src('s%["dmg_"')) or (k:match("^res_") and src('s%["res_"'))
		if not used then unused[#unused + 1] = k end
	end
	table.sort(unused)
	check(#unused == 0, "능력치 표의 모든 칸이 전투(또는 기술 레벨)에 쓰임", #unused > 0 and list(unused) or nil)
end

------------------------------------------------------------------------
section("2. 능력치 계산: 고정값 · % 합산 · % 곱셈 · 한도")
------------------------------------------------------------------------
do
	local tA, tH = ns.SpecTune(SPEC, "atk"), ns.SpecTune(SPEC, "hp")
	local s0 = ns.Stats.Compute(H)
	local bad, others = {}, {}
	local keys = {}
	for key in pairs(ns.AFFIX) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local a = ns.AFFIX[key]
		local v = key == "skills" and 1 or 7
		local s1 = ns.Stats.Compute(H, { { key, v } })
		local t = a.t
		local want
		if a.l == "flat" then
			want = s0[t] + v * ((t == "atk" and tA) or (t == "hp" and tH) or 1)
		else
			want = s0[t] * (1 + v / 100)
		end
		local tol = (t == "hp") and 1 or 1e-9 * max(1, abs(want))
		if abs(s1[t] - want) > tol then bad[#bad + 1] = key .. " " .. f(s1[t], 3) .. "/" .. f(want, 3) end
		for k, x in pairs(s0) do
			if type(x) == "number" and k ~= t and x ~= s1[k] then others[#others + 1] = key .. "→" .. k end
		end
	end
	check(#bad == 0, "모든 능력치 종류: 고정값은 더하고, %는 합산·곱셈 단계대로 (" .. #keys .. "종)", #bad > 0 and list(bad) or nil)
	check(#others == 0, "능력치 하나가 다른 능력치를 건드리지 않음", #others > 0 and list(others) or nil)
	-- the limits
	local CAP = { dodge = 60, block = 75, dr = 75, cdr = 60, res_fire = 75, res_frost = 75, res_nature = 75, res_shadow = 75, allres = 75, skills = 5 }
	local over = {}
	for k, cap in pairs(CAP) do
		local s = ns.Stats.Compute(H, { { k, 1000 } })
		if s[k] ~= cap then over[#over + 1] = k .. " " .. tostring(s[k]) .. "/" .. cap end
	end
	check(#over == 0, "한도: 회피 60 · 막기 75 · 받는 피해 감소 75 · 재사용 대기 60 · 저항 75 · 기술 레벨 +5", #over > 0 and list(over) or nil)
	-- several sources of one stat add up within a layer and multiply across
	local s = ns.Stats.Compute(H, { { "atk", 100 }, { "atk", 50 }, { "atkPct", 10 }, { "atkPct", 20 }, { "atkMult", 10 }, { "atkMult", 10 } })
	local want = (s0.atk / tA + 150) * 1.3 * 1.1 * 1.1 * tA
	check(abs(s.atk - want) < 1e-6 * want, "공격력: (기본 + 고정 합) × (1 + % 합) × 곱셈마다", f(s.atk) .. " / " .. f(want))
end

------------------------------------------------------------------------
section("3. 장비: 기본 능력치 · 강화 · 옵션")
------------------------------------------------------------------------
do
	local tested, bad, tips = 0, {}, {}
	for _, slot in ipairs(ns.SLOTS) do
		for _, q in ipairs({ 1, 3, ns.MAX_QUALITY }) do
			for _, lvl in ipairs({ 1, 35, 60, 100 }) do
				local it = ns.Items.New(slot, lvl, q)
				for _, up in ipairs({ 0, 7, 10, 14, 20 }) do
					it.up = up > 0 and up or nil
					tested = tested + 1
					local d = wearCheck(H, it)
					if #d > 0 then bad[#bad + 1] = slot .. " q" .. q .. " L" .. lvl .. " +" .. up .. ": " .. list(d, 3) end
					local m = tipCheck(it)
					if #m > 0 then tips[#tips + 1] = slot .. " +" .. up .. ": " .. list(m, 3) end
				end
			end
		end
	end
	db.heroes[H].gear = {}
	check(#bad == 0, "장비를 끼면 툴팁의 기본 능력치·옵션만큼 정확히 오름 (" .. tested .. "개)", #bad > 0 and list(bad, 4) or nil)
	check(#tips == 0, "툴팁에 그 능력치가 그 숫자로 적혀 있음", #tips > 0 and list(tips, 4) or nil)
	-- enhancement: the base stats (and only they) grow by the bonus
	local wrong = {}
	for _, slot in ipairs(ns.SLOTS) do
		local it = ns.Items.New(slot, 60, ns.MAX_QUALITY)
		it.up = nil
		local b0 = ns.Items.BaseStats(it)
		local a0 = {}
		for i, a in ipairs(it.a or {}) do a0[i] = a[2] end
		for up = 1, ns.Upgrade.MAX do
			it.up = up
			local k = ns.Upgrade.Bonus(up)
			for i, b in ipairs(ns.Items.BaseStats(it)) do
				-- rounded to 0.1 below 20, to 1 above
				local tol = (b0[i][2] * k >= 20) and 0.5 or 0.05
				if abs(b[2] - b0[i][2] * k) > tol + 0.5 * (b0[i][2] >= 20 and 1 or 0.1) * k then
					wrong[#wrong + 1] = slot .. " +" .. up .. " " .. b[1] .. " " .. b[2] .. "/" .. f(b0[i][2] * k)
				end
			end
			for i, a in ipairs(it.a or {}) do if a[2] ~= a0[i] then wrong[#wrong + 1] = slot .. " +" .. up .. ": 옵션이 바뀜" end end
			local line
			for _, l in ipairs(ns.Items.Tooltip(it)) do if (l[1] or ""):find("^강화 %+") then line = l[1] end end
			local pct = floor((k - 1) * 100 + 0.5)
			if not (line and line:find("+" .. pct .. "%", 1, true)) then wrong[#wrong + 1] = slot .. " +" .. up .. " 툴팁: " .. tostring(line) end
		end
	end
	check(#wrong == 0, "강화 +1~+20: 기본 능력치만 강화 보너스만큼 (+10까지 단계당 4%, 그 뒤 6%), 툴팁과 같게", #wrong > 0 and list(wrong, 4) or nil)
	check(abs(ns.Upgrade.Bonus(10) - 1.4) < 1e-9 and abs(ns.Upgrade.Bonus(20) - 2.0) < 1e-9, "강화 보너스: +10 = 1.4배, +20 = 2.0배",
		f(ns.Upgrade.Bonus(10)) .. " · " .. f(ns.Upgrade.Bonus(20)))
end

------------------------------------------------------------------------
section("4. 보석 · 마법부여 · 룬 각인")
------------------------------------------------------------------------
local CAT_SLOT = {}
for _, slot in ipairs(ns.SLOTS) do
	local cat = ns.SLOT[slot].cat
	if not CAT_SLOT[cat] then CAT_SLOT[cat] = slot end
end
do
	local tested, bad, range, tips, unseen = 0, {}, {}, {}, {}
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		for _, cat in ipairs({ "weapon", "armor", "accessory" }) do
			local slot = CAT_SLOT[cat]
			for tier = 1, #ns.SOCKET_TIER_MULT do
				local seen = {}
				for _ = 1, 120 do
					local it = ns.Items.New(slot, 60, ns.MAX_QUALITY)
					it.a = nil
					local e = ns.Items.AddSocket(it, kind, tier)
					seen[e[1]] = true
					tested = tested + 1
					local lo, hi = ns.Items.SocketRange(it, kind, e)
					if lo and (e[2] < lo - 1e-9 or e[2] > hi + 1e-9) then range[#range + 1] = kind .. " " .. e[1] .. " " .. e[2] .. " (" .. lo .. "~" .. hi .. ")" end
					local d = wearCheck(H, it)
					if #d > 0 then bad[#bad + 1] = kind .. " " .. cat .. " t" .. tier .. " " .. e[1] .. ": " .. list(d, 3) end
					local text = table.concat((function() local t = {} for _, l in ipairs(ns.Items.Tooltip(it)) do t[#t + 1] = l[1] or "" end return t end)(), "\n")
					if not text:find(ns.Items.SocketText(it, kind, e), 1, true) then tips[#tips + 1] = kind .. " " .. e[1] end
				end
				for _, p in ipairs(ns.SOCKET[kind][cat]) do
					if not seen[p[1]] then unseen[#unseen + 1] = kind .. " " .. cat .. " " .. p[1] end
				end
			end
		end
	end
	db.heroes[H].gear = {}
	check(#unseen == 0, "보석·마법부여·룬 각인: 부위마다 모든 종류가 나옴", #unseen > 0 and list(unseen) or nil)
	check(#range == 0, "나온 수치가 툴팁의 범위 안 (" .. tested .. "번)", #range > 0 and list(range) or nil)
	check(#bad == 0, "박은 능력치가 그 숫자 그대로 영웅 능력치에 들어감 (보석 " .. #ns.SOCKET_TIER_MULT .. "등급 × 부위 3종 × 3종류)", #bad > 0 and list(bad, 4) or nil)
	check(#tips == 0, "툴팁에 박은 능력치가 그 숫자로 적혀 있음", #tips > 0 and list(tips) or nil)
	-- a worn item with every kind of socket filled, enhanced, with random stats
	local it = ns.Items.New("neck", 60, ns.MAX_QUALITY)
	it.up = 12
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		for _ = 1, ns.Items.SocketCount(it, kind) do ns.Items.AddSocket(it, kind, 6) end
	end
	local d = wearCheck(H, it)
	db.heroes[H].gear = {}
	check(#d == 0, "옵션 + 강화 + 홈 전부 박은 장신구: 모두 합쳐 정확히 들어감", #d > 0 and list(d, 4) or nil)
end

------------------------------------------------------------------------
section("5. 특성")
------------------------------------------------------------------------
do
	local h = db.heroes[H]
	local tested, bad = 0, {}
	local specs = {}
	for sid in pairs(ns.SPECS) do specs[#specs + 1] = sid end
	table.sort(specs)
	for _, sid in ipairs(specs) do
		h.spec = sid
		clean(H)
		for t, tier in ipairs(ns.SPECS[sid].tree) do
			for n, node in ipairs(tier) do
				if node.p then
					local lvl = node.max or 1
					h.tree = { [t * 10 + n] = lvl }
					ns.Stats.Invalidate(H)
					local got = ns.Stats.Get(H)
					h.tree = {}
					local d = diff(got, ns.Stats.Compute(H, { { node.p, node.v * lvl } }))
					tested = tested + 1
					if #d > 0 then bad[#bad + 1] = sid .. " " .. t .. "-" .. n .. " " .. node.p .. ": " .. list(d, 2) end
				end
			end
		end
	end
	h.spec, h.tree = SPEC, {}
	ns.Stats.Invalidate()
	check(#bad == 0, "모든 전문화의 모든 특성: 찍은 만큼 (수치 × 레벨) 들어감 (" .. tested .. "개)", #bad > 0 and list(bad, 4) or nil)
	-- the whole tree at once adds up the same way
	local sp = ns.SPECS[SPEC]
	local mods = {}
	h.tree = {}
	for t, tier in ipairs(sp.tree) do
		for n, node in ipairs(tier) do
			if node.p then
				h.tree[t * 10 + n] = node.max or 1
				mods[#mods + 1] = { node.p, node.v * (node.max or 1) }
			end
		end
	end
	ns.Stats.Invalidate(H)
	local got = ns.Stats.Get(H)
	h.tree = {}
	local d = diff(got, ns.Stats.Compute(H, mods))
	h.tree = {}
	ns.Stats.Invalidate(H)
	check(#d == 0, "특성을 전부 찍어도 합쳐서 정확히 들어감", #d > 0 and list(d, 4) or nil)
end

------------------------------------------------------------------------
section("6. 계정 룬 · 동료")
------------------------------------------------------------------------
do
	local H2 = newHero("PRIEST_HOLY")
	local bad, acct, tested = {}, {}, 0
	local ids = {}
	for id in pairs(ns.Runes.byId) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, rid in ipairs(ids) do
		local node = ns.Runes.byId[rid]
		if node.stat and node.max and node.max > 0 then
			clean(H) clean(H2)
			local before = { ns.Stats.Compute(H), ns.Stats.Compute(H2) }
			db.runes = { [rid] = node.max }
			ns.Runes.Invalidate()
			local v = node.per * node.max
			tested = tested + 1
			if math.abs(ns.Bonus(node.stat) - v) > 1e-9 then acct[#acct + 1] = rid .. " " .. node.stat .. " " .. ns.Bonus(node.stat) .. "/" .. v end
			for i, id in ipairs({ H, H2 }) do
				local got = ns.Stats.Get(id)
				local want = before[i]
				if ns.AFFIX[node.stat] and node.stat ~= "exp" and node.stat ~= "gold" then
					want = ns.Stats.Compute(id, { { node.stat, v } })
					-- (Compute already has the rune: take it back out for the reference)
					db.runes = {} ns.Runes.Invalidate()
					want = ns.Stats.Compute(id, { { node.stat, v } })
					db.runes = { [rid] = node.max } ns.Runes.Invalidate()
					got = ns.Stats.Get(id)
				end
				local d = diff(got, want)
				if #d > 0 then bad[#bad + 1] = rid .. " (" .. node.stat .. ") 영웅" .. i .. ": " .. list(d, 2) end
			end
		end
	end
	clean(H) clean(H2)
	check(#acct == 0, "룬마다 계정 보너스 = 레벨당 수치 × 레벨 (" .. tested .. "개)", #acct > 0 and list(acct) or nil)
	check(#bad == 0, "전투 능력치 룬은 모든 영웅에게 그만큼, 골드·경험치 룬은 보상에서만 (영웅 능력치엔 없음)", #bad > 0 and list(bad, 4) or nil)
	-- derived account limits follow their runes
	local lim = {}
	local function at(rstat, fn, base, cap)
		for rid, node in pairs(ns.Runes.byId) do
			if node.stat == rstat then
				db.runes = { [rid] = node.max } ns.Runes.Invalidate()
				local want = base + node.per * node.max
				if cap then want = min(cap, want) end
				if math.abs(fn() - want) > 1e-9 then lim[#lim + 1] = rstat .. " " .. tostring(fn()) .. "/" .. want end
			end
		end
		db.runes = {} ns.Runes.Invalidate()
	end
	at("party", ns.PartyLimit, 1, ns.PARTY_SIZE)
	at("skillSlot", ns.SkillSlots, 1, 3)
	at("bag", ns.BagSize, 30)
	at("bank", ns.BankSize or function() return 10 + ns.Bonus("bank") end, 10)
	check(#lim == 0, "파티 인원·기술 칸·가방·창고 룬이 그 한도를 올림", #lim > 0 and list(lim) or nil)
	-- companions
	local pbad = {}
	for _, pet in ipairs(ns.PETS) do
		clean(H)
		local before = ns.Stats.Compute(H)
		db.pets = { [pet.id] = true }
		ns.Runes.Invalidate()
		local mods = {}
		for k, v in pairs(pet.bonus) do
			if math.abs(ns.Bonus(k) - v) > 1e-9 then pbad[#pbad + 1] = pet.id .. " " .. k end
			if ns.AFFIX[k] and k ~= "exp" and k ~= "gold" then mods[#mods + 1] = { k, v } end
		end
		local got = ns.Stats.Get(H)
		db.pets = {} ns.Runes.Invalidate()
		local want = #mods > 0 and ns.Stats.Compute(H, mods) or before
		local d = diff(got, want)
		if #d > 0 then pbad[#pbad + 1] = pet.id .. ": " .. list(d, 2) end
	end
	clean(H)
	check(#pbad == 0, "동료 보너스: 계정 보너스로 그만큼, 전투 능력치는 영웅에게 (" .. #ns.PETS .. "마리)", #pbad > 0 and list(pbad) or nil)
end

------------------------------------------------------------------------
section("7. 기술 레벨")
------------------------------------------------------------------------
do
	local h = db.heroes[H]
	clean(H)
	local sid = ns.Heroes.SkillList(H)[1]
	h.sk = { [sid] = 3 }
	h.skills = { sid }
	local bad = {}
	for extra = 0, 3 do
		local it = ns.Items.New("neck", 60, ns.MAX_QUALITY)
		it.a, it.g, it.e = nil, nil, nil
		it.i = {}
		for _ = 1, extra do it.i[#it.i + 1] = { "skills", 1, 6 } end
		h.gear = { neck = it }
		ns.Stats.Invalidate(H)
		local want = min(ns.SKILL_CAP, 3 + extra)
		local got = ns.Heroes.SkillLevel(H, sid)
		if got ~= want then bad[#bad + 1] = "+" .. extra .. ": Lv " .. got .. "/" .. want end
	end
	clean(H)
	check(#bad == 0, "'모든 기술 레벨' 각인 1~3개 → 기술 레벨이 그만큼 (기술 점수 3 기준)", #bad > 0 and list(bad) or nil)
end

------------------------------------------------------------------------
section("8. 전투 중인 영웅에게 바로 들어가는지")
------------------------------------------------------------------------
do
	-- one hero alone in the party, level 60, no skills (no auras or buffs):
	-- its combat stats are its stat sheet
	local h = db.heroes[H]
	clean(H)
	h.spec = SPEC
	h.level = 60
	h.sk, h.skills = {}, {}
	for i = 1, ns.PARTY_SIZE do db.party[i] = nil end
	ns.Heroes.Deploy(H)
	ns.Stats.Invalidate()
	ns.Combat.StartStage()
	for _ = 1, 3 do ns.Combat.Step() end
	local function unit()
		for _, u in ipairs(ns.Combat.heroes) do if u.id == H then return u end end
	end
	check(unit() ~= nil and #ns.Combat.heroes == 1, "검사할 영웅 혼자 전투 중")
	-- after an action: on the next step the hero fighting has exactly its
	-- (fresh) stat sheet, and the stat sheet changed
	local function live(name, before)
		ns.Combat.Step()
		local u = unit()
		local fresh = ns.Stats.Compute(H)
		local shown = ns.Stats.Get(H)
		local d = u and diff(u.s, fresh) or { "전투에 없음" }
		local stale = diff(shown, fresh)
		local changed = before and #diff(before, fresh) > 0
		check(#d == 0 and #stale == 0 and u.maxhp == fresh.hp and (before == nil or changed), name,
			(#d > 0 and ("전투: " .. list(d, 3))) or (#stale > 0 and ("영웅 화면 숫자가 옛 값: " .. list(stale, 3)))
			or ((before and not changed) and "능력치가 그대로") or nil)
		return fresh
	end
	local sp = ns.Heroes.Spec(H)
	local it = ns.Items.New("mh", 60, ns.MAX_QUALITY, sp.mh[1])
	db.bag[#db.bag + 1] = it
	local s = ns.Stats.Compute(H)
	local ok = ns.Items.Equip(H, #db.bag)
	check(ok ~= false and h.gear.mh == it, "가방의 장비를 낌")
	s = live("장비를 끼면 다음 순간 전투 능력치와 영웅 화면에", s)
	-- sockets on the worn item, named by the hero wearing it
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		db.forge.ops[kind] = true
		if ns.Items.FreeSockets(it, kind) > 0 then
			local mat = ns.SOCKET[kind].mat .. "4"
			ns.AddMat(mat, 1)
			check(ns.Forge.Socket(it, kind, mat, H), ns.N(ns.SOCKET[kind].name) .. ": 낀 장비에 박음")
			s = live(ns.N(ns.SOCKET[kind].name) .. " → 다음 순간 전투 능력치와 영웅 화면에", s)
		end
	end
	-- the forge screen's target can still name the hero it was picked from
	-- after the item went elsewhere (or no hero): whoever wears it gets it
	local other = newHero("MAGE_FIRE")
	local kind = ns.SOCKET_KINDS[1]
	if ns.Items.FreeSockets(it, kind) <= 0 then
		db.forge.ops.remove = true
		ns.Forge.RemoveSocket(it, kind, 1, H)
		s = live("추출 → 다음 순간 전투 능력치와 영웅 화면에", s)
	end
	local mat = ns.SOCKET[kind].mat .. "6"
	ns.AddMat(mat, 1)
	check(ns.Forge.Socket(it, kind, mat, other), "다른 영웅 이름으로 박음")
	s = live("다른 영웅 이름으로 박아도 실제로 낀 영웅의 전투 능력치와 영웅 화면에", s)
	db.forge.ops.remove = true
	ns.Forge.RemoveSocket(it, kind, #ns.Items.SocketList(it, kind), other)
	s = live("다른 영웅 이름으로 추출해도 실제로 낀 영웅에게", s)
	-- enhancement
	local wasOpen = ns.TowerOpen
	ns.TowerOpen = function() return true end
	check(ns.Upgrade.Try(it, H), "강화 시도")
	s = live("강화 → 다음 순간 전투 능력치와 영웅 화면에", s)
	check(ns.Upgrade.Try(it, other), "다른 영웅 이름으로 강화 시도")
	s = live("다른 영웅 이름으로 강화해도 실제로 낀 영웅에게", s)
	-- the steps moved onto a piece in the bag, then that piece worn
	local it2 = ns.Items.New("mh", 60, ns.MAX_QUALITY, sp.mh[1])
	it2.a = it.a
	db.bag[#db.bag + 1] = it2
	check(ns.Upgrade.Move(it, it2, other, nil), "강화 계승 (다른 영웅 이름으로)")
	s = live("강화를 빼 간 장비를 낀 영웅에게 바로", s)
	ns.Items.Equip(H, ns.Items.IndexInBag(it2))
	s = live("강화 계승한 장비로 바꿔 끼면", s)
	ns.TowerOpen = wasOpen
	-- talents, runes, a level, companions
	check(ns.Heroes.SpendPoint(H, 1, 1), "특성 찍기")
	s = live("특성 → 다음 순간 전투 능력치와 영웅 화면에", s)
	local rune
	for rid, node in pairs(ns.Runes.byId) do
		if ns.AFFIX[node.stat] and node.stat ~= "exp" and node.stat ~= "gold" then rune = rid break end
	end
	do
		local prev = ns.Runes.prev[rune]
		while prev do db.runes[prev] = max(1, db.runes[prev] or 0) prev = ns.Runes.prev[prev] end
		ns.Runes.Invalidate()
		s = ns.Stats.Compute(H)
		check(ns.Runes.Buy(rune), "룬 배우기")
		s = live("룬 '" .. ns.N(ns.Runes.byId[rune].name) .. "' → 다음 순간 전투 능력치와 영웅 화면에", s)
	end
	h.level = 40
	h.xp = 0
	ns.Stats.Invalidate(H)
	ns.Combat.Step()
	s = ns.Stats.Compute(H)
	ns.Heroes.AddXP(H, ns.XPForLevel(h.level) + 1)
	s = live("레벨 업 → 다음 순간 전투 능력치와 영웅 화면에", s)
	local pet
	for _, p in ipairs(ns.PETS) do
		for k in pairs(p.bonus) do if ns.AFFIX[k] and k ~= "exp" and k ~= "gold" then pet = p end end
	end
	if pet then
		db.pets[pet.id] = true
		ns.Runes.Invalidate()
		s = live("동료 '" .. ns.N(pet.name) .. "' 얻기 → 다음 순간 전투 능력치에", s)
	end
	-- the skill level from an inscription reaches the skill in combat
	local sid = ns.Heroes.SkillList(H)[1]
	h.sk, h.skills = { [sid] = 2 }, { sid }
	ns.Stats.Invalidate(H)
	ns.Combat.Step()
	local neck = ns.Items.New("neck", h.level, ns.MAX_QUALITY)
	neck.a, neck.g, neck.e, neck.i = nil, nil, nil, { { "skills", 1, 6 } }
	db.bag[#db.bag + 1] = neck
	check(ns.Items.Equip(H, #db.bag) ~= false and h.gear.neck == neck, "'모든 기술 레벨' 각인 장비를 낌")
	ns.Combat.Step()
	local u = unit()
	check(u and u.slv[sid] == 3, "'모든 기술 레벨' 각인 장비를 끼면 전투 중 기술 레벨이 오름", "Lv " .. tostring(u and u.slv[sid]))
end

------------------------------------------------------------------------
print(string.format("\n  결과: %d개 통과, %d개 실패", R.pass, R.fail))
for _, x in ipairs(R.fails) do print("  - " .. x) end
return R.fail == 0
