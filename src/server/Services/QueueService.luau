--!strict
-- Lobby matchmaking through the battle pads (reference: walk onto a pad, press E, "1/2 PLAYERS",
-- Invite / Leave panel) plus the green Play button (quick-join) and practice bots.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)

local DataService = require(script.Parent.DataService)
local ArenaService = require(script.Parent.ArenaService)
local MatchService = require(script.Parent.MatchService)

type Station = ArenaService.Station
type Pad = ArenaService.Pad

local QueueService = {}

local padOf: { [Player]: { Station: Station, Pad: Pad } } = {}
type Invite = { From: Player, To: Player, Station: Station, Expires: number }
local invites: { [string]: Invite } = {}
local foundTokens: { [Station]: number } = {}
local tradingService: any

local stationRemote: RemoteEvent
local notifyRemote: RemoteEvent
local inviteRemote: RemoteEvent

local function notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, { Text = text, Kind = kind or "Error" })
end

local function busyReason(player: Player): string?
	if MatchService.InMatch(player) then
		return "You're already in a battle."
	end
	if tradingService and tradingService.IsTrading(player) then
		return "Finish your trade first."
	end
	return nil
end

function QueueService.IsQueued(player: Player): boolean
	return padOf[player] ~= nil
end

local function stationPayload(station: Station): { [string]: any }
	local pads = {}
	for _, pad in station.Pads do
		local occupant = pad.Occupant
		local bot = pad.Bot
		table.insert(pads, {
			Team = pad.Team,
			UserId = if occupant then occupant.UserId elseif bot then bot.Id else 0,
			Name = if occupant then occupant.DisplayName elseif bot then bot.Name else "",
		})
	end
	return {
		Id = station.Id,
		Index = station.Index,
		Mode = station.Mode,
		State = station.State,
		Capacity = #station.Pads,
		Pads = pads,
		Match = if station.Match then station.Match:Summary() else nil,
	}
end

function QueueService.BroadcastStation(station: Station)
	stationRemote:FireAllClients(stationPayload(station))
end

local function destroyBot(pad: Pad)
	local bot = pad.Bot
	if bot and bot.Model then
		bot.Model:Destroy()
	end
	pad.Bot = nil
end

local function spawnBot(station: Station, pad: Pad, n: number)
	local bot: { [string]: any } = { Name = GameConfig.Bots.Name, Id = -n, Model = nil }
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		model.Name = GameConfig.Bots.Name
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = GameConfig.Bots.Name
		end
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = true
		end
		model:PivotTo(ArenaService.PadCFrame(station, pad.Index))
		model.Parent = station.Model
		bot.Model = model
	end
	pad.Bot = bot
end

local function updatePrompts(station: Station)
	for _, pad in station.Pads do
		pad.Prompt.Enabled = station.State ~= "InMatch" and station.State ~= "MatchFound" and pad.Occupant == nil and pad.Bot == nil
	end
end

local function startMatch(station: Station)
	local specs: { any } = {}
	local practice = false
	for _, pad in station.Pads do
		local bot = pad.Bot
		if pad.Occupant then
			table.insert(specs, { Player = pad.Occupant, Team = pad.Team, Pad = pad.Index })
		elseif bot then
			practice = true
			table.insert(specs, { BotName = bot.Name, BotId = bot.Id, Team = pad.Team, Pad = pad.Index })
		end
	end
	MatchService.Create(station, specs, practice)
	updatePrompts(station)
	QueueService.BroadcastStation(station)
end

local function refreshStation(station: Station)
	if station.State == "InMatch" then
		updatePrompts(station)
		return
	end
	local count = ArenaService.Occupants(station)
	local capacity = #station.Pads
	local humans = 0
	for _, pad in station.Pads do
		if pad.Occupant then
			humans += 1
		end
	end
	if humans == 0 then
		-- no humans left: clear any practice bots
		for _, pad in station.Pads do
			destroyBot(pad)
		end
		count = 0
	end
	if count >= capacity then
		station.State = "MatchFound"
		local token = (foundTokens[station] or 0) + 1
		foundTokens[station] = token
		task.spawn(function()
			for remaining = GameConfig.Timings.MatchFoundCountdown, 1, -1 do
				if foundTokens[station] ~= token or station.State ~= "MatchFound" then
					return
				end
				ArenaService.SetLabel(station, string.format("STARTING IN %d", remaining), "#7CFF6B")
				task.wait(1)
			end
			if foundTokens[station] == token and station.State == "MatchFound" and ArenaService.Occupants(station) >= capacity then
				startMatch(station)
			end
		end)
	else
		foundTokens[station] = (foundTokens[station] or 0) + 1
		station.State = if count == 0 then "Idle" else "Waiting"
		ArenaService.SetLabel(station, string.format("%d/%d PLAYERS", count, capacity))
	end
	updatePrompts(station)
	QueueService.BroadcastStation(station)
