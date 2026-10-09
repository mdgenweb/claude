--!strict
-- Shop-style offer card: blue gradient face with a coloured border, a glowing emoji plate in the
-- accent colour, a chunky stroked title, an accent subtitle ("+10K Skill"), a wrapped
-- description and a full-width action button pinned to the bottom (>= 60 px tall). A tilted
-- corner badge shows states such as OWNED / BEST VALUE. Fills whatever cell it is parented to.
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Button = require(script.Parent.Button)

export type CardProps = {
	Parent: Instance,
	Name: string?,
	LayoutOrder: number?,
	Size: UDim2?, -- default fills the grid cell
	Accent: Color3,
	Rainbow: boolean?, -- rainbow border + plate (top-tier offers)
	Icon: string,
	Title: string,
	Subtitle: string?,
	Description: string?,
	ButtonText: string?, -- nil = no action button
	ButtonStyle: string?,
	OnClick: (() -> ())?,
}

export type Card = {
	Instance: Frame,
	Button: Button.Button?,
	SetTitle: (Card, string) -> (),
	SetSubtitle: (Card, string) -> (),
	SetDescription: (Card, string) -> (),
	SetIcon: (Card, string) -> (),
	SetBadge: (Card, string?, Color3?) -> (),
	SetAction: (Card, text: string, style: string, enabled: boolean) -> (),
}

local MenuCard = {}

local function shade(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function tint(c: Color3, f: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), f)
end

function MenuCard.new(props: CardProps): Card
	local accent = props.Accent
	local root: Frame = Create("Frame", {
		Name = props.Name or "Card",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size or UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder or 0,
	})
	Create.Corner(16, root)
	Create.Gradient(root, Theme.Colors.Card, Theme.Colors.CardDeep, 90)
	local border = Create.Stroke(root, if props.Rainbow then Color3.new(1, 1, 1) else accent, 3, 0, true)
	if props.Rainbow then
		local g = Instance.new("UIGradient")
		g.Color = Theme.Rainbow
		g.Rotation = 45
		g.Parent = border
	end

	-- accent glow behind the icon
	local glow: Frame = Create("Frame", {
		Name = "Glow",
		BackgroundColor3 = accent,
		Size = UDim2.new(1, 0, 0, 130),
		Parent = root,
	})
	Create.Corner(16, glow)
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Rotation = 90
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Parent = glow

	local plate: Frame = Create("Frame", {
		Name = "Plate",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(92, 92),
		Rotation = -4,
		Parent = root,
	})
	Create.Corner(22, plate)
	if props.Rainbow then
		local g = Instance.new("UIGradient")
		g.Color = Theme.Rainbow
		g.Rotation = 45
		g.Parent = plate
	else
		Create.Gradient(plate, tint(accent, 0.35), shade(accent, 0.6), 90)
	end
	Create.Stroke(plate, Theme.Colors.Stroke, 3, 0, true)
	local icon = Create.Text({
		Name = "Icon",
		Text = props.Icon,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.74, 0.74),
		Font = Theme.Fonts.Display,
		TextSize = 64,
		Scaled = true,
		Parent = plate,
	})
	icon.Rotation = 4

	local title = Create.Text({
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(10, 114),
		Size = UDim2.new(1, -20, 0, 36),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		Stroke = 2.6,
		Parent = root,
	})
	local subtitle = Create.Text({
		Name = "Subtitle",
		Text = props.Subtitle or "",
		Position = UDim2.fromOffset(10, 150),
		Size = UDim2.new(1, -20, 0, 26),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Color = tint(accent, 0.25),
		Stroke = 2,
		Parent = root,
	})
	subtitle.Visible = (props.Subtitle or "") ~= ""
	local hasButton = props.ButtonText ~= nil
	local descTop = if subtitle.Visible then 180 else 156
	local description = Create.Text({
		Name = "Description",
		Text = props.Description or "",
		Position = UDim2.fromOffset(14, descTop),
		Size = UDim2.new(1, -28, 1, -descTop - (if hasButton then 84 else 14)),
		Font = Theme.Fonts.Body,
		TextSize = 19,
		Scaled = true,
		Wrapped = true,
		Color = Theme.Colors.TextDim,
		Stroke = 1,
		YAlign = Enum.TextYAlignment.Top,
		Parent = root,
	})

	local action: Button.Button? = nil
	if hasButton then
		action = Button.new({
			Parent = root,
			Name = "Action",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -24, 0, 62),
			Style = props.ButtonStyle or "Green",
			Text = props.ButtonText,
			TextSize = 30,
			Corner = 12,
			OnClick = props.OnClick,
		})
	end

	-- tilted corner badge (OWNED, BEST VALUE, TEST ...)
	local badge: Frame = Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = Theme.Colors.Success,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.fromOffset(126, 36),
		Rotation = 8,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Create.Corner(10, badge)
	Create.Stroke(badge, Theme.Colors.Stroke, 2.5, 0, true)
	local badgeText = Create.Text({
		Name = "Text",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -6),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Stroke = 2,
		ZIndex = 6,
		Parent = badge,
	})

	root.Parent = props.Parent

	local self = {
		Instance = root,
		Button = action,
	} :: any

	function self.SetTitle(_: any, text: string)
		title.Text = text
	end
	function self.SetSubtitle(_: any, text: string)
		subtitle.Text = text
	end
	function self.SetDescription(_: any, text: string)
		description.Text = text
	end
	function self.SetIcon(_: any, text: string)
		icon.Text = text
	end
	function self.SetBadge(_: any, text: string?, color: Color3?)
		if text == nil or text == "" then
			badge.Visible = false
			return
		end
		badge.Visible = true
		badgeText.Text = text
		badge.BackgroundColor3 = color or Theme.Colors.Success
	end
	function self.SetAction(_: any, text: string, style: string, enabled: boolean)
		local b = action
		if b == nil then
			return
		end
		b:SetText(text)
		b:SetStyle(style)
		b:SetEnabled(enabled)
	end

	return self :: Card
end

return MenuCard
