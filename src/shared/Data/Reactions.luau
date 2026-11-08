--!strict
-- Discoverable reactions between effects. Triggered by the server's status engine.

export type Reaction = {
	id: string,
	name: string,
	icon: string,
	description: string,
	chaos: number,
	color: Color3,
}

local list: { Reaction } = {
	{
		id = "steam",
		name = "Steam Burst",
		icon = "♨️",
		description = "Burning + Frozen. A scalding blast of steam.",
		chaos = 350,
		color = Color3.fromRGB(235, 240, 245),
	},
	{
		id = "shatter",
		name = "Shatter",
		icon = "🧊",
		description = "Frozen + a hard hit. The golem bursts into ice.",
		chaos = 500,
		color = Color3.fromRGB(140, 225, 255),
	},
	{
		id = "overcharge",
		name = "Overcharge",
		icon = "⚡",
		description = "Shocked + Wet or Slimed. Double the voltage!",
		chaos = 400,
		color = Color3.fromRGB(255, 240, 90),
	},
	{
		id = "conductor",
		name = "Conductor",
		icon = "🔗",
		description = "Shocked + metal. Lightning jumps to every metal golem.",
		chaos = 450,
		color = Color3.fromRGB(255, 220, 120),
	},
	{
		id = "pop",
		name = "Pop!",
		icon = "🎈",
		description = "Balloons + fire, lightning or a blast.",
		chaos = 200,
		color = Color3.fromRGB(255, 110, 200),
	},
	{
		id = "megablast",
		name = "Mega Blast",
		icon = "💥",
		description = "An explosion on a Giant golem. Double radius!",
		chaos = 600,
		color = Color3.fromRGB(255, 120, 50),
	},
	{
		id = "cure",
		name = "Cure",
		icon = "💖",
		description = "Healing a Zombie golem brings it back.",
		chaos = 250,
		color = Color3.fromRGB(255, 120, 170),
	},
	{
		id = "goldmelt",
		name = "Gold Melt",
		icon = "🪙",
		description = "Acid on a Golden golem. It rains coins!",
		chaos = 450,
		color = Color3.fromRGB(255, 210, 60),
	},
	{
		id = "overdrive",
		name = "Overdrive",
		icon = "🚀",
		description = "A Rocket golem gets Shocked. Maximum thrust!",
		chaos = 400,
		color = Color3.fromRGB(255, 170, 60),
	},
	{
		id = "spiritflame",
		name = "Spirit Flame",
		icon = "👻",
		description = "A Ghost catches fire. Spooky blue flames.",
		chaos = 350,
		color = Color3.fromRGB(110, 200, 255),
	},
}

local Reactions = {
	List = list,
	ById = {} :: { [string]: Reaction },
}

for _, reaction in list do
	Reactions.ById[reaction.id] = reaction
end

return Reactions
