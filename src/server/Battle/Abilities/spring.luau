--!strict
-- Spring Orb: speeds up with every wall bounce; contact damage scales with the boost.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.boost = 0
end

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, _nx: number, _ny: number, px: number, py: number)
	local boost = math.min(p.MaxBoost, ball.state.boost + p.BoostPerBounce)
	if boost > ball.state.boost then
		ball.state.boost = boost
		ball.speedMult = 1 + boost
		ctx:Fx("boost", { id = ball.id, x = px, y = py, level = boost / p.MaxBoost })
	end
end

Ability.ModifyContact = function(_ctx: any, ball: Ball, p: Params, _other: Ball, damage: number): number
	return damage * (1 + ball.state.boost * p.DamagePerBoost)
end

return Ability
