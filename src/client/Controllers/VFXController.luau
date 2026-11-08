--!nonstrict
-- Client-side visual effects. The server sends compact FX events; this module turns them into
-- particles, rings, flashes, debris, lightning, floating text, camera shake and sound. It also
-- renders thrown bottles, meteors, black holes, tornadoes and stasis bubbles locally so they move
-- perfectly smoothly.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Potions = require(Shared.Data.Potions)
local Reactions = require(Shared.Data.Reactions)
local PotionModel = require(Shared.Visual.PotionModel)

local VFXController = {
	HudEvent = Signal.new(), -- (kind, payload) for chaos meter / coin pops
}

local TEX = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
	expSmoke = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	circle = "rbxasset://textures/whiteCircle.png",
	square = "rbxasset://textures/particles/SquareParticle.png",
}

local fxRoot: Folder
local C -- controllers
local projectiles = {}
local meteors = {}
local blackholes = {}
local tornadoes = {}
local stasisBubbles = {}

local function seq(...): NumberSequence
	local points = { ... }
	local keypoints = {}
	for i = 1, #points, 2 do
		table.insert(keypoints, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keypoints)
end

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function quality(): number
	local lighting = C and C.LightingController
	return if lighting and lighting.quality == "low" then 0.5 else 1
end

-- ─────────────────────────────── primitives ───────────────────────────────

local function hostPart(position: Vector3, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = "Fx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size or Vector3.one
	part.CFrame = CFrame.new(position)
	part.Parent = fxRoot
	return part
end

-- One-shot particle burst. preset fields mirror ParticleEmitter properties.
local function burst(position: Vector3, count: number, props: { [string]: any }, hostSize: Vector3?)
	local host = hostPart(position, hostSize)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Texture = TEX.sparkle
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.TimeScale = math.max(C.State:TimeScale(), 0.05)
	emitter.Parent = host
	emitter:Emit(math.max(1, math.floor(count * quality())))
	Debris:AddItem(host, (emitter.Lifetime.Max or 1) + 1.5)
	return host
end

local function sparkles(position: Vector3, color: Color3, count: number, speed: number?)
	burst(position, count, {
		Texture = TEX.sparkle,
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new((speed or 14) * 0.5, speed or 14),
		Size = seq(0, 0.9, 1, 0),
		Color = ColorSequence.new(color),
		Drag = 3,
	})
end

local function smoke(position: Vector3, color: Color3, count: number, size: number?)
	burst(position, count, {
		Texture = TEX.smoke,
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(3, 9),
		Size = seq(0, (size or 2) * 0.6, 1, (size or 2) * 2.2),
		Transparency = seq(0, 0.35, 1, 1),
		Color = ColorSequence.new(color),
		LightEmission = 0,
		Drag = 2,
		Acceleration = Vector3.new(0, 3, 0),
		RotSpeed = NumberRange.new(-40, 40),
		Rotation = NumberRange.new(0, 360),
	})
end

local function droplets(position: Vector3, color: Color3, count: number, speed: number?)
	burst(position, count, {
		Texture = TEX.circle,
		Lifetime = NumberRange.new(0.45, 0.9),
		Speed = NumberRange.new((speed or 30) * 0.4, speed or 30),
		SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Top,
		Size = seq(0, 0.55, 1, 0.1),
		Color = ColorSequence.new(color),
		LightEmission = 0.5,
		Acceleration = Vector3.new(0, -120, 0),
	})
end

local function sparks(position: Vector3, color: Color3, count: number, speed: number?)
	burst(position, count, {
		Texture = TEX.sparks,
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new((speed or 40) * 0.5, speed or 40),
		Size = seq(0, 0.45, 1, 0),
		Color = ColorSequence.new(color),
		Acceleration = Vector3.new(0, -60, 0),
		Drag = 1,
	})
end

-- Expanding ring facing the camera (or flat on the floor).
local function ring(position: Vector3, radius: number, color: Color3, duration: number, flat: boolean?)
	local part = Instance.new("Part")
	part.Name = "FxRing"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.15
	local rotation = if flat then CFrame.Angles(0, 0, math.rad(90)) else CFrame.Angles(0, math.rad(90), 0)
	part.Size = Vector3.new(0.2, 1, 1)
	part.CFrame = CFrame.new(position) * rotation
	part.Parent = fxRoot
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, duration + 0.1)
	return part
end

local function flash(position: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local host = hostPart(position)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = host
	TweenService:Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(host, duration + 0.1)
end

local function orb(
	position: Vector3,
	fromSize: number,
	toSize: number,
	color: Color3,
	duration: number,
	material: Enum.Material?
)
	local part = Instance.new("Part")
	part.Name = "FxOrb"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.one * fromSize
	part.CFrame = CFrame.new(position)
	part.Parent = fxRoot
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.one * toSize,
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, duration + 0.1)
	return part
end

