-- Client-side Roblox API mock layered on top of _rbxmock.luau (loaded after the module harness).
-- Adds: event signals on every instance, UDim/UDim2/Vector2 with arithmetic, identity-stable Enum
-- items, mock services (Players/LocalPlayer, Workspace/Camera, RunService, input, tweens, ...),
-- remote stubs that record client->server intents, and a virtual-clock task scheduler so
-- task.wait / task.delay / tweens actually advance. Errors inside connected handlers are
-- collected in CLIENT_ERRORS (Roblox logs them; the spec fails on them).

CLIENT_ERRORS = {}
CLOCK = 1000

-- Scheduler -----------------------------------------------------------------------------------------
local timers = {} -- { at, thread | fn, args }
local function resumeThread(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(CLIENT_ERRORS, "task: " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end
task = {
	spawn = function(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		resumeThread(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		table.insert(timers, { at = CLOCK, co = co, args = table.pack(...) })
		return co
	end,
	delay = function(t, fn, ...)
		local co = coroutine.create(fn)
		table.insert(timers, { at = CLOCK + (t or 0), co = co, args = table.pack(...) })
		return co
	end,
	wait = function(t)
		local co = coroutine.running()
		if not coroutine.isyieldable() then
			return 0
		end
		table.insert(timers, { at = CLOCK + (t or 0.03), co = co, args = table.pack() })
		coroutine.yield()
		return t or 0.03
	end,
	cancel = function(co)
		for i = #timers, 1, -1 do
			if timers[i].co == co then
				table.remove(timers, i)
			end
		end
	end,
}
local function runTimers()
	local guard = 0
	while true do
		guard += 1
		if guard > 10000 then
			error("scheduler runaway")
		end
		local index = nil
		for i, t in timers do
			if t.at <= CLOCK and (index == nil or t.at < timers[index].at) then
				index = i
			end
		end
		if index == nil then
			return
		end
		local t = table.remove(timers, index)
		if coroutine.status(t.co) == "suspended" then
			resumeThread(t.co, table.unpack(t.args, 1, t.args.n))
		end
	end
end

-- Signals -------------------------------------------------------------------------------------------
local SignalMT = {}
SignalMT.__index = SignalMT
SignalMT.__type = "RBXScriptSignal"
function NEW_SIGNAL(name)
	return setmetatable({ handlers = {}, waiting = {}, name = name or "signal" }, SignalMT)
end
function SignalMT:Connect(fn)
	local conn = { Connected = true }
	conn.Disconnect = function(c)
		c.Connected = false
	end
	table.insert(self.handlers, { fn = fn, conn = conn })
	return conn
end
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function SignalMT:Wait()
	if not coroutine.isyieldable() then
		return nil
	end
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end
function SignalMT:Fire(...)
	for _, h in table.clone(self.handlers) do
		if h.conn.Connected then
			local co = coroutine.create(h.fn)
			resumeThread(co, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in waiting do
		if coroutine.status(co) == "suspended" then
			resumeThread(co, ...)
		end
	end
end

-- Value types ---------------------------------------------------------------------------------------
local V2mt = { __type = "Vector2" }
V2mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return Vector2.new(v.X / m, v.Y / m)
	elseif k == "Lerp" then
		return function(a, b, t)
			return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
		end
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y
		end
	end
	return nil
end
V2mt.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2mt.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2mt.__mul = function(a, b)
	if type(a) == "number" then
		return Vector2.new(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2mt.__div = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
V2mt.__unm = function(a)
	return Vector2.new(-a.X, -a.Y)
end
V2mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2mt)
	end,
}
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
Vector2.xAxis = Vector2.new(1, 0)
Vector2.yAxis = Vector2.new(0, 1)

local UDmt = { __type = "UDim" }
UDmt.__index = UDmt
UDmt.__add = function(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end
UDmt.__sub = function(a, b)
	return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset)
end
UDim = {
	new = function(s, o)
		return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDmt)
	end,
}
local U2mt = { __type = "UDim2" }
U2mt.__index = function(u, k)
	if k == "Width" then
		return u.X
	elseif k == "Height" then
		return u.Y
	elseif k == "Lerp" then
		return function(a, b, t)
			return UDim2.new(
				a.X.Scale + (b.X.Scale - a.X.Scale) * t,
				a.X.Offset + (b.X.Offset - a.X.Offset) * t,
				a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
				a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
			)
		end
	end
	return nil
end
U2mt.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
U2mt.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
U2mt.__eq = function(a, b)
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end
local function checkNum(v, what)
	if v ~= nil and (type(v) ~= "number" or v ~= v) then
		error("bad number for " .. what .. ": " .. tostring(v), 3)
	end
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		if type(xs) == "table" then
			return setmetatable({ X = xs, Y = xo }, U2mt)
		end
		checkNum(xs, "UDim2")
		checkNum(xo, "UDim2")
		checkNum(ys, "UDim2")
		checkNum(yo, "UDim2")
		return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, U2mt)
	end,
	fromScale = function(x, y)
		return UDim2.new(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return UDim2.new(0, x, 0, y)
	end,
}
TweenInfo = {
	new = function(time, style, direction, repeats, reverses, delay)
		return { Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeats or 0, Reverses = reverses, DelayTime = delay or 0 }
	end,
}
if CFrame.identity == nil then
	CFrame.identity = CFrame.new()
end

-- Enum: identity-stable items with Name/Value/EnumType
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		local items = enumCache[enumName]
		if not items then
			local counter = 0
			items = setmetatable({}, {
				__index = function(t, item)
					counter += 1
					local value = setmetatable({ Name = item, Value = counter, EnumType = enumName }, {
						__tostring = function()
							return "Enum." .. enumName .. "." .. item
						end,
						__type = "EnumItem",
					})
					rawset(t, item, value)
					return value
				end,
			})
			enumCache[enumName] = items
		end
		return items
	end,
})
Enum.ContextActionPriority.High.Value = 3000
Enum.ContextActionPriority.Default.Value = 2000

