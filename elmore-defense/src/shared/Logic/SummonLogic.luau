--[[
	SummonLogic
	Pure gacha maths. The server uses roll(); the UI uses displayOdds() which is built from the same entries,
	so displayed odds are always the real odds (Roblox paid-random-item policy).
]]

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Units = require(Shared.Config.Units)
local Banners = require(Shared.Config.Banners)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local SummonLogic = {}

local RARITY_RANK = { Rare = 1, Epic = 2, Legendary = 3, Mythic = 4, Secret = 5 }
SummonLogic.RARITY_RANK = RARITY_RANK

export type Options = { lucky: boolean?, now: number? }
export type PityState = { legendary: number, mythic: number }

function SummonLogic.isActive(banner, now: number): boolean
	if not banner.event then
		return true
	end
	return now >= (banner.startsAt or 0) and now < (banner.endsAt or math.huge)
end

-- Rarity weights with pass modifiers applied (Rare absorbs the difference).
function SummonLogic.rarityEntries(banner, options: Options?)
	local entries = {}
	for _, rarity in Banners.RARITY_ORDER do
		table.insert(entries, { id = rarity, weight = banner.rates[rarity] or 0 })
	end
	if options and options.lucky then
		entries = WeightedRandom.boost(entries, { Mythic = 2, Legendary = 1.5 }, "Rare")
	end
	return entries
end

-- Featured Mythic for the banner at time `now`, the next one, and seconds until rotation.
function SummonLogic.featured(banner, now: number): (string?, string?, number)
	if banner.featuredFixed then
		return banner.featuredFixed, nil, math.max(0, (banner.endsAt or now) - now)
	end
	local rotation = banner.featuredRotation
	if not rotation or #rotation == 0 then
		return nil, nil, 0
	end
	local period = GameConfig.Summon.BannerRotationSeconds
	local slot = math.floor(now / period)
	local index = slot % #rotation + 1
	local nextIndex = index % #rotation + 1
	return rotation[index], rotation[nextIndex], period - (now % period)
end

function SummonLogic.pool(rarity: string): { string }
	local ids = {}
	for _, unit in Units.listByRarity(rarity, true) do
		table.insert(ids, unit.id)
	end
	return ids
end

-- Per-unit weights inside a rarity (handles featured Mythic and rate-ups).
function SummonLogic.unitEntries(banner, rarity: string, now: number)
	local ids = SummonLogic.pool(rarity)
	local entries = {}
	local special: string? = nil
	local share = 0
	if rarity == "Mythic" then
		special = SummonLogic.featured(banner, now)
		share = banner.featuredShare or 0
	elseif banner.rateUp and banner.rateUp[rarity] then
		special = banner.rateUp[rarity].unit
		share = banner.rateUp[rarity].share
	end
	if special and not table.find(ids, special) then
		special = nil
	end
	local others = #ids - (if special then 1 else 0)
	for _, id in ids do
		local weight
		if special then
			if id == special then
				weight = if others > 0 then share else 1
			else
				weight = (1 - share) / math.max(others, 1)
			end
		else
			weight = 1 / #ids
		end
		table.insert(entries, { id = id, weight = weight })
	end
	return entries
end

local function rollRarity(entries, rng, minimumRank: number): string
	if minimumRank > 1 then
		local filtered = {}
		for _, entry in entries do
			if RARITY_RANK[entry.id] >= minimumRank then
				table.insert(filtered, entry)
			end
		end
		entries = filtered
	end
	return WeightedRandom.pick(entries, rng) :: string
end

-- One pull. Returns result and the updated pity state (input state is not mutated).
function SummonLogic.roll(banner, pity: PityState, rng, options: Options?)
	local now = (options and options.now) or os.time()
	local entries = SummonLogic.rarityEntries(banner, options)
	local legendaryCount = (pity.legendary or 0) + 1
	local mythicCount = (pity.mythic or 0) + 1

	local minimumRank = 1
	local pityHit: string? = nil
	if mythicCount >= GameConfig.Summon.MythicPity then
		minimumRank = RARITY_RANK.Mythic
		pityHit = "Mythic"
	elseif legendaryCount >= GameConfig.Summon.LegendaryPity then
		minimumRank = RARITY_RANK.Legendary
		pityHit = "Legendary"
	end

	local rarity = rollRarity(entries, rng, minimumRank)
	local unitId = WeightedRandom.pick(SummonLogic.unitEntries(banner, rarity, now), rng) :: string
	local shiny = rng:NextNumber() < GameConfig.Summon.ShinyChance

	local rank = RARITY_RANK[rarity]
	local newPity = {
		legendary = if rank >= RARITY_RANK.Legendary then 0 else legendaryCount,
		mythic = if rank >= RARITY_RANK.Mythic then 0 else mythicCount,
	}
	return { unitId = unitId, rarity = rarity, shiny = shiny, pityHit = pityHit }, newPity
end

-- Full odds table for display: every outcome with its exact percentage (sums to 100).
function SummonLogic.displayOdds(banner, options: Options?)
	local now = (options and options.now) or os.time()
	local rarityPct = WeightedRandom.toPercentages(SummonLogic.rarityEntries(banner, options))
	local rows = {}
	for _, rarity in Banners.RARITY_ORDER do
		local pct = rarityPct[rarity] or 0
		local unitRows = {}
		local unitPct = WeightedRandom.toPercentages(SummonLogic.unitEntries(banner, rarity, now))
		for _, id in SummonLogic.pool(rarity) do
			table.insert(unitRows, { id = id, percent = pct * (unitPct[id] or 0) / 100 })
		end
		table.sort(unitRows, function(a, b)
			return a.percent > b.percent
		end)
		table.insert(rows, { rarity = rarity, percent = pct, units = unitRows })
	end
	return rows
end

function SummonLogic.cost(count: number, vip: boolean): number
	local base = if count >= 10 then GameConfig.Summon.TenCost else GameConfig.Summon.SingleCost * count
	if vip then
		base = math.floor(base * (1 - GameConfig.Summon.VipDiscount) + 0.5)
	end
	return base
end

return SummonLogic
