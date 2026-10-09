--!strict
-- Rarity tiers shared by gliders, pets and trails.
export type RarityInfo = { Id: string, Name: string, Order: number, Color: string, Dark: string, Light: string }

local list: { RarityInfo } = {
	{ Id = "Common", Name = "Common", Order = 1, Color = "#B9C2CF", Dark = "#5D6675", Light = "#E9EEF5" },
	{ Id = "Uncommon", Name = "Uncommon", Order = 2, Color = "#5BE05B", Dark = "#1E7A1E", Light = "#C8FFC8" },
	{ Id = "Rare", Name = "Rare", Order = 3, Color = "#3FA9FF", Dark = "#1257A8", Light = "#C2E4FF" },
	{ Id = "Epic", Name = "Epic", Order = 4, Color = "#B65CFF", Dark = "#5B1AA8", Light = "#E6C9FF" },
	{ Id = "Legendary", Name = "Legendary", Order = 5, Color = "#FFC53D", Dark = "#A86A00", Light = "#FFF0B8" },
	{ Id = "Mythic", Name = "Mythic", Order = 6, Color = "#FF4FA3", Dark = "#A3115B", Light = "#FFD0E8" },
	{ Id = "Secret", Name = "Secret", Order = 7, Color = "#FF3B3B", Dark = "#7A0A0A", Light = "#FFD2D2" },
}

local byId: { [string]: RarityInfo } = {}
for _, r in list do
	byId[r.Id] = r
end

local Rarity = {}
Rarity.List = list

function Rarity.Get(id: string): RarityInfo
	return byId[id] or byId.Common
end

function Rarity.Exists(id: string): boolean
	return byId[id] ~= nil
end

function Rarity.Order(id: string): number
	return Rarity.Get(id).Order
end

return Rarity
