-- The Titan Forge: eight operations that consume and transform items.
-- Everything the forge consumes (smelting, fusion, crafting, bonus rolls)
-- feeds forge experience; socketing and extraction do not.
local _, ns = ...

local floor, max, min, random = math.floor, math.max, math.min, math.random
local U = ns.U

local Forge = {}
ns.Forge = Forge

Forge.FUSE_COUNT = 9

-- Fusion odds by input quality: { resultQuality, weight }.
-- From Epic upward a fusion can fail and return the same quality.
-- Fusion of nine of a grade: the grade it gives, by weight (TBH's
-- synthesis: two grades lower .. two grades higher, ns.QUALITY[q].fuse).
Forge.FUSE_ODDS = {}
for q = 1, ns.MAX_QUALITY - 1 do
	local odds, total = {}, 0
	for d = -2, 2 do
		local w = ns.QUALITY[q].fuse[d + 3] or 0
		if w > 0 and q + d >= 1 and q + d <= ns.MAX_QUALITY then
			odds[#odds + 1] = { q + d, w }
			total = total + w
		end
	end
	for _, o in ipairs(odds) do o[2] = o[2] / total * 100 end
	Forge.FUSE_ODDS[q] = odds
end

------------------------------------------------------------------------
-- Level and operations
------------------------------------------------------------------------
function Forge.Need(level)
	return floor(50 * level ^ 2.2)
end

function Forge.AddXP(n)
	local f = ns.db.forge
	if f.level >= ns.FORGE_MAX then return end
	f.xp = f.xp + n * (1 + ns.Bonus("forgeExp") / 100)
	local leveled = false
	while f.level < ns.FORGE_MAX and f.xp >= Forge.Need(f.level) do
		f.xp = f.xp - Forge.Need(f.level)
		f.level = f.level + 1
		leveled = true
	end
	if leveled then
		ns.Toast(string.format("티탄 대장간 %d레벨 달성!", f.level))
	end
	ns.Fire("FORGE")
end

function Forge.OpDef(op)
	for _, d in ipairs(ns.FORGE_OPS) do
		if d.key == op then return d end
	end
end

function Forge.Unlocked(op)
	return ns.db.forge.ops[op] == true
end

function Forge.Unlock(op)
	local d = Forge.OpDef(op)
	if not d or Forge.Unlocked(op) then return false end
	if ns.db.forge.level < d.level then
		return false, string.format("대장간 %d레벨이 필요합니다.", d.level)
	end
	if not ns.SpendGold(d.cost) then
		return false, "골드가 부족합니다."
	end
	ns.db.forge.ops[op] = true
	ns.Fire("FORGE")
	return true
end

local function needOp(op)
	if Forge.Unlocked(op) then return true end
	return false, string.format("'%s' 기능이 아직 잠겨 있습니다.", ns.N(Forge.OpDef(op).name))
end

-- Items near the forge's own level are worth the most experience.
function Forge.ItemXP(it)
	local _, fxp = ns.Items.Value(it)
	local gap = (it.l - ns.db.forge.level) / 15
	return fxp * max(0.1, 1 / (1 + gap * gap))
end

------------------------------------------------------------------------
-- Smelt: items -> gold + forge experience
------------------------------------------------------------------------
-- items: array of item tables that are currently in the bag. Every piece
-- is checked again here: a protected one is never broken down, and an
-- enhanced, socketed or still useful one only when opts.manual (the player
-- picked that one piece and confirmed). opts.checked: the caller picked the
-- list this very moment with the same rules (skips the slow checks).
function Forge.Smelt(items, opts)
	local ok, why = needOp("smelt")
	if not ok then return false, why end
	opts = opts or {}
	local gold, xp, n = 0, 0, 0
	local done, keptWhy = {}, nil
	for i = 1, #items do
		local it = items[i]
		local idx = ns.Items.IndexInBag(it)
		local why2 = idx and not done[it] and (it.lock and "보호한 장비입니다." or (not opts.checked and ns.Items.KeepReason(it, opts.manual)))
		if why2 then keptWhy = why2 idx = nil end
		if idx and not done[it] then
			done[it] = true
			local g = ns.Items.Value(items[i])
			gold = gold + g
			xp = xp + Forge.ItemXP(items[i])
			table.remove(ns.db.bag, idx)
			n = n + 1
		end
	end
	if n == 0 then return false, keptWhy or "분해할 아이템이 없습니다." end
	gold = floor(gold * (1 + ns.Bonus("smeltGold") / 100))
	ns.AddGold(gold)
	Forge.AddXP(xp)
	ns.Fire("BAG")
	return true, gold, n
end

-- Every bag item at or below a quality that is safe to break down: not
-- protected, without gems, and not an upgrade for anyone in the party.
-- Also returns how many matching items were kept back as upgrades.
function Forge.PickByQuality(maxQuality)
	local out, kept = {}, 0
	local heroes = ns.Items.KeptHeroes()
	for _, it in ipairs(ns.db.bag) do
		if not it.lock and not it.up and it.q <= maxQuality and not ns.Items.HasSockets(it) then
			if ns.Items.PartyUpgrade(it, heroes) or ns.Items.FutureUpgrade(it, heroes) then
				kept = kept + 1
			else
				out[#out + 1] = it
			end
		end
	end
	return out, kept
end

-- Gold for breaking down n of a material, bonuses included.
function Forge.MatSmeltGold(id, n)
	local gold = ns.MatValue(id)
	return floor(gold * (n or 1) * (1 + ns.Bonus("smeltGold") / 100))
end

function Forge.SmeltMat(id, n)
	local ok, why = needOp("smelt")
	if not ok then return false, why end
	n = min(n, ns.MatCount(id))
	if n <= 0 then return false end
	local _, fxp = ns.MatValue(id)
	local gold = Forge.MatSmeltGold(id, n)
	ns.AddMat(id, -n)
	ns.AddGold(gold)
	Forge.AddXP(fxp * n)
	return true, gold, n
end

-- Called when a chest reward does not fit. Returns true if space was made.
function Forge.AutoSmelt()
	local q = ns.db.opt.autoSmelt or 0
	if q <= 0 or not Forge.Unlocked("smelt") then return false end
	local list = Forge.PickByQuality(q)
	if #list == 0 then return false end
	local ok, gold, n = Forge.Smelt(list, { checked = true })
	if ok then
		ns.Log(string.format("자동 분해: %d개 → %s 골드", n, U.fmt(gold)))
	end
	return ok and ns.Items.BagFree() > 0
end

------------------------------------------------------------------------
-- Fusion: 9 of a quality -> 1 (usually) better
------------------------------------------------------------------------
-- Fusion by itself (ns.db.opt.autoFuse: the lowest grade it fuses, 0 =
-- off): after chests are opened, and when one's reward does not fit, every
-- nine of a grade from that one up are fused, the lower grades first (so a
-- result can join the next grade's nine), weapons and armour apart from
-- accessories. What fusion keeps out (protected, enhanced, socketed, better
-- for a hero now) stays. Returns how many fusions were made.
Forge.AUTO_FUSE_MAX = 200 -- fusions at most each time
local FUSE_CATS = { "gear", "accessory" }
-- Every nine of a grade from q0 up, the lower grades first (일괄 융합 and
-- 자동 융합). Returns how many fusions were made.
function Forge.FuseFrom(q0)
	local n = 0
	for q = q0, ns.MAX_QUALITY - 1 do
		for _, cat in ipairs(FUSE_CATS) do
			while n < Forge.AUTO_FUSE_MAX do
				local list = Forge.PickForFusion(q, cat)
				if not list or not Forge.Fuse(list) then break end
				n = n + 1
			end
		end
	end
	return n
end
-- How many fusions the bag holds now from grade q0 up (nine usable pieces
-- of a grade and kind each; what they give is not counted).
function Forge.FusionsFrom(q0)
	local count = {}
	for _, it in ipairs(ns.db.bag) do
		if it.q >= q0 and it.q < ns.MAX_QUALITY and not Forge.FuseBlock(it) then
			local k = it.q .. ns.Items.FuseCat(it)
			count[k] = (count[k] or 0) + 1
		end
	end
	local n = 0
	for _, c in pairs(count) do n = n + floor(c / Forge.FUSE_COUNT) end
	return n
end
function Forge.AutoFuse()
	local q0 = ns.db.opt.autoFuse or 0
	if q0 <= 0 then return 0 end
	local n = Forge.FuseFrom(q0)
	if n > 0 then ns.Log(string.format("자동 융합: %d번", n)) end
	return n
end

function Forge.CanFuse(items)
	if #items ~= Forge.FUSE_COUNT then
		return false, string.format("같은 등급 장비 %d개가 필요합니다.", Forge.FUSE_COUNT)
	end
	local q, cat = items[1].q, ns.Items.FuseCat(items[1])
	if q >= ns.MAX_QUALITY then
		return false, "최고 등급은 융합할 수 없습니다."
	end
	for i = 2, #items do
		if items[i].q ~= q then
			return false, "등급이 모두 같아야 합니다."
		end
		if ns.Items.FuseCat(items[i]) ~= cat then
			return false, "무기/방어구와 장신구류는 섞을 수 없습니다."
		end
	end
	return true
end

function Forge.Fuse(items)
	local ok, why = Forge.CanFuse(items)
	if not ok then return false, why end
	-- every piece again, right before it goes: in the bag, once only, and
	-- nothing that must be kept
	local seen = {}
	for i = 1, #items do
		local it = items[i]
		if seen[it] then return false, "같은 장비가 두 번 들어 있습니다." end
		seen[it] = true
		local block = Forge.FuseBlock(it)
		if block then return false, block end
	end
	local q, cat = items[1].q, ns.Items.FuseCat(items[1])
	local levelSum, xp = 0, 0
	for i = 1, #items do
		if not ns.Items.IndexInBag(items[i]) then
			return false, "가방에 없는 아이템이 있습니다."
		end
		levelSum = levelSum + items[i].l
		xp = xp + Forge.ItemXP(items[i])
	end
	for i = 1, #items do
		table.remove(ns.db.bag, ns.Items.IndexInBag(items[i]))
	end
	local pick = U.weighted(Forge.FUSE_ODDS[q], 2)
	local level = U.clamp(floor(levelSum / #items + 0.5), 1, ns.HERO_MAX_LEVEL)
	local it = ns.Items.New(ns.Items.RandomSlot(level, cat), level, pick[1])
	ns.Items.AddToBag(it)
	Forge.AddXP(xp)
	ns.Fire("BAG")
	local outcome = "up"
	if pick[1] == q then outcome = "same" elseif pick[1] >= q + 2 then outcome = "great" end
	return true, it, outcome
end

-- Nine unlocked bag items of a quality / category, lowest level first.
-- Why a bag item is kept out of fusion, or nil when it can be fused. The
-- fusion screen counts and marks items with this too.
function Forge.FuseBlock(it)
	if it.lock then return "보호한 장비는 쓰지 않습니다." end
	if it.up then return "강화한 장비는 쓰지 않습니다." end
	if ns.Items.HasSockets(it) then return "보석·마법부여·주문각인이 붙은 장비는 쓰지 않습니다." end
	local heroes = ns.Items.KeptHeroes()
	if ns.Items.PartyUpgrade(it, heroes) then return "영웅에게 더 좋은 장비라 쓰지 않습니다." end
	-- (gear a hero will wear at a higher level is fused like any other; only
	-- breaking down keeps it, Items.KeepReason)
	return nil
end

function Forge.PickForFusion(quality, cat)
	local pool = {}
	for _, it in ipairs(ns.db.bag) do
		if it.q == quality and ns.Items.FuseCat(it) == cat and not Forge.FuseBlock(it) then
			pool[#pool + 1] = it
		end
	end
	if #pool < Forge.FUSE_COUNT then return nil end
	table.sort(pool, function(a, b) return a.l < b.l end)
	local out = {}
	for i = 1, Forge.FUSE_COUNT do out[i] = pool[i] end
	return out
end

-- Materials: 9 of one become 1 of the next tier of the same kind (a
-- socket material: of the same line, a grade up).
function Forge.NextMat(id)
	local m = ns.MATS[id]
	if not m or m.tier >= ns.MAT_MAX_TIER[m.kind] then return nil end
	if m.line then
		local up = ns.SocketMatUp(id)
		return up and { up } or nil
	end
	return { m.kind .. (m.tier + 1) }
end

function Forge.FuseMat(id)
	local m = ns.MATS[id]
	if not m then return false end
	local nextList = Forge.NextMat(id)
	if not nextList then
		return false, "이미 최고 단계 재료입니다."
	end
	if ns.MatCount(id) < Forge.FUSE_COUNT then
		return false, string.format("%d개가 필요합니다.", Forge.FUSE_COUNT)
	end
	local _, fxp = ns.MatValue(id)
	ns.AddMat(id, -Forge.FUSE_COUNT)
	local nextId = nextList[random(#nextList)]
	ns.AddMat(nextId, 1)
	Forge.AddXP(fxp * Forge.FUSE_COUNT)
	return true, nextId
end

local MAT_KINDS = { "bar", "leather", "cloth", "gem", "dust", "scroll", "seal" }

-- The materials of a kind at a tier (several for socket materials).
local function matsAt(kind, tier)
	local by = ns.SOCKET_MATS_BY[kind]
	if by then return by[tier] or {} end
	return ns.MATS[kind .. tier] and { kind .. tier } or {}
end
Forge.MatsAt = matsAt

-- How many fusions FuseAllMats would make now (lower tiers first, so what
-- they make can be fused again).
-- kinds: { [kind] = true } to count only those (nil = every material)
function Forge.MatFusionsReady(kinds)
	local n = 0
	for _, kind in ipairs(MAT_KINDS) do
		if not kinds or kinds[kind] then
			local carry = {}
			for tier = 1, ns.MAT_MAX_TIER[kind] - 1 do
				local made = {}
				for i, id in ipairs(matsAt(kind, tier)) do
					-- (what the tier below made of this line lands on this one)
					local k = math.floor((ns.MatCount(id) + (carry[i] or 0)) / Forge.FUSE_COUNT)
					made[i] = k
					n = n + k
				end
				carry = made
			end
		end
	end
	return n
end

-- Fuses every material that has nine or more, tier by tier, until nothing
-- is left to fuse. Returns the number of fusions.
function Forge.FuseAllMats(kinds)
	local n = 0
	for _, kind in ipairs(MAT_KINDS) do
		for tier = 1, (kinds and not kinds[kind]) and 0 or (ns.MAT_MAX_TIER[kind] - 1) do
			for _, id in ipairs(matsAt(kind, tier)) do
				while ns.MatCount(id) >= Forge.FUSE_COUNT do
					if not Forge.FuseMat(id) then break end
					n = n + 1
				end
			end
		end
	end
	if n > 0 then ns.Fire("MATS") end
	return n
end

------------------------------------------------------------------------
-- Crafting
------------------------------------------------------------------------
function Forge.CraftTierUnlocked(tier)
	return ns.db.forge.craft[tier] == true
end

function Forge.UnlockCraftTier(tier)
	local d = ns.CRAFT_TIERS[tier]
	if not d or Forge.CraftTierUnlocked(tier) then return false end
	if ns.db.forge.level < d.forge then
		return false, string.format("대장간 %d레벨이 필요합니다.", d.forge)
	end
	if not ns.SpendGold(d.gold * 5) then
		return false, "골드가 부족합니다."
	end
	ns.db.forge.craft[tier] = true
	ns.Fire("FORGE")
	return true
end

-- Returns { [matId] = count }, goldFee
function Forge.CraftCost(group, tier)
	local g = ns.CRAFT_GROUPS[group]
	local cost = {}
	for kind, n in pairs(g.cost) do
		cost[kind .. tier] = n
	end
	return cost, ns.CRAFT_TIERS[tier].gold
end

function Forge.CanCraft(group, tier)
	local ok, why = needOp("craft")
	if not ok then return false, why end
	if not Forge.CraftTierUnlocked(tier) then
		return false, "이 제작 단계는 아직 잠겨 있습니다."
	end
	local cost, gold = Forge.CraftCost(group, tier)
	for id, n in pairs(cost) do
		if ns.MatCount(id) < n then
			return false, string.format("재료 부족: %s", ns.N(ns.MATS[id].name))
		end
	end
	if not ns.CanAfford(gold) then
		return false, "골드가 부족합니다."
	end
	if ns.Items.BagFree() <= 0 then
		return false, "가방이 가득 찼습니다."
	end
	return true
end

function Forge.Craft(group, tier)
	local ok, why = Forge.CanCraft(group, tier)
	if not ok then return false, why end
	local cost, gold = Forge.CraftCost(group, tier)
	local xp = 0
	for id, n in pairs(cost) do
		local _, fxp = ns.MatValue(id)
		xp = xp + fxp * n
		ns.AddMat(id, -n)
	end
	ns.SpendGold(gold)
	local d = ns.CRAFT_TIERS[tier]
	local g = ns.CRAFT_GROUPS[group]
	local level = d.levels[random(#d.levels)]
	local q = U.weightedIndex(d.q)
	local it = ns.Items.New(U.pick(g.slots), level, q)
	ns.Items.AddToBag(it)
	Forge.AddXP(xp)
	return true, it
end

------------------------------------------------------------------------
-- Sockets: gem / enchant / inscription, and extraction
------------------------------------------------------------------------
function Forge.CanSocket(it, kind, matId)
	local ok, why = needOp(kind)
	if not ok then return false, why end
	if not it then return false, "장비를 먼저 고르세요." end
	if not matId then return false, "쓸 재료를 먼저 고르세요." end
	if ns.Items.SocketCount(it, kind) <= 0 then
		return false, "이 장비에는 해당 홈이 없습니다."
	end
	if ns.Items.FreeSockets(it, kind) <= 0 then
		return false, "빈 홈이 없습니다. 먼저 추출하세요."
	end
	local m = ns.MATS[matId]
	if not m or m.kind ~= ns.SOCKET[kind].mat then
		return false, "맞지 않는 재료입니다."
	end
	if ns.MatCount(matId) <= 0 then
		return false, "재료가 없습니다."
	end
	return true
end

function Forge.Socket(it, kind, matId, heroId)
	local ok, why = Forge.CanSocket(it, kind, matId)
	if not ok then return false, why end
	ns.AddMat(matId, -1)
	local entry = ns.Items.AddSocket(it, kind, matId)
	-- the hero wearing it now (whatever hero the caller had in mind)
	local wearer = ns.Items.Wearer(it)
	ns.Stats.Invalidate(wearer)
	ns.Fire("BAG")
	if wearer then ns.Fire("GEAR", wearer) end
	return true, entry
end

-- TBH's extraction cost for the kind and the tier of what is set
function Forge.RemoveCost(kind, tier)
	local t = ns.TBH.EXTRACT[ns.SOCKET[kind].mat]
	return t[math.max(1, math.min(#t, tier or 1))]
end

function Forge.RemoveSocket(it, kind, index, heroId)
	local ok, why = needOp("remove")
	if not ok then return false, why end
	local l = ns.Items.SocketList(it, kind)
	local e = l and l[index]
	if not e then return false end
	if not ns.SpendGold(Forge.RemoveCost(kind, e[3])) then
		return false, "골드가 부족합니다."
	end
	table.remove(l, index)
	local wearer = ns.Items.Wearer(it)
	ns.Stats.Invalidate(wearer)
	ns.Fire("BAG")
	if wearer then ns.Fire("GEAR", wearer) end
	return true
end

------------------------------------------------------------------------
-- Bonus roll: a seal plus a gold fee for one random item
------------------------------------------------------------------------
-- The level of a piece a seal rolls: your furthest progress (like chest
-- gear, it may wait in the bag until a hero reaches it).
function Forge.SealLevel()
	local best = 1
	for diff = 1, #ns.DIFFS do
		local p = ns.db.prog[diff] or 0
		if p > 0 then best = max(best, ns.StageLevel(diff, min(ns.STAGE_COUNT, p))) end
	end
	return best
end

function Forge.BonusRoll(tier)
	local ok, why = needOp("seal")
	if not ok then return false, why end
	local d = ns.SEAL[tier]
	if not d then return false end
	if ns.MatCount(d.mat) <= 0 then
		return false, "인장이 없습니다."
	end
	if ns.Items.BagFree() <= 0 then
		return false, "가방이 가득 찼습니다."
	end
	if not ns.SpendGold(d.gold) then
		return false, "골드가 부족합니다."
	end
	local _, fxp = ns.MatValue(d.mat)
	ns.AddMat(d.mat, -1)
	local best = Forge.SealLevel()
	local q = U.weightedIndex(d.q)
	local it = ns.Items.New(ns.Items.RandomSlot(best), best, q)
	ns.Items.AddToBag(it)
	Forge.AddXP(fxp)
	return true, it
end
