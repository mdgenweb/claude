--!strict
-- Worlds (ORIGINAL names/themes; the reference has a beach start, a volcano world and a pirate
-- world, we keep that progression shape with our own places and add a fourth).
-- Each world is a separate area of the same place, offset along X (see Config/Map).
-- Unlocking follows the reference rule (CONFIRMED): a throw that reaches the end of the current
-- river opens the next world. ORIGINAL addition: a rebirth gate too, so a lucky special throw
-- (x3 / x8) can reach the river end early without skipping a whole world's progression.
-- DistanceScale grows x25 per world so each world spans a few rebirths.
export type World = {
	Id: number,
	Key: string,
	Name: string,
	Theme: string, -- palette key in Visual/Themes
	DistanceScale: number, -- scales zone spacing, ring counts, rendering (see Config/Flight)
	UnlockWins: number, -- extra Wins price at the portal (0 = free once the river end is reached)
	UnlockRebirths: number, -- extra rebirth gate (0 = none)
	UnlockZone: string?, -- zone id that must be reached first (end of the previous world's river)
	SkillPackScale: number, -- Robux skill packs are multiplied by this in this world
	Description: string,
}

local list: { World } = {
	{
		Id = 1,
		Key = "SunnyIsles",
		Name = "Sunny Isles",
		Theme = "Isles",
		DistanceScale = 1,
		UnlockWins = 0,
		UnlockRebirths = 0,
		SkillPackScale = 1,
		Description = "Warm breeze, gentle thermals.",
	},
	{
		Id = 2,
		Key = "EmberCrater",
		Name = "Ember Crater",
		Theme = "Ember",
		DistanceScale = 25,
		UnlockWins = 0,
		UnlockRebirths = 5,
		UnlockZone = "w1_z12",
		SkillPackScale = 1000,
		Description = "Lava vents throw gliders sky-high.",
	},
	{
		Id = 3,
		Key = "BuccaneerBay",
		Name = "Buccaneer Bay",
		Theme = "Bay",
		DistanceScale = 625,
		UnlockWins = 0,
		UnlockRebirths = 7,
		UnlockZone = "w2_z12",
		SkillPackScale = 1000000,
		Description = "Sea winds over sunken treasure.",
	},
	{
		Id = 4,
		Key = "FrostPeaks",
		Name = "Frost Peaks",
		Theme = "Frost",
		DistanceScale = 15625,
		UnlockWins = 0,
		UnlockRebirths = 9,
		UnlockZone = "w3_z12",
		SkillPackScale = 1000000000,
		Description = "Thin icy air, the longest glides of all.",
	},
}

local Worlds = {}
Worlds.List = list
Worlds.Count = #list

function Worlds.Get(id: number): World?
	return list[id]
end

function Worlds.Exists(id: any): boolean
	return type(id) == "number" and list[id] ~= nil
end

return Worlds
