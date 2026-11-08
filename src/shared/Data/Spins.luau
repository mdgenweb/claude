--!strict
-- Mystery Flask prize table, shared so the server's roll and the client's reel animation agree.
-- Weights are relative.

export type Prize = {
	weight: number,
	kind: "coins" | "bundle" | "ingredient" | "potions" | "skin",
	amount: number?,
	rarity: string?,
	id: string?,
	icon: string,
	label: string,
	tier: string, -- rarity colour used by the reel
}

local List: { Prize } = {
	{ weight = 26, kind = "coins", amount = 100, icon = "🪙", label = "100 Coins", tier = "Common" },
	{ weight = 16, kind = "coins", amount = 250, icon = "💰", label = "250 Coins", tier = "Uncommon" },
	{ weight = 5, kind = "coins", amount = 700, icon = "💎", label = "700 Coins", tier = "Rare" },
	{
		weight = 18,
		kind = "bundle",
		rarity = "Common",
		amount = 2,
		icon = "🌿",
		label = "Herb Bundle",
		tier = "Common",
	},
	{
		weight = 13,
		kind = "bundle",
		rarity = "Uncommon",
		amount = 2,
		icon = "🍄",
		label = "Uncommon Bundle",
		tier = "Uncommon",
	},
	{ weight = 8, kind = "bundle", rarity = "Rare", amount = 2, icon = "✨", label = "Rare Bundle", tier = "Rare" },
	{
		weight = 4,
		kind = "bundle",
		rarity = "Epic",
		amount = 1,
		icon = "🐉",
		label = "Epic Ingredient",
		tier = "Epic",
	},
	{
		weight = 1.2,
		kind = "ingredient",
		id = "star_shard",
		amount = 1,
		icon = "⭐",
		label = "Star Shard",
		tier = "Legendary",
	},
	{ weight = 6, kind = "potions", amount = 3, icon = "🧪", label = "3 Random Potions", tier = "Uncommon" },
	{ weight = 2, kind = "skin", id = "shadow", icon = "🌑", label = "Shadow Golem", tier = "Epic" },
	{ weight = 0.8, kind = "skin", id = "rainbow", icon = "🌈", label = "Rainbow Golem", tier = "Legendary" },
}

return { List = List }
