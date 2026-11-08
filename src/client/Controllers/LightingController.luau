--!nonstrict
-- Client-side lighting: each lab's mood preset (Lighting changes made by a LocalScript are local
-- to this player) plus post-processing and the slow-motion / pause color grades.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Maps = require(Shared.Data.Maps)

local LightingController = {}

local atmosphere: Atmosphere
local bloom: BloomEffect
local grade: ColorCorrectionEffect
local timeGrade: ColorCorrectionEffect
local sunRays: SunRaysEffect
local dof: DepthOfFieldEffect

local TRANSITION = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function ensure(className: string, name: string, parent: Instance): any
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

function LightingController:Init(controllers)
	self.C = controllers
end

function LightingController:Start()
	atmosphere = ensure("Atmosphere", "LabAtmosphere", Lighting)
	bloom = ensure("BloomEffect", "LabBloom", Lighting)
	grade = ensure("ColorCorrectionEffect", "LabGrade", Lighting)
	timeGrade = ensure("ColorCorrectionEffect", "TimeGrade", Lighting)
	sunRays = ensure("SunRaysEffect", "LabSunRays", Lighting)
	dof = ensure("DepthOfFieldEffect", "LabDepth", Lighting)
	dof.FarIntensity = 0.16
	dof.NearIntensity = 0
	dof.InFocusRadius = 42
	timeGrade.Saturation = 0
	timeGrade.Contrast = 0

	local State = self.C.State
	State.LabChanged:Connect(function(lab, previous)
		if not previous or previous.mapId ~= lab.mapId then
			self:Apply(Maps.get(lab.mapId).lighting, previous == nil)
		end
		self:_timeGrade(lab)
	end)
	State.Changed:Connect(function(key)
		if (key == "settings" or key == "*") and State.data then
			self:SetQuality(State.data.settings.quality or "high")
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and dof.Enabled then
			dof.FocusDistance = self.C.CameraController:Distance()
		end
	end)
end

function LightingController:Apply(preset, instant: boolean?)
	Lighting.ClockTime = preset.clockTime
	local function to(instance: Instance, goal: { [string]: any })
		if instant then
			for key, value in goal do
				(instance :: any)[key] = value
			end
		else
			TweenService:Create(instance, TRANSITION, goal):Play()
		end
	end
	to(Lighting, {
		Brightness = preset.brightness,
		Ambient = preset.ambient,
		OutdoorAmbient = preset.outdoorAmbient,
		ExposureCompensation = preset.exposure,
		FogColor = preset.fogColor,
	})
	to(atmosphere, {
		Density = preset.atmosphereDensity,
		Haze = preset.atmosphereHaze,
		Color = preset.atmosphereColor,
		Decay = preset.atmosphereDecay,
		Glare = 0.2,
		Offset = 0.25,
	})
	to(
		grade,
		{ TintColor = preset.tint, Saturation = preset.saturation, Contrast = preset.contrast, Brightness = 0.02 }
	)
	to(bloom, { Intensity = preset.bloomIntensity, Size = preset.bloomSize, Threshold = preset.bloomThreshold })
	to(sunRays, { Intensity = preset.sunRays, Spread = 0.6 })
end

function LightingController:_timeGrade(lab)
	local goal
	if lab.paused then
		goal = { Saturation = -0.75, Contrast = 0.12, TintColor = Color3.fromRGB(235, 235, 255), Brightness = -0.02 }
	elseif lab.slowmo then
		goal = { Saturation = -0.28, Contrast = 0.16, TintColor = Color3.fromRGB(215, 235, 255), Brightness = 0 }
	else
		goal = { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1), Brightness = 0 }
	end
	TweenService:Create(timeGrade, TweenInfo.new(0.35, Enum.EasingStyle.Quad), goal):Play()
end

-- Brief global flash used by big explosions / reveals.
function LightingController:Flash(intensity: number)
	local base = grade.Brightness
	grade.Brightness = base + intensity
	TweenService:Create(grade, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = base }):Play()
end

function LightingController:SetQuality(quality: string)
	local high = quality ~= "low"
	dof.Enabled = high
	sunRays.Enabled = high
	bloom.Enabled = true
	Lighting.GlobalShadows = high
	self.quality = quality
end

return LightingController
