--[[
	NetService
	Creates remotes, routes client requests to handlers, rate-limits, and pushes profile views.

	Handlers:  NetService.handle("Summon", function(player, payload, profile) return true, data end, { rate = 4 })
	Clients:   Request:InvokeServer("Summon", { bannerId = "Standard", count = 10 }) -> { ok = true, data = ... }
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local NetService = {}

local registry
local handlers: { [string]: { fn: any, rate: number, burst: number, requireProfile: boolean } } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}
local dirty: { [Player]: boolean } = {}
local lastPush: { [Player]: number } = {}
local viewDecorators = {}

local PUSH_INTERVAL = 0.2
local DEFAULT_RATE = 6
local HIDDEN_PROFILE_KEYS = { receipts = true, codes = true }

local remotes = {}

function NetService.remote(name: string)
	return remotes[name]
end

function NetService.handle(action: string, fn, options: { rate: number?, burst: number?, requireProfile: boolean? }?)
	assert(not handlers[action], "duplicate handler " .. action)
	local rate = options and options.rate or DEFAULT_RATE
	handlers[action] = {
		fn = fn,
		rate = rate,
		burst = options and options.burst or math.max(rate * 2, 4),
		requireProfile = not (options and options.requireProfile == false),
	}
end

local function allow(player: Player, action: string, rate: number, burst: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[action]
	local now = os.clock()
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[action] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function onInvoke(player: Player, action: any, payload: any)
	if type(action) ~= "string" then
		return { ok = false, err = "Bad request" }
	end
	local handler = handlers[action]
	if not handler then
		return { ok = false, err = "Unknown action" }
	end
	if payload ~= nil and type(payload) ~= "table" then
		return { ok = false, err = "Bad payload" }
	end
	if not allow(player, action, handler.rate, handler.burst) then
		return { ok = false, err = "Slow down!" }
	end
	local profile = registry.DataService.get(player)
	if handler.requireProfile and not profile then
		return { ok = false, err = "Still loading your data..." }
	end
	local ok, success, result = pcall(handler.fn, player, payload or {}, profile)
	if not ok then
		warn(string.format("[NetService] %s handler error for %s: %s", action, player.Name, tostring(success)))
		return { ok = false, err = "Something went wrong. Try again!" }
	end
	if success then
		if profile then
			registry.DataService.markDirty(player)
		end
		return { ok = true, data = result }
	end
	return { ok = false, err = result or "Can't do that right now." }
end

-- Other services add derived, non-saved info to the profile view (e.g. owned passes).
function NetService.addViewDecorator(fn: (Player, any, any) -> ())
	table.insert(viewDecorators, fn)
end

local function buildView(player: Player, profile)
	local view = {}
	for key, value in profile do
		if not HIDDEN_PROFILE_KEYS[key] then
			view[key] = value
		end
	end
	view.codesRedeemed = 0
	for _ in profile.codes do
		view.codesRedeemed += 1
	end
	for _, decorate in viewDecorators do
		local ok, err = pcall(decorate, player, profile, view)
		if not ok then
			warn("[NetService] view decorator failed:", err)
		end
	end
	return view
end

local function pushNow(player: Player)
	local profile = registry.DataService.get(player)
	if not profile then
		return
	end
	lastPush[player] = os.clock()
	dirty[player] = nil
	remotes.Profile:FireClient(player, buildView(player, profile))
end

function NetService.pushProfile(player: Player)
	dirty[player] = true
end

function NetService.notify(player: Player, text: string, kind: string?, extra: { [string]: any }?)
	local payload = { text = text, kind = kind or "info" }
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	remotes.Notify:FireClient(player, payload)
end

function NetService.notifyAll(text: string, kind: string?)
	remotes.Notify:FireAllClients({ text = text, kind = kind or "info" })
end

function NetService.init(services)
	registry = services
	local folder = Net.setupServer()
	for name in Net.Definitions do
		remotes[name] = folder:WaitForChild(name)
	end
	remotes.Request.OnServerInvoke = onInvoke
end

function NetService.start()
	registry.DataService.ProfileChanged:Connect(function(player)
		dirty[player] = true
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player in dirty do
			if now - (lastPush[player] or 0) >= PUSH_INTERVAL then
				pushNow(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		dirty[player] = nil
		lastPush[player] = nil
	end)

	-- Lightweight request the client uses at boot.
	NetService.handle("Hello", function(player)
		local profile = registry.DataService.wait(player, 30)
		if not profile then
			return false, "Profile not available"
		end
		pushNow(player)
		return true, { serverTime = os.time(), memoryMode = registry.DataService.isMemoryMode() }
	end, { rate = 1, burst = 3, requireProfile = false })
end

return NetService
