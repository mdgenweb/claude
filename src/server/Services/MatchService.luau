--!strict
-- Runs every live match (many arenas per server), routes validated player input to the
-- right match, and hands stations back to the queue when matches close.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)

local Server = script.Parent.Parent
local Match = require(Server.Battle.Match)
local Guard = require(Server.Util.Guard)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local BallService = require(script.Parent.BallService)
local AbilityService = require(script.Parent.AbilityService)
local RewardService = require(script.Parent.RewardService)
local ArenaService = require(script.Parent.ArenaService)
local BattleReplicator = require(script.Parent.BattleReplicator)

local MatchService = {}

local matches: { Match.Match } = {}
local byPlayer: { [Player]: Match.Match } = {}
local deps: Match.Deps
local queue: any -- QueueService (late-bound to avoid a require cycle)

function MatchService.InMatch(player: Player): boolean
	return if byPlayer[player] then true else false
end

function MatchService.Get(player: Player): Match.Match?
	return byPlayer[player]
end

function MatchService.Create(station: any, specs: { Match.ParticipantSpec }, practice: boolean): Match.Match
	local match = Match.new(deps, station, specs, practice)
	station.Match = match
	station.State = "InMatch"
	ArenaService.SetIdleVisuals(station, false)
	for _, p in match.Participants do
		if p.Player then
			byPlayer[p.Player] = match
		end
	end
	table.insert(matches, match)
	BattleReplicator.Attach(station, function()
		return match:Players()
	end, function()
		return match:FullState()
	end, function()
		return match:PublicState()
	end)
	match:Start()
	return match
end

local function onClosed(match: Match.Match)
	local i = table.find(matches, match)
	if i then
		table.remove(matches, i)
	end
	local station = match.Station
	for _, p in match.Participants do
		local player = p.Player
		if player and byPlayer[player] == match then
			byPlayer[player] = nil
		end
	end
	BattleReplicator.Detach(station)
	station.Match = nil
	task.delay(0.1, function()
		queue.ReleaseStation(station, match)
	end)
end

function MatchService.Init(registry: { [string]: any })
	queue = registry.QueueService
	local notify = Remotes.Event("Notify")
	deps = {
		BallService = BallService,
		AbilityService = AbilityService,
		EconomyService = EconomyService,
		DataService = DataService,
		RewardService = RewardService,
		ArenaService = ArenaService,
		Replicator = BattleReplicator,
		PrivateRemote = Remotes.Event("MatchPrivate"),
		Notify = function(player: Player, text: string)
			notify:FireClient(player, { Text = text, Kind = "Error" })
		end,
		OnPublicChanged = function(match: any)
			queue.BroadcastStation(match.Station)
		end,
		OnClosed = onClosed,
	}
end

function MatchService.Start()
	Guard.OnEvent(Remotes.Event("SelectionRequest"), 6, 10, function(player: Player, action: any, arg: any)
		if not Validate.OneOf(action, { "Pick", "Reroll", "Collection" }) then
			return
		end
		local match = byPlayer[player]
		if match then
			match:HandleSelection(player, action, arg)
		end
	end)
	Guard.OnUnreliable(Remotes.Unreliable("AimUpdate"), 15, 20, function(player: Player, angle: any)
		local match = byPlayer[player]
		if match then
			match:HandleAim(player, angle, false)
		end
	end)
	Guard.OnEvent(Remotes.Event("AimLock"), 4, 6, function(player: Player, angle: any)
		local match = byPlayer[player]
		if match then
			match:HandleAim(player, angle, true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local match = byPlayer[player]
		byPlayer[player] = nil
		if match then
			match:OnPlayerLeft(player)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, match: any in table.clone(matches) do
			local ok, err = pcall(function()
				match:Update(dt)
			end)
			if not ok then
				warn("[MatchService] match update failed: " .. tostring(err))
				pcall(function()
					match:Abort(tostring(err))
				end)
				if not match.Closed then
					onClosed(match)
				end
			end
		end
	end)
end

return MatchService
