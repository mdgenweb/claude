--!strict
-- XP and levels. Every level-up grants the reward from LevelRewards (reference: "Lv 3 Reward").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local LevelRewards = require(Shared.Definitions.LevelRewards)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local LevelService = {}

local rewardRemote: RemoteEvent

function LevelService.Init()
	rewardRemote = Remotes.Event("RewardPopup")
end

-- Returns { Levels = {gained levels}, XP = amount }
function LevelService.AddXP(player: Player, amount: number): { [string]: any }
	local gained: { number } = {}
	DataService.Update(player, function(profile)
		profile.XP += math.max(0, math.floor(amount))
		while profile.Level < Economy.MaxLevel and profile.XP >= Economy.XPToNext(profile.Level) do
			profile.XP -= Economy.XPToNext(profile.Level)
			profile.Level += 1
			table.insert(gained, profile.Level)
		end
		return true
	end)
	for _, level in gained do
		local reward = LevelRewards.For(level)
		EconomyService.GrantReward(player, reward :: any)
		rewardRemote:FireClient(player, { Kind = "LevelUp", Level = level, Reward = reward })
	end
	return { Levels = gained, XP = amount }
end

return LevelService
