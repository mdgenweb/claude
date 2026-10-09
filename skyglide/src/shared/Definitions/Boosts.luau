--!strict
-- Timed potions. Using one adds its duration to the matching active boost (stacks in time, not
-- in strength). Expiry is stored as a Unix timestamp, so boosts keep ticking while offline.
export type Boost = {
	Id: string,
	Name: string,
	Stat: string, -- "Skill" | "Wins" | "Luck"
	Multiplier: number,
	Duration: number, -- seconds per potion
	Color: string,
}

local list: { Boost } = {
	{ Id = "skill_potion", Name = "2x Skill Potion", Stat = "Skill", Multiplier = 2, Duration = 10 * 60, Color = "#FFD447" },
	{ Id = "wins_potion", Name = "2x Wins Potion", Stat = "Wins", Multiplier = 2, Duration = 10 * 60, Color = "#5BE05B" },
	{ Id = "luck_potion", Name = "2x Luck Potion", Stat = "Luck", Multiplier = 2, Duration = 10 * 60, Color = "#B65CFF" },
}

local byId: { [string]: Boost } = {}
for _, b in list do
	byId[b.Id] = b
end

local Boosts = {}
Boosts.List = list
Boosts.MaxStackSeconds = 24 * 3600

function Boosts.Get(id: string): Boost?
	return byId[id]
end

function Boosts.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return Boosts
