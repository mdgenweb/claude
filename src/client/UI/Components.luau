--!nonstrict
-- UI component library built on Theme tokens (see docs/UI_DESIGN_SYSTEM.md).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PotionModel = require(Shared.Visual.PotionModel)

local Theme = require(script.Parent.Theme)

local C = {}

local soundHandler: ((string) -> ())? = nil
function C.setSoundHandler(fn: (string) -> ())
	soundHandler = fn
end
local function sound(name: string)
	if soundHandler then
		soundHandler(name)
	end
end
C.sound = sound

-- ─────────────────────────────── primitives ───────────────────────────────

function C.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function C.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

function C.corner(parent: Instance, radius: UDim?): UICorner
	return C.new("UICorner", { CornerRadius = radius or Theme.Radius.MD, Parent = parent })
end

function C.stroke(
	parent: Instance,
	color: Color3?,
	thickness: number?,
	transparency: number?,
	border: boolean?
): UIStroke
	return C.new("UIStroke", {
		Color = color or Theme.Color.Stroke.Subtle,
		Thickness = thickness or Theme.Stroke.Default,
		Transparency = transparency or 0,
		ApplyStrokeMode = if border == false then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function C.padding(parent: Instance, all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return C.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
		Parent = parent,
	})
end

function C.list(
	parent: Instance,
	direction: Enum.FillDirection?,
	gap: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	return C.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.Space.SM),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function C.grid(parent: Instance, cell: Vector2, gap: number?): UIGridLayout
	return C.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap or Theme.Space.MD, gap or Theme.Space.MD),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function C.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return C.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

-- Text label using a Theme type token. Outline stroke for readability over the 3D scene.
function C.text(props: { [string]: any }): TextLabel
	local typeToken = Theme.Type[props.type or "Body"]
	local label = C.new("TextLabel", {
		Name = props.name or "Text",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.new(1, 0, 0, typeToken.size + 6),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		Text = props.text or "",
		FontFace = typeToken.font,
		TextSize = props.textSize or typeToken.size,
		TextColor3 = props.color or Theme.Color.Text.Primary,
		TextXAlignment = props.alignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY or Enum.TextYAlignment.Center,
		TextWrapped = props.wrap == true,
		RichText = props.rich == true,
		TextTruncate = if props.truncate then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		AutomaticSize = props.autoSize or Enum.AutomaticSize.None,
		LayoutOrder = props.order or 0,
		ZIndex = props.z or 1,
		Parent = props.parent,
	})
	if props.outline ~= false then
		C.stroke(label, Theme.Color.Text.Outline, props.outlineThickness or 2, props.outlineTransparency or 0.25, false)
	end
	return label
end

function C.frame(props: { [string]: any }): Frame
	local frame = C.new("Frame", {
		Name = props.name or "Frame",
		BackgroundColor3 = props.color or Theme.Color.Surface.Panel,
		BackgroundTransparency = props.transparency or 0,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.order or 0,
		ZIndex = props.z or 1,
		AutomaticSize = props.autoSize or Enum.AutomaticSize.None,
		ClipsDescendants = props.clip == true,
		Visible = props.visible ~= false,
		Parent = props.parent,
	})
	if props.radius ~= false then
		C.corner(frame, props.radius or Theme.Radius.MD)
	end
	if props.stroke then
		C.stroke(frame, props.stroke, props.strokeThickness, props.strokeTransparency)
	end
	return frame
end

-- Glass panel with fake drop shadow (returns outer container, inner panel).
function C.card(props: { [string]: any }): (Frame, Frame)
	local elevation = Theme.Elevation[props.elevation or "E1"]
	local outer = C.new("Frame", {
		Name = props.name or "Card",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromOffset(200, 100),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.order or 0,
		ZIndex = props.z or 1,
		Parent = props.parent,
	})
	local shadow = C.frame({
		name = "Shadow",
		parent = outer,
		color = Color3.new(0, 0, 0),
		transparency = elevation.transparency,
		position = UDim2.fromOffset(0, elevation.offset),
		radius = props.radius,
		z = props.z,
	})
	local _ = shadow
	local inner = C.frame({
		name = "Body",
		parent = outer,
		color = props.color or Theme.Color.Surface.Panel,
		transparency = props.transparency or Theme.Color.PanelTransparency,
		radius = props.radius,
		stroke = props.stroke or Theme.Color.Stroke.Subtle,
		strokeThickness = props.strokeThickness,
		z = props.z,
		clip = props.clip,
	})
	if props.gradient ~= false then
		C.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 195, 235)),
			Rotation = 90,
			Parent = inner,
		})
	end
	return outer, inner
