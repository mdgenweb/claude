--[[
	Match
	Server-authoritative tower defense simulation for one arena.

	Enemies are plain data (distance along the path); clients render them from packed snapshots.
	Placed units are invisible anchor parts with attributes; clients attach the visual model.
	All timings use `self.clock` (simulation seconds), which runs `self.speed` times faster than real time.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Units = require(Shared.Config.Units)
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local Rarities = require(Shared.Config.Rarities)
local Challenges = require(Shared.Config.Challenges)
local PathMath = require(Shared.Util.PathMath)
local SnapshotCodec = require(Shared.Util.SnapshotCodec)
local UnitStats = require(Shared.Logic.UnitStats)
local WaveGen = require(Shared.Logic.WaveGen)

local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local Match = {}
Match.__index = Match

Match.TARGETING = { "First", "Last", "Strongest", "Weakest", "Closest" }

local MATCH_CFG = GameConfig.Match
local STEP = 1 / 30
local AURA_INTERVAL = 0.5
local MAX_FX_TARGETS = 24
local ARENA_HALF_X, ARENA_HALF_Z = 70, 50

local function flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Match.new(spec, slot: number, origin: Vector3, registry)
	local world = Worlds.get(spec.worldId)
	assert(world, "Unknown world " .. tostring(spec.worldId))
	local modifier = spec.modifier and Challenges.Modifiers[spec.modifier] or {}
	local self = setmetatable({}, Match)
	self.id = spec.id
	self.spec = spec
	self.mode = spec.mode
	self.act = spec.act or 1
	self.world = world
	self.modifier = modifier
	self.slot = slot
	self.origin = origin
	self.registry = registry
	self.path = PathMath.build(PathMath.offset(world.path, origin))
	self.clock = 0
	self.speed = 1
	self.state = "loading"
	self.wave = 0
	self.wavesCompleted = 0
	self.totalWaves = WaveGen.totalWaves(spec.mode, self.act)
	self.baseMaxHp = modifier.baseHealth or MATCH_CFG.BaseHealth
	self.baseHp = self.baseMaxHp
	self.enemies = {}
	self.enemyById = {}
	self.nextEnemyId = 1
	self.units = {}
	self.unitById = {}
	self.nextUnitId = 1
	self.players = {}
	self.playerCount = 0
	self.spawnQueue = {}
	self.waveHpScale = 1
	self.snapshotTimer = 0
	self.auraTimer = 0
	self.rng = Random.new()
	self.leaks = 0
	self.bossKills = 0
	self.hostUserId = spec.hostUserId
	self.ended = false
	self.connections = {}

	local arenas = workspace:FindFirstChild("Arenas")
	if not arenas then
		arenas = Instance.new("Folder")
		arenas.Name = "Arenas"
		arenas.Parent = workspace
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arena_" .. slot
	folder:SetAttribute("MatchId", self.id)
	folder.Parent = arenas
	self.folder = folder

	local unitsFolder = Instance.new("Folder")
	unitsFolder.Name = "Units"
	unitsFolder.Parent = folder
	self.unitsFolder = unitsFolder

	for _, player in spec.players do
		self:addPlayer(player)
	end
	return self
end

------------------------------------------------------------------------------------------------
-- Players
------------------------------------------------------------------------------------------------
function Match:addPlayer(player: Player)
	local profile = self.registry.DataService.get(player)
	if not profile then
		return
	end
	local team = {}
	local order = {}
	for _, uid in profile.team do
		local instance = profile.units[uid]
		if instance then
			team[uid] = table.clone(instance)
			team[uid].grades = table.clone(instance.grades or {})
			table.insert(order, uid)
		end
	end
	self.players[player] = {
		player = player,
		cash = MATCH_CFG.StartCash,
		team = team,
		order = order,
		placedByUnit = {},
		placedTotal = 0,
		voteSkip = false,
		kills = 0,
		damage = 0,
		cashDirty = true,
	}
	self.playerCount += 1
end

function Match:playerList(): { Player }
	local list = {}
	for player in self.players do
		table.insert(list, player)
	end
	return list
end

function Match:broadcast(event: string, data: any)
	local remote = self.registry.NetService.remote("Match")
	for player in self.players do
		remote:FireClient(player, event, data)
	end
end

function Match:sendTo(player: Player, event: string, data: any)
	self.registry.NetService.remote("Match"):FireClient(player, event, data)
end

function Match:teleportPlayer(player: Player)
	local character = player.Character
	if character and self.spawnCFrame then
		local offset = Vector3.new(self.rng:NextNumber(-4, 4), 0, self.rng:NextNumber(-4, 4))
		character:PivotTo(self.spawnCFrame + offset)
	end
end

function Match:removePlayer(player: Player)
	local state = self.players[player]
	if not state then
		return
	end
	for index = #self.units, 1, -1 do
		local unit = self.units[index]
		if unit.owner == player then
			self:removeUnit(unit)
		end
	end
	self.players[player] = nil
	self.playerCount -= 1
	if self.hostUserId == player.UserId then
		local nextPlayer = next(self.players)
		self.hostUserId = if nextPlayer then nextPlayer.UserId else nil
	end
	self:broadcast("PlayerLeft", { userId = player.UserId, host = self.hostUserId })
end

------------------------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------------------------
function Match:begin()
	local built = MapBuilder.build(self.world, self.origin, self.folder, self.path)
	self.map = built.model
	self.placeable = built.placeable
	self.spawnCFrame = built.playerSpawn
	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Include
	self.raycastParams.FilterDescendantsInstances = { built.placeable, built.blocked }
	self.blockedFolder = built.blocked

	for player, state in self.players do
		self:teleportPlayer(player)
		self:sendTo(player, "MatchStarted", {
			matchId = self.id,
			mode = self.mode,
			worldId = self.world.id,
			act = self.act,
			modifier = self.spec.modifier,
			totalWaves = self.totalWaves,
			baseHp = self.baseHp,
			baseMaxHp = self.baseMaxHp,
			origin = self.origin,
			arena = self.folder,
			cash = state.cash,
			team = state.order,
			teamInstances = state.team,
			hostUserId = self.hostUserId,
			prepSeconds = MATCH_CFG.PrepSeconds,
			players = #self:playerList(),
		})
	end

	self.state = "prep"
	self.prepEndsAt = MATCH_CFG.PrepSeconds
	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function(dt)
			self:update(dt)
		end)
	)
