--!strict
-- Shared part-building kit for the Visual factories (GliderFactory, PetFactory, EggFactory).
-- Every model is built around an invisible "Root" part at the model origin. Parts get display-only
-- physics flags (no collision, queries, touches or shadows; massless; smooth surfaces) and
-- Finish() either anchors every part or welds every part to Root. Triangles are built from two
-- WedgeParts, so shapes need no meshes and no uploaded assets. Pure Instance code: server + client.
local FactoryKit = {}

export type Builder = {
	Model: Model,
	Root: Part,
	Parts: { BasePart },
}

export type Kind = "Block" | "Ball" | "Cylinder" | "Wedge"

FactoryKit.Sides = { -1, 1 }

local DEFAULT_MATERIAL = Enum.Material.SmoothPlastic
local MIN_SIZE = 0.01 -- smallest part dimension we create (Roblox clamps at 0.001)
local DEGENERATE = 0.004 -- a triangle half thinner than this is skipped

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- "#RRGGBB" -> Color3, falling back when the string is missing or malformed.
function FactoryKit.Color(hex: string?, fallback: Color3): Color3
	if type(hex) ~= "string" then
		return fallback
	end
	local ok, color = pcall(Color3.fromHex, hex)
	if ok then
		return color
	end
	return fallback
end

-- amount > 0 blends toward white, amount < 0 toward black.
function FactoryKit.Shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(WHITE, math.min(amount, 1))
	end
	return color:Lerp(BLACK, math.min(-amount, 1))
end

-- Stable small hash for deterministic per-definition variation (spot layouts etc.).
function FactoryKit.Hash(text: string): number
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 2147483647
	end
	return h
end

