--!strict
-- Client mirror of server-owned state. Read-only: every change comes from the server.
--   StateController.Data         -> profile view (Schema.PublicView + Derived/Session/...)
--   StateController.Relics       -> { [relicId] = { Sold, Stock } }
--   StateController.Leaderboards -> { [stat] = { { Name, Value } } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local StateController = {}

StateController.Data = nil :: { [string]: any }?
StateController.Relics = {} :: { [string]: { Sold: number, Stock: number } }
StateController.Leaderboards = {} :: { [string]: { { Name: string, Value: number } } }
StateController.Event = { Active = false, Name = "", EndsAt = 0 } :: { Active: boolean, Name: string, EndsAt: number }
StateController.ReceivedAt = 0 -- os.clock() when Data arrived (for local timers)

StateController.DataChanged = Signal.new() -- (data, previous)
StateController.ServerInfoChanged = Signal.new() -- (kind)
StateController.Notified = Signal.new() -- ({ Text, Kind })

function StateController.Get(): { [string]: any }?
	return StateController.Data
end

function StateController.Derived(): { [string]: any }
	local data = StateController.Data
	return if data and data.Derived then data.Derived else {}
end

function StateController.HasPass(key: string): boolean
	local passes = StateController.Derived().Passes
	return passes ~= nil and passes[key] == true
end

-- Seconds since the last data packet (for countdowns between syncs).
function StateController.Since(): number
	return os.clock() - StateController.ReceivedAt
end

function StateController.Start()
	Remotes.Event("PlayerData").OnClientEvent:Connect(function(data)
		local previous = StateController.Data
		StateController.Data = data
		StateController.ReceivedAt = os.clock()
		StateController.DataChanged:Fire(data, previous)
	end)
	Remotes.Event("ServerInfo").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Kind == "Relics" and type(payload.Relics) == "table" then
			StateController.Relics = payload.Relics
		elseif payload.Kind == "Leaderboards" and type(payload.Boards) == "table" then
			StateController.Leaderboards = payload.Boards
		elseif payload.Kind == "Event" then
			StateController.Event = {
				Active = payload.Active == true,
				Name = if type(payload.Name) == "string" then payload.Name else "",
				EndsAt = if type(payload.EndsAt) == "number" then payload.EndsAt else 0,
			}
		end
		StateController.ServerInfoChanged:Fire(payload.Kind)
	end)
	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		StateController.Notified:Fire(payload)
	end)
end

return StateController