end

function Match:update(dt: number)
	if self.ended then
		return
	end
	local simDt = math.min(dt, 0.25) * self.speed
	local steps = math.max(1, math.ceil(simDt / STEP))
	local sub = simDt / steps
	for _ = 1, steps do
		self:step(sub)
		if self.ended then
			return
		end
	end
	self.snapshotTimer += dt
	if self.snapshotTimer >= 1 / MATCH_CFG.SnapshotRate then
		self.snapshotTimer = 0
		self:sendSnapshots()
	end
end

function Match:allVotedSkip(): boolean
	if self.playerCount == 0 then
		return false
	end
	for _, state in self.players do
		if not state.voteSkip then
			return false
		end
	end
	return true
end

function Match:step(dt: number)
	self.clock += dt
	local clock = self.clock

	if self.state == "prep" then
		if clock >= self.prepEndsAt or self:allVotedSkip() then
			self:startWave(1)
		end
	elseif self.state == "intermission" then
		if clock >= self.nextWaveAt or self:allVotedSkip() then
			self:startWave(self.wave + 1)
		end
	elseif self.state == "wave" then
		local queue = self.spawnQueue
		while queue[1] and queue[1].time <= clock do
			local entry = table.remove(queue, 1)
			self:spawnEnemy(entry.enemy, entry.hpMult, { elite = entry.elite, boss = entry.boss })
		end
		if #queue == 0 then
			if #self.enemies == 0 then
				self:completeWave(false)
			elseif self:allVotedSkip() and (not self.totalWaves or self.wave < self.totalWaves) then
				self:completeWave(true)
			end
		end
	end
	if self.ended then
		return
	end

	self:updateEnemies(dt)
	if self.ended then
		return
	end
	self.auraTimer += dt
	if self.auraTimer >= AURA_INTERVAL then
		self.auraTimer = 0
		self:updateAuras()
	end
	self:updateUnits(dt)
end

------------------------------------------------------------------------------------------------
-- Waves
------------------------------------------------------------------------------------------------
function Match:startWave(index: number)
	self.wave = index
	self.state = "wave"
	for _, state in self.players do
		state.voteSkip = false
	end
	local entries
	if self.mode == "Infinite" then
		entries = WaveGen.infiniteWave(self.world.id, index)
	else
		entries = WaveGen.storyWave(self.world.id, self.act, index)
	end
	local isBossWave = false
	for _, entry in entries do
		table.insert(self.spawnQueue, {
			time = self.clock + entry.delay,
			enemy = entry.enemy,
			hpMult = entry.hpMult,
			elite = entry.elite,
			boss = entry.boss,
		})
		if entry.boss then
			isBossWave = true
		else
			self.waveHpScale = entry.hpMult
		end
	end
	table.sort(self.spawnQueue, function(a, b)
		return a.time < b.time
	end)
	self:broadcast("WaveStarted", { wave = index, total = self.totalWaves, boss = isBossWave })
end

function Match:completeWave(skipped: boolean)
	local wave = self.wave
	self.wavesCompleted = math.max(self.wavesCompleted, wave)
	local incomeMod = self.modifier.income or 1
	local bonus = math.floor((MATCH_CFG.WaveBonusBase + MATCH_CFG.WaveBonusPerWave * wave) * incomeMod)
	if skipped then
		bonus += MATCH_CFG.SkipBonus
	end
	for player, state in self.players do
		local income = 0
		for _, unit in self.units do
			if unit.owner == player and unit.stats.income > 0 then
				income += unit.stats.income
			end
		end
		state.cash += bonus + math.floor(income * incomeMod)
		state.cashDirty = true
		state.voteSkip = false
		local profile = self.registry.DataService.get(player)
		if profile then
			self.registry.ProgressionService.track(player, profile, "Waves", 1)
		end
		self:sendTo(player, "WaveCompleted", {
			wave = wave,
			bonus = bonus,
			income = math.floor(income * incomeMod),
			skipped = skipped,
		})
	end

	if self.totalWaves and wave >= self.totalWaves then
		if #self.enemies == 0 then
			self:finish(true)
		end
		return
	end
	if skipped then
		self:startWave(wave + 1)
	else
		self.state = "intermission"
		self.nextWaveAt = self.clock + MATCH_CFG.IntermissionSeconds
		self:broadcast("Intermission", { nextWave = wave + 1, seconds = MATCH_CFG.IntermissionSeconds })
	end
