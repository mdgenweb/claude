-- 3D previews in the UI (upgrade panel, garage, tool picker) built with the same
-- MechBuilder the server uses, so previews always match the real mech.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MechBuilder = require(Shared.MechBuilder)

local UIKit = require(script.Parent.UIKit)

local Viewport = {}

local spinning: { [ViewportFrame]: { camera: Camera, focus: Vector3, distance: number, height: number, angle: number } } =
	{}

RunService.RenderStepped:Connect(function(dt)
	for frame, spin in spinning do
		if not frame.Parent then
			spinning[frame] = nil
		elseif frame.Visible and frame:FindFirstAncestorWhichIsA("LayerCollector") then
			spin.angle += dt * 0.6
			local offset =
				Vector3.new(math.sin(spin.angle) * spin.distance, spin.height, math.cos(spin.angle) * spin.distance)
			spin.camera.CFrame = CFrame.lookAt(spin.focus + offset, spin.focus)
		end
	end
end)

local function frameModel(frame: ViewportFrame, model: Model, spin: boolean, zoom: number?)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	model.Parent = frame
	local cf, size = model:GetBoundingBox()
	local camera = frame.CurrentCamera or Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = frame
	frame.CurrentCamera = camera
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (zoom or 1.05)
	local focus = cf.Position
	local state = { camera = camera, focus = focus, distance = distance, height = radius * 0.25, angle = math.rad(200) }
	camera.CFrame = CFrame.lookAt(
		focus + Vector3.new(math.sin(state.angle) * distance, state.height, math.cos(state.angle) * distance),
		focus
	)
	if spin then
		spinning[frame] = state
	else
		spinning[frame] = nil
	end
end

function Viewport.create(parent: Instance, props: { [string]: any }): ViewportFrame
	local frame = UIKit.new("ViewportFrame", {
		Name = props.Name or "Preview",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		ZIndex = props.ZIndex or 2,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	return frame
end

function Viewport.showMech(
	frame: ViewportFrame,
	level: number,
	toolId: string,
	finishId: string?,
	pose: number?,
	spin: boolean?
)
	local model = MechBuilder.buildStatue(level, toolId, finishId, 1, CFrame.new(0, MechBuilder.RootHeight, 0), pose)
	frameModel(frame, model, spin ~= false, 0.95)
end

function Viewport.showTool(frame: ViewportFrame, toolId: string, finishId: string?, level: number)
	local model = MechBuilder.buildToolPreview(toolId, finishId, level, CFrame.Angles(0, 0, math.rad(180)))
	frameModel(frame, model, true, 1.1)
end

return Viewport
