--!strict
-- Mitosis Orb: grows over time; on death it splits into mini orbs that keep the team alive (OnDeath).
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.growth = 0
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if ball.state.growth >= p.MaxGrowth then
		return
	end
	if U.Every(ball.state, "grow", dt, p.GrowEvery) then
		ball.state.growth = math.min(p.MaxGrowth, ball.state.growth + p.GrowAmount)
		local scale = 1 + ball.state.growth
		ball.r = ball.baseR * scale
		ball.mass = ball.def.Mass * scale * scale
		ball.contact = ball.def.ContactDamage * (1 + ball.state.growth * p.ContactPerGrowth)
		ctx:Fx("grow", { id = ball.id, r = ball.r })
	end
end

Ability.OnDeath = function(ctx: any, ball: Ball, p: Params, _killer: Ball?): boolean?
	local base = ctx:Random():Range(0, 2 * math.pi)
	local speed = ctx.physics.CruiseSpeed
	for i = 1, p.Minis do
		local a = base + (i - 1) * (2 * math.pi / p.Minis)
		ctx:SpawnMinion(
			ball,
			ball.x + math.cos(a) * ball.r * 0.6,
			ball.y + math.sin(a) * ball.r * 0.6,
			math.cos(a) * speed,
			math.sin(a) * speed,
			p.MiniRadius,
			p.MiniHP,
			p.MiniContact
		)
	end
	ctx:Fx("split", { id = ball.id, x = ball.x, y = ball.y })
	return false
end

return Ability