local priorTypeof = typeof
function typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and type(mt.__type) == "string" then
		return mt.__type
	end
	return priorTypeof(v)
end

-- Instances: signals, defaults, extra methods ---------------------------------------------------------
local Imt = getmetatable(Instance.new("Folder"))
local baseIndex = Imt.__index
local EVENTS = {
	Activated = true, MouseEnter = true, MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseButton1Click = true, InputBegan = true, InputEnded = true, InputChanged = true, FocusLost = true,
	Focused = true, Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true,
	DescendantRemoving = true, Touched = true, TouchEnded = true, Triggered = true, TriggerEnded = true,
	PromptTriggered = true, Completed = true, Event = true, OnClientEvent = true, OnServerEvent = true,
	CharacterAdded = true, CharacterRemoving = true, Died = true, PlayerAdded = true, PlayerRemoving = true,
	Heartbeat = true, RenderStepped = true, Stepped = true, LastInputTypeChanged = true, Ended = true,
	SelectionGained = true, SelectionLost = true, AncestryChanged = true, Destroying = true,
	PromptShown = true, PromptHidden = true,
}
local GUI_DEFAULTS = {
	AbsoluteSize = function()
		return Vector2.new(120, 120)
	end,
	AbsolutePosition = function()
		return Vector2.zero
	end,
	TextBounds = function()
		return Vector2.new(80, 20)
	end,
}
local baseNewIndex = Imt.__newindex
Imt.__newindex = function(i, k, v)
	-- BaseParts: Position/Orientation are views of CFrame like in Roblox
	if k == "Position" and i:IsA("BasePart") then
		local cf = rawget(i, "_props").CFrame
		baseNewIndex(i, "CFrame", cf.Rotation + v)
		return
	end
	if (k == "CFrame" or k == "WorldPivot" or k == "PivotOffset") and type(v) == "table" and v.x ~= nil then
		-- Roblox keeps CFrames orthonormal; do the same so repeated PivotTo can't drift
		local x = v.x.Unit
		local y = (v.y - x * x:Dot(v.y)).Unit
		local z = x:Cross(y)
		v = CFrame.fromMatrix(v.Position, x, y, z)
	end
	baseNewIndex(i, k, v)
