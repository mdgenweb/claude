--!strict
-- Serpent Orb: leaves a venomous tail (its recent path). Enemies crossing the tail take damage.
-- Clients draw the tail from the interpolated path, so no entities are replicated for it.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local World = require(Battle.World)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.trail = {}
	ball.state.sample = 0
	ball.state.hitAt = {}
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	local s = ball.state
	local now = ctx:Now()
	s.sample -= dt
	if s.sample <= 0 then
		s.sample = p.SampleEvery
		table.insert(s.trail, { x = ball.x, y = ball.y, t = now })
	end
	while #s.trail > 0 and now - s.trail[1].t > p.TrailTime do
		table.remove(s.trail, 1)
	end
	local trail = s.trail
	-- skip the newest samples: those overlap the head itself
	local last = #trail - 3
	if last < 2 then
		return
	end
	for _, other in ctx:Enemies(ball) do
		if other.launched and other.status.phased <= 0 then
			local readyAt = s.hitAt[other.id]
			if readyAt == nil or now >= readyAt then
				for i = 1, last - 1 do
					local a, b = trail[i], trail[i + 1]
					if World.PointSegmentDistance(other.x, other.y, a.x, a.y, b.x, b.y) < p.Width + other.r then
						s.hitAt[other.id] = now + p.HitCooldown
						ctx:Damage(other, p.Damage, { source = ball, kind = "hazard", x = other.x, y = other.y })
						break
					end
				end
			end
		end
	end
end

return Ability