local function applyFlags(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

function FactoryKit.New(name: string, rootSize: number): Builder
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * math.max(0.05, rootSize)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	applyFlags(root)
	root.Parent = model
	model.PrimaryPart = root
	return { Model = model, Root = root, Parts = { root } }
end

function FactoryKit.Part(b: Builder, kind: Kind, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local part: BasePart
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		if kind == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		part = p
	end
	part.Name = kind
	part.Size = Vector3.new(math.max(size.X, MIN_SIZE), math.max(size.Y, MIN_SIZE), math.max(size.Z, MIN_SIZE))
	part.CFrame = cf
	part.Color = color
	part.Material = material or DEFAULT_MATERIAL
	applyFlags(part)
	part.Parent = b.Model
	table.insert(b.Parts, part)
	return part
end

function FactoryKit.Block(b: Builder, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return FactoryKit.Part(b, "Block", size, cf, color, material)
end

function FactoryKit.Ball(b: Builder, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): BasePart
	return FactoryKit.Part(b, "Ball", Vector3.one * diameter, CFrame.new(position), color, material)
end

-- CFrame at the midpoint of from -> to, looking at `to` (safe when the segment is vertical).
local function along(from: Vector3, to: Vector3, up: Vector3?): CFrame
	local mid = (from + to) / 2
	local dir = to - from
	if dir.Magnitude < 1e-6 then
		return CFrame.new(mid)
	end
	local u = up or Vector3.yAxis
	if math.abs(dir.Unit:Dot(u.Unit)) > 0.995 then
		u = if math.abs(dir.Unit.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	end
	return CFrame.lookAt(mid, to, u)
end
FactoryKit.Along = along

-- Cylinder from one point to another.
function FactoryKit.Rod(b: Builder, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local length = (to - from).Magnitude
	return FactoryKit.Part(b, "Cylinder", Vector3.new(length, diameter, diameter), along(from, to) * CFrame.Angles(0, math.pi / 2, 0), color, material)
end

-- Flat bar from one point to another; `up` orients the bar's thickness (height) axis.
function FactoryKit.Bar(b: Builder, from: Vector3, to: Vector3, width: number, height: number, color: Color3, material: Enum.Material?, up: Vector3?): BasePart
	local length = (to - from).Magnitude
	return FactoryKit.Part(b, "Block", Vector3.new(width, height, length), along(from, to, up), color, material)
end

-- Flat disc (cylinder) centred on `center` with its faces pointing along `axis`.
function FactoryKit.Disc(b: Builder, center: Vector3, axis: Vector3, diameter: number, thickness: number, color: Color3, material: Enum.Material?): BasePart
	return FactoryKit.Part(b, "Cylinder", Vector3.new(thickness, diameter, diameter), along(center, center + axis) * CFrame.Angles(0, math.pi / 2, 0), color, material)
end

-- Solid triangle p1-p2-p3 with the given thickness (centred on the triangle's plane), built from
-- up to two WedgePart halves split at the foot of the altitude onto the longest edge. Right
-- triangles therefore cost a single wedge.
function FactoryKit.Tri(b: Builder, p1: Vector3, p2: Vector3, p3: Vector3, thickness: number, color: Color3, material: Enum.Material?)
	local a, c, d = p1, p2, p3
	local ab, ac, bc = c - a, d - a, d - c
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		d, a = a, d
	elseif acd > bcd and acd > abd then
		a, c = c, a
	end
	ab, ac, bc = c - a, d - a, d - c
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-7 or bc.Magnitude < 1e-6 then
		return
	end
	local right = normal.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < DEGENERATE then
		return
	end
	local d1 = math.abs(ab:Dot(back))
	local d2 = math.abs(ac:Dot(back))
	if d1 > DEGENERATE then
		FactoryKit.Part(b, "Wedge", Vector3.new(thickness, height, d1), CFrame.fromMatrix((a + c) / 2, right, up, back), color, material)
	end
	if d2 > DEGENERATE then
		FactoryKit.Part(b, "Wedge", Vector3.new(thickness, height, d2), CFrame.fromMatrix((a + d) / 2, -right, up, -back), color, material)
	end
end

-- Pointed "cone" from two crossed triangles (horns, beaks, spikes); reads as round from most angles.
function FactoryKit.Spike(b: Builder, base: Vector3, tip: Vector3, radius: number, color: Color3, material: Enum.Material?)
	local dir = tip - base
	if dir.Magnitude < 1e-6 then
		return
	end
	local axis = dir.Unit
	local ref = if math.abs(axis.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local a1 = axis:Cross(ref).Unit
	local a2 = axis:Cross(a1).Unit
	local t = radius * 0.5
	FactoryKit.Tri(b, base - a1 * radius, base + a1 * radius, tip, t, color, material)
	FactoryKit.Tri(b, base - a2 * radius, base + a2 * radius, tip, t, color, material)
end

function FactoryKit.Light(b: Builder, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = color
	light.Brightness = brightness
	light.Range = math.clamp(range, 2, 60)
	light.Shadows = false
	light.Parent = b.Root
	return light
end

-- Anchor everything, or leave everything unanchored and welded to Root.
function FactoryKit.Finish(b: Builder, anchored: boolean): Model
	for _, part in b.Parts do
		part.Anchored = anchored
		if not anchored and part ~= b.Root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = b.Root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return b.Model
end

-- Template cache: build once per key, hand out clones (cheap) afterwards. Bounded so callers
-- that pass many distinct sizes can't grow it forever.
export type Cache = { Map: { [string]: Model }, Count: number, Limit: number }

function FactoryKit.NewCache(limit: number): Cache
	return { Map = {}, Count = 0, Limit = limit }
end

function FactoryKit.Cached(cache: Cache, key: string, build: () -> Model): Model
	local template = cache.Map[key]
	if not template then
		if cache.Count >= cache.Limit then
			for _, model in cache.Map do
				model:Destroy()
			end
			table.clear(cache.Map)
			cache.Count = 0
		end
		template = build()
		cache.Map[key] = template
		cache.Count += 1
	end
	return template:Clone()
end

return FactoryKit
