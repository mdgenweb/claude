--!strict
-- Session-locked DataStore profiles (ProfileService-style) with retries and a Studio mock.
--
-- Record layout in the DataStore: { Data = <profile>, Lock = { JobId, Time }?, Meta = 1 }
-- * Load claims the lock with UpdateAsync. A lock held by another live server is respected
--   until it is older than LOCK_TIMEOUT (crashed server), then it is stolen.
-- * Every save refreshes the lock and verifies we still own it; if another server took over,
--   the session is marked lost and the player is kicked to prevent duplication.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local LOCK_TIMEOUT = 150 -- seconds; autosave refreshes every 60
local LOAD_ATTEMPTS = 6
local RETRY_BASE = 1.5

type Record = { Data: any, Lock: { JobId: string, Time: number }?, Meta: number }

export type Session = {
	Key: string,
	Data: any,
	Lost: boolean,
	Released: boolean,
}

type Backend = {
	UpdateAsync: (self: Backend, key: string, transform: (any) -> any) -> any,
}

export type ProfileStore = typeof(setmetatable({} :: { _backend: Backend, _jobId: string, IsMock: boolean }, ProfileStore))

-- In-memory fallback used when Studio has no API access.
local MockBackend = {}
MockBackend.__index = MockBackend
function MockBackend.new()
	return setmetatable({ _store = {} :: { [string]: any } }, MockBackend)
end
function MockBackend:UpdateAsync(key: string, transform: (any) -> any): any
	local old = self._store[key]
	local copy = if old then HttpService:JSONDecode(HttpService:JSONEncode(old)) else nil
	local new = transform(copy)
	if new ~= nil then
		self._store[key] = HttpService:JSONDecode(HttpService:JSONEncode(new))
	end
	return new
end

local function jobId(): string
	if game.JobId ~= "" then
		return game.JobId
	end
	return "studio-" .. HttpService:GenerateGUID(false)
end

function ProfileStore.new(name: string): ProfileStore
	local backend: any = nil
	local isMock = false
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok and store then
		backend = store
		if RunService:IsStudio() then
			local probeOk = pcall(function()
				store:GetAsync("__probe")
			end)
			if not probeOk then
				backend = nil
			end
		end
	end
	if backend == nil then
		warn("[ProfileStore] DataStores unavailable (enable Studio API access to persist). Using in-memory mock.")
		backend = MockBackend.new()
		isMock = true
	end
	return setmetatable({ _backend = backend :: Backend, _jobId = jobId(), IsMock = isMock }, ProfileStore)
end

local function retry<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local lastErr: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(RETRY_BASE * 2 ^ (attempt - 1))
	end
	return false, tostring(lastErr)
end

-- Loads and locks a profile. Returns nil when the profile could not be claimed.
-- `isActive` lets the caller abort (e.g. the player left during loading).
function ProfileStore.Load(self: ProfileStore, key: string, isActive: () -> boolean): Session?
	for attempt = 1, LOAD_ATTEMPTS do
		if not isActive() then
			return nil
		end
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return self._backend:UpdateAsync(key, function(old: any)
				lockedElsewhere = false -- UpdateAsync may call the transform more than once
				local record: Record = if type(old) == "table" then old else { Data = nil, Lock = nil, Meta = 1 }
				local lock = record.Lock
				local now = os.time()
				if lock and lock.JobId ~= self._jobId and now - lock.Time < LOCK_TIMEOUT then
					lockedElsewhere = true
					return nil -- cancel write
				end
				record.Lock = { JobId = self._jobId, Time = now }
				record.Meta = 1
				return record
			end)
		end)
		if ok and result ~= nil and not lockedElsewhere then
			local record = result :: Record
			return { Key = key, Data = record.Data, Lost = false, Released = false }
		end
		if not ok then
			warn(string.format("[ProfileStore] load %s failed (attempt %d): %s", key, attempt, tostring(result)))
		end
		task.wait(if lockedElsewhere then 5 else RETRY_BASE * 2 ^ (attempt - 1))
	end
	return nil
end

-- Writes data and refreshes (or releases) the lock. Returns false if the session was lost.
function ProfileStore.Save(self: ProfileStore, session: Session, release: boolean): boolean
	if session.Released or session.Lost then
		return false
	end
	local lost = false
	local ok, err = retry(3, function()
		return self._backend:UpdateAsync(session.Key, function(old: any)
			lost = false
			local record: Record = if type(old) == "table" then old else { Data = nil, Lock = nil, Meta = 1 }
			local lock = record.Lock
			if lock and lock.JobId ~= self._jobId then
				lost = true
				return nil
			end
			record.Data = session.Data
			record.Lock = if release then nil else { JobId = self._jobId, Time = os.time() }
			record.Meta = 1
			return record
		end)
	end)
	if lost then
		session.Lost = true
		return false
	end
	if not ok then
		warn(string.format("[ProfileStore] save %s failed: %s", session.Key, tostring(err)))
		return false
	end
	if release then
		session.Released = true
	end
	return true
end

return ProfileStore
