-- Auto Farm pass: walks the mech to the next junk inside the player's own lane and
-- unlocked yard (via the shared corridor), then lets the free auto-hit do the work.
-- Moving the stick / WASD pauses it briefly so the player is always in control.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Signal = require(Shared.Signal)

local Net = require(script.Parent.Parent.Net)

local AutoFarm = {}

AutoFarm.enabled = false
AutoFarm.Changed = Signal.new()

local player = Players.LocalPlayer
local controls = nil
local pausedUntil = 0
local menuOpen = false

local function getControls()
	if controls == nil then
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		end)
		controls = if ok then module else false
	end
	return controls or nil
end

local function manualInput(): boolean
	local c = getControls()
	if not c then
		return false
	end
	local ok, vector = pcall(function()
		return c:GetMoveVector()
	end)
	return ok and vector.Magnitude > 0.1
end

local function stop(humanoid: Humanoid?)
	if humanoid then
		humanoid:Move(Vector3.zero)
	end
end

function AutoFarm.toggle(force: boolean?)
	local on = if force ~= nil then force else not AutoFarm.enabled
	if on and not player:GetAttribute("HasAutoFarm") then
		on = false
	end
	if on == AutoFarm.enabled then
		return
	end
	AutoFarm.enabled = on
	if not on then
		local character = player.Character
		stop(character and character:FindFirstChildOfClass("Humanoid"))
	end
	AutoFarm.Changed:Fire(on)
end

local function laneTargets(lane: number, area: number): { Model }
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Targets")
	local laneFolder = folder and folder:FindFirstChild("Lane" .. lane)
	local out = {}
	if laneFolder then
		for _, model in laneFolder:GetChildren() do
			if
				model:IsA("Model")
				and model:GetAttribute("Area") == area
				and not model:GetAttribute("Dead")
				and model.PrimaryPart
			then
				table.insert(out, model)
			end
		end
	end
	return out
end

local function chooseArea(position: Vector3): number
	local here = Layout.areaAt(position)
	if here and Net.unlocked(here) then
		return here
	end
	local best = 1
	for area = 2, 3 do
		if Net.unlocked(area) then
			best = area
		end
	end
	return best
end

local lastPos: Vector3? = nil
local stuckSince = 0

local function step()
	if not AutoFarm.enabled or menuOpen or os.clock() < pausedUntil then
		return
	end
	local state = Net.State
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not state.Lane or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if manualInput() then
		pausedUntil = os.clock() + 1.5
		return
	end
	local position = root.Position
	local area = chooseArea(position)
	local targets = laneTargets(state.Lane, area)
	local best, bestDistance = nil, math.huge
	for _, model in targets do
		local d = Layout.reachDistance(position, model.PrimaryPart :: BasePart)
		if d < bestDistance then
			best, bestDistance = model, d
		end
	end
	if not best then
		stop(humanoid)
		return
	end
	if bestDistance <= Config.Combat.Reach - 1 then
		stop(humanoid) -- in reach: the free auto-hit takes over
		return
	end
	-- Walk to the closest point just outside the target's box (never through it).
	local hitbox = best.PrimaryPart :: BasePart
	local half = hitbox.Size / 2 + Vector3.new(2, 0, 2)
	local centre = hitbox.Position
	local approach = Vector3.new(
		math.clamp(position.X, centre.X - half.X, centre.X + half.X),
		position.Y,
		math.clamp(position.Z, centre.Z - half.Z, centre.Z + half.Z)
	)
	local route = Layout.route(position, area, state.Lane, approach)
	for _, waypoint in route do
		local flat = Vector3.new(waypoint.X - position.X, 0, waypoint.Z - position.Z)
		if flat.Magnitude > 2.5 then
			humanoid:MoveTo(Vector3.new(waypoint.X, position.Y, waypoint.Z))
			break
		end
	end
	-- Unstick: hop if we haven't moved in a while.
	if lastPos and (lastPos - position).Magnitude < 0.6 then
		if os.clock() - stuckSince > 1.5 then
			humanoid.Jump = true
			stuckSince = os.clock()
		end
	else
		stuckSince = os.clock()
	end
	lastPos = position
end

function AutoFarm.init()
	Net.MenuChanged:Connect(function(name)
		menuOpen = name ~= nil
	end)
	player:GetAttributeChangedSignal("HasAutoFarm"):Connect(function()
		if not player:GetAttribute("HasAutoFarm") then
			AutoFarm.toggle(false)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(step)
			if not ok then
				warn("[AutoFarm] " .. tostring(err))
			end
		end
	end)
end

return AutoFarm
