--!strict
-- Builds every world (World/MapBuilder) and answers spatial questions for other services from
-- the shared layout in Config/Map: "which pad is this player standing on?", "is the player in
-- the Throw Zone?", "where is the tutorial target?". Positions are derived from config, never
-- from anything a client sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Worlds = require(Shared.Definitions.Worlds)
local Training = require(Shared.Definitions.Training)

local Server = script.Parent.Parent
local MapBuilder = require(Server.World.MapBuilder)

local MapService = {}

MapService.Folder = nil :: Folder?
MapService.Built = false

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end
MapService.RootPosition = rootPosition

local function worldOf(position: Vector3): number?
	local index = math.floor(position.X / Map.WorldSpacing + 0.5) + 1
	if Worlds.Get(index) then
		return index
	end
	return nil
end

-- World area the player is physically in (nil while dead/loading).
function MapService.WorldAt(player: Player): number?
	local pos = rootPosition(player)
	return if pos then worldOf(pos) else nil
end

local function local_(worldId: number, pos: Vector3): Vector3
	return pos - Map.Origin(worldId)
end

-- Training pad under the player (in the given world), or nil.
function MapService.PadAt(player: Player, worldId: number): Training.Pad?
	local pos = rootPosition(player)
	if not pos then
		return nil
	end
	local l = local_(worldId, pos)
	local half = Map.PadSize / 2 + Vector3.new(Map.StandTolerance, 0, Map.StandTolerance)
	for _, pad in Training.ForWorld(worldId) do
		local c = Map.PadPosition(pad.Slot)
		if math.abs(l.X - c.X) <= half.X and math.abs(l.Z - c.Z) <= half.Z and l.Y > c.Y - 2 and l.Y < c.Y + 12 then
			return pad
		end
	end
	return nil
end

function MapService.InThrowZone(player: Player, worldId: number): boolean
	local pos = rootPosition(player)
	if not pos then
		return false
	end
	local l = local_(worldId, pos)
	local z = Map.ThrowZone
	local tol = Map.StandTolerance
	return l.X >= z.MinX - tol and l.X <= z.MaxX + tol and l.Z >= z.MinZ - tol and l.Z <= z.MaxZ + tol and l.Y > -4 and l.Y < 16
end

function MapService.SpawnCFrame(worldId: number): CFrame
	local p = Map.Origin(worldId) + Map.Spawn
	return CFrame.lookAt(p, p + Vector3.new(0, 0, -1))
end

function MapService.Anchor(worldId: number, name: string): Vector3?
	local o = Map.Origin(worldId)
	if name == "Pad1" then
		return o + Map.PadPosition(1)
	elseif name == "ThrowZone" then
		return o + Vector3.new(0, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2)
	elseif name == "GliderShop" then
		return o + Map.PedestalPosition(2)
	elseif name == "Egg1" then
		return o + Map.EggPosition(1)
	end
	return nil
end

-- Near a world-space point? (used for pedestal / egg / portal prompts as a second check)
function MapService.Near(player: Player, point: Vector3, radius: number): boolean
	local pos = rootPosition(player)
	return pos ~= nil and (pos - point).Magnitude <= radius
end

function MapService.WorldModel(worldId: number): Instance?
	local folder = MapService.Folder
	return if folder then folder:FindFirstChild("World_" .. worldId) else nil
end

function MapService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Worlds"
	folder.Parent = Workspace
	MapService.Folder = folder
	for _, world in Worlds.List do
		local ok, err = pcall(MapBuilder.Build, world, folder)
		if not ok then
			warn(string.format("[MapService] building %s failed: %s", world.Name, tostring(err)))
		end
	end
	MapService.Built = true
end

function MapService.Start()
	-- nothing at runtime; prompts are wired by the services that own them
	local _ = Players
end

return MapService
