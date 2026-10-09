--!prelude-before _rbxmock.luau
-- Builds every world and every visual definition headlessly against the Roblox API mock and
-- checks the map naming contract the client depends on (docs/DESIGN.md §5), part budgets and the
-- factory self-tests.
local MapBuilder = MODULE("ServerScriptService/Server/World/MapBuilder")
local Worlds = MODULE("ReplicatedStorage/Shared/Definitions/Worlds")
local Training = MODULE("ReplicatedStorage/Shared/Definitions/Training")
local Gliders = MODULE("ReplicatedStorage/Shared/Definitions/Gliders")
local Relics = MODULE("ReplicatedStorage/Shared/Definitions/Relics")
local Eggs = MODULE("ReplicatedStorage/Shared/Definitions/Eggs")
local Zones = MODULE("ReplicatedStorage/Shared/Definitions/Zones")
local Map = MODULE("ReplicatedStorage/Shared/Config/Map")
local GliderFactory = MODULE("ReplicatedStorage/Shared/Visual/GliderFactory")
local PetFactory = MODULE("ReplicatedStorage/Shared/Visual/PetFactory")
local EggFactory = MODULE("ReplicatedStorage/Shared/Visual/EggFactory")

local failures, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAILED: " .. msg)
	end
end

local function path(root, ...)
	local node = root
	for _, name in { ... } do
		if node == nil then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	return node
end

check(GliderFactory.Validate() == true, "GliderFactory.Validate")
check(PetFactory.Validate() == true, "PetFactory.Validate")
check(EggFactory.Validate() == true, "EggFactory.Validate")

-- every glider builds in both modes with a Root primary part and welds when held
for _, glider in Gliders.List do
	local held = GliderFactory.ForId(glider.Id, 2.4, false)
	check(held.PrimaryPart ~= nil and held.PrimaryPart.Name == "Root", "glider root " .. glider.Id)
	local anchoredParts = 0
	for _, d in held:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored then
			anchoredParts += 1
		end
	end
	check(anchoredParts == 0, "held glider is unanchored " .. glider.Id)
end
check(GliderFactory.ForId("relic:aurora_relic", 4, true).PrimaryPart ~= nil, "relic glider builds")
check(GliderFactory.ForId("nope", 4, true).PrimaryPart ~= nil, "unknown glider falls back")

local root = Instance.new("Folder")
root.Name = "Worlds"
check(MapBuilder.Validate() == true, "MapBuilder.Validate")
for _, world in Worlds.List do
	local m = MapBuilder.Build(world, root)
	local tag = "world " .. world.Id .. " "
	check(m ~= nil and m.Name == "World_" .. world.Id, tag .. "model")
	local parts = m:GetAttribute("PartCount") or 0
	check(parts > 300 and parts <= MapBuilder.PartBudget, tag .. "part budget (" .. parts .. ")")
	check(m:FindFirstChild("ThrowZone", true) ~= nil, tag .. "ThrowZone")
	for _, pad in Training.ForWorld(world.Id) do
		local part = path(m, "Pads", "Pad_" .. pad.Id)
		check(part ~= nil, tag .. "pad " .. pad.Id)
		for _, label in { "Gate", "Status", "Mult" } do
			check(path(part, "Label", label) ~= nil, tag .. "pad label " .. pad.Id .. "." .. label)
		end
		if part then
			local expected = Map.Origin(world.Id) + Map.PadPosition(pad.Slot)
			local p = part.CFrame.Position
			check(math.abs(p.X - expected.X) < 0.5 and math.abs(p.Z - expected.Z) < 0.5, tag .. "pad position matches server " .. pad.Id)
		end
	end
	for _, glider in Gliders.ForWorld(world.Id) do
		local pedestal = path(m, "Pedestals", "Pedestal_" .. glider.Id)
		check(pedestal ~= nil and pedestal.PrimaryPart ~= nil and pedestal.PrimaryPart.Name == "Base", tag .. "pedestal " .. glider.Id)
		check(path(pedestal, "Base", "BuyPrompt") ~= nil, tag .. "pedestal prompt " .. glider.Id)
		for _, label in { "Status", "Skill", "Price" } do
			check(path(pedestal, "Base", "Label", label) ~= nil, tag .. "pedestal label " .. label)
		end
		local display = pedestal and pedestal:FindFirstChild("Display")
		check(display ~= nil and display:GetAttribute("Spin") == true, tag .. "pedestal display " .. glider.Id)
	end
	for _, relic in Relics.List do
		local r = path(m, "Pedestals", "Relic_" .. relic.Id)
		check(r ~= nil and path(r, "Base", "BuyPrompt") ~= nil, tag .. "relic " .. relic.Id)
		for _, label in { "Stock", "Title", "Bonus", "Price" } do
			check(path(r, "Base", "Label", label) ~= nil, tag .. "relic label " .. label)
		end
	end
	for _, egg in Eggs.ForWorld(world.Id) do
		local e = path(m, "Eggs", "Egg_" .. egg.Id)
		check(e ~= nil and path(e, "Base", "HatchPrompt") ~= nil, tag .. "egg " .. egg.Id)
		check(path(e, "Base", "Label", "Name") ~= nil and path(e, "Base", "Label", "Price") ~= nil, tag .. "egg labels " .. egg.Id)
	end
	if world.Id < #Worlds.List then
		local portal = path(m, "Portals", "Portal_" .. (world.Id + 1))
		check(portal ~= nil and path(portal, "Frame", "PortalPrompt") ~= nil, tag .. "next portal")
	end
	if world.Id > 1 then
		check(path(m, "Portals", "Portal_" .. (world.Id - 1)) ~= nil, tag .. "previous portal")
	end
	for _, entry in Map.Leaderboards do
		local board = path(m, "Boards", "Board_" .. entry.Stat)
		check(board ~= nil and path(board, "Board", "List") ~= nil and path(board, "Board", "Title") ~= nil, tag .. "board " .. entry.Stat)
	end
	for _, zone in Zones.ForWorld(world.Id) do
		check(path(m, "Zones", "ZoneSign_" .. zone.Id) ~= nil, tag .. "zone sign " .. zone.Id)
	end
	check((world.Id == 1) == (m:FindFirstChildWhichIsA("SpawnLocation", true) ~= nil), tag .. "spawn location only in world 1")
	print(string.format("  %s: %d parts", world.Name, parts))
end

print(string.format("world.spec: %d checks, %d failures", checks, failures))
