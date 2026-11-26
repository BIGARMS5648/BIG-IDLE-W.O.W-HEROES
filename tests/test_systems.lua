-- Checks of the game systems (no UI involved).
local ns = NS
local failures = 0

local function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("  FAIL: " .. msg)
	end
end

local function section(name) print("  - " .. name) end

math.randomseed(12345)
BigWowIdleDB = nil
ns.InitDB()
local db = ns.db

-- hero id by specialization (first match)
local function hero(specId)
	for _, id in ipairs(ns.Heroes.List()) do
		if db.heroes[id].spec == specId then return id end
	end
end

-- learns a rune to a level (its top level by default), the runes before it
-- first, as far as the gold goes
local function learnRune(id, lvl)
	local R = ns.Runes
	lvl = lvl or R.byId[id].max
	for _ = 1, 1000 do
		if R.Level(id) >= lvl then return true end
		local ok = R.Buy(R.NextStepTo(id))
		if not ok then return false end
	end
	return false
end

------------------------------------------------------------------------
section("data integrity")
do
	-- every monster, stage boss, summon and companion has a 3D model (an NPC id)
	local function isId(v) return type(v) == "number" and v > 0 and v == math.floor(v) end
	local noModel = {}
	for id in pairs(ns.MONSTERS) do if not isId(ns.MODEL.mob[id]) then noModel[#noModel + 1] = id end end
	for d = 1, #ns.DIFFS do
		for i = 1, ns.STAGE_COUNT do
			if not isId(ns.MODEL.boss[d .. "-" .. i]) then noModel[#noModel + 1] = "boss " .. d .. "-" .. i end
		end
	end
	for _, pet in ipairs(ns.PETS) do
		if pet.id ~= "skull" and not isId(ns.MODEL.pet[pet.id]) then noModel[#noModel + 1] = "pet " .. pet.id end
	end
	for k in pairs(ns.MODEL.mob) do if not ns.MONSTERS[k] then noModel[#noModel + 1] = "model for no monster: " .. k end end
	-- every spec holds weapons from the level 60 five-man dungeons; a
	-- two-hander or a bow has nothing in the off hand
	local DUNGEON_WEAPON = {
		[12592] = "2h", [12940] = "1h", [12939] = "1h", [11684] = "1h", [12602] = "shield", [11923] = "1h",
		[11928] = "held", [18538] = "2h", [18680] = "ranged", [12651] = "ranged", [12590] = "1h", [13368] = "1h",
		[18392] = "1h", [22406] = "2h", [22335] = "2h", [13964] = "1h", [22336] = "shield", [18523] = "held",
		[22253] = "held", [18372] = "1h", [23124] = "2h", [13372] = "2h", [18531] = "2h", [11932] = "2h",
	}
	for sid in pairs(ns.SPECS) do
		local w = ns.MODEL.weapons[sid]
		check(w and DUNGEON_WEAPON[w.mh], sid .. ": a main hand weapon from the dungeon list")
		if w and w.oh then
			check(DUNGEON_WEAPON[w.oh] and DUNGEON_WEAPON[w.mh] == "1h", sid .. ": an off hand only next to a one-hander")
		end
		if w and DUNGEON_WEAPON[w.mh] == "ranged" then check(ns.SPECS[sid].class == "HUNTER", sid .. ": only hunters hold a bow") end
	end
	-- the looks: armor for every class and weapons for every spec at every
	-- step, each piece once, a set where the original game had one
	local SLOT_COUNT = { [0] = 2, [1] = 8, [2] = 8, [3] = 8, [4] = 8 }
	for tier = 0, 4 do
		check(ns.MODEL.GEAR_TIER_NAME[tier], "a name for look " .. tier)
		for cls in pairs(ns.CLASSES) do
			local a = ns.MODEL.armorTier[tier][cls]
			check(a and #a >= SLOT_COUNT[tier], cls .. ": armor for look " .. tier)
			local once = {}
			for _, id in ipairs(a or {}) do
				check(not once[id], cls .. ": every piece once in look " .. tier)
				once[id] = true
			end
		end
		for sid in pairs(ns.SPECS) do
			local w = ns.MODEL.weaponTier[tier][sid]
			check(w and w.mh, sid .. ": a weapon in look " .. tier)
		end
	end
	check(ns.MODEL.armorTier[2].WARRIOR == ns.MODEL.dungeonSet.WARRIOR.items and ns.MODEL.weaponTier[2] == ns.MODEL.weapons, "look 2 is the dungeon set")
	-- the Ahn'Qiraj and Naxxramas sets (the warrior's Conqueror's and Dreadnaught pieces)
	local function has(list, id) for _, x in ipairs(list) do if x == id then return true end end end
	check(has(ns.MODEL.armorTier[3].WARRIOR, 21331) and has(ns.MODEL.armorTier[4].WARRIOR, 22416), "the raid sets on the warrior")
	check(has(ns.MODEL.armorTier[1].ROGUE, 10399) and has(ns.MODEL.armorTier[1].DRUID, 6473), "the level 20s sets on the leather wearers")
	check(has(ns.MODEL.armorTier[0].MAGE, 56), "the mage starts in the apprentice's robe")
	-- every NPC has a model id
	local noDisplay = {}
	local function needs(id)
		-- an NPC by its model id, or a model id itself ("disp:<id>")
		if id and not ns.MODEL.display[id] and not (type(id) == "string" and id:match("^disp:%d+$")) then noDisplay[#noDisplay + 1] = tostring(id) end
	end
	for _, id in pairs(ns.MODEL.mob) do needs(id) end
	for _, id in pairs(ns.MODEL.boss) do needs(id) end
	for _, id in pairs(ns.MODEL.summon) do needs(id) end
	for _, f in pairs(ns.MODEL.famous) do needs(f.ALLIANCE and f.ALLIANCE.npc) needs(f.HORDE and f.HORDE.npc) end
	for _, t in pairs(ns.MODEL.trainer) do needs(t.ALLIANCE.npc) needs(t.HORDE.npc) end
	check(#noDisplay == 0, "a model id for every NPC: " .. table.concat(noDisplay, ", "))
	check(#noModel == 0, "3D models for every monster, boss and companion: " .. table.concat(noModel, ", "))
end
-- heroes are of the original game's races
do
	local ORIGINAL = { HUMAN = 1, DWARF = 1, NIGHTELF = 1, GNOME = 1, ORC = 1, UNDEAD = 1, TAUREN = 1, TROLL = 1 }
	for race in pairs(ns.RACES) do check(ORIGINAL[race], "no race from after the original game: " .. race) end
	for cid, m in pairs(ns.CLASS_RACE) do
		for fac, race in pairs(m) do
			check(ns.RACES[race] and ns.RACES[race].faction == fac, "the " .. cid .. " " .. fac .. " race belongs to that faction: " .. tostring(race))
		end
	end
end
do
	local roles = { TANK = 0, DPS = 0, HEALER = 0 }
	local seenSkill = {}
	for _, cid in ipairs(ns.CLASS_ORDER) do
		local c = ns.CLASSES[cid]
		check(ns.CLASS_ICON_COORD[cid] or ns.CLASS_ICON_SQUARE[cid], cid .. ": no class icon")
		for _, f in ipairs(ns.FACTION_ORDER) do
			local race = ns.ClassRace(cid, f)
			check(race and ns.RACES[race] and ns.RACES[race].faction == f, cid .. ": no " .. f .. " race")
		end
		check(#c.specs >= 3, cid .. ": every class needs at least three specializations")
		for _, sid in ipairs(c.specs) do check(ns.SPECS[sid] and ns.SPECS[sid].class == cid, cid .. ": bad spec " .. sid) end
	end
	check(#ns.CLASS_ORDER == 9, "expected 9 classes, got " .. #ns.CLASS_ORDER)
	check(#ns.SPEC_ORDER == 28, "expected 28 specializations, got " .. #ns.SPEC_ORDER)
	for _, sid in ipairs(ns.SPEC_ORDER) do
		local sp = ns.SPECS[sid]
		check(ns.ROLE[sp.role], sid .. ": unknown role")
		roles[sp.role] = roles[sp.role] + 1
		check(ns.SCHOOL[sp.school], sid .. ": unknown school")
		check(#sp.tree == 8, sid .. ": tree must have 8 tiers")
		check(type(ns.SpecLabel(sid)) == "string", sid .. ": label")
		for _, tier in ipairs(sp.tree) do
			check(#tier == 2, sid .. ": every talent tier has two passives")
			for _, node in ipairs(tier) do
				check(node.p and not node.s and ns.AFFIX[node.p], sid .. ": talent nodes are passives only (" .. tostring(node.p) .. ")")
			end
		end
		check(#sp.skills == 6 and #ns.SKILL_UNLOCK == 6, sid .. ": expected 6 active skills, got " .. #sp.skills)
		for _, sk in ipairs(sp.skills) do
			check(ns.SKILLS[sk], sid .. ": unknown skill " .. tostring(sk))
			seenSkill[sk] = true
		end
		for _, t in ipairs(sp.mh) do check(ns.WTYPE[t] and ns.WTYPE[t].slot == "mh", sid .. ": bad main hand type " .. t) end
		for _, t in ipairs(sp.oh) do check(ns.WTYPE[t] and ns.WTYPE[t].slot == "oh", sid .. ": bad off hand type " .. t) end
	end
	check(roles.TANK >= 3 and roles.DPS >= 15 and roles.HEALER >= 4, "role spread: " .. roles.TANK .. "/" .. roles.DPS .. "/" .. roles.HEALER)
	check(#ns.PARTY_ROLES == 5 and ns.PARTY_ROLES[1] == "TANK" and ns.PARTY_ROLES[5] == "HEALER", "party must be tank / 3 damage / healer")
	-- the nine classes of the original game, nothing else
	check(#ns.CLASS_ORDER == 9 and not ns.CLASSES.TINKER, "the nine original classes")
	for sid, sp in pairs(ns.SPECS) do check(ns.CLASSES[sp.class], sid .. ": a spec of a class that exists") end
	for _, sid in ipairs({ "DRUID_FERAL", "DRUID_GUARDIAN", "DRUID_RESTO", "SHAMAN_ENH", "SHAMAN_ELE", "SHAMAN_RESTO" }) do
		check(ns.SPECS[sid], "missing specialization " .. sid)
	end
	-- every stage's place has scenery: its own terrain models outside, the
	-- dungeon's own props inside
	for d = 1, #ns.DIFFS do
		for i = 1, ns.STAGE_COUNT do
			local key = ns.SceneryKey(d, i)
			local set = ns.SceneryFor(d, i)
			check(key and set, "stage " .. d .. "-" .. i .. " should have scenery: " .. tostring(key))
			if set then
				local n = 0
				for _, row in ipairs({ "far", "mid", "near" }) do
					check(type(set[row]) == "table", "stage " .. d .. "-" .. i .. " scenery should have a " .. row .. " row")
					for _, f in ipairs(set[row] or {}) do check(type(f) == "number" and f > 0, "scenery should be file ids") n = n + 1 end
				end
				check(n >= 4, "stage " .. d .. "-" .. i .. " scenery should have a few models")
			end
		end
	end
	check(ns.SceneryFor(1, 6) and not ns.SceneryFor(1, 6).inside, "Tirisfal should have outdoor scenery")
	check(ns.SceneryFor(1, 15) and ns.SceneryFor(1, 15).inside, "the Deadmines should have its own props")
	check(ns.SceneryKey(1, 26) ~= ns.SceneryKey(1, 30) and ns.SceneryKey(3, 4) ~= ns.SceneryKey(3, 8), "the monastery's library and armory, Stratholme's square and slaughterhouse should differ")
	-- every spec's skills open in the order the original game teaches them
	for sid, sp in pairs(ns.SPECS) do
		for i = 2, #sp.skills do
			local a, b = ns.SKILL_LEARN[sp.skills[i - 1]], ns.SKILL_LEARN[sp.skills[i]]
			check(a and b and a <= b, sid .. ": " .. sp.skills[i - 1] .. " (" .. tostring(a) .. ") should open before " .. sp.skills[i] .. " (" .. tostring(b) .. ")")
		end
	end
	check(ns.SKILL_LEARN.insect_swarm < ns.SKILL_LEARN.hurricane, "Hurricane is learned after Insect Swarm")
	-- every skill is a classic spell; all but always-on auras and pets show
	-- an effect when used
	for id, sk in pairs(ns.SKILLS) do
		local fx = ns.SKILL_FX[id]
		check(fx and type(fx.spell) == "number", id .. ": a classic spell id")
		if fx and sk.kind ~= "aura" and sk.kind ~= "pet" then
			check(fx.cast or fx.hit or fx.missile, id .. ": an effect in battle")
		end
	end
	for id in pairs(ns.SKILL_FX) do check(ns.SKILLS[id], "effect data for a skill that exists: " .. id) end
	for id in pairs(ns.SKILLS) do
		check(seenSkill[id], "skill " .. id .. " is not used by any specialization")
	end
	-- every weapon type is usable by someone
	for t in pairs(ns.WTYPE) do
		local used = false
		for _, sid in ipairs(ns.SPEC_ORDER) do
			local sp = ns.SPECS[sid]
			if ns.U.contains(sp.mh, t) or ns.U.contains(sp.oh, t) then used = true end
		end
		check(used, "weapon type " .. t .. " has no user")
	end
end
for id, sk in pairs(ns.SKILLS) do
	check(sk.act == "cd" or sk.act == "count" or sk.act == "aura", id .. ": bad activation")
	for lvl = 1, 10, 3 do
		local d = ns.SkillDesc(id, lvl)
		check(type(d) == "string" and #d > 5 and not d:find("%%s") and not d:find("nil"), id .. ": bad description: " .. tostring(d))
	end
	check(type(ns.SkillActText(id, 1)) == "string" and type(ns.SkillTag(id)) == "string", id .. ": activation text / tag")
	if sk.school then check(ns.SCHOOL[sk.school], id .. ": unknown school") end
	if sk.status then
		local key = type(sk.status) == "table" and sk.status[1] or sk.status
		check(ns.STATUS[key], id .. ": unknown status " .. tostring(key))
		if sk.kind == "dot" then check(ns.STATUS[key].kind == "dot", id .. ": dot skills need a dot status") end
	end
	if sk.mods then for _, m in ipairs(sk.mods) do check(ns.AFFIX[m[1]], id .. ": unknown mod " .. m[1]) end end
	if sk.act == "cd" then check(sk.cd and sk.cd > 0, id .. ": cooldown missing") end
	if sk.act == "count" then check(sk.n and sk.n > 0, id .. ": attack count missing") end
end
do
	-- 4 difficulties x 30 stages: a route through the original game's zones,
	-- dungeons and raids, every stage its own name and a different boss
	local names, bosses, areas = {}, {}, {}
	local ORIGINAL = {}
	for _, n in ipairs({ "엘윈 숲", "서부 몰락지대", "티리스팔 숲", "로데론의 폐허", "죽음의 폐광", "던 모로", "듀로타", "멀고어",
		"텔드랏실", "성난불길 협곡", "불모의 땅", "은빛소나무 숲", "어둠해안", "통곡의 동굴", "모단 호수", "붉은마루 산맥",
		"그림자송곳니 성채", "잿빛 골짜기", "그늘숲", "검은심연 나락", "돌발톱 산맥", "스톰윈드 지하감옥", "저습지",
		"힐스브래드 구릉지", "놈리건", "버섯구름 봉우리", "가시덩굴 우리", "아라시 고원", "가시덤불 골짜기", "붉은십자군 수도원",
		"황야의 땅", "가시덩굴 구릉", "잊혀진 땅", "먼지진흙 습지대", "슬픔의 늪", "울다만", "무법항", "페랄라스", "동부 내륙지",
		"줄파락", "타나리스", "이글거리는 협곡", "마라우돈", "아즈샤라", "운고로 분화구", "아탈학카르 신전", "악령의 숲",
		"저주받은 땅", "불타는 평원", "검은바위 나락", "서부 역병지대", "동부 역병지대", "검은바위 첨탑 하층", "여명의 설원",
		"실리더스", "검은바위 첨탑 상층", "혈투의 전장", "스트라솔름", "스칼로맨스", "전쟁노래 협곡", "아라시 분지", "알터랙 계곡",
		"안퀴라즈 폐허", "줄구룹", "화산 심장부", "오닉시아의 둥지", "검은날개 둥지", "안퀴라즈 사원", "낙스라마스" }) do
		ORIGINAL[n] = true
	end
	check(#ns.STAGES == #ns.DIFFS and #ns.DIFFS == 4, "four difficulties")
	for d = 1, #ns.DIFFS do
		check(#ns.STAGES[d] == ns.STAGE_COUNT, "difficulty " .. d .. ": stage count " .. #ns.STAGES[d])
		check(#ns.DIFFS[d].acts == 3, "difficulty " .. d .. ": three acts")
		for i, stg in ipairs(ns.STAGES[d]) do
			local where = d .. "-" .. i
			local place = stg.place
			check(place and ORIGINAL[place], where .. ": not a place of the original game: " .. tostring(place))
			-- every stage its own name
			check(type(stg.name) == "string" and stg.name ~= "" and not areas[stg.name], where .. ": area name reused: " .. tostring(stg.name))
			areas[stg.name] = true
			names[place] = true
			check(not bosses[stg.boss.name], where .. ": boss reused: " .. tostring(stg.boss.name))
			bosses[stg.boss.name] = true
			check(ns.THEMES[stg.theme], where .. ": unknown theme " .. tostring(stg.theme))
			check(#stg.mobs >= 2, where .. ": needs monsters")
			for _, e in ipairs(stg.mobs) do check(ns.MONSTERS[e[1]], where .. ": unknown monster " .. tostring(e[1])) end
			local b = stg.boss
			check(b.hp and b.hp > 0 and b.atk > 0 and b.aspd > 0, where .. ": boss stats")
			check(ns.MTYPE[b.type] and ns.SCHOOL[b.school], where .. ": boss type / school")
			check((stg.raid ~= nil) == (i % 10 == 0), where .. ": raid flag")
			for _, sk in ipairs(b.skills) do
				if sk.kind == "summon" then check(ns.MONSTERS[sk.mob], where .. ": boss summons unknown " .. tostring(sk.mob)) end
				if sk.status then check(ns.STATUS[sk.status[1]], where .. ": boss status") end
				if sk.school then check(ns.SCHOOL[sk.school], where .. ": boss skill school") end
			end
			check(type(ns.StageLabel(d, i)) == "string", where .. ": label")
		end
	end
	check(ns.U.count(names) >= 60, "many places of the original game: " .. ns.U.count(names))
	check(ns.U.count(areas) == 120, "120 different stage names")
	check(ns.STAGES[4][30].place == "낙스라마스", "the last stage is in Naxxramas")
end
do
	local used = {}
	for d = 1, #ns.DIFFS do
		for _, stg in ipairs(ns.STAGES[d]) do
			for _, e in ipairs(stg.mobs) do used[e[1]] = true end
			for _, sk in ipairs(stg.boss.skills) do if sk.mob then used[sk.mob] = true end end
		end
	end
	for id, m in pairs(ns.MONSTERS) do
		check(ns.MTYPE[m.type], id .. ": unknown monster type")
		check(ns.SCHOOL[m.school], id .. ": unknown school")
		if m.status then check(ns.STATUS[m.status[1]], id .. ": unknown status") end
		if m.res then for k in pairs(m.res) do check(ns.SCHOOL[k], id .. ": unknown resistance " .. k) end end
		check(used[id], "monster " .. id .. " never appears")
	end
end
for cat, pool in pairs(ns.AFFIX_POOL) do
	for _, e in ipairs(pool) do check(ns.AFFIX[e[1]], cat .. " pool: unknown affix " .. e[1]) end
end
-- every TBH stat a socket material can give has one of ours, and every
-- material has a name, an icon and something for each gear group
do
	local counts = { gem = 0, dust = 0, scroll = 0 }
	for id, sm in pairs(ns.TBH.SOCKET_MATS) do
		counts[sm.kind] = counts[sm.kind] + 1
		local m = ns.MATS[sm.kind .. id]
		check(m and m.name ~= "?" and m.icon and m.tier == sm.grade, "socket material " .. id .. " is defined")
		for _, cat in ipairs({ "weapon", "armor", "accessory" }) do
			local opts = sm[cat] or sm.any
			check(opts and #opts > 0, id .. ": nothing for " .. cat)
			for _, o in ipairs(opts or {}) do
				local mod = ns.TBH.STAT_MODS[o[1]]
				local d = mod and ns.SOCKET_STAT[mod.stat .. ":" .. mod.mod]
				check(d and ns.AFFIX[d[1]], id .. ": TBH stat without ours: " .. tostring(mod and (mod.stat .. ":" .. mod.mod)))
				check(o[2] >= 1 and o[3] <= 10 and o[2] <= o[3], id .. ": tiers")
			end
		end
	end
	check(counts.gem == 36 and counts.dust == 33 and counts.scroll == 10, "TBH's 36 decoration, 33 engraving and 10 inscription materials")
end
-- TBH's rune tree: every rune on its own cell, joined to the first rune,
-- each level with a value and a price, every stat read and coloured
do
	local R = ns.Runes
	local n, cells, reach = 0, {}, {}
	for id, node in pairs(R.byId) do
		n = n + 1
		local cell = node.x .. "," .. node.y
		check(not cells[cell], "rune " .. id .. " shares its cell with rune " .. tostring(cells[cell]))
		cells[cell] = id
		check(node.group and node.group.rgb, "rune " .. id .. ": no kind")
		check(#node.v == node.max and #node.c == node.max, "rune " .. id .. ": a value and a price per level")
		for l = 1, node.max do
			check((R.Cost(id, l) or 0) >= 1, "rune " .. id .. " level " .. l .. ": no price")
			check(type(R.Text(id, R.Amount(id, l))) == "string" and type(R.Text(id, R.Amount(id, l), true)) == "string", "rune " .. id .. ": text")
		end
		local prev = R.prev[id]
		if prev then
			check(R.Need(id) >= 1 and R.Need(id) <= R.byId[prev].max, "rune " .. id .. ": needs a level its rune before has")
			check(math.abs(node.x - R.byId[prev].x) <= 1 or node.x == R.byId[prev].x, "rune " .. id .. ": next to the rune before it")
		else
			check(id == ns.RUNE_FIRST, "only the first rune has none before it: " .. id)
		end
		local c = id
		while R.prev[c] do c = R.prev[c] end
		if c == ns.RUNE_FIRST then reach[#reach + 1] = id end
	end
	check(n == 197 and #reach == n, "TBH's 197 runes, all reached from the first: " .. n .. " / " .. #reach)
	check(R.byId[ns.RUNE_FIRST].x == 0 and R.byId[ns.RUNE_FIRST].y == 0, "the first rune stands in the middle")
	for _, def in pairs(ns.RUNE_STAT) do
		check(def.flag or def.time or ns.BONUS_TEXT[def.key], "rune stat " .. def.key .. ": no text")
		if def.flag then check(def.sum, "rune stat " .. def.key .. ": no short line") end
	end
end
for _, pet in ipairs(ns.PETS) do
	for k in pairs(pet.bonus) do check(ns.BONUS_TEXT[k] or ns.AFFIX[k], "pet " .. pet.id .. ": unknown bonus " .. k) end
	check(type(ns.PetUnlockText(pet)) == "string", "pet unlock text")
end
check(ns.StageLevel(1, 1) == 1 and ns.StageLevel(#ns.DIFFS, ns.STAGE_COUNT) == 95, "stage levels are TBH's: 1..95")
do
	local up, kills, act = true, true, true
	for d = 1, #ns.DIFFS do
		for i = 1, ns.STAGE_COUNT do
			local t = ns.TBH.STAGES[d][i]
			if i > 1 and ns.StageLevel(d, i) < ns.StageLevel(d, i - 1) then up = false end
			if t.act then
				if ns.StageKills(d, i) ~= 0 or ns.StageWaves(d, i) ~= 1 or t.brate ~= 1000 then act = false end
			elseif ns.StageKills(d, i) < 1 or ns.MobsPerWave(d, i) > ns.MAX_WAVE_MOBS
				or ns.StageWaves(d, i) ~= math.ceil(ns.StageKills(d, i) / ns.MobsPerWave(d, i)) + 1 then
				kills = false
			end
		end
		check(ns.TBH.STAGES[d][10].act and ns.TBH.STAGES[d][20].act and ns.TBH.STAGES[d][30].act, "every act ends in an act-boss stage")
	end
	check(up, "stage levels never go down within a difficulty")
	check(kills, "a stage's monsters come in waves of at most MAX_WAVE_MOBS, then the boss")
	check(act, "an act-boss stage is the boss alone and its box always drops")
	check(ns.XPForLevel(1) == ns.TBH.XP[1] and ns.XPForLevel(99) == ns.TBH.XP[99], "experience table is TBH's")
end

------------------------------------------------------------------------
section("hero creation, names and party roles")
db.faction = "ALLIANCE"
check(ns.Heroes.CreateCost() == 0, "first hero is free")
local okc, firstId = ns.Heroes.Create("HUNTER_MM")
check(okc and db.heroes[firstId], "create starter")
check(type(db.heroes[firstId].name) == "string" and db.heroes[firstId].name:find("^%S+ %S+$"), "a new hero gets a given and a family name: " .. tostring(db.heroes[firstId].name))
check(db.heroes[firstId].sex == nil and ns.Heroes.Sex(firstId) == ns.PlayerSex(), "a hero stores no gender and takes the player's")
check(ns.Heroes.PartySlot(firstId) == 2, "damage dealer goes to slot 2")
check(ns.Heroes.CreateCost() == ns.HERO_COST[2], "later heroes cost gold")
check(not ns.Heroes.Create("PRIEST_HOLY"), "cannot create without gold")
ns.AddGold(5e7)
check(ns.PartyLimit() == 3, "a party of 3 before the 지휘 runes")
do
	local ok2, id2 = ns.Heroes.Create("PRIEST_HOLY")
	check(ok2 and ns.Heroes.PartySlot(id2) ~= nil, "a second hero takes a free party seat")
end
-- the rune tree: each rune opens once the rune before it has the level it needs
do
	local R = ns.Runes
	check(R.Available(ns.RUNE_FIRST) and not R.Available(10), "only the first rune is open at the start")
	local ok, why = R.Buy(21)
	check(not ok and why:find(ns.N(R.byId[20].name), 1, true) and why:find("3레벨", 1, true), "buying a closed rune names the rune and level it needs: " .. tostring(why))
	local step, total = R.NextStepTo(21)
	check(step == ns.RUNE_FIRST and total == R.Cost(1, 1) + R.Cost(20, 1) + R.Cost(20, 2) + R.Cost(20, 3) + R.Cost(21, 1),
		"the way to a rune: the runes before it to the levels they need, then the rune")
	local g0 = db.gold
	check(learnRune(1, 1) and R.Available(20) and not R.Available(21), "the first rune opens the ones after it")
	check(learnRune(20, 2) and not R.Available(21), "a rune with no level named needs its rune before at the top")
	check(learnRune(20, 3) and R.Available(21), "... and opens at it")
	check(g0 - db.gold == R.Spent() and R.Spent() == total - R.Cost(21, 1), "gold spent is what the runes cost")
	check(R.Text(1, R.Amount(1, 1)):find("+1", 1, true), "a rune reads its amount")
end
check(learnRune(21) and ns.PartyLimit() == 4, "a 지휘 rune adds a party seat")
check(learnRune(24) and ns.PartyLimit() == 5, "the second 지휘 rune fills the party")
check(ns.SkillSlots() == 2, "two skill slots from the start")
check(ns.Heroes.Deploy(hero("PRIEST_HOLY")) and ns.Heroes.PartySlot(hero("PRIEST_HOLY")) == 5, "healer goes to slot 5")
for _, sid in ipairs({ "WARRIOR_PROT", "DRUID_GUARDIAN", "MAGE_FIRE", "ROGUE_OUTLAW", "WARLOCK_AFF", "SHAMAN_RESTO", "DRUID_FERAL" }) do
	check(ns.Heroes.Create(sid), "create " .. sid)
end
check(ns.Heroes.PartySlot(hero("WARRIOR_PROT")) == 1, "tank goes to slot 1")
check(ns.Heroes.PartySlot(hero("DRUID_GUARDIAN")) == nil, "only one tank slot")
check(not ns.Heroes.Deploy(hero("DRUID_GUARDIAN")), "second tank is refused")
check(not ns.Heroes.Deploy(hero("SHAMAN_RESTO")), "second healer is refused")
check(ns.Heroes.PartyCount() == 5, "party is full with 5: " .. ns.Heroes.PartyCount())
do
	local dps = 0
	for i = 2, 4 do if db.party[i] and ns.Heroes.Role(db.party[i]) == "DPS" then dps = dps + 1 end end
	check(dps == 3, "three damage dealers in slots 2-4")
end
check(not ns.Heroes.Deploy(hero("WARLOCK_AFF")), "fourth damage dealer is refused")
check(ns.Heroes.Withdraw(hero("WARRIOR_PROT")) and ns.Heroes.Deploy(hero("DRUID_GUARDIAN")) and ns.Heroes.PartySlot(hero("DRUID_GUARDIAN")) == 1, "swap tanks")
check(not ns.Heroes.Deploy(hero("WARLOCK_AFF"), 1), "damage dealer cannot take the tank slot")
check(ns.Heroes.Swap(hero("WARLOCK_AFF"), 3) and db.party[3] == hero("WARLOCK_AFF"), "swap into a slot of the right role")
do
	-- two heroes of the same specialization are separate individuals
	local a = hero("DRUID_FERAL")
	local ok3, b = ns.Heroes.Create("DRUID_FERAL")
	check(ok3 and a ~= b and db.heroes[a].name ~= db.heroes[b].name, "same spec twice: different heroes, different names")
	local before = db.heroes[b].name
	ns.Heroes.RerollName(b)
	check(type(db.heroes[b].name) == "string" and db.heroes[b].name ~= "", "reroll name")
	local bag0 = #db.bag
	check(ns.Heroes.Dismiss(b) and not db.heroes[b] and #db.bag == bag0 + 1, "dismissing returns gear to the bags")
	-- a new hero starts with the party's average experience (about their level)
	local H = ns.Heroes
	local saved, total, n = {}, 0, 0
	for i = 1, ns.PARTY_SIZE do
		local h = db.party[i] and db.heroes[db.party[i]]
		if h then
			saved[h] = { h.level, h.xp }
			h.level, h.xp = 20 + i, math.floor(ns.XPForLevel(20 + i) / 2)
			total, n = total + H.TotalXP(h), n + 1
		end
	end
	local lv, xp = H.StartLevel()
	local okN, nid = H.Create("PALADIN_RET")
	local nh = db.heroes[nid]
	check(okN and nh.level == lv and nh.xp == xp, "a new hero starts where StartLevel says")
	check(math.abs(H.TotalXP(nh) - total / n) <= 1, string.format("a new hero has the party's average experience (%d vs %d)", H.TotalXP(nh), math.floor(total / n)))
	check(nh.level >= 21 and nh.level <= 25, "levels 21..25 with half bars average to about level 23: Lv " .. nh.level)
	check(H.SkillPointsFree(nid) > 0 and H.PointsFree(nid) > 0, "a hero that starts higher has the points of its level to spend")
	H.Dismiss(nid)
	for h, v in pairs(saved) do h.level, h.xp = v[1], v[2] end
	ns.Stats.Invalidate()
	local names = {}
	for _ = 1, 200 do names[ns.Names.Roll("ORC", "M")] = true end
	check(ns.U.count(names) > 150, "names are varied")
	local clash
	for _, race in ipairs({ "HUMAN", "DWARF", "GNOME", "NIGHTELF", "UNDEAD", "TAUREN", "ORC", "TROLL" }) do
		for _ = 1, 300 do
			for part in ns.Names.Roll(race, (_ % 2 == 0) and "F" or "M"):gmatch("%S+") do
				if ns.Names.BLOCKED[part] then clash = part end
			end
		end
	end
	check(not clash, "no rolled name is a game word or a famous name (" .. tostring(clash) .. ")")
	-- every hero follows the logged-in character's gender
	local okF, f = ns.Heroes.Create("PRIEST_SHADOW")
	local Mock = WoWMock
	local was = Mock.playerSex
	Mock.playerSex = 3
	check(okF and ns.Heroes.Sex(f) == "F" and ns.PlayerSex() == "F", "on a female character, heroes are women")
	Mock.playerSex = 2
	check(ns.Heroes.Sex(f) == "M" and ns.PlayerSex() == "M", "on a male character, heroes are men")
	Mock.playerSex = was
	local okN, n = ns.Heroes.Create("PRIEST_SHADOW", nil, "테스트 이름")
	check(okN and db.heroes[n].name == "테스트 이름" and ns.Heroes.ShortName(n) == "테스트", "create with a chosen name")
	ns.Heroes.Dismiss(f)
	ns.Heroes.Dismiss(n)
	for _, pool in pairs(ns.NAME_POOLS) do
		for _, k in ipairs({ "head", "M", "F", "pre", "suf" }) do check(#pool[k] >= 10, "name pool part " .. k) end
	end
end
do
	local n = ns.Heroes.Count()
	while ns.Heroes.Count() < ns.ROSTER_MAX do ns.Heroes.Create("MAGE_FROST") end
	check(not ns.Heroes.Create("MAGE_FROST"), "roster cap is enforced")
	for _, id in ipairs(ns.Heroes.List()) do
		if db.heroes[id].spec == "MAGE_FROST" and ns.Heroes.Count() > n + 1 then ns.Heroes.Dismiss(id) end
	end
end

------------------------------------------------------------------------
section("experience and talent tree")
local H = hero("HUNTER_MM")
local before = db.heroes[H].level
ns.Heroes.AddXP(H, 5000000)
check(db.heroes[H].level > before + 15, "experience grants levels")
check(ns.Heroes.PointsFree(H) == db.heroes[H].level, "one talent point per level, all free")
check(ns.Heroes.SkillPointsFree(H) == ns.Heroes.SkillPointsTotal(H) - 2, "skill points are separate (the first two skills are pre-learned)")
check(not ns.Heroes.SpendPoint(H, 2, 1), "tier 2 locked before 10 points")
for _ = 1, 3 do check(ns.Heroes.SpendPoint(H, 1, 2), "spend on passive") end
for _ = 1, 7 do ns.Heroes.SpendPoint(H, 1, 1) end
check(ns.Heroes.TierOpen(H, 2), "tier 2 opens after 10 points")
check(ns.Heroes.SkillPointsFree(H) == ns.Heroes.SkillPointsTotal(H) - 2, "talents do not use skill points")
local sp2 = ns.Heroes.SkillList(H)[2]
check(ns.Heroes.SkillPoints(H, sp2) == 1, "the second skill is learned from the start")
check(ns.Heroes.LearnSkill(H, sp2) and ns.Heroes.SkillPoints(H, sp2) == 2, "raise a skill")
check(#ns.Heroes.ActiveSkills(H) == 2, "two skills active with two slots")
do
	local ok, why = ns.Heroes.CanLearnSkill(H, ns.Heroes.SkillList(H)[6])
	check(db.heroes[H].level >= 40 or (not ok and why:find("40")), "level-locked skill says when it opens")
end
check(ns.Heroes.UnequipSkill(H, sp2), "unequip skill")
check(ns.Heroes.LearnSkill(H, ns.Heroes.SkillList(H)[3]) and ns.Heroes.IsSkillEquipped(H, ns.Heroes.SkillList(H)[3]), "a newly learned skill is slotted")
ns.Heroes.AddXP(H, 1e12)
check(db.heroes[H].level == ns.HERO_MAX_LEVEL, "level cap is 100")
local sBefore = ns.Stats.Get(H).aspd
check(ns.Heroes.ResetTree(H), "reset tree")
check(ns.Heroes.PointsSpent(H) == 0 and ns.Stats.Get(H).aspd < sBefore, "reset refunds points and removes passives")
check(ns.Heroes.AutoSkills(H) > 0 and ns.Heroes.SkillPointsFree(H) == 0, "auto skills spends every skill point")
check(#ns.Heroes.ActiveSkills(H) == ns.SkillSlots(), "auto skills fills the slots")
check(ns.Heroes.ResetSkills(H) and ns.Heroes.SkillPointsSpent(H) == 1, "skill reset keeps only the first skill")
-- auto skills: the equipped skills first (lowest rank first); an empty slot
-- takes the next open skill; only once the equipped skills are at the top do
-- points go to learned skills out of the slots, then to new ones
do
	local list = ns.Heroes.SkillList(H)
	local h = db.heroes[H]
	local wasSlots, wasLevel = ns.SkillSlots, h.level
	local function setup(level, slots, sk, skills)
		h.level, h.sk, h.skills = level, sk, skills
		ns.SkillSlots = function() return slots end
	end
	local function ranks()
		local out = {}
		for i, sid in ipairs(list) do out[i] = h.sk[sid] or 0 end
		return table.concat(out, ",")
	end
	-- one slot, level 12 (4 points): all three free points go into the equipped skill
	setup(12, 1, { [list[1]] = 1 }, { list[1] })
	ns.Heroes.AutoSkills(H)
	check(ranks() == "4,0,0,0,0,0", "auto skills raises the equipped skill instead of learning new ones: " .. ranks())
	-- one slot, level 24 (7 points): the equipped skill to its top, the rest
	-- to a learned skill out of the slot before any new one
	setup(24, 1, { [list[1]] = 1, [list[2]] = 1 }, { list[1] })
	ns.Heroes.AutoSkills(H)
	check(ranks() == "5,2,0,0,0,0", "auto skills: equipped to the top, then learned skills, then new ones: " .. ranks())
	-- two slots, one empty, level 40 (11 points): the next open skill fills
	-- the slot, both equipped go up evenly to the top, the last point learns
	-- the next skill
	setup(40, 2, { [list[1]] = 1 }, { list[1] })
	ns.Heroes.AutoSkills(H)
	check(ranks() == "5,5,1,0,0,0", "auto skills fills an empty slot, then raises the equipped ones: " .. ranks())
	check(ns.Heroes.IsSkillEquipped(H, list[2]) and #ns.Heroes.ActiveSkills(H) == 2, "the new skill is slotted")
	check(ns.Heroes.SkillPointsFree(H) == 0, "auto skills leaves no point unspent")
	ns.SkillSlots = wasSlots
	setup(wasLevel, ns.SkillSlots(), { [list[1]] = 1 }, { list[1] })
	ns.SkillSlots = wasSlots
	ns.Stats.Invalidate(H)
end

------------------------------------------------------------------------
section("items")
do
	-- the grades, in order; the top one's colours run across its letters
	local names = { "일반", "고급", "희귀", "영웅", "전설", "불멸", "초월", "신성", "천상", "아르카나" }
	for q, n in ipairs(names) do check(ns.QUALITY[q] and ns.QUALITY[q].name == n, "grade " .. q .. " should be " .. n) end
	check(ns.QUALITY[8].hex == "fce976" and ns.QUALITY[9].hex == "00ffff", "신성 is a softer yellow, 천상 is cyan")
	check(ns.MAX_QUALITY == #names, "ten grades")
	local top = ns.QText(ns.MAX_QUALITY, "아르 카나")
	local codes = select(2, top:gsub("|cff%x%x%x%x%x%x", ""))
	check(codes == 4 and top:find("|cff" .. ns.QUALITY[ns.MAX_QUALITY].grad[1] .. "아", 1, true)
		and top:find("|cff" .. ns.QUALITY[ns.MAX_QUALITY].grad[3] .. "나", 1, true), "the top grade's name runs through its colours: " .. top)
	check(ns.QText(4, "영웅") == "|cff" .. ns.QUALITY[4].hex .. "영웅|r", "a one-colour grade is one colour")
end
for _, slot in ipairs(ns.SLOTS) do
	for q = 1, ns.MAX_QUALITY do
		for _, lvl in ipairs({ 1, 37, 100 }) do
			local it = ns.Items.New(slot, lvl, q)
			check(#(it.a or {}) == ns.QUALITY[q].affix, slot .. " q" .. q .. ": affix count")
			check(type(ns.Items.Name(it)) == "string" and type(ns.Items.Icon(it)) == "string", "name / icon")
			check(#ns.Items.Tooltip(it, H) >= 4, "tooltip")
			local gold, fxp = ns.Items.Value(it)
			check(gold > 0 and fxp > 0, "value")
			local seen = {}
			for _, a in ipairs(it.a or {}) do
				check(not seen[a[1]], "duplicate affix " .. a[1])
				seen[a[1]] = true
				check(a[2] > 0, "affix value must be positive")
			end
		end
	end
end
do
	local W, M = hero("WARRIOR_PROT"), hero("MAGE_FIRE")
	local sword = ns.Items.New("mh", 5, 2, "sword")
	check(not ns.Items.CanUse(H, sword), "hunters cannot use swords")
	check(ns.Items.CanUse(W, sword), "warriors can use swords")
	local shield, stone = ns.Items.New("oh", 5, 2, "shield"), ns.Items.New("oh", 5, 2, "whetstone")
	check(ns.Items.SpecCanUse("WARRIOR_PROT", shield) and not ns.Items.SpecCanUse("WARRIOR_ARMS", shield), "shields are for the tank spec")
	check(ns.Items.SpecCanUse("WARRIOR_ARMS", stone) and not ns.Items.SpecCanUse("WARRIOR_FURY", stone), "whetstones are for two-handed specs")
	check(#ns.Items.UsableBy(sword) > 0, "usable-by text")
	local bow = ns.Items.New("mh", 50, 5, "bow")
	db.heroes[M].level = 10
	check(not ns.Items.CanEquip(M, bow), "mage cannot equip a bow")
	local staff = ns.Items.New("mh", 50, 5, "staff")
	check(not ns.Items.CanEquip(M, staff), "level requirement applies")
	check(ns.Items.ReqLevel(staff) == 50 and ns.Items.ReqLevel(ns.Items.New("mh", 3, 1, "staff")) == 1, "required level is the item's level")
	do
		local snapped = true
		for l = 1, 100 do
			local it = ns.Items.New("head", l, 2)
			local want = 1
			for _, v in ipairs(ns.TBH.ITEM_LEVELS) do if v <= l then want = v end end
			if it.l ~= want then snapped = false end
		end
		check(snapped, "item levels are TBH's wear levels (1, 5, 10, 15, 20, 30, 40, 50, 65, 80, 100)")
	end
	db.heroes[M].level = 60
	ns.Stats.Invalidate(M)
	db.bag = {}
	ns.Items.AddToBag(staff)
	local p0 = ns.Stats.Power(M)
	check(ns.Items.Compare(M, staff) > 1, "a level 50 epic staff is an upgrade")
	check(ns.Items.Equip(M, 1), "equip from bag")
	check(ns.Stats.Power(M) > p0, "power rises after equipping")
	check(#db.bag == 1 and db.bag[1].s == "mh", "old weapon returns to the bag")
	check(ns.Items.Unequip(M, "mh") and #db.bag == 2, "unequip")
	check(ns.Items.AutoEquip(M) >= 1 and db.heroes[M].gear.mh == staff, "auto-equip picks the best weapon")
end

-- every random stat on an item lies in the range its tooltip shows
do
	local I = ns.Items
	local outside, ranged, fixed = 0, 0, 0
	for _, slot in ipairs(ns.SLOTS) do
		for q = 2, ns.MAX_QUALITY do
			for _, lvl in ipairs({ 1, 23, 60, 100 }) do
				for _ = 1, 6 do
					local it = I.New(slot, lvl, q)
					for _, a in ipairs(it.a or {}) do
						local lo, hi = I.AffixRange(it, a[1])
						if lo then
							ranged = ranged + 1
							if a[2] < lo or a[2] > hi or lo >= hi then outside = outside + 1 end
							if not I.AffixText(it, a):find("~", 1, true) then outside = outside + 1 end
						else
							fixed = fixed + 1
							if a[1] ~= "skills" then outside = outside + 1 end
						end
					end
				end
			end
		end
	end
	check(ranged > 500 and outside == 0, string.format("every item stat lies in its shown range (%d checked, %d outside)", ranged, outside))
	local it = I.New("mh", 40, 5, "sword")
	local found
	for _, l in ipairs(I.Tooltip(it)) do if l[1]:find("~", 1, true) then found = true end end
	check(found, "the item tooltip shows the ranges of its random stats")
end

-- the hero screen shows every element's resistance and the share healed on a kill
do
	local id = hero("MAGE_FIRE")
	local h = db.heroes[id]
	local saved = h.gear.chest
	local it = ns.Items.New("chest", h.level, 2)
	it.a = { { "res_fire", 12 }, { "allres", 3 } }
	h.gear.chest = it
	ns.Stats.Invalidate(id)
	local row
	for _, g in ipairs(ns.Stats.Groups(id)) do
		for _, r in ipairs(g[2]) do if r[1] == "원소 저항" then row = r end end
	end
	check(row and row[2]:find("~", 1, true) and row[4], "원소 저항 shows the spread and a per-element tooltip")
	local fire
	for _, l in ipairs(row and row[4] or {}) do if l[1] == "화염 저항" then fire = l[2] end end
	check(fire and fire:find("^15"), "fire resistance = its own + 모든 원소 저항, got " .. tostring(fire))
	h.gear.chest = saved
	ns.Stats.Invalidate(id)
end

-- 전투력 compares any two heroes: same level and gear quality -> close
-- together whatever the role or spec (a tank used to show 5-10x a healer)
do
	local lo, hi, saved = 1e18, 0, {}
	for _, sid in ipairs(ns.SPEC_ORDER) do
		local h = ns.Heroes.NewRecord(sid)
		h.level = 40
		math.randomseed(7)
		local sp = ns.SPECS[sid]
		h.gear = {}
		for _, slot in ipairs(ns.SLOTS) do
			local w
			if slot == "mh" then w = sp.mh[1] elseif slot == "oh" then w = sp.oh and sp.oh[1] end
			if slot ~= "oh" or w then h.gear[slot] = ns.Items.New(slot, 40, 4, w) end
		end
		ns.Stats.Invalidate(h.id)
		local p = ns.Heroes.PowerScore(h.id)
		lo, hi = math.min(lo, p), math.max(hi, p)
		db.heroes[h.id] = nil
	end
	check(hi / lo < 1.3, string.format("전투력 is comparable across all specs (%d ~ %d)", lo, hi))
	math.randomseed(12345)
end

------------------------------------------------------------------------
section("stat layers")
do
	local R = hero("ROGUE_OUTLAW")
	db.heroes[R].gear = {}
	db.heroes[R].tree = {}
	ns.Stats.Invalidate(R)
	local s0 = ns.Stats.Compute(R)
	local s1 = ns.Stats.Compute(R, { { "atk", 10 }, { "atkPct", 50 }, { "atkPct", 50 }, { "atkMult", 100 } })
	local rune = 1 + ns.Bonus("atkPct") / 100
	local base = ns.BaseAtLevel(ns.SPECS.ROGUE_OUTLAW, "atk", db.heroes[R].level) + ns.Bonus("atk")
	local expect = (base + 10) * (rune + 1.0) * 2 * ns.SpecTune("ROGUE_OUTLAW", "atk")
	check(math.abs(s1.atk - expect) < 0.01, "final = (base+flat)*(1+add)*(1+mult): " .. s1.atk .. " vs " .. expect)
	check(ns.Stats.ArmorDR(ns.ArmorK(20), 20) == 0.5, "armor equal to the threshold halves damage")
	check(ns.Stats.ArmorDR(1e9, 20) == 0.75, "armor reduction caps at 75%")
	local capped = ns.Stats.Compute(R, { { "dodge", 500 }, { "cdr", 500 }, { "dr", 500 } })
	check(capped.dodge == 60 and capped.cdr == 60 and capped.dr == 75, "caps apply")
	check(s0.atk > 0 and #ns.Stats.Sheet(R) > 8, "sheet rows")
	-- account-wide gold / experience bonuses must not be counted once per hero
	local g, e = ns.Bonus("gold"), ns.Bonus("exp")
	local gr, xr = ns.Runes.FirstFor("gold"), ns.Runes.FirstFor("exp")
	local gl, xl = ns.Runes.Level(gr), ns.Runes.Level(xr)
	check(learnRune(gr, gl + 1) and learnRune(xr, xl + 1), "learn a gold and an experience rune")
	check(math.abs(ns.Bonus("gold") - g - (ns.Runes.Amount(gr, gl + 1) - ns.Runes.Amount(gr, gl))) < 1e-9
		and math.abs(ns.Bonus("exp") - e - (ns.Runes.Amount(xr, xl + 1) - ns.Runes.Amount(xr, xl))) < 1e-9,
		"gold / experience runes raise the account bonus")
	local s = ns.Stats.Compute(R)
	check(s.gold == 0 and s.exp == 0, "account gold / exp bonuses are not folded into hero stats")
end

------------------------------------------------------------------------
section("chests and loot")
db.bag = {}
db.chests = {}
for _ = 1, 100 do ns.Loot.AddChest(1, 20, 1) end
check(ns.Loot.Count(1) == ns.ChestCap(1), "chest capacity is enforced: " .. ns.Loot.Count(1))
local sum = ns.Loot.OpenAll()
check(sum.opened == ns.ChestCap(1), "open all")
check(ns.Loot.Count() == 0, "no chests left")
db.bag = {}
for _ = 1, ns.BagSize() do ns.Items.AddToBag(ns.Items.New("head", 3, 2)) end
ns.Loot.AddChest(2, 20, 1)
db.opt.autoSmelt = 0
sum = ns.Loot.OpenAll()
check(sum.opened == 0 and sum.full, "a full bag keeps chests closed")
do
	-- by hand: a click opens one chest, or every chest of its kind with
	-- 개방의 룬; a right-click stops its kind opening by itself, and starts
	-- it again
	db.bag = {}
	db.chests = {}
	local was = { [1021] = db.runes[1021], [13002] = db.runes[13002] }
	for _ = 1, 4 do ns.Loot.AddChest(1, 10, 1) end
	ns.Loot.AddChest(2, 10, 1)
	db.runes[1021] = nil
	ns.Runes.Invalidate()
	ns.Loot.OpenByHand(1, "kind")
	check(ns.Loot.Count(1) == 3, "a click before 개방의 룬 opens one chest")
	db.runes[1021] = 1
	ns.Runes.Invalidate()
	ns.Loot.OpenByHand(1, "kind")
	check(ns.Loot.Count(1) == 0 and ns.Loot.Count(2) == 1, "a click with 개방의 룬 opens every chest of its kind, no other")
	db.runes[13002] = nil
	ns.Runes.Invalidate()
	check(not ns.Loot.ToggleAutoStop(1) and not ns.Loot.AutoStopped(1), "with no auto-open there is nothing to stop")
	db.runes[13002] = 1
	ns.Runes.Invalidate()
	check(ns.Loot.AutoRunning(1), "the chest opens by itself with its 태엽의 룬")
	check(ns.Loot.ToggleAutoStop(1) and ns.Loot.AutoStopped(1) and not ns.Loot.AutoRunning(1), "a right-click stops the auto-open")
	for _ = 1, 3 do ns.Loot.AddChest(1, 10, 1) end
	ns.Loot.Tick(ns.Loot.AutoInterval(1) + 5)
	check(ns.Loot.Count(1) == 3, "a stopped auto-open opens nothing")
	check(db.autoStop[1] == true, "a stopped auto-open is kept in the save")
	ns.Loot.ToggleAutoStop(1)
	check(ns.Loot.AutoRunning(1), "another right-click starts the auto-open again")
	ns.Loot.Tick(ns.Loot.AutoInterval(1) + 5)
	check(ns.Loot.Count(1) == 0, "the auto-open runs again once started")
	for rid, v in pairs(was) do db.runes[rid] = v end
	ns.Runes.Invalidate()
	db.chests = {}
	db.bag = {}
end
do
	-- a box's gear is the box's own level (TBH): no cap by the party's level
	local key = ns.Loot.BoxFor("monster", 95)
	local lo, hi = ns.Loot.BoxLevels(key)
	check(lo >= 80 and hi <= 100 and lo <= hi, "a level 95 monster box holds level 80~100 gear: " .. lo .. "~" .. hi)
	local fromBox, gear, mats = true, 0, 0
	for _ = 1, 600 do
		local r = ns.Loot.RollBox(key)
		if r.item then
			gear = gear + 1
			if r.item.l < lo or r.item.l > hi then fromBox = false end
		else
			mats = mats + 1
			check(ns.MATS[r.mat] ~= nil, "box material is known: " .. tostring(r.mat))
		end
	end
	check(fromBox, "box gear keeps the box's levels whatever the party's level")
	check(gear > 0 and mats > 0, "boxes hold gear and materials: " .. gear .. " / " .. mats)
	-- every box rolls to something real
	local bad = 0
	for k in pairs(ns.TBH.BOXES) do
		for _ = 1, 30 do
			local r = ns.Loot.RollBox(k)
			if not (r.item and ns.Items.Name(r.item)) and not (r.mat and r.n and r.n > 0) then bad = bad + 1 end
		end
	end
	check(bad == 0, "every TBH box opens to an item or materials")
	-- each stage's boxes are TBH's
	local missing = 0
	for d = 1, #ns.DIFFS do
		for i = 1, ns.STAGE_COUNT do
			local t = ns.TBH.STAGES[d][i]
			if not ns.TBH.BOXES[t.bbox] or (t.mbox and not ns.TBH.BOXES[t.mbox]) then missing = missing + 1 end
		end
	end
	check(missing == 0, "every stage's boxes exist")
	-- a chest kept from before (no box) opens as the box of its kind and level
	check(ns.TBH.BOXES[ns.Loot.BoxFor("boss", 37)].lv <= 37 and ns.TBH.BOXES[ns.Loot.BoxFor("act", 1)], "an old chest finds its box")
end
do
	-- grade odds follow the box's table: common is likelier than rare
	local key = ns.TBH.STAGES[1][1].mbox
	local counts = {}
	for _ = 1, 4000 do
		local r = ns.Loot.RollBox(key)
		if r.item then counts[r.item.q] = (counts[r.item.q] or 0) + 1 end
	end
	check((counts[1] or 0) + (counts[2] or 0) > (counts[4] or 0), "low grades are likelier than rare from the first box")
	-- the luck bonus raises the better grades
	local function rare(luck)
		local was = ns.Bonus
		ns.Bonus = function(k) if k == "luck" then return luck end return was(k) end
		local n = 0
		local box = ns.TBH.STAGES[4][29].bbox
		for _ = 1, 4000 do
			local r = ns.Loot.RollBox(box)
			if r.item and r.item.q >= 5 then n = n + 1 end
		end
		ns.Bonus = was
		return n
	end
	check(rare(200) > rare(0), "luck makes the better grades likelier")
end
-- a piece above every hero's level is kept as a future upgrade
do
	db.bag = {}
	local top = ns.Heroes.PartyTopLevel()
	local future = ns.Items.New("mh", 100, 4)
	ns.Items.AddToBag(future)
	if top < 100 then
		check(ns.Items.FutureUpgrade(future), "a level 100 weapon waits in the bag for a hero to reach it")
	end
	db.bag = {}
end

------------------------------------------------------------------------
section("titan forge")
local F = ns.Forge
db.bag = {}
db.forge = { level = 1, xp = 0, ops = { fuse = true }, craft = { true } }
check(not F.Smelt({}), "smelt is locked at first")
check(F.Unlock("smelt"), "unlock smelt")
check(not F.Unlock("craft"), "craft needs forge level 5")
local it = ns.Items.New("chest", 10, 3)
ns.Items.AddToBag(it)
local g0 = db.gold
-- (a piece better than what the party wears: only when the player picks it)
check(not F.Smelt({ it }) or not ns.Items.PartyUpgrade(it), "a better piece is not broken down in a batch")
local ok, gold = F.Smelt({ it }, { manual = true })
check(ok and gold > 0 and db.gold == g0 + gold and #db.bag == 0, "smelting pays gold and removes the item")
check(db.forge.xp > 0 or db.forge.level > 1, "smelting grants forge experience")
db.bag = {}
for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, 2)) end
check(F.PickForFusion(2, "gear") == nil or not ns.Items.PartyUpgrade(db.bag[1]), "upgrades for the party are never fused")
local savedParty = db.party
db.party = { false, false, false, false, false } -- nobody to upgrade: everything may be fused
local list = F.PickForFusion(2, "gear")
check(list and #list == 9, "pick nine for fusion")
local okf, result = F.Fuse(list)
check(okf and #db.bag == 1 and result.q >= 3, "nine commons fuse into one better item")
db.bag = {}
for _ = 1, 8 do ns.Items.AddToBag(ns.Items.New("head", 12, 2)) end
ns.Items.AddToBag(ns.Items.New("ring", 12, 2))
check(not F.Fuse(db.bag), "armor and accessories do not mix")
db.bag = {}
for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, ns.MAX_QUALITY)) end
check(not F.Fuse(db.bag), "the top quality cannot be fused")
do
	local same, up = 0, 0
	for _ = 1, 300 do
		db.bag = {}
		for _ = 1, 9 do ns.Items.AddToBag(ns.Items.New("head", 12, 5)) end
		local _, r = F.Fuse(F.PickForFusion(5, "gear"))
		if r.q == 5 then same = same + 1 else up = up + 1 end
	end
	check(same > 100 and up > 80, "epic fusion can fail or succeed (" .. same .. "/" .. up .. ")")
end
db.party = savedParty
db.mats = {}
ns.AddMat("bar1", 9)
local okm, nextId = F.FuseMat("bar1")
check(okm and nextId == "bar2" and ns.MatCount("bar2") == 1 and ns.MatCount("bar1") == 0, "nine materials become one of the next tier")
check(not F.FuseMat("bar5"), "top tier material cannot be fused")
db.bag = {}
db.forge.level = 30
for _, op in ipairs(ns.FORGE_OPS) do if not F.Unlocked(op.key) then check(F.Unlock(op.key), "unlock " .. op.key) end end
for g = 1, #ns.CRAFT_GROUPS do
	local cost = F.CraftCost(g, 1)
	for id, n in pairs(cost) do ns.AddMat(id, n) end
	local okc2, crafted = F.Craft(g, 1)
	check(okc2 and crafted and crafted.l >= 1 and crafted.l <= 15, "craft group " .. g)
end
check(not F.Craft(1, 1), "crafting without materials fails")
check(not F.Craft(1, 2), "craft tier 2 is locked until bought")
check(F.UnlockCraftTier(2), "unlock craft tier 2")
local epic = ns.Items.New("chest", 40, 5)
check(ns.Items.FreeSockets(epic, "gem") == 2 and ns.Items.FreeSockets(epic, "ench") == 1 and ns.Items.FreeSockets(epic, "insc") == 0, "epic sockets")
local GEM3, DUST2, SCROLL1 = ns.SocketMat("gem", 3), ns.SocketMat("dust", 2), ns.SocketMat("scroll", 1)
ns.AddMat(GEM3, 3)
ns.AddMat(DUST2, 1)
check(F.Socket(epic, "gem", GEM3) and F.Socket(epic, "gem", GEM3), "socket two gems")
check(not F.Socket(epic, "gem", GEM3), "no third gem socket")
check(F.Socket(epic, "ench", DUST2), "enchant")
check(not F.Socket(epic, "insc", SCROLL1), "an immortal item has no inscription slot")
check(not F.Socket(epic, "gem", DUST2), "wrong material kind is refused")
check(#epic.g == 2 and #epic.e == 1, "socket entries stored")
local goldBefore = db.gold
check(F.RemoveSocket(epic, "gem", 1) and #epic.g == 1 and db.gold < goldBefore, "extraction costs gold and frees the slot")
check(ns.MatCount(GEM3) == 1, "extraction does not refund the material")
check(F.RemoveCost("gem", 5) == 1500 and F.RemoveCost("insc", 10) == 200000, "extraction costs are TBH's")
-- socket stats are rolled: each value lies in the range the tooltip shows
do
	local I = ns.Items
	local outside, ranged, fixed = 0, 0, 0
	for _, slot in ipairs({ "mh", "chest", "ring" }) do
		for _, kind in ipairs(ns.SOCKET_KINDS) do
			for tier = 1, ns.MAT_MAX_TIER[ns.SOCKET[kind].mat] do
				for _, mat in ipairs(ns.Forge.MatsAt(ns.SOCKET[kind].mat, tier)) do
					for _ = 1, 6 do
						local it = I.New(slot, 30, ns.MAX_QUALITY)
						local e = I.AddSocket(it, kind, mat)
						local lo, hi = I.SocketRange(it, kind, e)
						if lo then
							ranged = ranged + 1
							if e[2] < lo or e[2] > hi or lo >= hi then outside = outside + 1 end
						else
							fixed = fixed + 1
							-- (one more strike, or a TBH tier with a single number)
							local r = ns.TBH.STAT_MODS[e[5]][e[3]]
							if e[1] ~= "multi" and e[1] ~= "aspd" and r[1] ~= r[2] then outside = outside + 1 end
						end
						-- what was set is one of the material's options for this gear group
						local ok = false
						for _, p in ipairs(I.SocketPool(mat, it)) do
							if p[1] == e[1] and e[2] >= p[2] - 1e-9 and e[2] <= p[3] + 1e-9 then ok = true end
						end
						if not ok then outside = outside + 1 end
					end
				end
			end
		end
	end
	check(outside == 0, "every socket value lies in its shown range (" .. outside .. " outside)")
	check(ranged > 0 and fixed > 0, "rolled stats show a range, the fixed ones (one more strike) do not")
	local it = I.New("mh", 30, ns.MAX_QUALITY)
	local e = I.AddSocket(it, "gem", ns.SocketMat("gem", 3))
	local text = I.SocketText(it, "gem", e)
	check(text:find("%(") and text:find("~", 1, true), "the socket text ends with its range: " .. text)
	local tip = table.concat((function() local t = {} for _, l in ipairs(I.Tooltip(it)) do t[#t + 1] = l[1] end return t end)(), "\n")
	check(tip:find("~", 1, true), "the item tooltip shows the socket range")
	-- the sockets are drawn: a filled one with its material's icon, the
	-- empty ones by kind
	local top = I.New("chest", 50, ns.MAX_QUALITY)
	local gem4 = ns.SocketMat("gem", 4)
	I.AddSocket(top, "gem", gem4)
	local filled, order, emptyOf = nil, {}, {}
	for _, l in ipairs(I.Tooltip(top)) do
		if l.sockets then
			local kind = l.sockets[1][1]
			if order[#order] ~= kind then order[#order + 1] = kind end
			if l.sockets[1][2] then
				filled = filled or l.sockets[1]
			else
				for _, s in ipairs(l.sockets) do check(s[1] == kind, "an empty-socket line holds one kind only") end
				emptyOf[kind] = #l.sockets
			end
		end
	end
	check(filled and filled[1] == "gem" and filled[2] == ns.MATS[gem4].icon, "a set gem shows that gem's icon in its socket")
	check(table.concat(order, ",") == "gem,ench,insc", "sockets come kind by kind: gem, then ench, then insc (" .. table.concat(order, ",") .. ")")
	check(emptyOf.gem == I.SocketCount(top, "gem") - 1 and emptyOf.ench == I.SocketCount(top, "ench") and emptyOf.insc == I.SocketCount(top, "insc"),
		"each kind's empty sockets are drawn on that kind's own line")
end
db.bag = {}
ns.AddMat("seal1", 1)
local okb, rolled = F.BonusRoll(1)
check(okb and rolled and #db.bag == 1, "bonus roll gives one item")
check(not F.BonusRoll(1), "no seal, no roll")

------------------------------------------------------------------------
section("equipment enhancement")
do
	local Up = ns.Upgrade
	local savedProg = { db.prog[1], db.prog[2], db.prog[3], db.prog[4] }
	local savedGold, savedBag = db.gold, db.bag
	db.bag = {}
	local it = ns.Items.New("chest", 100, 5)
	ns.Items.AddToBag(it)
	check(Up.Level(it) == 0, "a piece starts at +0")
	-- locked until 신화+ opens (신화 cleared to its end)
	db.prog[3], db.prog[4] = ns.STAGE_COUNT - 1, 0
	db.gold = 1e15
	check(not Up.Open() and not Up.Try(it), "enhancement is locked before 신화+ opens")
	db.prog[1], db.prog[2], db.prog[3] = ns.STAGE_COUNT, ns.STAGE_COUNT, ns.STAGE_COUNT
	check(Up.Open(), "enhancement opens with 신화+ (신화 cleared)")
	check(Up.LOCKED_TEXT == "신화+ 난이도에 도달하면 해금할 수 있습니다.", "the lock text names 신화+")
	db.prog[4] = ns.STAGE_COUNT
	-- every try can fail (the gold is gone, the step stays): the same chance
	-- up to +10, lower and lower after; each step costs more
	check(Up.Chance(0) == Up.LOW and Up.Chance(Up.SAFE - 1) == Up.LOW and Up.LOW < 1, "up to +10 every try has the same chance")
	for n = Up.SAFE, Up.MAX - 1 do
		check(Up.Chance(n) < Up.Chance(n - 1), "the chance falls from +" .. n)
	end
	local base0 = ns.Items.BaseStats(it)[1][2]
	for n = 1, Up.MAX - 1 do check(Up.Cost(it, n) > Up.Cost(it, n - 1), "each step costs more than the one before") end
	local wins, fails, sawTen = 0, 0, false
	for _ = 1, 4000 do
		if Up.Level(it) >= Up.MAX then break end
		local n = Up.Level(it)
		local g, cost = db.gold, Up.Cost(it, n)
		local ok, success, now = Up.Try(it)
		check(ok and db.gold == g - cost, "every try costs its gold")
		if success then wins = wins + 1 check(now == n + 1, "a success adds one step") else fails = fails + 1 check(now == n, "a failure keeps the step") end
		if now == Up.SAFE and not sawTen then
			sawTen = true
			check(ns.Items.Tooltip(it)[1][1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("^%+10 ") ~= nil, "the tooltip names the step before the item: +10")
			local base10 = ns.Items.BaseStats(it)[1][2]
			check(math.abs(base10 / base0 - Up.Bonus(10)) < 0.05, "+10 raises the base stats by its bonus: " .. base10 / base0)
		end
	end
	check(Up.Bonus(0) == 1 and Up.Bonus(10) > 1 and Up.Bonus(20) > Up.Bonus(10), "each step gives more")
	check(Up.Level(it) == Up.MAX and wins == Up.MAX and fails > 0, "tries can fail and the top is +" .. Up.MAX)
	local ok, why = Up.Try(it)
	check(not ok and why, "no step past the top")
	-- an enhanced piece is kept out of auto salvage and fusion
	local picks = ns.Forge.PickByQuality(ns.MAX_QUALITY)
	for _, x in ipairs(picks) do check(x ~= it, "an enhanced piece is not salvaged automatically") end
	-- 계승: 70% of the old piece's worth in steps on a piece of the same
	-- slot, no gold, the old piece used up
	local other = ns.Items.New("chest", 100, ns.MAX_QUALITY)
	ns.Items.AddToBag(other)
	check(Up.SourceFor(other) == it, "the enhanced chest is the one to move from")
	local n = Up.MoveResult(it, other)
	local worth = Up.Worth(it) * Up.KEEP
	check(n > 5 and n < Up.MAX and Up.Worth(other, n) <= worth and Up.Worth(other, n + 1) > worth,
		"the new step is the highest the kept worth pays for: +" .. n)
	local g = db.gold
	local okMove, got = Up.Move(it, other)
	check(okMove and got == n and Up.Level(other) == n and db.gold == g, "계승 costs no gold and gives that step")
	check(ns.Items.IndexInBag(it) == nil and ns.Items.IndexInBag(other) ~= nil, "the old piece is used up")
	local ring = ns.Items.New("ring", 100, 5)
	ns.Items.AddToBag(ring)
	check(not Up.CanMove(other, ring) and Up.SourceFor(ring) == nil, "steps move only between pieces of the same slot")
	local plain = ns.Items.New("chest", 100, ns.MAX_QUALITY)
	ns.Items.AddToBag(plain)
	check(not Up.CanMove(plain, other), "a piece at +0 has nothing to move")
	-- a cheap piece's steps are worth little on a dear one
	local cheap = ns.Items.New("chest", 5, 1)
	cheap.up = Up.MAX
	ns.Items.AddToBag(cheap)
	check(Up.MoveResult(cheap, plain) < 10, "+20 on a level 5 piece moves as a few steps: +" .. Up.MoveResult(cheap, plain))
	-- the target's own steps count too
	local same = ns.Items.New("chest", 100, ns.MAX_QUALITY)
	same.up = 15
	check(Up.MoveResult(other, same) > 15, "the target's own steps are kept and added to: +" .. Up.MoveResult(other, same))
	-- from a worn piece: the new piece takes its place on that hero
	local H = db.party[1]
	local hero = db.heroes[H]
	local wornBefore, levelBefore = hero.gear.chest, hero.level
	hero.level = ns.HERO_MAX_LEVEL
	hero.gear.chest = other
	ns.Items.RemoveFromBag(ns.Items.IndexInBag(other))
	check(Up.Move(other, plain), "계승 from a worn piece")
	check(hero.gear.chest == plain and ns.Items.IndexInBag(plain) == nil and ns.Items.IndexInBag(other) == nil and Up.Level(plain) > 0,
		"the new piece is worn in the old one's place")
	hero.gear.chest, hero.level = wornBefore, levelBefore
	ns.Stats.Invalidate(H)
	-- a protected piece is never the one to move from
	local locked = ns.Items.New("chest", 100, ns.MAX_QUALITY)
	locked.up, locked.lock = 12, true
	ns.Items.AddToBag(locked)
	local fresh = ns.Items.New("chest", 100, ns.MAX_QUALITY)
	ns.Items.AddToBag(fresh)
	check(Up.SourceFor(fresh) ~= locked and not Up.CanMove(locked, fresh), "a protected piece is not used for 계승")
	locked.lock = nil
	check(Up.SourceFor(fresh) == locked and Up.CanMove(locked, fresh), "once unprotected it is")
	-- what is set in the sockets moves along, into the new piece's free
	-- sockets; what finds no room is lost
	local gemMat = ns.SocketMat("gem", 4)
	local dustMat = ns.SocketMat("dust", 4)
	for _ = 1, ns.Items.SocketCount(locked, "gem") do ns.Items.AddSocket(locked, "gem", gemMat) end
	ns.Items.AddSocket(locked, "ench", dustMat)
	local gems, ench = {}, locked.e[1]
	for i, e in ipairs(locked.g) do gems[i] = e end
	local small = ns.Items.New("chest", 100, 5) -- 전설: gem sockets, an enchant socket, no inscription
	ns.Items.AddToBag(small)
	ns.Items.AddSocket(small, "gem", gemMat)
	local ownGem = small.g[1]
	local plan = Up.SocketPlan(locked, small)
	local room = ns.Items.SocketCount(small, "gem") - 1
	check(plan.gem and plan.gem.moved == math.min(#gems, room) and plan.gem.lost == #gems - plan.gem.moved
		and plan.ench and plan.ench.moved == 1 and plan.ench.lost == 0, "the plan: as many as there is room for")
	check(Up.Move(locked, small), "계승 with sockets")
	local same = small.g[1] == ownGem
	for i = 1, plan.gem.moved do same = same and small.g[1 + i] == gems[i] end
	check(same and #small.g == 1 + plan.gem.moved and plan.gem.lost > 0, "the gems moved into the free sockets, its own kept, the one without room lost")
	check(small.e and small.e[1] == ench and #small.e == 1, "the enchant moved along")
	db.prog[1], db.prog[2], db.prog[3], db.prog[4] = savedProg[1], savedProg[2], savedProg[3], savedProg[4]
	db.gold, db.bag = savedGold, savedBag
end

section("combat: every specialization and every skill")
db.bag = {}
db.chests = {}
db.prog = { 30, 30, 30, 30 }
check(learnRune(ns.Runes.FirstFor("skillSlot")) and ns.SkillSlots() == 3, "the 각성 rune gives a third skill slot")
-- a fresh roster with one hero of every specialization
for _, id in ipairs(ns.Heroes.List()) do db.heroes[id] = nil end
db.party = { false, false, false, false, false }
local bySpec = {}
for _, sid in ipairs(ns.SPEC_ORDER) do
	local h = ns.Heroes.NewRecord(sid)
	h.level = 40
	for _, sk in ipairs(ns.SPECS[sid].skills) do h.sk[sk] = 2 end
	bySpec[sid] = h.id
end
ns.Stats.Invalidate()
local C = ns.Combat
local function skillsOf(sid, a, b, c)
	local s = ns.SPECS[sid].skills
	return { s[a], s[b], s[c] }
end
local tanks, healers, dps = {}, {}, {}
for _, sid in ipairs(ns.SPEC_ORDER) do
	local role = ns.SPECS[sid].role
	local list = role == "TANK" and tanks or (role == "HEALER" and healers or dps)
	list[#list + 1] = sid
end
local casts = {}
local runs = 0
for rot = 0, 1 do
	for i = 1, #dps, 3 do
		local party = { tanks[(runs % #tanks) + 1], dps[i], dps[(i % #dps) + 1], dps[((i + 1) % #dps) + 1], healers[(runs % #healers) + 1] }
		for slot = 1, 5 do
			local id = bySpec[party[slot]]
			db.party[slot] = id
			db.heroes[id].skills = rot == 0 and skillsOf(party[slot], 1, 2, 3) or skillsOf(party[slot], 4, 5, 6)
		end
		-- 일반 and 영웅 stages (levels 1..55) for these level-40 heroes without gear
		db.stage = { diff = 1 + runs % 2, idx = 1 + (runs * 7) % 30 }
		C.StartStage()
		for _ = 1, 1500 do
			C.Step()
			for _, u in ipairs(C.heroes) do
				if u.castIcon then casts[u.castIcon] = true end
			end
		end
		runs = runs + 1
	end
end
check(db.stat.kills > 100, "monsters died: " .. db.stat.kills)
check(db.stat.clears > 0, "stages were cleared: " .. db.stat.clears)
do
	-- every non-aura skill should have been cast at least once somewhere
	local missing = {}
	for id, sk in pairs(ns.SKILLS) do
		if sk.act ~= "aura" and not casts[sk.icon] then missing[#missing + 1] = id end
	end
	-- emergency and revive skills only fire when things go wrong; allow a few
	check(#missing <= 12, "skills never cast: " .. table.concat(missing, ", "))
end
do
	-- damage meters attribute damage and healing to the right heroes
	for slot, sid in ipairs({ "WARRIOR_PROT", "MAGE_FIRE", "ROGUE_OUTLAW", "HUNTER_BM", "PRIEST_HOLY" }) do
		db.party[slot] = bySpec[sid]
		db.heroes[bySpec[sid]].skills = skillsOf(sid, 1, 2, 3)
	end
	-- a stage the level 40 party wins while taking hits
	db.stage = { diff = 1, idx = 25 }
	C.StartStage()
	for _ = 1, 1200 do C.Step() end
	-- the running stage plus the one before it (a stage may just have restarted)
	local function total(sid, key)
		local id = bySpec[sid]
		return (C.meter[id] and C.meter[id][key] or 0) + (C.lastMeter[id] and C.lastMeter[id][key] or 0)
	end
	check(total("MAGE_FIRE", "dmg") > 0, "the mage dealt damage")
	check(total("PRIEST_HOLY", "heal") > 0, "the priest healed")
	check(total("WARRIOR_PROT", "taken") > 0, "the tank was hit")
	local petOwner
	for _, u in ipairs(C.heroes) do if u.spec == "HUNTER_BM" then petOwner = u end end
	check(petOwner and next(petOwner.pets) ~= nil, "the beast master's companion is out")
end
-- an under-geared solo hero must lose on a hard stage and retreat
db.opt.auto, db.opt.retreat, db.opt.retry = true, true, true
db.stage = { diff = 3, idx = 10 }
db.party = { false, bySpec.HUNTER_MM, false, false, false }
db.heroes[bySpec.HUNTER_MM].gear = {}
ns.Stats.Invalidate()
local wipes = db.stat.wipes
C.StartStage()
for _ = 1, 3000 do C.Step() end
check(db.stat.wipes > wipes, "a hopeless fight ends in defeat")
check(db.stage.idx < 10 or db.stage.diff < 3, "defeat retreats to an earlier stage")
check(not C.CanTravel(1, 31) and C.CanTravel(4, 30), "travel limits")
db.prog = { 3, 0, 0, 0 }
check(C.CanTravel(1, 4) and not C.CanTravel(1, 5) and not C.CanTravel(2, 1), "only unlocked stages are reachable")
check(#C.fx <= 40, "visual event list stays bounded")

------------------------------------------------------------------------
section("offline rewards")
db.rate = { gold = 10, xp = 5, level = 5 }
db.lastSeen = 1000
check(ns.Offline.Claim(1000 + 3600) == nil, "no offline rewards before the 안식 rune")
check(learnRune(11001) and ns.OfflineOn(), "the 안식 rune turns offline rewards on")
db.lastSeen = 1000
local g1 = db.gold
local r = ns.Offline.Claim(1000 + 3600)
check(r and r.gold == math.floor(10 * 3600 * ns.Offline.Efficiency()) and db.gold == g1 + r.gold, "one hour away pays the measured rate")
db.lastSeen = 1000
r = ns.Offline.Claim(1000 + 20 * 3600)
check(r and r.counted == ns.Offline.Cap(), "rewards are capped")
db.lastSeen = 1000
r = ns.Offline.Claim(1000 + 31 * 86400)
check(r and r.expired and r.gold == 0, "a month away pays nothing")
db.lastSeen = 1000
check(ns.Offline.Claim(1030) == nil, "less than a minute pays nothing")
-- a clock set back keeps the later time, so the span is not paid twice
db.lastSeen = 50000
check(ns.Offline.Claim(40000) == nil and db.lastSeen == 50000, "an earlier clock pays nothing and keeps the saved time")
ns.Offline.Stamp(45000)
check(db.lastSeen == 50000, "a stamp never moves the saved time back")
-- experience shown is what the heroes took: none at the top level
do
	local keep = {}
	for slot = 1, ns.PARTY_SIZE do
		local id = db.party[slot]
		if id and db.heroes[id] then keep[id] = db.heroes[id].level db.heroes[id].level = ns.HERO_MAX_LEVEL end
	end
	db.rate = { gold = 10, xp = 10, level = 5 }
	db.lastSeen = 1000
	r = ns.Offline.Claim(1060)
	check(r and r.xp == 0 and r.gold > 0, "heroes at the top level take no offline experience")
	for id, lv in pairs(keep) do db.heroes[id].level = lv ns.Stats.Invalidate(id) end
end

------------------------------------------------------------------------
section("companions")
db.pets = {}
local catNeed = ns.PET_BY_ID.cat.unlock.n
db.kills = { beast = catNeed - 1 }
ns.Runes.Invalidate()
local e0 = ns.Bonus("exp")
ns.CheckPets()
check(not db.pets.cat, "the cat waits for its kill count")
db.kills = { beast = catNeed }
ns.CheckPets()
check(db.pets.cat and ns.Bonus("exp") == e0 + 15, "enough beast kills unlock the cat and its bonus")

------------------------------------------------------------------------
section("stage results: retry, first clears, companions, income")
do
	for slot, sid in ipairs({ "WARRIOR_PROT", "MAGE_FIRE", "ROGUE_OUTLAW", "HUNTER_BM", "PRIEST_HOLY" }) do
		db.party[slot] = bySpec[sid]
	end
	ns.Stats.Invalidate()
	local function untilClear(limit)
		local c0 = db.stat.clears
		for _ = 1, limit or 6000 do
			C.Step()
			if db.stat.clears > c0 then return true end
		end
		return false
	end
	-- the retry option turned off while farming: stay on the stage, auto off
	db.prog = { 10, 0, 0, 0 }
	db.stage = { diff = 1, idx = 5 }
	db.opt.auto, db.opt.retry, db.retry = true, false, 3
	C.StartStage()
	check(untilClear(), "a farmed stage is cleared")
	check(db.retry == 0 and not db.opt.auto and db.stage.idx == 5, "retry turned off: the countdown stops and the stage stays")
	-- the countdown runs out: back up to the stage that was lost
	db.stage = { diff = 1, idx = 5 }
	db.opt.auto, db.opt.retry, db.retry = true, true, 1
	C.StartStage()
	untilClear()
	check(db.retry == 0 and db.stage.idx == 6, "the last counted clear goes back up a stage")
	-- auto off: no countdown starts after a retreat
	db.opt.auto, db.opt.retreat, db.opt.retry = false, true, true
	db.prog = { 30, 30, 9, 0 }
	db.stage = { diff = 3, idx = 10 }
	local keep = db.party
	db.party = { false, bySpec.HUNTER_MM, false, false, false }
	ns.Stats.Invalidate()
	local w0 = db.stat.wipes
	C.StartStage()
	for _ = 1, 3000 do
		C.Step()
		if db.stat.wipes > w0 then break end
	end
	check(db.stat.wipes > w0 and (db.retry or 0) == 0, "with auto off a retreat starts no retry countdown")
	db.party = keep
	ns.Stats.Invalidate()

	-- a first clear with the boss chest storage full counts as a lost chest
	db.opt.auto, db.retry = false, 0
	db.prog = { 4, 0, 0, 0 }
	db.stage = { diff = 1, idx = 5 }
	db.chests = {}
	for _ = 1, ns.ChestCap(2) do db.chests[#db.chests + 1] = { t = 2, l = 5, d = 1, box = ns.TBH.STAGES[1][5].bbox } end
	local lost0 = db.stat.lost or 0
	C.StartStage()
	untilClear()
	check(db.prog[1] == 5 and (db.stat.lost or 0) > lost0, "a first-clear chest that does not fit is counted as lost")
	db.chests = {}

	-- a companion comes with the kill that completes it, not at the stage's end
	db.pets = {}
	db.kills = { beast = catNeed - 1 }
	db.stage = { diff = 1, idx = 1 }
	C.StartStage()
	local c0 = db.stat.clears
	for _ = 1, 3000 do
		C.Step()
		if (db.kills.beast or 0) >= catNeed then break end
	end
	check(db.stat.clears == c0 and db.pets.cat, "the cat joins on the kill that reaches its count")

	-- income is measured over real time, game speed included, and kept
	-- even when no stage has been won
	local speed = ns.GameSpeed
	ns.GameSpeed = function() return 1.25 end
	C.FoldRate(0)
	local t0 = C.earn.t
	C.Update(2.0)
	check(math.abs((C.earn.t - t0) - 2.0) < 0.11, "a faster game still counts real seconds: " .. (C.earn.t - t0))
	ns.GameSpeed = speed
	db.rate = { gold = 0, xp = 0 }
	C.earn.g, C.earn.x, C.earn.t = 3, 2, 10
	ns.Offline.Stamp(5000)
	check(db.rate.gold > 0 and math.abs(db.rate.gold - 0.3) < 1e-9, "a kill before the first win already sets the income")
end

------------------------------------------------------------------------
section("the endless tower")
do
	local T = ns.Tower
	local st = C.state
	for slot, sid in ipairs({ "WARRIOR_PROT", "MAGE_FIRE", "ROGUE_OUTLAW", "HUNTER_BM", "PRIEST_HOLY" }) do
		db.party[slot] = bySpec[sid]
	end
	ns.Stats.Invalidate()
	local savedProg, savedChests = { db.prog[1], db.prog[2], db.prog[3], db.prog[4] }, db.chests
	db.tower = { on = false, floor = 1, best = 0 }
	db.prog = { 30, 30, 30, 29 }
	check(not T.Open() and not C.EnterTower(1), "the tower is closed before the last difficulty is cleared")
	db.prog = { 30, 30, 30, 30 }
	check(T.Open() and T.Top() == 1, "it opens with Mythic+ 30, from floor 1")
	check(not C.EnterTower(2), "a floor past the one after the best cannot be entered")
	check(C.EnterTower(1) and db.tower.on and st.tower == 1 and st.level == T.LEVEL, "entering the tower fights its first floor")
	-- a floor's place, monsters and boss: rolled anew each time it starts, each
	-- on its own; raid bosses on every tenth floor
	local places, packs, bosses, raidOk, mixed = {}, {}, {}, true, false
	for k = 1, 200 do
		local f = (k % 10 == 0) and 20 or 7
		local r = T.Roll(f)
		places[r.place[1] .. "-" .. r.place[2]] = true
		packs[r.mobs[1] .. "-" .. r.mobs[2]] = true
		bosses[r.boss[1] .. "-" .. r.boss[2]] = true
		if (ns.Stage(r.boss[1], r.boss[2]).raid and true or false) ~= T.IsRaid(f) then raidOk = false end
		if ns.Stage(r.mobs[1], r.mobs[2]).raid then raidOk = false end
		if r.place[1] ~= r.mobs[1] or r.place[2] ~= r.mobs[2] then mixed = true end
	end
	local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
	check(raidOk and mixed and count(places) >= 50 and count(packs) >= 50 and count(bosses) >= 50,
		string.format("places, packs and bosses rolled at random, raid bosses on the tenth floors: %d / %d / %d", count(places), count(packs), count(bosses)))
	local a = { st.diff, st.idx, st.mobStage[1], st.mobStage[2], st.bossStage[1], st.bossStage[2] }
	local changed = false
	for _ = 1, 5 do
		C.StartStage()
		local b = { st.diff, st.idx, st.mobStage[1], st.mobStage[2], st.bossStage[1], st.bossStage[2] }
		for i = 1, 6 do if a[i] ~= b[i] then changed = true end end
	end
	check(changed and st.tower == 1, "the same floor started again is rolled anew")
	do
		C.StartStage()
		for _ = 1, 400 do C.Step() if C.state.phase == "fight" then break end end
		local want = ns.Stage(st.mobStage[1], st.mobStage[2]).mobs
		local ok = #C.mobs > 0
		for _, m in ipairs(C.mobs) do
			local found = false
			for _, e in ipairs(want) do if e[1] == m.def.id then found = true end end
			if not found then ok = false end
		end
		check(ok, "the monsters come from the pack rolled for the floor")
	end
	check(#T.Affixes(4) == 0 and #T.Affixes(5) == 1 and T.Affixes(5)[1].key == "fortified" and #T.Affixes(49) == 9
		and #T.Affixes(50) == 10 and #T.Affixes(120) == #ns.TOWER_AFFIXES, "one more affix every fifth floor, in order")
	check(T.Kills(10) == 0 and T.Waves(10) == 1 and T.Kills(1) == T.WAVES * T.MobsPerWave()
		and T.Kills(41) > T.Kills(39), "a raid floor is its boss alone; 무리 brings more monsters")
	check(T.HPMult(30) > T.HPMult(29) and T.AtkMult(30) > T.AtkMult(29) and T.GoldMult(30) > T.GoldMult(1), "monsters grow stronger and richer every floor")
	for _, a in ipairs(ns.TOWER_AFFIXES) do
		check(T.FX[a.key] and type(a.text) == "string" and a.icon, "affix " .. a.key .. ": its effect, text and icon")
	end

	-- every chest of the tower holds gear of item level 100, better grades higher up
	db.chests = {}
	db.bag = {}
	local levels, mean = {}, {}
	for _, f in ipairs({ 1, 80 }) do
		local sum, k = 0, 0
		for _ = 1, 3000 do
			local r = ns.Loot.RollBox(T.Box(2), T.ITEM_LEVEL, T.Luck(f))
			if r.item then
				levels[r.item.l] = true
				sum, k = sum + r.item.q, k + 1
			end
		end
		mean[f] = sum / math.max(1, k)
	end
	check(levels[100] and next(levels, next(levels)) == nil, "tower boxes hold item level 100 gear only")
	check(mean[80] > mean[1] + 0.3, string.format("higher floors give better grades: %.2f -> %.2f", mean[1], mean[80]))
	ns.Loot.AddChest(2, T.ITEM_LEVEL, 1, T.Box(2), 7)
	check(db.chests[1].tf == 7, "a tower chest keeps its floor")
	-- (the bag emptied after each one: every chest has room to open)
	local opened, got, all100 = 0, 0, true
	for _ = 1, 40 do
		db.bag = {}
		ns.Loot.AddChest(1, T.ITEM_LEVEL, 1, T.Box(1), 7)
		local sum = ns.Loot.OpenAll(1)
		opened = opened + sum.opened
		for _, it in ipairs(db.bag) do
			got = got + 1
			if it.l ~= 100 then all100 = false end
		end
	end
	all100 = all100 and got > 0
	check(opened == 40 and all100, "opened tower chests give level 100 gear: " .. opened .. " opened")
	db.bag, db.chests = {}, {}

	-- a first clear: a new best, its gold and one more chest; then up a floor
	local hp, atk = T.HPMult, T.AtkMult
	T.HPMult = function() return 1e-9 end
	db.opt.auto, db.opt.retry, db.retry = true, true, 0
	db.tower = { on = true, floor = 1, best = 0 }
	C.StartStage()
	local g0, c0 = db.gold, db.stat.clears
	for _ = 1, 6000 do
		C.Step()
		if db.stat.clears > c0 then break end
	end
	check(db.stat.clears > c0 and db.tower.best == 1 and db.tower.floor == 2, "a cleared floor is the new best and the next floor comes")
	check(db.gold - g0 >= T.FirstGold(1), "the first clear pays its gold")
	local boss = 0
	for _, ch in ipairs(db.chests) do if ch.t == 2 and ch.tf == 1 then boss = boss + 1 end end
	check(boss >= 2, "the boss chest and the first clear's chest, both of the tower: " .. boss)
	-- a floor cleared again pays no first-clear gold
	db.tower.floor = 1
	C.StartStage()
	local best0 = db.tower.best
	c0 = db.stat.clears
	for _ = 1, 6000 do C.Step() if db.stat.clears > c0 then break end end
	check(db.tower.best == best0, "clearing a floor again sets no new best")
	-- every affix at once runs (floor 60, a raid floor; floor 59 with monsters)
	db.tower.best = 59
	for _, f in ipairs({ 59, 60 }) do
		db.tower.floor = f
		C.StartStage()
		c0 = db.stat.clears
		local ok = pcall(function() for _ = 1, 6000 do C.Step() if db.stat.clears > c0 then break end end end)
		check(ok and db.stat.clears > c0, "floor " .. f .. " with its affixes is fought to the end")
	end
	-- a wipe: one floor down, that floor again (eight clears, then up)
	T.HPMult, T.AtkMult = function() return 1e6 end, function() return 1e6 end
	db.tower.floor, db.opt.auto, db.opt.retry, db.retry = 30, true, true, 0
	C.StartStage()
	local w0 = db.stat.wipes
	for _ = 1, 6000 do C.Step() if db.stat.wipes > w0 then break end end
	check(db.stat.wipes > w0 and db.tower.floor == 29 and db.retry == 8, "a wipe drops one floor and counts eight clears before trying again")
	db.tower.floor, db.opt.retry, db.retry = 30, false, 0
	C.StartStage()
	w0 = db.stat.wipes
	for _ = 1, 6000 do C.Step() if db.stat.wipes > w0 then break end end
	check(db.tower.floor == 29 and not db.opt.auto, "without the retry option the floor below is repeated")
	T.HPMult, T.AtkMult = hp, atk
	-- a trip to a stage leaves the tower
	db.opt.auto = true
	check(C.Travel(1, 1) and not db.tower.on and not st.tower, "travelling to a stage leaves the tower")
	db.prog = { savedProg[1], savedProg[2], savedProg[3], savedProg[4] }
	C.StartStage()
	check(not st.tower and not db.tower.on, "with the tower closed again the stages are fought")
	db.chests = savedChests
	db.tower = { on = false, floor = 1, best = 0 }
end

------------------------------------------------------------------------
section("gear score and protection")
do
	local I = ns.Items
	local U = ns.U
	local savedParty, savedStage = db.party, db.stage
	db.bag = {}
	db.stage = { diff = 1, idx = 5 }
	local mage = bySpec.MAGE_FIRE
	db.party = { false, mage, false, false, false }
	local h = db.heroes[mage]
	h.gear = {}
	h.skills = skillsOf("MAGE_FIRE", 1, 2, 3)
	local base = I.New("chest", 40, 3)
	base.a = {}
	h.gear.chest = base
	ns.Stats.Invalidate()
	local function with(a)
		local it = U.copy(base)
		it.a = a
		return it
	end
	-- every combat stat counts
	for _, a in ipairs({ { "leech", 30 }, { "regen", 500 }, { "allres", 50 }, { "hph", 100 }, { "absorb", 100 }, { "thorns", 50 }, { "hpk", 300 } }) do
		local r = I.Compare(mage, with({ a }))
		check(r and r > 1, "the gear score counts " .. a[1] .. ": " .. tostring(r))
	end
	check(I.Compare(mage, with({ { "leech", 30 }, { "regen", 500 }, { "allres", 50 }, { "hph", 100 }, { "absorb", 100 } })) > I.UPGRADE,
		"lifesteal, regeneration, resistances and absorb together make an upgrade")
	-- +1 to all skills
	check(I.Compare(mage, with({ { "skills", 1 } })) > I.UPGRADE, "+1 to all skills makes an upgrade")
	-- the score is the same wherever the party fights: each element's
	-- resistance counts the same, on a fire boss's stage too
	do
		local fireStage
		for d = 1, #ns.DIFFS do
			for i = 1, ns.STAGE_COUNT do
				local stg = ns.Stage(d, i)
				if not fireStage and stg.boss.school == "fire" then fireStage = { diff = d, idx = i } end
			end
		end
		local frostOnly = with({ { "res_frost", 60 } })
		local fireOnly = with({ { "res_fire", 60 } })
		local armored = with({ { "armor", 400 } })
		local here = { I.Compare(mage, fireOnly), I.Compare(mage, frostOnly), I.Compare(mage, armored) }
		db.stage = fireStage
		local there = { I.Compare(mage, fireOnly), I.Compare(mage, frostOnly), I.Compare(mage, armored) }
		check(math.abs(here[1] - here[2]) < 1e-9, "fire and frost resistance score the same")
		check(math.abs(here[1] - there[1]) < 1e-9 and math.abs(here[3] - there[3]) < 1e-9,
			"an item scores the same on another stage (fire boss " .. fireStage.diff .. "-" .. fireStage.idx .. ")")
		db.stage = { diff = 1, idx = 5 }
	end
	-- element damage counts for the elements of the equipped skills
	do
		local found
		for _, sid in ipairs(ns.SPEC_ORDER) do
			local sp = ns.SPECS[sid]
			for _, sk in ipairs(sp.skills) do
				local d = ns.SKILLS[sk]
				if not found and d.school and d.school ~= sp.school and (d.kind == "dmg" or d.kind == "dot") then found = { sid, sk, d.school } end
			end
		end
		if found then
			local hid = bySpec[found[1]]
			local hh = db.heroes[hid]
			hh.gear = {}
			hh.sk[found[2]] = math.max(1, hh.sk[found[2]] or 0)
			hh.skills = { found[2] }
			ns.Stats.Invalidate(hid)
			local it = I.New("ring", 40, 3)
			it.a = { { "dmg_" .. found[3], 20 } }
			local r = I.Compare(hid, it, true)
			check(r and r > 1, "damage of an equipped skill's element counts (" .. found[2] .. ", " .. found[3] .. "): " .. tostring(r))
		end
	end
	-- multistrike stops at 100%
	h.gear.chest = with({ { "multi", 180 } })
	ns.Stats.Invalidate(mage)
	check(ns.Stats.Get(mage).multi == 100, "multistrike is capped at 100%")
	h.gear.chest = base
	ns.Stats.Invalidate(mage)

	-- every step up on the way is kept for a low hero
	local low = ns.Heroes.NewRecord("WARRIOR_PROT")
	low.level = 1
	db.party = { low.id, false, false, false, false }
	ns.Stats.Invalidate()
	db.bag = {}
	local h10 = I.New("head", 10, 3)
	local h100 = I.New("head", 100, ns.MAX_QUALITY)
	I.AddToBag(h10) I.AddToBag(h100)
	check(I.FutureUpgrade(h100), "the top piece for later is kept")
	check(I.FutureUpgrade(h10), "the level 10 piece is kept too, for the levels before the top one")
	local worse10 = I.New("head", 10, 1)
	I.AddToBag(worse10)
	check(not I.FutureUpgrade(worse10) or I.Compare(low.id, worse10, true) > I.Compare(low.id, h10, true), "a weaker piece of the same step is not kept")

	-- breaking down and fusion check every piece themselves
	db.party = { false, false, false, false, false }
	db.bag = {}
	local locked = I.New("feet", 20, 2)
	locked.lock = true
	I.AddToBag(locked)
	check(not F.Smelt({ locked }) and I.IndexInBag(locked), "a protected piece is never broken down")
	check(not F.Smelt({ locked }, { manual = true }) and I.IndexInBag(locked), "not even when picked by hand")
	local nine = { locked }
	for _ = 1, 8 do local x = I.New("feet", 20, 2) I.AddToBag(x) nine[#nine + 1] = x end
	check(not F.Fuse(nine) and I.IndexInBag(locked), "a protected piece is never fused")
	local up = I.New("feet", 20, 2)
	up.up = 3
	I.AddToBag(up)
	check(not F.Smelt({ up }) and I.IndexInBag(up), "an enhanced piece is not broken down in a batch")
	check(F.Smelt({ up }, { manual = true }) and not I.IndexInBag(up), "an enhanced piece goes when the player picks it")
	local twice = {}
	for i = 2, 9 do twice[#twice + 1] = nine[i] end
	twice[9] = nine[2]
	check(not F.Fuse(twice), "the same piece twice is not fused")

	-- the party's auto-equip gives a piece to whom it helps most
	local tank, arms = bySpec.WARRIOR_PROT, bySpec.WARRIOR_ARMS
	db.party = { tank, arms, false, false, false }
	db.heroes[tank].gear = { chest = I.New("chest", 40, 3) }
	db.heroes[arms].gear = {}
	ns.Stats.Invalidate()
	db.bag = {}
	local better = I.New("chest", 40, 4)
	I.AddToBag(better)
	local rt, ra = I.Compare(tank, better), I.Compare(arms, better)
	I.AutoEquipParty()
	check(db.heroes[arms].gear.chest == better or (rt and ra and rt > ra), "the piece goes to the hero it helps most")

	-- heroes waiting outside the party: their gear kept when the option is on
	local bench = bySpec.PRIEST_HOLY
	db.party = { false, false, false, false, false }
	db.heroes[bench].gear = {}
	ns.Stats.Invalidate()
	db.bag = {}
	local forBench = I.New("chest", 40, 3)
	I.AddToBag(forBench)
	F.Unlock("smelt")
	db.opt.keepBench = false
	local picked = F.PickByQuality(ns.MAX_QUALITY)
	check(#picked == 1, "without the option a bench hero's upgrade may be broken down")
	db.opt.keepBench = true
	picked = F.PickByQuality(ns.MAX_QUALITY)
	check(#picked == 0 and I.KeepReason(forBench), "with the option it is kept")
	check(F.FuseBlock(forBench), "and kept out of fusion")
	db.opt.keepBench = false

	-- a long frame: the fight catches up over the next frames
	local C2 = ns.Combat
	db.party = savedParty
	ns.Stats.Invalidate()
	C2.Update(0)
	local before = C2.Backlog()
	local steps = 0
	local step = C2.Step
	C2.Step = function() steps = steps + 1 end
	C2.Update(10)
	local afterOne = steps
	for _ = 1, 10 do C2.Update(0) end
	C2.Step = step
	check(afterOne <= 31 and steps >= 99 + math.floor(before / 0.1), "a 10 second frame runs 3 seconds at once and the rest after: " .. afterOne .. " then " .. steps)
	db.stage = savedStage
	db.bag = {}
end

------------------------------------------------------------------------
section("save repair and migration")
-- saves from before the renames (the old file copied to BigIdleHeroes.lua)
BigWowIdleDB, BigWowHeroesDB = nil, nil
BigIdleWoWHeroesDB = { v = 2, gold = 4321, heroes = {}, party = { false, false, false, false, false } }
ns.InitDB()
check(ns.db.gold == 4321, "a save under the first name BigIdleWoWHeroesDB loads")
check(BigWowIdleDB == ns.db and BigIdleWoWHeroesDB == nil, "it moves to BigWowIdleDB")
BigWowIdleDB = nil
BigWowHeroesDB = { v = 2, gold = 8765, heroes = {}, party = { false, false, false, false, false } }
ns.InitDB()
check(ns.db.gold == 8765, "a save under the name BigWowHeroesDB loads")
check(BigWowIdleDB == ns.db and BigWowHeroesDB == nil, "it moves to BigWowIdleDB")
BigWowIdleDB = { v = 2, gold = 11, heroes = {}, party = { false, false, false, false, false } }
BigWowHeroesDB = { v = 2, gold = 22, heroes = {}, party = { false, false, false, false, false } }
ns.InitDB()
check(ns.db.gold == 11 and BigWowHeroesDB == nil, "a save under the new name wins over a leftover old one")
-- a save from before TBH's runes: the runes are taken back and their gold returned
BigWowIdleDB = { v = 6, gold = 1000, heroes = {}, party = { false, false, false, false, false },
	runes = { root = 1, w1 = 2, c1 = 1, zz = 3 } }
ns.loadNote = nil
ns.InitDB()
check(ns.db.gold == 1000 + 50 + 100 + 160 + 300 and next(ns.db.runes) == nil, "old runes are taken back, their gold returned: " .. ns.db.gold)
check(ns.loadNote == nil, "the refund comes without a chat message: " .. tostring(ns.loadNote))
ns.loadNote = nil
BigWowIdleDB = { v = 7, gold = 5, heroes = {}, party = { false, false, false, false, false }, runes = { [1] = 9, [10] = 2, [999999] = 1 } }
ns.InitDB()
check(ns.db.gold == 5 and ns.db.runes[1] == 1 and ns.db.runes[10] == 2 and ns.db.runes[999999] == nil and ns.loadNote == nil,
	"a current save keeps its runes, at most at their top level")
-- a version 1 save: one hero per class, keyed by class
BigWowIdleDB = {
	v = 1, gold = 77,
	heroes = {
		MAGE = { level = 12, xp = 5, tree = { [11] = 3 }, skills = { "fireball" }, gear = { mh = { s = "mh", t = "staff", l = 5, q = 3 } } },
		WARRIOR = { level = 9, xp = 0, tree = {}, skills = {}, gear = { oh = { s = "oh", t = "shield", l = 3, q = 2 } } },
	},
	party = { "WARRIOR", "MAGE", false, false, false },
	prog = { 12, 0, 0, 0 },
}
ns.InitDB()
db = ns.db
check(db.v == 7 and db.gold == 77 and ns.Heroes.Count() == 2, "version 1 saves are migrated")
do
	local m, w = hero("MAGE_FIRE"), hero("WARRIOR_PROT")
	check(m and w, "old heroes become heroes of the matching specialization")
	check(db.heroes[m].level == 12 and db.heroes[m].gear.mh and db.heroes[m].gear.mh.t == "staff", "level and gear survive")
	check(ns.Heroes.PointsFree(m) == 12, "talent points are refunded")
	check(db.party[1] == w and db.party[2] == m, "the party survives")
	check(type(db.heroes[m].name) == "string", "migrated heroes get a name")
	check(db.prog[1] == 12, "progress survives")
end
BigWowIdleDB = { v = 2, gold = 5, heroes = { h9 = { spec = "NOPE" }, h3 = { spec = "MAGE_FROST", level = 3 } }, party = { "h3", "h9" } }
ns.InitDB()
check(ns.db.gold == 5 and ns.db.heroes.h9 == nil and ns.db.party[2] == false, "unknown specializations are dropped")
check(ns.db.heroSeq >= 3 and type(ns.db.heroes.h3.name) == "string" and ns.db.heroes.h3.gear, "missing hero fields are repaired")
ns.Heroes.ValidateParty()
check(ns.db.party[1] == false and ns.Heroes.PartySlot("h3") == 2, "a hero in the wrong role slot is moved")
check(ns.db.forge.level == 1 and ns.db.opt.auto == true, "missing fields get defaults")
-- a version 3 save: skills that became other classic spells keep their
-- levels and slots under the new ids
BigWowIdleDB = { v = 3, heroes = { h1 = { spec = "WARRIOR_ARMS", level = 50, name = "가 나",
	sk = { mortal_strike = 3, bladestorm = 4 }, skills = { "bladestorm", "mortal_strike" } },
	h2 = { spec = "MAGE_FROST", level = 50, name = "다 라", sk = { frostbolt = 2, water_elemental = 5, ice_lance = 1 }, skills = { "water_elemental", "ice_lance" } } },
	party = { false, "h1", "h2", false, false } }
ns.InitDB()
do
	local a, f = ns.db.heroes.h1, ns.db.heroes.h2
	check(a.sk.sweeping_strikes == 4 and a.sk.bladestorm == nil and a.skills[1] == "sweeping_strikes", "renamed skills keep their level and slot")
	check(f.sk.ice_armor == 5 and f.sk.cone_of_cold == 1 and f.skills[1] == "ice_armor" and f.skills[2] == "cone_of_cold", "every renamed skill moves to its new id")
end
-- a save with a tinker (a class that is gone): the hero goes, its gear comes
-- to the bag, guns and gadgets anywhere become bows and orbs
BigWowIdleDB = { v = 3, gold = 9, bag = { { s = "oh", t = "gadget", l = 4, q = 2 } }, bank = {},
	heroes = {
		h1 = { spec = "TINKER_TURRET", level = 20, name = "가 나", gear = { mh = { s = "mh", t = "gun", l = 18, q = 3 }, head = { s = "head", l = 17, q = 2 } } },
		h2 = { spec = "HUNTER_MM", level = 20, name = "다 라", gear = { mh = { s = "mh", t = "gun", l = 19, q = 4 } } },
	},
	party = { false, "h1", "h2", false, false } }
ns.InitDB()
do
	local d = ns.db
	check(d.heroes.h1 == nil and d.party[2] == false, "a tinker hero is dropped from the roster and the party")
	check(#d.bag == 3, "its gear comes to the bag: " .. #d.bag)
	local types = {}
	for _, it in ipairs(d.bag) do if it.t then types[#types + 1] = it.t end end
	table.sort(types)
	check(table.concat(types, ",") == "bow,orb", "a gun becomes a bow, a gadget an orb: " .. table.concat(types, ","))
	check(d.heroes.h2.gear.mh.t == "bow", "worn guns become bows too")
	check(d.heroes.h2.gear.mh.l == 15 and d.bag[1].l == 1, "old item levels move to the TBH level a hero of the same level wears")
	for _, it in ipairs(d.bag) do check(ns.Items.Def(it), "every kept item has a definition") end
end
-- a version 5 save: socket materials by tier become TBH's materials of
-- that grade, every one kept
BigWowIdleDB = { v = 5, mats = { gem3 = 7, dust1 = 2, scroll6 = 1, bar2 = 4 }, heroes = {}, party = { false, false, false, false, false } }
ns.InitDB()
do
	local n3, n1, n6 = 0, 0, 0
	for _, id in ipairs(ns.SOCKET_MATS_BY.gem[3]) do n3 = n3 + ns.MatCount(id) end
	for _, id in ipairs(ns.SOCKET_MATS_BY.dust[1]) do n1 = n1 + ns.MatCount(id) end
	for _, id in ipairs(ns.SOCKET_MATS_BY.scroll[6]) do n6 = n6 + ns.MatCount(id) end
	check(n3 == 7 and n1 == 2 and n6 == 1 and ns.MatCount("bar2") == 4 and ns.db.mats.gem3 == nil,
		"old socket materials become TBH's of the same grade")
end
-- version 2.0 stored names as { korean, english }, without family names
BigWowIdleDB = { v = 2, heroes = { h1 = { spec = "MAGE_FIRE", level = 5, name = { "아르단", "Ardan" } } }, party = { false, "h1" } }
ns.InitDB()
check(ns.db.heroes.h1.name:find("^아르단 %S+$"), "2.0 names keep the Korean given name and get a family name: " .. ns.db.heroes.h1.name)
check(ns.db.heroes.h1.sex == nil, "old heroes keep no gender of their own")
check(ns.db.faction == nil, "old saves still choose a faction")
-- version 2.0 kept skills in the talent tree
BigWowIdleDB = { v = 2, heroes = { h1 = { spec = "MAGE_FIRE", level = 22, name = "가 나",
	tree = { [11] = 8, [12] = 2, [13] = 3, [14] = 1, [23] = 2, [33] = 1 }, skills = { "fireball", "pyroblast" } } }, party = { false, "h1" } }
ns.InitDB()
do
	local h = ns.db.heroes.h1
	local sk = ns.SPECS.MAGE_FIRE.skills
	check(h.tree[13] == nil and h.tree[23] == nil and h.tree[11] == 8 and h.tree[12] == 2, "skill nodes leave the talent tree, passives stay")
	check(h.sk[sk[1]] and h.sk[sk[2]] and h.sk[sk[3]] and h.sk[sk[4]], "learned skills are kept")
	check(ns.Heroes.SkillPointsSpent("h1") <= ns.Heroes.SkillPointsTotal("h1"), "skill ranks fit the new budget")
	check(ns.Heroes.PointsFree("h1") == 22 - 10, "talent points not used by passives are free again")
	for _, sid in ipairs(h.skills) do check(h.sk[sid], "equipped skills are learned") end
end

-- a first-generation save without its version number (heroes keyed by class)
BigWowIdleDB = { gold = 3, heroes = { WARRIOR = { level = 20, xp = 0, tree = {}, skills = {},
	gear = { head = { s = "head", l = 18, q = 2 } } } }, party = { "WARRIOR", false, false, false, false } }
ns.InitDB()
check(ns.Heroes.Count() == 1 and ns.db.v == 7, "a save without a version number, heroes keyed by class, is read as the first version")
-- damaged values do not stop the load
BigWowIdleDB = { v = 6, faction = "PIRATES", heroes = { h1 = { spec = "MAGE_FIRE", level = 30, name = "외자" } }, party = { false, "h1", false, false, false } }
check(pcall(ns.InitDB) and ns.db.faction == nil and type(ns.db.heroes.h1.name) == "string", "an unknown faction with a one-word name loads")
BigWowIdleDB = { v = 6, heroes = { h1 = { spec = "MAGE_FIRE", level = 30, name = "가 나", tree = { abc = 2, [11] = 1 } } }, party = { false, "h1", false, false, false } }
check(pcall(ns.InitDB) and ns.db.heroes.h1.tree.abc == nil and ns.db.heroes.h1.tree[11] == 1, "a talent key that is not a number is dropped")
BigWowIdleDB = { v = 6, heroes = {}, party = true, stage = "x", gold = "lots" }
check(pcall(ns.InitDB) and type(ns.db.party) == "table" and ns.db.party[1] == false and ns.db.stage.idx == 1 and ns.db.gold == 0,
	"a party, stage or gold of the wrong kind takes the default")
-- the same hero twice in the party sits once
BigWowIdleDB = { v = 6, heroes = { h1 = { spec = "MAGE_FIRE", level = 30, name = "가 나" } }, party = { false, "h1", "h1", false, false } }
ns.InitDB()
do
	local n = 0
	for i = 1, ns.PARTY_SIZE do if ns.db.party[i] == "h1" then n = n + 1 end end
	check(n == 1, "a hero saved in two party slots keeps one")
	ns.db.party[3] = "h1"
	ns.Heroes.ValidateParty()
	n = 0
	for i = 1, ns.PARTY_SIZE do if ns.db.party[i] == "h1" then n = n + 1 end end
	check(n == 1, "party validation drops a repeated hero")
end
-- learned skill ranks stop at the top rank
BigWowIdleDB = { v = 6, heroes = { h1 = { spec = "MAGE_FIRE", level = 100, name = "가 나",
	sk = { [ns.SPECS.MAGE_FIRE.skills[1]] = 20 }, skills = { ns.SPECS.MAGE_FIRE.skills[1] } } }, party = { false, "h1", false, false, false } }
ns.InitDB()
check(ns.db.heroes.h1.sk[ns.SPECS.MAGE_FIRE.skills[1]] == ns.SKILL_MAX, "a saved skill rank above the top is brought down")
-- an old piece moved to a lower level keeps its stats inside the new range
BigWowIdleDB = { v = 4, heroes = {}, party = { false, false, false, false, false },
	bag = { { s = "head", l = 100, q = 5, a = { { "hp", 112345 } } } } }
ns.InitDB()
do
	local it = ns.db.bag[1]
	local lo, hi = ns.Items.AffixRange(it, "hp")
	check(it.l < 100 and lo and it.a[1][2] >= lo and it.a[1][2] <= hi, "migrated stats sit inside the range shown: " .. tostring(it.a[1][2]) .. " in " .. tostring(lo) .. "~" .. tostring(hi))
end
-- the first rune, at the middle of the map: 시작의 룬 with the hearthstone
-- (the other 전쟁의 룬 keeps its name)
check(ns.Runes.byId[1].name == "시작의 룬" and ns.Runes.byId[1].icon == "INV_Misc_Rune_01", "the first rune is 시작의 룬 with the hearthstone")
check(ns.Runes.byId[4031].name == "전쟁의 룬", "the other 전쟁의 룬 keeps its name")
-- a reset takes the runes' bonuses with it
BigWowIdleDB = { v = 6, heroes = {}, party = { false, false, false, false, false } }
ns.InitDB()
do
	local bag0, party0 = ns.BagSize(), ns.PartyLimit()
	for id, r in pairs(ns.Runes.byId) do
		if r.stat == "bag" or r.stat == "party" then ns.db.runes[id] = r.max or 1 end
	end
	ns.Runes.Invalidate()
	check(ns.BagSize() > bag0 or ns.PartyLimit() > party0, "the bag and party runes add room")
	ns.ResetDB()
	check(ns.BagSize() == bag0 and ns.PartyLimit() == party0, "after a reset the bag and party are back to their base size")
end
-- broken items are mended or set aside, never stop the game
BigWowIdleDB = { v = 6, heroes = { h1 = { spec = "MAGE_FIRE", level = 30, name = "가 나",
	gear = { head = { s = "chest", l = 20, q = 2 }, chest = { s = "nowhere", l = 5, q = 1 } } } },
	party = { false, "h1", false, false, false },
	bag = { { s = "head", l = "x", q = 99, a = { { "atk", 5 }, { "bogus", 3 }, "junk", { "hp", "lots" } }, g = "x", up = 50 },
		{ s = "nowhere", l = 10, q = 2 }, 17 } }
ns.InitDB()
do
	local d = ns.db
	local it
	for _, x in ipairs(d.bag) do if x.s == "head" then it = x end end
	check(it and it.q == ns.MAX_QUALITY and it.l == 1 and #it.a == 1 and it.g == nil and it.up == ns.Upgrade.MAX, "a broken item's values are put back in range")
	check(it and pcall(ns.Items.Tooltip, it) and pcall(ns.Items.Value, it), "a mended item shows and sells")
	check(d.setAside and #d.setAside == 2, "items of no known slot are set aside: " .. tostring(d.setAside and #d.setAside))
	local moved = false
	for _, x in ipairs(d.bag) do if x.s == "chest" then moved = true end end
	check(moved and d.heroes.h1.gear.head == nil, "a piece worn in the wrong slot goes back to the bag")
	check(ns.loadNote ~= nil, "the player is told what was mended")
	ns.loadNote = nil
end
BigWowIdleDB = { v = 6, heroes = {}, party = { false, false, false, false, false } }
ns.InitDB()
-- no recruiting before a side is chosen
ns.db.faction = nil
ns.db.gold = 1e9
check(not ns.Heroes.Create("MAGE_FIRE") and ns.Heroes.Count() == 0, "no hero is made before the faction is chosen")
ns.db.faction = "ALLIANCE"
check(ns.Heroes.Create("MAGE_FIRE") and ns.Heroes.Count() == 1, "with a faction the first hero is made")

if failures == 0 then print("  systems: all checks passed") end
return failures == 0
