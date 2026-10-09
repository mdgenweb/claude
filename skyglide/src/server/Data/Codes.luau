--!strict
-- Redeemable codes (server-only, never replicated). Codes are case-insensitive.
-- Expires = unix seconds, or 0 for never.
local Rewards = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Definitions.Rewards)

export type Code = { Rewards: { Rewards.Reward }, Expires: number }

local Codes: { [string]: Code } = {
	LAUNCH = { Rewards = { { Kind = "Wins", Amount = 50 }, { Kind = "Potion", Id = "skill_potion", Count = 1 } }, Expires = 0 },
	THERMAL = { Rewards = { { Kind = "Potion", Id = "luck_potion", Count = 2 } }, Expires = 0 },
	GLIDE = { Rewards = { { Kind = "Skill", Reps = 300 }, { Kind = "Potion", Id = "wins_potion", Count = 1 } }, Expires = 0 },
}

return Codes
