--!strict
-- Builds every lobby prop from plain parts (no uploaded meshes or textures), so the same
-- models serve the server-built lobby and client-side ViewportFrame icons.
-- All models have their pivot at the base centre and face local +Z.
local Lobby = require(script.Parent.Parent.Config.Lobby)
local Rng = require(script.Parent.Parent.Util.Rng)

local PropFactory = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

type PartProps = {
	Name: string?,
	Shape: Enum.PartType?,
	Size: Vector3,
	CFrame: CFrame,
	Color: string | Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Reflectance: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Class: string?,
}

function PropFactory.Part(parent: Instance, p: PartProps): BasePart
	local part: BasePart
	if p.Class == "WedgePart" then
		part = Instance.new("WedgePart")
	elseif p.Class == "CornerWedgePart" then
		part = Instance.new("CornerWedgePart")
	else
		local basic = Instance.new("Part")
		basic.Shape = p.Shape or Enum.PartType.Block
		part = basic
	end
	part.Name = p.Name or "Part"
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = if typeof(p.Color) == "Color3" then p.Color :: Color3 else hex(p.Color :: string)
	part.Material = p.Material or Enum.Material.SmoothPlastic
	part.Transparency = p.Transparency or 0
	part.Reflectance = p.Reflectance or 0
	part.Anchored = true
	part.CanCollide = if p.CanCollide == nil then true else p.CanCollide
	part.CastShadow = if p.CastShadow == nil then true else p.CastShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local P = PropFactory.Part

-- Cylinder whose axis points along world/local Y.
local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end
PropFactory.Upright = upright

