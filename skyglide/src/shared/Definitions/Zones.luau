--!strict
-- Distance zones along each world's channel. Landing in a zone pays its Wins (x Wins multiplier).
-- Zone signs are built at Sim/FlightSim.RenderZ(Distance) so they line up with flights exactly.
local Worlds = require(script.Parent.Worlds)

export type Zone = {
	Id: string,
	World: number,
	Index: number,
	Name: string,
	Distance: number, -- meters where the zone starts
	Wins: number,
	Color: string,
}

-- Base layout (meters, wins) scaled per world by DistanceScale and WinsScale.
-- (LIKELY anchor: a fan sample of a 1,404 m World 1 throw paid ~200 Wins.)
local BASE = {
	{ 0, 1 },
	{ 25, 3 },
	{ 60, 6 },
	{ 120, 12 },
	{ 220, 25 },
	{ 400, 45 },
	{ 700, 90 },
	{ 1200, 180 },
	{ 2000, 320 },
	{ 3500, 550 },
	{ 6000, 950 },
	{ 10000, 1600 },
}

local WINS_SCALE = { 1, 25, 600, 15000 }

local NAMES: { [number]: { string } } = {
	[1] = {
		"Driftwood Dock",
		"Coral Shallows",
		"Sunset Lagoon",
		"Coconut Cove",
		"Turtle Reef",
		"Lighthouse Point",
		"Whale Bay",
		"Breezy Strait",
		"Rainbow Falls",
		"Cloud Harbor",
		"Sky Archipelago",
		"Edge of the Map",
	},
	[2] = {
		"Ash Landing",
		"Cinder Flats",
		"Obsidian Pools",
		"Smoke Ridge",
		"Magma River",
		"Dragon's Nest",
		"Fire Geysers",
		"Basalt Towers",
		"Molten Core",
		"Phoenix Rise",
		"Eruption Peak",
		"Sun Forge",
	},
	[3] = {
		"Plank Pier",
		"Barrel Beach",
		"Parrot Isle",
		"Kraken Reef",
		"Cannon Cove",
		"Shipwreck Shoals",
		"Skull Rock",
		"Treasure Sands",
		"Ghost Fleet",
		"Mermaid Lagoon",
		"Storm Sea",
		"Captain's Horizon",
	},
	[4] = {
		"Snowdrift Dock",
		"Pine Hollow",
		"Frozen Falls",
		"Penguin Point",
		"Glacier Gap",
		"Crystal Caves",
		"Yeti Ridge",
		"Aurora Fields",
		"Icicle Spires",
		"Blizzard Belt",
		"Polar Crown",
		"Northern Lights",
	},
}

local COLORS = {
	"#FFFFFF",
	"#7CF3FF",
	"#FFB36B",
	"#9CFF7A",
	"#5FE0C8",
	"#FFE45E",
	"#7AB8FF",
	"#C49BFF",
	"#FF8FD0",
	"#B6FFF2",
	"#FFD27A",
	"#FF6B6B",
}

local byWorld: { [number]: { Zone } } = {}
local byId: { [string]: Zone } = {}

for _, world in Worlds.List do
	local zones = {}
	for i, row in BASE do
		local zone: Zone = {
			Id = string.format("w%d_z%d", world.Id, i),
			World = world.Id,
			Index = i,
			Name = NAMES[world.Id][i],
			Distance = row[1] * world.DistanceScale,
			Wins = row[2] * WINS_SCALE[world.Id],
			Color = COLORS[i],
		}
		zones[i] = zone
		byId[zone.Id] = zone
	end
	byWorld[world.Id] = zones
end

local Zones = {}

function Zones.ForWorld(worldId: number): { Zone }
	return byWorld[worldId] or {}
end

function Zones.Get(id: string): Zone?
	return byId[id]
end

-- Last zone of a world: landing there unlocks the next world (CONFIRMED mechanic: reaching the
-- end of the river opens the next world).
function Zones.Last(worldId: number): Zone?
	local zones = byWorld[worldId]
	return if zones then zones[#zones] else nil
end

-- The zone a landing at `distance` meters falls in (furthest zone whose start <= distance).
function Zones.At(worldId: number, distance: number): Zone
	local zones = byWorld[worldId] or byWorld[1]
	local found = zones[1]
	for _, zone in zones do
		if distance >= zone.Distance then
			found = zone
		else
			break
		end
	end
	return found
end

return Zones
