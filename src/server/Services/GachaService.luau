--!strict
-- Server-side weighted gacha rolls. The client only names a crate; price, pool and result are
-- decided here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local Economy = require(Shared.Config.Economy)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

export type Pull = { Kind: string, Id: string, Rarity: string, New: boolean }

local GachaService = {}

local rng = Random.new()

local function roll(crate: GachaDefinitions.Crate): GachaDefinitions.PoolItem?
	local pool = GachaDefinitions.Pool(crate)
	if #pool == 0 then
		return nil
	end
	if crate.Items then
		local total = 0
		for _, item in crate.Items do
			total += item.Weight
		end
		local pick = rng:NextNumber() * total
		for i, item in crate.Items do
			pick -= item.Weight
			if pick < 0 then
				return pool[i]
			end
		end
		return pool[#pool]
	end
	-- rarity first (published odds), then uniform within that rarity
	local odds: { [string]: number } = crate.Odds or {}
	local total = 0
	for _, pct in odds do
		total += pct
	end
	local pick = rng:NextNumber() * total
	local rarity: string? = nil
	for _, r in { "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local pct = odds[r]
		if pct then
			pick -= pct
			if pick < 0 then
				rarity = r
				break
			end
		end
	end
	local candidates = {}
	for _, item in pool do
		if item.Rarity == rarity then
			table.insert(candidates, item)
		end
	end
	if #candidates == 0 then
		candidates = pool
	end
	return candidates[rng:NextInteger(1, #candidates)]
end
GachaService.Roll = roll

local function grantPulls(player: Player, crate: GachaDefinitions.Crate, count: number): { Pull }
	local pulls: { Pull } = {}
	DataService.Update(player, function(profile)
		for _ = 1, count do
			local item = roll(crate)
			if item then
				local bag = EconomyService.BagFor(profile, item.Kind)
				local isNew = bag ~= nil and (bag[item.Id] or 0) == 0
				EconomyService.AddToProfile(profile, item.Kind, item.Id, 1)
				table.insert(pulls, { Kind = item.Kind, Id = item.Id, Rarity = item.Rarity, New = isNew })
			end
		end
		return true
	end)
	return pulls
end

function GachaService.Open(player: Player, crateId: any, count: any): { [string]: any }
	local crate = if type(crateId) == "string" then GachaDefinitions.Get(crateId) else nil
	if crate == nil or crate.TicketOnly then
		return { ok = false, error = "That crate doesn't exist." }
	end
	if count ~= 1 and count ~= Economy.Limits.MaxBulkOpen then
		return { ok = false, error = "Invalid amount." }
	end
	if not GachaDefinitions.IsActive(crate, os.time()) then
		return { ok = false, error = "This event has ended." }
	end
	local price = crate.Price * (count :: number)
	if not EconomyService.TrySpend(player, crate.Currency :: any, price) then
		return { ok = false, error = if crate.Currency == "Coins" then "Not enough coins!" else "Not enough gems!" }
	end
	local pulls = grantPulls(player, crate, count :: number)
	return { ok = true, crate = crate.Id, pulls = pulls }
end

function GachaService.OpenTicket(player: Player, crateId: any): { [string]: any }
	local crate = if type(crateId) == "string" then GachaDefinitions.Get(crateId) else nil
	if crate == nil then
		return { ok = false, error = "Unknown gacha." }
	end
	local spent = DataService.Update(player, function(profile)
		local have = profile.Tickets[crate.Id] or 0
		if have <= 0 then
			return false
		end
		if have > 1 then
			profile.Tickets[crate.Id] = have - 1
		else
			profile.Tickets[crate.Id] = nil
		end
		return true
	end)
	if spent ~= true then
		return { ok = false, error = "You don't have that gacha." }
	end
	local pulls = grantPulls(player, crate, 1)
	return { ok = true, crate = crate.Id, pulls = pulls }
end

return GachaService
