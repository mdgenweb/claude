--!strict
-- Reusable, pooled visual effects (client-only). Everything is cosmetic: the server never waits
-- on these. Particle textures use Roblox built-in content, so no uploaded assets are needed.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Effects = {}

local folder: Folder
local emitterPool: { BasePart } = {}
local rng = Random.new()

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function ensureFolder(): Folder
	if not folder or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "ClientVFX"
		f.Parent = Workspace
		folder = f
	end
	return folder
end

local function basicPart(shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end
Effects.Part = basicPart

local function emitter(): BasePart
	local p = table.remove(emitterPool)
	if p then
		return p
	end
	local part = basicPart()
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.Texture = SPARK_TEXTURE
	pe.LightEmission = 0.8
	pe.LightInfluence = 0
	pe.Drag = 4
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = part
	part.Parent = ensureFolder()
	return part
end

-- Burst of sparks.
function Effects.Sparks(pos: Vector3, color: Color3, count: number, speed: number?, size: number?, texture: string?)
	local part = emitter()
	part.Position = pos
	local pe = part:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
	pe.Texture = texture or SPARK_TEXTURE
	pe.Color = ColorSequence.new(color)
	local s = size or 0.6
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Speed = NumberRange.new((speed or 14) * 0.5, speed or 14)
	pe.Lifetime = NumberRange.new(0.25, 0.5)
	pe:Emit(count)
	task.delay(0.8, function()
		table.insert(emitterPool, part)
	end)
end

function Effects.Smoke(pos: Vector3, color: Color3, count: number)
	Effects.Sparks(pos, color, count, 4, 1.4, SMOKE_TEXTURE)
end

-- Neon ball that expands and fades (impact flash).
function Effects.Flash(pos: Vector3, diameter: number, color: Color3, duration: number?)
	local p = basicPart(Enum.PartType.Ball)
	p.Color = color
	p.Size = Vector3.one * diameter * 0.3
	p.Position = pos
	p.Transparency = 0.15
	p.Parent = ensureFolder()
	local d = duration or 0.25
	TweenService:Create(p, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * diameter, Transparency = 1 }):Play()
	Debris:AddItem(p, d + 0.05)
end

-- Expanding flat ring facing `normal`.
function Effects.Ring(pos: Vector3, normal: Vector3, radius: number, color: Color3, duration: number?, thickness: number?)
	local p = basicPart(Enum.PartType.Cylinder)
	p.Color = color
	p.Transparency = 0.2
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.rad(90), 0)
	p.CFrame = cf
	p.Size = Vector3.new(thickness or 0.15, radius * 0.4, radius * 0.4)
	p.Parent = ensureFolder()
	local d = duration or 0.35
	TweenService:Create(p, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(thickness or 0.15, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, d + 0.05)
end

-- Small parts flung outward that fall and fade.
function Effects.Debris(pos: Vector3, colors: { Color3 }, count: number, size: number, speed: number, life: number, planeRight: Vector3?, planeUp: Vector3?, shape: Enum.PartType?)
	local right = planeRight or Vector3.xAxis
	local up = planeUp or Vector3.yAxis
	for i = 1, count do
		local p = basicPart(shape)
		p.Material = Enum.Material.SmoothPlastic
		p.Color = colors[(i - 1) % #colors + 1]
		p.Size = Vector3.one * size * rng:NextNumber(0.6, 1.2)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		p.Parent = ensureFolder()
		local a = rng:NextNumber(0, 2 * math.pi)
		local v = speed * rng:NextNumber(0.5, 1)
		local dir = right * math.cos(a) + up * math.sin(a)
		local mid = pos + dir * v * life * 0.5 + up * v * 0.12
		local finish = pos + dir * v * life - up * 4
		TweenService:Create(p, TweenInfo.new(life * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = mid }):Play()
		task.delay(life * 0.5, function()
			TweenService:Create(p, TweenInfo.new(life * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = finish, Transparency = 1 }):Play()
		end)
		Debris:AddItem(p, life + 0.1)
	end
end

-- Jagged lightning between two points.
function Effects.Lightning(a: Vector3, b: Vector3, color: Color3, duration: number?)
	local segments = 7
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.01 then
		return
	end
	local side = dir:Cross(Vector3.zAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local prev = a
	for i = 1, segments do
		local t = i / segments
		local point = a + dir * t
		if i < segments then
			point += side * rng:NextNumber(-1, 1) * len * 0.08
		end
		local seg = basicPart()
		seg.Color = color
		seg.Size = Vector3.new(0.22, 0.22, (point - prev).Magnitude)
		seg.CFrame = CFrame.lookAt((prev + point) / 2, point)
		seg.Parent = ensureFolder()
		TweenService:Create(seg, TweenInfo.new(duration or 0.25), { Transparency = 1 }):Play()
		Debris:AddItem(seg, (duration or 0.25) + 0.05)
		prev = point
	end
	Effects.Flash(b, 2.2, color, 0.2)
end

-- Beam connecting two parts for a while (leech tether etc.).
function Effects.Tether(a: BasePart, b: BasePart, color: Color3, duration: number)
	local a0 = Instance.new("Attachment")
	a0.Parent = a
	local a1 = Instance.new("Attachment")
	a1.Parent = b
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 0.5
	beam.Width1 = 0.25
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 6
	beam.CurveSize0 = 1
	beam.Parent = a
	task.delay(duration, function()
		beam:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end

-- Floating text (damage numbers, dice rolls). Pooled BillboardGuis.
local popupPool: { BillboardGui } = {}
local popupAnchor: Part

function Effects.Popup(pos: Vector3, text: string, color: Color3, scale: number?)
	ensureFolder()
	if not popupAnchor then
		local anchor = basicPart()
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.1
		anchor.Position = Vector3.zero
		anchor.Parent = folder
		popupAnchor = anchor
	end
	local gui = table.remove(popupPool)
	if gui == nil then
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.new(3, 0, 1.4, 0)
		g.AlwaysOnTop = true
		g.LightInfluence = 0
		g.MaxDistance = 120
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = g
		gui = g
	end
	local g = gui :: BillboardGui
	local s = scale or 1
	g.Size = UDim2.new(3 * s, 0, 1.4 * s, 0)
	g.Adornee = popupAnchor
	g.StudsOffsetWorldSpace = pos
	local label = g:FindFirstChild("Text") :: TextLabel
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Transparency = 0
	g.Parent = folder
	TweenService:Create(g, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = pos + Vector3.new(0, 1.6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 }):Play()
	task.delay(0.75, function()
		g.Parent = nil
		table.insert(popupPool, g)
	end)
end

function Effects.Folder(): Folder
	return ensureFolder()
end

return Effects
