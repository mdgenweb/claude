--!strict
-- World unlocks and travel. Unlocking costs Wins and needs rebirths (checked here); travelling
-- moves the character to that world's spawn. Characters always respawn in their current world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)
local MapService = require(script.Parent.MapService)

local WorldService = {}

local registry: { [string]: any } = {}
local worldChanged: RemoteEvent

local function placeCharacter(player: Player, worldId: number)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(MapService.SpawnCFrame(worldId) + Vector3.new(math.random(-6, 6), 0, math.random(-4, 4)))
	end
	player:SetAttribute("World", worldId)
end

local function enterWorld(player: Player, worldId: any): { [string]: any }
	if not Validate.Integer(worldId, 1, Worlds.Count) then
		return { ok = false, error = "Unknown world." }
	end
	local world = Worlds.Get(worldId) :: Worlds.World
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if registry.FlightService and registry.FlightService.IsFlying(player) then
		return { ok = false, error = "Wait until your glider lands." }
	end
	local key = tostring(world.Id)
	local unlockedNow = false
	if not profile.Worlds[key] then
		if world.Id > 1 and not profile.Worlds[tostring(world.Id - 1)] then
			return { ok = false, error = "Unlock the previous world first!" }
		end
		if world.UnlockZone and not profile.Zones[world.UnlockZone] then
			local zone = Zones.Get(world.UnlockZone)
			local prevWorld = Worlds.Get(world.Id - 1)
			return {
				ok = false,
				error = string.format("Throw to %s in %s to unlock %s!", if zone then zone.Name else "the end of the river", if prevWorld then prevWorld.Name else "the last world", world.Name),
			}
		end
		if profile.Rebirths < world.UnlockRebirths then
			return { ok = false, error = string.format("%s needs %d rebirths!", world.Name, world.UnlockRebirths) }
		end
		if not StatService.SpendWins(player, world.UnlockWins) then
			return { ok = false, error = string.format("%s costs %s Wins!", world.Name, Format.Short(world.UnlockWins)) }
		end
		DataService.Update(player, function(p)
			p.Worlds[key] = true
			return true
		end)
		unlockedNow = true
	end
	DataService.Update(player, function(p)
		p.World = world.Id
		return true
	end)
	placeCharacter(player, world.Id)
	worldChanged:FireClient(player, world.Id)
	local notify = registry.NotifyService
	if notify and unlockedNow then
		notify.All(string.format("%s unlocked %s!", player.DisplayName, world.Name), "Success")
	end
	return { ok = true, unlocked = unlockedNow }
end

function WorldService.Init(reg: { [string]: any })
	registry = reg
	worldChanged = Remotes.Event("WorldChanged")
end

function WorldService.Start()
	Guard.OnInvoke(Remotes.Function("RequestEnterWorld"), 1, 3, enterWorld)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- a respawn mid-flight cancels that flight (no payout for a throw you can't watch)
			if registry.FlightService then
				registry.FlightService.Cancel(player)
			end
			local profile = DataService.WaitFor(player, 30)
			local worldId = if profile then profile.World else 1
			if not character:FindFirstChild("HumanoidRootPart") then
				character:WaitForChild("HumanoidRootPart", 10)
			end
			task.wait()
			if character.Parent then
				placeCharacter(player, worldId)
				worldChanged:FireClient(player, worldId)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return WorldService
