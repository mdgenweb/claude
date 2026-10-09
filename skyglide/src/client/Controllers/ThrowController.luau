--!strict
-- Local throwing input and feedback. Intents only: the server times the launch meter, builds the
-- plan and judges every gust tap; this module just tells it "started holding", "released" and
-- "tapped for ring N".
--   * Throw Zone detection (same math as MapService.InThrowZone) -> Bus.InThrowZoneChanged.
--   * THROW hold/release: Press()/Release() (HUD button), E and gamepad R2 while in the zone.
--   * ChargeState remote -> Bus.ChargeChanged(charging, startedAt, reason).
--   * Gust taps during the local flight (click, touch, Space, gamepad A, or the HUD's Tap()):
--     at most ONE RequestGust per ring, so spam can never fish for PERFECTs.
--   * Cosmetic throw animation: right-arm wind-up on press, swing on launch, held glider hidden
--     while the thrown one flies. FlightRenderer calls SetActive(plan | nil).
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flight = require(Shared.Config.Flight)
local Map = require(Shared.Config.Map)
local FlightSim = require(Shared.Sim.FlightSim)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local Bus = require(script.Parent.Bus)
local Net = require(script.Parent.Net)
local StateController = require(script.Parent.StateController)
local UIController = require(script.Parent.UIController)

local ThrowController = {}

-- (ringIndex: number, verdict: "Perfect" | "Miss" | "Late") local judgement of a sent gust tap.
ThrowController.Tapped = Signal.new()

local LocalPlayer = Players.LocalPlayer

local THROW_ACTION = "SkyGlideThrow"
local GUST_ACTION = "SkyGlideGust"
local ZONE_CHECK_INTERVAL = 0.1
local TOAST_COOLDOWN = 2
local LATE_GRACE = 0.2 -- a tap this soon after a ring's window still goes to that ring (ping help)
local WIND_UP_ANGLE = -1.0 -- radians: arm swung back
local RELEASE_ANGLE = 1.7 -- radians: arm swung forward

local inZone = false
local pressing = false
local charging = false
local activePlan: FlightSim.Plan? = nil
local sent: { [number]: boolean } = {}
local perfect: { [number]: boolean } = {}
local lastToast = 0

--------------------------------------------------------------------------------------------------
-- Arm animation and held glider
--------------------------------------------------------------------------------------------------

local baseC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local armTween: Tween? = nil
local armGeneration = 0
local woundUp = false
local heldConn: RBXScriptConnection? = nil

-- Right shoulder motor, its rest C0 and whether the rig is R15 (rotate about X) or R6 (about Z).
local function shoulder(): (Motor6D?, CFrame, boolean)
	local character = LocalPlayer.Character
	if not character then
		return nil, CFrame.identity, true
	end
	local r15 = true
	local upper = character:FindFirstChild("RightUpperArm")
	local motor = if upper then upper:FindFirstChild("RightShoulder") else nil
	if not (motor and motor:IsA("Motor6D")) then
		local torso = character:FindFirstChild("Torso")
		motor = if torso then torso:FindFirstChild("Right Shoulder") else nil
		r15 = false
	end
	if motor and motor:IsA("Motor6D") then
		local base = baseC0[motor]
		if not base then
			base = motor.C0
			baseC0[motor] = base
		end
		return motor, base, r15
	end
	return nil, CFrame.identity, true
end

local function poseArm(angle: number, duration: number, style: Enum.EasingStyle)
	local motor, base, r15 = shoulder()
	if not motor then
		return
	end
	if armTween then
		armTween:Cancel()
	end
	local rotation = if r15 then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, 0, angle)
	local tween = TweenService:Create(motor, TweenInfo.new(duration, style, Enum.EasingDirection.Out), { C0 = base * rotation })
	armTween = tween
	tween:Play()
end

local function windUp()
	armGeneration += 1
	woundUp = true
	poseArm(WIND_UP_ANGLE, 0.22, Enum.EasingStyle.Quad)
end

