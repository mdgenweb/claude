--!nonstrict
-- Low-gravity observatory floating among the stars.

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(46, 36, 70),
		floorMaterial = Enum.Material.Marble,
		wallColor = Color3.fromRGB(30, 22, 50),
		wallMaterial = Enum.Material.Marble,
		backColor = Color3.fromRGB(10, 6, 22),
		backMaterial = Enum.Material.Slate,
		ceilingColor = Color3.fromRGB(20, 14, 36),
		ceilingMaterial = Enum.Material.Slate,
		frameColor = Color3.fromRGB(40, 30, 70),
		frameMaterial = Enum.Material.Marble,
	})

	local solids = b:child("Solids")
	local deco = b:child("Decor")

	-- Starfield on the back wall.
	for _ = 1, 140 do
		local s = rng:NextNumber(0.15, 0.5)
		deco:part({ name = "Star", shape = Enum.PartType.Ball, size = Vector3.one * s, at = Vector3.new(rng:NextNumber(-halfW, halfW), rng:NextNumber(1, H), -10.8), color = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(190, 160, 255), rng:NextNumber()), material = Enum.Material.Neon, shadow = false })
	end
	-- Planets.
	local planets = {
		{ x = -38, y = 46, r = 12, color = Color3.fromRGB(255, 140, 90) },
		{ x = 40, y = 52, r = 7, color = Color3.fromRGB(120, 200, 255) },
		{ x = 18, y = 22, r = 4, color = Color3.fromRGB(200, 255, 160) },
	}
	for _, p in planets do
		local planet = deco:part({ name = "Planet", shape = Enum.PartType.Ball, size = Vector3.one * p.r * 2, at = Vector3.new(p.x, p.y, -10 - p.r), color = p.color, material = Enum.Material.Sand, shadow = false })
		deco:light(planet, "PointLight", { Color = p.color, Brightness = 0.6, Range = p.r * 2 })
	end
	deco:part({ name = "Ring", shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 34, 34), at = Vector3.new(-38, 46, -22), rot = CFrame.Angles(math.rad(70), 0, math.rad(20)), color = Color3.fromRGB(255, 210, 160), material = Enum.Material.Neon, transparency = 0.6, shadow = false })

	-- Telescope.
	deco:part({ name = "TelescopeBase", size = Vector3.new(6, 6, 6), at = Vector3.new(halfW - 10, 3, -6), color = Color3.fromRGB(70, 60, 100), material = Enum.Material.Marble })
	deco:part({ name = "TelescopeTube", shape = Enum.PartType.Cylinder, size = Vector3.new(16, 3, 3), at = Vector3.new(halfW - 14, 10, -6), rot = CFrame.Angles(0, 0, math.rad(35)), color = Color3.fromRGB(200, 160, 80), material = Enum.Material.Metal })

	-- Floating platforms (solid) with glowing undersides.
	local platforms = {
		{ x = -30, y = 18, w = 16 },
		{ x = 0, y = 30, w = 14 },
		{ x = 30, y = 18, w = 16 },
		{ x = -14, y = 46, w = 10 },
		{ x = 18, y = 50, w = 10 },
	}
	for _, p in platforms do
		solids:solid({ name = "FloatPlatform", size = Vector3.new(p.w, 1.6, 8), at = Vector3.new(p.x, p.y, -0.5), color = Color3.fromRGB(80, 66, 120), material = Enum.Material.Marble })
		local glow = deco:part({ name = "PlatformGlow", size = Vector3.new(p.w - 1, 0.2, 7), at = Vector3.new(p.x, p.y - 0.9, -0.5), color = Color3.fromRGB(170, 110, 255), material = Enum.Material.Neon, shadow = false })
		deco:light(glow, "SurfaceLight", { Face = Enum.NormalId.Bottom, Color = Color3.fromRGB(170, 110, 255), Brightness = 1.5, Range = 14, Angle = 90 })
	end

	-- Floor runes.
	for i = -5, 5 do
		deco:part({ name = "FloorRune", size = Vector3.new(2.4, 0.1, 2.4), at = Vector3.new(i * 9, 0.06, -3), rot = CFrame.Angles(0, math.rad(45), 0), color = Color3.fromRGB(150, 100, 255), material = Enum.Material.Neon, transparency = 0.4, shadow = false })
	end

	-- Space dust.
	local dustHost = deco:part({ name = "Dust", size = Vector3.new(W, H, 4), at = Vector3.new(0, H / 2, -4), transparency = 1, shadow = false })
	deco:emitter(dustHost, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 10,
		Lifetime = NumberRange.new(6, 10),
		Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Size = b.seq(0, 0, 0.5, 0.25, 1, 0),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(200, 170, 255)),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local fill = deco:part({ name = "Fill", size = Vector3.one, at = Vector3.new(0, H - 6, 10), transparency = 1, shadow = false })
	deco:light(fill, "PointLight", { Color = Color3.fromRGB(190, 160, 255), Brightness = 1.2, Range = 70, Shadows = true })

	return {
		cauldron = Vector3.new(-42, 0, -5.5),
		rack = Vector3.new(halfW - 26, 0, -8.8),
		spawn = Vector3.new(0, 0, 0),
	}
end
