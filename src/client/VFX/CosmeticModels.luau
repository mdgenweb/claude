--!strict
-- Part-built models for Flyer cosmetics (used by the finisher VFX and UI previews).
-- Each model is centred on its pivot and faces local -Z (its LookVector = direction of flight).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PropFactory = require(Shared.Visual.PropFactory)
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)

local P = PropFactory.Part

local CosmeticModels = {}

local function noCollide(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

local builders: { [string]: (m: Model, c: { string }) -> () } = {
	Toss = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(), Color = c[1], Material = Enum.Material.Neon, Transparency = 0.4 })
	end,
	PaperPlane = function(m, c)
		P(m, { Name = "Core", Class = "WedgePart", Size = Vector3.new(0.1, 0.8, 3.2), CFrame = CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(-80)), Color = c[1] })
		P(m, { Name = "WingR", Class = "WedgePart", Size = Vector3.new(0.1, 0.8, 3.2), CFrame = CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(80)), Color = c[1] })
		P(m, { Name = "Keel", Class = "WedgePart", Size = Vector3.new(0.1, 0.6, 3.2), CFrame = CFrame.new(0, -0.35, 0), Color = c[2] })
	end,
	Kite = function(m, c)
		P(m, { Name = "Core", Size = Vector3.new(2.2, 2.2, 0.1), CFrame = CFrame.Angles(math.rad(-70), 0, math.rad(45)), Color = c[1] })
		P(m, { Name = "Cross", Size = Vector3.new(3, 0.12, 0.12), CFrame = CFrame.Angles(math.rad(-70), 0, 0), Color = c[2] })
		for i = 1, 4 do
			P(m, { Name = "Tail", Size = Vector3.new(0.5, 0.1, 0.5), CFrame = CFrame.new(0, -0.3 - i * 0.2, 1.4 + i * 0.7) * CFrame.Angles(0, math.rad(i * 25), 0), Color = c[(i % 3) + 1] })
		end
	end,
	Balloon = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.8, 2.4), CFrame = CFrame.new(0, 2.2, 0), Color = c[1], Reflectance = 0.1 })
		P(m, { Name = "Knot", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(0, 0.75, 0), Color = c[1] })
		P(m, { Name = "String", Size = Vector3.new(0.05, 1.2, 0.05), CFrame = CFrame.new(0, 0.1, 0), Color = c[2] })
	end,
	Rocket = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.1, 1.1), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = c[1], Material = Enum.Material.Metal })
		P(m, { Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(0, 0, -1.5), Color = c[2] })
		for k = 0, 2 do
			P(m, { Name = "Fin", Class = "WedgePart", Size = Vector3.new(0.12, 0.8, 0.9), CFrame = CFrame.Angles(0, 0, math.rad(k * 120)) * CFrame.new(0, 0.75, 1.1), Color = c[2] })
		end
		P(m, { Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 1.4), CFrame = CFrame.new(0, 0, 1.9), Color = c[3], Material = Enum.Material.Neon })
	end,
	Comet = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(), Color = c[2], Material = Enum.Material.Neon })
		for i = 1, 4 do
			local s = 1.3 - i * 0.22
			P(m, { Name = "Tail", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(0, 0, i * 0.7), Color = c[if i % 2 == 0 then 1 else 3], Material = Enum.Material.Neon, Transparency = 0.15 * i })
		end
	end,
	Saucer = function(m, _c)
		PropFactory.SaucerInto(m, CFrame.new(0, 0.6, 0), 0.42)
		local core = m:FindFirstChild("Hull") :: BasePart
		core.Name = "Core"
	end,
	Dragonfly = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.8, 0.5, 0.5), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = c[1] })
		P(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(0, 0, -1.5), Color = c[2] })
		for side = -1, 1, 2 do
			for k = 0, 1 do
				P(m, { Name = "Wing", Size = Vector3.new(2, 0.05, 0.6), CFrame = CFrame.new(side * 1.1, 0.2, -0.4 + k * 0.7) * CFrame.Angles(0, math.rad(side * (10 - k * 20)), 0), Color = c[3], Material = Enum.Material.Glass, Transparency = 0.4 })
			end
		end
	end,
	Cruiser = function(m, c)
		P(m, { Name = "Core", Class = "WedgePart", Size = Vector3.new(2, 0.6, 3.6), CFrame = CFrame.Angles(0, math.rad(180), 0), Color = c[1], Material = Enum.Material.Metal })
		P(m, { Name = "Cockpit", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.5, 1.2), CFrame = CFrame.new(0, 0.35, -0.2), Color = c[2], Material = Enum.Material.Glass, Transparency = 0.2 })
		for side = -1, 1, 2 do
			P(m, { Name = "Engine", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.45, 0.45), CFrame = CFrame.new(side * 1.05, -0.1, 1.2) * CFrame.Angles(0, math.rad(90), 0), Color = c[1], Material = Enum.Material.Metal })
			P(m, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(side * 1.05, -0.1, 1.95), Color = c[3], Material = Enum.Material.Neon })
		end
	end,
	CyberEye = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(), Color = c[1], Material = Enum.Material.Metal })
		P(m, { Name = "Iris", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.1, 1.1), CFrame = CFrame.new(0, 0, -0.93) * CFrame.Angles(0, math.rad(90), 0), Color = c[2], Material = Enum.Material.Neon })
		P(m, { Name = "Pupil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 0.45, 0.45), CFrame = CFrame.new(0, 0, -1.0) * CFrame.Angles(0, math.rad(90), 0), Color = c[3] })
		P(m, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.4, 2.4), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = c[3], Material = Enum.Material.Metal })
	end,
	Broom = function(m, c)
		P(m, { Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 0.22, 0.22), CFrame = CFrame.Angles(0, math.rad(90), 0), Color = c[1] })
		P(m, { Name = "Bristles", Class = "WedgePart", Size = Vector3.new(1.0, 0.9, 1.4), CFrame = CFrame.new(0, 0, 2.2), Color = c[2] })
		P(m, { Name = "Spark", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(0, 0.2, 3), Color = c[3], Material = Enum.Material.Neon })
	end,
}

function CosmeticModels.Flyer(id: string): Model
	local def = CosmeticDefinitions.Get("Flyer", id)
	local style = if def then def.Style else "Toss"
	local colors = if def then def.Colors else { "#FFFFFF", "#BFD9FF", "#FFFFFF" }
	while #colors < 3 do
		table.insert(colors, colors[#colors])
	end
	local m = PropFactory.Model("Flyer_" .. id)
	local builder = builders[style] or builders.Toss
	builder(m, colors)
	local core = m:FindFirstChild("Core") :: BasePart?
	if core then
		m.PrimaryPart = core
	end
	noCollide(m)
	return m
end

return CosmeticModels