end

-- Springy hover/press behaviour shared by every button.
function C.interactive(button: GuiButton, opts: { [string]: any }?)
	local options = opts or {}
	local scale = button:FindFirstChildOfClass("UIScale") or C.new("UIScale", { Parent = button })
	local base = options.baseScale or 1
	local hovering = false
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		hovering = true
		C.tween(scale, Theme.Motion.Hover, { Scale = base * 1.06 })
		sound("hover")
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		C.tween(scale, Theme.Motion.Hover, { Scale = base })
	end)
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		C.tween(scale, Theme.Motion.Press, { Scale = base * 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		C.tween(scale, Theme.Motion.Release, { Scale = if hovering then base * 1.06 else base })
	end)
	return scale
end

function C.keyBadge(parent: Instance, key: string, z: number?): Frame
	local badge = C.frame({
		name = "KeyBadge",
		parent = parent,
		color = Theme.Color.Surface.Base,
		transparency = 0.1,
		size = UDim2.fromOffset(math.max(24, 12 + #key * 9), 22),
		position = UDim2.new(1, 6, 0, -8),
		anchor = Vector2.new(1, 0),
		radius = Theme.Radius.SM,
		stroke = Theme.Color.Stroke.Gold,
		strokeThickness = 1,
		z = (z or 1) + 3,
	})
	C.text({
		parent = badge,
		text = key,
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		color = Theme.Color.Accent.Gold,
		outline = false,
		z = (z or 1) + 4,
	})
	return badge
end

local VARIANTS = {
	primary = {
		fill = Theme.Color.Accent.Gold,
		fill2 = Theme.Color.Accent.GoldDeep,
		text = Theme.Color.Text.Inverse,
		stroke = Theme.Color.Stroke.Gold,
		outline = false,
	},
	secondary = {
		fill = Theme.Color.Surface.Raised,
		fill2 = Theme.Color.Surface.Panel,
		text = Theme.Color.Text.Primary,
		stroke = Theme.Color.Stroke.Strong,
		outline = true,
	},
	ghost = {
		fill = Theme.Color.Surface.Panel,
		fill2 = Theme.Color.Surface.Panel,
		text = Theme.Color.Text.Secondary,
		stroke = Theme.Color.Stroke.Subtle,
		outline = true,
		transparency = 0.6,
	},
	danger = {
		fill = Theme.Color.State.Danger,
		fill2 = Color3.fromRGB(190, 40, 70),
		text = Theme.Color.Text.Primary,
		stroke = Color3.fromRGB(255, 140, 150),
		outline = true,
	},
}

export type ButtonHandle = {
	button: TextButton,
	label: TextLabel,
	setText: (string) -> (),
	setDisabled: (boolean) -> (),
	setVariant: (string) -> (),
}

function C.Button(props: { [string]: any }): ButtonHandle
	local variantName = props.variant or "secondary"
	local height = Theme.Size.Button[props.size or "md"]
	local button = C.new("TextButton", {
		Name = props.name or "Button",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = props.width and UDim2.fromOffset(props.width, height) or (props.sizeUDim or UDim2.new(1, 0, 0, height)),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.order or 0,
		ZIndex = props.z or 1,
		Parent = props.parent,
	})
	C.corner(button, props.radius or Theme.Radius.MD)
	local stroke = C.stroke(button, nil, Theme.Stroke.Default)
	local gradient = C.new("UIGradient", { Rotation = 90, Parent = button })
	local label = C.text({
		parent = button,
		text = if props.icon then props.icon .. "  " .. (props.text or "") else (props.text or ""),
		type = if props.size == "lg" then "Heading" elseif props.size == "sm" then "Caption" else "Label",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		z = (props.z or 1) + 1,
	})
	label.TextScaled = false
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
	local disabled = false
	local function apply()
		local v = VARIANTS[variantName] or VARIANTS.secondary
		if disabled then
			button.BackgroundColor3 = Theme.Color.State.Disabled
			gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))
			label.TextColor3 = Theme.Color.Text.Muted
			stroke.Color = Theme.Color.Stroke.Subtle
			button.BackgroundTransparency = 0.2
		else
			button.BackgroundColor3 = Color3.new(1, 1, 1)
			gradient.Color = ColorSequence.new(v.fill, v.fill2)
			label.TextColor3 = v.text
			stroke.Color = v.stroke
			button.BackgroundTransparency = v.transparency or 0
		end
		if labelStroke then
			labelStroke.Enabled = v.outline and not disabled
		end
	end
	apply()
	C.interactive(button)
	if props.keybind then
		C.keyBadge(button, props.keybind, props.z)
	end
	button.Activated:Connect(function()
		if disabled then
			sound("error")
			return
		end
		sound("click")
		if props.onClick then
			props.onClick()
		end
	end)
	return {
		button = button,
		label = label,
		setText = function(text: string)
			label.Text = if props.icon then props.icon .. "  " .. text else text
		end,
		setDisabled = function(value: boolean)
			disabled = value
			button:SetAttribute("Disabled", value or nil)
			apply()
		end,
		setVariant = function(name: string)
			variantName = name
			apply()
		end,
	}
end

export type IconButtonHandle = {
	button: TextButton,
	setActive: (boolean) -> (),
	setIcon: (string) -> (),
	setCaption: (string) -> (),
	setBadge: (string?) -> (),
}

function C.IconButton(props: { [string]: any }): IconButtonHandle
	local size = props.sizePx or Theme.Size.IconButton
	local button = C.new("TextButton", {
		Name = props.name or "IconButton",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Color.Surface.Panel,
		BackgroundTransparency = Theme.Color.PanelTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.order or 0,
		ZIndex = props.z or 1,
		Parent = props.parent,
	})
	C.corner(button, Theme.Radius.LG)
	local stroke = C.stroke(button, Theme.Color.Stroke.Strong, Theme.Stroke.Default)
	C.gradient(button, Theme.Color.Surface.Raised, Theme.Color.Surface.Panel)
	local icon = C.text({
		parent = button,
		name = "Icon",
		text = props.icon or "?",
		type = "Heading",
		textSize = math.floor(size * 0.42),
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 1, if props.caption then -16 else 0),
		outline = false,
		z = (props.z or 1) + 1,
	})
	local caption
	if props.caption then
		caption = C.text({
			parent = button,
			name = "Caption",
			text = props.caption,
			type = "Caption",
			textSize = 12,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 16),
			position = UDim2.new(0, 0, 1, -19),
			color = Theme.Color.Text.Secondary,
			z = (props.z or 1) + 1,
		})
	end
	local glow = C.new("UIGradient", {
		Color = ColorSequence.new(Theme.Color.Accent.Gold, Theme.Color.Accent.GoldDeep),
		Rotation = 90,
		Enabled = false,
	})
	glow.Parent = button
	local badge: Frame? = nil
	local badgeLabel: TextLabel? = nil
	C.interactive(button)
	if props.keybind then
		C.keyBadge(button, props.keybind, props.z)
	end
	button.Activated:Connect(function()
		sound("click")
		if props.onClick then
			props.onClick()
		end
	end)
	if props.tooltip then
		button.MouseEnter:Connect(function()
			C.showTooltip(props.tooltip, props.tooltipBody, nil)
		end)
		button.MouseLeave:Connect(function()
			C.hideTooltip()
		end)
	end
	return {
		button = button,
		setActive = function(active: boolean)
			stroke.Color = if active then Theme.Color.Stroke.Gold else Theme.Color.Stroke.Strong
			stroke.Thickness = if active then Theme.Stroke.Emphasis else Theme.Stroke.Default
			button.BackgroundColor3 = if active then Theme.Color.Accent.GoldDeep else Theme.Color.Surface.Panel
			button.BackgroundTransparency = if active then 0.35 else Theme.Color.PanelTransparency
		end,
		setIcon = function(text: string)
			icon.Text = text
		end,
		setCaption = function(text: string)
			if caption then
				caption.Text = text
			end
		end,
		setBadge = function(text: string?)
			if not text then
				if badge then
					badge.Visible = false
				end
				return
			end
			local current = badge
			if not current then
				current = C.frame({
					name = "Badge",
					parent = button,
					color = Theme.Color.Accent.Magenta,
					size = UDim2.fromOffset(24, 24),
					position = UDim2.new(0, -6, 0, -6),
					radius = Theme.Radius.Pill,
					z = (props.z or 1) + 5,
				})
				badge = current
				badgeLabel = C.text({
					parent = current,
					text = text,
					type = "Caption",
					alignX = Enum.TextXAlignment.Center,
					size = UDim2.fromScale(1, 1),
					z = (props.z or 1) + 6,
				})
			end
			current.Visible = true
			if badgeLabel then
				badgeLabel.Text = text
			end
		end,
	}
