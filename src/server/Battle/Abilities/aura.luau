--!strict
-- Aura Orb: a harmful aura surrounds it and grows over the round.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(ctx: any, ball: Ball, p: Params)
	local base = ball.r + p.StartRadius
	ctx:Spawn({
		kind = "aura",
		shape = "circle",
		owner = ball,
		x = ball.x,
		y = ball.y,
		r = base,
		dynamic = true,
		pierce = true,
		damage = p.Damage,
		damageKind = "hazard",
		hitCooldown = p.TickEvery,
		data = { base = base },
		onUpdate = function(c: any, e: Entity, _dt: number)
			local owner = e.owner
			if owner == nil or not owner.alive then
				c:Remove(e, "owner")
				return
			end
			e.x, e.y = owner.x, owner.y
			local t = math.clamp(c:BattleTime() / p.GrowTime, 0, 1)
			local radius = owner.r + p.StartRadius + (p.EndRadius - p.StartRadius) * t
			e.scale = radius / e.data.base
			e.rot += 0.02
		end,
		visual = { color = ball.def.Visual.Base, rim = ball.def.Visual.Rim },
	})
end

return Ability
