--!strict
-- Part-built gliders (no meshes, no uploaded assets). Shared: the server builds pedestal displays and
-- the held glider, the client builds flight models and ViewportFrame previews.
--
-- Contract: Model.PrimaryPart = "Root" (invisible) at the glider's centre. The nose points along
-- Root's LookVector (local -Z), wings span local X, +Y is up, nose-to-tail is about `length` studs.
-- anchored = true -> every part anchored (move with PivotTo); false -> nothing anchored, every part
-- welded to Root (held in a hand). Glow = true adds Neon accents and a soft PointLight.
-- Shapes are authored in units of `length` with the nose at z = -0.5 and the tail at z = +0.5.
local Gliders = require(script.Parent.Parent.Definitions.Gliders)
local Relics = require(script.Parent.Parent.Definitions.Relics)
local Kit = require(script.Parent.FactoryKit)

local GliderFactory = {}

export type Visual = { Shape: string, Primary: string, Secondary: string, Glow: boolean? }

type Ctx = {
	b: Kit.Builder,
	L: number, -- length in studs
	T: number, -- paper thickness in studs
	P: Color3, -- primary
	S: Color3, -- secondary
	Glow: boolean,
	Accent: Enum.Material, -- Neon when glowing
}

local Sides = Kit.Sides
local WOOD = Color3.fromRGB(112, 80, 50)

-- Point in glider units -> studs.
local function at(c: Ctx, x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z) * c.L
end

local function tri(c: Ctx, p1: Vector3, p2: Vector3, p3: Vector3, color: Color3, material: Enum.Material?, thick: number?)
	Kit.Tri(c.b, p1, p2, p3, (thick or 1) * c.T, color, material)
end

local function bar(c: Ctx, from: Vector3, to: Vector3, width: number, color: Color3, material: Enum.Material?)
	Kit.Bar(c.b, from, to, width * c.L, c.T * 1.3, color, material)
end

-- Classic paper plane: two swept wings folded off a keel, turned-up winglets, centre crease.
local function dart(c: Ctx)
	local P, S = c.P, c.S
	for _, s in Sides do
		local tip = at(c, 0.4 * s, 0.07, 0.5)
		tri(c, at(c, 0, 0, -0.5), at(c, 0, 0, 0.5), tip, P) -- right angle at the tail root: one wedge
		tri(c, at(c, 0.3 * s, 0.07, 0.25), tip, at(c, 0.4 * s, 0.18, 0.5), S, c.Accent) -- winglet
		-- stripe across the wing, parallel to the trailing edge
		local y1, y2 = 0.07 * 0.05 / 0.4, 0.07 * 0.31 / 0.4
		bar(c, at(c, 0.05 * s, y1, 0.36) + Vector3.yAxis * c.T * 0.35, at(c, 0.31 * s, y2, 0.36) + Vector3.yAxis * c.T * 0.35, 0.05, S)
		if c.Glow then
			bar(c, at(c, 0.02 * s, 0, 0.495), at(c, 0.4 * s, 0.07, 0.495), 0.02, S, c.Accent)
		end
	end
	tri(c, at(c, 0, 0, -0.4), at(c, 0, 0, 0.5), at(c, 0, -0.13, 0.5), Kit.Shade(P, -0.12), nil, 1.2) -- keel
	bar(c, at(c, 0, 0, -0.46) + Vector3.yAxis * c.T * 0.4, at(c, 0, 0, 0.5) + Vector3.yAxis * c.T * 0.4, 0.018, S)
end

