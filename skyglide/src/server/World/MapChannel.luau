--!strict
-- The long glide channel of a world and its distance-zone arches. The channel runs from
-- Map.ChannelStartZ toward -Z for Flight.RenderMaxZ + 600 studs in Map.ChannelSegment-long
-- segments: water (Glass, or Neon lava), a bed, grass banks, checker cliffs and the plateau
-- behind them, a handful of long parts per segment. Checker blocks get longer with distance so
-- the far channel stays cheap. Zone arches stand at Z = ChannelStartZ - FlightSim.RenderZ(zone
-- distance), exactly where flights cross into the zone; the last zone gets a grand finish arch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Flight = require(Shared.Config.Flight)
local FlightSim = require(Shared.Sim.FlightSim)
local Format = require(Shared.Util.Format)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)

local MapKit = require(script.Parent.MapKit)

local MapChannel = {}

local HALF = Map.ChannelHalfWidth
local WATER_Y = Map.WaterY
MapChannel.BankTop = WATER_Y + 5 -- grass bank surface
MapChannel.CliffX = HALF + Map.BankWidth -- inner face of the cliffs
MapChannel.TopY = MapChannel.BankTop + Map.CliffHeight -- cliff top
MapChannel.PlateauY = MapChannel.TopY + 1 -- walkable surface behind the cliffs
MapChannel.OuterX = 330 -- plateau outer edge (worlds are 3200 apart)
MapChannel.SignBottom = 54 -- arch beams sit above typical flight altitude
MapChannel.SignTop = 68

local BANK_TOP = MapChannel.BankTop
local CLIFF_X = MapChannel.CliffX
local TOP_Y = MapChannel.TopY
local OUTER = MapChannel.OuterX
local CLIFF_T = 10
local PILLAR_X = HALF + 6

local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromHex("#15151C")
local PANEL = Color3.fromHex("#1B2140")
local GOLD = Color3.fromHex("#FFC93C")

-- Rendered channel length (studs).
function MapChannel.Length(): number
	return Flight.RenderMaxZ + 600
end

-- World-local Z of a zone's arch. The first zone starts at 0 m; its arch sits a few studs past the
-- Throw Zone edge so it frames the start instead of standing on it.
function MapChannel.ZoneZ(zone: Zones.Zone, world: Worlds.World): number
	return Map.ChannelStartZ - math.max(FlightSim.RenderZ(zone.Distance, world.DistanceScale), 6)
end

-- Checker block length for a stretch of cliff `d` studs down the channel. Every value divides a
-- segment into an even number of columns, so the pattern stays continuous across segments.
local function blockLength(d: number): number
	if d < 800 then
		return 12.5
	elseif d < 2800 then
		return 25
	elseif d < 5600 then
		return 50
	end
	return 100
end

local function segment(ctx: MapKit.Ctx, parent: Instance, index: number, d0: number, d1: number)
	local pal = ctx.Pal
	local at = function(x: number, y: number, z: number): Vector3
		return MapKit.At(ctx, x, y, z)
	end
	local lava = ctx.Theme.WaterMaterial == "Neon"
	local z0 = Map.ChannelStartZ - d0
	local z1 = Map.ChannelStartZ - d1
	local seg = MapKit.Group(parent, "Segment_" .. index)

	MapKit.Box(seg, at(-HALF, WATER_Y - 1, z1), at(HALF, WATER_Y, z0), pal.Water, {
		Material = MapKit.Material(ctx.Theme.WaterMaterial),
		Transparency = if lava then 0 else 0.15,
		Name = "Water",
	})
	MapKit.Box(seg, at(-HALF - 1, WATER_Y - 8, z1), at(HALF + 1, WATER_Y - 6, z0), MapKit.Shade(pal.Water, if lava then 0.6 else 0.45), {
		Solid = true,
		Shadow = false,
		Name = "Bed",
	})
	local foam = if lava then MapKit.Tint(pal.Water, 0.55) else WHITE
	local blockLen = blockLength(d0)
	for side = -1, 1, 2 do
		MapKit.Box(seg, at(side * HALF, WATER_Y - 7, z1), at(side * CLIFF_X, BANK_TOP - 1, z0), MapKit.Shade(pal.Cliff, 0.12), {
			Solid = true,
			Name = "Bank",
		})
		MapKit.Box(seg, at(side * (HALF - 0.6), BANK_TOP - 1, z1), at(side * CLIFF_X, BANK_TOP, z0), pal.CliffTop, {
			Solid = true,
			Name = "Grass",
		})
		MapKit.Box(seg, at(side * (HALF - 2.4), WATER_Y, z1), at(side * (HALF - 0.6), WATER_Y + 0.12, z0), foam, {
			Transparency = 0.25,
			Name = "Foam",
		})
		MapKit.CheckerWall(seg, at(side * CLIFF_X, BANK_TOP, z0), at(side * CLIFF_X, BANK_TOP, z1), Vector3.new(-side, 0, 0), Map.CliffHeight, pal.Cliff, pal.CliffAlt, pal.CliffTop, {
			Thickness = CLIFF_T,
			BlockLength = blockLen,
			Rows = 2,
			Below = 2,
		})
		MapKit.Box(seg, at(side * (CLIFF_X - 1), TOP_Y - 3, z1), at(side * OUTER, MapChannel.PlateauY, z0), pal.CliffTop, {
			Solid = true,
			Shadow = false,
			Name = "Plateau",
		})
	end
