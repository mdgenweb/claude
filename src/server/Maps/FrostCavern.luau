--!nonstrict
-- Ice cave: zero-friction floor, glowing crystals and icicles that drop when struck.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2
	local iceFloor = PhysicalProperties.new(0.9, 0.02, 0.05, 100, 1)

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(190, 230, 255),
		floorMaterial = Enum.Material.Ice,
		wallColor = Color3.fromRGB(120, 160, 200),
		wallMaterial = Enum.Material.Glacier,
		backColor = Color3.fromRGB(90, 130, 175),
		backMaterial = Enum.Material.Glacier,
		ceilingColor = Color3.fromRGB(100, 140, 185),
		ceilingMaterial = Enum.Material.Glacier,
		frameColor = Color3.fromRGB(60, 90, 130),
		frameMaterial = Enum.Material.Rock,
		floorPhysics = iceFloor,
	})

	local solids = b:child("Solids")
	local deco = b:child("Decor")
	local hazards = b:child("Hazards")

	-- Rock formations on the back wall.
	for _ = 1, 14 do
		local s = rng:NextNumber(4, 10)
		deco:part({ name = "Rock", size = Vector3.new(s, s * rng:NextNumber(0.6, 1.4), 4), at = Vector3.new(rng:NextNumber(-halfW, halfW), rng:NextNumber(0, H), -10), rot = CFrame.Angles(0, 0, math.rad(rng:NextNumber(0, 90))), color = Color3.fromRGB(80 + rng:NextInteger(0, 30), 120, 160), material = Enum.Material.Glacier })
	end
	-- Glowing crystal clusters.
	local crystalColors = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(170, 140, 255), Color3.fromRGB(120, 255, 220) }
	for i = 1, 7 do
		local x = -halfW + 6 + (i - 1) * ((W - 12) / 6)
		local color = crystalColors[rng:NextInteger(1, #crystalColors)]
		local host
		for c = 1, 3 do
			local h = rng:NextNumber(3, 7)
			local crystal = deco:part({ name = "Crystal", size = Vector3.new(1.2, h, 1.2), at = Vector3.new(x + (c - 2) * 1.2, h / 2, -8.8), rot = CFrame.Angles(0, math.rad(45), math.rad((c - 2) * 18)), color = color, material = Enum.Material.Neon, transparency = 0.25, shadow = false })
			host = host or crystal
		end
		deco:light(host, "PointLight", { Color = color, Brightness = 1.2, Range = 16 })
	end

	-- Icicles hanging from the ceiling (HazardService drops them when hit).
	for i = 1, 9 do
		local x = -halfW + 8 + (i - 1) * ((W - 16) / 8) + rng:NextNumber(-2, 2)
		local length = rng:NextNumber(4, 8)
		local icicle = hazards:part({
			name = "Icicle",
			class = "WedgePart",
			size = Vector3.new(2, length, 2),
			at = Vector3.new(x, H - length / 2, -0.5),
			rot = CFrame.Angles(math.rad(180), 0, 0),
			color = Color3.fromRGB(200, 240, 255),
			material = Enum.Material.Ice,
			transparency = 0.15,
			collide = true,
			attributes = { Hazard = "Icicle" },
		})
		icicle.CanTouch = true
	end

	-- Frozen ledges.
	solids:solid({ name = "IceLedge", size = Vector3.new(16, 1.4, 8), at = Vector3.new(-30, 16, -0.5), color = Color3.fromRGB(200, 235, 255), material = Enum.Material.Ice, physics = iceFloor })
	solids:solid({ name = "IceLedge", size = Vector3.new(16, 1.4, 8), at = Vector3.new(30, 26, -0.5), color = Color3.fromRGB(200, 235, 255), material = Enum.Material.Ice, physics = iceFloor })
	-- A snow ramp (wedge) on the right.
	solids:solid({ name = "SnowRamp", class = "WedgePart", size = Vector3.new(8, 8, 18), at = Vector3.new(halfW - 10, 4, -0.5), rot = CFrame.Angles(0, math.rad(-90), 0), color = Color3.fromRGB(240, 248, 255), material = Enum.Material.Snow, physics = iceFloor })

	-- Falling snow.
	local snowHost = deco:part({ name = "Snow", size = Vector3.new(W, 1, 14), at = Vector3.new(0, H - 1, 0), transparency = 1, shadow = false })
	deco:emitter(snowHost, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 40,
		Lifetime = NumberRange.new(5, 9),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(20, 20),
		Size = b.seq(0, 0.25, 1, 0.2),
		Transparency = b.seq(0, 0.2, 0.9, 0.4, 1, 1),
		LightEmission = 0.4,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local fill = deco:part({ name = "Fill", size = Vector3.one, at = Vector3.new(0, H - 10, 8), transparency = 1, shadow = false })
	deco:light(fill, "PointLight", { Color = Color3.fromRGB(170, 210, 255), Brightness = 1.4, Range = 60, Shadows = true })

	return {
		cauldron = Vector3.new(-14, 0, -5.5),
		rack = Vector3.new(halfW - 24, 0, -8.8),
		spawn = Vector3.new(0, 0, 0),
	}
end
