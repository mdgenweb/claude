--!strict
-- Satellite Orb: moons orbit the orb and hit anything they touch; one more joins on a timer.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

local function orbit(ctx: any, e: Entity, _dt: number)
	local owner = e.owner
	if owner == nil or not owner.alive then
		ctx:Remove(e, "owner")
		return
	end
	local s = owner.state
	local count = math.max(1, s.moonCount)
	local angle = ctx:Now() * e.data.angularSpeed + (e.data.index - 1) * (2 * math.pi / count)
	local radius = owner.r + e.data.gap
	e.x = owner.x + math.cos(angle) * radius
	e.y = owner.y + math.sin(angle) * radius
	e.rot = angle
end

local function addMoon(ctx: any, ball: Ball, p: Params)
	ball.state.moonCount += 1
	ctx:Spawn({
		kind = "moon",
		shape = "circle",
		owner = ball,
		x = ball.x,
		y = ball.y,
		r = p.MoonRadius,
		dynamic = true,
		pierce = true,
		damage = p.Damage,
		damageKind = "ability",
		hitCooldown = p.HitCooldown,
		data = { index = ball.state.moonCount, angularSpeed = p.AngularSpeed, gap = p.OrbitRadius - 1.5 },
		onUpdate = orbit,
		visual = { color = ball.def.Visual.Accent },
	})
end

Ability.Init = function(ctx: any, ball: Ball, p: Params)
	ball.state.moonCount = 0
	for _ = 1, p.StartMoons do
		addMoon(ctx, ball, p)
	end
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if ball.state.moonCount < p.MaxMoons and U.Every(ball.state, "add", dt, p.AddEvery) then
		addMoon(ctx, ball, p)
		ctx:Fx("moonAdded", { id = ball.id, count = ball.state.moonCount })
	end
end

return Ability
