--!strict
-- Procedural world builder (server). MapBuilder.Build(world, parent) builds one complete world at
-- Map.Origin(world.Id) from Config/Map, Config/Flight, Sim/FlightSim, Visual/Themes and the
-- definitions, and parents a Model "World_<id>" to `parent`:
--   hub (checker floor, stone path, checker cliff walls with grass tops, spawn plate, title arch),
--   the Throw Zone platform at the channel edge, the long channel with zone arches (MapChannel),
--   the interactive stations (MapStations) and themed decoration (MapProps).
-- Child names follow docs/DESIGN.md §5 exactly; clients depend on them. Everything is anchored,
-- only walkable/blocking geometry collides, and the build never yields. Lighting is per client
-- (WorldController), so it is not touched here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Themes = require(Shared.Visual.Themes)
local Worlds = require(Shared.Definitions.Worlds)
local Training = require(Shared.Definitions.Training)
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Eggs = require(Shared.Definitions.Eggs)
local Zones = require(Shared.Definitions.Zones)

local World = script.Parent
local MapKit = require(World.MapKit)
local MapProps = require(World.MapProps)
local MapChannel = require(World.MapChannel)
local MapStations = require(World.MapStations)

local MapBuilder = {}

MapBuilder.PartBudget = 2500 -- soft target per world; Build warns above it

local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)

local HUB = Map.Hub
local WALL_T = 12 -- hub wall thickness
local TILE_X = (HUB.MaxX - HUB.MinX) / 24 -- ~13.3 stud floor tiles
local TILE_Z = (HUB.MaxZ - HUB.MinZ) / 20 -- 13.5
local PATH_HALF = TILE_X -- the stone path covers two tile columns
local PATH_END = Map.Spawn.Z + 10
local TITLE_Z = 150 -- title arch over the path, ahead of spawn
local OPENING = MapChannel.CliffX -- hub front is open over the channel for |X| < this

type Rect = { X0: number, X1: number, Z0: number, Z1: number }

local function inside(r: Rect, x0: number, x1: number, z0: number, z1: number): boolean
	return x0 >= r.X0 - 0.01 and x1 <= r.X1 + 0.01 and z0 >= r.Z0 - 0.01 and z1 <= r.Z1 + 0.01
end

-- HUB ---------------------------------------------------------------------------------------------

