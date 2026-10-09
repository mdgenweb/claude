--!strict
-- Single source of truth for every network endpoint. The server creates them (Remotes.Init),
-- clients wait for them. Client -> server endpoints are INTENTS only ("I want to throw", "I want
-- to buy X"); the server decides every outcome. There is no remote that grants Skill or Wins,
-- sets a distance, unlocks a world or finishes a rebirth.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec: { [string]: "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent" } = {
	-- client -> server (intents)
	RequestThrowCharge = "RemoteEvent", -- () start holding the launch meter
	RequestThrow = "RemoteEvent", -- () release / quick tap
	RequestGust = "RemoteEvent", -- (flightId, ringIndex) tap for a PERFECT catch
	RequestTrain = "RemoteEvent", -- () one manual rep on the pad you stand on
	RequestToggle = "RemoteEvent", -- (key: "AutoTrain"|"AutoThrow", on)
	RequestBuyThrowable = "RemoteFunction", -- (gliderId)
	RequestEquipThrowable = "RemoteFunction", -- (gliderId | "relic:<id>")
	RequestHatchEgg = "RemoteFunction", -- (eggId, count)
	RequestPetAction = "RemoteFunction", -- (action, args)
	RequestTrailAction = "RemoteFunction", -- (action: "Buy"|"Equip"|"Unequip", trailId)
	RequestRebirth = "RemoteFunction", -- ()
	RequestEnterWorld = "RemoteFunction", -- (worldId)
	RequestClaimGift = "RemoteFunction", -- (giftIndex)
	RequestClaimDaily = "RemoteFunction", -- ()
	RequestRedeemCode = "RemoteFunction", -- (code)
	RequestUseBoost = "RemoteFunction", -- (potionId)
	RequestPurchase = "RemoteFunction", -- (kind: "Pass"|"Product", key)
	RequestSetting = "RemoteEvent", -- (key, value) cosmetic preferences
	RequestTutorial = "RemoteEvent", -- ("Skip")
	AdminRequest = "RemoteFunction", -- diagnostics; rejected for non-admins

	-- server -> client
	PlayerData = "RemoteEvent", -- owner's profile view
	Notify = "RemoteEvent", -- toast { Text, Kind }
	FlightStarted = "RemoteEvent", -- broadcast plan
	FlightRing = "RemoteEvent", -- owner: { Id, Index, Perfect, Amount }
	FlightLanded = "RemoteEvent", -- broadcast { Id, UserId, Distance, Zone } + owner rewards
	ChargeState = "RemoteEvent", -- owner: { Charging, StartedAt }
	TrainResult = "RemoteEvent", -- owner: amount per rep (for popups)
	HatchResult = "RemoteEvent", -- owner: { Egg, Pets }
	ServerInfo = "RemoteEvent", -- relic stock, leaderboards
	WorldChanged = "RemoteEvent", -- owner: worldId (camera/lighting swap)
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
