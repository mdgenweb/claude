--!strict
-- Cannon Orb: fires a heavy cannonball at the enemy's predicted position, with recoil.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if not U.Every(ball.state, "fire", dt, p.Interval, 1.4) then
		return
	end
	local target = ctx:Nearest(ball)
	if target == nil then
		return
	end
	-- lead the target by the projectile travel time
	local _, _, dist = U.Normalize(target.x - ball.x, target.y - ball.y)
	local t = dist / p.Speed
	local px, py = U.ClampInside(ctx, target.x + target.vx * t, target.y + target.vy * t, target.r)
	local nx, ny = U.Normalize(px - ball.x, py - ball.y)
	ctx:Spawn({
		kind = "cannonball",
		shape = "circle",
		owner = ball,
		x = ball.x + nx * (ball.r + p.Radius),
		y = ball.y + ny * (ball.r + p.Radius),
		r = p.Radius,
		vx = nx * p.Speed,
		vy = ny * p.Speed,
		dynamic = true,
		dieOnWall = true,
		damage = p.Damage,
		damageKind = "ability",
		life = 2,
		visual = { color = "#1C1E22" },
	})
	ball.vx -= nx * p.Recoil
	ball.vy -= ny * p.Recoil
	ctx:Fx("muzzle", { id = ball.id, x = ball.x + nx * ball.r, y = ball.y + ny * ball.r, angle = math.atan2(ny, nx) })
end

return Ability