end

-- Small pill with an icon and value (coins, flasks...).
function C.Pill(props: { [string]: any }): (Frame, TextLabel)
	local pill = C.frame({
		name = props.name or "Pill",
		parent = props.parent,
		color = Theme.Color.Surface.Sunken,
		transparency = 0.15,
		size = props.size or UDim2.fromOffset(150, 38),
		position = props.position,
		anchor = props.anchor,
		radius = Theme.Radius.Pill,
		stroke = props.stroke or Theme.Color.Stroke.Subtle,
		order = props.order,
	})
	C.text({
		parent = pill,
		text = props.icon or "",
		type = "Body",
		size = UDim2.fromOffset(34, 38),
		alignX = Enum.TextXAlignment.Center,
		outline = false,
	})
	local value = C.text({
		parent = pill,
		name = "Value",
		text = props.text or "",
		type = "Body",
		size = UDim2.new(1, -40, 1, 0),
		position = UDim2.fromOffset(34, 0),
		color = props.color or Theme.Color.Text.Primary,
	})
	return pill, value
end

-- ─────────────────────────────── progress ───────────────────────────────

export type ProgressHandle = { frame: Frame, set: (number, string?, boolean?) -> (), setColor: (Color3, Color3?) -> () }

function C.Progress(props: { [string]: any }): ProgressHandle
	local track = C.frame({
		name = props.name or "Progress",
		parent = props.parent,
		color = Theme.Color.Surface.Sunken,
		transparency = 0.1,
		size = props.size or UDim2.new(1, 0, 0, 14),
		position = props.position,
		anchor = props.anchor,
		radius = Theme.Radius.Pill,
		stroke = Theme.Color.Stroke.Subtle,
		strokeThickness = 1,
		order = props.order,
		clip = true,
	})
	local fill = C.frame({
		name = "Fill",
		parent = track,
		color = Color3.new(1, 1, 1),
		size = UDim2.fromScale(0, 1),
		radius = Theme.Radius.Pill,
	})
	local gradient = C.new("UIGradient", {
		Color = ColorSequence.new(props.color or Theme.Color.Accent.Gold, props.color2 or Theme.Color.Accent.GoldDeep),
		Parent = fill,
	})
	local label
	if props.showLabel then
		label = C.text({
			parent = track,
			text = "",
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
			z = 3,
		})
	end
	return {
		frame = track,
		set = function(fraction: number, text: string?, instant: boolean?)
			fraction = math.clamp(fraction, 0, 1)
			if instant then
				fill.Size = UDim2.fromScale(fraction, 1)
			else
				C.tween(fill, Theme.Motion.Count, { Size = UDim2.fromScale(fraction, 1) })
			end
			if label and text then
				label.Text = text
			end
		end,
		setColor = function(a: Color3, b: Color3?)
			gradient.Color = ColorSequence.new(a, b or a)
		end,
	}