function PropFactory.Model(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

local ORB_COLORS = { "#FF8A1F", "#5B6CFF", "#6EDB3A", "#FF7BD5", "#FFD23F", "#3BC6B5", "#D7263D", "#9D4DFF", "#7FE9FF", "#E9EBF0" }

local function finish(model: Model, base: BasePart): Model
	model.PrimaryPart = base
	return model
end

---------------------------------------------------------------------------- Gacha machine
function PropFactory.GachaMachine(advanced: boolean?): Model
	local m = PropFactory.Model(if advanced then "AdvancedMachine" else "GachaMachine")
	local body = if advanced then "#6A2BD6" else "#D8262E"
	local trim = "#FFC53D"
	local base = P(m, { Name = "Base", Size = Vector3.new(8, 6, 8), CFrame = CFrame.new(0, 3.3, 0), Color = body })
	P(m, { Name = "Foot", Size = Vector3.new(8.6, 0.6, 8.6), CFrame = CFrame.new(0, 0.3, 0), Color = "#24262C" })
	P(m, { Name = "TopTrim", Size = Vector3.new(8.6, 0.6, 8.6), CFrame = CFrame.new(0, 6.6, 0), Color = trim, Material = Enum.Material.Metal })
	P(m, { Name = "Stripe", Size = Vector3.new(8.05, 0.5, 8.05), CFrame = CFrame.new(0, 4.6, 0), Color = "#FFFFFF" })
	P(m, { Name = "Glow", Size = Vector3.new(8.1, 0.2, 8.1), CFrame = CFrame.new(0, 0.75, 0), Color = if advanced then "#D9B3FF" else "#FF6B7F", Material = Enum.Material.Neon })
	-- glass dome with orbs inside
	local dome = P(m, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(7.4, 7.4, 7.4), CFrame = CFrame.new(0, 10.4, 0), Color = "#DDEEFF", Material = Enum.Material.Glass, Transparency = 0.55, CanCollide = false })
	dome.CastShadow = false
	local rng = Rng.new(if advanced then 77 else 31)
	for i = 1, 18 do
		local a = rng:Range(0, 2 * math.pi)
		local rr = rng:Range(0, 2.4)
		local y = 8.6 + rng:Range(0, 2.6) + (if i > 12 then 0.8 else 0)
		local d = rng:Range(1.1, 1.5)
		P(m, {
			Name = "Capsule",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			CFrame = CFrame.new(math.cos(a) * rr, y, math.sin(a) * rr),
			Color = ORB_COLORS[(i - 1) % #ORB_COLORS + 1],
			Reflectance = 0.05,
			CanCollide = false,
		})
	end
	P(m, { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 3.2, 3.2), CFrame = upright(CFrame.new(0, 14.1, 0)), Color = trim, Material = Enum.Material.Metal })
	P(m, { Name = "CapBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(0, 15, 0), Color = body })
	-- front controls (+Z)
	P(m, { Name = "Knob", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 2.4, 2.4), CFrame = CFrame.new(0, 4, 4.3) * CFrame.Angles(0, math.rad(90), 0), Color = "#D9DCE1", Material = Enum.Material.Metal })
	P(m, { Name = "Handle", Size = Vector3.new(2.2, 0.45, 0.4), CFrame = CFrame.new(0, 4, 4.75), Color = "#9CA2AB", Material = Enum.Material.Metal })
	P(m, { Name = "Chute", Size = Vector3.new(2.6, 1.6, 0.4), CFrame = CFrame.new(0, 1.8, 4.1), Color = "#1A1B20" })
	P(m, { Name = "Slot", Size = Vector3.new(0.3, 0.9, 0.2), CFrame = CFrame.new(2.6, 4, 4.05), Color = "#1A1B20" })
	return finish(m, base)
end

---------------------------------------------------------------------------- Crates / boxes
function PropFactory.Crate(theme: string?): Model
	local m = PropFactory.Model("Crate")
	local cardboard = "#C8915A"
	local base = P(m, { Name = "Box", Size = Vector3.new(4, 3.4, 4), CFrame = CFrame.new(0, 1.7, 0), Color = cardboard, Material = Enum.Material.Cardboard })
	P(m, { Name = "Tape", Size = Vector3.new(4.05, 0.6, 0.6), CFrame = CFrame.new(0, 2.4, 2.0), Color = "#E9E2D0" })
	-- open flaps
	P(m, { Name = "FlapL", Size = Vector3.new(2, 0.15, 4), CFrame = CFrame.new(-2.6, 3.7, 0) * CFrame.Angles(0, 0, math.rad(35)), Color = "#B98250", Material = Enum.Material.Cardboard })
	P(m, { Name = "FlapR", Size = Vector3.new(2, 0.15, 4), CFrame = CFrame.new(2.6, 3.7, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color = "#B98250", Material = Enum.Material.Cardboard })
	P(m, { Name = "FlapB", Size = Vector3.new(4, 0.15, 2), CFrame = CFrame.new(0, 3.7, -2.6) * CFrame.Angles(math.rad(-35), 0, 0), Color = "#B98250", Material = Enum.Material.Cardboard })
	local rng = Rng.new(5)
	for i = 1, 6 do
		local d = rng:Range(0.9, 1.4)
		P(m, {
			Name = "Prize",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			CFrame = CFrame.new(rng:Range(-1.2, 1.2), 3.4 + rng:Range(0, 0.8), rng:Range(-1.2, 1.2)),
			Color = ORB_COLORS[i],
			CanCollide = false,
		})
	end
	if theme == "Flyer" then
		PropFactory.SaucerInto(m, CFrame.new(0.6, 5.6, -0.4) * CFrame.Angles(math.rad(-12), 0, math.rad(8)), 0.45)
	elseif theme == "Explosion" then
		local star = PropFactory.Model("Burst")
		for k = 1, 6 do
			P(star, { Name = "Ray", Size = Vector3.new(0.5, 2.6, 0.5), CFrame = CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(k * 30)), Color = if k % 2 == 0 then "#FF8C1A" else "#FFE14D", Material = Enum.Material.Neon, CanCollide = false })
		end
		star.Parent = m
	elseif theme == "Event" then
		P(m, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 1.7, 2), CFrame = CFrame.new(0, 4.4, 0), Color = "#FF8C1A", CanCollide = false })
		P(m, { Name = "Stem", Size = Vector3.new(0.3, 0.6, 0.3), CFrame = CFrame.new(0, 5.4, 0), Color = "#3E8E1E", CanCollide = false })
	end
	return finish(m, base)
