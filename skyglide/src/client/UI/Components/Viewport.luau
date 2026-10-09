--!strict
-- ViewportFrame previews of part-built models (gacha machine, crates, flyers). Optional slow
-- spin driven by one shared RenderStepped loop that only touches visible viewports.
local RunService = game:GetService("RunService")

local UI = script.Parent.Parent
local Create = require(UI.Create)

local Viewport = {}

type Entry = { vp: ViewportFrame, model: Model, base: CFrame, speed: number, angle: number }
local spinning: { Entry } = {}
local running = false

local function ensureLoop()
	if running then
		return
	end
	running = true
	RunService.RenderStepped:Connect(function(dt: number)
		for i = #spinning, 1, -1 do
			local e = spinning[i]
			if e.vp.Parent == nil then
				table.remove(spinning, i)
			elseif e.vp.Visible and e.vp:FindFirstAncestorWhichIsA("LayerCollector") then
				e.angle += dt * e.speed
				e.model:PivotTo(e.base * CFrame.Angles(0, e.angle, 0))
			end
		end
	end)
end

export type Options = {
	Spin: number?, -- radians/second
	Yaw: number?, -- initial yaw (radians)
	Pitch: number?, -- camera pitch (radians)
	Fov: number?,
	Zoom: number?, -- >1 = further away
	ZIndex: number?,
	Name: string?,
	Ambient: Color3?,
}

function Viewport.Model(parent: Instance, model: Model, opts: Options?): ViewportFrame
	local o: Options = opts or {}
	local vp: ViewportFrame = Create("ViewportFrame", {
		Name = o.Name or "Viewport",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = o.Ambient or Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = o.ZIndex or 1,
		Parent = parent,
	})
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cframe, size = model:GetBoundingBox()
	local base = CFrame.new(-cframe.Position) * model:GetPivot()
	model:PivotTo(base * CFrame.Angles(0, o.Yaw or 0, 0))
	model.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = o.Fov or 30
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (o.Zoom or 1.05)
	local pitch = o.Pitch or math.rad(-12)
	local dir = (CFrame.Angles(0, 0, 0) * CFrame.Angles(pitch, 0, 0)).LookVector
	camera.CFrame = CFrame.lookAt(-dir * dist, Vector3.zero)
	camera.Parent = vp
	vp.CurrentCamera = camera
	if o.Spin and o.Spin ~= 0 then
		table.insert(spinning, { vp = vp, model = model, base = base, speed = o.Spin, angle = o.Yaw or 0 })
		ensureLoop()
	end
	return vp
end

return Viewport
