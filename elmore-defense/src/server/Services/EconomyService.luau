--[[
	EconomyService
	All currency and material changes go through here.

	Bundles look like { Gumballs = 100, VoidShards = 2, JoyfulCoupons = 3, PassXp = 120 }.
	`paid = true` marks currency as Robux-bought; `random = true` spends are blocked from touching paid balances
	for players under paid-random-item restrictions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Config.Items)

local EconomyService = {}

local registry

local function isCurrency(id: string): boolean
	return table.find(Items.CURRENCIES, id) ~= nil
end

function EconomyService.balance(profile, id: string): number
	if isCurrency(id) then
		return profile.currencies[id] or 0
	end
	return profile.items[id] or 0
end

-- Balance that may be spent on random outcomes by this player.
function EconomyService.spendable(player: Player, profile, id: string, random: boolean?): number
	local total = EconomyService.balance(profile, id)
	if random and isCurrency(id) and registry.ComplianceService.isRestricted(player) then
		return math.max(0, total - (profile.paid[id] or 0))
	end
	return total
end

function EconomyService.canAfford(player: Player, profile, costs: { [string]: number }, random: boolean?): (boolean, string?)
	for id, amount in costs do
		if amount > 0 and EconomyService.spendable(player, profile, id, random) < amount then
			local item = Items.get(id)
			local name = if item then item.name else id
			if random and EconomyService.balance(profile, id) >= amount then
				return false, "Purchased " .. name .. " can't be used for random rewards in your region."
			end
			return false, "Not enough " .. name .. "!"
		end
	end
	return true, nil
end

-- Spends a bundle atomically. Returns ok, err.
function EconomyService.spend(player: Player, profile, costs: { [string]: number }, random: boolean?): (boolean, string?)
	local ok, err = EconomyService.canAfford(player, profile, costs, random)
	if not ok then
		return false, err
	end
	for id, amount in costs do
		if amount > 0 then
			if isCurrency(id) then
				local total = profile.currencies[id] or 0
				local paid = profile.paid[id] or 0
				local earned = total - paid
				local fromEarned = math.min(amount, earned)
				local fromPaid = amount - fromEarned
				profile.currencies[id] = total - amount
				profile.paid[id] = math.max(0, paid - fromPaid)
			else
				profile.items[id] = (profile.items[id] or 0) - amount
			end
		end
	end
	registry.DataService.markDirty(player)
	return true, nil
end

-- Grants a bundle. `multipliers` may scale specific ids (e.g. 2x Gumballs pass).
function EconomyService.grant(player: Player, profile, bundle: { [string]: number }, options: { paid: boolean? }?)
	local granted = {}
	for id, amount in bundle do
		amount = math.floor(amount)
		if amount ~= 0 then
			if id == "PassXp" then
				registry.BattlePassService.addXp(player, profile, amount)
			elseif isCurrency(id) then
				profile.currencies[id] = (profile.currencies[id] or 0) + amount
				if options and options.paid then
					profile.paid[id] = (profile.paid[id] or 0) + amount
				end
			elseif Items.get(id) then
				profile.items[id] = (profile.items[id] or 0) + amount
			else
				warn("[EconomyService] unknown grant id", id)
			end
			granted[id] = amount
		end
	end
	registry.DataService.markDirty(player)
	return granted
end

function EconomyService.init(services)
	registry = services
end

return EconomyService
