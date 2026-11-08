--!strict
-- Rarity tiers shared by ingredients, potions and skins.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Rarity = {
	id: RarityId,
	order: number,
	color: Color3,
	glow: Color3,
	discoverXp: number,
	discoverCoins: number,
}

local Rarity: { [string]: Rarity } = {
	Common = {
		id = "Common",
		order = 1,
		color = Color3.fromRGB(205, 212, 222),
		glow = Color3.fromRGB(255, 255, 255),
		discoverXp = 60,
		discoverCoins = 25,
	},
	Uncommon = {
		id = "Uncommon",
		order = 2,
		color = Color3.fromRGB(107, 255, 142),
		glow = Color3.fromRGB(160, 255, 190),
		discoverXp = 120,
		discoverCoins = 50,
	},
	Rare = {
		id = "Rare",
		order = 3,
		color = Color3.fromRGB(79, 168, 255),
		glow = Color3.fromRGB(150, 205, 255),
		discoverXp = 220,
		discoverCoins = 90,
	},
	Epic = {
		id = "Epic",
		order = 4,
		color = Color3.fromRGB(179, 107, 255),
		glow = Color3.fromRGB(215, 170, 255),
		discoverXp = 400,
		discoverCoins = 160,
	},
	Legendary = {
		id = "Legendary",
		order = 5,
		color = Color3.fromRGB(255, 177, 59),
		glow = Color3.fromRGB(255, 220, 140),
		discoverXp = 700,
		discoverCoins = 300,
	},
	Mythic = {
		id = "Mythic",
		order = 6,
		color = Color3.fromRGB(255, 79, 122),
		glow = Color3.fromRGB(255, 160, 190),
		discoverXp = 1500,
		discoverCoins = 1000,
	},
}

return Rarity
