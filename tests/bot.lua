-- A simple automatic player used by the balance run. It only calls the same
-- public functions the UI buttons call.
local ns = NS

local Bot = {}

-- Order in which the bot recruits after its starter: a healer second, then a
-- tank, then damage dealers. Entries the party has no room for are skipped.
Bot.recruit = { "PRIEST_HOLY", "WARRIOR_PROT", "MAGE_FIRE", "ROGUE_OUTLAW", "HUNTER_MM" }

function Bot.Start(starter, recruit)
	if recruit then Bot.recruit = recruit end
	ns.db.faction = ns.db.faction or "HORDE"
	ns.Heroes.Create(starter or "HUNTER_MM")
end

function Bot.SpendPoints(id)
	ns.Heroes.AutoSpend(id)
	ns.Heroes.AutoSkills(id)
end

-- Runes as a player would buy them: the cheapest open rune, or the next step
-- towards a rune worth heading for (party seats, skill slots, opening
-- chests), its whole way weighed against what it brings.
local GOAL = { party = 0.15, skillSlot = 0.2, openKind = 0.3, openAll = 0.3, auto1 = 0.3, auto2 = 0.3, auto3 = 0.3, waves = 0.4 }
local SLOW = { stash = 4, offGold = 4, offExp = 4, offlineOn = 4 }
local function buyRunes()
	local R = ns.Runes
	for _ = 1, 200 do
		local bestId, bestW
		for id, node in pairs(R.byId) do
			local cost = R.NextCost(id)
			if cost then
				if R.Available(id) then
					local w = cost * (SLOW[node.stat] or 1)
					if not bestW or w < bestW then bestId, bestW = id, w end
				end
				local f = GOAL[node.stat]
				if f then
					local step, total = R.NextStepTo(id)
					if step and total * f < (bestW or math.huge) then bestId, bestW = step, total * f end
				end
			end
		end
		if not bestId then return end
		local cost = R.NextCost(bestId)
		if not cost or ns.db.gold < cost then return end
		R.Buy(bestId)
	end
end

