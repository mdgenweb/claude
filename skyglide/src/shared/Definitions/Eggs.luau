--!strict
-- Eggs. Hatching is rolled on the server with a weighted RNG (x Luck for rare tiers).
local Pets = require(script.Parent.Pets)

export type EggEntry = { Pet: string, Weight: number }

export type Egg = {
	Id: string,
	Name: string,
	World: number?, -- nil = available in every world
	Price: number, -- Wins per egg (0 when ProductKey is set)
	ProductKey: string?, -- Robux egg (Config/Monetization)
	Pets: { EggEntry },
	Color: string,
	Accent: string,
}

local list: { Egg } = {
	{
		Id = "beach_egg",
		Name = "Beach Egg",
		World = 1,
		Price = 50,
		Color = "#FFE2A8",
		Accent = "#4FC3FF",
		Pets = {
			{ Pet = "sandy_crab", Weight = 60 },
			{ Pet = "sea_pup", Weight = 28 },
			{ Pet = "coral_fox", Weight = 10 },
			{ Pet = "sun_turtle", Weight = 1.9 },
			{ Pet = "golden_gull", Weight = 0.1 },
		},
	},
	{
		Id = "palm_egg",
		Name = "Palm Egg",
		World = 1,
		Price = 500,
		Color = "#8BE07A",
		Accent = "#8B5A2B",
		Pets = {
			{ Pet = "coco_monkey", Weight = 55 },
			{ Pet = "palm_parrot", Weight = 30 },
			{ Pet = "tiki_cat", Weight = 12 },
			{ Pet = "reef_ray", Weight = 2.8 },
			{ Pet = "tropic_phoenix", Weight = 0.2 },
		},
	},
	{
		Id = "breeze_egg",
		Name = "Breeze Egg",
		World = 1,
		Price = 4000,
		Color = "#CDEBFF",
		Accent = "#FFFFFF",
		Pets = {
			{ Pet = "cloud_lamb", Weight = 50 },
			{ Pet = "wind_bunny", Weight = 32 },
			{ Pet = "sky_whale", Weight = 14 },
			{ Pet = "storm_owl", Weight = 3.7 },
			{ Pet = "aurora_dragon", Weight = 0.3 },
		},
	},
	{
		Id = "ember_egg",
		Name = "Ember Egg",
		World = 2,
		Price = 100000,
		Color = "#FF6A00",
		Accent = "#2B2B33",
		Pets = {
			{ Pet = "ember_pup", Weight = 55 },
			{ Pet = "lava_slime", Weight = 30 },
			{ Pet = "ash_bat", Weight = 12 },
			{ Pet = "magma_golem", Weight = 2.8 },
			{ Pet = "fire_drake", Weight = 0.2 },
		},
	},
	{
		Id = "magma_egg",
		Name = "Magma Egg",
		World = 2,
		Price = 2500000,
		Color = "#C2182B",
		Accent = "#FFC400",
		Pets = {
			{ Pet = "cinder_cat", Weight = 52 },
			{ Pet = "smoke_fox", Weight = 32 },
			{ Pet = "obsidian_owl", Weight = 13 },
			{ Pet = "volcano_ray", Weight = 2.95 },
			{ Pet = "sun_phoenix", Weight = 0.05 },
		},
	},
	{
		Id = "pirate_egg",
		Name = "Pirate Egg",
		World = 3,
		Price = 3000000,
		Color = "#F2D8A7",
		Accent = "#A0522D",
		Pets = {
			{ Pet = "deck_rat", Weight = 55 },
			{ Pet = "cannon_crab", Weight = 30 },
			{ Pet = "captain_parrot", Weight = 12 },
			{ Pet = "ghost_shark", Weight = 2.8 },
			{ Pet = "kraken_jr", Weight = 0.2 },
		},
	},
	{
		Id = "kraken_egg",
		Name = "Kraken Egg",
		World = 3,
		Price = 75000000,
		Color = "#7A3FBF",
		Accent = "#2FD3C9",
		Pets = {
			{ Pet = "skull_slime", Weight = 52 },
			{ Pet = "treasure_mimic", Weight = 32 },
			{ Pet = "mermaid_cat", Weight = 13 },
			{ Pet = "storm_kraken", Weight = 2.95 },
			{ Pet = "galleon_dragon", Weight = 0.05 },
		},
	},
	{
		Id = "snow_egg",
		Name = "Snow Egg",
		World = 4,
		Price = 75000000,
		Color = "#F2F7FF",
		Accent = "#9AE6FF",
		Pets = {
			{ Pet = "snow_bunny", Weight = 55 },
			{ Pet = "penguin", Weight = 30 },
			{ Pet = "ice_fox", Weight = 12 },
			{ Pet = "frost_yeti", Weight = 2.8 },
			{ Pet = "crystal_dragon", Weight = 0.2 },
		},
	},
	{
		Id = "aurora_egg",
		Name = "Aurora Egg",
		World = 4,
		Price = 1900000000,
		Color = "#7CFFB2",
		Accent = "#B97CFF",
		Pets = {
			{ Pet = "aurora_owl", Weight = 52 },
			{ Pet = "glacier_whale", Weight = 32 },
			{ Pet = "polar_bear", Weight = 13 },
			{ Pet = "blizzard_wolf", Weight = 2.95 },
			{ Pet = "northern_phoenix", Weight = 0.05 },
		},
	},
	{
		Id = "overlord_egg",
		Name = "Overlord Egg",
		World = nil,
		Price = 0,
		ProductKey = "OverlordEgg",
		Color = "#14141F",
		Accent = "#39FF14",
		Pets = {
			{ Pet = "glitch_bunny", Weight = 60 },
			{ Pet = "neon_wolf", Weight = 30 },
			{ Pet = "overlord_cat", Weight = 9 },
			{ Pet = "admin_dragon", Weight = 1 },
		},
	},
}

local byId: { [string]: Egg } = {}
for _, egg in list do
	assert(byId[egg.Id] == nil, "duplicate egg " .. egg.Id)
	byId[egg.Id] = egg
	for _, entry in egg.Pets do
		assert(Pets.Get(entry.Pet) ~= nil, "egg " .. egg.Id .. " references unknown pet " .. entry.Pet)
	end
end

local Eggs = {}
Eggs.List = list

function Eggs.Get(id: string): Egg?
	return byId[id]
end

function Eggs.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function Eggs.ForWorld(world: number): { Egg }
	local out = {}
	for _, egg in list do
		if egg.World == world or egg.World == nil then
			table.insert(out, egg)
		end
	end
	return out
end

-- Odds (0..1) for each entry after Luck: every tier above the egg's most common tier has its
-- weight multiplied by `luck`.
function Eggs.Odds(egg: Egg, luck: number): { { Pet: string, Chance: number } }
	local Rarity = require(script.Parent.Parent.Config.Rarity)
	local minOrder = math.huge
	for _, entry in egg.Pets do
		local pet = Pets.Get(entry.Pet)
		if pet then
			minOrder = math.min(minOrder, Rarity.Order(pet.Rarity))
		end
	end
	local total = 0
	local weights = {}
	for i, entry in egg.Pets do
		local pet = Pets.Get(entry.Pet)
		local w = entry.Weight
		if pet and Rarity.Order(pet.Rarity) > minOrder then
			w *= math.max(1, luck)
		end
		weights[i] = w
		total += w
	end
	local out = {}
	for i, entry in egg.Pets do
		table.insert(out, { Pet = entry.Pet, Chance = if total > 0 then weights[i] / total else 0 })
	end
	return out
end

return Eggs
