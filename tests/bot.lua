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

local function buyRunes()
	-- party slots first, then whatever is cheapest
	for _ = 1, 50 do
		local bestId, bestCost
		for id, node in pairs(ns.Runes.byId) do
			if ns.Runes.Available(id) then
				local cost = ns.Runes.NextCost(id)
				if cost then
					local weight = cost
					if node.stat == "party" then weight = cost * 0.2 end
					if node.stat == "bank" or node.stat == "offline" or node.stat == "offlineCap" then weight = cost * 4 end
					if not bestCost or weight < bestCost then
						bestId, bestCost = id, weight
					end
				end
			end
		end
		if not bestId then return end
		local cost = ns.Runes.NextCost(bestId)
		if ns.db.gold < cost then return end
		ns.Runes.Buy(bestId)
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
		if #out > 0 then F.Smelt(out) end
	end
end

-- Fill every empty gem, enchant and rune socket on the party's gear with
-- the best material at hand, first making better materials out of nine.
local function sockets()
	local F = ns.Forge
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		local mk = ns.SOCKET[kind].mat
		for t = 1, ns.MAT_MAX_TIER[mk] - 1 do
			while ns.MatCount(mk .. t) >= F.FUSE_COUNT and F.FuseMat(mk .. t) do end
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
							if ns.MatCount(mk .. t) > 0 then best = mk .. t break end
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
end

return Bot
