--!strict
-- ON/OFF pill switch for settings: green gradient track when on, grey when off, a white knob that
-- slides across, and a stroked ON/OFF label. Clicking flips it and calls OnChanged; Set() updates
-- it from data without firing. Gamepad-selectable, 60 px tall by default.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local AudioController = require(UI.Parent.Controllers.AudioController)

export type ToggleProps = {
	Parent: Instance,
	Name: string?,
	Value: boolean,
	Size: Vector2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	OnChanged: (boolean) -> (),
}

export type Toggle = {
	Instance: TextButton,
	Value: boolean,
	Set: (Toggle, boolean) -> (),
}

local MenuToggle = {}

local SLIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ON = Theme.Buttons.Green
local OFF = Theme.Buttons.Disabled

function MenuToggle.new(props: ToggleProps): Toggle
	local size = props.Size or Vector2.new(140, 62)
	local root: TextButton = Create("TextButton", {
		Name = props.Name or "Toggle",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		LayoutOrder = props.LayoutOrder or 0,
	})
	Create.Round(root)
	local gradient = Create.Gradient(root, ON.Top, ON.Bottom, 90)
	local border = Create.Stroke(root, ON.Border, 3, 0, true)

	local knobSize = size.Y - 12
	local knob: Frame = Create("Frame", {
		Name = "Knob",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(knobSize, knobSize),
		Position = UDim2.new(0, 6, 0.5, 0),
		ZIndex = 3,
		Parent = root,
	})
	Create.Round(knob)
	Create.Gradient(knob, Color3.new(1, 1, 1), Color3.fromHex("#D6DEEA"), 90)
	Create.Stroke(knob, Theme.Colors.Stroke, 2.5, 0, true)
	local label = Create.Text({
		Name = "Label",
		Text = "ON",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -knobSize - 24, 0.62, 0),
		Position = UDim2.new(0, 12, 0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 28,
		Scaled = true,
		Stroke = 2.2,
		ZIndex = 2,
		Parent = root,
	})

	local self = {
		Instance = root,
		Value = props.Value,
	} :: any

	local function render(animate: boolean)
		local on = self.Value
		local style = if on then ON else OFF
		gradient.Color = ColorSequence.new(style.Top, style.Bottom)
		border.Color = style.Border
		label.Text = if on then "ON" else "OFF"
		label.Position = if on then UDim2.new(0, 12, 0.5, 0) else UDim2.new(0, knobSize + 12, 0.5, 0)
		local target = if on then UDim2.new(1, -knobSize - 6, 0.5, 0) else UDim2.new(0, 6, 0.5, 0)
		if animate then
			TweenService:Create(knob, SLIDE, { Position = target }):Play()
		else
			knob.Position = target
		end
	end

	function self.Set(this: any, value: boolean)
		if this.Value == value then
			return
		end
		this.Value = value
		render(true)
	end

	root.Activated:Connect(function()
		self.Value = not self.Value
		render(true)
		AudioController.Play("Click")
		props.OnChanged(self.Value)
	end)

	render(false)
	root.Parent = props.Parent
	return self :: Toggle
end

return MenuToggle
