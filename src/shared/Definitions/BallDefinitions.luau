--!strict
-- Data for every collectible fighter ("Orb"). Gameplay code never special-cases an Id:
-- behaviour comes from AbilityId + AbilityParams (server: Battle/Abilities/<AbilityId>.luau),
-- visuals come from Visual (client: Visual/OrbArt.luau). Adding a new orb = add an entry here,
-- add an ability module if it needs new behaviour, add an emblem painter if it needs new art.
--
-- Colours are hex strings so this module stays pure data (also used by headless tests).

export type BallVisual = {
	Base: string,
	Accent: string,
	Emblem: string, -- painter id in Visual/OrbArt
	Spikes: number?, -- decorative spikes around the silhouette
	Band: boolean?, -- equator band in Accent colour
	Rim: string?, -- glow rim colour (high rarities)
	Material: string?,
}

export type BallDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	Rarity: string,
	Category: string,
	BaseHP: number,
	ContactDamage: number,
	Speed: number, -- multiplier of Physics.CruiseSpeed
	Radius: number,
	Mass: number,
	Restitution: number,
	AbilityId: string?,
	AbilityParams: { [string]: any },
	Tags: { string },
	Obtain: { string },
	Tradable: boolean,
	Event: string?,
	Visual: BallVisual,
	VFXProfile: string,
	SFXProfile: string,
}

type Partial = {
	DisplayName: string,
	Description: string,
	Rarity: string,
	Category: string,
	BaseHP: number?,
	ContactDamage: number?,
	Speed: number?,
	Radius: number?,
	Mass: number?,
	AbilityId: string?,
	AbilityParams: { [string]: any }?,
	Tags: { string }?,
	Obtain: { string },
	Event: string?,
	Visual: BallVisual,
}

local Definitions: { [string]: BallDefinition } = {}
local Ordered: { BallDefinition } = {}

local function define(id: string, d: Partial)
	local def: BallDefinition = {
		Id = id,
		DisplayName = d.DisplayName,
		Description = d.Description,
		Rarity = d.Rarity,
		Category = d.Category,
		BaseHP = d.BaseHP or 100,
		ContactDamage = d.ContactDamage or 4,
		Speed = d.Speed or 1,
		Radius = d.Radius or 1.5,
		Mass = d.Mass or 1,
		Restitution = 1,
		AbilityId = d.AbilityId,
		AbilityParams = d.AbilityParams or {},
		Tags = d.Tags or { d.Category },
		Obtain = d.Obtain,
		Tradable = true,
		Event = d.Event,
		Visual = d.Visual,
		VFXProfile = d.AbilityId or "none",
		SFXProfile = d.AbilityId or "none",
	}
	assert(Definitions[id] == nil, "duplicate ball id " .. id)
	Definitions[id] = def
	table.insert(Ordered, def)
end

---------------------------------------------------------------------------- Uncommon
define("bumper", {
	DisplayName = "Bumper Orb",
	Description = "No gimmicks. Hits harder than anyone and knocks enemies flying on every bump.",
	Rarity = "Uncommon",
	Category = "Contact",
	BaseHP = 110,
	ContactDamage = 8,
	Mass = 1.2,
	AbilityId = "bumper",
	AbilityParams = { KnockbackBoost = 1.45 },
	Obtain = { "Starter", "OrbGacha" },
	Visual = { Base = "#FF8A1F", Accent = "#FFD08A", Emblem = "grin" },
})

define("thorn", {
	DisplayName = "Thorn Orb",
	Description = "Every wall bounce grows a thorn on that wall. Thorns sting enemies that brush past.",
	Rarity = "Uncommon",
	Category = "Hazard",
	ContactDamage = 3,
	AbilityId = "thorn",
	AbilityParams = { MaxThorns = 5, Damage = 5, Length = 2.2, Width = 1.5, Life = 10, HitCooldown = 0.8 },
	Obtain = { "Starter", "OrbGacha" },
	Visual = { Base = "#E9EBF0", Accent = "#8A8F9C", Emblem = "angry", Spikes = 8 },
})

define("spring", {
	DisplayName = "Spring Orb",
	Description = "Gains speed with every wall bounce. The faster it goes, the harder it hits.",
	Rarity = "Uncommon",
	Category = "Speed",
	BaseHP = 95,
	ContactDamage = 4,
	AbilityId = "spring",
	AbilityParams = { BoostPerBounce = 0.08, MaxBoost = 0.7, DamagePerBoost = 2.0 },
	Obtain = { "LevelReward", "OrbGacha" },
	Visual = { Base = "#9BE15D", Accent = "#3E8E1E", Emblem = "spring" },
})

