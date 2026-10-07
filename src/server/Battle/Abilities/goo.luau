--!strict
-- Goo Orb: wall bounces leave goo puddles that slow and damage enemies inside them.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, nx: number, ny: number, px: number, py: number)
	U.MakeRoom(ctx, ball, "goo", p.MaxPuddles)
	local x, y = U.ClampInside(ctx, px + nx * p.Radius * 0.55, py + ny * p.Radius * 0.55, p.Radius * 0.55)
	ctx:Spawn({
		kind = "goo",
		shape = "circle",
		owner = ball,
		x = x,
		y = y,
		r = p.Radius,
		rot = math.atan2(ny, nx),
		life = p.Life,
		armed = 0.1,
		pierce = true,
		hitCooldown = p.TickEvery,
		onHit = function(c: any, e: Entity, victim: Ball)
			c:SetStatus(victim, "slowed", p.SlowTime, { factor = 1 - p.Slow })
			c:Damage(victim, p.Damage, { source = e.owner, kind = "hazard", entity = e, x = victim.x, y = victim.y })
		end,
		visual = { color = ball.def.Visual.Base, accent = ball.def.Visual.Accent },
	})
	ctx:Fx("splat", { id = ball.id, x = px, y = py })
end

return Ability
