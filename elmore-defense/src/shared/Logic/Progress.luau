--[[
	Progress
	Unlock rules shared by server validation and the Play menu UI.
	World N unlocks when World N-1 Act 5 is cleared; Act N unlocks when Act N-1 is cleared.
]]

local Shared = script.Parent.Parent
local Worlds = require(Shared.Config.Worlds)

local Progress = {}

function Progress.stars(profile, worldId: string, act: number): number
	return (profile.story and profile.story[Worlds.stageKey(worldId, act)]) or 0
end

function Progress.worldUnlocked(profile, worldId: string): boolean
	local world = Worlds.get(worldId)
	if not world then
		return false
	end
	if world.order == 1 then
		return true
	end
	local previous = Worlds.ordered[world.order - 1]
	return Progress.stars(profile, previous.id, Worlds.ACTS) > 0
end

function Progress.actUnlocked(profile, worldId: string, act: number): boolean
	if not Progress.worldUnlocked(profile, worldId) then
		return false
	end
	if act <= 1 then
		return true
	end
	return Progress.stars(profile, worldId, act - 1) > 0
end

function Progress.totalStars(profile): number
	local total = 0
	for _, stars in profile.story or {} do
		total += stars
	end
	return total
end

return Progress