-- Client-simulated debris chunks (glass shards, clay bits, wood splinters, coins).
local function debris(position: Vector3, color: Color3, count: number, speed: number, opts)
	opts = opts or {}
	count = math.floor(count * quality())
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name = "FxDebris"
		local s = rand(opts.minSize or 0.25, opts.maxSize or 0.6)
		part.Size = if opts.shape == "coin"
			then Vector3.new(0.12, 0.7, 0.7)
			else Vector3.new(s, s * rand(0.5, 1.2), s * rand(0.3, 1))
		if opts.shape == "coin" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Color = color
		part.Material = opts.material or Enum.Material.SmoothPlastic
		part.Transparency = opts.transparency or 0
		part.Reflectance = opts.reflectance or 0
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CollisionGroup = "Debris"
		part.CFrame = CFrame.new(position + Vector3.new(rand(-0.5, 0.5), rand(-0.5, 0.5), rand(0, 1)))
			* CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		part.AssemblyLinearVelocity = Vector3.new(rand(-1, 1), rand(0.2, 1.3), rand(0, 0.35)).Unit
			* speed
			* rand(0.5, 1)
		part.AssemblyAngularVelocity = Vector3.new(rand(-12, 12), rand(-12, 12), rand(-12, 12))
		part.Parent = fxRoot
		local life = rand(1.2, 2)
		task.delay(life - 0.4, function()
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(part, life)
	end
end

local function floatText(
	position: Vector3,
	text: string,
	color: Color3,
	size: number?,
	rise: number?,
	duration: number?,
	font: Font?
)
	local host = hostPart(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 80)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffsetWorldSpace = Vector3.zero
	gui.MaxDistance = 1000
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size or 30
	label.FontFace = font or Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 10, 30)
	stroke.Thickness = 2.5
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	local d = duration or 0.9
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(
		gui,
		TweenInfo.new(d, Enum.EasingStyle.Quad),
		{ StudsOffsetWorldSpace = Vector3.new(rand(-0.6, 0.6), rise or 4, 0) }
	):Play()
	task.delay(d * 0.6, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(d * 0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(d * 0.4), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(host, d + 0.1)
end

-- Jagged lightning bolt from a to b (neon segments, flickers then fades).
local function bolt(a: Vector3, b: Vector3, color: Color3, width: number?)
	local model = Instance.new("Model")
	model.Name = "FxBolt"
	local segments = math.clamp(math.floor((b - a).Magnitude / 3.5), 4, 14)
	local points = { a }
	local dir = b - a
	local perp = Vector3.new(-dir.Y, dir.X, 0)
	perp = if perp.Magnitude > 0.01 then perp.Unit else Vector3.xAxis
	for i = 1, segments - 1 do
		local t = i / segments
		local jitter = (dir.Magnitude / segments) * 0.6
		table.insert(points, a + dir * t + perp * rand(-jitter, jitter) + Vector3.new(0, 0, rand(0.5, 1.2)))
	end
	table.insert(points, b)
	local parts = {}
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local len = (p1 - p0).Magnitude
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(width or 0.32, width or 0.32, len)
		part.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		part.Parent = model
		table.insert(parts, part)
	end
	model.Parent = fxRoot
	flash(b, color, 26, 6, 0.35)
	task.spawn(function()
		for flicker = 1, 3 do
			for _, part in parts do
				part.Transparency = if flicker % 2 == 0 then 0.7 else 0
			end
			task.wait(0.05)
		end
		for _, part in parts do
			TweenService
				:Create(part, TweenInfo.new(0.18), { Transparency = 1, Size = Vector3.new(0.05, 0.05, part.Size.Z) })
				:Play()
		end
	end)
	Debris:AddItem(model, 0.5)
end

local function shake(amount: number, position: Vector3?)
	C.CameraController:Shake(amount, position)
end

local function play(cue: string, position: Vector3?, opts)
	C.SoundController:Play(cue, position, opts)
end

local function potionColor(id: string?): Color3
	local potion = id and Potions.ById[id]
	return if potion then potion.color else Color3.fromRGB(200, 200, 255)
end

local function findGolem(id: number): Model?
	local labModel = C.State:LabModel()
	local dynamic = labModel and labModel:FindFirstChild("Dynamic")
	if not dynamic then
		return nil
	end
	for _, child in dynamic:GetChildren() do
		if child:GetAttribute("GolemId") == id then
			return child :: Model
		end
	end
	return nil
end

-- ─────────────────────────────── composite effects ───────────────────────────────

local function explosion(p: Vector3, radius: number, color: Color3, big: boolean?)
	local scale = math.clamp(radius / 16, 0.5, 3)
	orb(p, 2, radius * 0.9, Color3.fromRGB(255, 240, 200), 0.18)
	orb(p, 3, radius * 0.75, color, 0.42)
	ring(p, radius * 1.15, color, 0.45)
	if big then
		ring(p, radius * 1.6, Color3.fromRGB(255, 255, 255), 0.7)
		C.UIController:ScreenFlash(Color3.fromRGB(255, 250, 230), 0.25, 0.6)
		C.LightingController:Flash(0.35)
	end
	burst(p, 18, {
		Texture = TEX.core,
		Lifetime = NumberRange.new(0.3, 0.55),
		Speed = NumberRange.new(4, 14 * scale),
		Size = seq(0, 3 * scale, 1, 6 * scale),
		Transparency = seq(0, 0, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), color),
		Drag = 4,
	})
	smoke(p, Color3.fromRGB(70, 60, 64), 14, 2.4 * scale)
	sparks(p, Color3.fromRGB(255, 200, 90), 30, 55 * scale)
	debris(p, Color3.fromRGB(60, 50, 50), 8, 45 * scale, { material = Enum.Material.Slate })
	flash(p, color, radius * 3, 9, 0.5)
	shake(math.clamp(0.25 + scale * 0.22, 0.25, 1), p)
	C.CameraController:Punch(scale * 0.9)
	play(if big or radius > 25 then "bigExplosion" else "explosion", p)
end

local function splash(p: Vector3, color: Color3, normal: Vector3?)
	local _ = normal
	droplets(p, color, 26, 34)
	sparkles(p, color:Lerp(Color3.new(1, 1, 1), 0.4), 10, 16)
	ring(p, 6, color, 0.35)
	debris(
		p,
		Color3.fromRGB(220, 240, 255),
		7,
		30,
		{ material = Enum.Material.Glass, transparency = 0.35, reflectance = 0.2, minSize = 0.15, maxSize = 0.4 }
	)
	flash(p, color, 18, 4, 0.35)
	burst(p, 6, {
		Texture = TEX.glow,
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(0, 1),
		Size = seq(0, 3, 1, 8),
		Transparency = seq(0, 0.3, 1, 1),
		Color = ColorSequence.new(color),
	})
	shake(0.12, p)
	play("glass", p)
end

local function clayChunks(p: Vector3, color: Color3, strength: number)
	debris(
		p,
		color,
		math.floor(2 + strength * 4),
		18 + strength * 30,
		{ material = Enum.Material.Concrete, minSize = 0.2, maxSize = 0.5 }
	)
end

-- ─────────────────────────────── handlers ───────────────────────────────

local H = {}

H.throw = function(d)
	local potion = Potions.ById[d.pid]
	if not potion then
		return
	end
	local model = PotionModel.build(potion, 1.15)
	model.Parent = fxRoot
	local glass = model.PrimaryPart
	if glass then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.5, 0)
		a0.Parent = glass
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.5, 0)
		a1.Parent = glass
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.25
		trail.Color = ColorSequence.new(potion.color)
		trail.LightEmission = 0.8
		trail.Transparency = seq(0, 0.2, 1, 1)
		trail.FaceCamera = true
		trail.Parent = glass
		local light = Instance.new("PointLight")
		light.Color = potion.color
		light.Range = 9
		light.Brightness = 1.5
		light.Parent = glass
	end
	projectiles[d.id] =
		{ model = model, o = d.o, v = d.v, g = d.g, t = 0, spin = rand(-14, -8) * (if d.v.X < 0 then -1 else 1) }
	play("throw", d.o)