end

------------------------------------------------------------------------------------------------
-- Enemies
------------------------------------------------------------------------------------------------
function Match:spawnEnemy(enemyId: string, hpMult: number, options)
	local def = Enemies.get(enemyId)
	if not def then
		return nil
	end
	options = options or {}
	local id = self.nextEnemyId
	self.nextEnemyId = (self.nextEnemyId % 65000) + 1
	local coopScale = 1 + 0.5 * math.max(0, self.playerCount - 1)
	local maxHp = def.hp * hpMult * (self.modifier.enemyHp or 1) * coopScale
	local hidden = def.hidden == true
	if not hidden and self.modifier.hiddenChance and not def.boss then
		hidden = self.rng:NextNumber() < self.modifier.hiddenChance
	end
	local enemy = {
		id = id,
		def = def,
		hp = maxHp,
		maxHp = maxHp,
		distance = options.distance or 0,
		baseSpeed = def.speed * (self.modifier.enemySpeed or 1),
		speedMult = 1,
		armor = def.armor or 0,
		hidden = hidden,
		boss = options.boss == true or def.boss == true,
		elite = options.elite == true,
		size = def.size * (if options.elite then 1.5 else 1),
		slowAmount = 0,
		slowUntil = 0,
		auraSlow = 0,
		stunUntil = 0,
		shredAmount = 0,
		shredUntil = 0,
		burnDps = 0,
		burnUntil = 0,
		burnSource = nil,
		shieldUntil = 0,
		enraged = false,
		abilityTimers = {},
		healTimer = 0,
		hpMult = hpMult,
		position = PathMath.sample(self.path, options.distance or 0),
		alive = true,
	}
	table.insert(self.enemies, enemy)
	self.enemyById[id] = enemy
	self:broadcast("EnemySpawned", {
		id = id,
		enemy = enemyId,
		maxHp = maxHp,
		distance = enemy.distance,
		hidden = hidden,
		boss = enemy.boss,
		elite = enemy.elite,
		size = enemy.size,
	})
	return enemy
end

function Match:effectiveSpeed(enemy): number
	if enemy.stunUntil > self.clock then
		return 0
	end
	local slow = if enemy.slowUntil > self.clock then enemy.slowAmount else 0
	slow = math.max(slow, enemy.auraSlow)
	if enemy.boss then
		slow *= 0.5 -- bosses resist half of all slows
	end
	return enemy.baseSpeed * enemy.speedMult * (1 - math.clamp(slow, 0, 0.8))
end

function Match:updateEnemies(dt: number)
	local clock = self.clock
	local enemies = self.enemies
	local index = 1
	while index <= #enemies do
		local enemy = enemies[index]
		if enemy.alive then
			-- Damage over time
			if enemy.burnUntil > clock then
				self:damageEnemy(enemy, enemy.burnDps * dt, enemy.burnSource)
			end
			if enemy.alive then
				enemy.distance += self:effectiveSpeed(enemy) * dt
				enemy.position = PathMath.sample(self.path, enemy.distance)
				if enemy.def.abilities then
					self:updateBossAbilities(enemy, dt)
				end
				if enemy.def.heal then
					self:updateHealer(enemy, dt)
				end
				if enemy.distance >= self.path.length then
					self:leakEnemy(enemy)
				end
			end
		end
		if self.ended then
			return
		end
		if enemy.alive then
			index += 1
		else
			table.remove(enemies, index)
		end
	end
end

function Match:updateBossAbilities(enemy, dt: number)
	for abilityIndex, ability in enemy.def.abilities do
		if ability.type == "enrage" then
			if not enemy.enraged and enemy.hp / enemy.maxHp <= ability.threshold then
				enemy.enraged = true
				enemy.speedMult = ability.speedMult
				self:broadcast("BossAbility", { id = enemy.id, type = "enrage" })
			end
		else
			local timer = (enemy.abilityTimers[abilityIndex] or 0) + dt
			if timer >= ability.interval then
				timer = 0
				self:triggerAbility(enemy, ability)
			end
			enemy.abilityTimers[abilityIndex] = timer
		end
	end
end

function Match:triggerAbility(enemy, ability)
	if ability.type == "stunPulse" then
		local hit = {}
		for _, unit in self.units do
			if flat(unit.position, enemy.position) <= ability.radius then
				unit.stunnedUntil = self.clock + ability.duration
				table.insert(hit, unit.id)
			end
		end
		self:broadcast("BossAbility", {
			id = enemy.id,
			type = "stunPulse",
			radius = ability.radius,
			duration = ability.duration,
			units = hit,
		})
	elseif ability.type == "summon" then
		for k = 1, ability.count do
			self:spawnEnemy(ability.enemy, self.waveHpScale, { distance = math.max(0, enemy.distance - k * 1.6) })
		end
		self:broadcast("BossAbility", { id = enemy.id, type = "summon", count = ability.count })
	elseif ability.type == "shield" then
		enemy.shieldUntil = self.clock + ability.duration
		self:broadcast("BossAbility", { id = enemy.id, type = "shield", duration = ability.duration })
	end
end

