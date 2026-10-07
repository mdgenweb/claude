--!strict
-- Small helpers shared by ability modules (kept out of Abilities/ so the registry only sees abilities).
local Types = require(script.Parent.Types)

type Ball = Types.Ball

local AbilityUtil = {}

function AbilityUtil.Normalize(dx: number, dy: number): (number, number, number)
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-6 then
		return 1, 0, 0
	end
	return dx / len, dy / len, len
end

-- Counts state[key] down by dt; returns true (and resets to interval) when it elapses.
function AbilityUtil.Every(state: { [string]: any }, key: string, dt: number, interval: number, initial: number?): boolean
	local remaining = state[key]
	if remaining == nil then
		remaining = initial or interval
	end
	remaining -= dt
	if remaining <= 0 then
		state[key] = remaining + interval
		return true
	end
	state[key] = remaining
	return false
end

function AbilityUtil.ClampInside(ctx: any, x: number, y: number, margin: number): (number, number)
	local h = ctx:Half() - margin
	return math.clamp(x, -h, h), math.clamp(y, -h, h)
end

-- Removes the oldest entities of `kind` owned by `ball` so at most `max - 1` remain.
function AbilityUtil.MakeRoom(ctx: any, ball: Ball, kind: string, max: number)
	local list = ctx:EntitiesOf(ball, kind)
	table.sort(list, function(a, b)
		return a.age > b.age
	end)
	local excess = #list - (max - 1)
	for i = 1, excess do
		ctx:Remove(list[i], "replaced")
	end
end

-- Damages every enemy of `ball` within `radius` of (x, y). Returns number of victims.
function AbilityUtil.Blast(ctx: any, ball: Ball, x: number, y: number, radius: number, damage: number, kind: string?, except: Ball?): number
	local victims = 0
	for _, other in ctx:Enemies(ball) do
		if other ~= except and other.launched then
			local reach = radius + other.r
			if (other.x - x) ^ 2 + (other.y - y) ^ 2 < reach * reach then
				ctx:Damage(other, damage, { source = ball, kind = kind or "ability", x = other.x, y = other.y })
				victims += 1
			end
		end
	end
	return victims
end

function AbilityUtil.Speed(ball: Ball): number
	return math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
end

return AbilityUtil
