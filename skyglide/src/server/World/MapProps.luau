--!strict
-- Decoration props for the procedural worlds, built from plain parts in the bright voxel style:
-- palms, bushes, flowers, rocks, beach umbrellas (Palm); volcanoes with lava falls, lava pools,
-- dark spires, a dragon statue (Volcano); a pirate ship, barrels, crates, treasure chests, skull
-- flags (Pirate); snowy pines, ice spikes, igloos, crystals (Ice). Every prop is a small Model of
-- anchored, non-colliding, non-queryable parts. `base` is a CFrame on the ground (its look vector
-- is the prop's facing), `s` scales the prop. Randomness comes from the caller's seeded Random so
-- a world always builds the same way.
local MapKit = require(script.Parent.MapKit)

local MapProps = {}

export type Ctx = {
	Pal: MapKit.Palette,
	Rng: Random,
	Shadow: boolean, -- big hub props cast shadows; far channel props don't
}

type Builder = (parent: Instance, base: CFrame, s: number, ctx: Ctx) -> ()

local hex = Color3.fromHex
local Part, Beam, Ball, Disc, Wedge = MapKit.Part, MapKit.Beam, MapKit.Ball, MapKit.Disc, MapKit.Wedge
local Shade, Tint = MapKit.Shade, MapKit.Tint
local NEON = Enum.Material.Neon

local FLOWER_COLORS = { hex("#FF5FA2"), hex("#FFD447"), hex("#FFFFFF"), hex("#FF6B4A"), hex("#B98CFF") }
local LAVA = hex("#FF6A1F")
local LAVA_HOT = hex("#FFC23D")
local GOLD = hex("#FFC93C")
local WOOD = hex("#9A6235")
local WOOD_DARK = hex("#6B4022")
local METAL = hex("#3B3F4A")
local SNOW = hex("#FFFFFF")
local ICE = hex("#BFEFFF")

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function deco(ctx: Ctx, material: Enum.Material?, transparency: number?): MapKit.PartOpts
	return { Shadow = ctx.Shadow, Material = material, Transparency = transparency }
end

-- Small detail parts never cast shadows.
local FLAT: MapKit.PartOpts = { Shadow = false }

local function yaw(rng: Random): CFrame
	return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

-- PALM ------------------------------------------------------------------------------------------

function MapProps.Palm(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Palm")
	local rng = ctx.Rng
	local pal = ctx.Pal
	local height = 17 * s * rng:NextNumber(0.85, 1.15)
	local bend = rng:NextNumber(-5, 5) * s
	local frame = base * yaw(rng)
	local prev = frame.Position
	local top = prev
	for i = 1, 3 do
		local t = i / 3
		local point = frame * Vector3.new(bend * t * t, height * t, 0)
		local color = if i % 2 == 0 then Shade(pal.Trunk, 0.15) else pal.Trunk
		local w = (2 - 0.3 * i) * s
		Beam(m, prev - (point - prev).Unit * 0.4 * s, point, w, w, color, deco(ctx))
		prev = point
		top = point
	end
	local leaves = 5
	local spin = rng:NextNumber(0, math.pi * 2)
	for k = 1, leaves do
		local a = spin + (k / leaves) * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = top + out * (7.5 * s) + Vector3.new(0, -3 * s, 0)
		local color = if k % 2 == 0 then Tint(pal.Leaves, 0.12) else pal.Leaves
		Beam(m, top + Vector3.new(0, 0.6 * s, 0), tip, 2.8 * s, 0.6 * s, color, deco(ctx))
	end
	Ball(m, 1.3 * s, CFrame.new(top + Vector3.new(0.8 * s, -0.9 * s, 0.3 * s)), hex("#6B4A2B"), FLAT)
	Ball(m, 1.3 * s, CFrame.new(top + Vector3.new(-0.5 * s, -1 * s, -0.7 * s)), hex("#7A5632"), FLAT)
end

function MapProps.Bush(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Bush")
	local rng = ctx.Rng
	local color = ctx.Pal.Leaves
	local offsets = { Vector3.new(0, 0.9, 0), Vector3.new(2.2, 0.5, 0.8), Vector3.new(-1.8, 0.4, -0.9) }
	local sizes = { 4.4, 3.2, 2.8 }
	for i, o in offsets do
		local c = if i == 2 then Tint(color, 0.1) elseif i == 3 then Shade(color, 0.1) else color
		Ball(m, sizes[i] * s * rng:NextNumber(0.9, 1.1), base * CFrame.new(o * s), c, FLAT)
	end
end

function MapProps.Flower(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Flowers")
	local rng = ctx.Rng
	for i = 1, 2 do
		local spot = base * CFrame.new((i - 1.5) * 1.6 * s, 0, rng:NextNumber(-0.8, 0.8) * s)
		local h = rng:NextNumber(1.4, 2.2) * s
		Beam(m, spot.Position, spot.Position + Vector3.new(0, h, 0), 0.3 * s, 0.3 * s, hex("#3FAF3A"), FLAT)
		local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
		Ball(m, 1.2 * s, CFrame.new(spot.Position + Vector3.new(0, h + 0.3 * s, 0)), color, FLAT)
	end
end

function MapProps.Rock(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Rock")
	local rng = ctx.Rng
	local color = ctx.Pal.Rock
	local tilt = CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15))
	Part(m, Vector3.new(4.2, 2.8, 3.4) * s, base * CFrame.new(0, 1 * s, 0) * tilt, color, deco(ctx))
	Part(m, Vector3.new(2.2, 1.6, 2) * s, base * CFrame.new(2.6 * s, 0.5 * s, 1.2 * s) * yaw(rng), Shade(color, 0.12), FLAT)
end

function MapProps.Umbrella(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Umbrella")
	local rng = ctx.Rng
	local colors = { hex("#FF5A5A"), hex("#3FA9FF"), hex("#FFB13D"), hex("#B65CFF") }
	local color = colors[rng:NextInteger(1, #colors)]
	local tilt = base * CFrame.Angles(0.12, 0, 0.05)
	local top = (tilt * CFrame.new(0, 9 * s, 0)).Position
	Beam(m, base.Position, top, 0.45 * s, 0.45 * s, SNOW, FLAT)
	Disc(m, 11 * s, 0.6 * s, tilt * CFrame.new(0, 8.6 * s, 0), color, deco(ctx))
	Disc(m, 6 * s, 0.7 * s, tilt * CFrame.new(0, 8.75 * s, 0), SNOW, FLAT)
	Ball(m, 0.9 * s, CFrame.new(top + Vector3.new(0, 0.3 * s, 0)), color, FLAT)
	-- beach towel beside it
	Part(m, Vector3.new(3.4, 0.12, 6.5) * s, base * CFrame.new(3.5 * s, 0.06, 1 * s) * CFrame.Angles(0, 0.3, 0), Tint(color, 0.35), FLAT)
end

-- VOLCANO -----------------------------------------------------------------------------------------

-- Huge stepped cone with a lava crater, neon lava falls (on the side `base` faces) and a smoke
-- plume (background landmark).
function MapProps.Volcano(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Volcano")
	local pal = ctx.Pal
	local tiers = 5
	local tierH = 26 * s
	local bottom = 300 * s
	local topD = bottom * 0.3
	for i = 0, tiers - 1 do
		local d = bottom + (topD - bottom) * (i / (tiers - 1))
		local color = if i % 2 == 0 then pal.Cliff else pal.CliffAlt
		Disc(m, d, tierH, base * CFrame.new(0, tierH * (i + 0.5), 0), color, { Shadow = false })
	end
	local crestY = tierH * tiers
	local lava = Disc(m, topD * 0.7, 1, base * CFrame.new(0, crestY + 0.2, 0), LAVA, { Material = NEON })
	MapKit.Smoke(lava, hex("#3A3236"), math.min(60 * s, 90), 1.2)
	MapKit.Light(lava, LAVA_HOT, 60, 3)
	-- lava falls down three sides: the tier corners are collinear, so a slab laid just outside
	-- that line reads as lava pouring over every step
	local rTop = topD / 2 - 3 * s
	local rFoot = bottom / 2 + (bottom - topD) / (2 * (tiers - 1))
	local push = 3 * s
	for k = 0, 2 do
		-- fanned around the facing direction (local -Z), so the falls face the viewer
		local a = math.rad(-90 + (k - 1) * 38)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = (base * CFrame.new(out * (rTop + push) + Vector3.new(0, crestY + 0.6, 0))).Position
		local to = (base * CFrame.new(out * (rFoot + push))).Position
		Beam(m, from, to, 12 * s, 2 * s, if k == 1 then LAVA_HOT else LAVA, { Material = NEON })
	end
end

function MapProps.LavaPool(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "LavaPool")
	Disc(m, 15 * s, 1, base * CFrame.new(0, 0.5, 0), ctx.Pal.Rock, FLAT)
	local lava = Disc(m, 11.5 * s, 1.1, base * CFrame.new(0, 0.6, 0), LAVA, { Material = NEON })
	if ctx.Shadow then -- hub pools glow; the many bank pools skip the light
		MapKit.Light(lava, LAVA_HOT, 18 * s, 2)
	end
end

-- Jagged dark rock spire with a glowing crack (the volcano world's "tree").
function MapProps.Spire(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Spire")
	local rng = ctx.Rng
	local color = ctx.Pal.Rock
	local frame = base * yaw(rng)
	local h = 0
	for i = 1, 3 do
		local w = (5.5 - i * 1.3) * s
		local seg = (7 - i) * s
		Part(m, Vector3.new(w, seg, w), frame * CFrame.new(rng:NextNumber(-0.4, 0.4) * s, h + seg / 2, 0) * CFrame.Angles(0, i * 0.5, rng:NextNumber(-0.08, 0.08)), if i == 2 then Shade(color, 0.2) else color, deco(ctx))
		h += seg
	end
	Part(m, Vector3.new(0.5 * s, h * 0.7, 0.3 * s), frame * CFrame.new(0, h * 0.4, -2.2 * s), LAVA, { Material = NEON })
end

-- Charred tree with two bare branches.
function MapProps.DeadTree(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "DeadTree")
	local rng = ctx.Rng
	local color = ctx.Pal.Trunk
	local frame = base * yaw(rng)
	local top = (frame * CFrame.new(0, 11 * s, 0)).Position
	Beam(m, frame.Position, top, 1.6 * s, 1.6 * s, color, deco(ctx))
	for side = -1, 1, 2 do
		local from = (frame * CFrame.new(0, 7.5 * s, 0)).Position
		local to = (frame * CFrame.new(side * 4.5 * s, 12.5 * s, rng:NextNumber(-1, 1) * s)).Position
		Beam(m, from, to, 0.9 * s, 0.9 * s, Shade(color, 0.15), FLAT)
	end
end

-- Dragon statue on a plinth, glowing eyes, wings spread (hub landmark of the volcano world).
function MapProps.DragonStatue(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "DragonStatue")
	local stone = hex("#3A3640")
	local dark = Shade(stone, 0.25)
	local opts = { Shadow = true, Solid = false }
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x * s, y * s, z * s)
	end
	Part(m, Vector3.new(14, 3, 20) * s, at(0, 1.5, 0), ctx.Pal.Cliff, { Shadow = true, Solid = true })
	Part(m, Vector3.new(14.6, 0.6, 20.6) * s, at(0, 3.2, 0), LAVA, { Material = NEON })
	-- legs and body
	for _, x in { -2.6, 2.6 } do
		for _, z in { -3.5, 3.5 } do
			Part(m, Vector3.new(2, 4, 2) * s, at(x, 5.5, z), dark, opts)
		end
	end
	Part(m, Vector3.new(7, 6, 11) * s, at(0, 10, 0), stone, opts)
	-- neck and head (facing -Z of base)
	Beam(m, at(0, 12, -4).Position, at(0, 17.5, -8.5).Position, 3.4 * s, 3.4 * s, stone, opts)
	Part(m, Vector3.new(4.4, 3.6, 6) * s, at(0, 18.5, -10), stone, opts)
	Part(m, Vector3.new(3, 2, 3.5) * s, at(0, 17.6, -14), dark, opts)
	for _, x in { -1.3, 1.3 } do
		Part(m, Vector3.new(0.8, 0.8, 0.4) * s, at(x, 19.2, -13.1), LAVA_HOT, { Material = NEON })
		Wedge(m, Vector3.new(0.8, 3, 2.4) * s, at(x, 21.6, -8.6) * CFrame.Angles(-0.35, 0, 0), dark, opts)
	end
	-- wings
	for _, side in { -1, 1 } do
		local root = at(side * 3.5, 12, 0)
		Wedge(m, Vector3.new(0.6, 10, 12) * s, root * CFrame.new(side * 5 * s, 4 * s, 1 * s) * CFrame.Angles(0, 0, side * -0.55), dark, opts)
	end
	-- tail curling to the ground
	Beam(m, at(0, 9, 5.5).Position, at(1.5, 5, 11).Position, 2.6 * s, 2.6 * s, stone, opts)
	Beam(m, at(1.5, 5, 11).Position, at(4, 3.6, 13).Position, 1.6 * s, 1.6 * s, dark, opts)
end

-- PIRATE ------------------------------------------------------------------------------------------

-- Moored pirate ship: hull, raked bow, stern castle, deck, mast, two sails and a skull flag.
-- `base` sits at the waterline, bow along base.LookVector.
function MapProps.Ship(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "PirateShip")
	local hull = hex("#6E3F22")
	local hullDark = hex("#4A2914")
	local deck = hex("#B98A55")
	local sail = hex("#F6F0E2")
	local opts = { Shadow = true }
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x * s, y * s, z * s)
	end
	Part(m, Vector3.new(14, 7, 38) * s, at(0, -1.5, 0), hullDark, opts)
	Part(m, Vector3.new(16, 4, 36) * s, at(0, 3.5, 1), hull, opts)
	Part(m, Vector3.new(16.4, 0.8, 36.4) * s, at(0, 5.2, 1), GOLD, { Shadow = false })
	Wedge(m, Vector3.new(14, 9, 10) * s, at(0, 1, -24) * CFrame.Angles(0, math.pi, 0), hull, opts)
	Part(m, Vector3.new(15, 0.6, 33) * s, at(0, 5.6, 2), deck, { Shadow = false })
	Part(m, Vector3.new(16, 6, 9) * s, at(0, 8, 14.5), hull, opts)
	local mastTop = at(0, 38, -1).Position
	Beam(m, at(0, 5, -1).Position, mastTop, 1.4 * s, 1.4 * s, WOOD_DARK, opts)
	Part(m, Vector3.new(18, 9, 0.5) * s, at(0, 16, -1.6), sail, opts)
	Part(m, Vector3.new(14, 7.5, 0.5) * s, at(0, 27.5, -1.6), sail, opts)
	-- cannons poking out of each side
	for _, side in { -1, 1 } do
		for _, z in { -6, 6 } do
			local from = at(side * 7.5, 3.5, z).Position
			Beam(m, from, from + (base.RightVector * side) * (2.5 * s), 1.2 * s, 1.2 * s, METAL, { Shadow = false })
		end
	end
	MapProps.SkullFlag(m, CFrame.new(mastTop) * (base - base.Position), 0.8 * s, ctx)
end

function MapProps.Barrel(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Barrels")
	local rng = ctx.Rng
	local count = rng:NextInteger(1, 3)
	for i = 1, count do
		local spot = base * CFrame.new((i - 1) * 3.4 * s - (count - 1) * 1.7 * s, 0, rng:NextNumber(-0.6, 0.6) * s)
		Disc(m, 3 * s, 4 * s, spot * CFrame.new(0, 2 * s, 0), WOOD, deco(ctx))
		Disc(m, 3.2 * s, 0.35 * s, spot * CFrame.new(0, 0.9 * s, 0), METAL, FLAT)
		Disc(m, 3.2 * s, 0.35 * s, spot * CFrame.new(0, 3.1 * s, 0), METAL, FLAT)
	end
end

function MapProps.Crate(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Crate")
	local frame = base * yaw(ctx.Rng)
	local size = 3.6 * s
	Part(m, Vector3.new(size, size, size), frame * CFrame.new(0, size / 2, 0), hex("#C68B4E"), deco(ctx))
	local face = frame * CFrame.new(0, size / 2, -size / 2 - 0.05)
	Part(m, Vector3.new(size * 1.3, 0.5 * s, 0.15), face * CFrame.Angles(0, 0, math.pi / 4), WOOD_DARK, FLAT)
	Part(m, Vector3.new(size * 1.3, 0.5 * s, 0.15), face * CFrame.Angles(0, 0, -math.pi / 4), WOOD_DARK, FLAT)
end

-- Open treasure chest spilling gold, with sparkles.
function MapProps.TreasureChest(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "TreasureChest")
	Part(m, Vector3.new(5, 3, 3.4) * s, base * CFrame.new(0, 1.5 * s, 0), WOOD, deco(ctx))
	Part(m, Vector3.new(5.2, 0.5, 3.6) * s, base * CFrame.new(0, 2.6 * s, 0), GOLD, FLAT)
	Part(m, Vector3.new(5, 0.8, 3.4) * s, base * CFrame.new(0, 3.9 * s, 2.3 * s) * CFrame.Angles(math.rad(70), 0, 0), WOOD_DARK, FLAT)
	local gold = Ball(m, 3.6 * s, base * CFrame.new(0, 2.8 * s, 0), GOLD, { Material = NEON })
	Ball(m, 2.2 * s, base * CFrame.new(2.6 * s, 0.6 * s, -1.2 * s), GOLD, { Material = NEON })
	MapKit.Sparkles(gold, GOLD, 3, 3)
end

function MapProps.SkullFlag(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "SkullFlag")
	local top = (base * CFrame.new(0, 12 * s, 0)).Position
	Beam(m, base.Position, top, 0.5 * s, 0.5 * s, WOOD_DARK, FLAT)
	local flag = Part(m, Vector3.new(6, 4, 0.2) * s, base * CFrame.new(3.2 * s, 10 * s, 0), hex("#15151C"), FLAT)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = MapKit.Surface(flag, "Skull", face, 20)
		MapKit.Text(gui, "Icon", "☠", 0.05, 0.9, SNOW, { Stroke = hex("#15151C") })
	end
end

-- ICE ---------------------------------------------------------------------------------------------

-- Voxel pine: trunk plus three stacked, alternately rotated foliage blocks with snow caps.
function MapProps.Pine(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Pine")
	local rng = ctx.Rng
	local frame = base * yaw(rng)
	local green = ctx.Pal.Leaves
	Part(m, Vector3.new(1.6, 4, 1.6) * s, frame * CFrame.new(0, 2 * s, 0), ctx.Pal.Trunk, deco(ctx))
	local y = 3.5 * s
	for i = 1, 3 do
		local w = (11 - i * 2.6) * s
		local h = 4.2 * s
		local rot = frame * CFrame.Angles(0, if i % 2 == 0 then math.pi / 4 else 0, 0)
		Part(m, Vector3.new(w, h, w), rot * CFrame.new(0, y + h / 2, 0), if i == 2 then Tint(green, 0.08) else green, deco(ctx))
		Part(m, Vector3.new(w * 0.86, 0.7 * s, w * 0.86), rot * CFrame.new(0, y + h + 0.3 * s, 0), SNOW, FLAT)
		y += h * 0.9
	end
end

function MapProps.IceSpike(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "IceSpikes")
	local rng = ctx.Rng
	for i = 1, 3 do
		local h = (if i == 1 then 13 else rng:NextNumber(6, 9)) * s
		local foot = (base * CFrame.new(rng:NextNumber(-2.5, 2.5) * s, 0, rng:NextNumber(-2.5, 2.5) * s)).Position
		local tip = foot + Vector3.new(rng:NextNumber(-2, 2) * s, h, rng:NextNumber(-2, 2) * s)
		local w = (if i == 1 then 2.6 else 1.7) * s
		Beam(m, foot - Vector3.new(0, 1, 0), tip, w, w, if i == 2 then Tint(ICE, 0.4) else ICE, { Material = Enum.Material.Ice, Transparency = 0.1, Shadow = false })
	end
end

function MapProps.Igloo(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Igloo")
	Ball(m, 16 * s, base, SNOW, deco(ctx, Enum.Material.Snow))
	local door = base * CFrame.new(0, 0, -8 * s)
	MapKit.FacingDisc(m, 7 * s, 6 * s, door, Tint(ICE, 0.5), deco(ctx, Enum.Material.Snow))
	MapKit.FacingDisc(m, 4.2 * s, 0.4, door * CFrame.new(0, 0, -3 * s), hex("#1E2533"), FLAT)
end

function MapProps.Crystal(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "Crystals")
	local rng = ctx.Rng
	local color = ctx.Pal.Accent
	for i = 1, 3 do
		local h = (if i == 1 then 7 else rng:NextNumber(3.5, 5)) * s
		local w = (if i == 1 then 2 else 1.3) * s
		local cf = base * CFrame.new((i - 2) * 1.8 * s, h * 0.4, rng:NextNumber(-1, 1) * s) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, math.pi / 4, 0)
		Part(m, Vector3.new(w, h, w), cf, if i == 1 then color else Tint(color, 0.35), { Material = if i == 1 then NEON else Enum.Material.Glass, Transparency = if i == 1 then 0.1 else 0.25 })
	end
end

function MapProps.SnowMound(parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local m = model(parent, "SnowMound")
	Ball(m, 6 * s, base, SNOW, deco(ctx, Enum.Material.Snow))
	Ball(m, 4 * s, base * CFrame.new(2.8 * s, 0, 1.2 * s), Tint(ICE, 0.7), FLAT)
end

-- THEME DISPATCH ----------------------------------------------------------------------------------

-- Role -> builders per prop family. Roles: Tree (tall), Bush, Small, Rock, Feature (hub set piece).
local FAMILIES: { [string]: { [string]: { Builder } } } = {
	Palm = {
		Tree = { MapProps.Palm },
		Bush = { MapProps.Bush },
		Small = { MapProps.Flower },
		Rock = { MapProps.Rock },
		Feature = { MapProps.Umbrella },
	},
	Volcano = {
		Tree = { MapProps.Spire, MapProps.DeadTree },
		Bush = { MapProps.Rock },
		Small = { MapProps.LavaPool },
		Rock = { MapProps.Rock, MapProps.Spire },
		Feature = { MapProps.LavaPool },
	},
	Pirate = {
		Tree = { MapProps.Palm },
		Bush = { MapProps.Barrel, MapProps.Bush },
		Small = { MapProps.Crate, MapProps.Barrel },
		Rock = { MapProps.Rock },
		Feature = { MapProps.TreasureChest, MapProps.SkullFlag },
	},
	Ice = {
		Tree = { MapProps.Pine },
		Bush = { MapProps.SnowMound },
		Small = { MapProps.Crystal },
		Rock = { MapProps.IceSpike },
		Feature = { MapProps.Igloo, MapProps.Crystal },
	},
}

-- Builds the family's prop for `role` (a random pick when the family has several).
function MapProps.Place(family: string, role: string, parent: Instance, base: CFrame, s: number, ctx: Ctx)
	local set = FAMILIES[family] or FAMILIES.Palm
	local builders = set[role] or set.Rock
	if #builders == 0 then
		return
	end
	local build = builders[ctx.Rng:NextInteger(1, #builders)]
	build(parent, base, s, ctx)
end

return MapProps
