--!strict
-- Bumper Orb: plain contact fighter. Knocks enemies away harder on every bump.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnBallHit = function(ctx: any, ball: Ball, p: Params, other: Ball, cx: number, cy: number)
	if other.team == ball.team or other.status.frozen > 0 or other.status.snared > 0 then
		return
	end
	other.vx *= p.KnockbackBoost
	other.vy *= p.KnockbackBoost
	ctx:Fx("bump", { id = ball.id, x = cx, y = cy })
end

return Ability
