--!nonstrict
-- Unified input: one "pointer" for mouse, touch and gamepad (virtual cursor), keybinds mapped to
-- named actions, plus camera gestures (wheel, WASD, middle-drag, pinch, two-finger pan, sticks).

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)

local InputController = {
	pointer = Vector2.new(400, 300),
	device = "mouse", -- "mouse" | "touch" | "gamepad"
	PointerDown = Signal.new(), -- (button: "primary"|"secondary", position)
	PointerUp = Signal.new(), -- (button, position)
	Tap = Signal.new(), -- (position) touch tap / gamepad X
	Action = Signal.new(), -- (actionName)
	DeviceChanged = Signal.new(),
	primaryDown = false,
	enabled = true,
}

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.G] = "slowmo",
	[Enum.KeyCode.Space] = "pause",
	[Enum.KeyCode.H] = "heal",
	[Enum.KeyCode.R] = "reset",
	[Enum.KeyCode.N] = "spawnLast",
	[Enum.KeyCode.Z] = "undo",
	[Enum.KeyCode.K] = "clearZombies",
	[Enum.KeyCode.B] = "brew",
	[Enum.KeyCode.C] = "codex",
	[Enum.KeyCode.J] = "challenges",
	[Enum.KeyCode.M] = "menu",
	[Enum.KeyCode.O] = "shop",
	[Enum.KeyCode.P] = "photo",
	[Enum.KeyCode.F1] = "help",
	[Enum.KeyCode.Q] = "mode",
	[Enum.KeyCode.F] = "follow",
	[Enum.KeyCode.Escape] = "back",
	[Enum.KeyCode.One] = "slot1",
	[Enum.KeyCode.Two] = "slot2",
	[Enum.KeyCode.Three] = "slot3",
	[Enum.KeyCode.Four] = "slot4",
	[Enum.KeyCode.Five] = "slot5",
	[Enum.KeyCode.Six] = "slot6",
	[Enum.KeyCode.Seven] = "slot7",
	[Enum.KeyCode.Eight] = "slot8",
	[Enum.KeyCode.Nine] = "slot9",
	[Enum.KeyCode.Zero] = "deselect",
	[Enum.KeyCode.ButtonY] = "mode",
	[Enum.KeyCode.ButtonL1] = "slotPrev",
	[Enum.KeyCode.ButtonR1] = "slotNext",
	[Enum.KeyCode.DPadUp] = "slowmo",
	[Enum.KeyCode.DPadDown] = "pause",
	[Enum.KeyCode.DPadLeft] = "heal",
	[Enum.KeyCode.DPadRight] = "spawnLast",
	[Enum.KeyCode.ButtonStart] = "menu",
	[Enum.KeyCode.ButtonSelect] = "help",
	[Enum.KeyCode.ButtonB] = "back",
}
InputController.Keys = KEYS

local PAN_KEYS = {
	[Enum.KeyCode.W] = Vector3.new(0, 1, 0),
	[Enum.KeyCode.Up] = Vector3.new(0, 1, 0),
	[Enum.KeyCode.S] = Vector3.new(0, -1, 0),
	[Enum.KeyCode.Down] = Vector3.new(0, -1, 0),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.Left] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.Right] = Vector3.new(1, 0, 0),
}

local touchStart: { position: Vector2, time: number, input: InputObject }? = nil
local activeTouches = 0
local middleDragging = false
local lastMiddle = Vector2.zero
local stickLeft, stickRight = Vector2.zero, Vector2.zero
local triggerZoom = 0

local function setDevice(self, device: string)
	if self.device ~= device then
		self.device = device
		self.DeviceChanged:Fire(device)
	end
end

local function insetPosition(position: Vector3 | Vector2): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(position.X, position.Y) + inset
end

