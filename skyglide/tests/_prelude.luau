-- Minimal Roblox API fakes shared by the specs (globals + fake services). Only what the server
-- services under test touch is implemented; anything else errors loudly.

-- deterministic Random
Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 12345) % 2147483647 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end

-- Vector3 (value type with arithmetic)
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return rawget(V3, k)
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)

Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return enumName .. "." .. item
			end,
		})
	end,
})

-- task: spawn runs until the first wait, which parks the coroutine forever (loops never spin).
task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end,
	defer = function(fn, ...)
		return task.spawn(fn, ...)
	end,
	delay = function(_, fn, ...)
		return nil
	end,
	wait = function()
		coroutine.yield()
	end,
}

-- Fake signal
FakeSignal = {}
FakeSignal.__index = FakeSignal
function FakeSignal.new()
	return setmetatable({ handlers = {} }, FakeSignal)
end
function FakeSignal:Connect(fn)
	table.insert(self.handlers, fn)
	return { Disconnect = function() end, Connected = true }
end
function FakeSignal:Fire(...)
	for _, fn in self.handlers do
		fn(...)
	end
end

-- Fake services ------------------------------------------------------------------------------
CLOCK = 1000
PLAYERS = {}
local playersNode = FAKE_GAME:GetService("Players")
rawset(playersNode, "PlayerAdded", FakeSignal.new())
rawset(playersNode, "PlayerRemoving", FakeSignal.new())
rawset(playersNode, "GetPlayers", function()
	return table.clone(PLAYERS)
end)
rawset(playersNode, "GetPlayerByUserId", function(_, id)
	for _, p in PLAYERS do
		if p.UserId == id then
			return p
		end
	end
	return nil
end)
local runService = FAKE_GAME:GetService("RunService")
rawset(runService, "Heartbeat", FakeSignal.new())
rawset(runService, "IsStudio", function()
	return true
end)
rawset(runService, "IsServer", function()
	return true
end)
local workspaceNode = FAKE_GAME:GetService("Workspace")
rawset(workspaceNode, "GetServerTimeNow", function()
	return CLOCK
end)
local market = FAKE_GAME:GetService("MarketplaceService")
PROMPTS = {}
rawset(market, "PromptProductPurchase", function(_, player, id)
	table.insert(PROMPTS, { player, "Product", id })
end)
rawset(market, "PromptGamePassPurchase", function(_, player, id)
	table.insert(PROMPTS, { player, "Pass", id })
end)
rawset(market, "PromptGamePassPurchaseFinished", FakeSignal.new())
rawset(market, "UserOwnsGamePassAsync", function()
	return false
end)
local dss = FAKE_GAME:GetService("DataStoreService")
rawset(dss, "GetDataStore", function()
	error("no DataStore access in tests")
end)

-- Fake player with a character standing somewhere.
function makePlayer(userId)
	local attrs = {}
	local humanoid = { Health = 100 }
	local character = {
		PrimaryPart = {},
		pivots = {},
	}
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then humanoid else nil
	end
	function character:FindFirstChild(name)
		return nil
	end
	function character:PivotTo(cf)
		table.insert(self.pivots, cf)
	end
	local player = {
		UserId = userId,
		Name = "Player" .. userId,
		DisplayName = "Player" .. userId,
		Parent = playersNode,
		Character = character,
		MembershipType = "MembershipType.None",
		Ping = 0.05,
		Kicked = nil,
		CharacterAdded = FakeSignal.new(),
	}
	function player:GetNetworkPing()
		return self.Ping
	end
	function player:SetAttribute(k, v)
		attrs[k] = v
	end
	function player:GetAttribute(k)
		return attrs[k]
	end
	function player:IsFriendsWithAsync()
		return false
	end
	function player:Kick(msg)
		self.Kicked = msg
	end
	table.insert(PLAYERS, player)
	return player
end

-- Stub DataService over plain profiles (Schema defaults) -------------------------------------
function makeDataStub()
	local Schema = MODULE("ServerScriptService/Server/Data/Schema")
	local profiles = {}
	local stub = {
		Loaded = FakeSignal.new(),
		Changed = FakeSignal.new(),
		Releasing = FakeSignal.new(),
		profiles = profiles,
		saves = 0,
	}
	function stub.Get(player)
		return profiles[player]
	end
	function stub.WaitFor(player)
		return profiles[player]
	end
	function stub.Update(player, fn)
		local p = profiles[player]
		if not p then
			return nil
		end
		return fn(p)
	end
	function stub.MarkChanged() end
	function stub.MarkDirty() end
	function stub.SyncNow() end
	function stub.AddDecorator() end
	function stub.SaveNow()
		stub.saves += 1
		return true
	end
	function stub.IsMock()
		return true
	end
	function stub.Load(player)
		profiles[player] = Schema.Default()
		return profiles[player]
	end
	return stub
end

-- Stub Remotes: records server->client fires, exposes client->server handlers.
function makeRemotesStub()
	local fired = {}
	local function remote(name)
		return {
			Name = name,
			FireClient = function(_, player, payload)
				table.insert(fired, { Name = name, Player = player, Payload = payload })
			end,
			FireAllClients = function(_, payload)
				table.insert(fired, { Name = name, All = true, Payload = payload })
			end,
		}
	end
	local cache = {}
	local function get(name)
		cache[name] = cache[name] or remote(name)
		return cache[name]
	end
	return {
		fired = fired,
		Event = get,
		Function = get,
		Unreliable = get,
		Init = function() end,
		Last = function(name, player)
			for i = #fired, 1, -1 do
				local f = fired[i]
				if f.Name == name and (player == nil or f.Player == player or f.All) then
					return f.Payload
				end
			end
			return nil
		end,
		Count = function(name)
			local n = 0
			for _, f in fired do
				if f.Name == name then
					n += 1
				end
			end
			return n
		end,
	}
end

-- Stub Guard: handlers are callable directly as HANDLERS[remoteName](player, ...)
HANDLERS = {}
GuardStub = {
	OnEvent = function(remote, _, _, handler)
		HANDLERS[remote.Name] = handler
	end,
	OnInvoke = function(remote, _, _, handler)
		HANDLERS[remote.Name] = handler
	end,
	OnUnreliable = function(remote, _, _, handler)
		HANDLERS[remote.Name] = handler
	end,
	Allow = function()
		return true
	end,
}
