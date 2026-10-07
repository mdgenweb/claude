--!strict
-- Leech Orb: bumping an enemy latches on; drains HP over time and heals itself.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.readyAt = 0
end

Ability.OnBallHit = function(ctx: any, ball: Ball, p: Params, other: Ball, _cx: number, _cy: number)
	if other.team == ball.team or ctx:Now() < ball.state.readyAt then
		return
	end
	ball.state.readyAt = ctx:Now() + p.Cooldown
	ball.state.target = other
	ball.state.latchUntil = ctx:Now() + p.Duration
	ball.state.nextTick = ctx:Now() + p.TickEvery
	ctx:SetStatus(other, "latched", p.Duration)
	ctx:Fx("tether", { a = ball.id, b = other.id, duration = p.Duration })
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, _dt: number)
	local target: Ball? = ball.state.target
	if target == nil then
		return
	end
	local now = ctx:Now()
	if not target.alive or now > ball.state.latchUntil then
		ball.state.target = nil
		return
	end
	if now >= ball.state.nextTick then
		ball.state.nextTick += p.TickEvery
		local dealt = ctx:Damage(target, p.DrainPerTick, { source = ball, kind = "drain", x = target.x, y = target.y })
		if dealt > 0 then
			ctx:Heal(ball, dealt)
		end
	end
end

return Ability
