--[[
	LightingSetup
	Bright, saturated "cartoon afternoon" look. Clients may tint locally per world (see client WorldMood).
]]

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

local function ensure(className: string, name: string)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function LightingSetup.apply()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(120, 115, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 175)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.ExposureCompensation = 0.1

	local atmosphere = ensure("Atmosphere", "ElmoreAtmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 180, 230)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "ElmoreBloom") :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 26
	bloom.Threshold = 1.5

	local color = ensure("ColorCorrectionEffect", "ElmoreColor") :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 252, 245)

	local rays = ensure("SunRaysEffect", "ElmoreSunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.6

	ensure("Sky", "ElmoreSky")
end

return LightingSetup
