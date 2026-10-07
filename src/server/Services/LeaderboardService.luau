--!strict
-- leaderstats + all-time and weekly OrderedDataStore boards (reference: "Top Spenders" and
-- "Weekly Top Spenders" boards with a rewards column). The ranked stat is configurable.
-- Also pays last week's top 3 when they next join.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lobby = require(Shared.Config.Lobby)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type Profile = DataService.Profile
type Entry = { Rank: number, UserId: number, Name: string, Value: number }

local LeaderboardService = {}

local Config = Lobby.Leaderboards
local WEEK = 604800

local boardRemote: RemoteEvent
local rewardRemote: RemoteEvent
local storesOk = true
local nameCache: { [number]: string } = {}
local dirty: { [Player]: boolean } = {}
local latest: { [string]: any } = { AllTime = {}, Weekly = {}, Ranks = {} }

local function weekIndex(t: number?): number
	return ((t or os.time()) - Config.WeekEpochOffset) // WEEK
end

local function weekEndsAt(): number
	return (weekIndex() + 1) * WEEK + Config.WeekEpochOffset
end

local function statValue(profile: Profile, weekly: boolean): number
	if weekly then
		if profile.Weekly.Week ~= weekIndex() then
			return 0
		end
		return if Config.Stat == "RobuxSpent" then profile.Weekly.RobuxSpent else profile.Weekly.Wins
	end
	return if Config.Stat == "RobuxSpent" then profile.Stats.RobuxSpent else profile.Stats.Wins
end

local function storeFor(week: number?): OrderedDataStore?
	if not storesOk then
		return nil
	end
	local name = if week then string.format("OrbClash_Lb_%s_W%d", Config.Stat, week) else "OrbClash_Lb_" .. Config.Stat
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then store else nil
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else ("Player" .. userId)
	nameCache[userId] = result
	return result
end

local function fetch(store: OrderedDataStore?, size: number): { Entry }?
	if store == nil then
		return nil
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, size)
	end)
	if not ok then
		return nil
	end
	local entries: { Entry } = {}
	for rank, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { Rank = rank, UserId = userId, Name = "", Value = item.value })
		end
	end
	return entries
end

-- Board built from the players in this server (Studio / DataStore outage fallback).
local function localBoard(weekly: boolean): { Entry }
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile then
			table.insert(entries, { Rank = 0, UserId = player.UserId, Name = player.Name, Value = statValue(profile, weekly) })
		end
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	for i, e in entries do
		e.Rank = i
	end
	return entries
end

local function refresh()
	local allTime = fetch(storeFor(nil), 100) or localBoard(false)
	local weekly = fetch(storeFor(weekIndex()), 100) or localBoard(true)
	local ranks: { [string]: { AllTime: number?, Weekly: number? } } = {}
	for _, player in Players:GetPlayers() do
		ranks[tostring(player.UserId)] = {}
	end
	for _, e in allTime do
		local r = ranks[tostring(e.UserId)]
		if r then
			r.AllTime = e.Rank
		end
	end
	for _, e in weekly do
		local r = ranks[tostring(e.UserId)]
		if r then
			r.Weekly = e.Rank
		end
	end
	local function top(list: { Entry }): { Entry }
		local out = {}
		for i = 1, math.min(Config.Size, #list) do
			local e = list[i]
			e.Name = if e.Name ~= "" then e.Name else nameOf(e.UserId)
			table.insert(out, e)
		end
		return out
	end
	latest = {
		Stat = Config.Stat,
		AllTime = top(allTime),
		Weekly = top(weekly),
		Ranks = ranks,
		WeekEndsAt = weekEndsAt(),
		Rewards = Economy.WeeklyRewards,
	}
	boardRemote:FireAllClients(latest)
end

local function updateLeaderstats(player: Player, profile: Profile)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		stats = folder
	end
	local container = stats :: Instance
	local wins = container:FindFirstChild("Wins") :: IntValue?
	if wins == nil then
		local value = Instance.new("IntValue")
		value.Name = "Wins"
		value.Parent = container
		wins = value
	end
	(wins :: IntValue).Value = profile.Stats.Wins
end

local function flush(player: Player)
	local profile = DataService.Get(player)
	if profile == nil then
		return
	end
	dirty[player] = nil
	local key = tostring(player.UserId)
	local allTime = storeFor(nil)
	local weekly = storeFor(weekIndex())
	if allTime then
		pcall(function()
			allTime:SetAsync(key, statValue(profile, false))
		end)
	end
	if weekly then
		local value = statValue(profile, true)
		if value > 0 then
			pcall(function()
				weekly:SetAsync(key, value)
			end)
		end
	end
end

-- Pays last week's top 3 (once per week, on join).
local function payWeekly(player: Player, profile: Profile)
	local lastWeek = weekIndex() - 1
	local key = tostring(lastWeek)
	if profile.Flags.WeeklyPaid[key] then
		return
	end
	local entries = fetch(storeFor(lastWeek), 3)
	if entries == nil then
		return -- try again next join
	end
	local rank: number? = nil
	for _, e in entries do
		if e.UserId == player.UserId then
			rank = e.Rank
		end
	end
	DataService.Update(player, function(p)
		p.Flags.WeeklyPaid[key] = true
		return true
	end)
	local reward = if rank then Economy.WeeklyRewards[rank] else nil
	if reward then
		EconomyService.GrantItem(player, "Ticket", reward.Ticket, reward.Count)
		rewardRemote:FireClient(player, { Kind = "Weekly", Rank = rank, Ticket = reward.Ticket, Count = reward.Count })
	end
end

function LeaderboardService.Init()
	boardRemote = Remotes.Event("LeaderboardData")
	rewardRemote = Remotes.Event("RewardPopup")
	if DataService.IsMock() then
		storesOk = false
	end
end

function LeaderboardService.Start()
	DataService.Loaded:Connect(function(player: Player, profile: Profile)
		updateLeaderstats(player, profile)
		boardRemote:FireClient(player, latest)
		task.spawn(payWeekly, player, profile)
	end)
	DataService.Changed:Connect(function(player: Player, profile: Profile)
		updateLeaderstats(player, profile)
		dirty[player] = true
	end)
	DataService.Releasing:Connect(function(player: Player, _profile: Profile)
		if dirty[player] then
			flush(player)
		end
		dirty[player] = nil
	end)
	task.spawn(function()
		while true do
			for player in dirty do
				if player.Parent then
					flush(player)
				end
			end
			task.wait(Config.RefreshSeconds / 2)
		end
	end)
	task.spawn(function()
		task.wait(3)
		while true do
			pcall(refresh)
			task.wait(Config.RefreshSeconds)
		end
	end)
end

return LeaderboardService
