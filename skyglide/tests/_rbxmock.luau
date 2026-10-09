-- Roblox API mock (math types + a generic Instance tree) for headless world/factory builds.
-- Used by specs that start with "--!prelude-before _rbxmock.luau" (see run_tests.py).

Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = ((seed or 12345) % 2147483646) + 1 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end

local function check(n, what)
	if type(n) ~= "number" or n ~= n then
		error("bad number for " .. what .. ": " .. tostring(n), 3)
	end
end

-- Vector3 ---------------------------------------------------------------------------------------
local V3 = {}
local V3mt = {}
V3mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return Vector3.new(0 / 0, 0 / 0, 0 / 0)
		end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	local f = V3[k]
	if f then
		return f
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3mt.__add = function(a, b)
	assert(getmetatable(a) == V3mt and getmetatable(b) == V3mt, "Vector3 + non-vector")
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3mt.__sub = function(a, b)
	assert(getmetatable(a) == V3mt and getmetatable(b) == V3mt, "Vector3 - non-vector")
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3mt.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3mt.__tostring = function(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end
V3mt.__type = "Vector3"
function V3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Min(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3.Max(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3.Abs(a)
	return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
Vector3 = {
	new = function(x, y, z)
		x, y, z = x or 0, y or 0, z or 0
		check(x, "Vector3.X")
		check(y, "Vector3.Y")
		check(z, "Vector3.Z")
		return setmetatable({ X = x, Y = y, Z = z }, V3mt)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

Vector2 = {
	new = function(x, y)
		return { X = x or 0, Y = y or 0 }
	end,
}

-- CFrame: position + rotation columns (X = right, Y = up, Z = back) ---------------------------
local CF = {}
local CFmt = {}
local function mk(p, x, y, z)
	return setmetatable({ p = p, x = x, y = y, z = z }, CFmt)
end
local function rot(c, v)
	return c.x * v.X + c.y * v.Y + c.z * v.Z
end
CFmt.__type = "CFrame"
CFmt.__index = function(c, k)
	if k == "Position" or k == "p" then
		return rawget(c, "p")
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "LookVector" then
		return -c.z
	elseif k == "RightVector" then
		return c.x
	elseif k == "UpVector" then
		return c.y
	elseif k == "Rotation" then
		return mk(Vector3.zero, c.x, c.y, c.z)
	end
	local f = CF[k]
	if f then
		return f
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CFmt.__mul = function(a, b)
	if getmetatable(b) == CFmt then
		return mk(a.p + rot(a, b.p), rot(a, b.x), rot(a, b.y), rot(a, b.z))
	elseif getmetatable(b) == V3mt then
		return a.p + rot(a, b)
	end
	error("bad CFrame multiply")
end
CFmt.__add = function(a, v)
	assert(getmetatable(v) == V3mt, "CFrame + non-vector")
	return mk(a.p + v, a.x, a.y, a.z)
end
CFmt.__sub = function(a, v)
	assert(getmetatable(v) == V3mt, "CFrame - non-vector")
	return mk(a.p - v, a.x, a.y, a.z)
end
function CF.Inverse(c)
	-- transpose
	local x = Vector3.new(c.x.X, c.y.X, c.z.X)
	local y = Vector3.new(c.x.Y, c.y.Y, c.z.Y)
	local z = Vector3.new(c.x.Z, c.y.Z, c.z.Z)
	local r = mk(Vector3.zero, x, y, z)
	return mk(-(r * c.p), x, y, z)
end
function CF.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CF.ToWorldSpace(a, b)
	return a * b
end
function CF.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CF.PointToWorldSpace(a, v)
	return a * v
end
function CF.VectorToWorldSpace(a, v)
	return rot(a, v)
end
function CF.Lerp(a, b, t)
	return mk(a.p:Lerp(b.p, t), a.x, a.y, a.z)
end
local function orthocheck(x, y, z, what)
	for _, v in { x, y, z } do
		local m = v.Magnitude
		if math.abs(m - 1) > 1e-3 then
			error("non-unit CFrame axis in " .. what .. ": " .. tostring(v), 3)
		end
	end
end
CFrame = {}
function CFrame.new(a, b, c)
	if a == nil then
		return mk(Vector3.zero, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
	end
	if type(a) == "number" then
		return mk(Vector3.new(a, b, c), Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
	end
	assert(getmetatable(a) == V3mt, "CFrame.new expects Vector3")
	if b ~= nil then
		return CFrame.lookAt(a, b)
	end
	return mk(a, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
CFrame.identity = CFrame.new()
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = (target - at)
	if look.Magnitude < 1e-9 then
		error("CFrame.lookAt with coincident points", 2)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		error("CFrame.lookAt with look parallel to up", 2)
	end
	right = right.Unit
	local up2 = right:Cross(look)
	return mk(at, right, up2, -look)
end
function CFrame.fromMatrix(p, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	orthocheck(vx, vy, vz, "fromMatrix")
	return mk(p, vx, vy, vz)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return mk(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, c, s), Vector3.new(0, -s, c))
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return mk(Vector3.zero, Vector3.new(c, 0, -s), Vector3.new(0, 1, 0), Vector3.new(s, 0, c))
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return mk(Vector3.zero, Vector3.new(c, s, 0), Vector3.new(-s, c, 0), Vector3.new(0, 0, 1))
end
function CFrame.Angles(a, b, c)
	check(a, "Angles")
	check(b, "Angles")
	check(c, "Angles")
	return rx(a) * ry(b) * rz(c)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromAxisAngle(axis, angle)
	-- Rodrigues
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local function col(i)
		local e = ({ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis })[i]
		return e * c + u:Cross(e) * s + u * (u:Dot(e) * t)
	end
	return mk(Vector3.zero, col(1), col(2), col(3))
end

-- Color3 ---------------------------------------------------------------------------------------
local C3mt = { __type = "Color3" }
local C3 = {}
C3mt.__index = C3
function C3.Lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3.ToHex(c)
	return string.format("%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end
Color3 = {}
function Color3.new(r, g, b)
	check(r or 0, "Color3")
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3mt)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHex(hex)
	assert(type(hex) == "string", "fromHex expects string")
	local h = string.gsub(hex, "^#", "")
	if #h ~= 6 or not string.match(h, "^%x+$") then
		error("Unable to convert characters to hex value", 2)
	end
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end
function Color3.fromHSV(h, s, v)
	return Color3.new(v, v, v)
end

local function tag(kind)
	return function(...)
		return { __kind = kind, ... }
	end
end
Font = { new = tag("Font"), fromEnum = tag("Font") }
UDim = { new = tag("UDim") }
UDim2 = { new = tag("UDim2"), fromScale = tag("UDim2"), fromOffset = tag("UDim2") }
ColorSequence = { new = tag("ColorSequence") }
ColorSequenceKeypoint = { new = tag("ColorSequenceKeypoint") }
NumberSequence = { new = tag("NumberSequence") }
NumberSequenceKeypoint = { new = tag("NumberSequenceKeypoint") }
NumberRange = { new = tag("NumberRange") }
Rect = { new = tag("Rect") }

Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return "Enum." .. enumName .. "." .. item
			end,
		})
	end,
})

-- Instances ------------------------------------------------------------------------------------
local CLASS_PARENTS = {
	Part = "BasePart",
	WedgePart = "BasePart",
	SpawnLocation = "Part",
	MeshPart = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	Frame = "GuiObject",
	ImageLabel = "GuiObject",
	GuiObject = "GuiBase2d",
	SurfaceGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	ParticleEmitter = "Instance",
	PointLight = "Light",
	SpotLight = "Light",
	Light = "Instance",
}
local function isA(className, query)
	if query == "Instance" then
		return true
	end
	local c = className
	while c do
		if c == query then
			return true
		end
		c = CLASS_PARENTS[c]
	end
	return false
end

INSTANCE_COUNT = 0
CLASS_COUNT = {}
local Inst = {}
local Imt = {}
local function children(i)
	return rawget(i, "_children")
end
Imt.__type = "Instance"
Imt.__index = function(i, k)
	local m = Inst[k]
	if m then
		return m
	end
	local props = rawget(i, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	for _, c in children(i) do
		if rawget(c, "_props").Name == k then
			return c
		end
	end
	return nil
end
Imt.__newindex = function(i, k, v)
	local props = rawget(i, "_props")
	if rawget(i, "_destroyed") then
		error("set " .. k .. " on destroyed instance " .. props.Name, 2)
	end
	if k == "Parent" then
		local old = props.Parent
		if old == v then
			return
		end
		if old then
			local list = children(old)
			for idx, c in list do
				if c == i then
					table.remove(list, idx)
					break
				end
			end
		end
		props.Parent = v
		if v then
			table.insert(children(v), i)
		end
		return
	end
	if k == "PrimaryPart" and v ~= nil then
		assert(isA(v.ClassName, "BasePart"), "PrimaryPart must be a BasePart")
	end
	if k == "Size" and isA(props.ClassName, "BasePart") then
		assert(getmetatable(v) == V3mt, "Size must be Vector3")
		assert(v.X > 0 and v.Y > 0 and v.Z > 0, "Size must be positive: " .. tostring(v))
		if v.X > 2048 or v.Y > 2048 or v.Z > 2048 then
			error("part larger than 2048 studs: " .. tostring(v), 2)
		end
	end
	if k == "CFrame" and isA(props.ClassName, "BasePart") then
		assert(getmetatable(v) == CFmt, "CFrame must be CFrame")
	end
	if k == "CanQuery" and v == false and props.CanCollide ~= false then
		error("CanQuery false while CanCollide true on " .. tostring(props.Name), 2)
	end
	props[k] = v
end
Imt.__tostring = function(i)
	return rawget(i, "_props").Name
end

Instance = {}
function Instance.new(className)
	INSTANCE_COUNT += 1
	CLASS_COUNT[className] = (CLASS_COUNT[className] or 0) + 1
	local props = { ClassName = className, Name = className }
	local i = setmetatable({ _props = props, _children = {}, _attrs = {} }, Imt)
	if isA(className, "BasePart") then
		props.Size = Vector3.new(4, 1, 2)
		props.CFrame = CFrame.new()
		props.PivotOffset = CFrame.new()
		props.CanCollide = true
		props.CanQuery = true
		props.Transparency = 0
	elseif className == "Model" then
		props.WorldPivot = CFrame.new()
	end
	return i
end

function Inst.SetAttribute(i, k, v)
	rawget(i, "_attrs")[k] = v
end
function Inst.GetAttribute(i, k)
	return rawget(i, "_attrs")[k]
end
function Inst.GetChildren(i)
	return table.clone(children(i))
end
function Inst.GetDescendants(i)
	local out = {}
	local function walk(n)
		for _, c in children(n) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(i)
	return out
end
function Inst.FindFirstChild(i, name, recursive)
	for _, c in children(i) do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, c in children(i) do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst.FindFirstChildWhichIsA(i, class, recursive)
	for _, c in (recursive and i:GetDescendants() or children(i)) do
		if c:IsA(class) then
			return c
		end
	end
	return nil
end
function Inst.WaitForChild(i, name)
	local c = i:FindFirstChild(name)
	assert(c, "WaitForChild would yield forever: " .. name)
	return c
end
function Inst.IsA(i, class)
	return isA(rawget(i, "_props").ClassName, class)
end
function Inst.Destroy(i)
	i.Parent = nil
	local function kill(n)
		for _, c in table.clone(children(n)) do
			kill(c)
		end
		rawset(n, "_destroyed", true)
	end
	kill(i)
end
function Inst.ClearAllChildren(i)
	for _, c in table.clone(children(i)) do
		c:Destroy()
	end
end
function Inst.Clone(i)
	local map = {}
	local function copy(n)
		local p = rawget(n, "_props")
		local c = Instance.new(p.ClassName)
		local cp = rawget(c, "_props")
		for k, v in p do
			if k ~= "Parent" then
				cp[k] = v
			end
		end
		for k, v in rawget(n, "_attrs") do
			rawget(c, "_attrs")[k] = v
		end
		map[n] = c
		for _, ch in children(n) do
			copy(ch).Parent = c
		end
		return c
	end
	local root = copy(i)
	-- remap instance references
	for orig, cl in map do
		local cp = rawget(cl, "_props")
		for k, v in cp do
			if type(v) == "table" and getmetatable(v) == Imt and map[v] then
				cp[k] = map[v]
			end
		end
	end
	return root
end
local function parts(i)
	local out = {}
	if i:IsA("BasePart") then
		table.insert(out, i)
	end
	for _, d in i:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
function Inst.GetPivot(i)
	if i:IsA("BasePart") then
		return i.CFrame * i.PivotOffset
	end
	local pp = i.PrimaryPart
	if pp then
		return pp.CFrame * pp.PivotOffset
	end
	return i.WorldPivot
end
function Inst.PivotTo(i, cf)
	assert(getmetatable(cf) == CFmt, "PivotTo expects CFrame")
	local delta = cf * i:GetPivot():Inverse()
	for _, p in parts(i) do
		p.CFrame = delta * p.CFrame
	end
	if not i:IsA("BasePart") and not i.PrimaryPart then
		i.WorldPivot = delta * i.WorldPivot
	end
end
function Inst.GetBoundingBox(i)
	local lo, hi
	for _, p in parts(i) do
		local s = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = p.CFrame * Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
					lo = lo and lo:Min(w) or w
					hi = hi and hi:Max(w) or w
				end
			end
		end
	end
	if not lo then
		error("GetBoundingBox on a model with no parts", 2)
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end
function Inst.GetExtentsSize(i)
	local _, s = i:GetBoundingBox()
	return s
end

local realTypeof = typeof
function typeof(v)
	local mt = getmetatable(v)
	if mt == Imt then
		return "Instance"
	elseif mt == V3mt then
		return "Vector3"
	elseif mt == CFmt then
		return "CFrame"
	elseif mt == C3mt then
		return "Color3"
	end
	return realTypeof(v)
end

WARNINGS = {}
function warn(...)
	local t = {}
	for _, v in { ... } do
		table.insert(t, tostring(v))
	end
	local msg = table.concat(t, " ")
	table.insert(WARNINGS, msg)
	print("WARN", msg)
end
