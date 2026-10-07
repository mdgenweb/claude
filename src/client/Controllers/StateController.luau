--!strict
-- Client mirror of server-owned state: profile view, stations, leaderboards, notifications.
-- Read-only: every change comes from the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local StateController = {}

StateController.Data = nil :: { [string]: any }?
StateController.Stations = {} :: { [number]: { [string]: any } }
StateController.Leaderboards = nil :: { [string]: any }?

StateController.DataChanged = Signal.new() -- (data, previous)
StateController.StationChanged = Signal.new() -- (station payload)
StateController.LeaderboardChanged = Signal.new()
StateController.Notified = Signal.new() -- ({Text, Kind})

local localPlayer = Players.LocalPlayer

function StateController.Count(kind: string, id: string): number
	local data = StateController.Data
	if data == nil then
		return 0
	end
	local bag = if kind == "Ball" then data.Balls elseif kind == "Explosion" then data.Explosions elseif kind == "Flyer" then data.Flyers else data.Tickets
	return if bag then bag[id] or 0 else 0
end

-- Station the local player is standing on (queued or in a match), if any.
function StateController.MyStation(): ({ [string]: any }?, number?)
	for _, station in StateController.Stations do
		for padIndex, pad in station.Pads do
			if pad.UserId == localPlayer.UserId then
				return station, padIndex
			end
		end
	end
	return nil, nil
end

function StateController.Start()
	Remotes.Event("PlayerData").OnClientEvent:Connect(function(data)
		local previous = StateController.Data
		StateController.Data = data
		StateController.DataChanged:Fire(data, previous)
	end)
	Remotes.Event("StationState").OnClientEvent:Connect(function(payload)
		StateController.Stations[payload.Index] = payload
		StateController.StationChanged:Fire(payload)
	end)
	Remotes.Event("LeaderboardData").OnClientEvent:Connect(function(payload)
		StateController.Leaderboards = payload
		StateController.LeaderboardChanged:Fire(payload)
	end)
	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		StateController.Notified:Fire(payload)
	end)
end

return StateController
