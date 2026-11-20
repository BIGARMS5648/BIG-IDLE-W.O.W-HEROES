-- Map page: difficulty, act and stage selection plus the progression options.
local _, ns = ...

local UI, U = ns.UI, ns.U
local Main = ns.Main

local function bossSkillText(sk)
	local ko = ns.lang == "ko"
	if sk.kind == "smash" then
		return string.format(ko and "강타 (피해 x%s)" or "Smash (x%s damage)", U.num(sk.mult, 1))
	elseif sk.kind == "aoe" then
		local school = ns.N(ns.SCHOOL[sk.school or "phys"].name)
		return string.format(ko and "파티 전체 %s 공격" or "Party-wide %s attack", school)
	elseif sk.kind == "summon" then
		local name = ns.N(ns.MONSTERS[sk.mob].name)
		if ko then return string.format("%s %d마리 소환", name, sk.n) end
		return string.format("Summons %d x %s", sk.n, name)
	elseif sk.kind == "enrage" then
		return string.format(ko and "생명력 %d%% 이하에서 격노" or "Enrages below %d%% health", sk.hp * 100)
	elseif sk.kind == "shield" then
		if ko then return string.format("%d초 동안 받는 피해 %d%% 감소", sk.dur, sk.dr) end
		return string.format("Shield: %d%% less damage for %d sec", sk.dr, sk.dur)
	end
	return sk.kind
end

