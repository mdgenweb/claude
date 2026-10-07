--!strict
-- Lucky Orb: every bump rolls a die. Damage = roll; a six bursts into a jackpot of shards.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.ModifyContact = function(ctx: any, ball: Ball, p: Params, _other: Ball, _damage: number): number
	local roll = ctx:Random():Int(1, 6)
	ctx:Fx("dice", { id = ball.id, roll = roll })
	if roll == 6 then
		local base = ctx:Random():Range(0, 2 * math.pi)
		for i = 1, p.JackpotShards do
			local a = base + (i - 1) * (2 * math.pi / p.JackpotShards)
			ctx:Spawn({
				kind = "chip",
				shape = "circle",
				owner = ball,
				x = ball.x + math.cos(a) * ball.r,
				y = ball.y + math.sin(a) * ball.r,
				r = 0.32,
				vx = math.cos(a) * p.ShardSpeed,
				vy = math.sin(a) * p.ShardSpeed,
				dynamic = true,
				dieOnWall = true,
				life = 1,
				damage = p.ShardDamage,
				damageKind = "ability",
				visual = { color = "#FFD23F" },
			})
		end
	end
	return roll * p.DamagePerPip
end

return Ability
