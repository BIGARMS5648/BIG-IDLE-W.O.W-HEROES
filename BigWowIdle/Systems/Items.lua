-- Item instances: generation, naming, stat iteration, bag / bank handling.
--
-- An item is a plain table so it can live in SavedVariables:
--   s = slot, t = weapon type (weapons only), l = level, q = quality,
--   a = inherent affixes, g/e/i = gem / enchant / inscription sockets,
--   each entry { affixKey, value [, materialTier] }, lock = true when protected.
local _, ns = ...

local floor, max, min, random = math.floor, math.max, math.min, math.random
local U = ns.U

local Items = {}
ns.Items = Items

local BASE_ORDER = { "atk", "hp", "armor", "aspd", "crit", "critdmg", "block", "cast", "heal" }

local function roundValue(v)
	if v >= 20 then return floor(v + 0.5) end
	return floor(v * 10 + 0.5) / 10
end

------------------------------------------------------------------------
-- Reading an item
------------------------------------------------------------------------
function Items.Def(it)
	if it.t then return ns.WTYPE[it.t] end
	return ns.SLOT[it.s]
end

function Items.Cat(it)
	return ns.SLOT[it.s].cat
end

-- Fusion keeps armor / weapons apart from accessories.
function Items.FuseCat(it)
	return ns.SLOT[it.s].cat == "accessory" and "accessory" or "gear"
end

