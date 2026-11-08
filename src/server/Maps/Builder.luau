--!nonstrict
-- Tiny declarative helper for building lab geometry from primitive parts.
-- All positions are LOCAL to the lab origin: x = right, y = up (floor at 0), z = towards camera
-- (z = 0 is the play plane, the back wall sits around z = -10).

local Builder = {}
Builder.__index = Builder

export type PartSpec = {
	name: string?,
	size: Vector3,
	at: Vector3,
	rot: CFrame?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	shape: Enum.PartType?,
	collide: boolean?, -- default false (decoration)
	query: boolean?, -- default = collide
	touch: boolean?, -- default false
	shadow: boolean?, -- default true
	physics: PhysicalProperties?,
	attributes: { [string]: any }?,
	tags: { string }?,
	class: string?, -- "Part" | "WedgePart" | "CornerWedgePart" | "TrussPart"
}

function Builder.new(parent: Instance, origin: CFrame)
	return setmetatable({ parent = parent, origin = origin, count = 0 }, Builder)
end

function Builder:child(name: string)
	local folder = Instance.new("Model")
	folder.Name = name
	folder.Parent = self.parent
	return setmetatable({ parent = folder, origin = self.origin, count = 0 }, Builder), folder
end

function Builder:world(localPosition: Vector3): Vector3
	return self.origin * localPosition
end

function Builder:part(spec: PartSpec): BasePart
	local part = Instance.new(spec.class or "Part") :: BasePart
	if spec.shape and part:IsA("Part") then
		part.Shape = spec.shape
	end
	part.Name = spec.name or "Part"
	part.Size = spec.size
	part.CFrame = self.origin * CFrame.new(spec.at) * (spec.rot or CFrame.identity)
	part.Anchored = true
	part.Color = spec.color or Color3.fromRGB(120, 110, 130)
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
	local collide = spec.collide == true
	part.CanCollide = collide
	part.CanQuery = if spec.query ~= nil then spec.query else collide
	part.CanTouch = spec.touch == true
	part.CastShadow = spec.shadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if collide then
		part.CollisionGroup = "Static"
	end
	if spec.physics then
		part.CustomPhysicalProperties = spec.physics
	end
	if spec.attributes then
		for key, value in spec.attributes do
			part:SetAttribute(key, value)
		end
	end
	if spec.tags then
		for _, tag in spec.tags do
			part:AddTag(tag)
		end
	end
	part.Parent = self.parent
	self.count += 1
	return part
end

-- Solid static collider (floors, walls, platforms).
function Builder:solid(spec: PartSpec): BasePart
	spec.collide = true
	return self:part(spec)
end

function Builder:light(part: BasePart, kind: string, props: { [string]: any }): Light
	local light = Instance.new(kind) :: Light
	for key, value in props do
		(light :: any)[key] = value
	end
	light.Parent = part
	return light
end