-- Broad paper glider: blunt nose, wide straight wings with folded leading edges and tip fins.
local function wide(c: Ctx)
	local P, S = c.P, c.S
	local slope = 0.16 -- dihedral rise per unit of span
	local dih = math.atan(slope)
	local root, tipX = 0.1, 0.66
	local function lift(x: number): number
		return (math.abs(x) - root) * slope
	end
	Kit.Block(c.b, Vector3.new(root * 2 * c.L, c.T * 1.2, 0.8 * c.L), CFrame.new(at(c, 0, 0, 0.1)), P)
	for _, s in Sides do
		-- nose cap (right triangle) and the swept leading-edge triangle of the wing
		tri(c, at(c, 0, 0, -0.5), at(c, 0, 0, -0.3), at(c, root * s, 0, -0.3), P, nil, 1.2)
		tri(c, at(c, root * s, 0, -0.3), at(c, root * s, 0, -0.04), at(c, tipX * s, lift(tipX), -0.04), P)
		-- wing panel behind it
		local cx = (root + tipX) / 2
		local cf = CFrame.new(at(c, cx * s, lift(cx), 0.2)) * CFrame.Angles(0, 0, dih * s)
		Kit.Block(c.b, Vector3.new((tipX - root) / math.cos(dih) * c.L, c.T, 0.48 * c.L), cf, P)
		-- folded leading edge and turned-up tip fin
		bar(c, at(c, root * s, 0, -0.3) + Vector3.yAxis * c.T * 0.4, at(c, tipX * s, lift(tipX), -0.04) + Vector3.yAxis * c.T * 0.4, 0.05, S, c.Accent)
		local fin = CFrame.new(at(c, tipX * s, lift(tipX) + 0.04, 0.2))
		Kit.Block(c.b, Vector3.new(c.T, 0.08 * c.L, 0.44 * c.L), fin, S, c.Accent)
	end
	Kit.Block(c.b, Vector3.new(root * 2 * c.L, c.T * 2.2, 0.1 * c.L), CFrame.new(at(c, 0, 0, -0.25)), S) -- nose fold
	tri(c, at(c, 0, 0, -0.25), at(c, 0, 0, 0.5), at(c, 0, -0.11, 0.5), Kit.Shade(P, -0.12), nil, 1.2) -- keel
end

-- Leaf: two halves folded up along a midrib, rounded front edge, stem at the tail.
local function leaf(c: Ctx)
	local P, S = c.P, c.S
	local function y(x: number): number
		return math.abs(x) * 0.22
	end
	local tip, mid, base = at(c, 0, 0, -0.5), at(c, 0, 0, -0.04), at(c, 0, 0, 0.3)
	for _, s in Sides do
		local color = if s > 0 then P else Kit.Shade(P, -0.08)
		local w = at(c, 0.26 * s, y(0.26), -0.04)
		tri(c, tip, w, mid, color)
		tri(c, mid, w, base, color)
		tri(c, tip, at(c, 0.19 * s, y(0.19), -0.3), w, color) -- rounds the front edge
		tri(c, w, at(c, 0.2 * s, y(0.2), 0.17), base, color) -- and the back edge
		-- side vein
		bar(c, at(c, 0, 0, -0.1) + Vector3.yAxis * c.T * 0.4, at(c, 0.19 * s, y(0.19), -0.24) + Vector3.yAxis * c.T * 0.4, 0.016, S, c.Accent)
	end
	bar(c, tip + Vector3.yAxis * c.T * 0.4, base + Vector3.yAxis * c.T * 0.4, 0.024, S, c.Accent) -- midrib
	Kit.Rod(c.b, base, at(c, 0, 0.04, 0.5), 0.035 * c.L, S) -- stem
end

-- Feather: asymmetric vanes on a quill, coloured tip, soft down at the base.
local function feather(c: Ctx)
	local P, S = c.P, c.S
	local function y(x: number): number
		return -math.abs(x) * 0.14 -- vanes droop a little (cambered)
	end
	local tip, base = at(c, 0, 0, -0.5), at(c, 0, 0, 0.28)
	local spec = { { s = 1, w = 0.13, wz = -0.12, a = 0.1, az = -0.36 }, { s = -1, w = 0.19, wz = -0.06, a = 0.13, az = -0.33 } }
	for _, v in spec do
		local s = v.s
		local w = at(c, v.w * s, y(v.w), v.wz)
		local m = at(c, 0, 0, v.wz)
		tri(c, tip, w, m, P)
		tri(c, m, w, base, P)
		tri(c, tip, at(c, v.a * s, y(v.a), v.az), w, S) -- coloured tip
		tri(c, at(c, 0, 0, 0.2), at(c, 0, 0, 0.36), at(c, 0.08 * s, -0.01, 0.36), Kit.Shade(P, 0.3)) -- down
	end
	Kit.Rod(c.b, tip + Vector3.yAxis * c.T * 0.5, base + Vector3.yAxis * c.T * 0.5, 0.026 * c.L, Kit.Shade(S, -0.15), c.Accent)
	Kit.Rod(c.b, base, at(c, 0, 0.01, 0.5), 0.04 * c.L, Kit.Shade(S, 0.45))
end