end

function QueueService.JoinPad(player: Player, station: Station, padIndex: number): boolean
	if DataService.Get(player) == nil then
		notify(player, "Still loading your data...")
		return false
	end
	local reason = busyReason(player)
	if reason then
		notify(player, reason)
		return false
	end
	if station.State == "InMatch" or station.State == "MatchFound" then
		notify(player, "This arena is busy. Try another one!")
		return false
	end
	local pad = station.Pads[padIndex]
	if pad == nil or pad.Occupant ~= nil or pad.Bot ~= nil then
		notify(player, "That spot is taken.")
		return false
	end
	if padOf[player] then
		QueueService.Leave(player, true)
	end
	pad.Occupant = player
	padOf[player] = { Station = station, Pad = pad }
	if GameConfig.LockCharactersOnPads then
		ArenaService.LockCharacter(player, ArenaService.PadCFrame(station, padIndex))
	end
	refreshStation(station)
	return true
end

function QueueService.Leave(player: Player, switching: boolean?): boolean
	local entry = padOf[player]
	if entry == nil then
		return false
	end
	local station = entry.Station
	if station.State == "InMatch" then
		return false
	end
	entry.Pad.Occupant = nil
	padOf[player] = nil
	if player.Parent then
		ArenaService.UnlockCharacter(player, if switching then nil else ArenaService.ReleaseCFrame(station, entry.Pad.Index))
	end
	refreshStation(station)
	return true
end

local function freePadFor(station: Station, preferTeam: number?): Pad?
	local counts = { 0, 0 }
	for _, pad in station.Pads do
		if pad.Occupant or pad.Bot then
			counts[pad.Team] += 1
		end
	end
	local best: Pad? = nil
	for _, pad in station.Pads do
		if pad.Occupant == nil and pad.Bot == nil then
			if preferTeam and pad.Team == preferTeam then
				return pad
			end
			if best == nil or counts[pad.Team] < counts[best.Team] then
				best = pad
			end
		end
	end
	return best
end

function QueueService.QuickPlay(player: Player, mode: string)
	local entry = padOf[player]
	if entry and entry.Station.Mode == mode then
		notify(player, "You're already waiting for a battle.", "Info")
		return
	end
	local best: Station? = nil
	local bestCount = -1
	for _, station in ArenaService.Stations do
		if station.Mode == mode and (station.State == "Idle" or station.State == "Waiting") and station ~= (entry and entry.Station) then
			local count = ArenaService.Occupants(station)
			if count < #station.Pads and count > bestCount then
				best = station
				bestCount = count
			end
		end
	end
	if best == nil then
		notify(player, "All arenas are busy right now. Try again in a moment!")
		return
	end
	local pad = freePadFor(best, nil)
	if pad then
		QueueService.JoinPad(player, best, pad.Index)
	end
end

function QueueService.Practice(player: Player)
	if not GameConfig.Bots.Enabled then
		return
	end
	local entry = padOf[player]
	if entry == nil or entry.Station.State ~= "Waiting" then
		notify(player, "Stand on a battle pad first.")
		return
	end
	local station = entry.Station
	local n = 0
	for _, pad in station.Pads do
		if pad.Occupant == nil and pad.Bot == nil then
			n += 1
			spawnBot(station, pad, n)
		end
	end
	refreshStation(station)
end

