--!strict
-- Square HUD menu tile (left grid, right offers) in the simulator style: a bright gradient face
-- with a thick dark outline and gloss, raised on a darker base (pressing sinks it), big emoji
-- icon, chunky stroked label, optional caption over the icon ("83%"), a red count badge, a gold
-- "ready" glow, an attention wiggle (e.g. gifts waiting), an optional glint sweep and an optional
-- hover tooltip. The HUD ticker drives the glow and wiggle through Animate. Gamepad-selectable;
-- hover grows it, thickens the outline and wiggles the icon.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Shine = require(script.Parent.Shine)
local Tooltip = require(script.Parent.Tooltip)
local Icon = require(script.Parent.Icon)
local AudioController = require(UI.Parent.Controllers.AudioController)

export type TileProps = {
	Parent: Instance,
	Name: string,
	Icon: string,
	Label: string?,
	Size: number?, -- side in design px (default 92), base included
	Top: Color3,
	Bottom: Color3,
	LayoutOrder: number?,
	Round: boolean?,
	Shine: boolean?,
	Tooltip: { Title: string, Text: string, Beside: GuiObject? }?,
	OnClick: () -> (),
}

export type Tile = {
	Instance: TextButton,
	Face: Frame,
	Icon: GuiObject, -- 3D icon image (emoji until uploaded), see Components/Icon
	Label: TextLabel?,
	SetBadge: (Tile, number) -> (),
	SetCaption: (Tile, string?) -> (),
	SetGlow: (Tile, boolean) -> (),
	SetAttention: (Tile, boolean) -> (),
	Animate: (Tile, number) -> (),
	Glowing: boolean,
	Attention: boolean,
}

local HudTile = {}

local QUICK = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GOLD = Color3.fromHex("#FFD447")
local GOLD_HOT = Color3.fromHex("#FFF6C2")
local WIGGLE_EVERY = 2.4 -- seconds between attention wiggles
local WIGGLE_TIME = 0.6
local HOVER_WIGGLE = TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true)
-- Inner shadow: the lower part of a face darkens toward its bottom edge (depth under the gloss).
local INNER_SHADOW = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0.7),
})