local function buildFloor(ctx: MapKit.Ctx, hub: Instance)
	local pal = ctx.Pal
	local at = function(x: number, y: number, z: number): Vector3
		return MapKit.At(ctx, x, y, z)
	end
	local floor = MapKit.Group(hub, "Floor")
	MapKit.Box(floor, at(HUB.MinX, -16, HUB.MinZ), at(HUB.MaxX, 0, HUB.MaxZ), pal.FloorA, {
		Solid = true,
		Name = "Ground",
	})
	-- checkerboard: FloorB tiles sit 0.05 proud of the ground; tiles hidden under the throw zone or
	-- the path are skipped
	local covered: { Rect } = {
		{ X0 = Map.ThrowZone.MinX, X1 = Map.ThrowZone.MaxX, Z0 = Map.ThrowZone.MinZ, Z1 = Map.ThrowZone.MaxZ },
		{ X0 = -PATH_HALF, X1 = PATH_HALF, Z0 = Map.ThrowZone.MaxZ, Z1 = PATH_END },
	}
	for i = 0, 23 do
		for j = 0, 19 do
			if (i + j) % 2 == 1 then
				local x0 = HUB.MinX + i * TILE_X
				local z0 = HUB.MinZ + j * TILE_Z
				local hidden = false
				for _, r in covered do
					if inside(r, x0, x0 + TILE_X, z0, z0 + TILE_Z) then
						hidden = true
						break
					end
				end
				if not hidden then
					MapKit.Box(floor, at(x0, -0.15, z0), at(x0 + TILE_X, 0.05, z0 + TILE_Z), pal.FloorB, { Name = "Tile" })
				end
			end
		end
	end
	-- retaining face under the hub's open front, seen from the channel
	-- (0.3 proud of the ground's front face and 0.05 below its top, so no faces coincide)
	MapKit.CheckerWall(floor, at(-OPENING, Map.WaterY - 8, HUB.MinZ - 0.3), at(OPENING, Map.WaterY - 8, HUB.MinZ - 0.3), Vector3.new(0, 0, -1), 8 - Map.WaterY - 0.05, pal.Cliff, pal.CliffAlt, pal.CliffTop, {
		Thickness = 2,
		BlockLength = 14,
		Rows = 1,
	})
end

local function buildPath(ctx: MapKit.Ctx, hub: Instance)
	local pal = ctx.Pal
	local path = MapKit.Group(hub, "Path")
	local z0, z1 = Map.ThrowZone.MaxZ, PATH_END
	MapKit.Box(path, MapKit.At(ctx, -PATH_HALF, -0.2, z0), MapKit.At(ctx, PATH_HALF, 0.2, z1), pal.Path, {
		Solid = true,
		Name = "Stone",
	})
	local edge = MapKit.Shade(pal.Path, 0.18)
	for side = -1, 1, 2 do
		MapKit.Box(path, MapKit.At(ctx, side * PATH_HALF, 0.2, z0), MapKit.At(ctx, side * (PATH_HALF - 1.2), 0.3, z1), edge, { Name = "Edge" })
	end
	-- two columns of alternating stones
	local rows = 14
	local rowLen = (z1 - z0) / rows
	local stone = MapKit.Shade(pal.Path, 0.07)
	for r = 0, rows - 1 do
		for c = 0, 1 do
			if (r + c) % 2 == 1 then
				local x0 = -PATH_HALF + c * PATH_HALF
				MapKit.Box(path, MapKit.At(ctx, x0 + 1.2 * (1 - c), 0.2, z0 + r * rowLen), MapKit.At(ctx, x0 + PATH_HALF - 1.2 * c, 0.26, z0 + (r + 1) * rowLen), stone, {
					Name = "Slab",
				})
			end
		end
	end
end

local function buildWalls(ctx: MapKit.Ctx, hub: Instance)
	local pal = ctx.Pal
	local walls = MapKit.Group(hub, "Walls")
	local h = HUB.WallHeight
	local function wall(a: Vector3, b: Vector3, inward: Vector3, e0: number, e1: number)
		MapKit.CheckerWall(walls, MapKit.At(ctx, a.X, 0, a.Z), MapKit.At(ctx, b.X, 0, b.Z), inward, h, pal.Cliff, pal.CliffAlt, pal.CliffTop, {
			Thickness = WALL_T,
			BlockLength = TILE_X,
			Rows = 3,
			Below = 16,
			ExtendStart = e0,
			ExtendEnd = e1,
			Cap = true,
			CapOverhang = 1.2,
			Drips = ctx.Rng,
		})
	end
	wall(Vector3.new(HUB.MinX, 0, HUB.MaxZ), Vector3.new(HUB.MaxX, 0, HUB.MaxZ), Vector3.new(0, 0, -1), WALL_T, WALL_T)
	wall(Vector3.new(HUB.MinX, 0, HUB.MinZ), Vector3.new(HUB.MinX, 0, HUB.MaxZ), Vector3.new(1, 0, 0), WALL_T, 0)
	wall(Vector3.new(HUB.MaxX, 0, HUB.MinZ), Vector3.new(HUB.MaxX, 0, HUB.MaxZ), Vector3.new(-1, 0, 0), WALL_T, 0)
	wall(Vector3.new(HUB.MinX, 0, HUB.MinZ), Vector3.new(-OPENING, 0, HUB.MinZ), Vector3.new(0, 0, 1), WALL_T, 0)
	wall(Vector3.new(OPENING, 0, HUB.MinZ), Vector3.new(HUB.MaxX, 0, HUB.MinZ), Vector3.new(0, 0, 1), 0, WALL_T)
	-- grass plateau around the hub at wall-top height (no floating-island look from above)
	local top = h + 2
	local outer = MapChannel.OuterX
	local back = HUB.MaxZ + WALL_T
	local front = HUB.MinZ - WALL_T
	local opts: MapKit.PartOpts = { Solid = true, Shadow = false, Name = "Plateau" }
	MapKit.Box(walls, MapKit.At(ctx, -outer, top - 6, front), MapKit.At(ctx, HUB.MinX - WALL_T, top, back + 120), pal.CliffTop, opts)
	MapKit.Box(walls, MapKit.At(ctx, HUB.MaxX + WALL_T, top - 6, front), MapKit.At(ctx, outer, top, back + 120), pal.CliffTop, opts)
	MapKit.Box(walls, MapKit.At(ctx, HUB.MinX - WALL_T, top - 6, back), MapKit.At(ctx, HUB.MaxX + WALL_T, top, back + 120), pal.CliffTop, opts)
end

-- Spawn plate (every world) and the real SpawnLocation (world 1 only; WorldService teleports
-- players into the other worlds).
local function buildSpawn(ctx: MapKit.Ctx, hub: Instance)
	local pal = ctx.Pal
	local s = Map.Spawn
	local plate = MapKit.Group(hub, "SpawnPlate")
	MapKit.Disc(plate, 24, 0.5, MapKit.CF(ctx, s.X, 0.25, s.Z), pal.Accent, { Material = NEON, Name = "Glow" })
	MapKit.Disc(plate, 21, 0.62, MapKit.CF(ctx, s.X, 0.31, s.Z), pal.Stone, { Solid = true, Name = "Plate" })
	MapKit.Disc(plate, 9, 0.66, MapKit.CF(ctx, s.X, 0.33, s.Z), MapKit.Tint(pal.Accent, 0.35), { Name = "Center" })
	if ctx.World.Id == 1 then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Size = Vector3.new(12, 1, 12)
		local pos = MapKit.At(ctx, s.X, 0.5, s.Z)
		spawn.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)) -- players spawn facing the channel
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CanTouch = false
		spawn.AllowTeamChangeOnTouch = false
		spawn.Enabled = true
		spawn.Parent = ctx.Model
	end