function Match:updateHealer(enemy, dt: number)
	local heal = enemy.def.heal
	enemy.healTimer += dt
	if enemy.healTimer < heal.interval then
		return
	end
	enemy.healTimer = 0
	local healed = {}
	for _, other in self.enemies do
		if other.alive and other ~= enemy and other.hp < other.maxHp then
			if flat(other.position, enemy.position) <= heal.radius then
				other.hp = math.min(other.maxHp, other.hp + other.maxHp * heal.amount)
				table.insert(healed, other.id)
			end
		end
	end
	if #healed > 0 then
		self:broadcast("EnemyHealed", { id = enemy.id, targets = healed })
	end
end

function Match:leakEnemy(enemy)
	enemy.alive = false
	self.enemyById[enemy.id] = nil
	self.baseHp = math.max(0, self.baseHp - enemy.def.leak * (if enemy.elite then 3 else 1))
	self.leaks += 1
	self:broadcast("EnemyLeaked", { id = enemy.id, baseHp = self.baseHp, baseMaxHp = self.baseMaxHp })
	if self.baseHp <= 0 then
		self:finish(false)
	end
end

-- Applies damage after shield/armour. Returns damage actually dealt.
function Match:damageEnemy(enemy, amount: number, unit): number
	if not enemy.alive or amount <= 0 then
		return 0
	end
	if enemy.shieldUntil > self.clock then
		return 0
	end
	local shred = if enemy.shredUntil > self.clock then enemy.shredAmount else 0
	local armor = math.clamp(enemy.armor * (1 - shred), 0, 0.9)
	local dealt = math.min(enemy.hp, amount * (1 - armor))
	enemy.hp -= dealt
	if unit then
		unit.damageDealt += dealt
		local state = self.players[unit.owner]
		if state then
			state.damage += dealt
		end
	end
	if enemy.hp <= 0.001 then
		self:killEnemy(enemy, unit)
	end
	return dealt
end

function Match:killEnemy(enemy, unit)
	enemy.alive = false
	self.enemyById[enemy.id] = nil
	local def = enemy.def
	local cash = 0
	if unit and self.players[unit.owner] then
		local worldBonus = 1 + 0.15 * (self.world.order - 1)
		local multiplier = (self.modifier.income or 1) * unit.stats.bountyMult * (if enemy.elite then 5 else 1)
		cash = math.floor(def.bounty * worldBonus * multiplier + 0.5)
		local state = self.players[unit.owner]
		state.cash += cash
		state.kills += 1
		state.cashDirty = true
		unit.kills += 1
		local profile = self.registry.DataService.get(unit.owner)
		if profile then
			self.registry.ProgressionService.track(unit.owner, profile, "Kills", 1)
			if enemy.boss then
				self.registry.ProgressionService.track(unit.owner, profile, "BossKills", 1)
			end
		end
	end
	if enemy.boss then
		self.bossKills += 1
	end
	self:broadcast("EnemyDied", {
		id = enemy.id,
		by = unit and unit.id,
		owner = unit and unit.owner.UserId,
		cash = cash,
		boss = enemy.boss,
	})
	if def.splitInto then
		for k = 1, def.splitInto.count do
			self:spawnEnemy(def.splitInto.enemy, enemy.hpMult * 0.5, { distance = math.max(0, enemy.distance - k * 0.8) })
		end
	end
	-- Final wave cleared?
	if self.state == "wave" and self.totalWaves and self.wave >= self.totalWaves and #self.spawnQueue == 0 then
		local anyAlive = false
		for _, other in self.enemies do
			if other.alive then
				anyAlive = true
				break
			end
		end
		if not anyAlive then
			self:completeWave(false)
		end
	end
end

------------------------------------------------------------------------------------------------
-- Units
------------------------------------------------------------------------------------------------
function Match:canPlace(player: Player, uid: any, position: any)
	local state = self.players[player]
	if not state then
		return false, "You're not in this match."
	end
	if self.ended then
		return false, "The match is over."
	end
	local instance = type(uid) == "string" and state.team[uid]
	if not instance then
		return false, "That unit isn't on your team."
	end
	if typeof(position) ~= "Vector3" then
		return false, "Bad position."
	end
	local def = Units.get(instance.id)
	if self.modifier.rarityCap and def.rarity ~= self.modifier.rarityCap then
		return false, "Only " .. self.modifier.rarityCap .. " units allowed in this challenge!"
	end
	local limit = def.maxPlaced or Rarities.get(def.rarity).maxPlaced
	if (state.placedByUnit[def.id] or 0) >= limit then
		return false, string.format("You can only place %d %s.", limit, def.name)
	end
	if state.placedTotal >= MATCH_CFG.MaxUnitsPerPlayer then
		return false, "You've reached the unit limit."
	end
	local localPos = position - self.origin
	if math.abs(localPos.X) > ARENA_HALF_X or math.abs(localPos.Z) > ARENA_HALF_Z then
		return false, "Out of bounds."
	end
	if PathMath.distanceToPath(self.path, position) < MATCH_CFG.PathClearance then
		return false, "Too close to the path!"
	end
	for _, other in self.units do
		if flat(other.position, position) < MATCH_CFG.PlacementRadius * 2 then
			return false, "Too close to another unit."
		end
	end
	local hit = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), self.raycastParams)
	if not hit or not hit.Instance:IsDescendantOf(self.placeable) then
		return false, "Can't place there."
	end
	local cost = UnitStats.placementCost(instance)
	if state.cash < cost then
		return false, "Not enough cash!"
	end
	return true, nil, instance, def, cost, hit.Position
