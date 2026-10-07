--!strict
-- Chunky reference-style button: vertical gradient, dark border, bottom shade, stroked label.
-- Feedback: hover grow, press squash, disabled grey, click/hover sounds.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
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
	OnClick: (() -> ())?,
	Silent: boolean?,
}

export type Button = {
	Instance: TextButton,
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

local QUICK = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Button.new(props: ButtonProps): Button
	local styleName = props.Style or "Grey"
	local style = Theme.Buttons[styleName] or Theme.Buttons.Grey
	local corner = props.Corner or 8

	local root: TextButton = Create("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Selectable = true,
	})
	Create.Corner(corner, root)
	local gradient = Create.Gradient(root, style.Top, style.Bottom, 90)
	local border = Create.Stroke(root, style.Border, 2.5, 0, true)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- glossy top highlight
	local gloss = Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3),
		ZIndex = root.ZIndex,
		Parent = root,
	})
	Create.Corner(corner - 2, gloss)
	-- bottom shade (3D lip)
	local shade = Create("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.78,
		Size = UDim2.new(1, 0, 0, 5),
		Position = UDim2.new(0, 0, 1, -5),
		ZIndex = root.ZIndex,
		Parent = root,
	})
	Create.Corner(corner, shade)

	local content: Frame = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = root.ZIndex + 1,
		Parent = root,
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
		Stroke = 2.2,
		ZIndex = root.ZIndex + 2,
		Parent = content,
	})

	local self = {
		Instance = root,
		Label = label,
		Content = content,
		Enabled = true,
		Style = styleName,
	} :: any

	local function setStyle(name: string)
		local s = Theme.Buttons[name] or Theme.Buttons.Grey
		gradient.Color = ColorSequence.new(s.Top, s.Bottom)
		border.Color = s.Border
		label.TextColor3 = s.Text
	end

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

	root.MouseEnter:Connect(function()
		if self.Enabled then
			TweenService:Create(scale, QUICK, { Scale = 1.05 }):Play()
			if not props.Silent then
				AudioController.Play("Hover", nil, 0.05)
			end
		end
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	root.MouseButton1Down:Connect(function()
		if self.Enabled then
			TweenService:Create(scale, QUICK, { Scale = 0.94 }):Play()
		end
	end)
	root.MouseButton1Up:Connect(function()
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

-- Square close button in the reference style (light grey block, heavy stroked X).
function Button.Close(parent: Instance, onClick: () -> (), position: UDim2?, size: number?): Button
	local s = size or 64
	local b = Button.new({
		Parent = parent,
		Name = "Close",
		Size = UDim2.fromOffset(s, s),
		Position = position or UDim2.new(1, -s * 0.35, 0, -s * 0.35),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Style = "Grey",
		Text = "X",
		Font = Theme.Fonts.Display,
		ZIndex = 20,
		OnClick = onClick,
	})
	b.Label.Size = UDim2.fromScale(0.62, 0.62)
	return b
end

return Button
