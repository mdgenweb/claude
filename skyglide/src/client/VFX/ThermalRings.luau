--!strict
-- Thermal rings for the local flight: big glowing hoops built from neon segments around a faint
-- disc (no meshes, no assets). Rings face the channel (their normal runs along world Z) and spin
-- gently. Pooled: a flight acquires one ring per plan ring and releases each one after its pass
-- burst. Step() moves every segment with a single BulkMoveTo into a per-ring reusable CFrame list.
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent.Effects)

local ThermalRings = {}

local SEGMENTS = 14
local RADIUS = 10
local THICK = 1.1
local STEP = 2 * math.pi / SEGMENTS
local SEG_LEN = 2 * math.pi * RADIUS / SEGMENTS * 1.12 -- slight overlap so the hoop looks closed
local POOL_LIMIT = 32
local DISC_ROTATION = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis (X) -> world Z

ThermalRings.Radius = RADIUS

export type Ring = {
	Model: Model,
	Parts: { BasePart }, -- segments, in angle order
	CFrames: { CFrame }, -- reused by Step()
	Disc: BasePart,
	Center: Vector3,
}

local pool: { Ring } = {}
local folder: Folder? = nil

local function getFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "ThermalRings"
	created.Parent = Effects.Folder()
	folder = created
	return created
end

local function build(): Ring
	local model = Instance.new("Model")
	model.Name = "ThermalRing"
	local parts: { BasePart } = table.create(SEGMENTS)
	local cframes: { CFrame } = table.create(SEGMENTS)
	for i = 1, SEGMENTS do
		local p = Effects.Part()
		p.Name = "Segment"
		p.Size = Vector3.new(THICK, SEG_LEN, THICK)
		p.Parent = model
		parts[i] = p
		cframes[i] = CFrame.identity
	end
	local disc = Effects.Part(Enum.PartType.Cylinder)
	disc.Name = "Disc"
	disc.Size = Vector3.new(0.2, RADIUS * 2 - THICK, RADIUS * 2 - THICK)
	disc.Parent = model
	return { Model = model, Parts = parts, CFrames = cframes, Disc = disc, Center = Vector3.zero }
end

-- Recolours the hoop. `segTransparency` for the neon segments, `discTransparency` for the fill.
function ThermalRings.SetLook(ring: Ring, color: Color3, segTransparency: number, discTransparency: number)
	for _, p in ring.Parts do
		p.Color = color
		p.Transparency = segTransparency
	end
	ring.Disc.Color = color
	ring.Disc.Transparency = discTransparency
end

-- Places the segments at `spin` radians with the radius multiplied by `radiusScale`.
function ThermalRings.Step(ring: Ring, spin: number, radiusScale: number)
	local base = CFrame.new(ring.Center)
	local r = RADIUS * radiusScale
	local cframes = ring.CFrames
	for i = 1, SEGMENTS do
		cframes[i] = base * CFrame.Angles(0, 0, spin + (i - 1) * STEP) * CFrame.new(r, 0, 0)
	end
	Workspace:BulkMoveTo(ring.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Takes a ring from the pool and shows it at `center` (world position) in `color`.
function ThermalRings.Acquire(center: Vector3, color: Color3, spin: number): Ring
	local ring = table.remove(pool) or build()
	ring.Center = center
	ring.Disc.CFrame = CFrame.new(center) * DISC_ROTATION
	ThermalRings.SetLook(ring, color, 0.05, 0.88)
	ThermalRings.Step(ring, spin, 1)
	ring.Model.Parent = getFolder()
	return ring
end

function ThermalRings.Release(ring: Ring)
	ring.Model.Parent = nil
	if #pool < POOL_LIMIT then
		table.insert(pool, ring)
	else
		ring.Model:Destroy()
	end
end

return ThermalRings
