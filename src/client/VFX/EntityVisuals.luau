--!strict
-- Client visuals for battle entities (hazards, projectiles, beams, trains...). The server sends
-- an EntitySpawn event with geometry + a `visual` table; dynamic entities are then moved by
-- snapshots. Each visual is plain parts in the arena plane (station local space).
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArenaGeometry = require(Shared.Visual.ArenaGeometry)

local Effects = require(script.Parent.Effects)

export type Visual = {
	Model: Model,
	Update: (x: number, y: number, rot: number, scale: number) -> (),
	Arm: (() -> ())?,
	Destroy: () -> (),
}

local EntityVisuals = {}

local hex = Color3.fromHex

local function color(v: any, fallback: string): Color3
	if type(v) == "string" then
		local ok, c = pcall(Color3.fromHex, v)
		if ok then
			return c
		end
	end
	return hex(fallback)
end

local function part(model: Model, shape: Enum.PartType?, size: Vector3, c: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Effects.Part(shape)
	p.Size = size
	p.Color = c
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = model
	return p
end

-- Places a set of parts (given in entity-local 2D space) into the world every update.
type Piece = { Part: BasePart, Offset: CFrame }

local function make(station: CFrame, kind: string, pieces: { Piece }, model: Model, zOffset: number): Visual
	local k = ArenaGeometry.Get(kind)
	local self = {} :: any
	self.Model = model
	function self.Update(x: number, y: number, rot: number, scale: number)
		local base = station * CFrame.new(x, y, k.PlaneZ + zOffset) * CFrame.Angles(0, 0, rot)
		for _, piece in pieces do
			local off = piece.Offset
			if scale ~= 1 then
				off = CFrame.new(off.Position * scale) * off.Rotation
			end
			piece.Part.CFrame = base * off
		end
	end
	function self.Destroy()
		model:Destroy()
	end
	return self :: Visual
end

local builders: { [string]: (station: CFrame, kind: string, e: { [string]: any }, model: Model) -> Visual } = {}

-- Flat isosceles triangle from two wedges: base centred at the origin, tip at +X (length).
local function triangle(model: Model, length: number, width: number, c: Color3, thickness: number?): { Piece }
	local pieces: { Piece } = {}
	for side = -1, 1, 2 do
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.CastShadow = false
		wedge.Size = Vector3.new(thickness or 0.6, width / 2, length)
		wedge.Color = if side > 0 then c:Lerp(Color3.new(1, 1, 1), 0.18) else c
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Parent = model
		local offset = if side > 0
			then CFrame.new(length / 2, width / 4, 0) * CFrame.Angles(0, -math.pi / 2, 0)
			else CFrame.new(length / 2, -width / 4, 0) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		table.insert(pieces, { Part = wedge :: BasePart, Offset = offset })
	end
	return pieces
end

builders.thorn = function(station, kind, e, model)
	local v = e.visual or {}
	local len, width = v.length or 2.2, v.width or 1.5
	local c = color(v.color, "#C9CCD3"):Lerp(Color3.new(), 0.25)
	local vis = make(station, kind, triangle(model, len, width, c), model, 0)
	vis.Update(e.x, e.y, e.rot or 0, 1)
	return vis
end

builders.goo = function(station, kind, e, model)
	local v = e.visual or {}
	local r = e.r or 1.5
	local disc = part(model, Enum.PartType.Cylinder, Vector3.new(0.3, r * 2, r * 2), color(v.color, "#6EDB3A"), Enum.Material.Neon, 0.35)
	local inner = part(model, Enum.PartType.Cylinder, Vector3.new(0.32, r * 1.3, r * 1.3), color(v.accent, "#2C7A12"), Enum.Material.SmoothPlastic, 0.25)
	local face = CFrame.Angles(0, math.rad(90), 0)
	local gooPieces: { Piece } = { { Part = disc, Offset = face }, { Part = inner, Offset = face } }
	local vis = make(station, kind, gooPieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	disc.Size = Vector3.new(0.3, 0.2, 0.2)
	TweenService:Create(disc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = Vector3.new(0.3, r * 2, r * 2) }):Play()
	return vis
end

builders.fire = function(station, kind, e, model)
	local r = e.r or 1.5
	local disc = part(model, Enum.PartType.Cylinder, Vector3.new(0.3, r * 2, r * 2), hex("#FF8C1A"), Enum.Material.Neon, 0.45)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Color = ColorSequence.new(hex("#FFB347"), hex("#FF3B1A"))
	pe.Size = NumberSequence.new(0.8, 0)
	pe.Rate = 25
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(2, 4)
	pe.LightEmission = 0.8
	pe.Parent = disc
	local firePieces: { Piece } = { { Part = disc, Offset = CFrame.Angles(0, math.rad(90), 0) } }
	local vis = make(station, kind, firePieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	return vis
end

builders.mine = function(station, kind, e, model)
	local v = e.visual or {}
	local body = part(model, Enum.PartType.Ball, Vector3.one * 1.1, color(v.color, "#4A4F59"), Enum.Material.Metal)
	local light = part(model, Enum.PartType.Ball, Vector3.one * 0.45, color(v.light, "#FF3B3B"), Enum.Material.Neon)
	local spikes = {}
	for k = 0, 3 do
		local s = part(model, nil, Vector3.new(0.2, 1.6, 0.2), hex("#2A2D35"))
		table.insert(spikes, { Part = s :: BasePart, Offset = CFrame.Angles(0, 0, math.rad(k * 45)) })
	end
	local pieces: { Piece } = { { Part = body, Offset = CFrame.new() }, { Part = light, Offset = CFrame.new(0, 0, 0.45) } }
	for _, s in spikes do
		table.insert(pieces, s)
	end
	local vis = make(station, kind, pieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	light.Transparency = 0.7
	vis.Arm = function()
		TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0 }):Play()
	end
	return vis
end

builders.beam = function(station, kind, e, model)
	local v = e.visual or {}
	local k = ArenaGeometry.Get(kind)
	local a = Vector3.new(e.x, e.y, 0)
	local b = Vector3.new(e.x2, e.y2, 0)
	local len = (b - a).Magnitude
	local c = color(v.color, "#7A5CFF")
	local core = part(model, nil, Vector3.new(len, 0.12, 0.12), Color3.new(1, 1, 1), Enum.Material.Neon, 0.6)
	local glow = part(model, nil, Vector3.new(len, (e.r or 0.3) * 2, 0.3), c, Enum.Material.Neon, 0.85)
	local mid = (a + b) / 2
	local angle = math.atan2(b.Y - a.Y, b.X - a.X)
	local cf = station * CFrame.new(mid.X, mid.Y, k.PlaneZ) * CFrame.Angles(0, 0, angle)
	core.CFrame = cf
	glow.CFrame = cf
	local self = {} :: any
	self.Model = model
	self.Update = function() end
	self.Arm = function()
		core.Transparency = 0
		glow.Transparency = 0.25
		Effects.Flash(station:PointToWorldSpace(Vector3.new(e.x, e.y, k.PlaneZ)), 2, c, 0.2)
	end
	self.Destroy = function()
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		TweenService:Create(core, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		task.delay(0.16, function()
			model:Destroy()
		end)
	end
	return self :: Visual
end

builders.rail = function(station, kind, e, model)
	local v = e.visual or {}
	local k = ArenaGeometry.Get(kind)
	local horizontal = math.abs(e.y2 - e.y) < 0.01
	local len = if horizontal then math.abs(e.x2 - e.x) else math.abs(e.y2 - e.y)
	local line = if horizontal then e.y else e.x
	local rot = if horizontal then 0 else math.pi / 2
	local base = station * CFrame.new(if horizontal then 0 else line, if horizontal then line else 0, k.PlaneZ - 0.3) * CFrame.Angles(0, 0, rot)
	local warn = color(v.color, "#FFCC00")
	local rails = {}
	for side = -1, 1, 2 do
		local r = part(model, nil, Vector3.new(len, 0.12, 0.2), warn, Enum.Material.Neon, 0.2)
		r.CFrame = base * CFrame.new(0, side * 0.55, 0)
		table.insert(rails, r)
	end
	local ties = {}
	local count = math.floor(len / 1.4)
	for i = 0, count do
		local t = part(model, nil, Vector3.new(0.28, 1.5, 0.15), hex("#5A3A1C"), Enum.Material.Wood, 0.5)
		t.CFrame = base * CFrame.new(-len / 2 + i * (len / count), 0, -0.05)
		table.insert(ties, t)
	end
	for _, r in rails do
		TweenService:Create(r, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.8 }):Play()
	end
	local self = {} :: any
	self.Model = model
	self.Update = function() end
	self.Destroy = function()
		model:Destroy()
	end
	return self :: Visual
end

builders.train = function(station, kind, e, model)
	local v = e.visual or {}
	local len, width = v.length or 4.5, v.width or 1.6
	local bodyColor = color(v.color, "#3C3F46")
	local accent = color(v.accent, "#FFCC00")
	local body = part(model, nil, Vector3.new(len * 0.8, width, 1.2), bodyColor, Enum.Material.Metal)
	local stripe = part(model, nil, Vector3.new(len * 0.8, width * 0.25, 1.25), accent, Enum.Material.Neon)
	local windows = part(model, nil, Vector3.new(len * 0.5, width * 0.3, 1.3), hex("#BDF3FF"), Enum.Material.Neon)
	local pieces: { Piece } = {
		{ Part = body, Offset = CFrame.new(-len * 0.1, 0, 0) },
		{ Part = stripe, Offset = CFrame.new(-len * 0.1, -width * 0.25, 0) },
		{ Part = windows, Offset = CFrame.new(-len * 0.12, width * 0.18, 0) },
	}
	for _, piece in triangle(model, len * 0.2, width, accent, 1.2) do
		table.insert(pieces, { Part = piece.Part :: BasePart, Offset = CFrame.new(len * 0.3, 0, 0) * piece.Offset })
	end
	local vis = make(station, kind, pieces, model, 0)
	vis.Update(e.x, e.y, e.rot or 0, 1)
	return vis
end

builders.shackle = function(station, kind, e, model)
	local v = e.visual or {}
	local r = e.r or 1.2
	local c = color(v.color, "#C9CCD3")
	local pieces: { Piece } = {}
	for k = 0, 7 do
		local a = k * math.pi / 4
		local link = part(model, nil, Vector3.new(0.5, 0.25, 0.3), c, Enum.Material.Metal)
		table.insert(pieces, { Part = link :: BasePart, Offset = CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a + math.pi / 2) })
	end
	local core = part(model, Enum.PartType.Ball, Vector3.one * 0.6, color(v.rim, "#E04040"), Enum.Material.Neon, 0.7)
	table.insert(pieces, { Part = core :: BasePart, Offset = CFrame.new() })
	local vis = make(station, kind, pieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	vis.Arm = function()
		core.Transparency = 0
		TweenService:Create(core, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = Vector3.one * 0.9 }):Play()
	end
	return vis
