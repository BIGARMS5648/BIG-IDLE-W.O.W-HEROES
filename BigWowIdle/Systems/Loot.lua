-- Chests: dropping, storing, opening (manual or on the auto-open timer).
local _, ns = ...

local floor, max, min, random = math.floor, math.max, math.min, math.random
local U = ns.U

local Loot = {}
ns.Loot = Loot

------------------------------------------------------------------------
-- Rolling rewards
------------------------------------------------------------------------
-- weights: 8 numbers (one per quality). Higher difficulties and the luck
-- bonus push weight toward the better qualities.
function Loot.RollQuality(weights, diff)
	local shift = 1.4 ^ ((diff or 1) - 1) * (1 + ns.Bonus("luck") / 100)
	local w = {}
	for q = 1, ns.MAX_QUALITY do
		local v = weights[q] or 0
		if q > 2 and v > 0 then
			v = v * shift ^ (q - 2)
		end
		w[q] = v
	end
	return U.weightedIndex(w)
end

-- Gear from a chest is never above what the party's highest hero can wear:
-- its level is the stage's, but at most that hero's level + Items.REQ_GAP.
Loot.CAP = true
function Loot.GearLevel(level)
	if not Loot.CAP then return level end
	local top = ns.Heroes.PartyTopLevel()
	return min(level, top + ns.Items.REQ_GAP)
end

function Loot.RollGear(level, weights, diff, slot)
	level = Loot.GearLevel(level)
	slot = slot or ns.Items.RandomSlot(level)
	local q = Loot.RollQuality(weights, diff)
	local l = max(1, level - random(0, 2))
	return ns.Items.New(slot, l, q)
end

local function tierForLevel(level, breaks)
	local t = 1
	for i = 1, #breaks do
		if level >= breaks[i] then t = i + 1 end
	end
	return t
end

function Loot.CraftTier(level)
	return tierForLevel(level, { 15, 30, 50, 70 })
end

function Loot.SocketTier(level)
	return tierForLevel(level, { 12, 25, 40, 58, 78 })
end

