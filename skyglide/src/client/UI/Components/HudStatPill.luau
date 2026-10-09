--!strict
-- Bottom-left HUD counter pill: round emoji badge on the left, chunky stroked value text on a
-- dark translucent pill. Bump() pops it when the value goes up.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

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
	Value: TextLabel,
	SetText: (Pill, string) -> (),
	Bump: (Pill) -> (),
}

local HudStatPill = {}

local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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
	Create.Text({
		Name = "Icon",
		Text = props.Icon,
		Size = UDim2.fromScale(0.68, 0.68),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 40,
		Scaled = true,
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

	local self = { Instance = root, Value = value } :: any

	function self.SetText(_: any, text: string)
		if value.Text ~= text then
			value.Text = text
		end
	end

	function self.Bump(_: any)
		scale.Scale = 1.12
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end

	return self :: Pill
end

return HudStatPill
