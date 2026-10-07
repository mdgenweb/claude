--!strict
-- Frost Orb: contact freezes the enemy briefly (with frostbite damage); frozen orbs take extra damage.
local Battle = script.Parent.Parent
local Types = require(Battle.Types)

type Ball = Types.Ball
type Params = { [string]: any }

local Ability: Types.Ability = {}

Ability.Init = function(_ctx: any, ball: Ball, _p: Params)
	ball.state.cooldowns = {}
end

Ability.OnBallHit = function(ctx: any, ball: Ball, p: Params, other: Ball, cx: number, cy: number)
	if other.team == ball.team then
		return
	end
	local cooldowns = ball.state.cooldowns
	local now = ctx:Now()
	if cooldowns[other.id] and now < cooldowns[other.id] then
		return
	end
	cooldowns[other.id] = now + p.Cooldown
	other.frozenVuln = math.max(other.frozenVuln, p.FrozenVulnerability)
	ctx:SetStatus(other, "frozen", p.FreezeTime)
	ctx:Fx("freeze", { id = other.id, x = cx, y = cy, duration = p.FreezeTime })
	ctx:Damage(other, p.Frostbite, { source = ball, kind = "ability", x = other.x, y = other.y })
end

return Ability
