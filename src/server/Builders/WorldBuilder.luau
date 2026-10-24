-- Builds the whole map at server start, following the concept's world map sheet:
-- a floating scrapyard island; a compact hub (spawn, upgrade bench, rebirth pad, shop,
-- daily/workshop, garage); and three yards (Starter Yard -> Appliance Row -> Crusher Yard)
-- of six lanes each, joined by a corridor with two gates.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Theme = require(Shared.Theme)
local MechBuilder = require(Shared.MechBuilder)

local WorldBuilder = {}

local rng = Random.new(1337)

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local C = {
	Grass = hex("#6DBE45"),
	Dirt = hex("#8A6A4A"),
	Rock = hex("#6E6A66"),
	RockDark = hex("#4E4A47"),
	Concrete = hex("#C8CDD3"),
	ConcreteDark = hex("#9AA1AA"),
	Road = hex("#3B4048"),
	Steel = hex("#7D8794"),
	SteelDark = hex("#454C57"),
	Wall = hex("#5F6B7A"),
	WallAlt = hex("#4F5A68"),
	Hazard = Theme.Hazard,
	Ink = Theme.Ink,
	Wood = hex("#A0703C"),
	HubFloor = hex("#E9EEF4"),
	HubTrim = hex("#2F7BEA"),
}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function invisibleWall(parent: Instance, size: Vector3, cframe: CFrame)
	local p = block(parent, "Boundary", size, cframe, C.Ink)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Text helpers ------------------------------------------------------------------

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.Font or Theme.Font.Display
	t.TextColor3 = props.Color or Theme.White
	t.TextScaled = true
	t.Text = props.Text or ""
	t.Size = props.Size or UDim2.fromScale(1, 1)
	t.Position = props.Position or UDim2.new()
	t.AnchorPoint = props.AnchorPoint or Vector2.zero
	t.Name = props.Name or "Text"
	t.RichText = props.RichText or false
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Ink
	stroke.Thickness = props.Stroke or 3
	stroke.Parent = t
	t.Parent = parent
	return t
end

-- Floating label in the style of simulator pads: yellow title, white subtitle, info line.
local function padBillboard(
	adornee: BasePart,
	title: string,
	subtitle: string,
	info: string,
	titleColor: Color3?,
	height: number?
)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(300, 120)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height or 6, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = adornee
	text(gui, {
		Name = "Title",
		Text = title,
		Size = UDim2.fromScale(1, 0.42),
		Color = titleColor or hex("#FFE14D"),
		Stroke = 3.5,
	})
	text(gui, {
		Name = "Subtitle",
		Text = subtitle,
		Size = UDim2.fromScale(1, 0.26),
		Position = UDim2.fromScale(0, 0.42),
		Font = Theme.Font.Body,
		Stroke = 2.5,
	})
	text(gui, {
		Name = "Live",
		Text = info,
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.68),
		Color = Theme.Good,
		Stroke = 2.5,
	})
	gui.Parent = adornee
	return gui
end

local function surfaceSign(part: BasePart, face: Enum.NormalId, build: (SurfaceGui) -> ())
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	build(gui)
	gui.Parent = part
	return gui
end