define("sunny", {
	DisplayName = "Sunny Orb",
	Description = "Slowly regenerates. Once per round at low HP it bursts with sunlight: heals and shoves enemies away.",
	Rarity = "Uncommon",
	Category = "Sustain",
	ContactDamage = 5,
	AbilityId = "sunny",
	AbilityParams = { RegenPerSecond = 1.2, Threshold = 0.3, BurstHeal = 22, BurstRadius = 6, BurstPush = 22 },
	Obtain = { "LevelReward", "OrbGacha" },
	Visual = { Base = "#FFD23F", Accent = "#FF9F1C", Emblem = "smile", Spikes = 10 },
})

---------------------------------------------------------------------------- Rare
define("titan", {
	DisplayName = "Titan Orb",
	Description = "Huge, heavy and stubborn. Takes less damage from bumps and bullies smaller orbs.",
	Rarity = "Rare",
	Category = "Tank",
	BaseHP = 120,
	ContactDamage = 6,
	Speed = 0.86,
	Radius = 2.0,
	Mass = 1.9,
	AbilityId = "titan",
	AbilityParams = { ContactReduction = 0.25 },
	Obtain = { "LevelReward", "OrbGacha" },
	Visual = { Base = "#7C8794", Accent = "#3D4450", Emblem = "heavy", Band = true },
})

