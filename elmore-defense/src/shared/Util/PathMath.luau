--[[
	PathMath
	Enemies are simulated as a single number: distance travelled along a polyline path.
	Server and client both use this module, so positions agree without replicating parts.
]]

local PathMath = {}

export type Path = {
	points: { Vector3 },
	cumulative: { number }, -- cumulative[i] = distance from start to points[i]
	length: number,
}

function PathMath.build(points: { Vector3 }): Path
	assert(#points >= 2, "PathMath.build needs at least two points")
	local cumulative = { 0 }
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
		cumulative[index] = total
	end
	return { points = points, cumulative = cumulative, length = total }
end

-- Finds the segment index i such that cumulative[i] <= distance < cumulative[i+1]
local function findSegment(path: Path, distance: number): number
	local cumulative = path.cumulative
	local low, high = 1, #cumulative - 1
	while low < high do
		local mid = (low + high + 1) // 2
		if cumulative[mid] <= distance then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end

-- Returns world position and unit forward vector at `distance` along the path.
function PathMath.sample(path: Path, distance: number): (Vector3, Vector3)
	local points = path.points
	if distance <= 0 then
		return points[1], (points[2] - points[1]).Unit
	end
	if distance >= path.length then
		local count = #points
		return points[count], (points[count] - points[count - 1]).Unit
	end
	local index = findSegment(path, distance)
	local a, b = points[index], points[index + 1]
	local segmentLength = path.cumulative[index + 1] - path.cumulative[index]
	local alpha = if segmentLength > 0 then (distance - path.cumulative[index]) / segmentLength else 0
	return a:Lerp(b, alpha), (b - a).Unit
end

-- Shortest horizontal (XZ) distance from a point to the path polyline.
function PathMath.distanceToPath(path: Path, position: Vector3): number
	local best = math.huge
	local px, pz = position.X, position.Z
	local points = path.points
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local apx, apz = px - a.X, pz - a.Z
		local lengthSq = abx * abx + abz * abz
		local t = if lengthSq > 0 then math.clamp((apx * abx + apz * abz) / lengthSq, 0, 1) else 0
		local cx, cz = a.X + abx * t, a.Z + abz * t
		local dx, dz = px - cx, pz - cz
		local d = math.sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
	end
	return best
end

-- Horizontal distance helper used by range checks (towers ignore height differences).
function PathMath.flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Offsets a path by a world-space vector (used when a map is built at an arena slot).
function PathMath.offset(points: { Vector3 }, origin: Vector3): { Vector3 }
	local out = table.create(#points)
	for index, point in points do
		out[index] = point + origin
	end
	return out
end

return PathMath
