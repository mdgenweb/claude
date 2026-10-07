--!strict
-- Deterministic 2D battle simulation (server authoritative).
--
-- * Fixed time step (Physics.TickRate). Same seed + same inputs = same battle.
-- * No Roblox physics: results do not depend on ping or network ownership.
-- * Pure Luau apart from module lookups: runs headlessly in tests/ with the Luau CLI.
--
-- The World doubles as the AbilityContext: ability modules receive it as `ctx` and must only
-- use the helpers in the "Ability API" section.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhysicsConfig = require(Shared.Config.Physics)
local Rng = require(Shared.Util.Rng)
local SnapshotCodec = require(Shared.Net.SnapshotCodec)

local Types = require(script.Parent.Types)
local Damage = require(script.Parent.Damage)

type Ball = Types.Ball
type Entity = Types.Entity
type EntitySpec = Types.EntitySpec
type DamageInfo = Types.DamageInfo
type Ability = Types.Ability
type BattleEvent = Types.BattleEvent
type Result = Types.Result

export type WorldOptions = {
	seed: number,
	half: number,
	resolveAbility: (abilityId: string) -> Ability?,
	resolveDefinition: (defId: string) -> any,
	friendlyFire: boolean?,
	physics: { [string]: any }?,
	onError: ((message: string) -> ())?,
}

local World = {}
World.__index = World

export type World = typeof(setmetatable(
	{} :: {
		time: number,
		launchTime: number?,
		half: number,
		rng: Rng.Rng,
		physics: { [string]: any },
		balls: { Ball },
		ballsById: { [number]: Ball },
		entities: { Entity },
		entitiesById: { [number]: Entity },
		events: { BattleEvent },
		nextBallId: number,
		nextEntityId: number,
		pairCooldown: { [number]: number },
		friendlyFire: boolean,
		damageMult: number,
		overtimeLevel: number,
		resolveAbility: (string) -> Ability?,
		resolveDefinition: (string) -> any,
		onError: (string) -> (),
		accumulator: number,
		finished: boolean,
		_erroredHooks: { [string]: boolean },
	},
	World
))

local function newStatus(): Types.Status
	return {
		frozen = 0,
		snared = 0,
		slowed = 0,
		slowFactor = 1,
		phased = 0,
		charging = 0,
		latched = 0,
		invuln = 0,
	}
end

function World.new(opts: WorldOptions): World
	local physics = table.clone(PhysicsConfig) :: { [string]: any }
	if opts.physics then
		for k, v in opts.physics do
			physics[k] = v
		end
	end
	local self = setmetatable({
		time = 0,
		launchTime = nil,
		half = opts.half,
		rng = Rng.new(opts.seed),
		physics = physics,
		balls = {},
		ballsById = {},
		entities = {},
		entitiesById = {},
		events = {},
		nextBallId = 1,
		nextEntityId = 1,
		pairCooldown = {},
		friendlyFire = opts.friendlyFire == true,
		damageMult = 1,
		overtimeLevel = 0,
		resolveAbility = opts.resolveAbility,
		resolveDefinition = opts.resolveDefinition,
		onError = opts.onError or function(message: string)
			warn(message)
		end,
		accumulator = 0,
		finished = false,
		_erroredHooks = {},
	}, World)
	return self
end

---------------------------------------------------------------------------------------------
-- Hooks

function World._call(self: World, ball: Ball, hook: string, ...: any): (boolean, any)
	local ability = ball.ability
	if ability == nil then
		return false, nil
	end
	local fn = (ability :: any)[hook]
	if fn == nil then
		return false, nil
	end
	local ok, result = pcall(fn, self, ball, ball.params, ...)
	if not ok then
		local key = ball.defId .. ":" .. hook
		if not self._erroredHooks[key] then
			self._erroredHooks[key] = true
			self.onError(string.format("[Battle] ability %s.%s failed: %s", ball.defId, hook, tostring(result)))
		end
		return false, nil
	end
	return true, result