end

H.shatter = function(d)
	local projectile = projectiles[d.id]
	if projectile then
		projectile.model:Destroy()
		projectiles[d.id] = nil
	end
	splash(d.p, potionColor(d.pid), d.n)
end

H.feed = function(d)
	local potion = Potions.ById[d.pid]
	local golem = findGolem(d.golem)
	local head = golem and golem:FindFirstChild("Head") :: BasePart?
	if not potion or not head then
		return
	end
	local model = PotionModel.build(potion, 1.3)
	model.Parent = fxRoot
	local start = head.Position + Vector3.new(0, 5, 2)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / 0.55
		if t >= 1 or not head.Parent then
			conn:Disconnect()
			model:Destroy()
			droplets(head.Position + Vector3.new(0, 0.6, 1), potion.color, 10, 10)
			sparkles(head.Position, potion.color, 12, 10)
			play("bubble", head.Position, { pitch = 1.4 })
			return
		end
		local target = head.Position + Vector3.new(0.4, 2.2, 1.4)
		local pos = start:Lerp(target, 1 - (1 - t) ^ 3)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(150 * t)))
	end)
end

H.explode = function(d)
	explosion(d.p, d.r or 16, d.c or Color3.fromRGB(255, 150, 60), d.big)
end

H.lightning = function(d)
	bolt(d.a, d.b, d.c or Color3.fromRGB(170, 220, 255), 0.36)
	bolt(d.a, d.b, Color3.fromRGB(255, 255, 255), 0.14)
	sparkles(d.b, d.c or Color3.fromRGB(170, 220, 255), 16, 22)
	shake(0.18, d.b)
	play("zap", d.b)
	play("thunder", d.b)
end

H.impact = function(d)
	local s = d.s or 0.5
	burst(d.p, math.floor(3 + s * 6), {
		Texture = TEX.smoke,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(2, 6 + s * 8),
		Size = seq(0, 0.8 + s, 1, 2 + s * 2),
		Transparency = seq(0, 0.45, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(200, 180, 170)),
		LightEmission = 0,
		Drag = 3,
	})
	if s > 0.55 then
		clayChunks(d.p, d.c or Color3.fromRGB(200, 120, 80), s)
		shake(math.min(0.08 + s * 0.15, 0.4), d.p)
	end
	play("thud", d.p, { pitch = math.clamp(1.25 - s * 0.4, 0.6, 1.3), volume = math.clamp(0.4 + s, 0.4, 1.2) })
	if s > 0.8 and math.random() < 0.5 then
		play(if math.random() < 0.5 then "ouch" else "oof", d.p)
	end
end

