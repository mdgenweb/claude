--!strict
-- Explosions: played when a ball is destroyed at the end of a round (owner's equipped one).
-- Flyers: carry the winning ball to the losing player for the heart-break finisher.
-- Both are purely cosmetic (LIKELY per research) and tradable (CONFIRMED badge).
export type CosmeticKind = "Explosion" | "Flyer"

export type CosmeticDefinition = {
	Id: string,
	Kind: CosmeticKind,
	DisplayName: string,
	Description: string,
	Rarity: string,
	Default: boolean?, -- owned by everyone, never dropped by crates
	Event: string?,
	Style: string, -- renderer key in client VFX/Explosions or VFX/Flyers
	Colors: { string },
	Tradable: boolean,
}

local Definitions: { [string]: CosmeticDefinition } = {}
local Ordered: { CosmeticDefinition } = {}

local function define(kind: CosmeticKind, id: string, d: {
	DisplayName: string,
	Description: string,
	Rarity: string,
	Style: string,
	Colors: { string },
	Default: boolean?,
	Event: string?,
})
	local key = kind .. ":" .. id
	assert(Definitions[key] == nil, "duplicate cosmetic " .. key)
	local def: CosmeticDefinition = {
		Id = id,
		Kind = kind,
		DisplayName = d.DisplayName,
		Description = d.Description,
		Rarity = d.Rarity,
		Default = d.Default,
		Event = d.Event,
		Style = d.Style,
		Colors = d.Colors,
		Tradable = d.Default ~= true,
	}
	Definitions[key] = def
	table.insert(Ordered, def)
end

---------------------------------------------------------------------------- Explosions
define("Explosion", "classic", {
	DisplayName = "Classic Pop",
	Description = "A punchy orange burst.",
	Rarity = "Uncommon",
	Default = true,
	Style = "Burst",
	Colors = { "#FFB347", "#FF5E1A", "#3A3A3A" },
})
define("Explosion", "confetti", {
	DisplayName = "Confetti",
	Description = "Party time. Paper confetti everywhere.",
	Rarity = "Uncommon",
	Style = "Confetti",
	Colors = { "#FF4F7B", "#4FC3FF", "#FFE14D", "#7CFF6B" },
})
define("Explosion", "bubble", {
	DisplayName = "Bubble Pop",
	Description = "Pops into a cloud of soap bubbles.",
	Rarity = "Uncommon",
	Style = "Bubbles",
	Colors = { "#BDF3FF", "#FFFFFF", "#9FD8FF" },
})
define("Explosion", "pixel", {
	DisplayName = "Pixel Burst",
	Description = "Shatters into retro pixels.",
	Rarity = "Uncommon",
	Style = "Pixels",
	Colors = { "#00E5FF", "#FF2BD6", "#FFFFFF" },
})
define("Explosion", "ink", {
	DisplayName = "Ink Splash",
	Description = "A splash of thick black ink.",
	Rarity = "Rare",
	Style = "Splash",
	Colors = { "#14141C", "#3D3D52", "#7A7A99" },
})
define("Explosion", "frostbite", {
	DisplayName = "Frostbite",
	Description = "Freezes and cracks into ice shards.",
	Rarity = "Rare",
	Style = "Shards",
	Colors = { "#CFF6FF", "#7FDBFF", "#FFFFFF" },
})
define("Explosion", "supernova", {
	DisplayName = "Supernova",
	Description = "A blinding white flash and a stellar shockwave.",
	Rarity = "Epic",
	Style = "Nova",
	Colors = { "#FFFFFF", "#FFE9A8", "#7A5CFF" },
})
define("Explosion", "thunder", {
	DisplayName = "Thunderclap",
	Description = "Struck by lightning from above.",
	Rarity = "Epic",
	Style = "Thunder",
	Colors = { "#FFF27A", "#8CA8FF", "#FFFFFF" },
})
define("Explosion", "blackhole", {
	DisplayName = "Black Hole",
	Description = "Collapses into a swirling singularity.",
	Rarity = "Legendary",
	Style = "Implode",
	Colors = { "#0A0012", "#9D4DFF", "#FF7BD5" },
})
define("Explosion", "pumpkinpop", {
	DisplayName = "Pumpkin Pop",
	Description = "Bursts into pumpkin chunks and embers.",
	Rarity = "Epic",
	Event = "HarvestMoon",
	Style = "Burst",
	Colors = { "#FF8C1A", "#3E8E1E", "#FFD08A" },
})

---------------------------------------------------------------------------- Flyers
define("Flyer", "basic", {
	DisplayName = "Basic Toss",
	Description = "The winning orb flies straight at its target.",
	Rarity = "Uncommon",
	Default = true,
	Style = "Toss",
	Colors = { "#FFFFFF", "#BFD9FF" },
})
define("Flyer", "paperplane", {
	DisplayName = "Paper Plane",
	Description = "Folded and thrown with care.",
	Rarity = "Uncommon",
	Style = "PaperPlane",
	Colors = { "#F4F6FA", "#C9CED8" },
})
define("Flyer", "kite", {
	DisplayName = "Kite",
	Description = "Rides the breeze with a ribbon tail.",
	Rarity = "Uncommon",
	Style = "Kite",
	Colors = { "#FF4F7B", "#FFE14D", "#4FC3FF" },
})
define("Flyer", "balloon", {
	DisplayName = "Balloon",
	Description = "Floats over and pops on impact.",
	Rarity = "Uncommon",
	Style = "Balloon",
	Colors = { "#FF3D6E", "#FFFFFF" },
})
define("Flyer", "rocket", {
	DisplayName = "Rocket",
	Description = "Strapped to a rocket. What could go wrong?",
	Rarity = "Rare",
	Style = "Rocket",
	Colors = { "#E8E8EE", "#FF3B3B", "#FFB347" },
})
define("Flyer", "comet", {
	DisplayName = "Comet",
	Description = "Burns across the sky with a blazing tail.",
	Rarity = "Rare",
	Style = "Comet",
	Colors = { "#FF8C1A", "#FFE14D", "#FF3B3B" },
})
define("Flyer", "saucer", {
	DisplayName = "Saucer",
	Description = "Beamed up and delivered by a flying saucer.",
	Rarity = "Epic",
	Style = "Saucer",
	Colors = { "#C9D0DA", "#5FFFE0", "#7A5CFF" },
})
define("Flyer", "dragonfly", {
	DisplayName = "Dragonfly",
	Description = "Buzzes over on shimmering wings.",
	Rarity = "Epic",
	Style = "Dragonfly",
	Colors = { "#3FA34D", "#B6F07A", "#A8F0FF" },
})
define("Flyer", "starcruiser", {
	DisplayName = "Star Cruiser",
	Description = "A sleek starship with twin engines.",
	Rarity = "Legendary",
	Style = "Cruiser",
	Colors = { "#E8ECF5", "#2F74E8", "#FF3D6E" },
})
define("Flyer", "cybereye", {
	DisplayName = "Cyber Eye",
	Description = "A hovering cybernetic eye locks on and fires.",
	Rarity = "Legendary",
	Style = "CyberEye",
	Colors = { "#D9F2FF", "#19B6FF", "#0A2540" },
})
define("Flyer", "broom", {
	DisplayName = "Witch Broom",
	Description = "Swept over by a spooky broomstick.",
	Rarity = "Epic",
	Event = "HarvestMoon",
	Style = "Broom",
	Colors = { "#8B5A2B", "#E0B060", "#9D4DFF" },
})

local CosmeticDefinitions = {}

function CosmeticDefinitions.Get(kind: string, id: string): CosmeticDefinition?
	return Definitions[kind .. ":" .. id]
end

function CosmeticDefinitions.Exists(kind: any, id: any): boolean
	return type(kind) == "string" and type(id) == "string" and Definitions[kind .. ":" .. id] ~= nil
end

function CosmeticDefinitions.All(kind: CosmeticKind?): { CosmeticDefinition }
	if kind == nil then
		return Ordered
	end
	local out = {}
	for _, def in Ordered do
		if def.Kind == kind then
			table.insert(out, def)
		end
	end
	return out
end

return CosmeticDefinitions