end

-- ─────────────────────────────── tabs ───────────────────────────────

export type TabsHandle = { frame: Frame, select: (string) -> (), selected: () -> string }

function C.Tabs(props: { [string]: any }): TabsHandle
	local frame = C.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.new(1, 0, 0, 44),
		Position = props.position or UDim2.new(),
		Parent = props.parent,
	})
	C.list(frame, Enum.FillDirection.Horizontal, Theme.Space.SM)
	local buttons = {}
	local current = props.tabs[1].id
	local function refresh()
		for id, handle in buttons do
			handle.setVariant(if id == current then "primary" else "ghost")
		end
	end
	for index, tab in props.tabs do
		local handle = C.Button({
			parent = frame,
			text = tab.label,
			icon = tab.icon,
			width = tab.width or 150,
			size = "md",
			order = index,
			radius = Theme.Radius.Pill,
			onClick = function()
				if current ~= tab.id then
					current = tab.id
					refresh()
					if props.onSelect then
						props.onSelect(tab.id)
					end
				end
			end,
		})
		buttons[tab.id] = handle
	end
	refresh()
	return {
		frame = frame,
		select = function(id: string)
			current = id
			refresh()
			if props.onSelect then
				props.onSelect(id)
			end
		end,
		selected = function()
			return current
		end,
	}