H.dmg = function(d)
	local amount = d.a or 0
	local color = Color3.fromRGB(255, 255, 255)
	if d.k == "burn" or d.k == "lava" then
		color = Color3.fromRGB(255, 150, 60)
	elseif d.k == "shock" then
		color = Color3.fromRGB(140, 220, 255)
	elseif d.k == "blast" or d.k == "crush" then
		color = Color3.fromRGB(255, 90, 90)
	elseif d.k == "acid" or d.k == "bite" or d.k == "stink" then
		color = Color3.fromRGB(170, 255, 80)
	elseif d.k == "void" then
		color = Color3.fromRGB(200, 140, 255)
	end
	local size = math.clamp(22 + amount * 0.35, 22, 46)
	floatText(d.p + Vector3.new(rand(-1, 1), 2.5, 2), "-" .. tostring(amount), color, size, 4, 0.8)
end

H.reform = function(d)
	sparkles(d.p, d.c or Color3.fromRGB(120, 230, 255), 24, 18)
	ring(d.p, 8, d.c or Color3.fromRGB(120, 230, 255), 0.4)
	play("magic", d.p)
end
H.spawn = function(d)
	sparkles(d.p, d.c or Color3.fromRGB(255, 230, 160), 20, 16)
	ring(d.p - Vector3.new(0, 4, 0), 6, d.c or Color3.fromRGB(255, 230, 160), 0.35, true)
	smoke(d.p - Vector3.new(0, 3.5, 0), Color3.fromRGB(230, 220, 240), 6, 1.5)
	play("spawn", d.p)
end
H.poof = function(d)
	smoke(d.p, Color3.fromRGB(230, 225, 240), 12, 2)
	sparkles(d.p, Color3.fromRGB(255, 255, 255), 10, 12)
	play("pop", d.p)
end
H.heal = function(d)
	sparkles(d.p, Color3.fromRGB(255, 130, 180), 30, 14)
	floatText(d.p + Vector3.new(0, 3, 2), "💖", Color3.fromRGB(255, 140, 190), 36, 5, 1)
	ring(d.p, 7, Color3.fromRGB(255, 140, 190), 0.4)
	play("heal", d.p)
end
H.healall = function()
	play("heal", nil)
end
H.clone = function(d)
	droplets(d.p, d.c or Color3.fromRGB(150, 240, 120), 24, 24)
	sparkles(d.p, Color3.fromRGB(255, 200, 240), 16, 14)
	play("boing", d.p, { pitch = 1.3 })
end
H.grow = function(d)
	ring(d.p, 14, Color3.fromRGB(160, 220, 80), 0.5)
	sparkles(d.p, Color3.fromRGB(180, 255, 120), 20, 20)
	play("whoosh", d.p, { pitch = 0.6 })
end
H.shrink = function(d)
	ring(d.p, 6, Color3.fromRGB(120, 255, 200), 0.3)
	sparkles(d.p, Color3.fromRGB(120, 255, 220), 14, 10)
	play("squeak", d.p)
end
H.gild = function(d)
	sparkles(d.p, Color3.fromRGB(255, 220, 100), 30, 18)
	flash(d.p, Color3.fromRGB(255, 220, 120), 24, 5, 0.6)
	play("magic", d.p, { pitch = 0.8 })
end
H.freeze = function(d)
	burst(d.p, 26, {
		Texture = TEX.sparkle,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(6, 16),
		Size = seq(0, 1, 1, 0),
		Color = ColorSequence.new(Color3.fromRGB(200, 245, 255)),
		Drag = 3,
	})
	ring(d.p, 7, Color3.fromRGB(170, 235, 255), 0.4)
	play("freeze", d.p)
end
H.thaw = function(d)
	droplets(d.p, Color3.fromRGB(150, 210, 255), 14, 12)
	play("splash", d.p, { pitch = 1.4 })
end
H.ignite = function(d)
	burst(d.p, 16, {
		Texture = TEX.fire,
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(8, 18),
		Size = seq(0, 2, 1, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 80, 20)),
	})
	play("fire", d.p)
	play("whoosh", d.p, { pitch = 0.7 })
end
H.roar = function(d)
	burst(d.p, 24, {
		Texture = TEX.fire,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(10, 22),
		Size = seq(0, 2.5, 1, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 60, 20)),
	})
	play("thunder", d.p, { pitch = 1.3 })
	shake(0.3, d.p)
end
H.inflate = function(d)
	play("whoosh", d.p, { pitch = 1.8 })
	sparkles(d.p, Color3.fromRGB(255, 160, 220), 10, 10)
end
H.balloonpop = function(d)
	burst(d.p, 22, {
		Texture = TEX.square,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(10, 22),
		Size = seq(0, 0.45, 1, 0.35),
		Color = ColorSequence.new(d.c or Color3.fromRGB(255, 120, 180)),
		RotSpeed = NumberRange.new(-200, 200),
		Acceleration = Vector3.new(0, -30, 0),
		LightEmission = 0.3,
	})
	ring(d.p, 3, d.c or Color3.fromRGB(255, 120, 180), 0.2)
	play("pop", d.p, { pitch = 1.3 })
end
H.pop = function(d)
	clayChunks(d.p, d.c or Color3.fromRGB(200, 120, 80), 0.7)
	smoke(d.p, Color3.fromRGB(220, 200, 190), 5, 1)
	play("pop", d.p)
