--!strict
-- Deterministic PRNG (xorshift32 with a splitmix-style seed scramble).
-- Pure Luau: identical results on server, client and the headless test runner.
local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { _state: number }, Rng))

local function scramble(seed: number): number
	local x = bit32.bxor(math.floor(seed) % 4294967296, 0x9E3779B9)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = (x * 0x45D9F3B) % 4294967296
	x = bit32.bxor(x, bit32.rshift(x, 16))
	if x == 0 then
		x = 0x6D2B79F5
	end
	return x
end

function Rng.new(seed: number): Rng
	return setmetatable({ _state = scramble(seed) }, Rng)
end

function Rng.NextUInt(self: Rng): number
	local x = self._state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._state = x
	return x
end

-- Uniform float in [0, 1)
function Rng.Next(self: Rng): number
	return self:NextUInt() / 4294967296
end

function Rng.Range(self: Rng, min: number, max: number): number
	return min + (max - min) * self:Next()
end

-- Uniform integer in [min, max]
function Rng.Int(self: Rng, min: number, max: number): number
	return min + math.floor(self:Next() * (max - min + 1))
end

function Rng.Chance(self: Rng, p: number): boolean
	return self:Next() < p
end

function Rng.Pick<T>(self: Rng, list: { T }): T
	return list[self:Int(1, #list)]
end

-- Weighted pick over { {value, weight} } style list via accessor.
function Rng.Weighted<T>(self: Rng, items: { T }, weightOf: (T) -> number): T?
	local total = 0
	for _, item in items do
		total += math.max(0, weightOf(item))
	end
	if total <= 0 then
		return nil
	end
	local roll = self:Next() * total
	for _, item in items do
		roll -= math.max(0, weightOf(item))
		if roll < 0 then
			return item
		end
	end
	return items[#items]
end

function Rng.Shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:Int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
