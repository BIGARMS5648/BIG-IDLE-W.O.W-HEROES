-- Chests: dropping, storing, opening (manual or on the auto-open timer).
local _, ns = ...

local floor, max, min, random = math.floor, math.max, math.min, math.random
local U = ns.U

local Loot = {}
ns.Loot = Loot

------------------------------------------------------------------------
-- TBH boxes (Data/TBH.lua): each opening rolls one reward by weight
------------------------------------------------------------------------
local ARMOR = { "head", "chest", "hands", "feet" }
local CRAFT = { "bar", "leather", "cloth" }

-- The box of a kind ("monster", "boss", "act") for a level: the one of
-- the highest level at or below it (a chest kept from before boxes).
function Loot.BoxFor(kind, level)
	local best, bestLv
	for key, b in pairs(ns.TBH.BOXES) do
		if b.kind == kind and b.lv <= (level or 1) and (not bestLv or b.lv > bestLv or (b.lv == bestLv and key < best)) then
			best, bestLv = key, b.lv
		end
	end
	if best then return best end
	for key, b in pairs(ns.TBH.BOXES) do
		if b.kind == kind and (not bestLv or b.lv < bestLv) then best, bestLv = key, b.lv end
	end
	return best
end

-- The lowest and highest item level of the gear a box can hold.
function Loot.BoxLevels(key)
	local lo, hi
	for _, e in ipairs(ns.TBH.BOXES[key].e) do
		if e[1] == "gear" then
			lo, hi = math.min(lo or e[4], e[4]), math.max(hi or e[4], e[4])
		end
	end
	return lo or 1, hi or 1
end

-- A material of a TBH kind and grade as ours: 장식 → gem, 세공 → dust,
-- 각인 → scroll (one of that kind and grade, evenly, as TBH's "<grade>
-- Material" groups hold every one of them), crafting → bar / leather /
-- cloth, coins and soulstones → seals (their tier by their number).
function Loot.MatFor(kind, grade)
	if kind == "seal" or kind == "soul" then
		local tier = kind == "soul" and grade or math.ceil(grade / 2.5)
		return "seal" .. U.clamp(tier, 1, ns.MAT_MAX_TIER.seal), 1
	end
	local by = ns.SOCKET_MATS_BY[kind]
	if by then
		local g = U.clamp(grade, 1, ns.MAT_MAX_TIER[kind])
		while g > 1 and not by[g] do g = g - 1 end
		local list = by[g]
		return list[random(#list)], 1
	end
	local k = kind == "craft" and CRAFT[random(#CRAFT)] or kind
	local n = kind == "craft" and random(1, 3) or 1
	return k .. U.clamp(grade, 1, ns.MAT_MAX_TIER[k]), n
end

-- One opening of a box: an item (its family's slot, the grade and level of
-- the entry) or a material. Returns { item = it } or { mat = id, n = n }.
-- level: the gear's item level instead of the entry's (the tower's chests);
-- luck: better grades weighed up more (times this per grade above 2).
function Loot.RollBox(key, level, luck)
	local b = ns.TBH.BOXES[key]
	-- the luck bonus weighs gear of the better grades up (more the better)
	luck = (1 + ns.Bonus("luck") / 100) * (luck or 1)
	local list = {}
	for _, e in ipairs(b.e) do
		local w = e[#e]
		if e[1] == "gear" and e[3] > 2 then w = w * luck ^ (e[3] - 2) end
		list[#list + 1] = { e = e, w = w }
	end
	local e = U.weighted(list).e
	if e[1] == "gear" then
		local fam = e[2]
		local slot = fam == "armor" and ARMOR[random(#ARMOR)] or (fam == "weapon" and "mh") or (fam == "offhand" and "oh") or fam
		return { item = ns.Items.New(slot, level or e[4], e[3]) }
	end
	local id, n = Loot.MatFor(e[2], e[3])
	return { mat = id, n = n }
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
function Loot.Lost(chestType, quiet)
	local db = ns.db
	db.stat.lost = (db.stat.lost or 0) + 1
	if quiet then return end
	local now = GetTime and GetTime() or 0
	if not lostWarned[chestType] or now - lostWarned[chestType] > 60 then
		lostWarned[chestType] = now
		ns.Toast(string.format("%s 보관함이 가득 차 새 상자를 받지 못했습니다. 상자를 여세요.", ns.N(ns.CHEST[chestType].name)))
	end
end

-- towerFloor: a chest of the endless tower (its gear of the tower's item
-- level, the better grades by the floor).
function Loot.AddChest(chestType, level, diff, box, towerFloor)
	if Loot.Count(chestType) >= ns.ChestCap(chestType) then
		return false
	end
	local list = ns.db.chests
	list[#list + 1] = { t = chestType, l = level, d = diff, box = box, tf = towerFloor }
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
	-- its TBH box (a chest kept from before: the box of its kind and level)
	local box = ch.box and ns.TBH.BOXES[ch.box] and ch.box or Loot.BoxFor(def.box, ch.l)
	local tf = tonumber(ch.tf)
	local result = tf and Loot.RollBox(box, ns.Tower.ITEM_LEVEL, ns.Tower.Luck(tf)) or Loot.RollBox(box)
	if result.item then
		ns.Items.AddToBag(result.item)
	else
		ns.AddMat(result.mat, result.n)
	end
	table.remove(db.chests, index)
	db.stat.chests = db.stat.chests + 1
	return result
end

-- Opens every stored chest (optionally of one type). Returns a summary:
--   { opened, items = { [quality] = n }, best = item, mats = { [id] = n }, full }
function Loot.OpenAll(chestType, limit)
	local db = ns.db
	local sum = { opened = 0, items = {}, mats = {}, full = false }
	local i = 1
	while i <= #db.chests and (not limit or sum.opened < limit) do
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

-- Opening by hand: a click opens one chest; with its runes a right-click
-- opens every chest of the kind and a Shift+click every chest there is.
-- how: "one" | "kind" | "all"; chestType nil = any kind.
function Loot.CanOpen(how)
	if how == "kind" then return ns.Bonus("openKind") > 0 end
	if how == "all" then return ns.Bonus("openAll") > 0 end
	return true
end

function Loot.OpenByHand(chestType, how)
	if how == "all" and Loot.CanOpen("all") then return Loot.OpenAll() end
	if how == "kind" and Loot.CanOpen("kind") then return Loot.OpenAll(chestType) end
	return Loot.OpenAll(chestType, 1)
end

------------------------------------------------------------------------
-- Auto-open: each chest kind has its own rune (which sets the wait) and
-- timer; more runes cut the wait.
------------------------------------------------------------------------
function Loot.AutoOn(chestType)
	return ns.Bonus("auto" .. chestType) > 0
end

function Loot.AutoInterval(chestType)
	local wait = ns.Bonus("auto" .. chestType) - ns.Bonus("autoCut" .. chestType)
	return max(10, wait * (1 - min(80, ns.Bonus("autoCd")) / 100))
end

function Loot.Tick(dt)
	local db = ns.db
	for t = 1, #ns.CHEST do
		if not Loot.AutoOn(t) then
			db.autoT[t] = 0
		else
		db.autoT[t] = (db.autoT[t] or 0) + dt
		if db.autoT[t] >= Loot.AutoInterval(t) then
			db.autoT[t] = 0
			if Loot.Count(t) > 0 then
				Loot.OpenAll(t)
			end
		end
		end
	end
end
