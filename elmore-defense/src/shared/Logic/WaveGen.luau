--[[
	WaveGen
	Deterministic wave compositions. Same seed -> same waves, so balancing changes are reproducible and
	tests can assert difficulty curves.

	Spawn entry: { enemy, delay, hpMult, elite, boss }
	  delay   seconds after the wave starts
	  hpMult  multiplier applied to the enemy's base hp (bosses use their own scale)
]]

local Shared = script.Parent.Parent
local Worlds = require(Shared.Config.Worlds)
local Enemies = require(Shared.Config.Enemies)

local WaveGen = {}

WaveGen.WAVE_HP_GROWTH = 1.12
WaveGen.INFINITE_HP_GROWTH = 1.15
WaveGen.ELITE_HP_MULT = 8
WaveGen.INFINITE_BOSS_EVERY = 10

local function available(world, waveIndex: number): { string }
	local list = {}
	local newIndex = {}
	for index, id in world.newEnemies do
		newIndex[id] = index
	end
	for _, id in world.roster do
		local k = newIndex[id]
		local unlockWave = if k then (k - 1) * 3 + 1 else 1
		-- In worlds after the first, new enemies arrive a little later to give a "new threat" moment.
		if k and world.order > 1 then
			unlockWave = 2 + (k - 1) * 3
		end
		if waveIndex >= unlockWave then
			table.insert(list, id)
		end
	end
	if #list == 0 then
		table.insert(list, world.roster[1])
	end
	return list
end

local function spawnInterval(enemyId: string): number
	local enemy = Enemies.get(enemyId)
	if enemy.speed >= 8 then
		return 0.55
	elseif enemy.hp >= 150 then
		return 1.6
	end
	return 0.9
end

function WaveGen.hpScale(world, act: number, waveIndex: number): number
	return world.hpMult * Worlds.actHpMult(act) * WaveGen.WAVE_HP_GROWTH ^ (waveIndex - 1)
end

local function compose(world, rng, waveIndex: number, count: number, hpMult: number, entries)
	local pool = available(world, waveIndex)
	local groups = math.clamp(1 + waveIndex // 4, 1, 3)
	local remaining = count
	local cursor = if #entries > 0 then entries[#entries].delay + 1.5 else 0
	for group = 1, groups do
		local groupCount = if group == groups then remaining else math.max(1, math.floor(count / groups))
		remaining -= groupCount
		-- Favour the newest unlocked enemy in the last group so new threats are noticeable.
		local enemyId = if group == groups and #pool > 1 and rng:NextNumber() < 0.5
			then pool[#pool]
			else pool[rng:NextInteger(1, #pool)]
		local interval = spawnInterval(enemyId)
		for _ = 1, groupCount do
			table.insert(entries, { enemy = enemyId, delay = cursor, hpMult = hpMult, elite = false, boss = false })
			cursor += interval
		end
		cursor += 1.5
	end
	return entries
end

local function tankiest(world, waveIndex: number): string
	local best, bestHp = world.roster[1], -1
	for _, id in available(world, waveIndex) do
		local hp = Enemies.get(id).hp
		if hp > bestHp then
			best, bestHp = id, hp
		end
	end
	return best
end

function WaveGen.storyWave(worldId: string, act: number, waveIndex: number)
	local world = Worlds.get(worldId)
	local total = Worlds.wavesForAct(act)
	local rng = Random.new(world.order * 100003 + act * 1009 + waveIndex * 17)
	local hpMult = WaveGen.hpScale(world, act, waveIndex)
	local count = math.floor(5 + waveIndex * 1.6 + act * 0.8)
	local entries = {}

	if waveIndex == total then
		-- Boss wave: escorts first, then the boss.
		compose(world, rng, waveIndex, math.floor(count * 0.5), hpMult, entries)
		local last = entries[#entries]
		table.insert(entries, {
			enemy = world.boss,
			delay = (if last then last.delay else 0) + 2,
			hpMult = world.hpMult * Worlds.actHpMult(act),
			elite = false,
			boss = true,
		})
		return entries
	end

	compose(world, rng, waveIndex, count, hpMult, entries)
	if act >= 3 and waveIndex == total // 2 then
		local last = entries[#entries]
		table.insert(entries, {
			enemy = tankiest(world, waveIndex),
			delay = (if last then last.delay else 0) + 1.5,
			hpMult = hpMult * WaveGen.ELITE_HP_MULT,
			elite = true,
			boss = false,
		})
	end
	return entries
end

function WaveGen.infiniteWave(worldId: string, waveIndex: number)
	local world = Worlds.get(worldId)
	local rng = Random.new(world.order * 7919 + waveIndex * 31)
	local hpMult = world.hpMult * WaveGen.INFINITE_HP_GROWTH ^ (waveIndex - 1)
	local count = math.min(math.floor(6 + waveIndex * 1.8), 70)
	local entries = {}
	-- Infinite uses the full roster immediately.
	compose(world, rng, 99, count, hpMult, entries)
	if waveIndex % WaveGen.INFINITE_BOSS_EVERY == 0 then
		local last = entries[#entries]
		table.insert(entries, {
			enemy = world.boss,
			delay = (if last then last.delay else 0) + 2,
			hpMult = world.hpMult * (1 + waveIndex / 10) ^ 2,
			elite = false,
			boss = true,
		})
	end
	return entries
end

-- Total waves for a mode (nil = endless).
function WaveGen.totalWaves(mode: string, act: number): number?
	if mode == "Infinite" then
		return nil
	end
	return Worlds.wavesForAct(act)
end

return WaveGen
