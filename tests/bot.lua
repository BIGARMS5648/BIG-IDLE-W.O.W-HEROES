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

local function forge()
	local F = ns.Forge
	for _, op in ipairs(ns.FORGE_OPS) do
		if not F.Unlocked(op.key) and ns.db.forge.level >= op.level and ns.db.gold >= op.cost * 3 then
			F.Unlock(op.key)
		end
	end
	if not F.Unlocked("smelt") then return end
	-- fuse what can be fused, smelt the rest
	for q = 1, ns.MAX_QUALITY - 1 do
		for _, cat in ipairs({ "gear", "accessory" }) do
			local list = F.PickForFusion(q, cat)
			if list and q <= 3 and ns.Items.BagFree() < 6 then
				F.Fuse(list)
			end
		end
	end
	if ns.Items.BagFree() < 6 then
		F.Smelt(F.PickByQuality(ns.MAX_QUALITY))
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
	recruit()
	buyRunes()
end

return Bot
