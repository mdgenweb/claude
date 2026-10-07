-- Battle simulation spec: runs every orb matchup headlessly with the real server modules.
-- Executed by tests/run_tests.py (provides MODULE(path) and the fake DataModel).
local BallDefinitions = MODULE("ReplicatedStorage/Shared/Definitions/BallDefinitions")
local Physics = MODULE("ReplicatedStorage/Shared/Config/Physics")
local SnapshotCodec = MODULE("ReplicatedStorage/Shared/Net/SnapshotCodec")
local Rng = MODULE("ReplicatedStorage/Shared/Util/Rng")
local World = MODULE("ServerScriptService/Server/Battle/World")

local failures = 0
local function check(cond, message)
	if not cond then
		failures += 1
		print("FAILED: " .. message)
	end
end

local abilityCache = {}
local function resolveAbility(id)
	if abilityCache[id] == nil then
		abilityCache[id] = MODULE("ServerScriptService/Server/Battle/Abilities/" .. id)
	end
	return abilityCache[id]
end

local errors = {}
local function newWorld(seed, half)
	return World.new({
		seed = seed,
		half = half or 8,
		resolveAbility = resolveAbility,
		resolveDefinition = BallDefinitions.Get,
		onError = function(message)
			table.insert(errors, message)
		end,
	})
end

local function isFinite(v)
	return v == v and v ~= math.huge and v ~= -math.huge
end

local MAX_STEPS = Physics.TickRate * (Physics.RoundHardCap + 5)
local DT = 1 / Physics.TickRate

-- Runs one battle; returns result, battle seconds, total events
local function runBattle(seed, layout, half)
	local world = newWorld(seed, half)
	local rng = Rng.new(seed * 7 + 3)
	local balls = {}
	for _, spec in layout do
		local ball = world:SpawnBall({ defId = spec.def, owner = spec.owner, team = spec.team, x = spec.x, y = spec.y })
		table.insert(balls, ball)
	end
	for _, ball in balls do
		world:Launch(ball.id, rng:Range(0, 2 * math.pi))
	end
	local events = 0
	local maxSnapshot = 0
	local result = world:GetResult()
	local steps = 0
	while result.state == "ongoing" and steps < MAX_STEPS do
		world:Step(DT)
		steps += 1
		for _, ball in world.balls do
			if ball.alive then
				if not (isFinite(ball.x) and isFinite(ball.y) and isFinite(ball.vx) and isFinite(ball.vy)) then
					check(false, "non-finite ball state " .. ball.defId .. " seed " .. seed)
					return { state = "error" }, 0, 0
				end
				local h = world.half
				check(math.abs(ball.x) <= h - ball.r + 1e-6 and math.abs(ball.y) <= h - ball.r + 1e-6, "ball escaped arena: " .. ball.defId)
				check(ball.hp >= 0 and ball.hp <= ball.maxHp + 1e-6, "hp out of range: " .. ball.defId)
			end
		end
		if steps % 3 == 0 then
			local size = buffer.len(SnapshotCodec.Encode(world:Snapshot(1, steps)))
			maxSnapshot = math.max(maxSnapshot, size)
		end
		events += #world:DrainEvents()
		result = world:GetResult()
	end
	check(result.state ~= "ongoing", "battle did not terminate (seed " .. seed .. ")")
	check(maxSnapshot <= 850, "snapshot too large: " .. maxSnapshot)
	return result, world:BattleTime(), events
end

-------------------------------------------------------------------------------- 1v1 matrix
local defs = BallDefinitions.All()
local wins, games, durations, draws = {}, {}, {}, 0
local totalTime, totalGames = 0, 0
local longest = 0
for i, a in defs do
	for j, b in defs do
		if i ~= j then
			for s = 1, 2 do
				local seed = i * 1000 + j * 10 + s
				local result, t = runBattle(seed, {
					{ def = a.Id, owner = 1, team = 1, x = -4.5, y = 0 },
					{ def = b.Id, owner = 2, team = 2, x = 4.5, y = 0 },
				})
				games[a.Id] = (games[a.Id] or 0) + 1
				games[b.Id] = (games[b.Id] or 0) + 1
				if result.state == "win" then
					local winner = if result.team == 1 then a.Id else b.Id
					wins[winner] = (wins[winner] or 0) + 1
				elseif result.state == "draw" then
					draws += 1
				end
				durations[a.Id] = (durations[a.Id] or 0) + t
				durations[b.Id] = (durations[b.Id] or 0) + t
				totalTime += t
				totalGames += 1
				longest = math.max(longest, t)
			end
		end
	end
