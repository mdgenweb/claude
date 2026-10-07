--!strict
-- Interest-managed battle replication. Participants and nearby spectators receive:
--   * BattleEvent (reliable): batched simulation events (spawns, hits, deaths, FX)
--   * BattleSnapshot (unreliable): 20 Hz binary snapshots for interpolation
-- Late spectators get a full-state event first so they can render mid-round.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local SnapshotCodec = require(Shared.Net.SnapshotCodec)
local GameConfig = require(Shared.Config.Game)

local BattleReplicator = {}

type Feed = {
	station: any, -- ArenaService.Station
	viewers: { [Player]: boolean },
	participants: () -> { Player },
	fullState: () -> { [string]: any }?,
	publicState: () -> { [string]: any }?,
}

local feeds: { [number]: Feed } = {}
local eventRemote: RemoteEvent
local snapshotRemote: UnreliableRemoteEvent
local publicRemote: RemoteEvent

local function inRange(player: Player, station: any): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return false
	end
	return (root.Position - station.CFrame.Position).Magnitude <= GameConfig.SpectatorRange
end

local function addViewer(feed: Feed, player: Player)
	feed.viewers[player] = true
	local full = feed.fullState()
	if full then
		eventRemote:FireClient(player, feed.station.Index, { { t = "Full", state = full } })
	end
	local public = feed.publicState()
	if public then
		publicRemote:FireClient(player, public)
	end
end

local function refresh(feed: Feed)
	local wanted: { [Player]: boolean } = {}
	for _, player in feed.participants() do
		if player.Parent then
			wanted[player] = true
		end
	end
	for _, player in Players:GetPlayers() do
		if not wanted[player] and inRange(player, feed.station) then
			wanted[player] = true
		end
	end
	for player in feed.viewers do
		if not wanted[player] then
			feed.viewers[player] = nil
			if player.Parent then
				eventRemote:FireClient(player, feed.station.Index, { { t = "Clear" } })
			end
		end
	end
	for player in wanted do
		if not feed.viewers[player] then
			addViewer(feed, player)
		end
	end
end

function BattleReplicator.Attach(
	station: any,
	participants: () -> { Player },
	fullState: () -> { [string]: any }?,
	publicState: () -> { [string]: any }?
)
	local feed: Feed = {
		station = station,
		viewers = {},
		participants = participants,
		fullState = fullState,
		publicState = publicState,
	}
	feeds[station.Index] = feed
	refresh(feed)
end

function BattleReplicator.Detach(station: any)
	local feed = feeds[station.Index]
	if feed == nil then
		return
	end
	feeds[station.Index] = nil
	for player in feed.viewers do
		if player.Parent then
			eventRemote:FireClient(player, station.Index, { { t = "Clear" } })
		end
	end
end

function BattleReplicator.SendEvents(station: any, events: { { [string]: any } })
	if #events == 0 then
		return
	end
	local feed = feeds[station.Index]
	if feed == nil then
		return
	end
	for player in feed.viewers do
		eventRemote:FireClient(player, station.Index, events)
	end
end

function BattleReplicator.SendSnapshot(station: any, snapshot: SnapshotCodec.Snapshot)
	local feed = feeds[station.Index]
	if feed == nil or next(feed.viewers) == nil then
		return
	end
	local payload = SnapshotCodec.Encode(snapshot)
	for player in feed.viewers do
		snapshotRemote:FireClient(player, payload)
	end
end

function BattleReplicator.SendPublic(station: any, payload: { [string]: any })
	local feed = feeds[station.Index]
	if feed == nil then
		return
	end
	for player in feed.viewers do
		publicRemote:FireClient(player, payload)
	end
end

function BattleReplicator.Init()
	eventRemote = Remotes.Event("BattleEvent")
	snapshotRemote = Remotes.Unreliable("BattleSnapshot")
	publicRemote = Remotes.Event("MatchPublic")
end

function BattleReplicator.Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, feed in feeds do
			feed.viewers[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, feed in feeds do
				refresh(feed)
			end
		end
	end)
end

return BattleReplicator