end

---------------------------------------------------------------------------------------------
-- Balls

export type BallSpec = {
	defId: string,
	owner: number,
	team: number,
	x: number,
	y: number,
	isMinion: boolean?,
	radius: number?,
	hp: number?,
	contact: number?,
	noAbility: boolean?,
}

function World.SpawnBall(self: World, spec: BallSpec): Ball
	local def = self.resolveDefinition(spec.defId)
	assert(def ~= nil, "unknown ball definition " .. tostring(spec.defId))
	local id = self.nextBallId
	self.nextBallId += 1
	local radius = spec.radius or def.Radius
	local hp = spec.hp or def.BaseHP
	local ability: Ability? = nil
	if not spec.noAbility and def.AbilityId then
		ability = self.resolveAbility(def.AbilityId)
	end
	local ball: Ball = {
		id = id,
		defId = def.Id,
		def = def,
		owner = spec.owner,
		team = spec.team,
		isMinion = spec.isMinion == true,
		x = spec.x,
		y = spec.y,
		vx = 0,
		vy = 0,
		r = radius,
		baseR = radius,
		mass = def.Mass * (radius / def.Radius) ^ 2,
		hp = hp,
		maxHp = hp,
		contact = spec.contact or def.ContactDamage,
		speedMult = 1,
		gravityScale = 1,
		alive = true,
		launched = false,
		status = newStatus(),
		frozenVuln = 0,
		dmgTakenMult = 1,
		dmgDealtMult = 1,
		ability = ability,
		params = def.AbilityParams or {},
		state = {},
		attrition = 0,
		damageDealt = 0,
		lastAttacker = nil,
	}
	table.insert(self.balls, ball)
	self.ballsById[id] = ball
	self:Emit({
		t = "BallSpawn",
		id = id,
		def = def.Id,
		team = ball.team,
		owner = ball.owner,
		x = ball.x,
		y = ball.y,
		r = ball.r,
		hp = ball.hp,
		maxHp = ball.maxHp,
		minion = ball.isMinion,
	})
	self:_call(ball, "Init")
	return ball
end

function World.Launch(self: World, ballId: number, angle: number, speedOverride: number?)
	local ball = self.ballsById[ballId]
	if ball == nil or not ball.alive or ball.launched then
		return
	end
	local speed = speedOverride or self.physics.CruiseSpeed * ball.def.Speed
	ball.vx = math.cos(angle) * speed
	ball.vy = math.sin(angle) * speed
	ball.launched = true
	ball.status.invuln = self.physics.SpawnImmunity
	if self.launchTime == nil then
		self.launchTime = self.time
	end
	self:Emit({ t = "Launch", id = ballId, angle = angle })
	self:_call(ball, "OnLaunch")
end

---------------------------------------------------------------------------------------------
-- Ability API (ctx helpers)

function World.Emit(self: World, event: BattleEvent)
	table.insert(self.events, event)
end

function World.Fx(self: World, kind: string, data: { [string]: any })
	local event = table.clone(data)
	event.t = "Fx"
	event.kind = kind
	self:Emit(event)
end

function World.Now(self: World): number
	return self.time
end

function World.BattleTime(self: World): number
	return if self.launchTime then self.time - self.launchTime else 0
end

function World.Half(self: World): number
	return self.half
end

function World.Random(self: World): Rng.Rng
	return self.rng
end

function World.IsEnemy(self: World, a: Ball, b: Ball): boolean
	return a.team ~= b.team
end

function World.Enemies(self: World, ball: Ball): { Ball }
	local out = {}
	for _, other in self.balls do
		if other.alive and other.team ~= ball.team then
			table.insert(out, other)
		end
	end
	return out
end

function World.Nearest(self: World, ball: Ball, includePhased: boolean?): Ball?
	local best: Ball? = nil
	local bestDist = math.huge
	for _, other in self.balls do
		if other.alive and other.team ~= ball.team and (includePhased or other.status.phased <= 0) then
			local d = (other.x - ball.x) ^ 2 + (other.y - ball.y) ^ 2
			if d < bestDist then
				bestDist = d
				best = other
			end
		end
	end
	return best
