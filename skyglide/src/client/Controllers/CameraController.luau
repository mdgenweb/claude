--!strict
-- Throw/flight camera (docs/DESIGN.md §6). Phases:
--   Hub    default Custom camera (nothing runs)
--   Charge over-the-shoulder view down the channel while THROW is held, slight FOV zoom-in
--   Follow Scriptable chase camera behind/above the local glider. Position and look point are
--          critically damped springs RELATIVE to the glider (so 250 studs/s never drags them
--          behind); the first moments pull back from the shoulder ("Launch"), FOV widens with
--          speed, perfect rings shake it a little, special throws get a slow wide zoom
--   Land   hold on the splash
--   Return ease back to the character, then restore the Custom camera and its subject
-- Data.Settings.FollowCam == false keeps the Custom camera throughout. Every exit (respawn,
-- cancelled flight, world change, setting toggled, watchdogs) ends in restore(), so the camera
-- can never get stuck in Scriptable mode.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flight = require(Shared.Config.Flight)
local Map = require(Shared.Config.Map)

local Bus = require(script.Parent.Bus)
local StateController = require(script.Parent.StateController)
local FlightRenderer = require(script.Parent.FlightRenderer)

local CameraController = {}

type Phase = "Hub" | "Charge" | "Follow" | "Land" | "Return"

local LocalPlayer = Players.LocalPlayer

local CHARGE_OFFSET = Vector3.new(3.4, 3.2, 10.5) -- right shoulder, behind (channel runs toward -Z)
local CHARGE_FOV_DROP = 7
local FOLLOW_FOV_GAIN = 15 -- 70 -> 85 at full speed
local SPECIAL_TIME = 1.6
local LAND_HOLD_MAX = 2.2 -- seconds in Land before returning even without FlightEnded
local LAUNCH_TIME = 0.6

local phase: Phase = "Hub"
local hubFov = 70
local savedSubject: Instance? = nil

-- spring state (relative to the current anchor: character root or glider)
local offset = Vector3.zero
local offsetVel = Vector3.zero
local look = Vector3.zero
local lookVel = Vector3.zero
local fov = 70
local fovVel = 0

-- last applied absolute camera
local camPos = Vector3.zero
local lookPoint = Vector3.new(0, 0, -1)

local chargeAt = 0
local launchAwaitUntil = 0
local followStart = 0
local specialUntil = 0
local landAt = 0
local landPoint = Vector3.zero
local returnFrom = CFrame.identity
local returnFov = 70
local returnStart = 0
local returnTime = 0.6
local shake = 0
local rng = Random.new()

local function followCamEnabled(): boolean
	local data = StateController.Data
	local settings = data and data.Settings
	return not (type(settings) == "table" and settings.FollowCam == false)
end

local function characterRoot(): BasePart?
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function currentWorld(): number
	local data = StateController.Data
	return if data and type(data.World) == "number" then data.World else 1
end

-- Exact critically damped spring step (stable for any dt).
local function springV(x: Vector3, v: Vector3, target: Vector3, omega: number, dt: number): (Vector3, Vector3)
	local delta = x - target
	local decay = math.exp(-omega * dt)
	local tmp = (v + delta * omega) * dt
	return target + (delta + tmp) * decay, (v - tmp * omega) * decay
end

local function springN(x: number, v: number, target: number, omega: number, dt: number): (number, number)
	local delta = x - target
	local decay = math.exp(-omega * dt)
	local tmp = (v + delta * omega) * dt
	return target + (delta + tmp) * decay, (v - tmp * omega) * decay
end

-- Re-expresses the current camera relative to a new anchor so switching anchors never jumps.
local function anchorTo(anchor: Vector3)
	offset = camPos - anchor
	look = lookPoint - anchor
	offsetVel = Vector3.zero
	lookVel = Vector3.zero
end

local function apply(camera: Camera, pos: Vector3, target: Vector3)
	camPos = pos
	lookPoint = target
	if (target - pos).Magnitude < 1e-3 then
		return
	end
	camera.CFrame = CFrame.lookAt(pos, target)
	camera.Focus = CFrame.new(target)
	camera.FieldOfView = fov
end

-- Hands the camera back to the default Custom controller.
local function restore()
	local camera = Workspace.CurrentCamera
	local wasActive = phase ~= "Hub"
	phase = "Hub"
	shake = 0
	if camera and wasActive then
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		elseif savedSubject and savedSubject.Parent then
			camera.CameraSubject = savedSubject :: any
		end
		camera.FieldOfView = hubFov
	end
	savedSubject = nil
