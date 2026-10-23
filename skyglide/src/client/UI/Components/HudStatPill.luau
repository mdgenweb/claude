--!strict
-- Bottom-left HUD counter pill: round emoji badge on the left, chunky stroked value text on a
-- dark translucent pill. Bump() pops it when the value goes up; SetValue can count up to a new
-- value after a delay (rewards flying into the counter land first, then the number rolls up).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Icon = require(script.Parent.Icon)

export type PillProps = {
	Parent: Instance,
	Name: string,
	Icon: string,
	Color: Color3, -- value text colour
	Badge: Color3, -- icon circle colour
	Width: number?,
	Height: number?,
	LayoutOrder: number?,
}

export type Pill = {
	Instance: Frame,
	Badge: Frame,
	Value: TextLabel,
	SetText: (Pill, string) -> (),
	SetValue: (Pill, number, (number) -> string, number?) -> (),
	Bump: (Pill) -> (),
}

local HudStatPill = {}

local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local COUNT_TIME = 0.7

function HudStatPill.new(props: PillProps): Pill
	local height = props.Height or 52
	local root: Frame = Create("Frame", {
		Name = props.Name,
		Size = UDim2.fromOffset(props.Width or 250, height),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.25,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Create.Round(root)
	Create.Stroke(root, Theme.Colors.Stroke, 2.5, 0.1, true)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local badge: Frame = Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -4, 0.5, 0),
		Size = UDim2.fromOffset(height + 6, height + 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = root,
	})
	Create.Round(badge)
	Create.Gradient(badge, props.Badge:Lerp(Color3.new(1, 1, 1), 0.35), props.Badge, 90)
	Create.Stroke(badge, Theme.Colors.Stroke, 3, 0, true)
	Icon.new({
		Icon = props.Icon,
		Name = "Icon",
		Size = UDim2.fromScale(0.74, 0.74),
		TextSize = 40,
		ZIndex = 3,
		Parent = badge,
	})
	local value = Create.Text({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -(height + 18), 0.86, 0),
		Position = UDim2.new(0, height + 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 34,
		Scaled = true,
		Color = props.Color,
		Stroke = 3,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = root,
	})

	local self = { Instance = root, Badge = badge, Value = value } :: any

	local function show(text: string)
		if value.Text ~= text then
			value.Text = text
		end
	end
	function self.SetText(_: any, text: string)
		show(text)
	end

	-- Numeric counters: with a delay and a higher value, the text holds, then rolls up (ease-out)
	-- over COUNT_TIME; anything else (first value, a drop, no delay) shows at once. A sync that
	-- repeats the value being counted to leaves the roll alone.
	local shown: number? = nil
	local from, target, startAt = 0, 0, 0
	local format: (number) -> string = tostring
	local rolling: RBXScriptConnection? = nil
	local function stopRoll()
		if rolling then
			rolling:Disconnect()
			rolling = nil
		end
	end
	function self.SetValue(_: any, n: number, fmt: (number) -> string, delay: number?)
		format = fmt
		if rolling and n == target then
			return
		end
		local current = shown
		if current == nil or delay == nil or n <= current then
			stopRoll()
			shown, target = n, n
			show(fmt(n))
			return
		end
		from, target, startAt = current, n, os.clock() + delay
		if rolling then
			return
		end
		rolling = RunService.Heartbeat:Connect(function()
			local a = (os.clock() - startAt) / COUNT_TIME
			if a < 0 then
				return
			end
			if a >= 1 then
				stopRoll()
				shown = target
				show(format(target))
				return
			end
			local v = from + (target - from) * (1 - (1 - a) ^ 3)
			shown = v
			show(format(math.floor(v)))
		end)
	end

	function self.Bump(_: any)
		scale.Scale = 1.12
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end

	return self :: Pill
end

return HudStatPill