define("boomerang", {
	DisplayName = "Boomerang Orb",
	Description = "Throws a boomerang at the nearest enemy. It hits on the way out and on the way back.",
	Rarity = "Rare",
	Category = "Projectile",
	BaseHP = 95,
	ContactDamage = 3,
	AbilityId = "boomerang",
	AbilityParams = { Interval = 2.0, Range = 8, Speed = 21, Damage = 7, Radius = 0.8 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#3BC6B5", Accent = "#0E6E62", Emblem = "boomerang" },
})

define("satellite", {
	DisplayName = "Satellite Orb",
	Description = "Moons orbit around it and smack anything they touch. A new moon joins every few seconds.",
	Rarity = "Rare",
	Category = "Orbit",
	BaseHP = 95,
	ContactDamage = 3,
	AbilityId = "satellite",
	AbilityParams = { StartMoons = 2, MaxMoons = 5, AddEvery = 4, Damage = 4, OrbitRadius = 2.7, AngularSpeed = 4.2, MoonRadius = 0.45, HitCooldown = 0.4 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#5B6CFF", Accent = "#C9D0FF", Emblem = "ring" },
})

define("leech", {
	DisplayName = "Leech Orb",
	Description = "Latches onto enemies it bumps, draining their HP and healing itself.",
	Rarity = "Rare",
	Category = "Drain",
	ContactDamage = 3,
	AbilityId = "leech",
	AbilityParams = { Duration = 1.2, TickEvery = 0.3, DrainPerTick = 2.5, Cooldown = 2.8 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#B3122E", Accent = "#FF6B7F", Emblem = "fangs" },
})

define("goo", {
	DisplayName = "Goo Orb",
	Description = "Splats sticky goo on the walls it hits. Goo slows enemies and eats away their HP.",
	Rarity = "Rare",
	Category = "Hazard",
	ContactDamage = 3,
	AbilityId = "goo",
	AbilityParams = { MaxPuddles = 5, Radius = 1.6, Life = 8, Slow = 0.45, SlowTime = 0.8, Damage = 2, TickEvery = 0.3 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#6EDB3A", Accent = "#2C7A12", Emblem = "drip" },
})

define("magnet", {
	DisplayName = "Magnet Orb",
	Description = "Every few seconds it yanks enemies toward itself. Its next bump after a pull hits much harder.",
	Rarity = "Rare",
	Category = "Control",
	BaseHP = 105,
	ContactDamage = 5,
	AbilityId = "magnet",
	AbilityParams = { Interval = 3.5, PullBlend = 0.75, BonusDamage = 9, BonusWindow = 1.6 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#D7263D", Accent = "#E8E8EE", Emblem = "magnet" },
})

---------------------------------------------------------------------------- Epic
define("cannon", {
	DisplayName = "Cannon Orb",
	Description = "Fires heavy cannonballs at where the enemy is heading. The recoil pushes it backwards.",
	Rarity = "Epic",
	Category = "Projectile",
	ContactDamage = 3,
	AbilityId = "cannon",
	AbilityParams = { Interval = 2.8, Speed = 28, Damage = 10, Radius = 0.55, Recoil = 6 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#2E3138", Accent = "#F2C14E", Emblem = "barrel", Band = true },
})

define("frost", {
	DisplayName = "Frost Orb",
	Description = "Its touch freezes enemies solid with a bite of frost. Frozen orbs take extra damage.",
	Rarity = "Epic",
	Category = "Control",
	ContactDamage = 5,
	AbilityId = "frost",
	AbilityParams = { FreezeTime = 1.0, Cooldown = 2.6, FrozenVulnerability = 0.35, Frostbite = 4 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#9EE7FF", Accent = "#FFFFFF", Emblem = "snowflake" },
})

define("mine", {
	DisplayName = "Mine Orb",
	Description = "Drops proximity mines where it bounces. Mines explode when an enemy rolls close.",
	Rarity = "Epic",
	Category = "Hazard",
	ContactDamage = 3,
	AbilityId = "mine",
	AbilityParams = { MaxMines = 3, Cooldown = 1.4, ArmTime = 0.7, Trigger = 1.4, BlastRadius = 3, Damage = 10, Life = 10 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#4A4F59", Accent = "#FF3B3B", Emblem = "mine" },
})

define("prism", {
	DisplayName = "Prism Orb",
	Description = "Wall bounces project a beam of light straight across the arena. Enemies crossing it get burned.",
	Rarity = "Epic",
	Category = "Beam",
	BaseHP = 95,
	ContactDamage = 3,
	AbilityId = "prism",
	AbilityParams = { MaxBeams = 2, Cooldown = 1.3, ChargeTime = 0.4, Life = 1.6, Damage = 5, HitCooldown = 0.8, Width = 0.3 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#F2F2FF", Accent = "#7A5CFF", Emblem = "prism" },
})

define("lucky", {
	DisplayName = "Lucky Orb",
	Description = "Rolls a die on every bump: the damage is the roll. A six bursts into a jackpot of shards.",
	Rarity = "Epic",
	Category = "Random",
	ContactDamage = 0,
	AbilityId = "lucky",
	AbilityParams = { DamagePerPip = 2, JackpotShards = 8, ShardDamage = 3, ShardSpeed = 18 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#FFFFFF", Accent = "#1C1C24", Emblem = "dice" },
})

define("ghost", {
	DisplayName = "Ghost Orb",
	Description = "Turns ethereal every few seconds: untouchable, faster, and it chills anything it passes through. Reappearing next to an enemy spooks it.",
	Rarity = "Epic",
	Category = "Evasion",
	BaseHP = 95,
	ContactDamage = 5,
	AbilityId = "ghost",
	AbilityParams = { Interval = 4, Duration = 1.5, SpeedBoost = 0.35, PassDamage = 6, PassCooldown = 0.6, SpookDamage = 12, SpookRadius = 2.5 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#CFC8FF", Accent = "#6B5BD6", Emblem = "ghost" },
})

define("serpent", {
	DisplayName = "Serpent Orb",
	Description = "Leaves a venomous tail behind it. Enemies that cross the tail take damage.",
	Rarity = "Epic",
	Category = "Trail",
	ContactDamage = 3,
	AbilityId = "serpent",
	AbilityParams = { TrailTime = 1.5, SampleEvery = 0.07, Damage = 3, HitCooldown = 0.3, Width = 0.55 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#3FA34D", Accent = "#B6F07A", Emblem = "serpent" },
})

---------------------------------------------------------------------------- Legendary
define("forge", {
	DisplayName = "Forge Orb",
	Description = "Every fourth enemy hit is a SMASH: triple damage plus a shockwave that hurts everyone nearby.",
	Rarity = "Legendary",
	Category = "Contact",
	BaseHP = 110,
	ContactDamage = 5,
	AbilityId = "forge",
	AbilityParams = { HitsPerSmash = 4, SmashMultiplier = 3, WaveRadius = 4.5, WaveDamage = 7 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#FFB000", Accent = "#6B3A00", Emblem = "hammer", Rim = "#FFE08A" },
})

define("crystal", {
	DisplayName = "Crystal Orb",
	Description = "Any impact may shatter it into a spray of crystal shards that fly outward.",
	Rarity = "Legendary",
	Category = "Projectile",
	BaseHP = 95,
	ContactDamage = 3,
	AbilityId = "crystal",
	AbilityParams = { Chance = 0.55, Shards = 5, Speed = 20, Life = 0.8, Damage = 4, Cooldown = 0.3 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#7FE9FF", Accent = "#1B8FB3", Emblem = "gem", Rim = "#D4FAFF", Material = "Glass" },
})

define("storm", {
	DisplayName = "Storm Orb",
	Description = "Calls lightning on the nearest enemy. It never misses. Below half HP the storm speeds up and chains.",
	Rarity = "Legendary",
	Category = "Beam",
	ContactDamage = 3,
	AbilityId = "storm",
	AbilityParams = { Interval = 2.3, EnragedInterval = 1.7, Damage = 6, ChainDamage = 4, Threshold = 0.5 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#2B2D8F", Accent = "#FFE14D", Emblem = "bolt", Rim = "#8C8FFF" },
})

define("mitosis", {
	DisplayName = "Mitosis Orb",
	Description = "Keeps growing and hitting harder. When destroyed it splits into three mini orbs that keep fighting.",
	Rarity = "Legendary",
	Category = "Summon",
	BaseHP = 105,
	AbilityId = "mitosis",
	AbilityParams = { GrowEvery = 3, GrowAmount = 0.05, MaxGrowth = 0.4, ContactPerGrowth = 2, Minis = 3, MiniRadius = 0.8, MiniHP = 20, MiniContact = 5 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#FF7BD5", Accent = "#B5179E", Emblem = "cell", Rim = "#FFC2EE" },
})

define("rook", {
	DisplayName = "Rook Orb",
	Description = "Pauses, lines up with the enemy, then charges in a straight line. Getting rammed hurts.",
	Rarity = "Legendary",
	Category = "Dash",
	BaseHP = 110,
	AbilityId = "rook",
	AbilityParams = { Interval = 3.4, Windup = 0.35, ChargeSpeed = 2.6, ChargeTime = 0.6, ChargeDamage = 18 },
	Obtain = { "OrbGacha", "AdvancedOrbGacha" },
	Visual = { Base = "#F0E6D2", Accent = "#3B3228", Emblem = "rook", Rim = "#FFF6E0" },
})

---------------------------------------------------------------------------- Mythic
define("rail", {
	DisplayName = "Rail Orb",
	Description = "Bouncing off a wall lays a rail straight across the arena. Moments later a train thunders along it.",
	Rarity = "Mythic",
	Category = "Hazard",
	AbilityId = "rail",
	AbilityParams = { Cooldown = 2.6, Warning = 0.9, TrainSpeed = 42, TrainLength = 4.5, TrainWidth = 2.0, Damage = 20 },
	Obtain = { "AdvancedOrbGacha" },
	Visual = { Base = "#3C3F46", Accent = "#FFCC00", Emblem = "rail", Rim = "#FFCC00", Band = true },
})

define("shackle", {
	DisplayName = "Shackle Orb",
	Description = "Scatters shackle traps around the enemy. Anything caught is chained in place and badly hurt.",
	Rarity = "Mythic",
	Category = "Trap",
	AbilityId = "shackle",
	AbilityParams = { Interval = 4.2, Traps = 2, Spread = 4, ArmTime = 0.55, Life = 6, Radius = 1.2, SnareTime = 0.9, Damage = 8 },
	Obtain = { "AdvancedOrbGacha" },
	Visual = { Base = "#5B5F6B", Accent = "#C9CCD3", Emblem = "chain", Rim = "#E04040" },
})

define("aura", {
	DisplayName = "Aura Orb",
	Description = "Radiates a harmful aura that grows over the round. Standing near it is a bad idea.",
	Rarity = "Mythic",
	Category = "Zone",
	ContactDamage = 3,
	AbilityId = "aura",
	AbilityParams = { StartRadius = 1.4, EndRadius = 3.6, GrowTime = 24, Damage = 3.5, TickEvery = 0.5 },
	Obtain = { "AdvancedOrbGacha" },
	Visual = { Base = "#9D4DFF", Accent = "#F1E3FF", Emblem = "eye", Rim = "#D9B3FF" },
})

---------------------------------------------------------------------------- Event
define("jack", {
	DisplayName = "Jack Orb",
	Description = "Lobs pumpkin bombs that arc across the arena and leave burning patches behind.",
	Rarity = "Legendary",
	Category = "Projectile",
	ContactDamage = 3,
	AbilityId = "jack",
	AbilityParams = { Interval = 2.6, LobSpeed = 17, Damage = 12, BlastRadius = 2.6, FireLife = 2.5, FireDamage = 2, FireTick = 0.4, FireRadius = 1.6 },
	Obtain = { "HarvestCrate" },
	Event = "HarvestMoon",
	Visual = { Base = "#FF8C1A", Accent = "#2B1400", Emblem = "pumpkin", Rim = "#FFD08A" },
})

local BallDefinitions = {}

function BallDefinitions.Get(id: string): BallDefinition?
	return Definitions[id]
end

function BallDefinitions.All(): { BallDefinition }
	return Ordered
end

function BallDefinitions.Exists(id: any): boolean
	return type(id) == "string" and Definitions[id] ~= nil
end

-- Orbs that can appear as random battle offers (event orbs excluded).
function BallDefinitions.OfferPool(): { BallDefinition }
	local list = {}
	for _, def in Ordered do
		if def.Event == nil then
			table.insert(list, def)
		end
	end
	return list
end

return BallDefinitions