function Builder:emitter(part: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = part
	return emitter
end

local function seq(...): NumberSequence
	local points = { ... }
	local keypoints = {}
	for i = 1, #points, 2 do
		table.insert(keypoints, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keypoints)
end
Builder.seq = seq

-- Standard room shell: floor, back wall, side walls, ceiling and a diorama frame at the front.
export type ShellSpec = {
	width: number,
	height: number,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	wallColor: Color3,
	wallMaterial: Enum.Material,
	backColor: Color3?,
	backMaterial: Enum.Material?,
	ceilingColor: Color3?,
	ceilingMaterial: Enum.Material?,
	frameColor: Color3,
	frameMaterial: Enum.Material,
	noCeiling: boolean?,
	floorPhysics: PhysicalProperties?,
	wallPhysics: PhysicalProperties?,
}

function Builder:shell(spec: ShellSpec)
	local W, H = spec.width, spec.height
	local halfW = W / 2
	local shell, model = self:child("Shell")

	shell:solid({
		name = "Floor",
		size = Vector3.new(W + 12, 6, 24),
		at = Vector3.new(0, -3, 1),
		color = spec.floorColor,
		material = spec.floorMaterial,
		physics = spec.floorPhysics,
	})
	shell:solid({
		name = "BackWall",
		size = Vector3.new(W + 12, H + 12, 3),
		at = Vector3.new(0, H / 2, -12.5),
		color = spec.backColor or spec.wallColor,
		material = spec.backMaterial or spec.wallMaterial,
	})
	for _, side in { -1, 1 } do
		shell:solid({
			name = if side < 0 then "LeftWall" else "RightWall",
			size = Vector3.new(8, H + 12, 24),
			at = Vector3.new(side * (halfW + 4), H / 2, 1),
			color = spec.wallColor,
			material = spec.wallMaterial,
			physics = spec.wallPhysics,
		})
	end
	if not spec.noCeiling then
		shell:solid({
			name = "Ceiling",
			size = Vector3.new(W + 12, 6, 24),
			at = Vector3.new(0, H + 3, 1),
			color = spec.ceilingColor or spec.wallColor,
			material = spec.ceilingMaterial or spec.wallMaterial,
			physics = spec.wallPhysics,
		})
	end

	-- Diorama frame around the opening (visual only).
	local frameDepth = 2
	local z = 13 + frameDepth / 2
	local frame = {
		{ size = Vector3.new(10, H + 22, frameDepth), at = Vector3.new(-(halfW + 5), H / 2, z) },
		{ size = Vector3.new(10, H + 22, frameDepth), at = Vector3.new(halfW + 5, H / 2, z) },
		{ size = Vector3.new(W + 30, 6, frameDepth), at = Vector3.new(0, H + 5, z) },
		{ size = Vector3.new(W + 30, 6, frameDepth), at = Vector3.new(0, -5, z) },
	}
	for _, piece in frame do
		shell:part({
			name = "Frame",
			size = piece.size,
			at = piece.at,
			color = spec.frameColor,
			material = spec.frameMaterial,
		})
	end
	-- Gold trim along the inner edge of the frame.
	local trim = Color3.fromRGB(214, 170, 82)
	shell:part({
		name = "Trim",
		size = Vector3.new(0.6, H + 10, 0.6),
		at = Vector3.new(-(halfW + 0.3), H / 2, z + 1),
		color = trim,
		material = Enum.Material.Foil,
	})
	shell:part({
		name = "Trim",
		size = Vector3.new(0.6, H + 10, 0.6),
		at = Vector3.new(halfW + 0.3, H / 2, z + 1),
		color = trim,
		material = Enum.Material.Foil,
	})
	shell:part({
		name = "Trim",
		size = Vector3.new(W + 1.2, 0.6, 0.6),
		at = Vector3.new(0, H + 2.3, z + 1),
		color = trim,
		material = Enum.Material.Foil,
	})
	shell:part({
		name = "Trim",
		size = Vector3.new(W + 1.2, 0.6, 0.6),
		at = Vector3.new(0, -2.3, z + 1),
		color = trim,
		material = Enum.Material.Foil,
	})
	return model
end

-- A window in the back wall: dark frame, glass pane, moonlight beam and a soft light.
function Builder:window(x: number, y: number, w: number, h: number, frameColor: Color3, lightColor: Color3)
	local zWall = -10.9
	self:part({
		name = "WindowGlass",
		size = Vector3.new(w, h, 0.2),
		at = Vector3.new(x, y, zWall),
		color = lightColor,
		material = Enum.Material.Neon,
		transparency = 0.55,
	})
	self:part({
		name = "WindowFrame",
		size = Vector3.new(w + 1.2, 0.8, 0.8),
		at = Vector3.new(x, y + h / 2 + 0.4, zWall + 0.3),
		color = frameColor,
		material = Enum.Material.Wood,
	})
	self:part({
		name = "WindowFrame",
		size = Vector3.new(w + 1.2, 1.2, 1.4),
		at = Vector3.new(x, y - h / 2 - 0.6, zWall + 0.6),
		color = frameColor,
		material = Enum.Material.Wood,
	})
	self:part({
		name = "WindowFrame",
		size = Vector3.new(0.8, h, 0.8),
		at = Vector3.new(x - w / 2 - 0.2, y, zWall + 0.3),
		color = frameColor,
		material = Enum.Material.Wood,
	})
	self:part({
		name = "WindowFrame",
		size = Vector3.new(0.8, h, 0.8),
		at = Vector3.new(x + w / 2 + 0.2, y, zWall + 0.3),
		color = frameColor,
		material = Enum.Material.Wood,
	})
	self:part({
		name = "WindowMullion",
		size = Vector3.new(0.4, h, 0.4),
		at = Vector3.new(x, y, zWall + 0.2),
		color = frameColor,
		material = Enum.Material.Wood,
	})
	self:part({
		name = "WindowMullion",
		size = Vector3.new(w, 0.4, 0.4),
		at = Vector3.new(x, y, zWall + 0.2),
		color = frameColor,
		material = Enum.Material.Wood,
	})
	local emitterHost = self:part({
		name = "WindowLight",
		size = Vector3.new(w, h, 0.2),
		at = Vector3.new(x, y, zWall + 0.5),
		transparency = 1,
		shadow = false,
	})
	self:light(
		emitterHost,
		"SurfaceLight",
		{ Face = Enum.NormalId.Front, Color = lightColor, Brightness = 1.4, Range = 26, Angle = 70, Shadows = true }
	)
	-- Dust motes drifting in the light.
	self:emitter(emitterHost, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 3,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(60, 60),
		Size = seq(0, 0.12, 0.5, 0.18, 1, 0),
		Transparency = seq(0, 1, 0.3, 0.4, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(lightColor),
		EmissionDirection = Enum.NormalId.Front,
	})
end

-- Torch/candle with flickering light (client animates lights tagged "Flicker").
function Builder:torch(x: number, y: number, z: number, color: Color3, range: number?)
	self:part({
		name = "TorchHolder",
		size = Vector3.new(0.8, 2.2, 0.8),
		at = Vector3.new(x, y - 1, z),
		color = Color3.fromRGB(60, 46, 40),
		material = Enum.Material.Metal,
	})
	local flame = self:part({
		name = "TorchFlame",
		size = Vector3.new(0.5, 0.8, 0.5),
		at = Vector3.new(x, y + 0.5, z),
		color = color,
		material = Enum.Material.Neon,
		shadow = false,
		shape = Enum.PartType.Ball,
	})
	local light =
		self:light(flame, "PointLight", { Color = color, Brightness = 1.6, Range = range or 18, Shadows = true })
	light:AddTag("Flicker")
	self:emitter(flame, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 14,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(2, 3.5),
		SpreadAngle = Vector2.new(8, 8),
		Size = seq(0, 0.7, 0.5, 0.5, 1, 0),
		Transparency = seq(0, 0.3, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(color, Color3.fromRGB(255, 80, 30)),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 2, 0),
	})
	return flame
