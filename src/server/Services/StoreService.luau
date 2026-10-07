--!strict
-- Single request endpoint (RemoteFunction) for store / inventory / rewards actions.
-- Every action is validated by the owning service; the client never states prices or results.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GachaService = require(script.Parent.GachaService)
local CodeService = require(script.Parent.CodeService)
local RewardService = require(script.Parent.RewardService)
local MonetizationService = require(script.Parent.MonetizationService)

local StoreService = {}

local handlers: { [string]: (Player, any, any) -> { [string]: any } } = {
	OpenCrate = function(player, crateId, count)
		return GachaService.Open(player, crateId, count)
	end,
	OpenTicket = function(player, crateId)
		return GachaService.OpenTicket(player, crateId)
	end,
	Equip = function(player, kind, id)
		if not Validate.OneOf(kind, { "Explosion", "Flyer" }) or not Validate.Id(id) then
			return { ok = false, error = "Invalid item." }
		end
		local ok = EconomyService.Equip(player, kind, id)
		return if ok then { ok = true } else { ok = false, error = "You don't own that." }
	end,
	RedeemCode = function(player, code)
		return CodeService.Redeem(player, code)
	end,
	ClaimGroup = function(player)
		return RewardService.ClaimGroup(player)
	end,
	BuyGems = function(player, key)
		return MonetizationService.RequestGemPack(player, key)
	end,
}

function StoreService.Start()
	Guard.OnInvoke(Remotes.Function("StoreRequest"), 4, 8, function(player: Player, action: any, a1: any, a2: any)
		if type(action) ~= "string" then
			return { ok = false, error = "Invalid request." }
		end
		local handler = handlers[action]
		if handler == nil then
			return { ok = false, error = "Invalid request." }
		end
		if DataService.Get(player) == nil then
			return { ok = false, error = "Your data is still loading." }
		end
		return handler(player, a1, a2)
	end)
end

return StoreService
