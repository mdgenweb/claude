--!strict
-- Decisions for practice bots and for disconnected teammates in 2v2 (auto-play).
local BotBrain = {}

local rng = Random.new()

-- Called every frame while a match is in selection/aim. Returns actions to apply.
function BotBrain.Selection(participant: { [string]: any }, now: number): number?
	if participant.Picked then
		return nil
	end
	participant.ThinkAt = participant.ThinkAt or (now + rng:NextNumber(1.2, 3.2))
	if now >= participant.ThinkAt then
		participant.ThinkAt = nil
		return rng:NextInteger(1, #participant.Offers)
	end
	return nil
end

-- Aims roughly at the arena centre/opponents with some spread.
function BotBrain.Aim(participant: { [string]: any }, now: number, fromX: number, fromY: number, targetX: number, targetY: number): number?
	if participant.Locked then
		return nil
	end
	participant.ThinkAt = participant.ThinkAt or (now + rng:NextNumber(1.0, 2.8))
	if now >= participant.ThinkAt then
		participant.ThinkAt = nil
		local base = math.atan2(targetY - fromY, targetX - fromX)
		return base + rng:NextNumber(-0.9, 0.9)
	end
	return nil
end

return BotBrain