-- Lighting -----------------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(96, 98, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 152, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(205, 225, 255)
	atmosphere.Decay = Color3.fromRGB(120, 140, 175)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 0.92
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
end

-- Island ---------------------------------------------------------------------------

local X0, X1 = -24, Layout.TotalWidth + 24
local Z0, Z1 = -Layout.LaneDepth - 22, Layout.HubZ1 + 16

local function buildIsland(world: Instance)
	local island = folder(world, "Island")
	local w, d = X1 - X0, Z1 - Z0
	local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
	block(island, "Ground", Vector3.new(w, 6, d), CFrame.new(cx, -3, cz), C.Grass, Enum.Material.Grass)
	block(island, "Soil", Vector3.new(w - 4, 10, d - 4), CFrame.new(cx, -11, cz), C.Dirt, Enum.Material.Ground)
	-- Cliff skirt: chunky rock blocks around the rim stepping down into the void.
	local function rimRock(x: number, z: number)
		local s = rng:NextNumber(8, 16)
		local h = rng:NextNumber(14, 34)
		block(
			island,
			"Cliff",
			Vector3.new(s, h, s),
			CFrame.new(x, -4 - h / 2 + rng:NextNumber(0, 4), z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			if rng:NextNumber() > 0.5 then C.Rock else C.RockDark,
			Enum.Material.Slate
		)
	end
	for x = X0, X1, 12 do
		rimRock(x, Z0 + rng:NextNumber(-2, 3))
		rimRock(x, Z1 + rng:NextNumber(-3, 2))
	end
	for z = Z0, Z1, 12 do
		rimRock(X0 + rng:NextNumber(-2, 3), z)
		rimRock(X1 + rng:NextNumber(-3, 2), z)
	end
	-- Underside: tapering rock mass so the island reads as floating.
	for i = 1, 4 do
		local inset = i * 26
		block(
			island,
			"Underside",
			Vector3.new(math.max(w - inset * 2, 40), 14, math.max(d - inset * 1.4, 30)),
			CFrame.new(cx + rng:NextNumber(-10, 10), -16 - i * 12, cz),
			if i % 2 == 0 then C.Rock else C.RockDark,
			Enum.Material.Slate
		)
	end
	-- Small floating rocks around the island.
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.62, 0.8)
		local x = cx + math.cos(a) * w * r
		local z = cz + math.sin(a) * d * r
		local s = rng:NextNumber(4, 12)
		local rock = block(
			island,
			"FloatingRock",
			Vector3.new(s, s * 0.8, s),
			CFrame.new(x, rng:NextNumber(-30, 10), z) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0),
			C.Rock,
			Enum.Material.Slate
		)
		block(
			island,
			"RockGrass",
			Vector3.new(s * 0.9, 0.8, s * 0.9),
			rock.CFrame * CFrame.new(0, s * 0.4 + 0.3, 0),
			C.Grass,
			Enum.Material.Grass
		)
	end
	-- Boundary: keep players on the island.
	invisibleWall(island, Vector3.new(w, 60, 2), CFrame.new(cx, 30, Z0 + 1))
	invisibleWall(island, Vector3.new(w, 60, 2), CFrame.new(cx, 30, Z1 - 1))
	invisibleWall(island, Vector3.new(2, 60, d), CFrame.new(X0 + 1, 30, cz))
	invisibleWall(island, Vector3.new(2, 60, d), CFrame.new(X1 - 1, 30, cz))
end

-- Hub -------------------------------------------------------------------------------

local PAD_STYLE = {
	Upgrade = { Color = hex("#FF8A1F"), Title = "UPGRADE BENCH", Sub = "Buy Power. Grow your mech!", Info = "" },
	Rebirth = {
		Color = hex("#B57BFF"),
		Title = "REBIRTH PAD",
		Sub = "Start small. Earn more forever.",
		Info = "+25% Scrap each time",
	},
	Shop = { Color = hex("#5DEB5A"), Title = "SHOP", Sub = "Boosts, passes & paint", Info = "" },
	Daily = { Color = hex("#FFE14D"), Title = "DAILY & WORKSHOP", Sub = "Free Scrap every day", Info = "" },
	Garage = { Color = hex("#4FB8FF"), Title = "GARAGE", Sub = "Tools & finishes", Info = "Hammer · Saw · Drill" },
}