end

-- Water, banks, cliffs and plateau for the whole channel, plus the cap at the far end.
function MapChannel.Build(ctx: MapKit.Ctx, parent: Instance)
	local length = MapChannel.Length()
	local step = Map.ChannelSegment
	local count = math.ceil(length / step)
	for k = 0, count - 1 do
		segment(ctx, parent, k + 1, k * step, math.min(length, (k + 1) * step))
	end
	-- end wall across the channel (fog normally hides it)
	local pal = ctx.Pal
	local endZ = Map.ChannelStartZ - length
	local cap = MapKit.Group(parent, "EndCap")
	MapKit.Box(cap, MapKit.At(ctx, -OUTER, WATER_Y - 8, endZ - 14), MapKit.At(ctx, OUTER, MapChannel.PlateauY, endZ - 2), pal.Cliff, {
		Solid = true,
		Name = "Wall",
	})
	MapKit.CheckerWall(cap, MapKit.At(ctx, -CLIFF_X, WATER_Y - 1, endZ), MapKit.At(ctx, CLIFF_X, WATER_Y - 1, endZ), Vector3.new(0, 0, 1), TOP_Y - WATER_Y + 1, pal.Cliff, pal.CliffAlt, pal.CliffTop, {
		Thickness = 2,
		BlockLength = 14,
		Rows = 2,
	})
end

-- ZONE ARCHES -------------------------------------------------------------------------------------

local function signText(gui: SurfaceGui, name: string, text: string, y: number, h: number, color: Color3, strokeWidth: number)
	local label = MapKit.Text(gui, name, text, y, h, color, {
		Stroke = if MapKit.Luminance(color) > 0.9 then MapKit.StrokeColor else WHITE,
		StrokeThickness = strokeWidth,
	})
	label.Position = UDim2.fromScale(0.03, y)
	label.Size = UDim2.fromScale(0.94, h)
end

-- Neon line across the water where the zone begins, with a buoy at each end.
local function waterLine(ctx: MapKit.Ctx, sign: Model, z: number, color: Color3)
	MapKit.Box(sign, MapKit.At(ctx, -HALF, WATER_Y, z - 0.6), MapKit.At(ctx, HALF, WATER_Y + 0.15, z + 0.6), color, {
		Material = NEON,
		Transparency = 0.15,
		Name = "Line",
	})
	for side = -1, 1, 2 do
		MapKit.Ball(sign, 3, MapKit.CF(ctx, side * (HALF - 4), WATER_Y + 0.4, z), color, { Name = "Buoy" })
	end
end

local function pillar(ctx: MapKit.Ctx, sign: Model, x: number, z: number, width: number, top: number, color: Color3, band: Color3)
	local h = top - BANK_TOP
	MapKit.Part(sign, Vector3.new(width, h, width), MapKit.CF(ctx, x, BANK_TOP + h / 2, z), color, {
		Shadow = true,
		Name = "Pillar",
	})
	for _, y in { BANK_TOP + h * 0.3, BANK_TOP + h * 0.65 } do
		MapKit.Part(sign, Vector3.new(width + 0.8, 2.6, width + 0.8), MapKit.CF(ctx, x, y, z), band, { Name = "Band" })
	end
	MapKit.Part(sign, Vector3.new(width + 1, 3, width + 1), MapKit.CF(ctx, x, top + 1.5, z), band, {
		Material = NEON,
		Name = "Cap",
	})
end

-- Sign panel facing the hub (+Z) with a coloured border; returns the panel and its SurfaceGui.
local function panel(ctx: MapKit.Ctx, sign: Model, z: number, width: number, bottom: number, top: number, border: Color3, ppsHint: number): (Part, SurfaceGui)
	local h = top - bottom
	local center = MapKit.At(ctx, 0, bottom + h / 2, z)
	local board = MapKit.Part(sign, Vector3.new(width, h, 2.4), MapKit.Facing(center, Vector3.zAxis), PANEL, {
		Shadow = true,
		Name = "Panel",
	})
	MapKit.Part(sign, Vector3.new(width + 3, h + 3, 2), MapKit.Facing(center - Vector3.new(0, 0, 0.6), Vector3.zAxis), border, {
		Name = "Border",
	})
	local gui = MapKit.Surface(board, "Sign", Enum.NormalId.Front, ppsHint)
	return board, gui
