--[[
	MapBuilder
	Builds a themed arena for a world at an origin: placeable ground, the path (with outline trim),
	spawn portal, base, decorations and a player spawn deck.

	Returns { model, placeable (Folder), blocked (Folder), playerSpawn (CFrame) }
	Tags: everything in `placeable` can hold units; everything in `blocked` stops placement raycasts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathMath = require(ReplicatedStorage.Shared.Util.PathMath)
local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local MapBuilder = {}

local HALF_X, HALF_Z = 72, 52
local PATH_WIDTH = 6

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function buildPath(points: { Vector3 }, theme, blocked: Instance)
	local edgeColor = theme.pathEdge
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local flatA = Vector3.new(a.X, 0, a.Z)
		local flatB = Vector3.new(b.X, 0, b.Z)
		local mid = (flatA + flatB) / 2
		local length = (flatB - flatA).Magnitude
		local look = CFrame.lookAt(mid, flatB)
		local baseY = a.Y - 0.6
		-- Outline trim (slightly wider, darker) then the walkway on top.
		Build.part({
			CFrame = look + Vector3.new(0, baseY + 0.12, 0),
			Size = Vector3.new(PATH_WIDTH + 1.2, 0.24, length + 1.2),
			Color = edgeColor,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = true,
		}, blocked)
		Build.part({
			CFrame = look + Vector3.new(0, baseY + 0.3, 0),
			Size = Vector3.new(PATH_WIDTH, 0.24, length),
			Color = theme.path,
			Material = theme.pathMaterial,
			CanCollide = true,
		}, blocked)
	end
	-- Round corners
	for index = 1, #points do
		local p = points[index]
		local baseY = p.Y - 0.6
		Build.cylinder(blocked, Vector3.new(p.X, baseY + 0.12, p.Z), 0.24, PATH_WIDTH + 1.2, edgeColor)
		local disc = Build.cylinder(blocked, Vector3.new(p.X, baseY + 0.3, p.Z), 0.24, PATH_WIDTH, theme.path, theme.pathMaterial)
		disc.Name = "PathCorner"
	end
end

local function decorate(theme, origin: Vector3, path, blocked: Instance, seed: number)
	local rng = Random.new(seed)
	local kind = theme.props

	local function freeSpot(minPathDistance: number): Vector3?
		for _ = 1, 30 do
			local x = rng:NextNumber(-HALF_X + 4, HALF_X - 4)
			local z = rng:NextNumber(-HALF_Z + 4, HALF_Z - 4)
			local position = origin + Vector3.new(x, 0, z)
			if PathMath.distanceToPath(path, position) >= minPathDistance then
				return position
			end
		end
		return nil
	end

	-- Border dressing: trees / hedges / junk around the edges so the arena feels like a place.
	for index = 0, 15 do
		local t = index / 16
		local angle = t * math.pi * 2
		local position = origin + Vector3.new(math.cos(angle) * (HALF_X + 10), 0, math.sin(angle) * (HALF_Z + 10))
		if kind == "void" then
			Props.floatingJunk(blocked, position, seed + index)
		elseif kind == "mall" then
			Props.lamp(blocked, position, rgb(255, 230, 200))
		else
			Props.tree(blocked, position, rng:NextNumber(1.1, 1.6))
		end
	end

	local count = 14
	for index = 1, count do
		local spot = freeSpot(9)
		if spot then
			local roll = rng:NextNumber()
			if kind == "school" then
				if roll < 0.35 then
					Props.tree(blocked, spot, rng:NextNumber(0.8, 1.2))
				elseif roll < 0.6 then
					Props.lockers(blocked, CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextInteger(3, 5))
				elseif roll < 0.8 then
					Props.bench(blocked, CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				else
					Props.bush(blocked, spot)
				end
			elseif kind == "suburb" then
				if roll < 0.3 then
					Props.tree(blocked, spot, rng:NextNumber(0.9, 1.3))
				elseif roll < 0.55 then
					Props.bush(blocked, spot, rgb(90, 190, 100))
				elseif roll < 0.75 then
					Props.lamp(blocked, spot)
				else
					Props.rock(blocked, spot, rng:NextNumber(0.6, 1))
				end
			elseif kind == "mall" then
				if roll < 0.3 then
					Props.bench(blocked, CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				elseif roll < 0.6 then
					Props.bush(blocked, spot, rgb(110, 200, 120))
				else
					Props.lamp(blocked, spot, rgb(255, 210, 160))
				end
			elseif kind == "woods" then
				if roll < 0.5 then
					Props.pine(blocked, spot, rng:NextNumber(0.9, 1.4))
				elseif roll < 0.75 then
					Props.rock(blocked, spot, rng:NextNumber(0.8, 1.4))
				else
					Props.bush(blocked, spot, rgb(70, 160, 80))
				end
			else -- void
				Props.floatingJunk(blocked, spot, seed * 31 + index)
			end
		end
	end

	-- Landmark set pieces, placed in the arena's back corners.
	local corner = origin + Vector3.new(-HALF_X + 14, 0, HALF_Z + 22)
	if kind == "school" then
		Props.school(blocked, CFrame.new(origin + Vector3.new(0, 0, HALF_Z + 22)) * CFrame.Angles(0, math.rad(180), 0))
		Props.bus(blocked, CFrame.new(origin + Vector3.new(-HALF_X - 14, 0, 0)))
	elseif kind == "suburb" then
		for index = 0, 3 do
			local colors = { rgb(255, 200, 150), rgb(180, 220, 255), rgb(200, 255, 190), rgb(255, 190, 220) }
			Props.house(
				blocked,
				CFrame.new(origin + Vector3.new(-45 + index * 30, 0, HALF_Z + 20)) * CFrame.Angles(0, math.rad(180), 0),
				colors[index + 1]
			)
		end
	elseif kind == "mall" then
		local names = { "Joyful Burger", "Elmore Mall", "Comic Store", "Video Games" }
		local colors = { rgb(255, 120, 60), rgb(79, 183, 242), rgb(176, 108, 255), rgb(96, 200, 110) }
		for index = 0, 3 do
			Props.shop(
				blocked,
				CFrame.new(origin + Vector3.new(-48 + index * 32, 0, HALF_Z + 16)) * CFrame.Angles(0, math.rad(180), 0),
				names[index + 1],
				colors[index + 1]
			)
		end
		local spot = freeSpot(14)
		if spot then
			Props.fountain(blocked, spot)
		end
	elseif kind == "woods" then
		Props.lake(blocked, corner, 22)
	end
end

function MapBuilder.build(world, origin: Vector3, parent: Instance, path)
	local theme = world.theme
	local model = Build.model("Map_" .. world.id, parent)
	local placeable = Build.folder("Placeable", model)
	local blocked = Build.folder("Blocked", model)

	-- Outer apron (non-placeable) + main field (placeable).
	Build.part({
		CFrame = CFrame.new(origin + Vector3.new(0, -1.2, 0)),
		Size = Vector3.new(HALF_X * 2 + 80, 1, HALF_Z * 2 + 80),
		Color = theme.ground:Lerp(rgb(0, 0, 0), 0.15),
		Material = theme.groundMaterial,
	}, blocked)
	local ground = Build.part({
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Size = Vector3.new(HALF_X * 2, 1, HALF_Z * 2),
		Color = theme.ground,
		Material = theme.groundMaterial,
	}, placeable)
	ground.Name = "Ground"
	-- Field border trim
	for _, side in { -1, 1 } do
		Build.block(blocked, CFrame.new(origin + Vector3.new(0, -0.3, side * (HALF_Z + 0.5))), Vector3.new(HALF_X * 2 + 2, 1.2, 1), theme.accent)
		Build.block(blocked, CFrame.new(origin + Vector3.new(side * (HALF_X + 0.5), -0.3, 0)), Vector3.new(1, 1.2, HALF_Z * 2 + 2), theme.accent)
	end

	buildPath(path.points, theme, blocked)

	-- Spawn portal at the start, facing along the path.
	local startPos, startDir = PathMath.sample(path, 0)
	local startGround = Vector3.new(startPos.X, origin.Y, startPos.Z)
	Props.voidPortal(blocked, CFrame.lookAt(startGround, startGround + startDir) * CFrame.Angles(0, math.rad(90), 0))

	-- Base at the end.
	local endPos, endDir = PathMath.sample(path, path.length)
	local endGround = Vector3.new(endPos.X, origin.Y, endPos.Z)
	local baseCFrame = CFrame.lookAt(endGround + endDir * 6, endGround)
	local base
	if theme.props == "suburb" then
		base = Props.wattersonHouse(blocked, baseCFrame * CFrame.new(0, 0, 4))
	elseif theme.props == "void" then
		base = Build.model("VoidCoreBase", blocked)
		local core = Build.ball(base, endGround + Vector3.new(0, 5, 0), 7, rgb(255, 200, 255), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 3
		light.Color = rgb(220, 120, 255)
		light.Parent = core
	else
		base = Build.model("Base", blocked)
		local door = Build.block(base, baseCFrame * CFrame.new(0, 5, 2), Vector3.new(12, 10, 3), rgb(255, 248, 231))
		Build.block(base, baseCFrame * CFrame.new(0, 3.6, 0.4), Vector3.new(4.4, 7.2, 0.3), theme.accent)
		Build.wedge(base, baseCFrame * CFrame.new(0, 11.5, 2), Vector3.new(13, 3, 3.4), rgb(79, 183, 242))
		Build.label(door, "DEFEND!", { offset = Vector3.new(0, 9, 0), size = UDim2.fromOffset(220, 60), color = rgb(255, 214, 70) })
	end
	base.Name = "Base"

	-- Player spawn deck beside the base (raised so players overlook the field).
	local side = Vector3.new(-endDir.Z, 0, endDir.X)
	local deckPos = endGround + endDir * 2 + side * 14
	local clampX = math.clamp(deckPos.X - origin.X, -HALF_X + 6, HALF_X - 6)
	local clampZ = math.clamp(deckPos.Z - origin.Z, -HALF_Z + 6, HALF_Z - 6)
	deckPos = Vector3.new(origin.X + clampX, origin.Y, origin.Z + clampZ)
	local deck = Build.cylinder(blocked, deckPos + Vector3.new(0, 1, 0), 2, 9, theme.accent)
	deck.Name = "SpawnDeck"
	local playerSpawn = CFrame.lookAt(deckPos + Vector3.new(0, 5, 0), Vector3.new(origin.X, deckPos.Y + 5, origin.Z))

	decorate(theme, origin, path, blocked, world.order * 1337)

	return {
		model = model,
		placeable = placeable,
		blocked = blocked,
		playerSpawn = playerSpawn,
	}
end

return MapBuilder
