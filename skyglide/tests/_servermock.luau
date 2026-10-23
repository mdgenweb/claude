-- Server-side Roblox API mock + client/server loopback, layered on _rbxmock.luau and
-- _clientmock.luau. It lets one spec boot the REAL server (Main.server.luau) and the REAL client
-- (Main.client.luau) in the same VM:
--   * remotes deliver after a one-way LATENCY, and every argument is checked against Roblox's
--     network rules (no functions, mixed or sparse tables, NaN, metatables);
--   * DataStores are in-memory, enforce Roblox's storable-value rules and can inject failures;
--   * the clock is virtual: os.clock / os.time follow CLOCK (TIME_OFFSET jumps whole days);
--   * MarketplaceService records prompts; COMPLETE_PURCHASE delivers a receipt like Roblox does;
--   * JOIN / LEAVE add and remove extra (headless) players, SHUTDOWN runs BindToClose.
-- Warnings from any module and errors in any handler are collected (SERVER_WARNINGS,
-- CLIENT_ERRORS, NET_ERRORS) so a spec can fail on them.

-- Virtual time -------------------------------------------------------------------------------------
local realOs = os
REAL_CLOCK = realOs.clock -- wall-clock timer for performance measurements
TIME_OFFSET = 0
local EPOCH = 1760000000
os = setmetatable({
	clock = function()
		return CLOCK
	end,
	time = function(t)
		if t ~= nil then
			return realOs.time(t)
		end
		return EPOCH + math.floor(CLOCK) + TIME_OFFSET
	end,
}, { __index = realOs })

-- Warnings ----------------------------------------------------------------------------------------
SERVER_WARNINGS = {}
function WARN_HOOK(path, ...)
	local parts = {}
	for _, v in { ... } do
		table.insert(parts, tostring(v))
	end
	table.insert(SERVER_WARNINGS, path .. ": " .. table.concat(parts, " "))
end

-- Helpers -----------------------------------------------------------------------------------------
local ROOT = rawget(FAKE_GAME:GetService("ReplicatedStorage"), "Parent")
local function service(name)
	local existing = rawget(ROOT, "_children")[name]
	if existing and typeof(existing) == "Instance" then
		return existing
	end
	local s = Instance.new("Folder")
	s.Name = name
	rawget(ROOT, "_children")[name] = s
	return s
end

local function deepcopy(v)
	if type(v) ~= "table" or getmetatable(v) ~= nil then
		return v
	end
	local out = {}
	for k, x in v do
		out[deepcopy(k)] = deepcopy(x)
	end
	return out
end

-- Roblox DataStore value rules (JSON-like): nil/boolean/finite number/string, arrays 1..n and
-- string-keyed dictionaries only, no metatables, no Instances or other userdata.
local function storable(v, path)
	local t = type(v)
	if t == "nil" or t == "boolean" or t == "string" then
		return
	end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("DataStore: cannot store NaN/inf at " .. path, 0)
		end
		return
	end
	if t ~= "table" or getmetatable(v) ~= nil then
		error("DataStore: cannot store " .. typeof(v) .. " at " .. path, 0)
	end
	local n, count, strings, numbers = #v, 0, false, false
	for k, x in v do
		count += 1
		if type(k) == "string" then
			strings = true
		elseif type(k) == "number" then
			numbers = true
		else
			error("DataStore: key of type " .. type(k) .. " at " .. path, 0)
		end
		storable(x, path .. "." .. tostring(k))
	end
	if strings and numbers then
		error("DataStore: mixed table at " .. path, 0)
	end
	if numbers and count ~= n then
		error("DataStore: sparse array at " .. path, 0)
	end
end

local function approxSize(v)
	local t = type(v)
	if t == "string" then
		return #v + 2
	elseif t == "number" then
		return 12
	elseif t == "boolean" then
		return 5
	elseif t == "table" then
		local s = 2
		for k, x in v do
			s += approxSize(k) + approxSize(x) + 2
		end
		return s
	end
	return 4
end

-- DataStoreService -----------------------------------------------------------------------------------
DATASTORES = {} -- name -> { [key] = value }
ORDERED = {} -- name -> { [key] = integer }
DATASTORE_FAIL = 0 -- the next N requests throw (like a 5xx / throttle)
DATASTORE_CALLS = 0
local function request(key)
	DATASTORE_CALLS += 1
	if DATASTORE_FAIL > 0 then
		DATASTORE_FAIL -= 1
		error("DataStore request failed (mock 503)", 0)
	end
	if type(key) ~= "string" or #key == 0 or #key > 50 then
		error("DataStore: bad key " .. tostring(key), 0)
	end
