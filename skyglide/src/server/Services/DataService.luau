--!strict
-- Owns every player's profile: load (session locked), sanitise, mutate, replicate, autosave,
-- release on leave and on shutdown. Other services never touch DataStores directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local Server = script.Parent.Parent
local ProfileStore = require(Server.Data.ProfileStore)
local Schema = require(Server.Data.Schema)

export type Profile = Schema.Profile

local DataService = {}

DataService.Loaded = Signal.new() -- (player, profile)
DataService.Changed = Signal.new() -- (player, profile)
DataService.Releasing = Signal.new() -- (player, profile) fired before the final save

local STORE_NAME = "SkyGlide_PlayerData_v1"
local AUTOSAVE_SECONDS = 60

local store: ProfileStore.ProfileStore
local sessions: { [Player]: ProfileStore.Session } = {}
local dirtySync: { [Player]: boolean } = {}
local loadWaiters: { [Player]: { thread } } = {}
local loading: { [Player]: boolean } = {}

local playerDataRemote: RemoteEvent
local decorators: { (Player, { [string]: any }) -> () } = {}

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function DataService.Get(player: Player): Profile?
	local session = sessions[player]
	if session == nil or session.Lost or session.Released then
		return nil
	end
	return session.Data :: Profile
end

-- Yields until the profile is loaded (or the player leaves / timeout).
function DataService.WaitFor(player: Player, timeout: number?): Profile?
	local existing = DataService.Get(player)
	if existing then
		return existing
	end
	local thread = coroutine.running()
	local waiters = loadWaiters[player] or {}
	loadWaiters[player] = waiters
	table.insert(waiters, thread)
	task.delay(timeout or 30, function()
		local i = table.find(waiters, thread)
		if i then
			table.remove(waiters, i)
			task.spawn(thread)
		end
	end)
	coroutine.yield()
	return DataService.Get(player)
end

-- The only way to mutate a profile. `mutator` runs synchronously and must not yield.
-- Returns whatever the mutator returns (nil if the profile is not loaded).
function DataService.Update<T>(player: Player, mutator: (Profile) -> T): T?
	local profile = DataService.Get(player)
	if profile == nil then
		return nil
	end
	local result = mutator(profile)
	DataService.MarkChanged(player)
	return result
end

function DataService.MarkChanged(player: Player)
	dirtySync[player] = true
	local profile = DataService.Get(player)
	if profile then
		DataService.Changed:Fire(player, profile)
	end
end

-- Other services add derived, read-only fields (multipliers, pass ownership...) to the view.
function DataService.AddDecorator(fn: (Player, { [string]: any }) -> ())
	table.insert(decorators, fn)
end

function DataService.SyncNow(player: Player)
	local profile = DataService.Get(player)
	if profile and player.Parent then
		dirtySync[player] = nil
		local view = Schema.PublicView(profile)
		for _, fn in decorators do
			local ok, err = pcall(function()
				fn(player, view)
			end)
			if not ok then
				warn("[DataService] decorator failed: " .. tostring(err))
			end
		end
		playerDataRemote:FireClient(player, view)
	end
end

-- Marks the client view stale without firing Changed (used for derived values like timers).
function DataService.MarkDirty(player: Player)
	dirtySync[player] = true
end

-- Forces an immediate save (used after purchases and trades).
function DataService.SaveNow(player: Player): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	local ok = store:Save(session, false)
	if session.Lost then
		player:Kick("Your data was opened in another server. Please rejoin.")
	end
	return ok
end

function DataService.IsMock(): boolean
	return store.IsMock
end

local function onPlayerAdded(player: Player)
	if loading[player] or sessions[player] then
		return
	end
	loading[player] = true
	local session = store:Load(keyFor(player), function()
		return player.Parent == Players
	end)
	loading[player] = nil
	if player.Parent ~= Players then
		if session then
			store:Save(session, true)
		end
		return
	end
	if session == nil then
		player:Kick("Could not load your data. Please rejoin in a moment.")
		return
	end
	session.Data = Schema.Sanitize(session.Data)
	sessions[player] = session

	local waiters = loadWaiters[player]
	loadWaiters[player] = nil
	if waiters then
		for _, thread in waiters do
			task.spawn(thread)
		end
	end

	DataService.Loaded:Fire(player, session.Data)
	DataService.SyncNow(player)
end

local function release(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	DataService.Releasing:Fire(player, session.Data)
	sessions[player] = nil
	dirtySync[player] = nil
	store:Save(session, true)
end

function DataService.Init()
	store = ProfileStore.new(STORE_NAME)
	playerDataRemote = Remotes.Event("PlayerData")
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- deferred so every other service's Start() has connected to Loaded first
	task.defer(function()
		for _, player in Players:GetPlayers() do
			task.spawn(onPlayerAdded, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- let other services finish their PlayerRemoving work (flights in progress) first
		task.defer(release, player)
	end)

	-- batched client sync (at most ~6/s per player)
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player in dirtySync do
				DataService.SyncNow(player)
			end
		end
	end)

	-- autosave
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, session in sessions do
				task.spawn(function()
					store:Save(session, false)
					if session.Lost and player.Parent then
						player:Kick("Your data was opened in another server. Please rejoin.")
					end
				end)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 5 else 25)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
