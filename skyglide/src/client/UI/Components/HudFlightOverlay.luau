--!strict
-- In-flight HUD for the local player's glider: the big distance counter under AUTO THROW (punches
-- on every zone), the zone banner that slides in with the zone's colour, the cinematic SPECIAL
-- THROW banner with a screen flash, "PERFECT LAUNCH!", the "TAP!" prompt while a ring's gust
-- window is open, the "PERFECT xN" combo, and a full-screen transparent tap area (lowest ZIndex)
-- that forwards taps to ThrowController.Tap() so mobile players can catch gusts anywhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FlightSim = require(Shared.Sim.FlightSim)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local HudFlightState = require(script.Parent.HudFlightState)
local AudioController = require(Client.Controllers.AudioController)
local Bus = require(Client.Controllers.Bus)

export type FlightOverlay = {
	SetCounterTop: (FlightOverlay, number) -> (),
}

local HudFlightOverlay = {}

local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local WHITE = Color3.new(1, 1, 1)

local function throwController(): any
	local module = Client.Controllers:FindFirstChild("ThrowController")
	if module and module:IsA("ModuleScript") then
		return (require :: any)(module)
	end
	return nil
end

local function popScale(parent: GuiObject): UIScale
	local s = Instance.new("UIScale")
	s.Parent = parent
	return s
end

