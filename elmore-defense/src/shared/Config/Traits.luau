--[[
	Traits
	Rerolled with Void Shards at the Void Rift. Odds sum to exactly 100.
	`mods` keys: damage, range, speed, cost (reduction), bounty (kill cash bonus), detect (hidden), stunChance, stunTime
]]

export type Trait = {
	id: string,
	name: string,
	tier: string,
	weight: number,
	description: string,
	mods: { [string]: any },
}

local Tiers = {
	Common = { order = 1, color = Color3.fromRGB(196, 196, 206), label = "Common" },
	Uncommon = { order = 2, color = Color3.fromRGB(79, 183, 242), label = "Uncommon" },
	Rare = { order = 3, color = Color3.fromRGB(176, 108, 255), label = "Rare" },
	Epic = { order = 4, color = Color3.fromRGB(255, 120, 196), label = "Epic" },
	Legendary = { order = 5, color = Color3.fromRGB(255, 196, 46), label = "Legendary" },
	Mythic = { order = 6, color = Color3.fromRGB(255, 255, 255), label = "Mythic", rainbow = true },
}

local list: { Trait } = {
	{
		id = "Snappy",
		name = "Snappy",
		tier = "Common",
		weight = 17,
		description = "+8% attack speed",
		mods = { speed = 0.08 },
	},
	{
		id = "EagleEyed",
		name = "Eagle-Eyed",
		tier = "Common",
		weight = 17,
		description = "+8% range",
		mods = { range = 0.08 },
	},
	{
		id = "PennyPincher",
		name = "Penny Pincher",
		tier = "Uncommon",
		weight = 12,
		description = "costs 12% less",
		mods = { cost = 0.12 },
	},
	{
		id = "Hyperactive",
		name = "Hyperactive",
		tier = "Uncommon",
		weight = 12,
		description = "+14% attack speed",
		mods = { speed = 0.14 },
	},
	{
		id = "ToughCookie",
		name = "Tough Cookie",
		tier = "Uncommon",
		weight = 11,
		description = "+15% damage",
		mods = { damage = 0.15 },
	},
	{
		id = "HallMonitor",
		name = "Hall Monitor",
		tier = "Rare",
		weight = 7,
		description = "+18% range, sees hidden enemies",
		mods = { range = 0.18, detect = true },
	},
	{
		id = "Dude",
		name = "Dude!",
		tier = "Rare",
		weight = 6,
		description = "+10% damage, +15% range",
		mods = { damage = 0.10, range = 0.15 },
	},
	{
		id = "NerdMode",
		name = "Nerd Mode",
		tier = "Rare",
		weight = 5.5,
		description = "+25% damage",
		mods = { damage = 0.25 },
	},
	{
		id = "Moneybags",
		name = "Moneybags",
		tier = "Epic",
		weight = 4,
		description = "+5% damage, kills pay +50% cash",
		mods = { damage = 0.05, bounty = 0.5 },
	},
	{
		id = "Overclocked",
		name = "Overclocked",
		tier = "Epic",
		weight = 3.5,
		description = "+8% damage, +22% attack speed",
		mods = { damage = 0.08, speed = 0.22 },
	},
	{
		id = "Mischief",
		name = "Mischief",
		tier = "Epic",
		weight = 2.5,
		description = "+12% damage, 15% chance to stun",
		mods = { damage = 0.12, stunChance = 0.15, stunTime = 0.6 },
	},
	{
		id = "WonderfullyWeird",
		name = "Wonderfully Weird",
		tier = "Epic",
		weight = 1.5,
		description = "+40% damage, +15% attack speed",
		mods = { damage = 0.40, speed = 0.15 },
	},
	{
		id = "ElmoreLegend",
		name = "Elmore Legend",
		tier = "Legendary",
		weight = 0.8,
		description = "+30% damage, +15% range, +10% attack speed",
		mods = { damage = 0.30, range = 0.15, speed = 0.10 },
	},
	{
		id = "Amazing",
		name = "AMAZING",
		tier = "Mythic",
		weight = 0.2,
		description = "+200% damage, +20% range, +20% attack speed",
		mods = { damage = 2.00, range = 0.20, speed = 0.20 },
	},
}

local byId: { [string]: Trait } = {}
for _, trait in list do
	byId[trait.id] = trait
end

local Traits = {
	list = list,
	byId = byId,
	Tiers = Tiers,
	-- VIP pass luck: multipliers per tier (renormalised against Common traits)
	VipTierMultipliers = { Epic = 1.5, Legendary = 2, Mythic = 2 },
}

function Traits.get(id: string?): Trait?
	return if id then byId[id] else nil
end

function Traits.tierOf(id: string?)
	local trait = Traits.get(id)
	return if trait then Tiers[trait.tier] else nil
end

return Traits