end
H.smokepuff = function(d)
	smoke(d.p, Color3.fromRGB(90, 86, 96), 8, 1.6)
end
H.sizzle = function(d)
	smoke(d.p, Color3.fromRGB(235, 240, 245), 10, 1.8)
	play("sizzle", d.p)
end
H.infect = function(d)
	burst(d.p, 16, {
		Texture = TEX.smoke,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 10),
		Size = seq(0, 1, 1, 2.5),
		Transparency = seq(0, 0.4, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(110, 190, 60)),
		LightEmission = 0.2,
	})
	floatText(d.p + Vector3.new(0, 3, 2), "🧟", Color3.fromRGB(150, 255, 90), 34, 4, 0.9)
	play("groan", d.p)
end
H.cure = function(d)
	sparkles(d.p, Color3.fromRGB(255, 160, 200), 26, 16)
	play("heal", d.p)
end
H.ascend = function(d)
	for i = 1, 3 do
		task.delay(i * 0.12, function()
			ring(d.p, 14 + i * 8, Color3.fromRGB(255, 230, 150), 0.7)
		end)
	end
	sparkles(d.p, Color3.fromRGB(255, 240, 180), 60, 30)
	flash(d.p, Color3.fromRGB(255, 240, 200), 60, 10, 1.2)
	C.UIController:ScreenFlash(Color3.fromRGB(255, 240, 200), 0.35, 1)
	shake(0.4, d.p)
	play("levelup", nil)
	play("discover", nil)
end
H.coins = function(d)
	debris(
		d.p,
		Color3.fromRGB(255, 205, 60),
		math.clamp(d.n or 8, 4, 22),
		40,
		{ shape = "coin", material = Enum.Material.Foil, reflectance = 0.3 }
	)
	sparkles(d.p, Color3.fromRGB(255, 220, 100), 20, 20)
	for i = 0, 3 do
		task.delay(i * 0.07, function()
			play("coin", d.p)
		end)
	end
end
H.confetti = function(d)
	burst(d.p, 70, {
		Texture = TEX.square,
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(20, 45),
		Size = seq(0, 0.6, 1, 0.5),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(90, 200, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 220, 70)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 255, 120)),
		}),
		RotSpeed = NumberRange.new(-300, 300),
		Rotation = NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, -40, 0),
		Drag = 1.5,
		LightEmission = 0.2,
	}, Vector3.new(20, 1, 1))
	play("reward", nil)
end
H.reaction = function(d)
	local reaction = Reactions.ById[d.id]
	if not reaction then
		return
	end
	floatText(
		d.p + Vector3.new(0, 6, 3),
		reaction.icon .. " " .. reaction.name:upper() .. "!",
		reaction.color,
		40,
		6,
		1.4
	)
	ring(d.p, 12, reaction.color, 0.5)
	sparkles(d.p, reaction.color, 26, 22)
	C.CameraController:Punch(0.8)
	shake(0.2, d.p)
	play("magic", d.p)
end
H.puddle = function(d)
	ring(d.p + Vector3.new(0, 0.2, 0), (d.r or 5) + 1, d.c or Color3.fromRGB(200, 200, 255), 0.35, true)
	droplets(d.p, d.c or Color3.fromRGB(200, 200, 255), 10, 14)
end
H.steam = function(d)
	local r = d.r or 14
	burst(d.p, 26, {
		Texture = TEX.smoke,
		Lifetime = NumberRange.new(0.9, 1.7),
		Speed = NumberRange.new(r, r * 2),
		Size = seq(0, 2.5, 1, 7),
		Transparency = seq(0, 0.25, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(245, 248, 252)),
		LightEmission = 0.1,
		Drag = 3,
	})
	ring(d.p, r, Color3.fromRGB(240, 245, 250), 0.45)
	shake(0.25, d.p)
	play("sizzle", d.p, { pitch = 0.7, volume = 1.4 })
	play("whoosh", d.p, { pitch = 0.6 })
end
H.stink = function(d)
	local host = hostPart(d.p, Vector3.new(d.r or 10, 4, 2))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = TEX.smoke
	emitter.Rate = 14 * quality()
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.Size = seq(0, 2, 1, 5)
	emitter.Transparency = seq(0, 0.5, 1, 1)
	emitter.Color = ColorSequence.new(Color3.fromRGB(140, 150, 60))
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = host
	task.delay(d.d or 7, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(host, (d.d or 7) + 3)
	play("splash", d.p, { pitch = 0.6 })
end
H.blackhole = function(d)
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.fromRGB(8, 0, 16)
	core.Size = Vector3.one * 0.5
	core.CFrame = CFrame.new(d.p)
	core.Parent = fxRoot
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromRGB(170, 80, 255)
	disc.Transparency = 0.25
	disc.Size = Vector3.new(0.2, 1, 1)
	disc.CFrame = CFrame.new(d.p - Vector3.new(0, 0, 0.6)) * CFrame.Angles(0, math.rad(90), 0)
	disc.Parent = fxRoot
	local vortex = Instance.new("ParticleEmitter")
	vortex.Texture = TEX.vortex
	vortex.Rate = 30 * quality()
	vortex.Lifetime = NumberRange.new(0.6, 1)
	vortex.Speed = NumberRange.new(14, 22)
	vortex.Shape = Enum.ParticleEmitterShape.Sphere
	vortex.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	vortex.Size = seq(0, 2, 1, 0)
	vortex.LightEmission = 1
	vortex.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(80, 20, 160))
	vortex.Parent = core
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = TEX.sparkle
	streaks.Rate = 40 * quality()
	streaks.Lifetime = NumberRange.new(0.5, 0.9)
	streaks.Speed = NumberRange.new(20, 34)
	streaks.Shape = Enum.ParticleEmitterShape.Sphere
	streaks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	streaks.Size = seq(0, 0.5, 1, 0)
	streaks.LightEmission = 1
	streaks.Color = ColorSequence.new(Color3.fromRGB(240, 200, 255))
	streaks.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 80, 255)
	light.Range = 30
	light.Brightness = 3
	light.Parent = core
	TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = Vector3.one * 5.5 }):Play()
	TweenService:Create(disc, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = Vector3.new(0.2, 15, 15) }):Play()
	blackholes[d.id] = { core = core, disc = disc, p = d.p, t = 0 }
	shake(0.3, d.p)
	play("thunder", d.p, { pitch = 0.6 })
