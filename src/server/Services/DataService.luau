--!nonstrict
-- Player persistence: session-locked DataStore profiles with autosave, retries, schema reconcile
-- and BindToClose flushing. Falls back to in-memory profiles when DataStores are unavailable
-- (e.g. Studio without "Enable Studio Access to API Services").

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Skins = require(Shared.Data.Skins)

local STORE_NAME = "FlaskFiasco_Profiles_v1"
local LOCK_TIMEOUT = 30 * 60
local AUTOSAVE_INTERVAL = 120
local MAX_RECEIPTS = 60

local DataService = {
	ProfileLoaded = Signal.new(),
	ProfileReleasing = Signal.new(),
	_profiles = {} :: { [Player]: any },
	_loading = {} :: { [Player]: boolean },
	_memoryOnly = false,
}

local store: DataStore? = nil

local function template()
	return {
		version = 1,
		coins = Config.Economy.StartingCoins,
		xp = 0,
		level = 1,
		ingredients = table.clone(Config.StartingIngredients),
		potions = {},
		brewCount = {},
		discovered = {},
		reactions = {},
		skins = { [Skins.DefaultId] = true },
		equippedSkin = Skins.DefaultId,
		maps = {},
		daily = { day = 0, list = {}, bonusClaimed = false },
		trials = {},
		streak = { day = 0, count = 0 },
		spins = 1,
		rack = { stock = 3, last = 0 },
		codes = {},
		settings = {
			sfx = 0.8,
			music = 0.5,
			quality = "high",
			privacy = "everyone",
			shake = 1,
			tutorial = 0,
		},
		stats = {
			brews = 0,
			damage = 0,
			golemsSpawned = 0,
			potionsUsed = 0,
			shatters = 0,
			kos = 0,
			playtime = 0,
			maxHeight = 0,
			reactions = 0,
			chaos = 0,
		},
		receipts = {},
		title = "",
		firstJoin = 0,
		lastJoin = 0,
	}
end

DataService.Template = template

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds any keys present in the template but missing in saved data (schema evolution).
local function reconcile(data, defaults)
	for key, value in defaults do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			-- Only recurse into "record" tables (with string keys), not id->value maps that start empty.
			reconcile(data[key], value)
		end
	end
	return data
end

local function migrate(data)
	data.version = data.version or 1
	-- Future migrations go here: if data.version < 2 then ... data.version = 2 end
	return data
end

local function profileKey(userId: number): string
	return "u_" .. tostring(userId)
end

local function getStore(): DataStore?
	if store or DataService._memoryOnly then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, using memory-only profiles:", result)
		DataService._memoryOnly = true
	end
	return store
end

-- Loads (and session-locks) a profile. Returns data or nil if the player left meanwhile.
local function loadProfile(player: Player)
	local ds = getStore()
	if not ds then
		return reconcile({}, template()), true
	end
	local key = profileKey(player.UserId)
	for attempt = 1, 6 do
		if not player.Parent then
			return nil, false
		end
		local lockedElsewhere = false
		local loaded = nil
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(record)
				record = record or {}
				local lock = record.lock
				local now = os.time()
				-- Respect a fresh lock owned by another server for the first few attempts,
				-- then steal it (the other server most likely crashed or is mid-save).
				if lock and lock.job ~= game.JobId and (now - (lock.time or 0)) < LOCK_TIMEOUT and attempt < 5 then
					lockedElsewhere = true
					return nil
				end
				record.lock = { job = game.JobId, time = now }
				loaded = record.data
				return record
			end)
		end)
		if ok and not lockedElsewhere then
			local data = loaded and migrate(loaded) or template()
			return reconcile(data, template()), false
		end
		if not ok then
			warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
			if tostring(err):find("StudioAccessToApisNotAllowed") or tostring(err):find("403") then
				DataService._memoryOnly = true
				store = nil
				return reconcile({}, template()), true
			end
		end
		task.wait(if lockedElsewhere then 3 else 1.5 * attempt)
	end
	warn("[DataService] giving up loading profile for", player.Name, "- using a temporary profile")
	return reconcile({}, template()), true