end

-- Takes the camera over (saving the Hub state the first time).
local function takeCamera(camera: Camera)
	if phase == "Hub" then
		savedSubject = camera.CameraSubject
		hubFov = math.clamp(camera.FieldOfView, 40, 100)
		fov = camera.FieldOfView
		fovVel = 0
		camPos = camera.CFrame.Position
		lookPoint = camPos + camera.CFrame.LookVector * 15
	end
	camera.CameraType = Enum.CameraType.Scriptable
end

local function beginReturn()
	if phase == "Hub" or phase == "Return" then
		return
	end
	local root = characterRoot()
	if not root then
		restore()
		return
	end
	returnFrom = CFrame.lookAt(camPos, lookPoint)
	returnFov = fov
	returnStart = os.clock()
	local distance = (camPos - root.Position).Magnitude
	returnTime = math.clamp(0.45 + distance / 2500, 0.45, 1.1)
	phase = "Return"
end

local function returnTarget(root: BasePart): CFrame
	local forward = root.CFrame.LookVector
	local flat = Vector3.new(forward.X, 0, forward.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	return CFrame.lookAt(focus - flat * 12 + Vector3.new(0, 3.5, 0), focus)
end

--------------------------------------------------------------------------------------------------
-- Phase entry
--------------------------------------------------------------------------------------------------

local function enterCharge()
	if phase == "Follow" or phase == "Land" or not followCamEnabled() then
		return
	end
	local camera = Workspace.CurrentCamera
	local root = characterRoot()
	if not camera or not root then
		return
	end
	if phase == "Return" then
		local cf = camera.CFrame
		camPos = cf.Position
		lookPoint = camPos + cf.LookVector * 15
	end
	takeCamera(camera)
	anchorTo(root.Position)
	phase = "Charge"
	chargeAt = os.clock()
	launchAwaitUntil = 0
end

local function enterFollow(special: boolean)
	if not followCamEnabled() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if phase == "Return" then
		local cf = camera.CFrame
		camPos = cf.Position
		lookPoint = camPos + cf.LookVector * 15
	end
	takeCamera(camera)
	anchorTo(FlightRenderer.LocalState().Position)
	phase = "Follow"
	followStart = os.clock()
	specialUntil = if special then followStart + SPECIAL_TIME else 0
end

local function enterLand(position: Vector3)
	phase = "Land"
	landAt = os.clock()
	landPoint = position
end

--------------------------------------------------------------------------------------------------
-- Per-frame update (runs after the default camera)
--------------------------------------------------------------------------------------------------

local function updateCharge(camera: Camera, dt: number)
	local root = characterRoot()
	local clock = os.clock()
	if not root or clock - chargeAt > Flight.MeterMaxHold + 3 or (launchAwaitUntil > 0 and clock > launchAwaitUntil) then
		beginReturn()
		return
	end
	local anchor = root.Position
	local target = Map.ChannelPoint(currentWorld(), 0, 16, 110) - anchor
	offset, offsetVel = springV(offset, offsetVel, CHARGE_OFFSET, 7, dt)
	look, lookVel = springV(look, lookVel, target, 7, dt)
	fov, fovVel = springN(fov, fovVel, hubFov - CHARGE_FOV_DROP, 5, dt)
	apply(camera, anchor + offset, anchor + look)
end

local function updateFollow(camera: Camera, dt: number)
	local state = FlightRenderer.LocalState()
	if not state.Active then
		beginReturn()
		return
	end
	if state.Landed then
		enterLand(state.LandPosition)
		return
	end
	local anchor = state.Position
	local v = state.Velocity
	local dir = if v.Magnitude > 1 then v.Unit else Vector3.new(0, 0, -1)
	-- chase mostly along the channel so sway and climbs don't swing the camera around
	local chase = Vector3.new(dir.X * 0.35, dir.Y * 0.4, dir.Z)
	chase = if chase.Magnitude > 0.01 then chase.Unit else Vector3.new(0, 0, -1)
	local clock = os.clock()
	local offsetTarget: Vector3
	local lookTarget: Vector3
	local fovTarget: number
	local omega: number
	if clock < specialUntil then
		local k = 1 - (specialUntil - clock) / SPECIAL_TIME
		offsetTarget = -chase * 26 + Vector3.new(10, 8, 0)
		lookTarget = chase * 4
		fovTarget = hubFov - 10 - 12 * k -- slow cinematic zoom-in
		omega = 3
	else
		local speedK = math.clamp((state.Speed - 40) / 220, 0, 1)
		offsetTarget = -chase * (14 + 3 * speedK) + Vector3.new(0, 5, 0)
		lookTarget = chase * 18 + Vector3.new(0, 1, 0)
		fovTarget = hubFov + FOLLOW_FOV_GAIN * speedK
		omega = if clock - followStart < LAUNCH_TIME then 4.5 else 7
	end
	offset, offsetVel = springV(offset, offsetVel, offsetTarget, omega, dt)
	look, lookVel = springV(look, lookVel, lookTarget, omega + 3, dt)
	fov, fovVel = springN(fov, fovVel, fovTarget, 4, dt)
	local jitter = Vector3.zero
	if shake > 0.01 then
		jitter = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * shake
		shake *= math.exp(-dt * 9)
	end
	apply(camera, anchor + offset + jitter * 0.4, anchor + look + jitter)
end

local function updateLand(camera: Camera, dt: number)
	if os.clock() - landAt > LAND_HOLD_MAX or not FlightRenderer.LocalState().Active then
		beginReturn()
		return
	end
	-- hold position (drifting up a touch) and settle the view on the splash
	local pos = camPos + Vector3.new(0, 2 * dt, 0)
	local target = lookPoint:Lerp(landPoint, 1 - math.exp(-6 * dt))
	fov, fovVel = springN(fov, fovVel, hubFov + 4, 4, dt)
	apply(camera, pos, target)
end

local function updateReturn(camera: Camera)
	local root = characterRoot()
	if not root then
		restore()
		return
	end
	local a = math.clamp((os.clock() - returnStart) / returnTime, 0, 1)
	local e = if a < 0.5 then 4 * a * a * a else 1 - (-2 * a + 2) ^ 3 / 2
	local cf = returnFrom:Lerp(returnTarget(root), e)
	camera.CFrame = cf
	camera.Focus = CFrame.new(root.Position)
	camera.FieldOfView = returnFov + (hubFov - returnFov) * e
	camPos = cf.Position
	lookPoint = cf.Position + cf.LookVector * 15
	if a >= 1 then
		restore()
	end
end

local function update(dt: number)
	if phase == "Hub" then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		-- someone else took the camera back: stand down without fighting it
		phase = "Hub"
		savedSubject = nil
		return
	end
	if phase == "Charge" then
		updateCharge(camera, dt)
	elseif phase == "Follow" then
		updateFollow(camera, dt)
	elseif phase == "Land" then
		updateLand(camera, dt)
	elseif phase == "Return" then
		updateReturn(camera)
	end
end

--------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------

-- Current phase name ("Hub", "Charge", "Follow", "Land", "Return").
function CameraController.Phase(): string
	return phase
end

-- Adds a short camera shake (Follow phase only).
function CameraController.Shake(amount: number)
	if phase == "Follow" then
		shake = math.max(shake, amount)
	end
end

-- Immediately hands the camera back to the Custom controller.
function CameraController.Reset()
	restore()
end

function CameraController.Start()
	Bus.ChargeChanged:Connect(function(charging: boolean, _startedAt: number, reason: string?)
		if charging then
			enterCharge()
		elseif phase == "Charge" then
			if reason == "Launched" then
				launchAwaitUntil = os.clock() + 2 -- wait for FlightStarted
			else
				beginReturn()
			end
		end
	end)
	Bus.FlightStarted:Connect(function(plan, isLocal: boolean)
		if isLocal then
			enterFollow(type(plan) == "table" and plan.Special ~= nil)
		end
	end)
	Bus.RingPassed:Connect(function(_index: number, perfect: boolean)
		if perfect then
			CameraController.Shake(0.55)
		end
	end)
	Bus.FlightEnded:Connect(function(_plan, isLocal: boolean)
		if isLocal and (phase == "Follow" or phase == "Land") then
			beginReturn()
		end
	end)
	Bus.WorldChanged:Connect(function()
		restore()
	end)
	StateController.DataChanged:Connect(function(data, previous)
		if phase == "Hub" or type(data) ~= "table" then
			return
		end
		if not followCamEnabled() then
			restore()
		elseif type(previous) == "table" and data.World ~= previous.World then
			restore()
		end
	end)
	LocalPlayer.CharacterAdded:Connect(function()
		if phase == "Charge" or phase == "Return" then
			restore()
		end
	end)
	RunService:BindToRenderStep("SkyGlideCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
