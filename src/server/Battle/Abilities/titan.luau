--!strict
-- Titan Orb: big, heavy, takes reduced contact damage (OnDamageTaken modifier).
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.OnDamageTaken = function(_ctx: any, _ball: Ball, p: Params, amount: number, info: Types.DamageInfo): number
	if info.kind == "contact" then
		return amount * (1 - p.ContactReduction)
	end
	return amount
end

return Ability
