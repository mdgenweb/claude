--!prelude-before _rbxmock.luau
-- Builds every world with the real MapBuilder and prints each part (and each station's root) as
-- JSON for tests/map_render.py. Not a spec: run it through map_render.py.
local MapBuilder = MODULE("ServerScriptService/Server/World/MapBuilder")
local Worlds = MODULE("ReplicatedStorage/Shared/Definitions/Worlds")

local function n(v)
	if v ~= v or v == math.huge or v == -math.huge then
		return "null"
	end
	return string.format("%.3f", v)
end
local function hexColor(c)
	if c == nil then
		return "#A3A2A5"
	end
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local root = Instance.new("Folder")
root.Name = "Worlds"
for _, world in Worlds.List do
	local model = MapBuilder.Build(world, root)
	print(string.format('WORLD\t{"id":%d,"name":"%s"}', world.Id, world.Name))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local s = d.Size
			-- the path below the world model tells which station the part belongs to
			local names = {}
			local node = d.Parent
			while node and node ~= model do
				table.insert(names, 1, node.Name)
				node = node.Parent
			end
			print(string.format(
				'PART\t{"w":%d,"p":[%s,%s,%s],"s":[%s,%s,%s],"x":[%s,%s,%s],"z":[%s,%s,%s],"c":"%s","t":%s,"shape":"%s","path":"%s","name":"%s","collide":%s}',
				world.Id,
				n(cf.Position.X), n(cf.Position.Y), n(cf.Position.Z),
				n(s.X), n(s.Y), n(s.Z),
				n(cf.RightVector.X), n(cf.RightVector.Y), n(cf.RightVector.Z),
				n(-cf.LookVector.X), n(-cf.LookVector.Y), n(-cf.LookVector.Z),
				hexColor(d.Color), n(d.Transparency or 0),
				tostring(d.Shape or ""), table.concat(names, "/"), d.Name, tostring(d.CanCollide ~= false)
			))
		end
	end
end
print("END")