local function restoreArm()
	armGeneration += 1
	if woundUp or armTween then
		woundUp = false
		poseArm(0, 0.2, Enum.EasingStyle.Quad)
	end
end

-- Back (if not already wound up) -> forward -> rest.
local function swing()
	armGeneration += 1
	local generation = armGeneration
	local wasWound = woundUp
	woundUp = false
	task.spawn(function()
		if not wasWound then
			poseArm(WIND_UP_ANGLE, 0.08, Enum.EasingStyle.Quad)
			task.wait(0.08)
			if generation ~= armGeneration then
				return
			end
		end
		poseArm(RELEASE_ANGLE, 0.1, Enum.EasingStyle.Quad)
		task.wait(0.16)
		if generation ~= armGeneration then
			return
		end
		poseArm(0, 0.3, Enum.EasingStyle.Quad)
	end)
end

local function setModelHidden(model: Instance, hidden: boolean)
	local value = if hidden then 1 else 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = value
		end
	end
end

local function hideHeldGlider(hidden: boolean)
	if heldConn then
		heldConn:Disconnect()
		heldConn = nil
	end
	local character = LocalPlayer.Character
	if not character then
		return
	end
	local held = character:FindFirstChild("HeldGlider")
	if held then
		setModelHidden(held, hidden)
	end
	if hidden then
		-- the server may rebuild the held glider mid-flight (equip change): keep it hidden
		heldConn = character.ChildAdded:Connect(function(child)
			if child.Name == "HeldGlider" then
				task.defer(setModelHidden, child, true)
			end
		end)
	end
end

--------------------------------------------------------------------------------------------------
-- Throw input
--------------------------------------------------------------------------------------------------

-- Starts holding THROW (HUD button down / E / R2). Ignored while a menu is open or flying.
function ThrowController.Press()
	if pressing or activePlan ~= nil or UIController.AnyMenuOpen() or StateController.Data == nil then
		return
	end
	pressing = true
	windUp()
	Net.Fire("RequestThrowCharge")
end

-- Releases THROW. The server turns the hold time into the launch meter.
function ThrowController.Release()
	if not pressing then
		return
	end
	pressing = false
	Net.Fire("RequestThrow")
end

local function onThrowAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult?
	if state == Enum.UserInputState.Begin then
		if UIController.AnyMenuOpen() or activePlan ~= nil then
			return Enum.ContextActionResult.Pass
		end
		ThrowController.Press()
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if pressing then
			ThrowController.Release()
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

local function zoneCheck(): boolean
	local data = StateController.Data
	local character = LocalPlayer.Character
	if not data or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart")) or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local world = if type(data.World) == "number" then data.World else 1
	local l = root.Position - Map.Origin(world)
	local z = Map.ThrowZone
	local tol = Map.StandTolerance
	return l.X >= z.MinX - tol and l.X <= z.MaxX + tol and l.Z >= z.MinZ - tol and l.Z <= z.MaxZ + tol and l.Y > -4 and l.Y < 16
end

