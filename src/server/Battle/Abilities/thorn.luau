--!strict
-- Thorn Orb: every wall bounce grows a thorn sticking out of that wall.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnWallHit = function(ctx: any, ball: Ball, p: Params, nx: number, ny: number, px: number, py: number)
	U.MakeRoom(ctx, ball, "thorn", p.MaxThorns)
	-- slide the base along the wall slightly so thorns never sit exactly on the corner
	local h = ctx:Half() - p.Width * 0.5
	local bx = if nx ~= 0 then px else math.clamp(px, -h, h)
	local by = if ny ~= 0 then py else math.clamp(py, -h, h)
	ctx:Spawn({
		kind = "thorn",
		shape = "segment",
		owner = ball,
		x = bx,
		y = by,
		x2 = bx + nx * p.Length,
		y2 = by + ny * p.Length,
		r = p.Width * 0.3,
		rot = math.atan2(ny, nx),
		life = p.Life,
		armed = 0.15,
		damage = p.Damage,
		hitCooldown = p.HitCooldown,
		pierce = true,
		visual = { length = p.Length, width = p.Width, color = ball.def.Visual.Base },
	})
end

return Ability
