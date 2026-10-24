-- Smashable targets, built from parts to match the concept prop sheet:
-- Starter Yard junk, Appliance Row washers/fridges, Crusher Yard cars and ore nodes.
-- Ore types are looks only (no rarity, no separate currency). Every target gets an
-- invisible "Hitbox" PrimaryPart that carries collision; the visuals never collide.

local TargetModels = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

type Builder = { model: Model, origin: CFrame, rng: Random }

local function part(
	b: Builder,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = b.origin * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = b.model
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's X axis upright
local FLAT = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis along Z (facing front)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Starter Yard ----------------------------------------------------------------

local RUST = { hex("#9C5B35"), hex("#7A4A2E"), hex("#6E737A"), hex("#8A6A4A"), hex("#B36B3A") }

local function scrapPile(b: Builder)
	for i = 1, 7 do
		local w = b.rng:NextNumber(0.8, 1.8)
		local h = b.rng:NextNumber(0.4, 1.2)
		local d = b.rng:NextNumber(0.8, 1.8)
		local x = b.rng:NextNumber(-1, 1)
		local z = b.rng:NextNumber(-1, 1)
		local y = 0.3 + (i % 3) * 0.55
		part(
			b,
			"Scrap",
			Vector3.new(w, h, d),
			at(x, y + h / 2, z)
				* CFrame.Angles(b.rng:NextNumber(-0.5, 0.5), b.rng:NextNumber(0, 6.28), b.rng:NextNumber(-0.5, 0.5)),
			RUST[(i % #RUST) + 1],
			Enum.Material.CorrodedMetal
		)
	end
	part(
		b,
		"Tire",
		Vector3.new(0.6, 1.8, 1.8),
		at(1.2, 0.9, 0.6) * CFrame.Angles(0, 0.4, 0.3),
		hex("#1E1E22"),
		nil,
		Enum.PartType.Cylinder
	)
	part(
		b,
		"Plank",
		Vector3.new(3, 0.2, 0.5),
		at(-0.5, 1.6, -0.3) * CFrame.Angles(0, 0.7, 0.35),
		hex("#A0703C"),
		Enum.Material.WoodPlanks
	)
end

local function tireStack(b: Builder)
	for i = 0, 2 do
		local yaw = b.rng:NextNumber(-0.3, 0.3)
		part(
			b,
			"Tire",
			Vector3.new(0.75, 2.2, 2.2),
			at(b.rng:NextNumber(-0.15, 0.15), 0.38 + i * 0.75, 0) * CFrame.Angles(0, yaw, 0) * UP,
			hex("#1C1C20"),
			nil,
			Enum.PartType.Cylinder
		)
		part(
			b,
			"Hub",
			Vector3.new(0.78, 1.0, 1.0),
			at(0, 0.38 + i * 0.75, 0) * UP,
			hex("#8D939C"),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
end

local function crate(b: Builder)
	local wood = hex("#B07A40")
	local edge = hex("#7A5228")
	part(b, "Crate", Vector3.new(2.8, 2.8, 2.8), at(0, 1.4, 0), wood, Enum.Material.WoodPlanks)
	for _, y in { 0.15, 2.65 } do
		part(b, "Edge", Vector3.new(2.9, 0.3, 2.9), at(0, y, 0), edge, Enum.Material.Wood)
	end
	part(
		b,
		"Brace",
		Vector3.new(0.3, 3.6, 0.1),
		at(0, 1.4, -1.42) * CFrame.Angles(0, 0, math.rad(45)),
		edge,
		Enum.Material.Wood
	)
	part(
		b,
		"SmallCrate",
		Vector3.new(1.6, 1.6, 1.6),
		at(0.4, 3.6, 0.2) * CFrame.Angles(0, 0.5, 0),
		wood,
		Enum.Material.WoodPlanks
	)
end

local function oilBarrel(b: Builder)
	local colors = { hex("#2F6FD6"), hex("#D63A2F"), hex("#2FA35A") }
	for i, x in { -0.75, 0.85 } do
		local c = colors[((i + b.rng:NextInteger(0, 2)) % 3) + 1]
		part(
			b,
			"Barrel",
			Vector3.new(2.8, 1.5, 1.5),
			at(x, 1.4, 0) * UP,
			c,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		for _, y in { 0.6, 2.2 } do
			part(
				b,
				"Ring",
				Vector3.new(0.14, 1.56, 1.56),
				at(x, y, 0) * UP,
				hex("#2A2E35"),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
		part(b, "Label", Vector3.new(0.7, 0.7, 0.05), at(x, 1.4, -0.76), hex("#FFC61A"))
	end
end

local function oldTv(b: Builder)
	part(b, "Stand", Vector3.new(2.4, 1.2, 1.8), at(0, 0.6, 0), hex("#6B4A2E"), Enum.Material.Wood)
	part(b, "TV", Vector3.new(2.6, 2.1, 2.1), at(0, 2.25, 0), hex("#5A5F6A"), Enum.Material.SmoothPlastic)
	part(b, "Screen", Vector3.new(1.8, 1.4, 0.05), at(-0.2, 2.3, -1.06), hex("#1B3A4A"), Enum.Material.Glass)
	part(
		b,
		"Knob",
		Vector3.new(0.2, 0.3, 0.3),
		at(0.95, 2.6, -1.08) * FLAT,
		hex("#C9CED6"),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for side = -1, 1, 2 do
		part(
			b,
			"Antenna",
			Vector3.new(0.08, 1.6, 0.08),
			at(side * 0.4, 3.9, 0) * CFrame.Angles(0, 0, math.rad(side * -25)),
			hex("#C9CED6"),
			Enum.Material.Metal
		)
	end
end

-- Appliance Row -----------------------------------------------------------------

local APPLIANCE_WHITE = { hex("#F2F4F6"), hex("#E6EEF0"), hex("#A8E6CF"), hex("#FFD8A8"), hex("#CFE3FF") }

local function washer(b: Builder)
	local body = APPLIANCE_WHITE[b.rng:NextInteger(1, #APPLIANCE_WHITE)]
	part(b, "Body", Vector3.new(3.6, 4.0, 3.6), at(0, 2.0, 0), body)
	part(b, "Panel", Vector3.new(3.6, 0.7, 0.2), at(0, 3.65, -1.85), hex("#C9CFD6"))
	for i = 0, 2 do
		part(
			b,
			"Knob",
			Vector3.new(0.2, 0.35, 0.35),
			at(-1.1 + i * 0.6, 3.65, -1.98) * FLAT,
			hex("#4A4F57"),
			nil,
			Enum.PartType.Cylinder
		)
	end
	part(
		b,
		"DoorRing",
		Vector3.new(0.2, 2.5, 2.5),
		at(0, 1.75, -1.85) * FLAT,
		hex("#8D939C"),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	local glass = part(
		b,
		"Glass",
		Vector3.new(0.22, 1.9, 1.9),
		at(0, 1.75, -1.87) * FLAT,
		hex("#7FC8F0"),
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	glass.Transparency = 0.25
	part(
		b,
		"Dent",
		Vector3.new(0.9, 0.6, 0.05),
		at(1.3, 0.6, -1.81) * CFrame.Angles(0, 0, 0.3),
		body:Lerp(Color3.new(0, 0, 0), 0.15)
	)
end

local function fridge(b: Builder)
	local body = APPLIANCE_WHITE[b.rng:NextInteger(1, #APPLIANCE_WHITE)]
	part(b, "Body", Vector3.new(3.6, 6.6, 3.2), at(0, 3.3, 0), body)
	part(b, "Split", Vector3.new(3.62, 0.12, 3.22), at(0, 4.6, 0), body:Lerp(Color3.new(0, 0, 0), 0.25))
	part(b, "HandleTop", Vector3.new(0.18, 1.2, 0.25), at(1.4, 5.5, -1.72), hex("#C9CED6"), Enum.Material.Metal)
	part(b, "HandleBottom", Vector3.new(0.18, 2.2, 0.25), at(1.4, 3.3, -1.72), hex("#C9CED6"), Enum.Material.Metal)
	part(b, "Magnet", Vector3.new(0.5, 0.5, 0.05), at(-0.8, 3.6, -1.62) * CFrame.Angles(0, 0, 0.2), hex("#FF5A5A"))
	part(b, "Magnet", Vector3.new(0.4, 0.4, 0.05), at(-0.2, 2.9, -1.62), hex("#45D4FF"))
end

local function microwave(b: Builder)
	part(b, "Cabinet", Vector3.new(3.4, 2.4, 2.6), at(0, 1.2, 0), hex("#8A6A4A"), Enum.Material.Wood)
	part(b, "Body", Vector3.new(3.0, 1.9, 2.2), at(0, 3.35, 0), hex("#F2F4F6"))
	part(b, "Window", Vector3.new(1.9, 1.3, 0.05), at(-0.4, 3.35, -1.11), hex("#1E2228"), Enum.Material.Glass)
	part(b, "Keypad", Vector3.new(0.6, 1.3, 0.05), at(1.05, 3.35, -1.11), hex("#4A4F57"))
	part(b, "Glow", Vector3.new(0.4, 0.15, 0.05), at(1.05, 3.85, -1.13), hex("#6CFF5C"), Enum.Material.Neon)
end

local function oven(b: Builder)
	local body = APPLIANCE_WHITE[b.rng:NextInteger(1, #APPLIANCE_WHITE)]
	part(b, "Body", Vector3.new(3.6, 3.8, 3.4), at(0, 1.9, 0), body)
	part(b, "Door", Vector3.new(3.0, 2.0, 0.1), at(0, 1.5, -1.72), hex("#1E2228"), Enum.Material.Glass)
	part(b, "Handle", Vector3.new(2.6, 0.18, 0.25), at(0, 2.75, -1.82), hex("#C9CED6"), Enum.Material.Metal)
	part(b, "Back", Vector3.new(3.6, 0.9, 0.3), at(0, 4.25, 1.55), body)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			part(
				b,
				"Burner",
				Vector3.new(0.12, 1.0, 1.0),
				at(x * 0.85, 3.86, z * 0.75) * UP,
				hex("#2A2E35"),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
	end
end

local function waterHeater(b: Builder)
	part(b, "Tank", Vector3.new(5.2, 2.6, 2.6), at(0, 2.6, 0) * UP, hex("#E6EEF0"), nil, Enum.PartType.Cylinder)
	part(
		b,
		"Cap",
		Vector3.new(0.3, 2.7, 2.7),
		at(0, 5.2, 0) * UP,
		hex("#8D939C"),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for side = -1, 1, 2 do
		part(
			b,
			"Pipe",
			Vector3.new(1.2, 0.3, 0.3),
			at(side * 0.5, 5.8, 0) * UP,
			hex("#D9783A"),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	part(b, "Label", Vector3.new(0.9, 0.6, 0.05), at(0, 3.2, -1.3), hex("#FFC61A"))
end

-- Crusher Yard --------------------------------------------------------------------

local CAR_COLORS = { hex("#D63A2F"), hex("#2F6FD6"), hex("#2FA3A0"), hex("#E0A82E"), hex("#7A4AC8") }

local function wreckedCar(b: Builder)
	local c = CAR_COLORS[b.rng:NextInteger(1, #CAR_COLORS)]
	local tilt = CFrame.Angles(b.rng:NextNumber(-0.06, 0.06), 0, b.rng:NextNumber(-0.08, 0.08))
	local function cp(name, size, offset, color, material, shape)
		return part(b, name, size, tilt * offset, color, material, shape)
	end
	cp("Body", Vector3.new(4.6, 1.8, 9.0), at(0, 1.5, 0), c, Enum.Material.Metal)
	cp("Cabin", Vector3.new(4.2, 1.6, 4.6), at(0, 3.1, 0.4), c:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.Metal)
	local glass = cp("Windows", Vector3.new(4.3, 1.1, 4.0), at(0, 3.2, 0.4), hex("#2A3A48"), Enum.Material.Glass)
	glass.Transparency = 0.2
	cp("Bumper", Vector3.new(4.8, 0.5, 0.4), at(0, 0.95, -4.6), hex("#8D939C"), Enum.Material.Metal)
	cp("Rust", Vector3.new(1.6, 1.0, 0.05), at(2.31, 1.6, 1.5), hex("#7A4A2E"), Enum.Material.CorrodedMetal)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -2.9, 2.9 } do
			cp("Wheel", Vector3.new(0.7, 1.9, 1.9), at(x, 0.95, z), hex("#1C1C20"), nil, Enum.PartType.Cylinder)
		end
	end
	for side = -1, 1, 2 do
		cp("Headlight", Vector3.new(0.8, 0.4, 0.05), at(side * 1.5, 1.7, -4.52), hex("#FFF2B3"), Enum.Material.Neon)
	end
end

local ORES = {
	Iron = { rock = hex("#5B5E66"), vein = hex("#C9CED6"), material = Enum.Material.Metal, glow = false },
	Copper = { rock = hex("#6B5A4E"), vein = hex("#E07A3A"), material = Enum.Material.Metal, glow = false },
	Cobalt = { rock = hex("#3A3F4A"), vein = hex("#2F6BFF"), material = Enum.Material.Neon, glow = true },
}

local function oreNode(kind: string)
	return function(b: Builder)
		local ore = ORES[kind]
		-- A cluster of chunky rocks around a central boulder...
		local rocks = {}
		for i = 1, 5 do
			local s = if i == 1 then b.rng:NextNumber(2.6, 3.0) else b.rng:NextNumber(1.4, 2.1)
			local a = i * 1.26 + b.rng:NextNumber(-0.3, 0.3)
			local r = if i == 1 then 0 else 1.7
			local pos = Vector3.new(math.cos(a) * r, s * 0.42, math.sin(a) * r)
			part(
				b,
				"Rock",
				Vector3.new(s, s * b.rng:NextNumber(0.8, 1.05), s),
				CFrame.new(pos)
					* CFrame.Angles(b.rng:NextNumber(-0.3, 0.3), b.rng:NextNumber(0, 6.28), b.rng:NextNumber(-0.3, 0.3)),
				ore.rock,
				Enum.Material.Slate
			)
			table.insert(rocks, { pos = pos, size = s })
		end
		-- ...with ore chunks poking out of each rock's surface so the type reads at a glance.
		for i, rock in rocks do
			for k = 1, if i == 1 then 3 else 1 do
				local a = b.rng:NextNumber(0, 6.28)
				local out = Vector3.new(math.cos(a), 0, math.sin(a)) * rock.size * 0.45
				local size = b.rng:NextNumber(0.55, 0.9) * (if k == 1 then 1.2 else 1)
				local vein = part(
					b,
					"Vein",
					Vector3.new(size, size * 1.3, size),
					CFrame.new(rock.pos + out + Vector3.new(0, rock.size * b.rng:NextNumber(0.05, 0.35), 0))
						* CFrame.Angles(b.rng:NextNumber(0, 6.28), b.rng:NextNumber(0, 6.28), b.rng:NextNumber(0, 6.28)),
					ore.vein,
					ore.material
				)
				if ore.glow then
					vein.Transparency = 0.1
				end
			end
		end
	end
end

local function crystalOre(b: Builder)
	for i = 1, 4 do
		local s = b.rng:NextNumber(1.6, 2.6)
		part(
			b,
			"Rock",
			Vector3.new(s, s * 0.7, s),
			at(b.rng:NextNumber(-1.4, 1.4), s * 0.3, b.rng:NextNumber(-1.4, 1.4))
				* CFrame.Angles(0, b.rng:NextNumber(0, 6.28), b.rng:NextNumber(-0.3, 0.3)),
			hex("#4A4E58"),
			Enum.Material.Slate
		)
		local h = b.rng:NextNumber(2.6, 5.0) * (if i == 1 then 1.3 else 1)
		local crystal = part(
			b,
			"Crystal",
			Vector3.new(0.9, h, 0.9),
			at(b.rng:NextNumber(-1.2, 1.2), h / 2 + 0.6, b.rng:NextNumber(-1.2, 1.2))
				* CFrame.Angles(b.rng:NextNumber(-0.35, 0.35), b.rng:NextNumber(0, 6.28), b.rng:NextNumber(-0.35, 0.35)),
			hex("#9FF3FF"),
			Enum.Material.Glass
		)
		crystal.Transparency = 0.15
		part(
			b,
			"CrystalCore",
			Vector3.new(0.35, h * 0.7, 0.35),
			b.origin:ToObjectSpace(crystal.CFrame),
			hex("#5BE7FF"),
			Enum.Material.Neon
		)
	end
end

local function bigScrapHeap(b: Builder)
	for i = 1, 12 do
		local w = b.rng:NextNumber(1.2, 3.0)
		local h = b.rng:NextNumber(0.6, 1.6)
		local d = b.rng:NextNumber(1.2, 3.0)
		local r = 3.2 - (i / 12) * 2.4
		local a = b.rng:NextNumber(0, 6.28)
		part(
			b,
			"Scrap",
			Vector3.new(w, h, d),
			at(math.cos(a) * r * 0.6, 0.4 + (i / 12) * 3.6, math.sin(a) * r * 0.6)
				* CFrame.Angles(b.rng:NextNumber(-0.6, 0.6), b.rng:NextNumber(0, 6.28), b.rng:NextNumber(-0.6, 0.6)),
			RUST[(i % #RUST) + 1],
			Enum.Material.CorrodedMetal
		)
	end
	part(
		b,
		"Tire",
		Vector3.new(0.7, 2.0, 2.0),
		at(-1.5, 1.2, 1.0) * CFrame.Angles(0.5, 0.4, 0.3),
		hex("#1E1E22"),
		nil,
		Enum.PartType.Cylinder
	)
	part(
		b,
		"Door",
		Vector3.new(0.2, 2.2, 3.0),
		at(1.8, 1.6, -0.5) * CFrame.Angles(0.3, 0.2, 0.4),
		hex("#2F6FD6"),
		Enum.Material.Metal
	)
end

TargetModels.Kinds = {
	{
		{ Name = "Scrap Pile", Build = scrapPile },
		{ Name = "Tire Stack", Build = tireStack },
		{ Name = "Crate", Build = crate },
		{ Name = "Oil Barrels", Build = oilBarrel },
		{ Name = "Old TV", Build = oldTv },
	},
	{
		{ Name = "Washer", Build = washer },
		{ Name = "Fridge", Build = fridge },
		{ Name = "Microwave", Build = microwave },
		{ Name = "Oven", Build = oven },
		{ Name = "Water Heater", Build = waterHeater },
	},
	{
		{ Name = "Wrecked Car", Build = wreckedCar },
		{ Name = "Iron Ore", Build = oreNode("Iron") },
		{ Name = "Copper Ore", Build = oreNode("Copper") },
		{ Name = "Cobalt Ore", Build = oreNode("Cobalt") },
		{ Name = "Crystal Ore", Build = crystalOre },
		{ Name = "Scrap Heap", Build = bigScrapHeap },
	},
}

-- Builds a target at `position` (ground level). `seed` keeps layouts deterministic.
function TargetModels.build(area: number, kindIndex: number, position: Vector3, seed: number): Model
	local kinds = TargetModels.Kinds[area]
	local kind = kinds[((kindIndex - 1) % #kinds) + 1]
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = kind.Name
	local origin = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0)
	kind.Build({ model = model, origin = origin, rng = rng })

	local cf, size = model:GetBoundingBox()
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Anchored = true
	hitbox.Transparency = 1
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	hitbox.CanTouch = false
	-- Axis-aligned box on the ground so reach checks are simple and fair.
	local footprint = Vector3.new(math.max(size.X, 2), math.max(size.Y, 2), math.max(size.Z, 2))
	hitbox.Size = footprint
	hitbox.CFrame = CFrame.new(cf.Position.X, position.Y + footprint.Y / 2, cf.Position.Z)
	hitbox.Parent = model
	model.PrimaryPart = hitbox
	return model
end

-- A few representative colors, for debris effects when the target breaks.
function TargetModels.colors(model: Model): { Color3 }
	local colors = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "Hitbox" and d.Material ~= Enum.Material.Neon then
			table.insert(colors, d.Color)
			if #colors >= 4 then
				break
			end
		end
	end
	return colors
end

return TargetModels