end

-- Title arch over the path ("SUNNY ISLES"), readable from both sides.
local function buildTitle(ctx: MapKit.Ctx, hub: Instance)
	local pal = ctx.Pal
	local world = ctx.World
	local title = MapKit.Group(hub, "TitleSign")
	local px = PATH_HALF + 3.5
	for side = -1, 1, 2 do
		MapKit.Part(title, Vector3.new(3.4, 30, 3.4), MapKit.CF(ctx, side * px, 15, TITLE_Z), pal.Stone, { Solid = true, Shadow = true, Name = "Pillar" })
		MapKit.Part(title, Vector3.new(4.2, 2, 4.2), MapKit.CF(ctx, side * px, 8, TITLE_Z), pal.Accent, { Name = "Band" })
		MapKit.Ball(title, 4.6, MapKit.CF(ctx, side * px, 31.5, TITLE_Z), pal.Accent, { Material = NEON, Name = "Lamp" })
	end
	local width = px * 2 + 8
	local center = MapKit.At(ctx, 0, 25, TITLE_Z)
	local board = MapKit.Part(title, Vector3.new(width, 9, 2), MapKit.Facing(center, Vector3.zAxis), MapKit.Shade(pal.Accent, 0.55), {
		Shadow = true,
		Name = "Board",
	})
	-- thinner than the board and centred on it, so both sign faces stay in front of the border
	MapKit.Part(title, Vector3.new(width + 2, 11, 1.4), MapKit.Facing(center, Vector3.zAxis), pal.Accent, { Name = "Border" })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = MapKit.Surface(board, "Title", face, 20)
		local name = MapKit.Text(gui, "Name", string.upper(world.Name), 0.04, 0.62, WHITE, { StrokeThickness = 5 })
		MapKit.Gradient(name, { WHITE, MapKit.Tint(pal.Accent, 0.4) }).Rotation = 90
		MapKit.Text(gui, "Sub", string.format("WORLD %d  •  %s", world.Id, world.Description), 0.68, 0.28, MapKit.Tint(pal.Accent, 0.6), {
			Font = MapKit.Fonts.Body,
			StrokeThickness = 2,
		})
	end
