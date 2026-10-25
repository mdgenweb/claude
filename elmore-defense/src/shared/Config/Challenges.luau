--[[
	Challenges
	Three challenge slots rotate every 30 minutes (deterministic from UTC time). Each slot = world + act + modifier
	+ material reward. This is the main faucet for Glow-Up materials.
]]

local Challenges = {}

Challenges.RotationSeconds = 1800
Challenges.Slots = 3

Challenges.Modifiers = {
	Speedy = { name = "Speedy", description = "Enemies move 35% faster.", enemySpeed = 1.35 },
	Tanky = { name = "Tanky", description = "Enemies have 60% more HP.", enemyHp = 1.6 },
	Broke = { name = "Broke", description = "40% less cash income.", income = 0.6 },
	RaresOnly = { name = "Rares Only", description = "Only Rare units can be placed.", rarityCap = "Rare" },
	GhostTown = { name = "Ghost Town", description = "40% of enemies are hidden.", hiddenChance = 0.4 },
	GlassDoor = { name = "Glass Door", description = "Base HP is only 40.", baseHealth = 40 },
}

Challenges.ModifierOrder = { "Speedy", "Tanky", "Broke", "RaresOnly", "GhostTown", "GlassDoor" }

Challenges.Rewards = {
	{ JoyfulCoupons = 4 },
	{ RainbowSprinkles = 4 },
	{ VoidCores = 1 },
	{ StickerPages = 1 },
	{ JoyfulCoupons = 3, RainbowSprinkles = 2 },
	{ VoidShards = 2 },
}

return Challenges