local function buildPad(parent: Instance, id: string, position: Vector3): BasePart
	local style = PAD_STYLE[id]
	local ring = block(
		parent,
		id .. "Ring",
		Vector3.new(0.5, 13, 13),
		CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		C.Ink,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	ring.CanCollide = false
	local pad = block(
		parent,
		id,
		Vector3.new(0.6, 11.5, 11.5),
		CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		style.Color,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	pad.CanCollide = false
	pad.CanTouch = false
	pad:SetAttribute("PadId", id)
	local light = Instance.new("PointLight")
	light.Color = style.Color
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = pad
	padBillboard(pad, style.Title, style.Sub, style.Info, nil, 7)
	return pad
end

local function buildHubProps(hub: Instance)
	-- Upgrade bench: a workbench with a vice and tools.
	local bench = folder(hub, "UpgradeBench")
	local bx, bz = 28, 28
	block(bench, "Top", Vector3.new(12, 1, 4), CFrame.new(bx, 3.5, bz), C.Wood, Enum.Material.WoodPlanks)
	for _, x in { -5.5, 5.5 } do
		block(bench, "Leg", Vector3.new(0.8, 3, 3.4), CFrame.new(bx + x, 1.5, bz), C.SteelDark, Enum.Material.Metal)
	end
	block(bench, "Vice", Vector3.new(1.4, 1.4, 1.6), CFrame.new(bx - 3.5, 4.7, bz), hex("#2F7BEA"), Enum.Material.Metal)
	block(
		bench,
		"Wrench",
		Vector3.new(2.6, 0.2, 0.5),
		CFrame.new(bx + 1, 4.1, bz - 0.6) * CFrame.Angles(0, 0.4, 0),
		C.Steel,
		Enum.Material.Metal
	)
	block(bench, "Board", Vector3.new(12, 6, 0.4), CFrame.new(bx, 7, bz + 2.2), C.SteelDark, Enum.Material.DiamondPlate)
	MechBuilder.buildStatue(
		0,
		"Hammer",
		nil,
		0.9,
		CFrame.new(bx + 3.5, 3.5 + 0.9 * MechBuilder.RootHeight + 0.5, bz) * CFrame.Angles(0, math.rad(180), 0)
	).Parent =
		bench

	-- Rebirth pad: glowing pillars around the pad.
	local rebirth = folder(hub, "RebirthPillars")
	local rp = Layout.Pads[2].Position
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pos = rp + Vector3.new(math.cos(a) * 8.5, 0, math.sin(a) * 8.5)
		deco(
			block(
				rebirth,
				"Pillar",
				Vector3.new(1.2, 5, 1.2),
				CFrame.new(pos + Vector3.new(0, 2.5, 0)),
				hex("#2B1B4A"),
				Enum.Material.Metal
			)
		)
		deco(
			block(
				rebirth,
				"Crystal",
				Vector3.new(0.9, 1.6, 0.9),
				CFrame.new(pos + Vector3.new(0, 5.8, 0)) * CFrame.Angles(0, a, math.rad(45)),
				hex("#C99BFF"),
				Enum.Material.Neon
			)
		)
	end

	-- Shop stall with a striped awning.
	local shop = folder(hub, "ShopStall")
	local sp = Layout.Pads[3].Position + Vector3.new(-12, 0, 0)
	block(shop, "Counter", Vector3.new(4, 3.4, 12), CFrame.new(sp + Vector3.new(0, 1.7, 0)), hex("#2DBE2A"))
	block(shop, "CounterTop", Vector3.new(4.6, 0.5, 12.6), CFrame.new(sp + Vector3.new(0, 3.65, 0)), C.HubFloor)
	for i = 0, 5 do
		local stripe = block(
			shop,
			"Awning",
			Vector3.new(6, 0.4, 2.1),
			CFrame.new(sp + Vector3.new(0.5, 9, -5.25 + i * 2.1)) * CFrame.Angles(0, 0, math.rad(-15)),
			if i % 2 == 0 then hex("#2DBE2A") else C.HubFloor
		)
		deco(stripe)
	end
	for _, z in { -5.6, 5.6 } do
		block(
			shop,
			"Post",
			Vector3.new(0.6, 9, 0.6),
			CFrame.new(sp + Vector3.new(-1.8, 4.5, z)),
			C.SteelDark,
			Enum.Material.Metal
		)
	end

	-- Workshop shed beside the daily pad.
	local shed = folder(hub, "Workshop")
	local wp = Layout.Pads[4].Position + Vector3.new(14, 0, 0)
	block(
		shed,
		"Shed",
		Vector3.new(10, 10, 14),
		CFrame.new(wp + Vector3.new(0, 5, 0)),
		hex("#E07A3A"),
		Enum.Material.Metal
	)
	block(
		shed,
		"Roof",
		Vector3.new(11, 1, 15),
		CFrame.new(wp + Vector3.new(0, 10.5, 0)),
		C.SteelDark,
		Enum.Material.CorrodedMetal
	)
	local door = block(
		shed,
		"Door",
		Vector3.new(0.4, 7, 9),
		CFrame.new(wp + Vector3.new(-5.1, 3.5, 0)),
		C.Steel,
		Enum.Material.DiamondPlate
	)
	surfaceSign(door, Enum.NormalId.Left, function(gui)
		text(gui, {
			Text = "WORKSHOP",
			Size = UDim2.fromScale(0.9, 0.22),
			Position = UDim2.fromScale(0.05, 0.05),
			Color = hex("#FFE14D"),
		})
		text(gui, {
			Text = "40 Scrap / hour · even offline",
			Size = UDim2.fromScale(0.9, 0.12),
			Position = UDim2.fromScale(0.05, 0.28),
			Font = Theme.Font.Body,
			Stroke = 2,
		})
	end)

	-- Garage paint booth.
	local garage = folder(hub, "PaintBooth")
	local gp = Layout.Pads[5].Position + Vector3.new(0, 0, 9)
	block(garage, "BoothBack", Vector3.new(16, 9, 1), CFrame.new(gp + Vector3.new(0, 4.5, 0)), C.HubTrim)
	local swatches = { hex("#FF8A1F"), hex("#7BEA2E"), hex("#FFC61A"), hex("#D7DEE8"), hex("#2A2A30"), hex("#45D4FF") }
	for i, color in swatches do
		deco(
			block(
				garage,
				"Swatch",
				Vector3.new(1.8, 1.8, 0.3),
				CFrame.new(gp + Vector3.new(-5.5 + (i - 1) * 2.2, 6.5, -0.6)),
				color
			)
		)
	end
end

local function buildHub(world: Instance): { [string]: BasePart }
	local hub = folder(world, "Hub")
	local x0, x1 = 0, Layout.AreaWidth
	local z0, z1 = Layout.HubZ0, Layout.HubZ1
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	block(hub, "Floor", Vector3.new(x1 - x0, 1, z1 - z0), CFrame.new(cx, -0.45, cz), C.HubFloor, Enum.Material.Plastic).TopSurface =
		Enum.SurfaceType.Studs
	-- Blue studded trim around the hub, like a toy baseplate.
	for _, z in { z0 + 1, z1 - 1 } do
		block(hub, "Trim", Vector3.new(x1 - x0, 1.2, 2), CFrame.new(cx, -0.3, z), C.HubTrim).TopSurface =
			Enum.SurfaceType.Studs
	end
	for _, x in { x0 + 1, x1 - 1 } do
		block(hub, "Trim", Vector3.new(2, 1.2, z1 - z0), CFrame.new(x, -0.3, cz), C.HubTrim).TopSurface =
			Enum.SurfaceType.Studs
	end
	-- Railings on the hub's outer edges (west and south); east blocks the shortcut past Gate 1.
	block(hub, "RailSouth", Vector3.new(x1 - x0, 3, 1), CFrame.new(cx, 1.5, z1 + 0.5), C.HubTrim)
	block(hub, "RailWest", Vector3.new(1, 3, z1 - z0), CFrame.new(x0 - 0.5, 1.5, cz), C.HubTrim)
	block(hub, "RailEast", Vector3.new(1, 3, z1 - z0), CFrame.new(x1 + 0.5, 1.5, cz), C.HubTrim)
	invisibleWall(hub, Vector3.new(4, 40, z1 - z0 + 8), CFrame.new(x1 + 2, 20, cz + 4))

	-- Flat invisible spawn (players are moved to their own lane right after spawning)
	-- with a glowing ring on top for looks.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(Layout.SpawnPosition + Vector3.new(0, 0.2, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	deco(
		block(
			hub,
			"SpawnRing",
			Vector3.new(0.5, 11, 11),
			CFrame.new(Layout.SpawnPosition + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Theme.ScreenBlue,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
	)

	local pads = folder(hub, "Pads")
	local padParts = {}
	for _, pad in Layout.Pads do
		padParts[pad.Id] = buildPad(pads, pad.Id, pad.Position)
	end
	buildHubProps(hub)

	-- Big title wall facing the yard (like the sign walls in popular simulators).
	local wall = block(
		hub,
		"TitleWall",
		Vector3.new(60, 22, 3),
		CFrame.new(cx, 11, z1 - 4),
		hex("#FFFFFF"),
		Enum.Material.Plastic
	)
	wall.TopSurface = Enum.SurfaceType.Studs
	local frame = block(hub, "TitleFrame", Vector3.new(64, 26, 2), CFrame.new(cx, 12, z1 - 3), C.HubTrim)
	frame.TopSurface = Enum.SurfaceType.Studs
	surfaceSign(wall, Enum.NormalId.Front, function(gui)
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(0.92, 0.84)
		bg.Position = UDim2.fromScale(0.04, 0.08)
		bg.BackgroundColor3 = Theme.Swatch.Navy.Bottom
		bg.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 40)
		corner.Parent = bg
		text(bg, {
			Text = "PICK YOUR MECH!",
			Size = UDim2.fromScale(0.9, 0.34),
			Position = UDim2.fromScale(0.05, 0.06),
			Color = hex("#FFB24A"),
			Stroke = 8,
		})
		text(bg, {
			Text = Config.Tagline,
			Size = UDim2.fromScale(0.86, 0.15),
			Position = UDim2.fromScale(0.07, 0.42),
			Font = Theme.Font.Body,
			Stroke = 5,
		})
		text(bg, {
			Text = "👍 LIKE THE GAME FOR NEW YARDS!",
			Size = UDim2.fromScale(0.8, 0.13),
			Position = UDim2.fromScale(0.1, 0.64),
			Color = Theme.Good,
			Stroke = 5,
		})
		text(bg, {
			Text = "⭐ FAVORITE TO KEEP YOUR MECH CLOSE",
			Size = UDim2.fromScale(0.8, 0.11),
			Position = UDim2.fromScale(0.1, 0.8),
			Color = hex("#FFE14D"),
			Stroke = 4,
		})
	end)
	frame.Parent = hub

	-- Next-form preview: a Crusher statue in the hub shows the first big goal.
	local statue = MechBuilder.buildStatue(
		4,
		"Hammer",
		nil,
		2.2,
		CFrame.new(10, 2.2 * MechBuilder.RootHeight + 1.2, z1 - 36) * CFrame.Angles(0, math.rad(200), 0),
		120
	)
	statue.Name = "CrusherPreview"
	statue.Parent = hub
	block(
		hub,
		"Pedestal",
		Vector3.new(9, 1.2, 9),
		CFrame.new(10, 0.6, z1 - 36),
		C.SteelDark,
		Enum.Material.DiamondPlate
	)
	local tag = deco(block(hub, "PreviewTag", Vector3.new(1, 1, 1), CFrame.new(10, 16, z1 - 36), C.Ink))
	tag.Transparency = 1
	padBillboard(tag, "CRUSHER FORM", "Reach Power 25", "4 upgrades away!", hex("#FFB24A"), 0)
	return padParts
end

-- Corridor, yards, lanes ------------------------------------------------------------

local function buildCorridor(world: Instance)
	local corridor = folder(world, "Corridor")
	local w = Layout.TotalWidth
	block(
		corridor,
		"Road",
		Vector3.new(w, 1, Layout.CorridorWidth),
		CFrame.new(w / 2, -0.4, Layout.CorridorZ),
		C.Road,
		Enum.Material.Asphalt
	)
	for x = 4, w - 4, 10 do
		deco(
			block(
				corridor,
				"Dash",
				Vector3.new(5, 0.12, 0.6),
				CFrame.new(x, 0.12, Layout.CorridorZ),
				C.Hazard,
				Enum.Material.SmoothPlastic
			)
		)
	end
	-- Fence south of the corridor east of the hub (the Mega Mech plaza stays view-only).
	block(
		corridor,
		"SouthRail",
		Vector3.new(w - Layout.AreaWidth, 3, 1),
		CFrame.new((w + Layout.AreaWidth) / 2, 1.5, Layout.CorridorWidth + 0.5),
		C.Hazard
	)
	invisibleWall(
		corridor,
		Vector3.new(w - Layout.AreaWidth, 40, 2),
		CFrame.new((w + Layout.AreaWidth) / 2, 20, Layout.CorridorWidth + 1)
	)
end

local function laneSign(parent: Instance, area: number, lane: number): TextLabel
	local x = Layout.laneX(area, lane)
	local color = Theme.LaneColors[lane]
	local half = Layout.LaneWidth / 2 - 0.6
	for side = -1, 1, 2 do
		block(
			parent,
			"SignPost",
			Vector3.new(0.8, 15, 0.8),
			CFrame.new(x + side * half, 7.5, -1),
			C.SteelDark,
			Enum.Material.Metal
		)
	end
	-- High enough that a zoomed-out camera behind the mech looks under it.
	local beam = block(parent, "Sign", Vector3.new(Layout.LaneWidth - 1, 2.6, 0.6), CFrame.new(x, 15.5, -1), C.Ink)
	beam.Name = string.format("Lane%d_Area%d", lane, area)
	deco(
		block(
			parent,
			"SignGlow",
			Vector3.new(Layout.LaneWidth - 1, 0.3, 0.7),
			CFrame.new(x, 14.1, -1),
			color,
			Enum.Material.Neon
		)
	)
	local nameLabel
	surfaceSign(beam, Enum.NormalId.Back, function(gui)
		text(gui, {
			Name = "Lane",
			Text = "LANE " .. lane,
			Size = UDim2.fromScale(0.3, 0.8),
			Position = UDim2.fromScale(0.02, 0.1),
			Color = color,
			Stroke = 4,
		})
		nameLabel = text(gui, {
			Name = "Owner",
			Text = "OPEN LANE",
			Size = UDim2.fromScale(0.64, 0.7),
			Position = UDim2.fromScale(0.34, 0.15),
			Stroke = 4,
		})
	end)
	surfaceSign(beam, Enum.NormalId.Front, function(gui)
		text(gui, {
			Name = "Lane",
			Text = "LANE " .. lane,
			Size = UDim2.fromScale(0.96, 0.8),
			Position = UDim2.fromScale(0.02, 0.1),
			Color = color,
			Stroke = 4,
		})
	end)
	return nameLabel
end

local function buildArea(world: Instance, area: number, laneLabels: { [number]: { TextLabel } })
	local def = Config.Areas[area]
	local f = folder(world, "Area" .. area)
	local x0, x1 = Layout.areaX0(area), Layout.areaX1(area)
	local depth = Layout.LaneDepth
	local cx = (x0 + x1) / 2
	local floorColor = ({ hex("#B9A27E"), hex("#A7B0B9"), hex("#8C7F72") })[area]
	block(
		f,
		"Floor",
		Vector3.new(x1 - x0, 1, depth),
		CFrame.new(cx, -0.45, -depth / 2),
		floorColor,
		Enum.Material.Ground
	)

	for lane = 1, Layout.Lanes do
		local lx = Layout.laneX(area, lane)
		local color = Theme.LaneColors[lane]
		local shade = if lane % 2 == 0 then C.Concrete else C.ConcreteDark
		block(
			f,
			"LaneFloor",
			Vector3.new(Layout.LaneWidth - 2, 0.2, depth - 6),
			CFrame.new(lx, 0.02, -depth / 2 - 2),
			shade,
			Enum.Material.Concrete
		)
		for side = -1, 1, 2 do
			deco(
				block(
					f,
					"LaneEdge",
					Vector3.new(0.35, 0.22, depth - 6),
					CFrame.new(lx + side * (Layout.LaneWidth / 2 - 1.2), 0.05, -depth / 2 - 2),
					color,
					Enum.Material.Neon
				)
			)
		end
		-- Lane number painted near the mouth.
		local marker = block(f, "LaneNumber", Vector3.new(8, 0.1, 8), CFrame.new(lx, 0.13, -5), shade)
		deco(marker)
		marker.Transparency = 1
		surfaceSign(marker, Enum.NormalId.Top, function(gui)
			text(gui, { Text = tostring(lane), Color = color, Stroke = 5 })
		end)
		laneLabels[lane] = laneLabels[lane] or {}
		table.insert(laneLabels[lane], laneSign(f, area, lane))
	end

	-- Dividers between lanes: low rails so neighbours stay visible.
	for k = 1, Layout.Lanes - 1 do
		local x = x0 + k * Layout.LaneWidth
		for z = -depth + 2, -4, 13 do
			block(f, "FencePost", Vector3.new(0.5, 4, 0.5), CFrame.new(x, 2, z), C.Steel, Enum.Material.Metal)
		end
		for _, y in { 1.6, 3.6 } do
			block(
				f,
				"FenceRail",
				Vector3.new(0.3, 0.3, depth - 6),
				CFrame.new(x, y, -depth / 2 - 1),
				C.Steel,
				Enum.Material.Metal
			)
		end
		invisibleWall(f, Vector3.new(0.6, 30, depth - 6), CFrame.new(x, 15, -depth / 2 - 1))
	end

	-- Perimeter: corrugated north wall + outer side walls.
	local h = Layout.WallHeight
	local panel = 0
	for x = x0, x1 - 6, 6 do
		panel += 1
		block(
			f,
			"WallPanel",
			Vector3.new(6, h, 1.5),
			CFrame.new(x + 3, h / 2, -depth - 0.75),
			if panel % 2 == 0 then C.Wall else C.WallAlt,
			Enum.Material.CorrodedMetal
		)
	end
	deco(block(f, "WallStripe", Vector3.new(x1 - x0, 1, 1.7), CFrame.new(cx, h - 0.5, -depth - 0.75), C.Hazard))
	if area == 1 then
		block(
			f,
			"WestWall",
			Vector3.new(1.5, h, depth + 2),
			CFrame.new(x0 - 0.75, h / 2, -depth / 2 + 1),
			C.Wall,
			Enum.Material.CorrodedMetal
		)
	end
	if area == 3 then
		block(
			f,
			"EastWall",
			Vector3.new(1.5, h, depth + Layout.CorridorWidth + 2),
			CFrame.new(x1 + 0.75, h / 2, (-depth + Layout.CorridorWidth) / 2),
			C.Wall,
			Enum.Material.CorrodedMetal
		)
	end

	-- Area title floating over the corridor.
	local anchor = deco(block(f, "TitleAnchor", Vector3.new(1, 1, 1), CFrame.new(x0 + 26, 18, -2), C.Ink))
	anchor.Transparency = 1
	local gui = padBillboard(
		anchor,
		string.upper(def.Name),
		def.Blurb,
		string.format("%s HP · %d Scrap each", tostring(def.HP), def.Scrap),
		hex("#FFB24A"),
		0
	)
	gui.Size = UDim2.fromOffset(420, 160)
	gui.MaxDistance = 400

	-- Floodlights on the north wall.
	for _, x in { x0 + 20, cx, x1 - 20 } do
		local post = block(
			f,
			"LightPost",
			Vector3.new(1, 22, 1),
			CFrame.new(x, 11, -depth - 3),
			C.SteelDark,
			Enum.Material.Metal
		)
		local lamp = block(
			f,
			"Lamp",
			Vector3.new(4, 1.4, 2),
			CFrame.new(x, 22.5, -depth - 2) * CFrame.Angles(math.rad(-25), 0, 0),
			hex("#FFF4C9"),
			Enum.Material.Neon
		)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 40
		spot.Brightness = 1.2
		spot.Color = hex("#FFF4C9")
		spot.Parent = lamp
		post.CastShadow = false
	end
end

-- Gates ----------------------------------------------------------------------------

local function buildGate(world: Instance, gate: number): BasePart
	local area = gate + 1
	local def = Config.Areas[area]
	local f = folder(world, "Gate" .. gate)
	local gx = Layout.gateX(gate)
	local h = Layout.WallHeight
	local zMid = Layout.CorridorZ
	-- Wall between the two areas, north of the corridor.
	block(
		f,
		"DividerWall",
		Vector3.new(Layout.AreaGap, h, Layout.LaneDepth + 1.5),
		CFrame.new(gx, h / 2, -Layout.LaneDepth / 2 - 0.75),
		C.WallAlt,
		Enum.Material.CorrodedMetal
	)
	deco(
		block(
			f,
			"DividerStripe",
			Vector3.new(Layout.AreaGap + 0.2, 1, Layout.LaneDepth + 1.7),
			CFrame.new(gx, h - 0.5, -Layout.LaneDepth / 2 - 0.75),
			C.Hazard
		)
	)
	-- Gate frame over the corridor.
	for _, z in { -1, Layout.CorridorWidth + 1 } do
		block(f, "GatePost", Vector3.new(4, h + 4, 2), CFrame.new(gx, (h + 4) / 2, z), C.SteelDark, Enum.Material.Metal)
		for i = 0, 4 do
			deco(
				block(
					f,
					"PostStripe",
					Vector3.new(4.1, 1.2, 2.1),
					CFrame.new(gx, 2 + i * 3.4, z) * CFrame.Angles(math.rad(25), 0, 0),
					C.Hazard
				)
			)
		end
	end
	local beam = block(
		f,
		"GateBeam",
		Vector3.new(4, 4, Layout.CorridorWidth + 4),
		CFrame.new(gx, h + 2, zMid),
		C.Ink,
		Enum.Material.Metal
	)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		surfaceSign(beam, face, function(gui)
			text(gui, {
				Text = string.upper(def.Name),
				Size = UDim2.fromScale(0.9, 0.5),
				Position = UDim2.fromScale(0.05, 0.05),
				Color = hex("#FFB24A"),
				Stroke = 4,
			})
			text(gui, {
				Text = string.format("⚡ Power %d  +  %s Scrap", def.GatePower, tostring(def.GateScrap)),
				Size = UDim2.fromScale(0.9, 0.34),
				Position = UDim2.fromScale(0.05, 0.58),
				Font = Theme.Font.Body,
				Stroke = 3,
			})
		end)
	end
	-- The barrier itself. Clients turn it off locally once they own the gate.
	local barrier = block(
		f,
		"Barrier",
		Vector3.new(1.2, h, Layout.CorridorWidth),
		CFrame.new(gx, h / 2, zMid),
		hex("#FF4D4D"),
		Enum.Material.ForceField
	)
	barrier.Transparency = 0.2
	barrier.CanTouch = false
	barrier:SetAttribute("GateArea", area)
	padBillboard(
		barrier,
		"🔒 " .. string.upper(def.Name),
		string.format("Needs ⚡%d Power + %s Scrap", def.GatePower, tostring(def.GateScrap)),
		"Walk up to unlock",
		hex("#FF6B6B"),
		2
	)
	return barrier
end

-- Showcase plaza: the Mega Mech statue beyond Gate 1 shows the long-term goal.
local function buildShowcase(world: Instance)
	local f = folder(world, "Showcase")
	local cx, cz = Layout.areaX0(2) + 66, Layout.CorridorWidth + 26
	block(f, "Plaza", Vector3.new(110, 1, 40), CFrame.new(cx, -0.4, cz), C.ConcreteDark, Enum.Material.Concrete)
	block(f, "Pedestal", Vector3.new(16, 2, 16), CFrame.new(cx, 1, cz + 4), C.SteelDark, Enum.Material.DiamondPlate)
	deco(
		block(
			f,
			"PedestalGlow",
			Vector3.new(16.4, 0.4, 16.4),
			CFrame.new(cx, 2.1, cz + 4),
			hex("#FF7A00"),
			Enum.Material.Neon
		)
	)
	local scale = 3.4
	local statue = MechBuilder.buildStatue(
		9,
		"Hammer",
		nil,
		scale,
		CFrame.new(cx, 2 + scale * MechBuilder.RootHeight, cz + 4) * CFrame.Angles(0, math.rad(160), 0),
		150
	)
	statue.Name = "MegaMechStatue"
	statue.Parent = f
	local tag = deco(block(f, "Tag", Vector3.new(1, 1, 1), CFrame.new(cx, 2 + scale * 6.5, cz + 4), C.Ink))
	tag.Transparency = 1
	local gui = padBillboard(tag, "MEGA MECH", "Final form at Power 1,000", "Keep upgrading!", hex("#FFB24A"), 0)
	gui.MaxDistance = 400
	gui.Size = UDim2.fromOffset(360, 140)
	-- Decorative crane behind the Crusher Yard.
	local crane = folder(world, "Crane")
	local kx, kz = Layout.areaX0(3) + 100, -Layout.LaneDepth - 12
	for i = 0, 9 do
		block(
			crane,
			"Mast",
			Vector3.new(3, 4, 3),
			CFrame.new(kx, 2 + i * 4, kz),
			if i % 2 == 0 then C.Hazard else C.Ink,
			Enum.Material.Metal
		)
	end
	block(crane, "Jib", Vector3.new(44, 2.4, 2.4), CFrame.new(kx - 16, 41, kz), C.Hazard, Enum.Material.Metal)
	block(crane, "Cab", Vector3.new(4, 3.4, 4), CFrame.new(kx, 39, kz + 3), C.SteelDark, Enum.Material.Metal)
	block(crane, "Cable", Vector3.new(0.2, 14, 0.2), CFrame.new(kx - 32, 33, kz), C.Ink)
	block(
		crane,
		"Magnet",
		Vector3.new(1.6, 4.4, 4.4),
		CFrame.new(kx - 32, 25.4, kz) * CFrame.Angles(0, 0, math.rad(90)),
		C.SteelDark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end

-- Static junk heaps outside the lanes for atmosphere (not smashable).
local function buildDecorHeaps(world: Instance)
	local f = folder(world, "DecorHeaps")
	local spots = {
		Vector3.new(-14, 0, -40),
		Vector3.new(-14, 0, -90),
		Vector3.new(Layout.TotalWidth + 14, 0, -30),
		Vector3.new(Layout.TotalWidth + 14, 0, -80),
		Vector3.new(Layout.areaX0(3) + 40, 0, Layout.CorridorWidth + 20),
		Vector3.new(Layout.areaX0(3) + 90, 0, Layout.CorridorWidth + 30),
	}
	local colors = { hex("#9C5B35"), hex("#7A4A2E"), hex("#6E737A"), hex("#8A6A4A") }
	for _, spot in spots do
		for i = 1, 14 do
			local s = rng:NextNumber(1.5, 4)
			local r = (1 - i / 14) * 6
			local a = rng:NextNumber(0, math.pi * 2)
			deco(
				block(
					f,
					"Junk",
					Vector3.new(s, s * 0.6, s * 1.2),
					CFrame.new(spot + Vector3.new(math.cos(a) * r, i * 0.5, math.sin(a) * r))
						* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)),
					colors[(i % #colors) + 1],
					Enum.Material.CorrodedMetal
				)
			)
		end
	end
end

-- Blocky trees on the open grass so the island doesn't feel bare.
local function buildTrees(world: Instance)
	local f = folder(world, "Trees")
	local spots = {}
	for x = Layout.areaX0(2) - 4, Layout.TotalWidth + 14, 19 do
		table.insert(spots, Vector3.new(x + rng:NextNumber(-4, 4), 0, Layout.HubZ1 + rng:NextNumber(-12, 6)))
	end
	for x = Layout.areaX0(3) + 10, Layout.TotalWidth - 10, 24 do
		table.insert(spots, Vector3.new(x + rng:NextNumber(-4, 4), 0, Layout.CorridorWidth + rng:NextNumber(52, 62)))
	end
	for z = -Layout.LaneDepth + 6, Layout.HubZ1, 22 do
		table.insert(spots, Vector3.new(-12 + rng:NextNumber(-3, 3), 0, z))
	end
	local leaves = { hex("#4CAF3A"), hex("#5CC447"), hex("#3E9A33") }
	for _, spot in spots do
		local h = rng:NextNumber(5, 8)
		deco(
			block(
				f,
				"Trunk",
				Vector3.new(1.4, h, 1.4),
				CFrame.new(spot + Vector3.new(0, h / 2, 0)),
				hex("#7A5228"),
				Enum.Material.Wood
			)
		)
		local size = rng:NextNumber(5, 7)
		local color = leaves[rng:NextInteger(1, #leaves)]
		block(
			f,
			"Leaves",
			Vector3.new(size, size * 0.8, size),
			CFrame.new(spot + Vector3.new(0, h + size * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			color,
			Enum.Material.Grass
		)
		block(
			f,
			"LeavesTop",
			Vector3.new(size * 0.6, size * 0.5, size * 0.6),
			CFrame.new(spot + Vector3.new(0, h + size * 0.85, 0)),
			color,
			Enum.Material.Grass
		)
	end
end

export type World = {
	Root: Folder,
	Pads: { [string]: BasePart },
	Barriers: { [number]: BasePart },
	LaneLabels: { [number]: { TextLabel } },
	Targets: Folder,
}

function WorldBuilder.build(): World
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	setupLighting()
	local world = Instance.new("Folder")
	world.Name = "World"
	buildIsland(world)
	local pads = buildHub(world)
	buildCorridor(world)
	local laneLabels = {}
	for area = 1, 3 do
		buildArea(world, area, laneLabels)
	end
	local barriers = {}
	for gate = 1, 2 do
		barriers[gate + 1] = buildGate(world, gate)
	end
	buildShowcase(world)
	buildDecorHeaps(world)
	buildTrees(world)
	local targets = folder(world, "Targets")
	world.Parent = Workspace
	return { Root = world, Pads = pads, Barriers = barriers, LaneLabels = laneLabels, Targets = targets }
end

return WorldBuilder