function Items.Tier(it)
	return min(#ns.ITEM_TIER, floor(it.l / 10) + 1)
end

function Items.Name(it)
	local def = Items.Def(it)
	local tname = def.tname or def.name
	return ns.N(ns.ITEM_TIER[Items.Tier(it)]) .. " " .. ns.N(tname)
end

function Items.ColorName(it)
	return U.col(ns.QUALITY[it.q].hex, Items.Name(it))
end

function Items.Icon(it)
	local def = Items.Def(it)
	local icons = def.icons
	return icons[min(#icons, floor((Items.Tier(it) + 1) / 2))]
end

function Items.ReqLevel(it)
	return max(1, it.l - 2)
end

-- Base stats are derived from type, level and quality (never stored).
function Items.BaseStats(it)
	local def = Items.Def(it)
	local q = ns.QUALITY[it.q]
	local out = {}
	for i = 1, #BASE_ORDER do
		local key = BASE_ORDER[i]
		local b = def.base[key]
		if b then
			local a = ns.AFFIX[key]
			local v
			if a.s then
				v = b * ns.Scale[a.s](it.l) * q.mult
			else
				v = b * (0.8 + 0.1 * it.q)
			end
			out[#out + 1] = { key, roundValue(v) }
		end
	end
	return out
end

-- Calls fn(acc, affixKey, value) for every stat the item grants.
function Items.EachMod(it, fn, acc)
	local base = Items.BaseStats(it)
	for i = 1, #base do
		fn(acc, base[i][1], base[i][2])
	end
	local lists = { it.a, it.g, it.e, it.i }
	for n = 1, 4 do
		local l = lists[n]
		if l then
			for i = 1, #l do
				fn(acc, l[i][1], l[i][2])
			end
		end
	end
end

function Items.SocketCount(it, kind)
	return ns.QUALITY[it.q][kind] or 0
end

function Items.SocketList(it, kind, create)
	local f = ns.SOCKET_FIELD[kind]
	if not it[f] and create then it[f] = {} end
	return it[f]
end

function Items.FreeSockets(it, kind)
	local l = Items.SocketList(it, kind)
	return Items.SocketCount(it, kind) - (l and #l or 0)
end

function Items.HasSockets(it)
	return (it.g and #it.g > 0) or (it.e and #it.e > 0) or (it.i and #it.i > 0)
end

-- Gold and forge experience from smelting.
function Items.Value(it)
	local q = ns.QUALITY[it.q]
	local gold = floor(q.gold * ns.MobGold(1, it.l) + 0.5)
	local fxp = q.fxp * (1 + 0.5 * (it.l - 1)) * ns.SLOT[it.s].fxp
	return gold, fxp
end

function Items.SpecCanUse(specId, it)
	local sp = ns.SPECS[specId]
	if it.s == "mh" then
		return U.contains(sp.mh, it.t)
	elseif it.s == "oh" then
		return U.contains(sp.oh, it.t)
	end
	return true
end

function Items.CanUse(heroId, it)
	local h = ns.db.heroes[heroId]
	return h ~= nil and Items.SpecCanUse(h.spec, it)
end

function Items.CanEquip(heroId, it)
	if not Items.CanUse(heroId, it) then
		return false, "이 직업은 사용할 수 없는 장비입니다."
	end
	local h = ns.db.heroes[heroId]
	if h.level < Items.ReqLevel(it) then
		return false, string.format("%d레벨이 되어야 착용할 수 있습니다.", Items.ReqLevel(it))
	end
	return true
end

-- "Arms / Fury Warrior, Retribution Paladin ..." for weapon tooltips
function Items.UsableBy(it)
	local parts = {}
	for _, cid in ipairs(ns.CLASS_ORDER) do
		local c = ns.CLASSES[cid]
		local specs = {}
		for _, sid in ipairs(c.specs) do
			if Items.SpecCanUse(sid, it) then specs[#specs + 1] = ns.N(ns.SPECS[sid].name) end
		end
		if #specs == #c.specs then
			parts[#parts + 1] = U.col(c.hex, ns.N(c.name))
		elseif #specs > 0 then
			parts[#parts + 1] = U.col(c.hex, ns.N(c.name) .. "(" .. table.concat(specs, "/") .. ")")
		end
	end
	return table.concat(parts, ", ")
end

------------------------------------------------------------------------
-- Generation
------------------------------------------------------------------------
-- An affix is rolled between its pool entry's two numbers times this.
local function affixMult(key, level, quality)
	local a = ns.AFFIX[key]
	if a.s then return ns.Scale[a.s](level) * ns.QUALITY[quality].mult end
	return (1 + level / 200) * (0.86 + 0.07 * quality)
end

local function rollAffix(entry, level, quality)
	local key, lo, hi = entry[1], entry[2], entry[3]
	return { key, roundValue(U.rnd(lo, hi) * affixMult(key, level, quality)) }
end

-- The range a random stat of this item could have rolled in, for its slot,
-- level and grade (nil for a fixed one, such as +1 to all skills).
function Items.AffixRange(it, key)
	local cat = ns.SLOT[it.s] and ns.SLOT[it.s].cat
	local pool = cat and ns.AFFIX_POOL[cat]
	if not (pool and ns.AFFIX[key]) then return nil end
	for _, e in ipairs(pool) do
		if e[1] == key then
			if e[2] == e[3] then return nil end
			local m = affixMult(key, it.l, it.q)
			return roundValue(e[2] * m), roundValue(e[3] * m)
		end
	end
end

-- "+9.6% 공격력 (6.2~12.4)": the stat and the range it could have rolled in.
function Items.AffixText(it, a)
	local text = ns.Stats.ModText(a[1], a[2])
	local lo, hi = Items.AffixRange(it, a[1])
	if lo then
		local function n(v) return (ns.Stats.FormatValue(a[1], v):gsub("%%", "")) end
		text = text .. " " .. U.col("9aa3b5", "(" .. n(lo) .. "~" .. n(hi) .. ")")
	end
	return text
end

-- Weapon types the current party can actually use ("personal loot").
local function partyTypes(slot)
	local set, list = {}, {}
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		local sp = id and ns.Heroes.Spec(id)
		if sp then
			for _, t in ipairs(sp[slot]) do
				if not set[t] then
					set[t] = true
					list[#list + 1] = t
				end
			end
		end
	end
	return list
end

function Items.RandomType(slot)
	local all = slot == "mh" and ns.WTYPES_MH or ns.WTYPES_OH
	if ns.db and random() < 0.75 then
		local list = partyTypes(slot)
		if #list > 0 then return U.pick(list) end
	end
	return U.pick(all)
end

function Items.New(slot, level, quality, wtype)
	level = U.clamp(floor(level + 0.5), 1, ns.HERO_MAX_LEVEL)
	quality = U.clamp(quality, 1, ns.MAX_QUALITY)
	local it = { s = slot, l = level, q = quality }
	if slot == "mh" or slot == "oh" then
		it.t = wtype or Items.RandomType(slot)
	end
	local n = ns.QUALITY[quality].affix
	if n > 0 then
		it.a = {}
		local pool = ns.AFFIX_POOL[ns.SLOT[slot].cat]
		local used = {}
		for _ = 1, n do
			local choices = {}
			for i = 1, #pool do
				if not used[pool[i][1]] then
					choices[#choices + 1] = pool[i]
				end
			end
			local e = U.weighted(choices, 4)
			used[e[1]] = true
			it.a[#it.a + 1] = rollAffix(e, level, quality)
		end
		-- high-end amulets may carry +1 to all skills instead of their last affix
		if slot == "neck" and quality >= 6 and random() < 0.2 then
			it.a[#it.a] = { "skills", 1 }
		end
	end
	return it
end

-- Random slot for a level, optionally restricted to a fusion category.
function Items.RandomSlot(level, cat)
	local choices = {}
	for _, slot in ipairs(ns.SLOTS) do
		local def = ns.SLOT[slot]
		local okLevel = (def.minLevel or 1) <= level
		local isAcc = def.cat == "accessory"
		local okCat = (cat == nil) or (cat == "accessory" and isAcc) or (cat == "gear" and not isAcc)
		if okCat and (okLevel or cat ~= nil) then
			choices[#choices + 1] = { slot = slot, w = def.w }
		end
	end
	return U.weighted(choices).slot
end

-- Rolls a socket stat for an item; returns the entry that was added.
-- A socket stat is rolled between the pool entry's two numbers times this:
-- flat stats follow the material tier's level, the rest a tier multiplier.
local function socketScale(key, tier)
	local a = ns.AFFIX[key]
	if a and a.s then return ns.Scale[a.s](ns.SOCKET_TIER_LEVEL[tier]) end
	return ns.SOCKET_TIER_MULT[tier]
end

function Items.AddSocket(it, kind, tier)
	local pool = ns.SOCKET[kind][Items.Cat(it)]
	local e = U.pick(pool)
	local v
	if e[1] == "skills" then
		v = 1
	else
		v = U.rnd(e[2], e[3]) * socketScale(e[1], tier)
	end
	local entry = { e[1], roundValue(v), tier }
	local l = Items.SocketList(it, kind, true)
	l[#l + 1] = entry
	return entry
end

-- The lowest and highest value a socket stat could have rolled (its kind,
-- the item's category and the material tier), or nil for a fixed one.
function Items.SocketRange(it, kind, e)
	local key, tier = e[1], e[3]
	local pools = ns.SOCKET[kind]
	local pool = pools and pools[Items.Cat(it)]
	if not (pool and tier and ns.SOCKET_TIER_MULT[tier]) then return nil end
	for _, p in ipairs(pool) do
		if p[1] == key then
			if p[2] == p[3] then return nil end
			local s = socketScale(key, tier)
			return roundValue(p[2] * s), roundValue(p[3] * s)
		end
	end
end

-- The icon of the material set in a socket of this kind and tier.
function Items.SocketIcon(kind, tier)
	local m = ns.SOCKET[kind] and ns.MATS[ns.SOCKET[kind].mat .. (tier or 1)]
	return m and m.icon
end

-- "(10.5~21)", or nil for a fixed stat
function Items.SocketRangeText(it, kind, e)
	local lo, hi = Items.SocketRange(it, kind, e)
	if not lo then return nil end
	local function n(v) return (ns.Stats.FormatValue(e[1], v):gsub("%%", "")) end
	return "(" .. n(lo) .. "~" .. n(hi) .. ")"
end

-- "+14.2% 치명타 피해 (10.5~21)": the stat and, when it was rolled, the
-- range it could have rolled in (grey).
function Items.SocketText(it, kind, e)
	local text = ns.Stats.ModText(e[1], e[2])
	local range = Items.SocketRangeText(it, kind, e)
	if range then text = text .. " " .. U.col("9aa3b5", range) end
	return text
end

------------------------------------------------------------------------
-- Bag and bank
------------------------------------------------------------------------
function Items.BagFree()
	return ns.BagSize() - #ns.db.bag
end

function Items.BankFree()
	return ns.BankSize() - #ns.db.bank
end

function Items.AddToBag(it)
	if Items.BagFree() <= 0 then return false end
	local bag = ns.db.bag
	bag[#bag + 1] = it
	ns.Fire("BAG")
	return true
end

function Items.RemoveFromBag(index)
	local it = table.remove(ns.db.bag, index)
	ns.Fire("BAG")
	return it
end

function Items.IndexInBag(it)
	local bag = ns.db.bag
	for i = 1, #bag do
		if bag[i] == it then return i end
	end
end

function Items.ToggleLock(it)
	it.lock = (not it.lock) or nil
	ns.Fire("BAG")
end

function Items.ToBank(index)
	if Items.BankFree() <= 0 then
		return false, "은행이 가득 찼습니다."
	end
	local it = table.remove(ns.db.bag, index)
	if not it then return false end
	ns.db.bank[#ns.db.bank + 1] = it
	ns.Fire("BAG")
	return true
end

function Items.FromBank(index)
	if Items.BagFree() <= 0 then
		return false, "가방이 가득 찼습니다."
	end
	local it = table.remove(ns.db.bank, index)
	if not it then return false end
	ns.db.bag[#ns.db.bag + 1] = it
	ns.Fire("BAG")
	return true
end

local function sortKey(it)
	local slotIndex = 0
	for i = 1, #ns.SLOTS do
		if ns.SLOTS[i] == it.s then slotIndex = i end
	end
	return it.q * 100000 + it.l * 100 + (20 - slotIndex)
end

function Items.Sort(list)
	table.sort(list, function(a, b)
		local ka, kb = sortKey(a), sortKey(b)
		if ka ~= kb then return ka > kb end
		return (a.t or "") < (b.t or "")
	end)
	ns.Fire("BAG")
end

------------------------------------------------------------------------
-- Equipping
------------------------------------------------------------------------
function Items.Equip(heroId, bagIndex)
	local db = ns.db
	local it = db.bag[bagIndex]
	if not it then return false end
	local ok, why = Items.CanEquip(heroId, it)
	if not ok then return false, why end
	local h = db.heroes[heroId]
	local old = h.gear[it.s]
	table.remove(db.bag, bagIndex)
	h.gear[it.s] = it -- a protected item stays protected while worn
	if old then
		table.insert(db.bag, bagIndex, old)
	end
	ns.Stats.Invalidate(heroId)
	ns.Fire("BAG")
	ns.Fire("GEAR", heroId)
	return true
end

function Items.Unequip(heroId, slot)
	local h = ns.db.heroes[heroId]
	local it = h.gear[slot]
	if not it then return false end
	if Items.BagFree() <= 0 then
		return false, "가방이 가득 찼습니다."
	end
	h.gear[slot] = nil
	ns.db.bag[#ns.db.bag + 1] = it
	ns.Stats.Invalidate(heroId)
	ns.Fire("BAG")
	ns.Fire("GEAR", heroId)
	return true
end

-- Gold a player gets for breaking an item down, bonuses included. Every screen
-- and the forge itself use this, so the number shown is the number paid.
function Items.SmeltGold(it)
	return floor(Items.Value(it) * (1 + ns.Bonus("smeltGold") / 100))
end

-- The party hero this bag item would improve the most (ratio > 1.01), if any.
function Items.PartyUpgrade(it)
	local best, bestR
	for i = 1, ns.PARTY_SIZE do
		local id = ns.db.party[i]
		if id and ns.db.heroes[id] then
			local r = Items.Compare(id, it)
			if r and r > 1.01 and (not bestR or r > bestR) then best, bestR = id, r end
		end
	end
	return best, bestR
end

-- Would this bag item be an upgrade for the hero? Returns the power ratio.
function Items.Compare(heroId, it)
	if not Items.CanEquip(heroId, it) then return nil end
	local h = ns.db.heroes[heroId]
	local cur = ns.Stats.Power(heroId)
	local gear = {}
	for k, v in pairs(h.gear) do gear[k] = v end
	gear[it.s] = it
	local new = ns.Stats.Power(heroId, gear)
	return new / max(0.0001, cur)
end

-- Puts the best usable bag item into every slot. Returns how many changed.
function Items.AutoEquip(heroId)
	local db = ns.db
	local changed = 0
	for _ = 1, 3 do -- a few passes because percent stats interact
		local any = false
		for _, slot in ipairs(ns.SLOTS) do
			local bestIndex, bestRatio = nil, 1.002
			for i = 1, #db.bag do
				local it = db.bag[i]
				if it.s == slot then
					local r = Items.Compare(heroId, it)
					if r and r > bestRatio then
						bestIndex, bestRatio = i, r
					end
				end
			end
			if bestIndex then
				Items.Equip(heroId, bestIndex)
				changed = changed + 1
				any = true
			end
		end
		if not any then break end
	end
	return changed
end

------------------------------------------------------------------------
-- Tooltip text: array of { left, right, r, g, b }
------------------------------------------------------------------------
function Items.Tooltip(it, heroId)
	local q = ns.QUALITY[it.q]
	local lines = {}
	local function add(left, right, r, g, b)
		lines[#lines + 1] = { left, right, r or 1, g or 1, b or 1 }
	end
	local qr, qg, qb = U.rgb(q.hex)
	add(Items.Name(it), nil, qr, qg, qb)
	add(ns.N(q.name) .. " " .. ns.N(ns.SLOT[it.s].name), "아이템 레벨 " .. it.l, 0.7, 0.7, 0.7)
	for _, b in ipairs(Items.BaseStats(it)) do
		add(ns.Stats.ModText(b[1], b[2]), nil, 1, 1, 1)
	end
	if it.a then
		for _, a in ipairs(it.a) do
			add(Items.AffixText(it, a), nil, 0.2, 1, 0.2) -- with the range it could have rolled in
		end
	end
	-- sockets, kind by kind (보석, then 마법부여, then 룬 각인): each filled
	-- one on its own line, drawn as the socket with the material in it
	-- (line.sockets, see UI.Lines), then that kind's empty ones on one line
	for _, kind in ipairs(ns.SOCKET_KINDS) do
		local total = Items.SocketCount(it, kind)
		if total > 0 then
			local l = Items.SocketList(it, kind)
			local empty = {}
			for i = 1, total do
				local e = l and l[i]
				if e then
					add(Items.SocketText(it, kind, e), nil, 0.4, 0.8, 1)
					lines[#lines].sockets = { { kind, Items.SocketIcon(kind, e[3]) } }
				else
					empty[#empty + 1] = { kind }
				end
			end
			if #empty > 0 then
				add(string.format("빈 %s 홈%s", ns.N(ns.SOCKET[kind].short), #empty > 1 and (" " .. #empty .. "개") or ""), nil, 0.55, 0.58, 0.65)
				lines[#lines].sockets = empty
			end
		end
	end
	if it.t then
		add("사용 가능: " .. Items.UsableBy(it), nil, 0.8, 0.8, 0.8)
	end
	local req = Items.ReqLevel(it)
	local h = heroId and ns.db.heroes[heroId]
	if h and h.level < req then
		add(string.format("요구 레벨 %d", req), nil, 1, 0.2, 0.2)
	else
		add(string.format("요구 레벨 %d", req), nil, 0.8, 0.8, 0.8)
	end
	add("분해 가치", U.fmt(Items.SmeltGold(it)) .. " G", 1, 0.82, 0)
	if it.lock then
		add("보호됨 - 분해·융합에 쓰이지 않습니다", nil, 1, 0.5, 0.2)
	end
	if h and it ~= h.gear[it.s] then
		local r = Items.Compare(heroId, it)
		if r then
			local pct = (r - 1) * 100
			local name = ns.Heroes.Name(heroId)
			-- the role-weighted gear score auto-equip uses, not the 전투력 on screen
			if pct > 0.2 then
				add(string.format("%s 기준 장비 점수 +%s%%", name, U.num(pct, 1)), nil, 0.2, 1, 0.2)
			elseif pct < -0.2 then
				add(string.format("%s 기준 장비 점수 %s%%", name, U.num(pct, 1)), nil, 1, 0.3, 0.3)
			else
				add(string.format("%s 기준 장비 점수 변화 없음", name), nil, 0.7, 0.7, 0.7)
			end
		elseif not Items.CanUse(heroId, it) then
			add("선택한 영웅은 사용할 수 없습니다.", nil, 1, 0.3, 0.3)
		end
	end
	return lines
end

function Items.MatTooltip(id)
	local m = ns.MATS[id]
	local lines = {}
	local r, g, b = U.rgb(ns.QUALITY[m.q].hex)
	lines[#lines + 1] = { ns.N(m.name), nil, r, g, b }
	lines[#lines + 1] = { ns.N(ns.MAT_KIND_NAME[m.kind]) .. " " .. string.format("%d단계", m.tier), nil, 0.7, 0.7, 0.7 }
	local use
	if m.kind == "bar" or m.kind == "leather" or m.kind == "cloth" then
		use = "장비 > 제작 탭에서 장비를 만드는 재료입니다."
	elseif m.kind == "gem" then
		use = "장비 > 보석 탭에서 보석 홈에 능력치를 부여합니다."
	elseif m.kind == "dust" then
		use = "장비 > 마법부여 탭에서 마법 홈에 능력치를 부여합니다."
	elseif m.kind == "scroll" then
		use = "장비 > 각인 탭에서 룬 홈에 능력치를 부여합니다."
	else
		use = "장비 > 재료 > 행운의 인장 재료에서 [굴리기]로 무작위 장비를 얻습니다."
	end
	lines[#lines + 1] = { use, nil, 1, 0.82, 0, true }
	if m.tier < ns.MAT_MAX_TIER[m.kind] then
		lines[#lines + 1] = { "9개를 융합하면 다음 단계 1개가 됩니다.", nil, 0.6, 0.8, 1, true }
	end
	lines[#lines + 1] = { "분해 가치 (1개)", U.fmt(ns.Forge.MatSmeltGold(id, 1)) .. " G", 1, 0.82, 0 }
	lines[#lines + 1] = { "보유", tostring(ns.MatCount(id)), 0.8, 0.8, 0.8 }
	return lines
end