local function stageInfo(diff, idx)
	local T = ns.T
	local stg = ns.STAGES[idx]
	local level = ns.StageLevel(diff, idx)
	local lines = {}
	local waves = stg.raid and 4 or ns.WAVES
	lines[#lines + 1] = U.col("ffd100", ns.StageLabel(diff, idx)) .. "  " .. U.col(ns.DIFFS[diff].hex, ns.N(ns.DIFFS[diff].name)) ..
		"  Lv " .. level .. "  ·  " .. string.format(T("웨이브 %d개, 웨이브당 몬스터 %d마리", "%d waves, %d monsters per wave"), waves, ns.MobsPerWave(diff, idx))
	local names = {}
	for _, e in ipairs(stg.mobs) do
		local m = ns.MONSTERS[e[1]]
		local s = ns.N(m.name) .. " (" .. ns.N(ns.MTYPE[m.type])
		if m.school ~= "phys" then s = s .. ", " .. U.col(ns.SCHOOL[m.school].hex, ns.N(ns.SCHOOL[m.school].name)) end
		if m.range then s = s .. ", " .. T("원거리", "ranged") end
		names[#names + 1] = s .. ")"
	end
	lines[#lines + 1] = T("몬스터: ", "Monsters: ") .. table.concat(names, ", ")
	local b = stg.boss
	local skills = {}
	for _, sk in ipairs(b.skills) do skills[#skills + 1] = bossSkillText(sk) end
	lines[#lines + 1] = (stg.raid and T("공격대 우두머리: ", "Raid boss: ") or T("우두머리: ", "Boss: ")) .. U.col("ff8040", ns.N(b.name)) ..
		" (" .. ns.N(ns.MTYPE[b.type]) .. ")  -  " .. table.concat(skills, ", ")
	local chest = stg.raid and ns.CHEST[3] or ns.CHEST[2]
	lines[#lines + 1] = T("보상: ", "Rewards: ") .. ns.N(ns.CHEST[1].name) .. T(" (몬스터), ", " (monsters), ") .. ns.N(chest.name) .. T(" (우두머리)", " (boss)") ..
		"  ·  " .. string.format(T("장비 레벨 %d~%d", "item levels %d-%d"), math.max(1, level - 2), level)
	return table.concat(lines, "\n")
end

local function build(page)
	local T = ns.T
	page.diff = ns.db.stage.diff
	page.act = ns.StageAct(ns.db.stage.idx)
	page.idx = ns.db.stage.idx

	page.diffs = {}
	for d = 1, #ns.DIFFS do
		local b = UI.Button(page, 118, 24, "", function()
			page.diff = d
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", (d - 1) * 122, 0)
		UI.Tip(b, function()
			local lines = { { ns.N(ns.DIFFS[d].name), nil, U.rgb(ns.DIFFS[d].hex) } }
			lines[#lines + 1] = { string.format(ns.T("스테이지 레벨 %d ~ %d", "Stage levels %d - %d"), ns.StageLevel(d, 1), ns.StageLevel(d, ns.STAGE_COUNT)), nil, 1, 1, 1 }
			lines[#lines + 1] = { ns.T("난이도가 높을수록 몬스터가 많아지고 높은 등급 장비가 잘 나옵니다.", "Higher difficulties field more monsters and drop better quality gear."), nil, 0.8, 0.8, 0.8 }
			if d > 1 and (ns.db.prog[d - 1] or 0) < ns.STAGE_COUNT then
				lines[#lines + 1] = { string.format(ns.T("%s 난이도를 모두 공략하면 열립니다.", "Clear all of %s to unlock."), ns.N(ns.DIFFS[d - 1].name)), nil, 1, 0.3, 0.3 }
			end
			return lines
		end, "TOP")
		page.diffs[d] = b
	end
	page.rate = UI.Text(page, 10)
	page.rate:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -298)
	page.rate:SetJustifyH("RIGHT")
	page.rate:SetTextColor(0.75, 0.75, 0.75)

	page.acts = {}
	for a = 1, #ns.ACTS do
		local b = UI.Button(page, 180, 22, "", function()
			page.act = a
			Main.Refresh()
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", (a - 1) * 184, -32)
		page.acts[a] = b
	end

	page.stages = {}
	for n = 1, ns.STAGES_PER_ACT do
		local b = UI.Button(page, 141, 60, "", function(self)
			page.idx = self.idx
			Main.Refresh()
		end)
		local col, row = (n - 1) % 5, math.floor((n - 1) / 5)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", col * 146, -62 - row * 65)
		b.clickWhenOff = true
		b.label:SetWidth(137)
		page.stages[n] = b
	end

	page.info = UI.Text(page, 11)
	page.info:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -200)
	page.info:SetWidth(Main.PAGE_W)
	page.info:SetJustifyV("TOP")

	page.go = UI.Button(page, 190, 26, T("이 스테이지로 이동", "Travel to this stage"), function()
		UI.Try(ns.Combat.Travel(page.diff, page.idx))
		Main.Refresh()
	end)
	page.go:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -318)
	page.goHint = UI.Text(page, 10)
	page.goHint:SetPoint("LEFT", page.go, "RIGHT", 10, 0)
	page.goHint:SetTextColor(0.7, 0.7, 0.7)

	local opt = ns.db.opt
	page.checks = {
		UI.Check(page, T("자동 진행: 스테이지를 깨면 다음 스테이지로 이동", "Auto-advance: move on after every clear"),
			function() return ns.db.opt.auto end, function(v) ns.db.opt.auto = v if v then ns.db.retry = 0 end ns.Fire("OPTIONS") end),
		UI.Check(page, T("전멸하면 이전 스테이지로 물러나기", "Fall back one stage after a wipe"),
			function() return ns.db.opt.retreat end, function(v) ns.db.opt.retreat = v end),
		UI.Check(page, T("물러난 뒤 8번 깨면 자동으로 재도전 (끄면 자동 진행이 꺼짐)", "Retry automatically after 8 clears (otherwise auto-advance turns off)"),
			function() return ns.db.opt.retry end, function(v) ns.db.opt.retry = v end),
	}
	for i, c in ipairs(page.checks) do
		c:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -360 - (i - 1) * 24)
	end
	page.note = UI.Text(page, 10, T("경험치는 영웅 레벨과 스테이지 레벨이 비슷할 때 가장 많이 들어옵니다. 가장 높은 스테이지가 항상 가장 효율적인 것은 아닙니다 - 빠르게 깰 수 있는 곳이 더 벌이가 좋을 때가 많습니다.",
		"Experience is best when hero and stage levels are close. The highest stage is not always the most efficient - one you clear quickly often pays more."))
	page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -438)
	page.note:SetWidth(Main.PAGE_W)
	page.note:SetTextColor(0.7, 0.7, 0.7)
end

local function refresh(page)
	local T = ns.T
	local db = ns.db
	for d, b in ipairs(page.diffs) do
		local open = d == 1 or (db.prog[d - 1] or 0) >= ns.STAGE_COUNT
		b:SetLabel(ns.N(ns.DIFFS[d].name) .. "  " .. (db.prog[d] or 0) .. "/" .. ns.STAGE_COUNT)
		b:SetOn(d == page.diff)
		b:SetTextRGB(open and 1 or 0.5, open and 0.9 or 0.5, open and 0.6 or 0.5)
	end
	for a, b in ipairs(page.acts) do
		b:SetLabel(string.format(T("%d막 %s", "Act %d: %s"), a, ns.N(ns.ACTS[a].name)))
		b:SetOn(a == page.act)
	end
	local selAct = ns.StageAct(page.idx)
	if selAct ~= page.act then
		page.idx = (page.act - 1) * ns.STAGES_PER_ACT + 1
	end
	for n, b in ipairs(page.stages) do
		local idx = (page.act - 1) * ns.STAGES_PER_ACT + n
		b.idx = idx
		local cleared = (db.prog[page.diff] or 0) >= idx
		local reachable = ns.Combat.CanTravel(page.diff, idx)
		local here = db.stage.diff == page.diff and db.stage.idx == idx
		local state
		if here then
			state = U.col("40ff40", T("진행 중", "Here"))
		elseif cleared then
			state = U.col("a0a0a0", T("공략 완료", "Cleared"))
		elseif reachable then
			state = U.col("ffd100", T("도전 가능", "Open"))
		else
			state = U.col("804040", T("잠김", "Locked"))
		end
		local name = ns.N(ns.STAGES[idx].name)
		if ns.STAGES[idx].raid then name = U.col("ff8000", name) end
		b:SetLabel(page.act .. "-" .. n .. " " .. name .. "\nLv " .. ns.StageLevel(page.diff, idx) .. "\n" .. state)
		b:SetOn(idx == page.idx)
		b:SetOff(not reachable)
	end
	page.info:SetText(stageInfo(page.diff, page.idx))
	local can = ns.Combat.CanTravel(page.diff, page.idx)
	page.go:SetOff(not can)
	page.goHint:SetText(can and T("이동하면 그 스테이지의 1웨이브부터 다시 시작합니다.", "Travelling restarts that stage from wave 1.") or T("아직 열리지 않은 스테이지입니다.", "This stage is not unlocked yet."))
	for _, c in ipairs(page.checks) do c:Refresh() end
	local r = db.rate
	if (r.gold or 0) > 0 then
		page.rate:SetText(string.format(T("최근 수입: 시간당 %s 골드 · 경험치 %s", "Recent income: %s gold/h - %s xp/h"), U.fmt(r.gold * 3600), U.fmt(r.xp * 3600)))
	else
		page.rate:SetText("")
	end
end

Main.RegisterTab({
	key = "map", title = { "지도", "Map" }, build = build, refresh = refresh,
	events = { "STAGE", "PROGRESS", "RESULT", "OPTIONS", "RESET" },
})
