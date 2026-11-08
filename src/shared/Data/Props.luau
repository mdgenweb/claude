--!strict
-- Spawnable physics props (the "Items" tab). Built server-side by Systems/PropFactory.

export type PropInfo = {
	id: string,
	name: string,
	icon: string,
	description: string,
	unlockLevel: number,
	order: number,
}

local list: { PropInfo } = {
	{
		id = "crate",
		name = "Wooden Crate",
		icon = "📦",
		description = "Stackable, smashable, classic.",
		unlockLevel = 1,
		order = 1,
	},
	{
		id = "barrel",
		name = "Boom Barrel",
		icon = "🛢️",
		description = "Explodes when hit hard or set on fire.",
		unlockLevel = 2,
		order = 2,
	},
	{
		id = "ball",
		name = "Beach Ball",
		icon = "🏐",
		description = "Light and very bouncy.",
		unlockLevel = 1,
		order = 3,
	},
	{
		id = "plank",
		name = "Long Plank",
		icon = "🪵",
		description = "Build ramps, seesaws and bridges.",
		unlockLevel = 1,
		order = 4,
	},
	{
		id = "anvil",
		name = "Anvil",
		icon = "⚒️",
		description = "Very heavy. Drop it from high up.",
		unlockLevel = 4,
		order = 5,
	},
	{
		id = "bowling",
		name = "Bowling Ball",
		icon = "🎳",
		description = "Heavy and round. Strike!",
		unlockLevel = 3,
		order = 6,
	},
	{
		id = "tnt",
		name = "TNT Crate",
		icon = "🧨",
		description = "Fuse lights on impact. Three... two...",
		unlockLevel = 6,
		order = 7,
	},
	{
		id = "trampoline",
		name = "Trampoline",
		icon = "🤸",
		description = "Fixed in place. Launches anything that lands on it.",
		unlockLevel = 2,
		order = 8,
	},
}

local Props = {
	List = list,
	ById = {} :: { [string]: PropInfo },
}

for _, prop in list do
	Props.ById[prop.id] = prop
end

return Props
