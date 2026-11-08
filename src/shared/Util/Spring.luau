--!nonstrict
-- Critically-damped-capable spring for smooth UI/camera motion. Works with numbers,
-- Vector2 and Vector3 (anything supporting + - * by number).

local Spring = {}
Spring.__index = Spring

export type Spring<T> = {
	Position: T,
	Velocity: T,
	Target: T,
	Speed: number,
	Damping: number,
	Step: (self: Spring<T>, dt: number) -> T,
	Snap: (self: Spring<T>, value: T) -> (),
	Impulse: (self: Spring<T>, velocity: T) -> (),
}

function Spring.new<T>(initial: T, speed: number?, damping: number?): Spring<T>
	local zero = (initial :: any) * 0
	local self = setmetatable({
		Position = initial,
		Velocity = zero,
		Target = initial,
		Speed = speed or 12,
		Damping = damping or 1,
	}, Spring)
	return (self :: any) :: Spring<T>
end

-- Semi-implicit Euler with sub-stepping keeps it stable for large dt (frame hitches).
function Spring:Step(dt: number)
	local steps = math.clamp(math.ceil(dt / (1 / 120)), 1, 8)
	local h = dt / steps
	local w = self.Speed
	local zeta = self.Damping
	for _ = 1, steps do
		local displacement = self.Position - self.Target
		local acceleration = displacement * (-w * w) - self.Velocity * (2 * zeta * w)
		self.Velocity += acceleration * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

function Spring:Snap(value)
	self.Position = value
	self.Target = value
	self.Velocity = (value :: any) * 0
end

function Spring:Impulse(velocity)
	self.Velocity += velocity
end

return Spring
