--[[
	DataService
	Session-locked DataStore profiles (ProfileService-style, dependency free).

	* Load claims a lock { jobId, time } inside UpdateAsync. A lock held by another live server blocks the load
	  (retry, then kick) unless it's stale (crashed server), in which case it's taken over.
	* Autosave refreshes the lock; saves never overwrite a profile whose lock now belongs to another server.
	* Leaving / BindToClose saves and releases.
	* Without DataStore access (Studio "Enable Studio Access to API Services" off) profiles live in memory.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileChanged = Signal.new() -- (player)

local AUTOSAVE_INTERVAL = 60
local LOCK_STALE_SECONDS = 180
local LOAD_RETRIES = 5
local RETRY_DELAY = 4

local jobId = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))
local store: DataStore? = nil
local memoryMode = false
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local registry

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function migrate(data)
	data.schema = data.schema or 1
	-- Future: if data.schema < 2 then ... end
	TableUtil.reconcile(data, ProfileTemplate.new())
	data.schema = ProfileTemplate.SCHEMA
	return data
end

local function tryStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if not ok then
		warn("[DataService] DataStore unavailable, using in-memory profiles:", result)
		memoryMode = true
		return
	end
	store = result
	-- Probe once: in Studio without API access every call errors.
	local probeOk, probeErr = pcall(function()
		(result :: DataStore):GetAsync("__probe")
	end)
	if not probeOk then
		warn("[DataService] DataStore probe failed, using in-memory profiles:", probeErr)
		memoryMode = true
	end
end

local function loadFromStore(player: Player)
	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_RETRIES do
		local blockedBy = nil
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(old)
				-- The transform can run more than once; only the last run's verdict counts.
				blockedBy = nil
				local now = os.time()
				if old and old.lock and old.lock.jobId ~= jobId and now - (old.lock.time or 0) < LOCK_STALE_SECONDS then
					blockedBy = old.lock.jobId
					return nil -- abort write, keep their lock
				end
				local data = if old and old.data then old.data else ProfileTemplate.new()
				return { data = data, lock = { jobId = jobId, time = now } }
			end)
		end)
		if ok and result and not blockedBy then
			return migrate(result.data)
		end
		if not ok then
			warn(string.format("[DataService] load attempt %d for %s failed: %s", attempt, player.Name, tostring(result)))
		end
		if not player.Parent then
			return nil
		end
		task.wait(RETRY_DELAY)
	end
	return nil
end

local function writeToStore(player: Player, data, release: boolean): boolean
	local key = keyFor(player.UserId)
	local lostLock = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			if old and old.lock and old.lock.jobId ~= jobId then
				lostLock = true
				return nil
			end
			return {
				data = data,
				lock = if release then nil else { jobId = jobId, time = os.time() },
			}
		end)
	end)
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
		return false
	end
	if lostLock then
		warn("[DataService] lock for", player.Name, "was taken by another server; not overwriting")
		return false
	end
	return true
end

function DataService.isMemoryMode(): boolean
	return memoryMode
end

function DataService.get(player: Player)
	return profiles[player]
end

-- Yields until the profile is loaded (or the player leaves). Returns nil if unavailable.
function DataService.wait(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.markDirty(player: Player)
	if profiles[player] then
		DataService.ProfileChanged:Fire(player)
	end
end

function DataService.save(player: Player, release: boolean?): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	if memoryMode then
		return true
	end
	return writeToStore(player, data, release == true)
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true
	local data
	if memoryMode then
		data = migrate(ProfileTemplate.new())
	else
		data = loadFromStore(player)
	end
	loading[player] = nil
	if not player.Parent then
		-- Left while loading: release the lock we may have taken.
		if data and not memoryMode then
			writeToStore(player, data, true)
		end
		return
	end
	if not data then
		player:Kick("Your Elmore Defense data is open in another server. Please rejoin in a minute!")
		return
	end
	data.lastLogin = os.time()
	profiles[player] = data
	DataService.ProfileLoaded:Fire(player, data)
	DataService.markDirty(player)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		if registry and registry.MatchService then
			-- Let an active match settle rewards before the final save.
			pcall(registry.MatchService.onPlayerLeaving, player)
		end
		DataService.save(player, true)
		profiles[player] = nil
	end
end

function DataService.init(services)
	registry = services
	tryStore()
end

function DataService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and memoryMode then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
