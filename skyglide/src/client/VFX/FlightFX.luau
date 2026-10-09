--!strict
-- Flight-specific cosmetic effects (client-only): launch puffs, special-throw bursts, landing
-- splashes with droplet arcs and a water plume, speed lines in front of the camera, and "+N" /
-- "PERFECT!" popups that ride along with a moving glider (world-anchored popups would be left
-- behind at flight speed). Everything is pooled. Step(dt) animates droplets and must be called
-- once per frame (FlightRenderer does). Data.Settings.LowFx scales particle counts down.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local StateController = require(Client.Controllers.StateController)
local AudioController = require(Client.Controllers.AudioController)
local Effects = require(script.Parent.Effects)

local FlightFX = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Theme.Colors.Skill
local GRAVITY = Vector3.new(0, -70, 0)
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local UP_RING = Vector3.new(0, 1, 0.01) -- tiny tilt keeps CFrame.lookAt well defined

local rng = Random.new()
local folder: Folder? = nil

local function getFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "FlightFX"
	created.Parent = Effects.Folder()
	folder = created
	return created
end

-- True when the player picked reduced effects in Settings.
function FlightFX.Low(): boolean
	local data = StateController.Data
	local settings = data and data.Settings
	return type(settings) == "table" and settings.LowFx == true
end

-- Particle count after the LowFx reduction.
function FlightFX.Count(n: number): number
	if FlightFX.Low() then
		return math.max(1, math.floor(n * 0.35))
	end
	return n
end

--------------------------------------------------------------------------------------------------
-- Popups that follow an adornee (pooled BillboardGuis)
--------------------------------------------------------------------------------------------------

type Popup = { Gui: BillboardGui, Label: TextLabel, Stroke: UIStroke }

local popupPool: { Popup } = {}

local function newPopup(): Popup
	local gui = Instance.new("BillboardGui")
	gui.Name = "FlightPopup"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Numbers
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Theme.Colors.Stroke
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return { Gui = gui, Label = label, Stroke = stroke }
end