end

function Match:placeUnit(player: Player, uid: any, position: any, rotation: any)
	local ok, err, instance, def, cost, groundPos = self:canPlace(player, uid, position)
	if not ok then
		return false, err
	end
	local state = self.players[player]
	state.cash -= cost
	state.cashDirty = true
	state.placedByUnit[def.id] = (state.placedByUnit[def.id] or 0) + 1
	state.placedTotal += 1

	local id = self.nextUnitId
	self.nextUnitId += 1
	local yaw = if type(rotation) == "number" then math.rad(rotation % 360) else 0
	local unit = {
		id = id,
		owner = player,
		uid = uid,
		instance = instance,
		def = def,
		level = 0,
		position = groundPos,
		yaw = yaw,
		cooldown = 0.2,
		targeting = "First",
		invested = cost,
		auras = {},
		stunnedUntil = 0,
		kills = 0,
		damageDealt = 0,
	}
	unit.stats = UnitStats.compute(instance, 0, unit.auras)

	local anchor = Instance.new("Part")
	anchor.Name = "Unit_" .. id
	anchor.Shape = Enum.PartType.Cylinder
	anchor.Size = Vector3.new(0.3, 3.2, 3.2)
	anchor.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, yaw, math.rad(90))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = true
	anchor.Transparency = 1
	anchor:SetAttribute("PlacedId", id)
	anchor:SetAttribute("OwnerId", player.UserId)
	anchor:SetAttribute("UnitId", def.id)
	anchor:SetAttribute("Uid", uid)
	anchor:SetAttribute("Level", 0)
	anchor:SetAttribute("Trait", instance.trait or "")
	anchor:SetAttribute("Shiny", instance.shiny == true)
	anchor:SetAttribute("Targeting", unit.targeting)
	anchor:SetAttribute("Yaw", math.deg(yaw))
	anchor.Parent = self.unitsFolder
	unit.anchor = anchor

	table.insert(self.units, unit)
	self.unitById[id] = unit
	self:broadcast("UnitPlaced", { id = id, owner = player.UserId, unitId = def.id, level = 0 })
	local profile = self.registry.DataService.get(player)
	if profile then
		self.registry.ProgressionService.track(player, profile, "Placements", 1)
	end
	return true, { id = id, cash = state.cash }
end

function Match:ownedUnit(player: Player, id: any)
	local unit = type(id) == "number" and self.unitById[id]
	if not unit or unit.owner ~= player then
		return nil
	end
	return unit
end

function Match:upgradeUnit(player: Player, id: any)
	local unit = self:ownedUnit(player, id)
	if not unit then
		return false, "That's not your unit."
	end
	local maxLevel = #unit.def.tiers - 1
	if unit.level >= maxLevel then
		return false, "Already max level!"
	end
	local cost = UnitStats.tierCost(unit.instance, unit.level + 1)
	local state = self.players[player]
	if state.cash < cost then
		return false, "Not enough cash!"
	end
	state.cash -= cost
	state.cashDirty = true
	unit.level += 1
	unit.invested += cost
	unit.stats = UnitStats.compute(unit.instance, unit.level, unit.auras)
	unit.anchor:SetAttribute("Level", unit.level)
	self:broadcast("UnitUpgraded", { id = unit.id, level = unit.level, move = unit.stats.moveKey })
	local profile = self.registry.DataService.get(player)
	if profile then
		self.registry.ProgressionService.track(player, profile, "Upgrades", 1)
	end
	return true, { id = unit.id, level = unit.level, cash = state.cash }
end

function Match:removeUnit(unit)
	local index = table.find(self.units, unit)
	if index then
		table.remove(self.units, index)
	end
	self.unitById[unit.id] = nil
	local state = self.players[unit.owner]
	if state then
		state.placedByUnit[unit.def.id] = math.max(0, (state.placedByUnit[unit.def.id] or 1) - 1)
		state.placedTotal = math.max(0, state.placedTotal - 1)
	end
	if unit.anchor then
		unit.anchor:Destroy()
	end
	self:broadcast("UnitRemoved", { id = unit.id })
end

function Match:sellUnit(player: Player, id: any)
	local unit = self:ownedUnit(player, id)
	if not unit then
		return false, "That's not your unit."
	end
	local refund = math.floor(unit.invested * MATCH_CFG.SellRefund)
	local state = self.players[player]
	state.cash += refund
	state.cashDirty = true
	self:removeUnit(unit)
	return true, { refund = refund, cash = state.cash }
end

function Match:setTargeting(player: Player, id: any, mode: any)
	local unit = self:ownedUnit(player, id)
	if not unit then
		return false, "That's not your unit."
	end
	if not table.find(Match.TARGETING, mode) then
		return false, "Bad targeting mode."
	end
	unit.targeting = mode
	unit.anchor:SetAttribute("Targeting", mode)
	return true, mode
end