end

builders.aura = function(station, kind, e, model)
	local v = e.visual or {}
	local r = e.r or 2.5
	local disc = part(model, Enum.PartType.Cylinder, Vector3.new(0.2, r * 2, r * 2), color(v.color, "#9D4DFF"), Enum.Material.Neon, 0.82)
	local rim = part(model, Enum.PartType.Cylinder, Vector3.new(0.18, r * 2.04, r * 2.04), color(v.rim, "#D9B3FF"), Enum.Material.Neon, 0.6)
	local k = ArenaGeometry.Get(kind)
	local self = {} :: any
	self.Model = model
	self.Update = function(x: number, y: number, _rot: number, scale: number)
		local cf = station * CFrame.new(x, y, k.PlaneZ - 0.6) * CFrame.Angles(0, math.rad(90), 0)
		disc.CFrame = cf
		rim.CFrame = cf * CFrame.new(-0.02, 0, 0)
		disc.Size = Vector3.new(0.2, r * 2 * scale, r * 2 * scale)
		rim.Size = Vector3.new(0.18, r * 2.06 * scale, r * 2.06 * scale)
	end
	self.Destroy = function()
		model:Destroy()
	end
	self.Update(e.x, e.y, 0, e.scale or 1)
	return self :: Visual
end

local function simpleBall(diameter: number, c: Color3, material: Enum.Material?): (station: CFrame, kind: string, e: { [string]: any }, model: Model) -> Visual
	return function(station, kind, e, model)
		local b = part(model, Enum.PartType.Ball, Vector3.one * diameter, c, material)
		local single: { Piece } = { { Part = b, Offset = CFrame.new() } }
		local vis = make(station, kind, single, model, 0)
		vis.Update(e.x, e.y, 0, 1)
		return vis
	end
