--[[
	Minimal Roblox API shims so pure shared modules run under the stock `luau` CLI.
	Only what shared logic touches: Vector3, Color3, ColorSequence(+Keypoint), Random, Enum, instance-tree require.
]]

-- Vector3 -------------------------------------------------------------------------------------
local Vector3Meta = {}
Vector3Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end
	return Vector3Meta[key]
end
function Vector3Meta.Lerp(a, b, t)
	return Vector3.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function Vector3Meta.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
Vector3Meta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end
Vector3Meta.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
Vector3Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3Meta.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)

-- Color3 / ColorSequence ----------------------------------------------------------------------
Color3 = {
	new = function(r, g, b)
		return { R = r or 0, G = g or 0, B = b or 0, __type = "Color3" }
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
Color3.fromHSV = function(h, s, v)
	return Color3.new(h, s, v)
end
ColorSequenceKeypoint = {
	new = function(t, color)
		return { Time = t, Value = color }
	end,
}
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and a[1] then
			return { Keypoints = a }
		end
		return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }
	end,
}

-- Random (xorshift; deterministic per seed, API-compatible subset) ---------------------------
local RandomMeta = {}
RandomMeta.__index = RandomMeta
function RandomMeta:_next()
	local x = self._state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._state = x
	return x
end
function RandomMeta:NextNumber(min, max)
	local value = self:_next() / 4294967296
	if min then
		return min + (max - min) * value
	end
	return value
end
function RandomMeta:NextInteger(min, max)
	return min + math.floor(self:NextNumber() * (max - min + 1))
end
Random = {
	new = function(seed)
		seed = math.floor(math.abs(seed or os.time())) % 4294967295
		if seed == 0 then
			seed = 2463534242
		end
		local rng = setmetatable({ _state = seed }, RandomMeta)
		for _ = 1, 8 do
			rng:_next()
		end
		return rng
	end,
}

-- Enum ----------------------------------------------------------------------------------------
local function enumProxy(path)
	return setmetatable({}, {
		__index = function(_, key)
			return enumProxy(path .. "." .. key)
		end,
		__tostring = function()
			return path
		end,
	})
end
Enum = enumProxy("Enum")

-- Instance tree + require ---------------------------------------------------------------------
local Node = {}
Node.__index = function(self, key)
	local child = rawget(self, "_children")[key]
	if child then
		return child
	end
	if key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "Name" then
		return rawget(self, "_name")
	end
	error(string.format("%s is not a valid member of %s", tostring(key), rawget(self, "_name")), 2)
end

local function newNode(name, parent)
	local node = setmetatable({ _name = name, _parent = parent, _children = {} }, Node)
	if parent then
		rawget(parent, "_children")[name] = node
	end
	return node
end

local ROOT = newNode("ReplicatedStorage", nil)
local moduleFns = {}
local moduleCache = {}

local function shimRequire(node)
	local cached = moduleCache[node]
	if cached ~= nil then
		return cached
	end
	local fn = moduleFns[node]
	if not fn then
		error("require: no module at " .. tostring(rawget(node, "_name")), 2)
	end
	local result = fn(node, shimRequire)
	moduleCache[node] = result
	return result
end

function __registerModule(path, fn)
	local node = ROOT
	for segment in string.gmatch(path, "[^/]+") do
		node = rawget(node, "_children")[segment] or newNode(segment, node)
	end
	moduleFns[node] = fn
end

function __sharedRoot()
	return rawget(ROOT, "_children").Shared
end

__shimRequire = shimRequire
