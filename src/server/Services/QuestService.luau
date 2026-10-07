--!strict
-- Daily quests (reset at 00:00 UTC). Progress is driven by server-side match results only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestDefinitions = require(Shared.Definitions.QuestDefinitions)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type Profile = DataService.Profile

local QuestService = {}

local notify: RemoteEvent

local function ensureToday(profile: Profile)
	local today = QuestDefinitions.DayIndex(os.time())
	if profile.Quests.Day ~= today then
		profile.Quests.Day = today
		profile.Quests.Progress = {}
		profile.Quests.Done = {}
	end
end

function QuestService.Init()
	notify = Remotes.Event("Notify")
	DataService.Loaded:Connect(function(player: Player, _profile: Profile)
		DataService.Update(player, function(p)
			ensureToday(p)
			return true
		end)
	end)
end

function QuestService.Start()
	-- roll quests over for players who stay online across midnight
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in game:GetService("Players"):GetPlayers() do
				local profile = DataService.Get(player)
				if profile and profile.Quests.Day ~= QuestDefinitions.DayIndex(os.time()) then
					DataService.Update(player, function(p)
						ensureToday(p)
						return true
					end)
				end
			end
		end
	end)
end

function QuestService.Progress(player: Player, event: string, amount: number?)
	local completed: { QuestDefinitions.Quest } = {}
	DataService.Update(player, function(profile)
		ensureToday(profile)
		for _, quest in QuestDefinitions.Daily do
			if quest.Event == event and not profile.Quests.Done[quest.Id] then
				local value = math.min(quest.Goal, (profile.Quests.Progress[quest.Id] or 0) + (amount or 1))
				profile.Quests.Progress[quest.Id] = value
				if value >= quest.Goal then
					profile.Quests.Done[quest.Id] = true
					table.insert(completed, quest)
				end
			end
		end
		return true
	end)
	for _, quest in completed do
		EconomyService.AddCurrency(player, "Coins", quest.Reward.Coins)
		notify:FireClient(player, { Text = string.format("Quest complete: %s  +%d", quest.Title, quest.Reward.Coins), Kind = "Quest" })
	end
end

return QuestService
