--!strict
-- Throwables. ORIGINAL DESIGN: paper-style gliders instead of stones. World 1 follows the
-- reference's price/power curve shape (CONFIRMED stone table: +1/0 ... +3.5K/40K Wins) with our
-- own items and slightly different numbers. Each glider pays
-- "+N Skill" for every thermal ring it rides through (x the player's Skill multiplier), the same
-- role the reference's stones play per bounce. Bought with Wins on the pedestal row in each world.
export type GliderVisual = {
	Shape: string, -- template in Visual/GliderFactory
	Primary: string,
	Secondary: string,
	Glow: boolean?,
}

export type Glider = {
	Id: string,
	Name: string,
	World: number,
	Order: number,
	Price: number, -- Wins
	SkillPerRing: number,
	Rarity: string,
	Visual: GliderVisual,
}

local list: { Glider } = {}
local byId: { [string]: Glider } = {}

local function add(world: number, id: string, name: string, price: number, skill: number, rarity: string, shape: string, primary: string, secondary: string, glow: boolean?)
	local g: Glider = {
		Id = id,
		Name = name,
		World = world,
		Order = #list + 1,
		Price = price,
		SkillPerRing = skill,
		Rarity = rarity,
		Visual = { Shape = shape, Primary = primary, Secondary = secondary, Glow = glow },
	}
	assert(byId[id] == nil, "duplicate glider " .. id)
	table.insert(list, g)
	byId[id] = g
end

-- World 1: Sunny Isles
add(1, "paper_dart", "Paper Dart", 0, 1, "Common", "Dart", "#F4F4F4", "#C9D3E0")
add(1, "notebook_glider", "Notebook Glider", 2, 3, "Common", "Wide", "#FFF6C9", "#7FB2FF")
add(1, "palm_leaf", "Palm Leaf", 12, 6, "Uncommon", "Leaf", "#5BD15B", "#2E8B2E")
add(1, "gull_feather", "Gull Feather", 45, 14, "Uncommon", "Feather", "#FFFFFF", "#9AA6B5")
add(1, "balsa_wing", "Balsa Wing", 150, 30, "Rare", "Wide", "#E8C48A", "#B98A4A")
add(1, "beach_kite", "Beach Kite", 520, 80, "Rare", "Kite", "#FF6F61", "#FFD447")
add(1, "origami_crane", "Origami Crane", 1500, 200, "Epic", "Crane", "#FF8FC8", "#FFFFFF")
add(1, "coral_glider", "Coral Glider", 4600, 520, "Epic", "Dart", "#FF7F6B", "#FFC2A8")
add(1, "sunset_sail", "Sunset Sail", 14000, 1300, "Legendary", "Kite", "#FF9A3D", "#B24BFF", true)
add(1, "breeze_jet", "Breeze Jet", 40000, 3600, "Legendary", "Jet", "#7FE7FF", "#FFFFFF", true)

-- World 2: Ember Crater
add(2, "ash_dart", "Ash Dart", 60000, 25000, "Rare", "Dart", "#5A5A5A", "#FF7A1A")
add(2, "cinder_leaf", "Cinder Leaf", 150000, 40000, "Rare", "Leaf", "#FF6A00", "#3A1A0A", true)
add(2, "magma_kite", "Magma Kite", 400000, 65000, "Epic", "Kite", "#FF3D00", "#FFC400", true)
add(2, "obsidian_crane", "Obsidian Crane", 1000000, 100000, "Epic", "Crane", "#1B1B24", "#B44DFF", true)
add(2, "phoenix_feather", "Phoenix Feather", 2500000, 160000, "Legendary", "Feather", "#FF5A1F", "#FFE066", true)
add(2, "dragon_wing", "Dragon Wing", 6500000, 250000, "Mythic", "Bat", "#C2182B", "#FF9E3D", true)

-- World 3: Buccaneer Bay
add(3, "map_scroll", "Treasure Map", 1500000, 1500000, "Rare", "Wide", "#F2D8A7", "#A0522D")
add(3, "sail_cloth", "Sail Cloth", 3600000, 2400000, "Epic", "Kite", "#FFFFFF", "#1E1E1E")
add(3, "parrot_plume", "Parrot Plume", 9600000, 3800000, "Epic", "Feather", "#2ECC40", "#FF4136", true)
add(3, "doubloon_dart", "Doubloon Dart", 24000000, 6000000, "Legendary", "Dart", "#FFD700", "#B8860B", true)
add(3, "kraken_fin", "Kraken Fin", 60000000, 9500000, "Legendary", "Bat", "#7A3FBF", "#2FD3C9", true)
add(3, "ghost_galleon", "Ghost Galleon", 160000000, 15000000, "Mythic", "Crane", "#BFF7FF", "#3FA9FF", true)

-- World 4: Frost Peaks
add(4, "snowflake", "Snowflake", 36000000, 50000000, "Rare", "Star", "#E8FBFF", "#9AE6FF", true)
add(4, "icicle_dart", "Icicle Dart", 90000000, 80000000, "Epic", "Dart", "#BDEFFF", "#5FC8FF", true)
add(4, "penguin_wing", "Penguin Wing", 240000000, 130000000, "Epic", "Wide", "#1E2533", "#FFFFFF")
add(4, "yeti_kite", "Yeti Kite", 600000000, 200000000, "Legendary", "Kite", "#F2F7FF", "#7FA7FF", true)
add(4, "aurora_crane", "Aurora Crane", 1500000000, 320000000, "Legendary", "Crane", "#7CFFB2", "#B97CFF", true)
add(4, "comet_jet", "Comet Jet", 3900000000, 500000000, "Mythic", "Jet", "#FFFFFF", "#6AE3FF", true)

local Gliders = {}
Gliders.List = list
Gliders.Default = "paper_dart"

function Gliders.Get(id: string): Glider?
	return byId[id]
end

function Gliders.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function Gliders.ForWorld(world: number): { Glider }
	local out = {}
	for _, g in list do
		if g.World == world then
			table.insert(out, g)
		end
	end
	return out
end

-- Highest SkillPerRing among owned gliders (used by relics).
function Gliders.BestOwned(owned: { [string]: boolean }): Glider
	local best = byId[Gliders.Default]
	for id in owned do
		local g = byId[id]
		if g and g.SkillPerRing > best.SkillPerRing then
			best = g
		end
	end
	return best
end

return Gliders
