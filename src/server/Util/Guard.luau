--!strict
-- Remote hardening: per-player token-bucket rate limits around every client->server endpoint.
-- Handlers still validate every argument (see Shared/Util/Validate) and check server state.
local Players = game:GetService("Players")

local Guard = {}

type Bucket = { tokens: number, updated: number, strikes: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

-- Returns true if the player may perform `key` now. `rate` = tokens per second, `burst` = bucket size.
function Guard.Allow(player: Player, key: string, rate: number, burst: number): boolean
	local perPlayer = buckets[player]
	if perPlayer == nil then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[key]
	if bucket == nil then
		bucket = { tokens = burst, updated = now, strikes = 0 }
		perPlayer[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updated) * rate)
	bucket.updated = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	bucket.strikes += 1
	if bucket.strikes % 50 == 0 then
		warn(string.format("[Guard] %s is spamming %s (%d rejected)", player.Name, key, bucket.strikes))
	end
	return false
end

-- Connects a RemoteEvent with rate limiting; handler errors are contained and logged.
function Guard.OnEvent(remote: RemoteEvent, rate: number, burst: number, handler: (Player, ...any) -> ...any)
	remote.OnServerEvent:Connect(function(player: Player, ...)
		if not Guard.Allow(player, remote.Name, rate, burst) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Guard] %s handler error for %s: %s", remote.Name, player.Name, tostring(err)))
		end
	end)
end

function Guard.OnUnreliable(remote: UnreliableRemoteEvent, rate: number, burst: number, handler: (Player, ...any) -> ...any)
	remote.OnServerEvent:Connect(function(player: Player, ...)
		if not Guard.Allow(player, remote.Name, rate, burst) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Guard] %s handler error for %s: %s", remote.Name, player.Name, tostring(err)))
		end
	end)
end

-- RemoteFunction with rate limiting; always returns a result table to the client.
function Guard.OnInvoke(remote: RemoteFunction, rate: number, burst: number, handler: (Player, ...any) -> { [string]: any })
	remote.OnServerInvoke = function(player: Player, ...)
		if not Guard.Allow(player, remote.Name, rate, burst) then
			return { ok = false, error = "Slow down!" }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Guard] %s handler error for %s: %s", remote.Name, player.Name, tostring(result)))
			return { ok = false, error = "Something went wrong. Try again." }
		end
		return result
	end
end

return Guard
