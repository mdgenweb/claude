--!strict
-- Rook Orb: pauses, lines up on the enemy's axis, then charges in a straight line.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.phase = "roam"
	ball.state.timer = 2.5
	ball.state.struck = {}
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	local s = ball.state
	s.timer -= dt
	if s.phase == "roam" then
		if s.timer <= 0 then
			local target = ctx:Nearest(ball)
			if target == nil then
				s.timer = 0.5
				return
			end
			s.phase = "windup"
			s.timer = p.Windup
			s.target = target
			ball.vx, ball.vy = 0, 0
			ball.status.charging = p.Windup + 0.05
			ctx:Fx("windup", { id = ball.id, duration = p.Windup })
		end
	elseif s.phase == "windup" then
		ball.vx, ball.vy = 0, 0
		if s.timer <= 0 then
			local target: Ball? = s.target
			local dx, dy = 1, 0
			if target and target.alive then
				local ox, oy = target.x - ball.x, target.y - ball.y
				if math.abs(ox) >= math.abs(oy) then
					dx, dy = if ox >= 0 then 1 else -1, 0
				else
					dx, dy = 0, if oy >= 0 then 1 else -1
				end
			end
			local speed = ctx.physics.CruiseSpeed * p.ChargeSpeed
			ball.vx, ball.vy = dx * speed, dy * speed
			ball.status.charging = p.ChargeTime
			s.phase = "charge"
			s.timer = p.ChargeTime
			s.struck = {}
			ctx:Fx("charge", { id = ball.id, dx = dx, dy = dy })
		end
	elseif s.phase == "charge" then
		if s.timer <= 0 or ball.status.charging <= 0 then
			s.phase = "roam"
			s.timer = p.Interval
			ball.status.charging = 0
		end
	end
end

Ability.ModifyContact = function(_ctx: any, ball: Ball, p: Params, other: Ball, damage: number): number
	local s = ball.state
	if s.phase == "charge" and other.team ~= ball.team and not s.struck[other.id] then
		s.struck[other.id] = true
		return damage + p.ChargeDamage
	end
	return damage
end

Ability.OnWallHit = function(_ctx: any, ball: Ball, _p: Params, _nx: number, _ny: number, _px: number, _py: number)
	-- a charge ends when it slams into a wall
	if ball.state.phase == "charge" then
		ball.status.charging = 0
	end
end

return Ability