end

local function arch(ctx: MapKit.Ctx, sign: Model, zone: Zones.Zone, z: number)
	local color = MapKit.Hex(zone.Color)
	local stone = ctx.Pal.Stone
	for side = -1, 1, 2 do
		pillar(ctx, sign, side * PILLAR_X, z, 5, MapChannel.SignTop, stone, color)
	end
	local board, gui = panel(ctx, sign, z, PILLAR_X * 2 + 10, MapChannel.SignBottom, MapChannel.SignTop, color, 10)
	signText(gui, "Name", string.upper(zone.Name), 0.04, 0.6, color, 4)
	signText(gui, "Distance", Format.Meters(zone.Distance), 0.66, 0.3, WHITE, 3)
	sign.PrimaryPart = board
	waterLine(ctx, sign, z, color)
end

-- Grand finish arch for the last zone: chequered pillars and flag row, a big rainbow sign and a
-- teaser for the next world.
local function finishArch(ctx: MapKit.Ctx, sign: Model, zone: Zones.Zone, z: number)
	local color = MapKit.Hex(zone.Color)
	local top = MapChannel.SignTop + 8
	local bottom = MapChannel.SignBottom - 4
	local x = PILLAR_X + 2
	for side = -1, 1, 2 do
		local h = top - BANK_TOP
		MapKit.Part(sign, Vector3.new(8, h, 8), MapKit.CF(ctx, side * x, BANK_TOP + h / 2, z), WHITE, {
			Shadow = true,
			Name = "Pillar",
		})
		for i = 0, 3 do
			local y = BANK_TOP + h * (0.12 + i * 0.22)
			MapKit.Part(sign, Vector3.new(8.6, h * 0.11, 8.6), MapKit.CF(ctx, side * x, y, z), BLACK, { Name = "Check" })
		end
		local cap = MapKit.Part(sign, Vector3.new(9.5, 4, 9.5), MapKit.CF(ctx, side * x, top + 2, z), GOLD, {
			Material = NEON,
			Name = "Cap",
		})
		MapKit.Sparkles(cap, GOLD, 8, 9)
	end
	local width = x * 2 + 14
	local board, gui = panel(ctx, sign, z, width, bottom, top, GOLD, 10)
	sign.PrimaryPart = board
	local title = MapKit.Text(gui, "Title", "🏁 END OF THE RIVER 🏁", 0.03, 0.42, WHITE, { StrokeThickness = 5 })
	MapKit.Gradient(title, MapKit.Rainbow)
	signText(gui, "Name", string.upper(zone.Name) .. "  •  " .. Format.Meters(zone.Distance), 0.47, 0.24, color, 3)
	local nextWorld = Worlds.Get(ctx.World.Id + 1)
	local teaser = if nextWorld then nextWorld.Name .. " awaits!" else "You reached the edge of the sky!"
	signText(gui, "Next", teaser, 0.73, 0.23, GOLD, 3)
	-- chequered flag row on top of the panel
	local cells = 8
	local cellW = width / cells
	for i = 0, cells - 1 do
		local cx = -width / 2 + cellW * (i + 0.5)
		MapKit.Part(sign, Vector3.new(cellW, 4, 2.6), MapKit.CF(ctx, cx, top + 3.5, z), if i % 2 == 0 then BLACK else WHITE, {
			Name = "Flag",
		})
	end
	-- chequered finish line across the water
	MapKit.Box(sign, MapKit.At(ctx, -HALF, WATER_Y, z - 2), MapKit.At(ctx, HALF, WATER_Y + 0.15, z + 2), WHITE, { Name = "Finish" })
	local tiles = 8
	local tileW = HALF * 2 / tiles
	for i = 0, tiles - 1 do
		for row = 0, 1 do
			if (i + row) % 2 == 0 then
				local cx = -HALF + tileW * (i + 0.5)
				MapKit.Part(sign, Vector3.new(tileW, 0.2, 2), MapKit.CF(ctx, cx, WATER_Y + 0.12, z - 1 + row * 2), BLACK, { Name = "FinishTile" })
			end
		end
	end
end

-- One ZoneSign_<zoneId> model per zone of the world (see docs/DESIGN.md §5).
function MapChannel.BuildZones(ctx: MapKit.Ctx, parent: Instance): { number }
	local zones = Zones.ForWorld(ctx.World.Id)
	local positions = {}
	for i, zone in zones do
		local z = MapChannel.ZoneZ(zone, ctx.World)
		local sign = Instance.new("Model")
		sign.Name = "ZoneSign_" .. zone.Id
		sign:SetAttribute("Zone", zone.Id)
		sign:SetAttribute("Distance", zone.Distance)
		if i == #zones then
			finishArch(ctx, sign, zone, z)
		else
			arch(ctx, sign, zone, z)
		end
		sign.Parent = parent
		table.insert(positions, z)
	end
	return positions
end

return MapChannel
