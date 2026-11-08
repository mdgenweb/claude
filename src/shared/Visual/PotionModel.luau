--!strict
-- Builds a small 3D potion bottle out of primitive parts. Used for thrown bottles (client),
-- feeding animations and the ViewportFrame icons in the UI.

local PotionModel = {}

type BottleInput = { color: Color3, bottle: string }

local GLASS = Color3.fromRGB(220, 240, 255)
local CORK = Color3.fromRGB(150, 104, 62)

local function newPart(model: Model, shape: Enum.PartType, size: Vector3, cf: CFrame, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	part.Parent = model
	return part
end

local function glass(model: Model, shape: Enum.PartType, size: Vector3, cf: CFrame): Part
	return newPart(model, shape, size, cf, {
		Material = Enum.Material.Glass,
		Color = GLASS,
		Transparency = 0.55,
		Reflectance = 0.15,
		Name = "Glass",
	})
end

local function liquid(model: Model, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3): Part
	return newPart(model, shape, size, cf, {
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.05,
		Name = "Liquid",
	})
end

-- Cylinders are oriented along X; this rotation stands them upright (axis along Y).
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function neckAndCork(model: Model, topY: number)
	glass(model, Enum.PartType.Cylinder, Vector3.new(0.42, 0.34, 0.34), CFrame.new(0, topY + 0.2, 0) * UPRIGHT)
	newPart(model, Enum.PartType.Cylinder, Vector3.new(0.26, 0.4, 0.4), CFrame.new(0, topY + 0.5, 0) * UPRIGHT, {
		Material = Enum.Material.Wood,
		Color = CORK,
		Name = "Cork",
	})
end

local builders: { [string]: (Model, Color3) -> () } = {
	round = function(model, color)
		glass(model, Enum.PartType.Ball, Vector3.one * 1.2, CFrame.new(0, 0, 0))
		liquid(model, Enum.PartType.Ball, Vector3.one * 0.98, CFrame.new(0, -0.04, 0), color)
		neckAndCork(model, 0.5)
	end,
	tall = function(model, color)
		glass(model, Enum.PartType.Cylinder, Vector3.new(1.45, 0.8, 0.8), CFrame.new(0, 0.05, 0) * UPRIGHT)
		liquid(model, Enum.PartType.Cylinder, Vector3.new(1.1, 0.64, 0.64), CFrame.new(0, -0.08, 0) * UPRIGHT, color)
		neckAndCork(model, 0.72)
	end,
	square = function(model, color)
		glass(model, Enum.PartType.Block, Vector3.new(0.95, 1.05, 0.95), CFrame.new(0, 0, 0))
		liquid(model, Enum.PartType.Block, Vector3.new(0.78, 0.8, 0.78), CFrame.new(0, -0.08, 0), color)
		neckAndCork(model, 0.5)
	end,
	heart = function(model, color)
		glass(model, Enum.PartType.Ball, Vector3.one * 0.78, CFrame.new(-0.22, 0.1, 0))
		glass(model, Enum.PartType.Ball, Vector3.one * 0.78, CFrame.new(0.22, 0.1, 0))
		glass(
			model,
			Enum.PartType.Block,
			Vector3.new(0.6, 0.6, 0.5),
			CFrame.new(0, -0.22, 0) * CFrame.Angles(0, 0, math.rad(45))
		)
		liquid(model, Enum.PartType.Ball, Vector3.one * 0.6, CFrame.new(-0.2, 0.08, 0), color)
		liquid(model, Enum.PartType.Ball, Vector3.one * 0.6, CFrame.new(0.2, 0.08, 0), color)
		liquid(
			model,
			Enum.PartType.Block,
			Vector3.new(0.42, 0.42, 0.36),
			CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			color
		)
		neckAndCork(model, 0.42)
	end,
	skull = function(model, color)
		glass(model, Enum.PartType.Ball, Vector3.one * 1.1, CFrame.new(0, 0.05, 0))
		glass(model, Enum.PartType.Block, Vector3.new(0.6, 0.35, 0.6), CFrame.new(0, -0.45, 0.05))
		liquid(model, Enum.PartType.Ball, Vector3.one * 0.88, CFrame.new(0, 0, 0), color)
		for _, x in { -0.2, 0.2 } do
			newPart(model, Enum.PartType.Ball, Vector3.one * 0.26, CFrame.new(x, 0.08, 0.44), {
				Material = Enum.Material.SmoothPlastic,
				Color = Color3.fromRGB(25, 15, 30),
				Name = "Socket",
			})
		end
		neckAndCork(model, 0.5)
	end,
	star = function(model, color)
		glass(model, Enum.PartType.Ball, Vector3.one * 1.05, CFrame.new(0, 0, 0))
		liquid(model, Enum.PartType.Ball, Vector3.one * 0.84, CFrame.new(0, -0.03, 0), color)
		for i = 0, 4 do
			local angle = math.rad(90 + i * 72)
			local offset = Vector3.new(math.cos(angle), math.sin(angle), 0) * 0.58
			newPart(
				model,
				Enum.PartType.Block,
				Vector3.new(0.22, 0.22, 0.22),
				CFrame.new(offset) * CFrame.Angles(0, 0, angle + math.rad(45)),
				{ Material = Enum.Material.Neon, Color = color, Name = "Spike" }
			)
		end
		neckAndCork(model, 0.46)
	end,
	flask = function(model, color)
		glass(model, Enum.PartType.Cylinder, Vector3.new(0.55, 1.25, 1.25), CFrame.new(0, -0.35, 0) * UPRIGHT)
		glass(model, Enum.PartType.Cylinder, Vector3.new(0.45, 0.85, 0.85), CFrame.new(0, 0.12, 0) * UPRIGHT)
		liquid(model, Enum.PartType.Cylinder, Vector3.new(0.42, 1.08, 1.08), CFrame.new(0, -0.38, 0) * UPRIGHT, color)
		liquid(model, Enum.PartType.Cylinder, Vector3.new(0.3, 0.7, 0.7), CFrame.new(0, 0.04, 0) * UPRIGHT, color)
		neckAndCork(model, 0.32)
	end,
}

-- Returns an anchored, non-colliding Model whose pivot is the bottle's centre.
function PotionModel.build(potion: BottleInput, scale: number?): Model
	local model = Instance.new("Model")
	model.Name = "Bottle"
	local builder = builders[potion.bottle] or builders.round
	builder(model, potion.color)

	-- Specular glint on the glass so bottles read as glossy even without bloom.
	newPart(model, Enum.PartType.Ball, Vector3.one * 0.16, CFrame.new(-0.26, 0.22, 0.5), {
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.new(1, 1, 1),
		Transparency = 0.25,
		Name = "Glint",
	})

	local primary = model:FindFirstChild("Glass") :: BasePart?
	if primary then
		model.PrimaryPart = primary
	end
	model.WorldPivot = CFrame.new()
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

-- Neutral grey bottle used for undiscovered potions in the codex.
function PotionModel.silhouette(bottle: string): Model
	local model = PotionModel.build({ color = Color3.fromRGB(40, 34, 60), bottle = bottle })
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(46, 40, 70)
			part.Transparency = 0
			part.Reflectance = 0
		end
	end
	return model
end

return PotionModel
