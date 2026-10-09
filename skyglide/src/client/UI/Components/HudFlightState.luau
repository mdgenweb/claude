--!strict
-- Shared "is the local player's glider in the air?" flag for the HUD pieces (throw button,
-- tap area, left-menu fade, distance counter). Driven by Bus.FlightStarted/FlightEnded for the
-- local flight, with a failsafe timeout so a lost FlightEnded can never leave the HUD stuck.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local Bus = require(script.Parent.Parent.Parent.Controllers.Bus)

local HudFlightState = {}

HudFlightState.Active = false
HudFlightState.Plan = nil :: { [string]: any }?
HudFlightState.Changed = Signal.new() -- (active: boolean, plan: table?)

local FAILSAFE = 8 -- seconds after the planned landing

local function set(active: boolean, plan: { [string]: any }?)
	if HudFlightState.Active == active and HudFlightState.Plan == plan then
		return
	end
	HudFlightState.Active = active
	HudFlightState.Plan = plan
	HudFlightState.Changed:Fire(active, plan)
end

Bus.FlightStarted:Connect(function(plan: any, isLocal: any)
	if isLocal ~= true or type(plan) ~= "table" then
		return
	end
	set(true, plan)
	local duration = if type(plan.Duration) == "number" then plan.Duration else 10
	task.delay(duration + FAILSAFE, function()
		if HudFlightState.Plan == plan then
			set(false, nil)
		end
	end)
end)

Bus.FlightEnded:Connect(function(plan: any, isLocal: any)
	if isLocal ~= true then
		return
	end
	local current = HudFlightState.Plan
	if current == nil or type(plan) ~= "table" or plan.Id == current.Id then
		set(false, nil)
	end
end)

return HudFlightState
