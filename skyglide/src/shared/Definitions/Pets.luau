--!strict
-- Pets (ORIGINAL roster). The reference shows pets as "xN Skill" (LIKELY); we store SkillBoost = N - 1
-- so a pet shown as x2 has SkillBoost 1. Equipped pets add up:
--   Skill multiplier from pets = 1 + sum(SkillBoost) ; Wins multiplier from pets = 1 + sum(WinsBoost)
-- Visuals are built from parts by Visual/PetFactory (no uploaded meshes).
export type PetVisual = {
	Template: string, -- "Critter" | "Bird" | "Blob" | "Fish" | "Dragon" | "Crab" | "Bot"
	Body: string,
	Accent: string,
	Ears: string?, -- "Pointy" | "Round" | "Long" | "None"
	Wings: boolean?,
	Horns: boolean?,
	Glow: boolean?,
}

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string,
	SkillBoost: number, -- 1 = shown as "x2 Skill"
	WinsBoost: number,
	Exclusive: boolean?, -- not in eggs (starter pack, daily, gifts)
	Visual: PetVisual,
}

local list: { Pet } = {}
local byId: { [string]: Pet } = {}

local function add(id: string, name: string, rarity: string, skill: number, wins: number, visual: PetVisual, exclusive: boolean?)
	assert(byId[id] == nil, "duplicate pet " .. id)
	local p: Pet = { Id = id, Name = name, Rarity = rarity, SkillBoost = skill, WinsBoost = wins, Visual = visual, Exclusive = exclusive }
	table.insert(list, p)
	byId[id] = p
end

local function v(template: string, body: string, accent: string, ears: string?, wings: boolean?, horns: boolean?, glow: boolean?): PetVisual
	return { Template = template, Body = body, Accent = accent, Ears = ears, Wings = wings, Horns = horns, Glow = glow }
end

-- World 1 eggs
add("sandy_crab", "Sandy Crab", "Common", 1, 0, v("Crab", "#FF8A5B", "#FFD1B8"))
add("sea_pup", "Sea Pup", "Uncommon", 1.5, 0, v("Critter", "#9ED8FF", "#FFFFFF", "Round"))
add("coral_fox", "Coral Fox", "Rare", 3, 0.05, v("Critter", "#FF7F50", "#FFF1E0", "Pointy"))
add("sun_turtle", "Sun Turtle", "Epic", 5, 0.1, v("Blob", "#7BD36B", "#FFD84A"))
add("golden_gull", "Golden Gull", "Legendary", 10, 0.25, v("Bird", "#FFD447", "#FFFFFF", nil, true, nil, true))

add("coco_monkey", "Coco Monkey", "Common", 3, 0, v("Critter", "#8B5A2B", "#F2D3A2", "Round"))
add("palm_parrot", "Palm Parrot", "Uncommon", 4, 0, v("Bird", "#2ECC71", "#FF4136", nil, true))
add("tiki_cat", "Tiki Cat", "Rare", 6, 0.05, v("Critter", "#C68642", "#3B2414", "Pointy"))
add("reef_ray", "Reef Ray", "Epic", 9, 0.1, v("Fish", "#3FA9FF", "#B5F1FF"))
add("tropic_phoenix", "Tropic Phoenix", "Legendary", 15, 0.3, v("Bird", "#FF6A3D", "#FFE066", nil, true, nil, true))

add("cloud_lamb", "Cloud Lamb", "Common", 6, 0, v("Critter", "#FFFFFF", "#B9C7D9", "Long"))
add("wind_bunny", "Wind Bunny", "Uncommon", 8, 0.05, v("Critter", "#CDEBFF", "#FF9EC7", "Long"))
add("sky_whale", "Sky Whale", "Rare", 11, 0.1, v("Fish", "#6C8CFF", "#E0E8FF"))
add("storm_owl", "Storm Owl", "Epic", 15, 0.15, v("Bird", "#5B5F8A", "#FFE45E", "Pointy", true))
add("aurora_dragon", "Aurora Dragon", "Legendary", 25, 0.4, v("Dragon", "#7CFFB2", "#B97CFF", nil, true, true, true))

-- World 2 eggs
add("ember_pup", "Ember Pup", "Common", 20, 0.05, v("Critter", "#FF6A00", "#3A1A0A", "Pointy"))
add("lava_slime", "Lava Slime", "Uncommon", 25, 0.05, v("Blob", "#FF3D00", "#FFC400", nil, nil, nil, true))
add("ash_bat", "Ash Bat", "Rare", 30, 0.1, v("Bird", "#3A3A44", "#FF5A1F", "Pointy", true))
add("magma_golem", "Magma Golem", "Epic", 40, 0.15, v("Bot", "#4A2A1A", "#FF7A1A", nil, nil, nil, true))
add("fire_drake", "Fire Drake", "Legendary", 60, 0.4, v("Dragon", "#E8261F", "#FFB300", nil, true, true, true))

