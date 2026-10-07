--!strict
-- Ghost Orb: periodically phases out (untouchable + faster). Passing through enemies while
-- ethereal chills them; rematerialising near an enemy spooks it.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	local s = ball.state
	if s.phasing then
		if ball.status.phased <= 0 then
			s.phasing = false
			ball.speedMult = 1
			local spooked = false
			for _, other in ctx:Enemies(ball) do
				local reach = ball.r + other.r + p.SpookRadius
				if (other.x - ball.x) ^ 2 + (other.y - ball.y) ^ 2 < reach * reach then
					ctx:Damage(other, p.SpookDamage, { source = ball, kind = "ability", ignorePhase = true, x = other.x, y = other.y })
					spooked = true
				end
			end
			ctx:Fx("unphase", { id = ball.id, x = ball.x, y = ball.y, spook = spooked })
			return
		end
		-- haunting: passing through an enemy while ethereal chills it
		s.passedAt = s.passedAt or {}
		local now = ctx:Now()
		for _, other in ctx:Enemies(ball) do
			local reach = ball.r + other.r
			local ready = s.passedAt[other.id] == nil or now >= s.passedAt[other.id]
			if ready and (other.x - ball.x) ^ 2 + (other.y - ball.y) ^ 2 < reach * reach then
				s.passedAt[other.id] = now + p.PassCooldown
				ctx:Damage(other, p.PassDamage, { source = ball, kind = "ability", x = other.x, y = other.y })
				ctx:Fx("haunt", { id = other.id, x = other.x, y = other.y })
			end
		end
		return
	end
	if U.Every(s, "phase", dt, p.Interval, 2.5) then
		s.phasing = true
		ball.speedMult = 1 + p.SpeedBoost
		ctx:SetStatus(ball, "phased", p.Duration)
		ctx:Fx("phase", { id = ball.id, duration = p.Duration })
	end
end

return Ability
