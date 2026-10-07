--!strict
-- Shared arena measurements (studs) used by the server builder, the simulation and the
-- client camera/renderer, so all three always agree. Station local space:
--   origin = centre of the arena interior, +X = viewer's right, +Y = up, +Z = toward viewer.
-- Proportions were measured from the reference battle screenshot (see docs/RESEARCH.md §D).
export type PadSpec = { Team: number, X: number }

export type ArenaKind = {
	Half: number, -- interior half-extent (simulation bounds)
	Frame: number, -- frame thickness
	FrontZ: number, -- front face of the frame
	BackZ: number, -- inner face of the back wall
	PlaneZ: number, -- plane the orbs move in
	BaseHeight: number, -- floor to arena centre
	LedgeDrop: number, -- arena centre to ledge top (players' feet)
	LedgeInner: number, -- ledge inner x edge
	LedgeOuter: number, -- ledge outer x edge
	LedgeDepth: { number }, -- z range {back, front}
	Pads: { PadSpec },
}

local ArenaGeometry = {}

ArenaGeometry.Kinds = {
	Duel = {
		Half = 8,
		Frame = 1,
		FrontZ = 1.2,
		BackZ = -3.3,
		PlaneZ = -1.0,
		BaseHeight = 9,
		LedgeDrop = 4.8,
		LedgeInner = 9,
		LedgeOuter = 16,
		LedgeDepth = { -3.5, 4.5 },
		Pads = { { Team = 1, X = -12.5 }, { Team = 2, X = 12.5 } },
	},
	Team = {
		Half = 10,
		Frame = 1,
		FrontZ = 1.2,
		BackZ = -3.3,
		PlaneZ = -1.0,
		BaseHeight = 11,
		LedgeDrop = 4.8,
		LedgeInner = 11,
		LedgeOuter = 23,
		LedgeDepth = { -3.5, 4.5 },
		Pads = { { Team = 1, X = -14.2 }, { Team = 1, X = -19.6 }, { Team = 2, X = 14.2 }, { Team = 2, X = 19.6 } },
	},
} :: { [string]: ArenaKind }

function ArenaGeometry.Get(kind: string): ArenaKind
	return ArenaGeometry.Kinds[kind] or ArenaGeometry.Kinds.Duel
end

function ArenaGeometry.KindForMode(mode: string): string
	return if mode == "2v2" then "Team" else "Duel"
end

-- Station centre CFrame from a config floor position + yaw (degrees).
function ArenaGeometry.StationCFrame(floor: { number }, yaw: number, kind: string): CFrame
	local k = ArenaGeometry.Get(kind)
	return CFrame.new(floor[1], floor[2] + k.BaseHeight, floor[3]) * CFrame.Angles(0, math.rad(yaw), 0)
end

function ArenaGeometry.SimToWorld(station: CFrame, kind: string, x: number, y: number, zOffset: number?): Vector3
	local k = ArenaGeometry.Get(kind)
	return station:PointToWorldSpace(Vector3.new(x, y, k.PlaneZ + (zOffset or 0)))
end

-- Where a participant's character stands (HumanoidRootPart CFrame), facing the viewer.
function ArenaGeometry.PadCFrame(station: CFrame, kind: string, padIndex: number): CFrame
	local k = ArenaGeometry.Get(kind)
	local pad = k.Pads[padIndex]
	local feetY = -k.LedgeDrop
	return station * CFrame.new(pad.X, feetY + 3, 0.6) * CFrame.Angles(0, math.pi, 0)
end

-- Where a player is released after leaving the pad (in front of the station on the floor).
function ArenaGeometry.ReleaseCFrame(station: CFrame, kind: string, padIndex: number): CFrame
	local k = ArenaGeometry.Get(kind)
	local pad = k.Pads[padIndex]
	return station * CFrame.new(pad.X * 0.8, -k.BaseHeight + 3.2, 9) * CFrame.Angles(0, math.pi, 0)
end

-- Battle camera: front-on, fits the arena (and the players' ledges on wide screens).
function ArenaGeometry.CameraCFrame(station: CFrame, kind: string, aspect: number, verticalFov: number): CFrame
	local k = ArenaGeometry.Get(kind)
	local tanHalf = math.tan(math.rad(verticalFov) / 2)
	local needHalfH = k.Half + k.Frame + 0.7
	local needHalfW = if aspect >= 1.45 then k.LedgeOuter + 1 else k.Half + k.Frame + 0.8
	local dist = math.max(needHalfH / tanHalf, needHalfW / (tanHalf * aspect))
	local eye = station:PointToWorldSpace(Vector3.new(0, 0.2, k.FrontZ + dist))
	local target = station:PointToWorldSpace(Vector3.new(0, 0.2, k.PlaneZ))
	return CFrame.lookAt(eye, target)
end

return ArenaGeometry