local function setInZone(value: boolean)
	if value == inZone then
		return
	end
	inZone = value
	if value then
		ContextActionService:BindAction(THROW_ACTION, onThrowAction, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
	else
		ContextActionService:UnbindAction(THROW_ACTION)
		if pressing then
			ThrowController.Release() -- the server answers NotInZone, which shows the hint
		end
	end
	Bus.InThrowZoneChanged:Fire(value)
end

local function onChargeState(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local isCharging = payload.Charging == true
	local startedAt = if type(payload.StartedAt) == "number" then payload.StartedAt else 0
	local reason: string? = if type(payload.Reason) == "string" then payload.Reason else nil
	charging = isCharging
	if not isCharging then
		if reason == "NotInZone" then
			pressing = false
			local now = os.clock()
			if now - lastToast >= TOAST_COOLDOWN then
				lastToast = now
				UIController.Toast("Walk into the THROW ZONE!", "Info")
			end
		elseif reason == "Flying" or reason == "Dead" or reason == "Loading" or reason == "Launched" then
			pressing = false
		end
		-- "Cooldown" keeps the hold: releasing still sends a quick throw once the cooldown is over
		if reason ~= "Launched" and not pressing then
			restoreArm()
		end
	end
	Bus.ChargeChanged:Fire(isCharging, startedAt, reason)
end

--------------------------------------------------------------------------------------------------
-- Gust taps
--------------------------------------------------------------------------------------------------

-- One gust tap (also called by the HUD's full-screen tap area). Sends at most one RequestGust per
-- ring: a tap in the PERFECT window or the "too early" window spends that ring (the server judges
-- it), a tap far too early is ignored without spending anything, and a tap just after a ring's
-- window is credited to that ring so the server's ping allowance can still accept it.
function ThrowController.Tap()
	local plan = activePlan
	if not plan then
		return
	end
	local t = Workspace:GetServerTimeNow() - plan.Start
	local times = plan.RingTimes
	local idx = FlightSim.NextRing(plan, t)
	local previous = if idx then idx - 1 else #times
	if previous >= 1 and not sent[previous] and t <= times[previous] + Flight.GustLate + LATE_GRACE then
		sent[previous] = true
		Net.Fire("RequestGust", plan.Id, previous)
		ThrowController.Tapped:Fire(previous, "Late")
		return
	end
	if idx == nil or sent[idx] then
		return
	end
	local verdict = FlightSim.JudgeGust(plan, idx, t, 0)
	if verdict == nil then
		return -- far too early: the server would ignore it as well
	end
	sent[idx] = true
	if verdict == "Perfect" then
		perfect[idx] = true
	end
	Net.Fire("RequestGust", plan.Id, idx)
	ThrowController.Tapped:Fire(idx, verdict)
end

local function onGustAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult?
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if GuiService.SelectedObject ~= nil or UIController.AnyMenuOpen() then
		return Enum.ContextActionResult.Pass -- gamepad A is pressing a selected button
	end
	ThrowController.Tap()
	return Enum.ContextActionResult.Sink -- no jumping mid-flight
end

--------------------------------------------------------------------------------------------------
-- Public state
--------------------------------------------------------------------------------------------------

-- The local player's flight plan while it is in the air (nil otherwise).
function ThrowController.ActivePlan(): FlightSim.Plan?
	return activePlan
end

-- Called by FlightRenderer when the local flight starts (plan) and when its visuals end (nil).
function ThrowController.SetActive(plan: FlightSim.Plan?)
	if plan == activePlan then
		return
	end
	activePlan = plan
	table.clear(sent)
	table.clear(perfect)
	if plan then
		pressing = false
		charging = false
		ContextActionService:BindActionAtPriority(
			GUST_ACTION,
			onGustAction,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonA
		)
		hideHeldGlider(true)
		swing()
	else
		ContextActionService:UnbindAction(GUST_ACTION)
		hideHeldGlider(false)
	end
end

-- True when the local gust tap for ring `index` was judged PERFECT on this client.
function ThrowController.IsPerfect(index: number): boolean
	return perfect[index] == true
end

-- True once a tap was sent for ring `index`.
function ThrowController.WasTapped(index: number): boolean
	return sent[index] == true
end

function ThrowController.InZone(): boolean
	return inZone
end

function ThrowController.IsCharging(): boolean
	return charging
end

function ThrowController.IsPressing(): boolean
	return pressing
end

function ThrowController.Start()
	Remotes.Event("ChargeState").OnClientEvent:Connect(onChargeState)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < ZONE_CHECK_INTERVAL then
			return
		end
		acc = 0
		setInZone(zoneCheck())
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or activePlan == nil then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			ThrowController.Tap()
		end
	end)

	LocalPlayer.CharacterAdded:Connect(function()
		pressing = false
		charging = false
		woundUp = false
		armTween = nil
		armGeneration += 1
		if activePlan then
			hideHeldGlider(true) -- rebinds ChildAdded on the new character
		end
	end)
end

return ThrowController
