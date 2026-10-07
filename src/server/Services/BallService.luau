--!strict
-- Orb definitions lookup, ownership checks and the 3 random battle offers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local Rarity = require(Shared.Config.Rarity)
local GameConfig = require(Shared.Config.Game)

local DataService = require(script.Parent.DataService)

local BallService = {}

local rng = Random.new()

function BallService.Get(id: string): BallDefinitions.BallDefinition?
	return BallDefinitions.Get(id)
end

function BallService.Owns(player: Player, id: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and (profile.Balls[id] or 0) > 0
end

-- Rolls `count` distinct orb ids. Source "Global" uses the whole roster weighted by rarity
-- (default, see research notes); "Owned" draws from the player's collection.
function BallService.RollOffers(player: Player?, count: number, exclude: { string }?): { string }
	local pool: { BallDefinitions.BallDefinition } = {}
	local source = GameConfig.Selection.OfferSource
	if source == "Owned" and player then
		local profile = DataService.Get(player)
		if profile then
			for id, n in profile.Balls do
				local def = BallDefinitions.Get(id)
				if def and n > 0 then
					table.insert(pool, def)
				end
			end
		end
	end
	if #pool < count then
		pool = table.clone(BallDefinitions.OfferPool())
	end
	local excluded: { [string]: boolean } = {}
	if exclude then
		for _, id in exclude do
			excluded[id] = true
		end
	end
	local result: { string } = {}
	for _ = 1, count do
		local total = 0
		for _, def in pool do
			if not excluded[def.Id] then
				total += Rarity.Get(def.Rarity).OfferWeight
			end
		end
		if total <= 0 then
			-- everything excluded: allow repeats from the full pool
			table.clear(excluded)
			continue
		end
		local pick = rng:NextNumber() * total
		for _, def in pool do
			if not excluded[def.Id] then
				pick -= Rarity.Get(def.Rarity).OfferWeight
				if pick < 0 then
					table.insert(result, def.Id)
					excluded[def.Id] = true
					break
				end
			end
		end
	end
	return result
end

return BallService