end
local function checkValue(key, value)
	storable(value, key)
	if approxSize(value) > 4000000 then
		error("DataStore: value for " .. key .. " exceeds 4 MB", 0)
	end
end

local dss = service("DataStoreService")
dss.GetDataStore = function(_, name)
	local data = DATASTORES[name] or {}
	DATASTORES[name] = data
	local store = {}
	function store:GetAsync(key)
		request(key)
		return deepcopy(data[key])
	end
	function store:SetAsync(key, value)
		request(key)
		checkValue(key, value)
		data[key] = deepcopy(value)
	end
	function store:UpdateAsync(key, transform)
		request(key)
		local new = transform(deepcopy(data[key]))
		if new == nil then
			return nil -- write cancelled
		end
		checkValue(key, new)
		data[key] = deepcopy(new)
		return deepcopy(new)
	end
	function store:IncrementAsync(key, delta)
		request(key)
		data[key] = (data[key] or 0) + (delta or 1)
		return data[key]
	end
	function store:RemoveAsync(key)
		request(key)
		local old = data[key]
		data[key] = nil
		return old
	end
	return store
end
dss.GetOrderedDataStore = function(_, name)
	local data = ORDERED[name] or {}
	ORDERED[name] = data
	local store = {}
	function store:SetAsync(key, value)
		request(key)
		if type(value) ~= "number" or value ~= math.floor(value) then
			error("OrderedDataStore: value must be an integer, got " .. tostring(value), 0)
		end
		if math.abs(value) >= 2 ^ 63 then
			error("OrderedDataStore: value out of range", 0)
		end
		data[key] = value
	end
	function store:GetSortedAsync(ascending, pageSize)
		request("sorted")
		local rows = {}
		for k, v in data do
			table.insert(rows, { key = k, value = v })
		end
		table.sort(rows, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		while #rows > (pageSize or 50) do
			table.remove(rows)
		end
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return rows
			end,
			AdvanceToNextPageAsync = function() end,
		}
	end
	return store
end

-- Other server services ------------------------------------------------------------------------------
local guid = 0
local http = service("HttpService")
http.GenerateGUID = function(_, wrap)
	guid += 1
	local s = string.format("0000%04x-mock-guid-%08d", guid, guid)
	return if wrap == false then s else "{" .. s .. "}"
end
http.JSONEncode = function(_, v)
	storable(v, "JSONEncode")
	return { __json = deepcopy(v) }
end
http.JSONDecode = function(_, s)
	return deepcopy(s.__json)
end

local physics = service("PhysicsService")
COLLISION_GROUPS = {}
physics.RegisterCollisionGroup = function(_, name)
	COLLISION_GROUPS[name] = true
end
physics.CollisionGroupSetCollidable = function() end

local stats = service("Stats")
stats.GetTotalMemoryUsageMb = function()
	return 512
end
stats.HeartbeatTimeMs = 16.7

-- MarketplaceService: prompts are recorded; COMPLETE_PURCHASE plays Roblox's part
local market = service("MarketplaceService")
PROMPTS = {}
OWNED_PASSES = {} -- [userId] = { [passId] = true }
market.PromptGamePassPurchaseFinished = NEW_SIGNAL("PromptGamePassPurchaseFinished")
market.PromptProductPurchaseFinished = NEW_SIGNAL("PromptProductPurchaseFinished")
market.PromptProductPurchase = function(_, player, id)
	table.insert(PROMPTS, { Player = player, Kind = "Product", Id = id })
end
market.PromptGamePassPurchase = function(_, player, id)
	table.insert(PROMPTS, { Player = player, Kind = "Pass", Id = id })
end
market.UserOwnsGamePassAsync = function(_, userId, passId)
	local owned = OWNED_PASSES[userId]
	return owned ~= nil and owned[passId] == true
