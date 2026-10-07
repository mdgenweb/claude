--!strict
-- Lobby: default character camera. Battle: front-on framing of the arena (reference
-- screenshot 4) that refits to the viewport aspect, eased transitions, restrained shake and
-- FOV punches for heavy hits only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArenaGeometry = require(Shared.Visual.ArenaGeometry)

local CameraController = {}

local BASE_FOV = 70
local TRANSITION = 0.9

local inBattle = false
local stationCF: CFrame? = nil
local kind = "Duel"
local fromCF: CFrame? = nil
local transitionStart = 0
local exiting = false
local shakeMag = 0
local shakeTime = 0
local fovPunch = 0
local rng = Random.new()

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function targetCFrame(camera: Camera): CFrame
	local size = camera.ViewportSize
	local aspect = if size.Y > 0 then size.X / size.Y else 16 / 9
	return ArenaGeometry.CameraCFrame(stationCF :: CFrame, kind, aspect, BASE_FOV)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	if not inBattle and not exiting then
		return
	end
	local t = ease((os.clock() - transitionStart) / TRANSITION)
	local cf: CFrame
	if exiting then
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local back = if root then CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0)) else camera.CFrame
		cf = (fromCF :: CFrame):Lerp(back, t)
		if t >= 1 then
			exiting = false
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = BASE_FOV
			return
		end
	else
		local target = targetCFrame(camera)
		cf = if fromCF and t < 1 then fromCF:Lerp(target, t) else target
	end
	-- shake (decaying random offset) and fov punch
	if shakeTime > 0 then
		shakeTime -= dt
		local m = shakeMag * math.clamp(shakeTime / 0.25, 0, 1)
		cf *= CFrame.new(rng:NextNumber(-m, m), rng:NextNumber(-m, m), 0) * CFrame.Angles(0, 0, rng:NextNumber(-m, m) * 0.02)
	end
	fovPunch = fovPunch * math.exp(-dt * 10)
	camera.FieldOfView = BASE_FOV + fovPunch
	camera.CFrame = cf
end

function CameraController.EnterBattle(station: CFrame, arenaKind: string)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	stationCF = station
	kind = arenaKind
	if not inBattle then
		fromCF = camera.CFrame
		transitionStart = os.clock()
	end
	inBattle = true
	exiting = false
	camera.CameraType = Enum.CameraType.Scriptable
end

function CameraController.ExitBattle()
	local camera = Workspace.CurrentCamera
	if not inBattle or camera == nil then
		return
	end
	inBattle = false
	exiting = true
	fromCF = camera.CFrame
	transitionStart = os.clock()
end

function CameraController.InBattle(): boolean
	return inBattle
end

function CameraController.Shake(magnitude: number, duration: number?)
	if not inBattle then
		return
	end
	shakeMag = math.max(shakeMag * (if shakeTime > 0 then 1 else 0), magnitude)
	shakeTime = math.max(shakeTime, duration or 0.25)
end

function CameraController.Punch(fov: number)
	if inBattle then
		fovPunch = math.max(fovPunch, fov)
	end
end

function CameraController.Start()
	RunService:BindToRenderStep("OrbClashCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraController
