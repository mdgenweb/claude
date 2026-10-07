--!strict
-- Sunny Orb: passive regeneration plus a once-per-round sunburst at low HP (OnHPThreshold).
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.regen = 0
	ball.state.burstUsed = false
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if ball.hp >= ball.maxHp then
		ball.state.regen = 0
		return
	end
	ball.state.regen += p.RegenPerSecond * dt
	if ball.state.regen >= 1 then
		local chunk = math.floor(ball.state.regen)
		ball.state.regen -= chunk
		ctx:Heal(ball, chunk)
	end
end

Ability.OnHealthChanged = function(ctx: any, ball: Ball, p: Params, _old: number, new: number)
	if ball.state.burstUsed or new <= 0 or new > ball.maxHp * p.Threshold then
		return
	end
	ball.state.burstUsed = true
	ctx:Heal(ball, p.BurstHeal)
	for _, other in ctx:Enemies(ball) do
		local nx, ny, dist = U.Normalize(other.x - ball.x, other.y - ball.y)
		if dist < p.BurstRadius + other.r then
			ctx:SetVelocity(other, nx * p.BurstPush, ny * p.BurstPush)
		end
	end
	ctx:Fx("sunburst", { id = ball.id, x = ball.x, y = ball.y, r = p.BurstRadius })
end

return Ability