end
H.blackholeend = function(d)
	local entry = blackholes[d.id]
	if not entry then
		return
	end
	blackholes[d.id] = nil
	TweenService:Create(
		entry.core,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Size = Vector3.one * 0.1 }
	):Play()
	TweenService:Create(
		entry.disc,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Size = Vector3.new(0.2, 0.1, 0.1) }
	):Play()
	Debris:AddItem(entry.core, 0.3)
	Debris:AddItem(entry.disc, 0.3)
end
H.stasis = function(d)
	local bubble = Instance.new("Part")
	bubble.Shape = Enum.PartType.Ball
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Color3.fromRGB(110, 255, 255)
	bubble.Size = Vector3.one
	bubble.CFrame = CFrame.new(d.p)
	bubble.Parent = fxRoot
	TweenService:Create(bubble, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = Vector3.one * (d.r or 16) * 2 })
		:Play()
	table.insert(stasisBubbles, { part = bubble, p = d.p })
	ring(d.p, d.r or 16, Color3.fromRGB(150, 255, 255), 0.5)
	play("freeze", d.p, { pitch = 0.5 })
	play("magic", d.p, { pitch = 0.6 })
end
H.stasisend = function(d)
	local best, bestIndex = nil, nil
	for i, entry in stasisBubbles do
		local dist = (entry.p - d.p).Magnitude
		if not best or dist < best then
			best, bestIndex = dist, i
		end
	end
	if bestIndex then
		local entry = table.remove(stasisBubbles, bestIndex)
		TweenService:Create(entry.part, TweenInfo.new(0.3), { Size = Vector3.one * 0.5, Transparency = 1 }):Play()
		Debris:AddItem(entry.part, 0.35)
		play("whoosh", d.p, { pitch = 1.6 })
	end
end
H.meteorcall = function(d)
	C.UIController:ScreenFlash(Color3.fromRGB(255, 120, 60), 0.15, 0.6)
	play("thunder", d.p, { pitch = 0.7 })
end
H.meteor = function(d)
	local rock = Instance.new("Part")
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 3.2
	rock.Material = Enum.Material.CrackedLava
	rock.Color = Color3.fromRGB(80, 40, 30)
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.CFrame = CFrame.new(d.p)
	rock.Parent = fxRoot
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = TEX.fire
	fire.Rate = 60 * quality()
	fire.Lifetime = NumberRange.new(0.3, 0.5)
	fire.Speed = NumberRange.new(2, 5)
	fire.Size = seq(0, 3, 1, 0)
	fire.LightEmission = 1
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 60, 20))
	fire.Parent = rock
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60))
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = seq(0, 0.1, 1, 1)
	trail.Parent = rock
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 18
	light.Brightness = 3
	light.Parent = rock
	meteors[d.id] = { part = rock, p = d.p, v = d.v, t = 0 }
	play("whoosh", d.p, { pitch = 0.5 })
end
H.meteorhit = function(d)
	local meteor = meteors[d.id]
	if meteor then
		meteors[d.id] = nil
		meteor.part:Destroy()
	end
end
H.tornado = function(d)
	local model = Instance.new("Model")
	model.Name = "FxTornado"
	local rings = {}
	local h = d.h or 50
	for i = 1, 10 do
		local t = (i - 1) / 9
		local radius = 3 + t * 11
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.ForceField
		part.Color = Color3.fromRGB(220, 235, 255)
		part.Size = Vector3.new(h / 10 + 0.5, radius * 2, radius * 2)
		part.Parent = model
		table.insert(rings, { part = part, y = t * h, radius = radius, phase = i * 0.6 })
	end
	local host = Instance.new("Part")
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.new(14, h, 4)
	host.Parent = model
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = TEX.smoke
	dust.Rate = 30 * quality()
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Speed = NumberRange.new(4, 10)
	dust.Size = seq(0, 2, 1, 4)
	dust.Transparency = seq(0, 0.5, 1, 1)
	dust.Color = ColorSequence.new(Color3.fromRGB(210, 220, 235))
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.Acceleration = Vector3.new(0, 20, 0)
	dust.Parent = host
	model.Parent = fxRoot
	tornadoes[d.id] = { model = model, rings = rings, host = host, x = d.p.X, targetX = d.p.X, base = d.p, h = h }
	play("wind", d.p, { volume = 2 })
	play("whoosh", d.p, { pitch = 0.5 })
