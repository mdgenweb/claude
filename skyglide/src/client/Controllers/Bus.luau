--!strict
-- Client-side event bus so controllers and screens stay decoupled. Only cosmetic/UI events flow
-- through here; anything that changes game state goes to the server as an intent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local Bus = {
	-- Throwing (local player)
	ChargeChanged = Signal.new(), -- (charging: boolean, startedAt: number server time, reason: string?)
	InThrowZoneChanged = Signal.new(), -- (inZone: boolean)

	-- Flights
	FlightStarted = Signal.new(), -- (plan: FlightSim.Plan, isLocal: boolean)
	FlightProgress = Signal.new(), -- (distanceMeters: number, plan) local flight, every frame
	ZoneEntered = Signal.new(), -- (zone: Zones.Zone) local flight crossed a zone start
	GustWindow = Signal.new(), -- (open: boolean, ringIndex: number) next ring is tappable
	RingPassed = Signal.new(), -- (ringIndex: number, tappedPerfect: boolean, worldPosition: Vector3)
	RingResult = Signal.new(), -- ({ Id, Index, Perfect, Amount }) authoritative payout
	FlightLanded = Signal.new(), -- (payload) owner payload from the server (Distance, Zone, Wins, Skill, Special, UnlockedWorld, ...)
	FlightEnded = Signal.new(), -- (plan, isLocal) visuals finished (after splash)

	-- Training
	PadChanged = Signal.new(), -- (pad: Training.Pad?) pad under the local character
	TrainResult = Signal.new(), -- (amount: number)

	-- Pets
	HatchResult = Signal.new(), -- ({ Egg, Pets = { { Uid, Id } }, Source? })

	-- World
	WorldChanged = Signal.new(), -- (worldId: number)
}

return Bus
