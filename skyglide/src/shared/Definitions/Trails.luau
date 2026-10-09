--!strict
-- Trails: cosmetic ribbons behind your character and your glider, each with a Wins bonus.
export type Trail = {
	Id: string,
	Name: string,
	Price: number, -- Wins
	WinsBoost: number, -- 0.1 = +10% Wins
	Rarity: string,
	Colors: { string }, -- gradient stops
}

local list: { Trail } = {
	{ Id = "bubble", Name = "Bubble Trail", Price = 100, WinsBoost = 0.05, Rarity = "Common", Colors = { "#BFF7FF", "#FFFFFF" } },
	{ Id = "sunset", Name = "Sunset Trail", Price = 600, WinsBoost = 0.1, Rarity = "Uncommon", Colors = { "#FFB347", "#FF5E62" } },
	{ Id = "ocean", Name = "Ocean Trail", Price = 2500, WinsBoost = 0.2, Rarity = "Rare", Colors = { "#00C6FF", "#0072FF" } },
	{ Id = "ember", Name = "Ember Trail", Price = 25000, WinsBoost = 0.35, Rarity = "Rare", Colors = { "#FFC400", "#FF3D00" } },
	{ Id = "gold", Name = "Gold Trail", Price = 150000, WinsBoost = 0.6, Rarity = "Epic", Colors = { "#FFF3B0", "#FFC53D", "#B8860B" } },
	{ Id = "jolly", Name = "Jolly Trail", Price = 1000000, WinsBoost = 1.0, Rarity = "Epic", Colors = { "#1E1E1E", "#FFFFFF", "#E63946" } },
	{ Id = "frost", Name = "Frost Trail", Price = 8000000, WinsBoost = 1.6, Rarity = "Legendary", Colors = { "#FFFFFF", "#9AE6FF", "#4F7CFF" } },
	{ Id = "aurora", Name = "Aurora Trail", Price = 60000000, WinsBoost = 2.5, Rarity = "Legendary", Colors = { "#7CFFB2", "#6AE3FF", "#B97CFF" } },
	{ Id = "rainbow", Name = "Rainbow Trail", Price = 500000000, WinsBoost = 5, Rarity = "Mythic", Colors = { "#FF4F4F", "#FFC53D", "#5BE05B", "#3FA9FF", "#B65CFF" } },
}

local byId: { [string]: Trail } = {}
for _, t in list do
	byId[t.Id] = t
end

local Trails = {}
Trails.List = list

function Trails.Get(id: string): Trail?
	return byId[id]
end

function Trails.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return Trails
