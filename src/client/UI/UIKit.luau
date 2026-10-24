-- UI kit for the chunky simulator look (docs/DESIGN_SYSTEM.md):
-- vertical gradients, thick ink outlines, glossy shine strip, hard drop shadow,
-- white cartoon type with ink stroke, and springy hover/press animations.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local Sound = require(script.Parent.Parent.Controllers.Sound)

local UIKit = {}

UIKit.Theme = Theme

UIKit.reducedMotion = false
pcall(function()
	UIKit.reducedMotion = (GuiService :: any).ReducedMotionEnabled == true
end)

-- Instances --------------------------------------------------------------------

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if inst:IsA("GuiObject") and (props == nil or props.BorderSizePixel == nil) then
		inst.BorderSizePixel = 0
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius.M), Parent = parent })
end

function UIKit.stroke(parent: Instance, thickness: number?, color: Color3?, border: boolean?): UIStroke
	return UIKit.new("UIStroke", {
		Thickness = thickness or Theme.Stroke.Chunky,
		Color = color or Theme.Ink,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIKit.gradient(parent: Instance, swatch: Theme.Swatch, rotation: number?): UIGradient
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(swatch.Top, swatch.Bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UIKit.setSwatch(gradient: UIGradient, swatch: Theme.Swatch)
	gradient.Color = ColorSequence.new(swatch.Top, swatch.Bottom)
end

function UIKit.padding(parent: Instance, all: number, top: number?): UIPadding
	return UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, top or all),
		PaddingBottom = UDim.new(0, all),
		Parent = parent,
	})
end

function UIKit.list(
	parent: Instance,
	vertical: boolean,
	gap: number,
	align: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- Text with an ink outline. `TextSize` is the maximum; long text shrinks to fit.
function UIKit.text(parent: Instance?, props: { [string]: any }): TextLabel
	local size = props.TextSize or Theme.Text.Body
	local label = UIKit.new("TextLabel", {
		Name = props.Name or "Text",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Font = props.Font or Theme.Font.Display,
		Text = props.Text or "",
		TextColor3 = props.Color or Theme.White,
		TextScaled = true,
		TextWrapped = props.Wrap ~= false,
		RichText = props.RichText or false,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Rotation = props.Rotation or 0,
		Parent = parent,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = math.min(10, size), Parent = label })
	if props.Stroke ~= false then
		UIKit.stroke(label, props.StrokeThickness or Theme.strokeFor(size), props.StrokeColor)
	end
	return label
end

-- Emoji icon (no outline; emoji keep their own colors).
function UIKit.icon(parent: Instance?, emoji: string, size: UDim2?, position: UDim2?, anchor: Vector2?): TextLabel
	return UIKit.new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = size or UDim2.fromScale(1, 1),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		Font = Theme.Font.Body,
		Text = emoji,
		TextScaled = true,
		TextColor3 = Theme.White,
		Parent = parent,
	})
end

-- Motion ------------------------------------------------------------------------