end

-- THROW ZONE --------------------------------------------------------------------------------------

local function buildThrowZone(ctx: MapKit.Ctx, hub: Instance)
	local pal = ctx.Pal
	local tz = Map.ThrowZone
	local cx = (tz.MinX + tz.MaxX) / 2
	local cz = (tz.MinZ + tz.MaxZ) / 2
	local w = tz.MaxX - tz.MinX
	local d = tz.MaxZ - tz.MinZ
	local zone = MapKit.Part(ctx.Model, Vector3.new(w, 1, d), MapKit.CF(ctx, cx, -0.1, cz), pal.ThrowZone, {
		Solid = true,
		Shadow = true,
		Name = "ThrowZone",
	})
	zone.CanTouch = true -- clients may use touch/overlap queries on the zone
	zone:SetAttribute("ThrowZone", true)

	local deco = MapKit.Group(hub, "ThrowZoneDecor")
	local dark = MapKit.Shade(pal.ThrowZone, 0.1)
	local cols, rows = 6, 4
	local tw, td = w / cols, d / rows
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			if (c + r) % 2 == 1 then
				local x0 = tz.MinX + c * tw
				local z0 = tz.MinZ + r * td
				MapKit.Box(deco, MapKit.At(ctx, x0, 0.4, z0), MapKit.At(ctx, x0 + tw, 0.46, z0 + td), dark, { Name = "Tile" })
			end
		end
	end
	-- border trim, neon launch edge toward the channel
	local trim = MapKit.Shade(pal.ThrowZone, 0.3)
	MapKit.Box(deco, MapKit.At(ctx, tz.MinX, 0.4, tz.MaxZ - 1.4), MapKit.At(ctx, tz.MaxX, 0.52, tz.MaxZ), trim, { Name = "Trim" })
	MapKit.Box(deco, MapKit.At(ctx, tz.MinX, 0.4, tz.MinZ), MapKit.At(ctx, tz.MinX + 1.4, 0.52, tz.MaxZ), trim, { Name = "Trim" })
	MapKit.Box(deco, MapKit.At(ctx, tz.MaxX - 1.4, 0.4, tz.MinZ), MapKit.At(ctx, tz.MaxX, 0.52, tz.MaxZ), trim, { Name = "Trim" })
	MapKit.Box(deco, MapKit.At(ctx, tz.MinX, 0.4, tz.MinZ), MapKit.At(ctx, tz.MaxX, 0.55, tz.MinZ + 1.4), MapKit.Tint(pal.ThrowZone, 0.4), {
		Material = NEON,
		Name = "LaunchEdge",
	})
	-- "THROW ZONE" painted on the floor, upright for players walking in from spawn (-Z)
	local decal = MapKit.FloorDecal(deco, MapKit.At(ctx, cx, 0.58, cz + 2), Vector3.new(0, 0, -1), w - 10, d * 0.42)
	local gui = MapKit.Surface(decal, "Paint", Enum.NormalId.Front, 16)
	MapKit.Text(gui, "Text", "THROW ZONE", 0, 1, pal.ThrowZoneText, {
		Stroke = MapKit.StrokeFor(pal.ThrowZoneText),
		StrokeThickness = 6,
	})
	-- low railing across the whole open front, plus an invisible barrier so nobody falls in
	local railZ = HUB.MinZ + 0.5
	local posts = 13
	for i = 0, posts - 1 do
		local x = -OPENING + 1 + (OPENING * 2 - 2) * i / (posts - 1)
		MapKit.Part(deco, Vector3.new(0.9, 3.4, 0.9), MapKit.CF(ctx, x, 1.7, railZ), pal.Stone, { Name = "Post" })
	end
	MapKit.Box(deco, MapKit.At(ctx, -OPENING, 3.2, railZ - 0.5), MapKit.At(ctx, OPENING, 3.9, railZ + 0.5), pal.Accent, { Name = "Rail" })
	MapKit.Box(deco, MapKit.At(ctx, -OPENING, 1.6, railZ - 0.3), MapKit.At(ctx, OPENING, 2, railZ + 0.3), WHITE, { Name = "Rail" })
	MapKit.Box(deco, MapKit.At(ctx, -OPENING, 0, HUB.MinZ - 1), MapKit.At(ctx, OPENING, 14, HUB.MinZ), WHITE, {
		Solid = true,
		Transparency = 1,
		Shadow = false,
		Name = "Barrier",
	})