end

function PropFactory.InventoryBox(): Model
	local m = PropFactory.Model("InventoryBox")
	local base = P(m, { Name = "Box", Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(0, 1.5, 0), Color = "#E8E8EE" })
	P(m, { Name = "Lid", Size = Vector3.new(4.3, 0.7, 4.3), CFrame = CFrame.new(0, 3.2, 0), Color = "#F5F6FA" })
	P(m, { Name = "Strap", Size = Vector3.new(0.7, 3.6, 4.35), CFrame = CFrame.new(0, 1.85, 0), Color = "#9CA2AB" })
	return finish(m, base)
end

---------------------------------------------------------------------------- Saucer (flyer)
function PropFactory.SaucerInto(parent: Instance, cf: CFrame, scale: number): BasePart
	local s = scale
	local hull = P(parent, { Name = "Hull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8 * s, 7 * s, 7 * s), CFrame = cf * upright(CFrame.new()), Color = "#C9D0DA", Material = Enum.Material.Metal, CanCollide = false })
	P(parent, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, 7.4 * s, 7.4 * s), CFrame = cf * upright(CFrame.new()), Color = "#5FFFE0", Material = Enum.Material.Neon, CanCollide = false })
	P(parent, { Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4 * s, 1.6 * s, 4.4 * s), CFrame = cf * CFrame.new(0, -0.35 * s, 0), Color = "#8E97A6", Material = Enum.Material.Metal, CanCollide = false })
	P(parent, { Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(3 * s, 3 * s, 3 * s), CFrame = cf * CFrame.new(0, 0.6 * s, 0), Color = "#7FE9FF", Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false })
	return hull
end

---------------------------------------------------------------------------- Pedestals
function PropFactory.Pedestal(glow: string?): Model
	local m = PropFactory.Model("Pedestal")
	local base = P(m, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 9, 9), CFrame = upright(CFrame.new(0, 0.8, 0)), Color = "#1A2134" })
	P(m, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 9.4, 9.4), CFrame = upright(CFrame.new(0, 1.45, 0)), Color = glow or Lobby.Colors.TrimGlow, Material = Enum.Material.Neon, CanCollide = false })
	P(m, { Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 8, 8), CFrame = upright(CFrame.new(0, 1.8, 0)), Color = "#24304D" })
	return finish(m, base)
end

