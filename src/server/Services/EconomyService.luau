--!strict
-- Currency and inventory primitives. Every grant/spend in the game goes through here, inside
-- DataService.Update, so values stay clamped and replicated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)

local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

export type ItemKind = "Ball" | "Explosion" | "Flyer" | "Ticket"

local EconomyService = {}

local function bagFor(profile: Profile, kind: string): { [string]: number }?
	if kind == "Ball" then
		return profile.Balls
	elseif kind == "Explosion" then
		return profile.Explosions
	elseif kind == "Flyer" then
		return profile.Flyers
	elseif kind == "Ticket" then
		return profile.Tickets
	end
	return nil
end
EconomyService.BagFor = bagFor

function EconomyService.IsValidItem(kind: string, id: string): boolean
	if kind == "Ball" then
		return BallDefinitions.Exists(id)
	elseif kind == "Explosion" or kind == "Flyer" then
		return CosmeticDefinitions.Exists(kind, id)
	elseif kind == "Ticket" then
		return GachaDefinitions.Get(id) ~= nil
	end
	return false
end

function EconomyService.IsTradable(kind: string, id: string): boolean
	if kind == "Ball" then
		local def = BallDefinitions.Get(id)
		return def ~= nil and def.Tradable
	elseif kind == "Explosion" or kind == "Flyer" then
		local def = CosmeticDefinitions.Get(kind, id)
		return def ~= nil and def.Tradable
	end
	return false
end

function EconomyService.Count(player: Player, kind: string, id: string): number
	local profile = DataService.Get(player)
	if profile == nil then
		return 0
	end
	local bag = bagFor(profile, kind)
	return if bag then bag[id] or 0 else 0
end

-- Low-level mutation on an already-held profile (use inside DataService.Update).
function EconomyService.AddToProfile(profile: Profile, kind: string, id: string, count: number): boolean
	local bag = bagFor(profile, kind)
	if bag == nil or not EconomyService.IsValidItem(kind, id) then
		return false
	end
	local next = (bag[id] or 0) + count
	if next < 0 then
		return false
	end
	next = math.min(next, Economy.Limits.MaxItemCount)
	if next > 0 then
		bag[id] = next
	else
		bag[id] = nil
	end
	-- never leave an unowned cosmetic equipped
	if kind == "Explosion" and profile.Equipped.Explosion == id and next == 0 then
		profile.Equipped.Explosion = "classic"
	elseif kind == "Flyer" and profile.Equipped.Flyer == id and next == 0 then
		profile.Equipped.Flyer = "basic"
	end
	return true
end

function EconomyService.GrantItem(player: Player, kind: string, id: string, count: number?): boolean
	local result = DataService.Update(player, function(profile)
		return EconomyService.AddToProfile(profile, kind, id, count or 1)
	end)
	return result == true
end

function EconomyService.AddCurrency(player: Player, currency: "Coins" | "Gems", amount: number): boolean
	if amount ~= amount or amount <= 0 then
		return false
	end
	local result = DataService.Update(player, function(profile)
		if currency == "Coins" then
			profile.Coins = math.min(profile.Coins + math.floor(amount), Economy.Limits.MaxCoins)
		else
			profile.Gems = math.min(profile.Gems + math.floor(amount), Economy.Limits.MaxGems)
		end
		return true
	end)
	return result == true
end

-- Atomically checks and deducts. Returns false (and changes nothing) if unaffordable.
function EconomyService.TrySpend(player: Player, currency: "Coins" | "Gems", amount: number): boolean
	if amount ~= amount or amount < 0 then
		return false
	end
	local result = DataService.Update(player, function(profile)
		local balance = if currency == "Coins" then profile.Coins else profile.Gems
		if balance < amount then
			return false
		end
		if currency == "Coins" then
			profile.Coins -= amount
		else
			profile.Gems -= amount
		end
		return true
	end)
	return result == true
end

function EconomyService.Equip(player: Player, kind: string, id: string): boolean
	if kind ~= "Explosion" and kind ~= "Flyer" then
		return false
	end
	local result = DataService.Update(player, function(profile)
		local bag = bagFor(profile, kind)
		if bag == nil or (bag[id] or 0) <= 0 then
			return false
		end
		if kind == "Explosion" then
			profile.Equipped.Explosion = id
		else
			profile.Equipped.Flyer = id
		end
		return true
	end)
	return result == true
end

-- Generic reward table: { Kind = "Ball"|"Ticket"|"Coins"|"Gems"|"Explosion"|"Flyer", Id?, Amount? }
function EconomyService.GrantReward(player: Player, reward: { Kind: string, Id: string?, Amount: number? }): boolean
	if reward.Kind == "Coins" then
		return EconomyService.AddCurrency(player, "Coins", reward.Amount or 0)
	elseif reward.Kind == "Gems" then
		return EconomyService.AddCurrency(player, "Gems", reward.Amount or 0)
	elseif reward.Id then
		return EconomyService.GrantItem(player, reward.Kind, reward.Id, reward.Amount or 1)
	end
	return false
end

return EconomyService
