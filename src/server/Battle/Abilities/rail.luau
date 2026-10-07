--!strict
-- Rail Orb: a wall bounce lays a rail straight across the arena through the impact point.
-- After a warning, a train sweeps along the rail and rams every enemy on it.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

local function trainUpdate(ctx: any, e: Entity, dt: number)
	local d = e.data
	local owner = e.owner
	d.progress += d.speed * dt
	local along = d.start + d.dir * d.progress
	if d.horizontal then
		e.x, e.y = along, d.line
	else
		e.x, e.y = d.line, along
	end
	if d.progress > d.travel then
		ctx:Remove(e, "done")
		if d.rail and not d.rail.removed then
			ctx:Remove(d.rail, "done")
		end
		return
	end
	if owner == nil then
		return
	end
	local halfL, halfW = d.length / 2, d.width / 2
	for _, other in ctx:Enemies(owner) do
		if other.launched and other.status.phased <= 0 and not e.hits[other.id] then
			local ax = if d.horizontal then math.abs(other.x - e.x) else math.abs(other.y - e.y)
			local ay = if d.horizontal then math.abs(other.y - e.y) else math.abs(other.x - e.x)
			if ax < halfL + other.r and ay < halfW + other.r then
				e.hits[other.id] = ctx:Now()
				ctx:Damage(other, d.damage, { source = owner, kind = "ability", entity = e, x = other.x, y = other.y })
				-- the train shoves the victim along its direction
				local push = d.speed * 0.6
				if d.horizontal then
					ctx:SetVelocity(other, d.dir * push, other.vy + (if other.y >= e.y then 6 else -6))
				else
					ctx:SetVelocity(other, other.vx + (if other.x >= e.x then 6 else -6), d.dir * push)
				end
				ctx:Fx("trainHit", { id = other.id, x = other.x, y = other.y })
			end
		end
	end
end

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.readyAt = 0
end

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, nx: number, ny: number, px: number, py: number)
	local now = ctx:Now()
	if now < ball.state.readyAt then
		return
	end
	ball.state.readyAt = now + p.Cooldown
	local h = ctx:Half()
	local horizontal = nx ~= 0 -- hit a side wall -> rail runs horizontally at that height
	local line = if horizontal then math.clamp(py, -h + 0.8, h - 0.8) else math.clamp(px, -h + 0.8, h - 0.8)
	-- the train enters from the wall that was hit and crosses the whole arena
	local dir = if horizontal then nx else ny
	local startEdge = -dir * (h + p.TrainLength / 2)
	local travel = 2 * h + p.TrainLength
	local rail = ctx:Spawn({
		kind = "rail",
		shape = "none",
		owner = ball,
		x = if horizontal then -h else line,
		y = if horizontal then line else -h,
		x2 = if horizontal then h else line,
		y2 = if horizontal then line else h,
		r = 0.25,
		rot = if horizontal then 0 else math.pi / 2,
		life = p.Warning + travel / p.TrainSpeed + 0.5,
		persist = false,
		visual = { warning = p.Warning, color = ball.def.Visual.Accent },
		onUpdate = function(c: any, e: Entity, _dt: number)
			if e.data.spawned or e.age < p.Warning then
				return
			end
			e.data.spawned = true
			c:Spawn({
				kind = "train",
				shape = "none",
				owner = e.owner,
				x = if horizontal then startEdge else line,
				y = if horizontal then line else startEdge,
				r = p.TrainWidth / 2,
				rot = if horizontal then (if dir > 0 then 0 else math.pi) else (if dir > 0 then math.pi / 2 else -math.pi / 2),
				dynamic = true,
				life = travel / p.TrainSpeed + 0.4,
				data = {
					horizontal = horizontal,
					line = line,
					start = startEdge,
					dir = dir,
					progress = 0,
					travel = travel,
					speed = p.TrainSpeed,
					length = p.TrainLength,
					width = p.TrainWidth,
					damage = p.Damage,
					rail = e,
				},
				onUpdate = trainUpdate,
				visual = { length = p.TrainLength, width = p.TrainWidth, color = ball.def.Visual.Base, accent = ball.def.Visual.Accent },
			})
			c:Fx("train", { id = e.owner and e.owner.id or 0 })
		end,
	})
	if rail then
		rail.data.spawned = false
		ctx:Fx("railLaid", { id = ball.id, x = px, y = py })
	end
end

return Ability