end

function World.Damage(self: World, target: Ball, amount: number, info: DamageInfo): number
	return Damage.Apply(self, target, amount, info)
end

function World.Heal(self: World, ball: Ball, amount: number)
	if not ball.alive or amount <= 0 then
		return
	end
	local old = ball.hp
	ball.hp = math.min(ball.maxHp, ball.hp + amount)
	local healed = ball.hp - old
	if healed > 0 then
		self:Emit({ t = "Heal", id = ball.id, amount = healed })
		self:_call(ball, "OnHealthChanged", old, ball.hp)
	end
end

function World.SetStatus(self: World, ball: Ball, status: string, duration: number, extra: { [string]: any }?)
	local st = ball.status :: any
	if st[status] == nil then
		return
	end
	st[status] = math.max(st[status], duration)
	if status == "slowed" and extra and extra.factor then
		ball.status.slowFactor = math.min(ball.status.slowFactor, extra.factor)
	end
	self:Emit({ t = "Status", id = ball.id, status = status, duration = duration })
end

function World.SetVelocity(self: World, ball: Ball, vx: number, vy: number)
	ball.vx = vx
	ball.vy = vy
end

function World.Spawn(self: World, spec: EntitySpec): Entity?
	local live = 0
	for _, e in self.entities do
		if not e.removed then
			live += 1
		end
	end
	if live >= self.physics.MaxEntities then
		return nil
	end
	local id = self.nextEntityId
	self.nextEntityId = (self.nextEntityId % 65000) + 1
	local owner = spec.owner
	local e: Entity = {
		id = id,
		kind = spec.kind,
		shape = spec.shape or "circle",
		x = spec.x,
		y = spec.y,
		x2 = spec.x2 or spec.x,
		y2 = spec.y2 or spec.y,
		r = spec.r or 0.5,
		vx = spec.vx or 0,
		vy = spec.vy or 0,
		rot = spec.rot or 0,
		scale = spec.scale or 1,
		owner = owner,
		team = spec.team or (if owner then owner.team else 0),
		life = spec.life or math.huge,
		age = 0,
		armed = spec.armed or 0,
		dynamic = spec.dynamic == true,
		gravity = spec.gravity or 0,
		dieOnWall = spec.dieOnWall == true,
		pierce = spec.pierce == true,
		damage = spec.damage or 0,
		damageKind = spec.damageKind or "hazard",
		hitCooldown = spec.hitCooldown or 0.5,
		hits = {},
		persist = spec.persist == true,
		removed = false,
		data = spec.data or {},
		visual = spec.visual or {},
		onHit = spec.onHit,
		onUpdate = spec.onUpdate,
		onExpire = spec.onExpire,
		onWall = spec.onWall,
	}
	table.insert(self.entities, e)
	self.entitiesById[id] = e
	self:Emit({
		t = "EntitySpawn",
		id = id,
		kind = e.kind,
		shape = e.shape,
		x = e.x,
		y = e.y,
		x2 = e.x2,
		y2 = e.y2,
		r = e.r,
		rot = e.rot,
		scale = e.scale,
		team = e.team,
		owner = if owner then owner.id else nil,
		life = if e.life == math.huge then -1 else e.life,
		armed = e.armed,
		dynamic = e.dynamic,
		visual = e.visual,
	})
	return e
end

function World.Remove(self: World, e: Entity, reason: string?)
	if e.removed then
		return
	end
	e.removed = true
	self.entitiesById[e.id] = nil
	self:Emit({ t = "EntityRemove", id = e.id, reason = reason or "expire" })
end

-- Notify clients that a static entity moved/changed (rare; e.g. a rail train starting).
function World.UpdateEntity(self: World, e: Entity, fields: { [string]: any })
	local event = table.clone(fields)
	event.t = "EntityUpdate"
	event.id = e.id
	self:Emit(event)
