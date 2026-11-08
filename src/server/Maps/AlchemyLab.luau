--!nonstrict
-- Default lab: candle-lit stone workshop with shelves, windows, chandelier and a work table.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2
	local stone = Color3.fromRGB(96, 82, 94)
	local wood = Color3.fromRGB(96, 64, 46)
	local darkWood = Color3.fromRGB(58, 38, 30)

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(128, 88, 62),
		floorMaterial = Enum.Material.WoodPlanks,
		wallColor = stone,
		wallMaterial = Enum.Material.Brick,
		backColor = Color3.fromRGB(84, 70, 84),
		backMaterial = Enum.Material.Brick,
		ceilingColor = darkWood,
		ceilingMaterial = Enum.Material.Wood,
		frameColor = darkWood,
		frameMaterial = Enum.Material.Wood,
	})

	local deco = b:child("Decor")

	-- Stone skirting and pillars along the back wall.
	deco:part({
		name = "Skirting",
		size = Vector3.new(W, 2.4, 1.6),
		at = Vector3.new(0, 1.2, -10.2),
		color = Color3.fromRGB(70, 60, 72),
		material = Enum.Material.Cobblestone,
	})
	for _, x in { -halfW + 3, -18, 18, halfW - 3 } do
		deco:part({
			name = "Pillar",
			size = Vector3.new(4, H, 2.4),
			at = Vector3.new(x, H / 2, -9.8),
			color = Color3.fromRGB(110, 96, 108),
			material = Enum.Material.Slate,
		})
	end
	-- Ceiling beams.
	for i = -3, 3 do
		deco:part({
			name = "Beam",
			size = Vector3.new(2, 2.2, 22),
			at = Vector3.new(i * 16, H - 1.1, 0),
			color = darkWood,
			material = Enum.Material.Wood,
		})
	end

	-- Windows with moonlight.
	local moon = Color3.fromRGB(150, 180, 255)
	deco:window(-36, 34, 12, 16, darkWood, moon)
	deco:window(36, 34, 12, 16, darkWood, moon)

	-- Glowing alchemy circle on the back wall.
	local ringRot = CFrame.Angles(0, math.rad(90), 0)
	deco:part({
		name = "SigilOuter",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 18, 18),
		at = Vector3.new(0, 36, -10.6),
		rot = ringRot,
		color = Color3.fromRGB(170, 90, 255),
		material = Enum.Material.Neon,
		transparency = 0.55,
		shadow = false,
	})
	deco:part({
		name = "SigilInner",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.25, 16.6, 16.6),
		at = Vector3.new(0, 36, -10.5),
		rot = ringRot,
		color = Color3.fromRGB(60, 40, 80),
		material = Enum.Material.Slate,
		shadow = false,
	})
	local core = deco:part({
		name = "SigilCore",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 5, 5),
		at = Vector3.new(0, 36, -10.4),
		rot = ringRot,
		color = Color3.fromRGB(200, 140, 255),
		material = Enum.Material.Neon,
		transparency = 0.2,
		shadow = false,
	})
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		deco:part({
			name = "SigilSpoke",
			size = Vector3.new(0.3, 7, 0.3),
			at = Vector3.new(math.cos(angle) * 4, 36 + math.sin(angle) * 4, -10.35),
			rot = CFrame.Angles(0, 0, angle + math.rad(90)),
			color = Color3.fromRGB(200, 140, 255),
			material = Enum.Material.Neon,
			transparency = 0.3,
			shadow = false,
		})
	end
	core:AddTag("Spinner")
	core:SetAttribute("SpinSpeed", 0.4)
	deco:light(
		core,
		"PointLight",
		{ Color = Color3.fromRGB(170, 100, 255), Brightness = 1.2, Range = 22, Shadows = false }
	)

	-- Shelves full of bottles and books.
	deco:bottleShelf(-46, 14, 14, rng)
	deco:bottleShelf(-46, 22, 14, rng)
	deco:bottleShelf(46, 18, 12, rng)
	deco:bottleShelf(-8, 50, 22, rng)
	deco:books(-28, 14.3, 9, rng)
	deco:part({
		name = "Shelf",
		size = Vector3.new(12, 0.6, 3),
		at = Vector3.new(-24, 14, -9.2),
		color = wood,
		material = Enum.Material.WoodPlanks,
	})
	deco:books(22, 24.3, 12, rng)
	deco:part({
		name = "Shelf",
		size = Vector3.new(14, 0.6, 3),
		at = Vector3.new(26, 24, -9.2),
		color = wood,
		material = Enum.Material.WoodPlanks,
	})

	-- Hanging herbs.
	for i = 1, 7 do
		local x = -30 + i * 8 + rng:NextNumber(-1, 1)
		local len = rng:NextNumber(3, 6)
		deco:part({
			name = "String",
			size = Vector3.new(0.1, len, 0.1),
			at = Vector3.new(x, H - 2.2 - len / 2, -6),
			color = Color3.fromRGB(200, 190, 160),
			material = Enum.Material.Fabric,
			shadow = false,
		})
		deco:part({
			name = "Herb",
			size = Vector3.new(1.2, 1.6, 1.2),
			at = Vector3.new(x, H - 2.6 - len, -6),
			color = Color3.fromRGB(70 + rng:NextInteger(0, 40), 120, 60),
			material = Enum.Material.LeafyGrass,
			shape = Enum.PartType.Ball,
		})
	end

	-- Chandelier.
	local chandelier = deco:part({
		name = "Chandelier",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.6, 10, 10),
		at = Vector3.new(0, H - 12, -2),
		rot = CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(70, 56, 40),
		material = Enum.Material.Metal,
	})
	deco:part({
		name = "Chain",
		size = Vector3.new(0.3, 9, 0.3),
		at = Vector3.new(0, H - 7, -2),
		color = Color3.fromRGB(70, 60, 50),
		material = Enum.Material.Metal,
	})
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local px, pz = math.cos(angle) * 4.4, math.sin(angle) * 4.4 - 2
		deco:part({
			name = "Candle",
			size = Vector3.new(0.5, 1.4, 0.5),
			at = Vector3.new(px, H - 11, pz),
			color = Color3.fromRGB(245, 236, 210),
			material = Enum.Material.SmoothPlastic,
		})
		local flame = deco:part({
			name = "CandleFlame",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 0.45,
			at = Vector3.new(px, H - 10, pz),
			color = Color3.fromRGB(255, 196, 110),
			material = Enum.Material.Neon,
			shadow = false,
		})
		if i % 2 == 0 then
			local light = deco:light(
				flame,
				"PointLight",
				{ Color = Color3.fromRGB(255, 180, 110), Brightness = 1.3, Range = 22, Shadows = true }
			)
			light:AddTag("Flicker")
		end
	end
	local _ = chandelier

	-- Wall torches.
	deco:torch(-halfW + 6, 26, -8.5, Color3.fromRGB(255, 160, 70), 24)
	deco:torch(halfW - 6, 26, -8.5, Color3.fromRGB(255, 160, 70), 24)

	-- Rug.
	deco:part({
		name = "Rug",
		size = Vector3.new(30, 0.12, 9),
		at = Vector3.new(0, 0.07, -2),
		color = Color3.fromRGB(130, 40, 60),
		material = Enum.Material.Fabric,
		shadow = false,
	})
	deco:part({
		name = "RugTrim",
		size = Vector3.new(31, 0.1, 10),
		at = Vector3.new(0, 0.05, -2),
		color = Color3.fromRGB(214, 170, 82),
		material = Enum.Material.Fabric,
		shadow = false,
	})

	-- Foreground clutter on the front edge (frames the diorama without blocking play).
	deco:part({
		name = "FrontBarrel",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3, 2.6, 2.6),
		at = Vector3.new(-halfW + 4, 1.5, 9),
		rot = CFrame.Angles(0, 0, math.rad(90)),
		color = wood,
		material = Enum.Material.Wood,
	})
	deco:part({
		name = "FrontCrate",
		size = Vector3.new(3, 2, 3),
		at = Vector3.new(halfW - 5, 1, 9.5),
		rot = CFrame.Angles(0, math.rad(20), 0),
		color = Color3.fromRGB(150, 110, 70),
		material = Enum.Material.WoodPlanks,
	})

	-- Work table (solid): golems can be knocked off it.
	local solids = b:child("Solids")
	solids:solid({
		name = "TableTop",
		size = Vector3.new(16, 1, 8),
		at = Vector3.new(26, 8, -0.5),
		color = Color3.fromRGB(140, 96, 64),
		material = Enum.Material.WoodPlanks,
	})
	for _, x in { 19.5, 32.5 } do
		solids:solid({
			name = "TableLeg",
			size = Vector3.new(1, 7.5, 1),
			at = Vector3.new(x, 3.75, -0.5),
			color = darkWood,
			material = Enum.Material.Wood,
		})
	end
	-- A high wooden ledge on the left.
	solids:solid({
		name = "Ledge",
		size = Vector3.new(14, 1.2, 8),
		at = Vector3.new(-halfW + 7, 30, -0.5),
		color = Color3.fromRGB(110, 76, 54),
		material = Enum.Material.WoodPlanks,
	})

	return {
		cauldron = Vector3.new(-30, 0, -5.5),
		rack = Vector3.new(halfW - 14, 0, -8.8),
		spawn = Vector3.new(0, 0, 0),
	}
end
