-- Six lanes, one per player. Lanes are handed out on join and freed on leave.
-- The lane signs in every yard show the owner (gold with a crown for Foundry VIP).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.Layout)
local Signal = require(Shared.Signal)

local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)

local LaneService = {}

LaneService.Assigned = Signal.new() -- (player, lane)
LaneService.Freed = Signal.new() -- (lane)

local owners: { [number]: Player } = {}

local GOLD = Color3.fromHex("#FFD12E")

function LaneService.refreshSign(lane: number)
	local labels = WorldService.get().LaneLabels[lane]
	if not labels then
		return
	end
	local owner = owners[lane]
	local session = owner and StateService.get(owner)
	local vip = session ~= nil and session.Passes.FoundryVIP == true
	for _, label in labels do
		if owner then
			label.Text = (if vip then "👑 " else "") .. owner.DisplayName
			label.TextColor3 = if vip then GOLD else Color3.new(1, 1, 1)
		else
			label.Text = "OPEN LANE"
			label.TextColor3 = Color3.fromHex("#B8C4DA")
		end
	end
end

function LaneService.ownerOf(lane: number): Player?
	return owners[lane]
end

function LaneService.laneOf(player: Player): number?
	for lane, owner in owners do
		if owner == player then
			return lane
		end
	end
	return nil
end

local function tryAssign(player: Player, session): boolean
	if session.Lane then
		return true
	end
	for lane = 1, Layout.Lanes do
		if not owners[lane] then
			owners[lane] = player
			session.Lane = lane
			LaneService.refreshSign(lane)
			StateService.push(player)
			LaneService.Assigned:Fire(player, lane)
			return true
		end
	end
	return false
end

function LaneService.init()
	StateService.Started:Connect(function(player, session)
		if not tryAssign(player, session) then
			StateService.notify(player, "Error", "Yard full", "You'll get the next free lane.")
		end
	end)
	StateService.Ended:Connect(function(player)
		local lane = LaneService.laneOf(player)
		if not lane then
			return
		end
		owners[lane] = nil
		LaneService.refreshSign(lane)
		LaneService.Freed:Fire(lane)
		-- Anyone who joined while the yard was full gets this lane.
		for waiting, session in StateService.all() do
			if not session.Lane and tryAssign(waiting, session) then
				StateService.notify(
					waiting,
					"Info",
					"Lane " .. lane .. " is yours!",
					"Head to your lane and start smashing."
				)
				break
			end
		end
	end)
end

return LaneService