end
local purchaseCounter = 0
-- Completes a recorded prompt. Products: calls ProcessReceipt with a fresh (or given) purchase id
-- and returns the decision. Passes: marks the pass owned and fires PromptGamePassPurchaseFinished.
function COMPLETE_PURCHASE(prompt, purchaseId)
	if prompt.Kind == "Pass" then
		OWNED_PASSES[prompt.Player.UserId] = OWNED_PASSES[prompt.Player.UserId] or {}
		OWNED_PASSES[prompt.Player.UserId][prompt.Id] = true
		market.PromptGamePassPurchaseFinished:Fire(prompt.Player, prompt.Id, true)
		return true
	end
	purchaseCounter += 1
	local receipt = {
		PlayerId = prompt.Player.UserId,
		ProductId = prompt.Id,
		PurchaseId = purchaseId or ("purchase-" .. purchaseCounter),
		CurrencySpent = 99,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = 0,
	}
	local handler = market.ProcessReceipt
	assert(type(handler) == "function", "ProcessReceipt is not set")
	local decision
	local co = coroutine.create(function()
		decision = handler(receipt)
	end)
	local ok, err = coroutine.resume(co)
	assert(ok, err)
	for _ = 1, 600 do
		if decision ~= nil then
			break
		end
		STEP(0.1)
	end
	return decision, receipt.PurchaseId
end