end

print(string.format("1v1 matrix: %d battles, avg %.1fs, longest %.1fs, draws %d", totalGames, totalTime / totalGames, longest, draws))
local rows = {}
for _, def in defs do
	table.insert(rows, { id = def.Id, rarity = def.Rarity, rate = (wins[def.Id] or 0) / games[def.Id], avg = durations[def.Id] / games[def.Id] })
end
table.sort(rows, function(x, y)
	return x.rate > y.rate
end)
for _, row in rows do
	print(string.format("  %-10s %-9s win %5.1f%%  avg %4.1fs", row.id, row.rarity, row.rate * 100, row.avg))
end
check(totalTime / totalGames > 8 and totalTime / totalGames < 70, "average battle length out of the 8-70s window")

-------------------------------------------------------------------------------- 2v2
local rng = Rng.new(42)
local teamGames, teamTime = 0, 0
for n = 1, 150 do
	local pick = function()
		return rng:Pick(defs).Id
	end
	local result, t = runBattle(50000 + n, {
		{ def = pick(), owner = 1, team = 1, x = -5.5, y = 3.5 },
		{ def = pick(), owner = 2, team = 1, x = -5.5, y = -3.5 },
		{ def = pick(), owner = 3, team = 2, x = 5.5, y = 3.5 },
		{ def = pick(), owner = 4, team = 2, x = 5.5, y = -3.5 },
	}, 10)
	check(result.state == "win" or result.state == "draw", "2v2 battle did not resolve")
	teamGames += 1
	teamTime += t
end
print(string.format("2v2: %d battles, avg %.1fs", teamGames, teamTime / teamGames))

-------------------------------------------------------------------------------- determinism
local function fingerprint(seed)
	local world = newWorld(seed)
	local a = world:SpawnBall({ defId = "storm", owner = 1, team = 1, x = -4.5, y = 0 })
	local b = world:SpawnBall({ defId = "mitosis", owner = 2, team = 2, x = 4.5, y = 0 })
	world:Launch(a.id, 0.7)
	world:Launch(b.id, 2.4)
	for _ = 1, 600 do
		world:Step(DT)
	end
	local parts = {}
	for _, ball in world.balls do
		table.insert(parts, string.format("%d:%.9f,%.9f,%.4f", ball.id, ball.x, ball.y, ball.hp))
	end
	return table.concat(parts, "|")
end
check(fingerprint(99) == fingerprint(99), "simulation is not deterministic")
check(fingerprint(99) ~= fingerprint(100), "seed has no effect")

-------------------------------------------------------------------------------- codec
do
	local snap = {
		station = 3,
		seq = 1234,
		time = 12.5,
		balls = { { id = 1, x = -7.25, y = 3.5, hp = 74.2, r = 1.5, flags = 5 } },
		entities = { { id = 900, x = 12.1, y = -0.5, rot = math.pi / 2, scale = 1.75 } },
	}
	local decoded = SnapshotCodec.Decode(SnapshotCodec.Encode(snap))
	check(decoded ~= nil, "codec decode failed")
	if decoded then
		check(decoded.station == 3 and decoded.seq == 1234, "codec header mismatch")
		check(math.abs(decoded.balls[1].x + 7.25) < 0.001 and decoded.balls[1].hp == 75, "codec ball mismatch")
		check(math.abs(decoded.entities[1].scale - 1.75) < 0.05, "codec entity mismatch")
	end
end

-------------------------------------------------------------------------------- ability errors
for _, message in errors do
	check(false, message)
end

if failures == 0 then
	print("battle.spec: OK")
else
	print(string.format("battle.spec: %d FAILED checks", failures))
end