function Match:updateAuras()
	local supports = {}
	for _, unit in self.units do
		if unit.stats.aura then
			table.insert(supports, unit)
		end
	end
	-- Unit buffs: strongest aura per stat wins (no stacking).
	for _, unit in self.units do
		local auras = { damage = 0, speed = 0, range = 0 }
		for _, support in supports do
			if support ~= unit and flat(support.position, unit.position) <= support.stats.range then
				local aura = support.stats.aura
				auras.damage = math.max(auras.damage, aura.damage or 0)
				auras.speed = math.max(auras.speed, aura.speed or 0)
				auras.range = math.max(auras.range, aura.range or 0)
			end
		end
		local changed = auras.damage ~= (unit.auras.damage or 0)
			or auras.speed ~= (unit.auras.speed or 0)
			or auras.range ~= (unit.auras.range or 0)
		if changed then
			unit.auras = auras
			unit.stats = UnitStats.compute(unit.instance, unit.level, auras)
			unit.anchor:SetAttribute("Buffed", auras.damage + auras.speed + auras.range > 0)
		end
	end
	-- Enemy slow auras.
	for _, enemy in self.enemies do
		local slow = 0
		for _, support in supports do
			local enemySlow = support.stats.aura.enemySlow
			if enemySlow and flat(support.position, enemy.position) <= support.stats.range then
				slow = math.max(slow, enemySlow)
			end
		end
		enemy.auraSlow = slow
	end
end

local function targetScore(mode: string, enemy, unitPos: Vector3): number
	if mode == "First" then
		return enemy.distance
	elseif mode == "Last" then
		return -enemy.distance
	elseif mode == "Strongest" then
		return enemy.hp
	elseif mode == "Weakest" then
		return -enemy.hp
	end
	return -flat(enemy.position, unitPos)
end

function Match:updateUnits(dt: number)
	local clock = self.clock
	for _, unit in self.units do
		if unit.stunnedUntil <= clock then
			unit.cooldown -= dt
			if unit.cooldown <= 0 then
				if self:unitAttack(unit) then
					unit.cooldown = unit.stats.cooldown
				else
					unit.cooldown = 0.1
				end
			end
		end
		if self.ended then
			return
		end
	end
end

function Match:collectCandidates(unit)
	local stats = unit.stats
	local candidates = {}
	for _, enemy in self.enemies do
		if enemy.alive and (not enemy.hidden or stats.detect) then
			if flat(enemy.position, unit.position) <= stats.range then
				table.insert(candidates, enemy)
			end
		end
	end
	return candidates
end

function Match:unitAttack(unit): boolean
	local stats = unit.stats
	local move = stats.move
	if not move then
		return false
	end
	local candidates = self:collectCandidates(unit)
	if #candidates == 0 then
		return false
	end
	local mode = unit.targeting
	local unitPos = unit.position
	table.sort(candidates, function(a, b)
		return targetScore(mode, a, unitPos) > targetScore(mode, b, unitPos)
	end)
	local primary = candidates[1]
	local hits = {}
	local kind = move.kind

	if kind == "single" then
		hits[1] = primary
	elseif kind == "multi" then
		for index = 1, math.min(move.targets or 2, #candidates) do
			hits[index] = candidates[index]
		end
	elseif kind == "circle" then
		hits = candidates
	elseif kind == "splash" then
		local radius = move.radius or 4
		for _, enemy in self.enemies do
			if enemy.alive and (not enemy.hidden or stats.detect) and flat(enemy.position, primary.position) <= radius then
				table.insert(hits, enemy)
			end
		end
	elseif kind == "cone" then
		local toTarget = primary.position - unitPos
		local dir = Vector3.new(toTarget.X, 0, toTarget.Z)
		dir = if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, 1)
		local cosHalf = math.cos(math.rad((move.angle or 90) / 2))
		for _, enemy in candidates do
			local offset = enemy.position - unitPos
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			if flatOffset.Magnitude < 0.01 or flatOffset.Unit:Dot(dir) >= cosHalf then
				table.insert(hits, enemy)
			end
		end
	elseif kind == "line" then
		local toTarget = primary.position - unitPos
		local dir = Vector3.new(toTarget.X, 0, toTarget.Z)
		dir = if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, 1)
		local halfWidth = (move.width or 3) / 2
		for _, enemy in self.enemies do
			if enemy.alive and (not enemy.hidden or stats.detect) then
				local offset = enemy.position - unitPos
				local flatOffset = Vector3.new(offset.X, 0, offset.Z)
				local along = flatOffset:Dot(dir)
				if along >= 0 and along <= stats.range then
					local perpendicular = (flatOffset - dir * along).Magnitude
					if perpendicular <= halfWidth + enemy.size * 0.5 then
						table.insert(hits, enemy)
					end
				end
			end
		end
	elseif kind == "chain" then
		hits[1] = primary
		local used = { [primary] = true }
		local last = primary
		for _ = 2, move.chains or 3 do
			local best, bestDistance = nil, move.chainRange or 8
			for _, enemy in self.enemies do
				if enemy.alive and not used[enemy] and (not enemy.hidden or stats.detect) then
					local d = flat(enemy.position, last.position)
					if d <= bestDistance then
						best, bestDistance = enemy, d
					end
				end
			end
			if not best then
				break
			end
			used[best] = true
			table.insert(hits, best)
			last = best
		end
	end

	if #hits == 0 then
		return false
	end

	local damage = stats.damage
	local fxTargets = {}
	local primaryDealt = 0
	for index, enemy in hits do
		local falloff = if kind == "chain" then 0.85 ^ (index - 1) else 1
		local dealt = self:applyHit(unit, enemy, damage * falloff, move)
		if index == 1 then
			primaryDealt = dealt
		end
		if index <= MAX_FX_TARGETS then
			table.insert(fxTargets, enemy.id)
		end
	end

	local fx = { unit.id, math.floor(primaryDealt + 0.5), fxTargets }
	local remote = self.registry.NetService.remote("Fx")
	for player in self.players do
		remote:FireClient(player, fx)
	end
	return true
