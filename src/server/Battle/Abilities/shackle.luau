--!strict
-- Shackle Orb: scatters traps around the enemy. Anything caught is chained in place and hurt.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if not U.Every(ball.state, "drop", dt, p.Interval, 1.6) then
		return
	end
	local target = ctx:Nearest(ball)
	if target == nil then
		return
	end
	local rng = ctx:Random()
	for _ = 1, p.Traps do
		local a = rng:Range(0, 2 * math.pi)
		local dist = rng:Range(0.8, p.Spread)
		-- lead slightly along the target's travel direction
		local lx, ly = target.x + target.vx * 0.25, target.y + target.vy * 0.25
		local x, y = U.ClampInside(ctx, lx + math.cos(a) * dist, ly + math.sin(a) * dist, p.Radius)
		ctx:Spawn({
			kind = "shackle",
			shape = "circle",
			owner = ball,
			x = x,
			y = y,
			r = p.Radius,
			life = p.Life,
			armed = p.ArmTime,
			onHit = function(c: any, e: Entity, victim: Ball)
				c:SetStatus(victim, "snared", p.SnareTime)
				c:Damage(victim, p.Damage, { source = e.owner, kind = "ability", entity = e, x = victim.x, y = victim.y })
				c:Fx("chained", { id = victim.id, x = e.x, y = e.y, duration = p.SnareTime })
			end,
			visual = { color = ball.def.Visual.Accent, rim = ball.def.Visual.Rim, armTime = p.ArmTime },
		})
	end
	ctx:Fx("trapsDropped", { id = ball.id })
end

return Ability