-- 강화 once the tower opens: steps moved onto newly worn pieces first (계승),
-- then the cheapest next step of the party's gear while the gold lasts
local function enhance()
	local U = ns.Upgrade
	if not (U and U.Open()) then return end
	local worn = {}
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id then
			for _, it in pairs(ns.db.heroes[id].gear) do worn[#worn + 1] = { it, id } end
		end
	end
	for _, w in ipairs(worn) do
		local src, srcHero = U.SourceFor(w[1])
		if src and U.CanMove(src, w[1]) then U.Move(src, w[1], srcHero, w[2]) end
	end
	for _ = 1, 60 do
		local best, bestHero, bestCost
		for _, w in ipairs(worn) do
			local n = U.Level(w[1])
			if n < U.MAX then
				local c = U.Cost(w[1], n)
				if not bestCost or c < bestCost then best, bestHero, bestCost = w[1], w[2], c end
			end
		end
		if not best or ns.db.gold < bestCost then return end
		U.Try(best, bestHero)
	end
end

local function recruit()
	if ns.Heroes.PartyCount() >= ns.PartyLimit() then return end
	local have = {}
	for _, h in pairs(ns.db.heroes) do have[h.spec] = true end
	for _, specId in ipairs(Bot.recruit) do
		if not have[specId] and ns.Heroes.FreeSlot(ns.SPECS[specId].role) then
			if ns.db.gold >= ns.Heroes.CreateCost() then
				ns.Heroes.Create(specId)
			end
			return
		end
	end
end

-- What a player does with the bag: fuse nine of a grade, kind and level
-- (the best level first, lower grades first so results can fuse again),
-- and when the bag is nearly full, break down gear of older levels and the
-- lowest grades first, keeping what can still be fused.
local function fodder(it)
	return not it.lock and not it.up and not ns.Items.HasSockets(it)
		and not ns.Items.PartyUpgrade(it) and not ns.Items.FutureUpgrade(it)
end

local function forge()
	local F = ns.Forge
	for _, op in ipairs(ns.FORGE_OPS) do
		if not F.Unlocked(op.key) and ns.db.forge.level >= op.level and ns.db.gold >= op.cost * 3 then
			F.Unlock(op.key)
		end
	end
	if not F.Unlocked("smelt") then return end
	do -- (Forge.Fuse says no while fusing is locked)
		for q = 1, ns.MAX_QUALITY - 1 do
			for _, cat in ipairs({ "gear", "accessory" }) do
				local groups, levels = {}, {}
				for _, it in ipairs(ns.db.bag) do
					if it.q == q and ns.Items.FuseCat(it) == cat and fodder(it) then
						if not groups[it.l] then groups[it.l] = {} levels[#levels + 1] = it.l end
						table.insert(groups[it.l], it)
					end
				end
				table.sort(levels, function(a, b) return a > b end)
				for _, l in ipairs(levels) do
					local list = groups[l]
					while #list >= F.FUSE_COUNT do
						local nine = {}
						for i = 1, F.FUSE_COUNT do nine[i] = table.remove(list) end
						if not F.Fuse(nine) then break end
					end
				end
			end
		end
	end
	if ns.Items.BagFree() < 10 then
		local top = ns.Items.SnapLevel(ns.Heroes.PartyTopLevel())
		-- (gear taken off with filled sockets too: it would clog the bag)
		local list = {}
		for _, it in ipairs(ns.db.bag) do
			if not it.lock and not it.up and not ns.Items.PartyUpgrade(it) and not ns.Items.FutureUpgrade(it) then
				list[#list + 1] = it
			end
		end
		-- older levels first, then the lowest grades
		table.sort(list, function(a, b)
			local oa, ob = a.l < top and 0 or 1, b.l < top and 0 or 1
			if oa ~= ob then return oa < ob end
			if a.q ~= b.q then return a.q < b.q end
			return a.l < b.l
		end)
		local out = {}
		local need = 20 - ns.Items.BagFree()
		for i = 1, math.min(need, #list) do out[i] = list[i] end
		if #out > 0 then F.Smelt(out, { manual = true }) end -- (the player's own pick)
	end
end

-- Fill every empty gem, enchant and rune socket on the party's gear with
-- the best material at hand, first making better materials out of nine.
local function sockets()
	local F = ns.Forge
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		local mk = ns.SOCKET[kind].mat
		for t = 1, ns.MAT_MAX_TIER[mk] - 1 do
			for _, id in ipairs(F.MatsAt(mk, t)) do
				while ns.MatCount(id) >= F.FUSE_COUNT and F.FuseMat(id) do end
			end
		end
	end
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id then
			for _, it in pairs(ns.db.heroes[id].gear) do
				for _, kind in ipairs(ns.SOCKET_KINDS) do
					local mk = ns.SOCKET[kind].mat
					while F.Unlocked(kind) and ns.Items.FreeSockets(it, kind) > 0 do
						local best
						for t = ns.MAT_MAX_TIER[mk], 1, -1 do
							for _, id in ipairs(F.MatsAt(mk, t)) do
								if not best and ns.MatCount(id) > 0 then best = id end
							end
							if best then break end
						end
						if not best or not F.Socket(it, kind, best, id) then break end
					end
				end
			end
		end
	end
end

function Bot.Tick()
	ns.Loot.OpenAll()
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id then
			ns.Items.AutoEquip(id)
			Bot.SpendPoints(id)
		end
	end
	forge()
	sockets()
	recruit()
	buyRunes()
	enhance()
	-- the endless tower once it opens: up from the floor after the best
	if ns.Tower and ns.Tower.Open() and not ns.db.tower.on then ns.Combat.EnterTower(ns.Tower.Top()) end
end

return Bot