-- Diamond kite: four checkered panels, cross spars, string tail with bows.
local function kite(c: Ctx)
	local P, S = c.P, c.S
	local nose, cross, tail = at(c, 0, 0, -0.5), at(c, 0, 0, -0.22), at(c, 0, 0, 0.2)
	for _, s in Sides do
		local side = at(c, 0.3 * s, 0.04, -0.22)
		tri(c, nose, side, cross, if s > 0 then P else S, Enum.Material.Fabric)
		tri(c, cross, side, tail, if s > 0 then S else P, Enum.Material.Fabric)
	end
	local up = Vector3.yAxis * c.T * 1.2
	Kit.Rod(c.b, nose + up, tail + up, 0.024 * c.L, WOOD)
	Kit.Rod(c.b, at(c, -0.3, 0.04, -0.22) + up, at(c, 0.3, 0.04, -0.22) + up, 0.024 * c.L, WOOD)
	local stringEnd = at(c, 0, -0.04, 0.5)
	Kit.Rod(c.b, tail, stringEnd, 0.012 * c.L, Kit.Shade(S, 0.4))
	for i = 1, 3 do
		local t = (i - 0.4) / 3
		local p = tail:Lerp(stringEnd, t)
		Kit.Diamond(c.b, p, Vector3.yAxis, 0.075 * c.L, c.T * 1.2, if i % 2 == 1 then S else P, c.Accent)
	end
end

-- Origami crane: keel body, raised wings with folded flaps, long neck with a bent head, tail.
local function crane(c: Ctx)
	local P, S = c.P, c.S
	local slope = 0.29
	for _, s in Sides do
		local rf, rb, tp = at(c, 0.02 * s, 0.02, -0.14), at(c, 0.02 * s, 0.02, 0.16), at(c, 0.5 * s, 0.02 + 0.48 * slope, 0.06)
		tri(c, rf, rb, tp, P)
		local up = Vector3.yAxis * c.T * 0.9
		tri(c, at(c, 0.02 * s, 0.02, -0.11) + up, at(c, 0.02 * s, 0.02, 0.16) + up, at(c, 0.2 * s, 0.02 + 0.18 * slope, 0.16) + up, S, c.Accent)
	end
	local dark = Kit.Shade(P, -0.1)
	tri(c, at(c, 0, 0.02, -0.18), at(c, 0, 0.02, 0.2), at(c, 0, -0.12, 0.02), dark, nil, 1.4) -- body
	tri(c, at(c, 0, -0.06, -0.06), at(c, 0, 0.03, -0.22), at(c, 0, 0.23, -0.42), P, nil, 1.6) -- neck
	tri(c, at(c, 0, 0.24, -0.43), at(c, 0, 0.17, -0.4), at(c, 0, 0.11, -0.5), S, c.Accent, 1.6) -- head
	tri(c, at(c, 0, -0.06, 0.06), at(c, 0, 0.03, 0.22), at(c, 0, 0.21, 0.5), P, nil, 1.6) -- tail
end

-- Paper fighter jet: needle fuselage, delta wings, canards, canted twin fins, canopy.
local function jet(c: Ctx)
	local P, S = c.P, c.S
	for _, s in Sides do
		tri(c, at(c, 0, 0, -0.5), at(c, 0.065 * s, 0, 0.5), at(c, 0, 0, 0.5), P, nil, 1.3)
		tri(c, at(c, 0.06 * s, 0, -0.12), at(c, 0.06 * s, 0, 0.42), at(c, 0.4 * s, -0.03, 0.42), P)
		tri(c, at(c, 0.06 * s, 0, -0.34), at(c, 0.06 * s, 0, -0.22), at(c, 0.17 * s, 0, -0.22), S)
		tri(c, at(c, 0.07 * s, 0, 0.24), at(c, 0.07 * s, 0, 0.5), at(c, 0.11 * s, 0.17, 0.5), S)
		bar(c, at(c, 0.06 * s, 0, -0.12) + Vector3.yAxis * c.T * 0.4, at(c, 0.4 * s, -0.03, 0.42) + Vector3.yAxis * c.T * 0.4, 0.022, S, c.Accent)
	end
	tri(c, at(c, 0, 0, -0.35), at(c, 0, 0, 0.45), at(c, 0, -0.07, 0.45), Kit.Shade(P, -0.12), nil, 1.2) -- keel
	local canopy = Vector3.new(0.06, 0.05, 0.16) * c.L
	Kit.Part(c.b, "Wedge", canopy, CFrame.new(at(c, 0, 0, -0.24) + Vector3.yAxis * (canopy.Y / 2 + c.T * 0.5)), Kit.Shade(S, -0.1), c.Accent)
	if c.Glow then
		Kit.Block(c.b, Vector3.new(0.1, 0.035, 0.02) * c.L, CFrame.new(at(c, 0, 0, 0.5)), S, Enum.Material.Neon)
	end
