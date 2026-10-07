--!strict
-- Boomerang Orb: throws a boomerang at the nearest enemy; it flies out, turns, and homes back.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

local function update(ctx: any, e: Entity, dt: number)
	local owner = e.owner
	if owner == nil or not owner.alive then
		ctx:Remove(e, "owner")
		return
	end
	local d = e.data
	local h = ctx:Half() - e.r
	e.rot += 16 * dt
	if d.phase == "out" then
		e.x += e.vx * dt
		e.y += e.vy * dt
		d.travelled += d.speed * dt
		if d.travelled >= d.range or math.abs(e.x) >= h or math.abs(e.y) >= h then
			d.phase = "back"
			e.hits = {} -- allow a second hit on the way back
		end
		e.x, e.y = math.clamp(e.x, -h, h), math.clamp(e.y, -h, h)
	else
		local nx, ny, dist = U.Normalize(owner.x - e.x, owner.y - e.y)
		local speed = d.speed * 1.15
		e.vx, e.vy = nx * speed, ny * speed
		e.x += e.vx * dt
		e.y += e.vy * dt
		if dist < owner.r + 0.4 or e.age > 4 then
			ctx:Remove(e, "caught")
		end
	end
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if not U.Every(ball.state, "throw", dt, p.Interval, 1.0) then
		return
	end
	if #ctx:EntitiesOf(ball, "boomerang") > 0 then
		return
	end
	local target = ctx:Nearest(ball)
	if target == nil then
		return
	end
	local nx, ny = U.Normalize(target.x - ball.x, target.y - ball.y)
	ctx:Spawn({
		kind = "boomerang",
		shape = "circle",
		owner = ball,
		x = ball.x + nx * ball.r,
		y = ball.y + ny * ball.r,
		r = p.Radius,
		vx = nx * p.Speed,
		vy = ny * p.Speed,
		dynamic = true,
		pierce = true,
		damage = p.Damage,
		damageKind = "ability",
		hitCooldown = 0.6,
		data = { phase = "out", travelled = 0, range = p.Range, speed = p.Speed },
		onUpdate = update,
		visual = { color = ball.def.Visual.Accent },
	})
	ctx:Fx("throw", { id = ball.id })
end

return Ability