end

-- ─────────────────────────────── scrolling ───────────────────────────────

function C.Scroll(props: { [string]: any }): ScrollingFrame
	local scroll = C.new("ScrollingFrame", {
		Name = props.name or "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = props.axis or Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Stroke.Strong,
		ScrollingDirection = props.direction or Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		Parent = props.parent,
	})
	return scroll
end

-- ─────────────────────────────── modal ───────────────────────────────

export type ModalHandle = {
	root: Frame,
	panel: Frame,
	body: Frame,
	header: Frame,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	onClose: (() -> ())?,
	onOpen: (() -> ())?,
}

function C.Modal(props: { [string]: any }): ModalHandle
	local size = props.size or Theme.Size.Modal
	local root = C.new("Frame", {
		Name = props.name or "Modal",
		BackgroundColor3 = Theme.Color.Surface.Base,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
		Active = true,
		Parent = props.parent,
	})
	local scale = C.new("UIScale", { Scale = 0.92 })
	local outer, panel = C.card({
		parent = root,
		size = UDim2.fromOffset(size.X, size.Y),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		radius = Theme.Radius.LG,
		elevation = "E2",
		stroke = Theme.Color.Stroke.Strong,
		z = 51,
	})
	scale.Parent = outer
	local group = C.new("CanvasGroup", {
		Name = "Fade",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 0,
		Parent = panel,
	})
	local header =
		C.new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Parent = group })
	C.padding(header, 0, Theme.Space.XL)
	C.text({
		parent = header,
		text = props.title or "",
		type = "Title",
		size = UDim2.new(1, -60, 1, 0),
		position = UDim2.fromOffset(0, 4),
		color = Theme.Color.Accent.Gold,
	})
	local close = C.new("TextButton", {
		Name = "Close",
		AutoButtonColor = false,
		Text = "✕",
		FontFace = Theme.Font.UI,
		TextSize = 22,
		TextColor3 = Theme.Color.Text.Primary,
		BackgroundColor3 = Theme.Color.Surface.Raised,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = header,
	})
	C.corner(close, Theme.Radius.Pill)
	C.stroke(close, Theme.Color.Stroke.Strong)
	C.interactive(close)
	C.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = Theme.Color.Stroke.Subtle,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -48, 0, 2),
		Position = UDim2.fromOffset(24, 64),
		Parent = group,
	})
	local body = C.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 1, -88),
		Position = UDim2.fromOffset(24, 76),
		Parent = group,
	})
	local open = false
	local handle
	local blur: BlurEffect? = nil
	local function closeModal()
		if not open then
			return
		end
		open = false
		C.hideTooltip()
		sound("close")
		C.tween(scale, Theme.Motion.PanelOut, { Scale = 0.94 })
		C.tween(group, Theme.Motion.PanelOut, { GroupTransparency = 1 })
		C.tween(root, Theme.Motion.PanelOut, { BackgroundTransparency = 1 })
		if blur then
			C.tween(blur, Theme.Motion.PanelOut, { Size = 0 })
		end
		task.delay(Theme.Motion.PanelOut.Time, function()
			if not open then
				root.Visible = false
			end
		end)
		if handle.onClose then
			handle.onClose()
		end
	end
	local function openModal()
		if open then
			return
		end
		open = true
		root.Visible = true
		sound("open")
		scale.Scale = 0.92
		group.GroupTransparency = 1
		C.tween(scale, Theme.Motion.PanelIn, { Scale = 1 })
		C.tween(group, Theme.Motion.Fade, { GroupTransparency = 0 })
		C.tween(root, Theme.Motion.Fade, { BackgroundTransparency = 0.45 })
		local current = blur
		if not current then
			current = Instance.new("BlurEffect")
			current.Name = "ModalBlur"
			current.Size = 0
			current.Parent = game:GetService("Lighting")
			blur = current
		end
		C.tween(current, Theme.Motion.Fade, { Size = 10 })
		if handle.onOpen then
			handle.onOpen()
		end
	end
	close.Activated:Connect(closeModal)
	handle = {
		root = root,
		panel = panel,
		body = body,
		header = header,
		open = openModal,
		close = closeModal,
		isOpen = function()
			return open
		end,
		onClose = nil,
		onOpen = nil,
	}
	return handle