end

-- DECORATION --------------------------------------------------------------------------------------

type Spot = { X: number, Z: number, Role: string, Scale: number }

-- Hand-placed hub spots (world-local), clear of the path, pads, pedestals, eggs, portals and boards.
local HUB_SPOTS: { Spot } = {
	{ X = -143, Z = -25, Role = "Tree", Scale = 1.2 },
	{ X = -128, Z = -24, Role = "Bush", Scale = 1 },
	{ X = -152, Z = -4, Role = "Rock", Scale = 1.1 },
	{ X = -134, Z = 9, Role = "Tree", Scale = 1 },
	{ X = -100, Z = -20, Role = "Feature", Scale = 1 },
	{ X = -60, Z = -26, Role = "Small", Scale = 1 },
	{ X = -80, Z = -2, Role = "Bush", Scale = 0.9 },
	{ X = -140, Z = 42, Role = "Bush", Scale = 1 },
	{ X = -142, Z = 72, Role = "Tree", Scale = 1.15 },
	{ X = -134, Z = 95, Role = "Small", Scale = 1 },
	{ X = -60, Z = 34, Role = "Feature", Scale = 1 },
	{ X = -46, Z = 78, Role = "Tree", Scale = 1 },
	{ X = -70, Z = 118, Role = "Small", Scale = 1 },
	{ X = -36, Z = 120, Role = "Bush", Scale = 0.9 },
	{ X = -40, Z = 160, Role = "Rock", Scale = 1 },
	{ X = -64, Z = 178, Role = "Tree", Scale = 1.1 },
	{ X = 30, Z = 30, Role = "Small", Scale = 0.9 },
	{ X = 42, Z = 64, Role = "Bush", Scale = 1 },
	{ X = 52, Z = 102, Role = "Tree", Scale = 1 },
	{ X = 34, Z = 136, Role = "Small", Scale = 1 },
	{ X = 54, Z = 176, Role = "Rock", Scale = 1 },
	{ X = 140, Z = 30, Role = "Tree", Scale = 1.1 },
	{ X = 150, Z = 72, Role = "Bush", Scale = 1 },
	{ X = 138, Z = 112, Role = "Tree", Scale = 1 },
	{ X = 150, Z = 150, Role = "Small", Scale = 1 },
	{ X = 140, Z = 186, Role = "Rock", Scale = 1 },
	{ X = 112, Z = -22, Role = "Feature", Scale = 1 },
	{ X = 144, Z = -25, Role = "Tree", Scale = 1.2 },
	{ X = 54, Z = -26, Role = "Small", Scale = 1 },
	{ X = 128, Z = 6, Role = "Bush", Scale = 1 },
	{ X = 146, Z = 216, Role = "Tree", Scale = 1 },
	{ X = 16, Z = 220, Role = "Bush", Scale = 1 },
	{ X = -10, Z = 222, Role = "Rock", Scale = 0.9 },
	{ X = -136, Z = 217, Role = "Tree", Scale = 1 },
}

-- Facing toward the middle of the hub (props with a front, like the igloo or the statue).
local function hubFacing(ctx: MapKit.Ctx, x: number, z: number): CFrame
	local pos = MapKit.At(ctx, x, 0, z)
	local target = MapKit.At(ctx, 0, 0, 100)
	if (target - pos).Magnitude < 1 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, target)
end

