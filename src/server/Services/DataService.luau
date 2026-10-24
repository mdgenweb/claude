-- Session-locked saves. One server owns a player's data at a time: loading writes a
-- lock (JobId + time), autosaves refresh it every minute, leaving releases it.
-- A live lock is never taken: the new server waits for the old one to release. Only a
-- lock that hasn't been refreshed for LOCK_EXPIRE (a crashed server) is taken over.
-- In Studio without API access the service falls back to in-memory data (with a warning).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = {}

local LOCK_EXPIRE = Config.AutosaveSeconds * 3 -- live servers refresh their lock every autosave
local LOAD_ATTEMPTS = 16 -- x 4 s: plenty of time for another server's release save
local MAX_RECEIPTS = 60

local TEMPLATE = {
	Version = 1, -- schema version, for future migrations
	Scrap = 0,
	Level = 0,
	Rebirths = 0,
	Gates = { Appliance = false, Crusher = false },
	CrusherDestroys = 0,
	Tool = "Hammer",
	ToolChosen = false,
	Finish = "Default",
	Finishes = { Default = true },
	BoostCharges = 0,
	BoostRemaining = 0,
	Workshop = { Stored = 0, Updated = 0 },
	Daily = { Day = 0, Progress = 0, Claimed = false },
	Stamps = 0,
	StarterGranted = false,
	Receipts = {},
	Stats = { Destroys = 0, ScrapEarned = 0, Upgrades = 0, PlaySeconds = 0 },
	Funnel = {},
}

type Profile = { Data: any, Saving: boolean, Dirty: boolean, Released: boolean }

local profiles: { [Player]: Profile } = {}
local releasing: { [number]: boolean } = {} -- userId -> release save in flight on this server
local store: DataStore? = nil
local useMemory = false

local function deepCopy(t)
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return out
end

-- Fill in fields added after a player's data was first saved.
local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function update(key: string, transform: (any) -> any, attempts: number): (boolean, any)
	if useMemory or not store then
		return true, nil
	end
	for attempt = 1, attempts do
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		warn(string.format("[DataService] UpdateAsync failed for %s (attempt %d): %s", key, attempt, tostring(result)))
		task.wait(math.min(2 ^ attempt, 10))
	end
	return false, nil
end

function DataService.init()
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(Config.DataStoreName)
		ds:GetAsync("__probe")
		return ds
	end)
	if ok then
		store = result
	else
		useMemory = true
		warn(
			"[DataService] DataStores unavailable (" .. tostring(result) .. "). Using in-memory data for this session."
		)
		if RunService:IsStudio() then
			warn("[DataService] Publish the place and enable 'Studio Access to API Services' to test saving.")
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in profiles do
				task.spawn(DataService.save, player, false)
			end
		end
	end)
end

function DataService.load(player: Player): any?
	local key = keyFor(player)
	local data = nil
	-- Rejoined this same server before the previous session finished saving: wait for it.
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		waited += task.wait(0.2)
	end
	if useMemory then
		data = reconcile({}, TEMPLATE)
	else
		for _ = 1, LOAD_ATTEMPTS do
			local locked = false
			local ok = update(key, function(record)
				record = record or {}
				local lock = record.Lock
				local fresh = lock and lock.JobId ~= game.JobId and (os.time() - (lock.Time or 0)) < LOCK_EXPIRE
				if fresh then
					locked = true
					return nil -- leave the record untouched and try again shortly
				end
				locked = false
				record.Data = reconcile(record.Data or {}, TEMPLATE)
				record.Lock = { JobId = game.JobId, Time = os.time() }
				data = record.Data
				return record
			end, 3)
			if not ok then
				break
			end
			if not locked then
				break
			end
			data = nil
			task.wait(4)
			if not player.Parent then
				return nil
			end
		end
	end
	if not data then
		return nil
	end
	if not player.Parent then
		-- They left while we were loading: release the lock we just took.
		update(key, function(record)
			if record and record.Lock and record.Lock.JobId == game.JobId then
				record.Lock = nil
				return record
			end
			return nil
		end, 2)
		return nil
	end
	if data.Workshop.Updated == 0 then
		data.Workshop.Updated = os.time()
	end
	profiles[player] = { Data = data, Saving = false, Dirty = false, Released = false }
	return data
end

function DataService.get(player: Player): any?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Saves the player's data. `release` drops the session lock (on leave / shutdown).
function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	if profile.Saving then
		-- Coalesce: wait for the in-flight save, then save again with the latest data.
		profile.Dirty = true
		while profile.Saving do
			task.wait(0.1)
		end
		if profile.Released then
			return false
		end
	end
	profile.Saving = true
	profile.Dirty = false
	if release then
		profile.Released = true
		releasing[player.UserId] = true
	end
	local stolen = false
	local ok = update(keyFor(player), function(record)
		record = record or {}
		if record.Lock and record.Lock.JobId ~= game.JobId then
			stolen = true
			return nil -- another server owns this session now; never overwrite it
		end
		record.Data = profile.Data
		record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
		return record
	end, if release then 5 else 3)
	profile.Saving = false
	if release then
		profiles[player] = nil
		releasing[player.UserId] = nil
	end
	if stolen then
		warn("[DataService] Session for " .. player.Name .. " was taken over by another server.")
		profiles[player] = nil
		if player.Parent then
			player:Kick("Your progress was opened on another server. Please rejoin.")
		end
		return false
	end
	return ok
end

function DataService.release(player: Player)
	DataService.save(player, true)
end

-- Receipt bookkeeping for developer products: each PurchaseId is granted once.
function DataService.hasReceipt(data, purchaseId: string): boolean
	return table.find(data.Receipts, purchaseId) ~= nil
end

function DataService.addReceipt(data, purchaseId: string)
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
end

function DataService.usingMemory(): boolean
	return useMemory
end

return DataService
