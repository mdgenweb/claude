--!nonstrict
-- Server-side persistent effect instances (particle emitters and lights attached to golems).
-- One-shot bursts are sent to clients as FX events instead.

local Vfx = {}

local function seq(...): NumberSequence
	local points = { ... }
	local keypoints = {}
	for i = 1, #points, 2 do
		table.insert(keypoints, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keypoints)
end
Vfx.seq = seq

local TEX = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	circle = "rbxasset://textures/whiteCircle.png",
	square = "rbxasset://textures/particles/SquareParticle.png",
}
Vfx.Textures = TEX

local PRESETS = {
	fire = {
		Texture = TEX.fire,
		Rate = 28,
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(20, 20),
		Size = seq(0, 1.6, 0.5, 1.2, 1, 0),
		Transparency = seq(0, 0.15, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 60, 20)),
		Acceleration = Vector3.new(0, 12, 0),
		EmissionDirection = Enum.NormalId.Top,
		RotSpeed = NumberRange.new(-60, 60),
		Rotation = NumberRange.new(0, 360),
	},
	embers = {
		Texture = TEX.sparks,
		Rate = 14,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(40, 40),
		Size = seq(0, 0.3, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)),
		Acceleration = Vector3.new(0, 8, 0),
		EmissionDirection = Enum.NormalId.Top,
	},
	smoke = {
		Texture = TEX.smoke,
		Rate = 6,
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(2, 4),
		Size = seq(0, 1, 1, 4),
		Transparency = seq(0, 0.6, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(60, 56, 60)),
		Acceleration = Vector3.new(0, 4, 0),
		EmissionDirection = Enum.NormalId.Top,
	},
	frost = {
		Texture = TEX.sparkle,
		Rate = 10,
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 0.5, 1, 0),
		LightEmission = 0.8,
		Color = ColorSequence.new(Color3.fromRGB(200, 245, 255)),
		Acceleration = Vector3.new(0, -2, 0),
	},
	sparkle = {
		Texture = TEX.sparkle,
		Rate = 12,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 0.6, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	},
	shock = {
		Texture = TEX.sparkle,
		Rate = 40,
		Lifetime = NumberRange.new(0.1, 0.25),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 0.7, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(180, 230, 255)),
	},
	slime = {
		Texture = TEX.circle,
		Rate = 6,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0, 1),
		Size = seq(0, 0.35, 1, 0.1),
		Transparency = seq(0, 0.2, 1, 0.6),
		LightEmission = 0.3,
		Color = ColorSequence.new(Color3.fromRGB(120, 240, 90)),
		Acceleration = Vector3.new(0, -30, 0),
	},
	drip = {
		Texture = TEX.circle,
		Rate = 5,
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(0, 0.5),
		Size = seq(0, 0.22, 1, 0.12),
		Transparency = seq(0, 0.3, 1, 0.8),
		LightEmission = 0.2,
		Color = ColorSequence.new(Color3.fromRGB(140, 200, 255)),
		Acceleration = Vector3.new(0, -40, 0),
	},
	ghost = {
		Texture = TEX.glow,
		Rate = 8,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 1.6, 1, 0),
		Transparency = seq(0, 0.5, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(170, 255, 255)),
	},
	gold = {
		Texture = TEX.sparkle,
		Rate = 10,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 0.7, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 120)),
	},
	acid = {
		Texture = TEX.smoke,
		Rate = 10,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		Size = seq(0, 0.8, 1, 2.4),
		Transparency = seq(0, 0.5, 1, 1),
		LightEmission = 0.4,
		Color = ColorSequence.new(Color3.fromRGB(170, 255, 60)),
		Acceleration = Vector3.new(0, 4, 0),
		EmissionDirection = Enum.NormalId.Top,
	},
	stink = {
		Texture = TEX.smoke,
		Rate = 5,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.5, 1.5),
		Size = seq(0, 1, 1, 3),
		Transparency = seq(0, 0.55, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(130, 140, 60)),
		Acceleration = Vector3.new(0, 1.5, 0),
	},
	float = {
		Texture = TEX.sparkle,
		Rate = 10,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 0.5, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(210, 170, 255)),
		Acceleration = Vector3.new(0, -3, 0),
	},
	heal = {
		Texture = TEX.sparkle,
		Rate = 0,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(60, 60),
		Size = seq(0, 0.8, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 140, 190)),
		EmissionDirection = Enum.NormalId.Top,
	},
	thrust = {
		Texture = TEX.fire,
		Rate = 60,
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(20, 30),
		SpreadAngle = Vector2.new(8, 8),
		Size = seq(0, 1.4, 1, 0.2),
		Transparency = seq(0, 0, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 90, 20)),
		EmissionDirection = Enum.NormalId.Bottom,
	},
	thrustSmoke = {
		Texture = TEX.smoke,
		Rate = 22,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(14, 14),
		Size = seq(0, 0.8, 1, 3.2),
		Transparency = seq(0, 0.4, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(200, 196, 190)),
		EmissionDirection = Enum.NormalId.Bottom,
	},
	breath = {
		Texture = TEX.fire,
		Rate = 70,
		Lifetime = NumberRange.new(0.45, 0.6),
		Speed = NumberRange.new(36, 46),
		SpreadAngle = Vector2.new(9, 9),
		Size = seq(0, 0.8, 0.4, 2.6, 1, 4),
		Transparency = seq(0, 0.05, 0.7, 0.3, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 70, 20)),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 2,
	},
	aura = {
		Texture = TEX.glow,
		Rate = 6,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(0, 0.5),
		Size = seq(0, 4, 1, 7),
		Transparency = seq(0, 0.7, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 140)),
		LockedToPart = true,
	},
}

-- Creates an emitter from a preset; `overrides` replace preset fields.
function Vfx.emitter(parent: Instance, preset: string, overrides: { [string]: any }?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Fx_" .. preset
	for key, value in PRESETS[preset] or {} do
		(emitter :: any)[key] = value
	end
	if overrides then
		for key, value in overrides do
			(emitter :: any)[key] = value
		end
	end
	emitter.Parent = parent
	return emitter
end

function Vfx.light(parent: Instance, color: Color3, range: number, brightness: number, flicker: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Name = "FxLight"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	if flicker then
		light:AddTag("Flicker")
	end
	return light
end

-- Destroys a list of instances safely.
function Vfx.clean(list: { Instance }?)
	if not list then
		return
	end
	for _, instance in list do
		if typeof(instance) == "Instance" then
			instance:Destroy()
		end
	end
	table.clear(list)
end

return Vfx