end

-- ─────────────────────────────── 3D viewports ───────────────────────────────

local spinning = {} :: { [ViewportFrame]: { model: Model, base: CFrame, speed: number, active: boolean } }

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for viewport, entry in spinning do
		if not viewport.Parent then
			spinning[viewport] = nil
		elseif entry.active and viewport.Visible then
			entry.model:PivotTo(entry.base * CFrame.Angles(0, t * entry.speed, math.sin(t * 2) * 0.08))
		end
	end
end)

-- ViewportFrame showing `model`, framed automatically. Returns viewport and a setter for spin.
function C.Viewport(props: { [string]: any }): (ViewportFrame, (boolean) -> ())
	local viewport = C.new("ViewportFrame", {
		Name = props.name or "Viewport",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		Ambient = props.ambient or Color3.fromRGB(150, 140, 180),
		LightColor = props.light or Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = props.z or 1,
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	local model: Model = props.model
	local camera = Instance.new("Camera")
	camera.FieldOfView = props.fov or 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	local cf, extents = model:GetBoundingBox()
	local radius = extents.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (props.zoom or 1.05)
	local center = cf.Position
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * 0.18, distance), center)
	local base = model:GetPivot()
	local entry = { model = model, base = base, speed = props.spinSpeed or 1.2, active = props.spin == true }
	spinning[viewport] = entry
	return viewport,
		function(active: boolean)
			entry.active = active
			if not active then
				model:PivotTo(base)
			end
		end
end

function C.BottleIcon(props: { [string]: any }): (ViewportFrame, (boolean) -> ())
	local model = if props.silhouette
		then PotionModel.silhouette(props.potion.bottle)
		else PotionModel.build(props.potion)
	return C.Viewport({
		parent = props.parent,
		model = model,
		size = props.size,
		position = props.position,
		anchor = props.anchor,
		z = props.z,
		order = props.order,
		spin = props.spin,
		zoom = props.zoom or 1.15,
		ambient = Color3.fromRGB(170, 160, 200),
	})
end

-- ─────────────────────────────── tooltip ───────────────────────────────

local tooltip: Frame? = nil
local tooltipTitle: TextLabel? = nil
local tooltipBody: TextLabel? = nil

function C.mountTooltip(parent: Instance)
	local frame = C.frame({
		name = "Tooltip",
		parent = parent,
		color = Theme.Color.Surface.Panel,
		transparency = 0.02,
		size = UDim2.fromOffset(280, 0),
		autoSize = Enum.AutomaticSize.Y,
		radius = Theme.Radius.MD,
		stroke = Theme.Color.Stroke.Strong,
		z = 200,
		visible = false,
	})
	C.padding(frame, Theme.Space.MD)
	C.list(frame, Enum.FillDirection.Vertical, Theme.Space.XS)
	tooltipTitle = C.text({
		parent = frame,
		text = "",
		type = "Label",
		order = 1,
		z = 201,
		wrap = true,
		autoSize = Enum.AutomaticSize.Y,
	})
	tooltipBody = C.text({
		parent = frame,
		text = "",
		type = "Caption",
		order = 2,
		color = Theme.Color.Text.Secondary,
		wrap = true,
		autoSize = Enum.AutomaticSize.Y,
		z = 201,
	})
	tooltip = frame
	RunService.RenderStepped:Connect(function()
		if frame.Visible then
			-- The tooltip lives inside a UIScale'd root: convert viewport pixels to design pixels.
			local uiScale = parent:FindFirstChildOfClass("UIScale")
			local s = if uiScale then math.max(uiScale.Scale, 0.01) else 1
			local mouse = UserInputService:GetMouseLocation() / s
			local parentSize = ((parent :: any).AbsoluteSize or Vector2.new(1920, 1080)) / s
			local frameSize = frame.AbsoluteSize / s
			local x = math.min(mouse.X + 18, parentSize.X - frameSize.X - 8)
			local y = math.min(mouse.Y + 18, parentSize.Y - frameSize.Y - 8)
			frame.Position = UDim2.fromOffset(x, y)
		end
	end)
