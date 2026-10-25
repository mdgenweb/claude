--[[
	Levels
	XP curves for the account, units and the battle pass.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Levels = {}

function Levels.playerXpToNext(level: number): number
	return 100 + 60 * level
end

function Levels.unitXpToNext(level: number): number
	return 40 + 30 * level
end

-- Applies XP gain; returns newLevel, newXp, levelsGained.
function Levels.applyXp(level: number, xp: number, gain: number, toNext: (number) -> number, maxLevel: number?)
	local gained = 0
	xp += gain
	while (not maxLevel or level < maxLevel) and xp >= toNext(level) do
		xp -= toNext(level)
		level += 1
		gained += 1
	end
	if maxLevel and level >= maxLevel then
		level = maxLevel
		xp = 0
	end
	return level, xp, gained
end

function Levels.applyUnitXp(level: number, xp: number, gain: number)
	return Levels.applyXp(level, xp, gain, Levels.unitXpToNext, GameConfig.Units.MaxLevel)
end

function Levels.applyPlayerXp(level: number, xp: number, gain: number)
	return Levels.applyXp(level, xp, gain, Levels.playerXpToNext, nil)
end

return Levels
