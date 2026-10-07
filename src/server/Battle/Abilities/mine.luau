--!strict
-- Mine Orb: drops proximity mines on wall bounces; they explode when an enemy rolls close.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.readyAt = 0
end

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, nx: number, ny: number, px: number, py: number)
	if ctx:Now() < ball.state.readyAt then
		return
	end
	ball.state.readyAt = ctx:Now() + p.Cooldown
	U.MakeRoom(ctx, ball, "mine", p.MaxMines)
	local x, y = U.ClampInside(ctx, px + nx * 0.8, py + ny * 0.8, 0.8)
	ctx:Spawn({
		kind = "mine",
		shape = "none",
		owner = ball,
		x = x,
		y = y,
		r = 0.55,
		life = p.Life,
		armed = p.ArmTime,
		data = { trigger = p.Trigger },
		onUpdate = function(c: any, e: Entity, _dt: number)
			local owner = e.owner
			if e.armed > 0 or owner == nil then
				return
			end
			for _, other in c:Enemies(owner) do
				local reach = p.Trigger + other.r
				if other.launched and other.status.phased <= 0 and (other.x - e.x) ^ 2 + (other.y - e.y) ^ 2 < reach * reach then
					U.Blast(c, owner, e.x, e.y, p.BlastRadius, p.Damage, "ability")
					c:Fx("explosion", { x = e.x, y = e.y, r = p.BlastRadius, color = "#FF5E1A" })
					c:Remove(e, "detonated")
					return
				end
			end
		end,
		visual = { color = ball.def.Visual.Base, light = ball.def.Visual.Accent, armTime = p.ArmTime },
	})
end

return Ability