end

function C.showTooltip(title: string, body: string?, color: Color3?)
	if not tooltip or not tooltipTitle or not tooltipBody then
		return
	end
	tooltipTitle.Text = title
	tooltipTitle.TextColor3 = color or Theme.Color.Text.Primary
	tooltipBody.Text = body or ""
	tooltipBody.Visible = body ~= nil and body ~= ""
	tooltip.Visible = true
end

function C.hideTooltip()
	if tooltip then
		tooltip.Visible = false
	end
end

-- ─────────────────────────────── slider ───────────────────────────────

function C.Slider(props: { [string]: any })
	local frame = C.new("Frame", {
		Name = "Slider",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.new(1, 0, 0, 56),
		LayoutOrder = props.order or 0,
		Parent = props.parent,
	})
	C.text({ parent = frame, text = props.label or "", type = "Label", size = UDim2.new(0.5, 0, 0, 24) })
	local valueLabel = C.text({
		parent = frame,
		text = "",
		type = "Label",
		size = UDim2.new(0.5, 0, 0, 24),
		position = UDim2.fromScale(0.5, 0),
		alignX = Enum.TextXAlignment.Right,
		color = Theme.Color.Accent.Gold,
	})
	local track = C.new("TextButton", {
		Name = "Track",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Surface.Sunken,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 34),
		Parent = frame,
	})
	C.corner(track, Theme.Radius.Pill)
	C.stroke(track, Theme.Color.Stroke.Subtle, 1)
	local fill = C.frame({
		parent = track,
		color = Theme.Color.Accent.Gold,
		size = UDim2.fromScale(0, 1),
		radius = Theme.Radius.Pill,
	})
	local knob = C.frame({
		parent = track,
		color = Theme.Color.Text.Primary,
		size = UDim2.fromOffset(24, 24),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0, 0.5),
		radius = Theme.Radius.Pill,
		stroke = Theme.Color.Stroke.Gold,
	})
	local value = props.value or 0.5
	local function set(v: number, fire: boolean?)
		value = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		valueLabel.Text = string.format("%d%%", math.floor(value * 100 + 0.5))
		if fire and props.onChange then
			props.onChange(value)
		end
	end
	set(value)
	local dragging = false
	local function update(x: number)
		local absPos, absSize = track.AbsolutePosition.X, track.AbsoluteSize.X
		if absSize > 0 then
			set((x - absPos) / absSize, true)
		end
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if dragging then
				dragging = false
				sound("click")
			end
		end
	end)
	return { frame = frame, set = set }
end

-- Number count-up animation on a TextLabel (uses an IntValue to tween).
function C.countTo(label: TextLabel, from: number, to: number, format: (number) -> string)
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(v)
		label.Text = format(v)
	end)
	local tween = C.tween(value, Theme.Motion.Count, { Value = to })
	tween.Completed:Connect(function()
		label.Text = format(to)
		value:Destroy()
	end)
end

function C.pulse(instance: GuiObject, amount: number?)
	local scale = instance:FindFirstChild("PulseScale") :: UIScale?
	if not scale then
		scale = C.new("UIScale", { Name = "PulseScale", Parent = instance })
	end
	if scale then
		scale.Scale = amount or 1.25
		C.tween(scale, Theme.Motion.Pulse, { Scale = 1 })
	end
end

return C