end

function Match:applyHit(unit, enemy, damage: number, move): number
	if not enemy.alive then
		return 0
	end
	local clock = self.clock
	-- Effects first so a killing blow still shows them client-side.
	if move.slow then
		enemy.slowAmount = math.max(if enemy.slowUntil > clock then enemy.slowAmount else 0, move.slow.amount)
		enemy.slowUntil = math.max(enemy.slowUntil, clock + move.slow.duration)
	end
	local stun = move.stun or 0
	if unit.stats.stunChance > 0 and self.rng:NextNumber() < unit.stats.stunChance then
		stun = math.max(stun, unit.stats.stunTime)
	end
	if stun > 0 then
		local effective = if enemy.boss then stun * 0.35 else stun
		enemy.stunUntil = math.max(enemy.stunUntil, clock + effective)
	end
	if move.shred then
		enemy.shredAmount = math.max(if enemy.shredUntil > clock then enemy.shredAmount else 0, move.shred.amount)
		enemy.shredUntil = math.max(enemy.shredUntil, clock + move.shred.duration)
	end
	if move.burn then
		local dps = damage * move.burn.dps
		if enemy.burnUntil <= clock or dps >= enemy.burnDps then
			enemy.burnDps = dps
			enemy.burnSource = unit
		end
		enemy.burnUntil = math.max(enemy.burnUntil, clock + move.burn.duration)
	end
	if move.knockback and not enemy.boss then
		local push = if enemy.elite then move.knockback * 0.5 else move.knockback
		enemy.distance = math.max(0, enemy.distance - push)
		enemy.position = PathMath.sample(self.path, enemy.distance)
	end
	return self:damageEnemy(enemy, damage, unit)
end

