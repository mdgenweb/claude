--!strict
-- Crystal Orb: impacts (walls or orbs) may shatter shards outward.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

local function scatter(ctx: any, ball: Ball, p: Params, baseAngle: number, spread: number)
	local now = ctx:Now()
	if ball.state.readyAt and now < ball.state.readyAt then
		return
	end
	if not ctx:Random():Chance(p.Chance) then
		return
	end
	ball.state.readyAt = now + p.Cooldown
	for i = 1, p.Shards do
		local t = if p.Shards == 1 then 0.5 else (i - 1) / (p.Shards - 1)
		local a = baseAngle - spread / 2 + spread * t + ctx:Random():Range(-0.15, 0.15)
		ctx:Spawn({
			kind = "shard",
			shape = "circle",
			owner = ball,
			x = ball.x + math.cos(a) * ball.r,
			y = ball.y + math.sin(a) * ball.r,
			r = 0.3,
			vx = math.cos(a) * p.Speed,
			vy = math.sin(a) * p.Speed,
			dynamic = true,
			dieOnWall = true,
			life = p.Life,
			damage = p.Damage,
			damageKind = "ability",
			visual = { color = ball.def.Visual.Base },
		})
	end
	ctx:Fx("shatter", { id = ball.id, x = ball.x, y = ball.y })
end

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, nx: number, ny: number, _px: number, _py: number)
	scatter(ctx, ball, p, math.atan2(ny, nx), math.pi * 0.85)
end

Ability.OnBallHit = function(ctx: any, ball: Ball, p: Params, other: Ball, _cx: number, _cy: number)
	if other.team == ball.team then
		return
	end
	scatter(ctx, ball, p, math.atan2(ball.y - other.y, ball.x - other.x), math.pi * 1.6)
end

return Ability
