--!strict
-- Level-up rewards. Reference shows "Lv 3 Reward: <ball>" (CONFIRMED that levels grant orbs).
export type Reward = { Kind: "Ball" | "Ticket" | "Coins" | "Gems", Id: string?, Amount: number? }

local Explicit: { [number]: Reward } = {
	[2] = { Kind = "Ticket", Id = "OrbGacha", Amount = 1 },
	[3] = { Kind = "Ball", Id = "sunny" },
	[4] = { Kind = "Coins", Amount = 300 },
	[5] = { Kind = "Ball", Id = "spring" },
	[6] = { Kind = "Ticket", Id = "OrbGacha", Amount = 1 },
	[7] = { Kind = "Gems", Amount = 25 },
	[8] = { Kind = "Ball", Id = "titan" },
	[10] = { Kind = "Ticket", Id = "AdvancedOrbGacha", Amount = 1 },
}

local LevelRewards = {}

function LevelRewards.For(level: number): Reward
	local explicit = Explicit[level]
	if explicit then
		return explicit
	end
	if level % 5 == 0 then
		return { Kind = "Ticket", Id = "AdvancedOrbGacha", Amount = 1 }
	end
	return { Kind = "Ticket", Id = "OrbGacha", Amount = 1 }
end

return LevelRewards
