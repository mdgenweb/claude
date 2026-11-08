--!nonstrict
-- Grab & fling. Hover highlights grabbable objects; pressing on one asks the server for network
-- ownership, then a local AlignPosition drags the exact point you grabbed (so ragdolls dangle
-- naturally). Releasing keeps the object's momentum, boosted slightly, for a satisfying fling.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local GrabController = {
	grabbing = false,
	hoverModel = nil :: Model?,
	hoverPart = nil :: BasePart?,
	Grabbed = Signal.new(),
	Released = Signal.new(), -- (speed)
	InteractivePressed = Signal.new(), -- (kind)
}

local P = Config.Physics
local current = nil
local pending = nil
local highlight: Highlight
local fxFolder: Folder
local pointerPart: Part
local pointerAttachment: Attachment
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

function GrabController:Init(controllers)
	self.C = controllers
end

local function objectModel(part: Instance, dynamic: Instance): Model?
	local current = part
	while current and current.Parent ~= dynamic do
		current = current.Parent
		if current == nil or current == workspace then
			return nil
		end
	end
	if current and current:IsA("Model") then
		return current
	end
	return nil
end

-- Raycast under the pointer. Returns (hit part, owning model under Dynamic, interactive kind).
function GrabController:Pick(position: Vector2)
	local labModel = self.C.State:LabModel()
	if not labModel then
		return nil
	end
	local dynamic = labModel:FindFirstChild("Dynamic")
	local room = labModel:FindFirstChild("Room")
	if not dynamic or not room then
		return nil
	end
	rayParams.FilterDescendantsInstances = { dynamic, room }
	local ray = self.C.CameraController:Ray(position)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 800, rayParams)
	if not result then
		return nil
	end
	local part = result.Instance
	local interactive = part:GetAttribute("Interactive")
	if interactive then
		return nil, nil, interactive, result
	end
	if part:IsDescendantOf(dynamic) then
		local model = objectModel(part, dynamic)
		if model and model:FindFirstChild("TrampolineFrame") then
			return nil
		end
		return part, model, nil, result
	end
	return nil, nil, nil, result
end

local function modelMass(model: Model): number
	local mass = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide and not part.Massless then
			mass += part:GetMass()
		end
	end
	return math.max(mass, 1)
end

function GrabController:_begin(part: BasePart, model: Model, worldPoint: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "GrabPoint"
	attachment.WorldPosition = worldPoint
	attachment.Parent = part
	local align = Instance.new("AlignPosition")
	align.Name = "GrabAlign"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.ApplyAtCenterOfMass = false
	align.MaxForce = modelMass(model) * P.GrabMaxForcePerMass * (Workspace.Gravity / 196.2)
	align.MaxVelocity = P.GrabMaxVelocity
	align.Responsiveness = P.GrabResponsiveness
	align.Position = worldPoint
	align.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = pointerAttachment
	beam.Attachment1 = attachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 224, 120), Color3.fromRGB(255, 150, 60))
	beam.Width0 = 0.4
	beam.Width1 = 0.18
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Transparency = NumberSequence.new(0.15, 0.35)
	beam.Parent = pointerPart
	current = {
		part = part,
		model = model,
		attachment = attachment,
		align = align,
		beam = beam,
		samples = {},
		started = os.clock(),
	}
	self.grabbing = true
	highlight.Adornee = model
	highlight.OutlineColor = Color3.fromRGB(255, 220, 120)
	highlight.FillTransparency = 0.8
	self.Grabbed:Fire(model)
	self.C.SoundController:Play("whoosh", worldPoint, { pitch = 1.5, volume = 0.5 })
end

function GrabController:TryGrab(position: Vector2): boolean
	self.lastPressConsumed = false
	if self.grabbing or pending then
		return false
	end
	local part, model, interactive, result = self:Pick(position)
	if interactive then
		self.lastPressConsumed = true
		self.InteractivePressed:Fire(interactive)
		return true
	end
	if not part or not model or not result then
		return false
	end
	self.lastPressConsumed = true
	local plane = self.C.CameraController:ScreenToPlane(position) or result.Position
	local worldPoint = Vector3.new(result.Position.X, result.Position.Y, part.Position.Z)
	local localOffset = part.CFrame:PointToObjectSpace(worldPoint)
	local token = {}
	pending = token
	local _ = plane
	task.spawn(function()
		local ok, granted = pcall(function()
			return Net.func("Grab"):InvokeServer(part, localOffset)
		end)
		if pending ~= token then
			return
		end
		pending = nil
		if ok and granted and part.Parent and self.C.InputController.primaryDown then
			self:_begin(part, model, part.CFrame:PointToWorldSpace(localOffset))
		elseif ok and granted then
			-- Released before the server answered: give it straight back.
			Net.event("GrabRelease"):FireServer()
		end
	end)
	return true
