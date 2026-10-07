--!strict
-- The single damage pipeline. Every point of damage in a battle goes through Damage.Apply so
-- modifiers, immunity, ability hooks, events and deaths behave the same everywhere.
local Types = require(script.Parent.Types)

type Ball = Types.Ball
type DamageInfo = Types.DamageInfo

local Damage = {}

function Damage.Apply(world: any, target: Ball, amount: number, info: DamageInfo): number
	if not target.alive or amount <= 0 or amount ~= amount then
		return 0
	end
	local st = target.status
	if st.phased > 0 and not info.ignorePhase then
		return 0
	end
	if st.invuln > 0 and info.kind ~= "overtime" then
		return 0
	end
	local source = info.source
	if source ~= nil and source ~= target and source.team == target.team and not world.friendlyFire then
		return 0
	end

	if info.kind ~= "overtime" then
		amount *= world.damageMult
		if source ~= nil then
			amount *= source.dmgDealtMult
		end
	end
	amount *= target.dmgTakenMult
	if st.frozen > 0 then
		amount *= 1 + target.frozenVuln
	end

	local ok, modified = world:_call(target, "OnDamageTaken", amount, info)
	if ok and type(modified) == "number" then
		amount = modified
	end
	if amount <= 0 then
		return 0
	end

	local old = target.hp
	target.hp = math.max(0, old - amount)
	local dealt = old - target.hp
	if source ~= nil then
		source.damageDealt += dealt
		target.lastAttacker = source.id
	end

	world:Emit({
		t = "Damage",
		id = target.id,
		amount = dealt,
		kind = info.kind,
		src = if source then source.id else nil,
		x = info.x,
		y = info.y,
	})

	if source ~= nil and source.alive then
		world:_call(source, "OnDamageDealt", target, dealt, info)
	end
	world:_call(target, "OnHealthChanged", old, target.hp)

	if target.hp <= 0 then
		world:Kill(target, source)
	end
	return dealt
end

return Damage