end
Imt.__index = function(i, k)
	if k == "Position" then
		local props = rawget(i, "_props")
		if props.CFrame ~= nil and props.Position == nil then
			return props.CFrame.Position
		end
	end
	local v = baseIndex(i, k)
	if v ~= nil then
		return v
	end
	if k == "WorldPosition" or k == "WorldCFrame" then
		local props = rawget(i, "_props")
		if props.ClassName == "Attachment" then
			local parent = props.Parent
			local local_ = CFrame.new(0, 0, 0) + (props.Position or Vector3.zero)
			local world = if parent and parent.CFrame then parent.CFrame * local_ else local_
			return if k == "WorldPosition" then world.Position else world
		end
	end
	if EVENTS[k] then
		local signals = rawget(i, "_signals")
		if not signals then
			signals = {}
			rawset(i, "_signals", signals)
		end
		local s = signals[k]
		if not s then
			s = NEW_SIGNAL(k)
			signals[k] = s
		end
		return s
	end
	local default = GUI_DEFAULTS[k]
	if default and i:IsA("GuiBase2d") then
		return default()
	end
	return nil
end
local Inst = {}
local function method(name, fn)
	-- methods resolve through baseIndex -> Inst table of _rbxmock; we add via a props-less fallback
	Inst[name] = fn
end
local prevIndex = Imt.__index
Imt.__index = function(i, k)
	local m = Inst[k]
	if m then
		return m
	end
	return prevIndex(i, k)
end
local function namedSignal(i, bucket, name)
	local store = rawget(i, bucket)
	if not store then
		store = {}
		rawset(i, bucket, store)
	end
	local s = store[name]
	if not s then
		s = NEW_SIGNAL(name)
		store[name] = s
	end
	return s
end
method("GetPropertyChangedSignal", function(i, name)
	return namedSignal(i, "_propSignals", name)
end)
method("GetAttributeChangedSignal", function(i, name)
	return namedSignal(i, "_attrSignals", name)
end)
local baseSetAttribute = baseIndex(Instance.new("Folder"), "SetAttribute")
method("SetAttribute", function(i, k, v)
	baseSetAttribute(i, k, v)
	local store = rawget(i, "_attrSignals")
	if store and store[k] then
		store[k]:Fire()
	end
end)
method("FindFirstChildOfClass", function(i, class)
	for _, c in i:GetChildren() do
		if rawget(c, "_props").ClassName == class then
			return c
		end
	end
	return nil
end)
method("FindFirstAncestorWhichIsA", function(i, class)
	local p = i.Parent
	while p ~= nil and type(p) == "table" and getmetatable(p) == Imt do
		if p:IsA(class) then
			return p
		end
		p = p.Parent
	end
	return nil
end)
method("FindFirstAncestor", function(i, name)
	local p = i.Parent
	while p ~= nil and type(p) == "table" and getmetatable(p) == Imt do
		if p.Name == name then
			return p
		end
		p = p.Parent
	end
	return nil
end)
method("IsDescendantOf", function(i, other)
	local p = i.Parent
	while p ~= nil do
		if p == other then
			return true
		end
		if type(p) ~= "table" or getmetatable(p) ~= Imt then
			return false
		end
		p = p.Parent
	end
	return false
end)
method("Emit", function() end)
method("IsFocused", function()
	return false
end)
method("CaptureFocus", function() end)
method("ReleaseFocus", function() end)
method("Fire", function(i, ...)
	-- BindableEvent:Fire -> .Event
	if rawget(i, "_props").ClassName == "BindableEvent" then
		i.Event:Fire(...)
	end
end)
method("Play", function(i, ...)
	-- tweens carry their own Play (see TweenService.Create); sounds just start playing
	local own = rawget(i, "_props").Play
	if type(own) == "function" then
		return own(i, ...)
	end
	rawget(i, "_props").IsPlaying = true
end)
method("Stop", function(i)
	rawget(i, "_props").IsPlaying = false
end)
method("Clear", function() end)

-- extra classes for IsA
local function classParent(child, parent)
	-- _rbxmock keeps CLASS_PARENTS local; emulate common GUI/Instance hierarchy by name patterns
	return child, parent
