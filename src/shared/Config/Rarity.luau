--!strict
-- Rarity tiers. Colours were sampled from the reference store screenshot (odds labels);
-- Mythic is an additional tier reported by current guides for the rarest fighters.
export type RarityId = "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type RarityInfo = {
	Id: RarityId,
	Order: number,
	Color: string, -- hex, converted with Color3.fromHex on the client
	Dark: string,
	Light: string,
	OfferWeight: number, -- weight used when rolling the 3 random battle offers
}

local Rarity = {}

Rarity.Order = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } :: { RarityId }

Rarity.Info = {
	Uncommon = { Id = "Uncommon", Order = 1, Color = "#5CCF1A", Dark = "#2F7A06", Light = "#B8F58A", OfferWeight = 40 },
	Rare = { Id = "Rare", Order = 2, Color = "#5AAAF0", Dark = "#1F5FA8", Light = "#BFE0FF", OfferWeight = 30 },
	Epic = { Id = "Epic", Order = 3, Color = "#B24DFF", Dark = "#5E1A9C", Light = "#E3BFFF", OfferWeight = 18 },
	Legendary = { Id = "Legendary", Order = 4, Color = "#FFA000", Dark = "#A35A00", Light = "#FFE1A3", OfferWeight = 9 },
	Mythic = { Id = "Mythic", Order = 5, Color = "#FF3D6E", Dark = "#9C0F35", Light = "#FFC2D2", OfferWeight = 3 },
} :: { [string]: RarityInfo }

function Rarity.Get(id: string): RarityInfo
	return Rarity.Info[id] or Rarity.Info.Uncommon
end

function Rarity.Compare(a: string, b: string): boolean
	return Rarity.Get(a).Order < Rarity.Get(b).Order
end

return Rarity
