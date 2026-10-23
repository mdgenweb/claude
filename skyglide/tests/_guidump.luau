-- GUI tree dumper for tests/ui_render.py. DUMP_GUI(label) prints the local player's PlayerGui as
-- one JSON object per instance (every property, value types tagged), between DUMP/END lines.
-- SET_DEVICE(name) switches viewport, safe-area insets and input flags like a real device.

local function esc(str)
	return (string.gsub(str, '[%c"\\]', function(c)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		elseif c == "\n" then
			return "\\n"
		elseif c == "\t" then
			return "\\t"
		end
		return string.format("\\u%04x", string.byte(c))
	end))
end

local function num(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "null"
	end
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.6g", n)
end

local encode
local function encodeTable(t)
	local parts = {}
	for k, v in t do
		local e = encode(v)
		if e then
			table.insert(parts, '"' .. esc(tostring(k)) .. '":' .. e)
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
function encode(v)
	local t = typeof(v)
	if t == "string" then
		return '"' .. esc(v) .. '"'
	elseif t == "number" then
		return num(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "UDim2" then
		return string.format('{"_t":"UDim2","xs":%s,"xo":%s,"ys":%s,"yo":%s}', num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset))
	elseif t == "UDim" then
		return string.format('{"_t":"UDim","s":%s,"o":%s}', num(v.Scale), num(v.Offset))
	elseif t == "Vector2" then
		return string.format('{"_t":"V2","x":%s,"y":%s}', num(v.X), num(v.Y))
	elseif t == "Color3" then
		return string.format('{"_t":"C3","r":%s,"g":%s,"b":%s}', num(v.R), num(v.G), num(v.B))
	elseif t == "EnumItem" then
		return '{"_t":"Enum","n":"' .. esc(v.Name) .. '"}'
	elseif t == "table" and rawget(v, "__kind") then
		local items = {}
		for i = 1, 8 do
			local x = rawget(v, i)
			if x == nil then
				break
			end
			local e = encode(x)
			table.insert(items, e or "null")
		end
		return '{"_t":"' .. esc(v.__kind) .. '","a":[' .. table.concat(items, ",") .. "]}"
	end
	return nil -- functions, instances, signals: not part of the picture
end

local ids = {}
local nextId = 0
local function idOf(inst)
	local id = ids[inst]
	if not id then
		nextId += 1
		id = nextId
		ids[inst] = id
	end
	return id
end

DEVICE = "pc"
function DUMP_GUI(label)
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	local camera = FAKE_GAME:GetService("Workspace").CurrentCamera
	local v = camera.ViewportSize
	print(string.format('DUMP\t{"label":"%s","device":"%s","w":%s,"h":%s,"top":%s,"bottom":%s,"left":%s,"right":%s,"touch":%s}', esc(label), DEVICE, num(v.X), num(v.Y), num(GUI_INSETS.Top), num(GUI_INSETS.Bottom), num(GUI_INSETS.Left), num(GUI_INSETS.Right), tostring(FAKE_GAME:GetService("UserInputService").TouchEnabled)))
	local function walk(inst, parentId)
		local props = rawget(inst, "_props")
		local id = idOf(inst)
		local body = encodeTable(props)
		print(string.format('NODE\t{"id":%d,"parent":%d,"props":%s}', id, parentId, body))
		for _, c in rawget(inst, "_children") do
			walk(c, id)
		end
	end
	for _, c in rawget(playerGui, "_children") do
		walk(c, 0)
	end
	print("END")
end

local DEVICES = {
	-- name = { w, h, touch, insets {top, bottom, left, right}, tenFoot }
	pc = { 1920, 1080, false, { 58, 0, 0, 0 }, false },
	laptop = { 1366, 768, false, { 58, 0, 0, 0 }, false },
	tablet = { 1024, 768, true, { 58, 20, 0, 0 }, false },
	phone = { 844, 390, true, { 58, 21, 47, 47 }, false },
	phone_se = { 667, 375, true, { 58, 0, 0, 0 }, false },
	console = { 1920, 1080, false, { 58, 0, 0, 0 }, true },
}
DEVICE_NAMES = { "pc", "laptop", "tablet", "phone", "phone_se", "console" }
function SET_DEVICE(name)
	local d = assert(DEVICES[name], "unknown device " .. tostring(name))
	DEVICE = name
	local UIS = FAKE_GAME:GetService("UserInputService")
	UIS.TouchEnabled = d[3]
	UIS.KeyboardEnabled = not d[3] and not d[5]
	UIS.MouseEnabled = not d[3] and not d[5]
	UIS.GamepadEnabled = d[5]
	local last = if d[3] then Enum.UserInputType.Touch elseif d[5] then Enum.UserInputType.Gamepad1 else Enum.UserInputType.MouseButton1
	UIS.GetLastInputType = function()
		return last
	end
	FAKE_GAME:GetService("GuiService").IsTenFootInterface = function()
		return d[5]
	end
	GUI_INSETS.Top, GUI_INSETS.Bottom, GUI_INSETS.Left, GUI_INSETS.Right = d[4][1], d[4][2], d[4][3], d[4][4]
	local camera = FAKE_GAME:GetService("Workspace").CurrentCamera
	camera.ViewportSize = Vector2.new(d[1], d[2])
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	UIS.LastInputTypeChanged:Fire(last)
end