end

-- A shelf with assorted glowing bottles (pure decoration, lots of colour).
function Builder:bottleShelf(x: number, y: number, width: number, rng: Random)
	local wood = Color3.fromRGB(92, 60, 42)
	self:part({
		name = "Shelf",
		size = Vector3.new(width, 0.6, 3),
		at = Vector3.new(x, y, -9.2),
		color = wood,
		material = Enum.Material.WoodPlanks,
	})
	self:part({
		name = "ShelfBracket",
		size = Vector3.new(0.5, 1.6, 2.4),
		at = Vector3.new(x - width / 2 + 1, y - 1, -9.6),
		color = wood,
		material = Enum.Material.Wood,
	})
	self:part({
		name = "ShelfBracket",
		size = Vector3.new(0.5, 1.6, 2.4),
		at = Vector3.new(x + width / 2 - 1, y - 1, -9.6),
		color = wood,
		material = Enum.Material.Wood,
	})
	local palette = {
		Color3.fromRGB(255, 90, 140),
		Color3.fromRGB(90, 220, 255),
		Color3.fromRGB(150, 255, 90),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(190, 110, 255),
		Color3.fromRGB(255, 120, 40),
	}
	local cursor = x - width / 2 + 1.2
	while cursor < x + width / 2 - 1 do
		local h = rng:NextNumber(1.2, 2.6)
		local w = rng:NextNumber(0.7, 1.3)
		local color = palette[rng:NextInteger(1, #palette)]
		local shape = if rng:NextNumber() < 0.4 then Enum.PartType.Ball else Enum.PartType.Block
		if shape == Enum.PartType.Ball then
			self:part({
				name = "Bottle",
				size = Vector3.one * w * 1.2,
				at = Vector3.new(cursor, y + 0.3 + w * 0.6, -9),
				color = Color3.fromRGB(220, 240, 255),
				material = Enum.Material.Glass,
				transparency = 0.5,
				shadow = false,
				shape = shape,
			})
			self:part({
				name = "BottleLiquid",
				size = Vector3.one * w,
				at = Vector3.new(cursor, y + 0.3 + w * 0.55, -9),
				color = color,
				material = Enum.Material.Neon,
				shadow = false,
				shape = shape,
			})
		else
			self:part({
				name = "Bottle",
				size = Vector3.new(w, h, w),
				at = Vector3.new(cursor, y + 0.3 + h / 2, -9),
				color = Color3.fromRGB(220, 240, 255),
				material = Enum.Material.Glass,
				transparency = 0.5,
				shadow = false,
			})
			self:part({
				name = "BottleLiquid",
				size = Vector3.new(w * 0.8, h * 0.6, w * 0.8),
				at = Vector3.new(cursor, y + 0.3 + h * 0.32, -9),
				color = color,
				material = Enum.Material.Neon,
				shadow = false,
			})
		end
		cursor += w + rng:NextNumber(0.25, 0.7)
	end
end

-- Stack of books on a shelf.
function Builder:books(x: number, y: number, count: number, rng: Random)
	local colors = {
		Color3.fromRGB(150, 40, 50),
		Color3.fromRGB(40, 80, 140),
		Color3.fromRGB(60, 120, 70),
		Color3.fromRGB(140, 100, 40),
		Color3.fromRGB(90, 50, 120),
	}
	local cursor = x
	for _ = 1, count do
		local h = rng:NextNumber(1.6, 2.4)
		local w = rng:NextNumber(0.35, 0.6)
		self:part({
			name = "Book",
			size = Vector3.new(w, h, 1.8),
			at = Vector3.new(cursor, y + h / 2, -9.4),
			color = colors[rng:NextInteger(1, #colors)],
			material = Enum.Material.Fabric,
		})
		cursor += w + 0.05
	end
end

return Builder