end
local baseIsA = baseIndex(Instance.new("Folder"), "IsA")
local GUI_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true,
	ScrollingFrame = true, ViewportFrame = true, CanvasGroup = true,
}
method("IsA", function(i, class)
	local cn = rawget(i, "_props").ClassName
	if baseIsA(i, class) then
		return true
	end
	if (class == "GuiObject" or class == "GuiBase2d") and GUI_CLASSES[cn] then
		return true
	end
	if class == "GuiButton" and (cn == "TextButton" or cn == "ImageButton") then
		return true
	end
	if (class == "LayerCollector" or class == "GuiBase2d") and (cn == "ScreenGui" or cn == "BillboardGui" or cn == "SurfaceGui") then
		return true
	end
	if class == "ValueBase" and string.match(cn, "Value$") then
		return true
	end
	if class == "BasePart" and (cn == "Part" or cn == "WedgePart" or cn == "MeshPart" or cn == "TrussPart" or cn == "SpawnLocation" or cn == "CornerWedgePart") then
		return true
	end
	return false
end)
local _ = classParent

-- Mock services ---------------------------------------------------------------------------------------
local ROOT = rawget(FAKE_GAME:GetService("ReplicatedStorage"), "Parent")
local function service(name)
	local s = Instance.new("Folder")
	s.Name = name
	rawget(ROOT, "_children")[name] = s
	return s
end

local Players = service("Players")
local Workspace = service("Workspace")
local RunService = service("RunService")
local UserInputService = service("UserInputService")
local GuiService = service("GuiService")
local TweenService = service("TweenService")
local ContextActionService = service("ContextActionService")
local StarterGui = service("StarterGui")
service("SoundService")
local SocialService = service("SocialService")
local ProximityPromptService = service("ProximityPromptService")
service("Lighting")
local Debris = service("Debris")
local MarketplaceService = service("MarketplaceService")

-- local player + character
local localPlayer = Instance.new("Player")
localPlayer.Name = "Tester"
localPlayer.DisplayName = "Tester"
localPlayer.UserId = 42
localPlayer.Parent = Players
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
local function makeCharacter()
	local character = Instance.new("Model")
	character.Name = "Tester"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Parent = character
	character.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Health = 100
	humanoid.WalkSpeed = 24
	humanoid.Parent = character
	for _, limb in { "RightHand", "RightUpperArm", "UpperTorso", "Head" } do
		local p = Instance.new("Part")
		p.Name = limb
		p.Size = Vector3.new(1, 1, 1)
		p.Parent = character
	end
	local shoulder = Instance.new("Motor6D")
	shoulder.Name = "RightShoulder"
	shoulder.C0 = CFrame.new()
	shoulder.Parent = character:FindFirstChild("RightUpperArm")
	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "Root"
	rootJoint.C0 = CFrame.new()
	rootJoint.Parent = character:FindFirstChild("UpperTorso")
	character.Parent = Workspace
	return character
end
localPlayer.Character = makeCharacter()
localPlayer.MembershipType = Enum.MembershipType.None
localPlayer.GetNetworkPing = function()
	return 0.05
end
Players.LocalPlayer = localPlayer
Players.GetPlayers = function()
	local out = {}
	for _, c in Players:GetChildren() do
		if c:IsA("Player") or rawget(c, "_props").ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
Players.GetPlayerByUserId = function(_, id)
	for _, p in Players.GetPlayers() do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
Players.GetPlayerFromCharacter = function(_, character)
	for _, p in Players.GetPlayers() do
		if p.Character == character then
			return p
		end
	end
	return nil
end
LOCAL_PLAYER = localPlayer

-- camera / workspace
local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.CFrame = CFrame.new(0, 10, 20)
camera.FieldOfView = 70
camera.ViewportSize = Vector2.new(1800, 920)
camera.CameraType = Enum.CameraType.Custom
camera.Parent = Workspace
Workspace.CurrentCamera = camera
Workspace.Gravity = 196.2
Workspace.GetServerTimeNow = function()
	return CLOCK
end
Workspace.BulkMoveTo = function(_, parts, cframes)
	for idx, p in parts do
		p.CFrame = cframes[idx]
	end
end
Workspace.Raycast = function()
	return nil
end

-- run service
local renderBindings = {}
RunService.BindToRenderStep = function(_, name, priority, fn)
	renderBindings[name] = { priority = priority, fn = fn }
end
RunService.UnbindFromRenderStep = function(_, name)
	renderBindings[name] = nil
