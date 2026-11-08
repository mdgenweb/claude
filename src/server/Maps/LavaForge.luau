--!nonstrict
-- Smithy above a lava pool. Touching lava ignites golems and pops them back out.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2
	local basalt = Color3.fromRGB(46, 40, 42)
	local lavaColor = Color3.fromRGB(255, 110, 30)
	local pitHalf = 15

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(60, 52, 50),
		floorMaterial = Enum.Material.Basalt,
		wallColor = basalt,
		wallMaterial = Enum.Material.Basalt,
		backColor = Color3.fromRGB(52, 40, 38),
		backMaterial = Enum.Material.Rock,
		frameColor = Color3.fromRGB(34, 26, 24),
		frameMaterial = Enum.Material.Slate,
	})

	local solids = b:child("Solids")
	-- Carve the pit: the shell floor is replaced locally by a lower lava surface.
	local shellFloor = b.parent:FindFirstChild("Shell") and b.parent.Shell:FindFirstChild("Floor")
	if shellFloor then
		shellFloor:Destroy()
	end
	local sideWidth = halfW - pitHalf + 6
	solids:solid({ name = "FloorL", size = Vector3.new(sideWidth, 6, 24), at = Vector3.new(-halfW - 6 + sideWidth / 2, -3, 1), color = Color3.fromRGB(60, 52, 50), material = Enum.Material.Basalt })
	solids:solid({ name = "FloorR", size = Vector3.new(sideWidth, 6, 24), at = Vector3.new(halfW + 6 - sideWidth / 2, -3, 1), color = Color3.fromRGB(60, 52, 50), material = Enum.Material.Basalt })
	solids:solid({ name = "PitBottom", size = Vector3.new(pitHalf * 2, 4, 24), at = Vector3.new(0, -9, 1), color = Color3.fromRGB(40, 20, 18), material = Enum.Material.Basalt })
	local lava = solids:solid({
		name = "Lava",
		size = Vector3.new(pitHalf * 2, 1, 24),
		at = Vector3.new(0, -5.5, 1),
		color = lavaColor,
		material = Enum.Material.CrackedLava,
		physics = PhysicalProperties.new(2, 0.1, 0.4, 1, 1),
		attributes = { Hazard = "Lava" },
	})
	lava.CanTouch = true
	-- Glowing surface layer + light + bubbling.
	local glow = b:part({ name = "LavaGlow", size = Vector3.new(pitHalf * 2, 0.2, 22), at = Vector3.new(0, -4.9, 1), color = Color3.fromRGB(255, 150, 40), material = Enum.Material.Neon, transparency = 0.35, shadow = false })
	b:light(glow, "SurfaceLight", { Face = Enum.NormalId.Top, Color = lavaColor, Brightness = 3, Range = 30, Angle = 120, Shadows = false })
	b:emitter(glow, {
		Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
		Rate = 30,
		Lifetime = NumberRange.new(1, 2.4),
		Speed = NumberRange.new(4, 12),
		SpreadAngle = Vector2.new(25, 25),
		Size = b.seq(0, 0.35, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 4, 0),
	})
	b:emitter(glow, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 6,
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(2, 4),
		Size = b.seq(0, 3, 1, 8),
		Transparency = b.seq(0, 0.6, 1, 1),
		Color = ColorSequence.new(Color3.fromRGB(80, 50, 40)),
		EmissionDirection = Enum.NormalId.Top,
	})
	-- Pit rim stones.
	for _, side in { -1, 1 } do
		solids:solid({ name = "Rim", size = Vector3.new(2, 2, 24), at = Vector3.new(side * (pitHalf + 1), 1, 1), color = Color3.fromRGB(80, 60, 54), material = Enum.Material.Rock })
	end

	local deco = b:child("Decor")
	-- Forge furnace on the back wall.
	deco:part({ name = "Furnace", size = Vector3.new(16, 18, 5), at = Vector3.new(-34, 9, -9), color = Color3.fromRGB(70, 56, 50), material = Enum.Material.Cobblestone })
	local mouth = deco:part({ name = "FurnaceMouth", size = Vector3.new(8, 6, 0.4), at = Vector3.new(-34, 6, -6.4), color = Color3.fromRGB(255, 120, 30), material = Enum.Material.Neon })
	deco:light(mouth, "SurfaceLight", { Face = Enum.NormalId.Front, Color = Color3.fromRGB(255, 120, 40), Brightness = 2.5, Range = 24, Angle = 80 }):AddTag("Flicker")
	deco:emitter(mouth, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 24,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(2, 4),
		Size = b.seq(0, 2.4, 1, 0),
		Transparency = b.seq(0, 0.2, 1, 1),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 10)),
		EmissionDirection = Enum.NormalId.Top,
	})
	deco:part({ name = "Chimney", size = Vector3.new(6, H - 18, 4), at = Vector3.new(-34, 18 + (H - 18) / 2, -9.5), color = Color3.fromRGB(64, 50, 46), material = Enum.Material.Brick })
	-- Anvils and tools.
	deco:part({ name = "AnvilDeco", size = Vector3.new(4, 1.6, 2), at = Vector3.new(34, 3.8, -6), color = Color3.fromRGB(60, 62, 70), material = Enum.Material.Metal })
	deco:part({ name = "AnvilBase", size = Vector3.new(2, 3, 1.6), at = Vector3.new(34, 1.5, -6), color = Color3.fromRGB(50, 52, 60), material = Enum.Material.Metal })
	for i = 1, 6 do
		deco:part({ name = "Tool", size = Vector3.new(0.4, rng:NextNumber(3, 5), 0.4), at = Vector3.new(20 + i * 2.2, 20, -10.4), rot = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), color = Color3.fromRGB(80, 80, 90), material = Enum.Material.Metal })
	end
	-- Glowing cracks in the back wall.
	for _ = 1, 10 do
		deco:part({ name = "Crack", size = Vector3.new(rng:NextNumber(3, 9), 0.3, 0.2), at = Vector3.new(rng:NextNumber(-halfW + 6, halfW - 6), rng:NextNumber(8, H - 6), -10.9), rot = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-40, 40))), color = Color3.fromRGB(255, 110, 30), material = Enum.Material.Neon, transparency = 0.15, shadow = false })
	end
	deco:torch(-halfW + 6, 30, -8.5, Color3.fromRGB(255, 130, 50), 22)
	deco:torch(halfW - 6, 30, -8.5, Color3.fromRGB(255, 130, 50), 22)
	-- Hanging chains over the pit.
	for _, x in { -9, 0, 9 } do
		deco:part({ name = "Chain", size = Vector3.new(0.35, 22, 0.35), at = Vector3.new(x, H - 11, -4), color = Color3.fromRGB(60, 56, 54), material = Enum.Material.Metal })
	end
	-- Stone platform over the pit (solid).
	solids:solid({ name = "Platform", size = Vector3.new(10, 1.4, 8), at = Vector3.new(0, 18, -0.5), color = Color3.fromRGB(80, 64, 58), material = Enum.Material.Cobblestone })

	return {
		cauldron = Vector3.new(-24, 0, -5.5),
		rack = Vector3.new(halfW - 12, 0, -8.8),
		spawn = Vector3.new(-30, 0, 0),
	}
end
