--!strict
-- Server-wide live events: while one is active every player gets the Config/Events boosts and
-- special throws are more likely. Started by the schedule or by an admin; announced to clients via
-- ServerInfo { Kind = "Event", Active, Name, EndsAt }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Remotes = require(Shared.Net.Remotes)

local EventService = {}

local registry: { [string]: any } = {}
local manualName = ""
local manualEndsAt = 0
local serverInfo: RemoteEvent
local lastActive = false

-- Active event (name, endsAt) or nil.
function EventService.Current(): (string?, number)
	local now = os.time()
	if manualEndsAt > now then
		return manualName, manualEndsAt
	end
	for _, window in Events.Schedule do
		if now >= window.StartsAt and now < window.EndsAt then
			return window.Name, window.EndsAt
		end
	end
	return nil, 0
end

function EventService.IsActive(): boolean
	local name = EventService.Current()
	return name ~= nil
end

function EventService.SkillMultiplier(): number
	return if EventService.IsActive() then Events.SkillMultiplier else 1
end

function EventService.WinsMultiplier(): number
	return if EventService.IsActive() then Events.WinsMultiplier else 1
end

function EventService.SpecialLuck(): number
	return if EventService.IsActive() then Events.SpecialLuck else 1
end

local function broadcast(target: Player?)
	local name, endsAt = EventService.Current()
	local payload = { Kind = "Event", Active = name ~= nil, Name = name or "", EndsAt = endsAt }
	if target then
		serverInfo:FireClient(target, payload)
	else
		serverInfo:FireAllClients(payload)
	end
end

-- Begins (or extends) a manual event for `minutes`.
function EventService.Begin(minutes: number, name: string?)
	manualName = name or Events.Name
	manualEndsAt = os.time() + math.clamp(minutes, 1, 24 * 60) * 60
	broadcast(nil)
	local notify = registry.NotifyService
	if notify then
		notify.All(manualName .. " started! x2 Skill, x2 Wins, special throws x3 more likely!", "Rare")
	end
	local data = registry.DataService
	if data then
		for _, player in Players:GetPlayers() do
			data.MarkDirty(player)
		end
	end
end

function EventService.Stop()
	manualEndsAt = 0
	broadcast(nil)
end

function EventService.Init(reg: { [string]: any })
	registry = reg
	serverInfo = Remotes.Event("ServerInfo")
end

function EventService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, broadcast, player)
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			local active = EventService.IsActive()
			if active ~= lastActive then
				lastActive = active
				broadcast(nil)
				local data = registry.DataService
				if data then
					for _, player in Players:GetPlayers() do
						data.MarkDirty(player)
					end
				end
			end
		end
	end)
end

return EventService