end
function RUN_RENDER_BINDINGS(dt)
	local list = {}
	for name, b in renderBindings do
		table.insert(list, { name = name, priority = b.priority, fn = b.fn })
	end
	table.sort(list, function(a, b)
		return a.priority < b.priority
	end)
	for _, b in list do
		local ok, err = pcall(b.fn, dt)
		if not ok then
			table.insert(CLIENT_ERRORS, "render step " .. b.name .. ": " .. tostring(err))
		end
	end
end
RunService.IsStudio = function()
	return true
end
RunService.IsClient = function()
	return true
end
RunService.IsServer = function()
	return false
end

-- input
UserInputService.TouchEnabled = false
UserInputService.KeyboardEnabled = true
UserInputService.MouseEnabled = true
UserInputService.GamepadEnabled = false
UserInputService.GetLastInputType = function()
	return Enum.UserInputType.MouseButton1
end
UserInputService.GetFocusedTextBox = function()
	return nil
end
UserInputService.IsKeyDown = function()
	return false
end
UserInputService.GetMouseLocation = function()
	return Vector2.new(900, 460)
end
GuiService.IsTenFootInterface = function()
	return false
end
StarterGui.SetCoreGuiEnabled = function() end
StarterGui.SetCore = function() end
SocialService.PromptGameInvite = function() end
MarketplaceService.PromptProductPurchase = function() end
MarketplaceService.PromptGamePassPurchase = function() end
Debris.AddItem = function(_, item, t)
	task.delay(t or 10, function()
		if rawget(item, "_destroyed") == nil then
			item:Destroy()
		end
	end)
end

CAS_BINDINGS = {}
ContextActionService.BindAction = function(_, name, fn, _, ...)
	CAS_BINDINGS[name] = fn
end
ContextActionService.BindActionAtPriority = function(_, name, fn, _, _, ...)
	CAS_BINDINGS[name] = fn
end
ContextActionService.UnbindAction = function(_, name)
	CAS_BINDINGS[name] = nil
end

-- tweens: apply the goal immediately, fire Completed after the duration
TweenService.Create = function(_, inst, info, goal)
	local tween = Instance.new("Tween")
	tween.PlaybackState = Enum.PlaybackState.Begin
	tween.Play = function(self)
		for k, v in goal do
			inst[k] = v
		end
		self.PlaybackState = Enum.PlaybackState.Playing
		local repeats = info and info.RepeatCount or 0
		if repeats >= 0 then
			task.delay((info and info.Time or 0) * (repeats + 1) + (info and info.DelayTime or 0), function()
				self.PlaybackState = Enum.PlaybackState.Completed
				self.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
	end
	tween.Cancel = function(self)
		self.PlaybackState = Enum.PlaybackState.Cancelled
	end
	tween.Pause = function() end
	return tween
end

-- remotes ---------------------------------------------------------------------------------------------
SENT = {} -- { name, args... } client -> server
INVOKE_RESULTS = {} -- name -> function(args) -> result
local Spec = MODULE("ReplicatedStorage/Shared/Net/Remotes").Spec
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
rawget(FAKE_GAME:GetService("ReplicatedStorage"), "_children").Remotes = remotesFolder
for name, class in Spec do
	local r = Instance.new(class)
	r.Name = name
	r.FireServer = function(_, ...)
		table.insert(SENT, { name, ... })
	end
	r.InvokeServer = function(_, ...)
		table.insert(SENT, { name, ... })
		local handler = INVOKE_RESULTS[name]
		if handler then
			return handler(...)
		end
		return { ok = true }
	end
	r.Parent = remotesFolder
end
function SERVER_FIRE(name, ...)
	remotesFolder:FindFirstChild(name).OnClientEvent:Fire(...)
end

-- frames --------------------------------------------------------------------------------------------
function STEP(seconds, fps)
	local dt = 1 / (fps or 30)
	local frames = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, frames do
		CLOCK += dt
		runTimers()
		RUN_RENDER_BINDINGS(dt)
		RunService.RenderStepped:Fire(dt)
		RunService.Stepped:Fire(CLOCK, dt)
		RunService.Heartbeat:Fire(dt)
	end
	runTimers()
end