function PropFactory.FlyerDisplay(): Model
	local m = PropFactory.Pedestal("#FFE14D")
	m.Name = "FlyerDisplay"
	local saucer = PropFactory.Model("Saucer")
	PropFactory.SaucerInto(saucer, CFrame.new(0, 10, 0), 1)
	saucer.Parent = m
	local beam = P(m, { Name = "LightCone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 4.6, 4.6), CFrame = upright(CFrame.new(0, 5.6, 0)), Color = "#FFE97A", Material = Enum.Material.Neon, Transparency = 0.72, CanCollide = false })
	beam.CastShadow = false
	saucer:SetAttribute("Bob", 0.6)
	return m
end

function PropFactory.CrateDisplay(): Model
	local m = PropFactory.Pedestal("#B24DFF")
	m.Name = "CrateDisplay"
	local crate = PropFactory.Crate("Explosion")
	crate:PivotTo(CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(20), 0))
	crate.Parent = m
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#B24DFF")
	light.Range = 14
	light.Brightness = 2
	light.Parent = m.PrimaryPart
	return m
end

function PropFactory.EventDisplay(): Model
	local m = PropFactory.Pedestal("#FF8C1A")
	m.Name = "EventDisplay"
	local crate = PropFactory.Crate("Event")
	crate:PivotTo(CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-15), 0))
	crate.Parent = m
	-- glowing wings (event flair)
	for side = -1, 1, 2 do
		for k = 1, 3 do
			P(m, {
				Name = "Wing",
				Size = Vector3.new(0.25, 0.8, 4 - k * 0.7),
				CFrame = CFrame.new(side * (2.6 + k * 0.5), 6 + k * 0.6, 0) * CFrame.Angles(math.rad(side * -20 * k), 0, math.rad(side * (30 + k * 12))),
				Color = if k == 2 then "#FF7BD5" else "#B24DFF",
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	end
	return m
end

function PropFactory.GroupPedestal(): Model
	local m = PropFactory.Model("GroupPedestal")
	local base = P(m, { Name = "Block", Size = Vector3.new(7, 3.2, 4.5), CFrame = CFrame.new(0, 1.6, 0), Color = "#0D0F14" })
	P(m, { Name = "Edge", Size = Vector3.new(7.2, 0.25, 4.7), CFrame = CFrame.new(0, 3.25, 0), Color = "#FFA000", Material = Enum.Material.Neon, CanCollide = false })
	P(m, { Name = "Thumb", Size = Vector3.new(1.2, 1.8, 0.8), CFrame = CFrame.new(-1.2, 4.3, 0), Color = "#FFFFFF", CanCollide = false })
	P(m, { Name = "ThumbTip", Size = Vector3.new(0.6, 1, 0.8), CFrame = CFrame.new(-1.0, 5.6, 0), Color = "#FFFFFF", CanCollide = false })
	P(m, { Name = "Star", Size = Vector3.new(1.4, 1.4, 0.6), CFrame = CFrame.new(1.4, 4.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = "#FFE14D", Material = Enum.Material.Neon, CanCollide = false })
	return finish(m, base)
end

---------------------------------------------------------------------------- Leaderboard board
function PropFactory.Leaderboard(): Model
	local m = PropFactory.Model("Leaderboard")
	local legL = P(m, { Name = "LegL", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(-13, 3, -0.4), Color = "#1A2134" })
	P(m, { Name = "LegR", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(13, 3, -0.4), Color = "#1A2134" })
	P(m, { Name = "Frame", Size = Vector3.new(36, 21, 1.2), CFrame = CFrame.new(0, 16.5, -0.5), Color = "#2F74E8" })
	local screen = P(m, { Name = "Screen", Size = Vector3.new(35, 20, 0.4), CFrame = CFrame.new(0, 16.5, 0.2), Color = "#141A2B" })
	screen:SetAttribute("BoardScreen", true)
	return finish(m, legL)
end

---------------------------------------------------------------------------- Giant decor orb
function PropFactory.DecorOrb(): Model
	local m = PropFactory.Model("DecorOrb")
	local core = P(m, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(14, 14, 14), CFrame = CFrame.new(0, 7, 0), Color = "#FF8A1F", Reflectance = 0.04, CanCollide = false })
	P(m, { Name = "Visor", Size = Vector3.new(11.5, 3.2, 3), CFrame = CFrame.new(0, 8, 5.6), Color = "#14141C", CanCollide = false })
	P(m, { Name = "VisorGlow", Size = Vector3.new(9.5, 0.6, 0.3), CFrame = CFrame.new(0, 8, 7.15), Color = "#5FFFE0", Material = Enum.Material.Neon, CanCollide = false })
	P(m, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.5, 0.5), CFrame = upright(CFrame.new(2, 15.5, 0)), Color = "#C9CCD3", CanCollide = false })
	P(m, { Name = "AntennaTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(2, 17.6, 0), Color = "#FF3D6E", Material = Enum.Material.Neon, CanCollide = false })
	m:SetAttribute("Bob", 1.5)
	return finish(m, core)
end

return PropFactory
