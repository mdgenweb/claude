--!strict
-- Contextual throw controls (bottom-centre, above the level bar): the big green THROW button that
-- appears in the Throw Zone and the launch meter drawn while charging. Press-down / release are
-- forwarded to ThrowController (required lazily so load order never matters); the meter is purely
-- cosmetic and mirrors the server's clock (FlightSim.MeterAt of server time since StartedAt).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FlightConfig = require(Shared.Config.Flight)
local FlightSim = require(Shared.Sim.FlightSim)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Button = require(script.Parent.Button)
local HudFlightState = require(script.Parent.HudFlightState)
local AudioController = require(Client.Controllers.AudioController)
local Bus = require(Client.Controllers.Bus)

export type ThrowPanel = {
	Instance: Frame,
}

local HudThrowPanel = {}

local METER_W = 460
local METER_H = 40
local BUTTON_W = 220
local BUTTON_H = 90
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function throwController(): any
	local module = Client.Controllers:FindFirstChild("ThrowController")
	if module and module:IsA("ModuleScript") then
		return (require :: any)(module)
	end
	return nil
end

local function call(method: string)
	local controller = throwController()
	if controller and type(controller[method]) == "function" then
		controller[method]()
	end
end

function HudThrowPanel.new(parent: Instance, bottomOffset: number): ThrowPanel
	local holder: Frame = Create("Frame", {
		Name = "ThrowPanel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -bottomOffset),
		Size = UDim2.fromOffset(METER_W + 40, BUTTON_H + METER_H + 70),
		Visible = false,
		ZIndex = 3,
		Parent = parent,
	})

	-- THROW button
	local holdScale = Instance.new("UIScale")
	local buttonHolder: Frame = Create("Frame", {
		Name = "ButtonHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
		Parent = holder,
	})
	holdScale.Parent = buttonHolder
	local button = Button.new({
		Parent = buttonHolder,
		Name = "Throw",
		Size = UDim2.fromScale(1, 1),
		Style = "Green",
		Text = "THROW",
		TextSize = 56,
		Corner = 18,
		Silent = true,
	})
	button.Label.Size = UDim2.new(1, -20, 0.6, 0)
	button.Label.Position = UDim2.fromScale(0.5, 0.4)
	-- input hint under the label (ThrowController binds E / R2 while in the zone)
	local keyHint = Create.Text({
		Name = "KeyHint",
		Text = "HOLD",
		Size = UDim2.new(1, -20, 0.26, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 22,
		Scaled = true,
		Color = Color3.fromHex("#EFFFE6"),
		Stroke = 2,
		ZIndex = button.Instance.ZIndex + 2,
		Parent = button.Content,
	})
	local function refreshHint()
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			keyHint.Text = "HOLD & RELEASE"
		elseif string.find(last.Name, "Gamepad", 1, true) then
			keyHint.Text = "HOLD [R2]"
		else
			keyHint.Text = "HOLD [E]"
		end
	end
	UserInputService.LastInputTypeChanged:Connect(refreshHint)
	refreshHint()

	-- Launch meter
	local meter: Frame = Create("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(BUTTON_H + 18)),
		Size = UDim2.fromOffset(METER_W, METER_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = holder,
	})
	Create.Corner(12, meter)
	local meterStroke = Create.Stroke(meter, Theme.Colors.Stroke, 3.5, 0, true)
	local track = Instance.new("UIGradient")
	track.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4F5E")),
		ColorSequenceKeypoint.new(0.45, Color3.fromHex("#FFB300")),
		ColorSequenceKeypoint.new(0.8, Theme.Colors.MeterGood),
		ColorSequenceKeypoint.new(1, Theme.Colors.MeterGood),
	})
	track.Parent = meter
	local perfectAt = FlightConfig.PerfectLaunchAt
	local band: Frame = Create("Frame", {
		Name = "PerfectBand",
		Position = UDim2.fromScale(perfectAt, 0),
		Size = UDim2.fromScale(1 - perfectAt, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = meter,
	})
	Create.Corner(10, band)
	Create.Gradient(band, Color3.fromHex("#FFF6C2"), Theme.Colors.MeterPerfect, 90)
	Create.Stroke(band, Color3.fromHex("#6B4300"), 2, 0, true)
	Create.Text({
		Name = "PerfectLabel",
		Text = "PERFECT",
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.new(perfectAt + (1 - perfectAt) / 2, 0, 0, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		Color = Theme.Colors.MeterPerfect,
		Stroke = 2.5,
		Parent = meter,
	})
	Create.Text({
		Name = "Hint",
		Text = "RELEASE IN THE GOLD!",
		Size = UDim2.fromOffset(300, 28),
		Position = UDim2.new(0, 4, 0, -4),
		AnchorPoint = Vector2.new(0, 1),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Stroke = 2.5,
		XAlign = Enum.TextXAlignment.Left,
		Parent = meter,
	})
	local needle: Frame = Create("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 12, 1, 22),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = meter,
	})
	Create.Corner(6, needle)
	local needleStroke = Create.Stroke(needle, Theme.Colors.Stroke, 3, 0, true)

	-- state
	local inZone = false
	local charging = false
	local startedAt = 0
	local lastSegment = -1
	local renderConn: RBXScriptConnection? = nil
	local hideToken = 0

	local function refreshVisible()
		holder.Visible = (inZone or charging) and not HudFlightState.Active
	end

	local function stepMeter()
		local value = FlightSim.MeterAt(Workspace:GetServerTimeNow() - startedAt)
		needle.Position = UDim2.fromScale(value, 0.5)
		local perfect = value >= perfectAt
		needle.BackgroundColor3 = if perfect then Theme.Colors.MeterPerfect else Color3.new(1, 1, 1)
		meterStroke.Color = if perfect then Theme.Colors.MeterPerfect else Theme.Colors.Stroke
		local segment = math.floor(value * 8)
		if segment ~= lastSegment then
			lastSegment = segment
			AudioController.PlayPitched("Charge", 0.7 + value * 0.9, if perfect then 1 else 0.6)
		end
	end

	local function setCharging(on: boolean, at: number?)
		if on then
			hideToken += 1
			charging = true
			startedAt = at or Workspace:GetServerTimeNow()
			lastSegment = -1
			meter.Visible = true
			button:SetText("RELEASE!")
			button:SetStyle("Gold")
			holdScale.Scale = 0.94
			if renderConn == nil then
				renderConn = RunService.RenderStepped:Connect(stepMeter)
			end
			stepMeter()
		else
			if not charging then
				return
			end
			charging = false
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			button:SetText("THROW")
			button:SetStyle("Green")
			TweenService:Create(holdScale, POP, { Scale = 1 }):Play()
			-- freeze the needle briefly so the player sees where they released
			hideToken += 1
			local token = hideToken
			needleStroke.Thickness = 4
			task.delay(0.45, function()
				if token == hideToken then
					meter.Visible = false
					needleStroke.Thickness = 3
				end
			end)
		end
		refreshVisible()
	end

	-- input: press-down / release (mouse + touch); gamepad selection falls back to a quick tap
	local pressing: InputObject? = nil
	local gamepadHold = false
	button.Instance.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if pressing ~= nil or not holder.Visible then
			return
		end
		pressing = input
		AudioController.Play("Click")
		call("Press")
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if gamepadHold and input.KeyCode == Enum.KeyCode.ButtonA then
			gamepadHold = false
			call("Release")
			return
		end
		local held = pressing
		if held == nil then
			return
		end
		local mouseUp = input.UserInputType == Enum.UserInputType.MouseButton1 and held.UserInputType == Enum.UserInputType.MouseButton1
		if input == held or mouseUp then
			pressing = nil
			call("Release")
		end
	end)
	button.Instance.Activated:Connect(function(input: InputObject?)
		local kind = if input then input.UserInputType else UserInputService:GetLastInputType()
		local gamepad = kind == Enum.UserInputType.Gamepad1
			or kind == Enum.UserInputType.Gamepad2
			or kind == Enum.UserInputType.Gamepad3
			or kind == Enum.UserInputType.Gamepad4
		if not gamepad or gamepadHold or not holder.Visible then
			return
		end
		call("Press")
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) then
			gamepadHold = true -- released on ButtonA up
		else
			task.delay(0.08, function()
				call("Release")
			end)
		end
	end)

	Bus.InThrowZoneChanged:Connect(function(on: any)
		local was = inZone
		inZone = on == true
		refreshVisible()
		if inZone and not was and holder.Visible then
			buttonHolder.Size = UDim2.fromOffset(BUTTON_W * 0.6, BUTTON_H * 0.6)
			TweenService:Create(buttonHolder, POP, { Size = UDim2.fromOffset(BUTTON_W, BUTTON_H) }):Play()
		end
		if not inZone and pressing ~= nil then
			pressing = nil
		end
	end)
	Bus.ChargeChanged:Connect(function(on: any, at: any)
		setCharging(on == true, if type(at) == "number" then at else nil)
	end)
	HudFlightState.Changed:Connect(function(active: any)
		if active then
			setCharging(false)
			pressing = nil
			gamepadHold = false
		end
		refreshVisible()
	end)

	return { Instance = holder }
end

return HudThrowPanel
