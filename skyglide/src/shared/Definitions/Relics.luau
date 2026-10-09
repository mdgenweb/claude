--!strict
-- Limited relics (Robux, global stock). The reference sells a limited relic that is "always 125%
-- better" than your best throwable; ours follows the same rule with original names/art.
export type Relic = {
	Id: string,
	Name: string,
	ProductKey: string, -- Config/Monetization product
	Stock: number, -- global, across all servers (MonetizationService keeps the counter)
	BonusOverBest: number, -- 1.25 = 125% better than the best owned glider
	Visual: { Shape: string, Primary: string, Secondary: string, Glow: boolean? },
}

local list: { Relic } = {
	{
		Id = "aurora_relic",
		Name = "Aurora Relic",
		ProductKey = "AuroraRelic",
		Stock = 1000,
		BonusOverBest = 1.25,
		Visual = { Shape = "Relic", Primary = "#FFCF3D", Secondary = "#FF4F7B", Glow = true },
	},
}

local byId: { [string]: Relic } = {}
for _, r in list do
	byId[r.Id] = r
end

local Relics = {}
Relics.List = list

function Relics.Get(id: string): Relic?
	return byId[id]
end

function Relics.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return Relics
