--[[
	MatchService
	Owns running matches: arena slot allocation, player <-> match mapping, routing of in-match actions,
	and returning players to the lobby.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Match = require(script.Parent.Parent.Match.Match)

local MatchService = {}

local registry
local playerMatch: { [Player]: any } = {}
local slots: { [number]: any } = {}
local MAX_SLOTS = 40

local function allocateSlot(): number?
	for slot = 1, MAX_SLOTS do
		if not slots[slot] then
			return slot
		end
	end
	return nil
end

local function slotOrigin(slot: number): Vector3
	local cfg = GameConfig.Match
	return cfg.ArenaOrigin + Vector3.new((slot - 1) * cfg.ArenaSpacing, 0, 0)
end

function MatchService.isInMatch(player: Player): boolean
	return playerMatch[player] ~= nil
end

function MatchService.getMatch(player: Player)
	return playerMatch[player]
end

function MatchService.lobbySpawn(): CFrame
	local lobby = GameConfig.Lobby
	return CFrame.new(lobby.Origin + lobby.SpawnOffset)
end

function MatchService.returnToLobby(player: Player)
	local match = playerMatch[player]
	if match then
		match:removePlayer(player)
		playerMatch[player] = nil
		if match:isEmpty() then
			MatchService.cleanup(match)
		end
	end
	local character = player.Character
	if character then
		character:PivotTo(MatchService.lobbySpawn() + Vector3.new(math.random(-6, 6), 0, math.random(-4, 4)))
	end
	registry.NetService.remote("Match"):FireClient(player, "ReturnedToLobby", nil)
	registry.DataService.markDirty(player)
end

function MatchService.cleanup(match)
	if match.cleanedUp then
		return
	end
	match.cleanedUp = true
	for player in match.players do
		if playerMatch[player] == match then
			playerMatch[player] = nil
		end
	end
	match:destroy()
	if slots[match.slot] == match then
		slots[match.slot] = nil
	end
end

-- spec = { mode, worldId, act, modifier?, challengeId?, challengeReward?, players, hostUserId }
function MatchService.startMatch(spec)
	local slot = allocateSlot()
	if not slot then
		return false, "All arenas are busy. Try again in a moment!"
	end
	local players = {}
	for _, player in spec.players do
		if player.Parent and not playerMatch[player] and registry.DataService.get(player) then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return false, "Nobody to start with."
	end
	spec.players = players
	spec.id = HttpService:GenerateGUID(false)
	local match = Match.new(spec, slot, slotOrigin(slot), registry)
	slots[slot] = match
	for _, player in players do
		playerMatch[player] = match
	end
	match.onFinished = function()
		task.wait(GameConfig.Match.ResultReturnSeconds)
		for player in table.clone(match.players) do
			if playerMatch[player] == match then
				MatchService.returnToLobby(player)
			end
		end
		MatchService.cleanup(match)
	end
	local ok, err = pcall(match.begin, match)
	if not ok then
		warn("[MatchService] failed to begin match:", err)
		for _, player in players do
			MatchService.returnToLobby(player)
		end
		MatchService.cleanup(match)
		return false, "Couldn't start the match."
	end
	return true, match
end

function MatchService.onPlayerLeaving(player: Player)
	local match = playerMatch[player]
	if not match then
		return
	end
	match:removePlayer(player)
	playerMatch[player] = nil
	if match:isEmpty() then
		MatchService.cleanup(match)
	end
end

function MatchService.init(services)
	registry = services
end

function MatchService.start()
	local NetService = registry.NetService

	local function withMatch(fn)
		return function(player, payload)
			local match = playerMatch[player]
			if not match then
				return false, "You're not in a match."
			end
			return fn(match, player, payload)
		end
	end

	NetService.handle(
		"PlaceUnit",
		withMatch(function(match, player, payload)
			return match:placeUnit(player, payload.uid, payload.position, payload.rotation)
		end),
		{ rate = 8, burst = 10 }
	)
	NetService.handle(
		"UpgradeUnit",
		withMatch(function(match, player, payload)
			return match:upgradeUnit(player, payload.id)
		end),
		{ rate = 10, burst = 12 }
	)
	NetService.handle(
		"SellUnit",
		withMatch(function(match, player, payload)
			return match:sellUnit(player, payload.id)
		end),
		{ rate = 8 }
	)
	NetService.handle(
		"SetTargeting",
		withMatch(function(match, player, payload)
			return match:setTargeting(player, payload.id, payload.mode)
		end),
		{ rate = 8 }
	)
	NetService.handle(
		"VoteSkip",
		withMatch(function(match, player)
			return match:voteSkip(player)
		end),
		{ rate = 3 }
	)
	NetService.handle(
		"SetSpeed",
		withMatch(function(match, player, payload)
			return match:setSpeed(player, payload.speed)
		end),
		{ rate = 3 }
	)
	NetService.handle(
		"LeaveMatch",
		withMatch(function(_match, player)
			MatchService.returnToLobby(player)
			return true, nil
		end),
		{ rate = 1, burst = 2 }
	)

	-- Respawns during a match put you back in the arena.
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				local match = playerMatch[player]
				if match and match.spawnCFrame then
					character:PivotTo(match.spawnCFrame)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
end

return MatchService
