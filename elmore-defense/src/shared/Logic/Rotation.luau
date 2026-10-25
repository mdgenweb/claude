--[[
	Rotation
	Deterministic time-based rotations (challenges, quests). Every server computes the same answer
	from UTC time, so there's no cross-server coordination needed.
]]

local Shared = script.Parent.Parent
local Challenges = require(Shared.Config.Challenges)
local Quests = require(Shared.Config.Quests)
local Worlds = require(Shared.Config.Worlds)

local Rotation = {}

local DAY = 86400
local WEEK = 604800

function Rotation.dayIndex(now: number): number
	return math.floor(now / DAY)
end

-- Weeks start Monday 00:00 UTC (the Unix epoch was a Thursday).
function Rotation.weekIndex(now: number): number
	return math.floor((now + 3 * DAY) / WEEK)
end

function Rotation.secondsUntilNextDay(now: number): number
	return DAY - (now % DAY)
end

function Rotation.secondsUntilNextWeek(now: number): number
	return WEEK - ((now + 3 * DAY) % WEEK)
end

local function pickDistinct(pool: { any }, count: number, seed: number): { any }
	local rng = Random.new(seed)
	local indices = {}
	for index = 1, #pool do
		indices[index] = index
	end
	for index = #indices, 2, -1 do
		local swap = rng:NextInteger(1, index)
		indices[index], indices[swap] = indices[swap], indices[index]
	end
	local picked = {}
	for index = 1, math.min(count, #indices) do
		table.insert(picked, pool[indices[index]])
	end
	return picked
end

function Rotation.dailyQuests(dayIndex: number)
	return pickDistinct(Quests.DailyPool, Quests.DailyCount, 7919 * dayIndex + 17)
end

function Rotation.weeklyQuests(weekIndex: number)
	return pickDistinct(Quests.WeeklyPool, Quests.WeeklyCount, 104729 * weekIndex + 31)
end

-- Challenge slots: slot 1 easy (worlds 1-2), slot 2 medium (2-4), slot 3 hard (3-5).
local SLOT_WORLD_RANGES = { { 1, 2 }, { 2, 4 }, { 3, 5 } }

function Rotation.challenges(now: number)
	local period = Challenges.RotationSeconds
	local slotIndex = math.floor(now / period)
	local endsAt = (slotIndex + 1) * period
	local rng = Random.new(slotIndex * 2654435761 % 2147483647)
	local result = {}
	local usedModifiers = {}
	for slot = 1, Challenges.Slots do
		local range = SLOT_WORLD_RANGES[slot] or { 1, #Worlds.ordered }
		local world = Worlds.ordered[rng:NextInteger(range[1], math.min(range[2], #Worlds.ordered))]
		local act = rng:NextInteger(1, 3) + (slot - 1)
		local modifier
		repeat
			modifier = Challenges.ModifierOrder[rng:NextInteger(1, #Challenges.ModifierOrder)]
		until not usedModifiers[modifier] or #Challenges.ModifierOrder <= Challenges.Slots
		usedModifiers[modifier] = true
		local reward = Challenges.Rewards[rng:NextInteger(1, #Challenges.Rewards)]
		table.insert(result, {
			id = string.format("C%d_%d", slotIndex, slot),
			slot = slot,
			worldId = world.id,
			act = math.clamp(act, 1, Worlds.ACTS),
			modifier = modifier,
			reward = reward,
			endsAt = endsAt,
		})
	end
	return result
end

return Rotation