function HudFlightOverlay.new(root: Frame): FlightOverlay
	local localPlayer = Players.LocalPlayer

	-- full-screen tap area (below every other HUD element)
	local tapArea: TextButton = Create("TextButton", {
		Name = "FlightTapArea",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Active = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Visible = false,
		Parent = root,
	})
	tapArea.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			local controller = throwController()
			if controller and type(controller.Tap) == "function" then
				controller.Tap()
			end
		end
	end)

	-- distance counter
	local counter = Create.Text({
		Name = "FlightDistance",
		Text = "0 m",
		Size = UDim2.fromOffset(560, 92),
		Position = UDim2.new(0.5, 0, 0, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 92,
		Scaled = true,
		Stroke = 4.5,
		ZIndex = 4,
		Parent = root,
	})
	counter.Visible = false
	local counterScale = popScale(counter)

	-- zone banner
	local zoneBanner: Frame = Create("Frame", {
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(-0.4, 0, 0, 190),
		Size = UDim2.fromOffset(560, 74),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	Create.Corner(16, zoneBanner)
	local zoneStroke = Create.Stroke(zoneBanner, WHITE, 4, 0, true)
	Create.Text({
		Name = "Caption",
		Text = "ENTERING",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 2),
		Font = Theme.Fonts.Display,
		TextSize = 20,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		Stroke = 2,
		ZIndex = 5,
		Parent = zoneBanner,
	})
	local zoneName = Create.Text({
		Name = "ZoneName",
		Text = "",
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0.5, 0, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 44,
		Scaled = true,
		Stroke = 3.5,
		ZIndex = 5,
		Parent = zoneBanner,
	})

	-- special throw banner + screen flash
	local flash: Frame = Create("Frame", {
		Name = "ScreenFlash",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 8,
		Parent = root,
	})
	local special: Frame = Create("Frame", {
		Name = "SpecialBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(980, 150),
		BackgroundColor3 = WHITE,
		Visible = false,
		ZIndex = 9,
		Parent = root,
	})
	Create.Corner(24, special)
	Create.Stroke(special, Theme.Colors.Stroke, 5, 0, true)
	local specialGradient = Instance.new("UIGradient")
	specialGradient.Rotation = 90
	specialGradient.Parent = special
	local specialScale = popScale(special)
	local specialTitle = Create.Text({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -40, 0, 96),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 96,
		Scaled = true,
		Stroke = 5,
		ZIndex = 10,
		Parent = special,
	})
	local specialSub = Create.Text({
		Name = "Subtitle",
		Text = "",
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		Stroke = 3,
		ZIndex = 10,
		Parent = special,
	})

	-- PERFECT LAUNCH pop
	local launchText = Create.Text({
		Name = "PerfectLaunch",
		Text = "PERFECT LAUNCH!",
		Size = UDim2.fromOffset(640, 76),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 76,
		Scaled = true,
		Color = Theme.Colors.MeterPerfect,
		Stroke = 4.5,
		ZIndex = 6,
		Parent = root,
	})
	launchText.Visible = false
	local launchScale = popScale(launchText)

	-- TAP! prompt
	local tapPrompt = Create.Text({
		Name = "TapPrompt",
		Text = "TAP!",
		Size = UDim2.fromOffset(320, 116),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 130,
		Scaled = true,
		Color = Color3.fromHex("#7FF0FF"),
		Stroke = 5,
		ZIndex = 6,
		Parent = root,
	})
	tapPrompt.Visible = false
	local tapScale = popScale(tapPrompt)

	-- PERFECT xN combo
	local combo = Create.Text({
		Name = "Combo",
		Text = "",
		Size = UDim2.fromOffset(400, 70),
		Position = UDim2.new(0.5, 190, 0.5, -30),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 70,
		Scaled = true,
		Color = Theme.Colors.MeterPerfect,
		Stroke = 4,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = root,
	})
	combo.Visible = false
	local comboScale = popScale(combo)
	local comboAmount = Create.Text({
		Name = "Amount",
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, 2),
		Font = Theme.Fonts.Display,
		TextSize = 40,
		Scaled = true,
		Color = Theme.Colors.Skill,
		Stroke = 3,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = combo,
	})

	-- state
	local self = {} :: any
	local counterTop = 92
	local lastShown = -1
	local streak = 0
	local zoneToken = 0
	local comboToken = 0
	local launchToken = 0
	local specialToken = 0
	local flightId: number? = nil

	function self.SetCounterTop(_: any, top: number)
		counterTop = top
		counter.Position = UDim2.new(0.5, 0, 0, top)
		zoneBanner.Position = UDim2.new(zoneBanner.Position.X.Scale, 0, 0, top + 100)
	end

	local function hideFlightBits()
		counter.Visible = false
		tapPrompt.Visible = false
		zoneBanner.Visible = false
		tapArea.Visible = false
	end

	local function showSpecial(id: string)
		local info = FlightSim.SpecialInfo(id)
		if not info then
			return
		end
		specialToken += 1
		local token = specialToken
		local color = Color3.fromHex(info.Color)
		specialGradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.35), color:Lerp(Color3.new(0, 0, 0), 0.35))
		specialTitle.Text = string.format("%s! x%d", info.Name, info.Multiplier)
		specialTitle.TextColor3 = WHITE
		specialSub.Text = "SPECIAL THROW - " .. info.Multiplier .. "x DISTANCE!"
		special.Visible = true
		special.BackgroundTransparency = 0
		specialScale.Scale = 2.2
		TweenService:Create(specialScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		flash.Visible = true
		flash.BackgroundColor3 = color:Lerp(WHITE, 0.6)
		flash.BackgroundTransparency = 0.05
		TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		AudioController.Play("RareHatch")
		task.delay(0.75, function()
			if token == specialToken then
				flash.Visible = false
			end
		end)
		task.delay(2.6, function()
			if token ~= specialToken then
				return
			end
			local out = TweenService:Create(specialScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			out:Play()
			out.Completed:Wait()
			if token == specialToken then
				special.Visible = false
			end
		end)
	end

	local function showLaunch()
		launchToken += 1
		local token = launchToken
		launchText.Visible = true
		launchText.TextTransparency = 0
		launchScale.Scale = 0.3
		TweenService:Create(launchScale, POP, { Scale = 1 }):Play()
		task.delay(1, function()
			if token ~= launchToken then
				return
			end
			local fade = TweenService:Create(launchText, TweenInfo.new(0.3), { TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			if token == launchToken then
				launchText.Visible = false
			end
		end)
	end

	HudFlightState.Changed:Connect(function(active: any, plan: any)
		if active and type(plan) == "table" then
			flightId = plan.Id
			streak = 0
			lastShown = -1
			counter.Text = "0 m"
			counter.TextColor3 = WHITE
			counter.Visible = true
			counterScale.Scale = 0.5
			TweenService:Create(counterScale, POP, { Scale = 1 }):Play()
			tapArea.Visible = true
			combo.Visible = false
			if plan.PerfectLaunch then
				showLaunch()
			end
			if type(plan.Special) == "string" then
				showSpecial(plan.Special)
			end
		else
			flightId = nil
			hideFlightBits()
		end
	end)

	Bus.FlightProgress:Connect(function(distance: any)
		if not counter.Visible or type(distance) ~= "number" then
			return
		end
		local whole = math.floor(distance)
		if whole ~= lastShown then
			lastShown = whole
			counter.Text = Format.Meters(distance)
		end
	end)

	Bus.ZoneEntered:Connect(function(zone: any)
		if type(zone) ~= "table" or not HudFlightState.Active then
			return
		end
		local color = if type(zone.Color) == "string" then Color3.fromHex(zone.Color) else WHITE
		-- counter punch
		counterScale.Scale = 1.4
		TweenService:Create(counterScale, POP, { Scale = 1 }):Play()
		counter.TextColor3 = color
		TweenService:Create(counter, TweenInfo.new(0.6), { TextColor3 = WHITE }):Play()
		-- banner slide
		zoneToken += 1
		local token = zoneToken
		zoneName.Text = tostring(zone.Name or "")
		zoneName.TextColor3 = color
		zoneStroke.Color = color
		zoneBanner.Visible = true
		zoneBanner.Position = UDim2.new(-0.4, 0, 0, counterTop + 100)
		TweenService:Create(zoneBanner, SLIDE, { Position = UDim2.new(0.5, 0, 0, counterTop + 100) }):Play()
		task.delay(1.5, function()
			if token ~= zoneToken then
				return
			end
			local out = TweenService:Create(zoneBanner, QUICK, { Position = UDim2.new(1.4, 0, 0, counterTop + 100) })
			out:Play()
			out.Completed:Wait()
			if token == zoneToken then
				zoneBanner.Visible = false
			end
		end)
	end)

	Bus.GustWindow:Connect(function(open: any)
		if open == true and HudFlightState.Active then
			tapPrompt.Visible = true
			tapScale.Scale = 0.4
			TweenService:Create(tapScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			tapPrompt.Visible = false
		end
	end)

	Bus.RingResult:Connect(function(payload: any)
		if type(payload) ~= "table" or (flightId ~= nil and payload.Id ~= flightId) then
			return
		end
		tapPrompt.Visible = false
		if payload.Perfect then
			streak += 1
			combo.Text = "PERFECT x" .. tostring(streak)
			combo.TextColor3 = if streak >= 5 then Color3.fromHex("#FF8FF0") else Theme.Colors.MeterPerfect
			comboAmount.Text = if type(payload.Amount) == "number" and payload.Amount > 0
				then "+" .. Format.Short(payload.Amount) .. " " .. Theme.Icons.Skill
				else ""
			combo.Visible = true
			combo.TextTransparency = 0
			comboAmount.TextTransparency = 0
			comboScale.Scale = 0.5 + math.min(streak, 6) * 0.05
			TweenService:Create(comboScale, POP, { Scale = 1 + math.min(streak, 6) * 0.04 }):Play()
			comboToken += 1
			local token = comboToken
			task.delay(1.2, function()
				if token ~= comboToken then
					return
				end
				TweenService:Create(combo, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				local fade = TweenService:Create(comboAmount, TweenInfo.new(0.3), { TextTransparency = 1 })
				fade:Play()
				fade.Completed:Wait()
				if token == comboToken then
					combo.Visible = false
				end
			end)
		else
			streak = 0
		end
	end)

	Bus.FlightLanded:Connect(function(payload: any)
		if type(payload) ~= "table" or payload.UserId ~= localPlayer.UserId then
			return
		end
		-- the landing card takes over from the counter
		tapPrompt.Visible = false
		zoneBanner.Visible = false
		tapArea.Visible = false
		if payload.Cancelled then
			hideFlightBits()
		else
			task.delay(0.15, function()
				if flightId == nil or flightId == payload.Id then
					counter.Visible = false
				end
			end)
		end
	end)

	return self :: FlightOverlay
end

return HudFlightOverlay