add("cinder_cat", "Cinder Cat", "Common", 50, 0.05, v("Critter", "#2B2B33", "#FF7A1A", "Pointy"))
add("smoke_fox", "Smoke Fox", "Uncommon", 60, 0.1, v("Critter", "#8C8C99", "#FFB36B", "Pointy"))
add("obsidian_owl", "Obsidian Owl", "Rare", 70, 0.1, v("Bird", "#15151C", "#B44DFF", "Pointy", true, nil, true))
add("volcano_ray", "Volcano Ray", "Epic", 90, 0.2, v("Fish", "#C2182B", "#FFC400", nil, nil, nil, true))
add("sun_phoenix", "Sun Phoenix", "Mythic", 140, 0.6, v("Bird", "#FFB300", "#FF3D00", nil, true, nil, true))

-- World 3 eggs
add("deck_rat", "Deck Rat", "Common", 150, 0.1, v("Critter", "#8C7A6B", "#F2C9C9", "Round"))
add("cannon_crab", "Cannon Crab", "Uncommon", 180, 0.1, v("Crab", "#B22222", "#2B2B2B"))
add("captain_parrot", "Captain Parrot", "Rare", 220, 0.15, v("Bird", "#E63946", "#2A9D8F", nil, true))
add("ghost_shark", "Ghost Shark", "Epic", 280, 0.2, v("Fish", "#BFF7FF", "#7FDBFF", nil, nil, nil, true))
add("kraken_jr", "Kraken Jr.", "Legendary", 400, 0.5, v("Blob", "#7A3FBF", "#2FD3C9", nil, nil, true, true))

add("skull_slime", "Skull Slime", "Common", 350, 0.1, v("Blob", "#E8E3D3", "#2B2B2B"))
add("treasure_mimic", "Treasure Mimic", "Uncommon", 420, 0.15, v("Bot", "#A0522D", "#FFD700"))
add("mermaid_cat", "Mermaid Cat", "Rare", 500, 0.2, v("Critter", "#2FD3C9", "#FF8FC8", "Pointy"))
add("storm_kraken", "Storm Kraken", "Epic", 650, 0.3, v("Fish", "#3D2B7A", "#7FE7FF", nil, nil, true, true))
add("galleon_dragon", "Galleon Dragon", "Mythic", 900, 0.8, v("Dragon", "#1E3A5F", "#FFD700", nil, true, true, true))

-- World 4 eggs
add("snow_bunny", "Snow Bunny", "Common", 1000, 0.15, v("Critter", "#FFFFFF", "#A8D8FF", "Long"))
add("penguin", "Penguin", "Uncommon", 1200, 0.2, v("Bird", "#1E2533", "#FFFFFF"))
add("ice_fox", "Ice Fox", "Rare", 1500, 0.25, v("Critter", "#BDEFFF", "#FFFFFF", "Pointy", nil, nil, true))
add("frost_yeti", "Frost Yeti", "Epic", 1900, 0.35, v("Critter", "#F2F7FF", "#7FA7FF", "Round"))
add("crystal_dragon", "Crystal Dragon", "Legendary", 2600, 0.7, v("Dragon", "#9AE6FF", "#FFFFFF", nil, true, true, true))

add("aurora_owl", "Aurora Owl", "Common", 2200, 0.2, v("Bird", "#7CFFB2", "#B97CFF", "Pointy", true))
add("glacier_whale", "Glacier Whale", "Uncommon", 2700, 0.25, v("Fish", "#BDEFFF", "#4F7CFF"))
add("polar_bear", "Polar Bear", "Rare", 3300, 0.3, v("Critter", "#FFFFFF", "#D8E6F2", "Round"))
add("blizzard_wolf", "Blizzard Wolf", "Epic", 4200, 0.45, v("Critter", "#C9D6E8", "#2F6BFF", "Pointy", nil, nil, true))
add("northern_phoenix", "Northern Phoenix", "Mythic", 6000, 1.2, v("Bird", "#6AE3FF", "#7CFFB2", nil, true, nil, true))

-- Robux egg (available in every world)
add("glitch_bunny", "Glitch Bunny", "Epic", 40, 0.2, v("Critter", "#00FF9C", "#FF00E6", "Long", nil, nil, true))
add("neon_wolf", "Neon Wolf", "Legendary", 80, 0.4, v("Critter", "#2BFFF1", "#1A1A2E", "Pointy", nil, nil, true))
add("overlord_cat", "Overlord Cat", "Mythic", 200, 0.8, v("Critter", "#14141F", "#39FF14", "Pointy", true, true, true))
add("admin_dragon", "Admin Dragon", "Secret", 600, 2.0, v("Dragon", "#39FF14", "#0B0B12", nil, true, true, true))

-- Exclusives
add("starlight_unicat", "Starlight Unicat", "Legendary", 20, 0.25, v("Critter", "#FFFFFF", "#FF9EF5", "Pointy", nil, true, true), true)
add("daily_drake", "Daily Drake", "Epic", 8, 0.15, v("Dragon", "#4FC3FF", "#FFE45E", nil, true, true), true)
add("gift_bear", "Gift Bear", "Rare", 4, 0.1, v("Critter", "#C68642", "#FF4F7B", "Round"), true)

local Pets = {}
Pets.List = list

function Pets.Get(id: string): Pet?
	return byId[id]
end

function Pets.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return Pets
