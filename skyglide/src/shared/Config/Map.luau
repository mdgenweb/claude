--!strict
-- Map layout (world-local coordinates, studs). Every world uses the same layout at its own origin
-- so the server, client and tutorial share one set of anchors. +Z points back toward spawn,
-- the channel runs toward -Z from the Throw Zone.
local Map = {}

Map.WorldSpacing = 3200 -- world N origin = ((N - 1) * WorldSpacing, 0, 0)

Map.Hub = { MinX = -160, MaxX = 160, MinZ = -40, MaxZ = 230, WallHeight = 34 }
Map.Spawn = Vector3.new(0, 3, 190)

Map.ThrowZone = { MinX = -36, MaxX = 36, MinZ = -40, MaxZ = 4 }
Map.ThrowOrigin = Vector3.new(0, 5, -42) -- where gliders leave the hand (channel Z = 0 here)
Map.ChannelStartZ = -40
Map.ChannelHalfWidth = 44
Map.WaterY = -7
Map.BankWidth = 26
Map.CliffHeight = 26
Map.ChannelSegment = 400 -- studs per water/bank segment

-- Training pads: a column on the left side.
Map.PadSize = Vector3.new(24, 1, 24)
Map.PadOrigin = Vector3.new(-104, 0, 34) -- slot 1 centre
Map.PadStep = Vector3.new(0, 0, 27)

-- Glider pedestals: two columns on the right side.
Map.PedestalOrigin = Vector3.new(76, 0, 32)
Map.PedestalStepAlong = Vector3.new(0, 0, 28) -- next item in a column
Map.PedestalStepAcross = Vector3.new(34, 0, 0) -- next column
Map.PedestalsPerColumn = 6
Map.RelicSpot = Vector3.new(76, 0, 0)

-- Eggs: a row along the back wall (right half).
Map.EggOrigin = Vector3.new(40, 0, 214)
Map.EggStep = Vector3.new(26, 0, 0)

-- Portals and leaderboards on the back wall.
Map.PortalNext = Vector3.new(-34, 0, 224)
Map.PortalPrev = Vector3.new(-80, 0, 224)
Map.Leaderboards = {
	{ Stat = "Wins", Position = Vector3.new(-152, 14, 120), Facing = Vector3.new(1, 0, 0) },
	{ Stat = "BestDistance", Position = Vector3.new(-152, 14, 160), Facing = Vector3.new(1, 0, 0) },
	{ Stat = "Rebirths", Position = Vector3.new(-152, 14, 200), Facing = Vector3.new(1, 0, 0) },
}

-- Padding (studs) when checking "is the player standing on X" on the server.
Map.StandTolerance = 3

function Map.Origin(worldId: number): Vector3
	return Vector3.new((worldId - 1) * Map.WorldSpacing, 0, 0)
end

-- Channel-space (lateral x, altitude y above water, distance z along the channel) -> world position.
function Map.ChannelPoint(worldId: number, x: number, y: number, z: number): Vector3
	local o = Map.Origin(worldId)
	return o + Vector3.new(Map.ThrowOrigin.X + x, Map.WaterY + y, Map.ChannelStartZ - z)
end

function Map.PadPosition(slot: number): Vector3
	return Map.PadOrigin + Map.PadStep * (slot - 1)
end

function Map.PedestalPosition(index: number): Vector3
	local column = (index - 1) // Map.PedestalsPerColumn
	local row = (index - 1) % Map.PedestalsPerColumn
	return Map.PedestalOrigin + Map.PedestalStepAcross * column + Map.PedestalStepAlong * row
end

function Map.EggPosition(index: number): Vector3
	return Map.EggOrigin + Map.EggStep * (index - 1)
end

return Map