end

-- Bat/dragon wings: membranes fanned from the wrist with a scalloped trailing edge, finger bones on
-- top, a slim body with a round head and a spade-tipped tail.
local function bat(c: Ctx)
	local P, S = c.P, c.S
	local bone = if c.Glow then S else Kit.Shade(P, -0.35)
	local up = Vector3.yAxis * c.T
	for _, s in Sides do
		local shoulder, wrist = at(c, 0.04 * s, 0.02, -0.2), at(c, 0.27 * s, 0.13, -0.2)
		local tip1, notch1 = at(c, 0.62 * s, 0.05, -0.04), at(c, 0.42 * s, 0.07, 0.07)
		local tip2, notch2 = at(c, 0.45 * s, 0.04, 0.3), at(c, 0.24 * s, 0.05, 0.19)
		local rear = at(c, 0.04 * s, 0.02, 0.3)
		local dark = Kit.Shade(P, -0.1)
		tri(c, wrist, rear, shoulder, P) -- right angle at the shoulder: one wedge
		tri(c, wrist, tip1, notch1, P)
		tri(c, wrist, notch1, tip2, dark)
		tri(c, wrist, tip2, notch2, P)
		tri(c, wrist, notch2, rear, dark)
		Kit.Rod(c.b, shoulder + up, wrist + up, 0.034 * c.L, bone, c.Accent)
		Kit.Rod(c.b, wrist + up, tip1 + up, 0.028 * c.L, bone, c.Accent)
		Kit.Rod(c.b, wrist + up, tip2 + up, 0.022 * c.L, bone, c.Accent)
	end
	local body = Kit.Shade(P, -0.25)
	Kit.Rod(c.b, at(c, 0, 0.03, -0.36), at(c, 0, 0.03, 0.42), 0.05 * c.L, body)
	Kit.Ball(c.b, 0.1 * c.L, at(c, 0, 0.035, -0.42), body)
	Kit.Diamond(c.b, at(c, 0, 0.03, 0.45), Vector3.yAxis, 0.08 * c.L, c.T * 1.4, S, c.Accent) -- spade tail
end

-- Snowflake star: six-point core, three crossing arms with branch ticks.
local function star(c: Ctx)
	local P, S = c.P, c.S
	local r = 0.2
	for k = 0, 1 do
		local pts = {}
		for i = 0, 2 do
			local a = math.pi * (1 - k) + i * math.pi * 2 / 3 -- one triangle points -Z, the other +Z
			table.insert(pts, at(c, math.sin(a) * r, 0, math.cos(a) * r))
		end
		tri(c, pts[1], pts[2], pts[3], S, c.Accent, 1.6)
	end
	for i = 0, 2 do
		local a = i * math.pi / 3
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		Kit.Bar(c.b, -dir * 0.5 * c.L, dir * 0.5 * c.L, 0.055 * c.L, c.T * 1.3, P)
		for _, s in Sides do
			local mid = dir * 0.33 * s * c.L
			local across = Vector3.new(-dir.Z, 0, dir.X)
			Kit.Bar(c.b, mid - across * 0.09 * c.L, mid + across * 0.09 * c.L, 0.04 * c.L, c.T * 1.1, P)
		end
	end
end

-- Ornate golden phoenix relic: layered swept wings, flame tail, jewel core in a gold setting.
local function relic(c: Ctx)
	local P, S = c.P, c.S
	local deep = Kit.Shade(P, -0.18)
	local layers = {
		{ y = 0, f = -0.2, b = 0.06, x = 0.56, color = P },
		{ y = -0.012, f = -0.1, b = 0.16, x = 0.45, color = deep },
		{ y = -0.024, f = 0.0, b = 0.26, x = 0.32, color = S },
	}
	for _, s in Sides do
		for i, l in layers do
			local lift = 0.3 * l.x
			tri(c, at(c, 0.05 * s, l.y, l.f), at(c, 0.05 * s, l.y, l.b), at(c, l.x * s, l.y + lift, l.b), l.color, if i == 3 then c.Accent else nil)
		end
		-- side tail plume
		tri(c, at(c, 0.02 * s, -0.01, 0.18), at(c, 0.2 * s, 0.03, 0.5), at(c, 0.09 * s, -0.01, 0.2), deep)
		-- centre tail flame (right triangle per side)
		tri(c, at(c, 0, -0.005, 0.16), at(c, 0, -0.005, 0.5), at(c, 0.07 * s, -0.005, 0.16), S, c.Accent)
		-- pointed crest at the nose
		tri(c, at(c, 0, 0.01, -0.5), at(c, 0, 0.01, -0.22), at(c, 0.07 * s, 0.01, -0.22), P, nil, 1.6)
	end
	local core = at(c, 0, 0.03, -0.07)
	Kit.Disc(c.b, core - Vector3.yAxis * 0.02 * c.L, Vector3.yAxis, 0.26 * c.L, 0.05 * c.L, deep)
	Kit.Ball(c.b, 0.17 * c.L, core, S, Enum.Material.Neon)
	Kit.Sparkles(c.b, Kit.Shade(P, 0.3), 5, 0.12 * c.L)
