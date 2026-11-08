--!nonstrict
-- Pastel bouncy castle: rubber floor and walls plus pinball bumpers that kick golems away.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2
	local rubber = PhysicalProperties.new(0.8, 0.3, 0.95, 1, 100)

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(255, 140, 190),
		floorMaterial = Enum.Material.Rubber,
		wallColor = Color3.fromRGB(150, 200, 255),
		wallMaterial = Enum.Material.Rubber,
		backColor = Color3.fromRGB(255, 220, 150),
		backMaterial = Enum.Material.Fabric,
		ceilingColor = Color3.fromRGB(190, 150, 255),
		ceilingMaterial = Enum.Material.Rubber,
		frameColor = Color3.fromRGB(255, 120, 170),
		frameMaterial = Enum.Material.Plastic,
		floorPhysics = rubber,
		wallPhysics = rubber,
	})

	local solids = b:child("Solids")
	local deco = b:child("Decor")

	-- Inflatable stripes on the back wall.
	local stripeColors = {
		Color3.fromRGB(255, 120, 170),
		Color3.fromRGB(120, 200, 255),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(150, 255, 160),
	}
	for i = 0, 13 do
		deco:part({
			name = "Stripe",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(H, 4, 4),
			at = Vector3.new(-halfW + 4 + i * 8, H / 2, -10.2),
			rot = CFrame.Angles(0, 0, math.rad(90)),
			color = stripeColors[i % 4 + 1],
			material = Enum.Material.Rubber,
		})
	end
	-- Turrets with flags along the top.
	for _, x in { -halfW + 8, -20, 20, halfW - 8 } do
		deco:part({
			name = "Turret",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(10, 7, 7),
			at = Vector3.new(x, H - 6, -8),
			rot = CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(255, 160, 200),
			material = Enum.Material.Rubber,
		})
		deco:part({
			name = "FlagPole",
			size = Vector3.new(0.3, 5, 0.3),
			at = Vector3.new(x, H + 1.5, -8),
			color = Color3.fromRGB(240, 240, 240),
			material = Enum.Material.Metal,
		})
		deco:part({
			name = "Flag",
			size = Vector3.new(3, 1.8, 0.1),
			at = Vector3.new(x + 1.6, H + 3, -8),
			color = stripeColors[rng:NextInteger(1, 4)],
			material = Enum.Material.Fabric,
		})
	end

	-- Bumpers (round discs facing the camera).
	local bumpers = {
		{ x = -30, y = 22, r = 5 },
		{ x = 0, y = 34, r = 6 },
		{ x = 30, y = 22, r = 5 },
		{ x = -14, y = 46, r = 4 },
		{ x = 14, y = 46, r = 4 },
	}
	for _, spec in bumpers do
		local bumper = solids:solid({
			name = "Bumper",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(8, spec.r * 2, spec.r * 2),
			at = Vector3.new(spec.x, spec.y, -0.5),
			rot = CFrame.Angles(0, math.rad(90), 0),
			color = Color3.fromRGB(255, 80, 150),
			material = Enum.Material.Neon,
			physics = rubber,
			attributes = { Hazard = "Bumper", BumperForce = 140 },
		})
		bumper.CanTouch = true
		local ring = deco:part({
			name = "BumperRing",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(8.4, spec.r * 2 + 1, spec.r * 2 + 1),
			at = Vector3.new(spec.x, spec.y, -0.8),
			rot = CFrame.Angles(0, math.rad(90), 0),
			color = Color3.fromRGB(255, 255, 255),
			material = Enum.Material.SmoothPlastic,
		})
		local _ = ring
		deco:light(bumper, "PointLight", { Color = Color3.fromRGB(255, 120, 190), Brightness = 1, Range = 14 })
	end

	-- Springy platforms near the floor.
	for _, x in { -40, 40 } do
		local pad = solids:solid({
			name = "SpringPad",
			size = Vector3.new(10, 1, 8),
			at = Vector3.new(x, 1.5, -0.5),
			color = Color3.fromRGB(120, 255, 160),
			material = Enum.Material.Neon,
			physics = PhysicalProperties.new(0.8, 0.3, 1, 1, 100),
			attributes = { Hazard = "Trampoline", LaunchSpeed = 140 },
		})
		pad.CanTouch = true
	end

	-- Confetti drifting from above.
	local confettiHost = deco:part({
		name = "Confetti",
		size = Vector3.new(W, 1, 6),
		at = Vector3.new(0, H - 2, -1),
		transparency = 1,
		shadow = false,
	})
	deco:emitter(confettiHost, {
		Texture = "rbxasset://textures/particles/SquareParticle.png",
		Rate = 10,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(1, 3),
		Size = b.seq(0, 0.35, 1, 0.3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 170)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(120, 200, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 220, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 160)),
		}),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
		Acceleration = Vector3.new(0, -3, 0),
	})
	local sun = deco:part({
		name = "Glow",
		size = Vector3.new(1, 1, 1),
		at = Vector3.new(0, H - 8, 6),
		transparency = 1,
		shadow = false,
	})
	deco:light(
		sun,
		"PointLight",
		{ Color = Color3.fromRGB(255, 240, 250), Brightness = 1.2, Range = 60, Shadows = true }
	)

	return {
		cauldron = Vector3.new(-24, 0, -5.5),
		rack = Vector3.new(halfW - 14, 0, -8.8),
		spawn = Vector3.new(0, 0, 0),
	}
end
