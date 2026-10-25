--[[
	Shop
	Set real ids after creating passes/products in the Creator Dashboard. While an id is 0, Studio grants the
	purchase instantly (GameConfig.Dev.GrantUnconfiguredPurchasesInStudio) and live servers hide the buy button.

	Gamepass perks are read by server code via ShopService.hasPass(player, key).
]]

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Shop = {}

Shop.GamePasses = {
	VIP = {
		id = 0,
		price = 299,
		name = "VIP",
		color = rgb(255, 214, 70),
		icon = "crown",
		perks = { "20% off every summon", "2x Legendary & Mythic traits", "1.5x Epic traits", "VIP name & chat tag" },
		order = 1,
	},
	DoubleGumballs = {
		id = 0,
		price = 449,
		name = "2x Gumballs",
		color = rgb(255, 120, 190),
		icon = "gumball",
		perks = { "2x Gumballs from wins", "2x challenge Gumballs", "2x Infinite Gumballs" },
		order = 2,
	},
	LuckySummons = {
		id = 0,
		price = 349,
		name = "Lucky Summons",
		color = rgb(110, 220, 110),
		icon = "clover",
		perks = { "2x Mythic summon odds", "1.5x Legendary odds", "Works on every banner" },
		order = 3,
	},
	DoubleDrops = {
		id = 0,
		price = 449,
		name = "2x Drops",
		color = rgb(176, 108, 255),
		icon = "chest",
		perks = { "2x items from wins", "2x Glow-Up materials", "2x boss Void Cores" },
		order = 4,
	},
	BigBackpack = {
		id = 0,
		price = 99,
		name = "Big Backpack",
		color = rgb(255, 110, 110),
		icon = "backpack",
		perks = { "Hold 300 units", "150 more unit slots" },
		order = 5,
	},
	ThreeXSpeed = {
		id = 0,
		price = 149,
		name = "3x Speed",
		color = rgb(79, 183, 242),
		icon = "speed",
		perks = { "Unlocks 3x match speed", "Works for your whole party" },
		order = 6,
	},
}

-- Developer products. `grant` describes what ProcessReceipt gives.
Shop.Products = {
	StarterPack = {
		id = 0,
		price = 69,
		name = "Starter Pack",
		oneTime = true,
		color = rgb(255, 150, 200),
		icon = "gift",
		grant = { Gumballs = 3000, VoidShards = 20, ReportCards = 10, StickerPages = 3 },
		paid = true,
	},
	PassPremium = {
		id = 0,
		price = 799,
		name = "Elmore Pass Premium",
		oneTimePerSeason = true,
		special = "PassPremium",
	},
	PassTier = {
		id = 0,
		price = 29,
		name = "+1 Pass Tier",
		special = "PassTier",
	},
	Gumballs450 = { id = 0, price = 25, name = "450 Gumballs", grant = { Gumballs = 450 }, paid = true, pack = 1 },
	Gumballs1000 = { id = 0, price = 49, name = "1,000 Gumballs", grant = { Gumballs = 1000 }, paid = true, pack = 2 },
	Gumballs2200 = {
		id = 0,
		price = 99,
		name = "2,200 Gumballs",
		grant = { Gumballs = 2200 },
		paid = true,
		pack = 3,
		tag = "POPULAR",
	},
	Gumballs4800 = { id = 0, price = 199, name = "4,800 Gumballs", grant = { Gumballs = 4800 }, paid = true, pack = 4 },
	Gumballs10500 = {
		id = 0,
		price = 399,
		name = "10,500 Gumballs",
		grant = { Gumballs = 10500 },
		paid = true,
		pack = 5,
	},
	Gumballs21000 = {
		id = 0,
		price = 749,
		name = "21,000 Gumballs",
		grant = { Gumballs = 21000 },
		paid = true,
		pack = 6,
		tag = "BEST VALUE",
	},
}

-- Items bought with Gumballs (no Robux; always available).
Shop.GumballItems = {
	{ id = "Shards1", name = "1 Void Shard", cost = 75, grant = { VoidShards = 1 } },
	{ id = "Shards10", name = "10 Void Shards", cost = 675, grant = { VoidShards = 10 }, tag = "SAVE 10%" },
	{ id = "Cards1", name = "1 Report Card", cost = 50, grant = { ReportCards = 1 } },
	{ id = "Cards10", name = "10 Report Cards", cost = 450, grant = { ReportCards = 10 }, tag = "SAVE 10%" },
	{ id = "Coupons5", name = "5 Joyful Coupons", cost = 400, grant = { JoyfulCoupons = 5 } },
	{ id = "Sprinkles5", name = "5 Rainbow Sprinkles", cost = 400, grant = { RainbowSprinkles = 5 } },
}

function Shop.productByKey(key: string)
	return Shop.Products[key]
end

function Shop.productKeyById(productId: number): string?
	for key, product in Shop.Products do
		if product.id == productId and productId ~= 0 then
			return key
		end
	end
	return nil
end

function Shop.gumballItem(id: string)
	for _, entry in Shop.GumballItems do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

return Shop