local function decorateHub(ctx: MapKit.Ctx, decor: Instance)
	local family = ctx.Theme.Props
	local props: MapProps.Ctx = { Pal = ctx.Pal, Rng = ctx.Rng, Shadow = true }
	local hub = MapKit.Group(decor, "Hub")
	for _, spot in HUB_SPOTS do
		MapProps.Place(family, spot.Role, hub, hubFacing(ctx, spot.X, spot.Z), spot.Scale, props)
	end
	-- signature set pieces per family
	if family == "Volcano" then
		MapProps.DragonStatue(hub, hubFacing(ctx, 132, -12), 1, props)
		MapProps.LavaPool(hub, MapKit.CF(ctx, 100, 0, 186), 1.1, props)
	elseif family == "Pirate" then
		MapProps.SkullFlag(hub, MapKit.CF(ctx, -150, 0, -32), 1.4, props)
		MapProps.SkullFlag(hub, MapKit.CF(ctx, 150, 0, -32) * CFrame.Angles(0, math.pi, 0), 1.4, props)
		MapProps.TreasureChest(hub, hubFacing(ctx, 147, 198), 1.2, props)
	elseif family == "Ice" then
		MapProps.Crystal(hub, MapKit.CF(ctx, 147, 0, 198), 1.6, props)
		MapProps.IceSpike(hub, MapKit.CF(ctx, 100, 0, 186), 1.2, props)
	else
		MapProps.Umbrella(hub, MapKit.CF(ctx, 147, 0, 198), 1, props)
		MapProps.Palm(hub, MapKit.CF(ctx, 100, 0, 186), 1, props)
	end
end

