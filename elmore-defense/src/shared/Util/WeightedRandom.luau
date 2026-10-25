--[[
	WeightedRandom
	Pure helpers for weighted picks. Every gacha-style roll in the game goes through here so the
	displayed odds and the real odds come from the exact same numbers.
]]

local WeightedRandom = {}

export type Entry = { id: string, weight: number }

-- Returns total weight of a list of entries.
function WeightedRandom.total(entries: { Entry }): number
	local sum = 0
	for _, entry in entries do
		sum += math.max(0, entry.weight)
	end
	return sum
end

-- Picks one entry id. `rng` is a Random object (or anything with :NextNumber()).
function WeightedRandom.pick(entries: { Entry }, rng): string?
	local sum = WeightedRandom.total(entries)
	if sum <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * sum
	local acc = 0
	for _, entry in entries do
		acc += math.max(0, entry.weight)
		if roll < acc then
			return entry.id
		end
	end
	return entries[#entries].id
end

-- Converts entries to percentage odds that sum to exactly 100 (for display / compliance).
function WeightedRandom.toPercentages(entries: { Entry }): { [string]: number }
	local sum = WeightedRandom.total(entries)
	local result = {}
	if sum <= 0 then
		return result
	end
	for _, entry in entries do
		result[entry.id] = math.max(0, entry.weight) / sum * 100
	end
	return result
end

-- Multiplies the weight of selected ids and renormalises so the total stays constant.
-- `multipliers` maps id -> factor. The surplus/deficit is absorbed by `absorbId`
-- (or proportionally by all non-multiplied entries when absorbId is nil).
function WeightedRandom.boost(entries: { Entry }, multipliers: { [string]: number }, absorbId: string?): { Entry }
	local originalTotal = WeightedRandom.total(entries)
	local boosted = {}
	local boostedTotal = 0
	local untouchedTotal = 0
	for _, entry in entries do
		local factor = multipliers[entry.id]
		local weight = entry.weight * (factor or 1)
		table.insert(boosted, { id = entry.id, weight = weight })
		boostedTotal += weight
		if not factor and entry.id ~= absorbId then
			untouchedTotal += weight
		end
	end
	local delta = boostedTotal - originalTotal
	if delta == 0 then
		return boosted
	end
	if absorbId then
		for _, entry in boosted do
			if entry.id == absorbId then
				entry.weight = math.max(0, entry.weight - delta)
			end
		end
	elseif untouchedTotal > 0 then
		local scale = math.max(0, untouchedTotal - delta) / untouchedTotal
		for _, entry in boosted do
			if not multipliers[entry.id] then
				entry.weight *= scale
			end
		end
	end
	return boosted
end

return WeightedRandom