-- game members ------------------------------------------------------------------------------------
CLOSE_HANDLERS = {}
GAME_MEMBERS = {
	JobId = "",
	PlaceId = 0,
	BindToClose = function(_, fn)
		table.insert(CLOSE_HANDLERS, fn)
	end,
}
-- Runs every BindToClose handler like a server shutdown and steps time until they return.
function SHUTDOWN(maxSeconds)
	local pending = 0
	for _, fn in CLOSE_HANDLERS do
		pending += 1
		task.spawn(function()
			fn()
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < (maxSeconds or 30) do
		STEP(0.1)
		waited += 0.1
	end
	return pending == 0, waited
end

-- Players (server side) ---------------------------------------------------------------------------------
local Players = FAKE_GAME:GetService("Players")
local Workspace = FAKE_GAME:GetService("Workspace")
FRIENDS = {} -- ["a:b"] = true
KICKED = {}

local function serverPlayerMethods(player)
	player.Kick = function(self, message)
		table.insert(KICKED, { Player = self, Message = message })
	end
	player.IsFriendsWithAsync = function(self, otherId)
		return FRIENDS[self.UserId .. ":" .. otherId] == true or FRIENDS[otherId .. ":" .. self.UserId] == true
	end
	player.IsInGroupAsync = function()
		return false
	end
end
serverPlayerMethods(LOCAL_PLAYER)
LOCAL_PLAYER.GetNetworkPing = function()
	return LATENCY * 2
end

function MAKE_CHARACTER(name)
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Parent = character
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.Parent = character
	for _, limb in { "RightHand", "RightUpperArm", "UpperTorso", "Head" } do
		local p = Instance.new("Part")
		p.Name = limb
		p.Size = Vector3.new(1, 1, 1)
		p.Parent = character
	end
	character.Parent = Workspace
	return character
end

-- A headless extra player (no client): joins the server, can send intents with AS().
function JOIN(userId, name)
	local player = Instance.new("Player")
	player.Name = name or ("Player" .. userId)
	player.DisplayName = name or ("Player" .. userId)
	player.UserId = userId
	player.MembershipType = Enum.MembershipType.None
	player.GetNetworkPing = function()
		return 0.1
	end
	serverPlayerMethods(player)
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	SPAWN(player)
	return player
end

-- Like CharacterAutoLoads: the character appears shortly after the player joins.
function SPAWN(player)
	task.delay(0.1, function()
		if player.Parent == nil then
			return
		end
		player.Character = MAKE_CHARACTER(player.Name)
		player.CharacterAdded:Fire(player.Character)
	end)
end

-- Rejoins an existing Player object (the local player after LEAVE).
function REJOIN(player)
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	SPAWN(player)
end

function LEAVE(player)
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
end

-- Remotes: client <-> server loopback ------------------------------------------------------------------
LATENCY = 0.06 -- one-way seconds
NET_ERRORS = {}
SERVER_SENT = {} -- { name, player|"all", payload... }
local function netValue(v, path, seen)
	local t = type(v)
	if t == "function" or t == "thread" then
		error("cannot send a " .. t .. " at " .. path)
	end
	if t == "number" and v ~= v then
		error("NaN sent at " .. path)
	end
	if t ~= "table" then
		return v
	end
	local mt = getmetatable(v)
	if mt ~= nil then
		local tt = typeof(v)
		if tt == "table" then
			error("table with a metatable sent at " .. path .. " (metatables are not replicated)")
		end
		return v -- Roblox value types and Instances
	end
	if seen[v] then
		error("cyclic table sent at " .. path)
	end
	seen[v] = true
	local n, count, strings, numbers = #v, 0, false, false
	local out = {}
	for k, x in v do
		count += 1
		if type(k) == "string" then
			strings = true
		elseif type(k) == "number" then
			numbers = true
		else
			error("non-string key (" .. typeof(k) .. ") sent at " .. path)
		end
		out[k] = netValue(x, path .. "." .. tostring(k), seen)
	end
	if strings and numbers then
		error("mixed table sent at " .. path .. " (Roblox drops part of it)")
	end
	if numbers and count ~= n then
		error("sparse array sent at " .. path .. " (Roblox truncates it)")
	end
	seen[v] = nil
	return out
end
local function netCopy(label, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		local ok, result = pcall(netValue, args[i], label .. "#" .. i, {})
		if ok then
			args[i] = result
		else
			table.insert(NET_ERRORS, tostring(result))
		end
	end
	return args
end

local remotesFolder = FAKE_GAME:GetService("ReplicatedStorage"):FindFirstChild("Remotes")

-- Roblox queues events that reach a client before anything listens, and delivers them once a
-- handler connects (the client's scripts start after the server sends the first PlayerData).
local function deliverToClient(r, args)
	if LOCAL_PLAYER.Parent == nil then
		return
	end
	local signal = r.OnClientEvent
	if #signal.handlers == 0 then
		local queue = rawget(r, "_queue") or {}
		rawset(r, "_queue", queue)
		table.insert(queue, args)
		return
	end
	signal:Fire(table.unpack(args, 1, args.n))
end
for _, r in remotesFolder:GetChildren() do
	local signal = r.OnClientEvent
	local baseConnect = getmetatable(signal).Connect
	signal.Connect = function(self, fn)
		local conn = baseConnect(self, fn)
		local queue = rawget(r, "_queue")
		if queue and #queue > 0 then
			rawset(r, "_queue", nil)
			task.defer(function()
				for _, args in queue do
					self:Fire(table.unpack(args, 1, args.n))
				end
			end)
		end
		return conn
	end
end
for _, r in remotesFolder:GetChildren() do
	local name = r.Name
	local className = rawget(r, "_props").ClassName
	if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
		r.FireServer = function(_, ...)
			table.insert(SENT, { name, ... })
			local args = netCopy("client->server " .. name, ...)
			task.delay(LATENCY, function()
				r.OnServerEvent:Fire(LOCAL_PLAYER, table.unpack(args, 1, args.n))
			end)
		end
		r.FireClient = function(_, player, ...)
			if typeof(player) ~= "Instance" then
				table.insert(NET_ERRORS, name .. ":FireClient without a Player")
				return
			end
			local args = netCopy("server->client " .. name, ...)
			table.insert(SERVER_SENT, { name, player, table.unpack(args, 1, args.n) })
			if player == LOCAL_PLAYER then
				task.delay(LATENCY, deliverToClient, r, args)
			end
		end
		r.FireAllClients = function(_, ...)
			local args = netCopy("server->all " .. name, ...)
			table.insert(SERVER_SENT, { name, "all", table.unpack(args, 1, args.n) })
			task.delay(LATENCY, deliverToClient, r, args)
		end
	else -- RemoteFunction
		r.InvokeServer = function(_, ...)
			table.insert(SENT, { name, ... })
			local args = netCopy("client->server " .. name, ...)
			task.wait(LATENCY)
			local handler = r.OnServerInvoke
			if type(handler) ~= "function" then
				error("InvokeServer " .. name .. ": no OnServerInvoke (would yield forever)")
			end
			local results = table.pack(pcall(handler, LOCAL_PLAYER, table.unpack(args, 1, args.n)))
			task.wait(LATENCY)
			if not results[1] then
				error(results[2], 0) -- Roblox rethrows server errors on the client
			end
			local out = netCopy("server->client " .. name .. " result", table.unpack(results, 2, results.n))
			return table.unpack(out, 1, out.n)
		end
	end
end

-- Sends an intent as another (headless) player straight to the server handler.
function AS(player, name, ...)
	local r = remotesFolder:FindFirstChild(name)
	local className = rawget(r, "_props").ClassName
	local args = netCopy("client->server " .. name, ...)
	if className == "RemoteFunction" then
		return r.OnServerInvoke(player, table.unpack(args, 1, args.n))
	end
	r.OnServerEvent:Fire(player, table.unpack(args, 1, args.n))
	return nil
end

-- Last payload the server sent with this remote (optionally to one player).
function LAST_SENT(name, player)
	for i = #SERVER_SENT, 1, -1 do
		local s = SERVER_SENT[i]
		if s[1] == name and (player == nil or s[2] == player or s[2] == "all") then
			return s[3], s
		end
	end
	return nil
end
function COUNT_SENT(name, player)
	local n = 0
	for _, s in SERVER_SENT do
		if s[1] == name and (player == nil or s[2] == player or s[2] == "all") then
			n += 1
		end
	end
	return n
end

-- Boot ---------------------------------------------------------------------------------------------------
local RunService = FAKE_GAME:GetService("RunService")
function BOOT_SERVER()
	RunService.IsServer = function()
		return true
	end
	MODULE("ServerScriptService/Server/Main")
	RunService.IsServer = function()
		return false
	end
end
function BOOT_CLIENT()
	MODULE("StarterPlayer/StarterPlayerScripts/Client/Main")
end

-- GUI helpers ----------------------------------------------------------------------------------------------
-- True when the GUI object and all of its ancestors are visible (ScreenGuis enabled).
function SHOWN(inst)
	local node = inst
	while node ~= nil and typeof(node) == "Instance" do
		local props = rawget(node, "_props")
		if props.Visible == false then
			return false
		end
		if props.ClassName == "ScreenGui" and props.Enabled == false then
			return false
		end
		if props.ClassName == "PlayerGui" then
			return true
		end
		node = props.Parent
	end
	return false
end

local function labelText(button)
	local label = button:FindFirstChild("Label", true)
	if label and rawget(label, "_props").Text then
		return label.Text
	end
	return rawget(button, "_props").Text or ""
end
-- The visible button whose Name or label text matches `what` (plain, case-insensitive substring of
-- the label). `root` narrows the search.
function BUTTON(what, root)
	local needle = string.lower(what)
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	local byLabel = nil
	for _, d in (root or playerGui):GetDescendants() do
		local cn = rawget(d, "_props").ClassName
		if (cn == "TextButton" or cn == "ImageButton") and SHOWN(d) then
			if d.Name == what then
				return d -- an exact name always wins
			end
			if byLabel == nil and string.find(string.lower(labelText(d)), needle, 1, true) then
				byLabel = d
			end
		end
	end
	return byLabel
end
function BUTTON_TEXT(button)
	return labelText(button)
end
-- A mouse click on a button (down, up, Activated), like Roblox fires them.
function CLICK(button)
	assert(button ~= nil, "CLICK on a missing button")
	local input = { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.zero }
	button.MouseButton1Down:Fire()
	button.InputBegan:Fire(input)
	button.MouseButton1Up:Fire()
	FAKE_GAME:GetService("UserInputService").InputEnded:Fire(input, true)
	button.Activated:Fire(input, 1)
	button.MouseButton1Click:Fire()
end
-- Visible TextLabel texts under `root` (for asserting what the player sees).
function TEXTS(root)
	local out = {}
	for _, d in root:GetDescendants() do
		local props = rawget(d, "_props")
		if (props.ClassName == "TextLabel" or props.ClassName == "TextButton") and props.Text and props.Text ~= "" and SHOWN(d) then
			table.insert(out, props.Text)
		end
	end
	return out
end
function HAS_TEXT(root, needle)
	for _, t in TEXTS(root) do
		if string.find(string.lower(t), string.lower(needle), 1, true) then
			return true, t
		end
	end
	return false
end

-- Moves the local character (server and client both read HumanoidRootPart).
function MOVE_TO(position, character)
	local c = character or LOCAL_PLAYER.Character
	local root = c:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(position.X, position.Y, position.Z)
end

-- Fires a world ProximityPrompt for the local player (client handles it, sends the intent).
function TRIGGER_PROMPT(prompt)
	FAKE_GAME:GetService("ProximityPromptService").PromptTriggered:Fire(prompt, LOCAL_PLAYER)
end

-- Roblox's default (Custom) camera follows the character; the client only scripts it in flight.
FAKE_GAME:GetService("RunService").RenderStepped:Connect(function()
	local camera = FAKE_GAME:GetService("Workspace").CurrentCamera
	local character = LOCAL_PLAYER.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if camera and root and camera.CameraType == Enum.CameraType.Custom then
		local at = root.Position
		camera.CFrame = CFrame.lookAt(at + Vector3.new(0, 10, 18), at)
	end
end)