-- Props along the banks and on the plateau behind the cliffs. Dense near the hub where the camera
-- lingers, sparse far out; never on top of a zone arch.
local function decorateChannel(ctx: MapKit.Ctx, decor: Instance, archZ: { number })
	local family = ctx.Theme.Props
	local rng = ctx.Rng
	local props: MapProps.Ctx = { Pal = ctx.Pal, Rng = rng, Shadow = false }
	local banks = MapKit.Group(decor, "Banks")
	local function nearArch(z: number): boolean
		for _, az in archZ do
			if math.abs(z - az) < 16 then
				return true
			end
		end
		return false
	end
	local finish = if #archZ > 0 then Map.ChannelStartZ - archZ[#archZ] else 5000
	local limit = finish + 400
	local bankY = MapChannel.BankTop
	local roles = { "Bush", "Rock", "Small" }
	local d = 70
	local side = 1
	local n = 0
	while d < limit do
		local step = if d < 2400 then 115 else 290
		local z = Map.ChannelStartZ - d
		if not nearArch(z) then
			local x = side * rng:NextNumber(52, 60)
			MapProps.Place(family, "Tree", banks, MapKit.CF(ctx, x, bankY, z), rng:NextNumber(1, 1.25), props)
		end
		local z2 = z - step * 0.5
		if not nearArch(z2) then
			n += 1
			local x2 = -side * rng:NextNumber(53, 64)
			MapProps.Place(family, roles[n % #roles + 1], banks, MapKit.CF(ctx, x2, bankY, z2) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1, 1.4), props)
		end
		d += step * rng:NextNumber(0.85, 1.15)
		side = -side
	end
	-- plateau trees peeking over the cliffs near the hub
	local plateau = MapKit.Group(decor, "Plateau")
	local topY = MapChannel.PlateauY
	d = 140
	side = 1
	while d < 1700 do
		local z = Map.ChannelStartZ - d
		MapProps.Place(family, "Tree", plateau, MapKit.CF(ctx, side * rng:NextNumber(95, 230), topY, z), rng:NextNumber(1.5, 1.9), props)
		d += rng:NextNumber(120, 170)
		side = -side
	end
	-- big stepped hills far out on the plateau break up the horizon during long flights
	local hills = MapKit.Group(decor, "Hills")
	d = 500
	side = if rng:NextNumber() < 0.5 then 1 else -1
	local hillSide = MapKit.Shade(ctx.Pal.Cliff, 0.05)
	while d < MapChannel.Length() - 300 do
		local z = Map.ChannelStartZ - d
		local w = rng:NextNumber(70, 140)
		local h = rng:NextNumber(14, 34)
		local x = side * rng:NextNumber(120 + w / 2, MapChannel.OuterX - w / 2)
		local depth = rng:NextNumber(80, 180)
		MapKit.Box(hills, MapKit.At(ctx, x - w / 2, topY - 2, z - depth / 2), MapKit.At(ctx, x + w / 2, topY + h - 3, z + depth / 2), hillSide, { Name = "Hill" })
		MapKit.Box(hills, MapKit.At(ctx, x - w / 2 - 1, topY + h - 3, z - depth / 2 - 1), MapKit.At(ctx, x + w / 2 + 1, topY + h, z + depth / 2 + 1), ctx.Pal.CliffTop, { Name = "HillTop" })
		d += rng:NextNumber(380, 620)
		side = -side
	end
	-- landmarks
	local landmarks = MapKit.Group(decor, "Landmarks")
	if family == "Volcano" then
		-- rising out of the plateau's outer edge, visible over the cliffs from the Throw Zone
		local hub = MapKit.At(ctx, 0, topY - 2, 0)
		for _, v in { { -470, -700, 1.6 }, { 560, -1800, 2 } } do
			MapProps.Volcano(landmarks, CFrame.lookAt(MapKit.At(ctx, v[1], topY - 2, v[2]), hub), v[3], props)
		end
	elseif family == "Pirate" then
		MapProps.Ship(landmarks, CFrame.lookAt(MapKit.At(ctx, -27, Map.WaterY, -260), MapKit.At(ctx, -27, Map.WaterY, -400)), 1.3, props)
		MapProps.Ship(landmarks, CFrame.lookAt(MapKit.At(ctx, 27, Map.WaterY, -1900), MapKit.At(ctx, 27, Map.WaterY, -1700)), 1.4, props)
	elseif family == "Ice" then
		for i = 0, 3 do
			local s = if i % 2 == 0 then 1 else -1
			MapProps.Crystal(landmarks, MapKit.CF(ctx, s * rng:NextNumber(110, 200), topY, Map.ChannelStartZ - 300 - i * 420), 4, props)
		end
	end
end

-- BUILD -------------------------------------------------------------------------------------------

local function countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function section(name: string, worldId: number, fn: () -> ())
	xpcall(fn, function(err: any)
		warn(string.format("[MapBuilder] world %d: %s failed: %s\n%s", worldId, name, tostring(err), debug.traceback()))
	end)
end

-- Builds world `world` and parents "World_<id>" to `parent`. Never yields. A failing section is
-- reported and skipped so one bad definition can't take the whole world down.
function MapBuilder.Build(world: Worlds.World, parent: Instance): Model
	local theme = Themes[world.Theme] or Themes.Isles
	local origin = Map.Origin(world.Id)
	local model = Instance.new("Model")
	model.Name = "World_" .. world.Id
	model:SetAttribute("WorldId", world.Id)
	model.WorldPivot = CFrame.new(origin)
	local ctx: MapKit.Ctx = {
		World = world,
		Theme = theme,
		Pal = MapKit.Palette(theme),
		Origin = origin,
		Model = model,
		Rng = Random.new(world.Id * 7919 + 17),
	}
	local id = world.Id
	local hub = MapKit.Folder(model, "Hub")
	local stations = {
		Pads = MapKit.Folder(model, "Pads"),
		Pedestals = MapKit.Folder(model, "Pedestals"),
		Eggs = MapKit.Folder(model, "Eggs"),
		Portals = MapKit.Folder(model, "Portals"),
		Boards = MapKit.Folder(model, "Boards"),
		Zones = MapKit.Folder(model, "Zones"),
	}
	local channel = MapKit.Folder(model, "Channel")
	local decor = MapKit.Folder(model, "Decor")

	section("throw zone", id, function()
		buildThrowZone(ctx, hub)
	end)
	section("floor", id, function()
		buildFloor(ctx, hub)
	end)
	section("path", id, function()
		buildPath(ctx, hub)
	end)
	section("walls", id, function()
		buildWalls(ctx, hub)
	end)
	section("spawn", id, function()
		buildSpawn(ctx, hub)
	end)
	section("title", id, function()
		buildTitle(ctx, hub)
	end)
	section("channel", id, function()
		MapChannel.Build(ctx, channel)
	end)
	local archZ: { number } = {}
	section("zones", id, function()
		archZ = MapChannel.BuildZones(ctx, stations.Zones)
	end)
	section("pads", id, function()
		MapStations.Pads(ctx, stations.Pads)
	end)
	section("pedestals", id, function()
		MapStations.Pedestals(ctx, stations.Pedestals)
	end)
	section("eggs", id, function()
		MapStations.Eggs(ctx, stations.Eggs)
	end)
	section("portals", id, function()
		MapStations.Portals(ctx, stations.Portals)
	end)
	section("boards", id, function()
		MapStations.Boards(ctx, stations.Boards)
	end)
	section("hub decor", id, function()
		decorateHub(ctx, decor)
	end)
	section("channel decor", id, function()
		decorateChannel(ctx, decor, archZ)
	end)

	local parts = countParts(model)
	model:SetAttribute("PartCount", parts)
	if parts > MapBuilder.PartBudget then
		warn(string.format("[MapBuilder] %s uses %d parts (budget %d)", world.Name, parts, MapBuilder.PartBudget))
	end
	model.Parent = parent
	return model
end

-- Builds world 1 into a temporary folder, checks the naming contract clients rely on, destroys it.
-- Returns true when everything is in place (false and the first problem otherwise).
function MapBuilder.Validate(): (boolean, string?)
	local world = Worlds.Get(1)
	if not world then
		return false, "no world 1"
	end
	local folder = Instance.new("Folder")
	folder.Name = "MapBuilderValidate"
	local ok, result = pcall(MapBuilder.Build, world, folder)
	if not ok then
		folder:Destroy()
		return false, tostring(result)
	end
	local model = folder:FindFirstChild("World_1")
	local problem: string? = nil
	local function need(path: { string }, ...: string)
		if problem or not model then
			return
		end
		local node: Instance? = model
		for _, name in path do
			node = node and node:FindFirstChild(name)
		end
		if not node then
			problem = "missing " .. table.concat(path, "/")
			return
		end
		for _, child in { ... } do
			if not node:FindFirstChild(child, true) then
				problem = string.format("%s has no %s", table.concat(path, "/"), child)
				return
			end
		end
	end
	if not model then
		problem = "World_1 not built"
	end
	need({ "ThrowZone" })
	for _, pad in Training.ForWorld(1) do
		need({ "Pads", "Pad_" .. pad.Id }, "Label", "Gate", "Status", "Mult")
	end
	for _, glider in Gliders.ForWorld(1) do
		need({ "Pedestals", "Pedestal_" .. glider.Id }, "Base", "BuyPrompt", "Status", "Skill", "Price", "Display")
	end
	for _, relic in Relics.List do
		need({ "Pedestals", "Relic_" .. relic.Id }, "Base", "BuyPrompt", "Stock", "Title", "Bonus", "Price")
	end
	for _, egg in Eggs.ForWorld(1) do
		need({ "Eggs", "Egg_" .. egg.Id }, "Base", "HatchPrompt", "Name", "Price")
	end
	if Worlds.Get(2) then
		need({ "Portals", "Portal_2" }, "Frame", "PortalPrompt", "Name", "Requirement")
	end
	for _, entry in Map.Leaderboards do
		need({ "Boards", "Board_" .. entry.Stat }, "Board", "Title", "List")
	end
	for _, zone in Zones.ForWorld(1) do
		need({ "Zones", "ZoneSign_" .. zone.Id })
	end
	folder:Destroy()
	if problem then
		return false, problem
	end
	return true, nil
end

return MapBuilder