end

local SHAPES: { [string]: (Ctx) -> () } = {
	Dart = dart,
	Wide = wide,
	Leaf = leaf,
	Feather = feather,
	Kite = kite,
	Crane = crane,
	Jet = jet,
	Bat = bat,
	Star = star,
	Relic = relic,
}
GliderFactory.Shapes = { "Dart", "Wide", "Leaf", "Feather", "Kite", "Crane", "Jet", "Bat", "Star", "Relic" }

function GliderFactory.Build(visual: Visual, length: number, anchored: boolean): Model
	local L = math.max(0.2, length)
	local shape = if SHAPES[visual.Shape] then visual.Shape else "Dart"
	local glow = visual.Glow == true
	local b = Kit.New("Glider_" .. shape, L * 0.06)
	local c: Ctx = {
		b = b,
		L = L,
		T = math.max(0.03, L * 0.022),
		P = Kit.Color(visual.Primary, Color3.fromRGB(244, 244, 244)),
		S = Kit.Color(visual.Secondary, Color3.fromRGB(201, 211, 224)),
		Glow = glow,
		Accent = Kit.Mat(glow),
	}
	SHAPES[shape](c)
	if glow then
		Kit.Light(b, c.S, 1, L * 2.5)
	end
	b.Model:SetAttribute("Shape", shape)
	return Kit.Finish(b, anchored)
end

-- Visual for a glider id or "relic:<relicId>"; unknown ids fall back to the default glider.
function GliderFactory.VisualFor(id: string): Visual
	local relicId = string.match(id, "^relic:(.+)$")
	if relicId then
		local r = Relics.Get(relicId)
		if r then
			return r.Visual
		end
	end
	local g = Gliders.Get(id) or Gliders.Get(Gliders.Default)
	if g then
		return g.Visual
	end
	return { Shape = "Dart", Primary = "#F4F4F4", Secondary = "#C9D3E0" }
end

local cache = Kit.NewCache(64)

-- Built once per (id, length, anchored) and cloned afterwards, so flights and previews are cheap.
function GliderFactory.ForId(id: string, length: number, anchored: boolean): Model
	local key = string.format("%s|%.2f|%s", id, length, tostring(anchored))
	local model = Kit.Cached(cache, key, function()
		return GliderFactory.Build(GliderFactory.VisualFor(id), length, anchored)
	end)
	model.Name = id
	return model
end

-- Builds every glider, relic and shape once (anchored and welded), destroys them, returns true.
-- Studio command bar: require(game.ReplicatedStorage.Shared.Visual.GliderFactory).Validate()
function GliderFactory.Validate(): boolean
	local visuals: { Visual } = {}
	for _, g in Gliders.List do
		table.insert(visuals, g.Visual)
	end
	for _, r in Relics.List do
		table.insert(visuals, r.Visual)
	end
	for _, shape in GliderFactory.Shapes do
		table.insert(visuals, { Shape = shape, Primary = "#FFFFFF", Secondary = "#3FA9FF", Glow = true })
	end
	table.insert(visuals, { Shape = "NoSuchShape", Primary = "bad", Secondary = "#123456" })
	for _, visual in visuals do
		for _, anchored in { true, false } do
			local model = GliderFactory.Build(visual, 4, anchored)
			assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", "glider without Root")
			local count = Kit.PartCount(model)
			assert(count >= 3, "glider " .. visual.Shape .. " has too few parts")
			model:Destroy()
		end
	end
	GliderFactory.ForId("relic:aurora_relic", 3, true):Destroy()
	GliderFactory.ForId("unknown_glider", 3, false):Destroy()
	return true
end

return GliderFactory
