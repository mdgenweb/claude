--!strict
-- Aim phase: drag to aim (reference guides: "Drag your trajectory with the mouse and hit Lock
-- Aim"). Desktop: click-drag anywhere; touch: drag; keyboard A/D or arrows; gamepad thumbstick,
-- A to lock. The preview is a dotted trajectory simulated with the same physics constants as
-- the server (gravity + wall bounces) plus an arrow head. Only the angle is sent to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Physics = require(Shared.Config.Physics)
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local ArenaGeometry = require(Shared.Visual.ArenaGeometry)
local Remotes = require(Shared.Net.Remotes)

local AimController = {}

local DOTS = 16
local active = false
local locked = false
local angle = 0
local dragging = false
local station: CFrame
local kind = "Duel"
local half = 8
local originX, originY, radius = 0, 0, 1.5
local speed = Physics.CruiseSpeed
local folder: Folder
local dots: { BasePart } = {}
local arrow: { BasePart } = {}
local conns: { RBXScriptConnection } = {}
local lastSent = 0
local onLocked: (() -> ())?

local function makeDot(size: number): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Material = Enum.Material.Neon
	p.Color = Color3.new(1, 1, 1)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function ensureParts()
	if folder then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "AimPreview"
	f.Parent = Workspace
	folder = f
	for i = 1, DOTS do
		table.insert(dots, makeDot(0.38 - i * 0.012))
	end
	for side = -1, 1, 2 do
		local wedge = Instance.new("Part")
		wedge.Size = Vector3.new(0.18, 0.18, 1.1)
		wedge.Material = Enum.Material.Neon
		wedge.Color = Color3.new(1, 1, 1)
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Parent = folder
		wedge:SetAttribute("Side", side)
		table.insert(arrow, wedge)
	end
end

local function setVisible(visible: boolean)
	for _, p in dots do
		p.Transparency = if visible then 0 else 1
	end
	for _, p in arrow do
		p.Transparency = if visible then 0 else 1
	end
end

-- Simulates the opening of the flight (same rules as World._moveBall, without collisions).
local function trajectory(): { Vector2 }
	local points = {}
	local x, y = originX, originY
	local vx, vy = math.cos(angle) * speed, math.sin(angle) * speed
	local g = Physics.Gravity
	local dt = 1 / 60
	local step = 0
	local h = half
	while #points < DOTS and step < 600 do
		step += 1
		vy -= g * dt
		x += vx * dt
		y += vy * dt
		if x - radius < -h then
			x = -h + radius
			vx = math.abs(vx)
		elseif x + radius > h then
			x = h - radius
			vx = -math.abs(vx)
		end
		if y - radius < -h then
			y = -h + radius
			vy = math.abs(vy)
		elseif y + radius > h then
			y = h - radius
			vy = -math.abs(vy)
		end
		if step % 4 == 0 then
			table.insert(points, Vector2.new(x, y))
		end
	end
	return points
end

local function render()
	local points = trajectory()
	local color = if locked then Color3.fromHex("#7CFF6B") else Color3.new(1, 1, 1)
	for i, p in dots do
		local pt = points[i]
		if pt then
			p.CFrame = CFrame.new(ArenaGeometry.SimToWorld(station, kind, pt.X, pt.Y, 0.4))
			p.Color = color
			p.Transparency = 0.05 + i * 0.035
		end
	end
	-- arrow head just in front of the orb
	local dir = Vector2.new(math.cos(angle), math.sin(angle))
	local tip = Vector2.new(originX, originY) + dir * (radius + 1.6)
	local tipWorld = ArenaGeometry.SimToWorld(station, kind, tip.X, tip.Y, 0.5)
	local planeNormal = station.LookVector * -1
	for _, wedge in arrow do
		local side = wedge:GetAttribute("Side") :: number
		local back = Vector2.new(math.cos(angle + side * 2.5), math.sin(angle + side * 2.5))
		local tail = tip + back * 1.0
		local tailWorld = ArenaGeometry.SimToWorld(station, kind, tail.X, tail.Y, 0.5)
		local mid = (tipWorld + tailWorld) / 2
		wedge.CFrame = CFrame.lookAt(mid, tipWorld, planeNormal)
		wedge.Color = color
	end
end

local function sendLive()
	local now = os.clock()
	if now - lastSent > 0.12 then
		lastSent = now
		Remotes.Unreliable("AimUpdate"):FireServer(angle)
	end
end

local function aimAtScreen(pos: Vector2)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local orbWorld = ArenaGeometry.SimToWorld(station, kind, originX, originY, 0)
	local screen = camera:WorldToViewportPoint(orbWorld)
	-- the viewport point of the cursor; screen y grows downward, arena y grows upward
	local dx = pos.X - screen.X
	local dy = -(pos.Y - screen.Y)
	if dx * dx + dy * dy < 16 then
		return
	end
	-- convert screen direction into arena space (camera right ~ station +X)
	local right = camera.CFrame.RightVector
	local up = camera.CFrame.UpVector
	local world = right * dx + up * dy
	local lx = world:Dot(station.RightVector)
	local ly = world:Dot(station.UpVector)
	angle = math.atan2(ly, lx)
	sendLive()
end

function AimController.Lock()
	if not active or locked then
		return
	end
	locked = true
	Remotes.Event("AimLock"):FireServer(angle)
	render()
	if onLocked then
		onLocked()
	end
end

function AimController.Enable(args: {
	Station: CFrame,
	Kind: string,
	X: number,
	Y: number,
	Radius: number,
	DefaultAngle: number,
	Half: number,
	DefId: string?,
	OnLocked: (() -> ())?,
})
	ensureParts()
	AimController.Disable()
	active = true
	locked = false
	station = args.Station
	kind = args.Kind
	half = args.Half
	originX, originY, radius = args.X, args.Y, args.Radius
	angle = args.DefaultAngle
	onLocked = args.OnLocked
	local def = if args.DefId then BallDefinitions.Get(args.DefId) else nil
	speed = Physics.CruiseSpeed * (if def then def.Speed else 1)
	setVisible(true)

	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if not active or locked then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			AimController.Lock()
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			aimAtScreen(Vector2.new(input.Position.X, input.Position.Y))
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if not active or locked then
			return
		end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			aimAtScreen(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local v: Vector3 = input.Position
			if v.Magnitude > 0.35 then
				angle = math.atan2(v.Y, v.X)
				sendLive()
			end
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		if not locked then
			local turn = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
				turn += 1
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
				turn -= 1
			end
			if turn ~= 0 then
				angle += turn * dt * 2.2
				sendLive()
			end
		end
		render()
	end))
	render()
end

function AimController.Disable()
	active = false
	dragging = false
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	if folder then
		setVisible(false)
	end
end

function AimController.IsActive(): boolean
	return active
end

return AimController