function HudTile.new(props: TileProps): Tile
	local side = props.Size or 92
	local depth = Theme.Depth
	local function rounding(target: GuiObject, radius: number)
		if props.Round then
			Create.Round(target)
		else
			Create.Corner(radius, target)
		end
	end

	local root: TextButton = Create("TextButton", {
		Name = props.Name,
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		LayoutOrder = props.LayoutOrder or 0,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local base: Frame = Create("Frame", {
		Name = "Base",
		BackgroundColor3 = Theme.Darken(props.Bottom, 0.5),
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.new(1, 0, 1, -depth),
		Parent = root,
	})
	rounding(base, 16)
	Create.Stroke(base, Theme.Colors.Stroke, Theme.Outline, 0, true)

	local face: Frame = Create("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = 2,
		Parent = root,
	})
	rounding(face, 16)
	Create.Gradient(face, props.Top, props.Bottom, 90)
	local border = Create.Stroke(face, Theme.Colors.Stroke, Theme.Outline, 0, true)

	local gloss: Frame = Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Size = UDim2.new(1, -10, 0.42, 0),
		Position = UDim2.fromOffset(5, 4),
		Parent = face,
	})
	rounding(gloss, 12)
	local inner: Frame = Create("Frame", {
		Name = "InnerShadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		Parent = face,
	})
	rounding(inner, 16)
	local innerGradient = Instance.new("UIGradient")
	innerGradient.Rotation = 90
	innerGradient.Transparency = INNER_SHADOW
	innerGradient.Parent = inner
	if props.Shine then
		Shine.Add(face, if props.Round then UDim.new(0.5, 0) else UDim.new(0, 16), 2)
	end

	local hasLabel = props.Label ~= nil and props.Label ~= ""
	local icon = Icon.new({
		Icon = props.Icon,
		Name = "Icon",
		Size = if hasLabel then UDim2.fromScale(0.66, 0.6) else UDim2.fromScale(0.68, 0.68),
		Position = if hasLabel then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.5, 0.5),
		TextSize = 64,
		ZIndex = 3,
		Parent = face,
	})
	local label: TextLabel? = nil
	if hasLabel then
		label = Create.Text({
			Name = "Label",
			Text = props.Label or "",
			Size = UDim2.new(1, 4, 0.3, 0),
			Position = UDim2.new(0.5, 0, 1, -3),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Theme.Fonts.Display,
			TextSize = 24,
			Scaled = true,
			Stroke = 2.8,
			ZIndex = 4,
			Parent = face,
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
		Stroke = 2.8,
		ZIndex = 5,
		Parent = face,
	})
	caption.Visible = false

	local badge: Frame = Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Create.Round(badge)
	Create.Gradient(badge, Color3.fromHex("#FF7A85"), Theme.Colors.Danger, 90)
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
		Stroke = 1.8,
		ZIndex = 6,
		Parent = badge,
	})

	local self = {
		Instance = root,
		Face = face,
		Icon = icon,
		Label = label,
		Glowing = false,
		Attention = false,
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

	local function rest()
		if not self.Glowing then
			border.Color = Theme.Colors.Stroke
			border.Thickness = Theme.Outline
			caption.TextColor3 = Theme.Colors.Text
		end
		if not self.Glowing and not self.Attention then
			icon.Rotation = 0
			badge.Rotation = 0
		end
	end

	function self.SetGlow(this: any, on: boolean)
		if this.Glowing == on then
			return
		end
		this.Glowing = on
		rest()
	end

	function self.SetAttention(this: any, on: boolean)
		if this.Attention == on then
			return
		end
		this.Attention = on
		rest()
	end

	-- Called ~20x per second by the HUD ticker; only does work while glowing or asking for attention.
	function self.Animate(this: any, t: number)
		if this.Glowing then
			local w = (math.sin(t * 6) + 1) / 2
			border.Color = GOLD:Lerp(GOLD_HOT, w)
			border.Thickness = Theme.Outline + w * 2
			icon.Rotation = math.sin(t * 4) * 9
			caption.TextColor3 = GOLD:Lerp(GOLD_HOT, w)
		elseif this.Attention then
			-- a short shake every few seconds, then still (reads as "something is waiting")
			local phase = t % WIGGLE_EVERY
			if phase < WIGGLE_TIME then
				local fade = 1 - phase / WIGGLE_TIME
				icon.Rotation = math.sin(phase * 38) * 14 * fade
				badge.Rotation = math.sin(phase * 38 + 1) * 12 * fade
			elseif icon.Rotation ~= 0 then
				icon.Rotation = 0
				badge.Rotation = 0
			end
		end
	end

	local UP = UDim2.new()
	local DOWN = UDim2.fromOffset(0, depth - 1)
	root.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.07 }):Play()
		if not self.Glowing then
			TweenService:Create(border, QUICK, { Thickness = Theme.Outline + 1.5 }):Play()
			if not self.Attention then
				TweenService:Create(icon, HOVER_WIGGLE, { Rotation = 12 }):Play()
			end
		end
		AudioController.Play("Hover", nil, 0.05)
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
		TweenService:Create(face, QUICK, { Position = UP }):Play()
		if not self.Glowing then
			TweenService:Create(border, QUICK, { Thickness = Theme.Outline }):Play()
		end
	end)
	if props.Tooltip then
		Tooltip.Attach(root, props.Tooltip.Title, props.Tooltip.Text, props.Tooltip.Beside)
	end
	root.MouseButton1Down:Connect(function()
		TweenService:Create(face, QUICK, { Position = DOWN }):Play()
		TweenService:Create(scale, QUICK, { Scale = 0.96 }):Play()
	end)
	root.MouseButton1Up:Connect(function()
		TweenService:Create(face, SPRING, { Position = UP }):Play()
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