function UIKit.tween(
	inst: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

function UIKit.scaleOf(gui: Instance): UIScale
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = UIKit.new("UIScale", { Parent = gui })
	end
	return s :: UIScale
end

-- Quick "boing": shrink then spring back.
function UIKit.pop(gui: GuiObject, amount: number?)
	local s = UIKit.scaleOf(gui)
	if UIKit.reducedMotion then
		return
	end
	s.Scale = 1 + (amount or 0.18)
	UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Gentle idle bob for featured buttons.
function UIKit.bob(gui: GuiObject, pixels: number?, period: number?)
	if UIKit.reducedMotion then
		return
	end
	local base = gui.Position
	local offset = pixels or 4
	local t = TweenService:Create(
		gui,
		TweenInfo.new((period or 1.6) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = base + UDim2.fromOffset(0, -offset) }
	)
	t:Play()
	return t
end

function UIKit.shake(gui: GuiObject)
	local base = gui.Rotation
	task.spawn(function()
		for _, r in { -6, 6, -4, 4, 0 } do
			gui.Rotation = base + r
			task.wait(0.04)
		end
		gui.Rotation = base
	end)
end

-- Chunky surface --------------------------------------------------------------------
-- holder (transparent, sized) > Shadow (ink, offset down) + Face (gradient, outline, shine)

export type Surface = { Holder: Frame, Face: GuiObject, Gradient: UIGradient, Shadow: Frame }

function UIKit.surface(parent: Instance?, props: { [string]: any }): Surface
	local radius = props.Radius or Theme.Radius.M
	local holder = UIKit.new("Frame", {
		Name = props.Name or "Surface",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(120, 60),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	local shadow = UIKit.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, props.ShadowOffset or Theme.ShadowOffset),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	UIKit.corner(shadow, radius)
	local face = UIKit.new(props.Button and "TextButton" or "Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	if props.Button then
		face.Text = ""
		face.AutoButtonColor = false
	end
	UIKit.corner(face, radius)
	UIKit.stroke(face, props.StrokeThickness or Theme.Stroke.Chunky, Theme.Ink, true)
	local gradient = UIKit.gradient(face, props.Swatch or Theme.Swatch.Navy)
	if props.Shine ~= false then
		local shine = UIKit.new("Frame", {
			Name = "Shine",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.78,
			Size = UDim2.new(1, -10, 0.42, -4),
			Position = UDim2.fromOffset(5, 4),
			ZIndex = holder.ZIndex,
			Parent = face,
		})
		UIKit.corner(shine, math.max(radius - 4, 4))
	end
	return { Holder = holder, Face = face, Gradient = gradient, Shadow = shadow }
end

-- Buttons ---------------------------------------------------------------------------

export type Button = {
	Holder: Frame,
	Face: TextButton,
	Label: TextLabel?,
	Icon: TextLabel?,
	Gradient: UIGradient,
	SetText: (self: Button, text: string) -> (),
	SetSwatch: (self: Button, swatch: Theme.Swatch) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	Enabled: boolean,
}

local function attachMotion(holder: Frame, face: GuiButton, isEnabled: () -> boolean)
	local scale = UIKit.scaleOf(holder)
	local hovering = false
	local m = Theme.Motion
	face.MouseEnter:Connect(function()
		hovering = true
		if not isEnabled() or UIKit.reducedMotion then
			return
		end
		UIKit.tween(scale, m.Hover, { Scale = m.HoverScale }, Enum.EasingStyle.Back)
		UIKit.tween(holder, m.Hover, { Rotation = m.HoverTilt }, Enum.EasingStyle.Back)
	end)
	face.MouseLeave:Connect(function()
		hovering = false
		UIKit.tween(scale, m.Hover, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(holder, m.Hover, { Rotation = 0 })
		UIKit.tween(face, m.Press, { Position = UDim2.new() })
	end)
	face.MouseButton1Down:Connect(function()
		if not isEnabled() then
			return
		end
		UIKit.tween(scale, m.Press, { Scale = m.PressScale })
		UIKit.tween(face, m.Press, { Position = UDim2.fromOffset(0, 3) })
	end)
	face.MouseButton1Up:Connect(function()
		UIKit.tween(
			scale,
			m.Release,
			{ Scale = if hovering and not UIKit.reducedMotion then m.HoverScale else 1 },
			Enum.EasingStyle.Back
		)
		UIKit.tween(face, m.Release, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	end)
end

-- Rectangular button with optional emoji icon on the left.
function UIKit.button(parent: Instance?, props: { [string]: any }): Button
	local surface = UIKit.surface(parent, {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Swatch = props.Swatch or Theme.Swatch.Green,
		Radius = props.Radius,
		ZIndex = props.ZIndex,
		Button = true,
	})
	local face = surface.Face :: TextButton
	local textSize = props.TextSize or Theme.Text.H2
	local iconLabel
	if props.Icon then
		iconLabel = UIKit.icon(
			face,
			props.Icon,
			UDim2.new(0, textSize * 1.3, 0.8, 0),
			UDim2.new(0, 8, 0.5, 0),
			Vector2.new(0, 0.5)
		)
	end
	local label
	if props.Text then
		local left = if props.Icon then textSize * 1.3 + 10 else 8
		label = UIKit.text(face, {
			Name = "Label",
			Text = props.Text,
			TextSize = textSize,
			Size = UDim2.new(1, -left - 8, 0.86, 0),
			Position = UDim2.new(0, left, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Font = props.Font or Theme.Font.Display,
			RichText = props.RichText,
		})
	end
	local swatch = props.Swatch or Theme.Swatch.Green
	local button = {
		Holder = surface.Holder,
		Face = face,
		Label = label,
		Icon = iconLabel,
		Gradient = surface.Gradient,
		Enabled = props.Enabled ~= false,
	}
	function button.SetText(_, value: string)
		if label then
			label.Text = value
		end
	end
	function button.SetSwatch(_, value: Theme.Swatch)
		swatch = value
		if button.Enabled then
			UIKit.setSwatch(surface.Gradient, value)
		end
	end
	function button.SetEnabled(_, enabled: boolean)
		button.Enabled = enabled
		UIKit.setSwatch(surface.Gradient, if enabled then swatch else Theme.Swatch.Steel)
	end
	button:SetEnabled(button.Enabled)
	attachMotion(surface.Holder, face, function()
		return button.Enabled
	end)
	face.Activated:Connect(function()
		if not button.Enabled then
			UIKit.shake(surface.Holder)
			if props.OnDisabledClick then
				props.OnDisabledClick()
			end
			return
		end
		if props.Sound ~= false then
			Sound.play("Click")
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	return button :: any
end

-- Square menu button: big emoji, label overlapping the bottom edge, optional badge.
function UIKit.iconButton(parent: Instance?, props: { [string]: any })
	local size = props.SizePx or 78
	local surface = UIKit.surface(parent, {
		Name = props.Name or "IconButton",
		Size = UDim2.fromOffset(size, size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Swatch = props.Swatch,
		Radius = Theme.Radius.L,
		Button = true,
	})
	local face = surface.Face :: TextButton
	local icon =
		UIKit.icon(face, props.Icon, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.5, 0.42), Vector2.new(0.5, 0.5))
	local label = UIKit.text(surface.Holder, {
		Name = "Label",
		Text = props.Text,
		TextSize = 20,
		Size = UDim2.new(1, 24, 0, 24),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
	})
	local badge = UIKit.badge(surface.Holder)
	local enabled = true
	attachMotion(surface.Holder, face, function()
		return enabled
	end)
	face.Activated:Connect(function()
		Sound.play("Click")
		if props.OnClick then
			props.OnClick()
		end
	end)
	return {
		Holder = surface.Holder,
		Face = face,
		Icon = icon,
		Label = label,
		Badge = badge,
		Gradient = surface.Gradient,
	}
end

-- Red "!" notification dot with a pulse.
function UIKit.badge(parent: Instance)
	local dot = UIKit.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -6, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	UIKit.corner(dot, 14)
	UIKit.stroke(dot, 2.5, Theme.Ink, true)
	UIKit.gradient(dot, Theme.Swatch.Red)
	local label = UIKit.text(dot, { Text = "!", TextSize = 20, ZIndex = 6 })
	local scale = UIKit.scaleOf(dot)
	local pulse
	local badge = {}
	function badge.Set(_, visible: boolean, text: string?)
		label.Text = text or "!"
		if visible == dot.Visible then
			return
		end
		dot.Visible = visible
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		if visible and not UIKit.reducedMotion then
			scale.Scale = 1
			pulse = TweenService:Create(
				scale,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.18 }
			)
			pulse:Play()
		end
	end
	return badge
end

-- Pill progress bar with centred text.
function UIKit.progress(parent: Instance?, props: { [string]: any })
	local track = UIKit.new("Frame", {
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.fromOffset(240, 26),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Theme.Swatch.Navy.Deep,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	UIKit.corner(track, 999)
	UIKit.stroke(track, 2.5, Theme.Ink, true)
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	UIKit.corner(fill, 999)
	local gradient = UIKit.gradient(fill, props.Swatch or Theme.Swatch.Green)
	local label = UIKit.text(track, {
		Text = "",
		TextSize = props.TextSize or 16,
		Size = UDim2.new(1, -12, 1, -4),
		Position = UDim2.fromOffset(6, 2),
		ZIndex = 2,
	})
	local bar = { Frame = track, Label = label }
	function bar.Set(_, ratio: number, text: string?, swatch: Theme.Swatch?)
		ratio = math.clamp(ratio, 0, 1)
		UIKit.tween(fill, 0.25, { Size = UDim2.fromScale(ratio, 1) })
		fill.Visible = ratio > 0.001
		label.Text = text or ""
		if swatch then
			UIKit.setSwatch(gradient, swatch)
		end
	end
	return bar
end

-- Rotating light rays behind featured icons.
function UIKit.sunburst(parent: Instance, color: Color3?, rays: number?, zIndex: number?)
	local holder = UIKit.new("Frame", {
		Name = "Sunburst",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1.6, 1.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = zIndex or 1,
		Parent = parent,
	})
	UIKit.new("UIAspectRatioConstraint", { Parent = holder })
	local count = rays or 8
	for i = 1, count do
		UIKit.new("Frame", {
			Name = "Ray",
			BackgroundColor3 = color or Color3.new(1, 1, 1),
			BackgroundTransparency = 0.72,
			Size = UDim2.fromScale(0.12, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = (i - 1) * (180 / count),
			ZIndex = zIndex or 1,
			Parent = holder,
		})
	end
	if not UIKit.reducedMotion then
		TweenService
			:Create(
				holder,
				TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			)
			:Play()
	end
	return holder
end

-- Small rounded chip ("OWNED", "x2", "NEW FORM").
function UIKit.chip(parent: Instance?, props: { [string]: any })
	local surface = UIKit.surface(parent, {
		Name = props.Name or "Chip",
		Size = props.Size or UDim2.fromOffset(90, 28),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Swatch = props.Swatch or Theme.Swatch.Green,
		Radius = 999,
		ShadowOffset = 3,
		StrokeThickness = 2.5,
		Shine = false,
		ZIndex = props.ZIndex,
	})
	local label = UIKit.text(surface.Face, {
		Text = props.Text or "",
		TextSize = props.TextSize or 16,
		Size = UDim2.new(1, -10, 1, -4),
		Position = UDim2.fromOffset(5, 2),
		ZIndex = props.ZIndex,
	})
	return { Holder = surface.Holder, Label = label, Gradient = surface.Gradient }
end

return UIKit