end

local function saveProfile(player: Player, data, release: boolean)
	local ds = getStore()
	if not ds or DataService._memoryOnly then
		return true
	end
	local key = profileKey(player.UserId)
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(record)
				record = record or {}
				local lock = record.lock
				if lock and lock.job ~= game.JobId and (os.time() - (lock.time or 0)) < LOCK_TIMEOUT then
					-- Another server stole the session; never overwrite its newer data.
					return nil
				end
				record.data = data
				record.lock = if release then nil else { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok then
			return true
		end
		warn(("[DataService] save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(attempt * 2)
	end
	return false
end

function DataService:Init(services)
	self.S = services
end

function DataService:Start()
	Net.event("Data")
	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, data in self._profiles do
				task.spawn(saveProfile, player, data, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and self._memoryOnly then
			return
		end
		local pending = 0
		for player, data in self._profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, data, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

-- Called by Main once every service has started, so no one misses ProfileLoaded (in Studio a
-- failed DataStore call can return instantly and fire the signal before others subscribe).
function DataService:BeginPlayers()
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._onPlayerAdded, self, player)
	end
end

function DataService:_onPlayerAdded(player: Player)
	if self._loading[player] or self._profiles[player] then
		return
	end
	self._loading[player] = true
	local data, temporary = loadProfile(player)
	self._loading[player] = nil
	if not data then
		return
	end
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		task.spawn(saveProfile, player, data, true)
		return
	end
	local now = os.time()
	if data.firstJoin == 0 then
		data.firstJoin = now
	end
	data.lastJoin = now
	data._temporary = temporary
	self._profiles[player] = data
	player:SetAttribute("DataLoaded", true)
	self.ProfileLoaded:Fire(player, data)
	self:SendSnapshot(player)
end

function DataService:_onPlayerRemoving(player: Player)
	local data = self._profiles[player]
	if not data then
		return
	end
	self.ProfileReleasing:Fire(player, data)
	self._profiles[player] = nil
	data._temporary = nil
	task.spawn(saveProfile, player, data, true)
end

function DataService:Get(player: Player)
	return self._profiles[player]
end

-- Yields until the profile exists (or the player leaves).
function DataService:WaitFor(player: Player, timeout: number?)
	local started = os.clock()
	while player.Parent and not self._profiles[player] do
		if timeout and os.clock() - started > timeout then
			return nil
		end
		task.wait(0.1)
	end
	return self._profiles[player]
end

local function publicView(data)
	local view = {}
	for key, value in data do
		if key ~= "receipts" and key:sub(1, 1) ~= "_" then
			view[key] = value
		end
	end
	return view
end

function DataService:SendSnapshot(player: Player)
	local data = self._profiles[player]
	if data then
		Net.event("Data"):FireClient(player, "init", publicView(data))
	end
end

-- Replicates the given top-level keys to the owning client.
function DataService:Replicate(player: Player, ...: string)
	local data = self._profiles[player]
	if not data then
		return
	end
	local patch = {}
	for _, key in { ... } do
		patch[key] = data[key]
	end
	Net.event("Data"):FireClient(player, "patch", patch)
end

-- Receipt idempotency helpers used by ShopService.ProcessReceipt.
function DataService:HasReceipt(player: Player, purchaseId: string): boolean
	local data = self._profiles[player]
	return data ~= nil and table.find(data.receipts, purchaseId) ~= nil
end

function DataService:AddReceipt(player: Player, purchaseId: string)
	local data = self._profiles[player]
	if not data then
		return
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
end

-- Forces a save now (used right after purchases so Robux rewards are never lost).
function DataService:SaveNow(player: Player): boolean
	local data = self._profiles[player]
	if not data then
		return false
	end
	return saveProfile(player, data, false)
end

return DataService
