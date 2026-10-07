--!strict
-- Match rewards, first-battle gacha, and the Like + Join Group reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.Game)
local Lobby = require(Shared.Config.Lobby)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LevelService = require(script.Parent.LevelService)
local QuestService = require(script.Parent.QuestService)

local RewardService = {}

local rewardRemote: RemoteEvent

function RewardService.Init()
	rewardRemote = Remotes.Event("RewardPopup")
end

export type MatchOutcome = {
	Won: boolean,
	Forfeit: boolean,
	Practice: boolean,
	VsFriend: boolean,
}

-- Grants and returns the reward summary shown on the results screen.
function RewardService.GrantMatch(player: Player, outcome: MatchOutcome): { [string]: any }
	local tier = if outcome.Won then (if outcome.Forfeit then Economy.MatchRewards.ForfeitWin else Economy.MatchRewards.Win) else Economy.MatchRewards.Loss
	local coins, xp = tier.Coins, tier.XP
	if outcome.Practice then
		coins = math.max(1, math.floor(coins * GameConfig.Bots.RewardMultiplier))
		xp = math.max(1, math.floor(xp * GameConfig.Bots.RewardMultiplier))
	end

	local firstBattle = false
	DataService.Update(player, function(profile)
		local stats = profile.Stats
		stats.Matches += 1
		if outcome.Won then
			stats.Wins += 1
			stats.Streak += 1
			stats.BestStreak = math.max(stats.BestStreak, stats.Streak)
		else
			stats.Losses += 1
			stats.Streak = 0
		end
		if not outcome.Practice then
			local week = (os.time() - Lobby.Leaderboards.WeekEpochOffset) // 604800
			if profile.Weekly.Week ~= week then
				profile.Weekly.Week = week
				profile.Weekly.Wins = 0
				profile.Weekly.RobuxSpent = 0
			end
			if outcome.Won then
				profile.Weekly.Wins += 1
			end
		end
		if not profile.Flags.FirstBattle then
			profile.Flags.FirstBattle = true
			firstBattle = true
		end
		return true
	end)

	EconomyService.AddCurrency(player, "Coins", coins)
	local levelInfo = LevelService.AddXP(player, xp)

	if not outcome.Practice then
		QuestService.Progress(player, "Play", 1)
		if outcome.Won then
			QuestService.Progress(player, "Win", 1)
		end
		if outcome.VsFriend then
			QuestService.Progress(player, "FriendDuel", 1)
		end
	end

	if firstBattle then
		EconomyService.GrantItem(player, "Ticket", Economy.FirstBattleTicket, 1)
	end

	local profile = DataService.Get(player)
	local summary = {
		Coins = coins,
		XP = xp,
		Level = if profile then profile.Level else 1,
		XPNow = if profile then profile.XP else 0,
		XPNeed = if profile then Economy.XPToNext(profile.Level) else 20,
		LevelsGained = levelInfo.Levels,
		Streak = if profile then profile.Stats.Streak else 0,
		Practice = outcome.Practice,
	}
	if firstBattle then
		-- shown after the results screen closes (CONFIRMED modal in the reference)
		task.delay(0.2, function()
			if player.Parent then
				rewardRemote:FireClient(player, { Kind = "FirstBattle", Ticket = Economy.FirstBattleTicket })
			end
		end)
	end
	return summary
end

function RewardService.ClaimGroup(player: Player): { [string]: any }
	local profile = DataService.Get(player)
	if profile == nil then
		return { ok = false, error = "Your data is still loading." }
	end
	if profile.Flags.GroupClaimed then
		return { ok = false, error = "You already claimed this reward." }
	end
	local groupId = Economy.Group.Id
	if groupId == 0 then
		if not RunService:IsStudio() then
			return { ok = false, error = "Group rewards are not set up yet." }
		end
	else
		local ok, inGroup = pcall(function()
			return player:IsInGroup(groupId)
		end)
		if not ok then
			return { ok = false, error = "Couldn't check the group. Try again." }
		end
		if not inGroup then
			return { ok = false, error = "Like the game and join the group first!" }
		end
	end
	local claimed = DataService.Update(player, function(p)
		if p.Flags.GroupClaimed then
			return false
		end
		p.Flags.GroupClaimed = true
		return EconomyService.AddToProfile(p, "Ticket", Economy.Group.RewardTicket, 1)
	end)
	if claimed ~= true then
		return { ok = false, error = "You already claimed this reward." }
	end
	rewardRemote:FireClient(player, { Kind = "Group", Ticket = Economy.Group.RewardTicket })
	return { ok = true, message = "Advanced Orb Gacha +1!" }
end

return RewardService