-- Returns matId, count
function Loot.RollMaterial(level)
	local kinds = { { k = "bar", w = 22 }, { k = "leather", w = 20 }, { k = "cloth", w = 20 }, { k = "gem", w = 22 } }
	if level >= 15 then kinds[#kinds + 1] = { k = "dust", w = 12 } end
	if level >= 30 then kinds[#kinds + 1] = { k = "scroll", w = 6 } end
	local kind = U.weighted(kinds).k
	local tier
	if kind == "gem" or kind == "dust" or kind == "scroll" then
		tier = Loot.SocketTier(level)
	else
		tier = Loot.CraftTier(level)
	end
	-- a small chance of the neighbouring tiers
	local r = random()
	if r < 0.15 then tier = tier - 1 elseif r > 0.93 then tier = tier + 1 end
	tier = U.clamp(tier, 1, ns.MAT_MAX_TIER[kind])
	local n = (kind == "bar" or kind == "leather" or kind == "cloth") and random(1, 3) or 1
	return kind .. tier, n
end

function Loot.RollSeal(level)
	local tier = tierForLevel(level, { 30, 60, 85 })
	if tier > 1 and random() < 0.5 then tier = tier - 1 end
	return "seal" .. tier, 1
end

------------------------------------------------------------------------
-- Chest storage
------------------------------------------------------------------------
function Loot.Count(chestType)
	local n = 0
	local list = ns.db.chests
	for i = 1, #list do
		if not chestType or list[i].t == chestType then n = n + 1 end
	end
	return n
end

-- A chest dropped while its storage was full: counted, and the player is told
-- (at most once a minute per chest type) so it never vanishes unnoticed.
local lostWarned = {}
function Loot.Lost(chestType)
	local db = ns.db
	db.stat.lost = (db.stat.lost or 0) + 1
	local now = GetTime and GetTime() or 0
	if not lostWarned[chestType] or now - lostWarned[chestType] > 60 then
		lostWarned[chestType] = now
		ns.Toast(string.format("%s 보관함이 가득 차 새 상자를 받지 못했습니다. 상자를 여세요.", ns.N(ns.CHEST[chestType].name)))
	end
end

function Loot.AddChest(chestType, level, diff)
	if Loot.Count(chestType) >= ns.ChestCap(chestType) then
		return false
	end
	local list = ns.db.chests
	list[#list + 1] = { t = chestType, l = level, d = diff }
	ns.Fire("CHESTS")
	return true
end

-- Opens the chest at an index. Returns a result table, or nil + reason when
-- the reward does not fit in the bags.
local function openAt(index)
	local db = ns.db
	local ch = db.chests[index]
	if not ch then return nil end
	local def = ns.CHEST[ch.t]
	-- a chest needs a free bag slot whatever it turns out to hold, so a full
	-- bag cannot be used to fish for materials
	if ns.Items.BagFree() <= 0 and not (ns.Forge and ns.Forge.AutoSmelt()) then
		return nil, "full"
	end
	local kind = U.weighted({ { k = "gear", w = def.gear }, { k = "mat", w = def.mat }, { k = "seal", w = def.seal } }).k
	local result
	if kind == "gear" then
		local it = Loot.RollGear(ch.l, def.q, ch.d)
		ns.Items.AddToBag(it)
		result = { item = it }
	elseif kind == "mat" then
		local id, n = Loot.RollMaterial(ch.l)
		ns.AddMat(id, n)
		result = { mat = id, n = n }
	else
		local id, n = Loot.RollSeal(ch.l)
		ns.AddMat(id, n)
		result = { mat = id, n = n }
	end
	table.remove(db.chests, index)
	db.stat.chests = db.stat.chests + 1
	return result
end

-- Opens every stored chest (optionally of one type). Returns a summary:
--   { opened, items = { [quality] = n }, best = item, mats = { [id] = n }, full }
function Loot.OpenAll(chestType)
	local db = ns.db
	local sum = { opened = 0, items = {}, mats = {}, full = false }
	local i = 1
	while i <= #db.chests do
		local ch = db.chests[i]
		if not chestType or ch.t == chestType then
			local r, why = openAt(i)
			if r then
				sum.opened = sum.opened + 1
				if r.item then
					local q = r.item.q
					sum.items[q] = (sum.items[q] or 0) + 1
					if not sum.best or q > sum.best.q then sum.best = r.item end
				else
					sum.mats[r.mat] = (sum.mats[r.mat] or 0) + r.n
				end
			elseif why == "full" then
				sum.full = true
				break
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	if sum.opened > 0 then
		ns.Fire("CHESTS")
		ns.Fire("BAG")
		ns.Sound("loot")
		Loot.Announce(sum)
	elseif sum.full then
		ns.Toast("가방이 가득 차 상자를 열 수 없습니다.")
	end
	return sum
end

function Loot.Announce(sum)
	local parts = {}
	for q = ns.MAX_QUALITY, 1, -1 do
		if sum.items[q] then
			parts[#parts + 1] = U.col(ns.QUALITY[q].hex, ns.N(ns.QUALITY[q].name) .. " x" .. sum.items[q])
		end
	end
	local matCount = 0
	for _, n in pairs(sum.mats) do
		matCount = matCount + n
	end
	if matCount > 0 then
		parts[#parts + 1] = "재료 x" .. matCount
	end
	local msg = string.format("상자 %d개 개봉: %s", sum.opened, table.concat(parts, ", "))
	if sum.full then
		msg = msg .. " " .. U.col("ff4040", "(가방 가득 참)")
	end
	if sum.best and sum.best.q >= 5 then
		ns.Toast(msg)
		if sum.best.q >= 6 then
			-- only the really rare finds go to the chat window
			ns.Print(string.format("획득: %s", ns.Items.ColorName(sum.best)))
		end
	else
		ns.Log(msg)
		ns.Fire("TOAST", msg)
	end
end

------------------------------------------------------------------------
-- Auto-open (unlocked by a rune): each chest type has its own timer.
------------------------------------------------------------------------
function Loot.AutoInterval(chestType)
	return max(30, ns.CHEST[chestType].auto * (1 - min(80, ns.Bonus("autoCd")) / 100))
end

function Loot.Tick(dt)
	if ns.Bonus("autoOpen") <= 0 then return end
	local db = ns.db
	for t = 1, #ns.CHEST do
		db.autoT[t] = (db.autoT[t] or 0) + dt
		if db.autoT[t] >= Loot.AutoInterval(t) then
			db.autoT[t] = 0
			if Loot.Count(t) > 0 then
				Loot.OpenAll(t)
			end
		end
	end
end
