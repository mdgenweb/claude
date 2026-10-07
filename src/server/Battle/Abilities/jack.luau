--!strict
-- Jack Orb (Harvest Moon event): lobs pumpkin bombs on an arc; they explode on impact and
-- leave a short-lived fire patch.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Entity = Types.Entity
type Params = { [string]: any }

local Ability: Types.Ability = {}

local LOB_GRAVITY = 20

local function explode(ctx: any, e: Entity, p: Params)
	local owner = e.owner
	if owner == nil then
		return
	end
	local x, y = U.ClampInside(ctx, e.x, e.y, p.FireRadius * 0.6)
	U.Blast(ctx, owner, x, y, p.BlastRadius, p.Damage, "ability")
	ctx:Fx("explosion", { x = x, y = y, r = p.BlastRadius, color = "#FF8C1A" })
	ctx:Spawn({
		kind = "fire",
		shape = "circle",
		owner = owner,
		x = x,
		y = y,
		r = p.FireRadius,
		life = p.FireLife,
		pierce = true,
		damage = p.FireDamage,
		hitCooldown = p.FireTick,
		visual = { color = "#FF8C1A" },
	})
end

Ability.OnTick = function(ctx: any, ball: Ball, p: Params, dt: number)
	if not U.Every(ball.state, "lob", dt, p.Interval, 1.5) then
		return
	end
	local target = ctx:Nearest(ball)
	if target == nil then
		return
	end
	local dx, dy = target.x - ball.x, target.y - ball.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local flight = math.clamp(dist / p.LobSpeed, 0.45, 1.1)
	local vx = dx / flight
	local vy = dy / flight + 0.5 * LOB_GRAVITY * flight
	ctx:Spawn({
		kind = "pumpkin",
		shape = "circle",
		owner = ball,
		x = ball.x,
		y = ball.y + ball.r * 0.5,
		r = 0.6,
		vx = vx,
		vy = vy,
		gravity = LOB_GRAVITY,
		dynamic = true,
		dieOnWall = true,
		life = 2.5,
		onHit = function(c: any, e: Entity, _victim: Ball)
			explode(c, e, p)
		end,
		onWall = function(c: any, e: Entity)
			explode(c, e, p)
		end,
		visual = { color = ball.def.Visual.Base },
	})
	ctx:Fx("lob", { id = ball.id })
end

return Ability