function QueueService.Invite(player: Player, targetUserId: any)
	if not Validate.Integer(targetUserId, 1, 2 ^ 53) then
		return
	end
	local entry = padOf[player]
	if entry == nil or entry.Station.State ~= "Waiting" or freePadFor(entry.Station, nil) == nil then
		notify(player, "Stand on a battle pad with a free spot to invite someone.")
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil or target == player then
		notify(player, "That player isn't in this server.")
		return
	end
	if busyReason(target) or padOf[target] then
		notify(player, target.DisplayName .. " is busy right now.")
		return
	end
	for id, inv in invites do
		if inv.From == player and inv.To == target and os.clock() < inv.Expires then
			notify(player, "Invite already sent.", "Info")
			return
		end
		if os.clock() >= inv.Expires then
			invites[id] = nil
		end
	end
	local id = HttpService:GenerateGUID(false)
	invites[id] = { From = player, To = target, Station = entry.Station, Expires = os.clock() + GameConfig.InviteTimeout }
	inviteRemote:FireClient(target, {
		InviteId = id,
		FromName = player.DisplayName,
		FromUserId = player.UserId,
		Mode = entry.Station.Mode,
		Timeout = GameConfig.InviteTimeout,
	})
	notify(player, "Invite sent to " .. target.DisplayName, "Info")
end

function QueueService.RespondInvite(player: Player, inviteId: any, accept: any)
	if type(inviteId) ~= "string" or #inviteId > 64 then
		return
	end
	local inv = invites[inviteId]
	invites[inviteId] = nil
	if inv == nil or inv.To ~= player or os.clock() >= inv.Expires then
		notify(player, "That invite has expired.")
		return
	end
	local from = inv.From
	if accept ~= true then
		if from.Parent then
			notify(from, player.DisplayName .. " declined your invite.", "Info")
		end
		return
	end
	local entry = padOf[from]
	if entry == nil or entry.Station ~= inv.Station or inv.Station.State ~= "Waiting" then
		notify(player, "That battle is no longer available.")
		return
	end
	local opposite = if entry.Pad.Team == 1 then 2 else 1
	local pad = freePadFor(inv.Station, if inv.Station.Mode == "1v1" then opposite else nil)
	if pad == nil then
		notify(player, "That battle is already full.")
		return
	end
	QueueService.JoinPad(player, inv.Station, pad.Index)
end

-- Called by MatchService after a match closes.
function QueueService.ReleaseStation(station: Station, _match: any)
	for _, pad in station.Pads do
		local occupant = pad.Occupant
		if occupant then
			padOf[occupant] = nil
			if occupant.Parent then
				ArenaService.UnlockCharacter(occupant, ArenaService.ReleaseCFrame(station, pad.Index))
			end
		end
		pad.Occupant = nil
		destroyBot(pad)
	end
	station.State = "Idle"
	station.Match = nil
	ArenaService.SetIdleVisuals(station, true)
	refreshStation(station)
end

function QueueService.Init(registry: { [string]: any })
	tradingService = registry.TradingService
	stationRemote = Remotes.Event("StationState")
	notifyRemote = Remotes.Event("Notify")
	inviteRemote = Remotes.Event("InviteReceived")
end

function QueueService.Start()
	ArenaService.PadTriggered:Connect(function(player: Player, station: Station, padIndex: number)
		local entry = padOf[player]
		if entry and entry.Station == station and entry.Pad.Index == padIndex then
			return
		end
		QueueService.JoinPad(player, station, padIndex)
	end)

	Guard.OnEvent(Remotes.Event("QueueRequest"), 4, 6, function(player: Player, action: any, arg: any)
		if action == "Play" then
			local mode = if arg == "2v2" then "2v2" else "1v1"
			QueueService.QuickPlay(player, mode)
		elseif action == "Leave" then
			QueueService.Leave(player)
		elseif action == "Practice" then
			QueueService.Practice(player)
		end
	end)
	Guard.OnEvent(Remotes.Event("InviteRequest"), 1, 3, function(player: Player, targetUserId: any)
		QueueService.Invite(player, targetUserId)
	end)
	Guard.OnEvent(Remotes.Event("InviteResponse"), 3, 5, function(player: Player, inviteId: any, accept: any)
		QueueService.RespondInvite(player, inviteId, accept)
	end)

	DataService.Loaded:Connect(function(player: Player)
		for _, station in ArenaService.Stations do
			stationRemote:FireClient(player, stationPayload(station))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if padOf[player] and not MatchService.InMatch(player) then
			QueueService.Leave(player)
		end
		padOf[player] = nil
		for id, inv in invites do
			if inv.From == player or inv.To == player then
				invites[id] = nil
			end
		end
	end)
end

return QueueService
