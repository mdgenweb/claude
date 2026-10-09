--!strict
-- Game passes and developer products. Set the real ids before publishing.
-- Id = 0 means "not configured": inside Studio the purchase is a free TEST grant so every flow can
-- be exercised; in a live server the offer is shown as unavailable (never a fake button).
-- Prices are display hints; Roblox shows the real price in its purchase dialog.
export type Pass = { Key: string, Name: string, Description: string, Id: number, Robux: number, Icon: string }
export type Product = {
	Key: string,
	Name: string,
	Description: string,
	Id: number,
	Robux: number,
	Kind: string, -- "Skill" | "StarterPack" | "Relic" | "Egg" | "Potion"
	Amount: number?,
	Ref: string?, -- relic id / egg id / potion id
	OneTime: boolean?,
}

local Monetization = {}

Monetization.Passes = {
	{ Key = "AutoThrow", Name = "Auto Throw", Description = "Throws for you whenever you stand in the Throw Zone.", Id = 0, Robux = 10, Icon = "Auto" },
	{ Key = "DoubleSkill", Name = "2x Skill", Description = "Doubles all Skill you earn, forever.", Id = 0, Robux = 49, Icon = "Skill" },
	{ Key = "DoubleWins", Name = "2x Wins", Description = "Doubles all Wins you earn, forever.", Id = 0, Robux = 25, Icon = "Wins" },
	{ Key = "PetSlots", Name = "+2 Pet Slots", Description = "Equip 2 more pets.", Id = 0, Robux = 99, Icon = "Pet" },
	{ Key = "TripleHatch", Name = "Triple Hatch", Description = "Hatch 3 eggs at once.", Id = 0, Robux = 79, Icon = "Egg" },
	{ Key = "Pad3x", Name = "3x Skill Pads", Description = "Unlocks the 3x ALL WORLDS training pads.", Id = 0, Robux = 39, Icon = "Pad" },
	{ Key = "Pad15x", Name = "15x Skill Pads", Description = "Unlocks the 15x ALL WORLDS training pads.", Id = 0, Robux = 99, Icon = "Pad" },
	{ Key = "Pad50x", Name = "50x Skill Pads", Description = "Unlocks the 50x ALL WORLDS training pads.", Id = 0, Robux = 239, Icon = "Pad" },
} :: { Pass }

Monetization.Products = {
	{ Key = "Skill10K", Name = "+10K Skill", Description = "Instant Skill (scaled by world).", Id = 0, Robux = 5, Kind = "Skill", Amount = 10000 },
	{ Key = "Skill100K", Name = "+100K Skill", Description = "Instant Skill (scaled by world).", Id = 0, Robux = 20, Kind = "Skill", Amount = 100000 },
	{ Key = "Skill1M", Name = "+1M Skill", Description = "Instant Skill (scaled by world).", Id = 0, Robux = 40, Kind = "Skill", Amount = 1000000 },
	{ Key = "StarterPack", Name = "Starter Pack", Description = "Starlight Unicat pet, 2 potions of each kind and 500 Wins.", Id = 0, Robux = 49, Kind = "StarterPack", OneTime = true },
	{ Key = "AuroraRelic", Name = "Aurora Relic", Description = "Limited! Always 125% better than your best glider.", Id = 0, Robux = 199, Kind = "Relic", Ref = "aurora_relic", OneTime = true },
	{ Key = "OverlordEgg", Name = "Overlord Egg", Description = "Hatch one Overlord Egg.", Id = 0, Robux = 70, Kind = "Egg", Ref = "overlord_egg" },
	{ Key = "SkillPotions", Name = "3x 2x Skill Potions", Description = "Three 10-minute 2x Skill potions.", Id = 0, Robux = 25, Kind = "Potion", Ref = "skill_potion", Amount = 3 },
	{ Key = "WinsPotions", Name = "3x 2x Wins Potions", Description = "Three 10-minute 2x Wins potions.", Id = 0, Robux = 25, Kind = "Potion", Ref = "wins_potion", Amount = 3 },
} :: { Product }

Monetization.StarterPack = {
	Pet = "starlight_unicat",
	Potions = { skill_potion = 2, wins_potion = 2, luck_potion = 2 } :: { [string]: number },
	Wins = 500,
}

local passByKey: { [string]: Pass } = {}
for _, p in Monetization.Passes do
	passByKey[p.Key] = p
end
local productByKey: { [string]: Product } = {}
for _, p in Monetization.Products do
	productByKey[p.Key] = p
end

function Monetization.Pass(key: string): Pass?
	return passByKey[key]
end

function Monetization.Product(key: string): Product?
	return productByKey[key]
end

return Monetization
