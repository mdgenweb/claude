--!strict
-- Single source of truth for every network endpoint. The server creates the instances
-- (Remotes.Init), clients wait for them (Remotes.Get). Clients can only *request*: there is
-- no remote that grants currency, deals damage or decides results.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec: { [string]: "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent" } = {
	-- client -> server requests
	QueueRequest = "RemoteEvent", -- (action: "Play"|"Leave"|"Practice", mode?)
	InviteRequest = "RemoteEvent", -- (targetUserId)
	InviteResponse = "RemoteEvent", -- (inviteId, accept)
	SelectionRequest = "RemoteEvent", -- (action: "Pick"|"Reroll"|"Collection", arg)
	AimUpdate = "UnreliableRemoteEvent", -- (angle) live aim, low rate
	AimLock = "RemoteEvent", -- (angle)
	TradeRequest = "RemoteEvent", -- (action, ...)
	StoreRequest = "RemoteFunction", -- (action, args) -> result

	-- server -> client
	PlayerData = "RemoteEvent", -- full sanitized profile view
	Notify = "RemoteEvent", -- toast { Text, Kind }
	StationState = "RemoteEvent", -- public station/match summary (broadcast)
	MatchPrivate = "RemoteEvent", -- participant-only phase payloads
	MatchPublic = "RemoteEvent", -- phase changes / round results for participants + spectators
	BattleEvent = "RemoteEvent", -- batched simulation events
	BattleSnapshot = "UnreliableRemoteEvent", -- binary 20 Hz snapshots
	TradeState = "RemoteEvent",
	InviteReceived = "RemoteEvent",
	LeaderboardData = "RemoteEvent",
	RewardPopup = "RemoteEvent", -- modal rewards (first battle, level up, weekly)
	OpenUI = "RemoteEvent", -- server asks client to open a screen (e.g. prompts)
}

local Remotes = {}
Remotes.Spec = Spec

local FOLDER_NAME = "Remotes"

function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name, className in Spec do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Event(name: string): RemoteEvent
	assert(Spec[name] == "RemoteEvent", "not a RemoteEvent: " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Unreliable(name: string): UnreliableRemoteEvent
	assert(Spec[name] == "UnreliableRemoteEvent", "not an UnreliableRemoteEvent: " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	assert(Spec[name] == "RemoteFunction", "not a RemoteFunction: " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
