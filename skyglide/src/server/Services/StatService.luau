--!strict
-- Central place where Skill, Wins and XP are granted. Every reward in the game flows through
-- here, so multipliers, limits, stats and level-ups are applied consistently and only on the
-- server. Also tracks the Friend Boost (friends in the same server).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Sim.Progression)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

local StatService = {}

StatService.LevelUp = Signal.new() -- (player, newLevel)
StatService.SkillGained = Signal.new() -- (player, amount, source)
StatService.WinsGained = Signal.new() -- (player, amount, source)

local registry: { [string]: any } = {}
local friendCounts: { [Player]: number } = {}
local friendCache: { [Player]: { [number]: boolean } } = {}

-- Pass ownership lives in MonetizationService (late-bound to avoid a require cycle).
local function passes(player: Player): { [string]: boolean }
	local monetization = registry.MonetizationService
	if monetization then
		return monetization.Passes(player)
	end
	return {}
end

function StatService.Context(player: Player): Progression.Context
	return {
		Passes = passes(player),
		Friends = friendCounts[player] or 0,
		Premium = player.MembershipType == Enum.MembershipType.Premium,
		Now = os.time(),
	}
end

function StatService.SkillMultiplier(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	return Progression.SkillMultiplier(profile, StatService.Context(player))
end

function StatService.WinsMultiplier(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	return Progression.WinsMultiplier(profile, StatService.Context(player))
end

function StatService.Luck(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	return Progression.Luck(profile, StatService.Context(player))
end

-- Adds already-multiplied Skill and re-derives the level. Training and rings stop paying at the
-- level cap (Economy.CappedSources); purchases, gifts and codes always pay. Returns the amount added.
function StatService.AddSkill(player: Player, amount: number, source: string): number
	if amount ~= amount or amount <= 0 then
		return 0
	end
	local levels = 0
	local reachedCap = false
	local added = DataService.Update(player, function(p)
		if not Progression.SourcePays(p, source) then
			return 0
		end
		local before = p.Skill
		p.Skill = math.min(Economy.Limits.MaxSkill, p.Skill + amount)
		local delta = p.Skill - before
		p.Stats.TotalSkill = math.min(1e300, p.Stats.TotalSkill + delta)
		levels = Progression.SyncLevel(p)
		reachedCap = levels > 0 and Progression.IsMaxLevel(p)
		return delta
	end) or 0
	if added > 0 then
		StatService.SkillGained:Fire(player, added, source)
	end
	if levels > 0 then
		local profile = DataService.Get(player)
		if profile then
			StatService.LevelUp:Fire(player, profile.Level)
		end
		local notify = registry.NotifyService
		if notify and reachedCap then
			notify.Toast(player, "MAX LEVEL! Rebirth is ready (100%)", "Success")
		end
	end
	return added
end

-- True when training/rings no longer pay (level cap reached).
function StatService.AtCap(player: Player): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and Progression.IsMaxLevel(profile)
end

-- Adds already-multiplied Wins. Returns the amount actually added.
function StatService.AddWins(player: Player, amount: number, source: string): number
	if amount ~= amount or amount <= 0 then
		return 0
	end
	local added = DataService.Update(player, function(p)
		local before = p.Wins
		p.Wins = math.min(Economy.Limits.MaxWins, p.Wins + amount)
		local delta = p.Wins - before
		p.Stats.TotalWins = math.min(1e300, p.Stats.TotalWins + delta)
		return delta
	end) or 0
	if added > 0 then
		StatService.WinsGained:Fire(player, added, source)
	end
	return added
end

-- Spends Wins atomically. Returns false (and changes nothing) if the player can't afford it.
function StatService.SpendWins(player: Player, amount: number): boolean
	if amount ~= amount or amount < 0 then
		return false
	end
	return DataService.Update(player, function(p)
		if p.Wins < amount then
			return false
		end
		p.Wins -= amount
		return true
	end) == true
end

-- Training-rep-equivalent Skill (used by gifts/daily: "Reps" rewards).
function StatService.RepsToSkill(player: Player, reps: number, padMultiplier: number): number
	return reps * Economy.TrainRepBase * padMultiplier * StatService.SkillMultiplier(player)
end

function StatService.FriendBoost(player: Player): number
	return Progression.FriendBoost(friendCounts[player] or 0)
end

local function recountFriends()
	local list = Players:GetPlayers()
	for _, player in list do
		local cache = friendCache[player]
		local count = 0
		if cache then
			for _, other in list do
				if other ~= player and cache[other.UserId] then
					count += 1
				end
			end
		end
		if friendCounts[player] ~= count then
			friendCounts[player] = count
			DataService.MarkDirty(player)
		end
	end
end

local function cacheFriendships(player: Player)
	local cache = friendCache[player] or {}
	friendCache[player] = cache
	for _, other in Players:GetPlayers() do
		if other ~= player and cache[other.UserId] == nil then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok then
				cache[other.UserId] = isFriend
				local otherCache = friendCache[other]
				if otherCache then
					otherCache[player.UserId] = isFriend
				end
			end
		end
	end
	recountFriends()
end

function StatService.Init(reg: { [string]: any })
	registry = reg
	DataService.AddDecorator(function(player, view)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		local ctx = StatService.Context(player)
		local breakdown = Progression.SkillBreakdown(profile, ctx)
		view.Derived = {
			SkillMultiplier = breakdown.Total,
			Breakdown = breakdown,
			WinsMultiplier = Progression.WinsMultiplier(profile, ctx),
			Luck = Progression.Luck(profile, ctx),
			FriendBoost = Progression.FriendBoost(ctx.Friends),
			Friends = ctx.Friends,
			LevelCap = Progression.LevelCap(profile),
			XPToNext = Economy.XPToNext(profile.Level),
			RebirthProgress = Progression.RebirthProgress(profile),
			CanRebirth = Progression.CanRebirth(profile),
			NextRebirthMultiplier = Economy.RebirthMultiplier(profile.Rebirths + 1),
			SkillPerRing = Progression.SkillPerRing(profile),
			PetSlots = Progression.PetSlots(ctx),
			Passes = table.clone(ctx.Passes),
			ServerTime = os.time(),
		}
	end)
end

function StatService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(cacheFriendships, player)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				task.spawn(cacheFriendships, other)
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(cacheFriendships, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player] = nil
		friendCounts[player] = nil
		task.defer(recountFriends)
	end)
end

StatService.Format = Format

return StatService