end

builders.cannonball = function(station, kind, e, model)
	local b = part(model, Enum.PartType.Ball, Vector3.one * (e.r or 0.55) * 2, hex("#1C1E22"), Enum.Material.Metal)
	local glint = part(model, Enum.PartType.Ball, Vector3.one * 0.3, Color3.new(1, 1, 1), Enum.Material.Neon, 0.3)
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = b
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = b
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.Color = ColorSequence.new(hex("#9CA2AB"))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Parent = b
	local cannonPieces: { Piece } = { { Part = b, Offset = CFrame.new() }, { Part = glint, Offset = CFrame.new(-0.15, 0.15, 0.4) } }
	local vis = make(station, kind, cannonPieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	return vis
end

builders.moon = function(station, kind, e, model)
	local v = e.visual or {}
	return simpleBall((e.r or 0.45) * 2, color(v.color, "#C9D0FF"), Enum.Material.SmoothPlastic)(station, kind, e, model)
end

builders.pumpkin = function(station, kind, e, model)
	local b = part(model, Enum.PartType.Ball, Vector3.new(1.3, 1.1, 1.2), hex("#FF8C1A"))
	local stem = part(model, nil, Vector3.new(0.2, 0.4, 0.2), hex("#3E8E1E"))
	local face = part(model, nil, Vector3.new(0.6, 0.15, 0.1), hex("#2B1400"))
	local pumpkinPieces: { Piece } = { { Part = b, Offset = CFrame.new() }, { Part = stem, Offset = CFrame.new(0, 0.6, 0) }, { Part = face, Offset = CFrame.new(0, -0.15, 0.6) } }
	local vis = make(station, kind, pumpkinPieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	return vis
end

builders.boomerang = function(station, kind, e, model)
	local v = e.visual or {}
	local c = color(v.color, "#0E6E62")
	local armA = part(model, nil, Vector3.new(1.4, 0.35, 0.3), c)
	local armB = part(model, nil, Vector3.new(1.4, 0.35, 0.3), c)
	local boomerangPieces: { Piece } = {
		{ Part = armA, Offset = CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0.55, 0, 0) },
		{ Part = armB, Offset = CFrame.Angles(0, 0, math.rad(-35)) * CFrame.new(0.55, 0, 0) },
	}
	local vis = make(station, kind, boomerangPieces, model, 0)
	vis.Update(e.x, e.y, 0, 1)
	return vis
end

local function shardBuilder(defaultColor: string, size: number)
	return function(station: CFrame, kind: string, e: { [string]: any }, model: Model): Visual
		local v = e.visual or {}
		local s = part(model, nil, Vector3.new(size * 1.6, size, 0.25), color(v.color, defaultColor), Enum.Material.Glass, 0.15)
		local shardPieces: { Piece } = { { Part = s, Offset = CFrame.Angles(0, 0, math.rad(45)) } }
		local vis = make(station, kind, shardPieces, model, 0)
		vis.Update(e.x, e.y, e.rot or 0, 1)
		return vis
	end
end
builders.shard = shardBuilder("#7FE9FF", 0.5)
builders.chip = shardBuilder("#FFD23F", 0.45)

function EntityVisuals.Create(station: CFrame, kind: string, e: { [string]: any }, parent: Instance): Visual?
	local builder = builders[e.kind]
	if builder == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = e.kind .. "_" .. tostring(e.id)
	local ok, vis = pcall(builder, station, kind, e, model)
	if not ok then
		warn("[EntityVisuals] " .. tostring(e.kind) .. ": " .. tostring(vis))
		model:Destroy()
		return nil
	end
	model.Parent = parent
	return vis
end

return EntityVisuals
