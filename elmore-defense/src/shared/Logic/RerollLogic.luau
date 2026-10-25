--[[
	RerollLogic
	Trait and grade rolls. Same entries feed the UI odds table and the server roll.
]]

local Shared = script.Parent.Parent
local Traits = require(Shared.Config.Traits)
local Grades = require(Shared.Config.Grades)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local RerollLogic = {}

function RerollLogic.traitEntries(vip: boolean?)
	local entries = {}
	local multipliers = {}
	for _, trait in Traits.list do
		table.insert(entries, { id = trait.id, weight = trait.weight })
		if vip then
			local factor = Traits.VipTierMultipliers[trait.tier]
			if factor then
				multipliers[trait.id] = factor
			end
		end
	end
	if vip then
		entries = WeightedRandom.boost(entries, multipliers, nil)
	end
	return entries
end

function RerollLogic.traitOdds(vip: boolean?): { [string]: number }
	return WeightedRandom.toPercentages(RerollLogic.traitEntries(vip))
end

function RerollLogic.rollTrait(rng, vip: boolean?): string
	return WeightedRandom.pick(RerollLogic.traitEntries(vip), rng) :: string
end

function RerollLogic.rollGrade(rng): string
	return WeightedRandom.pick(Grades.entries(), rng) :: string
end

-- Rolls all three grades, keeping `lockedStat` (if any) from `current`.
function RerollLogic.rollGrades(rng, current: { [string]: string }?, lockedStat: string?)
	local result = {}
	for _, stat in Grades.STATS do
		if lockedStat == stat and current and current[stat] then
			result[stat] = current[stat]
		else
			result[stat] = RerollLogic.rollGrade(rng)
		end
	end
	return result
end

return RerollLogic
