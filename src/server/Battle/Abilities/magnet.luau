--!strict
-- Magnet Orb: periodically yanks enemies toward itself; the next bump after a pull hits harder.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if not U.Every(ball.state, "pulse", dt, p.Interval, 2) then
		return
	end
	for _, other in ctx:Enemies(ball) do
		if other.launched and other.status.phased <= 0 then
			local tx, ty = U.Normalize(ball.x - other.x, ball.y - other.y)
			local speed = math.max(U.Speed(other), 10)
			local cx, cy = U.Normalize(other.vx, other.vy)
			local bx, by = U.Normalize(cx + (tx - cx) * p.PullBlend * 1.0, cy + (ty - cy) * p.PullBlend)
			ctx:SetVelocity(other, bx * speed, by * speed)
		end
	end
	ball.state.bonusUntil = ctx:Now() + p.BonusWindow
	ctx:Fx("magnet", { id = ball.id, x = ball.x, y = ball.y })
end

Ability.ModifyContact = function(ctx: any, ball: Ball, p: Params, _other: Ball, damage: number): number
	if ball.state.bonusUntil and ctx:Now() <= ball.state.bonusUntil then
		ball.state.bonusUntil = nil
		return damage + p.BonusDamage
	end
	return damage
end

return Ability
