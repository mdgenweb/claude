--!nonstrict
-- Rain-soaked rooftop with two tesla coils that zap nearby golems.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(70, 66, 80),
		floorMaterial = Enum.Material.RoofShingles,
		wallColor = Color3.fromRGB(56, 60, 76),
		wallMaterial = Enum.Material.Slate,
		backColor = Color3.fromRGB(24, 28, 44),
		backMaterial = Enum.Material.Slate,
		ceilingColor = Color3.fromRGB(30, 32, 48),
		ceilingMaterial = Enum.Material.Slate,
		frameColor = Color3.fromRGB(30, 30, 40),
		frameMaterial = Enum.Material.Metal,
	})
	-- Open sky: the ceiling and back wall become nearly invisible (still solid).
	local shell = b.parent:FindFirstChild("Shell")
	if shell then
		local ceiling = shell:FindFirstChild("Ceiling")
		if ceiling then
			ceiling.Transparency = 1
			ceiling.CastShadow = false
		end
		local back = shell:FindFirstChild("BackWall")
		if back then
			back.Transparency = 0.92
			back.Material = Enum.Material.Glass
		end
	end

	local solids = b:child("Solids")
	local deco = b:child("Decor")
	local hazards = b:child("Hazards")

	-- City skyline silhouettes far behind (glowing windows).
	for i = 0, 11 do
		local h = rng:NextNumber(20, 55)
		local w = rng:NextNumber(8, 14)
		local x = -halfW - 20 + i * 14
		deco:part({ name = "Tower", size = Vector3.new(w, h, 6), at = Vector3.new(x, h / 2 - 8, -60), color = Color3.fromRGB(26, 28, 44), material = Enum.Material.Concrete, shadow = false })
		for _ = 1, 4 do
			deco:part({ name = "TowerWindow", size = Vector3.new(1, 1.4, 0.2), at = Vector3.new(x + rng:NextNumber(-w / 2 + 1, w / 2 - 1), rng:NextNumber(0, h - 10), -56.8), color = Color3.fromRGB(255, 220, 140), material = Enum.Material.Neon, shadow = false })
		end
	end

	-- Chimneys and antenna on the roof (solid).
	solids:solid({ name = "Chimney", size = Vector3.new(6, 12, 8), at = Vector3.new(-halfW + 8, 6, -0.5), color = Color3.fromRGB(110, 70, 60), material = Enum.Material.Brick })
	solids:solid({ name = "Vent", size = Vector3.new(10, 4, 8), at = Vector3.new(4, 2, -0.5), color = Color3.fromRGB(90, 96, 110), material = Enum.Material.DiamondPlate })
	deco:part({ name = "Antenna", size = Vector3.new(0.4, 30, 0.4), at = Vector3.new(halfW - 6, 15, -8), color = Color3.fromRGB(150, 150, 160), material = Enum.Material.Metal })
	local beacon = deco:part({ name = "Beacon", shape = Enum.PartType.Ball, size = Vector3.one, at = Vector3.new(halfW - 6, 30.5, -8), color = Color3.fromRGB(255, 50, 50), material = Enum.Material.Neon, shadow = false })
	deco:light(beacon, "PointLight", { Color = Color3.fromRGB(255, 60, 60), Brightness = 1.4, Range = 12 }):AddTag("Flicker")

	-- Tesla coils.
	for _, x in { -26, 30 } do
		solids:solid({ name = "CoilBase", size = Vector3.new(6, 3, 8), at = Vector3.new(x, 1.5, -0.5), color = Color3.fromRGB(70, 74, 90), material = Enum.Material.Metal })
		deco:part({ name = "CoilShaft", shape = Enum.PartType.Cylinder, size = Vector3.new(14, 2.4, 2.4), at = Vector3.new(x, 10, -0.5), rot = CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(184, 115, 51), material = Enum.Material.Metal })
		for ring = 0, 5 do
			deco:part({ name = "CoilRing", shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 3.4, 3.4), at = Vector3.new(x, 4.5 + ring * 2, -0.5), rot = CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(220, 160, 80), material = Enum.Material.Metal })
		end
		local top = hazards:part({
			name = "TeslaTop",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 5,
			at = Vector3.new(x, 19, -0.5),
			color = Color3.fromRGB(150, 220, 255),
			material = Enum.Material.Neon,
			shadow = false,
			attributes = { Hazard = "Tesla", TeslaRange = 34, TeslaInterval = 3 },
		})
		deco:light(top, "PointLight", { Color = Color3.fromRGB(140, 200, 255), Brightness = 2, Range = 22 }):AddTag("Flicker")
		deco:emitter(top, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 18,
			Lifetime = NumberRange.new(0.2, 0.5),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(180, 180),
			Size = b.seq(0, 0.6, 1, 0),
			LightEmission = 1,
			Color = ColorSequence.new(Color3.fromRGB(180, 230, 255)),
		})
	end

	-- Rain.
	local rainHost = deco:part({ name = "Rain", size = Vector3.new(W + 20, 1, 30), at = Vector3.new(0, H + 4, 0), transparency = 1, shadow = false })
	deco:emitter(rainHost, {
		Texture = "rbxasset://textures/particles/SquareParticle.png",
		Rate = 160,
		Lifetime = NumberRange.new(0.8, 1.1),
		Speed = NumberRange.new(80, 95),
		Size = b.seq(0, 0.07, 1, 0.07),
		Transparency = b.seq(0, 0.45, 1, 0.6),
		Squash = b.seq(0, 6, 1, 6),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.fromRGB(180, 200, 240)),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local moonHost = deco:part({ name = "Moonlight", size = Vector3.one, at = Vector3.new(-20, H, 20), transparency = 1, shadow = false })
	deco:light(moonHost, "PointLight", { Color = Color3.fromRGB(140, 160, 255), Brightness = 1.2, Range = 90, Shadows = true })

	return {
		cauldron = Vector3.new(-8, 0, -5.5),
		rack = Vector3.new(halfW - 16, 0, -8.8),
		spawn = Vector3.new(0, 4, 0),
	}
end
