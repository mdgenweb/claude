--!nonstrict
-- A tall brick tower with height markers, ledges and updraft fans at the bottom.

local function markerLabel(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(200, 100)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	label.Parent = gui
end

return function(b, info, rng: Random)
	local W, H = info.width, info.height
	local halfW = W / 2

	b:shell({
		width = W,
		height = H,
		floorColor = Color3.fromRGB(120, 110, 100),
		floorMaterial = Enum.Material.Cobblestone,
		wallColor = Color3.fromRGB(150, 110, 90),
		wallMaterial = Enum.Material.Brick,
		backColor = Color3.fromRGB(165, 125, 100),
		backMaterial = Enum.Material.Brick,
		ceilingColor = Color3.fromRGB(90, 70, 60),
		ceilingMaterial = Enum.Material.WoodPlanks,
		frameColor = Color3.fromRGB(70, 50, 40),
		frameMaterial = Enum.Material.Wood,
	})

	local solids = b:child("Solids")
	local deco = b:child("Decor")
	local hazards = b:child("Hazards")

	-- Height markers every 25 studs.
	for y = 25, H - 10, 25 do
		deco:part({ name = "MarkerLine", size = Vector3.new(W, 0.3, 0.2), at = Vector3.new(0, y, -10.8), color = Color3.fromRGB(255, 220, 120), material = Enum.Material.Neon, transparency = 0.4, shadow = false })
		local plate = deco:part({ name = "MarkerPlate", size = Vector3.new(6, 3, 0.4), at = Vector3.new(-halfW + 5, y + 2, -10.6), color = Color3.fromRGB(60, 40, 30), material = Enum.Material.Wood })
		markerLabel(plate, tostring(y))
	end

	-- Windows up the tower.
	local sky = Color3.fromRGB(180, 215, 255)
	for y = 30, H - 20, 45 do
		deco:window(14 * (if (y // 45) % 2 == 0 then 1 else -1), y, 9, 14, Color3.fromRGB(80, 56, 40), sky)
	end

	-- Ledges.
	local ledges = {
		{ x = -halfW + 8, y = 40 },
		{ x = halfW - 8, y = 75 },
		{ x = -halfW + 8, y = 115 },
		{ x = halfW - 8, y = 150 },
		{ x = 0, y = 190 },
	}
	for _, ledge in ledges do
		solids:solid({ name = "Ledge", size = Vector3.new(14, 1.4, 8), at = Vector3.new(ledge.x, ledge.y, -0.5), color = Color3.fromRGB(120, 86, 60), material = Enum.Material.WoodPlanks })
		deco:part({ name = "LedgeBracket", size = Vector3.new(1.2, 3, 6), at = Vector3.new(ledge.x, ledge.y - 2, -3), color = Color3.fromRGB(80, 56, 40), material = Enum.Material.Wood })
	end

	-- Updraft fans in the floor.
	for _, x in { -16, 16 } do
		deco:part({ name = "FanGrate", shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, 10, 10), at = Vector3.new(x, 0.2, -0.5), rot = CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(60, 64, 72), material = Enum.Material.DiamondPlate })
		local blades = deco:part({ name = "FanBlades", size = Vector3.new(9, 0.2, 1.2), at = Vector3.new(x, 0.6, -0.5), color = Color3.fromRGB(200, 205, 215), material = Enum.Material.Metal })
		blades:AddTag("Spinner")
		blades:SetAttribute("SpinSpeed", 12)
		blades:SetAttribute("SpinAxis", "Y")
		local zone = hazards:part({
			name = "FanZone",
			size = Vector3.new(10, 70, 12),
			at = Vector3.new(x, 35, -0.5),
			transparency = 1,
			shadow = false,
			attributes = { Hazard = "Fan", FanAccel = 330 },
		})
		local _ = zone
		local streaks = deco:part({ name = "FanStreaks", size = Vector3.new(9, 0.2, 9), at = Vector3.new(x, 1, -0.5), transparency = 1, shadow = false })
		deco:emitter(streaks, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 16,
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(28, 40),
			Size = b.seq(0, 0.25, 1, 0.1),
			Transparency = b.seq(0, 0.3, 1, 1),
			LightEmission = 0.6,
			Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
			EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end

	for y = 20, H - 10, 40 do
		deco:torch(-halfW + 4, y, -8.5, Color3.fromRGB(255, 170, 90), 26)
		deco:torch(halfW - 4, y + 20, -8.5, Color3.fromRGB(255, 170, 90), 26)
	end
	-- Banner at the top.
	deco:part({ name = "Banner", size = Vector3.new(10, 16, 0.3), at = Vector3.new(0, H - 14, -10.4), color = Color3.fromRGB(150, 40, 60), material = Enum.Material.Fabric })
	local _ = rng

	return {
		cauldron = Vector3.new(-24, 0, -5.5),
		rack = Vector3.new(halfW - 10, 0, -8.8),
		spawn = Vector3.new(0, 0, 0),
	}
end
