--!strict
-- Playtime gifts (per session) and the 7-day daily reward track.
-- Reward kinds:
--   { Kind = "Wins", Amount }      x the current world's zone Wins scale
--   { Kind = "Skill", Reps }       = Reps training reps on your best unlocked pad (x multipliers)
--   { Kind = "Potion", Id, Count }
--   { Kind = "Pet", Id }
export type Reward = { Kind: string, Amount: number?, Reps: number?, Id: string?, Count: number? }

export type Gift = { Index: number, Minutes: number, Reward: Reward }

local gifts: { Gift } = {}
local GIFT_MINUTES = { 1, 3, 5, 8, 12, 16, 20, 25, 30, 40, 50, 60 }
local GIFT_REWARDS: { Reward } = {
	{ Kind = "Wins", Amount = 10 },
	{ Kind = "Skill", Reps = 60 },
	{ Kind = "Potion", Id = "skill_potion", Count = 1 },
	{ Kind = "Wins", Amount = 40 },
	{ Kind = "Skill", Reps = 200 },
	{ Kind = "Potion", Id = "luck_potion", Count = 1 },
	{ Kind = "Wins", Amount = 120 },
	{ Kind = "Potion", Id = "wins_potion", Count = 1 },
	{ Kind = "Skill", Reps = 600 },
	{ Kind = "Wins", Amount = 400 },
	{ Kind = "Potion", Id = "skill_potion", Count = 2 },
	{ Kind = "Pet", Id = "gift_bear" },
}
for i, minutes in GIFT_MINUTES do
	table.insert(gifts, { Index = i, Minutes = minutes, Reward = GIFT_REWARDS[i] })
end

local daily: { Reward } = {
	{ Kind = "Wins", Amount = 25 },
	{ Kind = "Potion", Id = "skill_potion", Count = 1 },
	{ Kind = "Wins", Amount = 80 },
	{ Kind = "Potion", Id = "luck_potion", Count = 1 },
	{ Kind = "Skill", Reps = 500 },
	{ Kind = "Potion", Id = "wins_potion", Count = 2 },
	{ Kind = "Pet", Id = "daily_drake" },
}

return {
	Gifts = gifts,
	Daily = daily,
}