------------------------------------------------------------------------------------------------
-- Networking
------------------------------------------------------------------------------------------------
function Match:sendSnapshots()
	local clock = self.clock
	local records = table.create(#self.enemies)
	for _, enemy in self.enemies do
		if enemy.alive then
			local flags = 0
			if enemy.stunUntil > clock then
				flags += SnapshotCodec.FLAG_STUNNED
			end
			if enemy.slowUntil > clock or enemy.auraSlow > 0 then
				flags += SnapshotCodec.FLAG_SLOWED
			end
			if enemy.burnUntil > clock then
				flags += SnapshotCodec.FLAG_BURNING
			end
			if enemy.shieldUntil > clock then
				flags += SnapshotCodec.FLAG_SHIELDED
			end
			if enemy.shredUntil > clock then
				flags += SnapshotCodec.FLAG_SHREDDED
			end
			table.insert(records, {
				id = enemy.id,
				distance = enemy.distance,
				speed = self:effectiveSpeed(enemy) * self.speed,
				hp = math.clamp(enemy.hp / enemy.maxHp, 0, 1),
				flags = flags,
			})
		end
	end
	local remote = self.registry.NetService.remote("EnemySync")
	local now = workspace:GetServerTimeNow()
	local index = 1
	repeat
		local buf
		buf, index = SnapshotCodec.encode(records, index, now)
		for player in self.players do
			remote:FireClient(player, buf)
		end
	until index > #records

	-- Cash + base updates piggyback on the snapshot tick (reliable).
	for player, state in self.players do
		if state.cashDirty then
			state.cashDirty = false
			self:sendTo(player, "Cash", state.cash)
		end
	end
end

------------------------------------------------------------------------------------------------
-- Player actions
------------------------------------------------------------------------------------------------
function Match:voteSkip(player: Player)
	local state = self.players[player]
	if not state then
		return false, "Not in match."
	end
	if self.state == "wave" and #self.spawnQueue > 0 then
		return false, "Wait until the wave has fully spawned."
	end
	if self.state == "wave" and self.totalWaves and self.wave >= self.totalWaves then
		return false, "Beat the final wave!"
	end
	state.voteSkip = true
	local votes = 0
	for _, other in self.players do
		if other.voteSkip then
			votes += 1
		end
	end
	self:broadcast("SkipVotes", { votes = votes, needed = self.playerCount })
	return true, { votes = votes, needed = self.playerCount }
end

function Match:setSpeed(player: Player, speed: any)
	if not self.players[player] then
		return false, "Not in match."
	end
	if self.hostUserId and player.UserId ~= self.hostUserId then
		return false, "Only the host can change speed."
	end
	if not table.find(MATCH_CFG.Speeds, speed) then
		return false, "Bad speed."
	end
	if speed == 3 then
		local allowed = false
		for other in self.players do
			if self.registry.ShopService.hasPass(other, "ThreeXSpeed") then
				allowed = true
				break
			end
		end
		if not allowed then
			return false, "3x Speed needs the 3x Speed pass (anyone in your party)."
		end
	end
	self.speed = speed
	self:broadcast("Speed", speed)
	return true, speed
end

------------------------------------------------------------------------------------------------
-- End of match
------------------------------------------------------------------------------------------------
function Match:computeRewards(player: Player, state, victory: boolean)
	local registry = self.registry
	local profile = registry.DataService.get(player)
	if not profile then
		return nil
	end
	local ShopService = registry.ShopService
	local doubleGumballs = ShopService.hasPass(player, "DoubleGumballs")
	local doubleDrops = ShopService.hasPass(player, "DoubleDrops")
	local rewardsCfg = GameConfig.Rewards
	local bundle = {}
	local result = { victory = victory, wave = self.wave, kills = state.kills, damage = math.floor(state.damage) }
	local worldGumballs = rewardsCfg.WinGumballsByWorld[self.world.order] or 60
	local actScale = 1 + 0.15 * (self.act - 1)

	if self.mode == "Story" then
		local key = Worlds.stageKey(self.world.id, self.act)
		if victory then
			local stars = if self.leaks == 0 then 3 elseif self.baseHp / self.baseMaxHp >= 0.5 then 2 else 1
			local firstClear = (profile.story[key] or 0) == 0
			profile.story[key] = math.max(profile.story[key] or 0, stars)
			result.stars = stars
			result.firstClear = firstClear
			local gumballs = worldGumballs * actScale
			if firstClear then
				gumballs *= rewardsCfg.FirstClearMultiplier
				if self.act == Worlds.ACTS then
					bundle.VoidCores = 1
				end
			end
			bundle.Gumballs = gumballs
		else
			local progress = if self.totalWaves then self.wavesCompleted / self.totalWaves else 0
			bundle.Gumballs = worldGumballs * actScale * rewardsCfg.LossGumballFraction * progress
		end
	elseif self.mode == "Infinite" then
		bundle.Gumballs = math.floor(self.wavesCompleted / 5) * rewardsCfg.InfiniteGumballsPer5Waves
		local best = profile.infiniteBest[self.world.id] or 0
		if self.wavesCompleted > best then
			profile.infiniteBest[self.world.id] = self.wavesCompleted
			result.newBest = true
		end
		registry.LeaderboardService.submit(player, self.wavesCompleted)
	elseif self.mode == "Challenge" then
		if victory then
			local challengeId = self.spec.challengeId
			if challengeId and not profile.challengesDone[challengeId] then
				profile.challengesDone[challengeId] = os.time()
				bundle.Gumballs = rewardsCfg.ChallengeGumballs
				for id, amount in self.spec.challengeReward or {} do
					bundle[id] = (bundle[id] or 0) + amount * (if doubleDrops then 2 else 1)
				end
				result.challengeReward = true
				registry.ProgressionService.track(player, profile, "ChallengeWins", 1)
			else
				bundle.Gumballs = math.floor(rewardsCfg.ChallengeGumballs * 0.25)
				result.challengeRepeat = true
			end
		end
	end

	if victory and self.mode ~= "Infinite" then
		registry.ProgressionService.track(player, profile, "Wins", 1)
		if self.rng:NextNumber() < rewardsCfg.ItemDropChance then
			local drop = if self.rng:NextNumber() < 0.5 then "VoidShards" else "ReportCards"
			bundle[drop] = (bundle[drop] or 0) + (if doubleDrops then 2 else 1)
		end
	end
	if bundle.Gumballs then
		bundle.Gumballs = math.floor(bundle.Gumballs * (if doubleGumballs then 2 else 1))
	end
	bundle.PassXp = math.floor(
		(if victory then rewardsCfg.PassXpPerWin else rewardsCfg.PassXpPerLoss) + state.kills * rewardsCfg.PassXpPerKill
	)

	local granted = registry.EconomyService.grant(player, profile, bundle)
	local playerXp = if victory then rewardsCfg.PlayerXpPerWin else rewardsCfg.PlayerXpPerLoss
	registry.ProgressionService.addPlayerXp(player, profile, playerXp)
	local unitXp = math.max(1, self.wavesCompleted) * rewardsCfg.UnitXpPerWave
	registry.InventoryService.grantUnitXp(player, profile, state.order, unitXp)

	-- Prune old challenge completions (they rotate every 30 minutes).
	local cutoff = os.time() - 7200
	for id, time in profile.challengesDone do
		if type(time) ~= "number" or time < cutoff then
			profile.challengesDone[id] = nil
		end
	end

	result.rewards = granted
	result.playerXp = playerXp
	result.unitXp = unitXp
	return result
end

function Match:finish(victory: boolean)
	if self.ended then
		return
	end
	self.ended = true
	self.state = "ended"
	self.victory = victory
	for player, state in self.players do
		local ok, result = pcall(self.computeRewards, self, player, state, victory)
		if not ok then
			warn("[Match] reward error:", result)
			result = { victory = victory, wave = self.wave, kills = state.kills, rewards = {} }
		end
		self:sendTo(player, "MatchEnded", result)
	end
	self.endedAt = os.clock()
	if self.onFinished then
		task.spawn(self.onFinished, self, victory)
	end
end

function Match:destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.ended = true
	if self.folder then
		self.folder:Destroy()
	end
end

-- Used by DevService
function Match:devAddCash(player: Player, amount: number)
	local state = self.players[player]
	if state then
		state.cash += amount
		state.cashDirty = true
	end
end

function Match:devWin()
	for _, enemy in self.enemies do
		enemy.alive = false
	end
	table.clear(self.enemies)
	table.clear(self.spawnQueue)
	self:finish(true)
end

function Match:hasPlayer(player: Player): boolean
	return self.players[player] ~= nil
end

function Match:isEmpty(): boolean
	return next(self.players) == nil
end

return Match