end

function GrabController:Release(cancelled: boolean?)
	pending = nil
	if not current then
		return
	end
	local grab = current
	current = nil
	self.grabbing = false
	local speed = 0
	if not cancelled and grab.part.Parent then
		-- Momentum from the drag, boosted for a satisfying fling.
		local samples = grab.samples
		local velocity = Vector3.zero
		if #samples >= 2 then
			local first, last = samples[1], samples[#samples]
			local dt = last.t - first.t
			if dt > 0.01 then
				velocity = (last.p - first.p) / dt
			end
		end
		speed = velocity.Magnitude
		local boost = P.FlingBoost
		for _, part in grab.model:GetDescendants() do
			if part:IsA("BasePart") and not part.Anchored and part.CanCollide then
				local v = part.AssemblyLinearVelocity
				local boosted = v * boost
				if boosted.Magnitude > P.MaxSpeed * 0.75 then
					boosted = boosted.Unit * P.MaxSpeed * 0.75
				end
				part.AssemblyLinearVelocity = Vector3.new(boosted.X, boosted.Y, 0)
			end
		end
		if speed > 70 then
			self.C.SoundController:Play(
				"whoosh",
				grab.part.Position,
				{ pitch = math.clamp(0.7 + speed / 400, 0.7, 1.4), volume = 1 }
			)
			self.C.CameraController:Punch(math.clamp(speed / 300, 0.1, 0.6))
		end
	end
	grab.align:Destroy()
	grab.attachment:Destroy()
	grab.beam:Destroy()
	if not cancelled then
		Net.event("GrabRelease"):FireServer()
	end
	self.Released:Fire(speed)
end

-- Server reclaimed the object (e.g. an explosion hit it).
function GrabController:ForceDrop()
	if current then
		self:Release(true)
	end
end

function GrabController:Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "GrabFX"
	fxFolder.Parent = Workspace
	highlight = Instance.new("Highlight")
	highlight.Name = "HoverHighlight"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = fxFolder
	pointerPart = Instance.new("Part")
	pointerPart.Name = "Pointer"
	pointerPart.Anchored = true
	pointerPart.CanCollide = false
	pointerPart.CanQuery = false
	pointerPart.CanTouch = false
	pointerPart.Transparency = 1
	pointerPart.Size = Vector3.one * 0.2
	pointerPart.Parent = fxFolder
	pointerAttachment = Instance.new("Attachment")
	pointerAttachment.Parent = pointerPart

	local Input = self.C.InputController
	Input.PointerDown:Connect(function(button, position)
		if button == "primary" and not self.C.State.photoMode then
			self:TryGrab(position)
		end
	end)
	Input.PointerUp:Connect(function(button)
		if button == "primary" then
			self:Release(false)
		elseif button == "cancel" then
			self:Release(true)
			Net.event("GrabRelease"):FireServer()
		end
	end)
	self.C.State.LabChanged:Connect(function(lab, previous)
		if previous and previous.ownerId ~= lab.ownerId then
			self:ForceDrop()
		end
	end)

	local hoverTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local Camera = self.C.CameraController
		local planePoint = Camera:ScreenToPlane(Input.pointer)
		if planePoint then
			pointerPart.CFrame = CFrame.new(planePoint)
		end
		if current then
			if not current.part.Parent then
				self:Release(true)
				Net.event("GrabRelease"):FireServer()
				return
			end
			if planePoint then
				current.align.Position = Vector3.new(planePoint.X, planePoint.Y, current.part.Position.Z)
				local samples = current.samples
				local now = os.clock()
				table.insert(samples, { t = now, p = planePoint })
				while #samples > 2 and now - samples[1].t > 0.1 do
					table.remove(samples, 1)
				end
			end
			return
		end
		hoverTimer -= dt
		if hoverTimer > 0 then
			return
		end
		hoverTimer = 1 / 30
		if Input.device == "touch" then
			highlight.Adornee = nil
			return
		end
		local part, model = self:Pick(Input.pointer)
		self.hoverPart = part
		if model ~= self.hoverModel then
			self.hoverModel = model
			highlight.Adornee = model
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.88
		end
	end)
end

return GrabController
