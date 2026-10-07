--!strict
-- Storm Orb: lightning strikes the nearest enemy on a timer (cannot miss). Below the HP
-- threshold it strikes faster and chains to a second enemy.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.timer = 1.2
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	local enraged = ball.hp <= ball.maxHp * p.Threshold
	if enraged and not ball.state.enraged then
		ball.state.enraged = true
		ctx:Fx("enrage", { id = ball.id })
	end
	ball.state.timer -= dt
	if ball.state.timer > 0 then
		return
	end
	ball.state.timer = if enraged then p.EnragedInterval else p.Interval
	local first = ctx:Nearest(ball)
	if first == nil then
		return
	end
	ctx:Damage(first, p.Damage, { source = ball, kind = "ability", x = first.x, y = first.y })
	ctx:Fx("lightning", { from = ball.id, to = first.id, x = first.x, y = first.y })
	if enraged then
		local second: Ball? = nil
		local bestDist = math.huge
		for _, other in ctx:Enemies(ball) do
			if other ~= first and other.status.phased <= 0 then
				local d = (other.x - first.x) ^ 2 + (other.y - first.y) ^ 2
				if d < bestDist then
					bestDist = d
					second = other
				end
			end
		end
		if second then
			ctx:Damage(second, p.ChainDamage, { source = ball, kind = "ability", x = second.x, y = second.y })
			ctx:Fx("lightning", { from = first.id, to = second.id, x = second.x, y = second.y, chain = true })
		end
	end
end

return Ability
