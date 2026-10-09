--!strict
-- Square HUD menu tile (left grid): bright gradient face, big emoji icon, chunky stroked label,
-- optional caption over the icon ("83%"), a red count badge, and a gold "ready" glow that the
-- HUD ticker animates. Gamepad-selectable; hover grows, press squashes.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local AudioController = require(UI.Parent.Controllers.AudioController)

export type TileProps = {
	Parent: Instance,
	Name: string,
	Icon: string,
	Label: string?,
	Size: number?, -- side in design px (default 92)
	Top: Color3,
	Bottom: Color3,
	LayoutOrder: number?,
	Round: boolean?,
	OnClick: () -> (),
}

export type Tile = {
	Instance: TextButton,
	SetBadge: (Tile, number) -> (),
	SetCaption: (Tile, string?) -> (),
	SetGlow: (Tile, boolean) -> (),
	Animate: (Tile, number) -> (),
	Glowing: boolean,
}

local HudTile = {}

local QUICK = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GOLD = Color3.fromHex("#FFD447")
local GOLD_HOT = Color3.fromHex("#FFF6C2")

function HudTile.new(props: TileProps): Tile
	local side = props.Size or 92
	local root: TextButton = Create("TextButton", {
		Name = props.Name,
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		LayoutOrder = props.LayoutOrder or 0,
	})
	if props.Round then
		Create.Round(root)
	else
		Create.Corner(16, root)
	end
	Create.Gradient(root, props.Top, props.Bottom, 90)
	local border = Create.Stroke(root, Theme.Colors.Stroke, 3, 0, true)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local gloss: Frame = Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Size = UDim2.new(1, -10, 0.4, 0),
		Position = UDim2.fromOffset(5, 4),
		Parent = root,
	})
	if props.Round then
		Create.Round(gloss)
	else
		Create.Corner(12, gloss)
	end

	local hasLabel = props.Label ~= nil and props.Label ~= ""
	local icon = Create.Text({
		Name = "Icon",
		Text = props.Icon,
		Size = if hasLabel then UDim2.fromScale(0.66, 0.6) else UDim2.fromScale(0.68, 0.68),
		Position = if hasLabel then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 64,
		Scaled = true,
		ZIndex = 2,
		Parent = root,
	})
	if hasLabel then
		Create.Text({
			Name = "Label",
			Text = props.Label or "",
			Size = UDim2.new(1, 4, 0.3, 0),
			Position = UDim2.new(0.5, 0, 1, -3),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Theme.Fonts.Display,
			TextSize = 24,
			Scaled = true,
			Stroke = 2.5,
			ZIndex = 3,
			Parent = root,
		})
	end
	local caption = Create.Text({
		Name = "Caption",
		Text = "",
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.new(0.5, 0, 0, -4),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		Stroke = 2.5,
		ZIndex = 4,
		Parent = root,
	})
	caption.Visible = false

	local badge: Frame = Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Theme.Colors.Danger,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Create.Round(badge)
	Create.Stroke(badge, Theme.Colors.Stroke, 2.5, 0, true)
	local badgeText = Create.Text({
		Name = "Count",
		Text = "",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 22,
		Scaled = true,
		Stroke = 1.5,
		ZIndex = 6,
		Parent = badge,
	})

	local self = {
		Instance = root,
		Glowing = false,
	} :: any

	function self.SetBadge(_: any, count: number)
		if count <= 0 then
			badge.Visible = false
			return
		end
		local text = if count > 9 then "9+" else tostring(count)
		if not badge.Visible or badgeText.Text ~= text then
			badge.Visible = true
			badgeText.Text = text
			badge.Size = UDim2.fromOffset(22, 22)
			TweenService:Create(badge, SPRING, { Size = UDim2.fromOffset(32, 32) }):Play()
		end
	end

	function self.SetCaption(_: any, text: string?)
		caption.Visible = text ~= nil
		if text and caption.Text ~= text then
			caption.Text = text
		end
	end

	function self.SetGlow(this: any, on: boolean)
		if this.Glowing == on then
			return
		end
		this.Glowing = on
		if not on then
			border.Color = Theme.Colors.Stroke
			border.Thickness = 3
			icon.Rotation = 0
			caption.TextColor3 = Theme.Colors.Text
		end
	end

	-- Called ~20x per second by the HUD ticker; only does work while glowing.
	function self.Animate(this: any, t: number)
		if not this.Glowing then
			return
		end
		local w = (math.sin(t * 6) + 1) / 2
		border.Color = GOLD:Lerp(GOLD_HOT, w)
		border.Thickness = 3 + w * 2
		icon.Rotation = math.sin(t * 4) * 9
		caption.TextColor3 = GOLD:Lerp(GOLD_HOT, w)
	end

	root.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.07 }):Play()
		AudioController.Play("Hover", nil, 0.05)
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	root.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.92 }):Play()
	end)
	root.MouseButton1Up:Connect(function()
		TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
	end)
	root.Activated:Connect(function()
		AudioController.Play("Click")
		props.OnClick()
	end)

	root.Parent = props.Parent
	return self :: Tile
end

return HudTile