-- Floating text above `adornee` that rises and fades. `height` is the start offset in studs.
function FlightFX.Popup(adornee: BasePart, text: string, color: Color3, scale: number?, height: number?, duration: number?)
	local p = table.remove(popupPool) or newPopup()
	local s = scale or 1
	local h = height or 2.4
	local d = duration or 0.8
	local size = UDim2.new(7 * s, 0, 2 * s, 0)
	p.Gui.Adornee = adornee
	p.Gui.Size = UDim2.new(3 * s, 0, 0.9 * s, 0)
	p.Gui.StudsOffset = Vector3.new(0, h, 0)
	p.Label.Text = text
	p.Label.TextColor3 = color
	p.Label.TextTransparency = 0
	p.Stroke.Transparency = 0
	p.Gui.Parent = getFolder()
	TweenService:Create(p.Gui, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
	TweenService:Create(p.Gui, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, h + 2.2 * s, 0),
	}):Play()
	local fade = TweenInfo.new(d * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, d * 0.6)
	TweenService:Create(p.Label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(p.Stroke, fade, { Transparency = 1 }):Play()
	task.delay(d + 0.05, function()
		local gui: any = p.Gui -- the typings declare Adornee non-optional
		gui.Parent = nil
		gui.Adornee = nil
		table.insert(popupPool, p)
	end)
end

--------------------------------------------------------------------------------------------------
-- Droplets (pooled balls on simple ballistic arcs, moved with one BulkMoveTo per frame)
--------------------------------------------------------------------------------------------------

type Drop = { Part: BasePart, Pos: Vector3, Vel: Vector3, Age: number, Life: number }

local drops: { Drop } = {}
local dropPool: { BasePart } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local function newDropPart(): BasePart
	local p = Effects.Part(Enum.PartType.Ball)
	p.Name = "Droplet"
	p.Material = Enum.Material.Glass
	return p
end

function FlightFX.Droplets(pos: Vector3, colors: { Color3 }, n: number, speed: number)
	local parent = getFolder()
	for i = 1, FlightFX.Count(n) do
		local part = table.remove(dropPool) or newDropPart()
		part.Color = colors[(i - 1) % #colors + 1]
		part.Transparency = 0.1
		part.Size = Vector3.one * rng:NextNumber(0.4, 0.95)
		part.CFrame = CFrame.new(pos)
		part.Parent = parent
		local a = rng:NextNumber(0, 2 * math.pi)
		local horizontal = rng:NextNumber(0.15, 0.5) * speed
		local vel = Vector3.new(math.cos(a) * horizontal, rng:NextNumber(0.6, 1) * speed, math.sin(a) * horizontal)
		table.insert(drops, { Part = part, Pos = pos, Vel = vel, Age = 0, Life = rng:NextNumber(0.7, 1.1) })
	end
end

-- Advances droplets. Call once per frame.
function FlightFX.Step(dt: number)
	local n = #drops
	if n == 0 then
		return
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
	local i = 1
	while i <= n do
		local d = drops[i]
		d.Age += dt
		if d.Age >= d.Life then
			d.Part.Parent = nil
			table.insert(dropPool, d.Part)
			drops[i] = drops[n]
			drops[n] = nil
			n -= 1
		else
			d.Vel += GRAVITY * dt
			d.Pos += d.Vel * dt
			local k = d.Age / d.Life
			d.Part.Transparency = 0.1 + 0.9 * k * k
			table.insert(moveParts, d.Part)
			table.insert(moveCFrames, CFrame.new(d.Pos))
			i += 1
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--------------------------------------------------------------------------------------------------
-- Splash / launch / special bursts
--------------------------------------------------------------------------------------------------

local plumePool: { BasePart } = {}
local PLUME_ROTATION = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis (X) -> up

local function plume(pos: Vector3, color: Color3, height: number, width: number)
	local p = table.remove(plumePool)
	if not p then
		local created = Effects.Part(Enum.PartType.Cylinder)
		created.Name = "SplashPlume"
		created.Material = Enum.Material.Glass
		p = created
	end
	local part = p :: BasePart
	part.Color = color
	part.Transparency = 0.25
	part.Size = Vector3.new(1, width * 0.4, width * 0.4)
	part.CFrame = CFrame.new(pos) * PLUME_ROTATION
	part.Parent = getFolder()
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, {
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * PLUME_ROTATION,
		Transparency = 1,
	}):Play()
	task.delay(0.75, function()
		part.Parent = nil
		table.insert(plumePool, part)
	end)
end

-- Landing splash on the water surface at `pos`. `big` for the local player's own landing.
function FlightFX.Splash(pos: Vector3, water: Color3, big: boolean)
	local light = water:Lerp(WHITE, 0.55)
	local up = Vector3.new(0, 1, 0)
	Effects.Sparks(pos + up, light, FlightFX.Count(if big then 28 else 10), if big then 26 else 16, if big then 1.1 else 0.7)
	Effects.Smoke(pos + up * 1.5, WHITE, FlightFX.Count(if big then 12 else 4))
	Effects.Ring(pos + up * 0.15, UP_RING, if big then 16 else 8, light, if big then 0.7 else 0.5, 0.35)
	if big then
		Effects.Ring(pos + up * 0.2, UP_RING, 9, WHITE, 0.45, 0.25)
		Effects.Flash(pos + up, 6, WHITE, 0.25)
	end
	FlightFX.Droplets(pos, { water, light, WHITE }, if big then 22 else 8, if big then 34 else 22)
	plume(pos, light, if big then 14 else 7, if big then 6 else 3.5)
end

-- Swoosh + puff where the glider leaves the hand. Local throws get the sound in 2D.
function FlightFX.Launch(pos: Vector3, direction: Vector3, perfect: boolean, isLocal: boolean)
	Effects.Smoke(pos, WHITE, FlightFX.Count(8))
	Effects.Ring(pos, direction, 4, WHITE, 0.3, 0.2)
	if isLocal then
		AudioController.Play("Launch")
	else
		AudioController.Play("Launch", pos, 0.2, 0.6)
	end
	if perfect then
		Effects.Sparks(pos, GOLD, FlightFX.Count(26), 22, 0.9)
		Effects.Flash(pos, 7, GOLD, 0.3)
		Effects.Ring(pos, direction, 7, GOLD, 0.4, 0.3)
		if isLocal then
			AudioController.Play("PerfectLaunch")
		end
	end
end

-- Dramatic burst for JET STREAM / SKY TITAN launches.
function FlightFX.SpecialBurst(pos: Vector3, direction: Vector3, color: Color3)
	Effects.Flash(pos, 20, color, 0.6)
	Effects.Ring(pos, direction, 26, color, 0.7, 0.6)
	Effects.Ring(pos, UP_RING, 18, WHITE, 0.55, 0.4)
	Effects.Sparks(pos, color, FlightFX.Count(60), 40, 1.4)
	Effects.Sparks(pos, WHITE, FlightFX.Count(24), 28, 0.8)
	Effects.Debris(pos, { color, WHITE, GOLD }, FlightFX.Count(14), 0.7, 36, 1.0)
end

--------------------------------------------------------------------------------------------------
-- Speed lines (one emitter part kept in front of the camera; positioned after the camera moves)
--------------------------------------------------------------------------------------------------

local speedPart: BasePart? = nil
local speedEmitter: ParticleEmitter? = nil
local speedIntensity = 0
local speedBound = false

local function ensureSpeedLines(): (BasePart, ParticleEmitter)
	local part = speedPart
	local emitter = speedEmitter
	if part and emitter and part.Parent then
		return part, emitter
	end
	local p = Effects.Part()
	p.Name = "SpeedLines"
	p.Transparency = 1
	p.Size = Vector3.new(46, 28, 2)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK_TEXTURE
	e.Enabled = false
	e.Rate = 0
	e.LockedToPart = true
	e.EmissionDirection = Enum.NormalId.Back -- toward the camera
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Speed = NumberRange.new(120, 170)
	e.Lifetime = NumberRange.new(0.18, 0.3)
	e.SpreadAngle = Vector2.new(2, 2)
	e.Size = NumberSequence.new(0.3)
	e.Squash = NumberSequence.new(2.6)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(WHITE)
	e.Parent = p
	p.Parent = getFolder()
	speedPart = p
	speedEmitter = e
	return p, e
end

local function placeSpeedLines()
	local part = speedPart
	local camera = Workspace.CurrentCamera
	if speedIntensity <= 0 or not part or not camera then
		return
	end
	part.CFrame = camera.CFrame * CFrame.new(0, 0, -34)
end

-- Sets speed-line strength 0..1 (0 turns them off). LowFx disables them.
function FlightFX.SetSpeedLines(intensity: number)
	local k = if FlightFX.Low() then 0 else math.clamp(intensity, 0, 1)
	if k <= 0.01 then
		if speedIntensity > 0 and speedEmitter then
			(speedEmitter :: ParticleEmitter).Enabled = false
		end
		speedIntensity = 0
		return
	end
	local _, emitter = ensureSpeedLines()
	if not speedBound then
		speedBound = true
		RunService:BindToRenderStep("SkyGlideSpeedLines", Enum.RenderPriority.Camera.Value + 5, placeSpeedLines)
	end
	speedIntensity = k
	emitter.Rate = 110 * k
	emitter.Enabled = true
end

return FlightFX
