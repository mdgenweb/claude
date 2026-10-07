--!strict
-- Forge Orb: every Nth enemy hit is a SMASH (multiplied damage + shockwave around it).
local Battle = script.Parent.Parent
local Types = require(Battle.Types)
local U = require(Battle.AbilityUtil)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.hits = 0
end

Ability.ModifyContact = function(ctx: any, ball: Ball, p: Params, other: Ball, damage: number): number
	if other.team == ball.team then
		return damage
	end
	ball.state.hits += 1
	local charge = ball.state.hits % p.HitsPerSmash
	ctx:Fx("forgeCharge", { id = ball.id, charge = charge, max = p.HitsPerSmash })
	if charge ~= 0 then
		return damage
	end
	U.Blast(ctx, ball, ball.x, ball.y, p.WaveRadius, p.WaveDamage, "ability", other)
	ctx:Fx("shockwave", { id = ball.id, x = ball.x, y = ball.y, r = p.WaveRadius, color = "#FFB000" })
	return damage * p.SmashMultiplier
end

return Ability
