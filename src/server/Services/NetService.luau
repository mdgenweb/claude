-- The only client -> server entry point. Every action is whitelisted, type-checked
-- and rate-limited; handlers re-validate all game rules themselves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local ShopService = require(script.Parent.ShopService)

local Request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request") :: RemoteFunction

local NetService = {}

local MIN_INTERVAL = 0.15

local handlers: { [string]: { arg: string?, fn: (Player, any) -> (boolean, string?) } } = {
	Upgrade = { fn = ProgressService.upgrade },
	UnlockGate = { arg = "number", fn = ProgressService.unlockGate },
	Rebirth = { fn = ProgressService.rebirth },
	ClaimWorkshop = { fn = ProgressService.claimWorkshop },
	ClaimDaily = { fn = ProgressService.claimDaily },
	SelectTool = { arg = "string", fn = ProgressService.selectTool },
	SelectFinish = { arg = "string", fn = ProgressService.selectFinish },
	CraftWorker = { fn = ProgressService.craftWorker },
	Buy = { arg = "string", fn = ShopService.buy },
	ActivateBoost = { fn = ShopService.activateBoost },
	Sync = {
		fn = function(player)
			StateService.push(player)
			return true
		end,
	},
	Menu = {
		arg = "boolean",
		fn = function(player, open)
			local session = StateService.get(player)
			if session then
				session.InMenu = open
			end
			return true
		end,
	},
}

local lastCall: { [Player]: { [string]: number } } = {}

function NetService.init()
	Request.OnServerInvoke = function(player: Player, action: any, arg: any)
		if type(action) ~= "string" then
			return false
		end
		local handler = handlers[action]
		if not handler then
			return false
		end
		if handler.arg and type(arg) ~= handler.arg then
			return false
		end
		if type(arg) == "string" and #arg > 40 then
			return false
		end
		local calls = lastCall[player]
		if not calls then
			calls = {}
			lastCall[player] = calls
		end
		local now = os.clock()
		if action ~= "Menu" and calls[action] and now - calls[action] < MIN_INTERVAL then
			return false, "Slow down!"
		end
		calls[action] = now
		if not StateService.get(player) then
			return false, "Still loading your mech..."
		end
		local ok, result, message = pcall(handler.fn, player, arg)
		if not ok then
			warn("[NetService] " .. action .. " failed: " .. tostring(result))
			return false, "Something went wrong. Try again."
		end
		return result, message
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return NetService
