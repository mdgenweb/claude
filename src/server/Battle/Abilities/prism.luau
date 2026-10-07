--!strict
-- Prism Orb: a wall bounce projects a beam straight across the arena from the impact point.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, nx: number, ny: number, px: number, py: number)
	local now = ctx:Now()
	if ball.state.readyAt and now < ball.state.readyAt then
		return
	end
	ball.state.readyAt = now + p.Cooldown
	U.MakeRoom(ctx, ball, "beam", p.MaxBeams)
	local h = ctx:Half()
	local x2, y2 = px + nx * 2 * h, py + ny * 2 * h
	ctx:Spawn({
		kind = "beam",
		shape = "segment",
		owner = ball,
		x = px,
		y = py,
		x2 = math.clamp(x2, -h, h),
		y2 = math.clamp(y2, -h, h),
		r = p.Width,
		rot = math.atan2(ny, nx),
		life = p.ChargeTime + p.Life,
		armed = p.ChargeTime,
		damage = p.Damage,
		damageKind = "ability",
		hitCooldown = p.HitCooldown,
		pierce = true,
		visual = { color = ball.def.Visual.Accent, charge = p.ChargeTime },
	})
	ctx:Fx("beamCharge", { id = ball.id, x = px, y = py })
end

return Ability
