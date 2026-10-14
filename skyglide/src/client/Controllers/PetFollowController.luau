--!strict
-- Renders equipped pets following every player in the local player's world. The server mirrors
-- each player's equipped pet ids into the Player attribute "Pets" (comma-separated); models are
-- built locally with PetFactory (anchored, client-only) and moved with PivotTo. Pets near the
-- camera update every frame, far ones at ~10 Hz, players beyond 200 studs are skipped, and the
-- total is capped so busy servers stay smooth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetFactory = require(Shared.Visual.PetFactory)
local Pets = require(Shared.Definitions.Pets)

local Bus = require(script.Parent.Bus)

local PetFollowController = {}

local MAX_PETS = 40
local MAX_DISTANCE = 200
local NEAR_DISTANCE = 70
local PET_SIZE = 2.2

type Follower = { Model: Model, Id: string, Position: Vector3, Facing: Vector3 }
type Entry = { Player: Player, Ids: { string }, Followers: { Follower } }

local entries: { [Player]: Entry } = {}
local folder: Folder
local localPlayer = Players.LocalPlayer
local farAccumulator = 0
local localWorld = 0

local function parseIds(value: any): { string }
	local ids = {}
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			if Pets.Get(id) then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

local function clearFollowers(entry: Entry)
	for _, f in entry.Followers do
		f.Model:Destroy()
	end
	entry.Followers = {}
end

local function totalFollowers(): number
	local n = 0
	for _, entry in entries do
		n += #entry.Followers
	end
	return n
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function sameWorld(player: Player): boolean
	local world = player:GetAttribute("World")
	return world == nil or localWorld == 0 or world == localWorld
end

local function rebuild(entry: Entry)
	clearFollowers(entry)
	if not sameWorld(entry.Player) then
		return
	end
	local root = rootOf(entry.Player)
	local start = if root then root.Position else Vector3.zero
	for _, id in entry.Ids do
		if totalFollowers() >= MAX_PETS then
			break
		end
		local model = PetFactory.ForId(id, PET_SIZE)
		model.Name = "Pet_" .. id
		model.Parent = folder
		table.insert(entry.Followers, { Model = model, Id = id, Position = start, Facing = Vector3.new(0, 0, -1) })
	end
end

local function track(player: Player)
	if entries[player] then
		return
	end
	local entry: Entry = { Player = player, Ids = parseIds(player:GetAttribute("Pets")), Followers = {} }
	entries[player] = entry
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		entry.Ids = parseIds(player:GetAttribute("Pets"))
		rebuild(entry)
	end)
	player:GetAttributeChangedSignal("World"):Connect(function()
		rebuild(entry)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(rebuild, entry)
	end)
	rebuild(entry)
end

local function untrack(player: Player)
	local entry = entries[player]
	if entry then
		clearFollowers(entry)
		entries[player] = nil
	end
end

-- Slot offset (in the owner's local space) for pet `i` of `n`: an arc behind the character.
local function slotOffset(i: number, n: number): Vector3
	local spread = math.min(1, (n - 1) / 2) * 0.9
	local t = if n <= 1 then 0 else (i - 1) / (n - 1) * 2 - 1
	local angle = t * spread
	local radius = 5 + (if n > 3 then 1 else 0)
	return Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	farAccumulator += dt
	local updateFar = farAccumulator >= 0.1
	if updateFar then
		farAccumulator = 0
	end
	local t = os.clock()
	for _, entry in entries do
		local root = rootOf(entry.Player)
		if root == nil or #entry.Followers == 0 then
			continue
		end
		local distance = (root.Position - camPos).Magnitude
		local visible = distance <= MAX_DISTANCE
		local wanted: Instance? = if visible then folder else nil
		for _, f in entry.Followers do
			if f.Model.Parent ~= wanted then
				f.Model.Parent = wanted
			end
		end
		if not visible or (distance > NEAR_DISTANCE and not updateFar) then
			continue
		end
		local elapsed = if distance > NEAR_DISTANCE then 0.1 else dt
		local alpha = 1 - math.exp(-elapsed * 8)
		local velocity = root.AssemblyLinearVelocity
		local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
		local n = #entry.Followers
		for i, f in entry.Followers do
			local target = root.CFrame:PointToWorldSpace(slotOffset(i, n))
			target = Vector3.new(target.X, root.Position.Y - 1.6, target.Z)
			f.Position = f.Position:Lerp(target, alpha)
			if (f.Position - target).Magnitude > 40 then
				f.Position = target -- teleported owner: snap
			end
			local face = if moving then Vector3.new(velocity.X, 0, velocity.Z).Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if face.Magnitude > 0.01 then
				f.Facing = f.Facing:Lerp(face.Unit, alpha)
			end
			local bob = if moving then math.abs(math.sin(t * 9 + i)) * 0.9 else math.sin(t * 2.5 + i) * 0.25 + 0.25
			local pos = f.Position + Vector3.new(0, PET_SIZE * 0.5 + bob, 0)
			local look = if f.Facing.Magnitude > 0.01 then f.Facing else Vector3.new(0, 0, -1)
			f.Model:PivotTo(CFrame.lookAt(pos, pos + look))
		end
	end
end

function PetFollowController.Start()
	folder = Instance.new("Folder")
	folder.Name = "PetFollowers"
	folder.Parent = Workspace
	localWorld = (localPlayer:GetAttribute("World") :: number?) or 0
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	local function onWorld(worldId: number)
		localWorld = worldId
		for _, entry in entries do
			rebuild(entry)
		end
	end
	Bus.WorldChanged:Connect(onWorld)
	localPlayer:GetAttributeChangedSignal("World"):Connect(function()
		local w = localPlayer:GetAttribute("World")
		if type(w) == "number" then
			onWorld(w)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PetFollowController
