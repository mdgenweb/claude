--[[
	LobbyService
	Party rooms (up to 4 players). A room picks mode + stage, counts down, and hands off to MatchService.
	Room list is broadcast to everyone in the lobby so friends can join from the Play menu.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Worlds = require(Shared.Config.Worlds)
local Rotation = require(Shared.Logic.Rotation)
local Progress = require(Shared.Logic.Progress)

local LobbyService = {}

local registry
local rooms: { [string]: any } = {}
local playerRoom: { [Player]: any } = {}
local MODES = { Story = true, Infinite = true, Challenge = true }

local function summary(room)
	local names = {}
	for _, player in room.players do
		table.insert(names, player.DisplayName)
	end
	return {
		id = room.id,
		hostUserId = room.hostUserId,
		hostName = room.hostName,
		mode = room.mode,
		worldId = room.worldId,
		act = room.act,
		modifier = room.modifier,
		players = names,
		userIds = (function()
			local ids = {}
			for _, player in room.players do
				table.insert(ids, player.UserId)
			end
			return ids
		end)(),
		max = GameConfig.Match.MaxPlayers,
		startsAt = room.startsAt,
		solo = room.solo,
	}
end

local function broadcast()
	local list = {}
	for _, room in rooms do
		if not room.solo then
			table.insert(list, summary(room))
		end
	end
	table.sort(list, function(a, b)
		return a.startsAt < b.startsAt
	end)
	local remote = registry.NetService.remote("Lobby")
	remote:FireAllClients("Rooms", list)
	for _, room in rooms do
		for _, player in room.players do
			remote:FireClient(player, "MyRoom", summary(room))
		end
	end
end

local function removeFromRoom(player: Player)
	local room = playerRoom[player]
	if not room then
		return
	end
	playerRoom[player] = nil
	local index = table.find(room.players, player)
	if index then
		table.remove(room.players, index)
	end
	registry.NetService.remote("Lobby"):FireClient(player, "MyRoom", nil)
	if #room.players == 0 then
		rooms[room.id] = nil
	elseif room.hostUserId == player.UserId then
		room.hostUserId = room.players[1].UserId
		room.hostName = room.players[1].DisplayName
	end
	broadcast()
end

local function hasTeam(profile): boolean
	return #profile.team > 0
end

local function startRoom(room)
	if not rooms[room.id] then
		return
	end
	rooms[room.id] = nil
	for _, player in room.players do
		playerRoom[player] = nil
		registry.NetService.remote("Lobby"):FireClient(player, "MyRoom", nil)
	end
	local ok, err = registry.MatchService.startMatch({
		mode = room.mode,
		worldId = room.worldId,
		act = room.act,
		modifier = room.modifier,
		challengeId = room.challengeId,
		challengeReward = room.challengeReward,
		players = room.players,
		hostUserId = room.hostUserId,
	})
	if not ok then
		for _, player in room.players do
			registry.NetService.notify(player, err or "Couldn't start the match.", "error")
		end
	end
	broadcast()
end

local function createRoom(player: Player, payload, profile)
	if registry.MatchService.isInMatch(player) then
		return false, "You're already in a match."
	end
	if not hasTeam(profile) then
		return false, "Equip at least one unit first!"
	end
	local mode = payload.mode
	if not MODES[mode] then
		return false, "Pick a mode."
	end
	local worldId, act, modifier, challengeId, challengeReward
	if mode == "Challenge" then
		local slotIndex = tonumber(payload.slot)
		local challenges = Rotation.challenges(os.time())
		local challenge = slotIndex and challenges[math.floor(slotIndex)]
		if not challenge then
			return false, "That challenge isn't available."
		end
		worldId, act, modifier = challenge.worldId, challenge.act, challenge.modifier
		challengeId, challengeReward = challenge.id, challenge.reward
		if not Progress.worldUnlocked(profile, worldId) then
			return false, "Unlock " .. Worlds.get(worldId).name .. " first!"
		end
	else
		worldId = payload.worldId
		act = math.floor(tonumber(payload.act) or 1)
		if not Worlds.get(worldId) then
			return false, "Unknown world."
		end
		if mode == "Story" then
			if act < 1 or act > Worlds.ACTS or not Progress.actUnlocked(profile, worldId, act) then
				return false, "Clear the previous act first!"
			end
		else
			act = 3
			if not Progress.worldUnlocked(profile, worldId) then
				return false, "Unlock this world first!"
			end
		end
	end
	removeFromRoom(player)
	local solo = payload.solo == true
	local room = {
		id = HttpService:GenerateGUID(false),
		hostUserId = player.UserId,
		hostName = player.DisplayName,
		mode = mode,
		worldId = worldId,
		act = act,
		modifier = modifier,
		challengeId = challengeId,
		challengeReward = challengeReward,
		players = { player },
		startsAt = os.time() + (if solo then 0 else GameConfig.Match.PartyCountdown),
		solo = solo,
	}
	rooms[room.id] = room
	playerRoom[player] = room
	if solo then
		startRoom(room)
	else
		broadcast()
	end
	return true, summary(room)
end

function LobbyService.init(services)
	registry = services
end

function LobbyService.start()
	local NetService = registry.NetService

	NetService.handle("CreateRoom", createRoom, { rate = 1, burst = 3 })

	NetService.handle("JoinRoom", function(player, payload, profile)
		local room = rooms[payload.roomId]
		if not room then
			return false, "That party is gone."
		end
		if registry.MatchService.isInMatch(player) then
			return false, "You're already in a match."
		end
		if #room.players >= GameConfig.Match.MaxPlayers then
			return false, "That party is full."
		end
		if not hasTeam(profile) then
			return false, "Equip at least one unit first!"
		end
		if playerRoom[player] == room then
			return true, summary(room)
		end
		removeFromRoom(player)
		table.insert(room.players, player)
		playerRoom[player] = room
		broadcast()
		return true, summary(room)
	end, { rate = 2 })

	NetService.handle("LeaveRoom", function(player)
		removeFromRoom(player)
		return true, nil
	end, { rate = 2 })

	NetService.handle("StartRoom", function(player)
		local room = playerRoom[player]
		if not room then
			return false, "You're not in a party."
		end
		if room.hostUserId ~= player.UserId then
			return false, "Only the host can start."
		end
		startRoom(room)
		return true, nil
	end, { rate = 1, burst = 2 })

	NetService.handle("GetRooms", function()
		local list = {}
		for _, room in rooms do
			if not room.solo then
				table.insert(list, summary(room))
			end
		end
		return true, list
	end, { rate = 2, requireProfile = false })

	Players.PlayerRemoving:Connect(removeFromRoom)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.time()
			for _, room in rooms do
				if now >= room.startsAt then
					task.spawn(startRoom, room)
				end
			end
		end
	end)
end

return LobbyService
