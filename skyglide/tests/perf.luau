--!prelude-before _rbxmock.luau
--!prelude-after _clientmock.luau
--!prelude-after _servermock.luau
-- Performance budget (run through tests/perf.py, not a spec). A busy server: the local player
-- plus 9 headless players with pets, everyone throwing on Auto Throw and training, 10 flights in
-- the air at once. Every per-frame handler (Heartbeat, Stepped, RenderStepped, BindToRenderStep)
-- is timed and attributed to its module; remote traffic per player is sized as JSON.
local Map = MODULE("ReplicatedStorage/Shared/Config/Map")
local Eggs = MODULE("ReplicatedStorage/Shared/Definitions/Eggs")
local RunService = FAKE_GAME:GetService("RunService")

-- attribute time to the module that registered each per-frame callback
local cost = {} -- source -> { total, max, calls }
local frameCost = 0
local function timed(fn)
	local source = debug.info(fn, "s")
	return function(...)
		local t0 = REAL_CLOCK()
		fn(...)
		local dt = (REAL_CLOCK() - t0) * 1000
		local c = cost[source]
		if not c then
			c = { total = 0, max = 0, calls = 0 }
			cost[source] = c
		end
		c.total += dt
		c.calls += 1
		frameCost += dt
		if dt > c.max then
			c.max = dt
		end
	end
end
local bind = RunService.BindToRenderStep
RunService.BindToRenderStep = function(self, name, priority, fn)
	return bind(self, name, priority, timed(fn))
end
for _, signalName in { "Heartbeat", "Stepped", "RenderStepped" } do
	local signal = RunService[signalName]
	local connect = getmetatable(signal).Connect
	signal.Connect = function(self, fn)
		return connect(self, timed(fn))
	end
end

BOOT_SERVER()
STEP(0.2)
BOOT_CLIENT()
STEP(4)

-- nine more players, each with pets, standing in the throw zone with Auto Throw on
local zone = Map.Origin(1) + Vector3.new(0, 3, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2)
local egg = Eggs.ForWorld(1)[1]
local eggSpot = Map.Origin(1) + Map.EggPosition(1) + Vector3.new(0, 3, 5)
local players = { LOCAL_PLAYER }
for i = 1, 9 do
	table.insert(players, JOIN(100 + i, "Bot" .. i))
end
STEP(2)
for _, p in players do
	AS(p, "AdminRequest", "GrantWins", 1e6)
	AS(p, "AdminRequest", "MaxLevel")
	p.Character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(eggSpot)
end
STEP(0.5)
for round = 1, 4 do
	for _, p in players do
		AS(p, "RequestHatchEgg", egg.Id, 1)
	end
	STEP(1.2) -- hatch rate limit
	local _ = round
end
-- the 9 bots throw on Auto Throw; the local player watches from the zone, so every pet and
-- every flight is near the camera (the worst case for the client)
for i, p in players do
	p.Character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(zone + Vector3.new((i - 5) * 6, 0, 0))
	if p ~= LOCAL_PLAYER then
		AS(p, "RequestPurchase", "Pass", "AutoThrow")
		AS(p, "RequestToggle", "AutoThrow", true)
	end
end
-- the reveal overlays queue up; dismiss them like a player would
for _ = 1, 12 do
	STEP(2.5, 10)
	local reveal = LOCAL_PLAYER:FindFirstChild("PlayerGui"):FindFirstChild("HatchReveal", true)
	if reveal and SHOWN(reveal) then
		CLICK(reveal)
	end
end

-- measure 30 s of play at 60 fps (the local player keeps throwing by hand: one local flight too)
for k in cost do
	cost[k] = nil
end
local frames = {}
local sentBefore = #SERVER_SENT
local startClock = CLOCK
local maxFlights = 0
local FlightService = MODULE("ServerScriptService/Server/Services/FlightService")
for _ = 1, 30 * 60 do
	frameCost = 0
	STEP(1 / 60, 60)
	table.insert(frames, frameCost)
	maxFlights = math.max(maxFlights, FlightService.ActiveCount())
end
local seconds = CLOCK - startClock

table.sort(frames)
local sum = 0
for _, f in frames do
	sum += f
end
print(string.format("FRAME\t%.3f\t%.3f\t%.3f\t%d", sum / #frames, frames[math.floor(#frames * 0.95)], frames[#frames], maxFlights))
for source, c in cost do
	print(string.format("COST\t%s\t%.4f\t%.3f\t%d", source, c.total / (#frames), c.max, c.calls))
end

-- traffic: server -> local client, sized as compact JSON
local function size(v)
	local t = typeof(v)
	if t == "string" then
		return #v + 2
	elseif t == "number" then
		return 8
	elseif t == "boolean" then
		return 5
	elseif t == "table" then
		local s = 2
		for k, x in v do
			s += size(k) + size(x) + 2
		end
		return s
	elseif t == "Instance" then
		return 8
	end
	return 12 -- Vector3 / CFrame / Color3 and friends
end
local bytes, messages = 0, 0
local byName = {}
for i = sentBefore + 1, #SERVER_SENT do
	local s = SERVER_SENT[i]
	if s[2] == LOCAL_PLAYER or s[2] == "all" then
		local b = 0
		for j = 3, #s do
			b += size(s[j])
		end
		b += #s[1] + 16
		bytes += b
		messages += 1
		byName[s[1]] = (byName[s[1]] or 0) + b
	end
end
print(string.format("NET\t%.1f\t%.1f", bytes / seconds / 1024, messages / seconds))
for name, b in byName do
	print(string.format("NETBY\t%s\t%.2f", name, b / seconds / 1024))
end
print(string.format("INST\t%d", INSTANCE_COUNT))

-- heavy profile: the local player with a full pet inventory, throwing on Auto Throw for 30 s
local DataService = MODULE("ServerScriptService/Server/Services/DataService")
local Economy = MODULE("ReplicatedStorage/Shared/Config/Economy")
DataService.Update(LOCAL_PLAYER, function(p)
	local n = 0
	for _ in p.Pets do
		n += 1
	end
	for i = n + 1, Economy.PetInventory do
		p.Pets[tostring(1000 + i)] = { Id = "sandy_crab", Locked = false }
	end
	return true
end)
AS(LOCAL_PLAYER, "RequestPurchase", "Pass", "AutoThrow")
AS(LOCAL_PLAYER, "RequestToggle", "AutoThrow", true)
STEP(2, 10)
local heavyBefore = #SERVER_SENT
local heavyStart = CLOCK
STEP(30, 30)
local dataBytes, dataCount = 0, 0
for i = heavyBefore + 1, #SERVER_SENT do
	local s = SERVER_SENT[i]
	if s[1] == "PlayerData" and s[2] == LOCAL_PLAYER then
		dataBytes += size(s[3])
		dataCount += 1
	end
end
print(string.format("HEAVY\t%.2f\t%.2f\t%d", dataBytes / (CLOCK - heavyStart) / 1024, dataCount / (CLOCK - heavyStart), if dataCount > 0 then math.floor(dataBytes / dataCount) else 0))
local followers = FAKE_GAME:GetService("Workspace"):FindFirstChild("PetFollowers")
print(string.format("PETS\t%d", followers and #followers:GetChildren() or 0))
for _, e in CLIENT_ERRORS do
	print("CLIENT ERROR: " .. e)
end
