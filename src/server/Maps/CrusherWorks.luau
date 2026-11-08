--!nonstrict
-- Factory floor with two hydraulic crushers and a conveyor belt feeding them.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2
	local steel = Color3.fromRGB(88, 94, 104)

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(110, 112, 116),
		floorMaterial = Enum.Material.Concrete,
		wallColor = steel,
		wallMaterial = Enum.Material.DiamondPlate,
		backColor = Color3.fromRGB(78, 84, 92),
		backMaterial = Enum.Material.CorrodedMetal,
		ceilingColor = Color3.fromRGB(60, 64, 72),
		ceilingMaterial = Enum.Material.Metal,
		frameColor = Color3.fromRGB(40, 42, 48),
		frameMaterial = Enum.Material.Metal,
	})

	local solids = b:child("Solids")
	local deco = b:child("Decor")
	local hazards = b:child("Hazards")

	-- Hazard stripes along the floor edge.
	for i = 0, 27 do
		deco:part({
			name = "Stripe",
			size = Vector3.new(2, 0.12, 1.4),
			at = Vector3.new(-halfW + 2 + i * 4, 0.07, -7.6),
			rot = CFrame.Angles(0, math.rad(35), 0),
			color = if i % 2 == 0 then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(30, 30, 34),
			material = Enum.Material.SmoothPlastic,
			shadow = false,
		})
	end

	-- Two crushers. HazardService animates parts tagged "Crusher".
	for index, x in { -22, 16 } do
		deco:part({
			name = "PistonHousing",
			size = Vector3.new(8, 8, 9),
			at = Vector3.new(x, H - 4, -1),
			color = Color3.fromRGB(70, 74, 84),
			material = Enum.Material.DiamondPlate,
		})
		local head = hazards:solid({
			name = "CrusherHead",
			size = Vector3.new(12, 5, 10),
			at = Vector3.new(x, H - 12, -0.5),
			color = Color3.fromRGB(210, 60, 50),
			material = Enum.Material.Metal,
			attributes = { Hazard = "Crusher", TopY = H - 12, BottomY = 2.6, Period = 3.4, Phase = index * 1.6 },
		})
		head.CanTouch = true
		-- Warning stripes on the head.
		for s = -2, 2 do
			hazards:part({
				name = "HeadStripe",
				size = Vector3.new(1.2, 4.6, 0.2),
				at = Vector3.new(x + s * 2.4, H - 12, 4.6),
				rot = CFrame.Angles(0, 0, math.rad(30)),
				color = Color3.fromRGB(255, 210, 40),
				material = Enum.Material.SmoothPlastic,
				shadow = false,
				attributes = { CrusherChild = index },
			})
		end
		head:SetAttribute("CrusherIndex", index)
		local rod = hazards:part({
			name = "CrusherRod",
			size = Vector3.new(2.4, 10, 2.4),
			at = Vector3.new(x, H - 6, -0.5),
			color = Color3.fromRGB(200, 205, 215),
			material = Enum.Material.Metal,
			attributes = { CrusherChild = index },
		})
		local _ = rod
		-- Warning lamp.
		local lamp = deco:part({
			name = "WarningLamp",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 1.4,
			at = Vector3.new(x + 5, H - 2, 3),
			color = Color3.fromRGB(255, 120, 30),
			material = Enum.Material.Neon,
			shadow = false,
		})
		deco:light(lamp, "PointLight", { Color = Color3.fromRGB(255, 120, 30), Brightness = 1.5, Range = 16 })
			:AddTag("Flicker")
	end

	-- Conveyor belt on the right that carries things towards the crusher.
	local belt = hazards:solid({
		name = "Conveyor",
		size = Vector3.new(24, 1.2, 9),
		at = Vector3.new(halfW - 14, 0.6, -0.5),
		color = Color3.fromRGB(40, 40, 46),
		material = Enum.Material.Rubber,
		physics = PhysicalProperties.new(1, 1.2, 0, 2, 1),
		attributes = { Hazard = "Conveyor" },
	})
	belt.AssemblyLinearVelocity = Vector3.new(-22, 0, 0)
	for i = 0, 5 do
		local chevron = deco:part({
			name = "Chevron",
			size = Vector3.new(0.4, 0.1, 2.6),
			at = Vector3.new(halfW - 24 + i * 4, 1.25, 3),
			rot = CFrame.Angles(0, math.rad(45), 0),
			color = Color3.fromRGB(80, 255, 140),
			material = Enum.Material.Neon,
			shadow = false,
		})
		chevron:AddTag("Scroller")
		chevron:SetAttribute("ScrollSpeed", -22)
		chevron:SetAttribute("ScrollMin", halfW - 26)
		chevron:SetAttribute("ScrollMax", halfW - 2)
	end

	-- Catwalk (solid) and pipes.
	solids:solid({
		name = "Catwalk",
		size = Vector3.new(22, 1, 8),
		at = Vector3.new(-halfW + 11, 22, -0.5),
		color = Color3.fromRGB(80, 86, 96),
		material = Enum.Material.DiamondPlate,
	})
	for _, y in { 32, 38, 44 } do
		deco:part({
			name = "Pipe",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(W, 1.6, 1.6),
			at = Vector3.new(0, y, -10),
			color = Color3.fromRGB(120 + rng:NextInteger(0, 40), 90, 70),
			material = Enum.Material.CorrodedMetal,
		})
	end
	for _ = 1, 6 do
		local gauge = deco:part({
			name = "Gauge",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, 2.2, 2.2),
			at = Vector3.new(rng:NextNumber(-halfW + 6, halfW - 6), rng:NextNumber(8, 28), -10.6),
			rot = CFrame.Angles(0, math.rad(90), 0),
			color = Color3.fromRGB(230, 230, 220),
			material = Enum.Material.SmoothPlastic,
		})
		local _ = gauge
	end
	-- Big industrial lights.
	for _, x in { -36, 0, 36 } do
		local lampHousing = deco:part({
			name = "HighBay",
			size = Vector3.new(5, 1, 5),
			at = Vector3.new(x, H - 1, 0),
			color = Color3.fromRGB(50, 52, 60),
			material = Enum.Material.Metal,
		})
		local bulb = deco:part({
			name = "HighBayBulb",
			size = Vector3.new(4, 0.3, 4),
			at = Vector3.new(x, H - 1.6, 0),
			color = Color3.fromRGB(255, 250, 230),
			material = Enum.Material.Neon,
			shadow = false,
		})
		deco:light(bulb, "SpotLight", {
			Face = Enum.NormalId.Bottom,
			Color = Color3.fromRGB(255, 245, 225),
			Brightness = 2.2,
			Range = 60,
			Angle = 70,
			Shadows = true,
		})
		local _ = lampHousing
	end

	return {
		cauldron = Vector3.new(-40, 0, -5.5),
		rack = Vector3.new(halfW - 10, 0, -8.8),
		spawn = Vector3.new(halfW - 14, 1.4, 0),
	}
end
