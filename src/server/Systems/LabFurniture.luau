--!nonstrict
-- Interactive lab furniture shared by every map: the brewing cauldron and the ingredient rack.

local LabFurniture = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function seq(...): NumberSequence
	local points = { ... }
	local keypoints = {}
	for i = 1, #points, 2 do
		table.insert(keypoints, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keypoints)
end

function LabFurniture.cauldron(parent: Instance, base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Cauldron"
	model:SetAttribute("Interactive", "Cauldron")
	local iron = Color3.fromRGB(34, 32, 40)

	part(model, {
		Name = "Pot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5.2, 7.6, 7.6),
		CFrame = base * CFrame.new(0, 3.6, 0) * UPRIGHT,
		Color = iron,
		Material = Enum.Material.Metal,
	})
	part(model, {
		Name = "Belly",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 8.4,
		CFrame = base * CFrame.new(0, 3.1, 0),
		Color = iron,
		Material = Enum.Material.Metal,
	})
	part(model, {
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 8.4, 8.4),
		CFrame = base * CFrame.new(0, 6.3, 0) * UPRIGHT,
		Color = Color3.fromRGB(50, 46, 56),
		Material = Enum.Material.Metal,
	})
	local liquid = part(model, {
		Name = "CauldronLiquid",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7.2, 7.2),
		CFrame = base * CFrame.new(0, 6.25, 0) * UPRIGHT,
		Color = Color3.fromRGB(120, 255, 140),
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	local glow = Instance.new("PointLight")
	glow.Name = "LiquidGlow"
	glow.Color = liquid.Color
	glow.Range = 16
	glow.Brightness = 1.6
	glow.Shadows = false
	glow.Parent = liquid
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Texture = "rbxasset://textures/whiteCircle.png"
	bubbles.Rate = 9
	bubbles.Lifetime = NumberRange.new(0.6, 1.2)
	bubbles.Speed = NumberRange.new(1, 2.5)
	bubbles.SpreadAngle = Vector2.new(10, 10)
	bubbles.Size = seq(0, 0.2, 0.7, 0.55, 1, 0.75)
	bubbles.Transparency = seq(0, 0.25, 0.85, 0.3, 1, 1)
	bubbles.LightEmission = 0.7
	bubbles.Color = ColorSequence.new(liquid.Color)
	bubbles.EmissionDirection = Enum.NormalId.Right -- cylinder X axis points up after rotation
	bubbles.Shape = Enum.ParticleEmitterShape.Disc
	bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	bubbles.Parent = liquid
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 4
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Speed = NumberRange.new(2, 4)
	steam.Size = seq(0, 1.5, 1, 5)
	steam.Transparency = seq(0, 0.75, 1, 1)
	steam.Color = ColorSequence.new(Color3.fromRGB(230, 255, 235))
	steam.EmissionDirection = Enum.NormalId.Right
	steam.Parent = liquid

	for i = 0, 2 do
		local angle = math.rad(i * 120 + 30)
		part(model, {
			Name = "Leg",
			Size = Vector3.new(0.9, 1.6, 0.9),
			CFrame = base * CFrame.new(math.cos(angle) * 3, 0.8, math.sin(angle) * 3),
			Color = iron,
			Material = Enum.Material.Metal,
		})
	end
	-- Fire underneath.
	for _, angle in { 25, -25 } do
		part(model, {
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 0.9, 0.9),
			CFrame = base * CFrame.new(0, 0.45, 1.5) * CFrame.Angles(0, math.rad(angle), 0),
			Color = Color3.fromRGB(90, 58, 40),
			Material = Enum.Material.Wood,
		})
	end
	local fire = part(model, {
		Name = "Fire",
		Size = Vector3.new(3, 0.5, 2),
		CFrame = base * CFrame.new(0, 0.8, 1.8),
		Transparency = 1,
		CastShadow = false,
	})
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Rate = 20
	flames.Lifetime = NumberRange.new(0.4, 0.8)
	flames.Speed = NumberRange.new(2, 4)
	flames.Size = seq(0, 1.6, 1, 0.2)
	flames.Transparency = seq(0, 0.25, 1, 1)
	flames.LightEmission = 1
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.Parent = fire
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 140, 60)
	fireLight.Range = 14
	fireLight.Brightness = 1.8
	fireLight.Parent = fire
	fireLight:AddTag("Flicker")

	-- Invisible click target for the client raycast.
	local target = part(model, {
		Name = "ClickTarget",
		Size = Vector3.new(9, 8, 9),
		CFrame = base * CFrame.new(0, 4, 0),
		Transparency = 1,
		CanQuery = true,
		CastShadow = false,
	})
	target:SetAttribute("Interactive", "Cauldron")
	model.PrimaryPart = target
	model.Parent = parent
	return model
end

function LabFurniture.rack(parent: Instance, base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "IngredientRack"
	model:SetAttribute("Interactive", "Rack")
	local wood = Color3.fromRGB(110, 74, 50)
	for _, y in { 4.2, 8.4 } do
		part(model, {
			Name = "Board",
			Size = Vector3.new(11, 0.5, 2.6),
			CFrame = base * CFrame.new(0, y, 0),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
		})
	end
	for _, x in { -5.3, 5.3 } do
		part(model, {
			Name = "Post",
			Size = Vector3.new(0.6, 10.5, 2.6),
			CFrame = base * CFrame.new(x, 5.25, 0),
			Color = Color3.fromRGB(80, 54, 38),
			Material = Enum.Material.Wood,
		})
	end
	-- Six jars; LabService shows one per stocked ingredient.
	for i = 1, 6 do
		local row = if i <= 3 then 0 else 1
		local col = (i - 1) % 3
		local cf = base * CFrame.new(-3.4 + col * 3.4, 5.6 + row * 4.2, 0.2)
		part(model, {
			Name = "Jar" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2, 1.9, 1.9),
			CFrame = cf * UPRIGHT,
			Color = Color3.fromRGB(220, 240, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			CastShadow = false,
		})
		local content = part(model, {
			Name = "JarContent" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 1.5, 1.5),
			CFrame = cf * CFrame.new(0, -0.3, 0) * UPRIGHT,
			Color = Color3.fromRGB(255, 160, 60),
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		content.Transparency = 1
		part(model, {
			Name = "JarLid",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2.1, 2.1),
			CFrame = cf * CFrame.new(0, 1.2, 0) * UPRIGHT,
			Color = Color3.fromRGB(150, 104, 62),
			Material = Enum.Material.Wood,
		})
	end
	-- Sign.
	local sign = part(model, {
		Name = "Sign",
		Size = Vector3.new(7, 1.8, 0.3),
		CFrame = base * CFrame.new(0, 11.2, 0.6),
		Color = Color3.fromRGB(70, 46, 32),
		Material = Enum.Material.Wood,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.2
	gui.CanvasSize = Vector2.new(350, 90)
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "FREE HERBS"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 160)
	label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	label.Parent = gui

	local target = part(model, {
		Name = "ClickTarget",
		Size = Vector3.new(12, 12, 4),
		CFrame = base * CFrame.new(0, 6, 0),
		Transparency = 1,
		CanQuery = true,
		CastShadow = false,
	})
	target:SetAttribute("Interactive", "Rack")
	model.PrimaryPart = target
	model.Parent = parent
	return model
end

return LabFurniture
