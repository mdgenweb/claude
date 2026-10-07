--!strict
-- Store crates. The Flyer crates copy the prices and odds shown in the reference store
-- screenshot exactly (CONFIRMED). Orb/Explosion/Event crate prices are (TUNABLE).
local BallDefinitions = require(script.Parent.BallDefinitions)
local CosmeticDefinitions = require(script.Parent.CosmeticDefinitions)

export type ItemKind = string -- "Ball" | "Explosion" | "Flyer"

export type PoolItem = { Kind: ItemKind, Id: string, Rarity: string }

export type Crate = {
	Id: string,
	Tab: string, -- "Events" | "Balls" | "Explosions" | "Flyers"
	DisplayName: string,
	Kind: string, -- ItemKind or "Mixed"
	Currency: string, -- "Coins" | "Gems"
	Price: number,
	Odds: { [string]: number }?, -- rarity -> percent (for rarity crates)
	Items: { { Kind: ItemKind, Id: string, Weight: number } }?, -- explicit weights (event crate)
	Art: string, -- client art key
	Theme: string, -- "Coins" | "Gems" | "Event"
	EndsAt: number?, -- unix seconds (event)
	TicketOnly: boolean?,
}

local Crates: { Crate } = {
	{
		Id = "OrbGacha",
		Tab = "Balls",
		DisplayName = "Orb Gacha",
		Kind = "Ball",
		Currency = "Coins",
		Price = 600,
		Odds = { Uncommon = 50, Rare = 32, Epic = 14, Legendary = 4 },
		Art = "Machine",
		Theme = "Coins",
	},
	{
		Id = "AdvancedOrbGacha",
		Tab = "Balls",
		DisplayName = "Advanced Orb Gacha",
		Kind = "Ball",
		Currency = "Gems",
		Price = 100,
		Odds = { Rare = 62, Epic = 27, Legendary = 9, Mythic = 2 },
		Art = "MachineAdvanced",
		Theme = "Gems",
	},
	{
		Id = "CoinsExplosionCrate",
		Tab = "Explosions",
		DisplayName = "Coins Explosion Crate",
		Kind = "Explosion",
		Currency = "Coins",
		Price = 1000,
		Odds = { Uncommon = 87, Rare = 10, Epic = 2.5, Legendary = 0.5 },
		Art = "CrateExplosion",
		Theme = "Coins",
	},
	{
		Id = "GemsExplosionCrate",
		Tab = "Explosions",
		DisplayName = "Gems Explosion Crate",
		Kind = "Explosion",
		Currency = "Gems",
		Price = 100,
		Odds = { Rare = 79, Epic = 18, Legendary = 3 },
		Art = "CrateExplosion",
		Theme = "Gems",
	},
	{
		Id = "CoinsFlyerCrate",
		Tab = "Flyers",
		DisplayName = "Coins Flyer Crate",
		Kind = "Flyer",
		Currency = "Coins",
		Price = 1000,
		Odds = { Uncommon = 87, Rare = 10, Epic = 2.5, Legendary = 0.5 },
		Art = "CrateFlyer",
		Theme = "Coins",
	},
	{
		Id = "GemsFlyerCrate",
		Tab = "Flyers",
		DisplayName = "Gems Flyer Crate",
		Kind = "Flyer",
		Currency = "Gems",
		Price = 100,
		Odds = { Rare = 79, Epic = 18, Legendary = 3 },
		Art = "CrateFlyer",
		Theme = "Gems",
	},
	{
		Id = "HarvestCrate",
		Tab = "Events",
		DisplayName = "Harvest Moon Crate",
		Kind = "Mixed",
		Currency = "Gems",
		Price = 120,
		Items = {
			{ Kind = "Ball", Id = "jack", Weight = 6 },
			{ Kind = "Flyer", Id = "broom", Weight = 24 },
			{ Kind = "Explosion", Id = "pumpkinpop", Weight = 70 },
		},
		Art = "CrateEvent",
		Theme = "Event",
		EndsAt = 1793491200, -- 2026-11-01 00:00:00 UTC
	},
}

local ById: { [string]: Crate } = {}
for _, crate in Crates do
	ById[crate.Id] = crate
end

local GachaDefinitions = {}

GachaDefinitions.Tabs = { "Events", "Balls", "Explosions", "Flyers" }

function GachaDefinitions.Get(id: string): Crate?
	return ById[id]
end

function GachaDefinitions.All(): { Crate }
	return Crates
end

function GachaDefinitions.ForTab(tab: string): { Crate }
	local out = {}
	for _, crate in Crates do
		if crate.Tab == tab then
			table.insert(out, crate)
		end
	end
	return out
end

function GachaDefinitions.IsActive(crate: Crate, now: number): boolean
	return crate.EndsAt == nil or now < crate.EndsAt
end

-- All items a crate can produce, with their rarity (used for prize previews and rolls).
function GachaDefinitions.Pool(crate: Crate): { PoolItem }
	local out: { PoolItem } = {}
	if crate.Items then
		for _, item in crate.Items do
			local rarity = "Uncommon"
			if item.Kind == "Ball" then
				local def = BallDefinitions.Get(item.Id)
				rarity = def and def.Rarity or rarity
			else
				local def = CosmeticDefinitions.Get(item.Kind, item.Id)
				rarity = def and def.Rarity or rarity
			end
			table.insert(out, { Kind = item.Kind, Id = item.Id, Rarity = rarity })
		end
		return out
	end
	local odds = crate.Odds or {}
	if crate.Kind == "Ball" then
		for _, def in BallDefinitions.All() do
			if odds[def.Rarity] and table.find(def.Obtain, crate.Id) then
				table.insert(out, { Kind = "Ball", Id = def.Id, Rarity = def.Rarity })
			end
		end
	elseif crate.Kind == "Explosion" or crate.Kind == "Flyer" then
		for _, def in CosmeticDefinitions.All(crate.Kind) do
			if odds[def.Rarity] and not def.Default and def.Event == nil then
				table.insert(out, { Kind = def.Kind :: string, Id = def.Id, Rarity = def.Rarity })
			end
		end
	end
	return out
end

return GachaDefinitions
