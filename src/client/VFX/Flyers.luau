--!strict
-- Round finisher: the winning orb flies out of the arena at the losing player (LIKELY per
-- research), carried by the winner's equipped Flyer cosmetic, and breaks a heart on impact.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)

local Effects = require(script.Parent.Effects)
local CosmeticModels = require(script.Parent.CosmeticModels)

local Flyers = {}

local hex = Color3.fromHex

-- `orb` is the BillboardGui-carrying anchor of the winning orb (moved along with the flyer).
function Flyers.Play(flyerId: string?, from: Vector3, to: Vector3, orbAnchor: BasePart?, onImpact: () -> ())
	local id = flyerId or "basic"
	local def = CosmeticDefinitions.Get("Flyer", id)
	local model = CosmeticModels.Flyer(id)
	model.Parent = Effects.Folder()
	local trailColor = if def then hex(def.Colors[2] or def.Colors[1]) else Color3.new(1, 1, 1)

	-- trail on the model
	local core = model.PrimaryPart
	if core then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.4, 0)
		a0.Parent = core
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.4, 0)
		a1.Parent = core
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(trailColor)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.35
		trail.LightEmission = 0.7
		trail.Parent = core
	end

	local duration = 1.05
	local apex = (from + to) / 2 + Vector3.new(0, math.max(6, (to - from).Magnitude * 0.35), 0)
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local e = t * t * (3 - 2 * t)
		-- quadratic bezier
		local p = from:Lerp(apex, e):Lerp(apex:Lerp(to, e), e)
		local ahead = from:Lerp(apex, math.min(1, e + 0.02)):Lerp(apex:Lerp(to, math.min(1, e + 0.02)), math.min(1, e + 0.02))
		local look = if (ahead - p).Magnitude > 1e-3 then CFrame.lookAt(p, ahead) else CFrame.new(p)
		model:PivotTo(look)
		if orbAnchor then
			orbAnchor.CFrame = CFrame.new(p + look.UpVector * 0.9)
		end
		if t >= 1 then
			conn:Disconnect()
			model:Destroy()
			Effects.Flash(to, 4, Color3.new(1, 1, 1), 0.3)
			Effects.Sparks(to, trailColor, 30, 18, 0.7)
			onImpact()
		end
	end)
end

return Flyers