end

function World.EntitiesOf(self: World, owner: Ball, kind: string?): { Entity }
	local out = {}
	for _, e in self.entities do
		if not e.removed and e.owner == owner and (kind == nil or e.kind == kind) then
			table.insert(out, e)
		end
	end
	return out
end

-- Distance from a point to a segment (used for beams, rails, trails, thorns).
function World.PointSegmentDistance(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	local dx, dy = bx - ax, by - ay
	local lenSq = dx * dx + dy * dy
	local t = 0
	if lenSq > 1e-9 then
		t = math.clamp(((px - ax) * dx + (py - ay) * dy) / lenSq, 0, 1)
	end
	local cx, cy = ax + dx * t, ay + dy * t
	return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

function World.EntityTouches(self: World, e: Entity, ball: Ball): boolean
	if e.shape == "circle" then
		local reach = e.r * e.scale + ball.r
		return (ball.x - e.x) ^ 2 + (ball.y - e.y) ^ 2 < reach * reach
	elseif e.shape == "segment" then
		return World.PointSegmentDistance(ball.x, ball.y, e.x, e.y, e.x2, e.y2) < e.r + ball.r
	end
	return false
end

function World.SpawnMinion(self: World, parent: Ball, x: number, y: number, vx: number, vy: number, radius: number, hp: number, contact: number): Ball
	local h = self.half
	local minion = self:SpawnBall({
		defId = parent.defId,
		owner = parent.owner,
		team = parent.team,
		x = math.clamp(x, -h + radius, h - radius),
		y = math.clamp(y, -h + radius, h - radius),
		isMinion = true,
		radius = radius,
		hp = hp,
		contact = contact,
		noAbility = true,
	})
	minion.launched = true
	minion.vx = vx
	minion.vy = vy
	minion.status.invuln = 0.3
	return minion
end

---------------------------------------------------------------------------------------------
-- Death

function World.Kill(self: World, ball: Ball, killer: Ball?)
	if not ball.alive then
		return
	end
	local handled, prevent = self:_call(ball, "OnDeath", killer)
	if handled and prevent == true and ball.hp > 0 then
		return
	end
	ball.alive = false
	ball.hp = 0
	self:Emit({
		t = "Death",
		id = ball.id,
		killer = if killer then killer.id else nil,
		x = ball.x,
		y = ball.y,
		minion = ball.isMinion,
	})
	for _, e in self.entities do
		if not e.removed and e.owner == ball and not e.persist then
			self:Remove(e, "owner")
		end
	end
	if killer and killer.alive then
		self:_call(killer, "OnKill", ball)
	end
end

---------------------------------------------------------------------------------------------
-- Simulation step

local function rotate(vx: number, vy: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return vx * c - vy * s, vx * s + vy * c
end

function World._wallHit(self: World, ball: Ball, nx: number, ny: number, px: number, py: number)
	local jitter = math.rad(self.physics.WallJitterDegrees)
	if jitter > 0 then
		local vx, vy = rotate(ball.vx, ball.vy, self.rng:Range(-jitter, jitter))
		-- never jitter back into the wall
		if vx * nx + vy * ny > 0 then
			ball.vx, ball.vy = vx, vy
		end
	end
	self:Emit({ t = "Wall", id = ball.id, x = px, y = py, nx = nx, ny = ny })
	self:_call(ball, "OnWallHit", nx, ny, px, py)
end

function World._moveBall(self: World, ball: Ball, dt: number)
	local st = ball.status
	if st.frozen > 0 or st.snared > 0 then
		return
	end
	local P = self.physics
	local g = P.Gravity * ball.gravityScale
	if st.charging > 0 then
		g = 0
	end
	ball.vy -= g * dt
	local slow = if st.slowed > 0 then st.slowFactor else 1
	ball.x += ball.vx * dt * slow
	ball.y += ball.vy * dt * slow

	local h = self.half
	local r = ball.r
	local e = P.WallRestitution
	if ball.x - r < -h then
		ball.x = -h + r
		if ball.vx < 0 then
			ball.vx = -ball.vx * e
			self:_wallHit(ball, 1, 0, -h, ball.y)
		end
	elseif ball.x + r > h then
		ball.x = h - r
		if ball.vx > 0 then
			ball.vx = -ball.vx * e
			self:_wallHit(ball, -1, 0, h, ball.y)
		end
	end
	if ball.y - r < -h then
		ball.y = -h + r
		if ball.vy < 0 then
			ball.vy = -ball.vy * e
			self:_wallHit(ball, 0, 1, ball.x, -h)
		end
	elseif ball.y + r > h then
		ball.y = h - r
		if ball.vy > 0 then
			ball.vy = -ball.vy * e
			self:_wallHit(ball, 0, -1, ball.x, h)
		end
	end
end

-- Restores each ball's mechanical energy toward its cruise energy so fights stay lively
-- without ever looking like constant-speed billiards.
function World._govern(self: World, ball: Ball, dt: number)
	local st = ball.status
	if st.frozen > 0 or st.snared > 0 or st.charging > 0 then
		return
	end
	local P = self.physics
	local g = P.Gravity * ball.gravityScale
	local h = self.half
	local target = P.CruiseSpeed * ball.def.Speed * ball.speedMult
	local height = ball.y + h
	local energy = 0.5 * (ball.vx * ball.vx + ball.vy * ball.vy) + g * height
	local targetEnergy = 0.5 * target * target + g * h
	local newEnergy = energy + (targetEnergy - energy) * math.min(1, P.GovernorRate * dt)
	local kinetic = math.max(newEnergy - g * height, 0.5 * P.MinSpeed * P.MinSpeed)
	local speed = math.min(math.sqrt(2 * kinetic), P.MaxSpeed)
	local current = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
	if current < 1e-4 then
		local angle = self.rng:Range(0, 2 * math.pi)
		ball.vx, ball.vy = math.cos(angle) * speed, math.sin(angle) * speed
	else
		local k = speed / current
		ball.vx *= k
		ball.vy *= k
	end
end

local function immobile(ball: Ball): boolean
	return ball.status.frozen > 0 or ball.status.snared > 0
end

function World._collidePair(self: World, a: Ball, b: Ball)
	local dx, dy = b.x - a.x, b.y - a.y
	local distSq = dx * dx + dy * dy
	local minDist = a.r + b.r
	if distSq >= minDist * minDist then
		return
	end
	local dist = math.sqrt(distSq)
	local nx, ny = 1, 0
	if dist > 1e-6 then
		nx, ny = dx / dist, dy / dist
	end
	local overlap = minDist - dist
	local aFixed, bFixed = immobile(a), immobile(b)

	-- positional correction
	if aFixed and not bFixed then
		b.x += nx * overlap
		b.y += ny * overlap
	elseif bFixed and not aFixed then
		a.x -= nx * overlap
		a.y -= ny * overlap
	else
		local total = a.mass + b.mass
		a.x -= nx * overlap * (b.mass / total)
		a.y -= ny * overlap * (b.mass / total)
		b.x += nx * overlap * (a.mass / total)
		b.y += ny * overlap * (a.mass / total)
	end

	-- velocity response
	local e = self.physics.BallRestitution
	local rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
	if rel < 0 then
		if aFixed and not bFixed then
			local vn = b.vx * nx + b.vy * ny
			b.vx -= (1 + e) * vn * nx
			b.vy -= (1 + e) * vn * ny
		elseif bFixed and not aFixed then
			local vn = a.vx * nx + a.vy * ny
			a.vx -= (1 + e) * vn * nx
			a.vy -= (1 + e) * vn * ny
		elseif not aFixed and not bFixed then
			local j = -(1 + e) * rel / (1 / a.mass + 1 / b.mass)
			a.vx -= (j / a.mass) * nx
			a.vy -= (j / a.mass) * ny
			b.vx += (j / b.mass) * nx
			b.vy += (j / b.mass) * ny
		end
	end

	-- contact damage (pair cooldown)
	local key = math.min(a.id, b.id) * 1024 + math.max(a.id, b.id)
	local last = self.pairCooldown[key]
	if last ~= nil and self.time - last < self.physics.ContactCooldown then
		return
	end
	self.pairCooldown[key] = self.time
	local cx, cy = a.x + nx * a.r, a.y + ny * a.r
	local enemies = a.team ~= b.team or self.friendlyFire
	if not enemies then
		self:Emit({ t = "Hit", a = a.id, b = b.id, x = cx, y = cy, friendly = true })
		return
	end

	local dmgAB = a.contact
	local okA, modA = self:_call(a, "ModifyContact", b, dmgAB)
	if okA and type(modA) == "number" then
		dmgAB = modA
	end
	local dmgBA = b.contact
	local okB, modB = self:_call(b, "ModifyContact", a, dmgBA)
	if okB and type(modB) == "number" then
		dmgBA = modB
	end

	self:_call(a, "OnBallHit", b, cx, cy)
	self:_call(b, "OnBallHit", a, cx, cy)

	local dealtAB = if a.alive and b.alive then Damage.Apply(self, b, dmgAB, { source = a, kind = "contact", x = cx, y = cy }) else 0
	local dealtBA = if a.alive and b.alive then Damage.Apply(self, a, dmgBA, { source = b, kind = "contact", x = cx, y = cy }) else 0
	self:Emit({
		t = "Hit",
		a = a.id,
		b = b.id,
		x = cx,
		y = cy,
		nx = nx,
		ny = ny,
		dab = dealtAB,
		dba = dealtBA,
		heavy = math.max(dealtAB, dealtBA) >= 10,
	})
end

function World._updateEntities(self: World, dt: number)
	local h = self.half
	local count = #self.entities
	for i = 1, count do
		local e = self.entities[i]
		if e.removed then
			continue
		end
		e.age += dt
		e.life -= dt
		e.armed -= dt
		if e.onUpdate then
			local ok, err = pcall(e.onUpdate :: any, self, e, dt)
			if not ok then
				self.onError("[Battle] entity update failed: " .. tostring(err))
				self:Remove(e, "error")
				continue
			end
		elseif e.dynamic then
			e.vy -= e.gravity * dt
			e.x += e.vx * dt
			e.y += e.vy * dt
			if e.vx ~= 0 or e.vy ~= 0 then
				e.rot = math.atan2(e.vy, e.vx)
			end
		end
		if e.removed then
			continue
		end
		if e.dieOnWall and (math.abs(e.x) > h - e.r * 0.5 or math.abs(e.y) > h - e.r * 0.5) then
			if e.onWall then
				pcall(e.onWall, self, e)
			end
			self:Remove(e, "wall")
			continue
		end
		if e.life <= 0 then
			if e.onExpire then
				pcall(e.onExpire, self, e)
			end
			self:Remove(e, "expire")
			continue
		end
		if e.armed > 0 or (e.damage <= 0 and e.onHit == nil) or e.shape == "none" then
			continue
		end
		for _, ball in self.balls do
			if not ball.alive or not ball.launched or ball.team == e.team then
				continue
			end
			if ball.status.phased > 0 then
				continue
			end
			if not self:EntityTouches(e, ball) then
				continue
			end
			local last = e.hits[ball.id]
			if last ~= nil and self.time - last < e.hitCooldown then
				continue
			end
			e.hits[ball.id] = self.time
			if e.onHit then
				local ok, err = pcall(e.onHit :: any, self, e, ball)
				if not ok then
					self.onError("[Battle] entity hit failed: " .. tostring(err))
				end
			else
				Damage.Apply(self, ball, e.damage, { source = e.owner, kind = e.damageKind, entity = e, x = ball.x, y = ball.y })
			end
			if not e.pierce then
				self:Remove(e, "hit")
				break
			end
			if e.removed then
				break
			end
		end
	end
	-- compact removed entities
	if count > 0 then
		local kept = {}
		for _, e in self.entities do
			if not e.removed then
				table.insert(kept, e)
			end
		end
		self.entities = kept
	end
end

function World._overtime(self: World, dt: number)
	local P = self.physics
	local t = self:BattleTime()
	if t < P.OvertimeStart then
		return
	end
	local level = 1 + math.floor((t - P.OvertimeStart) / P.OvertimeStep)
	if level ~= self.overtimeLevel then
		self.overtimeLevel = level
		self.damageMult = 1 + level * P.OvertimeDamageBonus
		self:Emit({ t = "Overtime", level = level, mult = self.damageMult })
	end
	for _, ball in self.balls do
		if ball.alive and ball.launched then
			ball.attrition += P.OvertimeAttrition * dt
			if ball.attrition >= 1 then
				local chunk = math.floor(ball.attrition)
				ball.attrition -= chunk
				Damage.Apply(self, ball, chunk, { kind = "overtime", ignorePhase = true })
			end
		end
	end
end

function World.Step(self: World, dt: number)
	if self.finished then
		return
	end
	self.time += dt

	-- statuses + ability ticks
	for _, ball in self.balls do
		if not ball.alive then
			continue
		end
		local st = ball.status
		st.frozen = math.max(0, st.frozen - dt)
		st.snared = math.max(0, st.snared - dt)
		st.phased = math.max(0, st.phased - dt)
		st.charging = math.max(0, st.charging - dt)
		st.latched = math.max(0, st.latched - dt)
		st.invuln = math.max(0, st.invuln - dt)
		if st.slowed > 0 then
			st.slowed = math.max(0, st.slowed - dt)
			if st.slowed <= 0 then
				st.slowFactor = 1
			end
		end
		if ball.launched then
			self:_call(ball, "OnTick", dt)
		end
	end

	-- movement + walls
	for _, ball in self.balls do
		if ball.alive and ball.launched then
			self:_moveBall(ball, dt)
		end
	end

	-- ball vs ball
	local n = #self.balls
	for i = 1, n - 1 do
		local a = self.balls[i]
		if not a.alive or not a.launched or a.status.phased > 0 then
			continue
		end
		for j = i + 1, n do
			local b = self.balls[j]
			if b.alive and b.launched and b.status.phased <= 0 and a.alive then
				self:_collidePair(a, b)
			end
		end
	end

	-- keep everything inside after pushes
	local h = self.half
	for _, ball in self.balls do
		if ball.alive then
			ball.x = math.clamp(ball.x, -h + ball.r, h - ball.r)
			ball.y = math.clamp(ball.y, -h + ball.r, h - ball.r)
		end
	end

	-- governor
	for _, ball in self.balls do
		if ball.alive and ball.launched then
			self:_govern(ball, dt)
		end
	end

	self:_updateEntities(dt)
	if self.launchTime ~= nil then
		self:_overtime(dt)
	end
end

-- Advance by real time using the fixed step. Returns number of steps taken.
function World.Advance(self: World, dt: number): number
	local step = 1 / self.physics.TickRate
	self.accumulator = math.min(self.accumulator + dt, step * 8)
	local steps = 0
	while self.accumulator >= step do
		self.accumulator -= step
		self:Step(step)
		steps += 1
		if self:GetResult().state ~= "ongoing" then
			self.accumulator = 0
			break
		end
	end
	return steps
end

function World.GetResult(self: World): Result
	if self.launchTime == nil then
		return { state = "ongoing" }
	end
	local teamsAlive: { [number]: boolean } = {}
	local aliveCount = 0
	for _, ball in self.balls do
		if ball.alive and not teamsAlive[ball.team] then
			teamsAlive[ball.team] = true
			aliveCount += 1
		end
	end
	if aliveCount == 0 then
		return { state = "draw" }
	elseif aliveCount == 1 then
		local team = next(teamsAlive)
		return { state = "win", team = team :: number }
	end
	if self:BattleTime() >= self.physics.RoundHardCap then
		-- hard cap: highest remaining HP fraction wins
		local hp: { [number]: number } = {}
		local maxHp: { [number]: number } = {}
		for _, ball in self.balls do
			if not ball.isMinion then
				maxHp[ball.team] = (maxHp[ball.team] or 0) + ball.maxHp
			end
			if ball.alive then
				hp[ball.team] = (hp[ball.team] or 0) + ball.hp
			end
		end
		local bestTeam, bestFrac, tie = nil, -1, false
		for team, total in maxHp do
			local frac = (hp[team] or 0) / math.max(total, 1)
			if frac > bestFrac + 1e-6 then
				bestTeam, bestFrac, tie = team, frac, false
			elseif math.abs(frac - bestFrac) <= 1e-6 then
				tie = true
			end
		end
		if tie or bestTeam == nil then
			return { state = "draw" }
		end
		return { state = "win", team = bestTeam }
	end
	return { state = "ongoing" }
end

function World.Finish(self: World)
	self.finished = true
end

function World.DrainEvents(self: World): { BattleEvent }
	local events = self.events
	self.events = {}
	return events
end

---------------------------------------------------------------------------------------------
-- Replication helpers

local Flags = SnapshotCodec.Flags

function World.BallFlags(ball: Ball): number
	local st = ball.status
	local f = 0
	if st.frozen > 0 then
		f += Flags.Frozen
	end
	if st.snared > 0 then
		f += Flags.Snared
	end
	if st.phased > 0 then
		f += Flags.Phased
	end
	if st.slowed > 0 then
		f += Flags.Slowed
	end
	if st.charging > 0 then
		f += Flags.Charging
	end
	if st.latched > 0 then
		f += Flags.Latched
	end
	if st.invuln > 0 then
		f += Flags.Invulnerable
	end
	if not ball.alive then
		f += Flags.Dead
	end
	return f
end

function World.Snapshot(self: World, station: number, seq: number): SnapshotCodec.Snapshot
	local balls = {}
	for _, ball in self.balls do
		if ball.alive then
			table.insert(balls, {
				id = ball.id,
				x = ball.x,
				y = ball.y,
				hp = ball.hp,
				r = ball.r,
				flags = World.BallFlags(ball),
			})
		end
	end
	local entities = {}
	local limit = self.physics.MaxSnapshotEntities
	for _, e in self.entities do
		if e.dynamic and not e.removed then
			table.insert(entities, { id = e.id, x = e.x, y = e.y, rot = e.rot, scale = e.scale })
			if #entities >= limit then
				break
			end
		end
	end
	return { station = station, seq = seq, time = self.time, balls = balls, entities = entities }
end

-- Full state for spectators who arrive mid-round.
function World.FullState(self: World): { [string]: any }
	local balls = {}
	for _, ball in self.balls do
		if ball.alive then
			table.insert(balls, {
				id = ball.id,
				def = ball.defId,
				team = ball.team,
				owner = ball.owner,
				x = ball.x,
				y = ball.y,
				r = ball.r,
				hp = ball.hp,
				maxHp = ball.maxHp,
				minion = ball.isMinion,
				launched = ball.launched,
			})
		end
	end
	local entities = {}
	for _, e in self.entities do
		if not e.removed then
			table.insert(entities, {
				id = e.id,
				kind = e.kind,
				shape = e.shape,
				x = e.x,
				y = e.y,
				x2 = e.x2,
				y2 = e.y2,
				r = e.r,
				rot = e.rot,
				scale = e.scale,
				team = e.team,
				owner = if e.owner then e.owner.id else nil,
				life = if e.life == math.huge then -1 else e.life,
				armed = e.armed,
				dynamic = e.dynamic,
				visual = e.visual,
			})
		end
	end
	return { time = self.time, balls = balls, entities = entities }
end

return World
