--!strict
-- Chunky simulator-style button: a gradient face with a thick dark outline, a gloss highlight, an
-- inner shadow and a stroked label, raised on a darker base (Theme.Depth) like a 3D key. Hover
-- grows it and thickens the outline, pressing sinks the face into the base, disabled turns it
-- grey; click/hover sounds. Calls to action can carry a glint sweep (Shine = true).
--
-- Instance is the transparent hit box (face + base); Content is the face's content frame (it
-- moves with the face), so extra labels go there.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Shine = require(script.Parent.Shine)
local AudioController = require(UI.Parent.Controllers.AudioController)

export type ButtonProps = {
	Parent: Instance?,
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Style: string?,
	Text: string?,
	TextSize: number?,
	Font: Font?,
	LayoutOrder: number?,
	ZIndex: number?,
	Corner: number?,
	Depth: number?, -- base height under the face (default Theme.Depth)
	Shine: boolean?, -- glint sweep for calls to action
	OnClick: (() -> ())?,
	Silent: boolean?,
}

export type Button = {
	Instance: TextButton,
	Face: Frame,
	Gradient: UIGradient, -- the face gradient
	Label: TextLabel,
	Content: Frame,
	SetText: (Button, string) -> (),
	SetStyle: (Button, string) -> (),
	SetEnabled: (Button, boolean) -> (),
	Enabled: boolean,
	Style: string,
	Destroy: (Button) -> (),
}

local Button = {}

local QUICK = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MUTED: { [string]: boolean } = { Grey = true, Dark = true, Disabled = true }
-- Inner shadow: the lower part of a face darkens toward its bottom edge (depth under the gloss).
local INNER_SHADOW = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0.7),
})

function Button.new(props: ButtonProps): Button
	local styleName = props.Style or "Grey"
	local style = Theme.Buttons[styleName] or Theme.Buttons.Grey
	local corner = props.Corner or 10
	local depth = props.Depth or Theme.Depth
	local z = props.ZIndex or 1

	local root: TextButton = Create("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = z,
		Selectable = true,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- darker base: shows as a lip under the face
	local base: Frame = Create("Frame", {
		Name = "Base",
		BackgroundColor3 = Theme.Darken(style.Bottom, 0.55),
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = z,
		Parent = root,
	})
	Create.Corner(corner, base)
	local baseStroke = Create.Stroke(base, style.Border, Theme.Outline, 0, true)

	local face: Frame = Create("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = z + 1,
		Parent = root,
	})
	Create.Corner(corner, face)
	local gradient = Create.Gradient(face, style.Top, style.Bottom, 90)
	local border = Create.Stroke(face, style.Border, Theme.Outline, 0, true)

	-- glossy top highlight
	local gloss = Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Size = UDim2.new(1, -8, 0.44, 0),
		Position = UDim2.fromOffset(4, 3),
		ZIndex = z + 1,
		Parent = face,
	})
	Create.Corner(math.max(corner - 2, 0), gloss)
	local inner: Frame = Create("Frame", {
		Name = "InnerShadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		ZIndex = z + 1,
		Parent = face,
	})
	Create.Corner(corner, inner)
	local innerGradient = Instance.new("UIGradient")
	innerGradient.Rotation = 90
	innerGradient.Transparency = INNER_SHADOW
	innerGradient.Parent = inner
	local shine = if props.Shine then Shine.Add(face, UDim.new(0, corner), z + 2) else nil

	local content: Frame = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 3,
		Parent = face,
	})
	local label = Create.Text({
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = props.Font or Theme.Fonts.Display,
		TextSize = props.TextSize or 28,
		Scaled = true,
		Color = style.Text,
		Stroke = 2.6,
		ZIndex = z + 2,
		Parent = content,
	})

	local self = {
		Instance = root,
		Face = face,
		Gradient = gradient,
		Label = label,
		Content = content,
		Enabled = true,
		Style = styleName,
	} :: any

	local function setStyle(name: string)
		local s = Theme.Buttons[name] or Theme.Buttons.Grey
		gradient.Color = ColorSequence.new(s.Top, s.Bottom)
		border.Color = s.Border
		baseStroke.Color = s.Border
		base.BackgroundColor3 = Theme.Darken(s.Bottom, 0.55)
		label.TextColor3 = s.Text
		if shine then
			shine.Visible = not MUTED[name] -- no glint on grey / disabled keys
		end
	end
	setStyle(styleName)

	function self.SetText(_: any, text: string)
		label.Text = text
	end
	function self.SetStyle(this: any, name: string)
		this.Style = name
		if this.Enabled then
			setStyle(name)
		end
	end
	function self.SetEnabled(this: any, enabled: boolean)
		this.Enabled = enabled
		root.Active = enabled
		root.AutoButtonColor = false
		setStyle(if enabled then this.Style else "Disabled")
	end
	function self.Destroy(_: any)
		root:Destroy()
	end

	local UP = UDim2.new()
	local DOWN = UDim2.fromOffset(0, depth - 1)
	root.MouseEnter:Connect(function()
		if self.Enabled then
			TweenService:Create(scale, QUICK, { Scale = 1.05 }):Play()
			TweenService:Create(border, QUICK, { Thickness = Theme.Outline + 1.5 }):Play()
			if not props.Silent then
				AudioController.Play("Hover", nil, 0.05)
			end
		end
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
		TweenService:Create(face, QUICK, { Position = UP }):Play()
		TweenService:Create(border, QUICK, { Thickness = Theme.Outline }):Play()
	end)
	root.MouseButton1Down:Connect(function()
		if self.Enabled then
			TweenService:Create(face, QUICK, { Position = DOWN }):Play()
			TweenService:Create(scale, QUICK, { Scale = 0.97 }):Play()
		end
	end)
	root.MouseButton1Up:Connect(function()
		TweenService:Create(face, SPRING, { Position = UP }):Play()
		TweenService:Create(scale, SPRING, { Scale = 1 }):Play()
	end)
	root.Activated:Connect(function()
		if not self.Enabled then
			AudioController.Play("Error", nil, 0.2)
			return
		end
		if not props.Silent then
			AudioController.Play("Click")
		end
		if props.OnClick then
			props.OnClick()
		end
	end)

	root.Parent = props.Parent
	return self :: Button
end

-- Close button in the simulator style: red raised key with a heavy white X, breaking out of the
-- panel's top-right corner.
function Button.Close(parent: Instance, onClick: () -> (), position: UDim2?, size: number?): Button
	local s = size or 64
	local b = Button.new({
		Parent = parent,
		Name = "Close",
		Size = UDim2.fromOffset(s, s),
		Position = position or UDim2.new(1, -s * 0.35, 0, -s * 0.35),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Style = "Red",
		Text = "X",
		Font = Theme.Fonts.Display,
		Corner = 14,
		ZIndex = 20,
		OnClick = onClick,
	})
	b.Label.Size = UDim2.fromScale(0.6, 0.6)
	return b
end

return Button
