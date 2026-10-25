--[[
	Rarities
	Display + gameplay data for each unit rarity. Summon odds live in Banners.luau.
]]

export type Rarity = {
	id: string,
	order: number,
	stars: number,
	displayName: string,
	color: Color3,
	dark: Color3,
	maxPlaced: number,
	rainbow: boolean?,
	glitch: boolean?,
	yearbookReward: number,
}

local Rarities = {
	Rare = {
		id = "Rare",
		order = 1,
		stars = 3,
		displayName = "Rare",
		color = Color3.fromRGB(79, 183, 242),
		dark = Color3.fromRGB(32, 98, 168),
		maxPlaced = 5,
		yearbookReward = 25,
	},
	Epic = {
		id = "Epic",
		order = 2,
		stars = 4,
		displayName = "Epic",
		color = Color3.fromRGB(176, 108, 255),
		dark = Color3.fromRGB(96, 46, 168),
		maxPlaced = 4,
		yearbookReward = 75,
	},
	Legendary = {
		id = "Legendary",
		order = 3,
		stars = 5,
		displayName = "Legendary",
		color = Color3.fromRGB(255, 196, 46),
		dark = Color3.fromRGB(196, 112, 10),
		maxPlaced = 3,
		yearbookReward = 200,
	},
	Mythic = {
		id = "Mythic",
		order = 4,
		stars = 6,
		displayName = "Mythic",
		color = Color3.fromRGB(255, 92, 170),
		dark = Color3.fromRGB(150, 30, 110),
		maxPlaced = 3,
		rainbow = true,
		yearbookReward = 500,
	},
	Secret = {
		id = "Secret",
		order = 5,
		stars = 7,
		displayName = "Secret",
		color = Color3.fromRGB(40, 24, 64),
		dark = Color3.fromRGB(10, 6, 20),
		maxPlaced = 2,
		glitch = true,
		yearbookReward = 1000,
	},
}

local ordered = {}
for _, rarity in Rarities do
	table.insert(ordered, rarity)
end
table.sort(ordered, function(a, b)
	return a.order < b.order
end)

local module = {
	byId = Rarities :: { [string]: Rarity },
	ordered = ordered :: { Rarity },
	RAINBOW = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 84, 84)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 166, 48)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 232, 64)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(96, 226, 108)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(72, 190, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(150, 110, 255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 96, 200)),
	}),
}

function module.get(id: string): Rarity
	return Rarities[id] or Rarities.Rare
end

function module.compare(a: string, b: string): number
	return module.get(a).order - module.get(b).order
end

return module