end
H.tornadomove = function(d)
	local entry = tornadoes[d.id]
	if entry then
		entry.targetX = d.x
	end
end
H.tornadoend = function(d)
	local entry = tornadoes[d.id]
	if entry then
		tornadoes[d.id] = nil
		for _, ringEntry in entry.rings do
			TweenService:Create(ringEntry.part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		Debris:AddItem(entry.model, 0.45)
	end
end
H.supernova = function(d)
	local glow = Instance.new("Part")
	glow.Shape = Enum.PartType.Ball
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(255, 252, 220)
	glow.Size = Vector3.one
	glow.CFrame = CFrame.new(d.p)
	glow.Parent = fxRoot
	TweenService
		:Create(glow, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 12 })
		:Play()
	flash(d.p, Color3.fromRGB(255, 250, 220), 80, 12, 1.4)
	Debris:AddItem(glow, 0.8)
	C.UIController:ScreenFlash(Color3.fromRGB(255, 255, 240), 0.6, 1.3)
	play("magic", d.p, { pitch = 0.5 })
end
H.chaos = function(d)
	sparkles(d.p, Color3.fromRGB(255, 80, 200), 20, 24)
	sparkles(d.p, Color3.fromRGB(80, 220, 255), 20, 24)
	floatText(d.p + Vector3.new(0, 4, 2), "???", Color3.fromRGB(255, 120, 220), 44, 5, 1.1)
	play("magic", d.p, { pitch = 0.7 })
end
H.fuse = function(d)
	play("sizzle", d.p)
	sparks(d.p, Color3.fromRGB(255, 220, 120), 8, 12)
end
H.crush = function(d)
	smoke(d.p, Color3.fromRGB(180, 170, 160), 10, 1.8)
	floatText(d.p + Vector3.new(0, 3, 2), "SQUASH!", Color3.fromRGB(255, 220, 90), 34, 3, 0.8)
	shake(0.35, d.p)
	play("crush", d.p)
end
H.crusherslam = function(d)
	play("whoosh", d.p, { pitch = 0.45, volume = 0.8 })
end
H.splinter = function(d)
	debris(d.p, Color3.fromRGB(170, 120, 70), 12, 34, { material = Enum.Material.Wood })
	play("crack", d.p, { pitch = 0.5 })
end
H.lavasplash = function(d)
	sparks(d.p, Color3.fromRGB(255, 160, 40), 18, 30)
	droplets(d.p, Color3.fromRGB(255, 110, 30), 10, 26)
	play("sizzle", d.p)
end
H.bumper = function(d)
	ring(d.p, 7, d.c or Color3.fromRGB(255, 90, 160), 0.25)
	flash(d.p, d.c or Color3.fromRGB(255, 90, 160), 18, 5, 0.25)
	play("boing", d.p, { pitch = 1.4 })
end
H.boing = function(d)
	play("boing", d.p)
end
H.crack = function(d)
	play("crack", d.p)
	sparkles(d.p, Color3.fromRGB(220, 245, 255), 8, 8)
end
H.cough = function(d)
	smoke(d.p, Color3.fromRGB(130, 150, 60), 4, 0.9)
end
H.splat = function(d)
	droplets(d.p, d.c or Color3.fromRGB(150, 230, 60), 8, 12)
	play("splash", d.p, { pitch = 1.8, volume = 0.6 })
end
H.immune = function(d)
	floatText(d.p, "IMMUNE", Color3.fromRGB(200, 200, 220), 26, 3, 0.8)
end
H.quake = function(d)
	ring(d.p - Vector3.new(0, 4, 0), 18, Color3.fromRGB(200, 180, 150), 0.5, true)
	smoke(d.p - Vector3.new(0, 4, 0), Color3.fromRGB(190, 170, 150), 12, 2.5)
	shake(0.55, d.p)
	play("crush", d.p)
end
H.ko = function(d)
	if d.p then
		floatText(d.p + Vector3.new(0, 4, 2), "K.O.!", Color3.fromRGB(255, 90, 90), 44, 4, 1.1)
		sparkles(d.p, Color3.fromRGB(255, 240, 120), 12, 10)
		play("oof", d.p)
	end
end
H.shatterGolem = function(d)
	local color = if d.kind == "gold"
		then Color3.fromRGB(255, 205, 60)
		elseif d.kind == "crystal" then Color3.fromRGB(170, 230, 255)
		else Color3.fromRGB(190, 240, 255)
	local small = d.small == true
	debris(d.p, color, if small then 6 else 20, if small then 25 else 45, {
		material = if d.kind == "gold" then Enum.Material.Foil else Enum.Material.Ice,
		transparency = if d.kind == "gold" then 0 else 0.2,
		reflectance = 0.25,
		minSize = 0.3,
		maxSize = if small then 0.6 else 1.1,
	})
	sparkles(d.p, color, if small then 8 else 24, 22)
	if not small then
		ring(d.p, 10, color, 0.4)
		shake(0.3, d.p)
	end
	play("crack", d.p, { pitch = 0.8 })
	play("glass", d.p, { pitch = 0.7 })
