--[[
	Items
	Currencies and materials. `icon` selects the procedural UI icon drawn by the client (UI/Icons).
]]

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Items = {
	Gumballs = {
		name = "Gumballs",
		description = "Feed them to the Gumball Machine to summon defenders.",
		color = rgb(255, 92, 170),
		icon = "gumball",
		currency = true,
	},
	VoidShards = {
		name = "Void Shards",
		description = "Reroll a unit's trait at the Void Rift.",
		color = rgb(176, 108, 255),
		icon = "shard",
		currency = true,
	},
	ReportCards = {
		name = "Report Cards",
		description = "Reroll a unit's stat grades at Principal Brown's Office.",
		color = rgb(255, 214, 70),
		icon = "card",
		currency = true,
	},
	JoyfulCoupons = {
		name = "Joyful Coupons",
		description = "Joyful Burger coupons. Needed for Glow-Ups.",
		color = rgb(255, 120, 60),
		icon = "coupon",
	},
	RainbowSprinkles = {
		name = "Rainbow Sprinkles",
		description = "Straight from the Rainbow Factory. Needed for Glow-Ups.",
		color = rgb(255, 160, 220),
		icon = "sprinkles",
	},
	VoidCores = {
		name = "Void Cores",
		description = "Dropped by bosses. Powers the strongest Glow-Ups.",
		color = rgb(120, 60, 200),
		icon = "core",
	},
	StickerPages = {
		name = "Sticker Pages",
		description = "Rare challenge reward for legendary Glow-Ups.",
		color = rgb(80, 200, 255),
		icon = "page",
	},
}

for id, item in Items do
	item.id = id
end

local module = {
	byId = Items,
	CURRENCIES = { "Gumballs", "VoidShards", "ReportCards" },
	MATERIALS = { "JoyfulCoupons", "RainbowSprinkles", "VoidCores", "StickerPages" },
}

function module.get(id: string)
	return Items[id]
end

return module
