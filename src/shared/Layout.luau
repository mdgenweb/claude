--!strict
-- World layout shared by the server (building, ownership checks) and the client
-- (Auto Farm routing, pads, gates). The yard runs west -> east:
--   Starter Yard | Gate 1 | Appliance Row | Gate 2 | Crusher Yard
-- Each area holds six lanes running north (-Z) from a shared corridor. The hub
-- (spawn, upgrade bench, rebirth pad, shop...) sits south of the Starter Yard.

local Layout = {}

Layout.Lanes = 6
Layout.LaneWidth = 22
Layout.AreaWidth = Layout.Lanes * Layout.LaneWidth -- 132
Layout.AreaGap = 14 -- gate wall between areas
Layout.LaneDepth = 112 -- lanes run from z = 0 to z = -LaneDepth
Layout.CorridorWidth = 18 -- corridor spans z in [0, CorridorWidth]
Layout.HubDepth = 72 -- hub spans z in [CorridorWidth, CorridorWidth + HubDepth]
Layout.GroundY = 0
Layout.WallHeight = 16

function Layout.areaX0(area: number): number
	return (area - 1) * (Layout.AreaWidth + Layout.AreaGap)
end

function Layout.areaX1(area: number): number
	return Layout.areaX0(area) + Layout.AreaWidth
end

Layout.TotalWidth = Layout.areaX1(3)
Layout.CorridorZ = Layout.CorridorWidth / 2
Layout.HubZ0 = Layout.CorridorWidth
Layout.HubZ1 = Layout.CorridorWidth + Layout.HubDepth

function Layout.laneX(area: number, lane: number): number
	return Layout.areaX0(area) + (lane - 0.5) * Layout.LaneWidth
end

-- Gate g sits between area g and area g + 1 and guards entry to area g + 1.
function Layout.gateX(gate: number): number
	return Layout.areaX1(gate) + Layout.AreaGap / 2
end

-- Target slots per area as offsets (x from lane centre, z) inside a lane.
local SLOTS: { { { number } } } = {
	{ -- Starter Yard: two columns, six rows
		{ -5, -14 },
		{ 5, -14 },
		{ -5, -29 },
		{ 5, -29 },
		{ -5, -44 },
		{ 5, -44 },
		{ -5, -59 },
		{ 5, -59 },
		{ -5, -74 },
		{ 5, -74 },
		{ -5, -89 },
		{ 5, -89 },
	},
	{ -- Appliance Row: two columns, five rows
		{ -5, -16 },
		{ 5, -16 },
		{ -5, -34 },
		{ 5, -34 },
		{ -5, -52 },
		{ 5, -52 },
		{ -5, -70 },
		{ 5, -70 },
		{ -5, -88 },
		{ 5, -88 },
	},
	{ -- Crusher Yard: zig-zag, seven rows
		{ -4, -16 },
		{ 4, -30 },
		{ -4, -44 },
		{ 4, -58 },
		{ -4, -72 },
		{ 4, -86 },
		{ -4, -100 },
	},
}

function Layout.slotCount(area: number): number
	return #SLOTS[area]
end

function Layout.slotPosition(area: number, lane: number, slot: number): Vector3
	local offset = SLOTS[area][slot]
	return Vector3.new(Layout.laneX(area, lane) + offset[1], Layout.GroundY, offset[2])
end

-- Where a player stands when they spawn: their own Starter Yard lane, facing the junk.
function Layout.laneEntrance(area: number, lane: number): Vector3
	return Vector3.new(Layout.laneX(area, lane), Layout.GroundY, -4)
end

-- Hub pads: interactive circles players walk onto.
Layout.Pads = {
	{ Id = "Upgrade", Position = Vector3.new(28, 0, 40) },
	{ Id = "Rebirth", Position = Vector3.new(104, 0, 40) },
	{ Id = "Shop", Position = Vector3.new(28, 0, 70) },
	{ Id = "Daily", Position = Vector3.new(104, 0, 70) },
	{ Id = "Garage", Position = Vector3.new(66, 0, 64) },
}
Layout.PadRadius = 6
Layout.SpawnPosition = Vector3.new(66, 0, 44)

-- Area index (1..3) for a world position, or nil when outside every yard area.
function Layout.areaAt(position: Vector3): number?
	if position.Z > Layout.CorridorWidth or position.Z < -Layout.LaneDepth then
		return nil
	end
	for area = 1, 3 do
		if position.X >= Layout.areaX0(area) and position.X <= Layout.areaX1(area) then
			return area
		end
	end
	return nil
end

-- Lane index for a position inside an area's lane strip (north of the corridor).
function Layout.laneAt(position: Vector3): (number?, number?)
	local area = Layout.areaAt(position)
	if not area or position.Z > 0 then
		return area, nil
	end
	local lane = math.floor((position.X - Layout.areaX0(area)) / Layout.LaneWidth) + 1
	return area, math.clamp(lane, 1, Layout.Lanes)
end

-- True while a position is somewhere in the salvage yards (lanes or corridor), not the hub.
function Layout.isInYard(position: Vector3): boolean
	return Layout.areaAt(position) ~= nil
end

-- Horizontal distance from a position to the nearest point of an axis-aligned hitbox.
function Layout.reachDistance(from: Vector3, hitbox: BasePart): number
	local half = hitbox.Size / 2
	local centre = hitbox.Position
	local dx = math.max(math.abs(from.X - centre.X) - half.X, 0)
	local dz = math.max(math.abs(from.Z - centre.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Waypoints from a position to a point inside a lane, travelling via the corridor.
-- Used by Auto Farm so movement stays inside the player's own lane and the corridor.
function Layout.route(from: Vector3, area: number, lane: number, to: Vector3): { Vector3 }
	local curArea, curLane = Layout.laneAt(from)
	if curArea == area and curLane == lane then
		return { to }
	end
	local laneCentre = Layout.laneX(area, lane)
	local corridorFrom = Vector3.new(math.clamp(from.X, 2, Layout.TotalWidth - 2), from.Y, Layout.CorridorZ)
	local corridorTo = Vector3.new(laneCentre, from.Y, Layout.CorridorZ)
	local laneMouth = Vector3.new(laneCentre, from.Y, -3)
	return { corridorFrom, corridorTo, laneMouth, to }
end

return Layout