local function typing(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

function InputController:Init(controllers)
	self.C = controllers
end

function InputController:IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

function InputController:Start()
	if self:IsTouch() then
		self.device = "touch"
	end
	local Camera = self.C.CameraController

	UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 then
			setDevice(self, "mouse")
			if processed or not self.enabled then
				return
			end
			local button = if t == Enum.UserInputType.MouseButton1 then "primary" else "secondary"
			if button == "primary" then
				self.primaryDown = true
			end
			self.PointerDown:Fire(button, self.pointer)
		elseif t == Enum.UserInputType.MouseButton3 then
			if not processed then
				middleDragging = true
				lastMiddle = UserInputService:GetMouseLocation()
			end
		elseif t == Enum.UserInputType.Touch then
			setDevice(self, "touch")
			activeTouches += 1
			if processed or not self.enabled then
				return
			end
			self.pointer = insetPosition(input.Position)
			if activeTouches == 1 then
				touchStart = { position = self.pointer, time = os.clock(), input = input }
				self.primaryDown = true
				self.PointerDown:Fire("primary", self.pointer)
			elseif self.primaryDown then
				-- Second finger: cancel the grab and treat as a camera gesture.
				self.primaryDown = false
				touchStart = nil
				self.PointerUp:Fire("cancel", self.pointer)
			end
		elseif t == Enum.UserInputType.Keyboard or t.Name:sub(1, 7) == "Gamepad" then
			if t.Name:sub(1, 7) == "Gamepad" then
				setDevice(self, "gamepad")
				if input.KeyCode == Enum.KeyCode.ButtonA and not processed then
					self.primaryDown = true
					self.PointerDown:Fire("primary", self.pointer)
					return
				elseif input.KeyCode == Enum.KeyCode.ButtonX and not processed then
					self.PointerDown:Fire("secondary", self.pointer)
					return
				end
			end
			if typing() then
				return
			end
			local action = KEYS[input.KeyCode]
			if action and (not processed or action == "back" or input.KeyCode == Enum.KeyCode.F1) then
				self.Action:Fire(action)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 then
			local button = if t == Enum.UserInputType.MouseButton1 then "primary" else "secondary"
			if button == "primary" then
				self.primaryDown = false
			end
			self.PointerUp:Fire(button, self.pointer)
		elseif t == Enum.UserInputType.MouseButton3 then
			middleDragging = false
		elseif t == Enum.UserInputType.Touch then
			activeTouches = math.max(0, activeTouches - 1)
			local start = touchStart
			if start and start.input == input then
				touchStart = nil
				local position = insetPosition(input.Position)
				local moved = (position - start.position).Magnitude
				local quick = os.clock() - start.time < 0.28
				self.primaryDown = false
				self.PointerUp:Fire("primary", position)
				if moved < 14 and quick then
					self.Tap:Fire(position)
				end
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonA then
			self.primaryDown = false
			self.PointerUp:Fire("primary", self.pointer)
		end
	end)

	UserInputService.InputChanged:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement then
			setDevice(self, "mouse")
			self.pointer = UserInputService:GetMouseLocation()
			if middleDragging then
				local now = self.pointer
				Camera:PanPixels(now - lastMiddle)
				lastMiddle = now
			end
		elseif t == Enum.UserInputType.MouseWheel then
			if not processed and self.enabled then
				Camera:ZoomAt(self.pointer, if input.Position.Z > 0 then 0.88 else 1.14)
			end
		elseif t == Enum.UserInputType.Touch then
			if touchStart and touchStart.input == input then
				self.pointer = insetPosition(input.Position)
			end
		elseif t == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				stickLeft = Vector2.new(input.Position.X, -input.Position.Y)
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				stickRight = Vector2.new(input.Position.X, input.Position.Y)
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
				triggerZoom = -input.Position.Z
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				triggerZoom = input.Position.Z
			end
		end
	end)

	UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, state, processed)
		if processed or not self.enabled then
			return
		end
		if state == Enum.UserInputState.Change then
			self._lastPinch = self._lastPinch or 1
			local factor = self._lastPinch / math.max(scale, 0.01)
			self._lastPinch = scale
			Camera:ZoomAt(nil, math.clamp(factor, 0.8, 1.25))
		else
			self._lastPinch = 1
		end
	end)
	UserInputService.TouchPan:Connect(function(positions, _total, velocity, state, processed)
		if processed or not self.enabled or #positions < 2 then
			return
		end
		if state == Enum.UserInputState.Change then
			Camera:PanPixels(velocity * (1 / 60))
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if typing() then
			return
		end
		-- Keyboard panning.
		local pan = Vector3.zero
		for key, dir in PAN_KEYS do
			if UserInputService:IsKeyDown(key) then
				pan += dir
			end
		end
		if pan.Magnitude > 0 then
			Camera:Pan(pan.Unit * Camera:Distance() * 0.9 * dt)
		end
		-- Gamepad virtual cursor and camera.
		if self.device == "gamepad" then
			if stickLeft.Magnitude > 0.15 then
				local viewport = workspace.CurrentCamera.ViewportSize
				local speed = 950 * dt * stickLeft.Magnitude
				local next = self.pointer + stickLeft.Unit * speed
				self.pointer = Vector2.new(math.clamp(next.X, 0, viewport.X), math.clamp(next.Y, 0, viewport.Y))
			end
			if stickRight.Magnitude > 0.15 then
				Camera:Pan(Vector3.new(stickRight.X, stickRight.Y, 0) * Camera:Distance() * 0.9 * dt)
			end
			if math.abs(triggerZoom) > 0.1 then
				Camera:ZoomAt(nil, 1 + triggerZoom * dt * 1.5)
			end
		end
	end)
end

return InputController
