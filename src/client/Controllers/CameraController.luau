--!nonstrict
-- Side-view diorama camera: frames the current lab, smooth zoom-to-cursor and pan, trauma-based
-- screen shake, FOV punches and an optional follow target.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Spring = require(Shared.Util.Spring)

local CameraController = {
	planeZ = 0,
	trauma = 0,
	shakeScale = 1,
}

local BASE_FOV = 38
local camera: Camera

local focus = Spring.new(Vector3.zero, 9, 1)
local distance = Spring.new(100, 9, 1)
local fovKick = Spring.new(0, 14, 0.55)

local fitDistance = 100
local roomWidth, roomHeight = 112, 60
local origin = Vector3.zero
local follow: BasePart? = nil

local function noise(t: number, seed: number): number
	return math.noise(t, seed * 13.37, 0.5)
end

function CameraController:Init(controllers)
	self.C = controllers
end

local function viewportAspect(): number
	local size = camera.ViewportSize
	if size.Y <= 0 then
		return 16 / 9
	end
	return size.X / size.Y
end

function CameraController:_fit(snap: boolean)
	local tanHalf = math.tan(math.rad(BASE_FOV / 2))
	local needH = (roomHeight + 12) / (2 * tanHalf)
	local needW = (roomWidth + 14) / (2 * tanHalf * viewportAspect())
	if roomHeight > roomWidth * 1.4 then
		fitDistance = needW -- tall rooms: fit the width and pan vertically
	else
		fitDistance = math.max(needH, needW)
	end
	local visibleHalfH = fitDistance * tanHalf
	local focusY = math.min(roomHeight / 2, visibleHalfH - 4)
	local target = origin + Vector3.new(0, math.max(focusY, 8), 0)
	focus.Target = target
	distance.Target = fitDistance
	if snap then
		focus:Snap(target)
		distance:Snap(fitDistance)
	end
end

function CameraController:Start()
	camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = BASE_FOV
	local State = self.C.State

	State.LabChanged:Connect(function(lab, previous)
		local changedLab = not previous or previous.ownerId ~= lab.ownerId or previous.mapId ~= lab.mapId
		origin = lab.origin
		roomWidth, roomHeight = lab.width, lab.height
		self.planeZ = lab.origin.Z
		if changedLab then
			follow = nil
			self:_fit(previous == nil or previous.ownerId ~= lab.ownerId)
		end
	end)
	State.Changed:Connect(function(key)
		if (key == "settings" or key == "*") and State.data then
			self.shakeScale = State.data.settings.shake or 1
		end
	end)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if State.lab then
			self:_fit(false)
		end
	end)

	RunService:BindToRenderStep("FlaskCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_update(math.min(dt, 0.1))
	end)
end

function CameraController:_clamp(p: Vector3): Vector3
	local halfW, h = roomWidth / 2, roomHeight
	return Vector3.new(
		math.clamp(p.X, origin.X - halfW, origin.X + halfW),
		math.clamp(p.Y, origin.Y - 2, origin.Y + h + 2),
		origin.Z
	)
end

function CameraController:_update(dt: number)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if follow then
		if follow.Parent then
			focus.Target = self:_clamp(follow.Position)
		else
			follow = nil
		end
	end
	focus.Target = self:_clamp(focus.Target)
	local f = focus:Step(dt)
	local d = distance:Step(dt)
	local kick = fovKick:Step(dt)

	self.trauma = math.max(0, self.trauma - dt * 1.5)
	local shake = self.trauma * self.trauma * self.shakeScale
	local t = os.clock() * 24
	local offset = Vector3.new(noise(t, 1), noise(t, 2), 0) * shake * 2.2
	local roll = noise(t, 3) * shake * math.rad(2.2)

	local position = f + Vector3.new(0, d * 0.05, d) + offset
	camera.CFrame = CFrame.lookAt(position, f + offset * 0.5) * CFrame.Angles(0, 0, roll)
	camera.FieldOfView = BASE_FOV + kick * self.shakeScale
	camera.Focus = CFrame.new(f)
end

-- ─────────────────────────────── API ───────────────────────────────

function CameraController:ScreenToPlane(viewportPosition: Vector2): Vector3?
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(viewportPosition.X, viewportPosition.Y)
	if math.abs(ray.Direction.Z) < 1e-4 then
		return nil
	end
	local t = (self.planeZ - ray.Origin.Z) / ray.Direction.Z
	if t <= 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function CameraController:Ray(viewportPosition: Vector2): Ray
	return camera:ViewportPointToRay(viewportPosition.X, viewportPosition.Y)
end

-- Zoom keeping the world point under the cursor fixed.
function CameraController:ZoomAt(viewportPosition: Vector2?, factor: number)
	local old = distance.Target
	local new = math.clamp(old * factor, fitDistance * 0.32, fitDistance * 1.3)
	if viewportPosition then
		local point = self:ScreenToPlane(viewportPosition)
		if point then
			local ratio = new / old
			focus.Target = point + (focus.Target - point) * ratio
		end
	end
	distance.Target = new
	follow = nil
end

function CameraController:Pan(delta: Vector3)
	focus.Target = focus.Target + Vector3.new(delta.X, delta.Y, 0)
	follow = nil
end

-- Pan by a screen-space pixel delta (drag gestures).
function CameraController:PanPixels(pixels: Vector2)
	local d = distance.Position
	local worldPerPixel = 2 * d * math.tan(math.rad(BASE_FOV / 2)) / math.max(camera.ViewportSize.Y, 1)
	self:Pan(Vector3.new(-pixels.X * worldPerPixel, pixels.Y * worldPerPixel, 0))
end

function CameraController:Reset()
	follow = nil
	self:_fit(false)
end

function CameraController:Follow(part: BasePart?)
	follow = part
end

function CameraController:Shake(amount: number, position: Vector3?)
	local scale = 1
	if position and camera then
		local focusPoint = focus.Position
		local d = (position - focusPoint).Magnitude
		scale = math.clamp(1 - d / (fitDistance * 1.2), 0.2, 1)
	end
	self.trauma = math.min(1, self.trauma + amount * scale)
end

function CameraController:Punch(amount: number)
	fovKick:Impulse(amount * 10)
end

function CameraController:Distance(): number
	return distance.Position
end

function CameraController:FitDistance(): number
	return fitDistance
end

return CameraController