end
H.brew = function(d)
	local labModel = C.State:LabModel()
	local room = labModel and labModel:FindFirstChild("Room")
	local cauldron = room and room:FindFirstChild("Cauldron")
	local liquid = cauldron and cauldron:FindFirstChild("CauldronLiquid") :: BasePart?
	if liquid then
		liquid.Color = d.c
		local glow = liquid:FindFirstChild("LiquidGlow") :: PointLight?
		if glow then
			glow.Color = d.c
		end
		local bubbles = liquid:FindFirstChild("Bubbles") :: ParticleEmitter?
		if bubbles then
			bubbles.Color = ColorSequence.new(d.c)
			bubbles:Emit(25)
		end
	end
	local top = d.p + Vector3.new(0, 7, 0)
	sparkles(top, d.c, 30, 16)
	burst(top, 10, {
		Texture = TEX.smoke,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(6, 12),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Size = seq(0, 1.5, 1, 4),
		Transparency = seq(0, 0.4, 1, 1),
		Color = ColorSequence.new(d.c),
		LightEmission = 0.4,
	})
	ring(top, 6, d.c, 0.4, true)
	flash(top, d.c, 26, 6, 0.6)
	play("brew", top)
end
H.reset = function(d)
	C.UIController:ScreenFlash(Color3.fromRGB(200, 170, 255), 0.25, 0.5)
	sparkles(d.p, Color3.fromRGB(200, 170, 255), 40, 40)
	play("whoosh", d.p, { pitch = 0.8 })
end
H.drop = function()
	C.GrabController:ForceDrop()
end

-- ─────────────────────────────── per-frame updates ───────────────────────────────

local function update(dt: number)
	local ts = C.State:TimeScale()
	local labDt = dt * ts
	for id, p in projectiles do
		p.t += labDt
		if p.t > 5 then
			p.model:Destroy()
			projectiles[id] = nil
			continue
		end
		local pos = p.o + p.v * p.t + Vector3.new(0, -p.g, 0) * (0.5 * p.t * p.t)
		p.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, 0, p.t * p.spin))
	end
	for id, m in meteors do
		m.t += labDt
		if m.t > 4 then
			m.part:Destroy()
			meteors[id] = nil
			continue
		end
		m.part.CFrame = CFrame.new(m.p + m.v * m.t) * CFrame.Angles(m.t * 4, m.t * 3, 0)
	end
	for _, entry in blackholes do
		entry.t += labDt
		entry.disc.CFrame = CFrame.new(entry.p - Vector3.new(0, 0, 0.6))
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.Angles(entry.t * 4, 0, 0)
		entry.core.CFrame = CFrame.new(entry.p)
	end
	for _, entry in tornadoes do
		entry.x += (entry.targetX - entry.x) * math.min(1, dt * 6)
		local t = os.clock()
		for _, ringEntry in entry.rings do
			local wobble = math.sin(t * 3 + ringEntry.phase) * (1 + ringEntry.y * 0.04)
			ringEntry.part.CFrame = CFrame.new(entry.x + wobble, entry.base.Y + ringEntry.y, entry.base.Z)
				* CFrame.Angles(0, t * 6 * (1 + ringEntry.phase * 0.1), math.rad(90))
			ringEntry.part.Transparency = 0.25 + math.sin(t * 5 + ringEntry.phase) * 0.1
		end
		entry.host.CFrame = CFrame.new(entry.x, entry.base.Y + entry.h / 2, entry.base.Z)
	end
end

-- ─────────────────────────────── wiring ───────────────────────────────

function VFXController:Init(controllers)
	C = controllers
	self.C = controllers
end

function VFXController:Start()
	fxRoot = Instance.new("Folder")
	fxRoot.Name = "ClientFX"
	fxRoot.Parent = Workspace

	local function dispatch(kind: string, payload)
		if kind == "chaos" or (kind == "coins" and payload.a) then
			self.HudEvent:Fire(kind, payload)
			return
		end
		if kind == "shatter" and payload.kind then
			kind = "shatterGolem"
		end
		local handler = H[kind]
		if handler then
			local ok, err = pcall(handler, payload)
			if not ok then
				warn("[VFX]", kind, err)
			end
		end
	end
	Net.event("FX").OnClientEvent:Connect(dispatch)
	Net.unreliable("FXU").OnClientEvent:Connect(dispatch)
	RunService.RenderStepped:Connect(update)

	-- Clear lingering local effects when switching labs.
	C.State.LabChanged:Connect(function(lab, previous)
		if previous and previous.ownerId ~= lab.ownerId then
			for id, p in projectiles do
				p.model:Destroy()
				projectiles[id] = nil
			end
			for id, entry in tornadoes do
				entry.model:Destroy()
				tornadoes[id] = nil
			end
			for id, entry in blackholes do
				entry.core:Destroy()
				entry.disc:Destroy()
				blackholes[id] = nil
			end
		end
	end)
end

-- Public helpers for other controllers / UI.
VFXController.Sparkles = function(position: Vector3, color: Color3, count: number)
	sparkles(position, color, count, 14)
end
VFXController.Ring = ring
VFXController.FloatText = floatText

return VFXController
